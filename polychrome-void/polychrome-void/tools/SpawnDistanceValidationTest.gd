## SpawnDistanceValidationTest — verifies enemies never spawn on or near player.
## Validates that all spawned enemies maintain min_spawn_distance_to_player constraint.
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TEST_SECONDS: float = 20.0


func _ready() -> void:
	print("[SpawnDistanceValidationTest] Running...")
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)

	await get_tree().process_frame
	main.call("_start_run")

	var player: Player = main.get_node("Player") as Player
	var spawn_director: SpawnDirector = main.get_node("SpawnDirector") as SpawnDirector
	
	if player == null or spawn_director == null:
		push_error("[SpawnDistanceValidationTest] FAIL  could not get player or spawn_director")
		get_tree().quit()
		return

	player.stats.max_hp = 100000.0
	player.stats.current_hp = 100000.0

	var violations: Array[Dictionary] = []
	var spawn_count: int = 0
	var elapsed: float = 0.0
	var min_safe_distance: float = 170.0  # Baseline minimum spawn distance.

	# Move player in circular pattern to test spawn safety across arena positions.
	while elapsed < TEST_SECONDS:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		
		# Move player in a circle.
		var t: float = elapsed
		player.position = Vector2(640.0 + cos(t) * 180.0, 360.0 + sin(t * 1.4) * 130.0)

		# Check all active enemies and validate distance.
		var enemies: Array[Node] = main.get_tree().get_nodes_in_group("enemies")
		for enemy_node: Node in enemies:
			var enemy: Enemy = enemy_node as Enemy
			var boss: Boss = enemy_node as Boss
			
			if enemy != null:
				spawn_count += 1
				var distance: float = enemy.global_position.distance_to(player.global_position)
				if distance < min_safe_distance:
					violations.append({
						"type": "enemy",
						"id": enemy.enemy_id,
						"distance": distance,
						"min_distance": min_safe_distance,
						"player_pos": player.global_position,
						"enemy_pos": enemy.global_position
					})
			elif boss != null:
				spawn_count += 1
				var distance: float = boss.global_position.distance_to(player.global_position)
				if distance < min_safe_distance:
					violations.append({
						"type": "boss",
						"id": boss.boss_id,
						"distance": distance,
						"min_distance": min_safe_distance,
						"player_pos": player.global_position,
						"boss_pos": boss.global_position
					})

	if violations.is_empty():
		print("[SpawnDistanceValidationTest] PASS  ~%d spawns validated, no violations below %.0f px" % [spawn_count, min_safe_distance])
	else:
		print("[SpawnDistanceValidationTest] FAIL  %d violations out of ~%d spawns:" % [violations.size(), spawn_count])
		for violation: Dictionary in violations:
			print("  - %s (id=%d): distance=%.1f px (min=%.1f px)" % [
				violation.type,
				violation.id,
				violation.distance,
				violation.min_distance
			])
		push_error("[SpawnDistanceValidationTest] Spawn distance constraint violated!")
