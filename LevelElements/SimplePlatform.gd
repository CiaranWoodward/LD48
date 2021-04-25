tool
extends Node2D

const NAVPOINT_MARGIN = 1

export var width = 100.0 setget _setwidth
export var height = 37.0 setget _setheight

var id = -1

func _ready():
	# We make a new rectangleshape because otherwise each platform shares the same one
	$StaticBody2D/CollisionShape2D.shape = RectangleShape2D.new()
	_setwidth(width)
	_setheight(height)

func _setwidth(w):
	width = w
	$Sprite.region_rect.size.x = w/$Sprite.scale.x
	$StaticBody2D/CollisionShape2D.shape.extents.x = w / 2
	$Left.position.x = -w/2 - NAVPOINT_MARGIN
	$Right.position.x = w/2 + NAVPOINT_MARGIN

func _setheight(h):
	height = h
	$Sprite.region_rect.size.y = h/$Sprite.scale.y
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

func _reduceNavMap(list):
	var rmlist = []
	var distmap = {} # dst to dist
	# Remove suboptimal paths
	# Find shortest paths
	for elem in list:
		if distmap.get(elem["other"], INF) > elem["dist"]:
			distmap[elem["other"]] = elem["dist"]
	# Remove any path that is longer than the minimum
	for i in range(list.size()):
		if list[i]["dist"] > distmap[list[i]["other"]]:
			rmlist.push_front(i)
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
	list = _optimizeNavMap(list, maxDist)
	return _reduceNavMap(list)

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

# Return The minimum distance between two platforms
func GetMinDistanceToPlat(other):
	var p1 = other.GetClosestPoint($Left.global_position)
	var d1_2 = p1.distance_squared_to($Left.global_position)
	var p2 = other.GetClosestPoint($Right.global_position)
	var d2_2 = p2.distance_squared_to($Right.global_position)
	if d1_2 < d2_2:
		return sqrt(d1_2)
	return sqrt(d2_2)
