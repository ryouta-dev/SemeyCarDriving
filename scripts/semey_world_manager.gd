class_name SemeyWorldManager
extends Node3D

const MobileLayoutUtil = preload("res://scripts/ui/mobile_layout.gd")

@export var tile_manager: OSMTileManager
@export var sky_controller: SkyController
@export var weather_controller: WeatherController
@export var street_lamp_lights: StreetLampLights
@export var vehicle: Vehicle
@export var headlights: Node3D
@export var mobile_controls: MobileControls
var _loading: CanvasLayer
var _loading_label: Label
var _spawning := false
var _spawn_position := Vector3.ZERO
var _spawn_yaw := 0.0
var _rain: RainEffect
var _session: SemeySession
var _pause_ui: CanvasLayer
var _pause_requested: bool = false
var _leaving_world: bool = false
var _map_root: Control
var _minimap: Minimap
var _profile: Dictionary = {}

func _ready() -> void:
	await _boot()

func _boot() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if is_instance_valid(vehicle):
		vehicle.freeze = true
		vehicle.set_physics_process(false)
	_profile = ProfileManager.load_profile()
	_apply_profile(_profile)
	_prepare_scene()
	_show_loading(_loading_text())
	await get_tree().process_frame
	if not is_inside_tree() or _leaving_world:
		return
	if not _resolve_spawn():
		return
	await _spawn_vehicle()
	if not is_inside_tree() or _leaving_world:
		return
	_session = SemeySession.new()
	_session.vehicle = vehicle
	_session.tile_manager = tile_manager
	_session.world = self
	add_child(_session)
	_bind_mobile_actions()
	if _wants_minimap():
		_add_minimap()
	if _wants_traffic():
		var traffic := SemeyTraffic.new()
		traffic.vehicle = vehicle
		traffic.tile_manager = tile_manager
		add_child(traffic)
	_on_world_ready()

## Everything both the city and the test track need: audio, tuning, sky, rain,
## weather wiring, mobile signals and the quality preset.
func _apply_profile(profile: Dictionary) -> void:
	AudioServer.set_bus_mute(0, bool(profile["settings"].get("muted", false)))
	set_meta("light_budget", 6 if profile["settings"]["quality"] == "low" else (18 if profile["settings"]["quality"] == "high" else 10))
	VehicleTuningApplicator.apply_tuning(vehicle, profile)
	if is_instance_valid(sky_controller):
		sky_controller.day_night_changed.connect(_on_day_changed)
		sky_controller.dynamic_cycle = profile["settings"]["dynamic_time"]
		sky_controller.set_time_of_day(profile["environment"]["time_of_day"])
		_on_day_changed(sky_controller.is_day())
	_rain = RainEffect.new()
	_rain.follow = vehicle
	add_child(_rain)
	if is_instance_valid(weather_controller):
		weather_controller.wetness_changed.connect(_on_wetness_changed)
		weather_controller.set_wet(profile["environment"]["weather"] == "rain")
		_on_wetness_changed(weather_controller.get_level())
	if is_instance_valid(mobile_controls):
		mobile_controls.day_night_toggle_requested.connect(toggle_day_night)
		mobile_controls.weather_toggle_requested.connect(toggle_weather)
		mobile_controls.garage_requested.connect(open_garage)
	QualitySettings.apply(get_viewport(), profile["settings"]["quality"])

# ── Per-world hooks ───────────────────────────────────────────────────────────
# The city implements these against OSM tiles; the test track overrides them so
# it reuses the whole boot flow instead of copy-pasting _ready (which used to
# drift: no minimap, no shared guards, no orientation handling).

## Build world-specific geometry before the loading screen is shown.
func _prepare_scene() -> void:
	pass

## Decide where the car appears. Returns false when the world cannot be prepared
## and the caller should stop booting (the loading label already explains why).
func _resolve_spawn() -> bool:
	if not is_instance_valid(tile_manager) or not tile_manager.is_data_ready():
		if is_instance_valid(_loading_label):
			_loading_label.text = "Не удалось загрузить карту. Нажми ГАРАЖ или G."
		return false
	_pick_spawn()
	return true

