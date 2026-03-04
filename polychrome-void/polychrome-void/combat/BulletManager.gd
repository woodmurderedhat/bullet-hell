## BulletManager — pooled bullet system using MultiMeshInstance2D.
## Manages up to MAX_BULLETS player bullets and MAX_BULLETS enemy bullets.
## No per-bullet nodes; all data is stored in PackedFloat32Array pools.
## Add as a child of Main.tscn.
class_name BulletManager
extends Node2D

const MAX_BULLETS: int = 4000

## Bullet data layout per slot (6 floats):
## [0] x
## [1] y
## [2] vx (velocity x)
## [3] vy (velocity y)
## [4] lifetime  (seconds remaining; -1 = inactive)
## [5] active    (1.0 = active, 0.0 = inactive)
const SLOT: int = 6

const PLAYER_BEHAVIOR_STRAIGHT: int = 0
const PLAYER_BEHAVIOR_WAVE: int = 1

## Bullet visual sizes in pixels.
const ENEMY_BULLET_RADIUS: float = 3.0
const PLAYER_BULLET_HALF_W: float = 2.5
const PLAYER_BULLET_HALF_H: float = 8.0

## Maximum alive time for a bullet before auto-expiry.
const BULLET_LIFETIME: float = 6.0

## Off-screen position used to "hide" inactive MultiMesh instances.
const HIDDEN_POS: Vector2 = Vector2(-9999.0, -9999.0)

var _player_pool: PackedFloat32Array
var _enemy_pool: PackedFloat32Array

var _player_next_free: int = 0
var _enemy_next_free: int = 0

var _player_multimesh: MultiMesh
var _enemy_multimesh: MultiMesh

var _player_mmi: MultiMeshInstance2D
var _enemy_mmi: MultiMeshInstance2D

var _player_behavior_kind: PackedInt32Array
var _player_wave_origin_x: PackedFloat32Array
var _player_wave_origin_y: PackedFloat32Array
var _player_wave_forward_x: PackedFloat32Array
var _player_wave_forward_y: PackedFloat32Array
var _player_wave_side_x: PackedFloat32Array
var _player_wave_side_y: PackedFloat32Array
var _player_wave_speed: PackedFloat32Array
var _player_wave_amplitude: PackedFloat32Array
var _player_wave_frequency: PackedFloat32Array
var _player_wave_phase: PackedFloat32Array
var _player_age: PackedFloat32Array
var _player_split_depth: PackedInt32Array
var _player_split_budget: PackedInt32Array
var _player_damage_scale: PackedFloat32Array
var _enemy_source_damage: PackedFloat32Array
var _enemy_source_is_boss: PackedInt32Array

# Bullet material colours.
const PLAYER_BULLET_COLOR: Color = Color(0.4, 1.0, 0.6, 1.0)
const ENEMY_BULLET_COLOR: Color  = Color(1.0, 0.3, 0.3, 1.0)


