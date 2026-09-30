extends RigidBody3D
class_name ArcadeVehicle3D
@export_category("Suspension & Stabilizers")
@export var spring_stiffness: float = 60000.0  
@export var damper_stiffness: float = 3800.0   
@export var target_length: float = 0.65        
@export var tire_radius: float = 0.3
@export var anti_roll_force: float = 15000.0   

@export_category("Pro Driving Dynamics")
@export var max_engine_torque: float = 12000.0 
@export var max_speed: float = 40.0            
@export var braking_power: float = 8000.0      
@export var max_steer_angle: float = 0.52      
@export var side_grip: float = 0.9             

@export_category("Input & Audio Smoothing")
@export var steering_speed: float = 5.0        
@export var engine_rev_speed: float = 4.0      

@export_category("Custom Control Layout")
# Type your Project Settings -> Input Map action names here!
@export var forward_action: String = "ui_up"
@export var backward_action: String = "ui_down"
@export var left_action: String = "ui_left"
@export var right_action: String = "ui_right"

@export_category("Universal Vehicle Assigning")
@export var front_left_ray: RayCast3D
@export var front_right_ray: RayCast3D
@export var rear_left_ray: RayCast3D
@export var rear_right_ray: RayCast3D

@export_category("Universal Mesh Assigning")
@export var front_left_mesh: MeshInstance3D
@export var front_right_mesh: MeshInstance3D
@export var rear_left_mesh: MeshInstance3D
@export var rear_right_mesh: MeshInstance3D

@export_category("Audio Assigning")
@export var engine_sound: AudioStreamPlayer3D

# Internal register buffers built safely at runtime
var smooth_steer: float = 0.0
var rays: Array[RayCast3D] = []
var meshes: Array[MeshInstance3D] = []
var mesh_initial_offsets: Array[Vector3] = []
var wheel_rotation_angle: float = 0.0

func _ready() -> void:
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_AUTO
	center_of_mass = Vector3(0, -0.25, 0)
	
	# Pack the exported inspector nodes safely into runtime arrays
	rays = [front_left_ray, front_right_ray, rear_left_ray, rear_right_ray]
	meshes = [front_left_mesh, front_right_mesh, rear_left_mesh, rear_right_mesh]
	
	mesh_initial_offsets.clear()
	for mesh in meshes:
		if mesh != null:
			mesh_initial_offsets.append(Vector3(mesh.position.x, 0, mesh.position.z))
		else:
			mesh_initial_offsets.append(Vector3.ZERO)

func _physics_process(delta: float) -> void:
	# --- ASYNC DYNAMIC CONTROL MAPPING ---
	var throttle_input = Input.get_action_strength(backward_action) - Input.get_action_strength(forward_action)
	var raw_steer_input = Input.get_action_strength(left_action) - Input.get_action_strength(right_action)
	
	# --- SMOOTH KEYBOARD INPUT FILTER ---
	smooth_steer = move_toward(smooth_steer, raw_steer_input, steering_speed * delta)
	
	var car_forward = -global_transform.basis.z
	var forward_speed = linear_velocity.dot(car_forward)
	
	# Visual tire rotation calculation
	wheel_rotation_angle += (forward_speed / tire_radius) * delta
	
	# Safe Audio Check using your exported slot
	if engine_sound != null and is_instance_valid(engine_sound):
		if engine_sound.playing:
			var target_pitch = 1.0 + (abs(forward_speed) / max_speed) * 1.5
			engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, engine_rev_speed * delta)
	
	var compressions: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i in range(4):
		if rays[i] != null and rays[i].is_colliding():
			compressions[i] = target_length - rays[i].global_position.distance_to(rays[i].get_collision_point())
	
	var front_roll_force = (compressions[0] - compressions[1]) * anti_roll_force
	var rear_roll_force = (compressions[2] - compressions[3]) * anti_roll_force

	# Main Physics Loop
	for i in range(4):
		var ray = rays[i]
		var mesh = meshes[i]
		
		if ray == null or mesh == null:
			continue
			
		var initial_offset = mesh_initial_offsets[i]
		var is_front = (i < 2) 
		
		# Apply smooth steering angle to front tires
		if is_front:
			ray.rotation.y = smooth_steer * max_steer_angle
		else:
			ray.rotation.y = 0.0
			
		var wheel_forward_dir = -ray.global_transform.basis.z
		var wheel_right_dir = ray.global_transform.basis.x
		
		if ray.is_colliding():
			var hit_point = ray.get_collision_point()
			var hit_normal = ray.get_collision_normal()
			
			var wheel_offset = ray.global_position - global_position
			var wheel_velocity = linear_velocity + angular_velocity.cross(wheel_offset)
			
			# 1. SUSPENSION + ANTI-ROLL BALANCE FORCE
			var current_length = ray.global_position.distance_to(hit_point)
			var compression = target_length - current_length
			var normal_velocity = hit_normal.dot(wheel_velocity)
			
			var spring_force = (compression * spring_stiffness) - (normal_velocity * damper_stiffness)
			
			if i == 0: spring_force += front_roll_force 
			elif i == 1: spring_force -= front_roll_force 
			elif i == 2: spring_force += rear_roll_force  
			elif i == 3: spring_force -= rear_roll_force  
			
			spring_force = max(spring_force, 0.0)
			var total_suspension_force = hit_normal * spring_force
			
			# 2. PRO TORQUE DROP-OFF CURVE
			var total_engine_force = Vector3.ZERO
			if throttle_input != 0:
				if sign(throttle_input) != sign(forward_speed) and abs(forward_speed) > 1.0:
					total_engine_force = wheel_forward_dir * throttle_input * braking_power
				else:
					var speed_factor = clamp(1.0 - (abs(forward_speed) / max_speed), 0.0, 1.0)
					var dynamic_torque = max_engine_torque * speed_factor
					total_engine_force = wheel_forward_dir * throttle_input * dynamic_torque
			total_engine_force.y = 0.0
			
			# 3. DYNAMIC LATERAL GRIP & DRIFTING
			var lateral_velocity = wheel_right_dir.dot(wheel_velocity)
			var speed_slip_modifier = lerp(side_grip, side_grip * 0.35, clamp(abs(forward_speed) / max_speed, 0.0, 1.0))
			var total_grip_force = wheel_right_dir * (-lateral_velocity * mass * speed_slip_modifier)
			total_grip_force.y = 0.0
			
			apply_force(total_suspension_force + total_engine_force + total_grip_force, wheel_offset)
			
			# 4. SMOOTHED VISUAL MESH LOCK
			var local_hit_distance = ray.to_local(hit_point).y
			var target_mesh_y = local_hit_distance + tire_radius
			mesh.position.y = lerp(mesh.position.y, target_mesh_y, 15.0 * delta)
			mesh.position.x = initial_offset.x
			mesh.position.z = initial_offset.z
		else:
			var target_mesh_y = -target_length + tire_radius
			mesh.position.y = lerp(mesh.position.y, target_mesh_y, 15.0 * delta)
			mesh.position.x = initial_offset.x
			mesh.position.z = initial_offset.z
			
		# Visual Meshes Steering/Rolling
		mesh.rotation = Vector3.ZERO
		if is_front:
			mesh.rotate_y(smooth_steer * max_steer_angle)
		mesh.rotate_object_local(Vector3.RIGHT, wheel_rotation_angle)
