## SpawnDirector — manages wave pacing, enemy spawning, and arena progression.
## Emits wave_complete via EventBus when all enemies in a wave are dead.
## Every 5th level (index cadence) triggers a boss wave.
## Add as a child of Main.tscn.
class_name SpawnDirector
extends Node

## Configuration for one wave.
class WaveConfig:
	var enemy_count: int = 5
	var enemy_resource: EnemyResource = null
	var spawn_interval: float = 1.2  ## Seconds between individual enemy spawns.
	var boss_wave: bool = false
	var boss_resource: BossResource = null
	var swarm_enabled: bool = true
	var swarm_pattern_id: int = 0
	var swarm_group_count: int = 1
	var swarm_region_switch_interval: float = 6.0

const BOSS_LEVEL_INTERVAL: int = 5
const BASE_LEVELS_PER_ARENA: int = 25
const LEVEL_GROWTH_PER_ARENA: int = 10
const SWARM_PATTERN_COUNT: int = 25

## Preloaded resources.
const RES_BASIC_SQUARE   := preload("res://data/enemies/basic_square.tres")
const RES_BURST_SQUARE   := preload("res://data/enemies/burst_square.tres")
const RES_STRAFER_DIAMOND := preload("res://data/enemies/strafer_diamond.tres")
const RES_ORBIT_HEX       := preload("res://data/enemies/orbit_hex.tres")
const RES_DASH_SPIKE      := preload("res://data/enemies/dash_spike.tres")
const RES_WAVE_KITE       := preload("res://data/enemies/wave_kite.tres")
const RES_ORBIT_BURST     := preload("res://data/enemies/orbit_burst_node.tres")
const RES_STRAFE_SPIRAL   := preload("res://data/enemies/strafe_spiral_node.tres")
const RES_DASH_BURST      := preload("res://data/enemies/dash_burst_brute.tres")
const RES_KITING_SHARD    := preload("res://data/enemies/kiting_shard.tres")
const RES_ZIGZAG_DART     := preload("res://data/enemies/zigzag_dart.tres")
const RES_SENTRY_CORE     := preload("res://data/enemies/sentry_core.tres")
const RES_BOSS_01        := preload("res://data/bosses/boss_01.tres")
const RES_BOSS_02        := preload("res://data/bosses/boss_02.tres")
const RES_BOSS_03        := preload("res://data/bosses/boss_03.tres")

const SCENE_ENEMY := preload("res://scenes/Enemy.tscn")
const SCENE_BOSS  := preload("res://scenes/Boss.tscn")

## Arena bounds for spawn placement (set by Main).
var arena_min: Vector2 = Vector2(40.0, 40.0)
var arena_max: Vector2 = Vector2(1240.0, 680.0)

var arena_index: int = 0

var _player: Node2D = null
var _bullet_manager: BulletManager = null
var _collision_system: CollisionSystem = null
var _swarm_director = null
var _scene_root: Node = null

var _alive_enemies: int = 0
var _spawn_queue: Array[WaveConfig] = []
var _current_config: WaveConfig = null
var _spawned_in_wave: int = 0
var _spawn_timer: float = 0.0
var _wave_active: bool = false
var _next_enemy_id: int = 0
var _base_enemy_roster: Array[EnemyResource] = []
var _enemy_roster: Array[EnemyResource] = []
var _base_boss_roster: Array[BossResource] = []
var _boss_roster: Array[BossResource] = []

var _enemy_hp_multiplier: float = 1.0
var _boss_hp_multiplier: float = 1.0
var _spawn_interval_scale: float = 1.0
var _enemy_count_add: int = 0
var _intelligence_tier: int = 0
var _active_elite_archetypes: Array[StringName] = []
var _extra_enemy_paths: Array[String] = []
var _extra_boss_paths: Array[String] = []
var _wave_swarm_next_slot: Array[int] = []
var _wave_swarm_group_target_counts: Array[int] = []


## Call from Main once all dependencies are available.
func initialise(player: Node2D, bm: BulletManager, cs: CollisionSystem, root: Node, swarm_director = null) -> void:
	_player = player
	_bullet_manager = bm
	_collision_system = cs
	_scene_root = root
	_swarm_director = swarm_director
	_base_enemy_roster = [
		RES_BASIC_SQUARE,
		RES_BURST_SQUARE,
		RES_STRAFER_DIAMOND,
		RES_ORBIT_HEX,
		RES_DASH_SPIKE,
		RES_WAVE_KITE,
		RES_ORBIT_BURST,
		RES_STRAFE_SPIRAL,
		RES_DASH_BURST,
		RES_KITING_SHARD,
		RES_ZIGZAG_DART,
		RES_SENTRY_CORE,
	]
	_enemy_roster = _base_enemy_roster.duplicate()
	_base_boss_roster = [RES_BOSS_01, RES_BOSS_02, RES_BOSS_03]
	_boss_roster = _base_boss_roster.duplicate()
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.wave_complete.connect(_on_wave_complete)