## Make the ground under `world_pos` physical before dropping the car on it.
func _prepare_spawn(world_pos: Vector3) -> bool:
	if not is_instance_valid(tile_manager):
		return true
	return await tile_manager.prepare_spawn(world_pos)

func _wants_minimap() -> bool:
	return is_instance_valid(tile_manager)

func _wants_traffic() -> bool:
	return is_instance_valid(tile_manager) and bool(_profile.get("settings", {}).get("traffic", false))

func _loading_text() -> String:
	return "Подготовка города…"

func _spawn_loading_text() -> String:
	return "Загрузка дорог и коллизий…"

## Called once the session exists; worlds can inject their opening hint.
func _on_world_ready() -> void:
	pass

func _pick_spawn() -> void:
	var data = tile_manager.get_osm_data()
	if data == null or data.ways.is_empty():
		data = tile_manager.collect_osm_near(Vector3.ZERO, 600.0)
	var nearest := INF
	var found := false
	for way in data.ways.values():
		if way.tags.get("amenity", "") != "parking":
			continue
		var points := PolygonUtils.way_to_points(way.node_ids, data.nodes)
		if points.size() < 3:
			continue
		var centre := PolygonUtils.polygon_centroid(points)
		if centre.length_squared() < nearest:
			nearest = centre.length_squared()
			_spawn_position = centre
			found = true
	if found:
		return
	for way in data.ways.values():
		if way.tags.get("highway", "") not in ["primary", "secondary", "tertiary", "residential", "service", "unclassified"]:
			continue
		var points := PolygonUtils.way_to_points(way.node_ids, data.nodes)
		for i in range(1, points.size()):
			var a := Vector2(points[i - 1].x, points[i - 1].z)
			var b := Vector2(points[i].x, points[i].z)
			var point := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, a, b)
			if point.length_squared() < nearest:
				nearest = point.length_squared()
				_spawn_position = Vector3(point.x, 0, point.y)
				var direction := points[i] - points[i - 1]
				_spawn_yaw = atan2(-direction.x, -direction.z)

func _spawn_vehicle() -> bool:
	if _spawning or not is_instance_valid(vehicle):
		return false
	_spawning = true
	_show_loading(_spawn_loading_text())
	vehicle.freeze = true
	vehicle.set_physics_process(false)
	if is_instance_valid(mobile_controls):
		mobile_controls.reset_inputs()
	vehicle.global_position = _spawn_position + Vector3.UP * 2.0
	var prepared: bool = await _prepare_spawn(_spawn_position)
	# The player may have left for the garage while the tile/ground prep was
	# running; never touch nodes of a scene that is being replaced.
	if not is_inside_tree() or _leaving_world:
		_spawning = false
		return false
	if not prepared:
		if is_instance_valid(_loading_label):
			_loading_label.text = "Ошибка подготовки карты. Вернись в гараж."
		_spawning = false
		return false
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or _leaving_world:
		_spawning = false
		return false
	var query := PhysicsRayQueryParameters3D.create(_spawn_position + Vector3.UP * 80.0, _spawn_position - Vector3.UP * 20.0)
	query.exclude = [vehicle.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var height: float = hit.position.y if not hit.is_empty() else (tile_manager.get_terrain_height(_spawn_position) if is_instance_valid(tile_manager) else 0.0)
	vehicle.global_position = Vector3(_spawn_position.x, height + 0.85, _spawn_position.z)
	vehicle.global_rotation = Vector3(0, _spawn_yaw, 0)
	_reset_physics_history()
	await get_tree().physics_frame
	if not is_inside_tree() or _leaving_world:
		_spawning = false
		return false
	vehicle.freeze = false
	vehicle.set_physics_process(true)
	_spawning = false
	if is_instance_valid(_loading):
		_loading.queue_free()
		_loading = null
	var camera := get_viewport().get_camera_3d()
	if camera is ProVehicleCamera:
		camera.snap_to_target()
	return true

func _reset_physics_history() -> void:
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	vehicle.previous_global_position = vehicle.global_position
	vehicle.local_velocity = Vector3.ZERO
	vehicle.speed = 0.0
	vehicle.motor_rpm = vehicle.idle_rpm
	vehicle.clutch_torque = 0.0
	vehicle.steering_input = 0.0
	vehicle.throttle_input = 0.0
	vehicle.throttle_amount = 0.0
	vehicle.brake_input = 0.0
	vehicle.handbrake_input = 0.0
	vehicle.steering_amount = 0.0
	vehicle.true_steering_amount = 0.0
	for wheel in vehicle.wheel_array:
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

func respawn() -> void:
	if _session != null:
		_session.cancel_challenge()
	await _spawn_vehicle()

func _show_loading(message: String) -> void:
	if not is_instance_valid(_loading):
		_loading = CanvasLayer.new()
		_loading.layer = 40
		_loading.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_loading)
		var shade := ColorRect.new()
		shade.color = Color(0.02, 0.04, 0.08, 0.95)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_loading.add_child(shade)
		_loading_label = Label.new()
		_loading_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_loading_label.add_theme_font_size_override("font_size", 30)
		_loading.add_child(_loading_label)
		var back := Button.new()
		back.text = "В гараж"
		back.position = Vector2(32, 32)
		back.pressed.connect(open_garage)
		_loading.add_child(back)
	_loading_label.text = message

