extends CanvasLayer
class_name MobileControls

signal shift_up_requested
signal shift_down_requested
signal toggle_transmission_requested
signal day_night_toggle_requested
signal weather_toggle_requested
signal garage_requested
signal look_dragged(relative: Vector2)
signal look_ended
signal hud_editor_closed

enum SteeringMode {
	ARROWS,
	WHEEL
}

@export var camera: ProVehicleCamera
@export var current_steering_mode: SteeringMode = SteeringMode.ARROWS:
	set(val):
		current_steering_mode = val
		_update_visibility()

# UI References
var root_control: Control
var look_area: Control
var steer_container: Control
var arrow_left: TouchButton
var arrow_right: TouchButton
var steering_wheel: VirtualSteeringWheel
var mode_button: TouchButton

var pedals_container: Control
var gas_pedal: TouchButton
var brake_pedal: TouchButton
var handbrake_btn: TouchButton
var shift_up_btn: TouchButton
var shift_down_btn: TouchButton
var trans_mode_btn: TouchButton

var top_bar: Control
var garage_btn: TouchButton
var weather_btn: TouchButton
var sky_btn: TouchButton
var hud_edit_btn: TouchButton

# HUD Layout Editor UI
var is_editing_hud: bool = false
var hud_editor_panel: PanelContainer
var editor_scale_label: Label
var current_scale: float = 1.0

# Drag tracking in editor
var _dragging_target: String = "" # "steer", "pedals", or ""
var _drag_start_pos: Vector2 = Vector2.ZERO
var _steer_offset: Vector2 = Vector2(50, -50)
var _pedals_offset: Vector2 = Vector2(-50, -50)

# Touch look tracking
var active_look_index: int = -1
var is_looking: bool = false

func _ready() -> void:
	layer = 10
	_load_saved_hud_config()
	_build_ui()
	_update_visibility()

func _load_saved_hud_config() -> void:
	var prof := ProfileManager.load_profile()
	var hud_cfg: Dictionary = prof.get("hud", {})
	current_scale = clampf(hud_cfg.get("button_scale", 1.0), 0.7, 1.5)
	
	var mode_str: String = hud_cfg.get("steer_mode", "arrows")
	current_steering_mode = SteeringMode.WHEEL if mode_str == "wheel" else SteeringMode.ARROWS
	
	_steer_offset = Vector2(
		hud_cfg.get("steer_pos_x", 50.0),
		hud_cfg.get("steer_pos_y", -50.0)
	)
	_pedals_offset = Vector2(
		hud_cfg.get("pedals_pos_x", -50.0),
		hud_cfg.get("pedals_pos_y", -50.0)
	)

