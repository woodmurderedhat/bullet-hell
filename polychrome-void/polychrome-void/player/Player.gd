## Player — handles input, movement, drawing, firing, and HP.
## Shape: equilateral triangle rotated toward mouse/movement direction.
## Add via scenes/Player.tscn.
class_name Player
extends Node2D

## Inner class for BASE player stats — values here are never modified by upgrades.
## Effective values are computed via ModifierComponent.get_stat(base, key).
class PlayerStats:
	var max_hp: float        = 100.0
	var current_hp: float    = 100.0
	## Base values — used as input to ModifierComponent.get_stat().
	var speed: float         = 220.0
	var fire_rate: float     = 8.0    ## Bullets per second.
	var bullet_damage: float = 10.0
	var bullet_speed: float  = 480.0

## Triangle visual half-size.
const TRIANGLE_HALF: float = 12.0

## Invincibility frames after taking a hit (seconds).
const INVINCIBILITY_TIME: float = 0.5

const COLOR_ACTIVE: Color  = Color(0.4, 1.0, 0.6, 1.0)
const COLOR_HURT: Color    = Color(1.0, 1.0, 1.0, 0.4)

var stats: PlayerStats = PlayerStats.new()

var _fire_timer: float = 0.0
var _invincibility_timer: float = 0.0
var _is_hurt_flash: bool = false

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
	_handle_movement(delta)
	_handle_firing(delta)
	_handle_invincibility(delta)
	_handle_regen(delta)
	queue_redraw()


func _handle_regen(delta: float) -> void:
	if _modifier == null:
		return
	var regen_rate: float = _modifier.get_stat(0.0, &"hp_regen")
	if regen_rate > 0.0:
		apply_regen(regen_rate, delta)


func _handle_movement(delta: float) -> void:
	var dir: Vector2 = Vector2.ZERO
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
		# Rotate triangle to face movement direction.
		rotation = dir.angle() + PI * 0.5

	var effective_speed: float = _effective_stat(stats.speed, &"speed")
	position += dir * effective_speed * delta
	# Clamp to arena bounds.
	position.x = clampf(position.x, arena_min.x, arena_max.x)
	position.y = clampf(position.y, arena_min.y, arena_max.y)


func _handle_firing(delta: float) -> void:
	if _bullet_manager == null:
		return
	_fire_timer += delta
	var effective_rate: float = _effective_stat(stats.fire_rate, &"fire_rate")
	var fire_interval: float = 1.0 / maxf(effective_rate, 0.1)
	if Input.is_action_pressed("fire") and _fire_timer >= fire_interval:
		_fire_timer = 0.0
		# Fire in facing direction.
		var dir: Vector2 = Vector2.from_angle(rotation - PI * 0.5)
		var eff_bspeed: float = _effective_stat(stats.bullet_speed, &"bullet_speed")
		_bullet_manager.spawn_player_bullet(position, dir, eff_bspeed)


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
