## HUD — heads-up display drawn via CanvasLayer.
## Shows HP bar, arena counter, score.  Subscribes to EventBus.
## Add via scenes/HUD.tscn.
class_name HUD
extends CanvasLayer

## HP bar dimensions.
const HP_BAR_POS: Vector2  = Vector2(20.0, 20.0)
const HP_BAR_SIZE: Vector2 = Vector2(200.0, 16.0)
const COLOR_BG_PANEL: Color = Color(0.09, 0.10, 0.14, 0.86)
const COLOR_ACCENT_SCORE: Color = Color(1.0, 0.76, 0.28)
const COLOR_ACCENT_ARENA: Color = Color(0.35, 0.84, 1.0)
const COLOR_ACCENT_WAVE: Color = Color(0.95, 0.40, 1.0)
const COLOR_ACCENT_TELEMETRY: Color = Color(0.62, 0.95, 0.90)

var _player: Player = null
var _score: int = 0
var _arena_index: int = 0

var _hp_bar: ColorRect
var _hp_bg: ColorRect
var _score_label: Label
var _arena_label: Label
var _wave_label: Label
var _wave_label_timer: float = 0.0
var _telemetry_label: Label


func _ready() -> void:
	layer = 10
	_build_ui()
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.wave_complete.connect(_on_wave_complete)
	EventBus.boss_wave_started.connect(_on_boss_wave_started)
	EventBus.player_died.connect(_on_player_died)
	TelemetryService.telemetry_updated.connect(_on_telemetry_updated)


func _build_ui() -> void:
	# HP background.
	_hp_bg = ColorRect.new()
	_hp_bg.color = COLOR_BG_PANEL
	_hp_bg.position = HP_BAR_POS
	_hp_bg.size = HP_BAR_SIZE
	add_child(_hp_bg)

	# HP fill.
	_hp_bar = ColorRect.new()
	_hp_bar.color = Color(0.2, 1.0, 0.3)
	_hp_bar.position = HP_BAR_POS
	_hp_bar.size = HP_BAR_SIZE
	add_child(_hp_bar)

	# Score label (top right).
	_score_label = Label.new()
	_score_label.position = Vector2(1060.0, 16.0)
	_score_label.size = Vector2(200.0, 30.0)
	_score_label.text = "S 0"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.add_theme_color_override("font_color", COLOR_ACCENT_SCORE)
	_score_label.add_theme_font_size_override("font_size", 24)
	add_child(_score_label)

	# Arena label (top centre).
	_arena_label = Label.new()
	_arena_label.position = Vector2(540.0, 16.0)
	_arena_label.size = Vector2(200.0, 30.0)
	_arena_label.text = "A 1"
	_arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arena_label.add_theme_color_override("font_color", COLOR_ACCENT_ARENA)
	_arena_label.add_theme_font_size_override("font_size", 24)
	add_child(_arena_label)

	# Centre wave announcement label (hidden most of the time).
	_wave_label = Label.new()
	_wave_label.position = Vector2(390.0, 320.0)
	_wave_label.size = Vector2(500.0, 60.0)
	_wave_label.text = ""
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 32)
	_wave_label.add_theme_color_override("font_color", COLOR_ACCENT_WAVE)
	_wave_label.visible = false
	add_child(_wave_label)

	_telemetry_label = Label.new()
	_telemetry_label.position = Vector2(16.0, 620.0)
	_telemetry_label.size = Vector2(420.0, 90.0)
	_telemetry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_telemetry_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_telemetry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_telemetry_label.add_theme_font_size_override("font_size", 14)
	_telemetry_label.add_theme_color_override("font_color", COLOR_ACCENT_TELEMETRY)
	add_child(_telemetry_label)

	_on_telemetry_updated(TelemetryService.get_snapshot())


func _process(delta: float) -> void:
	_update_hp_bar()

	if _wave_label_timer > 0.0:
		_wave_label_timer -= delta
		if _wave_label_timer <= 0.0:
			_wave_label.visible = false


## Bind the Player node so the HUD can read current HP.
func set_player(player: Player) -> void:
	_player = player


func _update_hp_bar() -> void:
	if _player == null:
		return
	var effective_max: float = _player.effective_max_hp()
	var frac: float = _player.stats.current_hp / maxf(effective_max, 1.0)
	frac = clampf(frac, 0.0, 1.0)
	_hp_bar.size.x = HP_BAR_SIZE.x * frac
	# Colour shift: green → red as HP drops.
	_hp_bar.color = Color(1.0 - frac, frac * 0.9, 0.1 + frac * 0.2)


func _on_enemy_died(_id: int, _pos: Vector2, score: int) -> void:
	_score += score
	_score_label.text = "S %d" % _score
	EventBus.score_changed.emit(_score)


func _on_wave_complete(idx: int) -> void:
	var cleared_levels: int = idx + 1
	_arena_index = SpawnDirector.arena_for_cleared_levels(cleared_levels)
	_arena_label.text = "A %d" % _arena_index


func _on_boss_wave_started(_idx: int) -> void:
	_show_wave_message("!! BOSS !!")


func _on_player_died() -> void:
	_show_wave_message("YOU DIED")


func _show_wave_message(text: String) -> void:
	_wave_label.text = text
	_wave_label.visible = true
	_wave_label_timer = 2.5


func _on_telemetry_updated(snapshot: Dictionary) -> void:
	var enabled: bool = bool(snapshot.get("overlay_enabled", true))
	_telemetry_label.visible = enabled
	if not enabled:
		return

	var fps_cur: float = float(snapshot.get("fps_current", 0.0))
	var fps_avg: float = float(snapshot.get("fps_avg", 0.0))
	var fps_min: float = float(snapshot.get("fps_min", 0.0))
	var session_time: float = float(snapshot.get("session_time", 0.0))
	var enemies_killed: int = int(snapshot.get("enemies_killed", 0))
	var damage_taken: float = float(snapshot.get("damage_taken", 0.0))
	var damage_dealt: float = float(snapshot.get("damage_dealt", 0.0))
	var upgrades_chosen: int = int(snapshot.get("upgrades_chosen", 0))
	var collision_ms: float = float(snapshot.get("collision_process_ms", 0.0))
	var resolved_targets: int = int(snapshot.get("collision_resolved_targets", 0))
	var queued_events: int = int(snapshot.get("collision_queued_damage_events", 0))
	var player_active_bullets: int = int(snapshot.get("player_bullets_active", 0))
	var player_spawn_failures: int = int(snapshot.get("player_spawn_failures", 0))

	_telemetry_label.text = "FPS %.1f | AVG %.1f | MIN %.1f\nT %.1fs  K %d  U %d\nDEAL %.0f  TAKE %.0f\nCOL %.2fms  Q %d  R %d\nPB %d  SF %d" % [
		fps_cur,
		fps_avg,
		fps_min,
		session_time,
		enemies_killed,
		upgrades_chosen,
		damage_dealt,
		damage_taken,
		collision_ms,
		queued_events,
		resolved_targets,
		player_active_bullets,
		player_spawn_failures,
	]
