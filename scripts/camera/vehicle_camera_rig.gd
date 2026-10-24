class_name VehicleCameraRig
extends Node3D

## Four camera modes for the M1 slice:
##   CHASE_NEAR   low and close chase camera (default, Car Parking style)
##   CHASE_MEDIUM higher and further back for a wide road view
##   HOOD         mounted on the bonnet, looking ahead
##   COCKPIT      driver's eye position inside the cabin
##
## Dragging the mouse (left/right button) or swiping a finger swings the view:
## horizontal is unlimited (look all the way back) and vertical looks down/up
## (down swipe looks down), springing back to centre on release.
##
## Frame pacing: the chassis is a RigidBody3D simulated at 120 Hz and rendered
## interpolated (SceneTreeFTI, `physics/common/physics_interpolation`). The rig
## follows `get_global_transform_interpolated()`, which is exactly the transform
## the chassis is drawn with; following `global_transform` instead would make the
## car jitter inside the frame at speed. The rig itself keeps physics
## interpolation OFF because it is rewritten on every rendered frame.

enum Mode { CHASE_NEAR, CHASE_MEDIUM, HOOD, COCKPIT }

@export var target: Vehicle

var mode: Mode = Mode.CHASE_NEAR
var camera: Camera3D

## Chase geometry per mode: distance and height are measured from the chassis
## origin, so a height of 1.0 m puts the camera about 1.45 m above the road.
const CHASE_MODES := {
	Mode.CHASE_NEAR: {"distance": 4.2, "height": 0.95, "fov": 66.0},
	Mode.CHASE_MEDIUM: {"distance": 6.2, "height": 1.45, "fov": 64.0},
}
## Onboard cameras in chassis space: the bonnet camera sits just above the hood
## line and is tilted down a little so the bonnet edge stays visible at the
## bottom of the frame; the cockpit camera is the driver's eye behind the wheel.
const HOOD_OFFSET := Vector3(0.0, 0.86, -1.25)
const COCKPIT_OFFSET := Vector3(-0.36, 0.78, 0.24)
## Small downward tilt of the onboard cameras so the road reads better than the sky.
const HOOD_VIEW_TILT := 0.13
const COCKPIT_VIEW_TILT := 0.02
## Chase camera collision: how close to a wall the camera may get.
const COLLISION_MARGIN := 0.35
const COLLISION_SMOOTHING := 14.0
const COLLISION_MIN_DISTANCE := 1.2
## Free look: radians per pixel of drag.
const LOOK_RADIANS_PER_PIXEL := 0.0045
## `_look_pitch` is positive when looking down: -0.55 rad looks up, 1.05 looks down.
const LOOK_PITCH_MIN := -0.55
const LOOK_PITCH_MAX := 1.05
## The orbit never drops below the chassis origin (that would put the camera
## under the road). The view itself can keep tilting up past that limit so the
## sky stays reachable on a phone.
const CHASE_ELEVATION_MIN := 0.02
const CHASE_ELEVATION_MAX := 1.05
const VIEW_PITCH_MIN := -0.52
const VIEW_PITCH_MAX := 1.15
## The view springs back to centre when released, faster the quicker you drive:
## at a standstill you keep the free look, on the motorway it recentres quickly.
const LOOK_RETURN_SLOW := 0.6
const LOOK_RETURN_FAST := 5.0
const LOOK_RETURN_REFERENCE_KMH := 80.0
## Teleporting further than this (car reset) snaps the orbit instead of sliding.
const TELEPORT_DISTANCE := 8.0

var _look_yaw := 0.0
var _look_pitch := 0.0
var _dragging := false
var _camera_distance := 0.0
var _initialised := false
var _last_anchor := Vector3.ZERO

func _ready() -> void:
	# The rig's transform is written in `_process`; FTI must not hold it a tick back.
	physics_interpolation_mode = Node3D.PHYSICS_INTERPOLATION_MODE_OFF
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 66.0
	camera.near = 0.05
	camera.far = 4000.0
	camera.current = true
	add_child(camera)
	snap()

func cycle_mode() -> void:
	mode = ((int(mode) + 1) % Mode.size()) as Mode
	snap()

func mode_name() -> String:
	match mode:
		Mode.CHASE_NEAR:
			return "Близко"
		Mode.CHASE_MEDIUM:
			return "Средне"
		Mode.HOOD:
			return "Капот"
		_:
			return "Салон"

