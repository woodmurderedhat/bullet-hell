## AudioManager — pooled SFX player and music controller.
## Autoloaded as "AudioManager".
## Uses 8 pooled AudioStreamPlayer nodes to avoid dropping sounds under load.
## Music plays from a single looping AudioStreamPlayer.
extends Node

const SFX_POOL_SIZE: int = 8

## SFX identifiers.
const SFX_SHOOT    := &"shoot"
const SFX_HIT      := &"hit"
const SFX_ENEMY_DIE  := &"enemy_die"
const SFX_BOSS_PHASE := &"boss_phase"
const SFX_UPGRADE  := &"upgrade"

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

var _music_player: AudioStreamPlayer

## Maps SFX id → stream.  Populated by load_streams().
var _sfx_streams: Dictionary = {}


func _ready() -> void:
	_build_pool()
	_build_music_player()
	_subscribe_events()


func _build_pool() -> void:
	for _i: int in range(SFX_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)


func _build_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)


## Load audio streams from disk.  Call this once streams are generated/placed.
## Streams are optional — missing files are silently skipped.
func load_streams(stream_map: Dictionary) -> void:
	for key: Variant in stream_map.keys():
		_sfx_streams[key] = stream_map[key]


## Play a named SFX using the next free pool slot.
func play_sfx(sfx_id: StringName) -> void:
	if not _sfx_streams.has(sfx_id):
		return  # No stream loaded yet — skip silently.
	var player: AudioStreamPlayer = _sfx_pool[_sfx_index % SFX_POOL_SIZE]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	player.stream = _sfx_streams[sfx_id]
	player.play()


## Start looping music.
func play_music(stream: AudioStream) -> void:
	_music_player.stream = stream
	_music_player.play()


## Stop music immediately.
func stop_music() -> void:
	_music_player.stop()


func _subscribe_events() -> void:
	EventBus.bullet_hit_player.connect(func(_dmg: float) -> void: play_sfx(SFX_HIT))
	EventBus.enemy_died.connect(func(_id: int, _pos: Vector2, _score: int) -> void: play_sfx(SFX_ENEMY_DIE))
	EventBus.boss_phase_changed.connect(func(_idx: int) -> void: play_sfx(SFX_BOSS_PHASE))
	EventBus.upgrade_chosen.connect(func(_res: Resource) -> void: play_sfx(SFX_UPGRADE))
