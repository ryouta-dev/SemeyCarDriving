class_name GarageController
extends Node3D

const ProfileManagerClass = preload("res://scripts/profile_manager.gd")
const VehicleTuningApplicatorClass = preload("res://scripts/tuning/vehicle_tuning_applicator.gd")

@export var vehicle: RigidBody3D
@export var garage_ui: CanvasLayer
@export var camera_rig: Node3D

var _current_profile: Dictionary = {}

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

	# Clean up any stray duplicate vehicle instances in the garage scene
	for child in get_children():
		if child is RigidBody3D and child != vehicle:
			remove_child(child)
			child.queue_free()

	_current_profile = ProfileManagerClass.load_profile()
	
	_reload_vehicle_from_profile()

	if is_instance_valid(garage_ui):
		garage_ui.setup(_current_profile)
		garage_ui.tuning_changed.connect(_on_tuning_changed)
		garage_ui.reset_requested.connect(_on_reset_requested)
		garage_ui.drive_requested.connect(_on_drive_requested)
		if garage_ui.has_signal("car_changed"):
			garage_ui.car_changed.connect(_on_car_changed)

func _reload_vehicle_from_profile() -> void:
	var car_id = _current_profile.get("car", {}).get("selected_car", "simcade_car")

	if is_instance_valid(vehicle):
		vehicle.freeze = true
		vehicle.linear_velocity = Vector3.ZERO
		vehicle.angular_velocity = Vector3.ZERO
		vehicle.position = Vector3(0.0, 0.42, 0.0)
		vehicle.rotation = Vector3.ZERO
		_swap_vehicle_mesh(vehicle, car_id)
		VehicleTuningApplicatorClass.apply_tuning(vehicle, _current_profile)

## Swap only the visual mesh inside the existing physics vehicle node
func _swap_vehicle_mesh(veh: Node, car_id: String) -> void:
	VehicleTuningApplicatorClass.swap_vehicle_mesh(veh, car_id)



func _on_car_changed(car_id: String) -> void:
	if not _current_profile.has("car"):
		_current_profile["car"] = {}
	_current_profile["car"]["selected_car"] = car_id
	ProfileManagerClass.save_profile(_current_profile)
	_reload_vehicle_from_profile()

func _on_tuning_changed(new_profile: Dictionary) -> void:
	_current_profile = new_profile
	if is_instance_valid(vehicle):
		VehicleTuningApplicatorClass.apply_tuning(vehicle, _current_profile)
	ProfileManagerClass.save_profile(_current_profile)

func _on_reset_requested() -> void:
	_current_profile = ProfileManagerClass.reset_to_default()
	_reload_vehicle_from_profile()
	if is_instance_valid(garage_ui):
		garage_ui.setup(_current_profile)


func _on_drive_requested() -> void:
	# Save before changing scene
	ProfileManagerClass.save_profile(_current_profile)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			_on_drive_requested()
