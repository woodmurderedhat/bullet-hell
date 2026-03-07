## PatternExecutor - child node of Enemy/Boss that emits configurable bullet patterns.
## No dynamic arrays in _process; keep math deterministic for repeatable patterns.
class_name PatternExecutor
extends Node

const DOUBLE_SPIRAL_RES: Script = preload("res://data/DoubleSpiralPatternResource.gd")
const ROTATING_RADIAL_RES: Script = preload("res://data/RotatingRadialPatternResource.gd")
const FAN_SPREAD_RES: Script = preload("res://data/FanSpreadPatternResource.gd")
const SHOTGUN_SPREAD_RES: Script = preload("res://data/ShotgunSpreadPatternResource.gd")
const AIMED_SHOT_RES: Script = preload("res://data/AimedShotPatternResource.gd")
const PREDICTIVE_SHOT_RES: Script = preload("res://data/PredictiveShotPatternResource.gd")
const RING_RES: Script = preload("res://data/RingPatternResource.gd")
const BULLET_WALL_RES: Script = preload("res://data/BulletWallPatternResource.gd")
const BULLET_GRID_RES: Script = preload("res://data/BulletGridPatternResource.gd")
const ROTATING_CROSS_RES: Script = preload("res://data/RotatingCrossPatternResource.gd")
const STAR_RES: Script = preload("res://data/StarPatternResource.gd")
const FLOWER_RES: Script = preload("res://data/FlowerPatternResource.gd")
const DELAYED_RADIAL_RES: Script = preload("res://data/DelayedRadialBurstPatternResource.gd")
const ADVANCED_TRAJECTORY_RES: Script = preload("res://data/AdvancedTrajectoryPatternResource.gd")
const ADV_MODE_SINE: int = 0
const ADV_MODE_CURVED: int = 1
const ADV_MODE_SPLIT: int = 2
const ADV_MODE_HOMING: int = 3
const RING_MODE_COLLAPSING: int = 1

var _pattern: PatternResource = null
var _bullet_manager: BulletManager = null
var _owner_node: Node2D = null
var _fire_rate_scale: float = 1.0
var _bullet_speed_scale: float = 1.0
var _source_projectile_damage: float = 1.0
var _source_is_boss: bool = false
var _pattern_bullet_color: Color = Color(1.0, 0.3, 0.3, 1.0)

var _fire_timer: float = 0.0
var _spiral_angle: float = 0.0
var _arc_angle: float = 0.0
var _cross_flip: bool = false
var _rotating_angle: float = 0.0
var _wall_phase: float = 0.0
var _star_angle: float = 0.0
var _flower_angle: float = 0.0
var _burst_counter: int = 0
var _delayed_index: int = 0
var _delayed_cooldown: float = 0.0
var _target_last_position: Vector2 = Vector2.ZERO
var _target_velocity: Vector2 = Vector2.ZERO


func setup(
	pattern: PatternResource,
	bullet_manager: BulletManager,
	owner_node: Node2D,
	fire_rate_scale: float = 1.0,
	bullet_speed_scale: float = 1.0
) -> void:
	_pattern = pattern
	_bullet_manager = bullet_manager
	_owner_node = owner_node
	_fire_rate_scale = maxf(0.1, fire_rate_scale)
	_bullet_speed_scale = maxf(0.1, bullet_speed_scale)
	_refresh_owner_damage_source()
	_refresh_pattern_color()
	_target_last_position = _get_target_position()


func set_pattern(pattern: PatternResource, fire_rate_scale: float = 1.0, bullet_speed_scale: float = 1.0) -> void:
	_pattern = pattern
	_fire_timer = 0.0
	_spiral_angle = 0.0
	_arc_angle = 0.0
	_cross_flip = false
	_rotating_angle = 0.0
	_wall_phase = 0.0
	_star_angle = 0.0
	_flower_angle = 0.0
	_burst_counter = 0
	_delayed_index = 0
	_delayed_cooldown = 0.0
	_target_velocity = Vector2.ZERO
	_fire_rate_scale = maxf(0.1, fire_rate_scale)
	_bullet_speed_scale = maxf(0.1, bullet_speed_scale)
	_refresh_owner_damage_source()
	_refresh_pattern_color()
	_target_last_position = _get_target_position()


