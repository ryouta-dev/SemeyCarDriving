class_name SemeySession
extends CanvasLayer

const MobileLayoutUtil = preload("res://scripts/ui/mobile_layout.gd")

var vehicle: Vehicle
var tile_manager: OSMTileManager
var world
var _tracker := KudosTracker.new()
var _audio_logic := CarAudioTriggers.new()
var _tyres: AudioStreamPlayer3D
var _impact: AudioStreamPlayer3D
var _sparks: ImpactParticles
var _ui_root: Control
var _panel: VBoxContainer
var _info: Label
var _message: Label
var _marker: MeshInstance3D
var _challenge := ""
var _targets := PackedVector3Array()
var _target_index := 0
var _elapsed := 0.0
var _started := false
var _parking_hold := 0.0
var _drift_points := 0.0
var _save_elapsed := 0.0
var _reward_cooldown := 0.0
var _display_elapsed := 0.0

func _ready() -> void:
	layer = 12
	_credits = ProfileManager.load_profile()["progression"]["credits"]
	_build_ui()
	_tyres = _sound("res://sounds/tire_screech.wav", true)
	_impact = _sound("res://sounds/impact.wav", false)
	_sparks = ImpactParticles.new()
	vehicle.add_child(_sparks)

func _sound(path: String, loop: bool) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	var stream := load(path) as AudioStreamWAV
	if stream != null:
		stream = stream.duplicate() as AudioStreamWAV
		if loop:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		player.stream = stream
	player.max_distance = 30.0
	player.volume_db = -80.0
	vehicle.add_child(player)
	return player

func _build_ui() -> void:
	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)
	_panel = VBoxContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_panel)
	_info = Label.new()
	_info.clip_text = true
	_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_info)
	_message = Label.new()
	_message.clip_text = true
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.text = "МЕНЮ → Испытания"
	_panel.add_child(_message)
	get_viewport().size_changed.connect(_schedule_hud_layout)
	_schedule_hud_layout()

func _schedule_hud_layout() -> void:
	_layout_hud.call_deferred()

func _layout_hud() -> void:
	if not is_inside_tree() or not is_instance_valid(_ui_root):
		return
	var safe: Rect2 = MobileLayoutUtil.safe_rect_for(_ui_root)
	var unit: float = MobileLayoutUtil.unit_for(safe)
	var width: float = minf(420.0 * unit, safe.size.x * 0.40)
	MobileLayoutUtil.place(_panel, Rect2(Vector2(safe.get_center().x - width * 0.5, safe.position.y + 18.0 * unit), Vector2(width, 112.0 * unit)))
	_info.add_theme_font_size_override("font_size", maxi(12, int(26.0 * unit)))
	_message.add_theme_font_size_override("font_size", maxi(11, int(24.0 * unit)))
	_info.custom_minimum_size.y = 30.0 * unit
	_message.custom_minimum_size.y = 56.0 * unit

