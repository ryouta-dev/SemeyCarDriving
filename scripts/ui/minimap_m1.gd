class_name MinimapM1
extends Control

## Minimal top-down schematic for the bridge slice: river bands, the bridge
## deck and the car arrow. No OSM data, no textures.

var car_position := Vector3.ZERO

const Z_NEAR := 160.0
const Z_FAR := -1140.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_car_position(position: Vector3) -> void:
	car_position = position
	queue_redraw()

func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.5
	var center: Vector2 = size * 0.5
	draw_circle(center, radius, Color(0.05, 0.08, 0.10, 0.86))
	# River.
	draw_circle(center, radius - 3.0, Color("1b3a4d"))
	# Banks (top = far bank, bottom = near bank).
	var map_top: float = center.y - radius + 8.0
	var map_bottom: float = center.y + radius - 8.0
	var map_height: float = map_bottom - map_top
	var bank_fraction: float = 0.12
	draw_rect(Rect2(center.x - radius + 6.0, map_top, (radius - 6.0) * 2.0, map_height * bank_fraction), Color("4a5340"))
	draw_rect(Rect2(center.x - radius + 6.0, map_bottom - map_height * bank_fraction, (radius - 6.0) * 2.0, map_height * bank_fraction), Color("4a5340"))
	# Bridge deck.
	var deck_width: float = maxf(10.0, radius * 0.28)
	var deck := Rect2(center.x - deck_width * 0.5, map_top + map_height * bank_fraction, deck_width, map_height * (1.0 - bank_fraction * 2.0))
	draw_rect(deck, Color("8b8f96"))
	draw_line(Vector2(center.x, deck.position.y), Vector2(center.x, deck.end.y), Color("e9e5d8"), 1.0, true)
	# Towers.
	for z: float in [-240.0, -760.0]:
		var y: float = _map_y(z, map_top, map_bottom)
		draw_line(Vector2(center.x - deck_width * 0.7, y), Vector2(center.x + deck_width * 0.7, y), Color("d6d0c3"), 2.0, true)
	# Car arrow.
	var car_y: float = _map_y(car_position.z, map_top, map_bottom)
	var car_x: float = center.x + clampf(car_position.x / 40.0, -1.0, 1.0) * deck_width * 0.4
	var arrow := PackedVector2Array([
		Vector2(car_x, car_y - 7.0),
		Vector2(car_x - 5.0, car_y + 5.0),
		Vector2(car_x, car_y + 2.0),
		Vector2(car_x + 5.0, car_y + 5.0),
	])
	draw_colored_polygon(arrow, Color("3fa9ff"))
	# Frame.
	draw_arc(center, radius - 1.5, 0.0, TAU, 64, Color(1, 1, 1, 0.18), 2.0, true)

func _map_y(z: float, top: float, bottom: float) -> float:
	var t: float = clampf(inverse_lerp(Z_NEAR, Z_FAR, z), 0.0, 1.0)
	return lerpf(bottom, top, t)
