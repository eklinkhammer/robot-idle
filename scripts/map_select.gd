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

	# Move back button to the end
	vbox.move_child(back_btn, -1)
	back_btn.pressed.connect(_on_back_pressed)


func _on_map_selected(map_id: String) -> void:
	GameState.selected_map_id = map_id
	get_tree().change_scene_to_file("res://scenes/td_battle/td_battle.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
