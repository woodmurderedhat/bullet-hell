## TelemetryService — runtime performance and session metrics.
## Autoloaded as "TelemetryService".
extends Node

signal telemetry_updated(snapshot: Dictionary)

const UPDATE_INTERVAL: float = 0.25

var _session_active: bool = false
var _session_time: float = 0.0
var _run_count: int = 0

var _enemies_killed: int = 0
var _damage_taken: float = 0.0
var _damage_dealt: float = 0.0
var _upgrades_chosen: int = 0

var _fps_current: float = 0.0
var _fps_avg: float = 0.0
var _fps_min: float = 99999.0
var _fps_max: float = 0.0

var _accum_time: float = 0.0
var _accum_frames: int = 0
var _accum_fps_sum: float = 0.0

var _overlay_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_subscribe_events()


func _process(delta: float) -> void:
	if not _session_active:
		return

	_session_time += delta
	_accum_time += delta
	_accum_frames += 1

	if delta > 0.0:
		_fps_current = 1.0 / delta
		_accum_fps_sum += _fps_current
		if _fps_current < _fps_min:
			_fps_min = _fps_current
		if _fps_current > _fps_max:
			_fps_max = _fps_current

	if _accum_time >= UPDATE_INTERVAL:
		if _accum_frames > 0:
			_fps_avg = _accum_fps_sum / float(_accum_frames)
		telemetry_updated.emit(get_snapshot())
		_accum_time = 0.0
		_accum_frames = 0
		_accum_fps_sum = 0.0


func begin_run() -> void:
	_session_active = true
	_run_count += 1
	_session_time = 0.0
	_enemies_killed = 0
	_damage_taken = 0.0
	_damage_dealt = 0.0
	_upgrades_chosen = 0
	_fps_current = 0.0
	_fps_avg = 0.0
	_fps_min = 99999.0
	_fps_max = 0.0
	_accum_time = 0.0
	_accum_frames = 0
	_accum_fps_sum = 0.0
	telemetry_updated.emit(get_snapshot())


func end_run() -> void:
	_session_active = false
	telemetry_updated.emit(get_snapshot())


func set_overlay_enabled(enabled: bool) -> void:
	_overlay_enabled = enabled
	SaveService.set_save("telemetry_overlay_enabled", enabled)
	telemetry_updated.emit(get_snapshot())


func is_overlay_enabled() -> bool:
	return _overlay_enabled


func get_snapshot() -> Dictionary:
	return {
		"session_active": _session_active,
		"session_time": _session_time,
		"run_count": _run_count,
		"enemies_killed": _enemies_killed,
		"damage_taken": _damage_taken,
		"damage_dealt": _damage_dealt,
		"upgrades_chosen": _upgrades_chosen,
		"fps_current": _fps_current,
		"fps_avg": _fps_avg,
		"fps_min": 0.0 if _fps_min > 90000.0 else _fps_min,
		"fps_max": _fps_max,
		"overlay_enabled": _overlay_enabled,
	}


func _subscribe_events() -> void:
	_overlay_enabled = bool(SaveService.get_save("telemetry_overlay_enabled", true))
	EventBus.enemy_died.connect(func(_id: int, _pos: Vector2, _score: int) -> void:
		_enemies_killed += 1
	)
	EventBus.bullet_hit_player.connect(func(dmg: float) -> void:
		_damage_taken += dmg
	)
	EventBus.bullet_hit_enemy.connect(func(_enemy_id: int, dmg: float) -> void:
		_damage_dealt += dmg
	)
	EventBus.upgrade_chosen.connect(func(_res: Resource) -> void:
		_upgrades_chosen += 1
	)
