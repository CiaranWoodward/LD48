extends "res://Enemies/SimpleEnemy.gd"
class_name Ninja

export var knife_speed = 500.0

var knifeScene = preload("res://Enemies/Knife.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	._ready()

func _is_attack_possible(pos : Vector2) -> bool:
	if global_position.distance_to(pos) > attack_range:
		return false
	var space_state = get_world_2d().direct_space_state
	var res = space_state.intersect_ray(global_position, pos, [], 1)
	return res.empty()

func _attack():
	if !_dead && is_instance_valid(player):
		var newKnife = knifeScene.instance()
		var dir = global_position.direction_to(player.global_position)
		get_parent().add_child(newKnife)
		newKnife.global_position = global_position
		newKnife.velocity = dir * knife_speed
		newKnife.damage = damage
