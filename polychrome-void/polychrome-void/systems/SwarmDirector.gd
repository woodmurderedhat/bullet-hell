## SwarmDirector — coordinates enemy formations and regional occupancy.
## Applies deterministic, low-allocation swarm movement to registered enemies.
class_name SwarmDirector
extends Node

const PATTERN_COUNT: int = 25

class SwarmMember:
	var enemy: Enemy = null
	var enemy_id: int = -1
	var slot_index: int = 0
	var slot_count: int = 1


class SwarmGroup:
	var group_id: int = 0
	var pattern_id: int = 0
	var aggression: float = 0.0
	var region_index: int = 0
	var switch_interval: float = 6.0
	var switch_timer: float = 0.0
	var elapsed: float = 0.0
	var anchor: Vector2 = Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var descend_step: float = 22.0
	var speed: float = 92.0
	var amplitude: float = 48.0
	var frequency: float = 1.35
	var lane_width: float = 56.0
	var row_height: float = 42.0
	var pattern_seed: float = 0.0
	var members: Array[SwarmMember] = []


## Pattern catalog map for balancing/tuning:
## 00 Hold
## 01 Vertical Pulse
## 02 Horizontal Pulse
## 03 Ellipse Orbit
## 04 Figure Eight
## 05 Corkscrew
## 06 Triangle Drift
## 07 Saw Weave
## 08 Fast S-Curve
## 09 Pinwheel Drift
## 10 Lattice Wave
## 11 Helix Lanes
## 12 Phase Bloom
## 13 Riser Columns
## 14 Banner Sweep
## 15 Ladder Zig
## 16 Drift Rings
## 17 Dual Saw Grid
## 18 Long Arc Wave
## 19 Rotor Bands
## 20 Ribbon Surge
## 21 Crosswind Pulse
## 22 Serrated Lane
## 23 Spiral Screen
## 24 Compression Fan
const PATTERN_CATALOG: PackedStringArray = [
	"Hold",
	"Vertical Pulse",
	"Horizontal Pulse",
	"Ellipse Orbit",
	"Figure Eight",
	"Corkscrew",
	"Triangle Drift",
	"Saw Weave",
	"Fast S-Curve",
	"Pinwheel Drift",
	"Lattice Wave",
	"Helix Lanes",
	"Phase Bloom",
	"Riser Columns",
	"Banner Sweep",
	"Ladder Zig",
	"Drift Rings",
	"Dual Saw Grid",
	"Long Arc Wave",
	"Rotor Bands",
	"Ribbon Surge",
	"Crosswind Pulse",
	"Serrated Lane",
	"Spiral Screen",
	"Compression Fan",
]


var arena_min: Vector2 = Vector2(40.0, 40.0)
var arena_max: Vector2 = Vector2(1240.0, 680.0)

var _groups: Dictionary = {}


func reset() -> void:
	_groups.clear()


func clear_wave() -> void:
	_groups.clear()


func register_enemy(
	enemy: Enemy,
	enemy_id: int,
	group_id: int,
	slot_index: int,
	slot_count: int,
	pattern_id: int,
	switch_interval: float,
	arena_level: int
) -> void:
	if enemy == null:
		return

	var group: SwarmGroup = _ensure_group(group_id, pattern_id, switch_interval, arena_level)
	var member: SwarmMember = SwarmMember.new()
	member.enemy = enemy
	member.enemy_id = enemy_id
	member.slot_index = slot_index
	member.slot_count = maxi(1, slot_count)
	group.members.append(member)

	enemy.enable_swarm_mode(true)


func get_spawn_position_for_member(group_id: int, slot_index: int, slot_count: int) -> Vector2:
	var group: SwarmGroup = _groups.get(group_id, null)
	if group == null:
		var center: Vector2 = _region_center(0)
		return center + _slot_base(slot_index, slot_count, 54.0, 40.0)
	return group.anchor + _slot_base(slot_index, slot_count, group.lane_width, group.row_height)


func _process(delta: float) -> void:
	if _groups.is_empty():
		return

	var group_ids: Array = _groups.keys()
	for gid_variant: Variant in group_ids:
		var gid: int = int(gid_variant)
		var group: SwarmGroup = _groups.get(gid, null)
		if group == null:
			continue
		_update_group(group, delta)
		_apply_group_velocity(group)
		if group.members.is_empty():
			_groups.erase(gid)


