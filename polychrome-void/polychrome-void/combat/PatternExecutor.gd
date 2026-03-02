## PatternExecutor — child node of Enemy; reads a PatternResource and fires bullets.
## Supports SpiralPatternResource and RadialBurstPatternResource.
## No allocations in _process.
class_name PatternExecutor
extends Node

var _pattern: PatternResource = null
var _bullet_manager: BulletManager = null
var _owner_node: Node2D = null  # The Enemy this executor belongs to.
var _fire_rate_scale: float = 1.0
var _bullet_speed_scale: float = 1.0

# Shared state.
var _fire_timer: float = 0.0

# Spiral state.
var _spiral_angle: float = 0.0
var _arc_angle: float = 0.0
var _cross_flip: bool = false

# Radial burst state — reuses _fire_timer as burst timer.
# (fire_rate on PatternResource unused for burst; burst_interval governs timing)


## Call after adding to the scene tree.
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


## Hot-swap to a new pattern mid-run (used by Boss phase transitions).
func set_pattern(pattern: PatternResource, fire_rate_scale: float = 1.0, bullet_speed_scale: float = 1.0) -> void:
	_pattern = pattern
	_fire_timer = 0.0
	_spiral_angle = 0.0
	_arc_angle = 0.0
	_cross_flip = false
	_fire_rate_scale = maxf(0.1, fire_rate_scale)
	_bullet_speed_scale = maxf(0.1, bullet_speed_scale)


func _process(delta: float) -> void:
	if _pattern == null or _bullet_manager == null or _owner_node == null:
		return

	_fire_timer += delta

	if _pattern is SpiralPatternResource:
		_process_spiral(delta)
	elif _pattern is RadialBurstPatternResource:
		_process_radial_burst()
	elif _pattern is ArcPatternResource:
		_process_arc_pattern()
	elif _pattern is CrossPatternResource:
		_process_cross_pattern()


## Spiral: fires `arms` evenly-spaced bullets, rotating angle_step per tick.
func _process_spiral(_delta: float) -> void:
	var sp: SpiralPatternResource = _pattern as SpiralPatternResource
	var effective_rate: float = maxf(0.1, sp.fire_rate * _fire_rate_scale)
	var interval: float = 1.0 / effective_rate

	if _fire_timer < interval:
		return
	_fire_timer -= interval

	_spiral_angle += sp.angle_step
	var arm_arc: float = TAU / float(sp.arms)
	var origin: Vector2 = _owner_node.position

	for a: int in range(sp.arms):
		var angle: float = _spiral_angle + arm_arc * float(a)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		_bullet_manager.spawn_enemy_bullet(origin, dir, sp.bullet_speed * _bullet_speed_scale)


## Radial burst: fires bullet_count evenly-spaced bullets, then waits burst_interval.
func _process_radial_burst() -> void:
	var rb: RadialBurstPatternResource = _pattern as RadialBurstPatternResource

	var interval: float = rb.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval

	var arc: float = TAU / float(rb.bullet_count)
	var origin: Vector2 = _owner_node.position

	for b: int in range(rb.bullet_count):
		var angle: float = arc * float(b)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		_bullet_manager.spawn_enemy_bullet(origin, dir, rb.bullet_speed * _bullet_speed_scale)


func _process_arc_pattern() -> void:
	var arcp: ArcPatternResource = _pattern as ArcPatternResource
	var interval: float = arcp.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval

	_arc_angle += arcp.sweep_step
	var origin: Vector2 = _owner_node.position
	var count: int = maxi(1, arcp.bullet_count)
	var arc_radians: float = deg_to_rad(arcp.arc_degrees)

	if count == 1:
		var dir_single: Vector2 = Vector2.from_angle(_arc_angle)
		_bullet_manager.spawn_enemy_bullet(origin, dir_single, arcp.bullet_speed * _bullet_speed_scale)
		return

	for i: int in range(count):
		var ratio: float = float(i) / float(count - 1)
		var offset: float = lerpf(-arc_radians * 0.5, arc_radians * 0.5, ratio)
		var dir: Vector2 = Vector2.from_angle(_arc_angle + offset)
		_bullet_manager.spawn_enemy_bullet(origin, dir, arcp.bullet_speed * _bullet_speed_scale)


func _process_cross_pattern() -> void:
	var cp: CrossPatternResource = _pattern as CrossPatternResource
	var interval: float = cp.burst_interval / _fire_rate_scale
	if _fire_timer < interval:
		return
	_fire_timer -= interval

	var origin: Vector2 = _owner_node.position
	var base: float = cp.angle_offset + (PI * 0.25 if _cross_flip else 0.0)
	_cross_flip = not _cross_flip

	for i: int in range(4):
		var angle: float = base + PI * 0.5 * float(i)
		var dir: Vector2 = Vector2.from_angle(angle)
		_bullet_manager.spawn_enemy_bullet(origin, dir, cp.bullet_speed * _bullet_speed_scale)
