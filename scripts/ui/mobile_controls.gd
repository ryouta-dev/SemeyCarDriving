class_name MobileControls
extends CanvasLayer

const MobileLayoutUtil = preload("res://scripts/ui/mobile_layout.gd")

signal shift_up_requested
signal shift_down_requested
signal toggle_transmission_requested
signal day_night_toggle_requested
signal weather_toggle_requested
signal garage_requested
signal respawn_requested
signal challenge_requested(kind: String)
signal minimap_toggled(enabled: bool)
signal ui_blocked_changed(blocked: bool)
signal look_dragged(relative: Vector2)
signal look_ended
signal hud_editor_closed

enum SteeringMode { ARROWS, WHEEL }
@export var camera: ProVehicleCamera
@export var current_steering_mode: SteeringMode = SteeringMode.ARROWS:
	set(value):
		current_steering_mode = value
		_update_visibility()

var root_control: Control
var look_area: Control
var steer_container: Control
var pedals_container: Control
var arrow_left: TouchButton
var arrow_right: TouchButton
var steering_wheel: VirtualSteeringWheel
var mode_button: TouchButton
var gas_pedal: TouchButton
var brake_pedal: TouchButton
var handbrake_btn: TouchButton
var shift_up_btn: TouchButton
var shift_down_btn: TouchButton
var trans_mode_btn: TouchButton
var camera_btn: TouchButton
var menu_btn: TouchButton
var top_bar: Control
var hud_editor_panel: PanelContainer
var editor_scale_label: Label
var is_editing_hud: bool = false
var current_scale: float = 1.0
var minimap_visible: bool = true
var active_look_index: int = -1
var is_looking: bool = false
var _steer_offset: Vector2 = Vector2(20, -20)
var _pedals_offset: Vector2 = Vector2(-20, -20)
var _transmission_auto: bool = true
var _menu_open: bool = false
var _owns_pause: bool = false
var _layout_pending: bool = false
var _unit: float = 1.0
var _all_buttons: Array[TouchButton] = []
var _menu_shade: ColorRect
var _menu_panel: PanelContainer
var _menu_scroll: ScrollContainer
var _menu_rows: VBoxContainer
var _menu_title: Label
var _challenge_rows: VBoxContainer
var _editor_rows: HBoxContainer
var _editor_touch: int = -1
var _editor_target: String = ""

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_saved_hud_config()
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_changed)
	_schedule_layout()

func _load_saved_hud_config() -> void:
	var profile: Dictionary = ProfileManager.load_profile()
	var config: Dictionary = profile["hud"]
	current_scale = clampf(float(config["button_scale"]), 0.7, 1.5)
	minimap_visible = bool(config.get("minimap", true))
	current_steering_mode = SteeringMode.WHEEL if config["steer_mode"] == "wheel" else SteeringMode.ARROWS
	_steer_offset = Vector2(float(config["steer_pos_x"]), float(config["steer_pos_y"]))
	_pedals_offset = Vector2(float(config["pedals_pos_x"]), float(config["pedals_pos_y"]))

