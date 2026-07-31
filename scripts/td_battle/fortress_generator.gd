extends RefCounted
## Generates fortress layouts for offense mode: spine walls, lanes, threat profiles, towers.

const FortressData := preload("res://scripts/td_battle/fortress_data.gd")

const GRID_COLS: int = 20
const GRID_ROWS: int = 11

const TOWER_COSTS: Dictionary = {"peasant": 10, "archer": 25, "catapult": 40}
const UPGRADE_COSTS: Dictionary = {"peasant": 15, "archer": 35, "catapult": 50}

const PROFILES: Array = ["anti_single", "anti_swarm", "light"]


static func generate(difficulty: int, gen_seed: int) -> RefCounted:
	seed(gen_seed)

	var fort := FortressData.new()
	fort.fortress_id = "fortress_%d_%d" % [difficulty, gen_seed]
	fort.fortress_name = "Fortress (Diff %d)" % difficulty
	fort.difficulty = difficulty

	var lane_count: int = 2 if difficulty <= 2 else 3

	# Step 1: Generate spine walls and determine lanes
	var spine_rows: Array[int] = _pick_spine_rows(lane_count)
	var spine_gaps: Array[Dictionary] = []  # {"row": int, "gap_start": int, "gap_width": int}
	var gap_width: int = 2 if difficulty <= 2 else (randi_range(1, 2) if difficulty == 3 else 1)

	for i in range(spine_rows.size()):
		var gap_start: int
		if i == 0:
			gap_start = randi_range(3, 15 - gap_width)
		else:
			# Stagger gaps by 4+ columns from previous
			var prev_gap: int = spine_gaps[i - 1]["gap_start"]
			var candidates: Array[int] = []
			for col in range(3, 16 - gap_width):
				if absi(col - prev_gap) >= 4:
					candidates.append(col)
			if candidates.is_empty():
				gap_start = randi_range(3, 15 - gap_width)
			else:
				gap_start = candidates[randi_range(0, candidates.size() - 1)]
		spine_gaps.append({"row": spine_rows[i], "gap_start": gap_start, "gap_width": gap_width})

	# Build spine obstacle cells
	for sg: Dictionary in spine_gaps:
		var row: int = sg["row"]
		for col in range(2, 18):
			var in_gap: bool = col >= sg["gap_start"] and col < sg["gap_start"] + sg["gap_width"]
			if not in_gap:
				fort.obstacles.append(Vector2i(col, row))

	# Determine lane row ranges
	var lane_rows: Array[Dictionary] = []  # {"start": int, "end": int}
	if lane_count == 2:
		lane_rows.append({"start": 0, "end": spine_rows[0] - 1})
		lane_rows.append({"start": spine_rows[0] + 1, "end": GRID_ROWS - 1})
	else:
		lane_rows.append({"start": 0, "end": spine_rows[0] - 1})
		lane_rows.append({"start": spine_rows[0] + 1, "end": spine_rows[1] - 1})
		lane_rows.append({"start": spine_rows[1] + 1, "end": GRID_ROWS - 1})

	# Pick entry cells (column 0, center of each lane)
	for lr: Dictionary in lane_rows:
		var center_row: int = (lr["start"] + lr["end"]) / 2
		fort.entry_cells.append(Vector2i(0, center_row))

	# Exit cell near grid center-right
	fort.exit_cell = Vector2i(GRID_COLS - 1, GRID_ROWS / 2)

	# Step 2: Internal obstacles per lane
	var astar := _build_astar(fort.obstacles)
	var obs_per_lane: int = clampi(difficulty, 1, 3)
	for li in range(lane_rows.size()):
		var lr: Dictionary = lane_rows[li]
		var added: int = 0
		for _attempt in range(obs_per_lane * 10):
			if added >= obs_per_lane:
				break
			var seg := _try_internal_obstacle(astar, lr, fort.entry_cells, fort.exit_cell, fort.obstacles)
			if not seg.is_empty():
				for cell: Vector2i in seg:
					fort.obstacles.append(cell)
				added += 1

	# Rebuild astar with all obstacles
	astar = _build_astar(fort.obstacles)

	# Step 3: Assign threat profiles
	var profiles := PROFILES.duplicate()
	profiles.shuffle()
	for li in range(lane_rows.size()):
		var profile: String = profiles[li % profiles.size()]
		fort.lanes.append({
			"profile": profile,
			"row_range": Vector2i(lane_rows[li]["start"], lane_rows[li]["end"]),
			"entry_cell": fort.entry_cells[li],
		})

	# Step 4: Place towers with budget
	var budget: int = 120 + difficulty * 60
	_place_towers(fort, astar, budget, difficulty)

	# Step 5: Validate and adjust
	_validate_balance(fort, astar)

	# Unit budget and win threshold scale with difficulty
	fort.unit_budget = 15 + difficulty * 5
	fort.win_threshold = 2 + difficulty

	return fort


