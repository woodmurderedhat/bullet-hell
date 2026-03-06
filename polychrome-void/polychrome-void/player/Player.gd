## Player — handles input, movement, drawing, firing, and HP.
## Shape: equilateral triangle rotated toward mouse/movement direction.
## Add via scenes/Player.tscn.
class_name Player
extends Node2D

## Inner class for BASE player stats — values here are never modified by upgrades.
## Effective values are computed via ModifierComponent.get_stat(base, key).
class PlayerStats:
	var max_hp: float        = 10.0
	var current_hp: float    = 10.0
	## Base values — used as input to ModifierComponent.get_stat().
	var speed: float         = 110.0
	var fire_rate: float     = 3.0    ## Bullets per second.
	var bullet_damage: float = 10.0
	var bullet_speed: float  = 480.0

## Triangle visual half-size.
const TRIANGLE_HALF: float = 12.0

## Invincibility frames after taking a hit (seconds).
const INVINCIBILITY_TIME: float = 0.35
const SPLIT_FIRE_ARC_DEGREES: float = 10.0
const RANDOM_SPREAD_DEGREES_PER_STACK: float = 10.0
const SECONDARY_DAMAGE_SCALE: float = 0.65

const WAVE_BASE_AMPLITUDE: float = 12.0
const WAVE_BASE_FREQUENCY: float = 8.0
const MOVE_TARGET_STOP_DISTANCE: float = 8.0

const FAN_BASE_BULLETS: int = 3
const FAN_BULLETS_PER_STACK: int = 2
const FAN_MAX_BULLETS: int = 9
const FAN_BASE_SPREAD_DEGREES: float = 16.0

const PULSE_BASE_BULLETS: int = 6
const PULSE_BULLETS_PER_STACK: int = 2
const PULSE_MAX_BULLETS: int = 12

const COLOR_ACTIVE: Color  = Color(0.4, 1.0, 0.6, 1.0)
const COLOR_HURT: Color    = Color(1.0, 1.0, 1.0, 0.4)
const GUN_MOUNT_OFFSET: Vector2 = Vector2(0.0, -10.0)
const GUN_BARREL_LENGTH: float = 18.0
const GUN_BARREL_HALF_WIDTH: float = 2.5
const GUN_BODY_RADIUS: float = 4.0

var stats: PlayerStats = PlayerStats.new()

var _fire_timer: float = 0.0
var _invincibility_timer: float = 0.0
var _is_hurt_flash: bool = false
var _gameplay_input_enabled: bool = true
var _has_move_target: bool = false
var _move_target: Vector2 = Vector2.ZERO
var _gun_world_dir: Vector2 = Vector2.UP

# Cached reference set by Main.tscn after _ready.
var _bullet_manager: BulletManager = null
var _collision_system: CollisionSystem = null
var _modifier: ModifierComponent = null  ## Optional — nil = no upgrades active.

## Arena bounds (set by Main).
var arena_min: Vector2 = Vector2(40.0, 40.0)
var arena_max: Vector2 = Vector2(1240.0, 680.0)

## Pre-computed triangle vertices (local space, updated when TRIANGLE_HALF changes).
var _tri_verts: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_build_tri_verts()
	EventBus.bullet_hit_player.connect(_on_bullet_hit_player)
	EventBus.run_ended.connect(_on_run_ended)


func _build_tri_verts() -> void:
	_tri_verts.resize(3)
	# Tip pointing up (local -Y), base at bottom.
	_tri_verts[0] = Vector2(0.0, -TRIANGLE_HALF * 1.6)
	_tri_verts[1] = Vector2(TRIANGLE_HALF, TRIANGLE_HALF)
	_tri_verts[2] = Vector2(-TRIANGLE_HALF, TRIANGLE_HALF)


## Called by Main once all systems are ready.
func initialise(bm: BulletManager, cs: CollisionSystem, modifier: ModifierComponent = null) -> void:
	_bullet_manager = bm
	_collision_system = cs
	_modifier = modifier
	if _collision_system != null:
		_collision_system.set_player_damage(_effective_bullet_damage())


func _process(delta: float) -> void:
	_update_gun_aim()
	_handle_movement(delta)
	_handle_firing(delta)
	_handle_invincibility(delta)
	_handle_regen(delta)
	queue_redraw()


