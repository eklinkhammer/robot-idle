extends Node2D
## Owns the AStarGrid2D, draws the grid, handles tower placement/upgrades, and provides path queries.

signal grid_changed

const TowerScript: GDScript = preload("res://scripts/td_battle/tower.gd")

const TOWER_TYPES: Dictionary = {
	"peasant": {
		"damage": 8.0,
		"range": 96.0,
		"fire_rate": 4.0,
		"aoe_radius": 0.0,
		"cost": 10,
		"refund": 5,
		"color": Color(0.96, 0.64, 0.38),
	},
	"archer": {
		"damage": 40.0,
		"range": 224.0,
		"fire_rate": 0.6,
		"aoe_radius": 0.0,
		"cost": 25,
		"refund": 12,
		"color": Color(0.13, 0.55, 0.13),
	},
	"catapult": {
		"damage": 25.0,
		"range": 224.0,
		"fire_rate": 0.4,
		"aoe_radius": 80.0,
		"cost": 40,
		"refund": 20,
		"color": Color(0.44, 0.50, 0.56),
	},
}

const TOWER_UPGRADES: Dictionary = {
	"peasant": {
		"damage": 14.0,
		"fire_rate": 5.5,
		"range": 96.0,
		"aoe_radius": 0.0,
		"cost": 15,
		"refund": 12,
	},
	"archer": {
		"damage": 65.0,
		"range": 288.0,
		"fire_rate": 0.6,
		"aoe_radius": 0.0,
		"cost": 35,
		"refund": 30,
	},
	"catapult": {
		"damage": 40.0,
		"range": 224.0,
		"fire_rate": 0.4,
		"aoe_radius": 112.0,
		"cost": 50,
		"refund": 45,
	},
}

var selected_tower_type: String = "peasant"
var upgrade_cap: int = -1  # -1 = unlimited

var grid_cols: int = 20
var grid_rows: int = 11
var cell_size: int = 64
var spawn_cells: Array[Vector2i] = [Vector2i(0, 5)]
var exit_cell: Vector2i = Vector2i(19, 5)
var obstacles: Array[Vector2i] = []

var _astar: AStarGrid2D
# Dictionary[Vector2i, {"node": Node2D, "type": String, "upgraded": bool}]
var _towers: Dictionary = {}
var _blocked_cell: Vector2i
var _blocked_timer: float = 0.0
var _popup: PopupMenu
var _popup_cell: Vector2i

var _wave_manager: Node


func configure(map_data: RefCounted) -> void:
	grid_cols = map_data.grid_cols
	grid_rows = map_data.grid_rows
	cell_size = map_data.cell_size
	spawn_cells = map_data.spawn_cells.duplicate()
	exit_cell = map_data.exit_cell
	obstacles = map_data.obstacles.duplicate()
	_setup_astar()


func set_wave_manager(wm: Node) -> void:
	_wave_manager = wm


func _setup_astar() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, grid_cols, grid_rows)
	_astar.cell_size = Vector2(cell_size, cell_size)
	_astar.offset = Vector2(cell_size * 0.5, cell_size * 0.5)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	# Mark obstacles as solid
	for obs: Vector2i in obstacles:
		_astar.set_point_solid(obs, true)