func _ready() -> void:
	_player_pool = PackedFloat32Array()
	_player_pool.resize(MAX_BULLETS * SLOT)
	_enemy_pool = PackedFloat32Array()
	_enemy_pool.resize(MAX_BULLETS * SLOT)

	_player_behavior_kind = PackedInt32Array()
	_player_behavior_kind.resize(MAX_BULLETS)
	_player_wave_origin_x = PackedFloat32Array()
	_player_wave_origin_x.resize(MAX_BULLETS)
	_player_wave_origin_y = PackedFloat32Array()
	_player_wave_origin_y.resize(MAX_BULLETS)
	_player_wave_forward_x = PackedFloat32Array()
	_player_wave_forward_x.resize(MAX_BULLETS)
	_player_wave_forward_y = PackedFloat32Array()
	_player_wave_forward_y.resize(MAX_BULLETS)
	_player_wave_side_x = PackedFloat32Array()
	_player_wave_side_x.resize(MAX_BULLETS)
	_player_wave_side_y = PackedFloat32Array()
	_player_wave_side_y.resize(MAX_BULLETS)
	_player_wave_speed = PackedFloat32Array()
	_player_wave_speed.resize(MAX_BULLETS)
	_player_wave_amplitude = PackedFloat32Array()
	_player_wave_amplitude.resize(MAX_BULLETS)
	_player_wave_frequency = PackedFloat32Array()
	_player_wave_frequency.resize(MAX_BULLETS)
	_player_wave_phase = PackedFloat32Array()
	_player_wave_phase.resize(MAX_BULLETS)
	_player_age = PackedFloat32Array()
	_player_age.resize(MAX_BULLETS)
	_player_split_depth = PackedInt32Array()
	_player_split_depth.resize(MAX_BULLETS)
	_player_split_budget = PackedInt32Array()
	_player_split_budget.resize(MAX_BULLETS)
	_player_damage_scale = PackedFloat32Array()
	_player_damage_scale.resize(MAX_BULLETS)
	_enemy_source_damage = PackedFloat32Array()
	_enemy_source_damage.resize(MAX_BULLETS)
	_enemy_source_is_boss = PackedInt32Array()
	_enemy_source_is_boss.resize(MAX_BULLETS)

	# Mark all slots inactive.
	for i: int in range(MAX_BULLETS):
		_player_pool[i * SLOT + 5] = 0.0
		_enemy_pool[i * SLOT + 5] = 0.0
		_player_behavior_kind[i] = PLAYER_BEHAVIOR_STRAIGHT
		_player_wave_origin_x[i] = 0.0
		_player_wave_origin_y[i] = 0.0
		_player_wave_forward_x[i] = 0.0
		_player_wave_forward_y[i] = 0.0
		_player_wave_side_x[i] = 0.0
		_player_wave_side_y[i] = 0.0
		_player_wave_speed[i] = 0.0
		_player_wave_amplitude[i] = 0.0
		_player_wave_frequency[i] = 0.0
		_player_wave_phase[i] = 0.0
		_player_age[i] = 0.0
		_player_split_depth[i] = 0
		_player_split_budget[i] = 0
		_player_damage_scale[i] = 1.0
		_enemy_source_damage[i] = 1.0
		_enemy_source_is_boss[i] = 0

	_player_mmi = _build_multimesh_instance(
		Vector2(PLAYER_BULLET_HALF_W * 2.0, PLAYER_BULLET_HALF_H * 2.0),
		false,
		PLAYER_BULLET_COLOR
	)
	_enemy_mmi = _build_multimesh_instance(
		Vector2(ENEMY_BULLET_RADIUS * 2.0, ENEMY_BULLET_RADIUS * 2.0),
		true,
		ENEMY_BULLET_COLOR
	)

	_player_multimesh = _player_mmi.multimesh
	_enemy_multimesh = _enemy_mmi.multimesh

	add_child(_player_mmi)
	add_child(_enemy_mmi)


## Build a MultiMeshInstance2D with a flat quad mesh and optional circle shader.
func _build_multimesh_instance(
	quad_size: Vector2,
	circle_shader: bool,
	default_color: Color
) -> MultiMeshInstance2D:

	var qm: QuadMesh = QuadMesh.new()
	qm.size = quad_size

	var mat: ShaderMaterial = null
	if circle_shader:
		mat = ShaderMaterial.new()
		var s: Shader = Shader.new()
		s.code = """
shader_type canvas_item;
void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);
    if (dist > 0.5) discard;
    COLOR = vec4(COLOR.rgb, COLOR.a);
}
"""
		mat.shader = s
		qm.material = mat

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = MAX_BULLETS
	mm.mesh = qm

	# Hide all instances off-screen initially.
	var hidden_xform: Transform2D = Transform2D(0.0, HIDDEN_POS)
	for i: int in range(MAX_BULLETS):
		mm.set_instance_transform_2d(i, hidden_xform)
		mm.set_instance_color(i, default_color)

	var mmi: MultiMeshInstance2D = MultiMeshInstance2D.new()
	mmi.multimesh = mm
	return mmi


## Spawn a player bullet at world position pos, travelling in direction dir at speed.
func spawn_player_bullet(pos: Vector2, dir: Vector2, speed: float) -> void:
	spawn_player_bullet_advanced(pos, dir, speed)


