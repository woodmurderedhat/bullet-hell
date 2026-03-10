## Boss — multi-phase enemy unit.
## Extends Enemy pattern by owning BossResource and transitioning phases.
## Registered with CollisionSystem like a regular enemy.
## Add via scenes/Boss.tscn.
class_name Boss
extends Node2D

enum VisualMode {
	GEOMETRY,
	SPRITE,
}

@export var visual_mode: VisualMode = VisualMode.GEOMETRY
@export var auto_visual_from_resource: bool = true
const SPRITE_FRAME_SIZE: Vector2i = Vector2i(32, 32)

## Forwarded fields used by CollisionSystem.
var enemy_id: int = 0
var collision_radius: float = 40.0
var projectile_damage: float = 12.0
var contact_damage: float = 18.0
var is_boss_source: bool = true

var _resource: BossResource = null
var _current_hp: float = 0.0
var _max_hp: float = 0.0
var _current_phase: int = 0
var _pattern_executor: PatternExecutor = null
var _player_ref: Node2D = null
var _bullet_manager: BulletManager = null
var _intelligence_tier: int = 0
var _movement_scale: float = 1.0
var _fire_rate_scale: float = 1.0
var _bullet_speed_scale: float = 1.0
var _dead: bool = false
var _arena_min: Vector2 = Vector2(40.0, 40.0)
var _arena_max: Vector2 = Vector2(1240.0, 680.0)
var _visual_sprite: Sprite2D = null

## Cached per-state textures — loaded once in _apply_sprite_from_resource.
var _tex_idle: Texture2D = null
var _tex_move: Texture2D = null
var _tex_hit: Texture2D = null
var _tex_death: Texture2D = null

## Visual state tracking (VS_* constants below).
var _vis_state: int = 0
var _prev_vis_state: int = -1
var _hit_timer: float = 0.0
var _death_timer: float = 0.0
var _last_velocity_sqr: float = 0.0

const POLYGON_SIDES: int = 8
const POLYGON_RADIUS: float = 38.0

# Visual state indices — used to select the correct per-state texture.
const VS_IDLE: int = 0
const VS_MOVE: int = 1
const VS_HIT: int = 2
const VS_DEATH: int = 3
const MOVE_THRESHOLD_SQR: float = 1.0


## Called by SpawnDirector before adding to the scene tree.
func setup_boss(
	res: BossResource,
	scaled_hp: float,
	id: int,
	player: Node2D,
	bm: BulletManager,
	arena_min: Vector2,
	arena_max: Vector2,
	intelligence_tier: int = 0,
	movement_scale: float = 1.0,
	fire_rate_scale: float = 1.0,
	bullet_speed_scale: float = 1.0
) -> void:
	_resource = res
	if auto_visual_from_resource:
		visual_mode = VisualMode.SPRITE if not res.sprite_idle_path.is_empty() else VisualMode.GEOMETRY
	_max_hp = scaled_hp
	_current_hp = scaled_hp
	enemy_id = id
	collision_radius = res.collision_radius
	projectile_damage = res.projectile_damage
	contact_damage = res.contact_damage
	is_boss_source = true
	_player_ref = player
	_bullet_manager = bm
	_intelligence_tier = maxi(0, intelligence_tier)
	_movement_scale = maxf(0.1, movement_scale)
	_fire_rate_scale = maxf(0.1, fire_rate_scale)
	_bullet_speed_scale = maxf(0.1, bullet_speed_scale)
	_arena_min = arena_min
	_arena_max = arena_max
	_apply_sprite_from_resource()


func _ready() -> void:
	_visual_sprite = get_node_or_null("VisualSprite") as Sprite2D
	_apply_visual_mode()
	_enter_phase(0)


func set_visual_mode(mode: VisualMode) -> void:
	visual_mode = mode
	_apply_visual_mode()


func _apply_visual_mode() -> void:
	if _visual_sprite == null:
		return
	_visual_sprite.visible = (visual_mode == VisualMode.SPRITE)
	if visual_mode == VisualMode.SPRITE:
		_visual_sprite.scale = Vector2(2.0, 2.0)
		_apply_sprite_from_resource()
	else:
		_visual_sprite.scale = Vector2.ONE
	queue_redraw()


func _apply_sprite_from_resource() -> void:
	if _visual_sprite == null or _resource == null:
		return
	_tex_idle  = _load_state_tex(_resource.sprite_idle_path,  "idle")
	_tex_move  = _load_state_tex(_resource.sprite_move_path,  "move")
	_tex_hit   = _load_state_tex(_resource.sprite_hit_path,   "hit")
	_tex_death = _load_state_tex(_resource.sprite_death_path, "death")
	# Force first texture draw; phase modulation applied afterwards.
	_prev_vis_state = -1
	_swap_sprite_to_state(VS_IDLE)
	_update_sprite_modulate()


