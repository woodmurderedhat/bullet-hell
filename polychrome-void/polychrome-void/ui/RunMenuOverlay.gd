## RunMenuOverlay — in-run UI for pause/settings/controls and run complete results.
class_name RunMenuOverlay
extends CanvasLayer

signal resume_requested()
signal quit_to_menu_requested()
signal restart_requested()
signal tutorial_closed()

const ACTIONS_TO_REBIND: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"fire",
	&"pause",
]

const COLOR_OVERLAY: Color = Color(0.0, 0.0, 0.0, 0.78)
const COLOR_PANEL_BG: Color = Color(0.08, 0.10, 0.16, 0.96)
const COLOR_PANEL_BORDER: Color = Color(0.42, 0.78, 1.0, 0.48)
const COLOR_TITLE: Color = Color(0.95, 0.45, 1.0)
const COLOR_TEXT: Color = Color(0.88, 0.93, 1.0)
const COLOR_TEXT_DIM: Color = Color(0.70, 0.82, 0.95)
const COLOR_BUTTON_PRIMARY: Color = Color(0.22, 0.56, 0.98)
const COLOR_BUTTON_SECONDARY: Color = Color(0.18, 0.24, 0.36)

var _bg: ColorRect
var _pause_panel: Panel
var _settings_panel: Panel
var _controls_panel: Panel
var _result_panel: Panel
var _tutorial_panel: Panel

var _result_title: Label
var _result_summary: Label
var _music_slider: HSlider
var _sfx_slider: HSlider
var _telemetry_toggle: CheckBox
var _cloud_toggle: CheckBox
var _action_buttons: Dictionary = {}
var _pending_rebind_action: StringName = &""
var _tutorial_returns_to_pause: bool = true


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func show_pause_menu() -> void:
	visible = true
	_tutorial_returns_to_pause = true
	_show_only(_pause_panel)
	_update_setting_values()


func show_result_menu(won: bool, score: int, arena_reached: int, telemetry: Dictionary) -> void:
	visible = true
	_tutorial_returns_to_pause = false
	_show_only(_result_panel)
	_result_title.text = "RUN COMPLETE" if won else "RUN FAILED"
	_result_summary.text = "S %d\nA %d\nT %.1fs\nK %d" % [
		score,
		arena_reached + 1,
		float(telemetry.get("session_time", 0.0)),
		int(telemetry.get("enemies_killed", 0)),
	]


func hide_all() -> void:
	visible = false
	_pending_rebind_action = &""
	_tutorial_returns_to_pause = true


func show_tutorial_menu(returns_to_pause: bool) -> void:
	visible = true
	_tutorial_returns_to_pause = returns_to_pause
	_show_only(_tutorial_panel)


func _unhandled_input(event: InputEvent) -> void:
	if _pending_rebind_action == StringName():
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		_apply_key_rebind(_pending_rebind_action, key_event)
		_pending_rebind_action = &""
		_update_action_button_texts()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = COLOR_OVERLAY
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	_pause_panel = _make_panel("PAUSED", Vector2(410.0, 180.0), Vector2(460.0, 360.0))
	_settings_panel = _make_panel("SETTINGS", Vector2(320.0, 120.0), Vector2(640.0, 470.0))
	_controls_panel = _make_panel("CONTROLS", Vector2(320.0, 90.0), Vector2(640.0, 540.0))
	_result_panel = _make_panel("RUN COMPLETE", Vector2(390.0, 140.0), Vector2(500.0, 420.0))
	_tutorial_panel = _make_panel("HOW TO PLAY", Vector2(260.0, 80.0), Vector2(760.0, 560.0))

	_build_pause_panel()
	_build_settings_panel()
	_build_controls_panel()
	_build_result_panel()
	_build_tutorial_panel()

	_show_only(_pause_panel)


