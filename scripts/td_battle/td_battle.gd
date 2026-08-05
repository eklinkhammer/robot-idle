extends Node2D
## Battle orchestrator: reads MapData, configures managers, handles restart/menu.

const MapRegistry := preload("res://scripts/td_battle/map_registry.gd")
const MapGenerator := preload("res://scripts/td_battle/map_generator.gd")


func _ready() -> void:
	var map_id: String = GameState.selected_map_id
	var map_data: RefCounted
	if map_id == "procedural":
		if GameState.procedural_seed == -1:
			GameState.procedural_seed = randi()
		map_data = MapGenerator.generate(GameState.procedural_difficulty, GameState.procedural_seed)
	else:
		map_data = MapRegistry.get_map(map_id)
		if map_data == null:
			map_data = MapRegistry.get_map("plains")

	if GameState.campaign_active:
		map_data.starting_gold += GameState.campaign_gold_bonus

	var grid_manager: Node2D = $GridManager
	var wave_manager: Node = $WaveManager

	# Wire managers together
	grid_manager.set_wave_manager(wave_manager)
	grid_manager.configure(map_data)
	wave_manager.configure(map_data)

	# Update UI to match map data
	wave_manager._update_ui()
	grid_manager.queue_redraw()

	# Connect battle end signals
	wave_manager.battle_won.connect(_on_battle_won)
	wave_manager.battle_lost.connect(_on_battle_lost)

	# Connect end buttons
	var restart_btn: Button = $UILayer/EndButtons/RestartButton
	var menu_btn: Button = $UILayer/EndButtons/MainMenuButton
	restart_btn.pressed.connect(_on_restart_pressed)
	menu_btn.pressed.connect(_on_main_menu_pressed)


func _on_battle_won() -> void:
	GameState.mark_beaten(GameState.selected_map_id)
	if GameState.selected_map_id == "procedural":
		if GameState.procedural_difficulty > GameState.highest_procedural_difficulty_beaten:
			GameState.highest_procedural_difficulty_beaten = GameState.procedural_difficulty
	if GameState.campaign_active:
		GameState.add_campaign_gold($WaveManager.gold)
	$UILayer/EndButtons.visible = true


func _on_battle_lost() -> void:
	$UILayer/EndButtons.visible = true


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	GameState.procedural_seed = -1
	if GameState.campaign_return_scene != "":
		var return_scene: String = GameState.campaign_return_scene
		GameState.campaign_return_scene = ""
		get_tree().change_scene_to_file(return_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
