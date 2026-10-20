extends CharacterBody3D

enum EnemyFSM{Patrol,Chase,Attack,Loot}
var CurrentState= EnemyFSM.Attack
@export var MoveSpeed= 4.2
@export var DetectionRange = 45.0
@export var AttackRange = 28.0
@export var FireRate = 0.45
@export var Damage = 8.0
var Health = 100.0
var ShootTimer = 0.0
var PatrolTarget = Vector3.ZERO
var TargetNode = null
var TargetLoot= null
var HasGun =false

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var vision_ray: RayCast3D = $VisionRay
@onready var ak: Node3D = $Model/AK
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer

func _ready() -> void:
	add_to_group("Enemies")
	vision_ray.add_exception(self)
	#spawn with melee only
	AttackRange =2.2
	if ak:
		ak.visible= false
	CurrentState =EnemyFSM.Loot
	PickNewPatrolPoint()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity+=get_gravity() * delta

	FindTarget()
	if not HasGun:
		FindLoot()

	match CurrentState:
		EnemyFSM.Patrol:
			if global_position.distance_to(PatrolTarget)<2.5:
				PickNewPatrolPoint()
			MoveTowardPoint(PatrolTarget,delta)
			if not HasGun and is_instance_valid(TargetLoot):
				CurrentState =EnemyFSM.Loot
			elif is_instance_valid(TargetNode):
				CurrentState=EnemyFSM.Chase
		EnemyFSM.Loot:
			if HasGun or not is_instance_valid(TargetLoot):
				CurrentState= EnemyFSM.Patrol
				return
			MoveTowardPoint(TargetLoot.global_position,delta)
			if global_position.distance_to(TargetLoot.global_position)<2.0:
				PickupLoot(TargetLoot)
		EnemyFSM.Chase:
			if not is_instance_valid(TargetNode):
				CurrentState =EnemyFSM.Patrol
				return
			var Distance= global_position.distance_to(TargetNode.global_position)
			if Distance<=AttackRange and HasLineOfSight(TargetNode):
				CurrentState=EnemyFSM.Attack
			elif Distance>DetectionRange*1.3:
				TargetNode=null
				CurrentState=EnemyFSM.Patrol
			else:
				MoveTowardPoint(TargetNode.global_position,delta)
		EnemyFSM.Attack:
			if not is_instance_valid(TargetNode):
				CurrentState=EnemyFSM.Patrol
				return
			var Distance= global_position.distance_to(TargetNode.global_position)
			if Distance>AttackRange or not HasLineOfSight(TargetNode):
				CurrentState=EnemyFSM.Chase
				return
			velocity.x= move_toward(velocity.x, 0,MoveSpeed)
			velocity.z = move_toward(velocity.z, 0,MoveSpeed)
			FacePoint(TargetNode.global_position,delta)
			ShootTimer-= delta
			if ShootTimer<= 0.0:
				ShootTimer= FireRate
				ShootAtTarget()

	if animation_player:
		if velocity.length()>0.5:
			animation_player.play("RifleRun" if HasGun else "Run")
		else:
			animation_player.play("RifleAim" if HasGun else "Idle")
	move_and_slide()

func MoveTowardPoint(Destination,Delta):
	navigation_agent_3d.target_position = Destination
	var NextPosition = navigation_agent_3d.get_next_path_position()
	var Direction= (NextPosition-global_position)
	Direction.y = 0
	if Direction.length() > 0.1:
		Direction = Direction.normalized()
		velocity.x = Direction.x*MoveSpeed
		velocity.z =Direction.z*MoveSpeed
		FacePoint(global_position+Direction,Delta)

func FacePoint(Point,Delta):
	var FaceToPoint = Point-global_position
	var TargetYaw= atan2(-FaceToPoint.x, -FaceToPoint.z)
	rotation.y = lerp_angle(rotation.y,TargetYaw, 10.0*Delta)

func FindLoot():
	var ClosestDist= 80.0
	TargetLoot =null
	for Item in get_tree().get_nodes_in_group("Loot"):
		if is_instance_valid(Item) and (Item.ItemType=="AK" or Item.ItemType=="Pistol"):
			var Dist =global_position.distance_to(Item.global_position)
			if Dist<ClosestDist:
				ClosestDist= Dist
				TargetLoot = Item

func PickupLoot(Item):
	if not is_instance_valid(Item):
		return
	if Item.ItemType=="AK" or Item.ItemType=="Pistol":
		HasGun= true
		AttackRange = 28.0
		if ak:
			ak.visible =true
		Item.queue_free()
		CurrentState= EnemyFSM.Patrol

func FindTarget():
	var Player = get_tree().get_first_node_in_group("Player")
	if Player and Player.CurrentState==Player.PlayerState.Grounded:
		if global_position.distance_to(Player.global_position)<=DetectionRange:
			TargetNode =Player
			return
	#target other enemy bots aswell
	for Bot in get_tree().get_nodes_in_group("Enemies"):
		if Bot!=self and is_instance_valid(Bot):
			if global_position.distance_to(Bot.global_position)<=DetectionRange:
				TargetNode= Bot
				return

func HasLineOfSight(Target):
	vision_ray.look_at(Target.global_position+Vector3(0, 1.0, 0),Vector3.UP)
	vision_ray.force_raycast_update()
	return vision_ray.is_colliding() and vision_ray.get_collider()==Target

func ShootAtTarget():
	if not is_instance_valid(TargetNode):
		return
	# Apply realistic bot accuracy (70% hit chance)
	var HitPosition = TargetNode.global_position+Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6))
	if randf()<=0.70 and TargetNode.has_method("TakeDamage"):
		TargetNode.TakeDamage(Damage)

	var Player= get_tree().get_first_node_in_group("Player")
	if Player and Player.has_method("SpawnBulletTracer"):
		Player.SpawnBulletTracer(global_position + Vector3(0, 1.4, 0), HitPosition)

func PickNewPatrolPoint():
	PatrolTarget= Vector3(randf_range(-70.0, 70.0), 1.0, randf_range(-70.0, 70.0))

func TakeDamage(Damage):
	Health-=Damage
	if Health <= 0.0:
		Die()

func Die() -> void:
	var LootScene = load("res://Scenes/loot_item.tscn")
	if LootScene:
		var Drop= LootScene.instantiate()
		get_tree().current_scene.add_child(Drop)
		Drop.global_position= global_position + Vector3(0, 0.5, 0)
	var Player =get_tree().get_first_node_in_group("Player")
	if Player and Player.has_method("CheckWinner"):
		Player.CheckWinner()
	queue_free()