func _process(delta: float) -> void:
	if _pattern == null or _bullet_manager == null or _owner_node == null:
		return

	_fire_timer += delta
	_update_target_velocity(delta)
	_bullet_manager.set_enemy_homing_target_position(_get_target_position())

	if _pattern is SpiralPatternResource:
		_process_spiral()
	elif is_instance_of(_pattern, DOUBLE_SPIRAL_RES):
		_process_double_spiral()
	elif _pattern is RadialBurstPatternResource:
		_process_radial_burst()
	elif is_instance_of(_pattern, ROTATING_RADIAL_RES):
		_process_rotating_radial()
	elif _pattern is ArcPatternResource:
		_process_arc_pattern()
	elif is_instance_of(_pattern, FAN_SPREAD_RES):
		_process_fan_spread()
	elif is_instance_of(_pattern, SHOTGUN_SPREAD_RES):
		_process_shotgun_spread()
	elif is_instance_of(_pattern, AIMED_SHOT_RES):
		_process_aimed_shot()
	elif is_instance_of(_pattern, PREDICTIVE_SHOT_RES):
		_process_predictive_shot()
	elif is_instance_of(_pattern, RING_RES):
		_process_ring_pattern()
	elif is_instance_of(_pattern, BULLET_WALL_RES):
		_process_bullet_wall()
	elif is_instance_of(_pattern, BULLET_GRID_RES):
		_process_bullet_grid()
	elif _pattern is CrossPatternResource:
		_process_cross_pattern()
	elif is_instance_of(_pattern, ROTATING_CROSS_RES):
		_process_rotating_cross()
	elif is_instance_of(_pattern, STAR_RES):
		_process_star_pattern()
	elif is_instance_of(_pattern, FLOWER_RES):
		_process_flower_pattern()
	elif is_instance_of(_pattern, DELAYED_RADIAL_RES):
		_process_delayed_radial_burst(delta)
	elif is_instance_of(_pattern, ADVANCED_TRAJECTORY_RES):
		_process_advanced_trajectory()


func _process_spiral() -> void:
	var sp: SpiralPatternResource = _pattern as SpiralPatternResource
	var effective_rate: float = maxf(0.1, sp.fire_rate * _fire_rate_scale)
	var interval: float = 1.0 / effective_rate
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	_spiral_angle += sp.angle_step
	_emit_even_arc(_owner_node.position, _spiral_angle, TAU, maxi(1, sp.arms), sp.bullet_speed * _bullet_speed_scale)


func _process_double_spiral() -> void:
	var ds: Variant = _pattern
	var effective_rate: float = maxf(0.1, ds.fire_rate * _fire_rate_scale)
	var interval: float = 1.0 / effective_rate
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	_spiral_angle += ds.angle_step
	var arm_count: int = maxi(1, ds.arms_per_spiral)
	var arm_arc: float = TAU / float(arm_count)
	var speed: float = ds.bullet_speed * _bullet_speed_scale
	var origin: Vector2 = _owner_node.position
	for arm: int in range(arm_count):
		var base_angle: float = _spiral_angle + arm_arc * float(arm)
		_spawn_enemy_bullet_basic(origin, Vector2.from_angle(base_angle), speed)
		_spawn_enemy_bullet_basic(origin, Vector2.from_angle(base_angle + ds.separation_angle), speed)


func _process_radial_burst() -> void:
	var rb: RadialBurstPatternResource = _pattern as RadialBurstPatternResource
	var interval: float = rb.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	_emit_even_arc(_owner_node.position, 0.0, TAU, maxi(1, rb.bullet_count), rb.bullet_speed * _bullet_speed_scale)