func _physics_process(delta: float) -> void:
	if not is_instance_valid(vehicle) or vehicle.freeze:
		return
	var editing: bool = is_instance_valid(world.mobile_controls) and world.mobile_controls.is_driving_blocked()
	_panel.visible = not editing
	if editing:
		return
	_reward_cooldown = maxf(0.0, _reward_cooldown - delta)
	var telemetry := KudosTracker.Telemetry.new()
	var velocity := vehicle.linear_velocity
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var forward := -vehicle.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	telemetry.speed = horizontal.length()
	telemetry.forward_speed = horizontal.dot(forward)
	telemetry.slip_angle = absf(forward.signed_angle_to(horizontal.normalized(), Vector3.UP)) if horizontal.length() > 1.0 and telemetry.forward_speed > 0.0 else 0.0
	telemetry.yaw_rate = vehicle.angular_velocity.y
	telemetry.uprightness = vehicle.global_basis.y.dot(Vector3.UP)
	telemetry.braking = vehicle.brake_input > 0.05 or vehicle.handbrake_input > 0.05
	telemetry.wheels_on_ground = 0
	var road_wheels := 0
	for wheel in vehicle.wheel_array:
		if wheel.is_colliding():
			telemetry.wheels_on_ground += 1
			if wheel.surface_type == "Road":
				road_wheels += 1
	telemetry.on_road = road_wheels >= 2
	var before := _tracker.get_kudos()
	for event in _tracker.update(telemetry, delta):
		if event.label == "CRASH":
			var sound := _audio_logic.register_impact(absf(event.amount))
			if sound["play"]:
				_impact.volume_db = linear_to_db(sound["volume"] * 0.7)
				_impact.play()
				_sparks.burst(vehicle.global_position, absf(event.amount))
				var camera := get_viewport().get_camera_3d()
				if camera is ProVehicleCamera:
					camera.trigger_shake(minf(0.5, absf(event.amount) / 500.0), 0.35)
	if _challenge == "drift" and telemetry.slip_angle > 0.25 and telemetry.slip_angle < 1.5 and telemetry.wheels_on_ground >= 2:
		_drift_points += maxf(0.0, _tracker.get_kudos() - before)
	var squeal := _audio_logic.update_screech(telemetry.slip_angle, telemetry.speed, vehicle.handbrake_input < 0.1, delta)
	_tyres.volume_db = linear_to_db(maxf(0.0001, squeal * 0.5))
	if squeal > 0.01 and not _tyres.playing:
		_tyres.play()
	elif squeal <= 0.01:
		_tyres.stop()
	_update_challenge(delta)
	_save_elapsed += delta
	if _save_elapsed >= 15.0:
		_save_elapsed = 0.0
		save_progress()
	_display_elapsed += delta
	if _display_elapsed >= 0.1:
		_display_elapsed = 0.0
		_update_labels()

func _update_labels() -> void:
	# Cache bank state only on save/reward, not by reading disk every frame.
	_info.text = "Очки %d ×%.1f · %d кр." % [_tracker.get_kudos(), _tracker.get_combo(), _credits]
	if _challenge == "sprint":
		var distance := vehicle.global_position.distance_to(_targets[_target_index])
		_message.text = "Спринт • точка %d/%d • %.1f с • %.0f м" % [_target_index + 1, _targets.size(), _elapsed, distance]
	elif _challenge == "drift":
		_message.text = "Дрифт • осталось %.1f с • очки %d / 300" % [maxf(0.0, 30.0 - _elapsed), int(_drift_points)]
	elif _challenge == "parking":
		_message.text = "Остановись в зелёной зоне на 3 с • %.1f / 3 с" % _parking_hold

var _credits := 0

func start_challenge(kind: String) -> void:
	if is_instance_valid(world.mobile_controls) and world.mobile_controls.is_driving_blocked():
		return
	if _reward_cooldown > 0.0:
		_message.text = "Следующее испытание через %.0f с" % _reward_cooldown
		return
	cancel_challenge()
	_elapsed = 0.0
	_parking_hold = 0.0
	_target_index = 0
	_started = false
	if kind == "drift":
		_challenge = kind
		_started = true
		_drift_points = 0.0
		return
	if not is_instance_valid(tile_manager):
		_message.text = "На полигоне доступны дрифт и тесты физики. Спринт — в городе."
		return
	if kind == "parking":
		var best := INF
		for entry in tile_manager.collect_ways_near(vehicle.global_position, 500.0):
			if entry["way"].tags.get("amenity", "") != "parking" or entry["points"].size() < 3:
				continue
			var centre := PolygonUtils.polygon_centroid(entry["points"])
			var distance := centre.distance_squared_to(vehicle.global_position)
			if distance < best:
				best = distance
				_targets = PackedVector3Array([centre])
	else:
		var best := -INF
		for entry in tile_manager.collect_ways_near(vehicle.global_position, 500.0):
			if entry["way"].tags.get("highway", "") not in ["primary", "secondary", "tertiary", "residential", "unclassified"]:
				continue
			var points: PackedVector3Array = entry["points"].duplicate()
			var length := 0.0
			for i in range(1, points.size()):
				length += points[i].distance_to(points[i - 1])
			if length < 70.0 or length > 1000.0:
				continue
			if points[-1].distance_to(vehicle.global_position) < points[0].distance_to(vehicle.global_position):
				points.reverse()
			var merit := length * 0.2 - points[0].distance_to(vehicle.global_position)
			if merit > best:
				best = merit
				_targets = PackedVector3Array([points[0], _along(points, length * 0.5), points[-1]])
	if _targets.is_empty():
		_message.text = "Подходящая зона не найдена на этом участке карты."
		return
	_challenge = kind
	_show_target()

