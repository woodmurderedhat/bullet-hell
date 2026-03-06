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
	var spawn_interval: float = 0.2  ## Seconds between individual enemy spawns.
	var boss_wave: bool = false
	var boss_resource: BossResource = null
	var swarm_enabled: bool = true
	var swarm_pattern_id: int = 0
	var swarm_group_count: int = 1
	var swarm_region_switch_interval: float = 6.0
	var spawn_mix_mode: int = 0
	var edge_inject_ratio: float = 0.0
	var origin_region: int = 4
	var edge_bias_side: int = -1
	var min_spawn_distance_to_player: float = 180.0
	var side_repeat_cooldown: int = 2
	var swarm_start_regions: Array[int] = []
	var spawn_interval_jitter: float = 0.0

const BOSS_LEVEL_INTERVAL: int = 5
const BASE_LEVELS_PER_ARENA: int = 25
const LEVEL_GROWTH_PER_ARENA: int = 10
const SWARM_PATTERN_COUNT: int = 25
const SPAWN_MODE_SWARM: int = 0
const SPAWN_MODE_MIXED: int = 1
const SPAWN_MODE_EDGE: int = 2
const HP_SCALING_PER_LEVEL: float = 0.15
const LONG_RUN_HP_SCALING_PER_LEVEL: float = 0.0025
const LONG_RUN_HP_SCALING_START_LEVEL: int = 25
const SPAWN_BASE_ENEMY_COUNT: int = 5
const SPAWN_ENEMY_COUNT_PER_LEVEL: int = 2
const SPAWN_INTERVAL_FLOOR: float = 0.24
const SPAWN_INTERVAL_DROP_PER_LEVEL: float = 0.06
const SWARM_AGGRESSION_FULL_LEVEL: float = 72.0

const EDGE_TOP: int = 0
const EDGE_BOTTOM: int = 1
const EDGE_LEFT: int = 2
const EDGE_RIGHT: int = 3

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
var _next_spawn_interval: float = 0.0
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
var _recent_swarm_patterns: Array[int] = []
var _recent_origin_regions: Array[int] = []
var _recent_spawn_mix_modes: Array[int] = []
var _recent_edge_sides: Array[int] = []


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
	_recent_swarm_patterns.clear()
	_recent_origin_regions.clear()
	_recent_spawn_mix_modes.clear()
	_recent_edge_sides.clear()
	clear_active_entities()
	if _swarm_director != null:
		_swarm_director.arena_min = arena_min
		_swarm_director.arena_max = arena_max
		_swarm_director.reset()
	_start_wave()


## Clears all active spawned enemies/bosses and resets per-wave runtime state.
func clear_active_entities() -> void:
	_wave_active = false
	_alive_enemies = 0
	_spawned_in_wave = 0
	_spawn_timer = 0.0
	_next_spawn_interval = 0.0
	_current_config = null
	_wave_swarm_next_slot.clear()
	_wave_swarm_group_target_counts.clear()

	if _swarm_director != null:
		_swarm_director.clear_wave()

	if _collision_system != null and _collision_system.has_method("clear_enemies"):
		_collision_system.call("clear_enemies")

	if _scene_root == null:
		return

	for child: Node in _scene_root.get_children():
		if child is Enemy or child is Boss:
			child.queue_free()


func _process(delta: float) -> void:
	if not _wave_active:
		return
	if _current_config == null:
		return
	if _spawned_in_wave >= _current_config.enemy_count:
		return  # All queued — waiting for kills.

	_spawn_timer += delta
	if _spawn_timer >= _next_spawn_interval:
		_spawn_timer -= _next_spawn_interval
		_spawn_next_enemy()
		_next_spawn_interval = _roll_next_spawn_interval()


