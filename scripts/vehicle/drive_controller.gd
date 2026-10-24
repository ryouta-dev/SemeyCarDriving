class_name DriveController
extends Node

## Bridges the M1 HUD to the GEVP vehicle: steering smoothing, P/R/N/D gear
## modes, throttle/brake/handbrake, creep, brake hold and the engine sound update.

var vehicle: Vehicle
var hud: HUDM1
var engine_sound: EngineSound

var _steer := 0.0
var _mode := "D"
var _hold_timer := 0.0

func _ready() -> void:
	if is_instance_valid(vehicle):
		vehicle.automatic_transmission = true

func _physics_process(delta: float) -> void:
	if not is_instance_valid(vehicle) or hud == null or hud.is_paused():
		return
	_apply_mode(hud.gear_mode)
	var throttle: float = hud.get_throttle()
	var brake: float = hud.get_brake()
	var target: float = hud.get_steer()
	var rate: float = 7.0 if absf(target) > 0.01 else 10.0
	_steer = move_toward(_steer, target, rate * delta)
	var along_kmh: float = _along_gear_speed_kmh()
	if _mode == "P":
		# Parking holds the car with the brakes instead of freezing the body: a
		# frozen rigid body pops up when it is unfrozen again.
		throttle = 0.0
		brake = 1.0
		if vehicle.linear_velocity.length() < 0.2:
			vehicle.linear_velocity = Vector3.ZERO
			vehicle.angular_velocity = Vector3.ZERO
	else:
		_update_brake_hold(delta, brake, throttle, along_kmh)
		brake = _held_brake(brake)
		throttle = _creep_throttle(throttle, brake, along_kmh)
	vehicle.steering_input = _steer
	vehicle.throttle_input = throttle
	vehicle.brake_input = brake
	vehicle.handbrake_input = 1.0 if _mode == "P" else hud.get_handbrake()
	# Parking feel: no clutch kick, no drift assists.
	vehicle.clutch_input = 0.0
	if engine_sound != null:
		var ratio: float = clampf(vehicle.motor_rpm / maxf(1000.0, vehicle.max_rpm), 0.0, 1.0)
		engine_sound.update_engine(vehicle.linear_velocity.length() * 3.6, vehicle.current_gear, ratio)

## Signed speed along the gear direction: positive when the car moves the way the
## selected gear would drive it, so creep and brake hold work in D and R alike.
func _along_gear_speed_kmh() -> float:
	var forward: Vector3 = -vehicle.global_transform.basis.z
	var along: float = vehicle.linear_velocity.dot(forward) * 3.6
	return along if _mode != "R" else -along

## Brake hold: after the pedal is released at a standstill, keep braking for a
## couple of seconds so the car does not roll away on the bridge slope.
func _update_brake_hold(delta: float, brake: float, throttle: float, along_kmh: float) -> void:
	if brake > 0.05:
		_hold_timer = ParkingHandling.BRAKE_HOLD_SECONDS
		return
	if throttle > 0.05 or absf(along_kmh) > ParkingHandling.BRAKE_HOLD_MAX_KMH:
		_hold_timer = 0.0
		return
	_hold_timer = maxf(0.0, _hold_timer - delta)

func _held_brake(brake: float) -> float:
	return maxf(brake, 0.45) if _hold_timer > 0.0 else brake

## Creep: an automatic pulls away with no pedal input. The GEVP auto box only
## engages first gear once the engine revs past the clutch-out RPM, so with no
## throttle it stays in neutral; engage first manually and feed a little throttle
## until the car reaches the creep speed of the selected gear.
func _creep_throttle(throttle: float, brake: float, along_kmh: float) -> float:
	if _mode != "D" and _mode != "R":
		return throttle
	if throttle > 0.05 or brake > 0.05 or _hold_timer > 0.0:
		return throttle
	if _mode == "D" and vehicle.current_gear == 0 and not vehicle.is_shifting:
		vehicle.set_gear_instant(1)
	var target: float = ParkingHandling.CREEP_FORWARD_KMH if _mode == "D" else ParkingHandling.CREEP_REVERSE_KMH
	if along_kmh < target - 0.4:
		return 0.30
	return throttle

func _apply_mode(mode: String) -> void:
	if mode == _mode:
		return
	_mode = mode
	_hold_timer = 0.0
	match mode:
		"P":
			# Park: disengage the box and let the brakes stop the car smoothly.
			vehicle.automatic_transmission = false
			vehicle.set_gear_instant(Transmission.GEAR_NEUTRAL)
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
			# Leaving R the box is still in reverse; the automatic only shifts
			# forward from neutral, so reset it before handing over to the auto.
			if vehicle.current_gear < 0:
				vehicle.set_gear_instant(Transmission.GEAR_NEUTRAL)
			vehicle.automatic_transmission = true