func _save_hud_config() -> void:
	var prof := ProfileManager.load_profile()
	if not prof.has("hud"):
		prof["hud"] = {}
	prof["hud"]["button_scale"] = current_scale
	prof["hud"]["steer_mode"] = "wheel" if current_steering_mode == SteeringMode.WHEEL else "arrows"
	prof["hud"]["steer_pos_x"] = _steer_offset.x
	prof["hud"]["steer_pos_y"] = _steer_offset.y
	prof["hud"]["pedals_pos_x"] = _pedals_offset.x
	prof["hud"]["pedals_pos_y"] = _pedals_offset.y
	ProfileManager.save_profile(prof)

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	# Root fullscreen control container
	root_control = Control.new()
	root_control.name = "RootControls"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	
	# === 0. TOUCH LOOK AREA (Screen swipe to look around) ===
	look_area = Control.new()
	look_area.name = "TouchLookArea"
	look_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	look_area.mouse_filter = Control.MOUSE_FILTER_PASS
	look_area.gui_input.connect(_on_look_area_gui_input)
	root_control.add_child(look_area)

	var s := current_scale

	# === 1. LEFT SIDE: STEERING CLUSTER ===
	steer_container = Control.new()
	steer_container.name = "SteerCluster"
	steer_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	steer_container.anchor_left = 0.0
	steer_container.anchor_top = 1.0
	steer_container.anchor_right = 0.0
	steer_container.anchor_bottom = 1.0
	
	var steer_w := 380.0 * s
	var steer_h := 280.0 * s
	steer_container.offset_left = _steer_offset.x
	steer_container.offset_top = _steer_offset.y - steer_h
	steer_container.offset_right = _steer_offset.x + steer_w
	steer_container.offset_bottom = _steer_offset.y
	steer_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(steer_container)
	
	# Arrow Left (Large, ergonomic)
	arrow_left = TouchButton.new()
	arrow_left.name = "ArrowLeft"
	arrow_left.icon_type = "arrow_left"
	arrow_left.position = Vector2(0, 45) * s
	arrow_left.size = Vector2(170, 170) * s
	arrow_left.corner_radius = 28.0 * s
	arrow_left.border_width = 3.5 * s
	arrow_left.base_color = Color(0.10, 0.14, 0.22, 0.72)
	arrow_left.pressed_color = Color(0.18, 0.52, 0.95, 0.9)
	arrow_left.border_color = Color(0.35, 0.65, 1.0, 0.8)
	steer_container.add_child(arrow_left)
	
	# Arrow Right
	arrow_right = TouchButton.new()
	arrow_right.name = "ArrowRight"
	arrow_right.icon_type = "arrow_right"
	arrow_right.position = Vector2(195, 45) * s
	arrow_right.size = Vector2(170, 170) * s
	arrow_right.corner_radius = 28.0 * s
	arrow_right.border_width = 3.5 * s
	arrow_right.base_color = Color(0.10, 0.14, 0.22, 0.72)
	arrow_right.pressed_color = Color(0.18, 0.52, 0.95, 0.9)
	arrow_right.border_color = Color(0.35, 0.65, 1.0, 0.8)
	steer_container.add_child(arrow_right)
	
	# Virtual Steering Wheel (Enlarged ~310x310)
	steering_wheel = VirtualSteeringWheel.new()
	steering_wheel.name = "VirtualSteeringWheel"
	steering_wheel.position = Vector2(25, -20) * s
	steering_wheel.size = Vector2(310, 310) * s
	steer_container.add_child(steering_wheel)
	
	# Steering Mode Toggle
	mode_button = TouchButton.new()
	mode_button.name = "ModeToggle"
	mode_button.text = "РУЛЬ"
	mode_button.font_size = int(16 * s)
	mode_button.position = Vector2(115, 225) * s
	mode_button.size = Vector2(135, 46) * s
	mode_button.corner_radius = 14.0 * s
	mode_button.base_color = Color(0.14, 0.18, 0.26, 0.85)
	mode_button.border_color = Color(0.45, 0.65, 0.95, 0.75)
	mode_button.button_down.connect(_toggle_steering_mode)
	steer_container.add_child(mode_button)
	
	# === 2. RIGHT SIDE: PEDALS & TRANSMISSION CLUSTER ===
	pedals_container = Control.new()
	pedals_container.name = "PedalsCluster"
	pedals_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pedals_container.anchor_left = 1.0
	pedals_container.anchor_top = 1.0
	pedals_container.anchor_right = 1.0
	pedals_container.anchor_bottom = 1.0
	
	var pedals_w := 420.0 * s
	var pedals_h := 320.0 * s
	pedals_container.offset_left = _pedals_offset.x - pedals_w
	pedals_container.offset_top = _pedals_offset.y - pedals_h
	pedals_container.offset_right = _pedals_offset.x
	pedals_container.offset_bottom = _pedals_offset.y
	pedals_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(pedals_container)
	
	# Brake Pedal (Wide & responsive)
	brake_pedal = TouchButton.new()
	brake_pedal.name = "BrakePedal"
	brake_pedal.icon_type = "pedal_brake"
	brake_pedal.text = "ТОРМОЗ"
	brake_pedal.font_size = int(18 * s)
	brake_pedal.position = Vector2(65, 85) * s
	brake_pedal.size = Vector2(140, 205) * s
	brake_pedal.corner_radius = 22.0 * s
	brake_pedal.border_width = 3.5 * s
	brake_pedal.base_color = Color(0.24, 0.10, 0.12, 0.75)
	brake_pedal.pressed_color = Color(0.95, 0.22, 0.28, 0.92)
	brake_pedal.border_color = Color(0.9, 0.35, 0.4, 0.8)
	pedals_container.add_child(brake_pedal)
	
	# Gas Pedal (Tall & comfortable for thumb)
	gas_pedal = TouchButton.new()
	gas_pedal.name = "GasPedal"
	gas_pedal.icon_type = "pedal_gas"
	gas_pedal.text = "ГАЗ"
	gas_pedal.font_size = int(20 * s)
	gas_pedal.position = Vector2(230, 50) * s
	gas_pedal.size = Vector2(145, 245) * s
	gas_pedal.corner_radius = 24.0 * s
	gas_pedal.border_width = 3.5 * s
	gas_pedal.base_color = Color(0.10, 0.24, 0.15, 0.75)
	gas_pedal.pressed_color = Color(0.20, 0.90, 0.42, 0.92)
	gas_pedal.border_color = Color(0.35, 0.95, 0.55, 0.8)
	pedals_container.add_child(gas_pedal)
	
	# Handbrake Button (Drift button)
	handbrake_btn = TouchButton.new()
	handbrake_btn.name = "Handbrake"
	handbrake_btn.text = "РУЧНИК"
	handbrake_btn.font_size = int(16 * s)
	handbrake_btn.position = Vector2(-45, 160) * s
	handbrake_btn.size = Vector2(95, 105) * s
	handbrake_btn.corner_radius = 20.0 * s
	handbrake_btn.border_width = 3.0 * s
	handbrake_btn.base_color = Color(0.28, 0.18, 0.08, 0.78)
	handbrake_btn.pressed_color = Color(1.0, 0.65, 0.12, 0.95)
	handbrake_btn.border_color = Color(1.0, 0.75, 0.25, 0.85)
	pedals_container.add_child(handbrake_btn)
	
	# Trans Mode Toggle (AUTO / MAN)
	trans_mode_btn = TouchButton.new()
	trans_mode_btn.name = "TransMode"
	trans_mode_btn.text = "АКПП"
	trans_mode_btn.font_size = int(16 * s)
	trans_mode_btn.position = Vector2(-45, 85) * s
	trans_mode_btn.size = Vector2(95, 60) * s
	trans_mode_btn.corner_radius = 14.0 * s
	trans_mode_btn.base_color = Color(0.12, 0.25, 0.2, 0.82)
	trans_mode_btn.border_color = Color(0.3, 0.9, 0.5, 0.75)
	trans_mode_btn.button_down.connect(func(): toggle_transmission_requested.emit())
	pedals_container.add_child(trans_mode_btn)
	
	# Shift Down (-)
	shift_down_btn = TouchButton.new()
	shift_down_btn.name = "ShiftDown"
	shift_down_btn.text = "▼ -"
	shift_down_btn.font_size = int(24 * s)
	shift_down_btn.position = Vector2(65, 12) * s
	shift_down_btn.size = Vector2(90, 58) * s
	shift_down_btn.corner_radius = 14.0 * s
	shift_down_btn.button_down.connect(func(): shift_down_requested.emit())
	pedals_container.add_child(shift_down_btn)
	
	# Shift Up (+)
	shift_up_btn = TouchButton.new()
	shift_up_btn.name = "ShiftUp"
	shift_up_btn.text = "+ ▲"
	shift_up_btn.font_size = int(24 * s)
	shift_up_btn.position = Vector2(175, 12) * s
	shift_up_btn.size = Vector2(90, 58) * s
	shift_up_btn.corner_radius = 14.0 * s
	shift_up_btn.button_down.connect(func(): shift_up_requested.emit())
	pedals_container.add_child(shift_up_btn)
	
	# === 3. TOP RIGHT: QUICK ENVIRONMENT, GARAGE & HUD CONFIG ===
	top_bar = Control.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_bar.anchor_left = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = -380.0
	top_bar.offset_top = 24.0
	top_bar.offset_right = -30.0
	top_bar.offset_bottom = 90.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(top_bar)
	
	var top_hbox := HBoxContainer.new()
	top_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_hbox.alignment = BoxContainer.ALIGNMENT_END
	top_hbox.add_theme_constant_override("separation", 12)
	top_bar.add_child(top_hbox)

	hud_edit_btn = TouchButton.new()
	hud_edit_btn.name = "HUDEditBtn"
	hud_edit_btn.text = "⚙️ КНОПКИ"
	hud_edit_btn.font_size = 14
	hud_edit_btn.custom_minimum_size = Vector2(110, 52)
	hud_edit_btn.corner_radius = 14.0
	hud_edit_btn.base_color = Color(0.18, 0.22, 0.32, 0.85)
	hud_edit_btn.border_color = Color(0.5, 0.7, 1.0, 0.75)
	hud_edit_btn.button_down.connect(enter_hud_editor)
	top_hbox.add_child(hud_edit_btn)

	weather_btn = TouchButton.new()
	weather_btn.name = "WeatherToggle"
	weather_btn.text = "🌧️ ДОЖДЬ"
	weather_btn.font_size = 14
	weather_btn.custom_minimum_size = Vector2(100, 52)
	weather_btn.corner_radius = 14.0
	weather_btn.base_color = Color(0.12, 0.2, 0.3, 0.85)
	weather_btn.border_color = Color(0.4, 0.65, 0.9, 0.7)
	weather_btn.button_down.connect(func(): weather_toggle_requested.emit())
	top_hbox.add_child(weather_btn)

	sky_btn = TouchButton.new()
	sky_btn.name = "SkyToggle"
	sky_btn.text = "🌙 НОЧЬ"
	sky_btn.font_size = 14
	sky_btn.custom_minimum_size = Vector2(90, 52)
	sky_btn.corner_radius = 14.0
	sky_btn.base_color = Color(0.15, 0.16, 0.28, 0.85)
	sky_btn.border_color = Color(0.6, 0.5, 0.9, 0.7)
	sky_btn.button_down.connect(func(): day_night_toggle_requested.emit())
	top_hbox.add_child(sky_btn)

	garage_btn = TouchButton.new()
	garage_btn.name = "GarageButton"
	garage_btn.text = "🏠 МЕНЮ"
	garage_btn.font_size = 14
	garage_btn.custom_minimum_size = Vector2(90, 52)
	garage_btn.corner_radius = 14.0
	garage_btn.base_color = Color(0.28, 0.14, 0.22, 0.9)
	garage_btn.border_color = Color(0.9, 0.45, 0.6, 0.85)
	garage_btn.button_down.connect(func(): garage_requested.emit())
	top_hbox.add_child(garage_btn)

	# Build HUD Editor Overlay Toolbar (hidden by default)
	_build_hud_editor_toolbar()

