extends Node3D
class_name SemeyPlayerController

@export var vehicle_node: Vehicle
@export var mobile_controls: MobileControls

@export_group("Input Smoothing")
@export var steer_speed: float = 6.0
@export var return_speed: float = 9.0

var smooth_steer: float = 0.0

func _ready() -> void:
	if is_instance_valid(mobile_controls):
		mobile_controls.shift_up_requested.connect(_on_shift_up)
		mobile_controls.shift_down_requested.connect(_on_shift_down)
		mobile_controls.toggle_transmission_requested.connect(_toggle_transmission)
	setup_vehicle()

func setup_vehicle() -> void:
	if not is_instance_valid(vehicle_node):
		return
		
	if is_instance_valid(mobile_controls):
		mobile_controls.update_transmission_ui(vehicle_node.automatic_transmission)

	# Apply CPM style arcade physics
	if vehicle_node.coefficient_of_friction is Dictionary:
		vehicle_node.coefficient_of_friction["Road"] = 3.5
	if vehicle_node.lateral_grip_assist is Dictionary:
		vehicle_node.lateral_grip_assist["Road"] = 0.20
	vehicle_node.countersteer_assist = 1.5
	vehicle_node.steering_speed = 10.0
	if vehicle_node.has_method("recalculate_physics"):
		vehicle_node.recalculate_physics()
	
	# Only add debug UI once
	var existing_debug = get_node_or_null("DebugTuningUI")
	if existing_debug:
		existing_debug.vehicle = vehicle_node
	else:
		var debug_ui := DebugTuningUI.new()
		debug_ui.name = "DebugTuningUI"
		debug_ui.vehicle = vehicle_node
		debug_ui.player_controller = self
		add_child(debug_ui)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(vehicle_node):
		return
	
	# === 1. STEERING CALCULATION ===
	var kb_steer = Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	var mobile_steer = 0.0
	var wheel_active = false
	
	if is_instance_valid(mobile_controls):
		mobile_steer = mobile_controls.get_steering_input()
		wheel_active = mobile_controls.is_wheel_active()
	
	if wheel_active:
		# Direct responsive steering from virtual steering wheel
		smooth_steer = mobile_steer
	else:
		# Use keyboard if pressed, otherwise use mobile arrows
		var target_steer = kb_steer if absf(kb_steer) > 0.01 else mobile_steer
		
		if absf(target_steer) > 0.01:
			smooth_steer = move_toward(smooth_steer, target_steer, steer_speed * delta)
		else:
			smooth_steer = move_toward(smooth_steer, 0.0, return_speed * delta)
			
	vehicle_node.steering_input = smooth_steer
	
	# === 2. THROTTLE, BRAKE & HANDBRAKE ===
	var kb_throttle = Input.get_action_strength("throttle")
	var mobile_throttle = mobile_controls.get_throttle_input() if is_instance_valid(mobile_controls) else 0.0
	var raw_throttle = maxf(kb_throttle, mobile_throttle)
	
	var kb_brake = Input.get_action_strength("brake")
	var mobile_brake = mobile_controls.get_brake_input() if is_instance_valid(mobile_controls) else 0.0
	var raw_brake = maxf(kb_brake, mobile_brake)
	
	var kb_handbrake = Input.get_action_strength("handbrake")
	var mobile_handbrake = mobile_controls.get_handbrake_input() if is_instance_valid(mobile_controls) else 0.0
	var raw_handbrake = maxf(kb_handbrake, mobile_handbrake)
	
	vehicle_node.throttle_input = pow(raw_throttle, 1.5)
	vehicle_node.brake_input = raw_brake
	vehicle_node.handbrake_input = raw_handbrake
	
	# Disengage clutch on handbrake for easier drift initiation
	vehicle_node.clutch_input = vehicle_node.handbrake_input
	
	# Manual keyboard shifts (E / Q)
	if Input.is_action_just_pressed("shift_up"):
		_on_shift_up()
		
	if Input.is_action_just_pressed("shift_down"):
		_on_shift_down()
		
	# Reverse gear swap logic:
	# When in Reverse, brake input acts as accelerator and throttle input acts as brake
	if vehicle_node.current_gear == -1:
		vehicle_node.brake_input = raw_throttle
		vehicle_node.throttle_input = raw_brake

func _on_shift_up() -> void:
	if not is_instance_valid(vehicle_node): return
	# Shifting manually switches transmission to manual mode
	if vehicle_node.automatic_transmission:
		vehicle_node.automatic_transmission = false
		if is_instance_valid(mobile_controls):
			mobile_controls.update_transmission_ui(false)
	vehicle_node.shift(1)

func _on_shift_down() -> void:
	if not is_instance_valid(vehicle_node): return
	# Shifting manually switches transmission to manual mode
	if vehicle_node.automatic_transmission:
		vehicle_node.automatic_transmission = false
		if is_instance_valid(mobile_controls):
			mobile_controls.update_transmission_ui(false)
	vehicle_node.shift(-1)

func _toggle_transmission() -> void:
	if not is_instance_valid(vehicle_node): return
	vehicle_node.automatic_transmission = not vehicle_node.automatic_transmission
	if is_instance_valid(mobile_controls):
		mobile_controls.update_transmission_ui(vehicle_node.automatic_transmission)
