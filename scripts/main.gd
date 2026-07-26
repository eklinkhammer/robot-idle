extends Control
## Main menu scene. Provides navigation to the TD battle screen.


func _ready() -> void:
	var button := $CenterContainer/VBoxContainer/StartBattleButton as Button
	button.pressed.connect(_on_start_battle_pressed)


func _on_start_battle_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/td_battle/td_battle.tscn")