func _build_hud_editor_toolbar() -> void:
	hud_editor_panel = PanelContainer.new()
	hud_editor_panel.name = "HUDEditorToolbar"
	hud_editor_panel.anchor_left = 0.5
	hud_editor_panel.anchor_top = 0.0
	hud_editor_panel.anchor_right = 0.5
	hud_editor_panel.anchor_bottom = 0.0
	hud_editor_panel.offset_left = -380.0
	hud_editor_panel.offset_top = 20.0
	hud_editor_panel.offset_right = 380.0
	hud_editor_panel.offset_bottom = 90.0
	hud_editor_panel.visible = false
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.16, 0.96)
	style.set_corner_radius_all(18)
	style.border_width_bottom = 3
	style.border_color = Color(0.25, 0.85, 0.55, 0.9)
	hud_editor_panel.add_theme_stylebox_override("panel", style)
	root_control.add_child(hud_editor_panel)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	hud_editor_panel.add_child(hbox)

	var title := Label.new()
	title.text = "🛠️ РЕДАКТОР КНОПОК"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.3, 0.95, 0.6))
	hbox.add_child(title)

	var scale_down := Button.new()
	scale_down.text = "  🔍 −  "
	scale_down.custom_minimum_size = Vector2(60, 44)
	scale_down.pressed.connect(func(): _adjust_scale(-0.1))
	hbox.add_child(scale_down)

	editor_scale_label = Label.new()
	editor_scale_label.text = str(int(current_scale * 100)) + "%"
	editor_scale_label.custom_minimum_size = Vector2(65, 0)
	editor_scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	editor_scale_label.add_theme_font_size_override("font_size", 17)
	hbox.add_child(editor_scale_label)

	var scale_up := Button.new()
	scale_up.text = "  🔍 +  "
	scale_up.custom_minimum_size = Vector2(60, 44)
	scale_up.pressed.connect(func(): _adjust_scale(+0.1))
	hbox.add_child(scale_up)

	var reset_btn := Button.new()
	reset_btn.text = "СБРОС"
	reset_btn.custom_minimum_size = Vector2(80, 44)
	reset_btn.pressed.connect(_reset_hud_layout)
	hbox.add_child(reset_btn)

	var save_btn := Button.new()
	save_btn.text = "✓ ГОТОВО"
	save_btn.custom_minimum_size = Vector2(120, 44)
	var save_style := StyleBoxFlat.new()
	save_style.bg_color = Color(0.15, 0.75, 0.35, 0.95)
	save_style.set_corner_radius_all(10)
	save_btn.add_theme_stylebox_override("normal", save_style)
	save_btn.pressed.connect(func(): exit_hud_editor(true))
	hbox.add_child(save_btn)

