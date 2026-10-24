class_name ParkingHandling
extends RefCounted

## M1.2 handling preset: parking-lot feel instead of the 0.0.4 drift setup.
##
## Applied after [VehicleTuningApplicator] so the garage presets (comfort/sport/
## drift), which are tuned for drifting, cannot fight the showcase: no counter
## steer assist, slower steering ramps, softer suspension and a throttle that
## ramps like a pedal instead of a switch.

## Creep target in km/h: an automatic idles forward in D and slightly slower back
## in R. DriveController uses these to feed a little throttle with no pedal input.
const CREEP_FORWARD_KMH := 6.0
const CREEP_REVERSE_KMH := 3.5
## Brake hold: keep the pedal pressed for this long after release, at a standstill.
const BRAKE_HOLD_SECONDS := 2.0
const BRAKE_HOLD_MAX_KMH := 1.5

static func apply(vehicle: Vehicle) -> void:
	if not is_instance_valid(vehicle):
		return
	# Steering: slow, hydraulically damped ramps; no drift assists at all.
	# `steering_slip_assist` must stay generous: at 0 the GEVP steering assist
	# treats any wheel slip as "stop steering" and the car barely turns at all.
	vehicle.steering_speed = 4.0
	vehicle.countersteer_speed = 6.0
	vehicle.countersteer_assist = 0.0
	vehicle.steering_slip_assist = 0.6
	vehicle.steering_exponent = 1.0
	vehicle.steering_speed_decay = 0.30
	vehicle.max_steering_angle = deg_to_rad(38.0)
	# Pedals ramp like a heavy car: smooth from standstill, no clutch kick.
	vehicle.throttle_speed = 7.0
	vehicle.braking_speed = 6.0
	vehicle.brake_force_multiplier = 1.15
	# The GEVP clutch only closes above `clutch_out_rpm`, which the stock engine
	# sets to 2500 RPM — that is a racing clutch and the car cannot creep. A low
	# clutch-out point mimics a torque converter: it pulls away from idle.
	vehicle.clutch_out_rpm = 1400.0
	# Softer, longer-travel suspension; the car leans instead of snapping.
	vehicle.front_spring_length = 0.16
	vehicle.rear_spring_length = 0.20
	vehicle.suspension_stiffness_multiplier = 0.85
	vehicle.front_damping_ratio = 0.34
	vehicle.rear_damping_ratio = 0.38
	vehicle.front_arb_ratio = 0.18
	vehicle.rear_arb_ratio = 0.18
	# More grip, no drift bias: the car should hold its line at parking speeds.
	vehicle.coefficient_of_friction["Road"] = 3.2
	vehicle.lateral_grip_assist["Road"] = 0.0
	# Keep the stability systems: the bridge allows 90 km/h.
	vehicle.enable_stability = true
	vehicle.stability_yaw_strength = 8.0
	# A little less aero drag so the stock engine can still reach ~90 km/h.
	vehicle.coefficient_of_drag = 0.22
