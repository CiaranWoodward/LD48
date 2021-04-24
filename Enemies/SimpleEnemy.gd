extends KinematicBody2D

export var max_fallspeed = 700
export var max_speed = 500
export var max_jumpheight = 400

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
	move_and_collide(Vector2(0, fall_rate * max_fallspeed) * delta)

func _create_typed_navmap():
	var map = get_parent().GetNavMeshCopy()
	#TODO: Continue

# Take a random, non-backtracking path to the destination
func _repath_to(gpos : Vector2):
	var level = get_parent()
	var my_platform = level.GetClosestLowerPlatform(self.position, 0)
	var dest_platform = level.GetClosestPlatform(gpos)
	var astar = get_parent().GetAstarForType(MY_TYPE)
	if astar == null:
		_create_typed_navmap()
		astar = get_parent().GetAstarForType(MY_TYPE)
