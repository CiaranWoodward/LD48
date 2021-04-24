tool
extends Node2D

export var width = 100.0 setget _setwidth
export var height = 25.0 setget _setheight

func _ready():
	# We make a new rectangleshape because otherwise each platform shares the same one
	$StaticBody2D/CollisionShape2D.shape = RectangleShape2D.new()
	_setwidth(width)
	_setheight(height)

func _setwidth(w):
	width = w
	$Sprite.region_rect.size.x = w
	$StaticBody2D/CollisionShape2D.shape.extents.x = w / 2

func _setheight(h):
	height = h
	$Sprite.region_rect.size.y = h
	$StaticBody2D/CollisionShape2D.shape.extents.y = h / 2
