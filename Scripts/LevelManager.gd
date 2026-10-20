# res://Scripts/level_manager.gd
extends Node3D

@export var LootScene: PackedScene = preload("res://Scenes/loot_item.tscn")
@export var TotalLootSpawns = 45
const LootTypes = ["AK", "Pistol", "RifleAmmo", "PistolAmmo", "Medkit", "Armour"]

func _ready() -> void:
	SpawnMapLoot()

func SpawnMapLoot() -> void:
	if not LootScene:
		return
	for i in range(TotalLootSpawns):
		var Drop = LootScene.instantiate()
		Drop.ItemType = LootTypes[randi() % LootTypes.size()]
		add_child(Drop)
		Drop.global_position = Vector3(randf_range(-95.0, 95.0), 0.75, randf_range(-95.0, 95.0))