func snap() -> void:
	_initialised = false
	_camera_distance = 0.0
	_update_camera(0.016)

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

## Horizontal drag swings around the car (wrapped into -180..180 so the view can
## go all the way back); vertical drag looks down (positive) or up (negative).
func _add_look(relative: Vector2) -> void:
	_look_yaw = wrapf(_look_yaw - relative.x * LOOK_RADIANS_PER_PIXEL, -PI, PI)
	_look_pitch = clampf(_look_pitch + relative.y * LOOK_RADIANS_PER_PIXEL, LOOK_PITCH_MIN, LOOK_PITCH_MAX)

## Chassis transform as it is being rendered: SceneTreeFTI interpolates the
## RigidBody3D between physics ticks, and this is the transform the renderer gets.
func _anchor_transform() -> Transform3D:
	if not is_instance_valid(target):
		return global_transform
	return target.get_global_transform_interpolated()

## Chassis yaw (radians) taken from the forward axis so roll and pitch do not leak in.
func _yaw_of(xform: Transform3D) -> float:
	var forward: Vector3 = -xform.basis.z
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
	var xform: Transform3D = _anchor_transform()
	var anchor: Vector3 = xform.origin
	var teleported: bool = (not _initialised) or _last_anchor.distance_to(anchor) > TELEPORT_DISTANCE
	_last_anchor = anchor
	var body_yaw: float = _yaw_of(xform)
	match mode:
		Mode.HOOD:
			_onboard(xform, HOOD_OFFSET, 70.0, HOOD_VIEW_TILT)
		Mode.COCKPIT:
			_onboard(xform, COCKPIT_OFFSET, 72.0, COCKPIT_VIEW_TILT)
		_:
			_chase(delta, anchor, body_yaw, speed_kmh, teleported)
	_initialised = true

func _chase(delta: float, anchor: Vector3, body_yaw: float, speed_kmh: float, teleported: bool) -> void:
	var spec: Dictionary = CHASE_MODES[mode]
	var distance: float = spec.distance
	var height: float = spec.height
	var base_elevation: float = atan2(height, distance)
	var radius: float = sqrt(distance * distance + height * height)
	var orbit_elevation: float = clampf(base_elevation + _look_pitch,
		CHASE_ELEVATION_MIN, CHASE_ELEVATION_MAX)
	var view_pitch: float = clampf(base_elevation + _look_pitch, VIEW_PITCH_MIN, VIEW_PITCH_MAX)
	var total_yaw: float = body_yaw + _look_yaw
	var orbit := Basis(Vector3.UP, total_yaw)
	var offset := Vector3(0.0, radius * sin(orbit_elevation), radius * cos(orbit_elevation))
	var desired: Vector3 = anchor + orbit * offset
	# Keep the camera out of walls, posts and the deck.
	var from: Vector3 = anchor + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(from, desired)
	query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var wanted_distance: float = radius
	if not hit.is_empty():
		wanted_distance = maxf(COLLISION_MIN_DISTANCE, from.distance_to(hit.position) - COLLISION_MARGIN)
	if teleported:
		_camera_distance = wanted_distance
	else:
		_camera_distance = lerpf(_camera_distance, wanted_distance,
			1.0 - exp(-COLLISION_SMOOTHING * delta))
	var scale: float = _camera_distance / radius
	global_position = anchor + orbit * (offset * scale)
	# Orientation comes from the same yaw and pitch as the orbit, so the car stays
	# exactly in the middle of the frame and the view cannot wobble around it.
	global_transform = Transform3D(
		Basis(Vector3.UP, total_yaw) * Basis(Vector3.RIGHT, -view_pitch),
		global_position)
	camera.fov = lerpf(camera.fov, float(spec.fov) + clampf(speed_kmh * 0.18, 0.0, 10.0),
		clampf(delta * 2.5, 0.0, 1.0))

## Bonnet and cockpit cameras are bolted to the chassis: they inherit its yaw,
## pitch and roll and only add the free-look rotation on top.
func _onboard(xform: Transform3D, offset: Vector3, fov: float, view_tilt: float) -> void:
	var body := xform.basis.orthonormalized()
	var seat: Vector3 = xform.origin + body * offset
	var look := Basis(Vector3.UP, _look_yaw) * Basis(Vector3.RIGHT, -(_look_pitch + view_tilt))
	global_transform = Transform3D(body * look, seat)
	camera.fov = fov
