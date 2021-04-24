extends KinematicBody2D

const MY_TYPE = "simpleton"

export var max_fallspeed = 700
export var max_speed = 500
export var max_jumpheight = 300
export var max_fallheight = 300
export var max_jump_up_time = 0.7
export var pathing_random_factor = 5.0

#animation properties between 0 and 1
export var fall_rate = 0.0

onready var animTree = $AnimationTree
onready var stateMachine : AnimationNodeStateMachinePlayback = animTree["parameters/StateMachine/playback"]

var _path = []
var _platform = null
var _on_floor = false

# Called when the node enters the scene tree for the first time.
func _ready():
	stateMachine.start("Idle")

func _handle_falling(delta):
	if _on_floor:
		fall_rate = 0
		if stateMachine.get_current_node() == "Falling":
			stateMachine.travel("Idle")
			_platform = get_parent().GetClosestLowerPlatform(global_position)
	else:
		stateMachine.travel("Falling")
		var kc = move_and_collide(Vector2(0, fall_rate * max_fallspeed) * delta)
		if is_instance_valid(kc):
			_on_floor = true #TODO: Might have to enhance this

func _handle_idle(_delta):
	if _on_floor:
		var cn = stateMachine.get_current_node()
		if cn == "Idle":
			if _path.size() == 0 || !(_platform in _path):
				_repath_to(get_parent().GetTreasurePlatform())

func _physics_process(delta):
	_handle_falling(delta)
	_handle_idle(delta)

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
