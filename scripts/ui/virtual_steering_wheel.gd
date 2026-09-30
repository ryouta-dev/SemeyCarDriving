extends Control
class_name VirtualSteeringWheel

signal steering_changed(value: float)

@export var max_angle_degrees: float = 180.0
@export var return_speed: float = 15.0 # Speed of returning to center when released
@export var wheel_color: Color = Color(0.12, 0.15, 0.22, 0.85)
@export var rim_color: Color = Color(0.2, 0.25, 0.35, 0.95)
@export var accent_color: Color = Color(1.0, 0.25, 0.25, 1.0) # Top 12 o'clock racing stripe
@export var spoke_color: Color = Color(0.35, 0.45, 0.6, 0.9)

var current_angle_deg: float = 0.0
var steering_value: float = 0.0 # From -1.0 (left) to +1.0 (right)

var is_dragging: bool = false
var active_touch_index: int = -1
var previous_touch_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if not is_dragging:
		if abs(current_angle_deg) > 0.01:
			current_angle_deg = move_toward(current_angle_deg, 0.0, return_speed * delta * (abs(current_angle_deg) + 30.0))
			_update_steering_value()
			queue_redraw()
		elif current_angle_deg != 0.0:
			current_angle_deg = 0.0
			_update_steering_value()
			queue_redraw()

func _update_steering_value() -> void:
	# Positive angle is clockwise (turning right in car)
	steering_value = clamp(current_angle_deg / max_angle_degrees, -1.0, 1.0)
	steering_changed.emit(steering_value)

func _gui_input(event: InputEvent) -> void:
	var center = size * 0.5
	
	if event is InputEventScreenTouch:
		if event.pressed and active_touch_index == -1:
			active_touch_index = event.index
			is_dragging = true
			previous_touch_pos = event.position
			accept_event()
		elif not event.pressed and event.index == active_touch_index:
			active_touch_index = -1
			is_dragging = false
			accept_event()
			
	elif event is InputEventScreenDrag:
		if is_dragging and event.index == active_touch_index:
			_process_drag(event.position, center)
			accept_event()
			
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and active_touch_index == -1:
				active_touch_index = 9999
				is_dragging = true
				previous_touch_pos = event.position
				accept_event()
			elif not event.pressed and active_touch_index == 9999:
				active_touch_index = -1
				is_dragging = false
				accept_event()
				
	elif event is InputEventMouseMotion:
		if is_dragging and active_touch_index == 9999:
			_process_drag(event.position, center)
			accept_event()

func _process_drag(current_pos: Vector2, center: Vector2) -> void:
	var vec_prev = previous_touch_pos - center
	var vec_curr = current_pos - center
	
	if vec_prev.length() > 5.0 and vec_curr.length() > 5.0:
		var delta_angle = vec_prev.angle_to(vec_curr)
		current_angle_deg += rad_to_deg(delta_angle)
		current_angle_deg = clamp(current_angle_deg, -max_angle_degrees, max_angle_degrees)
		_update_steering_value()
		queue_redraw()
		
	previous_touch_pos = current_pos

func _draw() -> void:
	var center = size * 0.5
	var radius = min(size.x, size.y) * 0.46
	var inner_radius = radius * 0.72
	var hub_radius = radius * 0.28
	
	draw_set_transform(center, deg_to_rad(current_angle_deg), Vector2.ONE)
	
	# Outer rim background ring
	draw_arc(Vector2.ZERO, (radius + inner_radius) * 0.5, 0.0, TAU, 64, rim_color, radius - inner_radius, true)
	
	# Rim outer border highlight
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.5, 0.7, 1.0, 0.5), 2.5, true)
	# Rim inner border
	draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 64, Color(0.1, 0.1, 0.1, 0.8), 2.0, true)
	
	# Top 12 o'clock racing stripe (drift marker)
	var stripe_half_w = 0.08 # radians
	draw_arc(Vector2.ZERO, (radius + inner_radius) * 0.5, -PI*0.5 - stripe_half_w, -PI*0.5 + stripe_half_w, 8, accent_color, radius - inner_radius, true)
	
	# Spokes (Left, Right, Down)
	var spoke_thickness = radius * 0.14
	# Left spoke
	draw_line(Vector2(-hub_radius * 0.9, 0), Vector2(-inner_radius * 1.02, 0), spoke_color, spoke_thickness)
	# Right spoke
	draw_line(Vector2(hub_radius * 0.9, 0), Vector2(inner_radius * 1.02, 0), spoke_color, spoke_thickness)
	# Bottom spoke
	draw_line(Vector2(0, hub_radius * 0.9), Vector2(0, inner_radius * 1.02), spoke_color, spoke_thickness)
	
	# Center Hub
	draw_circle(Vector2.ZERO, hub_radius, wheel_color)
	draw_arc(Vector2.ZERO, hub_radius, 0.0, TAU, 48, Color(0.5, 0.7, 1.0, 0.6), 2.0, true)
	
	# Center Emblem (Stylized "S" for Semey)
	var font = ThemeDB.fallback_font
	var text = "S"
	var font_size = int(hub_radius * 1.1)
	var str_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = -str_size * 0.5 + Vector2(0, str_size.y * 0.75)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.4, 0.8, 1.0, 0.9))
	
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
