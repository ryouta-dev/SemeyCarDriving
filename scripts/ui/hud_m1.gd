class_name HUDM1
extends CanvasLayer

## Touch + keyboard HUD for the M1 slice. Layout follows the reference: wheel
## on the left, pedals/handbrake/gear on the right, speedometer top-right,
## minimap bottom-centre-left, camera/pause top-left.

var vehicle: Vehicle
var camera_rig: VehicleCameraRig
var headlights: Node3D

var gear_mode: String = "D"

var _root: Control
var _wheel: VirtualSteeringWheel
var _gas: TouchButton
var _brake: TouchButton
var _handbrake: TouchButton
var _camera_button: TouchButton
var _pause_button: TouchButton
var _lights_button: TouchButton
var _gear_buttons: Dictionary = {}
var _speedometer: SpeedometerM1
var _minimap: MinimapM1
var _pause_layer: Control
var _camera_hint: Label
var _camera_hint_time := 0.0
var _paused := false
var _lights_on := false
var _layout_pending := false

## How long the camera-mode caption stays on screen after switching modes.
const CAMERA_HINT_SECONDS := 1.4
## Fade-out tail of that caption, in seconds.
const CAMERA_HINT_FADE := 0.4

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_schedule_layout)
	_schedule_layout()

func is_paused() -> bool:
	return _paused

# ── Build ────────────────────────────────────────────────────────────────────

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_speedometer = SpeedometerM1.new()
	_speedometer.name = "Speedometer"
	_root.add_child(_speedometer)
	_minimap = MinimapM1.new()
	_minimap.name = "Minimap"
	_root.add_child(_minimap)

	# Short caption under the top edge: which of the four camera modes is active.
	# It only appears for a moment after the KAM button (or C) is pressed.
	_camera_hint = Label.new()
	_camera_hint.name = "CameraHint"
	_camera_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camera_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_camera_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camera_hint.visible = false
	ThemeM1.apply_label(_camera_hint, 24, ThemeM1.ACCENT)
	_root.add_child(_camera_hint)

	_wheel = VirtualSteeringWheel.new()
	_wheel.name = "SteeringWheel"
	_wheel.wheel_color = Color("14171c")
	_wheel.rim_color = Color("23262c")
	_wheel.spoke_color = Color("4a505a")
	_wheel.accent_color = ThemeM1.ACCENT
	_root.add_child(_wheel)

	_pause_button = _touch("II", Color(0.08, 0.09, 0.11, 0.85), Color(0.20, 0.22, 0.26, 0.95))
	_pause_button.button_down.connect(_toggle_pause)
	_camera_button = _touch("КАМ", Color(0.08, 0.09, 0.11, 0.85), Color(0.20, 0.22, 0.26, 0.95))
	_camera_button.button_down.connect(_cycle_camera)
	_lights_button = _touch("СВЕТ", Color(0.08, 0.09, 0.11, 0.85), Color(0.55, 0.45, 0.15, 0.95))
	_lights_button.button_down.connect(_toggle_lights)

	_gas = _touch("ГАЗ", Color(0.08, 0.26, 0.14, 0.86), Color(0.16, 0.75, 0.35, 0.95))
	_gas.font_size = 26
	_brake = _touch("ТОРМОЗ", Color(0.28, 0.10, 0.13, 0.86), Color(0.85, 0.18, 0.23, 0.95))
	_brake.font_size = 20
	_handbrake = _touch("РУЧНИК", Color(0.30, 0.18, 0.08, 0.86), Color(0.85, 0.45, 0.12, 0.95))
	_handbrake.font_size = 18

	for letter: String in ["P", "R", "N", "D"]:
		var button := _touch(letter, Color(0.08, 0.09, 0.11, 0.85), Color(0.20, 0.22, 0.26, 0.95))
		button.font_size = 24
		button.button_down.connect(_select_gear.bind(letter))
		_gear_buttons[letter] = button
	_update_gear_buttons()

	_build_pause_layer()

func _build_pause_layer() -> void:
	_pause_layer = Control.new()
	_pause_layer.name = "PauseLayer"
	_pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.visible = false
	_root.add_child(_pause_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.02, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeM1.panel_style(0.96, 18))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 320)
	panel.position -= Vector2(230, 160)
	_pause_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeM1.apply_label(title, 40)
	box.add_child(title)
	var resume := Button.new()
	resume.text = "Продолжить"
	ThemeM1.apply_button(resume, true, 28)
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var menu := Button.new()
	menu.text = "В меню"
	ThemeM1.apply_button(menu, false, 28)
	menu.pressed.connect(_go_to_menu)
	box.add_child(menu)

func _touch(text: String, base: Color, pressed: Color) -> TouchButton:
	var button := TouchButton.new()
	button.text = text
	button.font_size = 22
	button.base_color = base
	button.pressed_color = pressed
	button.border_color = Color(1, 1, 1, 0.18)
	button.corner_radius = 18.0
	_root.add_child(button)
	return button

# ── Layout ───────────────────────────────────────────────────────────────────

func _schedule_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	_apply_layout.call_deferred()

