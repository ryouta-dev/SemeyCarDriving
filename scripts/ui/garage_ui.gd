class_name GarageUI
extends CanvasLayer

signal tuning_changed(new_profile: Dictionary)
signal drive_requested
signal reset_requested
signal car_changed(car_id: String)

const MobileControlsClass = preload("res://scripts/ui/mobile_controls.gd")

var _profile: Dictionary = {}
var _current_tab: int = 0 # 0 = Paint, 1 = Stance, 2 = Engine

# Main UI elements
var _root: Control
var _top_bar: PanelContainer
var _bottom_bar: Control
var _side_panel: PanelContainer
var _tuning_open_btn: Button
var _status_label: Label

# Environment Chip Buttons
var _btn_day: Button
var _btn_night: Button
var _btn_clear: Button
var _btn_rain: Button

# Tab Content Panels
var _tab_container: Control
var _paint_panel: Control
var _stance_panel: Control
var _engine_panel: Control

# Stance Sliders & Labels
var _slider_f_height: HSlider
var _lbl_f_height: Label
var _slider_r_height: HSlider
var _lbl_r_height: Label
var _slider_f_camber: HSlider
var _lbl_f_camber: Label
var _slider_r_camber: HSlider
var _lbl_r_camber: Label
var _slider_f_offset: HSlider
var _lbl_f_offset: Label
var _slider_r_offset: HSlider
var _lbl_r_offset: Label
var _slider_stiff: HSlider
var _lbl_stiff: Label

# Tint Slider
var _slider_tint: HSlider
var _lbl_tint: Label

# Active HUD Editor preview instance (if opened in garage)
var _hud_editor_instance: MobileControls = null

func setup(initial_profile: Dictionary) -> void:
	_profile = initial_profile.duplicate(true)
	if not _profile.has("environment"):
		_profile["environment"] = {"time_of_day": "day", "weather": "clear"}
	_build_ui()
	_update_ui_values()
	_update_env_buttons()

