class_name DebugTuningUI
extends CanvasLayer

## Comprehensive In-Game Physics Tuning Panel & Live HUD
## Allows live tweaking of all suspension, tires, engine, steering, and aero parameters.
## Toggled via F1, Tab, or on-screen button.

var vehicle: Vehicle
var player_controller: Node

var _is_open: bool = false
var _main_panel: PanelContainer
var _toggle_btn: Button
var _status_lbl: Label
var _search_input: LineEdit
var _items_vbox: VBoxContainer

# Compact Live HUD
var _hud_panel: PanelContainer
var _lbl_fps: Label
var _lbl_speed: Label
var _lbl_rpm: Label
var _lbl_gear: Label

var _initial_values: Dictionary = {}
var _prop_controls: Dictionary = {}

const CATEGORIES := [
	{
		"name": "🛞 Шины и Сцепление (Tires & Road Grip)",
		"props": [
			{"id": "road_friction", "name": "Трение асфальта (Road Friction)", "min": 0.5, "max": 10.0, "step": 0.05, "type": "road_dict", "dict": "coefficient_of_friction"},
			{"id": "road_stiffness", "name": "Жесткость шин на асфальте (Tire Stiffness)", "min": 1.0, "max": 50.0, "step": 0.5, "type": "road_dict", "dict": "tire_stiffnesses"},
			{"id": "road_lateral_assist", "name": "Боковой зацеп в заносе (Lateral Assist)", "min": 0.0, "max": 0.8, "step": 0.01, "type": "road_dict", "dict": "lateral_grip_assist"},
			{"id": "road_longitudinal_ratio", "name": "Продольный зацеп к боковому (Long Grip Ratio)", "min": 0.1, "max": 2.0, "step": 0.05, "type": "road_dict", "dict": "longitudinal_grip_ratio"},
			{"id": "road_rolling_resistance", "name": "Сопротивление качению (Rolling Resist)", "min": 0.1, "max": 5.0, "step": 0.1, "type": "road_dict", "dict": "rolling_resistance"},
			{"id": "contact_patch", "name": "Пятно контакта (Contact Patch, m)", "min": 0.05, "max": 0.5, "step": 0.01, "type": "float"},
			{"id": "braking_grip_multiplier", "name": "Множитель зацепа при торможении", "min": 0.5, "max": 4.0, "step": 0.05, "type": "float"},
			{"id": "wheel_to_body_torque_multiplier", "name": "Реактивный момент колес на кузов", "min": 0.0, "max": 3.0, "step": 0.05, "type": "float"},
			{"id": "front_tire_radius", "name": "Передний радиус колеса (m)", "min": 0.2, "max": 0.6, "step": 0.01, "type": "float"},
			{"id": "rear_tire_radius", "name": "Задний радиус колеса (m)", "min": 0.2, "max": 0.6, "step": 0.01, "type": "float"},
			{"id": "front_tire_width", "name": "Передняя ширина шины (mm)", "min": 155.0, "max": 355.0, "step": 5.0, "type": "float"},
			{"id": "rear_tire_width", "name": "Задняя ширина шины (mm)", "min": 155.0, "max": 355.0, "step": 5.0, "type": "float"},
			{"id": "front_wheel_mass", "name": "Масса переднего колеса (kg)", "min": 5.0, "max": 50.0, "step": 1.0, "type": "float"},
			{"id": "rear_wheel_mass", "name": "Масса заднего колеса (kg)", "min": 5.0, "max": 50.0, "step": 1.0, "type": "float"}
		]
	},
	{
		"name": "🎯 Рулевое управление и Ассистенты (Steering)",
		"props": [
			{"id": "max_steering_angle", "name": "Макс. выворот колес (Max Steer Angle, deg)", "min": 15.0, "max": 70.0, "step": 0.5, "type": "deg"},
			{"id": "steering_speed", "name": "Скорость поворота колес (Steer Speed)", "min": 0.5, "max": 30.0, "step": 0.5, "type": "float"},
			{"id": "countersteer_speed", "name": "Скорость возврата руля (Countersteer Speed)", "min": 1.0, "max": 40.0, "step": 0.5, "type": "float"},
			{"id": "countersteer_assist", "name": "Ассистент контр-руления (Countersteer Assist)", "min": 0.0, "max": 3.0, "step": 0.05, "type": "float"},
			{"id": "steering_speed_decay", "name": "Затухание руля на скорости (Speed Decay)", "min": 0.01, "max": 1.0, "step": 0.01, "type": "float"},
			{"id": "steering_slip_assist", "name": "Порог заноса руля (Slip Assist)", "min": 0.0, "max": 1.0, "step": 0.02, "type": "float"},
			{"id": "steering_exponent", "name": "Нелинейность руля (Steering Exponent)", "min": 1.0, "max": 3.0, "step": 0.05, "type": "float"},
			{"id": "front_steering_ratio", "name": "Коэф. переднего подруливания", "min": 0.0, "max": 2.0, "step": 0.05, "type": "float"},
			{"id": "rear_steering_ratio", "name": "Коэф. заднего подруливания", "min": -0.5, "max": 0.5, "step": 0.02, "type": "float"},
			{"id": "steer_speed", "name": "Плавность клавиатуры/джойстика (Input Steer)", "min": 1.0, "max": 30.0, "step": 0.5, "type": "float", "is_controller": true},
			{"id": "return_speed", "name": "Плавность возврата клавиатуры (Input Return)", "min": 1.0, "max": 30.0, "step": 0.5, "type": "float", "is_controller": true}
		]
	},
	{
		"name": "🔩 Подвеска, Жесткость и Клиренс (Suspension)",
		"props": [
			{"id": "front_spring_length", "name": "Передний ход подвески (Spring Length, m)", "min": 0.05, "max": 0.5, "step": 0.01, "type": "float"},
			{"id": "rear_spring_length", "name": "Задний ход подвески (Spring Length, m)", "min": 0.05, "max": 0.5, "step": 0.01, "type": "float"},
			{"id": "front_resting_ratio", "name": "Передний клиренс покоя (Resting Ratio)", "min": 0.1, "max": 0.9, "step": 0.02, "type": "float"},
			{"id": "rear_resting_ratio", "name": "Задний клиренс покоя (Resting Ratio)", "min": 0.1, "max": 0.9, "step": 0.02, "type": "float"},
			{"id": "front_damping_ratio", "name": "Переднее демпфирование (Damping Ratio)", "min": 0.05, "max": 2.0, "step": 0.02, "type": "float"},
			{"id": "rear_damping_ratio", "name": "Заднее демпфирование (Damping Ratio)", "min": 0.05, "max": 2.0, "step": 0.02, "type": "float"},
			{"id": "front_bump_damp_multiplier", "name": "Передний сжатие (Bump Multiplier)", "min": 0.1, "max": 3.0, "step": 0.05, "type": "float"},
			{"id": "rear_bump_damp_multiplier", "name": "Задний сжатие (Bump Multiplier)", "min": 0.1, "max": 3.0, "step": 0.05, "type": "float"},
			{"id": "front_rebound_damp_multiplier", "name": "Передний отбой (Rebound Multiplier)", "min": 0.1, "max": 3.0, "step": 0.05, "type": "float"},
			{"id": "rear_rebound_damp_multiplier", "name": "Задний отбой (Rebound Multiplier)", "min": 0.1, "max": 3.0, "step": 0.05, "type": "float"},
			{"id": "front_arb_ratio", "name": "Передний стабилизатор (Anti-Roll Bar)", "min": 0.0, "max": 2.0, "step": 0.05, "type": "float"},
			{"id": "rear_arb_ratio", "name": "Задний стабилизатор (Anti-Roll Bar)", "min": 0.0, "max": 2.0, "step": 0.05, "type": "float"},
			{"id": "front_bump_stop_multiplier", "name": "Передний отбойник (Bump Stop)", "min": 0.5, "max": 5.0, "step": 0.1, "type": "float"},
			{"id": "rear_bump_stop_multiplier", "name": "Задний отбойник (Bump Stop)", "min": 0.5, "max": 5.0, "step": 0.1, "type": "float"}
		]
	},
	{
		"name": "📐 Геометрия Колес (Camber & Toe)",
		"props": [
			{"id": "front_camber", "name": "Передний развал (Front Camber, deg)", "min": -12.0, "max": 12.0, "step": 0.2, "type": "deg"},
			{"id": "rear_camber", "name": "Задний развал (Rear Camber, deg)", "min": -12.0, "max": 12.0, "step": 0.2, "type": "deg"},
			{"id": "front_toe", "name": "Переднее схождение (Front Toe, deg)", "min": -5.0, "max": 5.0, "step": 0.1, "type": "deg"},
			{"id": "rear_toe", "name": "Заднее схождение (Rear Toe, deg)", "min": -5.0, "max": 5.0, "step": 0.1, "type": "deg"}
		]
	},
	{
		"name": "⚖️ Масса, Развесовка и Центр тяжести (Chassis)",
		"props": [
			{"id": "vehicle_mass", "name": "Масса автомобиля (Mass, kg)", "min": 500.0, "max": 4000.0, "step": 25.0, "type": "float"},
			{"id": "front_weight_distribution", "name": "Развесовка перед/зад (Weight Dist)", "min": 0.2, "max": 0.8, "step": 0.01, "type": "float"},
			{"id": "center_of_gravity_height_offset", "name": "Смещение ЦТ по высоте (COG Height, m)", "min": -0.8, "max": 0.8, "step": 0.02, "type": "float"},
			{"id": "inertia_multiplier", "name": "Множитель инерции кузова (Inertia)", "min": 0.2, "max": 4.0, "step": 0.05, "type": "float"}
		]
	},
	{
		"name": "🏎️ Двигатель и Трансмиссия (Engine & Trans)",
		"props": [
			{"id": "max_torque", "name": "Крутящий момент (Max Torque, Nm)", "min": 50.0, "max": 2500.0, "step": 10.0, "type": "float"},
			{"id": "max_rpm", "name": "Максимальные обороты (Max RPM)", "min": 3000.0, "max": 12000.0, "step": 100.0, "type": "float"},
			{"id": "idle_rpm", "name": "Холостые обороты (Idle RPM)", "min": 500.0, "max": 2500.0, "step": 50.0, "type": "float"},
			{"id": "clutch_out_rpm", "name": "Обороты сцепления (Clutch RPM)", "min": 1000.0, "max": 6000.0, "step": 100.0, "type": "float"},
			{"id": "motor_drag", "name": "Внутреннее сопротивление (Motor Drag)", "min": 0.0001, "max": 0.05, "step": 0.0005, "type": "float"},
			{"id": "motor_brake", "name": "Торможение мотором (Motor Brake)", "min": 0.0, "max": 50.0, "step": 1.0, "type": "float"},
			{"id": "motor_moment", "name": "Инерция маховика (Motor Moment)", "min": 0.05, "max": 3.0, "step": 0.05, "type": "float"},
			{"id": "max_clutch_torque_ratio", "name": "Коэф. зажима сцепления (Clutch Ratio)", "min": 0.5, "max": 4.0, "step": 0.1, "type": "float"},
			{"id": "final_drive", "name": "Главная пара (Final Drive)", "min": 1.0, "max": 7.0, "step": 0.05, "type": "float"},
			{"id": "reverse_ratio", "name": "Передаточное число задней передачи", "min": 1.0, "max": 6.0, "step": 0.1, "type": "float"},
			{"id": "shift_time", "name": "Скорость переключения передач (s)", "min": 0.02, "max": 1.0, "step": 0.02, "type": "float"},
			{"id": "front_torque_split", "name": "Привод (0=RWD, 0.5=AWD, 1=FWD)", "min": 0.0, "max": 1.0, "step": 0.05, "type": "float"},
			{"id": "front_locking_differential_engage_torque", "name": "Блокировка переднего диффа (Nm)", "min": 0.0, "max": 1000.0, "step": 20.0, "type": "float"},
			{"id": "rear_locking_differential_engage_torque", "name": "Блокировка заднего диффа (Nm)", "min": 0.0, "max": 1000.0, "step": 20.0, "type": "float"}
		]
	},
	{
		"name": "🛑 Торможение и АБС (Brakes & ABS)",
		"props": [
			{"id": "brake_force_multiplier", "name": "Сила тормозов (Brake Force Mult)", "min": 0.1, "max": 5.0, "step": 0.05, "type": "float"},
			{"id": "braking_speed", "name": "Скорость нарастания давления тормозов", "min": 1.0, "max": 40.0, "step": 1.0, "type": "float"},
			{"id": "front_brake_bias", "name": "Баланс тормозов (0..1, -1=auto)", "min": -1.0, "max": 1.0, "step": 0.02, "type": "float"},
			{"id": "traction_control_max_slip", "name": "TCS: антипробуксовка (-1=off)", "min": -1.0, "max": 25.0, "step": 0.5, "type": "float"},
			{"id": "front_abs_pulse_time", "name": "Передняя АБС: время пульсации (s)", "min": 0.01, "max": 0.2, "step": 0.01, "type": "float"},
			{"id": "rear_abs_pulse_time", "name": "Задняя АБС: время пульсации (s)", "min": 0.01, "max": 0.2, "step": 0.01, "type": "float"}
		]
	},
	{
		"name": "🛡️ Система стабилизации (ESP & Stability)",
		"props": [
			{"id": "enable_stability", "name": "Включить ESP (Enable Stability)", "type": "bool"},
			{"id": "stability_yaw_strength", "name": "Сила выравнивания ESP (Yaw Strength)", "min": 0.0, "max": 30.0, "step": 0.5, "type": "float"},
			{"id": "stability_yaw_engage_angle", "name": "Угол срабатывания ESP (Engage Angle)", "min": 0.0, "max": 1.0, "step": 0.02, "type": "float"},
			{"id": "stability_yaw_ground_multiplier", "name": "Множитель зацепа на земле", "min": 0.0, "max": 10.0, "step": 0.2, "type": "float"},
			{"id": "stability_upright_spring", "name": "Выравнивание в воздухе (Spring)", "min": 0.0, "max": 5.0, "step": 0.1, "type": "float"},
			{"id": "stability_upright_damping", "name": "Демпфирование в воздухе (Damping)", "min": 100.0, "max": 5000.0, "step": 100.0, "type": "float"}
		]
	},
	{
		"name": "💨 Аэродинамика (Aero & Drag)",
		"props": [
			{"id": "coefficient_of_drag", "name": "Коэффициент лобового сопротивления (Cd)", "min": 0.05, "max": 1.5, "step": 0.01, "type": "float"},
			{"id": "frontal_area", "name": "Лобовая площадь (Frontal Area, m²)", "min": 0.5, "max": 5.0, "step": 0.1, "type": "float"},
			{"id": "air_density", "name": "Плотность воздуха (Air Density)", "min": 0.5, "max": 2.0, "step": 0.05, "type": "float"}
		]
	}
]

