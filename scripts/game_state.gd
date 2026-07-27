extends Node
## Autoload singleton: tracks selected map and beaten maps.

var selected_map_id: String = "plains"
var beaten_maps: Dictionary = {}  # Dictionary[String, bool]


func mark_beaten(map_id: String) -> void:
	beaten_maps[map_id] = true


func is_beaten(map_id: String) -> bool:
	return beaten_maps.has(map_id)
