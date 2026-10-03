@tool
extends Camera3D
class_name ProVehicleCamera

enum CameraMode {
	MEDIUM = 0,
	FAR = 1,
	FIRST_PERSON = 2
}

signal camera_mode_changed(new_mode: int)

@export_group("Target Tracking")
@export var follow_this: Node3D
@export var follow_distance: float = 5.5
@export var follow_height: float = 2.2

@export_group("Camera Modes")
@export var current_mode: CameraMode = CameraMode.MEDIUM:
	set(val):
		current_mode = val
		_apply_mode_settings()
@export var driver_seat_offset: Vector3 = Vector3(-0.36, 1.10, -0.20)
@export var seat_height_offset: float = 0.0
@export var seat_forward_offset: float = 0.0

@export_group("Physics & Elasticity")
@export var speed: float = 14.0

@export_group("Manual Orbit / Look Around")
@export var enable_orbit: bool = true
@export var orbit_sensitivity: float = 0.0025
@export var orbit_return_speed: float = 2.5
@export var orbit_max_pitch_up: float = 0.5
@export var orbit_max_pitch_down: float = 0.25

@export_group("Dynamic FOV")
@export var enable_fov_warp: bool = true
@export var minimum_fov: float = 70.0
@export var maximum_fov: float = 85.0
@export var top_speed_threshold: float = 40.0
@export var fov_smooth_speed: float = 5.0

@export_group("Visual Juice")
@export var enable_banking: bool = true
@export var banking_intensity: float = 0.35
@export var enable_look_back: bool = true
@export var look_back_action: String = "look_back"

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0

# Manual orbit variables with smooth interpolation
var target_yaw: float = 0.0
var target_pitch: float = 0.0
var current_yaw: float = 0.0
var current_pitch: float = 0.0
var is_orbiting: bool = false

var _base_rear_vector: Vector3 = Vector3.BACK
var _has_snapped: bool = false

func _ready() -> void:
	set_as_top_level(true)
	if not Engine.is_editor_hint():
		_load_camera_config()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C or event.keycode == KEY_V:
			cycle_camera_mode()

func snap_to_target() -> void:
	if not is_instance_valid(follow_this):
		return
	var car_origin: Vector3 = follow_this.global_transform.origin
	var car_basis: Basis = follow_this.global_transform.basis
	var target_rear: Vector3 = car_basis.z
	target_rear.y = 0.0
	if target_rear.is_zero_approx():
		target_rear = Vector3.BACK
	else:
		target_rear = target_rear.normalized()

	_base_rear_vector = target_rear
	target_yaw = 0.0
	target_pitch = 0.0
	current_yaw = 0.0
	current_pitch = 0.0
	is_orbiting = false
	_has_snapped = true

	if current_mode == CameraMode.FIRST_PERSON:
		var local_head := driver_seat_offset + Vector3(0.0, seat_height_offset, -seat_forward_offset)
		global_position = follow_this.to_global(local_head)
		var world_forward := -car_basis.z.normalized()
		var world_up := car_basis.y.normalized()
		if not world_forward.is_zero_approx() and not world_up.is_zero_approx():
			global_transform = Transform3D(Basis.looking_at(world_forward, world_up), global_position)
	else:
		global_position = car_origin + (_base_rear_vector * follow_distance)
		global_position.y = car_origin.y + follow_height
		look_at(car_origin + Vector3.UP * 1.0, Vector3.UP)

func rotate_orbit(relative: Vector2) -> void:
	if not enable_orbit:
		return
	target_yaw -= relative.x * orbit_sensitivity
	target_pitch = clampf(target_pitch + relative.y * orbit_sensitivity, -orbit_max_pitch_down, orbit_max_pitch_up)
	current_yaw = target_yaw
	current_pitch = target_pitch
	is_orbiting = true

func stop_orbit() -> void:
	is_orbiting = false

func cycle_camera_mode() -> CameraMode:
	var next_mode: int = (int(current_mode) + 1) % 3
	set_camera_mode(next_mode)
	return current_mode

func set_camera_mode(mode: int) -> void:
	current_mode = (mode % 3) as CameraMode
	_apply_mode_settings()
	_save_camera_config()
	camera_mode_changed.emit(int(current_mode))

func _apply_mode_settings() -> void:
	match current_mode:
		CameraMode.MEDIUM:
			follow_distance = 5.5
			follow_height = 2.2
			near = 0.15
		CameraMode.FAR:
			follow_distance = 8.8
			follow_height = 3.2
			near = 0.15
		CameraMode.FIRST_PERSON:
			near = 0.05