func spawn_player_bullet_advanced(
	pos: Vector2,
	dir: Vector2,
	speed: float,
	behavior_kind: int = PLAYER_BEHAVIOR_STRAIGHT,
	wave_amplitude: float = 0.0,
	wave_frequency: float = 0.0,
	wave_phase: float = 0.0,
	split_depth: int = 0,
	split_budget: int = 0,
	damage_scale: float = 1.0
) -> int:
	var slot: int = _find_free_player_slot()
	if slot == -1:
		return -1
	var n_dir: Vector2 = dir.normalized()
	var side: Vector2 = Vector2(-n_dir.y, n_dir.x)
	var base: int = slot * SLOT
	_player_pool[base + 0] = pos.x
	_player_pool[base + 1] = pos.y
	_player_pool[base + 2] = n_dir.x * speed
	_player_pool[base + 3] = n_dir.y * speed
	_player_pool[base + 4] = BULLET_LIFETIME
	_player_pool[base + 5] = 1.0

	_player_behavior_kind[slot] = behavior_kind
	_player_wave_origin_x[slot] = pos.x
	_player_wave_origin_y[slot] = pos.y
	_player_wave_forward_x[slot] = n_dir.x
	_player_wave_forward_y[slot] = n_dir.y
	_player_wave_side_x[slot] = side.x
	_player_wave_side_y[slot] = side.y
	_player_wave_speed[slot] = speed
	_player_wave_amplitude[slot] = wave_amplitude
	_player_wave_frequency[slot] = wave_frequency
	_player_wave_phase[slot] = wave_phase
	_player_age[slot] = 0.0
	_player_split_depth[slot] = split_depth
	_player_split_budget[slot] = split_budget
	_player_damage_scale[slot] = damage_scale
	_player_multimesh.set_instance_color(slot, PLAYER_BULLET_COLOR)

	return slot


## Spawn an enemy bullet at world position pos, travelling in direction dir at speed.
func spawn_enemy_bullet(
	pos: Vector2,
	dir: Vector2,
	speed: float,
	base_damage: float = 1.0,
	is_boss_source: bool = false
) -> void:
	spawn_enemy_bullet_colored(pos, dir, speed, base_damage, is_boss_source, ENEMY_BULLET_COLOR)


func spawn_enemy_bullet_colored(
	pos: Vector2,
	dir: Vector2,
	speed: float,
	base_damage: float = 1.0,
	is_boss_source: bool = false,
	bullet_color: Color = ENEMY_BULLET_COLOR
) -> void:
	var slot: int = _find_free_enemy_slot()
	if slot == -1:
		return
	var n_dir: Vector2 = dir.normalized()
	var base: int = slot * SLOT
	_enemy_pool[base + 0] = pos.x
	_enemy_pool[base + 1] = pos.y
	_enemy_pool[base + 2] = n_dir.x * speed
	_enemy_pool[base + 3] = n_dir.y * speed
	_enemy_pool[base + 4] = BULLET_LIFETIME
	_enemy_pool[base + 5] = 1.0
	_enemy_source_damage[slot] = maxf(0.0, base_damage)
	_enemy_source_is_boss[slot] = 1 if is_boss_source else 0
	_enemy_multimesh.set_instance_color(slot, bullet_color)


## Deactivate a specific player bullet slot (called by CollisionSystem on hit).
func deactivate_player_bullet(slot: int) -> void:
	if slot < 0 or slot >= MAX_BULLETS:
		return
	var base: int = slot * SLOT
	_player_pool[base + 5] = 0.0
	_player_behavior_kind[slot] = PLAYER_BEHAVIOR_STRAIGHT
	_player_wave_origin_x[slot] = 0.0
	_player_wave_origin_y[slot] = 0.0
	_player_wave_forward_x[slot] = 0.0
	_player_wave_forward_y[slot] = 0.0
	_player_wave_side_x[slot] = 0.0
	_player_wave_side_y[slot] = 0.0
	_player_wave_speed[slot] = 0.0
	_player_wave_amplitude[slot] = 0.0
	_player_wave_frequency[slot] = 0.0
	_player_wave_phase[slot] = 0.0
	_player_age[slot] = 0.0
	_player_split_depth[slot] = 0
	_player_split_budget[slot] = 0
	_player_damage_scale[slot] = 1.0
	_player_multimesh.set_instance_transform_2d(slot, Transform2D(0.0, HIDDEN_POS))
	_player_multimesh.set_instance_color(slot, PLAYER_BULLET_COLOR)