func _start_wave() -> void:
	_alive_enemies = 0
	_spawned_in_wave = 0
	_spawn_timer = 0.0
	_wave_active = true

	_current_config = _build_wave_config()
	_next_spawn_interval = _roll_next_spawn_interval()
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
		cfg.spawn_mix_mode = SPAWN_MODE_EDGE
	else:
		var swarm_aggression: float = _swarm_aggression_for_arena(arena_index)
		cfg.origin_region = _pick_origin_region_for_wave()
		cfg.edge_bias_side = _pick_edge_bias_for_origin(cfg.origin_region)
		# Scale enemy count and mix patterns as arenas progress.
		cfg.enemy_count = maxi(2, SPAWN_BASE_ENEMY_COUNT + arena_index * SPAWN_ENEMY_COUNT_PER_LEVEL + _enemy_count_add)
		cfg.spawn_interval = maxf(SPAWN_INTERVAL_FLOOR, (1.2 - arena_index * SPAWN_INTERVAL_DROP_PER_LEVEL) * _spawn_interval_scale)
		cfg.enemy_resource = _pick_enemy_for_arena()
		cfg.swarm_enabled = _swarm_director != null
		cfg.swarm_pattern_id = _pick_swarm_pattern_for_wave()
		cfg.swarm_group_count = clampi(1 + int(float(cfg.enemy_count) / 8.0) + int(floor(swarm_aggression * 2.2)), 1, 4)
		cfg.swarm_region_switch_interval = lerpf(8.2, 2.2, swarm_aggression)
		cfg.spawn_mix_mode = _pick_spawn_mix_mode_for_wave(cfg.swarm_enabled, swarm_aggression)
		cfg.edge_inject_ratio = _edge_injection_ratio_for_wave(cfg.spawn_mix_mode, swarm_aggression)
		cfg.min_spawn_distance_to_player = lerpf(170.0, 250.0, swarm_aggression)
		cfg.side_repeat_cooldown = 2
		cfg.spawn_interval_jitter = lerpf(0.14, 0.38, swarm_aggression)
		cfg.swarm_start_regions = _pick_swarm_start_regions(cfg.swarm_group_count, cfg.origin_region)

	return cfg


func _spawn_next_enemy() -> void:
	_spawned_in_wave += 1
	var id: int = _next_enemy_id
	_next_enemy_id += 1

	# Random edge spawn position.
	var pos: Vector2 = _fair_random_edge_position(
		_current_config.min_spawn_distance_to_player,
		_current_config.edge_bias_side,
		_current_config.side_repeat_cooldown
	)
	var group_id: int = 0
	var slot_index: int = 0
	var slot_count: int = 1
	var use_swarm_spawn: bool = _should_use_swarm_spawn_for_next_enemy()
	if use_swarm_spawn:
		group_id = _pick_swarm_group_for_spawn(_current_config.swarm_group_count)
		slot_index = _wave_swarm_next_slot[group_id]
		slot_count = maxi(1, _wave_swarm_group_target_counts[group_id])
		_wave_swarm_next_slot[group_id] += 1
		pos = _swarm_director.get_spawn_position_for_member(group_id, slot_index, slot_count)

	if _current_config.boss_wave:
		_spawn_boss(id, pos)
	else:
		var pick: EnemyResource = _pick_enemy_for_arena()
		_spawn_enemy(id, pos, pick, group_id, slot_index, slot_count, use_swarm_spawn)

	_alive_enemies += 1


func _spawn_enemy(
	id: int,
	pos: Vector2,
	res: EnemyResource,
	group_id: int,
	slot_index: int,
	slot_count: int,
	register_in_swarm: bool
) -> void:
	var enemy: Enemy = SCENE_ENEMY.instantiate() as Enemy
	var scaled_hp: float = res.base_hp * _hp_scale_for_arena(arena_index) * _enemy_hp_multiplier
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
	if register_in_swarm:
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
	var scaled_hp: float = res.base_hp * _hp_scale_for_arena(arena_index) * _boss_hp_multiplier
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


