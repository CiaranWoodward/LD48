extends KinematicBody2D

#movement
export var accel_time = 0.3
export var max_speed = 400
export var max_airspeed = 300
export var max_fallspeed = 800
export var max_jumpspeed = 1000
export var gravity_time = 0.4
export var jump_time = 0.5
export var tiny_jump_time = 0.1
export var grapple_length = 1400
export var grapple_accel_time = 0.3
export var max_grapplespeed = 600
export var grapple_stick_in_dist = 20.0
export(float, 0.0, 1.0) var grappling_slidyness = 0.5 #higher is more slidy

#attacking
export var damage = 10.0
export var max_health = 50.0
export var attack_ticks : int = 2
export var pushback_amount = 600.0
export var recoil_amount = 20.0
export var min_grapple_attack_dist = 200.0
export var grapple_attack_hit_dist = 40.0
export var grapple_attack_bonus = 2.0

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
var _grapplePoint = Vector2.INF
var _grapplee = null
var last_platform = null
var health = max_health
var _dead = false
#attacking state
var _attack_countdown = 0
var _recoil_countdown = 0
var _already_hit = []

# tween vars
var speed_proportion = 0
var _max_speed_proportion

enum state {IDLE, FALLING, WALKING, ATTACK, GRAPPLE}

onready var stateMachine : AnimationNodeStateMachinePlayback = $AnimationTree["parameters/StateMachine/playback"]
onready var myHand = $Flipper/Demon/Hand
onready var myTrident = $Flipper/Demon/Hand/Trident
onready var myAttackShape = $Flipper/Demon/AttackArea/AttackShape

# Called when the node enters the scene tree for the first time.
func _ready():
	$AnimationTree.active = true
	stateMachine.start("Idle")

func GetXcomponent() -> float:
	if IsGrappling():
		return myHand.global_position.direction_to(_grapplePoint).x
	else:
		return _direction

func _start_attack():
	_already_hit = []
	_attack_countdown = attack_ticks
	myAttackShape.disabled = false

# Button press actions
func _input(event: InputEvent) -> void:
	if _dead:
		return
	#jump
	if event.is_action_pressed("player_jump") && !_jumping:
		_end_grapple()
		_travel_animation("JumpStart")
		_jumping = true
	if event.is_action_released("player_jump"):
		if _jumping:
			$GravityTween.interpolate_callback(self, tiny_jump_time, "_endjump")
	# Attack
	if event.is_action_pressed("player_attack"):
		if _jumping || !_on_floor:
			_end_grapple()
			_travel_animation("FlyingAttack")
		else:
			_travel_animation("Attack")
	# Grapple
	if event.is_action_pressed("player_grapple"):
		var space_state = get_world_2d().direct_space_state
		var gmp = get_global_mouse_position()
		var ghp = myHand.global_position
		var dir = ghp.direction_to(gmp)
		var vec = dir * grapple_length
		var res = space_state.intersect_ray(ghp, ghp + vec, [self], 1 + 4)
		var colobj = res.get("collider")
		if res.empty():
			_travel_animation("GrappleFail")
		elif is_instance_valid(colobj) && colobj.has_method("_grapple_if_possible"):
			if colobj._grapple_if_possible(ghp):
				_grapplee = colobj
				_grapplePoint = res["position"] + dir * grapple_stick_in_dist
				_start_grapple()
			else:
				_travel_animation("GrappleFail")
		else:
			_grapplePoint = res["position"] + dir * grapple_stick_in_dist
			_start_grapple()
			
	if event.is_action_released("player_grapple"):
		_end_grapple()

func _start_grapple():
	_on_floor = false
	_moving = false
	$GravityTween.remove_all()
	$SpeedTween.remove_all()
	$SpeedTween.interpolate_property(self, "speed_proportion", null, 1, grapple_accel_time, Tween.TRANS_EXPO, Tween.EASE_OUT)
	$SpeedTween.start()
	_travel_animation("Grapple")
	$GrappleChain.visible = true
	$GrappleHook.visible = true
	myTrident.visible = false

func _end_grapple():
	if !IsGrappling():
		return
	var dir = myHand.global_position.direction_to(_grapplePoint)
	_fallspeed = dir.y * speed_proportion * max_grapplespeed
	speed_proportion = abs(dir.x)
	if dir.x > 0:
		_direction = 1
	else:
		_direction = -1
	_grapplePoint = Vector2.INF
	_leavefloor()
	$GrappleChain.visible = false
	$GrappleHook.visible = false
	myTrident.visible = true
	if is_instance_valid(_grapplee):
		_grapplee._grapple_done()
	_grapplee = null
	_startmoveifkeypressed()

func IsGrappling() -> bool:
	return (_grapplePoint != Vector2.INF)

# Continuous actions
func _handle_continuous_input() -> void:
	_handle_player_movement()

func _handle_player_movement() -> void:
	var left = Input.is_action_pressed("player_left")
	var right = Input.is_action_pressed("player_right")
	var oldDir = _direction
	if left && !right:
		_direction = -1
		_state = state.WALKING
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
		if _on_floor:
			_stopmove()
		else:
			_direction = oldDir # keep floating in air
	elif !oldDir && _direction:
		_startmove()
	_startmoveifkeypressed()
