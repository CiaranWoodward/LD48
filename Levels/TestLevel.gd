extends Node2D

# Maximum possible distance, just to minimize size of platform map
const MAX_JUMPDIST = 500

var _platforms = []
var _platform_navmap = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _processPlatformMap():
	# Get a list of all platforms
	for child in get_children():
		if child.has_method("IsPlatform") and child.IsPlatform():
			_platforms.append(child)
			_platform_navmap[child] = []
	# Map every platform to every other that is less than the MAX_JUMPDIST away
	for i in range(_platforms.size()):
		for j in range(i, _platforms.size()):
			pass

func GetTreasureLocation():
	return $Treasure.global_position
