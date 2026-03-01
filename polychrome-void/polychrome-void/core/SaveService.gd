## SaveService — meta-progression persistence.
## Saves and loads a JSON file at user://save.json.
## Stores meta currency, unlocked upgrade IDs, and run history.
## Autoloaded as "SaveService".
extends Node

const SAVE_PATH: String = "user://save.json"

## Default structure for a fresh save.
const DEFAULT_SAVE: Dictionary = {
	"meta_currency": 0,
	"meta_unlocks": [],
	"high_score": 0,
	"runs_completed": 0,
}

var _data: Dictionary = {}


func _ready() -> void:
	load_save()


## Load save from disk.  Falls back to DEFAULT_SAVE if no file exists.
func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_data = DEFAULT_SAVE.duplicate(true)
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
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
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot write save file.")
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()


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
