class_name ProceduralHUD
extends CanvasLayer

const MobileLayoutUtil = preload("res://scripts/ui/mobile_layout.gd")

@export var vehicle: Vehicle
@export var gauge_radius: float = 62.0
var hud_control: Control
var display_rpm: float = 0.0
var display_speed: float = 0.0
var _elapsed: float = 0.0

func _ready() -> void:
	layer = 9
	hud_control = Control.new()
	hud_control.name = "HUDCanvas"
	hud_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_control)
	hud_control.draw.connect(_on_hud_draw)

func _process(delta: float) -> void:
	if not is_instance_valid(vehicle):
		return
	display_rpm = move_toward(display_rpm, vehicle.motor_rpm, delta * 12000.0)
	display_speed = move_toward(display_speed, vehicle.linear_velocity.length() * 3.6, delta * 100.0)
	_elapsed += delta
	if _elapsed >= 1.0 / 30.0:
		_elapsed = 0.0
		hud_control.queue_redraw()

func _on_hud_draw() -> void:
	if not is_instance_valid(vehicle):
		return
	var safe: Rect2 = MobileLayoutUtil.safe_rect_for(hud_control)
	var unit: float = MobileLayoutUtil.unit_for(safe)
	var center: Vector2 = Vector2(safe.get_center().x, safe.end.y - 80.0 * unit)
	var radius: float = gauge_radius * unit
	var start: float = deg_to_rad(145.0)
	var sweep: float = deg_to_rad(250.0)
	var ratio: float = clampf(display_rpm / maxf(1000.0, vehicle.max_rpm), 0.0, 1.0)
	hud_control.draw_circle(center, radius, Color(0.03, 0.06, 0.10, 0.80))
	hud_control.draw_arc(center, radius, start, start + sweep, 48, Color(0.22, 0.29, 0.4, 0.7), 6.0 * unit, true)
	if ratio > 0.005:
		hud_control.draw_arc(center, radius, start, start + sweep * ratio, 48, Color(0.23, 0.68, 1.0) if ratio < 0.82 else Color(1.0, 0.25, 0.2), 6.0 * unit, true)
	var gear: String = "N"
	if vehicle.current_gear == -1:
		gear = "R"
	elif vehicle.current_gear > 0:
		gear = ("D" if vehicle.automatic_transmission else "M") + str(vehicle.current_gear)
	_text(gear, center + Vector2(0, -24.0 * unit), int(22.0 * unit), Color(0.52, 0.8, 1.0))
	_text(str(int(round(display_speed))), center + Vector2(0, 12.0 * unit), int(34.0 * unit), Color.WHITE)
	_text("км/ч", center + Vector2(0, 42.0 * unit), int(19.0 * unit), Color(0.72, 0.8, 0.9))

func _text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, maxi(10, font_size)).x
	hud_control.draw_string(font, center - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, maxi(10, font_size), color)