func _process(delta: float) -> void:
	# Death hold: count down then free the node.
	if _dead:
		if _death_timer > 0.0:
			_death_timer -= delta
			if _death_timer <= 0.0:
				_death_timer = 0.0
				_do_final_cleanup()
		return

	if _player_ref == null:
		return
	# Boss moves toward player slowly.
	var speed: float = _resource.speed
	if _current_phase < _resource.phases.size():
		speed *= _resource.phases[_current_phase].speed_multiplier
	speed *= _movement_scale
	speed *= (1.0 + float(_intelligence_tier) * 0.04)
	var dir: Vector2 = (_player_ref.position - position).normalized()
	var vel: Vector2 = dir * speed
	_last_velocity_sqr = vel.length_squared()
	position += vel * delta
	_wrap_position_to_arena()
	if visual_mode == VisualMode.SPRITE and _visual_sprite != null:
		if _hit_timer > 0.0:
			_hit_timer -= delta
			if _hit_timer <= 0.0:
				_hit_timer = 0.0
				_prev_vis_state = -1  # Force texture refresh after hit state ends.
		_swap_sprite_to_state(_resolve_vis_state())
		_update_sprite_modulate()
	queue_redraw()


func _update_sprite_modulate() -> void:
	if _resource == null:
		return
	var col: Color = _resource.base_color
	if _current_phase < _resource.phases.size():
		col = _resource.phases[_current_phase].phase_color
	# In hit/death states the sprite provides the visual; skip the low-HP sine flash.
	var hp_frac: float = _current_hp / _max_hp if _max_hp > 0.0 else 0.0
	if _vis_state != VS_HIT and _vis_state != VS_DEATH and hp_frac < 0.15:
		col = col.lerp(Color.WHITE, absf(sin(Time.get_ticks_msec() * 0.01)))
	_visual_sprite.modulate = col


func _wrap_position_to_arena() -> void:
	if position.x < _arena_min.x:
		position.x = _arena_max.x
	elif position.x > _arena_max.x:
		position.x = _arena_min.x

	if position.y < _arena_min.y:
		position.y = _arena_max.y
	elif position.y > _arena_max.y:
		position.y = _arena_min.y


func _draw() -> void:
	if _dead:
		return
	var col: Color = _resource.base_color
	if _current_phase < _resource.phases.size():
		col = _resource.phases[_current_phase].phase_color
	var hp_frac: float = _current_hp / _max_hp if _max_hp > 0.0 else 0.0
	if hp_frac < 0.15:
		col = col.lerp(Color.WHITE, absf(sin(Time.get_ticks_msec() * 0.01)))

	if not (visual_mode == VisualMode.SPRITE and _visual_sprite != null):
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
	apply_damage(damage)


func apply_damage(damage: float) -> void:
	if _dead or damage <= 0.0:
		return
	_current_hp -= damage
	_hit_timer = _resource.hit_state_duration if _resource != null else 0.1
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
		_pattern_executor.setup(
			phase_res.pattern,
			_bullet_manager,
			self,
			_fire_rate_scale,
			_bullet_speed_scale
		)
	else:
		_pattern_executor.set_pattern(phase_res.pattern, _fire_rate_scale, _bullet_speed_scale)


func _die() -> void:
	_dead = true
	var score_val: int = _resource.score_value if _resource != null else 0
	EventBus.enemy_died.emit(enemy_id, position, score_val)
	if visual_mode == VisualMode.SPRITE and _visual_sprite != null:
		# Hold the death sprite briefly, then free via _process death-hold loop.
		_death_timer = _resource.death_state_duration if _resource != null else 0.25
		_prev_vis_state = -1
		_swap_sprite_to_state(VS_DEATH)
	else:
		# Geometry mode — no death sprite; free immediately.
		queue_free()


func _do_final_cleanup() -> void:
	queue_free()


func _resolve_vis_state() -> int:
	if _hit_timer > 0.0:
		return VS_HIT
	if _last_velocity_sqr > MOVE_THRESHOLD_SQR:
		return VS_MOVE
	return VS_IDLE


func _swap_sprite_to_state(state: int) -> void:
	if _prev_vis_state == state:
		return
	_prev_vis_state = state
	_vis_state = state
	var tex: Texture2D = _tex_for_state(state)
	if tex == null:
		tex = _tex_idle  # Fall back to idle texture if state sprite is missing.
	_visual_sprite.texture = tex
	_visual_sprite.region_enabled = false


func _tex_for_state(state: int) -> Texture2D:
	match state:
		VS_IDLE:  return _tex_idle
		VS_MOVE:  return _tex_move
		VS_HIT:   return _tex_hit
		VS_DEATH: return _tex_death
	return _tex_idle


func _load_state_tex(path: String, state_name: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		push_warning("Boss %s sprite '%s' not found: %s" % [String(_resource.id), state_name, path])
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("Boss %s sprite '%s' failed to load: %s" % [String(_resource.id), state_name, path])
	return tex


func get_projectile_damage() -> float:
	return projectile_damage


func is_boss_unit() -> bool:
	return true


func get_target_position() -> Vector2:
	if _player_ref == null:
		return position
	return _player_ref.position
