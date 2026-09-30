extends Control
class_name TouchButton

signal button_down
signal button_up

@export var text: String = ""
@export var font_size: int = 18
@export var base_color: Color = Color(0.12, 0.15, 0.2, 0.65)
@export var pressed_color: Color = Color(0.2, 0.5, 0.9, 0.85)
@export var border_color: Color = Color(0.4, 0.6, 0.9, 0.6)
@export var corner_radius: float = 14.0
@export var border_width: float = 2.0
@export var icon_type: String = "none" # "none", "arrow_left", "arrow_right", "pedal_gas", "pedal_brake", "handbrake"

var is_pressed: bool = false
var active_touch_index: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch_index == -1:
			active_touch_index = event.index
			_set_pressed(true)
			accept_event()
		elif not event.pressed and event.index == active_touch_index:
			active_touch_index = -1
			_set_pressed(false)
			accept_event()
			
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and active_touch_index == -1:
				active_touch_index = 9999
				_set_pressed(true)
				accept_event()
			elif not event.pressed and active_touch_index == 9999:
				active_touch_index = -1
				_set_pressed(false)
				accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_FOCUS_EXIT:
		if is_pressed:
			active_touch_index = -1
			_set_pressed(false)

func _set_pressed(p: bool) -> void:
	if is_pressed != p:
		is_pressed = p
		queue_redraw()
		if is_pressed:
			button_down.emit()
		else:
			button_up.emit()

func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	var bg_color = pressed_color if is_pressed else base_color
	
	# Draw rounded background
	draw_style_box_rect(r, bg_color, corner_radius, border_color if is_pressed else border_color * 0.7, border_width)
	
	# Draw icon or text
	if icon_type == "arrow_left":
		_draw_arrow(true)
	elif icon_type == "arrow_right":
		_draw_arrow(false)
	elif icon_type == "pedal_gas":
		_draw_gas_pedal()
	elif icon_type == "pedal_brake":
		_draw_brake_pedal()
	elif text != "":
		var font = ThemeDB.fallback_font
		var string_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = (size - string_size) * 0.5 + Vector2(0, string_size.y * 0.8)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

func draw_style_box_rect(rect: Rect2, fill: Color, radius: float, border: Color, b_width: float) -> void:
	# Using Godot's StyleBoxFlat rendering for clean anti-aliased corners
	var sb = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.corner_radius_top_left = int(radius)
	sb.corner_radius_top_right = int(radius)
	sb.corner_radius_bottom_left = int(radius)
	sb.corner_radius_bottom_right = int(radius)
	sb.border_width_left = int(b_width)
	sb.border_width_top = int(b_width)
	sb.border_width_right = int(b_width)
	sb.border_width_bottom = int(b_width)
	sb.border_color = border
	sb.anti_aliasing = true
	draw_style_box(sb, rect)

func _draw_arrow(left: bool) -> void:
	var c = size * 0.5
	var w = size.x * 0.22
	var h = size.y * 0.28
	var points: PackedVector2Array = []
	if left:
		points.append(Vector2(c.x - w, c.y))
		points.append(Vector2(c.x + w * 0.6, c.y - h))
		points.append(Vector2(c.x + w * 0.6, c.y + h))
	else:
		points.append(Vector2(c.x + w, c.y))
		points.append(Vector2(c.x - w * 0.6, c.y - h))
		points.append(Vector2(c.x - w * 0.6, c.y + h))
	draw_colored_polygon(points, Color.WHITE if is_pressed else Color(0.9, 0.9, 0.9, 0.85))

func _draw_gas_pedal() -> void:
	var font = ThemeDB.fallback_font
	var label = "GAS" if text == "" else text
	var string_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = (size - string_size) * 0.5 + Vector2(0, string_size.y * 0.8)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.3, 1.0, 0.5) if is_pressed else Color.WHITE)
	
	# Tread lines
	var line_color = Color(1, 1, 1, 0.3)
	for i in range(3):
		var y_off = size.y * 0.25 + i * (size.y * 0.15)
		draw_line(Vector2(size.x * 0.2, y_off), Vector2(size.x * 0.8, y_off), line_color, 2.0)

func _draw_brake_pedal() -> void:
	var font = ThemeDB.fallback_font
	var label = "BRAKE" if text == "" else text
	var string_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = (size - string_size) * 0.5 + Vector2(0, string_size.y * 0.8)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1.0, 0.35, 0.35) if is_pressed else Color.WHITE)
	
	# Tread lines
	var line_color = Color(1, 1, 1, 0.3)
	for i in range(2):
		var y_off = size.y * 0.28 + i * (size.y * 0.2)
		draw_line(Vector2(size.x * 0.25, y_off), Vector2(size.x * 0.75, y_off), line_color, 2.0)
