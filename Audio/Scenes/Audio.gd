extends AudioStreamPlayer2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func play(time=0):
	pitch_scale = rand_range(0.9, 1.1)
	.play(time)
