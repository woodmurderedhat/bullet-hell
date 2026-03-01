## SaveService — meta-progression persistence.
## Supports multiple local save slots and optional cloud mirror fallback.
## Autoloaded as "SaveService".
extends Node

const SAVE_SLOT_COUNT: int = 3
const SLOT_PATH_TEMPLATE: String = "user://save_slot_%d.json"
const CLOUD_PATH_TEMPLATE: String = "user://cloud_slot_%d.json"

## Default structure for a fresh save.
const DEFAULT_SAVE: Dictionary = {
	"meta_currency": 0,
	"meta_unlocks": [],
	"high_score": 0,
	"leaderboard_scores": [],
	"runs_completed": 0,
	"cloud_enabled": false,
	"endless_mode": false,
	"selected_loadout": 0,
	"daily_modifier_id": "",
	"input_bindings": {},
	"platform_achievements": [],
	"platform_leaderboard_scores": [],
}

var _data: Dictionary = {}
var _active_slot: int = 0


func _ready() -> void:
	load_save()


## Load save from disk.  Falls back to DEFAULT_SAVE if no file exists.
func load_save() -> void:
	var save_path: String = _path_for_slot(_active_slot)
	var cloud_path: String = _cloud_path_for_slot(_active_slot)
	var use_cloud: bool = FileAccess.file_exists(cloud_path) and not FileAccess.file_exists(save_path)
	if use_cloud:
		_copy_cloud_to_local(cloud_path, save_path)

	if not FileAccess.file_exists(save_path):
		_data = DEFAULT_SAVE.duplicate(true)
		return

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("SaveService: failed to open save file, using defaults.")
		_data = DEFAULT_SAVE.duplicate(true)
		return

	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		push_warning("SaveService: corrupt save file, using defaults.")
		_data = DEFAULT_SAVE.duplicate(true)
		return

	# Merge so new default keys are added on first run after an update.
	_data = DEFAULT_SAVE.duplicate(true)
	for key: String in parsed.keys():
		_data[key] = parsed[key]


## Persist current data to disk.
func write_save() -> void:
	var save_path: String = _path_for_slot(_active_slot)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot write save file.")
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()

	if bool(_data.get("cloud_enabled", false)):
		var cloud_path: String = _cloud_path_for_slot(_active_slot)
		var cloud_file: FileAccess = FileAccess.open(cloud_path, FileAccess.WRITE)
		if cloud_file != null:
			cloud_file.store_string(JSON.stringify(_data, "\t"))
			cloud_file.close()


## Get a value by key; returns the default value if the key is missing.
func get_save(key: String, default: Variant = null) -> Variant:
	return _data.get(key, default)


## Set a value by key and persist immediately.
func set_save(key: String, value: Variant) -> void:
	_data[key] = value
	write_save()


## Convenience: add delta to meta_currency (negative values subtract).
func add_currency(delta: int) -> void:
	_data["meta_currency"] = int(_data.get("meta_currency", 0)) + delta
	write_save()


## Convenience: add an unlock ID if not already present.
func add_unlock(unlock_id: StringName) -> void:
	var unlocks: Array = _data.get("meta_unlocks", [])
	if not unlocks.has(str(unlock_id)):
		unlocks.append(str(unlock_id))
		_data["meta_unlocks"] = unlocks
		write_save()


## Returns true if the given upgrade ID is unlocked.
func is_unlocked(unlock_id: StringName) -> bool:
	var unlocks: Array = _data.get("meta_unlocks", [])
	return unlocks.has(str(unlock_id))


func set_active_slot(slot: int) -> void:
	_active_slot = clampi(slot, 0, SAVE_SLOT_COUNT - 1)
	load_save()


func get_active_slot() -> int:
	return _active_slot


func get_slot_summary(slot: int) -> Dictionary:
	var clamped_slot: int = clampi(slot, 0, SAVE_SLOT_COUNT - 1)
	var path: String = _path_for_slot(clamped_slot)
	if not FileAccess.file_exists(path):
		return {
			"exists": false,
			"meta_currency": 0,
			"high_score": 0,
			"runs_completed": 0,
		}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"exists": false,
			"meta_currency": 0,
			"high_score": 0,
			"runs_completed": 0,
		}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {
			"exists": false,
			"meta_currency": 0,
			"high_score": 0,
			"runs_completed": 0,
		}

	return {
		"exists": true,
		"meta_currency": int(parsed.get("meta_currency", 0)),
		"high_score": int(parsed.get("high_score", 0)),
		"runs_completed": int(parsed.get("runs_completed", 0)),
	}


func record_leaderboard_score(score: int) -> void:
	var scores: Array = _data.get("leaderboard_scores", [])
	scores.append(score)
	scores.sort_custom(func(a: int, b: int) -> bool: return a > b)
	if scores.size() > 10:
		scores.resize(10)
	_data["leaderboard_scores"] = scores
	if score > int(_data.get("high_score", 0)):
		_data["high_score"] = score
	write_save()


func get_leaderboard_scores() -> Array[int]:
	var raw: Array = _data.get("leaderboard_scores", [])
	var out: Array[int] = []
	for value: Variant in raw:
		out.append(int(value))
	return out


func _path_for_slot(slot: int) -> String:
	return SLOT_PATH_TEMPLATE % slot


func _cloud_path_for_slot(slot: int) -> String:
	return CLOUD_PATH_TEMPLATE % slot


func _copy_cloud_to_local(cloud_path: String, local_path: String) -> void:
	var cloud_file: FileAccess = FileAccess.open(cloud_path, FileAccess.READ)
	if cloud_file == null:
		return
	var cloud_text: String = cloud_file.get_as_text()
	cloud_file.close()

	var local_file: FileAccess = FileAccess.open(local_path, FileAccess.WRITE)
	if local_file == null:
		return
	local_file.store_string(cloud_text)
	local_file.close()
