## MetaMenuScene — displayed between runs; shows meta-currency and unlocks.
## Unlocks feed into UpgradePool on the next run.
class_name MetaMenu
extends CanvasLayer

const UNLOCK_COST: int = 50  ## Currency cost per unlock.

var _currency_label: Label
var _unlock_buttons: Array[Button] = []

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

	_refresh_currency()


func _refresh_currency() -> void:
	var cur: int = int(SaveService.get_save("meta_currency", 0))
	_currency_label.text = "META CURRENCY:  %d" % cur
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
	_refresh_currency()


func _on_run_ended(result: Dictionary) -> void:
	# Award meta currency based on score.
	var score: int = int(result.get("score", 0))
	var reward: int = max(1, score / 10)
	SaveService.add_currency(reward)
	EventBus.meta_reward_earned.emit(reward, &"")
	_refresh_currency()
	visible = true
