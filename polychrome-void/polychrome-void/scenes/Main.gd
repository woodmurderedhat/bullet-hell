## Main — root scene coordinator.
## Instantiates and wires together all game systems for a run.
## Handles run lifecycle: meta menu → run start → wave loop → run end.
class_name Main
extends Node2D

const STANDARD_CLEAR_ARENAS: int = 3
const RUN_MENU_SCENE := preload("res://ui/RunMenuOverlay.gd")
const DAMAGE_RAMP_PER_LEVEL_ENEMY: float = 0.006
const DAMAGE_RAMP_PER_LEVEL_BOSS: float = 0.008
const LATE_DAMAGE_RAMP_PER_LEVEL_ENEMY: float = 0.003
const LATE_DAMAGE_RAMP_PER_LEVEL_BOSS: float = 0.004
const LATE_DAMAGE_RAMP_START_LEVEL: int = 25

# ── Child node references (populated in _ready via $NodePath) ──────────────
@onready var _bullet_manager:   BulletManager   = $BulletManager
@onready var _collision_system: CollisionSystem = $CollisionSystem
@onready var _shield_system:    Node2D          = $ShieldSystem
@onready var _spawn_director:   SpawnDirector   = $SpawnDirector
@onready var _swarm_director = $SwarmDirector
@onready var _player:           Player          = $Player
@onready var _hud:              HUD             = $HUD
@onready var _upgrade_picker:   UpgradePicker   = $UpgradePicker
@onready var _meta_menu:        MetaMenu        = $MetaMenu
@onready var _modifier_component: ModifierComponent = $Player/ModifierComponent
@onready var _upgrade_pool:     UpgradePool     = $UpgradePool
@onready var _camera:           Camera2D        = $Camera2D
@onready var _arena_backdrop:   CanvasLayer     = $ArenaBackdrop

## Arena play-field bounds.
const ARENA_MIN: Vector2 = Vector2(40.0,  40.0)
const ARENA_MAX: Vector2 = Vector2(1240.0, 680.0)

var _score: int = 0
var _run_active: bool = false
var _pause_active: bool = false
var _run_menu: RunMenuOverlay = null
var _arena_min_runtime: Vector2 = ARENA_MIN
var _arena_max_runtime: Vector2 = ARENA_MAX
var _base_enemy_damage_scale: float = 1.0
var _base_boss_damage_scale: float = 1.0


