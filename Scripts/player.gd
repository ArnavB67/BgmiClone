extends CharacterBody3D

#Movement Values
const WalkSpeed = 5.0
const CrouchSpeed = 2.5
const AimSpeed=2.5
const SprintSpeed= 8.0
const JumpVelocity = 4.5
const LerpValue = 0.15

enum PlayerState{InPlane,SkyDiving,Parachuting,Grounded,Dead}
var CurrentState= PlayerState.Grounded
const SkydiveTerminalVelocity= -35.0
const SkydiveHorizontalSpeed= 18.0
const ParachuteTerminalVelocity= -6.0
const ParachuteHorizontalSpeed= 12.0
const AutoParachuteHeight= 25.0

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
@onready var left_hand_ik: TwoBoneIK3D = $Model/Armature/Skeleton3D/LeftHandIK
@onready var left_hand_ik_pistol: TwoBoneIK3D = $Model/Armature/Skeleton3D/LeftHandIKPistol
@onready var pistol_particles: CPUParticles3D = $Model/Armature/Skeleton3D/RightHandAttachment/Pistol/PistolParticles
@onready var color_rect: ColorRect = $HUD/CenterContainer/ColorRect
@onready var pistol_omni_light: OmniLight3D = $Model/Armature/Skeleton3D/RightHandAttachment/Pistol/PistolOmniLight
@onready var impact_effect: CPUParticles3D = $ImpactEffect
@onready var ak_particles: CPUParticles3D = $Model/Armature/Skeleton3D/RightHandAttachment/AK/AkParticles
@onready var ak_omni_light: OmniLight3D = $Model/Armature/Skeleton3D/RightHandAttachment/AK/AkOmniLight
@onready var hud: CanvasLayer = $HUD
@onready var parachute_mesh: MeshInstance3D = $ParachuteMesh
@onready var health_label: Label = $HUD/MarginContainer/BottomBar/HealthLabel
@onready var ammo_label: Label = $HUD/MarginContainer/BottomBar/AmmoLabel
@onready var prompt_label: Label = $HUD/MarginContainer/BottomBar/PromptLabel
@onready var end_title_label: Label = $HUD/EndPanel/VBoxContainer/EndTitleLabel
@onready var zone_label: Label = $HUD/MarginContainer/TopBar/ZoneLabel

#New Editor Nodes for HUD, Minimap and Sound
@onready var health_bar: ProgressBar = $HUD/MarginContainer/BottomBar/HealthBar
@onready var kills_label: Label = $HUD/MarginContainer/TopBar/KillsLabel
@onready var timer_label: Label = $HUD/MarginContainer/TopBar/TimerLabel
@onready var inventory_panel: Panel = $HUD/InventoryPanel
@onready var inventory_label: Label = $HUD/InventoryPanel/InventoryLabel
@onready var minimap_camera: Camera3D = $HUD/MiniMap/SubViewport/MiniMapCamera
@onready var shoot_sound: AudioStreamPlayer = $ShootSound
@onready var reload_sound: AudioStreamPlayer = $ReloadSound
@onready var footstep_sound: AudioStreamPlayer = $FootstepSound

#Weapon State
enum Weapon {Primary,Secondary,Melee}
var CurrentWeapon=Weapon.Melee
var IsAiming=false
var IsSprinting = false
var IsCrouching = false
var HasPrimary =false
var HasSecondary = false
var PrimaryMagazineBullets=0
var PrimaryMagazineReserve=0
const MaxPrimaryMagazineBullets=30
var SecondaryMagazineBullets=0
var SecpondaryMagazineReserve=0
const MaxSecondaryMagazineBullets=12
var IsReloading = false
var Health =100.0
const MaxHealth = 100.0
var Armour = 0.0
const MaxArmour = 50
var MedkitCount= 0
var NearbyLoot= []

const AkHoldingPosition = Vector3(-0.203, 0.52, 0.038)
const AkHoldingRotation=Vector3(24.2, 112.0, -172.7)
const AkAimingPosition=Vector3(0.096,0.664,0.037)
const AkAimingRotation=Vector3(74.1,-62.2,-121.6)
const PistolYawOffset =-25.0
const RifleYawOffset = -10.0

