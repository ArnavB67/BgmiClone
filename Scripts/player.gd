extends CharacterBody3D

#Movement Values
const WalkSpeed = 5.0
const AimSpeed=2.5
const JumpVelocity = 4.5
const LerpValue = 0.15

#Nodes
@onready var camera_3d: Camera3D = $SprintArmPivot/SpringArm3D/Camera3D
@onready var sprint_arm_pivot: Node3D = $SprintArmPivot
@onready var spring_arm_3d: SpringArm3D = $SprintArmPivot/SpringArm3D
@onready var aim_ray: RayCast3D = $SprintArmPivot/SpringArm3D/Camera3D/AimRay
@onready var armature: Node3D = $Model/Armature
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var ak: Node3D = $Model/Armature/Skeleton3D/RightHandAttachment/AK
@onready var pistol: Node3D = $Model/Armature/Skeleton3D/RightHandAttachment/Pistol
@onready var look_at_modifier: LookAtModifier3D = $Model/Armature/Skeleton3D/LookAtModifier3D
@onready var look_target: Marker3D = $SprintArmPivot/SpringArm3D/LookTarget
@onready var skeleton_3d: Skeleton3D = $Model/Armature/Skeleton3D

#Weapon State
enum Weapon {Primary,Secondary,Melee}
var CurrentWeapon=Weapon.Melee
var IsAiming=false
const AkHoldingPosition = Vector3(-0.203, 0.52, 0.038)
const AkHoldingRotation=Vector3(24.2, 112.0, -172.7)
const AkAimingPosition=Vector3(0.096,0.664,0.037)
const AkAimingRotation=Vector3(74.1,-62.2,-121.6)
const PistolYawOffset =-12.0
const RifleYawOffset = -10.0
#Others
var GunRange=100.0
var PunchRange=2.5
var GunBlend = 0.0
var ShootCooldown=0.0

func _ready() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if aim_ray:
		aim_ray.add_exception(self)	
	UpdateWeaponGeneration()

func _unhandled_input(event: InputEvent) -> void:
	#Mouse movement look
	if event is InputEventMouseMotion:
		sprint_arm_pivot.rotate_y(-event.relative.x*0.005)
		spring_arm_3d.rotate_x(-event.relative.y*0.005)
		spring_arm_3d.rotation.x=clamp(spring_arm_3d.rotation.x,-PI/4,PI/4)

func _process(delta: float) -> void:
	IsAiming= Input.is_action_pressed("Aim") and CurrentWeapon!=Weapon.Melee
	#Select Weapons
	if Input.is_action_just_pressed("PrimaryWeapon"):
		EquipWeapon(Weapon.Primary)
	elif Input.is_action_just_pressed("SecondaryWeapon"):
		EquipWeapon(Weapon.Secondary)
	elif Input.is_action_just_pressed("Melee"):
		EquipWeapon(Weapon.Melee)
	
	if Input.is_action_just_pressed("Shoot") and CurrentWeapon==Weapon.Secondary:
		Shoot()
	elif Input.is_action_pressed("Shoot") and CurrentWeapon!=Weapon.Secondary:
		Shoot()

