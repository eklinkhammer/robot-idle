extends PathFollow2D
## Base enemy script.
## Moves along the path and tracks health.

# TODO: Export enemy stats (speed, health, reward)
# TODO: Move along path each frame using progress += speed * delta
# TODO: Take damage, emit signal on death
# TODO: Reach end of path -> lose life

var speed: float = 100.0
var health: float = 100.0


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	# TODO: Move along path
	pass