#Others
var GunRange=100.0
var PunchRange=2.5
var GunBlend = 0.0
var ShootCooldown=0.0
var RecoilPitch =0.0
var RecoilYaw = 0.0
var Kills = 0
var MatchTimer = 0.0
var FallSpeed = 0.0
var FootstepTimer = 0.0
var LightTween: Tween
var ImpactMaterial: StandardMaterial3D
var BulletHoleMaterial: StandardMaterial3D
var ActiveDecals = []
const MaxDecals = 50

func _ready() -> void:
	add_to_group("Player")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if aim_ray:
		aim_ray.add_exception(self)
	if spring_arm_3d:
		spring_arm_3d.add_excluded_object(self.get_rid())
	if inventory_panel:
		inventory_panel.visible=false
	SetupVisualEffects()
	UpdateWeaponGeneration()

func UpdateHUD():
	health_label.text= "HP: %d/100 | Armour: %d/50 | MedKits[4]: %d" %[ceil(Health),ceil(Armour),MedkitCount]
	if health_bar:
		health_bar.value=Health
	if kills_label:
		var AliveCount= get_tree().get_nodes_in_group("Enemies").size()+1
		kills_label.text= "Kills: %d | Alive: %d" %[Kills,AliveCount]
	if timer_label:
		var Minutes= int(MatchTimer)/60
		var Seconds= int(MatchTimer)%60
		timer_label.text= "Time: %02d:%02d" %[Minutes,Seconds]
	if inventory_label:
		inventory_label.text= "Primary: %s\nSecondary: %s\nRifle Ammo: %d\nPistol Ammo: %d\nMedkits: %d\n\nPress [G] to Drop Equipped Gun" %[
			"AK-47" if HasPrimary else "None",
			"Glock" if HasSecondary else "None",
			PrimaryMagazineReserve,
			SecpondaryMagazineReserve,
			MedkitCount
		]
	match CurrentWeapon:
		Weapon.Primary:
			ammo_label.text= "Weapon: AK-47 | Ammo %d/30 |%d"%[PrimaryMagazineBullets,PrimaryMagazineReserve]
		Weapon.Secondary:
			ammo_label.text= "Weapon: Glock | Ammo %d/12 |%d"%[SecondaryMagazineBullets,SecpondaryMagazineReserve]
		Weapon.Melee:
			ammo_label.text= "Weapon: Fists"
	if CurrentState == PlayerState.InPlane:
		prompt_label.text = "Press [F] to Jump from Plane"
	elif CurrentState == PlayerState.SkyDiving:
		prompt_label.text = "Press [SPACE] to Open Parachute"
	elif not IsReloading:
		if NearbyLoot.size() > 0 and is_instance_valid(NearbyLoot[0]):
			prompt_label.text = "Press [F] to Pick Up " + NearbyLoot[0].ItemType
		else:
			prompt_label.text = ""

