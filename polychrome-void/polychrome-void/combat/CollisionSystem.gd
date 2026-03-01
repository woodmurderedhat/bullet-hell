## CollisionSystem — manual distance-check collision detection.
## No Godot PhysicsServer involvement; all checks are squared-distance comparisons.
## Add as a child of Main.tscn.
class_name CollisionSystem
extends Node

## Player hitbox half-size (triangle bounding circle radius).
const PLAYER_RADIUS: float = 10.0

const SLOT: int = 6  # Must match BulletManager.SLOT.

var _bullet_manager: BulletManager
var _player: Node2D
## Array of Enemy/Boss nodes — untyped to allow duck-typed property access
## (both expose .position, .collision_radius, and .enemy_id as plain vars).
var _enemies: Array = []

var _player_damage: float = 10.0  # Updated by Player via set_player_damage().


func _ready() -> void:
	# Resolved after all children have been added by Main.
	pass


## Called by Main once all systems are in the scene tree.
func initialise(bullet_manager: BulletManager, player: Node2D) -> void:
	_bullet_manager = bullet_manager
	_player = player


## Register an enemy so its position is checked against player bullets.
func register_enemy(enemy: Node) -> void:
	if not _enemies.has(enemy):
		_enemies.append(enemy)


## Unregister a dead or removed enemy.
func unregister_enemy(enemy: Node) -> void:
	_enemies.erase(enemy)


## Allow Player to update the damage value used for bullet_hit_enemy signals.
func set_player_damage(damage: float) -> void:
	_player_damage = damage


func _process(_delta: float) -> void:
	if _bullet_manager == null or _player == null:
		return
	_check_enemy_bullets_vs_player()
	_check_player_bullets_vs_enemies()


## Check all active enemy bullets against the player's position.
func _check_enemy_bullets_vs_player() -> void:
	if not is_instance_valid(_player):
		return

	var px: float = _player.position.x
	var py: float = _player.position.y
	var r_sq: float = PLAYER_RADIUS * PLAYER_RADIUS

	var pool: PackedFloat32Array = _bullet_manager.get_enemy_pool()
	var count: int = BulletManager.MAX_BULLETS

	for i: int in range(count):
		var base: int = i * SLOT
		if pool[base + 5] == 0.0:
			continue
		var dx: float = pool[base + 0] - px
		var dy: float = pool[base + 1] - py
		if dx * dx + dy * dy < r_sq:
			_bullet_manager.deactivate_enemy_bullet(i)
			EventBus.bullet_hit_player.emit(1.0)


## Check all active player bullets against each registered enemy.
func _check_player_bullets_vs_enemies() -> void:
	if _enemies.is_empty():
		return

	var pool: PackedFloat32Array = _bullet_manager.get_player_pool()
	var count: int = BulletManager.MAX_BULLETS

	for i: int in range(count):
		var base: int = i * SLOT
		if pool[base + 5] == 0.0:
			continue
		var bx: float = pool[base + 0]
		var by: float = pool[base + 1]

		for enemy in _enemies:
			if not is_instance_valid(enemy):
				continue
			var er_sq: float = float(enemy.collision_radius) * float(enemy.collision_radius)
			var dx: float = bx - float(enemy.position.x)
			var dy: float = by - float(enemy.position.y)
			if dx * dx + dy * dy < er_sq:
				_bullet_manager.deactivate_player_bullet(i)
				EventBus.bullet_hit_enemy.emit(int(enemy.enemy_id), _player_damage)
				break  # One bullet hits one enemy per frame.