## Deactivate a specific enemy bullet slot (called by CollisionSystem on hit).
func deactivate_enemy_bullet(slot: int) -> void:
	if slot < 0 or slot >= MAX_BULLETS:
		return
	var base: int = slot * SLOT
	_enemy_pool[base + 5] = 0.0
	_enemy_source_damage[slot] = 1.0
	_enemy_source_is_boss[slot] = 0
	_enemy_multimesh.set_instance_color(slot, ENEMY_BULLET_COLOR)
	_enemy_multimesh.set_instance_transform_2d(slot, Transform2D(0.0, HIDDEN_POS))


## Returns a read-only view of the enemy bullet pool for CollisionSystem.
func get_enemy_pool() -> PackedFloat32Array:
	return _enemy_pool


## Returns a read-only view of the player bullet pool for CollisionSystem.
func get_player_pool() -> PackedFloat32Array:
	return _player_pool


func get_enemy_bullet_damage(slot: int) -> float:
	if slot < 0 or slot >= MAX_BULLETS:
		return 1.0
	return _enemy_source_damage[slot]


func is_enemy_bullet_from_boss(slot: int) -> bool:
	if slot < 0 or slot >= MAX_BULLETS:
		return false
	return _enemy_source_is_boss[slot] != 0


func get_player_bullet_split_depth(slot: int) -> int:
	if slot < 0 or slot >= MAX_BULLETS:
		return 0
	return _player_split_depth[slot]


func get_player_bullet_split_budget(slot: int) -> int:
	if slot < 0 or slot >= MAX_BULLETS:
		return 0
	return _player_split_budget[slot]


func get_player_bullet_damage_scale(slot: int) -> float:
	if slot < 0 or slot >= MAX_BULLETS:
		return 1.0
	return _player_damage_scale[slot]


func get_player_bullet_position(slot: int) -> Vector2:
	if slot < 0 or slot >= MAX_BULLETS:
		return Vector2.ZERO
	var base: int = slot * SLOT
	return Vector2(_player_pool[base + 0], _player_pool[base + 1])


func get_player_bullet_velocity(slot: int) -> Vector2:
	if slot < 0 or slot >= MAX_BULLETS:
		return Vector2.ZERO
	var base: int = slot * SLOT
	return Vector2(_player_pool[base + 2], _player_pool[base + 3])


func is_player_bullet_wave(slot: int) -> bool:
	if slot < 0 or slot >= MAX_BULLETS:
		return false
	return _player_behavior_kind[slot] == PLAYER_BEHAVIOR_WAVE


func _process(delta: float) -> void:
	_update_player_pool(delta)
	_update_pool(_enemy_pool, _enemy_multimesh, delta)


func _update_player_pool(delta: float) -> void:
	for i: int in range(MAX_BULLETS):
		var base: int = i * SLOT
		if _player_pool[base + 5] == 0.0:
			continue

		_player_pool[base + 4] -= delta
		if _player_pool[base + 4] <= 0.0:
			deactivate_player_bullet(i)
			continue

		_player_age[i] += delta

		if _player_behavior_kind[i] == PLAYER_BEHAVIOR_WAVE:
			var t: float = _player_age[i]
			var phase: float = _player_wave_phase[i] + _player_wave_frequency[i] * t
			var forward_dist: float = _player_wave_speed[i] * t
			var lateral_dist: float = _player_wave_amplitude[i] * sin(phase)

			_player_pool[base + 0] = _player_wave_origin_x[i] + _player_wave_forward_x[i] * forward_dist + _player_wave_side_x[i] * lateral_dist
			_player_pool[base + 1] = _player_wave_origin_y[i] + _player_wave_forward_y[i] * forward_dist + _player_wave_side_y[i] * lateral_dist

			var lateral_vel: float = _player_wave_amplitude[i] * _player_wave_frequency[i] * cos(phase)
			_player_pool[base + 2] = _player_wave_forward_x[i] * _player_wave_speed[i] + _player_wave_side_x[i] * lateral_vel
			_player_pool[base + 3] = _player_wave_forward_y[i] * _player_wave_speed[i] + _player_wave_side_y[i] * lateral_vel
		else:
			_player_pool[base + 0] += _player_pool[base + 2] * delta
			_player_pool[base + 1] += _player_pool[base + 3] * delta

		var pos: Vector2 = Vector2(_player_pool[base + 0], _player_pool[base + 1])
		var vel: Vector2 = Vector2(_player_pool[base + 2], _player_pool[base + 3])
		var angle: float = vel.angle()
		_player_multimesh.set_instance_transform_2d(i, Transform2D(angle, pos))


