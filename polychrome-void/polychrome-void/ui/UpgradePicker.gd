## UpgradePicker — shown between arenas; displays 3 upgrade cards for selection.
## Hides during combat.  Emits EventBus.upgrade_chosen when player picks.
## Add via scenes/UpgradePicker.tscn.
class_name UpgradePicker
extends CanvasLayer

const CARD_SIZE: Vector2   = Vector2(260.0, 340.0)
const CARD_GAP: float      = 40.0
const CARD_Y: float        = 190.0
const CARD_DESC_Y: float = 110.0
const CARD_DESC_BOTTOM_PAD: float = 8.0
const CARD_TAGS_HEIGHT: float = 24.0
const CARD_TAGS_GAP_ABOVE_BUTTON: float = 8.0
const CARD_BUTTON_HEIGHT: float = 36.0
const CARD_BUTTON_BOTTOM_MARGIN: float = 10.0
const CARD_COLORS: Array[Color] = [
	Color(0.08, 0.08, 0.12),  # Base fill
	Color(0.12, 0.12, 0.18),  # Hover fill
]
const COLOR_TITLE: Color = Color(0.95, 0.45, 1.0)
const COLOR_NAME: Color = Color(0.93, 0.95, 1.0)
const COLOR_DESC: Color = Color(0.80, 0.87, 0.96)
const COLOR_TAGS: Color = Color(0.45, 0.90, 1.0)
const COLOR_BTN: Color = Color(0.20, 0.52, 0.95)
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
	title.add_theme_color_override("font_color", COLOR_TITLE)
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

	_offers = _upgrade_pool.generate_offer(3, tags, _modifier_component)

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
	panel.clip_contents = true

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
	name_lbl.text = _compact_name(res.display_name if res.display_name != "" else str(res.id))
	name_lbl.position = Vector2(10.0, 50.0)
	name_lbl.size = Vector2(CARD_SIZE.x - 20.0, 40.0)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", COLOR_NAME)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.clip_text = true
	panel.add_child(name_lbl)

	# Description.
	var button_y: float = CARD_SIZE.y - CARD_BUTTON_HEIGHT - CARD_BUTTON_BOTTOM_MARGIN
	var tags_y: float = button_y - CARD_TAGS_GAP_ABOVE_BUTTON - CARD_TAGS_HEIGHT
	var desc_height: float = tags_y - CARD_DESC_Y - CARD_DESC_BOTTOM_PAD

	var desc_lbl: RichTextLabel = RichTextLabel.new()
	desc_lbl.fit_content = false
	desc_lbl.scroll_active = false
	desc_lbl.bbcode_enabled = false
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.clip_contents = true
	desc_lbl.position = Vector2(16.0, CARD_DESC_Y)
	desc_lbl.size = Vector2(CARD_SIZE.x - 32.0, maxf(desc_height, 64.0))
	desc_lbl.add_theme_font_size_override("normal_font_size", 13)
	desc_lbl.add_theme_color_override("default_color", COLOR_DESC)
	desc_lbl.text = _compact_description(res.description)
	panel.add_child(desc_lbl)

	# Tags row.
	var tags_lbl: Label = Label.new()
	var tag_strs: Array[String] = []
	for t: StringName in res.tags:
		tag_strs.append(str(t).to_upper())
	tags_lbl.text = _compact_tags(tag_strs)
	tags_lbl.position = Vector2(10.0, tags_y)
	tags_lbl.size = Vector2(CARD_SIZE.x - 20.0, CARD_TAGS_HEIGHT)
	tags_lbl.add_theme_font_size_override("font_size", 12)
	tags_lbl.add_theme_color_override("font_color", COLOR_TAGS)
	tags_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tags_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tags_lbl.clip_text = true
	panel.add_child(tags_lbl)

	# Select button.
	var btn: Button = Button.new()
	btn.text = "SELECT"
	btn.position = Vector2(30.0, button_y)
	btn.size = Vector2(CARD_SIZE.x - 60.0, 36.0)
	_style_select_button(btn)
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


func _compact_description(text: String) -> String:
	var compact: String = text.strip_edges()
	compact = compact.replace("Increase ", "+")
	compact = compact.replace("Decreases ", "-")
	compact = compact.replace("your ", "")
	compact = compact.replace("damage", "DMG")
	compact = compact.replace("critical", "CRIT")
	compact = compact.replace("seconds", "s")
	if compact.length() > 120:
		compact = compact.substr(0, 117) + "..."
	return compact


func _compact_name(text: String) -> String:
	var compact: String = text.strip_edges()
	if compact.length() > 28:
		compact = compact.substr(0, 25) + "..."
	return compact


func _compact_tags(tags: Array[String]) -> String:
	if tags.is_empty():
		return ""
	var text: String = "• ".join(tags)
	if text.length() > 34:
		text = text.substr(0, 31) + "..."
	return text


func _style_select_button(button: Button) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = COLOR_BTN
	normal.border_color = Color(1.0, 1.0, 1.0, 0.25)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR_BTN.lightened(0.12)

	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = COLOR_BTN.darkened(0.16)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
