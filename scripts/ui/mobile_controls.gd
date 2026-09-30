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

# Touch look tracking
var active_look_index: int = -1
var is_looking: bool = false

func _ready() -> void:
	layer = 10
	_build_ui()
	_update_visibility()

func _build_ui() -> void:
	# Root fullscreen control container
	var root = Control.new()
	root.name = "RootControls"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	
	# === 0. TOUCH LOOK AREA (Screen swipe to look around) ===
	look_area = Control.new()
	look_area.name = "TouchLookArea"
	look_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	look_area.mouse_filter = Control.MOUSE_FILTER_STOP
	look_area.gui_input.connect(_on_look_area_gui_input)
	root.add_child(look_area)
	
	# === 1. LEFT SIDE: STEERING ===
	steer_container = Control.new()
	steer_container.name = "SteeringArea"
	steer_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	steer_container.anchor_left = 0.0
	steer_container.anchor_top = 1.0
	steer_container.anchor_right = 0.0
	steer_container.anchor_bottom = 1.0
	steer_container.offset_left = 30.0
	steer_container.offset_top = -260.0
	steer_container.offset_right = 320.0
	steer_container.offset_bottom = -30.0
	steer_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(steer_container)
	
	# Arrow Left
	arrow_left = TouchButton.new()
	arrow_left.name = "ArrowLeft"
	arrow_left.icon_type = "arrow_left"
	arrow_left.position = Vector2(0, 50)
	arrow_left.size = Vector2(125, 125)
	arrow_left.corner_radius = 24.0
	arrow_left.border_width = 3.0
	steer_container.add_child(arrow_left)
	
	# Arrow Right
	arrow_right = TouchButton.new()
	arrow_right.name = "ArrowRight"
	arrow_right.icon_type = "arrow_right"
	arrow_right.position = Vector2(145, 50)
	arrow_right.size = Vector2(125, 125)
	arrow_right.corner_radius = 24.0
	arrow_right.border_width = 3.0
	steer_container.add_child(arrow_right)
	
	# Virtual Steering Wheel
	steering_wheel = VirtualSteeringWheel.new()
	steering_wheel.name = "VirtualSteeringWheel"
	steering_wheel.position = Vector2(20, -10)
	steering_wheel.size = Vector2(230, 230)
	steer_container.add_child(steering_wheel)
	
	# Mode Toggle Button
	mode_button = TouchButton.new()
	mode_button.name = "ModeToggle"
	mode_button.text = "MODE"
	mode_button.font_size = 14
	mode_button.position = Vector2(85, 185)
	mode_button.size = Vector2(100, 36)
	mode_button.corner_radius = 10.0
	mode_button.base_color = Color(0.15, 0.2, 0.28, 0.8)
	mode_button.border_color = Color(0.5, 0.7, 1.0, 0.7)
	mode_button.button_down.connect(_toggle_steering_mode)
	steer_container.add_child(mode_button)
	
	# === 2. RIGHT SIDE: PEDALS & TRANSMISSION ===
	pedals_container = Control.new()
	pedals_container.name = "PedalsArea"
	pedals_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pedals_container.anchor_left = 1.0
	pedals_container.anchor_top = 1.0
	pedals_container.anchor_right = 1.0
	pedals_container.anchor_bottom = 1.0
	pedals_container.offset_left = -340.0
	pedals_container.offset_top = -280.0
	pedals_container.offset_right = -30.0
	pedals_container.offset_bottom = -30.0
	pedals_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pedals_container)
	
	# Brake Pedal (Left of pedals area)
	brake_pedal = TouchButton.new()
	brake_pedal.name = "BrakePedal"
	brake_pedal.icon_type = "pedal_brake"
	brake_pedal.text = "BRAKE"
	brake_pedal.position = Vector2(40, 70)
	brake_pedal.size = Vector2(100, 150)
	brake_pedal.corner_radius = 18.0
	brake_pedal.border_width = 3.0
	brake_pedal.base_color = Color(0.22, 0.12, 0.14, 0.7)
	brake_pedal.pressed_color = Color(0.9, 0.2, 0.25, 0.9)
	pedals_container.add_child(brake_pedal)
	
	# Gas Pedal (Rightmost)
	gas_pedal = TouchButton.new()
	gas_pedal.name = "GasPedal"
	gas_pedal.icon_type = "pedal_gas"
	gas_pedal.text = "GAS"
	gas_pedal.position = Vector2(165, 40)
	gas_pedal.size = Vector2(100, 180)
	gas_pedal.corner_radius = 20.0
	gas_pedal.border_width = 3.0
	gas_pedal.base_color = Color(0.12, 0.22, 0.16, 0.7)
	gas_pedal.pressed_color = Color(0.2, 0.85, 0.4, 0.9)
	pedals_container.add_child(gas_pedal)
	
	# Handbrake Button (drift trigger, placed next to brake)
	handbrake_btn = TouchButton.new()
	handbrake_btn.name = "Handbrake"
	handbrake_btn.text = "P"
	handbrake_btn.font_size = 22
	handbrake_btn.position = Vector2(-45, 120)
	handbrake_btn.size = Vector2(65, 75)
	handbrake_btn.corner_radius = 16.0
	handbrake_btn.border_width = 2.5
	handbrake_btn.base_color = Color(0.25, 0.18, 0.08, 0.7)
	handbrake_btn.pressed_color = Color(1.0, 0.65, 0.1, 0.9)
	pedals_container.add_child(handbrake_btn)
	
	# Trans Mode Toggle (AUTO / MAN)
	trans_mode_btn = TouchButton.new()
	trans_mode_btn.name = "TransMode"
	trans_mode_btn.text = "AUTO"
	trans_mode_btn.font_size = 14
	trans_mode_btn.position = Vector2(-45, 60)
	trans_mode_btn.size = Vector2(65, 45)
	trans_mode_btn.corner_radius = 10.0
	trans_mode_btn.base_color = Color(0.12, 0.25, 0.2, 0.8)
	trans_mode_btn.border_color = Color(0.3, 0.9, 0.5, 0.7)
	trans_mode_btn.button_down.connect(func(): toggle_transmission_requested.emit())
	pedals_container.add_child(trans_mode_btn)
	
	# Shift Down (-)
	shift_down_btn = TouchButton.new()
	shift_down_btn.name = "ShiftDown"
	shift_down_btn.text = "-"
	shift_down_btn.font_size = 28
	shift_down_btn.position = Vector2(40, 10)
	shift_down_btn.size = Vector2(65, 45)
	shift_down_btn.corner_radius = 10.0
	shift_down_btn.button_down.connect(func(): shift_down_requested.emit())
	pedals_container.add_child(shift_down_btn)
	
	# Shift Up (+)
	shift_up_btn = TouchButton.new()
	shift_up_btn.name = "ShiftUp"
	shift_up_btn.text = "+"
	shift_up_btn.font_size = 26
	shift_up_btn.position = Vector2(125, 10)
	shift_up_btn.size = Vector2(65, 45)
	shift_up_btn.corner_radius = 10.0
	shift_up_btn.button_down.connect(func(): shift_up_requested.emit())
	pedals_container.add_child(shift_up_btn)
	
	# === 3. TOP RIGHT: QUICK ENVIRONMENT & GARAGE TOGGLES ===
	var top_bar = Control.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_bar.anchor_left = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = -245.0
	top_bar.offset_top = 20.0
	top_bar.offset_right = -20.0
	top_bar.offset_bottom = 65.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar)

	var garage_btn = TouchButton.new()
	garage_btn.name = "GarageButton"
	garage_btn.text = "GARAGE"
	garage_btn.font_size = 12
	garage_btn.position = Vector2(0, 0)
	garage_btn.size = Vector2(75, 38)
	garage_btn.corner_radius = 10.0
	garage_btn.base_color = Color(0.22, 0.16, 0.32, 0.85)
	garage_btn.border_color = Color(0.7, 0.45, 0.95, 0.8)
	garage_btn.button_down.connect(func(): garage_requested.emit())
	top_bar.add_child(garage_btn)

	var weather_btn = TouchButton.new()
	weather_btn.name = "WeatherToggle"
	weather_btn.text = "RAIN"
	weather_btn.font_size = 13
	weather_btn.position = Vector2(85, 0)
	weather_btn.size = Vector2(65, 38)
	weather_btn.corner_radius = 10.0
	weather_btn.base_color = Color(0.12, 0.2, 0.28, 0.75)
	weather_btn.border_color = Color(0.4, 0.6, 0.8, 0.6)
	weather_btn.button_down.connect(func(): weather_toggle_requested.emit())
	top_bar.add_child(weather_btn)

	var sky_btn = TouchButton.new()
	sky_btn.name = "SkyToggle"
	sky_btn.text = "NIGHT"
	sky_btn.font_size = 13
	sky_btn.position = Vector2(160, 0)
	sky_btn.size = Vector2(65, 38)
	sky_btn.corner_radius = 10.0
	sky_btn.base_color = Color(0.15, 0.18, 0.28, 0.75)
	sky_btn.border_color = Color(0.5, 0.5, 0.8, 0.6)
	sky_btn.button_down.connect(func(): day_night_toggle_requested.emit())
	top_bar.add_child(sky_btn)

func _on_look_area_gui_input(event: InputEvent) -> void:
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

func _update_visibility() -> void:
	if not is_instance_valid(arrow_left) or not is_instance_valid(steering_wheel):
		return
		
	var is_arrows = current_steering_mode == SteeringMode.ARROWS
	arrow_left.visible = is_arrows
	arrow_right.visible = is_arrows
	steering_wheel.visible = not is_arrows
	
	if is_instance_valid(mode_button):
		mode_button.text = "WHEEL" if is_arrows else "ARROWS"

func update_transmission_ui(is_auto: bool) -> void:
	if is_instance_valid(trans_mode_btn):
		trans_mode_btn.text = "AUTO" if is_auto else "MAN"
		trans_mode_btn.base_color = Color(0.12, 0.25, 0.2, 0.8) if is_auto else Color(0.3, 0.2, 0.08, 0.8)
		trans_mode_btn.border_color = Color(0.3, 0.9, 0.5, 0.7) if is_auto else Color(1.0, 0.6, 0.2, 0.7)
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