func _process_rotating_radial() -> void:
	var rr: Variant = _pattern
	var interval: float = rr.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	_rotating_angle += rr.rotation_step
	_emit_even_arc(
		_owner_node.position,
		rr.initial_angle + _rotating_angle,
		TAU,
		maxi(1, rr.bullet_count),
		rr.bullet_speed * _bullet_speed_scale
	)


func _process_arc_pattern() -> void:
	var arcp: ArcPatternResource = _pattern as ArcPatternResource
	var interval: float = arcp.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	_arc_angle += arcp.sweep_step
	_emit_spread(
		_owner_node.position,
		_arc_angle,
		deg_to_rad(arcp.arc_degrees),
		maxi(1, arcp.bullet_count),
		arcp.bullet_speed * _bullet_speed_scale
	)


func _process_fan_spread() -> void:
	var fp: Variant = _pattern
	var interval: float = fp.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	var base_angle: float = _direction_to_target(_owner_node.position).angle() if fp.track_target else _arc_angle
	base_angle += _arc_angle
	_arc_angle += fp.sweep_step
	_emit_spread(
		_owner_node.position,
		base_angle,
		deg_to_rad(fp.spread_degrees),
		maxi(1, fp.bullet_count),
		fp.bullet_speed * _bullet_speed_scale
	)


func _process_shotgun_spread() -> void:
	var sp: Variant = _pattern
	var interval: float = sp.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	_burst_counter += 1
	var origin: Vector2 = _owner_node.position
	var pellets: int = maxi(1, sp.pellet_count)
	var spread: float = deg_to_rad(sp.spread_degrees)
	var jitter: float = deg_to_rad(sp.jitter_degrees)
	var base_angle: float = _direction_to_target(origin).angle()
	for idx: int in range(pellets):
		var ratio: float = 0.0 if pellets == 1 else float(idx) / float(pellets - 1)
		var angle: float = lerpf(base_angle - spread * 0.5, base_angle + spread * 0.5, ratio)
		var seed_value: float = float(_burst_counter * 131 + idx * 17 + sp.burst_seed_offset)
		var noise: float = _deterministic_01(seed_value) * 2.0 - 1.0
		angle += noise * jitter
		_spawn_enemy_bullet_basic(origin, Vector2.from_angle(angle), sp.bullet_speed * _bullet_speed_scale)


func _process_aimed_shot() -> void:
	var ap: Variant = _pattern
	var interval: float = ap.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	var origin: Vector2 = _owner_node.position
	var base_angle: float = _direction_to_target(origin).angle()
	_emit_spread(
		origin,
		base_angle,
		deg_to_rad(ap.spread_degrees),
		maxi(1, ap.shots_per_burst),
		ap.bullet_speed * _bullet_speed_scale
	)


func _process_predictive_shot() -> void:
	var pp: Variant = _pattern
	var interval: float = pp.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	var origin: Vector2 = _owner_node.position
	var speed: float = pp.bullet_speed * _bullet_speed_scale
	var lead_dir: Vector2 = _compute_predictive_direction(origin, speed, pp.max_lead_time, pp.fallback_to_aimed)
	var lead_angle: float = lead_dir.angle()
	_emit_spread(
		origin,
		lead_angle,
		deg_to_rad(pp.spread_degrees),
		maxi(1, pp.shots_per_burst),
		speed
	)


func _process_ring_pattern() -> void:
	var rp: Variant = _pattern
	var interval: float = rp.ring_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	var count: int = maxi(1, rp.bullet_count)
	var speed: float = rp.bullet_speed * _bullet_speed_scale
	var origin: Vector2 = _owner_node.position
	var spawn_radius: float = maxf(0.0, rp.spawn_radius)
	for idx: int in range(count):
		var angle: float = TAU * float(idx) / float(count)
		var dir: Vector2 = Vector2.from_angle(angle)
		if int(rp.ring_mode) == RING_MODE_COLLAPSING:
			var spawn_pos: Vector2 = origin + dir * maxf(40.0, spawn_radius)
			_spawn_enemy_bullet_basic(spawn_pos, -dir, speed)
		else:
			_spawn_enemy_bullet_basic(origin, dir, speed)