func _make_panel(title: String, pos: Vector2, size: Vector2) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = pos
	panel.size = size

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL_BG
	panel_style.border_color = COLOR_PANEL_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var title_label: Label = Label.new()
	title_label.text = title
	title_label.position = Vector2(0.0, 14.0)
	title_label.size = Vector2(size.x, 36.0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", COLOR_TITLE)
	panel.add_child(title_label)

	return panel


func _build_pause_panel() -> void:
	var resume_btn: Button = _make_button("RESUME", Vector2(130.0, 90.0), Vector2(200.0, 46.0), COLOR_BUTTON_PRIMARY)
	resume_btn.pressed.connect(func() -> void: resume_requested.emit())
	_pause_panel.add_child(resume_btn)

	var settings_btn: Button = _make_button("SETTINGS", Vector2(130.0, 150.0), Vector2(200.0, 46.0), COLOR_BUTTON_SECONDARY)
	settings_btn.pressed.connect(func() -> void:
		_update_setting_values()
		_show_only(_settings_panel)
	)
	_pause_panel.add_child(settings_btn)

	var tutorial_btn: Button = _make_button("HOW TO PLAY", Vector2(130.0, 210.0), Vector2(200.0, 46.0), COLOR_BUTTON_SECONDARY)
	tutorial_btn.pressed.connect(func() -> void: show_tutorial_menu(true))
	_pause_panel.add_child(tutorial_btn)

	var quit_btn: Button = _make_button("QUIT", Vector2(130.0, 270.0), Vector2(200.0, 46.0), COLOR_BUTTON_SECONDARY)
	quit_btn.pressed.connect(func() -> void: quit_to_menu_requested.emit())
	_pause_panel.add_child(quit_btn)


func _build_settings_panel() -> void:
	var music_lbl: Label = Label.new()
	music_lbl.text = "MUSIC"
	music_lbl.position = Vector2(50.0, 90.0)
	music_lbl.size = Vector2(180.0, 28.0)
	music_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_settings_panel.add_child(music_lbl)

	_music_slider = HSlider.new()
	_music_slider.position = Vector2(250.0, 92.0)
	_music_slider.size = Vector2(320.0, 24.0)
	_music_slider.min_value = 0.0
	_music_slider.max_value = 1.0
	_music_slider.step = 0.01
	_music_slider.value_changed.connect(func(v: float) -> void: _set_bus_linear_volume("Music", v, "volume_music"))
	_settings_panel.add_child(_music_slider)

	var sfx_lbl: Label = Label.new()
	sfx_lbl.text = "SFX"
	sfx_lbl.position = Vector2(50.0, 140.0)
	sfx_lbl.size = Vector2(180.0, 28.0)
	sfx_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_settings_panel.add_child(sfx_lbl)

	_sfx_slider = HSlider.new()
	_sfx_slider.position = Vector2(250.0, 142.0)
	_sfx_slider.size = Vector2(320.0, 24.0)
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.01
	_sfx_slider.value_changed.connect(func(v: float) -> void: _set_bus_linear_volume("SFX", v, "volume_sfx"))
	_settings_panel.add_child(_sfx_slider)

	_telemetry_toggle = CheckBox.new()
	_telemetry_toggle.text = "Telemetry HUD"
	_telemetry_toggle.position = Vector2(50.0, 200.0)
	_telemetry_toggle.add_theme_color_override("font_color", COLOR_TEXT)
	_telemetry_toggle.toggled.connect(func(pressed: bool) -> void: TelemetryService.set_overlay_enabled(pressed))
	_settings_panel.add_child(_telemetry_toggle)

	_cloud_toggle = CheckBox.new()
	_cloud_toggle.text = "Cloud Mirror"
	_cloud_toggle.position = Vector2(50.0, 240.0)
	_cloud_toggle.add_theme_color_override("font_color", COLOR_TEXT)
	_cloud_toggle.toggled.connect(func(pressed: bool) -> void: SaveService.set_save("cloud_enabled", pressed))
	_settings_panel.add_child(_cloud_toggle)

	var controls_btn: Button = _make_button("REMAP KEYS", Vector2(50.0, 300.0), Vector2(220.0, 42.0), COLOR_BUTTON_SECONDARY)
	controls_btn.pressed.connect(func() -> void:
		_update_action_button_texts()
		_show_only(_controls_panel)
	)
	_settings_panel.add_child(controls_btn)

	var back_btn: Button = _make_button("BACK", Vector2(430.0, 390.0), Vector2(140.0, 42.0), COLOR_BUTTON_PRIMARY)
	back_btn.pressed.connect(func() -> void: _show_only(_pause_panel))
	_settings_panel.add_child(back_btn)


func _build_controls_panel() -> void:
	var y: float = 90.0
	for action: StringName in ACTIONS_TO_REBIND:
		var label: Label = Label.new()
		label.text = str(action).replace("_", " ").to_upper()
		label.position = Vector2(40.0, y)
		label.size = Vector2(220.0, 30.0)
		label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		_controls_panel.add_child(label)

		var btn: Button = _make_button("", Vector2(280.0, y - 4.0), Vector2(320.0, 36.0), COLOR_BUTTON_SECONDARY)
		var captured_action: StringName = action
		btn.pressed.connect(func() -> void:
			_pending_rebind_action = captured_action
			btn.text = "PRESS A KEY..."
		)
		_controls_panel.add_child(btn)
		_action_buttons[action] = btn
		y += 58.0

	var back_btn: Button = _make_button("BACK", Vector2(460.0, 480.0), Vector2(140.0, 42.0), COLOR_BUTTON_PRIMARY)
	back_btn.pressed.connect(func() -> void: _show_only(_settings_panel))
	_controls_panel.add_child(back_btn)

	_update_action_button_texts()


func _build_result_panel() -> void:
	_result_title = Label.new()
	_result_title.text = "RUN COMPLETE"
	_result_title.position = Vector2(0.0, 60.0)
	_result_title.size = Vector2(500.0, 40.0)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 28)
	_result_title.add_theme_color_override("font_color", COLOR_TITLE)
	_result_panel.add_child(_result_title)

	_result_summary = Label.new()
	_result_summary.position = Vector2(120.0, 130.0)
	_result_summary.size = Vector2(260.0, 150.0)
	_result_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_summary.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_result_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_summary.add_theme_font_size_override("font_size", 18)
	_result_summary.add_theme_color_override("font_color", COLOR_TEXT)
	_result_panel.add_child(_result_summary)

	var retry_btn: Button = _make_button("PLAY AGAIN", Vector2(150.0, 300.0), Vector2(200.0, 44.0), COLOR_BUTTON_PRIMARY)
	retry_btn.pressed.connect(func() -> void: restart_requested.emit())
	_result_panel.add_child(retry_btn)

	var menu_btn: Button = _make_button("MENU", Vector2(150.0, 354.0), Vector2(200.0, 44.0), COLOR_BUTTON_SECONDARY)
	menu_btn.pressed.connect(func() -> void: quit_to_menu_requested.emit())
	_result_panel.add_child(menu_btn)


