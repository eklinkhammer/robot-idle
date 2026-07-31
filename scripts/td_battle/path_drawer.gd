extends Node2D
## Handles click-to-draw path input for offense mode.
## Player draws 1+ paths from entry cells to the exit cell.

signal paths_changed  # Emitted when any path is modified

var grid_cols: int = 20
var grid_rows: int = 11
var cell_size: int = 64
var entry_cells: Array[Vector2i] = []
var exit_cell: Vector2i = Vector2i(19, 5)
var obstacles: Array[Vector2i] = []
var tower_cells: Array[Vector2i] = []

# Array of paths, each path is Array[Vector2i]
var paths: Array[Array] = []
var active_path_index: int = -1

var _obstacle_set: Dictionary = {}
var _tower_set: Dictionary = {}
var _lanes: Array[Dictionary] = []  # Fortress lane data for labels
var _font: Font

const PATH_COLORS: Array = [
	Color(0.2, 0.7, 1.0, 0.6),   # Blue
	Color(1.0, 0.6, 0.2, 0.6),   # Orange
	Color(0.4, 1.0, 0.4, 0.6),   # Green
]

const PROFILE_LABELS: Dictionary = {
	"anti_single": "ARCHERS - weak vs Fast",
	"anti_swarm": "CATAPULTS - weak vs Armored",
	"light": "LIGHT DEFENSES",
}


func configure(fort_data: RefCounted) -> void:
	grid_cols = fort_data.grid_cols
	grid_rows = fort_data.grid_rows
	cell_size = fort_data.cell_size
	entry_cells = fort_data.entry_cells.duplicate()
	exit_cell = fort_data.exit_cell
	obstacles = fort_data.obstacles.duplicate()
	tower_cells.clear()
	for td: Dictionary in fort_data.towers:
		tower_cells.append(td["cell"])

	_obstacle_set.clear()
	for obs: Vector2i in obstacles:
		_obstacle_set[obs] = true
	_tower_set.clear()
	for tc: Vector2i in tower_cells:
		_tower_set[tc] = true

	_lanes.clear()
	for lane: Dictionary in fort_data.lanes:
		_lanes.append(lane)

	# Initialize empty paths array
	paths.clear()
	for _i in range(entry_cells.size()):
		paths.append([])
	active_path_index = -1


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _world_to_grid(get_global_mouse_position())
		_handle_click(cell)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_undo_last_cell()


func _handle_click(cell: Vector2i) -> void:
	if not _in_bounds(cell):
		return

	# Check if clicking an entry cell to start/switch paths
	for i in range(entry_cells.size()):
		if cell == entry_cells[i]:
			active_path_index = i
			if paths[i].is_empty():
				paths[i] = [cell]
			queue_redraw()
			paths_changed.emit()
			return

	# If no active path, ignore
	if active_path_index < 0:
		return

	var current_path: Array = paths[active_path_index]

	# If path already reached exit, ignore further clicks
	if not current_path.is_empty() and current_path.back() == exit_cell:
		return

	# Cell must be adjacent to last cell in path
	if current_path.is_empty():
		return

	var last_cell: Vector2i = current_path.back()
	if not _is_adjacent(last_cell, cell):
		return

	# Cell must be walkable (not obstacle, not tower)
	if _obstacle_set.has(cell) or _tower_set.has(cell):
		return

	# Cell must not already be in this path (no loops)
	if cell in current_path:
		return

	current_path.append(cell)
	paths[active_path_index] = current_path
	queue_redraw()
	paths_changed.emit()


func _undo_last_cell() -> void:
	if active_path_index < 0:
		return
	var current_path: Array = paths[active_path_index]
	if current_path.size() <= 1:
		# Don't remove the entry cell
		return
	current_path.pop_back()
	paths[active_path_index] = current_path
	queue_redraw()
	paths_changed.emit()


func is_path_complete(index: int) -> bool:
	if index < 0 or index >= paths.size():
		return false
	var p: Array = paths[index]
	return not p.is_empty() and p.back() == exit_cell


func get_complete_path_count() -> int:
	var count: int = 0
	for i in range(paths.size()):
		if is_path_complete(i):
			count += 1
	return count


