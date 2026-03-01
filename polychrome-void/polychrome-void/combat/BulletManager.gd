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

## Bullet visual sizes in pixels.
const ENEMY_BULLET_RADIUS: float = 6.0
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

# Bullet material colours.
const PLAYER_BULLET_COLOR: Color = Color(0.4, 1.0, 0.6, 1.0)
const ENEMY_BULLET_COLOR: Color  = Color(1.0, 0.3, 0.3, 1.0)


func _ready() -> void:
	_player_pool = PackedFloat32Array()
	_player_pool.resize(MAX_BULLETS * SLOT)
	_enemy_pool = PackedFloat32Array()
	_enemy_pool.resize(MAX_BULLETS * SLOT)

	# Mark all slots inactive.
	for i: int in range(MAX_BULLETS):
		_player_pool[i * SLOT + 5] = 0.0
		_enemy_pool[i * SLOT + 5] = 0.0

	_player_mmi = _build_multimesh_instance(
		Vector2(PLAYER_BULLET_HALF_W * 2.0, PLAYER_BULLET_HALF_H * 2.0),
		PLAYER_BULLET_COLOR,
		false
	)
	_enemy_mmi = _build_multimesh_instance(
		Vector2(ENEMY_BULLET_RADIUS * 2.0, ENEMY_BULLET_RADIUS * 2.0),
		ENEMY_BULLET_COLOR,
		true
	)

	_player_multimesh = _player_mmi.multimesh
	_enemy_multimesh = _enemy_mmi.multimesh

	add_child(_player_mmi)
	add_child(_enemy_mmi)


## Build a MultiMeshInstance2D with a flat quad mesh and optional circle shader.
func _build_multimesh_instance(
	quad_size: Vector2,
	tint: Color,
	circle_shader: bool
) -> MultiMeshInstance2D:

	var qm: QuadMesh = QuadMesh.new()
	qm.size = quad_size

	var mat: ShaderMaterial = ShaderMaterial.new()
	if circle_shader:
		var s: Shader = Shader.new()
		s.code = """
shader_type canvas_item;
void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);
    if (dist > 0.5) discard;
    COLOR = vec4(1.0, 0.3, 0.3, 1.0);
}
"""
		mat.shader = s
	else:
		var s: Shader = Shader.new()
		s.code = """
shader_type canvas_item;
void fragment() {
    COLOR = vec4(0.4, 1.0, 0.6, 1.0);
}
"""
		mat.shader = s

	qm.material = mat

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.instance_count = MAX_BULLETS
	mm.mesh = qm

	# Hide all instances off-screen initially.
	var hidden_xform: Transform2D = Transform2D(0.0, HIDDEN_POS)
	for i: int in range(MAX_BULLETS):
		mm.set_instance_transform_2d(i, hidden_xform)

	var mmi: MultiMeshInstance2D = MultiMeshInstance2D.new()
	mmi.multimesh = mm
	return mmi


## Spawn a player bullet at world position pos, travelling in direction dir at speed.
func spawn_player_bullet(pos: Vector2, dir: Vector2, speed: float) -> void:
	var slot: int = _find_free_player_slot()
	if slot == -1:
		return
	var base: int = slot * SLOT
	_player_pool[base + 0] = pos.x
	_player_pool[base + 1] = pos.y
	_player_pool[base + 2] = dir.x * speed
	_player_pool[base + 3] = dir.y * speed
	_player_pool[base + 4] = BULLET_LIFETIME
	_player_pool[base + 5] = 1.0


## Spawn an enemy bullet at world position pos, travelling in direction dir at speed.
func spawn_enemy_bullet(pos: Vector2, dir: Vector2, speed: float) -> void:
	var slot: int = _find_free_enemy_slot()
	if slot == -1:
		return
	var base: int = slot * SLOT
	_enemy_pool[base + 0] = pos.x
	_enemy_pool[base + 1] = pos.y
	_enemy_pool[base + 2] = dir.x * speed
	_enemy_pool[base + 3] = dir.y * speed
	_enemy_pool[base + 4] = BULLET_LIFETIME
	_enemy_pool[base + 5] = 1.0


## Deactivate a specific player bullet slot (called by CollisionSystem on hit).
func deactivate_player_bullet(slot: int) -> void:
	if slot < 0 or slot >= MAX_BULLETS:
		return
	var base: int = slot * SLOT
	_player_pool[base + 5] = 0.0
	_player_multimesh.set_instance_transform_2d(slot, Transform2D(0.0, HIDDEN_POS))


## Deactivate a specific enemy bullet slot (called by CollisionSystem on hit).
func deactivate_enemy_bullet(slot: int) -> void:
	if slot < 0 or slot >= MAX_BULLETS:
		return
	var base: int = slot * SLOT
	_enemy_pool[base + 5] = 0.0
	_enemy_multimesh.set_instance_transform_2d(slot, Transform2D(0.0, HIDDEN_POS))


## Returns a read-only view of the enemy bullet pool for CollisionSystem.
func get_enemy_pool() -> PackedFloat32Array:
	return _enemy_pool


## Returns a read-only view of the player bullet pool for CollisionSystem.
func get_player_pool() -> PackedFloat32Array:
	return _player_pool


func _process(delta: float) -> void:
	_update_pool(_player_pool, _player_multimesh, delta)
	_update_pool(_enemy_pool, _enemy_multimesh, delta)


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
		_player_multimesh.set_instance_transform_2d(i, hidden_xform)
		_enemy_multimesh.set_instance_transform_2d(i, hidden_xform)
