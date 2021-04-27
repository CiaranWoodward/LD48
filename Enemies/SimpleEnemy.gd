extends KinematicBody2D

export var my_type = "simpleton"

export var max_fallspeed = 300.0
export var max_jumpspeed = 300.0
export var max_speed = 300.0
export var max_jumpheight = 300.0
export var max_fallheight = 300.0
export var min_speed = 100.0
export var stop_dist = 40.0
export var min_x_jump = 30.0
export var min_jump_time = 0.2
export var jump_y_overshoot = 30.0
export var gravity_time = 0.5
export var myheight = 32
export var player_escape_distance = 1000.0
export var player_aggro_distance = 400.0

export var pathing_random_factor = 5.0

# Attack system properties
export var health = 20
export var pushback_multiplier = 1.0
export var pushback_time = 0.2
export var damage = 10
export var attack_range = 80
export var attack_period = 1.5
export var pushback_amount = 100

#animation properties between 0 and 1
export var speed_rate = 0.0

onready var animTree = $AnimationTree
onready var stateMachine : AnimationNodeStateMachinePlayback = animTree["parameters/StateMachine/playback"]

onready var jumpTween = Tween.new()
onready var fallTween = Tween.new()
onready var pushbackTween = Tween.new()
onready var attackTimer = Timer.new()
var fall_rate = 0.0

var accel_transition = Tween.TRANS_LINEAR
var accel_ease = Tween.EASE_OUT

# pathing
var _path = []
var _final_destination = Vector2.ZERO
# moving
var _cur_plat = null # Platform that the current dst point is on
var _cur_point = Vector2.INF # Current destination point we are moving towards
var _cur_after_point = Vector2.INF # When we get to that point, where are we trying to go?
var _direction = 0

# Cached
var _slowdown_time
var max_jump_up_time
var player = null

# current status
enum higher_purpose {TREASURE, KILL, STUCK}
var _higher_purpose = higher_purpose.TREASURE
var _on_floor = false
var _platform = null
var _jumping = false
var _grappled = false
var _dead = false
var _pushback = Vector2.ZERO
var _current_animation = ""
var fall_time = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	animTree.active = true
	_force_animation("Idle")
	_slowdown_time = $AnimationPlayer.get_animation("SlowDown").length
	max_jump_up_time = max_jumpheight / max_jumpspeed
	add_child(jumpTween)
	add_child(fallTween)
	add_child(pushbackTween)
	add_child(attackTimer)
	jumpTween.connect("tween_completed", self, "_on_Tween_tween_completed")
	fallTween.playback_process_mode = Tween.TWEEN_PROCESS_PHYSICS
	jumpTween.playback_process_mode = Tween.TWEEN_PROCESS_PHYSICS
	pushbackTween.playback_process_mode = Tween.TWEEN_PROCESS_PHYSICS
	attackTimer.one_shot = true
	attackTimer.wait_time = attack_period

func SetPlayerReference(p):
	self.player = p

func _is_player_in_sight() -> bool:
	if is_instance_valid(player):
		var space_state = get_world_2d().direct_space_state
		var res = space_state.intersect_ray(global_position, player.global_position, [], 1)
		return res.empty()
	return false

func _is_player_in_aggro_distance() -> bool:
	if is_instance_valid(player):
		return global_position.distance_to(player.global_position) < player_aggro_distance
	return false

func _is_player_escaped() -> bool:
	if is_instance_valid(player):
		return global_position.distance_to(player.global_position) > player_escape_distance
	return false

func _is_player_in_attack_range() -> bool:
	if is_instance_valid(player):
		return global_position.distance_to(player.global_position) < attack_range
	return false

func _is_path_valid() -> bool:
	return !(_path.size() == 0 || !(_platform in _path))

func _is_path_completed() -> bool:
	assert(_is_path_valid())
	assert(is_instance_valid(_platform))
	var pindex = _path.find(_platform)
	if pindex == _path.size() - 1:
		return true
	return false

func _get_last_player_plat():
	if is_instance_valid(player) && is_instance_valid(player.last_platform):
		return player.last_platform
	return null

func _clear_path():
	_path = []
	_cur_plat = null
	_cur_point = Vector2.INF

func _run_attackanim():
	if _dead:
		return
	_force_animation("Attack")
	print("Attak")

func _is_attack_possible(_position : Vector2) -> bool:
	return global_position.distance_to(player.global_position) < attack_range

func _attack():
	if !_dead && is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist < attack_range:
			var dir = sign(global_position.direction_to(player.global_position).x)
			player.take_damage(damage, Vector2(dir * pushback_amount, 0))