## Begin the first wave.
func start_run() -> void:
	arena_index = 0
	_next_enemy_id = 0
	if _swarm_director != null:
		_swarm_director.arena_min = arena_min
		_swarm_director.arena_max = arena_max
		_swarm_director.reset()
	_start_wave()


func _process(delta: float) -> void:
	if not _wave_active:
		return
	if _current_config == null:
		return
	if _spawned_in_wave >= _current_config.enemy_count:
		return  # All queued — waiting for kills.

	_spawn_timer += delta
	if _spawn_timer >= _current_config.spawn_interval:
		_spawn_timer -= _current_config.spawn_interval
		_spawn_next_enemy()


func _start_wave() -> void:
	_alive_enemies = 0
	_spawned_in_wave = 0
	_spawn_timer = 0.0
	_wave_active = true

	_current_config = _build_wave_config()
	_initialise_swarm_wave_state(_current_config)
	if _current_config.boss_wave:
		EventBus.boss_wave_started.emit(arena_index)


func _build_wave_config() -> WaveConfig:
	var cfg: WaveConfig = WaveConfig.new()
	var is_boss: bool = (arena_index > 0) and ((arena_index % BOSS_LEVEL_INTERVAL) == 0)
	cfg.boss_wave = is_boss

	if is_boss:
		cfg.enemy_count = 1
		cfg.boss_resource = _pick_boss_for_arena(arena_index)
		cfg.spawn_interval = 0.0
		cfg.swarm_enabled = false
	else:
		var swarm_aggression: float = _swarm_aggression_for_arena(arena_index)
		# Scale enemy count and mix patterns as arenas progress.
		cfg.enemy_count = maxi(2, 4 + arena_index * 2 + _enemy_count_add)
		cfg.spawn_interval = maxf(0.25, (1.2 - arena_index * 0.05) * _spawn_interval_scale)
		cfg.enemy_resource = _pick_enemy_for_arena()
		cfg.swarm_enabled = _swarm_director != null
		cfg.swarm_pattern_id = _pick_swarm_pattern_for_wave()
		cfg.swarm_group_count = clampi(1 + int(float(cfg.enemy_count) / 8.0) + int(floor(swarm_aggression * 2.2)), 1, 4)
		cfg.swarm_region_switch_interval = lerpf(8.2, 2.2, swarm_aggression)

	return cfg


func _spawn_next_enemy() -> void:
	_spawned_in_wave += 1
	var id: int = _next_enemy_id
	_next_enemy_id += 1

	# Random edge spawn position.
	var pos: Vector2 = _random_edge_position()
	var group_id: int = 0
	var slot_index: int = 0
	var slot_count: int = 1
	if _current_config.swarm_enabled and _swarm_director != null:
		group_id = _pick_swarm_group_for_spawn(_current_config.swarm_group_count)
		slot_index = _wave_swarm_next_slot[group_id]
		slot_count = maxi(1, _wave_swarm_group_target_counts[group_id])
		_wave_swarm_next_slot[group_id] += 1
		pos = _swarm_director.get_spawn_position_for_member(group_id, slot_index, slot_count)

	if _current_config.boss_wave:
		_spawn_boss(id, pos)
	else:
		var pick: EnemyResource = _pick_enemy_for_arena()
		_spawn_enemy(id, pos, pick, group_id, slot_index, slot_count)

	_alive_enemies += 1


func _spawn_enemy(
	id: int,
	pos: Vector2,
	res: EnemyResource,
	group_id: int,
	slot_index: int,
	slot_count: int
) -> void:
	var enemy: Enemy = SCENE_ENEMY.instantiate() as Enemy
	var scaled_hp: float = res.base_hp * (1.0 + arena_index * 0.12) * _enemy_hp_multiplier
	var elite_archetype: StringName = _pick_elite_archetype_for_spawn()
	enemy.setup(
		res,
		scaled_hp,
		id,
		_player,
		arena_min,
		arena_max,
		_intelligence_tier,
		elite_archetype
	)
	enemy.position = pos
	_scene_root.add_child(enemy)
	_collision_system.register_enemy(enemy)
	if _current_config.swarm_enabled and _swarm_director != null:
		_swarm_director.register_enemy(
			enemy,
			id,
			group_id,
			slot_index,
			slot_count,
			_current_config.swarm_pattern_id,
			_current_config.swarm_region_switch_interval,
			arena_index
		)

	# Attach pattern executor.
	var pe: PatternExecutor = PatternExecutor.new()
	enemy.add_child(pe)
	pe.setup(
		res.pattern,
		_bullet_manager,
		enemy,
		_enemy_fire_rate_scale(elite_archetype),
		_enemy_bullet_speed_scale(elite_archetype)
	)


