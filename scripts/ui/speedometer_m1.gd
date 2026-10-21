class_name SpeedometerM1
extends Control

## Circular speedometer/tachometer for the M1 HUD, drawn in code so it scales
## cleanly at any resolution and needs no texture assets.

var speed_kmh: float = 0.0
var rpm_ratio: float = 0.0
var gear_text: String = "D1"

const START_ANGLE := deg_to_rad(140.0)
const SWEEP := deg_to_rad(260.0)
const REDLINE := 0.82

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_values(speed: float, ratio: float, gear: String) -> void:
	speed_kmh = speed
	rpm_ratio = clampf(ratio, 0.0, 1.0)
	gear_text = gear
	queue_redraw()

func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.5 - 4.0
	var center: Vector2 = size * 0.5
	# Backplate.
	draw_circle(center, radius, Color(0.03, 0.04, 0.05, 0.82))
	draw_arc(center, radius - 2.0, 0.0, TAU, 64, Color(1, 1, 1, 0.10), 2.0, true)
	# Scale ticks.
	for i in range(11):
		var t: float = float(i) / 10.0
		var angle: float = START_ANGLE + SWEEP * t
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius - 16.0)
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius - 6.0)
		draw_line(inner, outer, Color(1, 1, 1, 0.55), 2.0, true)
	# RPM arc.
	draw_arc(center, radius - 10.0, START_ANGLE, START_ANGLE + SWEEP, 64, Color(1, 1, 1, 0.10), 8.0, true)
	if rpm_ratio > 0.005:
		var color: Color = Color("e2453c") if rpm_ratio >= REDLINE else Color("f2c230")
		draw_arc(center, radius - 10.0, START_ANGLE, START_ANGLE + SWEEP * rpm_ratio, 64, color, 8.0, true)
	# Needle.
	var needle_angle: float = START_ANGLE + SWEEP * rpm_ratio
	var needle_end: Vector2 = center + Vector2(cos(needle_angle), sin(needle_angle)) * (radius - 24.0)
	draw_line(center, needle_end, Color("f2c230"), 3.0, true)
	draw_circle(center, 5.0, Color("f2c230"))
	# Digits.
	var font: Font = ThemeM1.font_bold()
	var speed_text: String = str(int(round(speed_kmh)))
	var speed_size: int = maxi(18, int(radius * 0.42))
	draw_string(font, center + Vector2(-radius * 0.55, radius * 0.28), speed_text, HORIZONTAL_ALIGNMENT_CENTER, radius * 1.1, speed_size, Color.WHITE)
	draw_string(ThemeM1.font_regular(), center + Vector2(-radius * 0.4, radius * 0.62), "км/ч", HORIZONTAL_ALIGNMENT_CENTER, radius * 0.8, maxi(10, int(radius * 0.16)), ThemeM1.MUTED)
	# Gear badge.
	var badge := Rect2(center + Vector2(-radius * 0.22, -radius * 0.62), Vector2(radius * 0.44, radius * 0.26))
	draw_rect(badge, Color(0.06, 0.07, 0.09, 0.9), true)
	draw_rect(badge, Color(1, 1, 1, 0.12), false, 1.0)
	draw_string(font, badge.position + Vector2(0, badge.size.y * 0.72), gear_text, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, maxi(12, int(radius * 0.22)), Color("f2c230"))
