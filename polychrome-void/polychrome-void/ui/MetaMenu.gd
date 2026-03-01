## MetaMenuScene — displayed between runs; shows meta-currency and unlocks.
## Unlocks feed into UpgradePool on the next run.
class_name MetaMenu
extends CanvasLayer

const UNLOCK_COST: int = 50  ## Currency cost per unlock.

var _currency_label: Label
var _unlock_buttons: Array[Button] = []
var _leaderboard_label: Label
var _slot_label: Label
var _mode_label: Label
var _loadout_label: Label
var _daily_label: Label

## Hardcoded list of meta-unlockable upgrade IDs + their display names.
## When unlocked these IDs are passed to SaveService which UpgradePool reads.
const UNLOCKABLE_UPGRADES: Array[Dictionary] = [
	{"id": "fractal_chain_01",  "name": "FRACTAL CHAIN",  "cost": 50},
	{"id": "chaos_gamble_01",   "name": "CHAOS GAMBLE",   "cost": 75},
	{"id": "shield_reflect_01", "name": "SHIELD REFLECT", "cost": 60},
	{"id": "entropy_wild_01",   "name": "ENTROPY WILD",   "cost": 80},
	{"id": "crit_multi_01",     "name": "CRIT MULTIPLIER","cost": 65},
]

signal play_pressed()
signal tutorial_pressed()


func _ready() -> void:
	layer = 30
	_build_ui()
	EventBus.run_ended.connect(_on_run_ended)


func _build_ui() -> void:
	# Dark full-screen background.
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title: Label = Label.new()
	title.text = "POLYCHROME  VOID"
	title.position = Vector2(0.0, 60.0)
	title.size = Vector2(1280.0, 60.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	add_child(title)

	_currency_label = Label.new()
	_currency_label.position = Vector2(0.0, 140.0)
	_currency_label.size = Vector2(1280.0, 36.0)
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_currency_label.add_theme_font_size_override("font_size", 22)
	add_child(_currency_label)

	_slot_label = Label.new()
	_slot_label.position = Vector2(40.0, 40.0)
	_slot_label.size = Vector2(300.0, 30.0)
	add_child(_slot_label)

	for slot: int in range(SaveService.SAVE_SLOT_COUNT):
		var slot_btn: Button = Button.new()
		slot_btn.text = "SLOT %d" % (slot + 1)
		slot_btn.position = Vector2(40.0 + slot * 100.0, 72.0)
		slot_btn.size = Vector2(90.0, 34.0)
		var captured_slot: int = slot
		slot_btn.pressed.connect(func() -> void: _on_slot_selected(captured_slot))
		add_child(slot_btn)

	_mode_label = Label.new()
	_mode_label.position = Vector2(930.0, 46.0)
	_mode_label.size = Vector2(320.0, 30.0)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_mode_label)

	var mode_btn: Button = Button.new()
	mode_btn.text = "TOGGLE ENDLESS"
	mode_btn.position = Vector2(1030.0, 76.0)
	mode_btn.size = Vector2(220.0, 34.0)
	mode_btn.pressed.connect(_toggle_endless)
	add_child(mode_btn)

	_loadout_label = Label.new()
	_loadout_label.position = Vector2(930.0, 116.0)
	_loadout_label.size = Vector2(320.0, 30.0)
	_loadout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_loadout_label)

	var loadout_btn: Button = Button.new()
	loadout_btn.text = "CYCLE LOADOUT"
	loadout_btn.position = Vector2(1030.0, 146.0)
	loadout_btn.size = Vector2(220.0, 34.0)
	loadout_btn.pressed.connect(_cycle_loadout)
	add_child(loadout_btn)

	_daily_label = Label.new()
	_daily_label.position = Vector2(930.0, 186.0)
	_daily_label.size = Vector2(320.0, 30.0)
	_daily_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_daily_label)

	# Unlock grid.
	var grid_x: float = 340.0
	var grid_y: float = 210.0
	for i: int in range(UNLOCKABLE_UPGRADES.size()):
		var data: Dictionary = UNLOCKABLE_UPGRADES[i]
		var btn: Button = Button.new()
		btn.position = Vector2(grid_x, grid_y + i * 60.0)
		btn.size = Vector2(600.0, 48.0)
		var unlocked: bool = SaveService.is_unlocked(StringName(data["id"]))
		btn.text = "%s  [%s]  Cost: %d" % [
			data["name"],
			"UNLOCKED" if unlocked else "LOCKED",
			int(data["cost"])
		]
		btn.disabled = unlocked
		var cap_i: int = i
		btn.pressed.connect(func() -> void: _on_unlock_pressed(cap_i))
		add_child(btn)
		_unlock_buttons.append(btn)

	# Play button.
	var play_btn: Button = Button.new()
	play_btn.text = "▶  PLAY"
	play_btn.position = Vector2(490.0, 590.0)
	play_btn.size = Vector2(300.0, 56.0)
	play_btn.add_theme_font_size_override("font_size", 24)
	play_btn.pressed.connect(func() -> void: play_pressed.emit())
	add_child(play_btn)

	var tutorial_btn: Button = Button.new()
	tutorial_btn.text = "?  HOW TO PLAY"
	tutorial_btn.position = Vector2(490.0, 654.0)
	tutorial_btn.size = Vector2(300.0, 40.0)
	tutorial_btn.pressed.connect(func() -> void: tutorial_pressed.emit())
	add_child(tutorial_btn)

	_leaderboard_label = Label.new()
	_leaderboard_label.position = Vector2(40.0, 420.0)
	_leaderboard_label.size = Vector2(300.0, 240.0)
	_leaderboard_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_leaderboard_label)

	refresh_menu()