func _save_hud_config() -> bool:
	return ProfileManager.save_sections({"hud": {"button_scale": current_scale,
		"steer_mode": "wheel" if current_steering_mode == SteeringMode.WHEEL else "arrows",
		"steer_pos_x": _steer_offset.x, "steer_pos_y": _steer_offset.y,
		"pedals_pos_x": _pedals_offset.x, "pedals_pos_y": _pedals_offset.y,
		"minimap": minimap_visible}})

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "RootControls"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	look_area = Control.new()
	look_area.name = "TouchLookArea"
	look_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	look_area.mouse_filter = Control.MOUSE_FILTER_STOP
	look_area.gui_input.connect(_on_look_area_gui_input)
	root_control.add_child(look_area)
	steer_container = _cluster("SteerCluster", MobileLayoutUtil.STEER_SIZE)
	pedals_container = _cluster("PedalsCluster", MobileLayoutUtil.PEDALS_SIZE)
	arrow_left = _touch(steer_container, "ArrowLeft", "", Rect2(0, 64, 112, 112), "arrow_left")
	arrow_right = _touch(steer_container, "ArrowRight", "", Rect2(136, 64, 112, 112), "arrow_right")
	steering_wheel = VirtualSteeringWheel.new()
	steering_wheel.name = "VirtualSteeringWheel"
	steering_wheel.position = Vector2(24, 0)
	steering_wheel.size = Vector2(216, 216)
	steer_container.add_child(steering_wheel)
	mode_button = _touch(steer_container, "ModeToggle", "РУЛЬ", Rect2(64, 222, 136, 88))
	mode_button.button_down.connect(_toggle_steering_mode)
	gas_pedal = _touch(pedals_container, "GasPedal", "ГАЗ", Rect2(224, 104, 100, 164), "pedal_gas")
	gas_pedal.base_color = Color(0.08, 0.24, 0.14, 0.80)
	gas_pedal.pressed_color = Color(0.16, 0.75, 0.35, 0.95)
	brake_pedal = _touch(pedals_container, "BrakePedal", "ТОРМОЗ", Rect2(112, 120, 98, 148), "pedal_brake")
	brake_pedal.font_size = 22
	brake_pedal.base_color = Color(0.27, 0.10, 0.13, 0.80)
	brake_pedal.pressed_color = Color(0.85, 0.18, 0.23, 0.95)
	handbrake_btn = _touch(pedals_container, "Handbrake", "РУЧНИК", Rect2(0, 188, 94, 84))
	handbrake_btn.font_size = 22
	handbrake_btn.base_color = Color(0.28, 0.18, 0.06, 0.82)
	trans_mode_btn = _touch(pedals_container, "TransMode", "АКПП", Rect2(0, 92, 94, 88))
	trans_mode_btn.button_down.connect(func(): toggle_transmission_requested.emit())
	shift_down_btn = _touch(pedals_container, "ShiftDown", "−", Rect2(112, 8, 98, 88))
	shift_down_btn.font_size = 26
	shift_down_btn.button_down.connect(func(): shift_down_requested.emit())
	shift_up_btn = _touch(pedals_container, "ShiftUp", "+", Rect2(224, 8, 100, 88))
	shift_up_btn.font_size = 26
	shift_up_btn.button_down.connect(func(): shift_up_requested.emit())
	top_bar = Control.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(top_bar)
	camera_btn = _touch(top_bar, "CameraButton", "КАМЕРА", Rect2(0, 0, 128, 60))
	camera_btn.button_down.connect(_cycle_camera)
	menu_btn = _touch(top_bar, "MenuButton", "МЕНЮ", Rect2(0, 0, 100, 60))
	menu_btn.button_down.connect(func(): _set_menu_open(not _menu_open))
	_build_menu()
	_build_hud_editor_toolbar()
	_update_visibility()

func _cluster(node_name: String, dimensions: Vector2) -> Control:
	var cluster: Control = Control.new()
	cluster.name = node_name
	cluster.size = dimensions
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(cluster)
	cluster.gui_input.connect(func(event: InputEvent): _on_editor_drag(event, node_name))
	return cluster

func _touch(parent: Control, node_name: String, label: String, rect: Rect2, icon: String = "none") -> TouchButton:
	var button: TouchButton = TouchButton.new()
	button.name = node_name
	button.text = label
	button.font_size = 24
	button.icon_type = icon
	button.position = rect.position
	button.size = rect.size
	button.corner_radius = 16.0
	button.base_color = Color(0.08, 0.12, 0.19, 0.78)
	button.border_color = Color(0.36, 0.58, 0.8, 0.70)
	parent.add_child(button)
	_all_buttons.append(button)
	return button

