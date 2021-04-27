extends Area2D

export var max_hits = 4

var cur_hits = max_hits

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !get_parent().has_method("SetShrineHealthProp"):
		self.collision_mask = 0
		monitoring = false

func _on_Shrine_body_entered(body: Node) -> void:
	if body.has_method("_actually_die") && !body._dead:
		body._actually_die()
		cur_hits-=1
		if cur_hits < 0:
			cur_hits = 0
		get_parent().SetShrineHealthProp(float(cur_hits)/max_hits)
		$Audio.play()
		$Shrine/Gold.frame = cur_hits