func adjust_seat(delta_height: float, delta_forward: float) -> void:
	seat_height_offset = clampf(seat_height_offset + delta_height, -0.25, 0.25)
	seat_forward_offset = clampf(seat_forward_offset + delta_forward, -0.25, 0.25)
	_save_camera_config()

func reset_seat() -> void:
	seat_height_offset = 0.0
	seat_forward_offset = 0.0
	_save_camera_config()

func _load_camera_config() -> void:
	var prof := ProfileManager.load_profile()
	var cam_cfg: Dictionary = prof.get("camera", {})
	var m: int = cam_cfg.get("mode", 0)
	seat_height_offset = clampf(cam_cfg.get("seat_height", 0.0), -0.25, 0.25)
	seat_forward_offset = clampf(cam_cfg.get("seat_forward", 0.0), -0.25, 0.25)
	
	var car_id: String = prof.get("car", {}).get("selected_car", "simcade_car")
	match car_id:
		"lada_vaz_2110":
			driver_seat_offset = Vector3(-0.36, 1.10, -0.22)
		"priora":
			driver_seat_offset = Vector3(-0.36, 1.10, -0.18)
		_:
			driver_seat_offset = Vector3(-0.36, 1.10, -0.15)
			
	set_camera_mode(m)

func _save_camera_config() -> void:
	var prof := ProfileManager.load_profile()
	if not prof.has("camera"):
		prof["camera"] = {}
	prof["camera"]["mode"] = int(current_mode)
	prof["camera"]["seat_height"] = seat_height_offset
	prof["camera"]["seat_forward"] = seat_forward_offset
	ProfileManager.save_profile(prof)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(follow_this):
		return
	if Engine.is_editor_hint():
		return

	if not _has_snapped:
		snap_to_target()

	var car_origin: Vector3 = follow_this.global_transform.origin
	var car_basis: Basis = follow_this.global_transform.basis
	
	var car_speed: float = 0.0
	var forward_speed: float = 0.0
	if "linear_velocity" in follow_this:
		var vel: Vector3 = follow_this.linear_velocity
		car_speed = vel.length()
		var forward_axis: Vector3 = -car_basis.z
		forward_axis.y = 0.0
		if not forward_axis.is_zero_approx():
			forward_speed = vel.dot(forward_axis.normalized())
	elif "speed" in follow_this:
		car_speed = follow_this.speed
		forward_speed = car_speed

	# Update base rear heading from vehicle orientation
	var target_rear: Vector3 = car_basis.z
	target_rear.y = 0.0
	if target_rear.is_zero_approx():
		target_rear = Vector3.BACK
	else:
		target_rear = target_rear.normalized()

	if _base_rear_vector.is_zero_approx():
		_base_rear_vector = target_rear
	else:
		# Smoothly track car rear direction when turning
		_base_rear_vector = _base_rear_vector.slerp(target_rear, clampf(speed * 0.25 * delta, 0.0, 1.0)).normalized()

	# Auto-straightening ONLY when actively driving in a direction:
	# If moving forward (> 1.8 m/s): straighten looking forward (target 0.0)
	# If moving backward (< -1.8 m/s): straighten looking backward (target PI)
	# If stopped/slow (<= 1.8 m/s): stay EXACTLY where player rotated it!
	if not is_orbiting:
		if forward_speed > 1.8:
			var diff_yaw: float = wrapf(0.0 - target_yaw, -PI, PI)
			target_yaw = move_toward(target_yaw, target_yaw + diff_yaw, orbit_return_speed * delta)
			target_pitch = move_toward(target_pitch, 0.0, orbit_return_speed * delta)
		elif forward_speed < -1.8:
			var target_reverse_yaw: float = PI
			var diff_yaw: float = wrapf(target_reverse_yaw - target_yaw, -PI, PI)
			target_yaw = move_toward(target_yaw, target_yaw + diff_yaw, orbit_return_speed * delta)
			target_pitch = move_toward(target_pitch, 0.0, orbit_return_speed * delta)

		current_yaw = lerp_angle(current_yaw, target_yaw, clampf(10.0 * delta, 0.0, 1.0))
		current_pitch = lerp(current_pitch, target_pitch, clampf(10.0 * delta, 0.0, 1.0))

	# === 1. FIRST PERSON (COCKPIT) MODE ===
	if current_mode == CameraMode.FIRST_PERSON:
		var local_head := driver_seat_offset + Vector3(0.0, seat_height_offset, -seat_forward_offset)
		var head_world_pos := follow_this.to_global(local_head)
		
		# Shake in first person
		if _shake_timer > 0.0:
			_shake_timer -= delta
			var random_offset := Vector3(
				randf_range(-_shake_intensity, _shake_intensity),
				randf_range(-_shake_intensity, _shake_intensity),
				randf_range(-_shake_intensity, _shake_intensity)
			) * 0.3
			head_world_pos += random_offset
			_shake_intensity = lerp(_shake_intensity, 0.0, delta * (1.0 / _shake_duration))
		
		global_position = head_world_pos
		
		# Direction driver's head is looking (relative to car cockpit)
		var local_look := Vector3(
			-sin(current_yaw) * cos(current_pitch),
			sin(current_pitch),
			-cos(current_yaw) * cos(current_pitch)
		).normalized()
		
		var world_look_dir := (car_basis * local_look).normalized()
		var world_up := car_basis.y.normalized()
		if not world_look_dir.is_zero_approx() and not world_up.is_zero_approx():
			global_transform = Transform3D(Basis.looking_at(world_look_dir, world_up), global_position)
		
		if enable_fov_warp:
			var target_fov: float = lerp(75.0, 85.0, clampf(car_speed / top_speed_threshold, 0.0, 1.0))
			fov = lerp(fov, target_fov, clampf(fov_smooth_speed * delta, 0.0, 1.0))
		return

	# === 2. THIRD PERSON (MEDIUM & FAR) MODES ===
	var is_looking_back: bool = false
	if enable_look_back and InputMap.has_action(look_back_action):
		is_looking_back = Input.is_action_pressed(look_back_action)

	if is_looking_back:
		var forward_vector: Vector3 = -target_rear * follow_distance
		var target_position: Vector3 = car_origin + forward_vector
		target_position.y = car_origin.y + follow_height
		global_position = global_position.lerp(target_position, clampf(speed * delta, 0.0, 1.0))
	else:
		var orbit_vector: Vector3 = _base_rear_vector.rotated(Vector3.UP, current_yaw)
		var target_position: Vector3 = car_origin + (orbit_vector * follow_distance)
		target_position.y = car_origin.y + follow_height + (current_pitch * follow_distance)
		
		# CAMERA COLLISION (RayCast to prevent clipping through buildings/terrain)
		var world_3d := get_world_3d()
		if world_3d and is_inside_tree():
			var space_state := world_3d.direct_space_state
			if space_state:
				var from_pos := car_origin + Vector3(0.0, follow_height * 0.5, 0.0)
				var query := PhysicsRayQueryParameters3D.create(from_pos, target_position)
				var exclude_rids: Array[RID] = []
				if follow_this is CollisionObject3D:
					exclude_rids.append((follow_this as CollisionObject3D).get_rid())
				for child in follow_this.get_children():
					if child is CollisionObject3D:
						exclude_rids.append((child as CollisionObject3D).get_rid())
				query.exclude = exclude_rids
				
				var result := space_state.intersect_ray(query)
				if result and not result.is_empty():
					var hit_pos: Vector3 = result.position
					var hit_dist: float = (hit_pos - car_origin).length()
					if hit_dist > 1.2:
						target_position = hit_pos + (car_origin - hit_pos).normalized() * 0.5
			
		global_position = global_position.lerp(target_position, clampf(speed * delta, 0.0, 1.0))

	# Dynamic FOV
	if enable_fov_warp:
		var target_fov: float = lerp(minimum_fov, maximum_fov, clamp(car_speed / top_speed_threshold, 0.0, 1.0))
		fov = lerp(fov, target_fov, clampf(fov_smooth_speed * delta, 0.0, 1.0))

	# Look Direction
	var look_target := car_origin + Vector3.UP * (1.0 - current_pitch * 0.5)
	if not global_position.is_equal_approx(look_target):
		var look_dir := (look_target - global_position).normalized()
		if absf(look_dir.dot(Vector3.UP)) < 0.999:
			look_at(look_target, Vector3.UP)

	# Corner Banking
	if enable_banking:
		var tilt_target := 0.0
		if "steering" in follow_this:
			tilt_target = follow_this.steering * banking_intensity
		elif "steering_amount" in follow_this:
			tilt_target = follow_this.steering_amount * banking_intensity
		rotation.z = lerp(rotation.z, -tilt_target * 0.15, speed * delta)

	# Camera Shake
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var random_offset: Vector3 = Vector3(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		global_position += random_offset
		_shake_intensity = lerp(_shake_intensity, 0.0, delta * (1.0 / _shake_duration))

func trigger_shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration
