extends Control
## Main menu scene. Provides navigation to map selection.


func _ready() -> void:
	var button := $CenterContainer/VBoxContainer/StartBattleButton as Button
	button.pressed.connect(_on_select_map_pressed)


func _on_select_map_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map_select.tscn")