func _build_menu() -> void:
	_menu_shade = ColorRect.new()
	_menu_shade.color = Color(0.015, 0.025, 0.045, 0.78)
	_menu_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_shade.visible = false
	root_control.add_child(_menu_shade)
	_menu_panel = PanelContainer.new()
	_menu_panel.visible = false
	_menu_panel.add_theme_stylebox_override("panel", _panel_style())
	root_control.add_child(_menu_panel)
	_menu_scroll = ScrollContainer.new()
	_menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_panel.add_child(_menu_scroll)
	_menu_rows = VBoxContainer.new()
	_menu_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_rows.add_theme_constant_override("separation", 8)
	_menu_scroll.add_child(_menu_rows)
	_menu_title = Label.new()
	_menu_title.text = "ПАУЗА"
	_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_rows.add_child(_menu_title)
	_menu_action("Продолжить", func(): _set_menu_open(false))
	_menu_action("Испытания", func(): _show_challenges(true))
	_menu_action("Раскладка кнопок", enter_hud_editor)
	_menu_action("Салон: посадка выше", func(): _adjust_seat(0.03))
	_menu_action("Салон: посадка ниже", func(): _adjust_seat(-0.03))
	_menu_action("Погода: дождь / ясно", func(): weather_toggle_requested.emit())
	_menu_action("Освещение: день / ночь", func(): day_night_toggle_requested.emit())
	var map_toggle: CheckButton = CheckButton.new()
	map_toggle.text = "Миникарта"
	map_toggle.button_pressed = minimap_visible
	map_toggle.toggled.connect(func(value: bool):
		minimap_visible = value
		minimap_toggled.emit(value)
		if not _save_hud_config():
			_menu_title.text = "Не удалось сохранить настройки")
	_menu_rows.add_child(map_toggle)
	var sound_toggle: CheckButton = CheckButton.new()
	sound_toggle.text = "Звук"
	sound_toggle.button_pressed = not bool(ProfileManager.load_profile()["settings"].get("muted", false))
	sound_toggle.toggled.connect(func(value: bool):
		AudioServer.set_bus_mute(0, not value)
		if not ProfileManager.save_sections({"settings": {"muted": not value}}):
			_menu_title.text = "Не удалось сохранить настройки")
	_menu_rows.add_child(sound_toggle)
	_menu_action("Вернуть машину", func():
		_set_menu_open(false)
		respawn_requested.emit())
	_menu_action("В гараж", func():
		_set_menu_open(false)
		garage_requested.emit())
	_challenge_rows = VBoxContainer.new()
	_challenge_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_challenge_rows.visible = false
	_menu_panel.add_child(_challenge_rows)
	for entry in [["Спринт", "sprint"], ["Дрифт — 30 секунд", "drift"], ["Парковка", "parking"]]:
		var action: String = entry[1]
		var button: Button = Button.new()
		button.text = entry[0]
		button.pressed.connect(func():
			_set_menu_open(false)
			challenge_requested.emit(action))
		_challenge_rows.add_child(button)
	var back: Button = Button.new()
	back.text = "Назад"
	back.pressed.connect(func(): _show_challenges(false))
	_challenge_rows.add_child(back)

func _menu_action(label: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = label
	button.pressed.connect(action)
	_menu_rows.add_child(button)

func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.065, 0.11, 0.98)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(14)
	return style

func _show_challenges(enabled: bool) -> void:
	_menu_scroll.visible = not enabled
	_challenge_rows.visible = enabled

func _set_menu_open(enabled: bool) -> void:
	if is_editing_hud:
		return
	reset_inputs()
	_menu_open = enabled
	_menu_shade.visible = enabled
	_menu_panel.visible = enabled
	_show_challenges(false)
	if enabled:
		_menu_scroll.scroll_vertical = 0
		_menu_title.text = "ПАУЗА"
		_hold_pause()
	else:
		_release_pause()
	ui_blocked_changed.emit(is_driving_blocked())

func _hold_pause() -> void:
	if is_inside_tree() and not get_tree().paused:
		ui_blocked_changed.emit(true)
		_owns_pause = true
		get_tree().paused = true

