extends CharacterBody3D

#Movement Values
const Speed = 5.0
const JumpVelocity = 4.5
const LerpValue = 0.15

#Nodes
@onready var sprint_arm_pivot: Node3D = $SprintArmPivot
@onready var spring_arm_3d: SpringArm3D = $SprintArmPivot/SpringArm3D
@onready var armature: Node3D = $Model/Armature
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var pistol: Node3D = $Model/Armature/Skeleton3D/RightHandAttachment/Pistol
@onready var look_at_modifier: LookAtModifier3D = $Model/Armature/Skeleton3D/LookAtModifier3D
@onready var look_target: Marker3D = $SprintArmPivot/SpringArm3D/LookTarget

#Others
var GunEquipped= true
var GunBlend = 0.0

func _ready() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	#Mouse movement look
	if event is InputEventMouseMotion:
		sprint_arm_pivot.rotate_y(-event.relative.x*0.005)
		spring_arm_3d.rotate_x(-event.relative.y*0.005)
		spring_arm_3d.rotation.x=clamp(spring_arm_3d.rotation.x,-PI/4,PI/4)
	
	#Toggle Gun Equipment
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_1:
		GunEquipped=!GunEquipped

func _physics_process(delta: float) -> void:
	#Gravity
	if not is_on_floor():
		velocity+= get_gravity()*delta

	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y= JumpVelocity
	
	#Movement
	var InputDirection=Input.get_vector("Left","Right","Up","Down")
	var Direction = (transform.basis*Vector3(InputDirection.x, 0, InputDirection.y)).normalized()
	Direction = Direction.rotated(Vector3.UP, sprint_arm_pivot.rotation.y)

	if Direction:
		velocity.x = lerp(velocity.x,Direction.x*Speed,LerpValue)
		velocity.z = lerp(velocity.z, Direction.z*Speed,LerpValue)
		#rotate in direction of movement
		if not GunEquipped:
			armature.rotation.y = lerp_angle(armature.rotation.y,atan2(velocity.x,velocity.z),LerpValue)
	else:
		velocity.x = lerp(velocity.x, 0.0, LerpValue)
		velocity.z = lerp(velocity.z, 0.0, LerpValue)

	# rotate in crosshairs direction
	if GunEquipped:
		armature.rotation.y = lerp_angle(armature.rotation.y, sprint_arm_pivot.rotation.y + PI, LerpValue)

	# blend between gun equipped and unequipped smoothly
	var TargetBlend = 1.0 if GunEquipped else 0.0
	GunBlend = lerp(GunBlend, TargetBlend, 10.0 * delta)
	animation_tree.set("parameters/Blend2/blend_amount", GunBlend)
	
	if pistol:
		pistol.visible = GunEquipped

	UpdateHeadIK(delta)
	animation_tree.set("parameters/BlendSpace1D/blend_position", velocity.length()/Speed)
	move_and_slide()

func UpdateHeadIK(delta: float) -> void:
	if not look_at_modifier or not look_target:
		return
	# Character faces +Z in local space
	var LocalForward = armature.global_transform.basis.z.normalized()
	var ToTarget= (look_target.global_position-armature.global_position).normalized()
	var Alignment = LocalForward.dot(ToTarget)
	var TargetInfluence= 1.0 if Alignment>-0.2 else 0.0
	look_at_modifier.influence = lerp(look_at_modifier.influence, TargetInfluence, 10.0*delta)