func _ready() -> void:
	layer = 30 # Topmost UI layer
	_cache_initial_values()
	_build_ui()
	_update_all_values()

func _process(_delta: float) -> void:
	if not is_instance_valid(vehicle):
		return
		
	if _lbl_fps:
		_lbl_fps.text = "FPS: %d" % Engine.get_frames_per_second()
	if _lbl_speed:
		_lbl_speed.text = "Speed: %d km/h" % int(vehicle.speed * 3.6)
	if _lbl_rpm:
		_lbl_rpm.text = "RPM: %d" % int(vehicle.motor_rpm)
	if _lbl_gear:
		var g = vehicle.current_gear
		_lbl_gear.text = "Gear: %s" % ("R" if g == -1 else ("N" if g == 0 else str(g)))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 or event.keycode == KEY_TAB or event.keycode == KEY_QUOTELEFT:
			toggle_ui()
			get_viewport().set_input_as_handled()

func toggle_ui() -> void:
	_is_open = not _is_open
	_main_panel.visible = _is_open
	_toggle_btn.text = "✖ Закрыть тюнинг" if _is_open else "⚙ ТЮНИНГ ФИЗИКИ (F1/Tab)"
	_toggle_btn.modulate = Color(1.0, 0.4, 0.4) if _is_open else Color(1.0, 1.0, 1.0)
	
	if _is_open:
		_update_all_values()

