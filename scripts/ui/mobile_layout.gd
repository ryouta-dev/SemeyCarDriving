class_name MobileLayout
extends RefCounted

const STEER_SIZE: Vector2 = Vector2(264, 312)
const PEDALS_SIZE: Vector2 = Vector2(340, 288)

static func safe_rect_for(fullscreen: Control) -> Rect2:
	var full_size: Vector2 = fullscreen.size
	if full_size.x <= 1.0 or full_size.y <= 1.0:
		full_size = fullscreen.get_viewport_rect().size
	var bounds: Rect2 = Rect2(Vector2.ZERO, full_size)
	if not OS.has_feature("mobile"):
		return bounds
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var pixels: Rect2i = DisplayServer.get_display_safe_area()
	if window_size.x <= 0.0 or window_size.y <= 0.0 or pixels.size.x <= 0 or pixels.size.y <= 0:
		return bounds
	# Safe-area pixels are display coordinates; UI dimensions are canvas units.
	var origin: Vector2 = Vector2(DisplayServer.window_get_position())
	var ratio: Vector2 = full_size / window_size
	var safe: Rect2 = Rect2((Vector2(pixels.position) - origin) * ratio, Vector2(pixels.size) * ratio)
	safe = safe.intersection(bounds)
	return safe if safe.size.x > 1.0 and safe.size.y > 1.0 else bounds

static func unit_for(safe: Rect2) -> float:
	return maxf(0.1, minf(safe.size.x / 1280.0, safe.size.y / 720.0))

static func controls(safe: Rect2, requested_scale: float, steer_offset: Vector2, pedal_offset: Vector2) -> Dictionary:
	var unit: float = unit_for(safe)
	var margin: float = 16.0 * unit
	var scale: float = unit * clampf(requested_scale, 0.7, 1.5)
	# Keep both thumb zones apart and leave space for the central speed display.
	scale = minf(scale, minf(safe.size.x * 0.32 / PEDALS_SIZE.x, safe.size.y * 0.46 / STEER_SIZE.y))
	var steer_size: Vector2 = STEER_SIZE * scale
	var pedal_size: Vector2 = PEDALS_SIZE * scale
	var left_max: float = maxf(margin, safe.size.x * 0.43 - steer_size.x)
	var right_min: float = safe.size.x * 0.57
	var left_x: float = safe.position.x + clampf(steer_offset.x * unit, margin, left_max)
	var right_x: float = clampf(safe.end.x + pedal_offset.x * unit - pedal_size.x, safe.position.x + right_min, safe.end.x - margin - pedal_size.x)
	var top_min: float = safe.position.y + safe.size.y * 0.42
	var left_y: float = clampf(safe.end.y + steer_offset.y * unit - steer_size.y, top_min, safe.end.y - margin - steer_size.y)
	var right_y: float = clampf(safe.end.y + pedal_offset.y * unit - pedal_size.y, top_min, safe.end.y - margin - pedal_size.y)
	return {"unit": unit, "scale": scale,
		"steer": Rect2(Vector2(left_x, left_y), steer_size),
		"pedals": Rect2(Vector2(right_x, right_y), pedal_size),
		"camera": Rect2(Vector2(safe.end.x - 256.0 * unit, safe.position.y + margin), Vector2(128, 96) * unit),
		"menu": Rect2(Vector2(safe.end.x - 116.0 * unit, safe.position.y + margin), Vector2(100, 96) * unit),
		"minimap": Rect2(safe.position + Vector2.ONE * margin, Vector2.ONE * 148.0 * unit),
		"gauge_center": Vector2(safe.get_center().x, safe.end.y - 80.0 * unit)}

static func place(control: Control, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size
