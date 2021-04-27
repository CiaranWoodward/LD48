extends TextureRect

var minimum_timer : Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	minimum_timer = Timer.new()
	add_child(minimum_timer)
	minimum_timer.start(0.5)
	minimum_timer.one_shot = true

func _input(event: InputEvent) -> void:
	if !minimum_timer.is_stopped():
		return
	if event is InputEventKey || event is InputEventJoypadButton || event is InputEventMouseButton:
		$AnimationPlayer.play("GameEnd")