func _spawn_boss(id: int, pos: Vector2) -> void:
	var boss: Boss = SCENE_BOSS.instantiate() as Boss
	var res: BossResource = _current_config.boss_resource
	var scaled_hp: float = res.base_hp * (1.0 + arena_index * 0.12) * _boss_hp_multiplier
	boss.setup_boss(
		res,
		scaled_hp,
		id,
		_player,
		_bullet_manager,
		arena_min,
		arena_max,
		_intelligence_tier,
		_boss_movement_scale(),
		_boss_fire_rate_scale(),
		_boss_bullet_speed_scale()
	)
	boss.position = pos
	_scene_root.add_child(boss)
	_collision_system.register_enemy(boss)


func _pick_enemy_for_arena() -> EnemyResource:
	if _enemy_roster.is_empty():
		return RES_BASIC_SQUARE

	var unlock_count: int = mini(_enemy_roster.size(), 2 + (arena_index / 2))
	if unlock_count <= 1:
		return _enemy_roster[0]

	var pick_idx: int = RandomService.next_int_range(0, unlock_count - 1)
	return _enemy_roster[pick_idx]


func _pick_boss_for_arena(current_arena: int) -> BossResource:
	var boss_cycle: Array[BossResource] = _boss_roster
	if boss_cycle.is_empty():
		return RES_BOSS_01
	var cycle_idx: int = int((current_arena / BOSS_LEVEL_INTERVAL) - 1) % boss_cycle.size()
	if cycle_idx < 0:
		cycle_idx = 0
	return boss_cycle[cycle_idx]


## Returns total levels in an arena using 1-based arena numbering.
static func levels_in_arena(arena_number: int) -> int:
	var clamped_arena: int = maxi(1, arena_number)
	return BASE_LEVELS_PER_ARENA + (clamped_arena - 1) * LEVEL_GROWTH_PER_ARENA


## Returns cumulative cleared levels through the provided arena number (inclusive).
static func total_levels_through_arena(arena_number: int) -> int:
	var clamped_arena: int = maxi(0, arena_number)
	if clamped_arena <= 0:
		return 0
	var total_levels: int = 0
	for index: int in range(clamped_arena):
		total_levels += levels_in_arena(index + 1)
	return total_levels


## Converts cumulative cleared levels to the current arena number.
static func arena_for_cleared_levels(cleared_levels: int) -> int:
	var levels_remaining: int = maxi(0, cleared_levels)
	var arena_number: int = 1
	while levels_remaining > levels_in_arena(arena_number):
		levels_remaining -= levels_in_arena(arena_number)
		arena_number += 1
	return arena_number


func apply_expansion_profile(profile: Dictionary) -> void:
	_enemy_hp_multiplier = maxf(0.1, float(profile.get("enemy_hp_multiplier", 1.0)))
	_boss_hp_multiplier = maxf(0.1, float(profile.get("boss_hp_multiplier", 1.0)))
	_spawn_interval_scale = maxf(0.1, float(profile.get("spawn_interval_scale", 1.0)))
	_enemy_count_add = int(profile.get("enemy_count_add", 0))
	_intelligence_tier = maxi(0, int(profile.get("intelligence_tier", 0)))

	_active_elite_archetypes.clear()
	var elite_raw: Array = profile.get("elite_archetypes", [])
	for value: Variant in elite_raw:
		_active_elite_archetypes.append(StringName(str(value)))

	_extra_enemy_paths.clear()
	var enemy_paths_raw: Array = profile.get("enemy_resource_paths", [])
	for value: Variant in enemy_paths_raw:
		_extra_enemy_paths.append(str(value))

	_extra_boss_paths.clear()
	var boss_paths_raw: Array = profile.get("boss_resource_paths", [])
	for value: Variant in boss_paths_raw:
		_extra_boss_paths.append(str(value))

	_rebuild_runtime_rosters()


func _rebuild_runtime_rosters() -> void:
	_enemy_roster = _base_enemy_roster.duplicate()
	for path: String in _extra_enemy_paths:
		if not ResourceLoader.exists(path):
			continue
		var loaded_enemy: Resource = load(path)
		if loaded_enemy is EnemyResource:
			_enemy_roster.append(loaded_enemy as EnemyResource)

	_boss_roster = _base_boss_roster.duplicate()
	for path: String in _extra_boss_paths:
		if not ResourceLoader.exists(path):
			continue
		var loaded_boss: Resource = load(path)
		if loaded_boss is BossResource:
			_boss_roster.append(loaded_boss as BossResource)


