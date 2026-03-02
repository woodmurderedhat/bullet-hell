## CollisionSystem — manual distance-check collision detection.
## No Godot PhysicsServer involvement; all checks are squared-distance comparisons.
## Add as a child of Main.tscn.
class_name CollisionSystem
extends Node

## Player hitbox half-size (triangle bounding circle radius).
const PLAYER_RADIUS: float = 10.0
const SECONDARY_DAMAGE_SCALE: float = 0.65
const SPLIT_ARC_DEGREES: float = 18.0
const SPLIT_MAX_CHILDREN: int = 6
const CHAIN_BASE_RADIUS: float = 120.0
const PULSE_BASE_RADIUS: float = 56.0
const REFLECT_DEFAULT_SPEED: float = 480.0

const SLOT: int = 6  # Must match BulletManager.SLOT.

var _bullet_manager: BulletManager
var _player: Node2D
## Array of Enemy/Boss nodes — untyped to allow duck-typed property access
## (both expose .position, .collision_radius, and .enemy_id as plain vars).
var _enemies: Array = []

var _player_damage: float = 10.0  # Updated by Player via set_player_damage().
var _enemy_damage_scale: float = 1.0
var _modifier: ModifierComponent = null
var _absorb_charges: int = 0


func _ready() -> void:
	EventBus.wave_complete.connect(_on_wave_complete)


## Called by Main once all systems are in the scene tree.
func initialise(
	bullet_manager: BulletManager,
	player: Node2D,
	modifier: ModifierComponent = null
) -> void:
	_bullet_manager = bullet_manager
	_player = player
	_modifier = modifier
	_refresh_absorb_charges()


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


func set_enemy_damage_scale(scale: float) -> void:
	_enemy_damage_scale = maxf(0.1, scale)


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
			var hit_pos: Vector2 = Vector2(pool[base + 0], pool[base + 1])
			var hit_vel: Vector2 = Vector2(pool[base + 2], pool[base + 3])
			_bullet_manager.deactivate_enemy_bullet(i)
			if _consume_absorb_charge():
				_try_reflect_bullet(hit_pos, hit_vel)
				continue
			EventBus.bullet_hit_player.emit(1.0 * _enemy_damage_scale)


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
		var bullet_pos: Vector2 = Vector2(bx, by)

		for enemy in _enemies:
			if not is_instance_valid(enemy):
				continue
			var er_sq: float = float(enemy.collision_radius) * float(enemy.collision_radius)
			var dx: float = bx - float(enemy.position.x)
			var dy: float = by - float(enemy.position.y)
			if dx * dx + dy * dy < er_sq:
				var damage: float = _player_damage * _bullet_manager.get_player_bullet_damage_scale(i)
				damage = _apply_crit(damage)
				EventBus.bullet_hit_enemy.emit(int(enemy.enemy_id), damage)

				var should_deactivate: bool = true
				if _trigger_stack(&"split_on_hit") > 0:
					_spawn_split_children(i, bullet_pos)
					should_deactivate = true
				elif _trigger_stack(&"pierce") > 0:
					should_deactivate = false

				_apply_chain_lightning(enemy, damage)
				_apply_pulse_aoe(enemy, damage)

				if should_deactivate:
					_bullet_manager.deactivate_player_bullet(i)
				break  # One bullet hits one enemy per frame.


func _apply_crit(base_damage: float) -> float:
	var crit_stacks: int = _trigger_stack(&"crit_10")
	if crit_stacks <= 0:
		return base_damage
	var crit_chance: float = minf(0.1 * float(crit_stacks), 0.95)
	if RandomService.next_float() >= crit_chance:
		return base_damage
	var crit_multiplier: float = 2.0 if _trigger_stack(&"crit_multiplier_2x") > 0 else 1.5
	return base_damage * crit_multiplier