static func _pick_spine_rows(lane_count: int) -> Array[int]:
	var rows: Array[int] = []
	if lane_count == 2:
		# One spine roughly in the middle
		rows.append(randi_range(4, 6))
	else:
		# Two spines dividing into thirds
		rows.append(randi_range(3, 4))
		rows.append(randi_range(7, 8))
	return rows


static func _build_astar(obstacles: Array[Vector2i]) -> AStarGrid2D:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, GRID_COLS, GRID_ROWS)
	astar.cell_size = Vector2(64, 64)
	astar.offset = Vector2(32, 32)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for obs: Vector2i in obstacles:
		astar.set_point_solid(obs, true)
	return astar


static func _try_internal_obstacle(astar: AStarGrid2D, lane: Dictionary, entries: Array[Vector2i], exit: Vector2i, existing_obs: Array[Vector2i]) -> Array[Vector2i]:
	for _attempt in range(15):
		var col: int = randi_range(4, 16)
		var seg_len: int = randi_range(2, 4)
		# Decide horizontal or vertical within the lane
		var horizontal: bool = randf() < 0.5
		var segment: Array[Vector2i] = []
		var valid := true

		if horizontal:
			var row: int = randi_range(lane["start"], lane["end"])
			for c in range(col, mini(col + seg_len, 18)):
				var cell := Vector2i(c, row)
				if astar.is_point_solid(cell) or cell in existing_obs:
					valid = false
					break
				# Don't block entry/exit columns
				if c == 0 or c == GRID_COLS - 1:
					valid = false
					break
				segment.append(cell)
		else:
			var start_row: int = randi_range(lane["start"], maxi(lane["start"], lane["end"] - seg_len + 1))
			for r in range(start_row, mini(start_row + seg_len, lane["end"] + 1)):
				var cell := Vector2i(col, r)
				if astar.is_point_solid(cell) or cell in existing_obs:
					valid = false
					break
				segment.append(cell)

		if not valid or segment.size() < 2:
			continue

		# Temporarily mark solid and validate
		for cell: Vector2i in segment:
			astar.set_point_solid(cell, true)

		var paths_ok := true
		for entry: Vector2i in entries:
			var path := astar.get_point_path(entry, exit)
			if path.is_empty():
				paths_ok = false
				break

		if paths_ok:
			return segment

		# Revert
		for cell: Vector2i in segment:
			astar.set_point_solid(cell, false)

	return []