func _ensure_group(group_id: int, pattern_id: int, switch_interval: float, arena_level: int) -> SwarmGroup:
	var existing: SwarmGroup = _groups.get(group_id, null)
	if existing != null:
		return existing

	var group: SwarmGroup = SwarmGroup.new()
	var aggression: float = _arena_aggression(arena_level)
	group.group_id = group_id
	group.pattern_id = clampi(pattern_id, 0, PATTERN_COUNT - 1)
	group.aggression = aggression
	group.region_index = posmod(group_id, 9)
	group.switch_interval = maxf(1.9, switch_interval * lerpf(1.22, 0.70, aggression))
	group.switch_timer = 0.0
	group.elapsed = 0.0
	group.anchor = _region_center(group.region_index)
	group.direction = Vector2(1.0 if (group_id % 2) == 0 else -1.0, 0.0)
	group.pattern_seed = float(group_id * 37 + arena_level * 11)
	group.speed = lerpf(58.0, 164.0, aggression) + float(group_id % 3) * 5.0
	group.amplitude = lerpf(16.0, 72.0, aggression) + float((group_id + arena_level) % 4) * 3.0
	group.frequency = lerpf(0.58, 2.24, aggression) + float((group_id + arena_level) % 3) * 0.04
	group.descend_step = lerpf(11.0, 30.0, aggression)
	group.lane_width = lerpf(64.0, 42.0, aggression) + float(group_id % 3) * 2.0
	group.row_height = lerpf(48.0, 30.0, aggression)
	_groups[group_id] = group
	return group


func _update_group(group: SwarmGroup, delta: float) -> void:
	group.elapsed += delta
	group.switch_timer += delta
	if group.switch_timer >= group.switch_interval:
		group.switch_timer = 0.0
		group.region_index = _next_region_index(group)

	var region_target: Vector2 = _region_center(group.region_index)
	group.anchor = group.anchor.lerp(region_target, minf(1.0, delta * lerpf(0.38, 1.08, group.aggression)))

	var x_min: float = arena_min.x + 90.0
	var x_max: float = arena_max.x - 90.0
	group.anchor.x += group.direction.x * group.speed * delta
	if group.anchor.x <= x_min:
		group.anchor.x = x_min
		group.direction.x = 1.0
		group.anchor.y += group.descend_step
	elif group.anchor.x >= x_max:
		group.anchor.x = x_max
		group.direction.x = -1.0
		group.anchor.y += group.descend_step

	var y_min: float = arena_min.y + 70.0
	var y_max: float = arena_max.y - 70.0
	if group.anchor.y > y_max:
		group.anchor.y = y_min + float(posmod(group.region_index, 3)) * 70.0


func _apply_group_velocity(group: SwarmGroup) -> void:
	if group.members.is_empty():
		return

	for idx: int in range(group.members.size() - 1, -1, -1):
		var member: SwarmMember = group.members[idx]
		if member.enemy == null or not is_instance_valid(member.enemy):
			group.members.remove_at(idx)
			continue

		var desired: Vector2 = _target_position(group, member)
		var to_target: Vector2 = desired - member.enemy.position
		var velocity: Vector2 = to_target * lerpf(1.85, 3.9, group.aggression)
		var max_speed: float = maxf(88.0, group.speed * lerpf(2.45, 3.65, group.aggression))
		if velocity.length() > max_speed:
			velocity = velocity.normalized() * max_speed
		member.enemy.set_swarm_velocity(velocity)


func _target_position(group: SwarmGroup, member: SwarmMember) -> Vector2:
	var base: Vector2 = _slot_base(member.slot_index, member.slot_count, group.lane_width, group.row_height)
	var offset: Vector2 = _pattern_offset(
		group.pattern_id,
		group.elapsed,
		member.slot_index,
		member.slot_count,
		group.amplitude,
		group.frequency,
		group.pattern_seed
	)
	return group.anchor + base + offset


func _slot_base(slot_index: int, slot_count: int, lane_width: float, row_height: float) -> Vector2:
	var clamped_count: int = maxi(1, slot_count)
	var cols: int = maxi(2, int(ceil(sqrt(float(clamped_count)))))
	var row: int = int(floor(float(slot_index) / float(cols)))
	var col: int = slot_index % cols
	var x: float = (float(col) - float(cols - 1) * 0.5) * lane_width
	var y: float = float(row) * row_height
	return Vector2(x, y)


