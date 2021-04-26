extends Camera2D

export var top_left = Vector2.ZERO
export var speed = 5
export var lookahead_speed = 4
export var ahead_distance = 150

var follow_target = null
var target_position = Vector2.ZERO

var _prev_lookahead_direction = 0.0
var _max_lookahead_component_this_direction = 0.0
var _max_lookahead_x_this_dir = 0.0
var _prev_lookahead_vec = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _bound_camera() -> void:
	if global_position.x < top_left.x:
		global_position.x = top_left.x
	if global_position.y < top_left.y:
		global_position.y = top_left.y

func _update_lookahead(delta: float) -> Vector2:
	if follow_target.has_method("GetXcomponent"):
		var cur_dir = sign(follow_target.GetXcomponent())
		var cur_look_cmp = follow_target.speed_proportion
		if cur_dir == 0:
			cur_dir = _prev_lookahead_direction
		if cur_dir != _prev_lookahead_direction:
			_max_lookahead_component_this_direction = cur_look_cmp
			_max_lookahead_x_this_dir = abs(follow_target.GetXcomponent())
		else:
			_max_lookahead_component_this_direction = max(cur_look_cmp, _max_lookahead_component_this_direction)
			_max_lookahead_x_this_dir = max(abs(_max_lookahead_x_this_dir), abs(follow_target.GetXcomponent()))
			cur_look_cmp = _max_lookahead_component_this_direction
		_prev_lookahead_direction = cur_dir
		
		var target = Vector2(cur_dir * _max_lookahead_x_this_dir * cur_look_cmp * ahead_distance, 0)
		var current = _prev_lookahead_vec
		var dir = current.direction_to(target)
		var dist = current.distance_to(target)
		var rval = current + dir * dist * delta * lookahead_speed
		_prev_lookahead_vec = rval
		return rval
	return Vector2.ZERO

func _physics_process(delta: float) -> void:
	if is_instance_valid(follow_target):
		target_position = follow_target.global_position
		target_position = target_position + _update_lookahead(delta)
		if follow_target.has_method("GetCameraOffset"):
			target_position = target_position + follow_target.GetCameraOffset()
	
	var dir = global_position.direction_to(target_position)
	var dist = global_position.distance_to(target_position)
	global_position = global_position + dir * dist * delta * speed
