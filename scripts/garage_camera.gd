class_name GarageCamera
extends Node3D

## Orbit showroom camera rig with touch drag, mouse rotation, zoom,
## smooth damping and slow turntable rotation during idle.

@export var target_height := 0.65
@export var default_distance := 5.2
@export var min_distance := 3.2
@export var max_distance := 7.5
@export var sensitivity := 0.005
@export var zoom_sensitivity := 0.5
@export var auto_rotate_speed := 0.08 # Radians per sec when idle

var _current_distance := 5.2
var _target_distance := 5.2

var _yaw := 0.75
var _target_yaw := 0.75
var _pitch := 0.25
var _target_pitch := 0.25

var _is_dragging := false
var _idle_timer := 0.0
var _camera: Camera3D

func _ready() -> void:
	_current_distance = default_distance
	_target_distance = default_distance
	
	_camera = get_node_or_null("Camera3D") as Camera3D
	if not _camera:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		_camera.current = true
		_camera.fov = 50.0
		add_child(_camera)
		
	_update_camera_transform(1.0)

func _process(delta: float) -> void:
	if not _is_dragging:
		_idle_timer += delta
		if _idle_timer > 2.0:
			_target_yaw += auto_rotate_speed * delta
	else:
		_idle_timer = 0.0

	_update_camera_transform(delta)

func _update_camera_transform(delta: float) -> void:
	var blend := 1.0 - exp(-15.0 * delta)
	_yaw = lerp_angle(_yaw, _target_yaw, blend)
	_pitch = lerpf(_pitch, _target_pitch, blend)
	_current_distance = lerpf(_current_distance, _target_distance, blend)

	position = Vector3(0.0, target_height, 0.0)
	rotation = Vector3.ZERO

	# Calculate spherical coordinates
	var cam_x := sin(_yaw) * cos(_pitch) * _current_distance
	var cam_y := sin(_pitch) * _current_distance
	var cam_z := cos(_yaw) * cos(_pitch) * _current_distance

	if is_instance_valid(_camera):
		_camera.position = Vector3(cam_x, cam_y, cam_z)
		_camera.look_at(position + Vector3(0.0, 0.15, 0.0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = clampf(_target_distance - zoom_sensitivity, min_distance, max_distance)
			_idle_timer = 0.0
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = clampf(_target_distance + zoom_sensitivity, min_distance, max_distance)
			_idle_timer = 0.0

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_dragging:
			_target_yaw -= mm.relative.x * sensitivity
			_target_pitch = clampf(_target_pitch + mm.relative.y * sensitivity, deg_to_rad(4.0), deg_to_rad(65.0))
			_idle_timer = 0.0

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_target_yaw -= sd.relative.x * sensitivity
		_target_pitch = clampf(_target_pitch + sd.relative.y * sensitivity, deg_to_rad(4.0), deg_to_rad(65.0))
		_idle_timer = 0.0