func _apply_layout() -> void:
	_layout_pending = false
	if not is_inside_tree():
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var u: float = clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.55, 2.4)
	var margin: float = 20.0 * u
	_place(_pause_button, Rect2(Vector2(margin, margin), Vector2(64, 64) * u))
	_place(_camera_button, Rect2(Vector2(margin, margin + 76 * u), Vector2(64, 64) * u))
	_place(_lights_button, Rect2(Vector2(margin + 76 * u, margin), Vector2(72, 64) * u))
	_place(_camera_hint, Rect2(Vector2(viewport_size.x * 0.5 - 190 * u, margin + 4 * u), Vector2(380, 40) * u))
	_place(_speedometer, Rect2(Vector2(viewport_size.x - 244 * u - margin, margin), Vector2(244, 244) * u))
	_place(_wheel, Rect2(Vector2(margin, viewport_size.y - 300 * u), Vector2(260, 260) * u))
	_place(_minimap, Rect2(Vector2(margin + 286 * u, viewport_size.y - 226 * u), Vector2(190, 190) * u))
	_place(_gas, Rect2(Vector2(viewport_size.x - 124 * u - margin, viewport_size.y - 300 * u), Vector2(112, 220) * u))
	_place(_brake, Rect2(Vector2(viewport_size.x - 246 * u - margin, viewport_size.y - 250 * u), Vector2(104, 170) * u))
	_place(_handbrake, Rect2(Vector2(viewport_size.x - 124 * u - margin, viewport_size.y - 392 * u), Vector2(112, 76) * u))
	var gear_index := 0
	for letter: String in ["P", "R", "N", "D"]:
		var button: TouchButton = _gear_buttons[letter]
		_place(button, Rect2(Vector2(viewport_size.x - 246 * u - margin, viewport_size.y - 480 * u + gear_index * 60 * u), Vector2(104, 50) * u))
		gear_index += 1

func _place(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size
	control.queue_redraw()

# ── Input ────────────────────────────────────────────────────────────────────

func get_steer() -> float:
	if is_instance_valid(_wheel) and _wheel.is_dragging:
		return -_wheel.steering_value
	var keyboard: float = Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	return keyboard

func get_throttle() -> float:
	var keyboard: float = Input.get_action_strength("throttle")
	return maxf(keyboard, 1.0 if is_instance_valid(_gas) and _gas.is_pressed else 0.0)

func get_brake() -> float:
	var keyboard: float = Input.get_action_strength("brake")
	return maxf(keyboard, 1.0 if is_instance_valid(_brake) and _brake.is_pressed else 0.0)

func get_handbrake() -> float:
	var keyboard: float = Input.get_action_strength("handbrake")
	return maxf(keyboard, 1.0 if is_instance_valid(_handbrake) and _handbrake.is_pressed else 0.0)

func _select_gear(letter: String) -> void:
	gear_mode = letter
	_update_gear_buttons()

func _update_gear_buttons() -> void:
	for letter: String in _gear_buttons:
		var button: TouchButton = _gear_buttons[letter]
		var active: bool = letter == gear_mode
		button.base_color = Color(0.88, 0.70, 0.15, 0.95) if active else Color(0.08, 0.09, 0.11, 0.85)
		button.pressed_color = Color(0.95, 0.78, 0.22, 1.0) if active else Color(0.20, 0.22, 0.26, 0.95)
		button.queue_redraw()

# ── Frame update ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_tick_camera_hint(delta)
	if _paused or not is_instance_valid(vehicle):
		return
	var speed_kmh: float = vehicle.linear_velocity.length() * 3.6
	var ratio: float = clampf(vehicle.motor_rpm / maxf(1000.0, vehicle.max_rpm), 0.0, 1.0)
	_speedometer.set_values(speed_kmh, ratio, _gear_label())
	_minimap.set_car_position(vehicle.global_position)

func _tick_camera_hint(delta: float) -> void:
	if _camera_hint_time <= 0.0 or not is_instance_valid(_camera_hint):
		return
	_camera_hint_time -= delta
	if _camera_hint_time <= 0.0:
		_camera_hint.visible = false
		return
	_camera_hint.modulate.a = clampf(_camera_hint_time / CAMERA_HINT_FADE, 0.0, 1.0)

func _show_camera_hint(text: String) -> void:
	if not is_instance_valid(_camera_hint):
		return
	_camera_hint.text = text
	_camera_hint.visible = true
	_camera_hint.modulate.a = 1.0
	_camera_hint_time = CAMERA_HINT_SECONDS

func _gear_label() -> String:
	if gear_mode == "P":
		return "P"
	if gear_mode == "R":
		return "R"
	if gear_mode == "N":
		return "N"
	var gear: int = vehicle.current_gear
	if gear > 0:
		return ("D" if vehicle.automatic_transmission else "M") + str(gear)
	return "D" if vehicle.automatic_transmission else "M"

# ── Actions ──────────────────────────────────────────────────────────────────

func _toggle_pause() -> void:
	_paused = not _paused
	_pause_layer.visible = _paused
	get_tree().paused = _paused
	if _paused:
		_reset_inputs()
	elif is_instance_valid(camera_rig):
		camera_rig.snap()

func _cycle_camera() -> void:
	if not is_instance_valid(camera_rig):
		return
	camera_rig.cycle_mode()
	_show_camera_hint("КАМЕРА: " + camera_rig.mode_name().to_upper())

func _toggle_lights() -> void:
	if not is_instance_valid(headlights):
		return
	_lights_on = not _lights_on
	headlights.visible = _lights_on
	for child in headlights.get_children():
		if child is SpotLight3D:
			child.visible = _lights_on
			child.light_energy = 4.0 if _lights_on else 0.0

func _go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _reset_inputs() -> void:
	if is_instance_valid(_wheel):
		_wheel.reset_input()
	for button: TouchButton in [_gas, _brake, _handbrake]:
		if is_instance_valid(button):
			button.reset_input()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_reset_inputs()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_toggle_pause()
			KEY_C:
				_cycle_camera()
			KEY_L:
				_toggle_lights()
