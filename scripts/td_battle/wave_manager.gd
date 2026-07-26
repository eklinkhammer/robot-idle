extends Node
## Spawns waves of enemies at timed intervals.

const EnemyScene := preload("res://scenes/td_battle/enemy.tscn")

var current_wave: int = 0
var total_waves: int = 5
var enemies_per_wave: int = 5
var spawn_interval: float = 0.5
var gold: int = 100

var _spawned_count: int = 0
var _active_enemies: int = 0
var _spawning: bool = false
var _spawn_timer: float = 0.0

@onready var _grid_manager: Node2D = get_parent().get_node("GridManager")
@onready var _enemies_container: Node2D = get_parent().get_node("Enemies")
@onready var _button: Button = get_parent().get_node("UILayer/HBoxContainer/SendWaveButton")
@onready var _label: Label = get_parent().get_node("UILayer/HBoxContainer/WaveLabel")
@onready var _gold_label: Label = get_parent().get_node("UILayer/HBoxContainer/GoldLabel")


func _ready() -> void:
	_button.pressed.connect(_on_send_wave_pressed)


func _process(delta: float) -> void:
	if not _spawning:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _spawned_count < enemies_per_wave:
		_spawn_enemy()
		_spawned_count += 1
		_spawn_timer = spawn_interval

		if _spawned_count >= enemies_per_wave:
			_spawning = false


func _on_send_wave_pressed() -> void:
	if _spawning:
		return
	current_wave += 1
	_label.text = "Wave: %d / %d" % [current_wave, total_waves]
	_button.disabled = true
	_spawned_count = 0
	_spawning = true
	_spawn_timer = 0.0  # Spawn first enemy immediately


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


func _spawn_enemy() -> void:
	var enemy: Node2D = EnemyScene.instantiate()
	enemy.global_position = _grid_manager.grid_to_world(_grid_manager.SPAWN_CELL)
	_enemies_container.add_child(enemy)
	enemy.initialize(_grid_manager)
	enemy.tree_exiting.connect(_on_enemy_finished)
	enemy.died.connect(_on_enemy_died)
	_active_enemies += 1


func _on_enemy_died() -> void:
	add_gold(10)


func _on_enemy_finished() -> void:
	_active_enemies -= 1
	if _active_enemies <= 0 and not _spawning:
		_active_enemies = 0
		_button.disabled = false
