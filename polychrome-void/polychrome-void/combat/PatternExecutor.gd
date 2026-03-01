## PatternExecutor — child node of Enemy; reads a PatternResource and fires bullets.
## Supports SpiralPatternResource and RadialBurstPatternResource.
## No allocations in _process.
class_name PatternExecutor
extends Node

var _pattern: PatternResource = null
var _bullet_manager: BulletManager = null
var _owner_node: Node2D = null  # The Enemy this executor belongs to.

# Shared state.
var _fire_timer: float = 0.0

# Spiral state.
var _spiral_angle: float = 0.0

# Radial burst state — reuses _fire_timer as burst timer.
# (fire_rate on PatternResource unused for burst; burst_interval governs timing)


## Call after adding to the scene tree.
func setup(pattern: PatternResource, bullet_manager: BulletManager, owner_node: Node2D) -> void:
	_pattern = pattern
	_bullet_manager = bullet_manager
	_owner_node = owner_node


## Hot-swap to a new pattern mid-run (used by Boss phase transitions).
func set_pattern(pattern: PatternResource) -> void:
	_pattern = pattern
	_fire_timer = 0.0
	_spiral_angle = 0.0


func _process(delta: float) -> void:
	if _pattern == null or _bullet_manager == null or _owner_node == null:
		return

	_fire_timer += delta

	if _pattern is SpiralPatternResource:
		_process_spiral(delta)
	elif _pattern is RadialBurstPatternResource:
		_process_radial_burst()


## Spiral: fires `arms` evenly-spaced bullets, rotating angle_step per tick.
func _process_spiral(_delta: float) -> void:
	var sp: SpiralPatternResource = _pattern as SpiralPatternResource
	var interval: float = 1.0 / sp.fire_rate

	if _fire_timer < interval:
		return
	_fire_timer -= interval

	_spiral_angle += sp.angle_step
	var arm_arc: float = TAU / float(sp.arms)
	var origin: Vector2 = _owner_node.position

	for a: int in range(sp.arms):
		var angle: float = _spiral_angle + arm_arc * float(a)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		_bullet_manager.spawn_enemy_bullet(origin, dir, sp.bullet_speed)


## Radial burst: fires bullet_count evenly-spaced bullets, then waits burst_interval.
func _process_radial_burst() -> void:
	var rb: RadialBurstPatternResource = _pattern as RadialBurstPatternResource

	if _fire_timer < rb.burst_interval:
		return
	_fire_timer -= rb.burst_interval

	var arc: float = TAU / float(rb.bullet_count)
	var origin: Vector2 = _owner_node.position

	for b: int in range(rb.bullet_count):
		var angle: float = arc * float(b)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		_bullet_manager.spawn_enemy_bullet(origin, dir, rb.bullet_speed)
