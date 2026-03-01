## Main — root scene coordinator.
## Instantiates and wires together all game systems for a run.
## Handles run lifecycle: meta menu → run start → wave loop → run end.
class_name Main
extends Node2D

# ── Child node references (populated in _ready via $NodePath) ──────────────
@onready var _bullet_manager:   BulletManager   = $BulletManager
@onready var _collision_system: CollisionSystem = $CollisionSystem
@onready var _spawn_director:   SpawnDirector   = $SpawnDirector
@onready var _player:           Player          = $Player
@onready var _hud:              HUD             = $HUD
@onready var _upgrade_picker:   UpgradePicker   = $UpgradePicker
@onready var _meta_menu:        MetaMenu        = $MetaMenu
@onready var _modifier_component: ModifierComponent = $Player/ModifierComponent
@onready var _upgrade_pool:     UpgradePool     = $UpgradePool
@onready var _camera:           Camera2D        = $Camera2D

## Arena play-field bounds.
const ARENA_MIN: Vector2 = Vector2(40.0,  40.0)
const ARENA_MAX: Vector2 = Vector2(1240.0, 680.0)

var _score: int = 0
var _run_active: bool = false


func _ready() -> void:
	# Wire systems.
	_collision_system.initialise(_bullet_manager, _player)
	_player.initialise(_bullet_manager, _collision_system, _modifier_component)
	_player.arena_min = ARENA_MIN
	_player.arena_max = ARENA_MAX

	_spawn_director.initialise(_player, _bullet_manager, _collision_system, self)
	_spawn_director.arena_min = ARENA_MIN
	_spawn_director.arena_max = ARENA_MAX

	_hud.set_player(_player)
	_upgrade_picker.initialise(_upgrade_pool, _modifier_component)

	# Connect EventBus signals.
	EventBus.player_died.connect(_on_player_died)
	EventBus.upgrade_chosen.connect(_on_upgrade_chosen)
	EventBus.score_changed.connect(_on_score_changed)

	# Show meta menu first; play begins when button is pressed.
	_meta_menu.play_pressed.connect(_start_run)
	_meta_menu.visible = true
	_set_run_systems_active(false)


## Begin a fresh run.
func _start_run() -> void:
	_meta_menu.visible = false
	_modifier_component.reset()
	_player.stats = Player.PlayerStats.new()
	_player.stats.current_hp = _player.stats.max_hp
	_player.position = Vector2(640.0, 360.0)
	_player.visible = true
	_score = 0
	_run_active = true
	_set_run_systems_active(true)
	_spawn_director.start_run()


func _set_run_systems_active(active: bool) -> void:
	_player.set_process(active)
	_bullet_manager.set_process(active)
	_collision_system.set_process(active)
	_spawn_director.set_process(active)
	_hud.visible = active


func _on_player_died() -> void:
	if not _run_active:
		return
	_run_active = false
	_set_run_systems_active(false)
	_bullet_manager.clear_all()

	await get_tree().create_timer(2.2).timeout

	var result: Dictionary = {
		"won": false,
		"score": _score,
		"arena_reached": _spawn_director.arena_index,
	}
	EventBus.run_ended.emit(result)

	# Save high score.
	var best: int = int(SaveService.get_save("high_score", 0))
	if _score > best:
		SaveService.set_save("high_score", _score)
	SaveService.set_save("runs_completed",
		int(SaveService.get_save("runs_completed", 0)) + 1)


func _on_upgrade_chosen(res: Resource) -> void:
	_modifier_component.apply_upgrade(res as UpgradeResource)
	# Notify player so CollisionSystem damage value stays current.
	_player.refresh_stats()
	# Small HP heal on pickup (10 pts, capped at effective max).
	_player.stats.current_hp = minf(
		_player.stats.current_hp + 10.0,
		_player.effective_max_hp()
	)

	# Delay briefly then begin the next wave.
	await get_tree().create_timer(0.3).timeout
	_spawn_director.begin_next_wave()


func _on_score_changed(new_score: int) -> void:
	_score = new_score
