extends Control
## Campaign map screen: territory panels, building UI, navigation.

const TERRITORIES: Array[Dictionary] = [
	{"id": "forest", "name": "Dark Forest", "difficulty": 1, "seed": 1001, "reward": 20, "sites": 3, "unlock": ""},
	{"id": "mountain", "name": "Iron Mountain", "difficulty": 3, "seed": 3001, "reward": 35, "sites": 4, "unlock": "forest"},
	{"id": "volcano", "name": "Ash Volcano", "difficulty": 5, "seed": 5001, "reward": 50, "sites": 5, "unlock": "mountain"},
]

var _gold_label: Label
var _unit_bonus_label: Label
var _gold_bonus_label: Label
var _territory_panels: Array[VBoxContainer] = []


func _ready() -> void:
	if not GameState.campaign_active:
		GameState.init_campaign()
	_build_ui()
	_refresh_ui()


func _build_ui() -> void:
	# Top bar
	var top_bar := PanelContainer.new()
	top_bar.layout_mode = 1
	top_bar.anchors_preset = Control.PRESET_TOP_WIDE
	top_bar.offset_bottom = 50.0
	add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.layout_mode = 2
	top_hbox.add_theme_constant_override("separation", 20)
	top_bar.add_child(top_hbox)

	var title := Label.new()
	title.text = "CAMPAIGN"
	title.add_theme_font_size_override("font_size", 20)
	top_hbox.add_child(title)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 16)
	top_hbox.add_child(_gold_label)

	_unit_bonus_label = Label.new()
	_unit_bonus_label.add_theme_font_size_override("font_size", 16)
	top_hbox.add_child(_unit_bonus_label)

	_gold_bonus_label = Label.new()
	_gold_bonus_label.add_theme_font_size_override("font_size", 16)
	top_hbox.add_child(_gold_bonus_label)

	# Territory panels container
	var center := CenterContainer.new()
	center.layout_mode = 1
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.offset_top = 60.0
	center.offset_bottom = -60.0
	add_child(center)

	var territories_hbox := HBoxContainer.new()
	territories_hbox.layout_mode = 2
	territories_hbox.add_theme_constant_override("separation", 20)
	center.add_child(territories_hbox)

	for t: Dictionary in TERRITORIES:
		var panel := _build_territory_panel(t)
		territories_hbox.add_child(panel)
		_territory_panels.append(panel)

	# Bottom bar
	var bottom_bar := HBoxContainer.new()
	bottom_bar.layout_mode = 1
	bottom_bar.anchors_preset = Control.PRESET_BOTTOM_WIDE
	bottom_bar.offset_top = -50.0
	bottom_bar.add_theme_constant_override("separation", 20)
	add_child(bottom_bar)

	var practice_btn := Button.new()
	practice_btn.text = "Practice Defense"
	practice_btn.pressed.connect(_on_practice_defense_pressed)
	bottom_bar.add_child(practice_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "Back to Menu"
	back_btn.pressed.connect(_on_back_pressed)
	bottom_bar.add_child(back_btn)


func _build_territory_panel(t: Dictionary) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(300, 400)
	panel.add_theme_constant_override("separation", 6)

	var bg := PanelContainer.new()
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 4)
	bg.add_child(vbox)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = t["name"].to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	var diff_label := Label.new()
	diff_label.text = "Difficulty: %d" % t["difficulty"]
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(diff_label)

	var reward_label := Label.new()
	reward_label.text = "Reward: %dg" % t["reward"]
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reward_label)

	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_label)

	var attack_btn := Button.new()
	attack_btn.name = "AttackButton"
	attack_btn.text = "Attack"
	attack_btn.pressed.connect(_on_attack_pressed.bind(t))
	vbox.add_child(attack_btn)

	# Building sites container
	var sites_label := Label.new()
	sites_label.name = "SitesLabel"
	sites_label.text = "Building Sites:"
	sites_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(sites_label)

	var sites_container := VBoxContainer.new()
	sites_container.name = "SitesContainer"
	sites_container.add_theme_constant_override("separation", 2)
	vbox.add_child(sites_container)

	return panel


