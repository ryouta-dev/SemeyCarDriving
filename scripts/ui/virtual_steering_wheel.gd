class_name VirtualSteeringWheel
extends Control

signal steering_changed(value: float)

@export var max_angle_degrees: float = 180.0
@export var return_speed: float = 15.0 # Speed of returning to center when released
@export var wheel_color: Color = Color(0.12, 0.15, 0.22, 0.85)
@export var rim_color: Color = Color(0.2, 0.25, 0.35, 0.95)
@export var accent_color: Color = Color(1.0, 0.25, 0.25, 1.0) # Top 12 o'clock racing stripe
@export var spoke_color: Color = Color(0.35, 0.45, 0.6, 0.9)
## Input-only mode: keep the touch/drag logic but let a 3D wheel draw itself.
@export var draw_visual: bool = true

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
	if not draw_visual:
		return
	if size.x < 8.0 or size.y < 8.0:
		return
	var center = size * 0.5
	var radius = min(size.x, size.y) * 0.46
	var inner_radius = radius * 0.72
	var hub_radius = radius * 0.28
	
	draw_set_transform(center, deg_to_rad(current_angle_deg), Vector2.ONE)

	# Soft drop shadow grounds the wheel on the HUD.
	draw_circle(Vector2(3, 4), radius * 1.02, Color(0, 0, 0, 0.28))

	# Leather rim: concentric arcs fake a gradient without textures.
	var rim_steps := 7
	var rim_thickness: float = (radius - inner_radius) / float(rim_steps)
	for i in range(rim_steps):
		var t: float = float(i) / float(maxi(1, rim_steps - 1))
		var ring_radius: float = inner_radius + rim_thickness * (float(i) + 0.5)
		var ring_color: Color = rim_color.darkened(0.38).lerp(rim_color.lightened(0.22), t)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, ring_color, rim_thickness + 0.8, true)

	# Bevels.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.18), 1.5, true)
	draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 64, Color(0, 0, 0, 0.6), 2.0, true)

	# 12 o'clock accent with a soft glow.
	var stripe_half_w := 0.09
	draw_arc(Vector2.ZERO, (radius + inner_radius) * 0.5, -PI * 0.5 - stripe_half_w, -PI * 0.5 + stripe_half_w, 10, Color(accent_color.r, accent_color.g, accent_color.b, 0.22), (radius - inner_radius) * 1.6, true)
	draw_arc(Vector2.ZERO, (radius + inner_radius) * 0.5, -PI * 0.5 - stripe_half_w, -PI * 0.5 + stripe_half_w, 10, accent_color, radius - inner_radius, true)

	# Spokes with a dark base and a light top edge (reads as brushed metal).
	var spoke_thickness: float = radius * 0.14
	for direction: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]:
		var start: Vector2 = direction * hub_radius * 0.85
		var end: Vector2 = direction * inner_radius * 1.02
		draw_line(start, end, Color(0, 0, 0, 0.45), spoke_thickness + 2.0, true)
		draw_line(start, end, spoke_color, spoke_thickness, true)
		draw_line(start + Vector2(0, -1.5), end + Vector2(0, -1.5), spoke_color.lightened(0.35), maxf(1.0, spoke_thickness * 0.22), true)

	# Hub: concentric gradient plus a chrome ring.
	for i in range(5):
		var t: float = float(i) / 4.0
		draw_circle(Vector2.ZERO, hub_radius * (1.0 - t * 0.5), wheel_color.darkened(0.22).lerp(wheel_color.lightened(0.22), t))
	draw_arc(Vector2.ZERO, hub_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 1.5, true)

	# Center emblem.
	var font = ThemeDB.fallback_font
	var text = "S"
	var font_size = maxi(1, int(hub_radius * 1.1))
	var str_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = -str_size * 0.5 + Vector2(0, str_size.y * 0.75)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.92, 0.78, 0.25, 0.95))

	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func reset_input() -> void:
	active_touch_index = -1
	is_dragging = false
	current_angle_deg = 0.0
	_update_steering_value()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_VISIBILITY_CHANGED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		reset_input()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and event.index == active_touch_index:
		active_touch_index = -1
		is_dragging = false
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and active_touch_index == 9999:
		active_touch_index = -1
		is_dragging = false
