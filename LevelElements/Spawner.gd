extends Node2D

export(PackedScene) var to_spawn : PackedScene
export var period = 5.0
export var count = 3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Timer.start(period)
	get_parent().enemy_count += count

func _on_Timer_timeout() -> void:
	if count > 0:
		count = count - 1
		var new = to_spawn.instance()
		get_parent().add_child(new)
		new.global_position = global_position
		$Timer.start()