func _relogic_if_necessary(_delta):
	# Higher purpose logic
	if _higher_purpose == higher_purpose.TREASURE:
		if _is_player_in_aggro_distance():
			_higher_purpose = higher_purpose.KILL
			_clear_path()
			print("aggro attack!")
		elif !_is_player_escaped() && _is_player_in_sight():
			_higher_purpose = higher_purpose.KILL
			_clear_path()
			print("sight attack!")
	elif _higher_purpose == higher_purpose.KILL:
		if _is_player_escaped():
			_higher_purpose = higher_purpose.TREASURE
			_clear_path()
			print("escaped hunt!")
	if !_on_floor:
		return
	# Middle Management
	if _higher_purpose == higher_purpose.TREASURE:
		if !_is_path_valid():
			_repath_to(get_parent().GetTreasurePlatform())
			_final_destination = get_parent().GetTreasureLocation()
	elif _higher_purpose == higher_purpose.KILL:
		var target_plat = _get_last_player_plat()
		if is_instance_valid(target_plat):
			if _platform == target_plat:
				_final_destination = player.global_position
			elif !_is_path_valid() || _path[-1] != target_plat:
				_repath_to(target_plat)
				_final_destination = player.global_position
		if attackTimer.is_stopped() && _is_attack_possible(player.global_position):
			attackTimer.start()
			call_deferred("_run_attackanim")
	
	if _is_path_valid():
		if _is_path_completed():
			_cur_plat = _platform
			_cur_point = _final_destination
			_cur_after_point = _final_destination
		else:
			_configure_next_point()

func _grapple_if_possible(_source) -> bool:
	_grappled = true
	fallTween.stop_all()
	jumpTween.stop_all()
	return true

func _grapple_done():
	_grappled = false
	_end_jump()

# Actually execute and move the character
func _handle_movement(delta):
	var speed = _direction * speed_rate * (max_speed-min_speed) + _direction * min_speed
	var kc = move_and_collide(Vector2(speed + _pushback.x, fall_rate * max_fallspeed + _pushback.y) * delta)
	if is_instance_valid(kc):
		if kc.normal.y < -0.5:
			_on_floor = true
			_platform = get_parent().GetClosestLowerPlatform(global_position)
			stop_pushback()

# Handle gravity timing
func _handle_falling(delta):
	if _on_floor:
		fallTween.remove_all()
		fall_rate = 0
		if _current_animation == "Falling":
			_travel_animation("Idle")
			_platform = get_parent().GetClosestLowerPlatform(global_position)
	elif _pushback.y != 0:
		pass # We're being pushed back
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
	if _dead:
		return
	health -= damage
	fallTween.remove_all()
	jumpTween.remove_all()
	_force_animation("Hit")
	start_pushback(pushback)
	if health <= 0:
		_travel_animation("Die")
		_dead = true

func _actually_die():
	print("freeing enemy...")
	get_parent().enemy_count -= 1
	self.queue_free()

func _configure_next_point():
	if is_instance_valid(_platform) && (_platform in _path) && (_platform != _cur_plat):
		var pindex = _path.find(_platform)
		if pindex == _path.size() - 1:
			# This point is final destination
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

func _end_jump():
	_jumping = false
	_on_floor = false
	_platform = null
	jumpTween.remove_all()
	_travel_animation("Falling")

func _mid_jump():
	_travel_animation("JumpDown")

func _force_animation(dest : String):
	_current_animation = dest
	stateMachine.start(dest)

func _travel_animation(dest : String):
	if !_dead && dest != _current_animation:
		_current_animation = dest
		stateMachine.travel(dest)
		#call_deferred("_deferred_travel", dest)

func _deferred_travel(dest):
	print(dest)
	if !_dead || dest == "Die":
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
	if  _cur_after_point != _cur_point && _cur_point != Vector2.INF && _cur_after_point != Vector2.INF:
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
		_on_floor = false
		_cur_plat = null
		_cur_point = Vector2.INF

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
	if _on_floor && !_dead && _cur_point != Vector2.INF:
		_walk_to_point(delta, _cur_point)
		if _on_floor && _direction == 0 && _is_path_valid() && !_is_path_completed():
			_clear_path()
	
func _physics_process(delta):
	if is_nan(global_position.x):
		print("Help!")
	if !_jumping && !_grappled:
		_handle_movement(delta)
		_handle_falling(delta)
		_relogic_if_necessary(delta)
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
	
	print("Repathing")
	var astar = get_parent().GetAstarForType(my_type)
	if astar == null:
		_create_typed_navmap()
		astar = get_parent().GetAstarForType(my_type)
	_path = astar.get_path(_platform, dest_platform)
	get_parent()._drawPath(_path)

func _repath_to_loc(gpos : Vector2):
	var dest_platform = get_parent().GetClosestPlatform(gpos)
	_repath_to(dest_platform)