## Core pool update — advances positions, expires old bullets, syncs MultiMesh.
## No allocations; all operations on the pre-allocated PackedFloat32Array.
func _update_pool(pool: PackedFloat32Array, mm: MultiMesh, delta: float) -> void:
	for i: int in range(MAX_BULLETS):
		var base: int = i * SLOT
		if pool[base + 5] == 0.0:
			continue

		pool[base + 4] -= delta  # Decrement lifetime.
		if pool[base + 4] <= 0.0:
			pool[base + 5] = 0.0
			mm.set_instance_transform_2d(i, Transform2D(0.0, HIDDEN_POS))
			continue

		pool[base + 0] += pool[base + 2] * delta  # x += vx * dt
		pool[base + 1] += pool[base + 3] * delta  # y += vy * dt

		var pos: Vector2 = Vector2(pool[base + 0], pool[base + 1])

		# Build transform: rotation aligned to velocity direction.
		var vel: Vector2 = Vector2(pool[base + 2], pool[base + 3])
		var angle: float = vel.angle()
		mm.set_instance_transform_2d(i, Transform2D(angle, pos))


## Scan forward from _player_next_free to find an inactive slot.
func _find_free_player_slot() -> int:
	var start: int = _player_next_free
	for _i: int in range(MAX_BULLETS):
		var idx: int = (_player_next_free) % MAX_BULLETS
		_player_next_free = (idx + 1) % MAX_BULLETS
		if _player_pool[idx * SLOT + 5] == 0.0:
			return idx
		if _player_next_free == start:
			break
	return -1  # Pool exhausted.


## Scan forward from _enemy_next_free to find an inactive slot.
func _find_free_enemy_slot() -> int:
	var start: int = _enemy_next_free
	for _i: int in range(MAX_BULLETS):
		var idx: int = (_enemy_next_free) % MAX_BULLETS
		_enemy_next_free = (idx + 1) % MAX_BULLETS
		if _enemy_pool[idx * SLOT + 5] == 0.0:
			return idx
		if _enemy_next_free == start:
			break
	return -1  # Pool exhausted.


## Clear all active bullets (e.g. on wave transition).
func clear_all() -> void:
	var hidden_xform: Transform2D = Transform2D(0.0, HIDDEN_POS)
	for i: int in range(MAX_BULLETS):
		_player_pool[i * SLOT + 5] = 0.0
		_enemy_pool[i * SLOT + 5] = 0.0
		_player_behavior_kind[i] = PLAYER_BEHAVIOR_STRAIGHT
		_player_wave_origin_x[i] = 0.0
		_player_wave_origin_y[i] = 0.0
		_player_wave_forward_x[i] = 0.0
		_player_wave_forward_y[i] = 0.0
		_player_wave_side_x[i] = 0.0
		_player_wave_side_y[i] = 0.0
		_player_wave_speed[i] = 0.0
		_player_wave_amplitude[i] = 0.0
		_player_wave_frequency[i] = 0.0
		_player_wave_phase[i] = 0.0
		_player_age[i] = 0.0
		_player_split_depth[i] = 0
		_player_split_budget[i] = 0
		_player_damage_scale[i] = 1.0
		_enemy_source_damage[i] = 1.0
		_enemy_source_is_boss[i] = 0
		_player_multimesh.set_instance_color(i, PLAYER_BULLET_COLOR)
		_enemy_multimesh.set_instance_color(i, ENEMY_BULLET_COLOR)
		_player_multimesh.set_instance_transform_2d(i, hidden_xform)
		_enemy_multimesh.set_instance_transform_2d(i, hidden_xform)
