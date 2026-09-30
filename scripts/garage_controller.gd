class_name GarageController
extends Node3D

const ProfileManagerClass = preload("res://scripts/profile_manager.gd")
const VehicleTuningApplicatorClass = preload("res://scripts/tuning/vehicle_tuning_applicator.gd")

@export var vehicle: RigidBody3D
@export var garage_ui: CanvasLayer
@export var camera_rig: Node3D

var _current_profile: Dictionary = {}

func _ready() -> void:
	# Ensure physics won't cause vehicle to slide or glitch in showroom
	if is_instance_valid(vehicle):
		vehicle.freeze = true
		vehicle.linear_velocity = Vector3.ZERO
		vehicle.angular_velocity = Vector3.ZERO
		vehicle.position = Vector3(0.0, 0.42, 0.0)
		vehicle.rotation = Vector3.ZERO

	_current_profile = ProfileManagerClass.load_profile()

	if is_instance_valid(vehicle):
		VehicleTuningApplicatorClass.apply_tuning(vehicle, _current_profile)

	if is_instance_valid(garage_ui):
		garage_ui.setup(_current_profile)
		garage_ui.tuning_changed.connect(_on_tuning_changed)
		garage_ui.reset_requested.connect(_on_reset_requested)
		garage_ui.drive_requested.connect(_on_drive_requested)

func _on_tuning_changed(new_profile: Dictionary) -> void:
	_current_profile = new_profile
	if is_instance_valid(vehicle):
		VehicleTuningApplicatorClass.apply_tuning(vehicle, _current_profile)
	ProfileManagerClass.save_profile(_current_profile)

func _on_reset_requested() -> void:
	_current_profile = ProfileManagerClass.reset_to_default()
	if is_instance_valid(vehicle):
		VehicleTuningApplicatorClass.apply_tuning(vehicle, _current_profile)
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