static func _place_towers(fort: RefCounted, astar: AStarGrid2D, budget: int, difficulty: int) -> void:
	# Compute A* path per lane for tower placement guidance
	var lane_paths: Array[PackedVector2Array] = []
	for lane: Dictionary in fort.lanes:
		var path := astar.get_point_path(lane["entry_cell"], fort.exit_cell)
		lane_paths.append(path)

	# Determine budget split: light lane gets 15-25%, heavy lanes split the rest
	var light_idx: int = -1
	for i in range(fort.lanes.size()):
		if fort.lanes[i]["profile"] == "light":
			light_idx = i
			break

	var lane_budgets: Array[int] = []
	if light_idx >= 0:
		var light_share: int = roundi(budget * randf_range(0.15, 0.25))
		var heavy_share: int = budget - light_share
		var heavy_count: int = fort.lanes.size() - 1
		for i in range(fort.lanes.size()):
			if i == light_idx:
				lane_budgets.append(light_share)
			else:
				lane_budgets.append(heavy_share / heavy_count)
	else:
		# No light lane — split evenly
		for i in range(fort.lanes.size()):
			lane_budgets.append(budget / fort.lanes.size())

	# Place towers per lane
	for li in range(fort.lanes.size()):
		var lane: Dictionary = fort.lanes[li]
		var lane_budget: int = lane_budgets[li]
		var path: PackedVector2Array = lane_paths[li]
		var profile: String = lane["profile"]

		# Determine tower types for this profile
		var tower_types: Array[String] = []
		match profile:
			"anti_single":
				tower_types = ["archer", "archer", "peasant"]
			"anti_swarm":
				tower_types = ["catapult", "catapult", "peasant"]
			"light":
				tower_types = ["peasant", "peasant"]

		# Find candidate cells adjacent to path within this lane's rows
		var path_cells: Array[Vector2i] = []
		for wp: Vector2 in path:
			var cell := Vector2i(floori(wp.x / 64.0), floori(wp.y / 64.0))
			if cell.y >= lane["row_range"].x and cell.y <= lane["row_range"].y:
				path_cells.append(cell)

		var candidates: Array[Vector2i] = _get_tower_candidates(path_cells, astar, fort)

		# Place towers until budget runs out, validating each placement
		var spent: int = 0
		var type_idx: int = 0
		candidates.shuffle()
		for cell: Vector2i in candidates:
			if spent >= lane_budget:
				break
			var tower_type: String = tower_types[type_idx % tower_types.size()]
			var cost: int = TOWER_COSTS[tower_type]
			if spent + cost > lane_budget:
				tower_type = "peasant"
				cost = TOWER_COSTS["peasant"]
				if spent + cost > lane_budget:
					break
			# Validate this placement doesn't block any entry→exit path
			astar.set_point_solid(cell, true)
			var blocks := false
			for entry: Vector2i in fort.entry_cells:
				if astar.get_point_path(entry, fort.exit_cell).is_empty():
					blocks = true
					break
			if blocks:
				astar.set_point_solid(cell, false)
				continue
			fort.towers.append({"cell": cell, "type": tower_type, "upgraded": false})
			spent += cost
			type_idx += 1

	# Step 4b: Upgrades at difficulty 3+
	if difficulty >= 3:
		var upgrade_count: int
		match difficulty:
			3: upgrade_count = randi_range(3, 4)
			4: upgrade_count = randi_range(5, 6)
			_: upgrade_count = randi_range(8, 10)

		var upgradeable: Array[int] = []
		for i in range(fort.towers.size()):
			if not fort.towers[i]["upgraded"]:
				upgradeable.append(i)
		upgradeable.shuffle()

		var upgraded: int = 0
		for idx: int in upgradeable:
			if upgraded >= upgrade_count:
				break
			fort.towers[idx]["upgraded"] = true
			upgraded += 1


static func _get_tower_candidates(path_cells: Array[Vector2i], astar: AStarGrid2D, fort: RefCounted) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var used: Dictionary = {}
	var obstacle_set: Dictionary = {}
	for obs: Vector2i in fort.obstacles:
		obstacle_set[obs] = true
	var tower_set: Dictionary = {}
	for td: Dictionary in fort.towers:
		tower_set[td["cell"]] = true

	for pc: Vector2i in path_cells:
		for dir: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var adj: Vector2i = pc + dir
			if adj.x < 0 or adj.x >= GRID_COLS or adj.y < 0 or adj.y >= GRID_ROWS:
				continue
			if used.has(adj) or obstacle_set.has(adj) or tower_set.has(adj):
				continue
			# Don't place on entry/exit cells
			if adj in fort.entry_cells or adj == fort.exit_cell:
				continue
			# Don't place on path cells themselves
			if adj in path_cells:
				continue
			# Check it won't block paths
			astar.set_point_solid(adj, true)
			var blocks := false
			for entry: Vector2i in fort.entry_cells:
				if astar.get_point_path(entry, fort.exit_cell).is_empty():
					blocks = true
					break
			astar.set_point_solid(adj, false)
			if blocks:
				continue
			candidates.append(adj)
			used[adj] = true
	return candidates


static func _validate_balance(fort: RefCounted, astar: AStarGrid2D) -> void:
	# Ensure at least one lane has a coverage gap (4+ path cells with no tower in range)
	# If lanes are too similar, remove towers from the lightest lane
	var tower_range: float = 224.0  # Archer/catapult range
	var light_idx: int = -1
	for i in range(fort.lanes.size()):
		if fort.lanes[i]["profile"] == "light":
			light_idx = i
			break

	if light_idx < 0:
		return

	# Count towers in light lane
	var light_lane: Dictionary = fort.lanes[light_idx]
	var light_towers: Array[int] = []
	for i in range(fort.towers.size()):
		var tc: Vector2i = fort.towers[i]["cell"]
		if tc.y >= light_lane["row_range"].x and tc.y <= light_lane["row_range"].y:
			light_towers.append(i)

	# If light lane has more than 3 towers, remove extras to create gaps
	while light_towers.size() > 3:
		var remove_idx: int = light_towers.pop_back()
		var cell: Vector2i = fort.towers[remove_idx]["cell"]
		astar.set_point_solid(cell, false)
		fort.towers.remove_at(remove_idx)