func SetupVisualEffects():
	#fix pistol particles and light scale
	if pistol_particles:
		pistol_particles.visible=true
		if pistol_particles.mesh:
			var PistolMesh=pistol_particles.mesh.duplicate()
			PistolMesh.size=Vector3(0.036,0.36,0.036)
			pistol_particles.mesh=PistolMesh
	if ak_particles and ak_particles.mesh:
		var AkMesh=ak_particles.mesh.duplicate()
		AkMesh.size=Vector3(0.012,0.12,0.012)
		ak_particles.mesh=AkMesh
	if pistol_omni_light:
		pistol_omni_light.shadow_enabled=false
		pistol_omni_light.light_energy=0.0
	if ak_omni_light:
		ak_omni_light.light_energy=0.0
	#impact effect for falling debris
	if impact_effect:
		ImpactMaterial=StandardMaterial3D.new()
		ImpactMaterial.shading_mode=BaseMaterial3D.SHADING_MODE_PER_VERTEX
		ImpactMaterial.vertex_color_use_as_albedo=true
		ImpactMaterial.roughness=0.9
		var DebrisMesh=BoxMesh.new()
		DebrisMesh.material=ImpactMaterial
		DebrisMesh.size=Vector3(0.045,0.045,0.045)
		impact_effect.mesh=DebrisMesh
		impact_effect.amount=16
		impact_effect.lifetime=0.55
		impact_effect.one_shot=true
		impact_effect.explosiveness=0.95
		impact_effect.randomness=0.4
		impact_effect.local_coords=false
		impact_effect.particle_flag_align_y=false
		impact_effect.direction=Vector3(0,0,-1)
		impact_effect.spread=55.0
		impact_effect.initial_velocity_min=2.2
		impact_effect.initial_velocity_max=5.5
		impact_effect.gravity=Vector3(0,-14.0,0)
		impact_effect.damping_min=1.0
		impact_effect.damping_max=3.0
		var DebrisCurve=Curve.new()
		DebrisCurve.add_point(Vector2(0.0,1.0))
		DebrisCurve.add_point(Vector2(0.7,0.85))
		DebrisCurve.add_point(Vector2(1.0,0.0))
		impact_effect.scale_amount_curve=DebrisCurve
	BulletHoleMaterial=CreateBulletHoleMaterial()

func CreateBulletHoleMaterial():
	var HoleImage=Image.create(64,64,false,Image.FORMAT_RGBA8)
	var Center=Vector2(32,32)
	for y in range(64):
		for x in range(64):
			var Dist=Vector2(x,y).distance_to(Center)/32.0
			if Dist>1.0:
				HoleImage.set_pixel(x,y,Color(0,0,0,0))
			elif Dist<0.35:
				HoleImage.set_pixel(x,y,Color(0.05,0.05,0.05,0.92))
			elif Dist<0.65:
				var Weight=(Dist-0.35)/0.3
				HoleImage.set_pixel(x,y,Color(0.15,0.14,0.13,lerpf(0.85,0.35,Weight)))
			else:
				var Weight=(Dist-0.65)/0.35
				HoleImage.set_pixel(x,y,Color(0.25,0.25,0.25,lerpf(0.35,0.0,Weight)))
	var HoleTexture=ImageTexture.create_from_image(HoleImage)
	var BulletMaterial=StandardMaterial3D.new()
	BulletMaterial.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	BulletMaterial.albedo_texture=HoleTexture
	BulletMaterial.roughness=1.0
	BulletMaterial.cull_mode=BaseMaterial3D.CULL_BACK
	return BulletMaterial

func _unhandled_input(event: InputEvent) -> void:
	#Mouse movement look
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		sprint_arm_pivot.rotate_y(-event.relative.x*0.005)
		spring_arm_3d.rotate_x(-event.relative.y*0.005)
		spring_arm_3d.rotation.x=clamp(spring_arm_3d.rotation.x,-PI/4,PI/4)

func _process(delta: float) -> void:
	if CurrentState!=PlayerState.Dead:
		MatchTimer+=delta
	if minimap_camera:
		minimap_camera.global_position=Vector3(global_position.x,60.0,global_position.z)

	if CurrentState!=PlayerState.Grounded:
		UpdateHUD()
		return

	#Toggle Inventory UI
	if Input.is_action_just_pressed("Inventory") and inventory_panel:
		inventory_panel.visible=not inventory_panel.visible
		if inventory_panel.visible:
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

	#Toggle Crouch
	if Input.is_action_just_pressed("Crouch"):
		IsCrouching=not IsCrouching

	#Drop Current Weapon
	if Input.is_action_just_pressed("Drop"):
		DropCurrentWeapon()

	IsAiming= Input.is_action_pressed("Aim") and CurrentWeapon!=Weapon.Melee
	IsSprinting = Input.is_action_pressed("Sprint") and not IsAiming and not IsCrouching and is_on_floor()

	#Select Weapons
	if Input.is_action_just_pressed("PrimaryWeapon"):
		EquipWeapon(Weapon.Primary)
	elif Input.is_action_just_pressed("SecondaryWeapon"):
		EquipWeapon(Weapon.Secondary)
	elif Input.is_action_just_pressed("Melee"):
		EquipWeapon(Weapon.Melee)
	if Input.is_action_just_pressed("Reload"):
		Reload()
	if Input.is_action_just_pressed("Heal"):
		UseMedkit()
	if Input.is_action_just_pressed("Interact"):
		PickupNearestLoot()
	if Input.is_action_just_pressed("Shoot") and CurrentWeapon==Weapon.Secondary:
		Shoot()
	elif Input.is_action_pressed("Shoot") and CurrentWeapon!=Weapon.Secondary:
		Shoot()

	UpdateHUD()

