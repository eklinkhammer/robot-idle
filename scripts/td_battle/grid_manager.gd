extends Node2D
## Owns the AStarGrid2D, draws the grid, handles tower placement, and provides path queries.

signal grid_changed

const GRID_COLS: int = 20
const GRID_ROWS: int = 11
const CELL_SIZE: int = 64
const SPAWN_CELL: Vector2i = Vector2i(0, 5)
const EXIT_CELL: Vector2i = Vector2i(19, 5)
const TowerScript: GDScript = preload("res://scripts/td_battle/tower.gd")

const TOWER_TYPES: Dictionary = {
	"peasant": {
		"damage": 8.0,
		"range": 80.0,
		"fire_rate": 4.0,
		"aoe_radius": 0.0,
		"cost": 10,
		"refund": 5,
		"color": Color(0.96, 0.64, 0.38),  # Sandy Brown
	},
	"archer": {
		"damage": 40.0,
		"range": 224.0,
		"fire_rate": 0.6,
		"aoe_radius": 0.0,
		"cost": 25,
		"refund": 12,
		"color": Color(0.13, 0.55, 0.13),  # Forest Green
	},
	"catapult": {
		"damage": 25.0,
		"range": 224.0,
		"fire_rate": 0.4,
		"aoe_radius": 80.0,
		"cost": 40,
		"refund": 20,
		"color": Color(0.44, 0.50, 0.56),  # Slate Gray
	},
}

var selected_tower_type: String = "peasant"

var _astar: AStarGrid2D
var _towers: Dictionary = {}  # Dictionary[Vector2i, {"node": Node2D, "type": String}]
var _blocked_cell: Vector2i
var _blocked_timer: float = 0.0
var _popup: PopupMenu
var _popup_cell: Vector2i

@onready var _wave_manager: Node = get_parent().get_node("WaveManager")


func _ready() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, GRID_COLS, GRID_ROWS)
	_astar.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()

	_popup = PopupMenu.new()
	_popup.add_item("Remove (Refund)", 0)
	_popup.id_pressed.connect(_on_popup_id_pressed)
	add_child(_popup)

	# Connect tower selection buttons
	var hbox: HBoxContainer = get_parent().get_node("UILayer/HBoxContainer")
	var peasant_btn: Button = hbox.get_node("PeasantButton")
	var archer_btn: Button = hbox.get_node("ArcherButton")
	var catapult_btn: Button = hbox.get_node("CatapultButton")
	peasant_btn.pressed.connect(_on_tower_type_selected.bind("peasant"))
	archer_btn.pressed.connect(_on_tower_type_selected.bind("archer"))
	catapult_btn.pressed.connect(_on_tower_type_selected.bind("catapult"))


func _process(delta: float) -> void:
	if _blocked_timer > 0.0:
		_blocked_timer -= delta
		if _blocked_timer <= 0.0:
			queue_redraw()


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

	# Tower cells (per-type color)
	for cell: Vector2i in _towers:
		var tower_data: Dictionary = _towers[cell]
		var tower_color: Color = TOWER_TYPES[tower_data["type"]]["color"]
		draw_rect(Rect2(cell.x * CELL_SIZE, cell.y * CELL_SIZE, CELL_SIZE, CELL_SIZE), tower_color, true)

	# Blocked-placement flash (translucent red)
	if _blocked_timer > 0.0:
		draw_rect(Rect2(_blocked_cell.x * CELL_SIZE, _blocked_cell.y * CELL_SIZE, CELL_SIZE, CELL_SIZE), Color(1, 0, 0, 0.5), true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := world_to_grid(get_global_mouse_position())
		if _towers.has(cell):
			_popup_cell = cell
			var tower_data: Dictionary = _towers[cell]
			var refund: int = TOWER_TYPES[tower_data["type"]]["refund"]
			_popup.set_item_text(0, "Remove (Refund %dg)" % refund)
			_popup.position = Vector2i(get_viewport().get_mouse_position())
			_popup.popup()
		else:
			try_place_tower(cell)

	# Keyboard shortcuts for tower selection
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_on_tower_type_selected("peasant")
				_update_button_toggle("peasant")
			KEY_2:
				_on_tower_type_selected("archer")
				_update_button_toggle("archer")
			KEY_3:
				_on_tower_type_selected("catapult")
				_update_button_toggle("catapult")


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

	var type_data: Dictionary = TOWER_TYPES[selected_tower_type]
	var cost: int = type_data["cost"]

	# Can't afford
	if not _wave_manager.can_afford(cost):
		_blocked_cell = cell
		_blocked_timer = 0.3
		queue_redraw()
		return false

	# Temporarily mark solid and test path
	_astar.set_point_solid(cell, true)
	var path := _astar.get_point_path(SPAWN_CELL, EXIT_CELL)
	if path.is_empty():
		# Would block — revert and flash
		_astar.set_point_solid(cell, false)
		_blocked_cell = cell
		_blocked_timer = 0.3
		queue_redraw()
		return false

	# Commit placement
	_wave_manager.spend_gold(cost)
	var tower := Node2D.new()
	tower.set_script(TowerScript)
	tower.tower_type = selected_tower_type
	tower.damage = type_data["damage"]
	tower.fire_range = type_data["range"]
	tower.fire_rate = type_data["fire_rate"]
	tower.aoe_radius = type_data["aoe_radius"]
	tower.position = grid_to_world(cell)
	add_child(tower)
	_towers[cell] = {"node": tower, "type": selected_tower_type}
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


func _on_popup_id_pressed(id: int) -> void:
	if id == 0:
		var tower_data: Dictionary = _towers[_popup_cell]
		var tower: Node2D = tower_data["node"]
		var refund: int = TOWER_TYPES[tower_data["type"]]["refund"]
		if tower:
			tower.queue_free()
		_towers.erase(_popup_cell)
		_astar.set_point_solid(_popup_cell, false)
		_wave_manager.add_gold(refund)
		queue_redraw()
		grid_changed.emit()


func _on_tower_type_selected(type: String) -> void:
	selected_tower_type = type


func _update_button_toggle(type: String) -> void:
	var hbox: HBoxContainer = get_parent().get_node("UILayer/HBoxContainer")
	var buttons := {
		"peasant": hbox.get_node("PeasantButton") as Button,
		"archer": hbox.get_node("ArcherButton") as Button,
		"catapult": hbox.get_node("CatapultButton") as Button,
	}
	for t: String in buttons:
		(buttons[t] as Button).button_pressed = (t == type)
