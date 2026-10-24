class_name VehicleCameraRig
extends Node3D

## Two cameras for the M1 slice: a smooth chase camera with collision and a
## cockpit camera seated inside the Priora. Replaces Pro-Vehicle-Camera for the
## showcase until the old HUD/camera stack is retired.

enum Mode { CHASE, COCKPIT }

@export var target: Vehicle

var mode: Mode = Mode.CHASE
var camera: Camera3D
var _initialised := false
var _smoothed_position := Vector3.ZERO
var _smoothed_target := Vector3.ZERO

## The chassis is a rigid body simulated at the physics rate. Rendering runs at
## the display rate, so sampling the raw transform makes the whole view judder at
## speed. The rig samples the chassis once per physics tick and interpolates
## between samples at render time (manual physics interpolation for the camera),
## then applies a little extra smoothing on top.
var _have_sample := false
var _previous_target := Vector3.ZERO
var _current_target := Vector3.ZERO
var _previous_yaw := 0.0
var _current_yaw := 0.0

const CHASE_DISTANCE := 5.1
const CHASE_HEIGHT := 1.9
const CHASE_LOOK_HEIGHT := 1.0
const COCKPIT_OFFSET := Vector3(-0.36, 1.16, 0.12)
## Extra low-pass on top of the interpolation; higher is more rigid.
const TARGET_SMOOTHING := 16.0
const POSITION_SMOOTHING := 9.0
## Teleporting further than this (car reset) snaps the filters instead of sliding.
const TELEPORT_DISTANCE := 8.0
## How much of the chassis roll/pitch the cockpit inherits; the rest is yaw only,
## which keeps the horizon readable without making the cabin feel rigid.
const COCKPIT_BODY_BLEND := 0.35
## Free look: right/left mouse drag or a finger swipe swings the view around the
## car and springs back to centre when the finger is lifted.
const LOOK_YAW_LIMIT := 2.4
const LOOK_PITCH_LIMIT := 0.65
const LOOK_RADIANS_PER_PIXEL := 0.005
const LOOK_RETURN_RATE := 6.0

var _look_yaw := 0.0
var _look_pitch := 0.0
var _dragging := false

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
	if is_instance_valid(target):
		_smoothed_target = target.global_position
		_previous_target = target.global_position
		_current_target = target.global_position
		_previous_yaw = _target_yaw()
		_current_yaw = _previous_yaw
		_have_sample = false
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
	_look_yaw = clampf(_look_yaw - relative.x * LOOK_RADIANS_PER_PIXEL, -LOOK_YAW_LIMIT, LOOK_YAW_LIMIT)
	_look_pitch = clampf(_look_pitch - relative.y * LOOK_RADIANS_PER_PIXEL, -LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT)

func _update_camera(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var position: Vector3 = _current_target
	var yaw: float = _current_yaw
	if _have_sample:
		# `get_physics_interpolation_fraction()` counts down from 1 to 0 over the
		# tick (1.0 right after the tick, 0.0 just before the next one), so invert
		# it to interpolate forward from the previous sample to the current one.
		var fraction: float = 1.0 - clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
		position = _previous_target.lerp(_current_target, fraction)
		yaw = lerp_angle(_previous_yaw, _current_yaw, fraction)
	if not _initialised or _smoothed_target.distance_to(position) > TELEPORT_DISTANCE:
		_smoothed_target = position
		_initialised = true
	_smoothed_target = _smoothed_target.lerp(position, 1.0 - exp(-TARGET_SMOOTHING * delta))
	if not _dragging:
		var settle: float = 1.0 - exp(-LOOK_RETURN_RATE * delta)
		_look_yaw = lerpf(_look_yaw, 0.0, settle)
		_look_pitch = lerpf(_look_pitch, 0.0, settle)
	if mode == Mode.CHASE:
		_chase(delta, yaw)
	else:
		_cockpit(yaw)

## Yaw of the car body in radians, taken from the forward axis so roll and pitch
## do not leak into it (Euler angles do).
func _target_yaw() -> float:
	var forward: Vector3 = -target.global_transform.basis.z
	return atan2(-forward.x, -forward.z)

func _chase(delta: float, body_yaw: float) -> void:
	# Chase only follows yaw: inheriting roll/pitch from the body makes the
	# horizon swim and reads as motion sickness on a phone.
	var yaw: float = body_yaw + _look_yaw
	var basis := Basis(Vector3.UP, yaw)
	var anchor: Vector3 = _smoothed_target
	var desired: Vector3 = anchor + basis * Vector3(0.0, CHASE_HEIGHT, CHASE_DISTANCE)
	var from: Vector3 = anchor + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, desired)
	query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + (from - desired).normalized() * 0.4
	_smoothed_position = _smoothed_position.lerp(desired, 1.0 - exp(-POSITION_SMOOTHING * delta))
	# Orient from the interpolated yaw and a fixed pitch instead of `look_at()`:
	# aiming at a smoothed target made the view angle wobble with the physics
	# tick even though the camera position itself was smooth.
	var down_angle: float = atan2(CHASE_HEIGHT - CHASE_LOOK_HEIGHT, CHASE_DISTANCE)
	global_transform = Transform3D(
		Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _look_pitch - down_angle),
		_smoothed_position)
	var speed: float = target.linear_velocity.length()
	camera.fov = lerpf(camera.fov, 64.0 + clampf(speed * 0.35, 0.0, 12.0), clampf(delta * 2.5, 0.0, 1.0))

func _cockpit(body_yaw: float) -> void:
	# Seat follows the filtered chassis position, so the cabin does not jitter
	# frame by frame, and only a third of the body roll/pitch comes through.
	var stable := Basis(Vector3.UP, body_yaw)
	var seat: Vector3 = _smoothed_target + stable * COCKPIT_OFFSET
	var body := stable.slerp(target.global_transform.basis, COCKPIT_BODY_BLEND).orthonormalized()
	var look := Basis(Vector3.UP, _look_yaw) * Basis(Vector3.RIGHT, _look_pitch)
	global_transform = Transform3D(body * look, seat)
	camera.fov = 72.0