func DropCurrentWeapon():
	var LootScene=load("res://Scenes/loot_item.tscn")
	if not LootScene:
		return
	if CurrentWeapon==Weapon.Primary and HasPrimary:
		HasPrimary=false
		var Drop=LootScene.instantiate()
		Drop.ItemType="AK"
		get_tree().current_scene.add_child(Drop)
		Drop.global_position=global_position+Vector3(0,0.5,1.5)
		EquipWeapon(Weapon.Melee)
	elif CurrentWeapon==Weapon.Secondary and HasSecondary:
		HasSecondary=false
		var Drop=LootScene.instantiate()
		Drop.ItemType="Pistol"
		get_tree().current_scene.add_child(Drop)
		Drop.global_position=global_position+Vector3(0,0.5,1.5)
		EquipWeapon(Weapon.Melee)

func Reload():
	if IsReloading:
		return
	if CurrentWeapon==Weapon.Primary and PrimaryMagazineBullets<MaxPrimaryMagazineBullets and PrimaryMagazineReserve>0:
		IsReloading=true
		if reload_sound:
			reload_sound.play()
		prompt_label.text= "Reloading AK...."
		await get_tree().create_timer(1.5).timeout
		var BulletsNeeded= min(MaxPrimaryMagazineBullets-PrimaryMagazineBullets,PrimaryMagazineReserve)
		PrimaryMagazineBullets+=BulletsNeeded
		PrimaryMagazineReserve-=BulletsNeeded
		IsReloading= false
	elif CurrentWeapon==Weapon.Secondary and SecondaryMagazineBullets<MaxSecondaryMagazineBullets and SecpondaryMagazineReserve>0:
		IsReloading= true
		if reload_sound:
			reload_sound.play()
		prompt_label.text = "Reloading Glock...."
		await get_tree().create_timer(1).timeout
		var BulletsNeeded= min(MaxSecondaryMagazineBullets-SecondaryMagazineBullets,SecpondaryMagazineReserve)
		SecondaryMagazineBullets+=BulletsNeeded
		SecpondaryMagazineReserve-= BulletsNeeded
		IsReloading = false

func UseMedkit():
	if MedkitCount>0 and Health<MaxHealth:
		MedkitCount-=1
		Health= min(Health+50,MaxHealth)

func PickupNearestLoot():
	if NearbyLoot.is_empty():
		return
	var Item = NearbyLoot[0]
	if not is_instance_valid(Item):
		NearbyLoot.remove_at(0)
		return
	match Item.ItemType:
		"AK":
			HasPrimary= true
			PrimaryMagazineBullets=randi_range(5,30)
			PrimaryMagazineReserve+=30
			EquipWeapon(Weapon.Primary)
		"Pistol":
			HasSecondary = true
			SecondaryMagazineBullets=randi_range(1,12)
			SecpondaryMagazineReserve+=12
			if CurrentWeapon==Weapon.Melee:
				EquipWeapon(Weapon.Secondary)
		"RifleAmmo":
			PrimaryMagazineReserve+=randi_range(25,60)
		"PistolAmmo":
			SecpondaryMagazineReserve+=randi_range(8,24)
		"Medkit":
			MedkitCount+=1
		"Armour":
			Armour=MaxArmour
	NearbyLoot.erase(Item)
	Item.queue_free()