func _process_bullet_wall() -> void:
	var wp: Variant = _pattern
	var interval: float = wp.wall_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	_wall_phase += wp.advance_per_burst
	var count: int = maxi(1, wp.bullet_count)
	var wall_angle: float = wp.wall_angle + _wall_phase
	var tangent: Vector2 = Vector2.from_angle(wall_angle)
	var direction: Vector2 = Vector2(-tangent.y, tangent.x)
	var half_width: float = maxf(0.0, wp.wall_width) * 0.5
	var origin: Vector2 = _owner_node.position
	for idx: int in range(count):
		var ratio: float = 0.0 if count == 1 else float(idx) / float(count - 1)
		var offset: float = lerpf(-half_width, half_width, ratio)
		var spawn_pos: Vector2 = origin + tangent * offset
		_spawn_enemy_bullet_basic(spawn_pos, direction, wp.bullet_speed * _bullet_speed_scale)


func _process_bullet_grid() -> void:
	var gp: Variant = _pattern
	var interval: float = gp.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	var rows: int = maxi(1, gp.rows)
	var cols: int = maxi(1, gp.columns)
	var spacing: float = maxf(1.0, gp.spacing)
	var tangent: Vector2 = Vector2.from_angle(gp.grid_angle)
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	var origin: Vector2 = _owner_node.position
	var half_w: float = float(cols - 1) * spacing * 0.5
	var half_h: float = float(rows - 1) * spacing * 0.5
	for row: int in range(rows):
		for col: int in range(cols):
			var x: float = float(col) * spacing - half_w
			var y: float = float(row) * spacing - half_h
			var spawn_pos: Vector2 = origin + tangent * x + normal * y
			_spawn_enemy_bullet_basic(spawn_pos, normal, gp.bullet_speed * _bullet_speed_scale)


func _process_cross_pattern() -> void:
	var cp: CrossPatternResource = _pattern as CrossPatternResource
	var interval: float = cp.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	var base: float = cp.angle_offset + (PI * 0.25 if _cross_flip else 0.0)
	_cross_flip = not _cross_flip
	_emit_even_arc(_owner_node.position, base, TAU, 4, cp.bullet_speed * _bullet_speed_scale)


func _process_rotating_cross() -> void:
	var rc: Variant = _pattern
	var interval: float = rc.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	_rotating_angle += rc.angle_step
	_emit_even_arc(
		_owner_node.position,
		rc.initial_angle + _rotating_angle,
		TAU,
		maxi(2, rc.arms),
		rc.bullet_speed * _bullet_speed_scale
	)


func _process_star_pattern() -> void:
	var sp: Variant = _pattern
	var interval: float = sp.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	_star_angle += sp.rotation_step
	var point_count: int = maxi(3, sp.points)
	var bullet_count: int = point_count * 2
	var origin: Vector2 = _owner_node.position
	for idx: int in range(bullet_count):
		var angle: float = _star_angle + TAU * float(idx) / float(bullet_count)
		var speed_scale: float = 1.0 if (idx % 2) == 0 else clampf(sp.inner_scale, 0.15, 1.0)
		_spawn_enemy_bullet_basic(origin, Vector2.from_angle(angle), sp.bullet_speed * _bullet_speed_scale * speed_scale)


func _process_flower_pattern() -> void:
	var fp: Variant = _pattern
	var interval: float = fp.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval
	_flower_angle += fp.rotation_step
	var count: int = maxi(3, fp.bullet_count)
	var petals: float = float(maxi(1, fp.petal_count))
	var amp: float = clampf(fp.petal_amplitude, 0.0, 0.95)
	var origin: Vector2 = _owner_node.position
	for idx: int in range(count):
		var angle: float = _flower_angle + TAU * float(idx) / float(count)
		var speed_scale: float = 1.0 + amp * sin(angle * petals)
		_spawn_enemy_bullet_basic(origin, Vector2.from_angle(angle), fp.bullet_speed * _bullet_speed_scale * maxf(0.1, speed_scale))


