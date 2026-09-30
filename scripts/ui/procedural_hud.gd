extends CanvasLayer
class_name ProceduralHUD

@export var vehicle: Vehicle

# Visual properties
@export_group("Gauge Appearance")
@export var gauge_radius: float = 85.0
@export var gauge_thickness: float = 12.0
@export var arc_bg_color: Color = Color(0.12, 0.15, 0.22, 0.6)
@export var arc_fill_color: Color = Color(0.2, 0.65, 1.0, 0.85)
@export var redline_color: Color = Color(1.0, 0.25, 0.25, 0.9)
@export var needle_color: Color = Color(1.0, 0.4, 0.2, 0.95)

# Smooth display values
var display_rpm: float = 0.0
var display_speed: float = 0.0
var drift_intensity: float = 0.0
var current_drift_angle: float = 0.0

var hud_control: Control

func _ready() -> void:
	layer = 9
	hud_control = Control.new()
	hud_control.name = "HUDCanvas"
	hud_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_control)
	hud_control.draw.connect(_on_hud_draw)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_instance_valid(vehicle):
		return
		
	# Smooth RPM and Speed (with safe property access)
	var target_rpm = vehicle.motor_rpm if "motor_rpm" in vehicle else 0.0
	var target_speed = (vehicle.linear_velocity.length() * 3.6) if "linear_velocity" in vehicle else 0.0
	
	display_rpm = move_toward(display_rpm, target_rpm, 12000.0 * delta)
	display_speed = move_toward(display_speed, target_speed, 80.0 * delta)
	
	# Calculate Drift Angle
	var forward = -vehicle.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	var horizontal_vel = vehicle.linear_velocity if "linear_velocity" in vehicle else Vector3.ZERO
	horizontal_vel.y = 0.0
	var speed_kmh = horizontal_vel.length() * 3.6
	
	var is_drifting = false
	if speed_kmh > 15.0 and forward.length_squared() > 0.1 and horizontal_vel.length_squared() > 0.1:
		var vel_dir = horizontal_vel.normalized()
		var dot = clamp(forward.dot(vel_dir), -1.0, 1.0)
		var angle_deg = rad_to_deg(acos(dot))
		
		# If sliding significantly sideways
		if angle_deg > 12.0 and angle_deg < 120.0:
			is_drifting = true
			current_drift_angle = angle_deg
			drift_intensity = move_toward(drift_intensity, 1.0, 4.0 * delta)
	
	if not is_drifting:
		drift_intensity = move_toward(drift_intensity, 0.0, 2.5 * delta)
		
	if is_instance_valid(hud_control):
		hud_control.queue_redraw()

func _on_hud_draw() -> void:
	if not is_instance_valid(vehicle):
		return
		
	var viewport_size = hud_control.get_viewport_rect().size
	
	# Cluster Position (Bottom Center)
	var cluster_center = Vector2(viewport_size.x * 0.5, viewport_size.y - gauge_radius - 25.0)
	
	_draw_tachometer_and_speedometer(cluster_center)
	
	# Drift Indicator (Center Screen, slightly above gauge)
	if drift_intensity > 0.01:
		_draw_drift_badge(Vector2(viewport_size.x * 0.5, viewport_size.y * 0.4))

