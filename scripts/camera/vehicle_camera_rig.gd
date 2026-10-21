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

const CHASE_DISTANCE := 5.1
const CHASE_HEIGHT := 1.9
const CHASE_LOOK_HEIGHT := 1.0
const COCKPIT_OFFSET := Vector3(-0.36, 1.16, 0.12)

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 66.0
	camera.near = 0.05
	camera.far = 4000.0
	camera.current = true
	add_child(camera)
	snap()

func cycle_mode() -> void:
	mode = Mode.COCKPIT if mode == Mode.CHASE else Mode.CHASE
	snap()

func mode_name() -> String:
	return "Салон" if mode == Mode.COCKPIT else "Снаружи"

func snap() -> void:
	_initialised = false
	_update_camera(1.0)

func _process(delta: float) -> void:
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	if not is_instance_valid(target):
		return
	if mode == Mode.CHASE:
		_chase(delta)
	else:
		_cockpit()

func _chase(delta: float) -> void:
	# Chase only follows yaw: inheriting roll/pitch from the body makes the
	# horizon swim and reads as motion sickness on a phone.
	var yaw: float = target.global_rotation.y
	var basis := Basis(Vector3.UP, yaw)
	var desired: Vector3 = target.global_position + basis * Vector3(0.0, CHASE_HEIGHT, CHASE_DISTANCE)
	var from: Vector3 = target.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, desired)
	query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + (from - desired).normalized() * 0.4
	if not _initialised:
		_smoothed_position = desired
		_initialised = true
	else:
		_smoothed_position = _smoothed_position.lerp(desired, 1.0 - exp(-9.0 * delta))
	global_position = _smoothed_position
	look_at(target.global_position + Vector3.UP * CHASE_LOOK_HEIGHT, Vector3.UP)
	var speed: float = target.linear_velocity.length()
	camera.fov = lerpf(camera.fov, 64.0 + clampf(speed * 0.35, 0.0, 12.0), clampf(delta * 2.5, 0.0, 1.0))

func _cockpit() -> void:
	var seat: Vector3 = target.to_global(COCKPIT_OFFSET)
	global_transform = Transform3D(target.global_transform.basis, seat)
	camera.fov = 72.0
