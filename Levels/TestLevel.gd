extends Node2D

export var drawNavMesh = false

# Maximum possible distance, just to minimize size of platform map
const MAX_JUMPDIST = 500

var _platforms = []
var _platform_idmap = {}
var _platform_navmap = {}
var _navmap_collided = false
var _treasure_platform = null
var _typed_navmap = {}
var _typed_astar = {}

class LevelAStar:
	extends AStar2D
	
	var navmap
	var idmap
	var random_factor
	
	# Initialise the astar with a navmap
	func init(navmap, idmap, random_factor=1.0):
		assert(random_factor >= 1)
		self.navmap = navmap
		self.idmap = idmap
		self.random_factor = random_factor
		# add the points first
		for plat in navmap.keys():
			add_point(plat.id, plat.global_position)
		# Register all the connections
		for plat in navmap.keys():
			for entry in navmap[plat]:
				self.connect_points(plat.id, entry["other"].id, false)
	
	# Get a path (as a list of platforms)
	func get_path(start_plat, dst_plat):
		var retlist = []
		var idpath = self.get_id_path(start_plat.id, dst_plat.id)
		for id in idpath:
			retlist.append(idmap[id])
		return retlist
	
	func _compute_cost(from_id, to_id):
		var list = navmap[idmap[from_id]]
		var dst = idmap[to_id]
		var mindist = INF
		for con in list:
			if con["other"] == dst && con["dist"] < mindist:
				mindist = con["dist"]
		return mindist * rand_range(1.0, random_factor)
	
	func _estimate_cost(from_id, to_id):
		return idmap[from_id].GetMinDistanceToPlat(idmap[to_id])
	
# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	_processPlatformMap()
	assert(_platforms.size() > 0)
	_treasure_platform = GetClosestPlatform($Treasure.global_position)

func _physics_process(_delta):
	if !_navmap_collided:
		_navmap_collided = true
		_collide_navmesh()
		#TODO: Hack to draw navmap
		$SimpleEnemy._create_typed_navmap()
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
		#var lst = _platform_navmap[plat]
		var lst = _typed_navmap["simpleton"][plat]
		for cnt in lst:
			var line = Line2D.new()
			line.width = 1
			line.add_point(cnt["src"])
			line.add_point(cnt["dst"])
			self.add_child(line)

func _drawPath(pathlist):
	if !drawNavMesh || pathlist.size() < 2:
		return
	var line = Line2D.new()
	line.width = 2
	line.default_color = Color(1, 0, 0)
	for plat in pathlist:
		line.add_point(plat.position)
	self.add_child(line)

func _processPlatformMap():
	# Get a list of all platforms
	var idcount = 0
	for child in get_children():
		if child.has_method("IsPlatform") and child.IsPlatform():
			child.id = idcount
			idcount += 1
			_platforms.append(child)
			_platform_navmap[child] = []
			_platform_idmap[child.id] = child
	# Map every platform to every other that is less than the MAX_JUMPDIST away
	for i in range(_platforms.size()):
		for j in range(i+1, _platforms.size()):
			var p1 = _platforms[i]
			var p2 = _platforms[j]
			var n1 = p1.GetNavMap(p2, MAX_JUMPDIST)
			var n2 = p1.InvertNavMap(n1, p1)
			_platform_navmap[p1].append_array(n1)
			_platform_navmap[p2].append_array(n2)

func GetNavMeshForType(type : String):
	return _typed_navmap.get(type)

func SetNavMeshForType(type : String, map, random_factor=1.0):
	_typed_navmap[type] = map
	var astar = LevelAStar.new()
	astar.init(map, _platform_idmap, random_factor)
	_typed_astar[type] = astar

func GetAstarForType(type : String):
	return _typed_astar.get(type)

func GetNavMeshCopy():
	return _platform_navmap.duplicate(true)

func GetClosestPlatform(gpos):
	var retVal = null
	var closestDist2 = INF
	for platform in _platforms:
		var p1 : Vector2 = platform.GetClosestPoint(gpos)
		var d2 = p1.distance_squared_to(gpos)
		if d2 < closestDist2:
			closestDist2 = d2
			retVal = platform
	return retVal

func GetClosestLowerPlatform(gpos, lower_threshold=0):
	var retVal = null
	var closestDist2 = INF
	for platform in _platforms:
		var p1 : Vector2 = platform.GetClosestPoint(gpos)
		if (p1.y - lower_threshold) < gpos.y:
			continue
		var d2 = p1.distance_squared_to(gpos)
		if d2 < closestDist2:
			closestDist2 = d2
			retVal = platform
	return retVal

func GetTreasureLocation():
	return $Treasure.global_position

func GetTreasurePlatform():
	return _treasure_platform