func _draw_tachometer_and_speedometer(center: Vector2) -> void:
	var max_rpm = 7500.0
	if "max_rpm" in vehicle and vehicle.max_rpm > 1000.0:
		max_rpm = float(vehicle.max_rpm)
		
	var redline_rpm = max_rpm * 0.82
	
	var start_angle = deg_to_rad(145.0)
	var total_sweep = deg_to_rad(250.0)
	var end_angle = start_angle + total_sweep
	
	# Background Arc
	hud_control.draw_arc(center, gauge_radius, start_angle, end_angle, 64, arc_bg_color, gauge_thickness, true)
	
	# Redline Zone Arc
	var redline_ratio = (max_rpm - redline_rpm) / max_rpm
	var redline_start = end_angle - total_sweep * redline_ratio
	hud_control.draw_arc(center, gauge_radius, redline_start, end_angle, 24, redline_color * 0.5, gauge_thickness, true)
	
	# RPM Active Fill Arc
	var rpm_ratio = clamp(display_rpm / max_rpm, 0.0, 1.0)
	var fill_sweep = total_sweep * rpm_ratio
	var active_color = redline_color if display_rpm >= redline_rpm else arc_fill_color
	
	if fill_sweep > 0.01:
		hud_control.draw_arc(center, gauge_radius, start_angle, start_angle + fill_sweep, 48, active_color, gauge_thickness, true)
	
	# Subtle dial plate inside
	hud_control.draw_circle(center, gauge_radius - gauge_thickness * 0.5, Color(0.08, 0.1, 0.14, 0.75))
	hud_control.draw_arc(center, gauge_radius - gauge_thickness * 0.5, 0.0, TAU, 48, Color(0.3, 0.5, 0.8, 0.4), 1.5, true)
	
	# Digital Speed Display (Big center digits)
	var font = ThemeDB.fallback_font
	var speed_int = int(round(display_speed))
	var speed_str = str(speed_int)
	var speed_font_size = 38
	var str_size = font.get_string_size(speed_str, HORIZONTAL_ALIGNMENT_CENTER, -1, speed_font_size)
	var speed_pos = center - Vector2(str_size.x * 0.5, str_size.y * 0.25)
	hud_control.draw_string(font, speed_pos, speed_str, HORIZONTAL_ALIGNMENT_CENTER, -1, speed_font_size, Color(1, 1, 1, 0.98))
	
	# "KM/H" Subtitle
	var kmh_str = "KM/H"
	var kmh_font_size = 13
	var kmh_size = font.get_string_size(kmh_str, HORIZONTAL_ALIGNMENT_CENTER, -1, kmh_font_size)
	var kmh_pos = center + Vector2(-kmh_size.x * 0.5, 18.0)
	hud_control.draw_string(font, kmh_pos, kmh_str, HORIZONTAL_ALIGNMENT_CENTER, -1, kmh_font_size, Color(0.6, 0.75, 0.9, 0.7))
	
	# Gear Indicator (Top part of cluster)
	var gear_str = "N"
	var gear_color = Color(1.0, 0.8, 0.2)
	var is_auto = vehicle.automatic_transmission if "automatic_transmission" in vehicle else true
	var current_gear = vehicle.current_gear if "current_gear" in vehicle else 0
	var mode_prefix = "D" if is_auto else "M"
	
	if current_gear == -1:
		gear_str = "R"
		gear_color = Color(1.0, 0.35, 0.35)
	elif current_gear == 0:
		gear_str = "N"
		gear_color = Color(0.7, 0.7, 0.7)
	else:
		gear_str = mode_prefix + str(current_gear)
		gear_color = Color(0.3, 0.9, 1.0) if is_auto else Color(1.0, 0.65, 0.2)
		
	var gear_font_size = 20
	var gear_size = font.get_string_size(gear_str, HORIZONTAL_ALIGNMENT_CENTER, -1, gear_font_size)
	var gear_pos = center + Vector2(-gear_size.x * 0.5, -gauge_radius * 0.42)
	hud_control.draw_string(font, gear_pos, gear_str, HORIZONTAL_ALIGNMENT_CENTER, -1, gear_font_size, gear_color)
	
	# Needle
	var needle_angle = start_angle + fill_sweep
	var needle_dir = Vector2(cos(needle_angle), sin(needle_angle))
	var needle_start = center + needle_dir * (gauge_radius - gauge_thickness * 1.1)
	var needle_end = center + needle_dir * (gauge_radius + gauge_thickness * 0.7)
	hud_control.draw_line(needle_start, needle_end, needle_color, 3.5)

func _draw_drift_badge(center: Vector2) -> void:
	var font = ThemeDB.fallback_font
	var alpha = drift_intensity
	
	# Background capsule for drift badge
	var badge_w = 210.0
	var badge_h = 50.0
	var rect = Rect2(center - Vector2(badge_w * 0.5, badge_h * 0.5), Vector2(badge_w, badge_h))
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.9, 0.25, 0.05, 0.75 * alpha)
	sb.border_color = Color(1.0, 0.65, 0.1, 0.9 * alpha)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.anti_aliasing = true
	hud_control.draw_style_box(sb, rect)
	
	# Text: DRIFT + Angle
	var drift_text = "🔥 DRIFT  %d°" % int(current_drift_angle)
	var font_size = 20
	var str_size = font.get_string_size(drift_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = center - Vector2(str_size.x * 0.5, -str_size.y * 0.3)
	hud_control.draw_string(font, text_pos, drift_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, alpha))