func _cache_initial_values() -> void:
	if not is_instance_valid(vehicle):
		return
	for cat in CATEGORIES:
		for prop in cat["props"]:
			var pid: String = prop["id"]
			var ptype: String = prop.get("type", "float")
			var is_ctrl: bool = prop.get("is_controller", false)
			var target = player_controller if is_ctrl and is_instance_valid(player_controller) else vehicle
			if not is_instance_valid(target):
				continue
			
			if ptype == "road_dict":
				var dict_name: String = prop["dict"]
				var dict = target.get(dict_name)
				if dict is Dictionary and dict.has("Road"):
					_initial_values[pid] = dict["Road"]
			elif ptype == "deg":
				var rad_val = target.get(pid)
				if rad_val != null:
					_initial_values[pid] = rad_to_deg(rad_val)
			else:
				var val = target.get(pid)
				if val != null:
					_initial_values[pid] = val

func _build_ui() -> void:
	var root := Control.new()
	root.name = "RootTuningOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Live Minimal HUD (Top Left) ---
	_hud_panel = PanelContainer.new()
	_hud_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hud_panel.offset_left = 15.0
	_hud_panel.offset_top = 15.0
	_hud_panel.offset_right = 160.0
	_hud_panel.offset_bottom = 115.0
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.06, 0.08, 0.12, 0.65)
	hud_style.border_color = Color(0.2, 0.5, 0.9, 0.5)
	hud_style.set_border_width_all(1)
	hud_style.set_corner_radius_all(8)
	hud_style.content_margin_left = 10
	hud_style.content_margin_top = 8
	hud_style.content_margin_right = 10
	hud_style.content_margin_bottom = 8
	_hud_panel.add_theme_stylebox_override("panel", hud_style)
	root.add_child(_hud_panel)

	var hud_vbox := VBoxContainer.new()
	hud_vbox.set("theme_override_constants/separation", 3)
	_hud_panel.add_child(hud_vbox)

	_lbl_fps = Label.new()
	_lbl_fps.text = "FPS: 60"
	_lbl_fps.add_theme_font_size_override("font_size", 13)
	_lbl_fps.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	hud_vbox.add_child(_lbl_fps)

	_lbl_speed = Label.new()
	_lbl_speed.text = "Speed: 0 km/h"
	_lbl_speed.add_theme_font_size_override("font_size", 14)
	_lbl_speed.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	hud_vbox.add_child(_lbl_speed)

	_lbl_rpm = Label.new()
	_lbl_rpm.text = "RPM: 0"
	_lbl_rpm.add_theme_font_size_override("font_size", 12)
	_lbl_rpm.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hud_vbox.add_child(_lbl_rpm)

	_lbl_gear = Label.new()
	_lbl_gear.text = "Gear: N"
	_lbl_gear.add_theme_font_size_override("font_size", 12)
	_lbl_gear.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	hud_vbox.add_child(_lbl_gear)

	# --- Floating Top-Middle Button to Open/Close Tuning ---
	_toggle_btn = Button.new()
	_toggle_btn.text = "⚙ ТЮНИНГ ФИЗИКИ (F1/Tab)"
	_toggle_btn.anchor_left = 0.5
	_toggle_btn.anchor_right = 0.5
	_toggle_btn.offset_left = -110.0
	_toggle_btn.offset_top = 12.0
	_toggle_btn.offset_right = 110.0
	_toggle_btn.offset_bottom = 44.0
	
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.14, 0.22, 0.85)
	btn_style.border_color = Color(0.35, 0.65, 1.0, 0.9)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(8)
	btn_style.content_margin_left = 12
	btn_style.content_margin_right = 12
	_toggle_btn.add_theme_stylebox_override("normal", btn_style)
	_toggle_btn.pressed.connect(toggle_ui)
	root.add_child(_toggle_btn)

	# --- Slide-out Tuning Panel on the Right ---
	_main_panel = PanelContainer.new()
	_main_panel.name = "MainTuningPanel"
	_main_panel.anchor_left = 1.0
	_main_panel.anchor_right = 1.0
	_main_panel.anchor_top = 0.0
	_main_panel.anchor_bottom = 1.0
	_main_panel.offset_left = -480.0
	_main_panel.offset_right = 0.0
	_main_panel.offset_top = 0.0
	_main_panel.offset_bottom = 0.0
	_main_panel.visible = _is_open
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.13, 0.96)
	panel_style.border_color = Color(0.2, 0.28, 0.42, 0.9)
	panel_style.border_width_left = 2
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	_main_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_main_panel)

	var panel_vbox := VBoxContainer.new()
	panel_vbox.set("theme_override_constants/separation", 8)
	_main_panel.add_child(panel_vbox)

	# Header
	var header_hbox := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "🔧 ТЮНИНГ ФИЗИКИ В РЕАЛЬНОМ ВРЕМЕНИ"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✖"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(toggle_ui)
	header_hbox.add_child(close_btn)
	panel_vbox.add_child(header_hbox)

	# Action Buttons
	var actions_hbox := HBoxContainer.new()
	actions_hbox.set("theme_override_constants/separation", 8)

	var copy_btn := Button.new()
	copy_btn.text = "📋 СКОПИРОВАТЬ НАСТРОЙКИ (JSON)"
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_btn.custom_minimum_size = Vector2(0, 36)
	var copy_style := StyleBoxFlat.new()
	copy_style.bg_color = Color(0.12, 0.52, 0.25, 0.95)
	copy_style.set_corner_radius_all(6)
	copy_btn.add_theme_stylebox_override("normal", copy_style)
	copy_btn.pressed.connect(_on_copy_settings_pressed)
	actions_hbox.add_child(copy_btn)

	var reset_btn := Button.new()
	reset_btn.text = "🔄 Сброс"
	reset_btn.custom_minimum_size = Vector2(85, 36)
	reset_btn.pressed.connect(_on_reset_pressed)
	actions_hbox.add_child(reset_btn)

	panel_vbox.add_child(actions_hbox)

	# Status message
	_status_lbl = Label.new()
	_status_lbl.text = ""
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 12)
	_status_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	panel_vbox.add_child(_status_lbl)

	# Search Filter
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "🔍 Быстрый поиск параметра (например: friction, camber, torque)..."
	_search_input.clear_button_enabled = true
	_search_input.text_changed.connect(_on_filter_changed)
	panel_vbox.add_child(_search_input)

	# Scroll Container for Categories
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_vbox.add_child(scroll)

	_items_vbox = VBoxContainer.new()
	_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_vbox.set("theme_override_constants/separation", 12)
	scroll.add_child(_items_vbox)

	for cat in CATEGORIES:
		_build_category_section(cat)

