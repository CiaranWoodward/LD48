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
	$Left.position.x = -w/2
	$Right.position.x = w/2

func _setheight(h):
	height = h
	$Sprite.region_rect.size.y = h
	$StaticBody2D/CollisionShape2D.shape.extents.y = h / 2
	$Left.position.y = -h/2
	$Right.position.y = -h/2

func IsPlatform():
	return true

func _getNavPoint(other, other_gpos):
	var mpos = self.GetClosestPoint(other_gpos)
	var dist = mpos.distance_to(other_gpos)
	return {}

func GetNavMap(other):
	var list = []
	self.GetClosestPoint(other.GetLeft)

func GetLeft():
	return $Left.global_position

func GetRight():
	return $Right.global_position

# Get the closest point on the platform to the global position
func GetClosestPoint(gpos : Vector2) -> Vector2:
	var segLen2 = $Left.position.distance_squared_to($Right)
	assert(segLen2 > 0)
	
	# vector maths is fun
	var v1 = gpos - $Left.global_position
	var v2 = $Right.global_position - $Left.global_position
	var t = max(0, min(1, v1.dot(v2)/segLen2))
	var p = $Left.global_position + (t * v2)
	return p