func enter_hud_editor() -> void:
	is_editing_hud = true
	hud_editor_panel.visible = true
	top_bar.visible = false
	if is_instance_valid(mode_button):
		mode_button.visible = true
	
	# Make clusters interactive for dragging
	steer_container.mouse_filter = Control.MOUSE_FILTER_STOP
	pedals_container.mouse_filter = Control.MOUSE_FILTER_STOP
	steer_container.gui_input.connect(_on_steer_cluster_gui_input)
	pedals_container.gui_input.connect(_on_pedals_cluster_gui_input)

func exit_hud_editor(save: bool = true) -> void:
	is_editing_hud = false
	hud_editor_panel.visible = false
	top_bar.visible = true
	
	if steer_container.gui_input.is_connected(_on_steer_cluster_gui_input):
		steer_container.gui_input.disconnect(_on_steer_cluster_gui_input)
	if pedals_container.gui_input.is_connected(_on_pedals_cluster_gui_input):
		pedals_container.gui_input.disconnect(_on_pedals_cluster_gui_input)
	steer_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pedals_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if save:
		_save_hud_config()
	else:
		_load_saved_hud_config()
		_build_ui()
		_update_visibility()
		
	hud_editor_closed.emit()

func _adjust_scale(delta: float) -> void:
	current_scale = clampf(current_scale + delta, 0.7, 1.5)
	editor_scale_label.text = str(int(current_scale * 100)) + "%"
	_build_ui()
	_update_visibility()
	hud_editor_panel.visible = true
	top_bar.visible = false
	steer_container.mouse_filter = Control.MOUSE_FILTER_STOP
	pedals_container.mouse_filter = Control.MOUSE_FILTER_STOP
	steer_container.gui_input.connect(_on_steer_cluster_gui_input)
	pedals_container.gui_input.connect(_on_pedals_cluster_gui_input)