func _bind_mobile_actions() -> void:
	if not is_instance_valid(mobile_controls):
		return
	if not mobile_controls.respawn_requested.is_connected(respawn):
		mobile_controls.respawn_requested.connect(respawn)
	if not mobile_controls.challenge_requested.is_connected(_session.start_challenge):
		mobile_controls.challenge_requested.connect(_session.start_challenge)
	if not mobile_controls.ui_blocked_changed.is_connected(_on_ui_blocked):
		mobile_controls.ui_blocked_changed.connect(_on_ui_blocked)

func _on_ui_blocked(_blocked: bool) -> void:
	var controller: Node = get_node_or_null("SemeyPlayerController")
	if controller != null and controller.has_method("reset_inputs"):
		controller.call("reset_inputs")

func _add_minimap() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	_map_root = Control.new()
	_map_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_map_root)
	_minimap = Minimap.new()
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Resolve references before add_child triggers the minimap's _ready().
	_minimap.car_node_path = vehicle.get_path()
	_minimap.tile_manager_node_path = tile_manager.get_path()
	_map_root.add_child(_minimap)
	_minimap.visible = mobile_controls.minimap_visible if is_instance_valid(mobile_controls) else true
	if is_instance_valid(mobile_controls):
		mobile_controls.minimap_toggled.connect(_set_minimap_visible)
	get_viewport().size_changed.connect(_schedule_minimap_layout)
	_schedule_minimap_layout()

func _set_minimap_visible(enabled: bool) -> void:
	if is_instance_valid(_minimap):
		_minimap.visible = enabled

func _schedule_minimap_layout() -> void:
	_layout_minimap.call_deferred()

func _layout_minimap() -> void:
	if not is_instance_valid(_map_root) or not is_instance_valid(_minimap):
		return
	var safe: Rect2 = MobileLayoutUtil.safe_rect_for(_map_root)
	var unit: float = MobileLayoutUtil.unit_for(safe)
	MobileLayoutUtil.place(_minimap, Rect2(safe.position + Vector2.ONE * 16.0 * unit, Vector2.ONE * 148.0 * unit))

func _on_day_changed(is_day: bool) -> void:
	if is_instance_valid(headlights):
		headlights.set_on(not is_day)
	if is_instance_valid(street_lamp_lights):
		street_lamp_lights.set_on(not is_day)

func _on_wetness_changed(level: float) -> void:
	if is_instance_valid(vehicle):
		vehicle.set_meta("wetness", level)
		for wheel in vehicle.wheel_array:
			wheel.refresh_surface()
	if is_instance_valid(_rain):
		_rain.set_level(level)

