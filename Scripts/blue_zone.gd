extends Node3D

@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D

var CurrentRadius: float = 160.0
var TargetRadius: float = 25.0
var ShrinkDuration: float = 120.0
var DamagePerSecond: float = 5.0
var DamageTick: float = 0.0

func _ready() -> void:
	mesh_instance_3d.mesh.top_radius = CurrentRadius
	mesh_instance_3d.mesh.bottom_radius = CurrentRadius

	var RadiusTween = create_tween()
	RadiusTween.tween_property(self, "CurrentRadius",TargetRadius,ShrinkDuration)

func _process(delta: float) -> void:
	mesh_instance_3d.mesh.top_radius =CurrentRadius
	mesh_instance_3d.mesh.bottom_radius=CurrentRadius
	DamageTick+=delta
	if DamageTick>= 1.0:
		DamageTick= 0.0
		CheckZoneDamage()

func CheckZoneDamage() -> void:
	var Player=get_tree().get_first_node_in_group("Player")
	if Player and Player.CurrentState==Player.PlayerState.Grounded:
		var Distance = Vector2(Player.global_position.x,Player.global_position.z).length()
		if Distance>CurrentRadius:
			Player.TakeDamage(DamagePerSecond)
			if Player.zone_label:
				Player.zone_label.text = "OUTSIDE SAFE ZONE! TAKING DAMAGE!"
		elif Player.zone_label:
			Player.zone_label.text = "SAFE ZONE RADIUS: %dm" % int(CurrentRadius)

	for Bot in get_tree().get_nodes_in_group("Enemies"):
		var Distance= Vector2(Bot.global_position.x,Bot.global_position.z).length()
		if Distance>CurrentRadius:
			Bot.TakeDamage(DamagePerSecond)