func _reset_hud_layout() -> void:
	current_scale = 1.0
	_steer_offset = Vector2(50.0, -50.0)
	_pedals_offset = Vector2(-50.0, -50.0)
	editor_scale_label.text = "100%"
	_build_ui()
	_update_visibility()
	hud_editor_panel.visible = true
	top_bar.visible = false
	steer_container.mouse_filter = Control.MOUSE_FILTER_STOP
	pedals_container.mouse_filter = Control.MOUSE_FILTER_STOP
	steer_container.gui_input.connect(_on_steer_cluster_gui_input)
	pedals_container.gui_input.connect(_on_pedals_cluster_gui_input)

func _on_steer_cluster_gui_input(event: InputEvent) -> void:
	if not is_editing_hud:
		return
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		_steer_offset.x = clampf(_steer_offset.x + event.relative.x, 20.0, 700.0)
		_steer_offset.y = clampf(_steer_offset.y + event.relative.y, -500.0, -20.0)
		var s := current_scale
		var steer_w := 380.0 * s
		var steer_h := 280.0 * s
		steer_container.offset_left = _steer_offset.x
		steer_container.offset_top = _steer_offset.y - steer_h
		steer_container.offset_right = _steer_offset.x + steer_w
		steer_container.offset_bottom = _steer_offset.y
		get_viewport().set_input_as_handled()

