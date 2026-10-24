extends SceneTree

const MobileLayoutUtil = preload("res://scripts/ui/mobile_layout.gd")

var _failures := 0
var _checks := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", label)
	else:
		print("PASS: ", label)

## Poll a condition across frames instead of assuming a fixed frame count: OSM
## parsing and spawn are asynchronous, so "90 frames" was a source of flakiness.
func _wait_until(predicate: Callable, max_frames: int = 600) -> bool:
	for i in range(max_frames):
		if predicate.call():
			return true
		await process_frame
	return false

## Run the camera rig for one nominal frame so a test reads exactly what the
## player would see after the input it just simulated.
func _initialise_rig(rig: VehicleCameraRig) -> void:
	rig._update_camera(0.016)

func _run() -> void:
	var corrupt := {"paint": {"color": [1], "tint_alpha": "bad"}, "stance": {"stiffness": -100},
		"engine": {"engine_id": "unknown"}, "camera": {"mode": 900}}
	var clean := ProfileManager.validate_profile(corrupt)
	_check(clean["paint"]["color"].size() == 4, "malformed color restored")
	_check(clean["stance"]["stiffness"] >= 0.6, "stiffness clamped")
	_check(clean["engine"]["engine_id"] == "stock_25", "unknown engine restored")
	_check(clean["camera"]["mode"] <= 2, "camera mode clamped")
	for dimensions in [Vector2(1280, 720), Vector2(2340, 1080), Vector2(1024, 768), Vector2(640, 360)]:
		var safe: Rect2 = Rect2(Vector2(30, 10), dimensions - Vector2(60, 30))
		for scale_factor in [0.7, 1.0, 1.5]:
			var positions: Dictionary = MobileLayoutUtil.controls(safe, scale_factor, Vector2(700, -500), Vector2(-700, -500))
			for key in ["steer", "pedals", "camera", "menu", "minimap"]:
				var rect: Rect2 = positions[key]
				_check(safe.encloses(rect), "safe mobile bounds: " + key + str(dimensions))
	var packed := load("res://addons/gevp/scenes/simcade_car.tscn") as PackedScene
	if packed == null:
		_check(false, "vehicle scene loads")
		quit(1)
		return
	var car := packed.instantiate() as Vehicle
	car.freeze = true
	root.add_child(car)
	car.set_physics_process(false)
	await physics_frame
	var profile := ProfileManager.get_default_profile()
	profile["stance"]["stiffness"] = 1.5
	VehicleTuningApplicator.apply_tuning(car, profile)
	var spring: float = car.front_left_wheel.spring_rate
	var body_inertia := car.vehicle_inertia
	VehicleTuningApplicator.apply_tuning(car, profile)
	_check(is_equal_approx(spring, car.front_left_wheel.spring_rate), "reapplying tune is idempotent")
	profile["paint"]["finish"] = "matte"
	VehicleTuningApplicator.apply_tuning(car, profile)
	_check(is_equal_approx(spring, car.front_left_wheel.spring_rate), "painting does not alter suspension")
	_check(body_inertia.is_equal_approx(car.vehicle_inertia), "painting does not compound inertia")
	profile["engine"]["drivetrain"] = "awd"
	VehicleTuningApplicator.apply_tuning(car, profile)
	_check(car.drive_wheels.size() == 4 and car.front_axle.is_drive_axle, "AWD rebuilds driven wheels")
	profile["engine"]["drivetrain"] = "rwd"
	profile["engine"]["engine_id"] = "v8_beast"
	VehicleTuningApplicator.apply_tuning(car, profile)
	_check(car.drive_wheels.size() == 2 and not car.front_axle.is_drive_axle, "RWD clears front drive state")
	_check(is_equal_approx(car.max_clutch_torque, car.max_torque * car.max_clutch_torque_ratio), "swap updates clutch")
	car.speed = 0.0
	car.process_steering(1.0 / 120.0)
	_check(is_finite(car.steering_amount), "steering remains finite at rest")
	car.front_left_wheel._update_surface("not-a-surface")
	_check(car.front_left_wheel.surface_type == "Road", "unknown surface fallback")
	var dry: float = car.front_left_wheel.current_cof
	car.set_meta("wetness", 1.0)
	car.front_left_wheel.refresh_surface()
	_check(car.front_left_wheel.current_cof < dry, "rain reduces tyre grip")
	var tracker := KudosTracker.new()
	_check(tracker.has_method("reset_motion_state"), "kudos exposes reset_motion_state")

	# ── Custom visual: ownership, variant selection, single body ──────────────
	profile["car"]["selected_car"] = "lada_vaz_2110"
	profile["settings"]["quality"] = "high"
	VehicleTuningApplicator.apply_tuning(car, profile)
	_check(String(car.get_meta("visual_variant", "")) == "high", "high preset uses the full model")
	var body := car.get_node_or_null("CustomBody")
	_check(body != null, "custom body mounted")
	if body != null:
		_check(body.owner == null, "custom body owner cleared")
	var custom_wheels := 0
	for wheel_name in VehicleTuningApplicator.WHEEL_NAMES:
		var wheel = car.get_node_or_null(wheel_name)
		if wheel != null:
			for child in wheel.wheel_node.get_children():
				if child.name == "CustomWheel":
					custom_wheels += 1
					_check(child.owner == null, "custom wheel owner cleared: " + wheel_name)
	_check(custom_wheels == 4, "four custom wheels mounted")
	profile["settings"]["quality"] = "balanced"
	VehicleTuningApplicator.apply_tuning(car, profile)
	_check(String(car.get_meta("visual_variant", "")) == "low", "balanced preset uses the low-poly model")
	profile["settings"]["quality"] = "low"
	VehicleTuningApplicator.apply_tuning(car, profile)
	_check(String(car.get_meta("visual_variant", "")) == "low", "low preset uses the low-poly model")
	var bodies := 0
	for child in car.get_children():
		if child.name == "CustomBody":
			bodies += 1
	_check(bodies == 1, "exactly one custom body after variant switches")

	for car_id in ["lada_vaz_2110", "priora", "simcade_car"]:
		profile["car"]["selected_car"] = car_id
		VehicleTuningApplicator.apply_tuning(car, profile)
		_check(car.get_meta("car_id", "") == car_id, "car visual selection: " + car_id)
	car.queue_free()
	await process_frame

	for path in ["res://scenes/garage.tscn", "res://scenes/main.tscn", "res://scenes/test_track.tscn"]:
		var scene_resource := load(path) as PackedScene
		_check(scene_resource != null, "scene load: " + path)
		if scene_resource == null:
			continue
		var scene := scene_resource.instantiate()
		root.add_child(scene)
		if scene is SemeyWorldManager:
			var activated: bool = await _wait_until(func(): return is_instance_valid(scene.vehicle) and not scene.vehicle.freeze)
			_check(activated, "scene vehicle activated: " + path)
			_check(scene.vehicle.global_position.is_finite(), "finite vehicle position: " + path)
			var controls: MobileControls = scene.mobile_controls
			_check(is_instance_valid(controls.camera_btn), "mobile camera button exists")
			if is_instance_valid(controls.camera):
				var initial_mode: int = int(controls.camera.current_mode)
				controls._cycle_camera()
				_check(int(controls.camera.current_mode) != initial_mode, "touch camera cycles mode")
				controls._cycle_camera()
				controls._cycle_camera()
				_check(int(controls.camera.current_mode) == initial_mode, "three camera modes wrap")
			controls._set_menu_open(true)
			_check(paused and controls.is_driving_blocked(), "mobile menu pauses and blocks driving")
			controls._set_menu_open(false)
			_check(not paused and not controls.is_driving_blocked(), "mobile menu resumes safely")
			if path.ends_with("test_track.tscn"):
				_check(scene._minimap == null, "test track runs without an OSM minimap")
				_check(scene._session != null, "test track session created")
		else:
			await _wait_until(func(): return is_instance_valid(scene.get_node_or_null("ShowroomCar")), 120)
			_check(is_instance_valid(scene.get_node_or_null("ShowroomCar")), "garage showroom car exists")
		for frame in range(30):
			await process_frame
		scene.queue_free()
		await process_frame
	# ── M1 rework scenes ──────────────────────────────────────────────────────
	var menu_scene := (load("res://scenes/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu_scene)
	await _wait_until(func(): return is_instance_valid(menu_scene._car), 180)
	_check(is_instance_valid(menu_scene._car), "M1 menu car spawned")
	_check(menu_scene.get_node_or_null("MenuUI") != null, "M1 menu UI built")
	menu_scene.queue_free()
	await process_frame

	var showcase := (load("res://scenes/showcase_bridge.tscn") as PackedScene).instantiate()
	root.add_child(showcase)
	var showcase_ready: bool = await _wait_until(func(): return is_instance_valid(showcase.vehicle) and not showcase.vehicle.freeze, 300)
	_check(showcase_ready, "M1 showcase car activated")
	_check(showcase.vehicle.countersteer_assist == 0.0, "M1 parking handling: no countersteer assist")
	_check(showcase.vehicle.steering_slip_assist >= 0.3, "M1 parking handling: slip assist does not block steering")
	_check(absf(showcase.vehicle.max_steering_angle - deg_to_rad(38.0)) < 0.01, "M1 parking handling: steering lock")
	_check(showcase.get_node_or_null("BridgeDeck") != null, "M1 bridge deck built")
	_check(showcase.get_node_or_null("CameraRig") != null, "M1 camera rig exists")
	# Free look: a mouse drag must swing the camera and release must spring it back.
	var rig: VehicleCameraRig = showcase.camera_rig
	var look_press := InputEventMouseButton.new()
	look_press.button_index = MOUSE_BUTTON_RIGHT
	look_press.pressed = true
	Input.parse_input_event(look_press)
	await process_frame
	var look_drag := InputEventMouseMotion.new()
	look_drag.relative = Vector2(180.0, 0.0)
	Input.parse_input_event(look_drag)
	await process_frame
	_check(absf(rig._look_yaw) > 0.05, "M1 drag looks around")
	var look_release := InputEventMouseButton.new()
	look_release.button_index = MOUSE_BUTTON_RIGHT
	look_release.pressed = false
	Input.parse_input_event(look_release)
	await process_frame
	# Camera rework: four modes, correct vertical look direction and sane heights.
	var hero: Vehicle = showcase.vehicle
	var cam: Camera3D = rig.camera
	_check(rig.mode == VehicleCameraRig.Mode.CHASE_NEAR, "M1 camera starts in close chase mode")
	_initialise_rig(rig)
	var close_height: float = cam.global_position.y - hero.global_position.y
	_check(close_height > 0.75 and close_height < 1.15, "M1 close chase camera is low")
	var close_distance: float = cam.global_position.distance_to(hero.global_position)
	_check(close_distance > 4.0 and close_distance < 5.3, "M1 close chase camera is close")
	_check(cam.global_transform.basis.y.y > 0.9, "M1 chase horizon is level")
	# Down drag must look DOWN and lift the camera; up drag must look up but never
	# put the camera under the bridge deck.
	rig._add_look(Vector2(0.0, 120.0))
	_initialise_rig(rig)
	_check(rig._look_pitch > 0.0, "M1 drag down looks down")
	_check(cam.global_position.y > hero.global_position.y + close_height + 0.1, "M1 drag down raises the chase camera")
	rig._look_pitch = VehicleCameraRig.LOOK_PITCH_MIN
	rig._look_yaw = 0.0
	_initialise_rig(rig)
	_check(cam.global_position.y > 0.2, "M1 look up keeps the camera above the road")
	_check(cam.global_position.y < hero.global_position.y + 0.2, "M1 look up drops the camera to chassis level")
	rig._look_pitch = 0.0
	rig._look_yaw = 0.0
	_initialise_rig(rig)
	# Mode order: close -> medium -> bonnet -> cockpit -> close.
	var mode_names: Array[String] = []
	var first_mode: int = int(rig.mode)
	for i in range(VehicleCameraRig.Mode.size()):
		mode_names.append(rig.mode_name())
		rig.cycle_mode()
		_initialise_rig(rig)
	_check(int(rig.mode) == first_mode, "M1 four camera modes wrap")
	_check(mode_names.size() == 4 and mode_names[0] != mode_names[1] and mode_names[1] != mode_names[2] and mode_names[2] != mode_names[3], "M1 camera modes have distinct names")
	# Bonnet camera sits above the hood, ahead of the windscreen.
	rig.mode = VehicleCameraRig.Mode.HOOD
	rig.snap()
	var bonnet_local: Vector3 = hero.global_transform.affine_inverse() * cam.global_position
	_check(bonnet_local.z < -0.8 and bonnet_local.z > -1.4, "M1 bonnet camera is over the hood")
	_check(bonnet_local.y > 0.7 and bonnet_local.y < 0.95, "M1 bonnet camera stays at hood height")
	# Cockpit camera is the driver's eye inside the cabin, not above the roof.
	rig.mode = VehicleCameraRig.Mode.COCKPIT
	rig.snap()
	var cockpit_local: Vector3 = hero.global_transform.affine_inverse() * cam.global_position
	_check(absf(cockpit_local.x) < 0.5, "M1 cockpit camera is on the driver's side")
	_check(cockpit_local.y > 0.6 and cockpit_local.y < 0.9, "M1 cockpit camera is at eye height")
	_check(absf(cockpit_local.z) < 1.5, "M1 cockpit camera is inside the wheelbase")
	rig.mode = VehicleCameraRig.Mode.CHASE_NEAR
	rig.snap()
	_check(showcase.hud != null and is_instance_valid(showcase.hud._speedometer), "M1 HUD built")
	_check(showcase.get_node_or_null("KmPosts") != null, "M1 bridge kilometre posts")
	_check(showcase.get_node_or_null("TowerDetails") != null, "M1 bridge tower details")
	_check(showcase.get_node_or_null("EmbankmentProps") != null, "M1 embankment props")
	_check(showcase.light_lenses != null, "M1 car light lenses attached")
	_check(showcase.light_lenses != null and showcase.light_lenses.get_meta("tail_materials", []).size() > 0, "M1 tail lamps use the optics material")
	_check(showcase.get_node_or_null("Traffic") != null, "M1 traffic flow exists")
	var traffic_cars := showcase.get_node_or_null("Traffic/Cars")
	var car_count: int = traffic_cars.get_child_count() if traffic_cars != null else 0
	_check(car_count >= 6 and car_count <= 10, "M1 traffic car count 6..10")
	if traffic_cars != null and car_count > 0:
		var lead_car := traffic_cars.get_child(0) as Node3D
		var start_z: float = lead_car.position.z
		var moved: bool = await _wait_until(func(): return absf(lead_car.position.z - start_z) > 0.5, 60)
		_check(moved, "M1 traffic cars move")
	# Park stops the car with the brakes instead of freezing the body: freezing a
	# rigid body and unfreezing it made the car pop up into the air.
	showcase.hud._select_gear("P")
	var parked: bool = await _wait_until(func(): return showcase.vehicle.linear_velocity.length() < 0.2, 240)
	_check(parked, "M1 P stops the car with the brakes")
	_check(not showcase.vehicle.freeze, "M1 P does not freeze the body")
	_check(showcase.vehicle.current_gear == 0, "M1 P selects neutral")
	showcase.hud._select_gear("D")
	var driving: bool = await _wait_until(func(): return showcase.vehicle.automatic_transmission, 60)
	_check(driving, "M1 D restores the automatic box")
	# N and R used to poll `Vehicle.shift()` in a while loop, which never leaves
	# the timed shift and froze the game; both must select the gear instantly.
	showcase.hud._select_gear("N")
	var neutral: bool = await _wait_until(func(): return showcase.vehicle.current_gear == 0, 30)
	_check(neutral, "M1 N selects neutral")
	showcase.hud._select_gear("R")
	var reversing: bool = await _wait_until(func(): return showcase.vehicle.current_gear == Transmission.GEAR_REVERSE, 30)
	_check(reversing, "M1 R selects reverse")
	for i in range(60):
		await physics_frame
	# Switching R -> D must leave the reverse gear, not keep reversing.
	showcase.hud._select_gear("D")
	var left_reverse: bool = await _wait_until(func():
		return showcase.vehicle.current_gear >= 0 and showcase.vehicle.automatic_transmission, 90)
	_check(left_reverse, "M1 D leaves reverse gear")
	# Creep: with no pedal input the automatic must pull the car to ~6 km/h.
	var creeping: bool = await _wait_until(func(): return showcase.vehicle.linear_velocity.length() * 3.6 > 2.0, 240)
	_check(creeping, "M1 automatic creeps in D")
	showcase.hud._toggle_pause()
	_check(paused and showcase.hud.is_paused(), "M1 pause works")
	showcase.hud._toggle_pause()
	_check(not paused and not showcase.hud.is_paused(), "M1 resume works")
	showcase.queue_free()
	await process_frame

	# Free anything still parented to the test root so the headless teardown does
	# not report leaked renderer instances.
	for child in root.get_children():
		child.free()
	await process_frame
	print("Runtime checks: %d; failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
