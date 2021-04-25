extends KinematicBody2D

export var accel_time = 0.3
export var max_speed = 400
export var max_airspeed = 300
export var max_fallspeed = 800
export var max_jumpspeed = 1000
export var gravity_time = 0.4
export var jump_time = 0.5
export var tiny_jump_time = 0.1

# current state
var _direction = 0
var _on_floor = true
var _moving = false
var _jumping = false
var _rapid_switcher = false # For allowing rapid direction switching
var _speed = 0
var _fallspeed = 1
var cur_maxspeed = max_speed
var _state = state.IDLE

# tween vars
var speed_proportion = 0

enum state {IDLE, FALLING, WALKING, ATTACK, GRAPPLE}

onready var stateMachine : AnimationNodeStateMachinePlayback = $AnimationTree["parameters/StateMachine/playback"]

# Called when the node enters the scene tree for the first time.
func _ready():
	$AnimationTree.active = true
	stateMachine.start("Idle")

# Button press actions
func _input(event: InputEvent) -> void:
	#jump
	if event.is_action_pressed("player_jump") && !_jumping:
		stateMachine.travel("JumpStart")
		_jumping = true
	if event.is_action_released("player_jump") && _jumping:
		_endjump()
	# Attack
	if event.is_action_pressed("player_attack"):
		if _jumping || !_on_floor:
			stateMachine.travel("FlyingAttack")
		else:
			stateMachine.travel("Attack")

# Continuous actions
func _handle_continuous_input() -> void:
	var left = Input.is_action_pressed("player_left")
	var right = Input.is_action_pressed("player_right")
	var oldDir = _direction
	if left && !right:
		_direction = -1
		_state = state.WALKING
		$Flipper.scale.x = -abs($Flipper.scale.x)
		_rapid_switcher = true
	elif right && !left:
		_direction = 1
		_state = state.WALKING
		_rapid_switcher = true
	elif !left && !right:
		_direction = 0
		_rapid_switcher = false
	elif _direction && _rapid_switcher:
		_direction = -_direction
		_rapid_switcher = false
	
	if oldDir != _direction:
		_cancel_momentum()
	
	if _direction == 1:
		$Flipper.scale.x = abs($Flipper.scale.x)
	if _direction == -1:
		$Flipper.scale.x = -abs($Flipper.scale.x)
	
	if oldDir && !_direction:
		_stopmove()
	elif !oldDir && _direction:
		_startmove()

func _startmove():
	$SpeedTween.remove_all()
	$SpeedTween.interpolate_property(self, "speed_proportion", null, 1, accel_time, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$SpeedTween.start()
	if(_on_floor):
		stateMachine.travel("Walk")
	_moving = true

func _stopmove():
	$SpeedTween.remove_all()
	$SpeedTween.interpolate_property(self, "speed_proportion", null, 0, accel_time, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$SpeedTween.start()
	if(_on_floor):
		stateMachine.travel("Idle")
	_moving = false

func _hitfloor():
	# We just hit the floor
	_on_floor = true
	$GravityTween.remove_all()
	_fallspeed = 1
	_jumping = false
	cur_maxspeed = max_speed
	if _moving:
		stateMachine.travel("Walk")
	else:
		stateMachine.travel("Idle")

func _leavefloor():
	# we just left the floor (or ended jump)
	$GravityTween.remove_all()
	$GravityTween.interpolate_property(self, "_fallspeed", null, max_fallspeed, gravity_time, Tween.TRANS_SINE, Tween.EASE_OUT)
	$GravityTween.start()
	_on_floor = false
	if !_direction:
		cur_maxspeed = max_airspeed
	stateMachine.travel("Falling")

func _jump():
	_on_floor = false
	_jumping = true
	if !_direction:
		cur_maxspeed = max_airspeed
	$GravityTween.remove_all()
	_fallspeed = -max_jumpspeed
	$GravityTween.interpolate_property(self, "_fallspeed", null, 0, jump_time, Tween.TRANS_SINE, Tween.EASE_OUT)
	if Input.is_action_pressed("player_jump"):
		$GravityTween.interpolate_callback(self, jump_time, "_endjump")
	else:
		$GravityTween.interpolate_callback(self, tiny_jump_time, "_endjump")
	$GravityTween.start()

func _endjump():
	if _jumping:
		_leavefloor()

func _handle_falling(delta: float) -> void:
	var kc = move_and_collide(Vector2(0, _fallspeed) * delta)
	if is_instance_valid(kc):
		if kc.normal.y < -0.5:
			if !_on_floor:
				_hitfloor()
			return
		if kc.normal.y > 0.5:
			# hit ceiling
			_fallspeed = 1
			_endjump()
	if _on_floor:
		_leavefloor()

func _cancel_momentum():
	if _on_floor:
		cur_maxspeed = max_speed
	else:
		cur_maxspeed = max_airspeed

func _handle_playermove(delta: float) -> void:
	var kc = move_and_collide(Vector2(_direction, 0) * delta * cur_maxspeed)

func _physics_process(delta: float) -> void:
	_handle_continuous_input()
	_handle_falling(delta)
	_handle_playermove(delta)
