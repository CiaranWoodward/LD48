extends KinematicBody2D

export var my_type = "simpleton"

export var max_fallspeed = 300.0
export var max_jumpspeed = 300.0
export var max_speed = 300.0
export var max_jumpheight = 300.0
export var max_fallheight = 300.0
export var min_speed = 100.0
export var stop_dist = 30.0
export var min_x_jump = 30.0
export var min_jump_time = 0.2
export var jump_y_overshoot = 30.0
export var gravity_time = 0.5
export var myheight = 32

export var pathing_random_factor = 5.0

# Attack system properties
export var health = 20
export var pushback_multiplier = 1.0
export var pushback_time = 0.2

#animation properties between 0 and 1
export var speed_rate = 0.0

onready var animTree = $AnimationTree
onready var stateMachine : AnimationNodeStateMachinePlayback = animTree["parameters/StateMachine/playback"]

var jumpTween = Tween.new()
var fallTween = Tween.new()
var pushbackTween = Tween.new()
var fall_rate = 0.0

var accel_transition = Tween.TRANS_LINEAR
var accel_ease = Tween.EASE_OUT

# pathing
var _path = []
var _final_destination = Vector2.ZERO
# moving
var _cur_plat = null # Platform that the current dst point is on
var _cur_point = null # Current destination point we are moving towards
var _cur_after_point = null # When we get to that point, where are we trying to go?
var _direction = 0

# Cached
var _slowdown_time
var max_jump_up_time

# current status
enum state {IDLE, GOING_TO_TREASURE, GOING_TO_PLAYER, FIGHTING, DEAD}
var _on_floor = false
var _platform = null
var _jumping = false
var _dead = false
var _pushback = Vector2.ZERO
var fall_time = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	stateMachine.start("Idle")
	_slowdown_time = $AnimationPlayer.get_animation("SlowDown").length
	max_jump_up_time = max_jumpheight / max_jumpspeed
	jumpTween = Tween.new()
	fallTween = Tween.new()
	pushbackTween = Tween.new()
	add_child(jumpTween)
	add_child(fallTween)
	add_child(pushbackTween)
	jumpTween.connect("tween_completed", self, "_on_Tween_tween_completed")
	fallTween.playback_process_mode = Tween.TWEEN_PROCESS_PHYSICS
	jumpTween.playback_process_mode = Tween.TWEEN_PROCESS_PHYSICS
	pushbackTween.playback_process_mode = Tween.TWEEN_PROCESS_PHYSICS

# Actually execute and move the character
func _handle_movement(delta):
	var speed = _direction * speed_rate * (max_speed-min_speed) + _direction * min_speed
	var kc = move_and_collide(Vector2(speed + _pushback.x, fall_rate * max_fallspeed + _pushback.y) * delta)
	if is_instance_valid(kc):
		if kc.normal.y < -0.5:
			_on_floor = true
			stop_pushback()

func _handle_falling(delta):
	if _on_floor:
		fallTween.remove_all()
		fall_rate = 0
		if stateMachine.get_current_node() == "Falling":
			_travel_animation("Idle")
			_platform = get_parent().GetClosestLowerPlatform(global_position)
	elif _pushback.y != 0:
		pass # We're beign pushed back
	else:
		_travel_animation("Falling")
		if fall_rate == 0:
			fall_rate = 0.01
			fallTween.interpolate_property(self, "fall_rate", null, 1, gravity_time, Tween.TRANS_SINE, Tween.EASE_OUT)
			fallTween.start()

func stop_pushback():
	if _pushback != Vector2.ZERO:
		pushbackTween.remove_all()
		_pushback = Vector2.ZERO

func start_pushback(pushback : Vector2):
	_jumping = false
	_on_floor = false
	_platform = null
	_pushback = pushback * pushback_multiplier
	pushbackTween.remove_all()
	pushbackTween.interpolate_property(self, "_pushback", null, Vector2.ZERO, pushback_time, Tween.TRANS_EXPO, Tween.EASE_IN)
	pushbackTween.interpolate_callback(self, pushback_time, "stop_pushback")
	pushbackTween.start()

func is_pushedback() -> bool:
	return _pushback != Vector2.ZERO

func take_damage(damage, pushback):
	health -= damage
	fallTween.remove_all()
	jumpTween.remove_all()
	stateMachine.start("Hit")
	start_pushback(pushback)
	if health <= 0:
		_travel_animation("Die")
		_dead = true

func _actually_die():
	self.queue_free()

func _configure_next_point():
	if is_instance_valid(_platform) && (_platform in _path) && (_platform != _cur_plat):
		var pindex = _path.find(_platform)
		if pindex == _path.size() - 1:
			# This point is final destination
			# TODO: This code can't be reached
			_cur_plat = _platform
			_cur_point = _final_destination
			_cur_after_point = _final_destination
			return
		var next_plat = _path[pindex + 1]
		var list = get_parent().GetNavMeshForType(my_type)[_platform]
		# Get all potential paths to next platform
		var potentials = []
		for elem in list:
			if elem["other"] == next_plat:
				potentials.append(elem)
		if potentials.size() == 0:
			_path = []
		# Randomly choose any path to the next platform
		var target_path = potentials[randi() % potentials.size()]
		_cur_plat = _platform
		_cur_point = target_path["src"]
		_cur_after_point = target_path["dst"]