func _build_category_section(cat: Dictionary) -> void:
	var cat_box := VBoxContainer.new()
	cat_box.name = "Category_" + cat["name"]
	cat_box.set("theme_override_constants/separation", 6)
	_items_vbox.add_child(cat_box)

	var cat_header := PanelContainer.new()
	var cat_style := StyleBoxFlat.new()
	cat_style.bg_color = Color(0.12, 0.17, 0.26, 0.85)
	cat_style.content_margin_left = 8
	cat_style.content_margin_right = 8
	cat_style.content_margin_top = 4
	cat_style.content_margin_bottom = 4
	cat_style.set_corner_radius_all(4)
	cat_header.add_theme_stylebox_override("panel", cat_style)

	var cat_lbl := Label.new()
	cat_lbl.text = cat["name"]
	cat_lbl.add_theme_font_size_override("font_size", 13)
	cat_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	cat_header.add_child(cat_lbl)
	cat_box.add_child(cat_header)

	for prop in cat["props"]:
		_build_property_row(cat_box, prop)

func _build_property_row(parent: VBoxContainer, prop: Dictionary) -> void:
	var pid: String = prop["id"]
	var ptype: String = prop.get("type", "float")
	
	var row := VBoxContainer.new()
	row.name = "PropRow_" + pid
	row.set("theme_override_constants/separation", 2)
	parent.add_child(row)

	var top_hbox := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = prop["name"]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.91, 0.95))
	top_hbox.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.name = "ValLabel"
	val_lbl.text = "0.00"
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	top_hbox.add_child(val_lbl)
	row.add_child(top_hbox)

	if ptype == "bool":
		var check := CheckBox.new()
		check.text = "Включено"
		check.toggled.connect(func(pressed: bool):
			_on_bool_changed(prop, pressed)
		)
		row.add_child(check)
		_prop_controls[pid] = {
			"check": check,
			"val_lbl": val_lbl,
			"row": row,
			"prop": prop
		}
	else:
		var ctrl_hbox := HBoxContainer.new()
		ctrl_hbox.set("theme_override_constants/separation", 8)

		var slider := HSlider.new()
		slider.min_value = prop.get("min", 0.0)
		slider.max_value = prop.get("max", 100.0)
		slider.step = prop.get("step", 0.1)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(0, 22)
		ctrl_hbox.add_child(slider)

		var edit := LineEdit.new()
		edit.custom_minimum_size = Vector2(75, 22)
		edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ctrl_hbox.add_child(edit)
		row.add_child(ctrl_hbox)

		slider.value_changed.connect(func(val: float):
			_on_slider_changed(prop, val)
		)

		edit.text_submitted.connect(func(new_text: String):
			_on_edit_submitted(prop, new_text)
		)

		_prop_controls[pid] = {
			"slider": slider,
			"edit": edit,
			"val_lbl": val_lbl,
			"row": row,
			"prop": prop
		}