func _pick_elite_archetype_for_spawn() -> StringName:
	if _active_elite_archetypes.is_empty():
		return &""
	var chance: float = minf(0.70, 0.08 + float(_intelligence_tier) * 0.06 + float(arena_index) * 0.02)
	if RandomService.next_float() > chance:
		return &""
	var idx: int = RandomService.next_int_range(0, _active_elite_archetypes.size() - 1)
	return _active_elite_archetypes[idx]


func _enemy_fire_rate_scale(elite_archetype: StringName) -> float:
	var scale: float = 1.0 + float(_intelligence_tier) * 0.08
	if elite_archetype == &"suppressor":
		scale += 0.18
	elif elite_archetype == &"hunter":
		scale += 0.10
	return maxf(0.2, scale)


func _enemy_bullet_speed_scale(elite_archetype: StringName) -> float:
	var scale: float = 1.0 + float(_intelligence_tier) * 0.05
	if elite_archetype == &"interceptor":
		scale += 0.20
	elif elite_archetype == &"splitter":
		scale += 0.08
	return maxf(0.2, scale)


func _boss_movement_scale() -> float:
	return 1.0 + float(_intelligence_tier) * 0.05


func _boss_fire_rate_scale() -> float:
	return 1.0 + float(_intelligence_tier) * 0.11


func _boss_bullet_speed_scale() -> float:
	return 1.0 + float(_intelligence_tier) * 0.07


func _random_edge_position() -> Vector2:
	var edge: int = RandomService.next_int_range(0, 3)
	match edge:
		0:  # Top
			return Vector2(
				RandomService.next_int_range(int(arena_min.x), int(arena_max.x)),
				arena_min.y
			)
		1:  # Bottom
			return Vector2(
				RandomService.next_int_range(int(arena_min.x), int(arena_max.x)),
				arena_max.y
			)
		2:  # Left
			return Vector2(
				arena_min.x,
				RandomService.next_int_range(int(arena_min.y), int(arena_max.y))
			)
		_:  # Right
			return Vector2(
				arena_max.x,
				RandomService.next_int_range(int(arena_min.y), int(arena_max.y))
			)


func _pick_swarm_pattern_for_wave() -> int:
	if _swarm_director == null:
		return 0
	var base_pattern: int = arena_index % SWARM_PATTERN_COUNT
	var offset: int = RandomService.next_int_range(0, SWARM_PATTERN_COUNT - 1)
	return posmod(base_pattern + offset, SWARM_PATTERN_COUNT)


func _initialise_swarm_wave_state(cfg: WaveConfig) -> void:
	_wave_swarm_next_slot.clear()
	_wave_swarm_group_target_counts.clear()
	if not cfg.swarm_enabled:
		if _swarm_director != null:
			_swarm_director.clear_wave()
		return

	var group_count: int = maxi(1, cfg.swarm_group_count)
	for idx: int in range(group_count):
		_wave_swarm_next_slot.append(0)
		_wave_swarm_group_target_counts.append(0)

	for enemy_idx: int in range(cfg.enemy_count):
		var group_id: int = enemy_idx % group_count
		_wave_swarm_group_target_counts[group_id] += 1

	if _swarm_director != null:
		_swarm_director.clear_wave()
		_swarm_director.arena_min = arena_min
		_swarm_director.arena_max = arena_max


func _pick_swarm_group_for_spawn(group_count: int) -> int:
	if group_count <= 1:
		return 0
	var best_group: int = 0
	var best_fill: float = INF
	for group_id: int in range(group_count):
		var used: int = _wave_swarm_next_slot[group_id]
		var total: int = maxi(1, _wave_swarm_group_target_counts[group_id])
		var fill: float = float(used) / float(total)
		if fill < best_fill:
			best_fill = fill
			best_group = group_id
	return best_group


func _swarm_aggression_for_arena(arena_level: int) -> float:
	return clampf(float(arena_level) / 90.0, 0.0, 1.0)


func _on_enemy_died(_id: int, _pos: Vector2, _score: int) -> void:
	if not _wave_active:
		return
	_alive_enemies -= 1
	if _alive_enemies <= 0 and _spawned_in_wave >= _current_config.enemy_count:
		_wave_active = false
		EventBus.wave_complete.emit(arena_index)


func _on_wave_complete(_idx: int) -> void:
	# Main.gd listens and shows the upgrade picker; we just increment arena_index here.
	arena_index += 1


## Called by Main after upgrade picker is dismissed to start the next wave.
func begin_next_wave() -> void:
	_start_wave()
