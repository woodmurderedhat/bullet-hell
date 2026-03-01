## Boss — multi-phase enemy unit.
## Extends Enemy pattern by owning BossResource and transitioning phases.
## Registered with CollisionSystem like a regular enemy.
## Add via scenes/Boss.tscn.
class_name Boss
extends Node2D

## Forwarded fields used by CollisionSystem.
var enemy_id: int = 0
var collision_radius: float = 40.0

var _resource: BossResource = null
var _current_hp: float = 0.0
var _max_hp: float = 0.0
var _current_phase: int = 0
var _pattern_executor: PatternExecutor = null
var _player_ref: Node2D = null
var _bullet_manager: BulletManager = null
var _dead: bool = false

const POLYGON_SIDES: int = 8
const POLYGON_RADIUS: float = 38.0


## Called by SpawnDirector before adding to the scene tree.
func setup_boss(
	res: BossResource,
	scaled_hp: float,
	id: int,
	player: Node2D,
	bm: BulletManager
) -> void:
	_resource = res
	_max_hp = scaled_hp
	_current_hp = scaled_hp
	enemy_id = id
	collision_radius = res.collision_radius
	_player_ref = player
	_bullet_manager = bm


func _ready() -> void:
	EventBus.bullet_hit_enemy.connect(_on_bullet_hit_enemy)
	_enter_phase(0)


func _process(delta: float) -> void:
	if _dead or _player_ref == null:
		return
	# Boss moves toward player slowly.
	var speed: float = _resource.speed
	if _current_phase < _resource.phases.size():
		speed *= _resource.phases[_current_phase].speed_multiplier
	var dir: Vector2 = (_player_ref.position - position).normalized()
	position += dir * speed * delta
	queue_redraw()


func _draw() -> void:
	if _dead:
		return
	var col: Color = _resource.base_color
	if _current_phase < _resource.phases.size():
		col = _resource.phases[_current_phase].phase_color
	var hp_frac: float = _current_hp / _max_hp if _max_hp > 0.0 else 0.0
	if hp_frac < 0.15:
		col = col.lerp(Color.WHITE, absf(sin(Time.get_ticks_msec() * 0.01)))

	# Draw octagonal polygon.
	var verts: PackedVector2Array = PackedVector2Array()
	verts.resize(POLYGON_SIDES)
	for i: int in range(POLYGON_SIDES):
		var a: float = TAU * i / float(POLYGON_SIDES) + rotation
		verts[i] = Vector2(cos(a), sin(a)) * POLYGON_RADIUS
	draw_colored_polygon(verts, col)
	# Outline.
	var outline: PackedVector2Array = verts + PackedVector2Array([verts[0]])
	draw_polyline(outline, Color(1.0, 1.0, 1.0, 0.6), 1.5)

	# HP bar (wide, centred above).
	var bar_w: float = POLYGON_RADIUS * 2.5
	var bar_y: float = -POLYGON_RADIUS - 12.0
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, 5.0), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * hp_frac, 5.0), Color(1.0, 0.8, 0.1))


func _on_bullet_hit_enemy(id: int, damage: float) -> void:
	if id != enemy_id or _dead:
		return
	_current_hp -= damage
	_check_phase_transition()
	if _current_hp <= 0.0:
		_die()


func _check_phase_transition() -> void:
	if _resource == null or _resource.phases.is_empty():
		return
	var hp_frac: float = _current_hp / _max_hp
	# Find the first phase that the boss has NOT yet passed through:
	# phases are ordered by descending threshold; a phase is active while
	# hp_frac is still above that phase's own threshold.
	var next_phase: int = _resource.phases.size() - 1
	for i: int in range(_resource.phases.size()):
		if hp_frac > _resource.phases[i].hp_threshold:
			next_phase = i
			break
	if next_phase != _current_phase:
		_enter_phase(next_phase)


func _enter_phase(phase_index: int) -> void:
	_current_phase = phase_index
	EventBus.boss_phase_changed.emit(phase_index)

	if _resource == null or phase_index >= _resource.phases.size():
		return

	var phase_res: BossPhaseResource = _resource.phases[phase_index]
	if _pattern_executor == null:
		_pattern_executor = PatternExecutor.new()
		add_child(_pattern_executor)
		_pattern_executor.setup(phase_res.pattern, _bullet_manager, self)
	else:
		_pattern_executor.set_pattern(phase_res.pattern)


func _die() -> void:
	_dead = true
	var score_val: int = _resource.score_value if _resource != null else 0
	EventBus.enemy_died.emit(enemy_id, position, score_val)
	queue_free()
