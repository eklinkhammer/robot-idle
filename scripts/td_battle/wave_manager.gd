extends Node
## Manages wave spawning for the TD battle.
## Spawns enemies along the path in configurable waves.

# TODO: Define wave data (enemy count, spawn interval, enemy type)
# TODO: Spawn enemies as children of the Path2D
# TODO: Track wave state (current wave, enemies remaining)
# TODO: Signal when all waves are complete

var current_wave: int = 0
var total_waves: int = 5


func _ready() -> void:
	var button := get_parent().get_node("UILayer/HBoxContainer/SendWaveButton") as Button
	button.pressed.connect(_on_send_wave_pressed)


func _on_send_wave_pressed() -> void:
	# TODO: Spawn a wave of enemies
	current_wave += 1
	var label := get_parent().get_node("UILayer/HBoxContainer/WaveLabel") as Label
	label.text = "Wave: %d / %d" % [current_wave, total_waves]
