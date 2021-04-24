tool
extends Node2D

const NAVPOINT_MARGIN = 1

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
	$Left.position.x = -w/2 - NAVPOINT_MARGIN
	$Right.position.x = w/2 + NAVPOINT_MARGIN

func _setheight(h):
	height = h
	$Sprite.region_rect.size.y = h
	$StaticBody2D/CollisionShape2D.shape.extents.y = h / 2
	$Left.position.y = -h/2 - NAVPOINT_MARGIN
	$Right.position.y = -h/2 - NAVPOINT_MARGIN

func IsPlatform():
	return true

func _getNavPoint(other, other_gpos):
	var mpos = self.GetClosestPoint(other_gpos)
	var dist = mpos.distance_to(other_gpos)
	return {
		"other" : other,
		"src" : mpos,
		"dst" : other_gpos,
		"dist" : dist
		}

func _invertNavPoint(point, newOther):
	return {
		"other" : newOther,
		"src" : point["dst"],
		"dst" : point["src"],
		"dist" : point["dist"]
	}

func _optimizeNavMap(list, maxDist):
	var rmlist = []
	# Remove duplicates & too far aways
	for i in range(list.size()):
		for j in range(i, list.size()):
			if list[i]["dist"] > maxDist:
				rmlist.push_front(i)
				break
			elif i != j && list[i]["src"] == list[j]["src"] && list[i]["dst"] == list[j]["dst"]:
				rmlist.push_front(i)
				break
	for i in rmlist:
		list.remove(i)
	return list

func InvertNavMap(navMap, newOther):
	var newList = []
	for elem in navMap:
		newList.append(_invertNavPoint(elem, newOther))
	return newList

func GetNavMap(other, maxDist):
	var list = []
	list.append(_getNavPoint(other, other.GetLeft()))
	list.append(_getNavPoint(other, other.GetRight()))
	list.append(_invertNavPoint(other._getNavPoint(self, self.GetLeft()), other))
	list.append(_invertNavPoint(other._getNavPoint(self, self.GetRight()), other))
	return _optimizeNavMap(list, maxDist)

func GetLeft():
	return $Left.global_position

func GetRight():
	return $Right.global_position

# Get the closest point on the platform to the global position
func GetClosestPoint(gpos : Vector2) -> Vector2:
	var segLen2 = $Left.position.distance_squared_to($Right.position)
	assert(segLen2 > 0)
	
	# vector maths is fun
	var v1 = gpos - $Left.global_position
	var v2 = $Right.global_position - $Left.global_position
	var t = max(0, min(1, v1.dot(v2)/segLen2))
	var p = $Left.global_position + (t * v2)
	return p