func _release_pause() -> void:
	reset_inputs()
	if _owns_pause and is_inside_tree():
		_owns_pause = false
		get_tree().paused = false

func is_driving_blocked() -> bool:
	return is_editing_hud or _menu_open

func _cycle_camera() -> void:
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d() as ProVehicleCamera
	if is_instance_valid(camera):
		camera.stop_orbit()
		camera.cycle_camera_mode()
		camera.snap_to_target()
		camera_btn.text = "КАМЕРА"
		camera_btn.queue_redraw()

func _build_hud_editor_toolbar() -> void:
	hud_editor_panel = PanelContainer.new()
	hud_editor_panel.visible = false
	hud_editor_panel.add_theme_stylebox_override("panel", _panel_style())
	root_control.add_child(hud_editor_panel)
	_editor_rows = HBoxContainer.new()
	_editor_rows.add_theme_constant_override("separation", 8)
	hud_editor_panel.add_child(_editor_rows)
	for entry in [["−", "smaller"], ["+", "larger"], ["Руль / стрелки", "mode"], ["Сброс", "reset"], ["Готово", "save"]]:
		var action: String = entry[1]
		var button: Button = Button.new()
		button.text = entry[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_editor_action.bind(action))
		_editor_rows.add_child(button)
	editor_scale_label = Label.new()
	editor_scale_label.text = "%d%%" % int(current_scale * 100.0)
	_editor_rows.add_child(editor_scale_label)

func enter_hud_editor() -> void:
	if is_editing_hud:
		return
	reset_inputs()
	_menu_open = false
	_menu_panel.visible = false
	_menu_shade.visible = false
	is_editing_hud = true
	_hold_pause()
	_set_editor_input(true)
	_schedule_layout()
	ui_blocked_changed.emit(true)

func exit_hud_editor(save: bool = true) -> void:
	if not is_editing_hud:
		return
	if save and not _save_hud_config():
		editor_scale_label.text = "Ошибка записи"
		return
	if not save:
		_load_saved_hud_config()
	reset_inputs()
	is_editing_hud = false
	_set_editor_input(false)
	_schedule_layout()
	_release_pause()
	ui_blocked_changed.emit(false)
	hud_editor_closed.emit()

func _set_editor_input(enabled: bool) -> void:
	steer_container.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	pedals_container.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for button: TouchButton in _all_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE if enabled else Control.MOUSE_FILTER_STOP
	steering_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE if enabled else Control.MOUSE_FILTER_STOP
	hud_editor_panel.visible = enabled
	top_bar.visible = not enabled
	look_area.mouse_filter = Control.MOUSE_FILTER_IGNORE if enabled else Control.MOUSE_FILTER_STOP

func _adjust_scale(delta: float) -> void:
	current_scale = clampf(current_scale + delta, 0.7, 1.5)
	editor_scale_label.text = "%d%%" % int(current_scale * 100.0)
	_schedule_layout()

func _reset_hud_layout() -> void:
	current_scale = 1.0
	editor_scale_label.text = "100%"
	_steer_offset = Vector2(20, -20)
	_pedals_offset = Vector2(-20, -20)
	_schedule_layout()

func _on_editor_drag(event: InputEvent, target: String) -> void:
	if not is_editing_hud:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _editor_touch == -1:
			_editor_touch = event.index
			_editor_target = target
		elif not event.pressed and event.index == _editor_touch:
			_editor_touch = -1
			_editor_target = ""
		return
	var movement: Vector2 = Vector2.ZERO
	var cluster: Control = steer_container if target == "SteerCluster" else pedals_container
	if event is InputEventScreenDrag and event.index == _editor_touch and target == _editor_target:
		movement = event.relative * cluster.scale.x / maxf(0.1, _unit)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		movement = event.relative * cluster.scale.x / maxf(0.1, _unit)
	if movement != Vector2.ZERO:
		if target == "SteerCluster":
			_steer_offset += movement
		else:
			_pedals_offset += movement
		_apply_safe_area()
		get_viewport().set_input_as_handled()

