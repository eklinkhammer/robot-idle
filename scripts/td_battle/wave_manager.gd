extends Node
## Spawns waves of enemies at timed intervals.

const EnemyScene := preload("res://scenes/td_battle/enemy.tscn")

signal battle_won
signal battle_lost

var current_wave: int = 0
var total_waves: int = 5
var spawn_interval: float = 0.5
var gold: int = 100
var lives: int = 20

var _spawned_count: int = 0
var _active_enemies: int = 0
var _spawning: bool = false
var _spawn_timer: float = 0.0
var _battle_over: bool = false
var _spawn_queue: Array[String] = []
var _wave_data: Array = []
var _spawn_cells: Array[Vector2i] = [Vector2i(0, 5)]
var _spawn_index: int = 0  # Round-robin index for multi-spawn
var _lives_at_wave_start: int = 20

@onready var _grid_manager: Node2D = get_parent().get_node("GridManager")
@onready var _enemies_container: Node2D = get_parent().get_node("Enemies")
@onready var _button: Button = get_parent().get_node("UILayer/HBoxContainer/SendWaveButton")
@onready var _label: Label = get_parent().get_node("UILayer/HBoxContainer/WaveLabel")
@onready var _gold_label: Label = get_parent().get_node("UILayer/HBoxContainer/GoldLabel")
@onready var _lives_label: Label = get_parent().get_node("UILayer/HBoxContainer/LivesLabel")
@onready var _end_label: Label = get_parent().get_node("UILayer/EndLabel")


func configure(map_data: RefCounted) -> void:
	gold = map_data.starting_gold
	lives = map_data.starting_lives
	_wave_data = map_data.waves.duplicate()
	total_waves = _wave_data.size()
	_spawn_cells = map_data.spawn_cells.duplicate()
	current_wave = 0
	_battle_over = false
	_spawning = false
	_active_enemies = 0
	_spawn_index = 0


func _ready() -> void:
	_button.pressed.connect(_on_send_wave_pressed)


func _process(delta: float) -> void:
	if not _spawning:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _spawned_count < _spawn_queue.size():
		_spawn_enemy(_spawn_queue[_spawned_count])
		_spawned_count += 1
		_spawn_timer = spawn_interval

		if _spawned_count >= _spawn_queue.size():
			_spawning = false


func _on_send_wave_pressed() -> void:
	if _spawning or _battle_over:
		return
	current_wave += 1
	_label.text = "Wave: %d / %d" % [current_wave, total_waves]
	_button.disabled = true
	_spawned_count = 0
	_spawning = true
	_spawn_timer = 0.0
	_spawn_index = 0
	_lives_at_wave_start = lives

	# Build spawn queue from wave data and shuffle
	_spawn_queue.clear()
	var data: Dictionary = _wave_data[current_wave - 1]
	for i in data.get("normal", 0):
		_spawn_queue.append("normal")
	for i in data.get("fast", 0):
		_spawn_queue.append("fast")
	for i in data.get("armored", 0):
		_spawn_queue.append("armored")
	_spawn_queue.shuffle()


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend_gold(amount: int) -> void:
	gold -= amount
	_update_gold_label()


func add_gold(amount: int) -> void:
	gold += amount
	_update_gold_label()


func _update_gold_label() -> void:
	_gold_label.text = "Gold: %d" % gold


func _update_ui() -> void:
	_label.text = "Wave: %d / %d" % [current_wave, total_waves]
	_gold_label.text = "Gold: %d" % gold
	_lives_label.text = "Lives: %d" % lives


func _spawn_enemy(type: String = "normal") -> void:
	var enemy: Node2D = EnemyScene.instantiate()
	# Round-robin through spawn cells
	var spawn_cell: Vector2i = _spawn_cells[_spawn_index % _spawn_cells.size()]
	_spawn_index += 1
	enemy.global_position = _grid_manager.grid_to_world(spawn_cell)
	_enemies_container.add_child(enemy)
	enemy.initialize(_grid_manager, type)
	enemy.tree_exiting.connect(_on_enemy_finished)
	enemy.reached_exit.connect(_on_enemy_reached_exit)
	_active_enemies += 1


func _on_enemy_reached_exit() -> void:
	lives -= 1
	_lives_label.text = "Lives: %d" % lives
	if lives <= 0 and not _battle_over:
		_battle_over = true
		_spawning = false
		_button.disabled = true
		_end_label.text = "Defeated!"
		_end_label.visible = true
		battle_lost.emit()


func _on_enemy_finished() -> void:
	_active_enemies -= 1
	if _active_enemies <= 0:
		_active_enemies = 0
		if _battle_over:
			return
		if current_wave >= total_waves and not _spawning:
			_battle_over = true
			_button.disabled = true
			_end_label.text = "Victory!"
			_end_label.visible = true
			battle_won.emit()
		elif not _spawning:
			# Wave cleared — award gold + 1g per life lost this wave
			var wave_gold: int = _wave_data[current_wave - 1].get("gold", 0)
			var lives_lost: int = _lives_at_wave_start - lives
			wave_gold += lives_lost
			if wave_gold > 0:
				add_gold(wave_gold)
			_button.disabled = false
