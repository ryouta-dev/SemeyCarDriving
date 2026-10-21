class_name SemeyTraffic
extends Node3D

var vehicle: Vehicle
var tile_manager: OSMTileManager
var _timer := 0.0
var _actors: Array = []
var _max_actors := 4

class TrafficCar:
	extends CharacterBody3D
	var route := PackedVector3Array()
	var target_index := 1
	var cruise_speed := 6.0
	var player: Vehicle

	func _physics_process(delta: float) -> void:
		if route.size() < 2:
			return
		if is_instance_valid(player) and global_position.distance_to(player.global_position) > 500.0:
			queue_free()
			return
		var offset := route[target_index] - global_position
		offset.y = 0.0
		if offset.length() < 2.5:
			target_index += 1
			if target_index >= route.size():
				route.reverse()
				target_index = 1
			return
		var direction := offset.normalized()
		var desired_speed := cruise_speed
		var query := PhysicsRayQueryParameters3D.create(global_position, global_position + direction * 7.0)
		query.exclude = [get_rid()]
		var obstacle := get_world_3d().direct_space_state.intersect_ray(query)
		if not obstacle.is_empty():
			desired_speed *= clampf(global_position.distance_to(obstacle.position) / 7.0 - 0.3, 0.0, 1.0)
		if is_instance_valid(player) and global_position.distance_to(player.global_position) < 5.0:
			desired_speed = 0.0
		velocity.x = move_toward(velocity.x, direction.x * desired_speed, 3.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * desired_speed, 3.0 * delta)
		velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 3.0))
		move_and_slide()

func _ready() -> void:
	_max_actors = 2 if ProfileManager.load_profile()["settings"]["quality"] == "low" else 4
	_replenish()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 8.0:
		_timer = 0.0
		_replenish()

func _replenish() -> void:
	_actors = _actors.filter(func(actor): return is_instance_valid(actor) and not actor.is_queued_for_deletion())
	if not is_instance_valid(vehicle) or _actors.size() >= _max_actors:
		return
	for entry in tile_manager.collect_ways_near(vehicle.global_position, 350.0):
		if _actors.size() >= _max_actors:
			break
		var tags: Dictionary = entry["way"].tags
		if tags.get("highway", "") not in ["residential", "tertiary", "secondary"] or tags.get("oneway", "no") in ["yes", "1", "-1"]:
			continue
		var points: PackedVector3Array = entry["points"]
		if points.size() < 2 or points[0].distance_to(vehicle.global_position) < 40.0:
			continue
		var duplicate_route := false
		for actor in _actors:
			if actor.get_meta("way_id", 0) == entry["way"].id:
				duplicate_route = true
		if duplicate_route:
			continue
		var actor := TrafficCar.new()
		actor.player = vehicle
		actor.set_meta("way_id", entry["way"].id)
		for i in range(points.size()):
			var next := points[mini(i + 1, points.size() - 1)]
			var previous := points[maxi(0, i - 1)]
			var direction := (next - previous).normalized()
			actor.route.append(points[i] + Vector3(-direction.z, 0.0, direction.x) * 1.1)
		var shape := CollisionShape3D.new()
		var collider := BoxShape3D.new()
		collider.size = Vector3(1.65, 1.1, 3.9)
		shape.shape = collider
		actor.add_child(shape)
		var body := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = collider.size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.from_hsv(float(_actors.size()) / 4.0, 0.45, 0.7)
		mesh.material = mat
		body.mesh = mesh
		actor.add_child(body)
		var cabin := MeshInstance3D.new()
		var cabin_mesh := BoxMesh.new()
		cabin_mesh.size = Vector3(1.4, 0.5, 1.8)
		cabin.mesh = cabin_mesh
		cabin.position.y = 0.7
		actor.add_child(cabin)
		add_child(actor)
		actor.global_position = actor.route[0] + Vector3.UP * 0.65
		_actors.append(actor)
