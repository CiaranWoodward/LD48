extends Camera2D

export var top_left = Vector2.ZERO
export var speed = 5

var follow_target = null
var target_position = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _bound_camera() -> void:
	if global_position.x < top_left.x:
		global_position.x = top_left.x
	if global_position.y < top_left.y:
		global_position.y = top_left.y

func _physics_process(delta: float) -> void:
	if is_instance_valid(follow_target):
		target_position = follow_target.global_position
		if follow_target.has_method("GetCameraOffset"):
			target_position = target_position + follow_target.GetCameraOffset()
	
	var dir = global_position.direction_to(target_position)
	var dist = global_position.distance_to(target_position)
	global_position = global_position + dir * dist * delta * speed