func _on_viewport_changed() -> void:
	reset_inputs()
	_schedule_layout()

func _schedule_layout() -> void:
	if _layout_pending or not is_inside_tree():
		return
	_layout_pending = true
	_apply_safe_area.call_deferred()

func _apply_safe_area() -> void:
	_layout_pending = false
	if not is_instance_valid(root_control) or not is_inside_tree():
		return
	var safe: Rect2 = MobileLayoutUtil.safe_rect_for(root_control)
	var layout: Dictionary = MobileLayoutUtil.controls(safe, current_scale, _steer_offset, _pedals_offset)
	_unit = float(layout["unit"])
	var scale_factor: float = float(layout["scale"])
	steer_container.position = layout["steer"].position
	steer_container.scale = Vector2.ONE * scale_factor
	pedals_container.position = layout["pedals"].position
	pedals_container.scale = Vector2.ONE * scale_factor
	# Persist the clamped layout, not coordinates that already sit off-screen.
	_steer_offset = Vector2((steer_container.position.x - safe.position.x) / _unit,
		(steer_container.position.y + MobileLayoutUtil.STEER_SIZE.y * scale_factor - safe.end.y) / _unit)
	_pedals_offset = Vector2((pedals_container.position.x + MobileLayoutUtil.PEDALS_SIZE.x * scale_factor - safe.end.x) / _unit,
		(pedals_container.position.y + MobileLayoutUtil.PEDALS_SIZE.y * scale_factor - safe.end.y) / _unit)
	MobileLayoutUtil.place(camera_btn, layout["camera"])
	MobileLayoutUtil.place(menu_btn, layout["menu"])
	camera_btn.font_size = maxi(12, int(26.0 * _unit))
	menu_btn.font_size = maxi(12, int(26.0 * _unit))
	camera_btn.queue_redraw()
	menu_btn.queue_redraw()
	var menu_width: float = minf(safe.size.x - 32.0 * _unit, 328.0 * _unit)
	MobileLayoutUtil.place(_menu_panel, Rect2(Vector2(safe.end.x - menu_width - 16.0 * _unit, safe.position.y + 112.0 * _unit), Vector2(menu_width, safe.size.y - 132.0 * _unit)))
	for row: Node in _menu_rows.get_children():
		if row is Control:
			var item: Control = row as Control
			item.custom_minimum_size.y = 88.0 * _unit
			item.add_theme_font_size_override("font_size", maxi(14, int(28.0 * _unit)))
	for row: Node in _challenge_rows.get_children():
		if row is Control:
			var item: Control = row as Control
			item.custom_minimum_size.y = 88.0 * _unit
			item.add_theme_font_size_override("font_size", maxi(14, int(28.0 * _unit)))
	var editor_width: float = minf(safe.size.x - 32.0 * _unit, 1000.0 * _unit)
	MobileLayoutUtil.place(hud_editor_panel, Rect2(Vector2(safe.get_center().x - editor_width * 0.5, safe.position.y + 16.0 * _unit), Vector2(editor_width, 112.0 * _unit)))
	for item: Node in _editor_rows.get_children():
		if item is Control:
			var control: Control = item as Control
			control.custom_minimum_size.y = 88.0 * _unit
			control.add_theme_font_size_override("font_size", maxi(12, int(26.0 * _unit)))
	_update_visibility()

func _toggle_steering_mode() -> void:
	reset_inputs()
	current_steering_mode = SteeringMode.WHEEL if current_steering_mode == SteeringMode.ARROWS else SteeringMode.ARROWS
	if not is_editing_hud:
		_save_hud_config()