func get_path_world_points(index: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	if index < 0 or index >= paths.size():
		return result
	for cell: Vector2i in paths[index]:
		result.append(Vector2(cell.x * cell_size + cell_size * 0.5, cell.y * cell_size + cell_size * 0.5))
	return result


func clear_path(index: int) -> void:
	if index < 0 or index >= paths.size():
		return
	paths[index] = [entry_cells[index]]
	if active_path_index == index:
		active_path_index = index
	queue_redraw()
	paths_changed.emit()


func _draw() -> void:
	if _font == null:
		_font = ThemeDB.fallback_font

	# Draw lane labels and zone shading
	for li in range(_lanes.size()):
		var lane: Dictionary = _lanes[li]
		var row_range: Vector2i = lane["row_range"]
		var profile: String = lane["profile"]
		var color: Color = PATH_COLORS[li % PATH_COLORS.size()]

		# Light shading for each lane zone
		var zone_color: Color = color
		zone_color.a = 0.06
		var zone_rect := Rect2(
			0, row_range.x * cell_size,
			grid_cols * cell_size, (row_range.y - row_range.x + 1) * cell_size
		)
		draw_rect(zone_rect, zone_color, true)

		# Lane label text on the left side
		var label_text: String = PROFILE_LABELS.get(profile, profile)
		var label_y: float = ((row_range.x + row_range.y) * 0.5) * cell_size + cell_size * 0.5
		draw_string(_font, Vector2(cell_size * 1.5, label_y + 5), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))

	# Draw entry cell markers (pulsing border + arrow)
	for i in range(entry_cells.size()):
		var ec: Vector2i = entry_cells[i]
		var color: Color = PATH_COLORS[i % PATH_COLORS.size()]
		var rect := Rect2(ec.x * cell_size + 2, ec.y * cell_size + 2, cell_size - 4, cell_size - 4)

		if paths[i].is_empty():
			# Prominent border for unstarted paths
			color.a = 0.9
			draw_rect(rect, color, false, 3.0)
			# Arrow pointing right
			var cx: float = ec.x * cell_size + cell_size * 0.5
			var cy: float = ec.y * cell_size + cell_size * 0.5
			var arrow := PackedVector2Array([
				Vector2(cx - 8, cy - 8), Vector2(cx + 10, cy), Vector2(cx - 8, cy + 8)
			])
			draw_colored_polygon(arrow, color)
		else:
			# Subtle border for started paths
			color.a = 0.4
			draw_rect(rect, color, false, 2.0)

	# Draw paths
	for pi in range(paths.size()):
		var path: Array = paths[pi]
		if path.is_empty():
			continue
		var color: Color = PATH_COLORS[pi % PATH_COLORS.size()]
		var is_active: bool = (pi == active_path_index)

		# Draw path cells
		for cell: Vector2i in path:
			var rect := Rect2(cell.x * cell_size, cell.y * cell_size, cell_size, cell_size)
			var c: Color = color
			c.a = 0.5 if is_active else 0.3
			draw_rect(rect, c, true)

		# Draw path lines connecting cell centers
		if path.size() >= 2:
			var line_color: Color = color
			line_color.a = 0.9
			for i in range(path.size() - 1):
				var from_cell: Vector2i = path[i]
				var to_cell: Vector2i = path[i + 1]
				var from_pos := Vector2(from_cell.x * cell_size + cell_size * 0.5, from_cell.y * cell_size + cell_size * 0.5)
				var to_pos := Vector2(to_cell.x * cell_size + cell_size * 0.5, to_cell.y * cell_size + cell_size * 0.5)
				draw_line(from_pos, to_pos, line_color, 3.0)

		# Completion checkmark
		if is_path_complete(pi):
			var last: Vector2i = path.back()
			var center := Vector2(last.x * cell_size + cell_size * 0.5, last.y * cell_size + cell_size * 0.5)
			draw_circle(center, 10.0, Color(0.2, 1.0, 0.2, 0.8))
			draw_string(_font, center + Vector2(-5, 5), "ok", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		elif path.size() > 1:
			# Draw a small circle at the tip of an incomplete path
			var tip: Vector2i = path.back()
			var tip_pos := Vector2(tip.x * cell_size + cell_size * 0.5, tip.y * cell_size + cell_size * 0.5)
			draw_circle(tip_pos, 6.0, color)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_cols and cell.y >= 0 and cell.y < grid_rows


func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var diff := b - a
	return (absi(diff.x) + absi(diff.y)) == 1


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / cell_size), floori(world_pos.y / cell_size))
