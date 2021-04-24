extends Node2D

export var drawNavMesh = false

# Maximum possible distance, just to minimize size of platform map
const MAX_JUMPDIST = 500
# Threshold for determining "below" - i.e. must be more below than this value
const LOWER_THRESHOLD = 50

var _platforms = []
var _platform_navmap = {}
var _navmap_collided = false
var _treasure_platform = null

# Called when the node enters the scene tree for the first time.
func _ready():
	_processPlatformMap()
	assert(_platforms.size() > 0)
	_treasure_platform = GetClosestPlatform($Treasure.global_position)

func _physics_process(delta):
	if !_navmap_collided:
		_navmap_collided = true
		_collide_navmesh()
		_drawNavMesh()

func _collide_navmesh():
	#TODO: We could half the processing here, but YOLO
	var space_state = get_world_2d().direct_space_state
	for plat in _platforms:
		var rmlist = []
		var lst = _platform_navmap[plat]
		for i in range(lst.size()):
			var res = space_state.intersect_ray(lst[i]["src"], lst[i]["dst"])
			if !res.empty():
				rmlist.push_front(i)
		for rm in rmlist:
			lst.remove(rm)

func _drawNavMesh():
	if !drawNavMesh:
		return
	for plat in _platforms:
		var lst = _platform_navmap[plat]
		for cnt in lst:
			var line = Line2D.new()
			line.width = 1
			line.add_point(cnt["src"])
			line.add_point(cnt["dst"])
			self.add_child(line)

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
			_platform_navmap[p1].append_array(n1)
			_platform_navmap[p2].append_array(n2)

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