func _update_gun_aim() -> void:
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 0.0001:
		_gun_world_dir = to_mouse.normalized()


func _handle_regen(delta: float) -> void:
	if _modifier == null:
		return
	var regen_rate: float = _modifier.get_stat(0.0, &"hp_regen")
	if regen_rate > 0.0:
		apply_regen(regen_rate, delta)


func _handle_movement(delta: float) -> void:
	var dir: Vector2 = Vector2.ZERO
	if _gameplay_input_enabled:
		if Input.is_action_just_pressed("move_mouse"):
			_move_target = get_global_mouse_position()
			_has_move_target = true
		if Input.is_action_pressed("move_mouse"):
			_move_target = get_global_mouse_position()
			_has_move_target = true

		if Input.is_action_pressed("move_up"):
			dir.y -= 1.0
		if Input.is_action_pressed("move_down"):
			dir.y += 1.0
		if Input.is_action_pressed("move_left"):
			dir.x -= 1.0
		if Input.is_action_pressed("move_right"):
			dir.x += 1.0

		if dir != Vector2.ZERO:
			dir = dir.normalized()
			_has_move_target = false
		elif _has_move_target:
			var to_target: Vector2 = _move_target - position
			if to_target.length_squared() > MOVE_TARGET_STOP_DISTANCE * MOVE_TARGET_STOP_DISTANCE:
				dir = to_target.normalized()
			else:
				_has_move_target = false
	else:
		_has_move_target = false

	if dir != Vector2.ZERO:
		# Rotate triangle to face movement direction.
		rotation = dir.angle() + PI * 0.5

	var effective_speed: float = _effective_stat(stats.speed, &"speed")
	position += dir * effective_speed * delta
	_wrap_position_to_arena()


func _wrap_position_to_arena() -> void:
	if position.x < arena_min.x:
		position.x = arena_max.x
	elif position.x > arena_max.x:
		position.x = arena_min.x

	if position.y < arena_min.y:
		position.y = arena_max.y
	elif position.y > arena_max.y:
		position.y = arena_min.y


func _handle_firing(delta: float) -> void:
	if _bullet_manager == null:
		return
	if not _gameplay_input_enabled:
		return
	_fire_timer += delta
	var effective_rate: float = _effective_stat(stats.fire_rate, &"fire_rate")
	var fire_interval: float = 1.0 / maxf(effective_rate, 0.1)
	if Input.is_action_just_pressed("fire"):
		_fire_timer = fire_interval
	if Input.is_action_pressed("fire") and _fire_timer >= fire_interval:
		_fire_timer = 0.0
		EventBus.player_fired.emit()
		var dir: Vector2 = _gun_world_dir
		var eff_bspeed: float = _effective_stat(stats.bullet_speed, &"bullet_speed")
		var split_hit_stacks: int = _trigger_stack(&"split_on_hit")
		var split_fire_stacks: int = _trigger_stack(&"split_on_fire")
		var wave_sine_stacks: int = _trigger_stack(&"wave_sine")
		var fan_stacks: int = _trigger_stack(&"wave_fan")
		var pulse_stacks: int = _trigger_stack(&"wave_pulse")
		var chain_stacks: int = _trigger_stack(&"chain_lightning")
		var pulse_aoe_stacks: int = _trigger_stack(&"pulse_aoe")
		var pierce_stacks: int = _trigger_stack(&"pierce")
		var chaos_stacks: int = _trigger_stack(&"random_direction")
		var split_budget: int = _compute_split_budget_from_stacks(
			split_hit_stacks,
			split_fire_stacks,
			wave_sine_stacks,
			fan_stacks,
			pulse_stacks,
			chain_stacks,
			pulse_aoe_stacks,
			pierce_stacks
		)

		_fire_primary(dir, eff_bspeed, 1.0, split_fire_stacks, wave_sine_stacks, chaos_stacks, split_budget)

		if fan_stacks > 0:
			_fire_fan(dir, eff_bspeed, fan_stacks, wave_sine_stacks, chaos_stacks, split_budget)

		if pulse_stacks > 0:
			_fire_pulse_ring(eff_bspeed, pulse_stacks, wave_sine_stacks, chaos_stacks, split_budget)


