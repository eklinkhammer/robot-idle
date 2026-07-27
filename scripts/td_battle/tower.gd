extends Node2D
## Base tower script.
## Targets nearest enemy in range and fires projectiles.

const ProjectileScene: PackedScene = preload("res://scenes/td_battle/projectile.tscn")

var tower_type: String = "peasant"
var damage: float = 20.0
var fire_range: float = 150.0
var fire_rate: float = 1.0
var aoe_radius: float = 0.0

var _fire_cooldown: float = 0.0


func apply_upgrade(new_damage: float, new_range: float, new_fire_rate: float, new_aoe: float) -> void:
	damage = new_damage
	fire_range = new_range
	fire_rate = new_fire_rate
	aoe_radius = new_aoe


func _process(delta: float) -> void:
	_fire_cooldown -= delta
	if _fire_cooldown > 0.0:
		return

	var target := _find_nearest_enemy()
	if target:
		_fire(target)
		_fire_cooldown = 1.0 / fire_rate


func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist: float = fire_range
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _fire(target: Node2D) -> void:
	var projectile: Node2D = ProjectileScene.instantiate()
	# Add to TDBattle level (two parents up: Tower -> GridManager -> TDBattle)
	get_parent().get_parent().add_child(projectile)
	projectile.global_position = global_position
	if tower_type == "catapult":
		projectile.speed = 250.0
	projectile.initialize(target, damage, aoe_radius)