func _save_environment() -> void:
	if is_instance_valid(sky_controller) and is_instance_valid(weather_controller):
		ProfileManager.save_sections({"environment": {"time_of_day": sky_controller.get_time_of_day(),
			"weather": "rain" if weather_controller.is_wet() else "clear"}})

func toggle_weather() -> void:
	if is_instance_valid(weather_controller):
		weather_controller.toggle()
		_save_environment()

func toggle_day_night() -> void:
	if is_instance_valid(sky_controller):
		sky_controller.set_time_of_day("night" if sky_controller.is_day() else "day")
		_save_environment()

func open_garage() -> void:
	if _leaving_world:
		return
	_leaving_world = true
	_pause_requested = false
	_save_environment()
	if _session != null:
		_session.save_progress()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/garage.tscn")

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		if is_inside_tree() and not is_queued_for_deletion() and not _leaving_world:
			_pause_for_resume()

func _pause_for_resume() -> void:
	# Notifications can arrive while SceneTree is attaching children.
	# Queue the WHOLE operation: do not pause the tree or add UI here.
	if _pause_requested or is_instance_valid(_pause_ui) or _leaving_world:
		return
	_pause_requested = true
	_apply_pause_for_resume.call_deferred()

func _apply_pause_for_resume() -> void:
	_pause_requested = false
	if not is_inside_tree() or is_queued_for_deletion() or _leaving_world:
		return
	# Ignore startup/respawn notifications before the driving scene is active.
	if not is_node_ready() or _spawning:
		return
	if is_instance_valid(_pause_ui) or get_tree().paused:
		return
	_save_environment()
	if is_instance_valid(_session):
		_session.save_progress()
	if is_instance_valid(mobile_controls):
		mobile_controls.reset_inputs()
	# Build the subtree detached, then attach once from the deferred callback.
	var pause_layer: CanvasLayer = CanvasLayer.new()
	pause_layer.layer = 50
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(shade)
	var resume: Button = Button.new()
	resume.text = "Игра на паузе — продолжить"
	resume.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	resume.position -= Vector2(220, 35)
	resume.size = Vector2(440, 70)
	resume.pressed.connect(_resume_after_focus_loss)
	pause_layer.add_child(resume)
	_pause_ui = pause_layer
	add_child(pause_layer)
	_schedule_resume_layout()
	if not get_viewport().size_changed.is_connected(_schedule_resume_layout):
		get_viewport().size_changed.connect(_schedule_resume_layout)
	# Pause only after the always-processing resume UI is attached.
	get_tree().paused = true

func _resume_after_focus_loss() -> void:
	if not is_inside_tree() or _leaving_world:
		return
	if is_instance_valid(_pause_ui):
		_pause_ui.visible = false
		_pause_ui.queue_free()
	_pause_ui = null
	_pause_requested = false
	if is_instance_valid(mobile_controls):
		mobile_controls.reset_inputs()
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5: toggle_weather()
			KEY_F6: toggle_day_night()
			KEY_R: respawn()
			KEY_ESCAPE, KEY_G: open_garage()

func _schedule_resume_layout() -> void:
	_layout_resume_ui.call_deferred()

func _layout_resume_ui() -> void:
	if not is_instance_valid(_pause_ui) or _pause_ui.get_child_count() < 2:
		return
	var shade: Control = _pause_ui.get_child(0) as Control
	var resume: Button = _pause_ui.get_child(1) as Button
	if shade == null or resume == null:
		return
	var safe: Rect2 = MobileLayoutUtil.safe_rect_for(shade)
	var unit: float = MobileLayoutUtil.unit_for(safe)
	var dimensions: Vector2 = Vector2(560, 96) * unit
	MobileLayoutUtil.place(resume, Rect2(safe.get_center() - dimensions * 0.5, dimensions))
	resume.add_theme_font_size_override("font_size", maxi(14, int(26.0 * unit)))