func _hp_scale_for_arena(arena_level: int) -> float:
	var clamped_level: int = maxi(0, arena_level)
	var base_scale: float = 1.0 + float(clamped_level) * HP_SCALING_PER_LEVEL
	# Add a late-session slope so challenge keeps rising past early arenas.
	var long_run_levels: int = maxi(0, clamped_level - LONG_RUN_HP_SCALING_START_LEVEL)
	return base_scale + float(long_run_levels) * LONG_RUN_HP_SCALING_PER_LEVEL


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
	return _position_on_edge(edge)


func _position_on_edge(edge: int) -> Vector2:
	match edge:
		EDGE_TOP:
			return Vector2(
				RandomService.next_int_range(int(arena_min.x), int(arena_max.x)),
				arena_min.y
			)
		EDGE_BOTTOM:
			return Vector2(
				RandomService.next_int_range(int(arena_min.x), int(arena_max.x)),
				arena_max.y
			)
		EDGE_LEFT:
			return Vector2(
				arena_min.x,
				RandomService.next_int_range(int(arena_min.y), int(arena_max.y))
			)
		_:
			return Vector2(
				arena_max.x,
				RandomService.next_int_range(int(arena_min.y), int(arena_max.y))
			)


func _pick_swarm_pattern_for_wave() -> int:
	if _swarm_director == null:
		return 0
	var base_pattern: int = arena_index % SWARM_PATTERN_COUNT
	var fallback: int = posmod(base_pattern + RandomService.next_int_range(0, SWARM_PATTERN_COUNT - 1), SWARM_PATTERN_COUNT)
	for _attempt: int in range(8):
		var candidate: int = posmod(base_pattern + RandomService.next_int_range(0, SWARM_PATTERN_COUNT - 1), SWARM_PATTERN_COUNT)
		if _contains_recent(_recent_swarm_patterns, candidate):
			continue
		if not _recent_swarm_patterns.is_empty():
			var last_pattern: int = _recent_swarm_patterns[_recent_swarm_patterns.size() - 1]
			if int(floor(float(candidate) / 5.0)) == int(floor(float(last_pattern) / 5.0)):
				if RandomService.next_float() < 0.7:
					continue
		_push_recent_int(_recent_swarm_patterns, candidate, 5)
		return candidate
	_push_recent_int(_recent_swarm_patterns, fallback, 5)
	return fallback


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

	for _enemy_idx: int in range(cfg.enemy_count):
		var group_id: int = _pick_group_for_wave_distribution(group_count)
		_wave_swarm_group_target_counts[group_id] += 1

	if _swarm_director != null:
		_swarm_director.clear_wave()
		_swarm_director.arena_min = arena_min
		_swarm_director.arena_max = arena_max
		_swarm_director.configure_wave_regions(cfg.swarm_start_regions, cfg.origin_region)


func _pick_swarm_group_for_spawn(group_count: int) -> int:
	if group_count <= 1:
		return 0
	var best_group: int = 0
	var best_fill: float = INF
	var tie_groups: Array[int] = []
	for group_id: int in range(group_count):
		var used: int = _wave_swarm_next_slot[group_id]
		var total: int = maxi(1, _wave_swarm_group_target_counts[group_id])
		var fill: float = float(used) / float(total)
		if fill < best_fill:
			best_fill = fill
			best_group = group_id
			tie_groups.clear()
			tie_groups.append(group_id)
		elif is_equal_approx(fill, best_fill):
			tie_groups.append(group_id)
	if tie_groups.size() <= 1:
		return best_group
	var pick_idx: int = RandomService.next_int_range(0, tie_groups.size() - 1)
	return tie_groups[pick_idx]