func _ready() -> void:
	_ensure_pause_action()
	_apply_saved_audio_settings()
	_apply_saved_input_bindings()

	# Wire systems.
	if _shield_system != null and _shield_system.has_method("initialise"):
		_shield_system.call("initialise", _player, _modifier_component, _bullet_manager)
	_collision_system.initialise(_bullet_manager, _player, _modifier_component, _shield_system)
	_collision_system.set_enemy_damage_scale(1.0)
	_collision_system.set_boss_damage_scale(1.0)
	_player.initialise(_bullet_manager, _collision_system, _modifier_component)
	_player.arena_min = _arena_min_runtime
	_player.arena_max = _arena_max_runtime

	_spawn_director.initialise(_player, _bullet_manager, _collision_system, self, _swarm_director)
	_spawn_director.arena_min = _arena_min_runtime
	_spawn_director.arena_max = _arena_max_runtime
	_swarm_director.arena_min = _arena_min_runtime
	_swarm_director.arena_max = _arena_max_runtime
	TelemetryService.set_perf_sources(_collision_system, _bullet_manager)

	_hud.set_player(_player)
	_upgrade_picker.initialise(_upgrade_pool, _modifier_component)

	# Connect EventBus signals.
	EventBus.player_died.connect(_on_player_died)
	EventBus.upgrade_chosen.connect(_on_upgrade_chosen)
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.wave_complete.connect(_on_wave_complete)

	# Show meta menu first; play begins when button is pressed.
	_meta_menu.play_pressed.connect(_start_run)
	_meta_menu.tutorial_pressed.connect(_on_tutorial_pressed)
	_meta_menu.visible = true
	_arena_backdrop.visible = false
	_set_run_systems_active(false)
	_player.set_gameplay_input_enabled(false)

	_run_menu = RUN_MENU_SCENE.new() as RunMenuOverlay
	add_child(_run_menu)
	_run_menu.resume_requested.connect(_resume_from_pause)
	_run_menu.quit_to_menu_requested.connect(_return_to_meta_menu)
	_run_menu.restart_requested.connect(_restart_run)
	_run_menu.tutorial_closed.connect(_on_tutorial_closed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _pause_active:
			_resume_from_pause()
		elif _run_active and _upgrade_picker.visible == false:
			_pause_run()
		get_viewport().set_input_as_handled()


## Begin a fresh run.
func _start_run() -> void:
	get_tree().paused = false
	_pause_active = false
	_run_menu.hide_all()
	_meta_menu.visible = false
	_arena_backdrop.visible = true
	var expansion_profile: Dictionary = _build_expansion_profile_from_active_unlocks()
	_apply_expansion_profile(expansion_profile)
	_refresh_enemy_boss_damage_scaling(0)
	_modifier_component.reset()
	if _shield_system != null and _shield_system.has_method("refresh_state"):
		_shield_system.call("refresh_state", true)
	_player.stats = Player.PlayerStats.new()
	_apply_loadout_to_player()
	_apply_daily_modifier_to_player()
	_player.stats.current_hp = _player.stats.max_hp
	_player.refresh_stats()
	_log_player_run_stats()
	_player.position = Vector2(640.0, 360.0)
	_player.visible = true
	_player.set_gameplay_input_enabled(true)
	_score = 0
	_run_active = true
	TelemetryService.begin_run()
	AudioManager.start_gameplay_music()
	_set_run_systems_active(true)
	_spawn_director.start_run()


func _apply_expansion_profile(profile: Dictionary) -> void:
	_arena_min_runtime = profile.get("arena_min", ARENA_MIN)
	_arena_max_runtime = profile.get("arena_max", ARENA_MAX)

	_player.arena_min = _arena_min_runtime
	_player.arena_max = _arena_max_runtime
	_spawn_director.arena_min = _arena_min_runtime
	_spawn_director.arena_max = _arena_max_runtime
	_swarm_director.arena_min = _arena_min_runtime
	_swarm_director.arena_max = _arena_max_runtime
	_spawn_director.apply_expansion_profile(profile)

	_base_enemy_damage_scale = maxf(0.1, float(profile.get("enemy_damage_multiplier", 1.0)))
	_base_boss_damage_scale = maxf(0.1, float(profile.get("boss_damage_multiplier", 1.0)))
	_refresh_enemy_boss_damage_scaling()


func _refresh_enemy_boss_damage_scaling(arena_level: int = -1) -> void:
	var level: int = arena_level
	if level < 0:
		level = maxi(0, _spawn_director.arena_index)

	var enemy_ramp: float = _damage_ramp_for_level(
		level,
		DAMAGE_RAMP_PER_LEVEL_ENEMY,
		LATE_DAMAGE_RAMP_PER_LEVEL_ENEMY
	)
	var boss_ramp: float = _damage_ramp_for_level(
		level,
		DAMAGE_RAMP_PER_LEVEL_BOSS,
		LATE_DAMAGE_RAMP_PER_LEVEL_BOSS
	)
	_collision_system.set_enemy_damage_scale(_base_enemy_damage_scale * enemy_ramp)
	_collision_system.set_boss_damage_scale(_base_boss_damage_scale * boss_ramp)


func _damage_ramp_for_level(level: int, per_level: float, late_per_level: float) -> float:
	var clamped_level: int = maxi(0, level)
	var ramp: float = 1.0 + float(clamped_level) * per_level
	var late_levels: int = maxi(0, clamped_level - LATE_DAMAGE_RAMP_START_LEVEL)
	ramp += float(late_levels) * late_per_level
	return maxf(0.1, ramp)


func _build_expansion_profile_from_active_unlocks() -> Dictionary:
	var profile: Dictionary = {
		"enemy_resource_paths": [],
		"boss_resource_paths": [],
		"enemy_hp_multiplier": 1.0,
		"boss_hp_multiplier": 1.0,
		"enemy_damage_multiplier": 1.0,
		"boss_damage_multiplier": 1.0,
		"enemy_count_add": 0,
		"spawn_interval_scale": 1.0,
		"intelligence_tier": 0,
		"elite_archetypes": [],
		"arena_min": ARENA_MIN,
		"arena_max": ARENA_MAX,
	}

	var active_ids: Array[StringName] = SaveService.get_active_expansion_unlocks()
	if active_ids.is_empty():
		return profile

	var catalog_by_id: Dictionary = ExpansionUnlockCatalog.get_catalog_by_id()

	for unlock_id: StringName in active_ids:
		if not catalog_by_id.has(unlock_id):
			push_warning("Main: active expansion unlock id not found in catalog: %s" % String(unlock_id))
			continue
		var expansion: ExpansionUnlockResource = catalog_by_id[unlock_id]
		for enemy_path: String in expansion.enemy_resource_paths:
			if not profile["enemy_resource_paths"].has(enemy_path):
				profile["enemy_resource_paths"].append(enemy_path)
		for boss_path: String in expansion.boss_resource_paths:
			if not profile["boss_resource_paths"].has(boss_path):
				profile["boss_resource_paths"].append(boss_path)

		profile["enemy_hp_multiplier"] = float(profile["enemy_hp_multiplier"]) * expansion.enemy_hp_multiplier
		profile["boss_hp_multiplier"] = float(profile["boss_hp_multiplier"]) * expansion.boss_hp_multiplier
		profile["enemy_damage_multiplier"] = float(profile["enemy_damage_multiplier"]) * expansion.enemy_damage_multiplier
		profile["boss_damage_multiplier"] = float(profile["boss_damage_multiplier"]) * expansion.boss_damage_multiplier
		profile["enemy_count_add"] = int(profile["enemy_count_add"]) + expansion.enemy_count_add
		profile["spawn_interval_scale"] = float(profile["spawn_interval_scale"]) * expansion.spawn_interval_scale
		profile["intelligence_tier"] = maxi(int(profile["intelligence_tier"]), expansion.intelligence_tier)

		if expansion.elite_archetype != StringName():
			if not profile["elite_archetypes"].has(expansion.elite_archetype):
				profile["elite_archetypes"].append(expansion.elite_archetype)

		if expansion.category == ExpansionUnlockResource.Category.ARENA_PROFILE:
			profile["arena_min"] = expansion.arena_min
			profile["arena_max"] = expansion.arena_max

	return profile


func _set_run_systems_active(active: bool) -> void:
	_player.set_process(active)
	if not active:
		_player.set_gameplay_input_enabled(false)
		_upgrade_picker.visible = false
	_bullet_manager.set_process(active)
	_collision_system.set_process(active)
	_shield_system.set_process(active)
	var shield_active: bool = false
	if _shield_system != null and _shield_system.has_method("is_active"):
		shield_active = bool(_shield_system.call("is_active"))
	_shield_system.visible = active and shield_active
	_spawn_director.set_process(active)
	_swarm_director.set_process(active)
	_hud.visible = active


func _on_player_died() -> void:
	_end_run(false)


func _on_upgrade_chosen(res: Resource) -> void:
	if not _run_active:
		return
	_player.set_gameplay_input_enabled(true)
	_modifier_component.apply_upgrade(res as UpgradeResource)
	if _shield_system != null and _shield_system.has_method("refresh_state"):
		_shield_system.call("refresh_state")
	# Notify player so CollisionSystem damage value stays current.
	_player.refresh_stats()
	# Small HP heal on pickup (10 pts, capped at effective max).
	_player.stats.current_hp = minf(
		_player.stats.current_hp + 10.0,
		_player.effective_max_hp()
	)

	# Delay briefly then begin the next wave.
	await get_tree().create_timer(0.3).timeout
	if _run_active:
		_refresh_enemy_boss_damage_scaling(_spawn_director.arena_index)
		_spawn_director.begin_next_wave()


func _on_score_changed(new_score: int) -> void:
	_score = new_score


func _on_wave_complete(_arena_index: int) -> void:
	if not _run_active:
		return
	_clear_arena_entities()

	var endless_mode: bool = bool(SaveService.get_save("endless_mode", false))
	var standard_clear_levels: int = SpawnDirector.total_levels_through_arena(STANDARD_CLEAR_ARENAS)
	if not endless_mode and _spawn_director.arena_index >= standard_clear_levels:
		_end_run(true)
		return
	_refresh_enemy_boss_damage_scaling(_spawn_director.arena_index)

	_player.set_gameplay_input_enabled(false)


func _end_run(won: bool) -> void:
	if not _run_active:
		return
	_run_active = false
	_set_run_systems_active(false)
	_clear_arena_entities()
	TelemetryService.end_run()
	AudioManager.stop_music()

	var result: Dictionary = {
		"won": won,
		"score": _score,
		"arena_reached": SpawnDirector.arena_for_cleared_levels(_spawn_director.arena_index),
		"levels_cleared": _spawn_director.arena_index,
	}
	EventBus.run_ended.emit(result)

	SaveService.record_leaderboard_score(_score)
	PlatformService.submit_score(_score)
	if won:
		PlatformService.unlock_achievement(&"first_clear")
	if _score >= 1000:
		PlatformService.unlock_achievement(&"score_1000")
	if int(TelemetryService.get_snapshot().get("enemies_killed", 0)) >= 100:
		PlatformService.unlock_achievement(&"slayer_100")
	SaveService.set_save(
		"runs_completed",
		int(SaveService.get_save("runs_completed", 0)) + 1
	)

	_run_menu.show_result_menu(
		won,
		_score,
		SpawnDirector.arena_for_cleared_levels(_spawn_director.arena_index),
		_spawn_director.arena_index,
		TelemetryService.get_snapshot()
	)


func _pause_run() -> void:
	if not _run_active:
		return
	_pause_active = true
	get_tree().paused = true
	_run_menu.show_pause_menu()


func _resume_from_pause() -> void:
	_pause_active = false
	get_tree().paused = false
	_run_menu.hide_all()


func _return_to_meta_menu() -> void:
	_pause_active = false
	get_tree().paused = false
	_run_active = false
	_set_run_systems_active(false)
	_arena_backdrop.visible = false
	_clear_arena_entities()
	AudioManager.stop_music()
	_run_menu.hide_all()
	_meta_menu.refresh_menu()
	_meta_menu.visible = true


func _restart_run() -> void:
	_run_menu.hide_all()
	_clear_arena_entities()
	_start_run()


func _clear_arena_entities() -> void:
	_bullet_manager.clear_all()
	_spawn_director.clear_active_entities()


func _on_tutorial_pressed() -> void:
	_meta_menu.visible = false
	_run_menu.show_tutorial_menu(false)


func _on_tutorial_closed() -> void:
	if not _run_active:
		_meta_menu.refresh_menu()
		_meta_menu.visible = true


func _apply_saved_audio_settings() -> void:
	_set_audio_bus_from_save("Music", "volume_music", 0.85)
	_set_audio_bus_from_save("SFX", "volume_sfx", 0.9)


func _set_audio_bus_from_save(bus_name: String, key: String, fallback: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var volume_linear: float = clampf(float(SaveService.get_save(key, fallback)), 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, volume_linear)))