func _process_delayed_radial_burst(delta: float) -> void:
	var dr: Variant = _pattern
	var count: int = maxi(1, dr.bullet_count)
	if _delayed_index <= 0:
		var burst_interval: float = dr.burst_interval / _fire_rate_scale
		if _fire_timer < burst_interval:
			return
		_fire_timer -= burst_interval
		_delayed_index = count
		_delayed_cooldown = maxf(0.0, dr.base_delay)

	if _delayed_cooldown > 0.0:
		_delayed_cooldown -= delta
		return

	var fired_index: int = count - _delayed_index
	var angle: float = TAU * float(fired_index) / float(count)
	var dir: Vector2 = Vector2.from_angle(angle)
	var speed: float = dr.bullet_speed * _bullet_speed_scale
	var spawn_pos: Vector2 = _owner_node.position - dir * dr.delay_radius_speed * float(fired_index) * maxf(0.0, dr.radial_delay_step)
	_spawn_enemy_bullet_basic(spawn_pos, dir, speed)
	_delayed_index -= 1
	_delayed_cooldown = maxf(0.0, dr.radial_delay_step)


func _process_advanced_trajectory() -> void:
	var ap: Variant = _pattern
	var interval: float = ap.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval

	var origin: Vector2 = _owner_node.position
	var count: int = maxi(1, ap.bullet_count)
	var spread: float = deg_to_rad(ap.spread_degrees)
	var speed: float = ap.bullet_speed * _bullet_speed_scale
	var base_angle: float = ap.base_angle_offset
	if ap.track_target:
		base_angle += _direction_to_target(origin).angle()

	for idx: int in range(count):
		var ratio: float = 0.0 if count == 1 else float(idx) / float(count - 1)
		var angle: float = base_angle if count == 1 else lerpf(base_angle - spread * 0.5, base_angle + spread * 0.5, ratio)
		var dir: Vector2 = Vector2.from_angle(angle)
		if int(ap.mode) == ADV_MODE_SINE:
			_bullet_manager.spawn_enemy_bullet_advanced(
				origin,
				dir,
				speed,
				_source_projectile_damage,
				_source_is_boss,
				_pattern_bullet_color,
				BulletManager.ENEMY_BEHAVIOR_SINE,
				ap.sine_amplitude,
				ap.sine_frequency,
				float(idx) * ap.sine_phase_step
			)
		elif int(ap.mode) == ADV_MODE_CURVED:
			_bullet_manager.spawn_enemy_bullet_advanced(
				origin,
				dir,
				speed,
				_source_projectile_damage,
				_source_is_boss,
				_pattern_bullet_color,
				BulletManager.ENEMY_BEHAVIOR_CURVED,
				0.0,
				0.0,
				0.0,
				ap.turn_rate
			)
		elif int(ap.mode) == ADV_MODE_HOMING:
			_bullet_manager.spawn_enemy_bullet_advanced(
				origin,
				dir,
				speed,
				_source_projectile_damage,
				_source_is_boss,
				_pattern_bullet_color,
				BulletManager.ENEMY_BEHAVIOR_HOMING,
				0.0,
				0.0,
				0.0,
				ap.turn_rate,
				ap.homing_delay
			)
		else:
			_bullet_manager.spawn_enemy_bullet_advanced(
				origin,
				dir,
				speed,
				_source_projectile_damage,
				_source_is_boss,
				_pattern_bullet_color,
				BulletManager.ENEMY_BEHAVIOR_SPLIT,
				0.0,
				0.0,
				0.0,
				0.0,
				0.0,
				ap.split_time,
				ap.split_count,
				deg_to_rad(ap.split_spread_degrees),
				ap.split_speed_scale,
				ap.split_depth
			)


func _emit_even_arc(origin: Vector2, base_angle: float, total_arc: float, bullet_count: int, speed: float) -> void:
	if bullet_count <= 1:
		_spawn_enemy_bullet_basic(origin, Vector2.from_angle(base_angle), speed)
		return
	for idx: int in range(bullet_count):
		var angle: float = base_angle + total_arc * float(idx) / float(bullet_count)
		_spawn_enemy_bullet_basic(origin, Vector2.from_angle(angle), speed)


