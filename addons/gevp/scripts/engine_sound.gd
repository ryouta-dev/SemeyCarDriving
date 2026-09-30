extends AudioStreamPlayer3D

@export var vehicle : Vehicle
@export var sample_rpm := 4000.0

func _physics_process(delta):
	pitch_scale = maxf(0.01, vehicle.motor_rpm / sample_rpm) if is_instance_valid(vehicle) else 1.0
	volume_db = linear_to_db((vehicle.throttle_amount * 0.5) + 0.5) if is_instance_valid(vehicle) else -80.0