func _ensure_pause_action() -> void:
	if InputMap.has_action("pause"):
		return
	InputMap.add_action("pause")
	var esc: InputEventKey = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", esc)


func _apply_saved_input_bindings() -> void:
	var bindings: Dictionary = SaveService.get_save("input_bindings", {})
	for action_name: String in bindings.keys():
		if not InputMap.has_action(action_name):
			continue
		for ev: InputEvent in InputMap.action_get_events(action_name):
			if ev is InputEventKey:
				InputMap.action_erase_event(action_name, ev)
		var key_event: InputEventKey = InputEventKey.new()
		key_event.keycode = int(bindings[action_name]) as Key
		InputMap.action_add_event(action_name, key_event)


func _apply_loadout_to_player() -> void:
	var loadout: int = int(SaveService.get_save("selected_loadout", 0))
	var hp_scale: float = 1.0
	var fire_rate_scale: float = 1.0
	var speed_scale: float = 1.0

	match loadout:
		1: # Striker
			hp_scale = 15.0
			fire_rate_scale = 9.5
			speed_scale = 2.1363636
		2: # Tank
			hp_scale = 21.6666667
			fire_rate_scale = 7.0
			speed_scale = 1.8636364
		_:
			pass

	_player.stats.max_hp *= hp_scale
	_player.stats.current_hp = _player.stats.max_hp
	_player.stats.fire_rate *= fire_rate_scale
	_player.stats.speed *= speed_scale


