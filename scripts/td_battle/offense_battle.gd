extends Node2D
## Battle orchestrator for offense (PvE attack) mode.
## Player draws paths through a fortress and sends units to reach the exit.

const FortressGenerator := preload("res://scripts/td_battle/fortress_generator.gd")
const EnemyScene: PackedScene = preload("res://scenes/td_battle/enemy.tscn")

enum Phase { DRAW_PATHS, ASSIGN_UNITS, BATTLE, DONE }

var _fortress: RefCounted
var _phase: int = Phase.DRAW_PATHS
var _units_reached_exit: int = 0
var _active_enemies: int = 0
var _spawning: bool = false
var _spawn_queues: Array[Array] = []
var _spawn_paths: Array[PackedVector2Array] = []
var _spawn_timers: Array[float] = []
var _spawn_indices: Array[int] = []
var _spawn_interval: float = 0.5

# Ordered spawn queues per path — each is Array[String] of unit types in spawn order
var _unit_queues: Array[Array] = []

@onready var _grid_manager: Node2D = $GridManager
@onready var _path_drawer: Node2D = $PathDrawer
@onready var _enemies_container: Node2D = $Enemies
@onready var _phase_label: Label = $UILayer/TopBar/HBox/PhaseLabel
@onready var _instruction_label: Label = $UILayer/TopBar/HBox/InstructionLabel
@onready var _budget_label: Label = $UILayer/TopBar/HBox/BudgetLabel
@onready var _launch_btn: Button = $UILayer/TopBar/HBox/LaunchButton
@onready var _side_panel: PanelContainer = $UILayer/SidePanel
@onready var _alloc_container: VBoxContainer = $UILayer/SidePanel/ScrollContainer/AllocPanel
@onready var _end_label: Label = $UILayer/EndLabel
@onready var _end_buttons: HBoxContainer = $UILayer/EndButtons

const PROFILE_DISPLAY: Dictionary = {
	"anti_single": {"name": "Archers", "weak": "Fast", "strong": "Normal/Armored"},
	"anti_swarm": {"name": "Catapults", "weak": "Armored", "strong": "Normal/Fast"},
	"light": {"name": "Light", "weak": "-", "strong": "-"},
}

const PATH_COLORS: Array = [
	Color(0.2, 0.7, 1.0),
	Color(1.0, 0.6, 0.2),
	Color(0.4, 1.0, 0.4),
]

const UNIT_COLORS: Dictionary = {
	"normal": Color.ORANGE,
	"fast": Color(0.68, 0.85, 0.0),
	"armored": Color(0.5, 0.5, 0.55),
}

const UNIT_LETTERS: Dictionary = {
	"normal": "N",
	"fast": "F",
	"armored": "A",
}


func _ready() -> void:
	if GameState.offense_seed == -1:
		GameState.offense_seed = randi()
	_fortress = FortressGenerator.generate(GameState.offense_difficulty, GameState.offense_seed)

	_grid_manager.configure_fortress(_fortress)
	_grid_manager.queue_redraw()

	_path_drawer.configure(_fortress)
	_path_drawer.paths_changed.connect(_on_paths_changed)

	_unit_queues.clear()
	for _i in range(_fortress.entry_cells.size()):
		_unit_queues.append([])

	_side_panel.visible = false
	_launch_btn.text = "Confirm Paths"
	_launch_btn.disabled = true
	_launch_btn.pressed.connect(_on_action_pressed)
	$UILayer/EndButtons/RestartButton.pressed.connect(_on_restart_pressed)
	$UILayer/EndButtons/MainMenuButton.pressed.connect(_on_main_menu_pressed)

	_update_ui()


func _on_action_pressed() -> void:
	match _phase:
		Phase.DRAW_PATHS:
			_enter_assign_phase()
		Phase.ASSIGN_UNITS:
			_enter_battle_phase()


func _enter_assign_phase() -> void:
	_phase = Phase.ASSIGN_UNITS
	_path_drawer.set_process_unhandled_input(false)

	_build_alloc_ui()
	_side_panel.visible = true

	_launch_btn.text = "Launch Attack"
	_launch_btn.disabled = true
	_update_ui()


