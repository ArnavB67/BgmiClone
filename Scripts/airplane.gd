extends Node3D
@onready var camera_3d: Camera3D = $Camera3D
@export var FlightSpeed= 12.0
@export var EnemyScene: PackedScene
@export var NoOfBots = 10

var Player: CharacterBody3D
var IsPlayerInPlane = true
var BotDropTimer: float = 0.0

func _ready() -> void:
	global_position = Vector3(0, 85, -140)
	camera_3d.look_at_from_position(global_position+camera_3d.position, global_position+Vector3(0, -30, 20), Vector3.UP)
	await get_tree().process_frame
	Player = get_tree().get_first_node_in_group("Player")
	if Player:
		Player.CurrentState= Player.PlayerState.InPlane
		Player.visible = false
		camera_3d.make_current()

func _process(delta: float) -> void:
	global_position.z+=FlightSpeed*delta
	if IsPlayerInPlane and Player:
		Player.global_position= global_position+Vector3(0, -3, 0)
		if Input.is_action_just_pressed("Interact") or global_position.z >= 120.0:
			EjectPlayer()
	#Drop Enemy Bots
	if NoOfBots>0 and global_position.z>-110.0 and global_position.z<110.0:
		BotDropTimer-=delta
		if BotDropTimer<=0.0:
			BotDropTimer=randf_range(0.6, 1.2)
			DropBot()
	if global_position.z>180.0:
		queue_free()

func EjectPlayer() -> void:
	IsPlayerInPlane= false
	Player.StartSkydiving(global_position+Vector3(0, -4, 0))

func DropBot() -> void:
	if not EnemyScene:
		return
	NoOfBots-= 1
	var Bot= EnemyScene.instantiate()
	get_tree().current_scene.add_child(Bot)
	Bot.global_position = Vector3(global_position.x+randf_range(-60.0, 60.0),1.5,global_position.z+randf_range(-25.0, 25.0))