func _emit_spread(origin: Vector2, base_angle: float, spread: float, bullet_count: int, speed: float) -> void:
	if bullet_count <= 1:
		_spawn_enemy_bullet_basic(origin, Vector2.from_angle(base_angle), speed)
		return
	for idx: int in range(bullet_count):
		var ratio: float = float(idx) / float(bullet_count - 1)
		var angle: float = lerpf(base_angle - spread * 0.5, base_angle + spread * 0.5, ratio)
		_spawn_enemy_bullet_basic(origin, Vector2.from_angle(angle), speed)


func _spawn_enemy_bullet_basic(origin: Vector2, dir: Vector2, speed: float) -> void:
	_bullet_manager.spawn_enemy_bullet_colored(
		origin,
		dir,
		speed,
		_source_projectile_damage,
		_source_is_boss,
		_pattern_bullet_color
	)


func _direction_to_target(origin: Vector2) -> Vector2:
	var target: Vector2 = _get_target_position()
	var delta: Vector2 = target - origin
	if delta.length_squared() <= 0.0001:
		return Vector2.RIGHT
	return delta.normalized()


func _compute_predictive_direction(origin: Vector2, bullet_speed: float, max_lead_time: float, fallback_to_aimed: bool) -> Vector2:
	var target_pos: Vector2 = _get_target_position()
	var target_vel: Vector2 = _target_velocity
	var rel_pos: Vector2 = target_pos - origin
	var rel_speed_sq: float = bullet_speed * bullet_speed
	var target_speed_sq: float = target_vel.length_squared()
	var a: float = target_speed_sq - rel_speed_sq
	var b: float = 2.0 * rel_pos.dot(target_vel)
	var c: float = rel_pos.length_squared()
	var t: float = -1.0

	if absf(a) < 0.00001:
		if absf(b) > 0.00001:
			t = -c / b
	else:
		var disc: float = b * b - 4.0 * a * c
		if disc >= 0.0:
			var sqrt_disc: float = sqrt(disc)
			var t1: float = (-b - sqrt_disc) / (2.0 * a)
			var t2: float = (-b + sqrt_disc) / (2.0 * a)
			if t1 > 0.0 and t2 > 0.0:
				t = minf(t1, t2)
			elif t1 > 0.0:
				t = t1
			elif t2 > 0.0:
				t = t2

	if t > 0.0:
		t = minf(t, maxf(0.05, max_lead_time))
		var intercept: Vector2 = target_pos + target_vel * t
		var intercept_delta: Vector2 = intercept - origin
		if intercept_delta.length_squared() > 0.0001:
			return intercept_delta.normalized()

	if fallback_to_aimed:
		return _direction_to_target(origin)
	return Vector2.RIGHT


func _update_target_velocity(delta: float) -> void:
	var current_target: Vector2 = _get_target_position()
	if delta > 0.0001:
		_target_velocity = (current_target - _target_last_position) / delta
	_target_last_position = current_target


func _get_target_position() -> Vector2:
	if _owner_node == null:
		return Vector2.ZERO
	if _owner_node.has_method("get_target_position"):
		return _owner_node.call("get_target_position") as Vector2
	return _owner_node.position


func _deterministic_01(seed_value: float) -> float:
	var value: float = sin(seed_value * 12.9898 + 78.233) * 43758.5453
	return value - floor(value)


func _refresh_owner_damage_source() -> void:
	_source_projectile_damage = 1.0
	_source_is_boss = false
	if _owner_node == null:
		return
	if _owner_node.has_method("get_projectile_damage"):
		_source_projectile_damage = float(_owner_node.call("get_projectile_damage"))
	if _owner_node.has_method("is_boss_unit"):
		_source_is_boss = bool(_owner_node.call("is_boss_unit"))


func _refresh_pattern_color() -> void:
	if _pattern == null:
		_pattern_bullet_color = Color(1.0, 0.3, 0.3, 1.0)
		return
	_pattern_bullet_color = _pattern.bullet_color
