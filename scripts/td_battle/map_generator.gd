extends RefCounted
## Procedural map generator: produces a valid MapData with randomized layout and waves.

const MapData := preload("res://scripts/td_battle/map_data.gd")

const GRID_COLS: int = 20
const GRID_ROWS: int = 11
const ZONES: Array = [
	{"min_col": 3, "max_col": 6},
	{"min_col": 7, "max_col": 10},
	{"min_col": 11, "max_col": 14},
	{"min_col": 15, "max_col": 17},
]


static func generate(difficulty: int, map_seed: int) -> RefCounted:
	seed(map_seed)

	var m := MapData.new()
	m.map_id = "procedural"
	m.map_name = "Procedural (Diff %d)" % difficulty
	m.grid_cols = GRID_COLS
	m.grid_rows = GRID_ROWS

	# --- Spawns ---
	var spawn_count: int
	if difficulty <= 2:
		spawn_count = 1
	elif difficulty <= 4:
		spawn_count = 2
	else:
		spawn_count = 3

	m.spawn_cells = _generate_spawns(spawn_count)

	# --- Exit ---
	m.exit_cell = _generate_exit()

	# --- Obstacles ---
	m.obstacles = _generate_obstacles(difficulty, m.spawn_cells, m.exit_cell)

	# --- Economy & lives ---
	m.starting_gold = 80 + difficulty * 20
	m.starting_lives = maxi(10, 25 - difficulty * 2)

	# --- Waves ---
	m.waves = _generate_waves(difficulty)

	return m


static func _generate_spawns(count: int) -> Array[Vector2i]:
	var spawns: Array[Vector2i] = []
	var spacing: float = float(GRID_ROWS) / float(count + 1)
	for i in range(count):
		var base_row: int = roundi(spacing * (i + 1))
		var jitter: int = randi_range(-1, 1)
		var row: int = clampi(base_row + jitter, 0, GRID_ROWS - 1)
		spawns.append(Vector2i(0, row))
	return spawns


static func _generate_exit() -> Vector2i:
	# Weighted toward center: pick from middle rows with some variance
	var center: int = GRID_ROWS / 2
	var offset: int = randi_range(-2, 2)
	var row: int = clampi(center + offset, 1, GRID_ROWS - 2)
	return Vector2i(GRID_COLS - 1, row)


static func _generate_obstacles(difficulty: int, spawns: Array[Vector2i], exit: Vector2i) -> Array[Vector2i]:
	var obstacles: Array[Vector2i] = []
	var segment_count: int = 2 + difficulty

	# Build reserved set: spawn/exit cells + 1-cell buffer
	var reserved: Dictionary = {}  # used as set
	for sp: Vector2i in spawns:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				reserved[Vector2i(sp.x + dx, sp.y + dy)] = true
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			reserved[Vector2i(exit.x + dx, exit.y + dy)] = true

	# Build AStarGrid2D for validation
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, GRID_COLS, GRID_ROWS)
	astar.cell_size = Vector2(64, 64)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	for _i in range(segment_count):
		var segment := _try_place_segment(astar, spawns, exit, reserved)
		if segment.is_empty():
			continue
		for cell: Vector2i in segment:
			obstacles.append(cell)

	return obstacles


static func _try_place_segment(astar: AStarGrid2D, spawns: Array[Vector2i], exit: Vector2i, reserved: Dictionary) -> Array[Vector2i]:
	# Try a few times to place a valid segment
	for _attempt in range(15):
		var zone: Dictionary = ZONES[randi_range(0, ZONES.size() - 1)]
		var col: int = randi_range(zone["min_col"], zone["max_col"])

		# Prefer horizontal walls that cut across the path.
		# 60% horizontal (span columns), 40% vertical (span rows).
		var horizontal: bool = randf() < 0.6

		var segment: Array[Vector2i] = []
		var valid := true

		if horizontal:
			var seg_length: int = randi_range(3, 6)
			var start_col: int = clampi(col - seg_length / 2, zone["min_col"], maxi(zone["min_col"], zone["max_col"] - seg_length + 1))
			var row: int = randi_range(1, GRID_ROWS - 2)
			for c in range(start_col, mini(start_col + seg_length, zone["max_col"] + 1)):
				var cell := Vector2i(c, row)
				if reserved.has(cell) or astar.is_point_solid(cell):
					valid = false
					break
				segment.append(cell)
		else:
			var seg_length: int = randi_range(3, 5)
			var start_row: int = randi_range(0, GRID_ROWS - seg_length)
			for r in range(start_row, start_row + seg_length):
				var cell := Vector2i(col, r)
				if reserved.has(cell) or astar.is_point_solid(cell):
					valid = false
					break
				segment.append(cell)

		if not valid or segment.size() < 2:
			continue

		# Temporarily mark solid
		for cell: Vector2i in segment:
			astar.set_point_solid(cell, true)

		# Validate all paths
		if _all_paths_valid(astar, spawns, exit):
			return segment

		# Revert if blocked
		for cell: Vector2i in segment:
			astar.set_point_solid(cell, false)

	return []


static func _all_paths_valid(astar: AStarGrid2D, spawns: Array[Vector2i], exit: Vector2i) -> bool:
	for sp: Vector2i in spawns:
		var path := astar.get_point_path(sp, exit)
		if path.is_empty():
			return false
	return true


static func _generate_waves(difficulty: int) -> Array:
	var waves: Array = []
	var wave_count: int = 4 + difficulty
	var base_enemies: int = 8 + difficulty * 2

	for i in range(wave_count):
		var total: int = roundi(base_enemies * pow(1.35, i))
		var fast_ratio: float = 0.0
		var armored_ratio: float = 0.0

		# Fast enemies: wave threshold scales down with difficulty
		# Diff 1-2: from wave 3, Diff 3: from wave 2, Diff 4-5: from wave 1
		var fast_wave: int = maxi(1, 4 - difficulty)
		if i >= fast_wave:
			var waves_in: int = i - fast_wave
			fast_ratio = 0.2 + waves_in * 0.06

		# Armored enemies: wave threshold scales down with difficulty
		# Diff 1-2: from wave 4, Diff 3: from wave 3, Diff 4-5: from wave 2
		var armored_wave: int = maxi(2, 5 - difficulty)
		if i >= armored_wave:
			var waves_in: int = i - armored_wave
			armored_ratio = 0.15 + waves_in * 0.05

		fast_ratio = minf(fast_ratio, 0.5)
		armored_ratio = minf(armored_ratio, 0.4)

		var fast_count: int = roundi(total * fast_ratio)
		var armored_count: int = roundi(total * armored_ratio)
		var normal_count: int = total - fast_count - armored_count

		var gold: int = 0
		if i < wave_count - 1:
			gold = 25 + difficulty * 5 + i * 10

		waves.append({
			"normal": normal_count,
			"fast": fast_count,
			"armored": armored_count,
			"gold": gold,
		})

	return waves
