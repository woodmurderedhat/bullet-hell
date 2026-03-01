## SpawnWaveIntegrationTest — verifies waves advance under runtime load.
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TEST_SECONDS: float = 14.0


func _ready() -> void:
	print("[SpawnWaveIntegrationTest] Running...")
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)

	await get_tree().process_frame
	main.call("_start_run")

	await get_tree().create_timer(TEST_SECONDS).timeout
	var arena_index: int = int(main.get_node("SpawnDirector").arena_index)
	if arena_index >= 1:
		print("[SpawnWaveIntegrationTest] PASS  arena_index=%d" % arena_index)
	else:
		push_error("[SpawnWaveIntegrationTest] FAIL  wave did not advance")
