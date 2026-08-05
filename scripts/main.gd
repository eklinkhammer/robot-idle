extends Control
## Main menu scene. Provides navigation to map selection.


func _ready() -> void:
	var button := $CenterContainer/VBoxContainer/StartBattleButton as Button
	button.pressed.connect(_on_select_map_pressed)

	var campaign_btn := $CenterContainer/VBoxContainer/CampaignButton as Button
	campaign_btn.pressed.connect(_on_campaign_pressed)


func _on_select_map_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map_select.tscn")


func _on_campaign_pressed() -> void:
	GameState.init_campaign()
	get_tree().change_scene_to_file("res://scenes/campaign/campaign_map.tscn")