func _fire_primary(
	dir: Vector2,
	bullet_speed: float,
	damage_scale: float,
	split_fire_stacks: int,
	wave_sine_stacks: int,
	chaos_stacks: int,
	split_budget: int
) -> void:
	_spawn_weapon_bullet(dir, bullet_speed, damage_scale, 0, wave_sine_stacks, chaos_stacks, split_budget)

	if split_fire_stacks <= 0:
		return

	var side_pairs: int = mini(1 + split_fire_stacks, 4)
	for i: int in range(side_pairs):
		var t: float = float(i + 1)
		var spread: float = deg_to_rad(SPLIT_FIRE_ARC_DEGREES * t)
		_spawn_weapon_bullet(dir.rotated(spread), bullet_speed, SECONDARY_DAMAGE_SCALE, 1, wave_sine_stacks, chaos_stacks, split_budget)
		_spawn_weapon_bullet(dir.rotated(-spread), bullet_speed, SECONDARY_DAMAGE_SCALE, 1, wave_sine_stacks, chaos_stacks, split_budget)


func _fire_fan(
	dir: Vector2,
	bullet_speed: float,
	fan_stacks: int,
	wave_sine_stacks: int,
	chaos_stacks: int,
	split_budget: int
) -> void:
	var count: int = mini(FAN_BASE_BULLETS + FAN_BULLETS_PER_STACK * (fan_stacks - 1), FAN_MAX_BULLETS)
	if count < 2:
		_spawn_weapon_bullet(dir, bullet_speed, SECONDARY_DAMAGE_SCALE, 1, wave_sine_stacks, chaos_stacks, split_budget)
		return

	var spread_deg: float = FAN_BASE_SPREAD_DEGREES + float(fan_stacks - 1) * 4.0
	var spread_rad: float = deg_to_rad(spread_deg)
	for i: int in range(count):
		var ratio: float = float(i) / float(count - 1)
		var offset: float = lerpf(-spread_rad, spread_rad, ratio)
		_spawn_weapon_bullet(dir.rotated(offset), bullet_speed, SECONDARY_DAMAGE_SCALE, 1, wave_sine_stacks, chaos_stacks, split_budget)


func _fire_pulse_ring(
	bullet_speed: float,
	pulse_stacks: int,
	wave_sine_stacks: int,
	chaos_stacks: int,
	split_budget: int
) -> void:
	var count: int = mini(PULSE_BASE_BULLETS + PULSE_BULLETS_PER_STACK * (pulse_stacks - 1), PULSE_MAX_BULLETS)
	if count <= 0:
		return

	var rotation_offset: float = 0.0
	if _modifier != null:
		rotation_offset = RandomService.next_float() * TAU

	for i: int in range(count):
		var angle: float = rotation_offset + TAU * float(i) / float(count)
		var dir: Vector2 = Vector2.from_angle(angle)
		_spawn_weapon_bullet(dir, bullet_speed, SECONDARY_DAMAGE_SCALE, 1, wave_sine_stacks, chaos_stacks, split_budget)


func _spawn_weapon_bullet(
	direction: Vector2,
	bullet_speed: float,
	damage_scale: float,
	split_depth: int,
	wave_stacks: int,
	chaos_stacks: int,
	split_budget: int
) -> void:
	var shot_dir: Vector2 = _apply_random_direction(direction, chaos_stacks)
	var behavior_kind: int = BulletManager.PLAYER_BEHAVIOR_STRAIGHT
	var wave_amp: float = 0.0
	var wave_freq: float = 0.0
	var wave_phase: float = 0.0
	if wave_stacks > 0:
		behavior_kind = BulletManager.PLAYER_BEHAVIOR_WAVE
		wave_amp = WAVE_BASE_AMPLITUDE + float(wave_stacks - 1) * 2.0
		wave_freq = WAVE_BASE_FREQUENCY + float(wave_stacks - 1)
		wave_phase = RandomService.next_float() * TAU

	_bullet_manager.spawn_player_bullet_advanced(
		position,
		shot_dir,
		bullet_speed,
		behavior_kind,
		wave_amp,
		wave_freq,
		wave_phase,
		split_depth,
		split_budget,
		damage_scale
	)


func _apply_random_direction(direction: Vector2, chaos_stacks: int) -> Vector2:
	if chaos_stacks <= 0:
		return direction.normalized()
	var max_spread_deg: float = minf(RANDOM_SPREAD_DEGREES_PER_STACK * float(chaos_stacks), 45.0)
	var roll: float = RandomService.next_float() * 2.0 - 1.0
	var angle_offset: float = deg_to_rad(max_spread_deg * roll)
	return direction.normalized().rotated(angle_offset)


