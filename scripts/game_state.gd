extends Node
## Autoload singleton: tracks selected map and beaten maps.

var selected_map_id: String = "plains"
var beaten_maps: Dictionary = {}  # Dictionary[String, bool]
var procedural_difficulty: int = 1
var procedural_seed: int = -1  # -1 = generate new seed on battle start
var highest_procedural_difficulty_beaten: int = 0


func mark_beaten(map_id: String) -> void:
	beaten_maps[map_id] = true


func is_beaten(map_id: String) -> bool:
	return beaten_maps.has(map_id)
