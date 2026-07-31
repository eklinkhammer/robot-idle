extends Node2D
## Enemy that follows waypoints from GridManager's AStarGrid2D.

signal reached_exit
signal died

var enemy_type: String = "normal"
var speed: float = 100.0
var hp: float = 100.0
var max_hp: float = 100.0

var _grid_manager: Node2D
var _path: PackedVector2Array
var _path_index: int = 0
var _needs_repath: bool = false
var _radius: float = 24.0
var _fixed_path: bool = false  # When true, follow pre-drawn path without repathing


func _ready() -> void:
	add_to_group("enemies")


func initialize(grid_manager: Node2D, type: String = "normal") -> void:
	_grid_manager = grid_manager
	enemy_type = type
	_apply_type_stats()
	_grid_manager.grid_changed.connect(_on_grid_changed)
	_recalculate_path()


func initialize_fixed_path(path: PackedVector2Array, type: String = "normal") -> void:
	_fixed_path = true
	enemy_type = type
	_apply_type_stats()
	_path = path
	_path_index = 0
	if _path.size() > 1 and global_position.distance_to(_path[0]) < 4.0:
		_path_index = 1


func _apply_type_stats() -> void:
	match enemy_type:
		"fast":
			speed = 200.0
			hp = 50.0
			max_hp = 50.0
		"armored":
			speed = 100.0
			hp = 300.0
			max_hp = 300.0
			_radius = 28.0
		_:  # normal
			speed = 100.0
			hp = 100.0
			max_hp = 100.0


func take_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		died.emit()
		queue_free()


func _recalculate_path() -> void:
	if _fixed_path:
		_needs_repath = false
		return
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
	var color: Color
	match enemy_type:
		"fast":
			color = Color(0.68, 0.85, 0.0)
		"armored":
			color = Color(0.35, 0.35, 0.40)
		_:
			color = Color.ORANGE
	draw_circle(Vector2.ZERO, _radius, color)
	# HP bar
	var bar_width: float = 32.0
	var bar_height: float = 4.0
	var bar_offset := Vector2(-bar_width * 0.5, -(_radius + 8.0))
	draw_rect(Rect2(bar_offset, Vector2(bar_width, bar_height)), Color(0.2, 0.2, 0.2))
	var hp_ratio: float = clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(bar_offset, Vector2(bar_width * hp_ratio, bar_height)), Color.GREEN)


func _on_grid_changed() -> void:
	if not _fixed_path:
		_needs_repath = true