func Shoot():
	if ShootCooldown>0 or IsReloading:
		return
	match CurrentWeapon:
		Weapon.Melee:
			ShootCooldown=0.5
			if shoot_sound:
				shoot_sound.play()
			ShootRayCastAttack(PunchRange,15.0,null)
		Weapon.Secondary:
			if SecondaryMagazineBullets<=0:
				Reload()
				return
			SecondaryMagazineBullets-=1
			ShootCooldown = 0.25
			if shoot_sound:
				shoot_sound.play()
			#send a transition request to PistolShoot
			animation_tree.set("parameters/ActionTransition/transition_request", "PistolShoot")
			animation_tree.set("parameters/ActionOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			TriggerMuzzleFlash(pistol_particles, pistol_omni_light, 10.0, 45.0)
			ApplyCameraRecoil(0.035, 0.015)
			ShootRayCastAttack(GunRange, 25.0, pistol_particles)
		Weapon.Primary:
			if PrimaryMagazineBullets<=0:
				Reload()
				return
			PrimaryMagazineBullets-=1
			ShootCooldown = 0.1
			if shoot_sound:
				shoot_sound.play()
			#send a transition request to RifleShoot
			animation_tree.set("parameters/ActionTransition/transition_request", "RifleShoot")
			animation_tree.set("parameters/ActionOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			TriggerMuzzleFlash(ak_particles, ak_omni_light, 11.0, 18.0)
			ApplyCameraRecoil(0.025, 0.02)
			ShootRayCastAttack(GunRange, 35.0, ak_particles)

func TriggerMuzzleFlash(Particles,Light,PeakEnergy,PeakRange):
	if Particles:
		Particles.visible=true
		Particles.restart()
		Particles.emitting = true
	if Light:
		if LightTween and LightTween.is_running():
			LightTween.kill()
		Light.light_energy= PeakEnergy*randf_range(0.85,1.15)
		Light.omni_range = PeakRange*randf_range(0.9,1.1)
		Light.light_color = Color(1.0, randf_range(0.58, 0.72), randf_range(0.18, 0.32))
		LightTween = create_tween().set_parallel(true)
		LightTween.tween_property(Light, "light_energy", 0.0, 0.045).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		LightTween.tween_property(Light, "omni_range", 0.5, 0.045).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func ApplyCameraRecoil(PitchIntensity,Spread):
	spring_arm_3d.rotation.x = clamp(spring_arm_3d.rotation.x+PitchIntensity,-PI/4,PI/4)
	sprint_arm_pivot.rotate_y(randf_range(-Spread,Spread))

func ShootRayCastAttack(MaxDistance,Damage,MuzzleNode):
	if not aim_ray:
		return
	#shoot a raycast in forward direction upto MaxDistance
	aim_ray.target_position=Vector3(0,0,-MaxDistance)
	aim_ray.force_raycast_update()
	var EndPoint=GetCrosshairWorldTarget()
	if aim_ray.is_colliding():
		var Collider= aim_ray.get_collider()
		var HitPoint = aim_ray.get_collision_point()
		var HitPointNormal = aim_ray.get_collision_normal()
		EndPoint=HitPoint
		#calculate damage based on distance and apply to enemy
		if Collider.has_method("TakeDamage"):
			var Distance=global_position.distance_to(HitPoint)
			var FinalDamage=Damage*clamp(1.0-(Distance/MaxDistance)*0.4,0.5,1.0)
			Collider.TakeDamage(FinalDamage)
			
		if CurrentWeapon!=Weapon.Melee:
			ShowImpactEffect(HitPoint,HitPointNormal,Collider)
			SpawnBulletDecal(HitPoint,HitPointNormal,Collider)
		print("Hit, ",Collider.name)
	if MuzzleNode and CurrentWeapon!=Weapon.Melee:
		SpawnBulletTracer(MuzzleNode.global_position,EndPoint)

func GetObjectColor(Collider):
	var BaseColor=Color(0.75,0.76,0.78,1.0)
	if Collider is CSGShape3D and Collider.material:
		if "albedo_color" in Collider.material:
			BaseColor=Collider.material.albedo_color
	elif Collider is MeshInstance3D:
		var Mat=Collider.get_active_material(0)
		if Mat and "albedo_color" in Mat:
			BaseColor=Mat.albedo_color
	elif Collider is Node:
		for Child in Collider.get_children():
			if Child is MeshInstance3D:
				var Mat=Child.get_active_material(0)
				if Mat and "albedo_color" in Mat:
					BaseColor=Mat.albedo_color
					break
	return BaseColor

func ShowImpactEffect(HitPoint,HitPointNormal,Collider):
	if not impact_effect:
		return
	impact_effect.global_position = HitPoint
	if HitPointNormal.abs().is_equal_approx(Vector3.UP):
		impact_effect.look_at(HitPoint+HitPointNormal,Vector3.FORWARD)
	else:
		impact_effect.look_at(HitPoint+HitPointNormal,Vector3.UP)
	#darken surface color so it looks like bullet debris
	var SurfaceColor=GetObjectColor(Collider)
	var DarkDebris=SurfaceColor.darkened(0.38)
	var DarkerDust=SurfaceColor.darkened(0.55)
	impact_effect.color=DarkDebris
	var Grad=Gradient.new()
	Grad.offsets=PackedFloat32Array([0.0,0.7,1.0])
	Grad.colors=PackedColorArray([
		DarkDebris,
		DarkerDust,
		Color(DarkerDust.r,DarkerDust.g,DarkerDust.b,0.0)
	])
	impact_effect.color_ramp=Grad
	impact_effect.restart()
	impact_effect.emitting=true

func SpawnBulletDecal(HitPoint,HitPointNormal,Collider):
	var Decal=MeshInstance3D.new()
	var Quad=QuadMesh.new()
	var DecalSize=randf_range(0.09,0.13)
	Quad.size=Vector2(DecalSize,DecalSize)
	Decal.mesh=Quad
	Decal.material_override=BulletHoleMaterial
	Decal.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if Collider is Node3D:
		Collider.add_child(Decal)
	else:
		get_tree().current_scene.add_child(Decal)
	Decal.global_position=HitPoint+HitPointNormal*0.005
	if HitPointNormal.abs().is_equal_approx(Vector3.UP):
		Decal.look_at(Decal.global_position-HitPointNormal,Vector3.FORWARD)
	else:
		Decal.look_at(Decal.global_position-HitPointNormal,Vector3.UP)
	Decal.rotate_object_local(Vector3.FORWARD,randf()*TAU)
	ActiveDecals.append(Decal)
	if ActiveDecals.size()>MaxDecals:
		var OldestDecal=ActiveDecals.pop_front()
		if is_instance_valid(OldestDecal):
			OldestDecal.queue_free()

func SpawnBulletTracer(StartPosition,EndPosition):
	var Distance=StartPosition.distance_to(EndPosition)
	if Distance<0.5:
		return
	var Tracer=MeshInstance3D.new()
	var Box=BoxMesh.new()
	Box.size=Vector3(0.018,0.018,Distance)
	var Mat=StandardMaterial3D.new()
	Mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	Mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	Mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	Mat.albedo_color=Color(1.0,0.78,0.35,0.85)
	Box.material=Mat
	Tracer.mesh=Box
	Tracer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(Tracer)
	Tracer.global_position=(StartPosition+EndPosition)*0.5
	var TracerDirection=(EndPosition-StartPosition).normalized()
	if TracerDirection.abs().is_equal_approx(Vector3.UP):
		Tracer.look_at(EndPosition,Vector3.FORWARD)
	else:
		Tracer.look_at(EndPosition,Vector3.UP)
	var TracerTween=create_tween().set_parallel(true)
	TracerTween.tween_property(Mat,"albedo_color:a",0.0,0.06)
	TracerTween.tween_property(Tracer,"scale:x",0.1,0.06)
	TracerTween.tween_property(Tracer,"scale:y",0.1,0.06)
	TracerTween.chain().tween_callback(Tracer.queue_free)

func EquipWeapon(NewWeapon):
	#only equip guns if player has picked them up
	if NewWeapon==Weapon.Primary and not HasPrimary:
		return
	if NewWeapon==Weapon.Secondary and not HasSecondary:
		return
	if CurrentWeapon==NewWeapon:
		CurrentWeapon=Weapon.Melee
	else:
		CurrentWeapon=NewWeapon
	if CurrentWeapon==Weapon.Melee:
		IsAiming=false
	UpdateWeaponGeneration()

func UpdateWeaponGeneration():
	if pistol:
		pistol.visible=CurrentWeapon==Weapon.Secondary and HasSecondary
	if ak:
		ak.visible=CurrentWeapon==Weapon.Primary and HasPrimary

func _physics_process(delta: float) -> void:
	if CurrentState==PlayerState.Dead or CurrentState==PlayerState.InPlane:
		return
	var InputDirection=Input.get_vector("Left","Right","Up","Down")
	var Direction = (transform.basis*Vector3(InputDirection.x, 0, InputDirection.y)).normalized()
	Direction = Direction.rotated(Vector3.UP, sprint_arm_pivot.rotation.y)
	if CurrentState==PlayerState.SkyDiving or CurrentState==PlayerState.Parachuting:
		var HoriszontalSpeed= SkydiveHorizontalSpeed if CurrentState==PlayerState.SkyDiving else ParachuteHorizontalSpeed
		var TerminalVelocity = SkydiveTerminalVelocity if CurrentState==PlayerState.SkyDiving else ParachuteTerminalVelocity
		velocity.y= move_toward(velocity.y,TerminalVelocity, 25.0*delta)
		velocity.x= lerp(velocity.x, Direction.x * HoriszontalSpeed, 5.0*delta)
		velocity.z= lerp(velocity.z, Direction.z * HoriszontalSpeed, 5.0*delta)
		if Direction:
			armature.rotation.y = lerp_angle(armature.rotation.y, atan2(velocity.x, velocity.z), LerpValue)
		if CurrentState==PlayerState.SkyDiving:
			if Input.is_action_just_pressed("Jump") or global_position.y <= AutoParachuteHeight:
				OpenParachute()
		move_and_slide()
		if is_on_floor():
			CurrentState = PlayerState.Grounded
			parachute_mesh.visible= false
		return

	#Gravity and Fall Damage
	var WasOnFloor = is_on_floor()
	if not is_on_floor():
		velocity+= get_gravity()*delta
		FallSpeed = velocity.y

	if ShootCooldown>0.0:
		ShootCooldown-=delta
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		IsCrouching = false
		velocity.y= JumpVelocity

	#Crouch height
	var TargetScaleY = 0.7 if IsCrouching else 1.0
	armature.scale.y = lerp(armature.scale.y, TargetScaleY, 10.0*delta)

	#Movement
	var CurrentSpeed= CrouchSpeed if IsCrouching else (AimSpeed if IsAiming else (SprintSpeed if IsSprinting else WalkSpeed))
	if Direction:
		velocity.x = lerp(velocity.x,Direction.x*CurrentSpeed,LerpValue)
		velocity.z = lerp(velocity.z, Direction.z*CurrentSpeed,LerpValue)
		#rotate in direction of movement
		if CurrentWeapon==Weapon.Melee:
			armature.rotation.y = lerp_angle(armature.rotation.y,atan2(velocity.x,velocity.z),LerpValue)
	else:
		velocity.x = lerp(velocity.x, 0.0, LerpValue)
		velocity.z = lerp(velocity.z, 0.0, LerpValue)

	#Footstep sound
	if is_on_floor() and velocity.length()>1.5:
		FootstepTimer-=delta
		if FootstepTimer<=0.0:
			FootstepTimer= 0.3 if IsSprinting else 0.45
			if footstep_sound:
				footstep_sound.play()

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
	var IkTargetRifle= 1.0 if CurrentWeapon== Weapon.Primary else 0.0
	var IkTargetPistol= 1.0 if CurrentWeapon== Weapon.Secondary and (IsAiming or IsActionActive) else 0.0
	left_hand_ik.influence=lerpf(left_hand_ik.influence,IkTargetRifle,10.0*delta)
	left_hand_ik_pistol.influence=lerpf(left_hand_ik_pistol.influence,IkTargetPistol,10.0*delta)
	animation_tree.set("parameters/Blend2/blend_amount", GunBlend)

	UpdateHeadIK(delta)
	UpdateAnimations(delta,IsActionActive)
	UpdateCameraZoom(delta)
	UpdateAkTransform(delta,IsActionActive)
	animation_tree.set("parameters/BlendSpace1D/blend_position", velocity.length()/WalkSpeed)
	move_and_slide()

	#Apply fall damage when hitting ground at high speed
	if not WasOnFloor and is_on_floor():
		if FallSpeed < -12.0:
			TakeDamage((abs(FallSpeed)-12.0)*3.5)
		FallSpeed = 0.0

func GetCrosshairWorldTarget() -> Vector3:
	var CameraPosition = camera_3d.global_position
	var CameraForward= -camera_3d.global_transform.basis.z.normalized()
	if aim_ray:
		aim_ray.target_position = Vector3(0, 0, -GunRange)
		aim_ray.force_raycast_update()
		if aim_ray.is_colliding():
			var HitPoint= aim_ray.get_collision_point()
			# Ensure the hit point is actually in front of the player, not between camera & player back
			var ToHit = HitPoint-armature.global_position
			if ToHit.dot(CameraForward) > 1.0:
				return HitPoint
	# Reliable fallback: 100 units straight ahead of the camera
	return CameraPosition+CameraForward*GunRange

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
		Weapon.Secondary:
			if IsAiming:
				animation_tree.set("parameters/Transition/transition_request", "PistolAim")
			else:
				animation_tree.set("parameters/Transition/transition_request", "PistolLow")
			animation_tree.set("parameters/PistolBlend/blend_position", SpeedRatio)

func UpdateCameraZoom(Delta):
	if not camera_3d:
		return
	var TargetFov = 50.0 if IsAiming else (85.0 if IsSprinting else 75.0)
	var TargetSpringLength = 1.8 if IsAiming else 3.0
	camera_3d.fov=lerp(camera_3d.fov,TargetFov,10.0*Delta)
	spring_arm_3d.spring_length= lerp(spring_arm_3d.spring_length,TargetSpringLength,10.0*Delta)

func _on_skeleton_3d_skeleton_updated() -> void:
	if CurrentWeapon==Weapon.Melee or not skeleton_3d:
		return
	if not (IsAiming or animation_tree.get("parameters/ActionOneShot/active")):
		return
	var pitch= Quaternion(Vector3.RIGHT, -spring_arm_3d.rotation.x)
	# Right arm always follows the camera pitch; with the rifle, IK handles the left.
	var UpperArmBone = skeleton_3d.find_bone("UpperArm.r")
	skeleton_3d.set_bone_pose_rotation(UpperArmBone,pitch*skeleton_3d.get_bone_pose_rotation(UpperArmBone))

func StartSkydiving(DropPosition: Vector3) -> void:
	global_position = DropPosition
	visible = true
	CurrentState =PlayerState.SkyDiving
	EquipWeapon(Weapon.Melee)
	camera_3d.make_current()

func OpenParachute() -> void:
	if CurrentState == PlayerState.SkyDiving:
		CurrentState = PlayerState.Parachuting
		parachute_mesh.visible= true

func TakeDamage(Damage,Attacker=null) -> void:
	if CurrentState==PlayerState.Dead or CurrentState==PlayerState.InPlane:
		return
	if Armour>0:
		var DamageAbsorbed=min(Armour, Damage* 0.5)
		Armour-= DamageAbsorbed
		Damage-= DamageAbsorbed
	Health-= Damage
	UpdateHUD()
	if Health<=0:
		Health = 0
		Die()

func AddKill() -> void:
	Kills+=1
	UpdateHUD()

func CheckWinner() -> void:
	if CurrentState==PlayerState.Dead:
		return
	if get_tree().get_nodes_in_group("Enemies").size()==0:
		ShowEndScreen("WINNER WINNER CHICKEN DINNER!")

func Die() -> void:
	CurrentState = PlayerState.Dead
	ShowEndScreen("BETTER LUCK NEXT TIME!")

func ShowEndScreen(EndText: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	end_title_label.text = EndText
	$HUD/EndPanel.visible = true

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
