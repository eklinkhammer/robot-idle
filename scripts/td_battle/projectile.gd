extends Node2D
## Projectile that moves toward a target and applies damage on arrival.

var speed: float = 400.0
var damage: float = 0.0

var _target: Node2D


func initialize(target: Node2D, dmg: float) -> void:
	_target = target
	damage = dmg


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return

	var direction := (global_position.direction_to(_target.global_position))
	var dist := global_position.distance_to(_target.global_position)
	var step := speed * delta

	if dist <= step + 4.0:
		_target.take_damage(damage)
		queue_free()
	else:
		global_position += direction * step


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