func Shoot():
	if ShootCooldown>0:
		return
	match CurrentWeapon:
		Weapon.Melee:
			ShootCooldown=0.5
			ShootRayCastAttack(PunchRange,15.0)
		Weapon.Secondary:
			ShootCooldown = 0.25
			#send a transition request to PistolShoot
			animation_tree.set("parameters/ActionTransition/transition_request", "PistolShoot")
			animation_tree.set("parameters/ActionOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			ShootRayCastAttack(GunRange, 25.0)
		Weapon.Primary:
			ShootCooldown = 0.1
			#send a transition request to RifleShoot
			animation_tree.set("parameters/ActionTransition/transition_request", "RifleShoot")
			animation_tree.set("parameters/ActionOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			ShootRayCastAttack(GunRange, 35.0)
			

func ShootRayCastAttack(MaxDistance,Damage):
	if not aim_ray:
		return
	#shoot a raycast in forward direction upto MaxDistance
	aim_ray.target_position=Vector3(0,0,-MaxDistance)
	aim_ray.force_raycast_update()
	if aim_ray.is_colliding():
		var Collider= aim_ray.get_collider()
		var HitPoint = aim_ray.get_collision_point()
		print("Hit, ",Collider.name)


func EquipWeapon(NewWeapon):
	if CurrentWeapon==NewWeapon:
		CurrentWeapon=Weapon.Melee
	else:
		CurrentWeapon=NewWeapon
	if CurrentWeapon==Weapon.Melee:
		IsAiming=false
	UpdateWeaponGeneration()

func UpdateWeaponGeneration():
	if pistol:
		pistol.visible=CurrentWeapon==Weapon.Secondary
	if ak:
		ak.visible=CurrentWeapon==Weapon.Primary
	
func _physics_process(delta: float) -> void:
	#Gravity
	if not is_on_floor():
		velocity+= get_gravity()*delta
	
	if ShootCooldown>0.0:
		ShootCooldown-=delta

	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y= JumpVelocity
	
	#Movement
	var CurrentSpeed= AimSpeed if IsAiming else WalkSpeed
	var InputDirection=Input.get_vector("Left","Right","Up","Down")
	var Direction = (transform.basis*Vector3(InputDirection.x, 0, InputDirection.y)).normalized()
	Direction = Direction.rotated(Vector3.UP, sprint_arm_pivot.rotation.y)

	if Direction:
		velocity.x = lerp(velocity.x,Direction.x*CurrentSpeed,LerpValue)
		velocity.z = lerp(velocity.z, Direction.z*CurrentSpeed,LerpValue)
		#rotate in direction of movement
		if CurrentWeapon==Weapon.Melee:
			armature.rotation.y = lerp_angle(armature.rotation.y,atan2(velocity.x,velocity.z),LerpValue)
	else:
		velocity.x = lerp(velocity.x, 0.0, LerpValue)
		velocity.z = lerp(velocity.z, 0.0, LerpValue)
		
	# Face Towards crosshair if gun is equipped or shooting
	var IsActionActive = animation_tree.get("parameters/ActionOneShot/active")
	var FaceCrosshair =(CurrentWeapon!=Weapon.Melee) or IsAiming or IsActionActive
	if FaceCrosshair:
		var TargetPosition = GetCrosshairWorldTarget()
		var ToTarget=TargetPosition-armature.global_position
		var TargetYaw=atan2(ToTarget.x,ToTarget.z)
		#add pose yaw compensation so the gun barrel lines up with the crosshair
		if CurrentWeapon==Weapon.Secondary:
			TargetYaw+= deg_to_rad(PistolYawOffset)
		elif CurrentWeapon==Weapon.Primary:
			TargetYaw+= deg_to_rad(RifleYawOffset)
		#rotate faster when aiming/shooting so the gun never lags behind the crosshair
		var RotationSpeed = 25.0*delta if(IsAiming or IsActionActive) else 12.0*delta
		armature.rotation.y = lerp_angle(armature.rotation.y, TargetYaw, RotationSpeed)
	elif Direction:
		armature.rotation.y=lerp_angle(armature.rotation.y,atan2(velocity.x,velocity.z),LerpValue)

	# blend between gun equipped and unequipped smoothly
	var TargetBlend = 1.0 if not CurrentWeapon==Weapon.Melee else 0.0
	GunBlend = lerp(GunBlend, TargetBlend, 10.0 * delta)
	animation_tree.set("parameters/Blend2/blend_amount", GunBlend)

	UpdateHeadIK(delta)
	UpdateAnimations(delta,IsActionActive)
	UpdateCameraZoom(delta)
	UpdateAkTransform(delta,IsActionActive)
	animation_tree.set("parameters/BlendSpace1D/blend_position", velocity.length()/WalkSpeed)
	move_and_slide()

func GetCrosshairWorldTarget():
	if aim_ray:
		aim_ray.target_position=Vector3(0,0,-GunRange)
		aim_ray.force_raycast_update()
		if aim_ray.is_colliding():
			var HitPoint=aim_ray.get_collision_point()
			if HitPoint.distance_to(global_position)>1.5:
				return HitPoint
	if look_target:
		return look_target.global_position
	return -camera_3d.global_transform.basis.z*20.0

func UpdateAkTransform(Delta,IsShooting):
	if not ak or CurrentWeapon!=Weapon.Primary:
		return
	var UseAimTransform=IsAiming or IsShooting
	#update ak position and rotation to desired values
	var TargetPosition= AkAimingPosition if UseAimTransform else AkHoldingPosition
	var TargetRotation = AkAimingRotation if UseAimTransform else AkHoldingRotation
	ak.position=ak.position.lerp(TargetPosition,18.0*Delta)
	var TargetQuaternion= Quaternion.from_euler(Vector3(deg_to_rad(TargetRotation.x),deg_to_rad(TargetRotation.y),deg_to_rad(TargetRotation.z)))
	ak.quaternion=ak.quaternion.slerp(TargetQuaternion,18.0*Delta)

func UpdateHeadIK(delta: float) -> void:
	if not look_at_modifier or not look_target:
		return
	#character faces +Z in local space
	var LocalForward = armature.global_transform.basis.z.normalized()
	var ToTarget= (look_target.global_position-armature.global_position).normalized()
	var Alignment = LocalForward.dot(ToTarget)
	var TargetInfluence= 1.0 if Alignment>-0.2 else 0.0
	look_at_modifier.influence = lerp(look_at_modifier.influence, TargetInfluence, 10.0*delta)

func UpdateAnimations(Delta,CurrentSpeed):
	var SpeedRatio =velocity.length()/WalkSpeed
	animation_tree.set("parameters/BlendSpace1D/blend_position",SpeedRatio)
	var TargetBlend=0.0 if CurrentWeapon==Weapon.Melee else 1.0
	animation_tree.set("parameters/Blend2/blend_amount",TargetBlend)
	GunBlend=lerp(GunBlend,TargetBlend,10.0*Delta)
	animation_tree.set("parameters/Blend2/blend_amount",GunBlend)
	match CurrentWeapon:
		Weapon.Primary:
			if IsAiming:
				animation_tree.set("parameters/Transition/transition_request","RifleAim")
			else:
				animation_tree.set("parameters/Transition/transition_request","RifleHold")
				animation_tree.set("parameters/BlendSpace1D 3/blend_position", SpeedRatio)
		Weapon.Secondary:
			if IsAiming:
				animation_tree.set("parameters/Transition/transition_request", "PistolAim")
			else:
				animation_tree.set("parameters/Transition/transition_request", "PistolLow")
				animation_tree.set("parameters/PistolBlend/blend_position", SpeedRatio)

func UpdateCameraZoom(Delta):
	if not camera_3d:
		return
	var TargetFov = 50.0 if IsAiming else 75.0
	var TargetSpringLength = 1.8 if IsAiming else 3.0
	camera_3d.fov=lerp(camera_3d.fov,TargetFov,10.0*Delta)
	spring_arm_3d.spring_length= lerp(spring_arm_3d.spring_length,TargetSpringLength,10.0*Delta)


func _on_skeleton_3d_skeleton_updated() -> void:
	#tilt arms up and down with vertical camera pitch when holding gun
	if CurrentWeapon==Weapon.Melee or not skeleton_3d:
		return
	var is_shooting = animation_tree.get("parameters/ActionOneShot/active")
	if IsAiming or is_shooting:
		var PitchAngle= -spring_arm_3d.rotation.x
		var PitchQuaternion= Quaternion(Vector3.RIGHT,PitchAngle)
		var LeftArmIndex=3
		var RightArmIndex=5
		var LeftRotation=skeleton_3d.get_bone_pose_rotation(LeftArmIndex)
		var RightRotation=skeleton_3d.get_bone_pose_rotation(RightArmIndex)
		skeleton_3d.set_bone_pose_rotation(LeftArmIndex,PitchQuaternion*LeftRotation)
		skeleton_3d.set_bone_pose_rotation(RightArmIndex,PitchQuaternion*RightRotation)
