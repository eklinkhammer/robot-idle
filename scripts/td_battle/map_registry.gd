extends RefCounted
## Static registry returning all battle map definitions.

const MapData := preload("res://scripts/td_battle/map_data.gd")


static func get_map(map_id: String) -> RefCounted:
	var maps := get_all_maps()
	for m: RefCounted in maps:
		if m.map_id == map_id:
			return m
	return null


static func get_all_maps() -> Array:
	return [_plains(), _valley(), _siege()]


static func _plains() -> RefCounted:
	var m := MapData.new()
	m.map_id = "plains"
	m.map_name = "Plains"
	m.grid_cols = 20
	m.grid_rows = 11
	m.spawn_cells = [Vector2i(0, 5)]
	m.exit_cell = Vector2i(19, 5)
	m.obstacles = []
	m.starting_gold = 100
	m.starting_lives = 20
	# Totals: 10, 14, 18, 26, 38  |  Gold: 30, 40, 50, 60, 0
	m.waves = [
		{"normal": 10, "fast": 0, "armored": 0, "gold": 30},
		{"normal": 14, "fast": 0, "armored": 0, "gold": 40},
		{"normal": 12, "fast": 6, "armored": 0, "gold": 50},
		{"normal": 14, "fast": 12, "armored": 0, "gold": 60},
		{"normal": 16, "fast": 22, "armored": 0, "gold": 0},
	]
	return m


static func _valley() -> RefCounted:
	var m := MapData.new()
	m.map_id = "valley"
	m.map_name = "Valley"
	m.grid_cols = 20
	m.grid_rows = 11
	m.spawn_cells = [Vector2i(0, 0)]
	m.exit_cell = Vector2i(19, 10)
	m.obstacles = [
		# Wall segment 1
		Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5),
		# Wall segment 2
		Vector2i(10, 5), Vector2i(10, 6), Vector2i(10, 7),
		# Wall segment 3
		Vector2i(15, 3), Vector2i(15, 4), Vector2i(15, 5),
	]
	m.starting_gold = 120
	m.starting_lives = 20
	# Totals: 12, 18, 24, 34, 48, 66  |  Gold: 35, 45, 55, 65, 75, 0
	m.waves = [
		{"normal": 12, "fast": 0, "armored": 0, "gold": 35},
		{"normal": 14, "fast": 4, "armored": 0, "gold": 45},
		{"normal": 12, "fast": 8, "armored": 4, "gold": 55},
		{"normal": 12, "fast": 14, "armored": 8, "gold": 65},
		{"normal": 12, "fast": 22, "armored": 14, "gold": 75},
		{"normal": 12, "fast": 32, "armored": 22, "gold": 0},
	]
	return m


static func _siege() -> RefCounted:
	var m := MapData.new()
	m.map_id = "siege"
	m.map_name = "Siege"
	m.grid_cols = 20
	m.grid_rows = 11
	m.spawn_cells = [Vector2i(0, 2), Vector2i(0, 8)]
	m.exit_cell = Vector2i(19, 5)
	m.obstacles = [
		# Upper barrier
		Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3),
		Vector2i(8, 0), Vector2i(8, 1),
		# Lower barrier (symmetric)
		Vector2i(4, 7), Vector2i(4, 8), Vector2i(4, 9),
		Vector2i(8, 9), Vector2i(8, 10),
		# Central barriers
		Vector2i(12, 4), Vector2i(12, 5), Vector2i(12, 6),
		Vector2i(16, 5),
	]
	m.starting_gold = 150
	m.starting_lives = 15
	# Totals: 20, 28, 38, 52, 70, 92, 120  |  Gold: 40, 50, 60, 70, 80, 90, 0
	m.waves = [
		{"normal": 16, "fast": 4, "armored": 0, "gold": 40},
		{"normal": 14, "fast": 10, "armored": 4, "gold": 50},
		{"normal": 12, "fast": 16, "armored": 10, "gold": 60},
		{"normal": 10, "fast": 24, "armored": 18, "gold": 70},
		{"normal": 8, "fast": 34, "armored": 28, "gold": 80},
		{"normal": 6, "fast": 46, "armored": 40, "gold": 90},
		{"normal": 4, "fast": 60, "armored": 56, "gold": 0},
	]
	return m
