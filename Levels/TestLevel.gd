extends Node2D

# Maximum possible distance, just to minimize size of platform map
const MAX_JUMPDIST = 500
# Threshold for determining "below" - i.e. must be more below than this value
const LOWER_THRESHOLD = 50

var _platforms = []
var _platform_navmap = {}
var _treasure_platform = null

# Called when the node enters the scene tree for the first time.
func _ready():
	_processPlatformMap()
	assert(_platforms.size() > 0)
	_treasure_platform = GetClosestPlatform($Treasure.global_position)

func _processPlatformMap():
	# Get a list of all platforms
	for child in get_children():
		if child.has_method("IsPlatform") and child.IsPlatform():
			_platforms.append(child)
			_platform_navmap[child] = []
	# Map every platform to every other that is less than the MAX_JUMPDIST away
	for i in range(_platforms.size()):
		for j in range(i+1, _platforms.size()):
			var p1 = _platforms[i]
			var p2 = _platforms[j]
			var n1 = p1.GetNavMap(p2, MAX_JUMPDIST)
			var n2 = p1.InvertNavMap(n1, p1)
			_platform_navmap[p1] = n1
			_platform_navmap[p2] = n2

func GetClosestPlatform(gpos):
	var retVal = null
	var closestDist2 = INF
	for platform in _platforms:
		var p1 : Vector2 = platform.GetClosestPoint(gpos)
		var d2 = p1.distance_squared_to(gpos)
		if d2 < closestDist2:
			closestDist2 = d2
			retVal = p1
	return retVal

func GetClosestLowerPlatform(gpos, lower_threshold=LOWER_THRESHOLD):
	var retVal = null
	var closestDist2 = INF
	for platform in _platforms:
		var p1 : Vector2 = platform.GetClosestPoint(gpos)
		if p1.y + lower_threshold > gpos.y:
			continue
		var d2 = p1.distance_squared_to(gpos)
		if d2 < closestDist2:
			closestDist2 = d2
			retVal = p1
	return retVal

func GetTreasureLocation():
	return $Treasure.global_position

func GetTreasurePlatform():
	return _treasure_platform
