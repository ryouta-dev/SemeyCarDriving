extends SemeyWorldManager

## Calibration polygon. It reuses SemeyWorldManager's boot flow (audio, tuning,
## sky, weather, session, pause/resume, guards) and only supplies geometry, a
## spawn point and the world-specific toggles. Previously this scene overrode
## _ready wholesale, which silently drifted from the city (no minimap, no
## orientation handling, no shared await guards).

func _prepare_scene() -> void:
	_floor(Vector3(0, -0.1, 0), Vector3(500, 0.2, 500), "Road", Color(0.16, 0.17, 0.19))
	_floor(Vector3(60, 0.05, -40), Vector3(25, 0.1, 100), "Dirt", Color(0.45, 0.34, 0.2))
	_floor(Vector3(-60, 0.05, -40), Vector3(25, 0.1, 100), "Grass", Color(0.16, 0.40, 0.13))
	for i in range(8):
		_floor(Vector3(-3 if i % 2 == 0 else 3, 0.35, -18 - i * 14), Vector3(0.5, 0.7, 0.5), "Road", Color(1, 0.4, 0.05))
	for i in range(6):
		_floor(Vector3(25, 0.05 + i * 0.015, -25 - i * 4), Vector3(10, 0.1 + i * 0.03, 0.5), "Road", Color(0.65, 0.65, 0.65))
	var ramp := _floor(Vector3(-25, 0.8, -45), Vector3(10, 0.3, 15), "Road", Color(0.4, 0.45, 0.5))
	ramp.rotation.x = deg_to_rad(-8.0)
	# Collision bridge deck demonstrates that raised surfaces are physical.
	_floor(Vector3(0, 1.0, -150), Vector3(12, 0.4, 30), "Road", Color(0.4, 0.42, 0.45))
	_floor(Vector3(0, 0.55, -126), Vector3(12, 0.3, 18), "Road", Color(0.4, 0.42, 0.45)).rotation.x = deg_to_rad(-4.0)
	_floor(Vector3(0, 0.55, -174), Vector3(12, 0.3, 18), "Road", Color(0.4, 0.42, 0.45)).rotation.x = deg_to_rad(4.0)

func _resolve_spawn() -> bool:
	_spawn_position = Vector3.ZERO
	_spawn_yaw = 0.0
	return true

func _prepare_spawn(_world_pos: Vector3) -> bool:
	return true

func _wants_minimap() -> bool:
	return false

func _wants_traffic() -> bool:
	return false

func _loading_text() -> String:
	return "Подготовка полигона…"

func _on_world_ready() -> void:
	_session.set_hint("Полигон: прямо слалом; слева рампа; справа грунт")

func _floor(position: Vector3, dimensions: Vector3, surface: String, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.set_meta("surface_type", surface)
	body.add_to_group(surface)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	visual.mesh = mesh
	body.add_child(visual)
	add_child(body)
	return body

func _physics_process(_delta: float) -> void:
	if is_instance_valid(vehicle) and (vehicle.global_position.y < -15 or not vehicle.global_position.is_finite()):
		respawn()
