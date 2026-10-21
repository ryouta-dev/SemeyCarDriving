class_name GarageController
extends Node3D

@export var vehicle: Vehicle
@export var garage_ui: CanvasLayer
@export var camera_rig: Node3D
var _current_profile: Dictionary = {}
var _save_timer: Timer
var _dirty := false

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.3
	_save_timer.timeout.connect(_flush_save)
	add_child(_save_timer)
	if is_instance_valid(vehicle):
		vehicle.freeze = true
		vehicle.set_physics_process(false)
		vehicle.linear_velocity = Vector3.ZERO
		vehicle.angular_velocity = Vector3.ZERO
		vehicle.position = Vector3(0.0, 0.42, 0.0)
		vehicle.rotation = Vector3.ZERO
	_current_profile = ProfileManager.load_profile()
	AudioServer.set_bus_mute(0, bool(_current_profile["settings"].get("muted", false)))
	VehicleTuningApplicator.apply_tuning(vehicle, _current_profile)
	QualitySettings.apply(get_viewport(), _current_profile["settings"]["quality"])
	if is_instance_valid(garage_ui):
		garage_ui.setup(_current_profile)
		garage_ui.tuning_changed.connect(_on_tuning_changed)
		garage_ui.reset_requested.connect(_on_reset_requested)
		garage_ui.drive_requested.connect(_on_drive_requested)
		garage_ui.track_requested.connect(_on_track_requested)

func _on_tuning_changed(new_profile: Dictionary) -> void:
	_current_profile = ProfileManager.validate_profile(new_profile)
	VehicleTuningApplicator.apply_tuning(vehicle, _current_profile)
	QualitySettings.apply(get_viewport(), _current_profile["settings"]["quality"])
	_dirty = true
	_save_timer.start()
	garage_ui.set_save_status(false, true)

func _flush_save() -> bool:
	if not _dirty:
		return true
	var sections := {}
	for key in ["paint", "stance", "engine", "environment", "handling", "car", "settings"]:
		sections[key] = _current_profile[key]
	var success := ProfileManager.save_sections(sections)
	_dirty = not success
	if is_instance_valid(garage_ui):
		garage_ui.set_save_status(success)
	return success

func _on_reset_requested() -> void:
	_flush_save()
	_current_profile = ProfileManager.reset_to_default()
	VehicleTuningApplicator.apply_tuning(vehicle, _current_profile)
	garage_ui.setup(_current_profile)

func _on_drive_requested() -> void:
	if _flush_save():
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _exit_tree() -> void:
	_flush_save()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_flush_save()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		_on_drive_requested()

func _on_track_requested() -> void:
	if _flush_save():
		get_tree().change_scene_to_file("res://scenes/test_track.tscn")