#	elif speed_proportion < 1 && _direction && _on_floor && !_jumping:
#		_startmove()

func _startmoveifkeypressed():
	if Input.is_action_pressed("player_left") || Input.is_action_pressed("player_right"):
		if !_moving:
			_startmove()

func _startmove():
	$SpeedTween.remove_all()
	$SpeedTween.interpolate_property(self, "speed_proportion", null, 1, accel_time, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$SpeedTween.start()
	if(_on_floor):
		_travel_animation("Walk")
	_moving = true

func _stopmove():
	$SpeedTween.remove_all()
	$SpeedTween.interpolate_property(self, "speed_proportion", null, 0, accel_time, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$SpeedTween.start()
	if(_on_floor):
		_travel_animation("Idle")
	_moving = false

func _hitfloor():
	# We just hit the floor
	_on_floor = true
	last_platform = get_parent().GetClosestLowerPlatform(global_position)
	$GravityTween.remove_all()
	_fallspeed = 1
	_jumping = false
	cur_maxspeed = max_speed
	if _moving:
		_travel_animation("Walk")
	else:
		_travel_animation("Idle")

func _leavefloor():
	# we just left the floor (or ended jump)
	$GravityTween.remove_all()
	$GravityTween.interpolate_property(self, "_fallspeed", null, max_fallspeed, gravity_time, Tween.TRANS_SINE, Tween.EASE_OUT)
	$GravityTween.start()
	_on_floor = false
	if !_direction:
		cur_maxspeed = max_airspeed
	_travel_animation("Falling")

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
		_startmoveifkeypressed()

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
	var kc = move_and_collide(Vector2(_direction, 0) * delta * speed_proportion * cur_maxspeed)
	if abs(_recoil_countdown) > 1:
		kc = move_and_collide(Vector2(_recoil_countdown/2, 0))
		_recoil_countdown = _recoil_countdown/2

func _handle_playergrapplemove(delta: float) -> void:
	var dir = myHand.global_position.direction_to(_grapplePoint)
	var dist = myHand.global_position.distance_to(_grapplePoint)
	var midpoint = (myHand.global_position + _grapplePoint)/2
	var angle = myHand.global_position.angle_to_point(_grapplePoint) -PI/2
	var kc = move_and_collide(dir * delta * speed_proportion * max_grapplespeed)
	if is_instance_valid(kc):
		var slidedir = dir.slide(kc.normal)
		if slidedir.length() < (1.0-grappling_slidyness):
			_end_grapple()
		else:
			kc = move_and_collide(slidedir * delta * speed_proportion * max_grapplespeed)
			if is_instance_valid(kc):
				_end_grapple()
	$GrappleChain.global_rotation = angle
	$GrappleChain.global_position = midpoint
	$GrappleChain.region_rect.size.y = int(dist)/$GrappleChain.scale.x
	$GrappleHook.rotation = angle
	$GrappleHook.global_position = _grapplePoint
	if dir.x > 0:
		$Flipper.scale.x = abs($Flipper.scale.x)
	if dir.x < 0:
		$Flipper.scale.x = -abs($Flipper.scale.x)

func _handle_playergrappleattack(delta: float) -> void:
	if is_instance_valid(_grapplee):
		if global_position.distance_to(_grapplee.global_position) <= grapple_attack_hit_dist:
			var dir = sign($Flipper.scale.x)
			var pushback = Vector2(dir * 0.5, -0.5) * pushback_amount * grapple_attack_bonus
			_grapplee.take_damage(damage * grapple_attack_bonus, pushback)
			_end_grapple()

func _countdown_attack():
	if myAttackShape.disabled:
		_attack_countdown = 0
		return
	_attack_countdown = _attack_countdown - 1
	if _attack_countdown <= 0:
		myAttackShape.disabled = true
		_attack_countdown = 0

func _on_AttackArea_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		if body in _already_hit:
			return
		var dir = sign($Flipper.scale.x)
		var pushback = Vector2(dir * 0.5, -0.5) * pushback_amount
		body.take_damage(damage, pushback)
		_recoil_countdown = _recoil_countdown - dir * recoil_amount
		_already_hit.append(body)

func take_damage(damage, pushback):
	if _dead:
		return
	_recoil_countdown = _recoil_countdown + pushback.x
	stateMachine.start("Hit")
	health = health - damage
	if health < 0:
		_travel_animation("Die")
		_dead = true
		_end_grapple()
		_endjump()

func _travel_animation(dest : String):
	if !_dead:
		stateMachine.travel(dest)

func _physics_process(delta: float) -> void:
	_countdown_attack()
	if _on_floor:
		_jumping = false
	if IsGrappling():
		_handle_playergrapplemove(delta)
		_handle_playergrappleattack(delta)
	else:
		_handle_continuous_input()
		_handle_falling(delta)
		_handle_playermove(delta)
