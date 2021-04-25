tool
extends StaticBody2D

export var length = 200.0 setget set_length

func _ready():
	var xlen = $CollisionShape2D.shape.extents.x
	$CollisionShape2D.shape = RectangleShape2D.new()
	set_length(length)
	$CollisionShape2D.shape.extents.x = xlen

func set_length(newlen):
	length = newlen
	$Walls.region_rect.size.x = newlen/$Walls.scale.x
	$CollisionShape2D.shape.extents.y = newlen / 2