func _on_pedals_cluster_gui_input(event: InputEvent) -> void:
	if not is_editing_hud:
		return
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		_pedals_offset.x = clampf(_pedals_offset.x + event.relative.x, -700.0, -20.0)
		_pedals_offset.y = clampf(_pedals_offset.y + event.relative.y, -500.0, -20.0)
		var s := current_scale
		var pedals_w := 420.0 * s
		var pedals_h := 320.0 * s
		pedals_container.offset_left = _pedals_offset.x - pedals_w
		pedals_container.offset_top = _pedals_offset.y - pedals_h
		pedals_container.offset_right = _pedals_offset.x
		pedals_container.offset_bottom = _pedals_offset.y
		get_viewport().set_input_as_handled()

func _on_look_area_gui_input(event: InputEvent) -> void:
	if is_editing_hud:
		return
	if event is InputEventScreenTouch:
		if event.pressed and active_look_index == -1:
			active_look_index = event.index
			is_looking = true
		elif not event.pressed and event.index == active_look_index:
			active_look_index = -1
			is_looking = false
			if is_instance_valid(camera):
				camera.stop_orbit()
			look_ended.emit()
			
	elif event is InputEventScreenDrag:
		if is_looking and event.index == active_look_index:
			if is_instance_valid(camera):
				camera.rotate_orbit(event.relative)
			look_dragged.emit(event.relative)
			
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if event.pressed and active_look_index == -1:
				active_look_index = 9998
				is_looking = true
			elif not event.pressed and active_look_index == 9998:
				active_look_index = -1
				is_looking = false
				if is_instance_valid(camera):
					camera.stop_orbit()
				look_ended.emit()
				
	elif event is InputEventMouseMotion:
		if is_looking and active_look_index == 9998:
			if is_instance_valid(camera):
				camera.rotate_orbit(event.relative)
			look_dragged.emit(event.relative)

func _toggle_steering_mode() -> void:
	if current_steering_mode == SteeringMode.ARROWS:
		current_steering_mode = SteeringMode.WHEEL
	else:
		current_steering_mode = SteeringMode.ARROWS
	_save_hud_config()

func _update_visibility() -> void:
	if not is_instance_valid(arrow_left) or not is_instance_valid(steering_wheel):
		return
		
	var is_arrows = current_steering_mode == SteeringMode.ARROWS
	arrow_left.visible = is_arrows
	arrow_right.visible = is_arrows
	steering_wheel.visible = not is_arrows
	
	if is_instance_valid(mode_button):
		mode_button.text = "РУЛЬ" if is_arrows else "СТРЕЛКИ"

func update_transmission_ui(is_auto: bool) -> void:
	if is_instance_valid(trans_mode_btn):
		trans_mode_btn.text = "АКПП" if is_auto else "МКПП"
		trans_mode_btn.base_color = Color(0.12, 0.25, 0.2, 0.82) if is_auto else Color(0.3, 0.2, 0.08, 0.85)
		trans_mode_btn.border_color = Color(0.3, 0.9, 0.5, 0.75) if is_auto else Color(1.0, 0.6, 0.2, 0.8)
		trans_mode_btn.queue_redraw()

func get_steering_input() -> float:
	if current_steering_mode == SteeringMode.ARROWS:
		var steer = 0.0
		if is_instance_valid(arrow_left) and arrow_left.is_pressed:
			steer += 1.0
		if is_instance_valid(arrow_right) and arrow_right.is_pressed:
			steer -= 1.0
		return steer
	else:
		if is_instance_valid(steering_wheel):
			return -steering_wheel.steering_value
		return 0.0

func is_wheel_active() -> bool:
	return current_steering_mode == SteeringMode.WHEEL and is_instance_valid(steering_wheel) and steering_wheel.is_dragging

func get_throttle_input() -> float:
	return 1.0 if (is_instance_valid(gas_pedal) and gas_pedal.is_pressed) else 0.0

func get_brake_input() -> float:
	return 1.0 if (is_instance_valid(brake_pedal) and brake_pedal.is_pressed) else 0.0

func get_handbrake_input() -> float:
	return 1.0 if (is_instance_valid(handbrake_btn) and handbrake_btn.is_pressed) else 0.0
