extends KinematicBody2D

const MY_TYPE = "simpleton"

export var max_fallspeed = 700
export var max_speed = 300
export var max_jumpheight = 300
export var max_fallheight = 300
export var min_speed = 50

export var max_jump_up_time = 0.7

export var pathing_random_factor = 5.0

#animation properties between 0 and 1
export var fall_rate = 0.0
export var speed_rate = 0.0

onready var animTree = $AnimationTree
onready var stateMachine : AnimationNodeStateMachinePlayback = animTree["parameters/StateMachine/playback"]

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
var _slowdown_time

# current status
var _on_floor = false
var _platform = null

# Called when the node enters the scene tree for the first time.
func _ready():
	stateMachine.start("Idle")
	_slowdown_time = $AnimationPlayer.get_animation("SlowDown").length
	$Tween.start()

func _handle_movement(delta):
	var speed = _direction * speed_rate * (max_speed-min_speed) + _direction * min_speed
	var kc = move_and_collide(Vector2(speed, fall_rate * max_fallspeed) * delta)
	if is_instance_valid(kc):
		if kc.normal.y < -0.5:
			_on_floor = true

func _handle_falling(delta):
	if _on_floor:
		fall_rate = 0
		if stateMachine.get_current_node() == "Falling":
			stateMachine.travel("Idle")
			_platform = get_parent().GetClosestLowerPlatform(global_position)
	else:
		stateMachine.travel("Falling")

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
		var list = get_parent().GetNavMeshForType(MY_TYPE)[_platform]
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

func _walk_to_point(_delta, point :Vector2):
	var vec = point - self.global_position
	var dir = vec.normalized()
	if dir.x > 0:
		_direction = 1
	else:
		_direction = -1
	if abs(vec.x) > _slowdown_time * max_speed:
		stateMachine.travel("Walking")
	else:
		stateMachine.travel("SlowWalking")

func _handle_travel(delta):
	_direction = 0
	if _on_floor:
		if is_instance_valid(_platform):
			if _platform == _cur_plat:
				_walk_to_point(delta, _cur_point)
	
func _physics_process(delta):
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
	get_parent().SetNavMeshForType(MY_TYPE, map, pathing_random_factor)

# Find a path to the destination
func _repath_to(dest_platform):
	if !is_instance_valid(_platform):
		_platform = get_parent().GetClosestLowerPlatform(self.global_position)
	
	var astar = get_parent().GetAstarForType(MY_TYPE)
	if astar == null:
		_create_typed_navmap()
		astar = get_parent().GetAstarForType(MY_TYPE)
	_path = astar.get_path(_platform, dest_platform)
	get_parent()._drawPath(_path)

func _repath_to_loc(gpos : Vector2):
	var dest_platform = get_parent().GetClosestPlatform(gpos)
	_repath_to(dest_platform)
