## Enemy — a single enemy unit.
## Loads an EnemyResource to define stats and pattern.
## Draws a solid square. CollisionSystem queries position + collision_radius.
## Instantiated by SpawnDirector; add via scenes/Enemy.tscn.
class_name Enemy
extends Node2D

## Unique per-run integer ID assigned by SpawnDirector.
var enemy_id: int = 0

## Collision radius read by CollisionSystem.
var collision_radius: float = 16.0
var projectile_damage: float = 8.0
var contact_damage: float = 12.0
var is_boss_source: bool = false

var _resource: EnemyResource = null
var _current_hp: float = 0.0
var _max_hp: float = 0.0
var _player_ref: Node2D = null
var _intelligence_tier: int = 0
var _elite_archetype: StringName = &""
var _base_speed_multiplier: float = 1.0
var _arena_min: Vector2 = Vector2(40.0, 40.0)
var _arena_max: Vector2 = Vector2(1240.0, 680.0)

var _dead: bool = false
var _movement_sign: float = 1.0
var _dash_timer: float = 0.0
var _is_dashing: bool = false
var _lifetime: float = 0.0
var _wave_seed: float = 0.0
var _last_player_pos: Vector2 = Vector2.ZERO
var _swarm_mode: bool = false
var _swarm_velocity: Vector2 = Vector2.ZERO

const HALF_SIZE: float = 14.0


## Initialise with a resource and scaled HP.  Call before adding to the scene tree.
func setup(
	res: EnemyResource,
	scaled_hp: float,
	id: int,
	player: Node2D,
	arena_min: Vector2,
	arena_max: Vector2,
	intelligence_tier: int = 0,
	elite_archetype: StringName = &""
) -> void:
	_resource = res
	_max_hp = scaled_hp
	_current_hp = scaled_hp
	enemy_id = id
	collision_radius = res.collision_radius
	projectile_damage = res.projectile_damage
	contact_damage = res.contact_damage
	is_boss_source = false
	_player_ref = player
	_intelligence_tier = maxi(0, intelligence_tier)
	_elite_archetype = elite_archetype
	_base_speed_multiplier = _elite_speed_multiplier(_elite_archetype)
	_arena_min = arena_min
	_arena_max = arena_max
	_movement_sign = 1.0 if (id % 2) == 0 else -1.0
	_dash_timer = 0.0
	_is_dashing = false
	_lifetime = 0.0
	_wave_seed = float(id) * 0.371
	_last_player_pos = _player_ref.position if _player_ref != null else Vector2.ZERO


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if _dead or _player_ref == null:
		return
	_lifetime += delta
	var player_pos: Vector2 = _player_ref.position
	var predicted_player_pos: Vector2 = player_pos
	if _intelligence_tier >= 2:
		var player_velocity: Vector2 = (player_pos - _last_player_pos) / maxf(0.001, delta)
		var prediction_horizon: float = minf(0.45, 0.10 + 0.05 * float(_intelligence_tier - 1))
		predicted_player_pos += player_velocity * prediction_horizon
	_last_player_pos = player_pos

	position += _compute_velocity(delta, predicted_player_pos) * delta
	if _swarm_mode:
		_clamp_position_to_arena()
	else:
		_wrap_position_to_arena()
	queue_redraw()


func _wrap_position_to_arena() -> void:
	if position.x < _arena_min.x:
		position.x = _arena_max.x
	elif position.x > _arena_max.x:
		position.x = _arena_min.x

	if position.y < _arena_min.y:
		position.y = _arena_max.y
	elif position.y > _arena_max.y:
		position.y = _arena_min.y


func _clamp_position_to_arena() -> void:
	position.x = clampf(position.x, _arena_min.x, _arena_max.x)
	position.y = clampf(position.y, _arena_min.y, _arena_max.y)


func _compute_velocity(delta: float, target_position: Vector2) -> Vector2:
	if _resource == null or _player_ref == null:
		return Vector2.ZERO
	if _swarm_mode:
		return _swarm_velocity

	var to_player: Vector2 = target_position - position
	var dist: float = to_player.length()
	if dist <= 0.0001:
		return Vector2.ZERO

	var to_dir: Vector2 = to_player / dist
	var tangent: Vector2 = Vector2(-to_dir.y, to_dir.x)
	var velocity: Vector2 = Vector2.ZERO

	match _resource.movement_type:
		EnemyResource.MovementType.CHASER:
			velocity = to_dir * _resource.speed
		EnemyResource.MovementType.STRAFING:
			velocity = _velocity_strafing(to_dir, tangent)
		EnemyResource.MovementType.ORBITING:
			velocity = _velocity_orbiting(to_dir, tangent, dist)
		EnemyResource.MovementType.DASHING:
			velocity = _velocity_dashing(to_dir, delta)
		EnemyResource.MovementType.WAVY:
			velocity = _velocity_wavy(to_dir, tangent)
		EnemyResource.MovementType.KITING:
			velocity = _velocity_kiting(to_dir, tangent, dist)
		EnemyResource.MovementType.ZIGZAG:
			velocity = _velocity_zigzag(to_dir, tangent)
		EnemyResource.MovementType.SENTRY:
			velocity = Vector2.ZERO
		_:
			velocity = to_dir * _resource.speed

	if _elite_archetype == &"zoner" and dist < maxf(120.0, _resource.preferred_range * 0.8):
		velocity -= to_dir * (_resource.speed * 0.55)
	elif _elite_archetype == &"hunter" and dist > maxf(60.0, _resource.preferred_range * 0.45):
		velocity += to_dir * (_resource.speed * 0.35)

	var intelligence_speed_bonus: float = 1.0 + float(_intelligence_tier) * 0.035
	return velocity * _base_speed_multiplier * intelligence_speed_bonus