func _build_tutorial_panel() -> void:
	var info: Label = Label.new()
	info.position = Vector2(40.0, 86.0)
	info.size = Vector2(680.0, 390.0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", COLOR_TEXT)
	info.text = "MOVE: WASD / ARROWS\nFIRE: SPACE / RMB\nDASH TO CURSOR: LMB\n\nCLEAR WAVES. PICK 1 OF 3 UPGRADES.\nBOSS EVERY 5TH ARENA.\n\nTAGS: VECTOR ORBIT PULSE FRACTAL\nENTROPY SUSTAIN CRIT SHIELD CHAOS\n\nESC = PAUSE"
	_tutorial_panel.add_child(info)

	var back_btn: Button = _make_button("BACK", Vector2(590.0, 500.0), Vector2(140.0, 42.0), COLOR_BUTTON_PRIMARY)
	back_btn.pressed.connect(func() -> void:
		if _tutorial_returns_to_pause:
			_show_only(_pause_panel)
		else:
			hide_all()
			tutorial_closed.emit()
	)
	_tutorial_panel.add_child(back_btn)


func _make_button(text: String, pos: Vector2, size: Vector2, base_color: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = size

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.border_color = Color(1.0, 1.0, 1.0, 0.30)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = base_color.lightened(0.12)

	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base_color.darkened(0.16)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	return btn


func _show_only(active: Control) -> void:
	_pause_panel.visible = _pause_panel == active
	_settings_panel.visible = _settings_panel == active
	_controls_panel.visible = _controls_panel == active
	_result_panel.visible = _result_panel == active
	_tutorial_panel.visible = _tutorial_panel == active


func _update_setting_values() -> void:
	_music_slider.value = _get_bus_linear_volume("Music")
	_sfx_slider.value = _get_bus_linear_volume("SFX")
	_telemetry_toggle.button_pressed = TelemetryService.is_overlay_enabled()
	_cloud_toggle.button_pressed = bool(SaveService.get_save("cloud_enabled", false))


func _get_bus_linear_volume(bus_name: String) -> float:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))


func _set_bus_linear_volume(bus_name: String, linear: float, save_key: String) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	var clamped: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(0.0001, clamped)))
	SaveService.set_save(save_key, clamped)


func _update_action_button_texts() -> void:
	for action: StringName in ACTIONS_TO_REBIND:
		if not _action_buttons.has(action):
			continue
		var btn: Button = _action_buttons[action]
		btn.text = _action_name_for_display(action)


func _action_name_for_display(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "UNBOUND"
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var key_ev: InputEventKey = ev as InputEventKey
			return OS.get_keycode_string(key_ev.keycode)
	return "UNBOUND"


func _apply_key_rebind(action: StringName, event: InputEventKey) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)

	var new_event: InputEventKey = InputEventKey.new()
	new_event.keycode = event.keycode
	InputMap.action_add_event(action, new_event)

	var bindings: Dictionary = SaveService.get_save("input_bindings", {})
	bindings[str(action)] = int(event.keycode)
	SaveService.set_save("input_bindings", bindings)
