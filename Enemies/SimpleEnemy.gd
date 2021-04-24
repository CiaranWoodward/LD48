extends KinematicBody2D

export var max_fallspeed = 700
export var max_speed = 500
export var max_jumpheight = 300
export var max_fallheight = 300
export var max_jump_up_time = 0.7

#animation properties between 0 and 1
export var fall_rate = 0.0

onready var animTree = $AnimationTree
onready var stateMachine : AnimationNodeStateMachinePlayback = animTree["parameters/StateMachine/playback"]

const MY_TYPE = "simpleton"

# Called when the node enters the scene tree for the first time.
func _ready():
	stateMachine.start("Idle")

func _handle_falling(_delta):
	if is_on_floor():
		fall_rate = 0
		if stateMachine.get_current_node() == "Falling":
			stateMachine.travel("Idle")
	else:
		stateMachine.travel("Falling")

func _handle_idle(_delta):
	pass

func _physics_process(delta):
	_handle_falling(delta)
	_handle_idle(delta)
	move_and_collide(Vector2(0, fall_rate * max_fallspeed) * delta)

func _is_jump_possible(from : Vector2, to : Vector2) -> bool:
	var heightincrease = from.y - to.y # This is backwards because y is inverted!
	var xdist = abs(from.x - to.x)
	var time_required = xdist/max_speed
	var time_fromheight
	
	if heightincrease < 0:
		time_fromheight = -heightincrease/max_fallspeed
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
	get_parent().SetNavMeshForType(MY_TYPE, map)

# Take a random, non-backtracking path to the destination
func _repath_to(gpos : Vector2):
	var level = get_parent()
	var my_platform = level.GetClosestLowerPlatform(self.position, 0)
	var dest_platform = level.GetClosestPlatform(gpos)
	var astar = get_parent().GetAstarForType(MY_TYPE)
	if astar == null:
		_create_typed_navmap()
		astar = get_parent().GetAstarForType(MY_TYPE)
	astar.get_path(my_platform, dest_platform)
