extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func SetHealthProp(proportion : float):
	$Control/HPBar.value = proportion * 100

func SetShrineHealthProp(proportion : float):
	$Control/ShrineBar.value = proportion * 100

func SetMortalsCount(count : int):
	$Control/Counter/Number.text = str(count)