func _handle_idle(_delta):
	if _on_floor:
		var cn = stateMachine.get_current_node()
		if cn == "Idle":
			if _path.size() == 0 || !(_platform in _path):
				# Go to treasure
				_repath_to(get_parent().GetTreasurePlatform())
				_final_destination = get_parent().GetTreasureLocation()
			_configure_next_point()

func _end_jump():
	_jumping = false
	_on_floor = false
	_platform = null
	jumpTween.remove_all()
	_travel_animation("Falling")

func _mid_jump():
	_travel_animation("JumpDown")

func _travel_animation(dest : String):
	if !_dead:
		stateMachine.travel(dest)

func _on_Tween_tween_completed(object, key):
	if object != self:
		return
	if key == ":global_position:x":
		_end_jump()
	if key == ":global_position:y" && _jumping:
		_mid_jump()
		jumpTween.interpolate_property(self, "global_position:y", null, _cur_after_point.y, fall_time, Tween.TRANS_CIRC, Tween.EASE_IN)
		jumpTween.start()

func _reached_point(_delta):
	if  _cur_after_point != _cur_point:
		# We jumping
		_cur_after_point.y = _cur_after_point.y - myheight
		var diff = _cur_after_point - global_position
		var jump_height = -jump_y_overshoot + min(0, diff.y) # Maximum jump height relative to start position (negative is higher)
		var fall_height = jump_height - max(0, diff.y) # Maximum fall height between peak of jump and the end position (negative is higher)
		fall_time = max(0, -fall_height/max_fallspeed)
		var rise_time = -jump_height/max_jumpspeed
		var jump_time = max(rise_time + fall_time, diff.x/max_speed)
		
		# Make an arc
		if jump_time > (rise_time + fall_time):
			rise_time = jump_time * (rise_time/(rise_time + fall_time))
			fall_time = jump_time * (fall_time/(rise_time + fall_time))
		
		var midpoint_ypos = global_position.y + jump_height
		jumpTween.interpolate_property(self, "global_position:x", global_position.x, _cur_after_point.x, jump_time, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		jumpTween.interpolate_property(self, "global_position:y", global_position.y, midpoint_ypos, rise_time, Tween.TRANS_CIRC, Tween.EASE_OUT)
		jumpTween.start()
		_travel_animation("JumpUp")
		_jumping = true
		_cur_plat = null
		_cur_point = null

func _set_visual_facing_dir(direction):
	if direction == 0:
		return
	var flipper = get_node_or_null("Flipper")
	if is_instance_valid(flipper):
		flipper.scale.x = direction

func _walk_to_point(delta, point : Vector2):
	var vec = point - self.global_position
	var dir = vec.normalized()
	if dir.x > 0:
		_direction = 1
	else:
		_direction = -1
	if abs(vec.x) > _slowdown_time * max_speed:
		_travel_animation("Walking")
	elif abs(vec.x) < stop_dist:
		_direction = 0
		_travel_animation("Idle")
		_reached_point(delta)
	else:
		_travel_animation("SlowWalking")
	_set_visual_facing_dir(_direction)

func _handle_travel(delta):
	_direction = 0
	if _on_floor && !_dead:
		if is_instance_valid(_platform):
			if _platform == _cur_plat:
				_walk_to_point(delta, _cur_point)
	
func _physics_process(delta):
	if is_nan(global_position.x):
		print("Help!")
	if !_jumping:
		_handle_movement(delta)
		_handle_falling(delta)
		_handle_idle(delta)
		_handle_travel(delta)

func _is_jump_possible(from : Vector2, to : Vector2) -> bool:
	var heightincrease = from.y - to.y # This is backwards because y is inverted!
	var xdist = abs(from.x - to.x)
	var time_required = xdist/max_speed
	var time_fromheight
	
	if heightincrease < 0:
		var maxFall = min(max_fallheight, max_jumpheight - heightincrease)
		time_fromheight = max_jump_up_time + maxFall/max_fallspeed
	else:
		time_fromheight = max_jump_up_time + (max_jumpheight-heightincrease)/max_fallspeed
	
	# Too high
	if heightincrease > max_jumpheight:
		return false
	# Too low
	if heightincrease < -max_fallheight:
		return false
	# Too far
	if time_required > time_fromheight:
		return false
	return true

func _create_typed_navmap():
	var map = get_parent().GetNavMeshCopy()
	for plat in map.keys():
		var rmlist = []
		for entry in map[plat]:
			if !_is_jump_possible(entry["src"], entry["dst"]):
				rmlist.append(entry)
		for val in rmlist:
			map[plat].erase(val)
	get_parent().SetNavMeshForType(my_type, map, pathing_random_factor)

# Find a path to the destination
func _repath_to(dest_platform):
	if !is_instance_valid(_platform):
		_platform = get_parent().GetClosestLowerPlatform(self.global_position)
	if !is_instance_valid(_platform):
		return
	
	var astar = get_parent().GetAstarForType(my_type)
	if astar == null:
		_create_typed_navmap()
		astar = get_parent().GetAstarForType(my_type)
	_path = astar.get_path(_platform, dest_platform)
	get_parent()._drawPath(_path)

func _repath_to_loc(gpos : Vector2):
	var dest_platform = get_parent().GetClosestPlatform(gpos)
	_repath_to(dest_platform)
