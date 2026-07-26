extends Node2D
## Enemy that follows waypoints from GridManager's AStarGrid2D.

signal reached_exit

var speed: float = 100.0

var _grid_manager: Node2D
var _path: PackedVector2Array
var _path_index: int = 0
var _needs_repath: bool = false


func initialize(grid_manager: Node2D) -> void:
	_grid_manager = grid_manager
	_grid_manager.grid_changed.connect(_on_grid_changed)
	_recalculate_path()


func _recalculate_path() -> void:
	var cell: Vector2i = _grid_manager.world_to_grid(global_position)
	var new_path: PackedVector2Array = _grid_manager.get_enemy_path_from_cell(cell)
	if not new_path.is_empty():
		_path = new_path
		_path_index = 0
		# Skip the first waypoint if we're already close to it
		if _path.size() > 1 and global_position.distance_to(_path[0]) < 4.0:
			_path_index = 1
	_needs_repath = false


func _process(delta: float) -> void:
	if _path.is_empty() or _path_index >= _path.size():
		return

	var target := _path[_path_index]
	var direction := (target - global_position).normalized()
	var step := speed * delta

	if global_position.distance_to(target) <= step:
		global_position = target
		_path_index += 1

		# Repath at waypoint boundaries if grid changed
		if _needs_repath:
			_recalculate_path()
			return

		# Check if reached end of path
		if _path_index >= _path.size():
			reached_exit.emit()
			queue_free()
			return
	else:
		global_position += direction * step


func _draw() -> void:
	draw_circle(Vector2.ZERO, 24.0, Color.ORANGE)


func _on_grid_changed() -> void:
	_needs_repath = true