func _build_ui() -> void:
	# Clear existing children if rebuilt
	for child in get_children():
		child.queue_free()

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# --- 1. TOP HEADER BAR ---
	_top_bar = PanelContainer.new()
	_top_bar.name = "TopBar"
	_top_bar.anchor_left = 0.0
	_top_bar.anchor_right = 1.0
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_bottom = 0.0
	_top_bar.offset_left = 24.0
	_top_bar.offset_top = 16.0
	_top_bar.offset_right = -24.0
	_top_bar.offset_bottom = 84.0
	_top_bar.mouse_filter = Control.MOUSE_FILTER_PASS

	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.06, 0.08, 0.12, 0.88)
	top_style.set_corner_radius_all(14)
	top_style.border_width_bottom = 2
	top_style.border_width_top = 1
	top_style.border_color = Color(0.25, 0.45, 0.8, 0.6)
	top_style.content_margin_left = 18.0
	top_style.content_margin_right = 18.0
	top_style.content_margin_top = 8.0
	top_style.content_margin_bottom = 8.0
	_top_bar.add_theme_stylebox_override("panel", top_style)
	_root.add_child(_top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_hbox.add_theme_constant_override("separation", 20)
	_top_bar.add_child(top_hbox)

	# Title & Subtitle
	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(title_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "🏁 SEMEY RACING • ШОУРУМ"
	title_lbl.add_theme_font_size_override("font_size", 21)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
	title_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "СЕМЕЙ • СВОБОДНАЯ ЕЗДА ПО ГОРОДУ"
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
	title_vbox.add_child(sub_lbl)

	# Environment selectors (Time of Day & Weather chips)
	var env_hbox := HBoxContainer.new()
	env_hbox.alignment = BoxContainer.ALIGNMENT_END
	env_hbox.add_theme_constant_override("separation", 10)
	top_hbox.add_child(env_hbox)

	# Time of Day Chips
	var tod_box := HBoxContainer.new()
	tod_box.add_theme_constant_override("separation", 4)
	env_hbox.add_child(tod_box)

	_btn_day = _create_chip_button("☀️ День")
	_btn_day.pressed.connect(func(): _set_time_of_day("day"))
	tod_box.add_child(_btn_day)

	_btn_night = _create_chip_button("🌙 Ночь")
	_btn_night.pressed.connect(func(): _set_time_of_day("night"))
	tod_box.add_child(_btn_night)

	# Separator line
	var sep := VSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	env_hbox.add_child(sep)

	# Weather Chips
	var w_box := HBoxContainer.new()
	w_box.add_theme_constant_override("separation", 4)
	env_hbox.add_child(w_box)

	_btn_clear = _create_chip_button("☀️ Ясно")
	_btn_clear.pressed.connect(func(): _set_weather("clear"))
	w_box.add_child(_btn_clear)

	_btn_rain = _create_chip_button("🌧️ Дождь")
	_btn_rain.pressed.connect(func(): _set_weather("rain"))
	w_box.add_child(_btn_rain)

	# Separator line 2
	var sep2 := VSeparator.new()
	sep2.add_theme_constant_override("separation", 10)
	env_hbox.add_child(sep2)

	# Car Selection Chips
	var car_box := HBoxContainer.new()
	car_box.add_theme_constant_override("separation", 4)
	env_hbox.add_child(car_box)

	var _btn_car_def = _create_chip_button("🚗 Default")
	_btn_car_def.pressed.connect(func(): car_changed.emit("simcade_car"))
	car_box.add_child(_btn_car_def)

	var _btn_car_lada = _create_chip_button("🚗 Lada 2110")
	_btn_car_lada.pressed.connect(func(): car_changed.emit("lada_vaz_2110"))
	car_box.add_child(_btn_car_lada)

	var _btn_car_priora = _create_chip_button("🚗 Priora")
	_btn_car_priora.pressed.connect(func(): car_changed.emit("priora"))
	car_box.add_child(_btn_car_priora)

	# --- 2. FLOATING TUNING DRAWER BUTTON (WHEN CLOSED) ---
	_tuning_open_btn = Button.new()
	_tuning_open_btn.name = "TuningOpenBtn"
	_tuning_open_btn.text = "🎨  ТЮНИНГ  ❯"
	_tuning_open_btn.anchor_left = 0.0
	_tuning_open_btn.anchor_top = 0.5
	_tuning_open_btn.anchor_bottom = 0.5
	_tuning_open_btn.offset_left = 24.0
	_tuning_open_btn.offset_top = -30.0
	_tuning_open_btn.offset_right = 210.0
	_tuning_open_btn.offset_bottom = 34.0
	_tuning_open_btn.add_theme_font_size_override("font_size", 16)
	
	var open_btn_style := StyleBoxFlat.new()
	open_btn_style.bg_color = Color(0.08, 0.12, 0.20, 0.88)
	open_btn_style.set_corner_radius_all(14)
	open_btn_style.border_width_left = 3
	open_btn_style.border_width_top = 1
	open_btn_style.border_width_right = 1
	open_btn_style.border_width_bottom = 1
	open_btn_style.border_color = Color(0.3, 0.6, 1.0, 0.9)
	_tuning_open_btn.add_theme_stylebox_override("normal", open_btn_style)
	_tuning_open_btn.pressed.connect(func(): _set_drawer_open(true))
	_root.add_child(_tuning_open_btn)

	# --- 3. COLLAPSIBLE TUNING DRAWER (LEFT SIDEBAR) ---
	_side_panel = PanelContainer.new()
	_side_panel.name = "TuningDrawer"
	_side_panel.anchor_left = 0.0
	_side_panel.anchor_right = 0.0
	_side_panel.anchor_top = 0.0
	_side_panel.anchor_bottom = 1.0
	_side_panel.offset_left = 24.0
	_side_panel.offset_top = 100.0
	_side_panel.offset_right = 440.0
	_side_panel.offset_bottom = -24.0
	_side_panel.visible = false # Starts collapsed for sleek showroom view!

	var side_style := StyleBoxFlat.new()
	side_style.bg_color = Color(0.05, 0.06, 0.09, 0.95)
	side_style.set_corner_radius_all(18)
	side_style.border_width_left = 2
	side_style.border_width_top = 1
	side_style.border_width_right = 1
	side_style.border_width_bottom = 2
	side_style.border_color = Color(0.25, 0.38, 0.6, 0.6)
	side_style.content_margin_left = 16.0
	side_style.content_margin_right = 16.0
	side_style.content_margin_top = 14.0
	side_style.content_margin_bottom = 14.0
	_side_panel.add_theme_stylebox_override("panel", side_style)
	_root.add_child(_side_panel)

	var side_vbox := VBoxContainer.new()
	side_vbox.add_theme_constant_override("separation", 12)
	_side_panel.add_child(side_vbox)

	# Drawer Header (Title + Close Button)
	var drawer_header := HBoxContainer.new()
	side_vbox.add_child(drawer_header)

	var drawer_title := Label.new()
	drawer_title.text = "🎨 ТЮНИНГ-АТЕЛЬЕ"
	drawer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_title.add_theme_font_size_override("font_size", 16)
	drawer_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	drawer_header.add_child(drawer_title)

	var close_drawer_btn := Button.new()
	close_drawer_btn.text = " ✕ ЗАКРЫТЬ "
	close_drawer_btn.custom_minimum_size = Vector2(90, 36)
	close_drawer_btn.add_theme_font_size_override("font_size", 12)
	close_drawer_btn.pressed.connect(func(): _set_drawer_open(false))
	drawer_header.add_child(close_drawer_btn)

	# Tabs Switcher
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 6)
	side_vbox.add_child(tabs_hbox)

	var tab_names := ["🎨 ПОКРАСКА", "🛠️ СТЕНС", "⚡ МОТОР"]
	for i in range(tab_names.size()):
		var t_btn := Button.new()
		t_btn.text = tab_names[i]
		t_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_btn.custom_minimum_size = Vector2(0, 42)
		t_btn.add_theme_font_size_override("font_size", 13)
		var idx := i
		t_btn.pressed.connect(func(): _select_tab(idx))
		tabs_hbox.add_child(t_btn)

	# Scroll Container for Tuning Sliders
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_vbox.add_child(scroll)

	_tab_container = VBoxContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tab_container)

	_build_paint_panel()
	_build_stance_panel()
	_build_engine_panel()

	_tab_container.add_child(_paint_panel)
	_tab_container.add_child(_stance_panel)
	_tab_container.add_child(_engine_panel)

	# Bottom Controls in Side Panel
	var drawer_bottom_hbox := HBoxContainer.new()
	drawer_bottom_hbox.add_theme_constant_override("separation", 8)
	side_vbox.add_child(drawer_bottom_hbox)

	_status_label = Label.new()
	_status_label.text = "✓ Сохранено"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
	drawer_bottom_hbox.add_child(_status_label)

	var reset_btn := Button.new()
	reset_btn.text = "↺ Сброс в сток"
	reset_btn.custom_minimum_size = Vector2(130, 38)
	reset_btn.add_theme_font_size_override("font_size", 13)
	reset_btn.pressed.connect(func(): reset_requested.emit())
	drawer_bottom_hbox.add_child(reset_btn)

	_select_tab(0)

	# --- 4. BOTTOM ACTION BAR ---
	_bottom_bar = Control.new()
	_bottom_bar.name = "BottomBar"
	_bottom_bar.anchor_left = 0.0
	_bottom_bar.anchor_right = 1.0
	_bottom_bar.anchor_top = 1.0
	_bottom_bar.anchor_bottom = 1.0
	_bottom_bar.offset_left = 24.0
	_bottom_bar.offset_top = -90.0
	_bottom_bar.offset_right = -24.0
	_bottom_bar.offset_bottom = -20.0
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom_bar)

	# Bottom Left: HUD Layout Editor Launcher
	var hud_config_btn := Button.new()
	hud_config_btn.name = "HudConfigBtn"
	hud_config_btn.text = "⚙️  РАСКЛАДКА КНОПОК"
	hud_config_btn.anchor_left = 0.0
	hud_config_btn.anchor_top = 0.0
	hud_config_btn.anchor_bottom = 1.0
	hud_config_btn.offset_right = 260.0
	hud_config_btn.add_theme_font_size_override("font_size", 15)

	var hud_btn_style := StyleBoxFlat.new()
	hud_btn_style.bg_color = Color(0.10, 0.13, 0.18, 0.92)
	hud_btn_style.set_corner_radius_all(14)
	hud_btn_style.border_width_left = 1
	hud_btn_style.border_width_top = 1
	hud_btn_style.border_width_right = 1
	hud_btn_style.border_width_bottom = 1
	hud_btn_style.border_color = Color(0.35, 0.5, 0.7, 0.7)
	hud_config_btn.add_theme_stylebox_override("normal", hud_btn_style)
	hud_config_btn.pressed.connect(_launch_hud_editor)
	_bottom_bar.add_child(hud_config_btn)

	# Bottom Center: Orbit Hint
	var hint_panel := PanelContainer.new()
	hint_panel.anchor_left = 0.5
	hint_panel.anchor_top = 0.5
	hint_panel.anchor_right = 0.5
	hint_panel.anchor_bottom = 0.5
	hint_panel.offset_left = -160.0
	hint_panel.offset_top = -18.0
	hint_panel.offset_right = 160.0
	hint_panel.offset_bottom = 18.0
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	hint_style.set_corner_radius_all(12)
	hint_panel.add_theme_stylebox_override("panel", hint_style)
	_bottom_bar.add_child(hint_panel)

	var hint_lbl := Label.new()
	hint_lbl.text = "🖐 Свайпайте по экрану для обзора"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92, 0.8))
	hint_panel.add_child(hint_lbl)

	# Bottom Right: Giant "В ГОРОД ▶" CTA
	var drive_btn := Button.new()
	drive_btn.name = "DriveBtn"
	drive_btn.text = "В ГОРОД ▶"
	drive_btn.anchor_left = 1.0
	drive_btn.anchor_top = 0.0
	drive_btn.anchor_right = 1.0
	drive_btn.anchor_bottom = 1.0
	drive_btn.offset_left = -270.0
	drive_btn.offset_right = 0.0
	drive_btn.add_theme_font_size_override("font_size", 21)

	var drive_style := StyleBoxFlat.new()
	drive_style.bg_color = Color(0.10, 0.76, 0.36, 0.96)
	drive_style.set_corner_radius_all(16)
	drive_style.border_width_left = 2
	drive_style.border_width_top = 2
	drive_style.border_width_right = 2
	drive_style.border_width_bottom = 2
	drive_style.border_color = Color(0.45, 1.0, 0.6)
	drive_style.shadow_color = Color(0.1, 0.8, 0.35, 0.3)
	drive_style.shadow_size = 12
	drive_btn.add_theme_stylebox_override("normal", drive_style)
	drive_btn.pressed.connect(func(): drive_requested.emit())
	_bottom_bar.add_child(drive_btn)

