extends "res://SplashScreens/SplashScreen.gd"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	dest_scene = load(Global.latest_level)