func _compute_split_budget_from_stacks(
	split_hit_stacks: int,
	split_fire_stacks: int,
	wave_sine_stacks: int,
	fan_stacks: int,
	pulse_stacks: int,
	chain_stacks: int,
	pulse_aoe_stacks: int,
	pierce_stacks: int
) -> int:
	if split_hit_stacks <= 0:
		return 0

	var behavior_stacks: int = 0
	behavior_stacks += split_hit_stacks
	behavior_stacks += split_fire_stacks
	behavior_stacks += wave_sine_stacks
	behavior_stacks += fan_stacks
	behavior_stacks += pulse_stacks
	behavior_stacks += chain_stacks
	behavior_stacks += pulse_aoe_stacks
	behavior_stacks += pierce_stacks

	return clampi(1 + behavior_stacks / 2, 1, 10)


func _trigger_stack(trigger_id: StringName) -> int:
	if _modifier == null:
		return 0
	return _modifier.get_trigger_stack(trigger_id)


func _handle_invincibility(delta: float) -> void:
	if _invincibility_timer > 0.0:
		_invincibility_timer -= delta
		_is_hurt_flash = fmod(_invincibility_timer, 0.1) > 0.05
	else:
		_is_hurt_flash = false


func _draw() -> void:
	var col: Color = COLOR_HURT if _is_hurt_flash else COLOR_ACTIVE
	draw_colored_polygon(_tri_verts, col)
	# Thin outline.
	draw_polyline(_tri_verts + PackedVector2Array([_tri_verts[0]]),
		Color(1.0, 1.0, 1.0, 0.6), 1.0)

	var gun_col: Color = col
	var mount: Vector2 = GUN_MOUNT_OFFSET
	var gun_local_angle: float = _gun_world_dir.angle() - rotation
	var gun_forward: Vector2 = Vector2.from_angle(gun_local_angle)
	var gun_side: Vector2 = Vector2(-gun_forward.y, gun_forward.x)
	var p0: Vector2 = mount - gun_side * GUN_BARREL_HALF_WIDTH
	var p1: Vector2 = mount + gun_side * GUN_BARREL_HALF_WIDTH
	var tip_base: Vector2 = mount + gun_forward * GUN_BARREL_LENGTH
	var p2: Vector2 = tip_base + gun_side * GUN_BARREL_HALF_WIDTH
	var p3: Vector2 = tip_base - gun_side * GUN_BARREL_HALF_WIDTH
	draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), gun_col)
	draw_circle(mount, GUN_BODY_RADIUS, Color(1.0, 1.0, 1.0, 0.85))


func _on_bullet_hit_player(damage: float) -> void:
	if _invincibility_timer > 0.0:
		return  # Invincible — ignore hit.
	stats.current_hp -= damage
	_invincibility_timer = INVINCIBILITY_TIME
	if stats.current_hp <= 0.0:
		stats.current_hp = 0.0
		EventBus.player_died.emit()


func _on_run_ended(_result: Dictionary) -> void:
	set_process(false)
	set_gameplay_input_enabled(false)


func set_gameplay_input_enabled(enabled: bool) -> void:
	_gameplay_input_enabled = enabled
	if not enabled:
		_has_move_target = false


## --- Stat helpers -----------------------------------------------------------

## Return the effective (modifier-scaled) value for a stat key.
func _effective_stat(base: float, key: StringName) -> float:
	if _modifier != null:
		return _modifier.get_stat(base, key)
	return base


func _effective_bullet_damage() -> float:
	return _effective_stat(stats.bullet_damage, &"bullet_damage")


## Effective max HP (used by HUD for bar display).
func effective_max_hp() -> float:
	return _effective_stat(stats.max_hp, &"max_hp")


## Called after an upgrade is applied so CollisionSystem updates damage value.
func refresh_stats() -> void:
	if _collision_system != null:
		_collision_system.set_player_damage(_effective_bullet_damage())


## Apply passive HP regeneration (called by triggers each second).
func apply_regen(hp_per_second: float, delta: float) -> void:
	var effective_max: float = effective_max_hp()
	stats.current_hp = minf(stats.current_hp + hp_per_second * delta, effective_max)