func _enter_battle_phase() -> void:
	_phase = Phase.BATTLE
	_launch_btn.disabled = true
	_side_panel.visible = false

	_spawn_queues.clear()
	_spawn_paths.clear()
	_spawn_timers.clear()
	_spawn_indices.clear()

	for i in range(_path_drawer.paths.size()):
		if not _path_drawer.is_path_complete(i):
			continue
		var queue: Array = _unit_queues[i]
		if queue.is_empty():
			continue

		# Use the player's chosen order directly
		var typed_queue: Array[String] = []
		for unit_type: String in queue:
			typed_queue.append(unit_type)

		_spawn_queues.append(typed_queue)
		_spawn_paths.append(_path_drawer.get_path_world_points(i))
		_spawn_timers.append(0.0)
		_spawn_indices.append(0)

	_spawning = true
	_update_ui()


func _get_total_units() -> int:
	var total: int = 0
	for q: Array in _unit_queues:
		total += q.size()
	return total


func _build_alloc_ui() -> void:
	for child: Node in _alloc_container.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "Assign Units"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	_alloc_container.add_child(title)

	var hint := Label.new()
	hint.text = "Click unit buttons to add\nthem to the spawn queue.\nThey deploy in this order."
	hint.add_theme_font_size_override("font_size", 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_alloc_container.add_child(hint)

	_alloc_container.add_child(HSeparator.new())

	for i in range(_fortress.lanes.size()):
		if not _path_drawer.is_path_complete(i):
			continue

		var lane: Dictionary = _fortress.lanes[i]
		var profile_info: Dictionary = PROFILE_DISPLAY[lane["profile"]]
		var path_color: Color = PATH_COLORS[i % PATH_COLORS.size()]

		# Path header
		var header := Label.new()
		header.text = "Path %d" % [i + 1]
		header.add_theme_color_override("font_color", path_color)
		header.add_theme_font_size_override("font_size", 14)
		_alloc_container.add_child(header)

		# Lane info
		var info := Label.new()
		info.text = "  Towers: %s | Weak vs: %s" % [profile_info["name"], profile_info["weak"]]
		info.add_theme_font_size_override("font_size", 11)
		_alloc_container.add_child(info)

		# Add unit buttons row
		var btn_hbox := HBoxContainer.new()
		btn_hbox.add_theme_constant_override("separation", 4)
		for unit_type: String in ["normal", "fast", "armored"]:
			var btn := Button.new()
			btn.text = "+ %s" % UNIT_LETTERS[unit_type]
			btn.tooltip_text = "Add %s unit" % unit_type
			btn.custom_minimum_size = Vector2(50, 28)
			btn.add_theme_color_override("font_color", UNIT_COLORS[unit_type])
			btn.pressed.connect(_on_add_unit.bind(i, unit_type))
			btn_hbox.add_child(btn)

		var undo_btn := Button.new()
		undo_btn.text = "Undo"
		undo_btn.custom_minimum_size = Vector2(46, 28)
		undo_btn.pressed.connect(_on_undo_unit.bind(i))
		btn_hbox.add_child(undo_btn)

		_alloc_container.add_child(btn_hbox)

		# Queue display — shows ordered list of unit letters
		var queue_label := Label.new()
		queue_label.name = "Queue_%d" % i
		queue_label.add_theme_font_size_override("font_size", 12)
		queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		queue_label.custom_minimum_size.x = 200
		_alloc_container.add_child(queue_label)

		if i < _fortress.lanes.size() - 1:
			_alloc_container.add_child(HSeparator.new())

	_refresh_queue_labels()


func _on_add_unit(path_idx: int, unit_type: String) -> void:
	if _get_total_units() >= _fortress.unit_budget:
		return
	_unit_queues[path_idx].append(unit_type)
	_refresh_queue_labels()
	_update_ui()


func _on_undo_unit(path_idx: int) -> void:
	if _unit_queues[path_idx].is_empty():
		return
	_unit_queues[path_idx].pop_back()
	_refresh_queue_labels()
	_update_ui()


func _refresh_queue_labels() -> void:
	for i in range(_fortress.lanes.size()):
		var lbl: Label = _alloc_container.find_child("Queue_%d" % i, true, false)
		if lbl == null:
			continue
		var queue: Array = _unit_queues[i]
		if queue.is_empty():
			lbl.text = "  (empty)"
		else:
			var parts: PackedStringArray = PackedStringArray()
			for unit_type: String in queue:
				parts.append(UNIT_LETTERS[unit_type])
			lbl.text = "  " + " ".join(parts) + "  (%d)" % queue.size()


func _update_ui() -> void:
	var total: int = _get_total_units()
	_budget_label.text = "Units: %d / %d" % [total, _fortress.unit_budget]

	match _phase:
		Phase.DRAW_PATHS:
			_phase_label.text = "STEP 1"
			var complete: int = _path_drawer.get_complete_path_count()
			if complete == 0:
				_instruction_label.text = "Click a green entry cell (left edge) to start a path. Draw to the red exit (right edge). Right-click to undo."
			else:
				_instruction_label.text = "%d path(s) drawn. Draw more or click Confirm." % complete
			_launch_btn.disabled = (complete == 0)

		Phase.ASSIGN_UNITS:
			_phase_label.text = "STEP 2"
			_instruction_label.text = "Add units to each path's queue. They spawn left-to-right in the order shown."
			_launch_btn.disabled = (total == 0)

		Phase.BATTLE:
			_phase_label.text = "BATTLE"
			_instruction_label.text = "Units reached exit: %d / %d needed to win" % [_units_reached_exit, _fortress.win_threshold]

		Phase.DONE:
			_phase_label.text = ""
			_instruction_label.text = ""


func _on_paths_changed() -> void:
	_update_ui()


func _process(delta: float) -> void:
	if not _spawning:
		return

	var all_done := true
	for qi in range(_spawn_queues.size()):
		if _spawn_indices[qi] >= _spawn_queues[qi].size():
			continue
		all_done = false
		_spawn_timers[qi] -= delta
		if _spawn_timers[qi] <= 0.0:
			_spawn_one(qi)
			_spawn_indices[qi] += 1
			_spawn_timers[qi] = _spawn_interval

	if all_done:
		_spawning = false


func _spawn_one(queue_index: int) -> void:
	var unit_type: String = _spawn_queues[queue_index][_spawn_indices[queue_index]]
	var path: PackedVector2Array = _spawn_paths[queue_index]

	var enemy: Node2D = EnemyScene.instantiate()
	enemy.global_position = path[0]
	_enemies_container.add_child(enemy)
	enemy.initialize_fixed_path(path, unit_type)
	enemy.reached_exit.connect(_on_unit_reached_exit)
	enemy.tree_exiting.connect(_on_unit_finished)
	_active_enemies += 1


func _on_unit_reached_exit() -> void:
	_units_reached_exit += 1
	_update_ui()
	if _units_reached_exit >= _fortress.win_threshold and _phase == Phase.BATTLE:
		_end_battle(true)


func _on_unit_finished() -> void:
	_active_enemies -= 1
	if _active_enemies <= 0 and not _spawning and _phase == Phase.BATTLE:
		_active_enemies = 0
		if _units_reached_exit < _fortress.win_threshold:
			_end_battle(false)


func _end_battle(won: bool) -> void:
	_phase = Phase.DONE
	_spawning = false
	if won:
		_end_label.text = "Victory!"
		GameState.mark_beaten("offense_%d" % _fortress.difficulty)
		if _fortress.difficulty > GameState.highest_offense_difficulty_beaten:
			GameState.highest_offense_difficulty_beaten = _fortress.difficulty
	else:
		_end_label.text = "Defeated! (%d / %d)" % [_units_reached_exit, _fortress.win_threshold]
	_end_label.visible = true
	_end_buttons.visible = true
	_update_ui()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	GameState.offense_seed = -1
	get_tree().change_scene_to_file("res://scenes/main.tscn")
