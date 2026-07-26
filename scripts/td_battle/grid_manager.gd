extends Node2D
## Owns the AStarGrid2D, draws the grid, handles tower placement, and provides path queries.

signal grid_changed

const GRID_COLS: int = 20
const GRID_ROWS: int = 11
const CELL_SIZE: int = 64
const SPAWN_CELL: Vector2i = Vector2i(0, 5)
const EXIT_CELL: Vector2i = Vector2i(19, 5)

var _astar: AStarGrid2D
var _towers: Dictionary = {}  # Dictionary[Vector2i, bool]


func _ready() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, GRID_COLS, GRID_ROWS)
	_astar.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()


func _draw() -> void:
	# Grid lines
	var grid_color := Color(0.3, 0.3, 0.3, 0.4)
	for x in range(GRID_COLS + 1):
		draw_line(Vector2(x * CELL_SIZE, 0), Vector2(x * CELL_SIZE, GRID_ROWS * CELL_SIZE), grid_color)
	for y in range(GRID_ROWS + 1):
		draw_line(Vector2(0, y * CELL_SIZE), Vector2(GRID_COLS * CELL_SIZE, y * CELL_SIZE), grid_color)

	# Spawn cell (green)
	draw_rect(Rect2(SPAWN_CELL.x * CELL_SIZE, SPAWN_CELL.y * CELL_SIZE, CELL_SIZE, CELL_SIZE), Color.GREEN, true)

	# Exit cell (red)
	draw_rect(Rect2(EXIT_CELL.x * CELL_SIZE, EXIT_CELL.y * CELL_SIZE, CELL_SIZE, CELL_SIZE), Color.RED, true)

	# Tower cells (steel blue)
	for cell: Vector2i in _towers:
		draw_rect(Rect2(cell.x * CELL_SIZE, cell.y * CELL_SIZE, CELL_SIZE, CELL_SIZE), Color.STEEL_BLUE, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := world_to_grid(get_global_mouse_position())
		try_place_tower(cell)


func try_place_tower(cell: Vector2i) -> bool:
	# Validate bounds
	if cell.x < 0 or cell.x >= GRID_COLS or cell.y < 0 or cell.y >= GRID_ROWS:
		return false
	# Can't place on spawn or exit
	if cell == SPAWN_CELL or cell == EXIT_CELL:
		return false
	# Can't place where tower already exists
	if _towers.has(cell):
		return false

	# Temporarily mark solid and test path
	_astar.set_point_solid(cell, true)
	var path := _astar.get_point_path(SPAWN_CELL, EXIT_CELL)
	if path.is_empty():
		# Would block — revert
		_astar.set_point_solid(cell, false)
		return false

	# Commit placement
	_towers[cell] = true
	queue_redraw()
	grid_changed.emit()
	return true


func get_enemy_path_from_cell(cell: Vector2i) -> PackedVector2Array:
	if _astar.is_point_solid(cell):
		return PackedVector2Array()
	var path := _astar.get_point_path(cell, EXIT_CELL)
	return path


func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5, cell.y * CELL_SIZE + CELL_SIZE * 0.5)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x) / CELL_SIZE, int(world_pos.y) / CELL_SIZE)