func _update_visibility() -> void:
	if not is_instance_valid(arrow_left) or not is_instance_valid(steering_wheel):
		return
	var arrows: bool = current_steering_mode == SteeringMode.ARROWS
	arrow_left.visible = arrows
	arrow_right.visible = arrows
	steering_wheel.visible = not arrows
	mode_button.text = "РУЛЬ" if arrows else "СТРЕЛКИ"
	mode_button.queue_redraw()
	update_transmission_ui(_transmission_auto)

func update_transmission_ui(is_auto: bool) -> void:
	_transmission_auto = is_auto
	if is_instance_valid(trans_mode_btn):
		trans_mode_btn.text = "АКПП" if is_auto else "МКПП"
		trans_mode_btn.queue_redraw()
	if is_instance_valid(shift_up_btn):
		shift_up_btn.visible = not is_auto or is_editing_hud
		shift_down_btn.visible = not is_auto or is_editing_hud

func get_steering_input() -> float:
	if is_driving_blocked():
		return 0.0
	if current_steering_mode == SteeringMode.WHEEL:
		return -steering_wheel.steering_value if is_instance_valid(steering_wheel) else 0.0
	return (1.0 if arrow_left.is_pressed else 0.0) - (1.0 if arrow_right.is_pressed else 0.0)

func is_wheel_active() -> bool:
	return not is_driving_blocked() and current_steering_mode == SteeringMode.WHEEL and is_instance_valid(steering_wheel) and steering_wheel.is_dragging

func get_throttle_input() -> float:
	return 1.0 if not is_driving_blocked() and is_instance_valid(gas_pedal) and gas_pedal.is_pressed else 0.0

func get_brake_input() -> float:
	return 1.0 if not is_driving_blocked() and is_instance_valid(brake_pedal) and brake_pedal.is_pressed else 0.0

func get_handbrake_input() -> float:
	return 1.0 if not is_driving_blocked() and is_instance_valid(handbrake_btn) and handbrake_btn.is_pressed else 0.0

func reset_inputs() -> void:
	for button: TouchButton in _all_buttons:
		if is_instance_valid(button):
			button.reset_input()
	if is_instance_valid(steering_wheel):
		steering_wheel.reset_input()
	active_look_index = -1
	is_looking = false
	_editor_touch = -1
	_editor_target = ""
	if is_instance_valid(camera):
		camera.stop_orbit()

func _on_look_area_gui_input(event: InputEvent) -> void:
	if is_driving_blocked():
		return
	if event is InputEventScreenTouch:
		if event.pressed and active_look_index == -1:
			active_look_index = event.index
			is_looking = true
		elif not event.pressed and event.index == active_look_index:
			_end_look()
	elif event is InputEventScreenDrag and is_looking and event.index == active_look_index:
		if is_instance_valid(camera):
			camera.rotate_orbit(event.relative)
		look_dragged.emit(event.relative)
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.pressed and active_look_index == -1:
			active_look_index = 9998
			is_looking = true
		elif not event.pressed and active_look_index == 9998:
			_end_look()
	elif event is InputEventMouseMotion and is_looking and active_look_index == 9998:
		if is_instance_valid(camera):
			camera.rotate_orbit(event.relative)
		look_dragged.emit(event.relative)

func _end_look() -> void:
	active_look_index = -1
	is_looking = false
	if is_instance_valid(camera):
		camera.stop_orbit()
	look_ended.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and event.index == active_look_index:
		_end_look()
	elif event is InputEventMouseButton and not event.pressed and active_look_index == 9998:
		_end_look()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		reset_inputs()
		if is_editing_hud:
			_save_hud_config()

func _exit_tree() -> void:
	_release_pause()

func _adjust_seat(delta_height: float) -> void:
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d() as ProVehicleCamera
	if is_instance_valid(camera):
		camera.adjust_seat(delta_height, 0.0)

func _on_editor_action(action: String) -> void:
	match action:
		"smaller":
			_adjust_scale(-0.1)
		"larger":
			_adjust_scale(0.1)
		"mode":
			_toggle_steering_mode()
		"reset":
			_reset_hud_layout()
		"save":
			exit_hud_editor(true)
