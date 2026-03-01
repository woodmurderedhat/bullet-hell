## UpgradePicker — shown between arenas; displays 3 upgrade cards for selection.
## Hides during combat.  Emits EventBus.upgrade_chosen when player picks.
## Add via scenes/UpgradePicker.tscn.
class_name UpgradePicker
extends CanvasLayer

const CARD_SIZE: Vector2   = Vector2(260.0, 340.0)
const CARD_GAP: float      = 40.0
const CARD_Y: float        = 190.0
const CARD_COLORS: Array[Color] = [
	Color(0.08, 0.08, 0.12),  # Base fill
	Color(0.12, 0.12, 0.18),  # Hover fill
]
const RARITY_COLORS: Array[Color] = [
	Color(0.7, 0.7, 0.7),   # Common
	Color(0.3, 0.6, 1.0),   # Rare
	Color(0.8, 0.3, 1.0),   # Epic
	Color(1.0, 0.8, 0.0),   # Legendary
]
const RARITY_NAMES: Array[String] = ["COMMON", "RARE", "EPIC", "LEGENDARY"]

var _offers: Array[UpgradeResource] = []
var _card_panels: Array[Panel] = []
var _upgrade_pool: UpgradePool = null
var _modifier_component: ModifierComponent = null

var _bg_overlay: ColorRect


func _ready() -> void:
	layer = 20
	visible = false
	_build_bg()
	EventBus.wave_complete.connect(_on_wave_complete)


func initialise(pool: UpgradePool, modifier: ModifierComponent) -> void:
	_upgrade_pool = pool
	_modifier_component = modifier


func _build_bg() -> void:
	_bg_overlay = ColorRect.new()
	_bg_overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	_bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_overlay)

	var title: Label = Label.new()
	title.text = "— CHOOSE UPGRADE —"
	title.position = Vector2(0.0, 100.0)
	title.size = Vector2(1280.0, 50.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)


func _on_wave_complete(_arena_index: int) -> void:
	_show_picker()


func _show_picker() -> void:
	# Clear previous cards.
	for panel: Panel in _card_panels:
		panel.queue_free()
	_card_panels.clear()

	if _upgrade_pool == null:
		return

	# Gather dominant tags for synergy bias.
	var tags: Array[StringName] = []
	if _modifier_component != null:
		tags = _modifier_component.get_active_tags(_upgrade_pool._all_resources)

	_offers = _upgrade_pool.generate_offer(3, tags)

	var total_w: float = 3.0 * CARD_SIZE.x + 2.0 * CARD_GAP
	var start_x: float = (1280.0 - total_w) * 0.5

	for i: int in range(_offers.size()):
		var res: UpgradeResource = _offers[i]
		var card_x: float = start_x + i * (CARD_SIZE.x + CARD_GAP)
		var panel: Panel = _build_card(res, Vector2(card_x, CARD_Y), i)
		add_child(panel)
		_card_panels.append(panel)

	visible = true


## Build a single upgrade card panel.
func _build_card(res: UpgradeResource, pos: Vector2, card_index: int) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = pos
	panel.size = CARD_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Rarity colour border via StyleBoxFlat.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_COLORS[0]
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = RARITY_COLORS[res.rarity]
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	# Rarity label.
	var rarity_lbl: Label = Label.new()
	rarity_lbl.text = RARITY_NAMES[res.rarity]
	rarity_lbl.position = Vector2(10.0, 12.0)
	rarity_lbl.size = Vector2(CARD_SIZE.x - 20.0, 24.0)
	rarity_lbl.add_theme_color_override("font_color", RARITY_COLORS[res.rarity])
	rarity_lbl.add_theme_font_size_override("font_size", 13)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(rarity_lbl)

	# Upgrade name.
	var name_lbl: Label = Label.new()
	name_lbl.text = res.display_name if res.display_name != "" else str(res.id)
	name_lbl.position = Vector2(10.0, 50.0)
	name_lbl.size = Vector2(CARD_SIZE.x - 20.0, 40.0)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(name_lbl)

	# Description.
	var desc_lbl: Label = Label.new()
	desc_lbl.text = res.description
	desc_lbl.position = Vector2(16.0, 110.0)
	desc_lbl.size = Vector2(CARD_SIZE.x - 32.0, 160.0)
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	panel.add_child(desc_lbl)

	# Tags row.
	var tags_lbl: Label = Label.new()
	var tag_strs: Array[String] = []
	for t: StringName in res.tags:
		tag_strs.append(str(t).to_upper())
	tags_lbl.text = " / ".join(tag_strs)
	tags_lbl.position = Vector2(10.0, 286.0)
	tags_lbl.size = Vector2(CARD_SIZE.x - 20.0, 22.0)
	tags_lbl.add_theme_font_size_override("font_size", 12)
	tags_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	tags_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(tags_lbl)

	# Select button.
	var btn: Button = Button.new()
	btn.text = "SELECT"
	btn.position = Vector2(30.0, 0.0)
	btn.size = Vector2(CARD_SIZE.x - 60.0, 36.0)
	btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	btn.offset_top    = -46.0
	btn.offset_bottom = -10.0
	var idx: int = card_index  # Capture for lambda.
	btn.pressed.connect(func() -> void: _on_card_selected(idx))
	panel.add_child(btn)

	return panel


func _on_card_selected(index: int) -> void:
	if index < 0 or index >= _offers.size():
		return
	var chosen: UpgradeResource = _offers[index]
	visible = false
	EventBus.upgrade_chosen.emit(chosen)
