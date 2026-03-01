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

var _resource: EnemyResource = null
var _current_hp: float = 0.0
var _max_hp: float = 0.0
var _player_ref: Node2D = null

var _dead: bool = false
var _movement_sign: float = 1.0
var _dash_timer: float = 0.0
var _is_dashing: bool = false
var _lifetime: float = 0.0
var _wave_seed: float = 0.0

const HALF_SIZE: float = 14.0


## Initialise with a resource and scaled HP.  Call before adding to the scene tree.
func setup(res: EnemyResource, scaled_hp: float, id: int, player: Node2D) -> void:
	_resource = res
	_max_hp = scaled_hp
	_current_hp = scaled_hp
	enemy_id = id
	collision_radius = res.collision_radius
	_player_ref = player
	_movement_sign = 1.0 if (id % 2) == 0 else -1.0
	_dash_timer = 0.0
	_is_dashing = false
	_lifetime = 0.0
	_wave_seed = float(id) * 0.371


func _ready() -> void:
	EventBus.bullet_hit_enemy.connect(_on_bullet_hit_enemy)


func _process(delta: float) -> void:
	if _dead or _player_ref == null:
		return
	_lifetime += delta
	position += _compute_velocity(delta) * delta
	queue_redraw()


func _compute_velocity(delta: float) -> Vector2:
	if _resource == null or _player_ref == null:
		return Vector2.ZERO

	var to_player: Vector2 = _player_ref.position - position
	var dist: float = to_player.length()
	if dist <= 0.0001:
		return Vector2.ZERO

	var to_dir: Vector2 = to_player / dist
	var tangent: Vector2 = Vector2(-to_dir.y, to_dir.x)

	match _resource.movement_type:
		EnemyResource.MovementType.CHASER:
			return to_dir * _resource.speed
		EnemyResource.MovementType.STRAFING:
			return _velocity_strafing(to_dir, tangent)
		EnemyResource.MovementType.ORBITING:
			return _velocity_orbiting(to_dir, tangent, dist)
		EnemyResource.MovementType.DASHING:
			return _velocity_dashing(to_dir, delta)
		EnemyResource.MovementType.WAVY:
			return _velocity_wavy(to_dir, tangent)
		_:
			return to_dir * _resource.speed


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
	_current_hp -= damage
	if _current_hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	var score_val: int = _resource.score_value if _resource != null else 0
	EventBus.enemy_died.emit(enemy_id, position, score_val)
	queue_free()