func _apply_daily_modifier_to_player() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var day_seed: int = int(now.get("year", 0)) * 10000 + int(now.get("month", 0)) * 100 + int(now.get("day", 0))
	var mod_case: int = day_seed % 3
	SaveService.set_save("daily_modifier_id", "daily_%d" % mod_case)

	match mod_case:
		0:
			_player.stats.fire_rate *= 1.08
		1:
			_player.stats.speed *= 1.10
		2:
			_player.stats.bullet_damage *= 1.12


func _log_player_run_stats() -> void:
	var loadout_idx: int = int(SaveService.get_save("selected_loadout", 0))
	var loadout_name: String = _loadout_name(loadout_idx)
	var daily_modifier_id: String = String(SaveService.get_save("daily_modifier_id", "daily_0"))
	var effective_max_hp: float = _player.effective_max_hp()
	var effective_speed: float = _modifier_component.get_stat(_player.stats.speed, &"speed")

	print(
		"Run stats | loadout=%s daily=%s base_hp=%.2f effective_hp=%.2f base_speed=%.2f effective_speed=%.2f" % [
			loadout_name,
			daily_modifier_id,
			_player.stats.max_hp,
			effective_max_hp,
			_player.stats.speed,
			effective_speed,
		]
	)


func _loadout_name(loadout: int) -> String:
	match loadout:
		1:
			return "Striker"
		2:
			return "Tank"
		_:
			return "Balanced"
