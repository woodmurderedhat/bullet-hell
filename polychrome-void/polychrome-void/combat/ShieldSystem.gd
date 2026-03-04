## ShieldSystem — deterministic rotating shield runtime component.
## Resolves exclusive shield branches and branch-specific combat effects.
class_name ShieldSystem
extends Node2D

enum Branch {
	NONE,
	ABSORB,
	REPULSE,
	AURA,
}

const SHIELD_RADIUS_BASE: float = 48.0
const SHIELD_RADIUS_PER_STACK: float = 8.0
const SHIELD_ROTATION_BASE: float = 2.0
const SHIELD_ROTATION_PER_STACK: float = 0.3
const SHIELD_COOLDOWN_REPULSE: float = 0.22
const SHIELD_COOLDOWN_AURA: float = 0.16
const SHIELD_COOLDOWN_FAST_DELTA: float = 0.04
const SHIELD_REPULSE_MIN_SPEED: float = 480.0
const SHIELD_REPULSE_DAMAGE_BASE: float = 0.75
const SHIELD_REPULSE_DAMAGE_PER_STACK: float = 0.10
const SHIELD_ABSORB_BASE_CAPACITY: int = 1
const SHIELD_AURA_CONTACT_COOLDOWN: float = 0.28
const SHIELD_AURA_DAMAGE_BASE: float = 14.0
const SHIELD_AURA_DAMAGE_PER_STACK: float = 8.0
const SHIELD_RING_THICKNESS: float = 2.0

const SHIELD_COLOR_ABSORB: Color = Color(0.45, 0.85, 1.0, 0.9)
const SHIELD_COLOR_REPULSE: Color = Color(1.0, 0.66, 0.38, 0.9)
const SHIELD_COLOR_AURA: Color = Color(0.92, 0.35, 1.0, 0.9)

var _player: Node2D = null
var _modifier: ModifierComponent = null
var _bullet_manager: BulletManager = null

var _active_branch: Branch = Branch.NONE
var _shield_radius: float = 0.0
var _rotation_speed: float = 0.0
var _rotation_angle: float = 0.0
var _branch_intercept_cooldown: float = 0.0
var _intercept_cooldown_remaining: float = 0.0

var _absorb_capacity: int = 0
var _absorb_charges: int = 0
var _aura_contact_next_hit_time: Dictionary = {}


func _ready() -> void:
	set_process(false)
	visible = false
	z_index = 20

	EventBus.run_ended.connect(_on_run_ended)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.wave_complete.connect(_on_wave_complete)


func initialise(player: Node2D, modifier: ModifierComponent, bullet_manager: BulletManager) -> void:
	_player = player
	_modifier = modifier
	_bullet_manager = bullet_manager
	refresh_state(true)


func refresh_state(fill_absorb: bool = false) -> void:
	var previous_branch: Branch = _active_branch
	_active_branch = _resolve_branch()
	visible = _active_branch != Branch.NONE

	if _active_branch == Branch.NONE:
		_shield_radius = 0.0
		_rotation_speed = 0.0
		_branch_intercept_cooldown = 0.0
		_intercept_cooldown_remaining = 0.0
		_absorb_capacity = 0
		_absorb_charges = 0
		_aura_contact_next_hit_time.clear()
		queue_redraw()
		return

	var radius_stacks: int = _trigger_stack(&"shield_radius_up")
	var orbit_stacks: int = _trigger_stack(&"shield_orbit_fragments")
	var cooldown_fast_stacks: int = _trigger_stack(&"shield_cooldown_fast")

	_shield_radius = SHIELD_RADIUS_BASE + SHIELD_RADIUS_PER_STACK * float(radius_stacks)
	_rotation_speed = SHIELD_ROTATION_BASE + SHIELD_ROTATION_PER_STACK * float(orbit_stacks)

	match _active_branch:
		Branch.REPULSE:
			_branch_intercept_cooldown = maxf(0.05, SHIELD_COOLDOWN_REPULSE - SHIELD_COOLDOWN_FAST_DELTA * float(cooldown_fast_stacks))
		Branch.AURA:
			_branch_intercept_cooldown = maxf(0.05, SHIELD_COOLDOWN_AURA - SHIELD_COOLDOWN_FAST_DELTA * float(cooldown_fast_stacks))
		_:
			_branch_intercept_cooldown = 0.0

	if _active_branch == Branch.ABSORB:
		_absorb_capacity = SHIELD_ABSORB_BASE_CAPACITY + _trigger_stack(&"shield_absorb_charge")
		_absorb_capacity = maxi(_absorb_capacity, SHIELD_ABSORB_BASE_CAPACITY)
		if fill_absorb or previous_branch != Branch.ABSORB:
			_absorb_charges = _absorb_capacity
		else:
			_absorb_charges = mini(_absorb_charges, _absorb_capacity)
	else:
		_absorb_capacity = 0
		_absorb_charges = 0

	if previous_branch != _active_branch:
		_intercept_cooldown_remaining = 0.0
		_aura_contact_next_hit_time.clear()

	if _player != null:
		global_position = _player.global_position
	queue_redraw()


func is_active() -> bool:
	return _active_branch != Branch.NONE


func get_radius() -> float:
	return _shield_radius