func _pick_group_for_wave_distribution(group_count: int) -> int:
	if group_count <= 1:
		return 0

	var best_groups: Array[int] = []
	var lowest_count: int = 1_000_000
	for group_id: int in range(group_count):
		var count: int = _wave_swarm_group_target_counts[group_id]
		if count < lowest_count:
			lowest_count = count
			best_groups.clear()
			best_groups.append(group_id)
		elif count == lowest_count:
			best_groups.append(group_id)

	var pick_idx: int = RandomService.next_int_range(0, best_groups.size() - 1)
	return best_groups[pick_idx]


func _roll_next_spawn_interval() -> float:
	if _current_config == null:
		return 0.25
	if _current_config.boss_wave:
		return 0.0
	var base_interval: float = maxf(0.1, _current_config.spawn_interval)
	var jitter: float = clampf(_current_config.spawn_interval_jitter, 0.0, 0.7)
	if jitter <= 0.0:
		return base_interval
	var min_scale: float = maxf(0.55, 1.0 - jitter)
	var max_scale: float = 1.0 + jitter
	var interval_scale: float = lerpf(min_scale, max_scale, RandomService.next_float())
	return maxf(0.1, base_interval * interval_scale)


func _should_use_swarm_spawn_for_next_enemy() -> bool:
	if _current_config == null:
		return false
	if not _current_config.swarm_enabled or _swarm_director == null:
		return false
	if _current_config.spawn_mix_mode == SPAWN_MODE_EDGE:
		return false
	if _current_config.spawn_mix_mode == SPAWN_MODE_SWARM:
		return true
	# Mixed mode injects edge-origin flanks to break predictability.
	return RandomService.next_float() >= _current_config.edge_inject_ratio


func _pick_spawn_mix_mode_for_wave(swarm_available: bool, aggression: float) -> int:
	if not swarm_available:
		_push_recent_int(_recent_spawn_mix_modes, SPAWN_MODE_EDGE, 4)
		return SPAWN_MODE_EDGE

	var choices: Array = [SPAWN_MODE_SWARM, SPAWN_MODE_MIXED, SPAWN_MODE_EDGE]
	var weights: Array[float] = [
		maxf(0.08, 0.52 - aggression * 0.48),
		0.36 + aggression * 0.40,
		0.12 + aggression * 0.20,
	]
	var fallback: int = int(RandomService.weighted_pick(choices, weights))
	for _attempt: int in range(6):
		var candidate: int = int(RandomService.weighted_pick(choices, weights))
		if _contains_recent(_recent_spawn_mix_modes, candidate):
			continue
		_push_recent_int(_recent_spawn_mix_modes, candidate, 4)
		return candidate
	_push_recent_int(_recent_spawn_mix_modes, fallback, 4)
	return fallback


func _edge_injection_ratio_for_wave(spawn_mode: int, aggression: float) -> float:
	if spawn_mode == SPAWN_MODE_SWARM:
		return 0.0
	if spawn_mode == SPAWN_MODE_EDGE:
		return 1.0
	return lerpf(0.30, 0.72, aggression)


func _pick_origin_region_for_wave() -> int:
	var fallback: int = RandomService.next_int_range(0, 8)
	for _attempt: int in range(10):
		var candidate: int = RandomService.next_int_range(0, 8)
		if _contains_recent(_recent_origin_regions, candidate):
			continue
		if not _recent_origin_regions.is_empty():
			var last: int = _recent_origin_regions[_recent_origin_regions.size() - 1]
			if _region_grid_distance(candidate, last) <= 1 and RandomService.next_float() < 0.8:
				continue
		_push_recent_int(_recent_origin_regions, candidate, 6)
		return candidate
	_push_recent_int(_recent_origin_regions, fallback, 6)
	return fallback


func _pick_edge_bias_for_origin(origin_region: int) -> int:
	if RandomService.next_float() > 0.72:
		return -1
	var col: int = posmod(origin_region, 3)
	var row: int = int(floor(float(origin_region) / 3.0))
	var horizontal: int = EDGE_LEFT if col <= 0 else EDGE_RIGHT
	var vertical: int = EDGE_TOP if row <= 0 else EDGE_BOTTOM
	if col == 1 and row == 1:
		return RandomService.next_int_range(0, 3)
	if absi(col - 1) >= absi(row - 1):
		return horizontal
	return vertical


