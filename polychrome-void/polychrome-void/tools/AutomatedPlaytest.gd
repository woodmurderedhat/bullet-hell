## AutomatedPlaytest — scripted gameplay simulation for quick regression checks.
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TEST_SECONDS: float = 20.0


func _ready() -> void:
	print("[AutomatedPlaytest] Running...")
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)

	await get_tree().process_frame
	main.call("_start_run")

	var player: Player = main.get_node("Player") as Player
	if player != null:
		player.stats.max_hp = 100000.0
		player.stats.current_hp = 100000.0

	var elapsed: float = 0.0
	while elapsed < TEST_SECONDS:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if player != null:
			var t: float = elapsed
			player.position = Vector2(640.0 + cos(t) * 180.0, 360.0 + sin(t * 1.4) * 130.0)

	var run_active: bool = bool(main.get("_run_active"))
	var killed: int = int(TelemetryService.get_snapshot().get("enemies_killed", 0))
	if run_active:
		print("[AutomatedPlaytest] PASS  run survived %.1fs  kills=%d" % [TEST_SECONDS, killed])
	else:
		push_error("[AutomatedPlaytest] FAIL  run ended early")
