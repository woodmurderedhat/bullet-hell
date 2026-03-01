## BulletStressTest — editor-only scene script.
## Spawns 4000 enemy bullets in a spiral formation and reports FPS.
## Run via scenes/tools/BulletStressTest.tscn; check Output tab for results.
## NOT included in export builds (place this scene in tools/ folder only).
extends Node2D

@onready var _bm: BulletManager = $BulletManager

var _running: bool = false
var _elapsed: float = 0.0
var _frame_count: int = 0
var _min_fps: float = 9999.0
var _max_fps: float = 0.0
var _test_duration: float = 5.0

const CENTER: Vector2 = Vector2(640.0, 360.0)


func _ready() -> void:
	print("[StressTest] Spawning 4000 bullets in spiral...")
	_spawn_4000_bullets()
	_running = true
	print("[StressTest] Measuring for %0.1f seconds..." % _test_duration)


func _spawn_4000_bullets() -> void:
	for i: int in range(BulletManager.MAX_BULLETS):
		var angle: float = i * 0.009  # Tight spiral.
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var offset: Vector2 = dir * 20.0
		_bm.spawn_enemy_bullet(CENTER + offset, dir, 120.0)


func _process(delta: float) -> void:
	if not _running:
		return

	_elapsed += delta
	_frame_count += 1

	var fps: float = 1.0 / delta if delta > 0.0 else 0.0
	if fps < _min_fps:
		_min_fps = fps
	if fps > _max_fps:
		_max_fps = fps

	if _elapsed >= _test_duration:
		_running = false
		var avg_fps: float = float(_frame_count) / _elapsed
		print("[StressTest] ===== RESULTS =====")
		print("[StressTest] Duration:  %.2fs" % _elapsed)
		print("[StressTest] Frames:    %d" % _frame_count)
		print("[StressTest] Avg FPS:   %.1f" % avg_fps)
		print("[StressTest] Min FPS:   %.1f" % _min_fps)
		print("[StressTest] Max FPS:   %.1f" % _max_fps)
		print("[StressTest] Target >= 60 FPS: %s" % ("PASS" if avg_fps >= 60.0 else "FAIL"))
