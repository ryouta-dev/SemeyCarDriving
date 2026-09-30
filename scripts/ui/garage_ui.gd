class_name GarageUI
extends CanvasLayer

signal tuning_changed(new_profile: Dictionary)
signal drive_requested
signal reset_requested

var _profile: Dictionary = {}
var _current_tab: int = 0 # 0 = Paint, 1 = Stance, 2 = Engine

var _tab_container: Control
var _paint_panel: Control
var _stance_panel: Control
var _engine_panel: Control

var _status_label: Label

# Cached Sliders & Labels for Stance
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

# Cached Tint Slider
var _slider_tint: HSlider
var _lbl_tint: Label

func setup(initial_profile: Dictionary) -> void:
	_profile = initial_profile.duplicate(true)
	_build_ui()
	_update_ui_values()

func _build_ui() -> void:
	# Clear existing children if rebuilt
	for child in get_children():
		child.queue_free()

	# Root Control Container
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- 1. TOP HEADER BAR ---
	var top_bar := PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 20.0
	top_bar.offset_top = 16.0
	top_bar.offset_right = -20.0
	top_bar.offset_bottom = 80.0
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.08, 0.10, 0.14, 0.88)
	top_style.set_corner_radius_all(14)
	top_style.border_width_bottom = 2
	top_style.border_color = Color(0.2, 0.4, 0.8, 0.6)
	top_bar.add_theme_stylebox_override("panel", top_style)
	root.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_hbox.add_theme_constant_override("separation", 16)
	top_bar.add_child(top_hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(title_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "🏁 SEMEY CUSTOMS • ГАРАЖ"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	title_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "ТЮНИНГ-АТЕЛЬЕ • ВЫБЕРИТЕ ПАРАМЕТРЫ АВТОМОБИЛЯ"
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	title_vbox.add_child(sub_lbl)

	# DRIVE BUTTON
	var drive_btn := Button.new()
	drive_btn.text = "  ВЫЕХАТЬ В ГОРОД ▶  "
	drive_btn.custom_minimum_size = Vector2(240, 52)
	drive_btn.add_theme_font_size_override("font_size", 18)
	var drive_style := StyleBoxFlat.new()
	drive_style.bg_color = Color(0.12, 0.72, 0.32, 0.95)
	drive_style.set_corner_radius_all(12)
	drive_style.border_width_left = 2
	drive_style.border_width_right = 2
	drive_style.border_width_top = 2
	drive_style.border_width_bottom = 2
	drive_style.border_color = Color(0.4, 0.95, 0.5)
	drive_btn.add_theme_stylebox_override("normal", drive_style)
	drive_btn.pressed.connect(func(): drive_requested.emit())
	top_hbox.add_child(drive_btn)

	# --- 2. LEFT TUNING SIDEBAR / TAB BAR ---
	var side_panel := PanelContainer.new()
	side_panel.name = "SidePanel"
	side_panel.anchor_left = 0.0
	side_panel.anchor_right = 0.0
	side_panel.anchor_top = 0.0
	side_panel.anchor_bottom = 1.0
	side_panel.offset_left = 20.0
	side_panel.offset_top = 96.0
	side_panel.offset_right = 430.0
	side_panel.offset_bottom = -20.0
	var side_style := StyleBoxFlat.new()
	side_style.bg_color = Color(0.06, 0.07, 0.10, 0.92)
	side_style.set_corner_radius_all(16)
	side_style.border_width_left = 1
	side_style.border_width_top = 1
	side_style.border_width_right = 1
	side_style.border_width_bottom = 1
	side_style.border_color = Color(0.25, 0.3, 0.45, 0.5)
	side_panel.add_theme_stylebox_override("panel", side_style)
	root.add_child(side_panel)

	var side_vbox := VBoxContainer.new()
	side_vbox.add_theme_constant_override("separation", 12)
	side_panel.add_child(side_vbox)

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
		t_btn.add_theme_font_size_override("font_size", 14)
		var idx := i
		t_btn.pressed.connect(func(): _select_tab(idx))
		tabs_hbox.add_child(t_btn)

	# Scroll Container for Content
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
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 8)
	side_vbox.add_child(bottom_hbox)

	_status_label = Label.new()
	_status_label.text = "✓ Сохранено"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
	bottom_hbox.add_child(_status_label)

	var reset_btn := Button.new()
	reset_btn.text = "↺ Сброс в сток"
	reset_btn.custom_minimum_size = Vector2(130, 38)
	reset_btn.add_theme_font_size_override("font_size", 13)
	reset_btn.pressed.connect(func(): reset_requested.emit())
	bottom_hbox.add_child(reset_btn)

	_select_tab(0)

# --- PANEL 1: PAINT & FINISH ---
func _build_paint_panel() -> void:
	_paint_panel = VBoxContainer.new()
	_paint_panel.name = "PaintPanel"
	_paint_panel.add_theme_constant_override("separation", 14)

	# Body Color Label
	var l1 := Label.new()
	l1.text = "ЦВЕТ КУЗОВА"
	l1.add_theme_font_size_override("font_size", 15)
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
		btn.custom_minimum_size = Vector2(80, 44)
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
	l_finish.add_theme_font_size_override("font_size", 15)
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
	l_tint.add_theme_font_size_override("font_size", 15)
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
	l_rim.add_theme_font_size_override("font_size", 15)
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
		btn.custom_minimum_size = Vector2(110, 38)
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
	l_swap.add_theme_font_size_override("font_size", 15)
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
		btn.custom_minimum_size = Vector2(0, 56)
		btn.text = "%s\n%s" % [eng["name"], eng["stats"]]
		btn.add_theme_font_size_override("font_size", 13)
		var eid: String = eng["id"]
		btn.pressed.connect(func(): _set_engine_id(eid))
		_engine_panel.add_child(btn)

	# Drivetrain
	var l_dt := Label.new()
	l_dt.text = "ПРИВОД (DRIVETRAIN)"
	l_dt.add_theme_font_size_override("font_size", 15)
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
	l_fd.add_theme_font_size_override("font_size", 15)
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
	_status_label.text = "✓ Сохранено"