func _spawn_split_children(slot: int, hit_pos: Vector2) -> void:
	var split_stacks: int = _trigger_stack(&"split_on_hit")
	if split_stacks <= 0:
		return

	var split_budget: int = _bullet_manager.get_player_bullet_split_budget(slot)
	if split_budget <= 0:
		return

	var velocity: Vector2 = _bullet_manager.get_player_bullet_velocity(slot)
	if velocity.length_squared() <= 0.0001:
		return

	var child_count: int = mini(2 + split_stacks, SPLIT_MAX_CHILDREN)
	var speed: float = velocity.length()
	var forward: Vector2 = velocity.normalized()
	var damage_scale: float = _bullet_manager.get_player_bullet_damage_scale(slot) * SECONDARY_DAMAGE_SCALE
	var next_depth: int = _bullet_manager.get_player_bullet_split_depth(slot) + 1

	if child_count <= 1:
		_bullet_manager.spawn_player_bullet_advanced(
			hit_pos,
			forward,
			speed,
			BulletManager.PLAYER_BEHAVIOR_STRAIGHT,
			0.0,
			0.0,
			0.0,
			next_depth,
			split_budget - 1,
			damage_scale
		)
		return

	var spread_rad: float = deg_to_rad(SPLIT_ARC_DEGREES + float(split_stacks - 1) * 2.0)
	for i: int in range(child_count):
		var ratio: float = float(i) / float(child_count - 1)
		var offset: float = lerpf(-spread_rad, spread_rad, ratio)
		var dir: Vector2 = forward.rotated(offset)
		_bullet_manager.spawn_player_bullet_advanced(
			hit_pos,
			dir,
			speed,
			BulletManager.PLAYER_BEHAVIOR_STRAIGHT,
			0.0,
			0.0,
			0.0,
			next_depth,
			split_budget - 1,
			damage_scale
		)


func _apply_chain_lightning(primary_enemy: Variant, source_damage: float) -> void:
	var chain_stacks: int = _trigger_stack(&"chain_lightning")
	if chain_stacks <= 0:
		return

	var jumps: int = mini(chain_stacks, 4)
	var chain_radius: float = CHAIN_BASE_RADIUS + float(chain_stacks - 1) * 16.0
	var chain_radius_sq: float = chain_radius * chain_radius
	var current_pos: Vector2 = Vector2(primary_enemy.position)
	var used_ids: Array[int] = [int(primary_enemy.enemy_id)]

	for _jump: int in range(jumps):
		var next_enemy: Variant = null
		var next_dist_sq: float = INF
		for enemy in _enemies:
			if not is_instance_valid(enemy):
				continue
			var eid: int = int(enemy.enemy_id)
			if used_ids.has(eid):
				continue
			var delta: Vector2 = Vector2(enemy.position) - current_pos
			var dist_sq: float = delta.length_squared()
			if dist_sq <= chain_radius_sq and dist_sq < next_dist_sq:
				next_dist_sq = dist_sq
				next_enemy = enemy

		if next_enemy == null:
			break

		used_ids.append(int(next_enemy.enemy_id))
		current_pos = Vector2(next_enemy.position)
		EventBus.bullet_hit_enemy.emit(int(next_enemy.enemy_id), source_damage * SECONDARY_DAMAGE_SCALE)


func _apply_pulse_aoe(primary_enemy: Variant, source_damage: float) -> void:
	var pulse_stacks: int = _trigger_stack(&"pulse_aoe")
	if pulse_stacks <= 0:
		return

	var radius: float = PULSE_BASE_RADIUS + float(pulse_stacks - 1) * 10.0
	var radius_sq: float = radius * radius
	var center: Vector2 = Vector2(primary_enemy.position)

	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		if int(enemy.enemy_id) == int(primary_enemy.enemy_id):
			continue
		var delta: Vector2 = Vector2(enemy.position) - center
		if delta.length_squared() <= radius_sq:
			EventBus.bullet_hit_enemy.emit(int(enemy.enemy_id), source_damage * SECONDARY_DAMAGE_SCALE)


func _consume_absorb_charge() -> bool:
	if _absorb_charges <= 0:
		return false
	_absorb_charges -= 1
	return true


func _try_reflect_bullet(hit_pos: Vector2, hit_vel: Vector2) -> void:
	if _trigger_stack(&"reflect_bullet") <= 0:
		return
	if _bullet_manager == null:
		return

	var reflect_dir: Vector2 = -hit_vel.normalized()
	if reflect_dir.length_squared() <= 0.0001:
		reflect_dir = Vector2.UP
	var reflect_speed: float = maxf(hit_vel.length(), REFLECT_DEFAULT_SPEED)

	_bullet_manager.spawn_player_bullet_advanced(
		hit_pos,
		reflect_dir,
		reflect_speed,
		BulletManager.PLAYER_BEHAVIOR_STRAIGHT,
		0.0,
		0.0,
		0.0,
		0,
		_trigger_stack(&"split_on_hit"),
		SECONDARY_DAMAGE_SCALE
	)


func _trigger_stack(trigger_id: StringName) -> int:
	if _modifier == null:
		return 0
	return _modifier.get_trigger_stack(trigger_id)


func _refresh_absorb_charges() -> void:
	_absorb_charges = _trigger_stack(&"absorb_one")


func _on_wave_complete(_arena_index: int) -> void:
	_refresh_absorb_charges()