func _set_drawer_open(is_open: bool) -> void:
	_side_panel.visible = is_open
	_tuning_open_btn.visible = not is_open

func _create_chip_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(92, 38)
	btn.add_theme_font_size_override("font_size", 13)
	return btn

func _set_chip_active(btn: Button, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(10)
	if active:
		s.bg_color = Color(0.18, 0.42, 0.85, 0.95)
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 2
		s.border_color = Color(0.5, 0.8, 1.0)
	else:
		s.bg_color = Color(0.10, 0.12, 0.16, 0.75)
		s.border_width_left = 1
		s.border_width_top = 1
		s.border_width_right = 1
		s.border_width_bottom = 1
		s.border_color = Color(0.25, 0.3, 0.4, 0.5)
	btn.add_theme_stylebox_override("normal", s)

func _update_env_buttons() -> void:
	var env: Dictionary = _profile.get("environment", {})
	var tod: String = env.get("time_of_day", "day")
	var w: String = env.get("weather", "clear")

	if is_instance_valid(_btn_day):
		_set_chip_active(_btn_day, tod == "day")
	if is_instance_valid(_btn_night):
		_set_chip_active(_btn_night, tod == "night")
	if is_instance_valid(_btn_clear):
		_set_chip_active(_btn_clear, w == "clear")
	if is_instance_valid(_btn_rain):
		_set_chip_active(_btn_rain, w == "rain")

func _set_time_of_day(tod: String) -> void:
	if not _profile.has("environment"):
		_profile["environment"] = {}
	_profile["environment"]["time_of_day"] = tod
	_update_env_buttons()
	_emit_tuning()

func _set_weather(w: String) -> void:
	if not _profile.has("environment"):
		_profile["environment"] = {}
	_profile["environment"]["weather"] = w
	_update_env_buttons()
	_emit_tuning()

# --- HUD LAYOUT EDITOR IN GARAGE ---
func _launch_hud_editor() -> void:
	if is_instance_valid(_hud_editor_instance):
		return
	
	# Hide garage UI panels while customizing HUD
	_top_bar.visible = false
	_bottom_bar.visible = false
	_side_panel.visible = false
	_tuning_open_btn.visible = false

	_hud_editor_instance = MobileControlsClass.new()
	add_child(_hud_editor_instance)
	_hud_editor_instance.enter_hud_editor()
	_hud_editor_instance.hud_editor_closed.connect(_on_hud_editor_closed)

func _on_hud_editor_closed() -> void:
	if is_instance_valid(_hud_editor_instance):
		_hud_editor_instance.queue_free()
		_hud_editor_instance = null

	# Restore garage UI
	_top_bar.visible = true
	_bottom_bar.visible = true
	_tuning_open_btn.visible = not _side_panel.visible

# --- PANEL 1: PAINT & FINISH ---
func _build_paint_panel() -> void:
	_paint_panel = VBoxContainer.new()
	_paint_panel.name = "PaintPanel"
	_paint_panel.add_theme_constant_override("separation", 14)

	# Body Color Label
	var l1 := Label.new()
	l1.text = "ЦВЕТ КУЗОВА"
	l1.add_theme_font_size_override("font_size", 14)
	l1.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_paint_panel.add_child(l1)

	var colors := [
		{"name": "Ruby Red", "c": Color(0.85, 0.12, 0.12)},
		{"name": "Nardo Grey", "c": Color(0.45, 0.48, 0.52)},
		{"name": "Obsidian Black", "c": Color(0.06, 0.06, 0.07)},
		{"name": "Pearl White", "c": Color(0.95, 0.95, 0.98)},
		{"name": "San Marino Blue", "c": Color(0.08, 0.32, 0.88)},
		{"name": "Sunset Gold", "c": Color(0.94, 0.72, 0.15)},
		{"name": "Emerald Green", "c": Color(0.06, 0.48, 0.22)},
		{"name": "Cyber Purple", "c": Color(0.52, 0.12, 0.82)}
	]

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_paint_panel.add_child(grid)

	for c_data in colors:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(78, 42)
		var style := StyleBoxFlat.new()
		style.bg_color = c_data["c"]
		style.set_corner_radius_all(8)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(1.0, 1.0, 1.0, 0.4)
		btn.add_theme_stylebox_override("normal", style)
		var col: Color = c_data["c"]
		btn.pressed.connect(func(): _set_paint_color(col))
		grid.add_child(btn)

	# Finish Selector
	var l_finish := Label.new()
	l_finish.text = "ТИП ЛАКА (ФИНИШ)"
	l_finish.add_theme_font_size_override("font_size", 14)
	l_finish.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_paint_panel.add_child(l_finish)

	var f_hbox := HBoxContainer.new()
	f_hbox.add_theme_constant_override("separation", 6)
	_paint_panel.add_child(f_hbox)

	var finishes := [["Глянец", "gloss"], ["Металлик", "metallic"], ["Матовый", "matte"]]
	for f_item in finishes:
		var btn := Button.new()
		btn.text = f_item[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 40)
		var f_val: String = f_item[1]
		btn.pressed.connect(func(): _set_paint_finish(f_val))
		f_hbox.add_child(btn)

	# Window Tint
	var l_tint := Label.new()
	l_tint.text = "ТОНИРОВКА СТЕКОЛ"
	l_tint.add_theme_font_size_override("font_size", 14)
	l_tint.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_paint_panel.add_child(l_tint)

	_lbl_tint = Label.new()
	_lbl_tint.text = "Затемнение: 50%"
	_lbl_tint.add_theme_font_size_override("font_size", 13)
	_lbl_tint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	_paint_panel.add_child(_lbl_tint)

	_slider_tint = HSlider.new()
	_slider_tint.min_value = 0.0
	_slider_tint.max_value = 0.95
	_slider_tint.step = 0.05
	_slider_tint.value = 0.5
	_slider_tint.value_changed.connect(_on_tint_slider_changed)
	_paint_panel.add_child(_slider_tint)

	var tint_preset_box := HBoxContainer.new()
	tint_preset_box.add_theme_constant_override("separation", 6)
	_paint_panel.add_child(tint_preset_box)
	var tint_presets := [["Сток (0%)", 0.0], ["Евро (50%)", 0.5], ["В бункер (95%)", 0.95]]
	for tp in tint_presets:
		var btn := Button.new()
		btn.text = tp[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val: float = tp[1]
		btn.pressed.connect(func():
			_slider_tint.value = val
			_on_tint_slider_changed(val)
		)
		tint_preset_box.add_child(btn)

	# Rim Color
	var l_rim := Label.new()
	l_rim.text = "ЦВЕТ ДИСКОВ"
	l_rim.add_theme_font_size_override("font_size", 14)
	l_rim.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_paint_panel.add_child(l_rim)

	var rim_colors := [
		{"name": "Silver", "c": Color(0.88, 0.88, 0.90)},
		{"name": "Gloss Black", "c": Color(0.08, 0.08, 0.09)},
		{"name": "Bronze", "c": Color(0.65, 0.45, 0.22)},
		{"name": "Gold", "c": Color(0.85, 0.70, 0.20)},
		{"name": "Chrome", "c": Color(0.98, 0.98, 1.0)},
		{"name": "White", "c": Color(0.95, 0.95, 0.95)}
	]
	var rim_grid := GridContainer.new()
	rim_grid.columns = 3
	rim_grid.add_theme_constant_override("h_separation", 8)
	rim_grid.add_theme_constant_override("v_separation", 8)
	_paint_panel.add_child(rim_grid)
	for rc in rim_colors:
		var btn := Button.new()
		btn.text = rc["name"]
		btn.custom_minimum_size = Vector2(105, 38)
		var col: Color = rc["c"]
		btn.pressed.connect(func(): _set_rim_color(col))
		rim_grid.add_child(btn)

# --- PANEL 2: STANCE ---
func _build_stance_panel() -> void:
	_stance_panel = VBoxContainer.new()
	_stance_panel.name = "StancePanel"
	_stance_panel.add_theme_constant_override("separation", 12)

	# Front Height
	_lbl_f_height = Label.new()
	_stance_panel.add_child(_lbl_f_height)
	_slider_f_height = _create_slider(0.08, 0.24, 0.01, 0.15, func(v):
		_profile["stance"]["front_spring_length"] = v
		_update_labels()
		_emit_tuning()
	)
	_stance_panel.add_child(_slider_f_height)

	# Rear Height
	_lbl_r_height = Label.new()
	_stance_panel.add_child(_lbl_r_height)
	_slider_r_height = _create_slider(0.10, 0.28, 0.01, 0.20, func(v):
		_profile["stance"]["rear_spring_length"] = v
		_update_labels()
		_emit_tuning()
	)
	_stance_panel.add_child(_slider_r_height)

	# Front Camber
	_lbl_f_camber = Label.new()
	_stance_panel.add_child(_lbl_f_camber)
	_slider_f_camber = _create_slider(0.0, -8.0, -0.5, 0.0, func(v):
		_profile["stance"]["front_camber"] = v
		_update_labels()
		_emit_tuning()
	)
	_stance_panel.add_child(_slider_f_camber)

	# Rear Camber
	_lbl_r_camber = Label.new()
	_stance_panel.add_child(_lbl_r_camber)
	_slider_r_camber = _create_slider(0.0, -8.0, -0.5, 0.0, func(v):
		_profile["stance"]["rear_camber"] = v
		_update_labels()
		_emit_tuning()
	)
	_stance_panel.add_child(_slider_r_camber)

	# Front Offset
	_lbl_f_offset = Label.new()
	_stance_panel.add_child(_lbl_f_offset)
	_slider_f_offset = _create_slider(0.0, 0.07, 0.005, 0.0, func(v):
		_profile["stance"]["front_offset"] = v
		_update_labels()
		_emit_tuning()
	)
	_stance_panel.add_child(_slider_f_offset)

	# Rear Offset
	_lbl_r_offset = Label.new()
	_stance_panel.add_child(_lbl_r_offset)
	_slider_r_offset = _create_slider(0.0, 0.07, 0.005, 0.0, func(v):
		_profile["stance"]["rear_offset"] = v
		_update_labels()
		_emit_tuning()
	)
	_stance_panel.add_child(_slider_r_offset)

	# Stiffness
	_lbl_stiff = Label.new()
	_stance_panel.add_child(_lbl_stiff)
	_slider_stiff = _create_slider(0.6, 2.2, 0.1, 1.0, func(v):
		_profile["stance"]["stiffness"] = v
		_update_labels()
		_emit_tuning()
	)
	_stance_panel.add_child(_slider_stiff)

# --- PANEL 3: ENGINE & DRIVETRAIN ---
func _build_engine_panel() -> void:
	_engine_panel = VBoxContainer.new()
	_engine_panel.name = "EnginePanel"
	_engine_panel.add_theme_constant_override("separation", 14)

	var l_swap := Label.new()
	l_swap.text = "СВАП ДВИГАТЕЛЯ (ENGINE SWAP)"
	l_swap.add_theme_font_size_override("font_size", 14)
	l_swap.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_engine_panel.add_child(l_swap)

	var engine_list := [
		{"id": "stock_25", "name": "2.5L I4 Stock", "stats": "203 hp • 250 Nm • 6500 RPM"},
		{"id": "v6_35", "name": "3.5L V6 VVT-i", "stats": "301 hp • 370 Nm • 6800 RPM"},
		{"id": "jz_turbo", "name": "3.0L 2JZ Turbo", "stats": "580 hp • 620 Nm • 7800 RPM (Дрифт)"},
		{"id": "v8_beast", "name": "6.2L V8 Supercharged", "stats": "750 hp • 850 Nm • 7200 RPM"}
	]

	for eng in engine_list:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 54)
		btn.text = "%s\n%s" % [eng["name"], eng["stats"]]
		btn.add_theme_font_size_override("font_size", 13)
		var eid: String = eng["id"]
		btn.pressed.connect(func(): _set_engine_id(eid))
		_engine_panel.add_child(btn)

	# Drivetrain
	var l_dt := Label.new()
	l_dt.text = "ПРИВОД (DRIVETRAIN)"
	l_dt.add_theme_font_size_override("font_size", 14)
	l_dt.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_engine_panel.add_child(l_dt)

	var dt_hbox := HBoxContainer.new()
	dt_hbox.add_theme_constant_override("separation", 8)
	_engine_panel.add_child(dt_hbox)

	var rwd_btn := Button.new()
	rwd_btn.text = "RWD (Задний - Дрифт)"
	rwd_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rwd_btn.custom_minimum_size = Vector2(0, 44)
	rwd_btn.pressed.connect(func(): _set_drivetrain("rwd"))
	dt_hbox.add_child(rwd_btn)

	var awd_btn := Button.new()
	awd_btn.text = "AWD (Полный - Зацеп)"
	awd_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	awd_btn.custom_minimum_size = Vector2(0, 44)
	awd_btn.pressed.connect(func(): _set_drivetrain("awd"))
	dt_hbox.add_child(awd_btn)

	# Final Drive
	var l_fd := Label.new()
	l_fd.text = "ГЛАВНАЯ ПАРА (FINAL DRIVE)"
	l_fd.add_theme_font_size_override("font_size", 14)
	l_fd.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_engine_panel.add_child(l_fd)

	var fd_hbox := HBoxContainer.new()
	fd_hbox.add_theme_constant_override("separation", 8)
	_engine_panel.add_child(fd_hbox)

	var fd_list := [["Короткая (3.90)", 3.90], ["Баланс (3.45)", 3.45], ["Длинная (2.90)", 2.90]]
	for fd in fd_list:
		var btn := Button.new()
		btn.text = fd[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 42)
		var val: float = fd[1]
		btn.pressed.connect(func(): _set_final_drive(val))
		fd_hbox.add_child(btn)

func _create_slider(min_v: float, max_v: float, step: float, default_v: float, callback: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = default_v
	s.value_changed.connect(callback)
	return s

func _select_tab(index: int) -> void:
	_current_tab = index
	_paint_panel.visible = (index == 0)
	_stance_panel.visible = (index == 1)
	_engine_panel.visible = (index == 2)

func _set_paint_color(c: Color) -> void:
	_profile["paint"]["color"] = [c.r, c.g, c.b, c.a]
	_emit_tuning()

func _set_paint_finish(finish: String) -> void:
	_profile["paint"]["finish"] = finish
	_emit_tuning()

func _on_tint_slider_changed(val: float) -> void:
	_profile["paint"]["tint_alpha"] = val
	_lbl_tint.text = "Затемнение: %d%%" % int(val * 100)
	_emit_tuning()

func _set_rim_color(c: Color) -> void:
	_profile["paint"]["rim_color"] = [c.r, c.g, c.b, c.a]
	_emit_tuning()

func _set_engine_id(id: String) -> void:
	_profile["engine"]["engine_id"] = id
	_emit_tuning()

func _set_drivetrain(dt: String) -> void:
	_profile["engine"]["drivetrain"] = dt
	_emit_tuning()

func _set_final_drive(fd: float) -> void:
	_profile["engine"]["final_drive"] = fd
	_emit_tuning()

func _update_labels() -> void:
	var s: Dictionary = _profile.get("stance", {})
	_lbl_f_height.text = "Клиренс передней оси: %.2f м" % s.get("front_spring_length", 0.15)
	_lbl_r_height.text = "Клиренс задней оси: %.2f м" % s.get("rear_spring_length", 0.20)
	_lbl_f_camber.text = "Развал передних колес: %.1f°" % s.get("front_camber", 0.0)
	_lbl_r_camber.text = "Развал задних колес: %.1f°" % s.get("rear_camber", 0.0)
	_lbl_f_offset.text = "Вылет передней оси: +%.1f см" % (s.get("front_offset", 0.0) * 100.0)
	_lbl_r_offset.text = "Вылет задней оси: +%.1f см" % (s.get("rear_offset", 0.0) * 100.0)
	_lbl_stiff.text = "Жесткость подвески: %.1fx" % s.get("stiffness", 1.0)

func _update_ui_values() -> void:
	var stance: Dictionary = _profile.get("stance", {})
	_slider_f_height.value = stance.get("front_spring_length", 0.15)
	_slider_r_height.value = stance.get("rear_spring_length", 0.20)
	_slider_f_camber.value = stance.get("front_camber", 0.0)
	_slider_r_camber.value = stance.get("rear_camber", 0.0)
	_slider_f_offset.value = stance.get("front_offset", 0.0)
	_slider_r_offset.value = stance.get("rear_offset", 0.0)
	_slider_stiff.value = stance.get("stiffness", 1.0)

	var paint: Dictionary = _profile.get("paint", {})
	_slider_tint.value = paint.get("tint_alpha", 0.5)
	_lbl_tint.text = "Затемнение: %d%%" % int(_slider_tint.value * 100)

	_update_labels()

func _emit_tuning() -> void:
	tuning_changed.emit(_profile)
	if is_instance_valid(_status_label):
		_status_label.text = "✓ Сохранено"