func enable_swarm_mode(enabled: bool) -> void:
	_swarm_mode = enabled
	if not enabled:
		_swarm_velocity = Vector2.ZERO


func set_swarm_velocity(velocity: Vector2) -> void:
	_swarm_velocity = velocity


func _elite_speed_multiplier(archetype: StringName) -> float:
	match archetype:
		&"flanker":
			return 1.10
		&"suppressor":
			return 0.94
		&"interceptor":
			return 1.20
		&"zoner":
			return 0.92
		&"splitter":
			return 1.05
		&"hunter":
			return 1.15
		_:
			return 1.0


func _velocity_strafing(to_dir: Vector2, tangent: Vector2) -> Vector2:
	var lateral: float = clampf(_resource.lateral_weight, 0.0, 1.0)
	var blend: Vector2 = to_dir * (1.0 - lateral) + tangent * _movement_sign * lateral
	if blend.length_squared() <= 0.0001:
		return to_dir * _resource.speed
	return blend.normalized() * _resource.speed


func _velocity_orbiting(to_dir: Vector2, tangent: Vector2, dist: float) -> Vector2:
	var target_range: float = maxf(16.0, _resource.preferred_range)
	var radial_factor: float = clampf((dist - target_range) / target_range, -1.0, 1.0)
	var lateral: float = maxf(0.2, clampf(_resource.lateral_weight, 0.0, 1.0))
	var blend: Vector2 = to_dir * radial_factor + tangent * _movement_sign * lateral
	if blend.length_squared() <= 0.0001:
		return tangent * _movement_sign * _resource.speed
	return blend.normalized() * _resource.speed


func _velocity_dashing(to_dir: Vector2, delta: float) -> Vector2:
	_dash_timer += delta

	var dash_interval: float = maxf(0.2, _resource.dash_interval)
	var dash_duration: float = maxf(0.05, _resource.dash_duration)

	if _is_dashing:
		if _dash_timer >= dash_duration:
			_is_dashing = false
			_dash_timer = 0.0
	else:
		if _dash_timer >= dash_interval:
			_is_dashing = true
			_dash_timer = 0.0

	if _is_dashing:
		return to_dir * (_resource.speed * maxf(1.0, _resource.dash_speed_multiplier))

	return to_dir * (_resource.speed * 0.55)


func _velocity_wavy(to_dir: Vector2, tangent: Vector2) -> Vector2:
	var phase: float = _lifetime * _resource.wave_frequency + _wave_seed
	var lateral_speed: float = sin(phase) * _resource.wave_amplitude * _movement_sign
	var velocity: Vector2 = to_dir * _resource.speed + tangent * lateral_speed
	var max_speed: float = _resource.speed * 1.6
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	return velocity


func _velocity_kiting(to_dir: Vector2, tangent: Vector2, dist: float) -> Vector2:
	var target_range: float = maxf(24.0, _resource.preferred_range)
	var radial: float = 0.0
	if dist < target_range * 0.8:
		radial = -1.0
	elif dist > target_range * 1.2:
		radial = 0.7
	var lateral: float = maxf(0.15, _resource.lateral_weight)
	var blend: Vector2 = to_dir * radial + tangent * _movement_sign * lateral
	if blend.length_squared() <= 0.0001:
		blend = tangent * _movement_sign
	return blend.normalized() * _resource.speed


func _velocity_zigzag(to_dir: Vector2, tangent: Vector2) -> Vector2:
	var phase: float = _lifetime * (_resource.wave_frequency * 1.8) + _wave_seed
	var side: float = 1.0 if sin(phase) >= 0.0 else -1.0
	var blend: Vector2 = to_dir * 0.82 + tangent * side * 0.58
	if blend.length_squared() <= 0.0001:
		return to_dir * _resource.speed
	return blend.normalized() * (_resource.speed * 1.1)


func _draw() -> void:
	if _dead:
		return
	var col: Color = _resource.color if _resource != null else Color.RED
	# Flash white at low HP.
	var hp_frac: float = _current_hp / _max_hp if _max_hp > 0.0 else 0.0
	if hp_frac < 0.25:
		col = col.lerp(Color.WHITE, 0.5)
	draw_rect(Rect2(-HALF_SIZE, -HALF_SIZE, HALF_SIZE * 2.0, HALF_SIZE * 2.0), col)
	draw_rect(Rect2(-HALF_SIZE, -HALF_SIZE, HALF_SIZE * 2.0, HALF_SIZE * 2.0),
		Color(1.0, 1.0, 1.0, 0.4), false, 1.0)

	# HP bar above enemy.
	var bar_w: float = HALF_SIZE * 2.0
	draw_rect(Rect2(-HALF_SIZE, -HALF_SIZE - 6.0, bar_w, 3.0), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-HALF_SIZE, -HALF_SIZE - 6.0, bar_w * hp_frac, 3.0), Color(0.2, 1.0, 0.2))


func _on_bullet_hit_enemy(id: int, damage: float) -> void:
	if id != enemy_id or _dead:
		return
	apply_damage(damage)


func apply_damage(damage: float) -> void:
	if _dead or damage <= 0.0:
		return
	_current_hp -= damage
	if _current_hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	var score_val: int = _resource.score_value if _resource != null else 0
	EventBus.enemy_died.emit(enemy_id, position, score_val)
	queue_free()


func get_projectile_damage() -> float:
	return projectile_damage


func is_boss_unit() -> bool:
	return false