func _on_slider_changed(prop: Dictionary, new_val: float) -> void:
	var pid: String = prop["id"]
	_set_prop_value(prop, new_val)
	
	if _prop_controls.has(pid):
		var ctrl = _prop_controls[pid]
		ctrl["edit"].text = "%.3f" % new_val if prop.get("step", 0.1) < 0.1 else "%.2f" % new_val
		ctrl["val_lbl"].text = "%.2f" % new_val

func _on_edit_submitted(prop: Dictionary, text: String) -> void:
	if not text.is_valid_float():
		return
	var val: float = text.to_float()
	var pid: String = prop["id"]
	_set_prop_value(prop, val)
	
	if _prop_controls.has(pid):
		var ctrl = _prop_controls[pid]
		ctrl["slider"].set_value_no_signal(val)
		ctrl["val_lbl"].text = "%.2f" % val

func _on_bool_changed(prop: Dictionary, pressed: bool) -> void:
	var pid: String = prop["id"]
	_set_prop_value(prop, pressed)
	if _prop_controls.has(pid):
		_prop_controls[pid]["val_lbl"].text = "ON" if pressed else "OFF"

func _set_prop_value(prop: Dictionary, val: Variant) -> void:
	if not is_instance_valid(vehicle):
		return
	var pid: String = prop["id"]
	var ptype: String = prop.get("type", "float")
	var is_ctrl: bool = prop.get("is_controller", false)
	var target = player_controller if is_ctrl and is_instance_valid(player_controller) else vehicle
	if not is_instance_valid(target):
		return

	if ptype == "road_dict":
		var dict_name: String = prop["dict"]
		var dict = target.get(dict_name)
		if dict is Dictionary:
			var fval := float(val)
			for k in dict.keys():
				dict[k] = fval
			dict["Road"] = fval
			dict["Dirt"] = fval
			dict["road_surface"] = fval
			target.set(dict_name, dict)
			
		# Instantly apply to all live wheels
		for wheel in vehicle.wheel_array:
			if not is_instance_valid(wheel):
				continue
			var fval := float(val)
			if pid == "road_friction":
				wheel.current_cof = fval
				wheel.coefficient_of_friction = target.get("coefficient_of_friction")
			elif pid == "road_stiffness":
				wheel.current_tire_stiffness = 1000000.0 + 8000000.0 * fval
				wheel.tire_stiffnesses = target.get("tire_stiffnesses")
			elif pid == "road_lateral_assist":
				wheel.current_lateral_grip_assist = fval
				wheel.lateral_grip_assist = target.get("lateral_grip_assist")
			elif pid == "road_longitudinal_ratio":
				wheel.current_longitudinal_grip_ratio = fval
				wheel.longitudinal_grip_ratio = target.get("longitudinal_grip_ratio")
			elif pid == "road_rolling_resistance":
				wheel.current_rolling_resistance = fval
				wheel.rolling_resistance = target.get("rolling_resistance")

	elif ptype == "deg":
		var rad: float = deg_to_rad(float(val))
		target.set(pid, rad)
		if pid == "front_camber":
			_apply_visual_camber(true, float(val))
		elif pid == "rear_camber":
			_apply_visual_camber(false, float(val))
		elif pid == "front_toe":
			if vehicle.front_left_wheel: vehicle.front_left_wheel.toe = -rad
			if vehicle.front_right_wheel: vehicle.front_right_wheel.toe = rad
		elif pid == "rear_toe":
			if vehicle.rear_left_wheel: vehicle.rear_left_wheel.toe = -rad
			if vehicle.rear_right_wheel: vehicle.rear_right_wheel.toe = rad

	elif ptype == "bool":
		target.set(pid, bool(val))

	else:
		var fval := float(val)
		target.set(pid, fval)
		if pid == "max_torque" or pid == "max_clutch_torque_ratio":
			vehicle.max_clutch_torque = vehicle.max_torque * vehicle.max_clutch_torque_ratio
		elif pid == "vehicle_mass":
			vehicle.mass = fval
		elif pid == "front_torque_split":
			vehicle.front_torque_split = fval
		elif pid == "front_locking_differential_engage_torque" and vehicle.front_axle:
			vehicle.front_axle.differential_lock_torque = fval
		elif pid == "rear_locking_differential_engage_torque" and vehicle.rear_axle:
			vehicle.rear_axle.differential_lock_torque = fval
		elif pid in ["front_spring_length", "rear_spring_length", "front_damping_ratio", "rear_damping_ratio", "front_arb_ratio", "rear_arb_ratio", "front_resting_ratio", "rear_resting_ratio", "front_bump_damp_multiplier", "rear_bump_damp_multiplier", "front_rebound_damp_multiplier", "rear_rebound_damp_multiplier"]:
			_update_suspension_rates()

