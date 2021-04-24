extends KinematicBody2D

export var fall_velocity = 0.0

onready var animTree = $AnimationTree
onready var stateMachine : AnimationNodeStateMachinePlayback = animTree["parameters/StateMachine/playback"]

# Called when the node enters the scene tree for the first time.
func _ready():
	stateMachine.start("Idle")

func _handle_falling(_delta):
	if is_on_floor():
		fall_velocity = 0
		if stateMachine.get_current_node() == "Falling":
			stateMachine.travel("Idle")
	else:
		stateMachine.travel("Falling")

func _handle_idle(_delta):
	pass

func _physics_process(delta):
	_handle_falling(delta)
	move_and_collide(Vector2(0, fall_velocity) * delta)