func _refresh_ui() -> void:
	_gold_label.text = "Gold: %dg" % GameState.campaign_gold
	_unit_bonus_label.text = "+%d units" % GameState.campaign_unit_bonus
	_gold_bonus_label.text = "+%dg defense" % GameState.campaign_gold_bonus

	for i in range(TERRITORIES.size()):
		var t: Dictionary = TERRITORIES[i]
		var panel: VBoxContainer = _territory_panels[i]
		var territory_id: String = t["id"]
		var conquered: bool = GameState.campaign_territories[territory_id]["conquered"]
		var unlocked: bool = _is_territory_unlocked(territory_id)

		var bg: PanelContainer = panel.get_child(0)
		var vbox: VBoxContainer = bg.get_child(0)
		var status_label: Label = vbox.find_child("StatusLabel", false, false)
		var attack_btn: Button = vbox.find_child("AttackButton", false, false)
		var sites_label: Label = vbox.find_child("SitesLabel", false, false)
		var sites_container: VBoxContainer = vbox.find_child("SitesContainer", false, false)

		if conquered:
			status_label.text = "Conquered"
			status_label.add_theme_color_override("font_color", Color.GREEN)
			attack_btn.text = "Attack (Replay)"
			attack_btn.disabled = false
		elif unlocked:
			status_label.text = "Available"
			attack_btn.text = "Attack"
			attack_btn.disabled = false
		else:
			status_label.text = "Locked"
			status_label.add_theme_color_override("font_color", Color.GRAY)
			attack_btn.text = "Locked"
			attack_btn.disabled = true

		# Building sites
		for child: Node in sites_container.get_children():
			child.queue_free()

		if conquered:
			sites_label.visible = true
			var buildings: Array = GameState.campaign_buildings[territory_id]
			for si in range(buildings.size()):
				var site: Dictionary = buildings[si]
				if site["built"]:
					var lbl := Label.new()
					if site["mode"] == "unit":
						lbl.text = "  Unit +1"
					else:
						lbl.text = "  Gold +5g"
					lbl.add_theme_font_size_override("font_size", 12)
					sites_container.add_child(lbl)
				else:
					var build_hbox := HBoxContainer.new()
					build_hbox.add_theme_constant_override("separation", 4)

					var build_btn := Button.new()
					build_btn.text = "Build (10g)"
					build_btn.disabled = GameState.campaign_gold < 10
					build_btn.pressed.connect(_on_build_pressed.bind(territory_id, si))
					build_hbox.add_child(build_btn)

					sites_container.add_child(build_hbox)
		else:
			sites_label.visible = false


func _is_territory_unlocked(territory_id: String) -> bool:
	for t: Dictionary in TERRITORIES:
		if t["id"] == territory_id:
			if t["unlock"] == "":
				return true
			return GameState.campaign_territories[t["unlock"]]["conquered"]
	return false


func _on_attack_pressed(t: Dictionary) -> void:
	if not _is_territory_unlocked(t["id"]):
		return
	GameState.offense_difficulty = t["difficulty"]
	GameState.offense_seed = t["seed"]
	GameState.campaign_return_scene = "res://scenes/campaign/campaign_map.tscn"
	GameState.campaign_attacking_territory = t["id"]
	GameState.campaign_territory_reward = t["reward"]
	get_tree().change_scene_to_file("res://scenes/td_battle/offense_battle.tscn")


func _on_build_pressed(territory_id: String, site_index: int) -> void:
	if not GameState.spend_campaign_gold(10):
		return
	GameState.campaign_buildings[territory_id][site_index]["built"] = true
	_show_mode_choice(territory_id, site_index)


func _show_mode_choice(territory_id: String, site_index: int) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Choose Building Mode"
	dialog.dialog_text = "Choose a bonus for this building site:"
	dialog.ok_button_text = "Unit +1 (offense budget)"
	dialog.add_cancel_button("Gold +5g (defense start)")
	dialog.confirmed.connect(_on_mode_chosen.bind(territory_id, site_index, "unit", dialog))
	dialog.canceled.connect(_on_mode_chosen.bind(territory_id, site_index, "gold", dialog))
	add_child(dialog)
	dialog.popup_centered()


func _on_mode_chosen(territory_id: String, site_index: int, mode: String, dialog: AcceptDialog) -> void:
	GameState.campaign_buildings[territory_id][site_index]["mode"] = mode
	GameState.recalculate_campaign_bonuses()
	dialog.queue_free()
	_refresh_ui()


func _on_practice_defense_pressed() -> void:
	GameState.campaign_return_scene = "res://scenes/campaign/campaign_map.tscn"
	get_tree().change_scene_to_file("res://scenes/map_select.tscn")


func _on_back_pressed() -> void:
	GameState.campaign_active = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")
