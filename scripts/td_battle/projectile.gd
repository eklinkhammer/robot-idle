extends Node2D
## Projectile that moves toward a target and applies damage on arrival.

var speed: float = 400.0
var damage: float = 0.0
var aoe_radius: float = 0.0

var _target: Node2D
var _last_known_pos: Vector2


func initialize(target: Node2D, dmg: float, aoe: float = 0.0) -> void:
	_target = target
	damage = dmg
	aoe_radius = aoe
	_last_known_pos = target.global_position


func _process(delta: float) -> void:
	# Update last known position while target is alive
	if is_instance_valid(_target):
		_last_known_pos = _target.global_position

	# If target died and no AoE, self-destruct
	if not is_instance_valid(_target) and aoe_radius <= 0.0:
		queue_free()
		return

	var destination: Vector2
	if is_instance_valid(_target):
		destination = _target.global_position
	else:
		destination = _last_known_pos

	var direction := global_position.direction_to(destination)
	var dist := global_position.distance_to(destination)
	var step := speed * delta

	if dist <= step + 4.0:
		_on_arrival()
	else:
		global_position += direction * step


func _on_arrival() -> void:
	if aoe_radius > 0.0:
		# Damage all enemies within AoE radius of impact point
		var impact_pos := _last_known_pos
		for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
			if enemy.global_position.distance_to(impact_pos) <= aoe_radius:
				enemy.take_damage(damage)
	else:
		# Single-target damage
		if is_instance_valid(_target):
			_target.take_damage(damage)
	queue_free()


func _draw() -> void:
	if aoe_radius > 0.0:
		# AoE projectiles: larger orange-red circle
		draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.35, 0.1))
	else:
		draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
