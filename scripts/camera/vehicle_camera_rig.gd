class_name VehicleCameraRig
extends Node3D

## Two cameras for the M1 slice: a chase camera with collision and a cockpit
## camera seated inside the Priora. Replaces Pro-Vehicle-Camera for the showcase
## until the old HUD/camera stack is retired.
##
## The chassis is simulated at the physics rate but rendered at the display rate.
## Following the raw transform makes the whole view step at 120 Hz, so the rig
## samples the chassis once per physics tick and interpolates between the last two
## samples when rendering. Nothing else lags: a chase camera that trails the car
## makes the car visibly swim inside the frame.

enum Mode { CHASE, COCKPIT }

@export var target: Vehicle

var mode: Mode = Mode.CHASE
var camera: Camera3D

## Interpolation samples, refreshed in _physics_process.
var _have_sample := false
var _previous_target := Vector3.ZERO
var _current_target := Vector3.ZERO
var _previous_yaw := 0.0
var _current_yaw := 0.0

const CHASE_DISTANCE := 5.1
const CHASE_HEIGHT := 1.9
const COCKPIT_OFFSET := Vector3(-0.36, 1.16, 0.12)
## Chase camera collision: how close the camera is allowed to get to a wall.
const COLLISION_MARGIN := 0.4
const COLLISION_SMOOTHING := 14.0
## How much of the chassis roll/pitch the cockpit inherits; the rest is yaw only,
## which keeps the horizon readable without making the cabin feel rigid.
const COCKPIT_BODY_BLEND := 0.35

## Free look: drag the mouse or swipe a finger to swing the view. The yaw is
## unlimited (you can look all the way back), the pitch is clamped to +-60 deg.
const LOOK_PITCH_LIMIT := 1.05
const LOOK_RADIANS_PER_PIXEL := 0.005
## The view springs back to centre when released, faster the quicker you drive:
## at a standstill you keep the free look, on the motorway it recentres quickly.
const LOOK_RETURN_SLOW := 0.6
const LOOK_RETURN_FAST := 5.0
const LOOK_RETURN_REFERENCE_KMH := 80.0

var _look_yaw := 0.0
var _look_pitch := 0.0
var _dragging := false
var _camera_distance := 0.0
var _initialised := false

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 66.0
	camera.near = 0.05
	camera.far = 4000.0
	camera.current = true
	add_child(camera)
	snap()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	var position: Vector3 = target.global_position
	var yaw: float = _target_yaw()
	if _have_sample:
		_previous_target = _current_target
		_previous_yaw = _current_yaw
	else:
		_previous_target = position
		_previous_yaw = yaw
		_have_sample = true
	_current_target = position
	_current_yaw = yaw

func cycle_mode() -> void:
	mode = Mode.COCKPIT if mode == Mode.CHASE else Mode.CHASE
	snap()

func mode_name() -> String:
	return "Салон" if mode == Mode.COCKPIT else "Снаружи"

func snap() -> void:
	_initialised = false
	_have_sample = false
	_camera_distance = CHASE_DISTANCE
	_update_camera(1.0)

func _process(delta: float) -> void:
	_update_camera(delta)

## Free look input: a mouse drag (left or right button) on the scene, or a finger
## swipe away from the HUD buttons. The view springs back to centre on release.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_dragging = button.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_add_look((event as InputEventMouseMotion).relative)
	elif event is InputEventScreenDrag:
		_add_look((event as InputEventScreenDrag).relative)

func _add_look(relative: Vector2) -> void:
	# Unlimited yaw: wrap into -180..180 so the view can swing all the way round.
	_look_yaw = wrapf(_look_yaw - relative.x * LOOK_RADIANS_PER_PIXEL, -PI, PI)
	_look_pitch = clampf(_look_pitch - relative.y * LOOK_RADIANS_PER_PIXEL, -LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT)

## Chassis position interpolated between the last two physics samples. The
## engine fraction counts up from just after a tick, so it is used as is: the
## previous sample is one tick behind, which is exactly what we interpolate from.
func _interpolated_target() -> Vector3:
	if not _have_sample:
		return target.global_position
	var alpha: float = clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	return _previous_target.lerp(_current_target, alpha)

## Chassis yaw (radians) interpolated the same way; taken from the forward axis
## so roll and pitch do not leak in.
func _interpolated_yaw() -> float:
	if not _have_sample:
		return _target_yaw()
	var alpha: float = clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	return lerp_angle(_previous_yaw, _current_yaw, alpha)

func _target_yaw() -> float:
	var forward: Vector3 = -target.global_transform.basis.z
	return atan2(-forward.x, -forward.z)

func _update_camera(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var speed_kmh: float = target.linear_velocity.length() * 3.6
	if not _dragging:
		var return_rate: float = lerpf(LOOK_RETURN_SLOW, LOOK_RETURN_FAST,
			clampf(speed_kmh / LOOK_RETURN_REFERENCE_KMH, 0.0, 1.0))
		var settle: float = 1.0 - exp(-return_rate * delta)
		_look_yaw = lerpf(_look_yaw, 0.0, settle)
		_look_pitch = lerpf(_look_pitch, 0.0, settle)
	var anchor: Vector3 = _interpolated_target()
	var body_yaw: float = _interpolated_yaw()
	if mode == Mode.CHASE:
		_chase(delta, anchor, body_yaw, speed_kmh)
	else:
		_cockpit(anchor, body_yaw)

func _chase(delta: float, anchor: Vector3, body_yaw: float, speed_kmh: float) -> void:
	var total_yaw: float = body_yaw + _look_yaw
	var base_elevation: float = atan2(CHASE_HEIGHT, CHASE_DISTANCE)
	var distance: float = sqrt(CHASE_HEIGHT * CHASE_HEIGHT + CHASE_DISTANCE * CHASE_DISTANCE)
	var elevation: float = clampf(base_elevation + _look_pitch, -LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT)
	var orbit := Basis(Vector3.UP, total_yaw)
	var offset: Vector3 = Vector3(0.0, distance * sin(elevation), distance * cos(elevation))
	var desired: Vector3 = anchor + orbit * offset
	# Keep the camera out of walls and posts.
	var from: Vector3 = anchor + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, desired)
	query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var wanted_distance: float = distance
	if not hit.is_empty():
		wanted_distance = maxf(1.2, from.distance_to(hit.position) - COLLISION_MARGIN)
	if not _initialised:
		_camera_distance = wanted_distance
		_initialised = true
	else:
		_camera_distance = lerpf(_camera_distance, wanted_distance,
			1.0 - exp(-COLLISION_SMOOTHING * delta))
	var scale: float = _camera_distance / distance
	global_position = anchor + orbit * (offset * scale)
	# Orientation is derived from the same yaw and pitch, so the car stays exactly
	# in the middle of the frame and the view cannot wobble around it.
	global_transform = Transform3D(
		Basis(Vector3.UP, total_yaw) * Basis(Vector3.RIGHT, -elevation),
		global_position)
	camera.fov = lerpf(camera.fov, 64.0 + clampf(speed_kmh * 0.2, 0.0, 12.0), clampf(delta * 2.5, 0.0, 1.0))

func _cockpit(anchor: Vector3, body_yaw: float) -> void:
	var stable := Basis(Vector3.UP, body_yaw)
	var seat: Vector3 = anchor + stable * COCKPIT_OFFSET
	var body := stable.slerp(target.global_transform.basis, COCKPIT_BODY_BLEND).orthonormalized()
	var look := Basis(Vector3.UP, _look_yaw) * Basis(Vector3.RIGHT, _look_pitch)
	global_transform = Transform3D(body * look, seat)
	camera.fov = 72.0
