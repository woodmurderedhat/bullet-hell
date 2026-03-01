## AudioManager — pooled SFX player and music controller.
## Autoloaded as "AudioManager".
## Uses 8 pooled AudioStreamPlayer nodes to avoid dropping sounds under load.
## Music uses a base gameplay layer and an optional boss intensity layer.
extends Node

const SFX_POOL_SIZE: int = 8
const MIX_RATE: int = 44100

## SFX identifiers.
const SFX_SHOOT    := &"shoot"
const SFX_HIT      := &"hit"
const SFX_ENEMY_DIE  := &"enemy_die"
const SFX_BOSS_PHASE := &"boss_phase"
const SFX_UPGRADE  := &"upgrade"
const SFX_GLITCH   := &"glitch"

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

var _music_player: AudioStreamPlayer
var _music_layer_player: AudioStreamPlayer
var _gameplay_music: AudioStream = null
var _boss_layer_music: AudioStream = null

## Maps SFX id → stream.  Populated by load_streams().
var _sfx_streams: Dictionary = {}


func _ready() -> void:
	_build_pool()
	_build_music_players()
	_build_default_streams()
	_subscribe_events()


func _build_pool() -> void:
	for _i: int in range(SFX_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)


func _build_music_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.stream_paused = false
	_music_player.autoplay = false
	_music_player.volume_db = -4.0
	add_child(_music_player)

	_music_layer_player = AudioStreamPlayer.new()
	_music_layer_player.bus = "Music"
	_music_layer_player.autoplay = false
	_music_layer_player.volume_db = -12.0
	add_child(_music_layer_player)


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


func start_gameplay_music() -> void:
	if _gameplay_music == null:
		return
	_music_player.stream = _gameplay_music
	_music_player.play()
	stop_boss_layer_music()


func start_boss_layer_music() -> void:
	if _boss_layer_music == null:
		return
	_music_layer_player.stream = _boss_layer_music
	if not _music_player.playing:
		start_gameplay_music()
	_music_layer_player.play()


func stop_boss_layer_music() -> void:
	if _music_layer_player.playing:
		_music_layer_player.stop()


## Stop music immediately.
func stop_music() -> void:
	_music_player.stop()
	_music_layer_player.stop()


func _subscribe_events() -> void:
	EventBus.player_fired.connect(func() -> void: play_sfx(SFX_SHOOT))
	EventBus.bullet_hit_player.connect(func(_dmg: float) -> void: play_sfx(SFX_HIT))
	EventBus.enemy_died.connect(func(_id: int, _pos: Vector2, _score: int) -> void: play_sfx(SFX_ENEMY_DIE))
	EventBus.boss_phase_changed.connect(func(_idx: int) -> void:
		play_sfx(SFX_BOSS_PHASE)
		play_sfx(SFX_GLITCH)
	)
	EventBus.upgrade_chosen.connect(func(_res: Resource) -> void: play_sfx(SFX_UPGRADE))
	EventBus.boss_wave_started.connect(func(_arena_idx: int) -> void: start_boss_layer_music())
	EventBus.wave_complete.connect(func(arena_idx: int) -> void:
		if arena_idx > 0 and (arena_idx % 5) == 0:
			stop_boss_layer_music()
	)


func _build_default_streams() -> void:
	_sfx_streams[SFX_SHOOT] = _generate_tone(880.0, 0.055, 0.22, 0)
	_sfx_streams[SFX_HIT] = _generate_tone(190.0, 0.085, 0.35, 2)
	_sfx_streams[SFX_ENEMY_DIE] = _generate_tone(130.0, 0.13, 0.32, 1)
	_sfx_streams[SFX_BOSS_PHASE] = _generate_tone(76.0, 0.2, 0.34, 1)
	_sfx_streams[SFX_UPGRADE] = _generate_dual_tone(560.0, 740.0, 0.16, 0.2)
	_sfx_streams[SFX_GLITCH] = _generate_noise(0.09, 0.28)

	_gameplay_music = _generate_loop_music([220.0, 246.94, 293.66, 329.63], 8.0, 0.14)
	_boss_layer_music = _generate_loop_music([110.0, 130.81, 146.83, 196.0], 8.0, 0.10)


func _generate_tone(freq: float, duration: float, volume: float, waveform: int) -> AudioStreamWAV:
	var sample_count: int = int(float(MIX_RATE) * duration)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = 1.0 - (float(i) / float(sample_count))
		var value: float = 0.0
		match waveform:
			0:
				value = sin(TAU * freq * t)
			1:
				value = 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
			2:
				value = asin(sin(TAU * freq * t)) * (2.0 / PI)
			_:
				value = sin(TAU * freq * t)

		var sample: float = clampf(value * env * volume, -1.0, 1.0)
		var pcm: int = int(sample * 32767.0)
		var lo: int = pcm & 255
		var hi: int = (pcm >> 8) & 255
		bytes[i * 2] = lo
		bytes[i * 2 + 1] = hi

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	return stream


func _generate_dual_tone(freq_a: float, freq_b: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(float(MIX_RATE) * duration)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = 1.0 - (float(i) / float(sample_count))
		var value: float = (sin(TAU * freq_a * t) + sin(TAU * freq_b * t)) * 0.5
		var sample: float = clampf(value * env * volume, -1.0, 1.0)
		var pcm: int = int(sample * 32767.0)
		bytes[i * 2] = pcm & 255
		bytes[i * 2 + 1] = (pcm >> 8) & 255
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	return stream


func _generate_noise(duration: float, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(float(MIX_RATE) * duration)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(sample_count * 2)
	for i: int in range(sample_count):
		var env: float = 1.0 - (float(i) / float(sample_count))
		var rand_unit: float = RandomService.next_float() * 2.0 - 1.0
		var sample: float = clampf(rand_unit * env * volume, -1.0, 1.0)
		var pcm: int = int(sample * 32767.0)
		bytes[i * 2] = pcm & 255
		bytes[i * 2 + 1] = (pcm >> 8) & 255
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	return stream


func _generate_loop_music(notes: Array[float], duration: float, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(float(MIX_RATE) * duration)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(sample_count * 2)
	var note_count: int = maxi(notes.size(), 1)
	var sec_per_note: float = duration / float(note_count)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var note_index: int = mini(note_count - 1, int(t / sec_per_note))
		var freq: float = notes[note_index] if note_index < notes.size() else 220.0
		var local_t: float = fmod(t, sec_per_note)
		var env: float = minf(1.0, local_t * 8.0) * minf(1.0, (sec_per_note - local_t) * 8.0)
		var value: float = sin(TAU * freq * t) * 0.72 + sin(TAU * (freq * 0.5) * t) * 0.28
		var sample: float = clampf(value * env * volume, -1.0, 1.0)
		var pcm: int = int(sample * 32767.0)
		bytes[i * 2] = pcm & 255
		bytes[i * 2 + 1] = (pcm >> 8) & 255

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = bytes
	return stream