func _ready() -> void:
	_popup = PopupMenu.new()
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
	for x in range(grid_cols + 1):
		draw_line(Vector2(x * cell_size, 0), Vector2(x * cell_size, grid_rows * cell_size), grid_color)
	for y in range(grid_rows + 1):
		draw_line(Vector2(0, y * cell_size), Vector2(grid_cols * cell_size, y * cell_size), grid_color)

	# Spawn cells (green)
	for sc: Vector2i in spawn_cells:
		draw_rect(Rect2(sc.x * cell_size, sc.y * cell_size, cell_size, cell_size), Color.GREEN, true)

	# Exit cell (red)
	draw_rect(Rect2(exit_cell.x * cell_size, exit_cell.y * cell_size, cell_size, cell_size), Color.RED, true)

	# Obstacle cells (dark brown)
	for obs: Vector2i in obstacles:
		draw_rect(Rect2(obs.x * cell_size, obs.y * cell_size, cell_size, cell_size), Color(0.3, 0.2, 0.1), true)

	# Tower cells
	for cell: Vector2i in _towers:
		var tower_data: Dictionary = _towers[cell]
		var tower_color: Color = TOWER_TYPES[tower_data["type"]]["color"]
		if tower_data["upgraded"]:
			tower_color = tower_color.lightened(0.25)
		draw_rect(Rect2(cell.x * cell_size, cell.y * cell_size, cell_size, cell_size), tower_color, true)
		# Diamond marker for upgraded towers
		if tower_data["upgraded"]:
			var center := Vector2(cell.x * cell_size + cell_size * 0.5, cell.y * cell_size + cell_size * 0.5)
			var s: float = 8.0
			var diamond := PackedVector2Array([
				center + Vector2(0, -s), center + Vector2(s, 0),
				center + Vector2(0, s), center + Vector2(-s, 0),
			])
			draw_colored_polygon(diamond, Color.WHITE)

	# Blocked-placement flash
	if _blocked_timer > 0.0:
		draw_rect(Rect2(_blocked_cell.x * cell_size, _blocked_cell.y * cell_size, cell_size, cell_size), Color(1, 0, 0, 0.5), true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := world_to_grid(get_global_mouse_position())
		if _towers.has(cell):
			_show_tower_popup(cell)
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


func _show_tower_popup(cell: Vector2i) -> void:
	_popup_cell = cell
	_popup.clear()
	var tower_data: Dictionary = _towers[cell]
	var tower_type: String = tower_data["type"]

	# Upgrade option (if not already upgraded and upgrade_cap allows)
	if not tower_data["upgraded"] and TOWER_UPGRADES.has(tower_type):
		if upgrade_cap < 0 or true:  # unlimited for now
			var upgrade_cost: int = TOWER_UPGRADES[tower_type]["cost"]
			_popup.add_item("Upgrade (%dg)" % upgrade_cost, 1)

	# Remove option
	var refund: int
	if tower_data["upgraded"]:
		refund = TOWER_UPGRADES[tower_type]["refund"]
	else:
		refund = TOWER_TYPES[tower_type]["refund"]
	_popup.add_item("Remove (%dg)" % refund, 0)

	_popup.position = Vector2i(get_viewport().get_mouse_position())
	_popup.popup()


func try_place_tower(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= grid_cols or cell.y < 0 or cell.y >= grid_rows:
		return false
	# Can't place on spawn, exit, or obstacles
	for sc: Vector2i in spawn_cells:
		if cell == sc:
			return false
	if cell == exit_cell:
		return false
	if cell in obstacles:
		return false
	if _towers.has(cell):
		return false

	var type_data: Dictionary = TOWER_TYPES[selected_tower_type]
	var cost: int = type_data["cost"]

	if not _wave_manager.can_afford(cost):
		_blocked_cell = cell
		_blocked_timer = 0.3
		queue_redraw()
		return false

	# Temporarily mark solid and test all spawn→exit paths
	_astar.set_point_solid(cell, true)
	if not _all_paths_valid():
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
	_towers[cell] = {"node": tower, "type": selected_tower_type, "upgraded": false}
	queue_redraw()
	grid_changed.emit()
	return true


func try_upgrade_tower(cell: Vector2i) -> bool:
	if not _towers.has(cell):
		return false
	var tower_data: Dictionary = _towers[cell]
	if tower_data["upgraded"]:
		return false
	var tower_type: String = tower_data["type"]
	if not TOWER_UPGRADES.has(tower_type):
		return false

	var upgrade: Dictionary = TOWER_UPGRADES[tower_type]
	var cost: int = upgrade["cost"]
	if not _wave_manager.can_afford(cost):
		_blocked_cell = cell
		_blocked_timer = 0.3
		queue_redraw()
		return false

	_wave_manager.spend_gold(cost)
	var tower: Node2D = tower_data["node"]
	tower.apply_upgrade(upgrade["damage"], upgrade["range"], upgrade["fire_rate"], upgrade["aoe_radius"])
	tower_data["upgraded"] = true
	_towers[cell] = tower_data
	queue_redraw()
	return true


func _all_paths_valid() -> bool:
	for sc: Vector2i in spawn_cells:
		var path := _astar.get_point_path(sc, exit_cell)
		if path.is_empty():
			return false
	return true


func get_enemy_path_from_cell(cell: Vector2i) -> PackedVector2Array:
	if _astar.is_point_solid(cell):
		return PackedVector2Array()
	var path := _astar.get_point_path(cell, exit_cell)
	return path


func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * cell_size + cell_size * 0.5, cell.y * cell_size + cell_size * 0.5)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / cell_size), floori(world_pos.y / cell_size))


func _on_popup_id_pressed(id: int) -> void:
	match id:
		0:  # Remove
			var tower_data: Dictionary = _towers[_popup_cell]
			var tower: Node2D = tower_data["node"]
			var tower_type: String = tower_data["type"]
			var refund: int
			if tower_data["upgraded"]:
				refund = TOWER_UPGRADES[tower_type]["refund"]
			else:
				refund = TOWER_TYPES[tower_type]["refund"]
			if tower:
				tower.queue_free()
			_towers.erase(_popup_cell)
			_astar.set_point_solid(_popup_cell, false)
			_wave_manager.add_gold(refund)
			queue_redraw()
			grid_changed.emit()
		1:  # Upgrade
			try_upgrade_tower(_popup_cell)


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
