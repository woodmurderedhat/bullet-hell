## VisualRegressionTest — captures frame snapshot and compares hash with baseline.
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const BASELINE_PATH: String = "user://visual_baseline_hash.txt"


func _ready() -> void:
	print("[VisualRegressionTest] Running...")
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)

	await get_tree().process_frame
	main.call("_start_run")
	await get_tree().create_timer(1.5).timeout

	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var hash_value: String = _hash_image(image)

	if not FileAccess.file_exists(BASELINE_PATH):
		var file_init: FileAccess = FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
		if file_init != null:
			file_init.store_string(hash_value)
			file_init.close()
		print("[VisualRegressionTest] BASELINE CREATED")
		return

	var file: FileAccess = FileAccess.open(BASELINE_PATH, FileAccess.READ)
	if file == null:
		push_error("[VisualRegressionTest] FAIL  unable to read baseline")
		return
	var baseline: String = file.get_as_text().strip_edges()
	file.close()

	if baseline == hash_value:
		print("[VisualRegressionTest] PASS  hash matches baseline")
	else:
		push_warning("[VisualRegressionTest] WARN  hash differs from baseline")


func _hash_image(image: Image) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(image.get_data())
	var digest: PackedByteArray = ctx.finish()
	return digest.hex_encode()
