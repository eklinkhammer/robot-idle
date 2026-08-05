extends Control
## Map selection screen: shows buttons for each map with cleared status.

const MapRegistry := preload("res://scripts/td_battle/map_registry.gd")


func _ready() -> void:
	var vbox: VBoxContainer = $CenterContainer/VBoxContainer
	var back_btn: Button = $CenterContainer/VBoxContainer/BackButton
	var maps := MapRegistry.get_all_maps()
	for m: RefCounted in maps:
		var btn := Button.new()
		var label_text: String = m.map_name
		if GameState.is_beaten(m.map_id):
			label_text += " [Cleared]"
		label_text += " (%d waves)" % m.waves.size()
		btn.text = label_text
		btn.pressed.connect(_on_map_selected.bind(m.map_id))
		vbox.add_child(btn)

	# --- Procedural Map section ---
	var sep := HSeparator.new()
	vbox.add_child(sep)

	var proc_label := Label.new()
	proc_label.text = "Procedural Map"
	proc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(proc_label)

	var diff_hbox := HBoxContainer.new()
	diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var diff_label := Label.new()
	diff_label.text = "Difficulty: "
	diff_hbox.add_child(diff_label)
	var spinbox := SpinBox.new()
	spinbox.min_value = 1
	spinbox.max_value = 5
	spinbox.step = 1
	spinbox.value = GameState.procedural_difficulty
	spinbox.custom_minimum_size.x = 80
	diff_hbox.add_child(spinbox)
	vbox.add_child(diff_hbox)

	if GameState.highest_procedural_difficulty_beaten > 0:
		var best_label := Label.new()
		best_label.text = "Best cleared: Difficulty %d" % GameState.highest_procedural_difficulty_beaten
		best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(best_label)

	var gen_btn := Button.new()
	gen_btn.text = "Generate & Play"
	gen_btn.pressed.connect(_on_procedural_selected.bind(spinbox))
	vbox.add_child(gen_btn)

	# --- Offense (Attack Fortress) section ---
	var off_sep := HSeparator.new()
	vbox.add_child(off_sep)

	var off_label := Label.new()
	off_label.text = "Attack Fortress"
	off_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(off_label)

	var off_diff_hbox := HBoxContainer.new()
	off_diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var off_diff_label := Label.new()
	off_diff_label.text = "Difficulty: "
	off_diff_hbox.add_child(off_diff_label)
	var off_spinbox := SpinBox.new()
	off_spinbox.min_value = 1
	off_spinbox.max_value = 5
	off_spinbox.step = 1
	off_spinbox.value = GameState.offense_difficulty
	off_spinbox.custom_minimum_size.x = 80
	off_diff_hbox.add_child(off_spinbox)
	vbox.add_child(off_diff_hbox)

	if GameState.highest_offense_difficulty_beaten > 0:
		var off_best_label := Label.new()
		off_best_label.text = "Best cleared: Difficulty %d" % GameState.highest_offense_difficulty_beaten
		off_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(off_best_label)

	var off_btn := Button.new()
	off_btn.text = "Attack Fortress"
	off_btn.pressed.connect(_on_offense_selected.bind(off_spinbox))
	vbox.add_child(off_btn)

	# Move back button to the end
	vbox.move_child(back_btn, -1)
	back_btn.pressed.connect(_on_back_pressed)


func _on_map_selected(map_id: String) -> void:
	GameState.selected_map_id = map_id
	get_tree().change_scene_to_file("res://scenes/td_battle/td_battle.tscn")


func _on_procedural_selected(spinbox: SpinBox) -> void:
	GameState.procedural_difficulty = int(spinbox.value)
	GameState.procedural_seed = -1
	GameState.selected_map_id = "procedural"
	get_tree().change_scene_to_file("res://scenes/td_battle/td_battle.tscn")


func _on_offense_selected(spinbox: SpinBox) -> void:
	GameState.offense_difficulty = int(spinbox.value)
	GameState.offense_seed = -1
	get_tree().change_scene_to_file("res://scenes/td_battle/offense_battle.tscn")


func _on_back_pressed() -> void:
	if GameState.campaign_return_scene != "":
		var return_scene: String = GameState.campaign_return_scene
		GameState.campaign_return_scene = ""
		get_tree().change_scene_to_file(return_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
