class_name DriveController
extends Node

## Bridges the M1 HUD to the GEVP vehicle: steering smoothing, P/R/N/D gear
## modes, throttle/brake/handbrake and the engine sound update.

var vehicle: Vehicle
var hud: HUDM1
var engine_sound: EngineSound

var _steer := 0.0
var _mode := "D"

func _ready() -> void:
	if is_instance_valid(vehicle):
		vehicle.automatic_transmission = true

func _physics_process(delta: float) -> void:
	if not is_instance_valid(vehicle) or hud == null or hud.is_paused():
		return
	_apply_mode(hud.gear_mode)
	var target: float = hud.get_steer()
	var rate: float = 7.0 if absf(target) > 0.01 else 10.0
	_steer = move_toward(_steer, target, rate * delta)
	vehicle.steering_input = _steer
	vehicle.throttle_input = hud.get_throttle() if _mode != "P" else 0.0
	vehicle.brake_input = hud.get_brake() if _mode != "P" else 1.0
	vehicle.handbrake_input = hud.get_handbrake() if _mode != "P" else 1.0
	# Parking feel: no clutch kick, no drift assists.
	vehicle.clutch_input = 0.0
	if engine_sound != null:
		var ratio: float = clampf(vehicle.motor_rpm / maxf(1000.0, vehicle.max_rpm), 0.0, 1.0)
		engine_sound.update_engine(vehicle.linear_velocity.length() * 3.6, vehicle.current_gear, ratio)

func _apply_mode(mode: String) -> void:
	if mode == _mode:
		return
	_mode = mode
	match mode:
		"P":
			vehicle.freeze = true
			vehicle.linear_velocity = Vector3.ZERO
			vehicle.angular_velocity = Vector3.ZERO
		"R":
			vehicle.freeze = false
			vehicle.automatic_transmission = false
			vehicle.set_gear_instant(Transmission.GEAR_REVERSE)
		"N":
			vehicle.freeze = false
			vehicle.automatic_transmission = false
			vehicle.set_gear_instant(Transmission.GEAR_NEUTRAL)
		"D":
			vehicle.freeze = false
			vehicle.automatic_transmission = true