func try_intercept_enemy_bullet(hit_pos: Vector2, hit_velocity: Vector2) -> bool:
	if _active_branch == Branch.NONE or _player == null:
		return false

	var delta: Vector2 = hit_pos - _player.global_position
	if delta.length_squared() > _shield_radius * _shield_radius:
		return false

	match _active_branch:
		Branch.ABSORB:
			if _absorb_charges <= 0:
				return false
			_absorb_charges -= 1
			queue_redraw()
			return true
		Branch.REPULSE:
			if _intercept_cooldown_remaining > 0.0:
				return false
			_intercept_cooldown_remaining = _branch_intercept_cooldown
			_spawn_repulse_conversion(hit_pos, hit_velocity, delta)
			return true
		Branch.AURA:
			if _intercept_cooldown_remaining > 0.0:
				return false
			_intercept_cooldown_remaining = _branch_intercept_cooldown
			return true
		_:
			return false


func try_apply_aura_contact(enemy: Variant, now: float) -> void:
	if _active_branch != Branch.AURA or _player == null:
		return
	if not is_instance_valid(enemy):
		return

	var enemy_id: int = int(enemy.enemy_id)
	var next_allowed: float = float(_aura_contact_next_hit_time.get(enemy_id, 0.0))
	if now < next_allowed:
		return

	var combined_radius: float = _shield_radius + float(enemy.collision_radius)
	var delta: Vector2 = Vector2(enemy.position) - _player.global_position
	if delta.length_squared() > combined_radius * combined_radius:
		return

	_aura_contact_next_hit_time[enemy_id] = now + SHIELD_AURA_CONTACT_COOLDOWN
	var aura_stacks: int = maxi(1, _trigger_stack(&"shield_aura_burst"))
	var damage: float = SHIELD_AURA_DAMAGE_BASE + SHIELD_AURA_DAMAGE_PER_STACK * float(aura_stacks - 1)
	EventBus.bullet_hit_enemy.emit(enemy_id, damage)


func _process(delta: float) -> void:
	if _active_branch == Branch.NONE:
		return

	if _player != null:
		global_position = _player.global_position
	_rotation_angle = wrapf(_rotation_angle + _rotation_speed * delta, 0.0, TAU)
	if _intercept_cooldown_remaining > 0.0:
		_intercept_cooldown_remaining = maxf(0.0, _intercept_cooldown_remaining - delta)
	queue_redraw()


func _draw() -> void:
	if _active_branch == Branch.NONE:
		return

	var branch_color: Color = _color_for_branch(_active_branch)
	draw_arc(Vector2.ZERO, _shield_radius, 0.0, TAU, 56, branch_color, SHIELD_RING_THICKNESS, true)

	var fragment_count: int = maxi(1, _trigger_stack(&"shield_orbit_fragments") + 1)
	for i: int in range(fragment_count):
		var angle: float = _rotation_angle + TAU * float(i) / float(fragment_count)
		var p: Vector2 = Vector2.from_angle(angle) * _shield_radius
		draw_circle(p, 4.0, branch_color)

	if _active_branch == Branch.ABSORB:
		for c: int in range(_absorb_charges):
			var charge_angle: float = TAU * float(c) / float(maxi(1, _absorb_capacity))
			var cp: Vector2 = Vector2.from_angle(charge_angle) * (_shield_radius - 10.0)
			draw_circle(cp, 2.5, Color(1.0, 1.0, 1.0, 0.9))


func _resolve_branch() -> Branch:
	if _trigger_stack(&"shield_branch_absorb") > 0:
		return Branch.ABSORB
	if _trigger_stack(&"shield_branch_repulse") > 0:
		return Branch.REPULSE
	if _trigger_stack(&"shield_branch_aura") > 0:
		return Branch.AURA
	return Branch.NONE


func _trigger_stack(trigger_id: StringName) -> int:
	if _modifier == null:
		return 0
	return _modifier.get_trigger_stack(trigger_id)


func _spawn_repulse_conversion(hit_pos: Vector2, hit_velocity: Vector2, player_to_bullet: Vector2) -> void:
	if _bullet_manager == null:
		return

	var out_dir: Vector2 = player_to_bullet.normalized()
	if out_dir.length_squared() <= 0.0001:
		out_dir = -hit_velocity.normalized()
	if out_dir.length_squared() <= 0.0001:
		out_dir = Vector2.UP

	var speed: float = maxf(hit_velocity.length(), SHIELD_REPULSE_MIN_SPEED)
	var repulse_stacks: int = _trigger_stack(&"shield_repulse_power")
	var damage_scale: float = SHIELD_REPULSE_DAMAGE_BASE + SHIELD_REPULSE_DAMAGE_PER_STACK * float(repulse_stacks)
	_bullet_manager.spawn_player_bullet_advanced(
		hit_pos,
		out_dir,
		speed,
		BulletManager.PLAYER_BEHAVIOR_STRAIGHT,
		0.0,
		0.0,
		0.0,
		0,
		0,
		damage_scale
	)


func _color_for_branch(branch: Branch) -> Color:
	match branch:
		Branch.ABSORB:
			return SHIELD_COLOR_ABSORB
		Branch.REPULSE:
			return SHIELD_COLOR_REPULSE
		Branch.AURA:
			return SHIELD_COLOR_AURA
		_:
			return Color(1.0, 1.0, 1.0, 0.6)


func _on_enemy_died(enemy_id: int, _position: Vector2, _score: int) -> void:
	_aura_contact_next_hit_time.erase(enemy_id)
	if _active_branch != Branch.ABSORB:
		return
	if _absorb_capacity <= 0:
		return
	var recharge_bonus: int = _trigger_stack(&"shield_absorb_kill_boost")
	var recharge_amount: int = maxi(1, 1 + recharge_bonus)
	_absorb_charges = mini(_absorb_capacity, _absorb_charges + recharge_amount)
	queue_redraw()


func _on_wave_complete(_arena_index: int) -> void:
	_aura_contact_next_hit_time.clear()


func _on_run_ended(_result: Dictionary) -> void:
	set_process(false)
	visible = false
