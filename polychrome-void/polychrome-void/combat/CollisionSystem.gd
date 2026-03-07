## CollisionSystem — manual distance-check collision detection.
## No Godot PhysicsServer involvement; all checks are squared-distance comparisons.
## Add as a child of Main.tscn.
class_name CollisionSystem
extends Node

## Player hitbox half-size (triangle bounding circle radius).
const PLAYER_RADIUS: float = 25.0
const SECONDARY_DAMAGE_SCALE: float = 0.65
const SPLIT_ARC_DEGREES: float = 18.0
const SPLIT_MAX_CHILDREN: int = 6
const SPLIT_FREE_SLOT_RESERVE: int = 128
const CHAIN_BASE_RADIUS: float = 120.0
const PULSE_BASE_RADIUS: float = 56.0
const CONTACT_TICK_SECONDS: float = 0.35

const SLOT: int = 6  # Must match BulletManager.SLOT.

var _bullet_manager: BulletManager
var _player: Node2D
## Array of Enemy/Boss nodes — untyped to allow duck-typed property access
## (both expose .position, .collision_radius, and .enemy_id as plain vars).
var _enemies: Array = []
var _enemy_by_id: Dictionary = {}

var _player_damage: float = 10.0  # Updated by Player via set_player_damage().
var _enemy_damage_scale: float = 1.0
var _boss_damage_scale: float = 1.0
var _modifier: ModifierComponent = null
var _shield_system: Node2D = null
var _contact_next_hit_time: Dictionary = {}
var _pending_enemy_damage: Dictionary = {}
var _shield_can_intercept_enemy_bullet: bool = false
var _shield_can_apply_aura_contact: bool = false

var _perf_last_process_ms: float = 0.0
var _perf_last_enemy_bullet_checks: int = 0
var _perf_last_player_bullet_checks: int = 0
var _perf_last_enemy_overlap_checks: int = 0
var _perf_last_queued_events: int = 0
var _perf_last_resolved_targets: int = 0
var _perf_last_resolved_damage: float = 0.0
var _perf_last_active_player_bullets: int = 0


func _ready() -> void:
	EventBus.wave_complete.connect(_on_wave_complete)
	EventBus.enemy_died.connect(_on_enemy_died)


## Called by Main once all systems are in the scene tree.
func initialise(
	bullet_manager: BulletManager,
	player: Node2D,
	modifier: ModifierComponent = null,
	shield_system: Node2D = null
) -> void:
	_bullet_manager = bullet_manager
	_player = player
	_modifier = modifier
	_shield_system = shield_system
	_shield_can_intercept_enemy_bullet = _shield_system != null and _shield_system.has_method("try_intercept_enemy_bullet")
	_shield_can_apply_aura_contact = _shield_system != null and _shield_system.has_method("try_apply_aura_contact")


## Register an enemy so its position is checked against player bullets.
func register_enemy(enemy: Node) -> void:
	if not _enemies.has(enemy):
		_enemies.append(enemy)
	if enemy != null and enemy.has_method("get"):
		var enemy_id: int = int(enemy.get("enemy_id"))
		_enemy_by_id[enemy_id] = enemy


## Unregister a dead or removed enemy.
func unregister_enemy(enemy: Node) -> void:
	_enemies.erase(enemy)
	if enemy != null and enemy.has_method("get"):
		var enemy_id: int = int(enemy.get("enemy_id"))
		if _enemy_by_id.has(enemy_id):
			_enemy_by_id.erase(enemy_id)


## Force-clear all enemy tracking state (used during run/wave transitions).
func clear_enemies() -> void:
	_enemies.clear()
	_enemy_by_id.clear()
	_contact_next_hit_time.clear()
	_pending_enemy_damage.clear()


## Allow Player to update the damage value used for bullet_hit_enemy signals.
func set_player_damage(damage: float) -> void:
	_player_damage = damage


func set_enemy_damage_scale(scale: float) -> void:
	_enemy_damage_scale = maxf(0.1, scale)


func set_boss_damage_scale(scale: float) -> void:
	_boss_damage_scale = maxf(0.1, scale)


func _process(delta: float) -> void:
	if _bullet_manager == null or _player == null:
		return
	var start_us: int = Time.get_ticks_usec()
	_perf_last_enemy_bullet_checks = 0
	_perf_last_player_bullet_checks = 0
	_perf_last_enemy_overlap_checks = 0
	_perf_last_queued_events = 0
	_perf_last_resolved_targets = 0
	_perf_last_resolved_damage = 0.0
	_perf_last_active_player_bullets = 0
	_check_enemy_bullets_vs_player()
	_check_enemy_contact_vs_player(delta)
	_check_player_bullets_vs_enemies()
	_flush_pending_enemy_damage()
	_perf_last_process_ms = float(Time.get_ticks_usec() - start_us) * 0.001


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
		_perf_last_enemy_bullet_checks += 1
		var base: int = i * SLOT
		if pool[base + 5] == 0.0:
			continue

		var bullet_pos: Vector2 = Vector2(pool[base + 0], pool[base + 1])
		var bullet_vel: Vector2 = Vector2(pool[base + 2], pool[base + 3])
		if _shield_can_intercept_enemy_bullet and bool(_shield_system.call("try_intercept_enemy_bullet", bullet_pos, bullet_vel)):
			_bullet_manager.deactivate_enemy_bullet(i)
			continue

		var dx: float = pool[base + 0] - px
		var dy: float = pool[base + 1] - py
		if dx * dx + dy * dy < r_sq:
			_bullet_manager.deactivate_enemy_bullet(i)
			var base_damage: float = _bullet_manager.get_enemy_bullet_damage(i)
			var from_boss: bool = _bullet_manager.is_enemy_bullet_from_boss(i)
			var scale: float = _boss_damage_scale if from_boss else _enemy_damage_scale
			EventBus.bullet_hit_player.emit(base_damage * scale)