func _pattern_offset(
	pattern_id: int,
	time_sec: float,
	slot_index: int,
	slot_count: int,
	amplitude: float,
	frequency: float,
	pattern_seed: float
) -> Vector2:
	var idx: float = float(slot_index)
	var count: float = maxf(1.0, float(slot_count))
	var ratio: float = idx / count
	var phase: float = time_sec * frequency + pattern_seed * 0.017 + idx * 0.37
	var fast_phase: float = time_sec * (frequency * 1.65) + idx * 0.63
	var wide: float = amplitude * 1.2
	var tall: float = amplitude * 0.85

	match pattern_id:
		0:
			return Vector2.ZERO
		1:
			return Vector2(0.0, sin(phase) * tall)
		2:
			return Vector2(cos(phase) * wide, 0.0)
		3:
			return Vector2(cos(phase) * wide, sin(phase) * tall)
		4:
			return Vector2(sin(phase) * wide, sin(phase * 2.0) * tall)
		5:
			return Vector2(cos(phase * 2.0) * wide * 0.8, sin(phase) * tall)
		6:
			return Vector2(_tri(phase) * wide, _tri(phase + PI * 0.5) * tall)
		7:
			return Vector2(_saw(phase) * wide, sin(phase * 1.8) * tall)
		8:
			return Vector2(sin(fast_phase) * wide, cos(phase * 0.6) * tall)
		9:
			return Vector2(cos(fast_phase) * wide * 0.6, _tri(phase * 1.25) * tall)
		10:
			return Vector2(_tri(phase * 1.6) * wide, sin(phase + ratio * TAU) * tall)
		11:
			return Vector2(sin(phase + ratio * PI * 4.0) * wide, cos(phase * 1.4) * tall)
		12:
			return Vector2(cos(phase + ratio * TAU) * wide, sin(phase * 2.3 + ratio * PI) * tall)
		13:
			return Vector2(sin(phase * 2.0 + idx) * wide * 0.55, sin(phase + idx * 0.2) * tall * 1.4)
		14:
			return Vector2(cos(phase * 0.5 + ratio * PI * 6.0) * wide, _saw(phase * 1.2) * tall)
		15:
			return Vector2(sin(phase * 1.2) * wide, _tri(phase * 2.0 + ratio * PI * 2.0) * tall)
		16:
			return Vector2(cos(phase * 1.7 + idx) * wide * 0.9, sin(phase * 0.9 + idx * 0.1) * tall)
		17:
			return Vector2(_saw(phase * 1.5 + ratio * PI) * wide, _saw(phase * 0.75 + ratio * TAU) * tall)
		18:
			return Vector2(_tri(phase * 0.7 + ratio * PI * 2.0) * wide * 1.15, sin(phase * 1.9) * tall)
		19:
			return Vector2(cos(phase * 2.4) * wide * 0.75, cos(phase + ratio * PI * 3.0) * tall)
		20:
			return Vector2(sin(phase * 0.8 + ratio * TAU) * wide, sin(phase * 2.8 + idx * 0.3) * tall * 0.7)
		21:
			return Vector2(cos(phase * 1.1 + idx * 0.2) * wide, _tri(phase * 1.9 + ratio * PI) * tall)
		22:
			return Vector2(_tri(phase * 2.2) * wide * 0.7, _saw(phase * 1.1 + idx * 0.1) * tall)
		23:
			return Vector2(cos(phase * 0.6 + ratio * PI * 8.0) * wide, sin(phase * 1.6 + ratio * PI * 4.0) * tall)
		24:
			return Vector2(sin(phase * 3.0 + idx * 0.12) * wide * 0.45, _tri(phase * 0.9 + ratio * TAU) * tall * 1.1)
		_:
			return Vector2.ZERO


func _next_region_index(group: SwarmGroup) -> int:
	var count: int = 9
	var max_step: float = lerpf(1.4, 4.0, group.aggression)
	var step: int = 1 + int(absf(sin(group.elapsed + group.pattern_seed * 0.01)) * max_step)
	return posmod(group.region_index + step, count)


func _arena_aggression(arena_level: int) -> float:
	return clampf(float(arena_level) / 90.0, 0.0, 1.0)


func _region_center(region_index: int) -> Vector2:
	var idx: int = posmod(region_index, 9)
	var col: int = idx % 3
	var row: int = int(floor(float(idx) / 3.0))

	var width: float = arena_max.x - arena_min.x
	var height: float = arena_max.y - arena_min.y

	var x: float = arena_min.x + width * (0.2 + float(col) * 0.3)
	var y: float = arena_min.y + height * (0.2 + float(row) * 0.3)
	return Vector2(x, y)


func _tri(value: float) -> float:
	var t: float = fposmod(value, TAU) / TAU
	return 1.0 - 4.0 * absf(t - 0.5)


func _saw(value: float) -> float:
	var t: float = fposmod(value, TAU) / TAU
	return t * 2.0 - 1.0
