extends KinematicBody2D

export var pushback_amount = 50.0

var velocity = Vector2.ZERO
var damage = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

#take_damage(damage, Vector2(dir * pushback_amount, 0))
func _physics_process(delta: float) -> void:
	if velocity == Vector2.ZERO:
		return
	$Rotator.global_rotation = velocity.angle() - Vector2(1, 0).angle()
	var kc = self.move_and_collide(velocity * delta)
	if is_instance_valid(kc):
		if kc.collider.has_method("take_damage"):
			var dir = sign(velocity.x)
			kc.collider.take_damage(damage, Vector2(dir * pushback_amount, 0))
			queue_free()
			return
		velocity = Vector2.ZERO
		damage = 0
		pushback_amount = 0
		$Rotator/Knife/CPUParticles2D.emitting = false