func _check_enemy_contact_vs_player(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	if _enemies.is_empty():
		return

	var px: float = _player.position.x
	var py: float = _player.position.y
	var now: float = Time.get_ticks_msec() * 0.001

	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue

		if _shield_can_apply_aura_contact:
			_shield_system.call("try_apply_aura_contact", enemy, now)

		var combined_r: float = PLAYER_RADIUS + float(enemy.collision_radius)
		var dx: float = float(enemy.position.x) - px
		var dy: float = float(enemy.position.y) - py
		if dx * dx + dy * dy >= combined_r * combined_r:
			continue

		var enemy_id: int = int(enemy.enemy_id)
		var next_time: float = float(_contact_next_hit_time.get(enemy_id, 0.0))
		if now < next_time:
			continue

		_contact_next_hit_time[enemy_id] = now + CONTACT_TICK_SECONDS
		var base_contact_damage: float = float(enemy.contact_damage)
		var from_boss: bool = bool(enemy.is_boss_source)
		var scale: float = _boss_damage_scale if from_boss else _enemy_damage_scale
		EventBus.bullet_hit_player.emit(base_contact_damage * scale)


## Check all active player bullets against each registered enemy.
func _check_player_bullets_vs_enemies() -> void:
	if _enemies.is_empty():
		return
	_pending_enemy_damage.clear()

	var has_live_enemy: bool = false
	var enemy_min_x: float = INF
	var enemy_min_y: float = INF
	var enemy_max_x: float = -INF
	var enemy_max_y: float = -INF
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_radius: float = float(enemy.collision_radius)
		var ex: float = float(enemy.position.x)
		var ey: float = float(enemy.position.y)
		enemy_min_x = minf(enemy_min_x, ex - enemy_radius)
		enemy_min_y = minf(enemy_min_y, ey - enemy_radius)
		enemy_max_x = maxf(enemy_max_x, ex + enemy_radius)
		enemy_max_y = maxf(enemy_max_y, ey + enemy_radius)
		has_live_enemy = true

	if not has_live_enemy:
		return

	var crit_stacks: int = _trigger_stack(&"crit_10")
	var crit_has_double: bool = _trigger_stack(&"crit_multiplier_2x") > 0
	var split_stacks: int = _trigger_stack(&"split_on_hit")
	var pierce_stacks: int = _trigger_stack(&"pierce")
	var chain_stacks: int = _trigger_stack(&"chain_lightning")
	var pulse_stacks: int = _trigger_stack(&"pulse_aoe")

	var pool: PackedFloat32Array = _bullet_manager.get_player_pool()
	var count: int = BulletManager.MAX_BULLETS

	for i: int in range(count):
		_perf_last_player_bullet_checks += 1
		var base: int = i * SLOT
		if pool[base + 5] == 0.0:
			continue
		_perf_last_active_player_bullets += 1
		var bx: float = pool[base + 0]
		var by: float = pool[base + 1]
		if bx < enemy_min_x or bx > enemy_max_x or by < enemy_min_y or by > enemy_max_y:
			continue
		var bullet_pos: Vector2 = Vector2(bx, by)

		for enemy in _enemies:
			_perf_last_enemy_overlap_checks += 1
			if not is_instance_valid(enemy):
				continue
			var er_sq: float = float(enemy.collision_radius) * float(enemy.collision_radius)
			var dx: float = bx - float(enemy.position.x)
			var dy: float = by - float(enemy.position.y)
			if dx * dx + dy * dy < er_sq:
				var damage: float = _player_damage * _bullet_manager.get_player_bullet_damage_scale(i)
				damage = _apply_crit(damage, crit_stacks, crit_has_double)
				_queue_enemy_damage(int(enemy.enemy_id), damage)

				var should_deactivate: bool = true
				if split_stacks > 0:
					_spawn_split_children(i, bullet_pos, split_stacks)
					should_deactivate = true
				elif pierce_stacks > 0:
					should_deactivate = false

				_apply_chain_lightning(enemy, damage, chain_stacks)
				_apply_pulse_aoe(enemy, damage, pulse_stacks)

				if should_deactivate:
					_bullet_manager.deactivate_player_bullet(i)
				break  # One bullet hits one enemy per frame.


func _apply_crit(base_damage: float, crit_stacks: int, crit_has_double: bool) -> float:
	if crit_stacks <= 0:
		return base_damage
	var crit_chance: float = minf(0.1 * float(crit_stacks), 0.95)
	if RandomService.next_float() >= crit_chance:
		return base_damage
	var crit_multiplier: float = 2.0 if crit_has_double else 1.5
	return base_damage * crit_multiplier


func _spawn_split_children(slot: int, hit_pos: Vector2, split_stacks: int) -> void:
	if split_stacks <= 0:
		return

	var split_budget: int = _bullet_manager.get_player_bullet_split_budget(slot)
	if split_budget <= 0:
		return

	var velocity: Vector2 = _bullet_manager.get_player_bullet_velocity(slot)
	if velocity.length_squared() <= 0.0001:
		return

	var child_count: int = mini(2 + split_stacks, SPLIT_MAX_CHILDREN)
	var free_slots: int = _bullet_manager.get_player_free_slot_count()
	var split_capacity: int = maxi(0, free_slots - SPLIT_FREE_SLOT_RESERVE)
	child_count = mini(child_count, split_capacity)
	if child_count <= 0:
		return
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


func _apply_chain_lightning(primary_enemy: Variant, source_damage: float, chain_stacks: int) -> void:
	if chain_stacks <= 0:
		return

	var jumps: int = mini(chain_stacks, 4)
	var chain_radius: float = CHAIN_BASE_RADIUS + float(chain_stacks - 1) * 16.0
	var chain_radius_sq: float = chain_radius * chain_radius
	var current_pos: Vector2 = Vector2(primary_enemy.position)
	var used_ids: Dictionary = {}
	used_ids[int(primary_enemy.enemy_id)] = true

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

		used_ids[int(next_enemy.enemy_id)] = true
		current_pos = Vector2(next_enemy.position)
		_queue_enemy_damage(int(next_enemy.enemy_id), source_damage * SECONDARY_DAMAGE_SCALE)


func _apply_pulse_aoe(primary_enemy: Variant, source_damage: float, pulse_stacks: int) -> void:
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
			_queue_enemy_damage(int(enemy.enemy_id), source_damage * SECONDARY_DAMAGE_SCALE)


func _queue_enemy_damage(enemy_id: int, damage: float) -> void:
	if damage <= 0.0:
		return
	_perf_last_queued_events += 1
	var existing: float = float(_pending_enemy_damage.get(enemy_id, 0.0))
	_pending_enemy_damage[enemy_id] = existing + damage


func _flush_pending_enemy_damage() -> void:
	if _pending_enemy_damage.is_empty():
		return
	for enemy_id_variant in _pending_enemy_damage.keys():
		var enemy_id: int = int(enemy_id_variant)
		var damage: float = float(_pending_enemy_damage[enemy_id_variant])
		if damage <= 0.0:
			continue
		_perf_last_resolved_targets += 1
		_perf_last_resolved_damage += damage

		var enemy: Variant = _enemy_by_id.get(enemy_id, null)
		if enemy != null and is_instance_valid(enemy):
			if enemy is Enemy:
				(enemy as Enemy).apply_damage(damage)
			elif enemy is Boss:
				(enemy as Boss).apply_damage(damage)

		# Keep batched event emission for telemetry and observers.
		EventBus.bullet_hit_enemy.emit(enemy_id, damage)
	_pending_enemy_damage.clear()


func get_perf_snapshot() -> Dictionary:
	return {
		"collision_process_ms": _perf_last_process_ms,
		"collision_enemy_bullet_checks": _perf_last_enemy_bullet_checks,
		"collision_player_bullet_checks": _perf_last_player_bullet_checks,
		"collision_enemy_overlap_checks": _perf_last_enemy_overlap_checks,
		"collision_queued_damage_events": _perf_last_queued_events,
		"collision_resolved_targets": _perf_last_resolved_targets,
		"collision_resolved_damage": _perf_last_resolved_damage,
		"collision_checks_per_active_player_bullet": (
			float(_perf_last_enemy_overlap_checks) / float(_perf_last_active_player_bullets)
			if _perf_last_active_player_bullets > 0 else 0.0
		),
	}


func _trigger_stack(trigger_id: StringName) -> int:
	if _modifier == null:
		return 0
	return _modifier.get_trigger_stack(trigger_id)


func _on_wave_complete(_arena_index: int) -> void:
	clear_enemies()


func _on_enemy_died(enemy_id: int, _position: Vector2, _score: int) -> void:
	_enemy_by_id.erase(enemy_id)
	_contact_next_hit_time.erase(enemy_id)
	for idx: int in range(_enemies.size() - 1, -1, -1):
		var enemy: Variant = _enemies[idx]
		if not is_instance_valid(enemy):
			_enemies.remove_at(idx)
			continue
		if int(enemy.enemy_id) == enemy_id:
			_enemies.remove_at(idx)