func _apply_visual_camber(is_front: bool, camber_deg: float) -> void:
	var camber_rad := deg_to_rad(absf(camber_deg))
	if is_front:
		var fl_mesh = vehicle.get_node_or_null("WheelFrontLeft/FrontLeftWheel")
		if fl_mesh: fl_mesh.rotation.z = camber_rad
		var fr_mesh = vehicle.get_node_or_null("WheelFrontRight/FrontRightWheel")
		if fr_mesh: fr_mesh.rotation.z = -camber_rad
	else:
		var rl_mesh = vehicle.get_node_or_null("WheelRearLeft/RearLeftWheel")
		if rl_mesh: rl_mesh.rotation.z = camber_rad
		var rr_mesh = vehicle.get_node_or_null("WheelRearRight/RearRightWheel")
		if rr_mesh: rr_mesh.rotation.z = -camber_rad

func _update_suspension_rates() -> void:
	if not is_instance_valid(vehicle):
		return
	var v_mass: float = float(vehicle.vehicle_mass)
	var f_dist: float = float(vehicle.front_weight_distribution)
	
	var front_weight_per_wheel: float = v_mass * f_dist * 4.9
	var front_spring_rate: float = vehicle.calculate_spring_rate(front_weight_per_wheel, vehicle.front_spring_length, vehicle.front_resting_ratio)
	var front_damping_rate: float = vehicle.calculate_damping(front_weight_per_wheel, front_spring_rate, vehicle.front_damping_ratio)
	
	if vehicle.front_axle != null:
		for wheel in vehicle.front_axle.wheels:
			if is_instance_valid(wheel):
				wheel.spring_length = vehicle.front_spring_length
				wheel.spring_rate = front_spring_rate
				wheel.antiroll = front_spring_rate * vehicle.front_arb_ratio
				wheel.slow_bump = front_damping_rate * vehicle.front_bump_damp_multiplier
				wheel.slow_rebound = front_damping_rate * vehicle.front_rebound_damp_multiplier

	var rear_weight_per_wheel: float = v_mass * (1.0 - f_dist) * 4.9
	var rear_spring_rate: float = vehicle.calculate_spring_rate(rear_weight_per_wheel, vehicle.rear_spring_length, vehicle.rear_resting_ratio)
	var rear_damping_rate: float = vehicle.calculate_damping(rear_weight_per_wheel, rear_spring_rate, vehicle.rear_damping_ratio)
	
	if vehicle.rear_axle != null:
		for wheel in vehicle.rear_axle.wheels:
			if is_instance_valid(wheel):
				wheel.spring_length = vehicle.rear_spring_length
				wheel.spring_rate = rear_spring_rate
				wheel.antiroll = rear_spring_rate * vehicle.rear_arb_ratio
				wheel.slow_bump = rear_damping_rate * vehicle.rear_bump_damp_multiplier
				wheel.slow_rebound = rear_damping_rate * vehicle.rear_rebound_damp_multiplier

