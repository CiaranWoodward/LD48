extends Node2D

export var max_hits = 4

var cur_hits = max_hits

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_Shrine_body_entered(body: Node) -> void:
	if body.has_method("_actually_die"):
		body._actually_die()
		cur_hits-=1
		get_parent().SetShrineHealthProp(float(cur_hits)/max_hits)
		$Audio.play()