func _pick_swarm_start_regions(group_count: int, origin_region: int) -> Array[int]:
	var picked: Array[int] = []
	if group_count <= 0:
		return picked
	picked.append(origin_region)

	while picked.size() < group_count:
		var best_candidates: Array[int] = []
		var best_score: int = -1
		for candidate: int in range(9):
			if picked.has(candidate):
				continue
			var nearest: int = 99
			for used: int in picked:
				nearest = mini(nearest, _region_grid_distance(candidate, used))
			if nearest > best_score:
				best_score = nearest
				best_candidates.clear()
				best_candidates.append(candidate)
			elif nearest == best_score:
				best_candidates.append(candidate)
		if best_candidates.is_empty():
			break
		var pick_idx: int = RandomService.next_int_range(0, best_candidates.size() - 1)
		picked.append(best_candidates[pick_idx])

	return picked


func _fair_random_edge_position(min_distance: float, preferred_edge: int, repeat_cooldown: int) -> Vector2:
	var edge: int = _pick_edge_side(preferred_edge, repeat_cooldown)
	var best_pos: Vector2 = _position_on_edge(edge)
	var best_distance: float = _distance_to_player(best_pos)

	for _attempt: int in range(8):
		var candidate: Vector2 = _position_on_edge(edge)
		var distance_to_player: float = _distance_to_player(candidate)
		if distance_to_player >= min_distance:
			_push_recent_int(_recent_edge_sides, edge, 6)
			return candidate
		if distance_to_player > best_distance:
			best_distance = distance_to_player
			best_pos = candidate

	_push_recent_int(_recent_edge_sides, edge, 6)
	return best_pos


func _pick_edge_side(preferred_edge: int, repeat_cooldown: int) -> int:
	var fallback: int = RandomService.next_int_range(0, 3)
	for _attempt: int in range(8):
		var candidate: int = RandomService.next_int_range(0, 3)
		if preferred_edge >= 0 and RandomService.next_float() < 0.62:
			candidate = preferred_edge
		if _is_edge_on_cooldown(candidate, repeat_cooldown):
			continue
		return candidate
	if preferred_edge >= 0 and not _is_edge_on_cooldown(preferred_edge, repeat_cooldown):
		return preferred_edge
	return fallback


func _is_edge_on_cooldown(edge: int, repeat_cooldown: int) -> bool:
	if repeat_cooldown <= 0:
		return false
	if _recent_edge_sides.size() < repeat_cooldown:
		return false
	for idx: int in range(_recent_edge_sides.size() - repeat_cooldown, _recent_edge_sides.size()):
		if _recent_edge_sides[idx] != edge:
			return false
	return true


func _distance_to_player(pos: Vector2) -> float:
	if _player == null:
		return INF
	return pos.distance_to(_player.global_position)


func _contains_recent(history: Array[int], value: int) -> bool:
	if history.is_empty():
		return false
	for idx: int in range(history.size() - 1, maxi(0, history.size() - 3) - 1, -1):
		if history[idx] == value:
			return true
	return false


func _push_recent_int(history: Array[int], value: int, max_size: int) -> void:
	history.append(value)
	while history.size() > max_size:
		history.remove_at(0)


func _region_grid_distance(a: int, b: int) -> int:
	var a_col: int = posmod(a, 3)
	var a_row: int = int(floor(float(a) / 3.0))
	var b_col: int = posmod(b, 3)
	var b_row: int = int(floor(float(b) / 3.0))
	return absi(a_col - b_col) + absi(a_row - b_row)


func _swarm_aggression_for_arena(arena_level: int) -> float:
	return clampf(float(arena_level) / SWARM_AGGRESSION_FULL_LEVEL, 0.0, 1.0)


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
