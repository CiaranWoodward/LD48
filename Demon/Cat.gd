extends "res://Enemies/SimpleEnemy.gd"#Shhh
class_name Cat

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	._ready()

func _is_attack_possible(pos : Vector2) -> bool:
	return false

func _attack():
	pass