func _get_prop_value(prop: Dictionary) -> Variant:
	if not is_instance_valid(vehicle):
		return 0.0
	var pid: String = prop["id"]
	var ptype: String = prop.get("type", "float")
	var is_ctrl: bool = prop.get("is_controller", false)
	var target = player_controller if is_ctrl and is_instance_valid(player_controller) else vehicle
	if not is_instance_valid(target):
		return 0.0

	if ptype == "road_dict":
		var dict_name: String = prop["dict"]
		var dict = target.get(dict_name)
		if dict is Dictionary and dict.has("Road"):
			return dict["Road"]
		return 0.0
	elif ptype == "deg":
		var rad_val = target.get(pid)
		return rad_to_deg(rad_val) if rad_val != null else 0.0
	elif ptype == "bool":
		return target.get(pid) if target.get(pid) != null else false
	else:
		var val = target.get(pid)
		return val if val != null else 0.0

func _update_all_values() -> void:
	for cat in CATEGORIES:
		for prop in cat["props"]:
			var pid: String = prop["id"]
			if not _prop_controls.has(pid):
				continue
			var ctrl = _prop_controls[pid]
			var val = _get_prop_value(prop)
			
			if prop.get("type") == "bool":
				ctrl["check"].set_pressed_no_signal(bool(val))
				ctrl["val_lbl"].text = "ON" if bool(val) else "OFF"
			else:
				var fval: float = float(val)
				ctrl["slider"].set_value_no_signal(fval)
				ctrl["edit"].text = "%.3f" % fval if prop.get("step", 0.1) < 0.1 else "%.2f" % fval
				ctrl["val_lbl"].text = "%.2f" % fval