static func _along(points: PackedVector3Array, distance: float) -> Vector3:
	for i in range(1, points.size()):
		var length := points[i].distance_to(points[i - 1])
		if distance <= length:
			return points[i - 1].lerp(points[i], distance / maxf(0.001, length))
		distance -= length
	return points[-1]

func _show_target() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 3.6
	mesh.outer_radius = 4.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 1.0, 0.4)
	material.emission_enabled = true
	material.emission = Color(0.05, 0.5, 0.1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	_marker.mesh = mesh
	world.add_child(_marker)
	var position := _targets[_target_index]
	position.y = tile_manager.get_terrain_height(position) + 0.25
	_marker.global_position = position

func _update_challenge(delta: float) -> void:
	if _challenge.is_empty():
		return
	if _started:
		_elapsed += delta
	if _challenge == "drift":
		if _elapsed >= 30.0:
			var gained := int(_drift_points)
			if gained >= 300:
				_finish(200, "Дрифт пройден!")
			else:
				cancel_challenge()
				_message.text = "Нужно 300 очков за 30 с. Попробуй ещё раз."
		return
	var horizontal := Vector2(vehicle.global_position.x, vehicle.global_position.z)
	var target := Vector2(_targets[_target_index].x, _targets[_target_index].z)
	var inside := horizontal.distance_to(target) <= 7.0
	if _challenge == "parking":
		_started = true
		_parking_hold = _parking_hold + delta if inside and vehicle.linear_velocity.length() < 0.5 else 0.0
		if _parking_hold >= 3.0:
			_finish(100, "Парковка выполнена!")
	elif inside:
		_started = true
		_target_index += 1
		if _target_index >= _targets.size():
			var profile := ProfileManager.load_profile()
			var best: float = profile["progression"]["best_sprint"]
			if best <= 0.0 or _elapsed < best:
				profile["progression"]["best_sprint"] = _elapsed
				ProfileManager.save_sections({"progression": profile["progression"]})
			_finish(150, "Спринт: %.1f с!" % _elapsed)
		else:
			_show_target()
	if _elapsed > 180.0 and _challenge != "drift":
		cancel_challenge()
		_message.text = "Время истекло."

func _finish(reward: int, text: String) -> void:
	var profile := ProfileManager.load_profile()
	profile["progression"]["credits"] += reward
	var success := ProfileManager.save_sections({"progression": profile["progression"]})
	_credits = profile["progression"]["credits"] if success else _credits
	cancel_challenge()
	_reward_cooldown = 20.0
	_message.text = text + (" +%d кредитов" % reward if success else " — награда не сохранена, проверь запись на диск")

func cancel_challenge() -> void:
	_challenge = ""
	_targets.clear()
	if is_instance_valid(_marker):
		_marker.queue_free()
		_marker = null
	_tracker.reset_motion_state()

func save_progress() -> void:
	var profile := ProfileManager.load_profile()
	_credits = profile["progression"]["credits"]
	if _tracker.get_kudos() > profile["progression"]["best_drift"]:
		profile["progression"]["best_drift"] = _tracker.get_kudos()
		ProfileManager.save_sections({"progression": profile["progression"]})

func set_hint(text: String) -> void:
	_message.text = text