func refresh_menu() -> void:
	var cur: int = int(SaveService.get_save("meta_currency", 0))
	_currency_label.text = "META CURRENCY:  %d" % cur
	_slot_label.text = "ACTIVE SLOT: %d" % (SaveService.get_active_slot() + 1)
	_mode_label.text = "MODE: %s" % ("ENDLESS" if bool(SaveService.get_save("endless_mode", false)) else "STANDARD")
	_loadout_label.text = "LOADOUT: %s" % _loadout_name(int(SaveService.get_save("selected_loadout", 0)))
	_daily_label.text = "DAILY: %s" % String(SaveService.get_save("daily_modifier_id", "pending"))

	var scores: Array[int] = SaveService.get_leaderboard_scores()
	var lines: Array[String] = ["LEADERBOARD"]
	if scores.is_empty():
		lines.append("- no scores yet -")
	else:
		for i: int in range(scores.size()):
			lines.append("%d. %d" % [i + 1, scores[i]])
	_leaderboard_label.text = "\n".join(lines)

	# Refresh button disabled states.
	for i: int in range(UNLOCKABLE_UPGRADES.size()):
		if i < _unlock_buttons.size():
			var unlocked: bool = SaveService.is_unlocked(
				StringName(UNLOCKABLE_UPGRADES[i]["id"])
			)
			_unlock_buttons[i].disabled = unlocked


func _on_unlock_pressed(index: int) -> void:
	var data: Dictionary = UNLOCKABLE_UPGRADES[index]
	var cost: int = int(data["cost"])
	var cur: int = int(SaveService.get_save("meta_currency", 0))
	if cur < cost:
		return
	SaveService.add_currency(-cost)
	SaveService.add_unlock(StringName(data["id"]))
	refresh_menu()


func _on_run_ended(result: Dictionary) -> void:
	# Award meta currency based on score.
	var score: int = int(result.get("score", 0))
	var reward: int = max(1, score / 10)
	SaveService.add_currency(reward)
	EventBus.meta_reward_earned.emit(reward, &"")
	refresh_menu()


func _on_slot_selected(slot: int) -> void:
	SaveService.set_active_slot(slot)
	refresh_menu()


func _toggle_endless() -> void:
	var next_value: bool = not bool(SaveService.get_save("endless_mode", false))
	SaveService.set_save("endless_mode", next_value)
	refresh_menu()


func _cycle_loadout() -> void:
	var current: int = int(SaveService.get_save("selected_loadout", 0))
	var next_value: int = (current + 1) % 3
	SaveService.set_save("selected_loadout", next_value)
	refresh_menu()


func _loadout_name(loadout_idx: int) -> String:
	match loadout_idx:
		1:
			return "STRIKER"
		2:
			return "TANK"
		_:
			return "BALANCED"