func _on_reset_pressed() -> void:
	for cat in CATEGORIES:
		for prop in cat["props"]:
			var pid: String = prop["id"]
			if _initial_values.has(pid):
				_set_prop_value(prop, _initial_values[pid])
	_update_all_values()
	_show_status("🔄 Все параметры сброшены к начальным значениям", Color(1.0, 0.85, 0.3))

func _on_copy_settings_pressed() -> void:
	var export_dict := {}
	for cat in CATEGORIES:
		var cat_name: String = cat["name"].split("(")[0].strip_edges()
		var cat_data := {}
		for prop in cat["props"]:
			var pid: String = prop["id"]
			var val = _get_prop_value(prop)
			cat_data[pid] = val
		export_dict[cat_name] = cat_data

	var json_str := JSON.stringify(export_dict, "\t")
	DisplayServer.clipboard_set(json_str)
	print("--- VEHICLE TUNING EXPORT ---")
	print(json_str)
	print("-----------------------------")

	_show_status("✅ Скопировано в буфер обмена! Отправьте этот JSON.", Color(0.3, 1.0, 0.4))

func _show_status(text: String, color: Color) -> void:
	_status_lbl.text = text
	_status_lbl.add_theme_color_override("font_color", color)
	var timer := get_tree().create_timer(3.5)
	timer.timeout.connect(func():
		if _status_lbl.text == text:
			_status_lbl.text = ""
	)

func _on_filter_changed(new_text: String) -> void:
	var query := new_text.to_lower().strip_edges()
	for cat in CATEGORIES:
		for prop in cat["props"]:
			var pid: String = prop["id"]
			if not _prop_controls.has(pid):
				continue
			var row: Control = _prop_controls[pid]["row"]
			if query.is_empty():
				row.visible = true
			else:
				var prop_name: String = str(prop["name"])
				var cat_name: String = str(cat["name"])
				var match_name: bool = prop_name.to_lower().contains(query)
				var match_id: bool = pid.to_lower().contains(query)
				var match_cat: bool = cat_name.to_lower().contains(query)
				row.visible = match_name or match_id or match_cat
