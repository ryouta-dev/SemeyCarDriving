extends Node3D
class_name SemeyWorldManager

const ProfileManagerClass = preload("res://scripts/profile_manager.gd")
const VehicleTuningApplicatorClass = preload("res://scripts/tuning/vehicle_tuning_applicator.gd")

@export var tile_manager: Node3D # OSMTileManager
@export var sky_controller: Node # SkyController
@export var weather_controller: Node # WeatherController
@export var street_lamp_lights: Node3D # StreetLampLights
@export var vehicle: RigidBody3D # Vehicle
@export var headlights: Node3D # Headlights
@export var mobile_controls: CanvasLayer # MobileControls

func _ready() -> void:
	# Keep running even if tree pauses
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Wire day/night events
	if is_instance_valid(sky_controller):
		if is_instance_valid(headlights):
			sky_controller.day_night_changed.connect(func(is_day: bool):
				headlights.set_on(not is_day)
			)
		if is_instance_valid(street_lamp_lights):
			sky_controller.day_night_changed.connect(func(is_day: bool):
				street_lamp_lights.set_on(not is_day)
			)
	if is_instance_valid(mobile_controls):
		mobile_controls.day_night_toggle_requested.connect(toggle_day_night)
		mobile_controls.weather_toggle_requested.connect(toggle_weather)
		if mobile_controls.has_signal("garage_requested"):
			mobile_controls.garage_requested.connect(open_garage)
	
	# Spawn vehicle onto road/ground
	if is_instance_valid(vehicle):
		vehicle.freeze = true
		vehicle.set_physics_process(false)
		# Apply saved custom tuning to the car
		var profile = ProfileManagerClass.load_profile()
		VehicleTuningApplicatorClass.apply_tuning(vehicle, profile)
		print("[SemeyWorldManager] Applied tuning profile to vehicle: ", profile.get("engine", {}).get("engine_id", "stock"))
		
	if is_instance_valid(tile_manager):
		var osm_data = tile_manager.get_osm_data()
		if osm_data != null:
			_spawn_vehicle()
		else:
			tile_manager.data_loaded.connect(func(_data): _spawn_vehicle())

func _spawn_vehicle() -> void:
	if not is_instance_valid(vehicle) or not is_instance_valid(tile_manager):
		return
		
	var target_xz := Vector2(vehicle.global_position.x, vehicle.global_position.z)
	var spawn_yaw := 0.0
	var osm_data = tile_manager.get_osm_data()
	var triumph_found := false

	if osm_data != null and osm_data.ways.size() > 0:
		# Check for Triumph mall first to spawn on its parking plaza
		for way in osm_data.ways.values():
			var b_name: String = way.tags.get("name", "")
			if way.id == 44085896 or b_name.find("Триумф") != -1:
				# Spawn on the open asphalt plaza in front of Triumph facing Shakarim Ave
				target_xz = Vector2(0.0, -50.0)
				spawn_yaw = deg_to_rad(-45.0)
				triumph_found = true
				print("[SemeyWorldManager] Spawning car on Triumph plaza at: ", target_xz)
				break

		if not triumph_found:
			var best_pos := target_xz
			var min_dist_sq := INF
			for way in osm_data.ways.values():
				if not way.tags.has("highway"):
					continue
				var h_type: String = way.tags["highway"]
				if h_type in ["primary", "secondary", "tertiary", "residential", "trunk", "motorway"]:
					for nid in way.node_ids:
						if osm_data.nodes.has(nid):
							var node_pos: Vector3 = osm_data.nodes[nid].local_pos
							var dist_sq = Vector2(node_pos.x, node_pos.z).length_squared()
							if dist_sq < min_dist_sq:
								min_dist_sq = dist_sq
								best_pos = Vector2(node_pos.x, node_pos.z)
			if min_dist_sq < INF:
				target_xz = best_pos
				print("[SemeyWorldManager] Spawning car on road at: ", target_xz)

	# Ensure tiles around spawn position are instanced immediately
	var spawn_3d := Vector3(target_xz.x, 0.0, target_xz.y)
	tile_manager.ensure_tiles_around(spawn_3d)
	
	# Wait for physics frames so colliders are fully registered in Jolt physics engine
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Raycast straight down from high up to find actual surface
	var space_state = get_world_3d().direct_space_state
	var from = Vector3(target_xz.x, 50.0, target_xz.y)
	var to = Vector3(target_xz.x, -20.0, target_xz.y)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [vehicle.get_rid()]
	var result = space_state.intersect_ray(query)
	
	var ground_y = 0.0
	if result:
		ground_y = result.position.y
	else:
		ground_y = tile_manager.get_terrain_height(spawn_3d)
		
	# Place vehicle safely suspended ~0.85m above ground (GEVP standard spawn height)
	# This ensures wheel raycasts start extended with zero initial impulse or bottom-out shock
	vehicle.global_position = Vector3(target_xz.x, ground_y + 0.85, target_xz.y)
	vehicle.rotation = Vector3(0.0, spawn_yaw, 0.0)
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	
	# Reset vehicle drivetrain and velocity tracking to prevent astronomical drag forces
	if "previous_global_position" in vehicle:
		vehicle.previous_global_position = vehicle.global_position
	if "local_velocity" in vehicle:
		vehicle.local_velocity = Vector3.ZERO
	if "speed" in vehicle:
		vehicle.speed = 0.0
	if "motor_rpm" in vehicle and "idle_rpm" in vehicle:
		vehicle.motor_rpm = vehicle.idle_rpm
	if "clutch_torque" in vehicle:
		vehicle.clutch_torque = 0.0
	if "true_steering_amount" in vehicle:
		vehicle.true_steering_amount = 0.0
		
	# Reset each wheel's history to avoid massive velocity/compression delta spikes
	if "wheel_array" in vehicle:
		for wheel in vehicle.wheel_array:
			if is_instance_valid(wheel):
				wheel.force_raycast_update()
				wheel.previous_global_position = wheel.global_position
				wheel.local_velocity = Vector3.ZERO
				wheel.previous_velocity = Vector3.ZERO
				wheel.force_vector = Vector2.ZERO
				wheel.slip_vector = Vector2.ZERO
				wheel.spin = 0.0
				wheel.spring_force = 0.0
				wheel.previous_compression = 0.0
				wheel.spring_current_length = wheel.spring_length
	
	await get_tree().physics_frame
	vehicle.freeze = false
	vehicle.set_physics_process(true)
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	print("[SemeyWorldManager] Vehicle activated at: ", vehicle.global_position)
	
	var cam := get_viewport().get_camera_3d()
	if cam is ProVehicleCamera:
		cam.snap_to_target()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			toggle_weather()
		elif event.keycode == KEY_F6:
			toggle_day_night()
		elif event.keycode == KEY_ESCAPE or event.keycode == KEY_G:
			open_garage()

func open_garage() -> void:
	print("[SemeyWorldManager] Returning to Garage...")
	get_tree().change_scene_to_file("res://scenes/garage.tscn")

func toggle_weather() -> void:
	if is_instance_valid(weather_controller):
		var wet = weather_controller.toggle()
		print("[Weather] Rain/Wetness toggled: ", wet)

func toggle_day_night() -> void:
	if is_instance_valid(sky_controller):
		var day = sky_controller.toggle()
		print("[Sky] Day/Night toggled. Is Day: ", day)
