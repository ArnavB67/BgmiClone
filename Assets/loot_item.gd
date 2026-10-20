extends Area3D

@export var ItemType =""
var Items= ["AK","Pistol","RifleAmmo","PistolAmmo","Medkit","Armour"]

func _ready() -> void:
	add_to_group("Loot")
	if ItemType=="":
		ItemType = Items.pick_random()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		body.NearbyLoot.append(self)
	elif body.is_in_group("Enemies") and body.has_method("PickupLoot"):
		body.PickupLoot(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		body.NearbyLoot.erase(self)
