class_name VehicleTuningApplicator
extends RefCounted

## VehicleTuningApplicator translates a profile dictionary into live physics,
## stance, materials, and engine parameters for a Vehicle instance.

const BASE_WHEEL_X := 0.924808 # Absolute base lateral position of wheels

const ENGINES := {
	"stock_25": {
		"name": "2.5L I4 Stock",
		"desc": "203 hp / 250 Nm / 6500 RPM",
		"torque": 260.0,
		"max_rpm": 6500.0,
		"idle_rpm": 800.0,
		"clutch_rpm": 2500.0,
		"pitch_scale": 1.0
	},
	"v6_35": {
		"name": "3.5L V6 VVT-i",
		"desc": "301 hp / 370 Nm / 6800 RPM",
		"torque": 370.0,
		"max_rpm": 6800.0,
		"idle_rpm": 750.0,
		"clutch_rpm": 2800.0,
		"pitch_scale": 1.08
	},
	"jz_turbo": {
		"name": "3.0L 2JZ-GTE Turbo",
		"desc": "580 hp / 620 Nm / 7800 RPM",
		"torque": 620.0,
		"max_rpm": 7800.0,
		"idle_rpm": 900.0,
		"clutch_rpm": 3400.0,
		"pitch_scale": 1.18
	},
	"v8_beast": {
		"name": "6.2L V8 Supercharged",
		"desc": "750 hp / 850 Nm / 7200 RPM",
		"torque": 850.0,
		"max_rpm": 7200.0,
		"idle_rpm": 700.0,
		"clutch_rpm": 3200.0,
		"pitch_scale": 0.88
	}
}

static func apply_tuning(vehicle: RigidBody3D, profile: Dictionary) -> void:
	if not is_instance_valid(vehicle):
		return

	var car_id: String = profile.get("car", {}).get("selected_car", "simcade_car")
	_apply_visuals(vehicle, profile.get("paint", {}))
	_apply_stance(vehicle, profile.get("stance", {}), car_id)
	_apply_engine(vehicle, profile.get("engine", {}))

static func _apply_visuals(vehicle: RigidBody3D, paint: Dictionary) -> void:

	var body_mesh := vehicle.get_node_or_null("Muscle") as MeshInstance3D
	if not body_mesh:
		# Search children for first suitable MeshInstance3D
		for child in vehicle.get_children():
			if child is MeshInstance3D and not "wheel" in child.name.to_lower():
				body_mesh = child
				break

	if body_mesh:
		# 1. Body Paint
		var raw_color = paint.get("color", [0.85, 0.12, 0.12, 1.0])
		var color := Color(raw_color[0], raw_color[1], raw_color[2], 1.0)
		var finish: String = paint.get("finish", "gloss")

		var mat_body := StandardMaterial3D.new()
		mat_body.albedo_color = color
		match finish:
			"gloss":
				mat_body.metallic = 0.15
				mat_body.roughness = 0.18
				mat_body.clearcoat_enabled = true
				mat_body.clearcoat = 0.8
			"metallic":
				mat_body.metallic = 0.90
				mat_body.roughness = 0.22
				mat_body.clearcoat_enabled = true
				mat_body.clearcoat = 0.5
			"matte":
				mat_body.metallic = 0.05
				mat_body.roughness = 0.82
			_:
				mat_body.metallic = 0.3
				mat_body.roughness = 0.3

		body_mesh.set_surface_override_material(0, mat_body)

		# 2. Window Tint
		var tint_val: float = clampf(paint.get("tint_alpha", 0.5), 0.0, 0.98)
		var mat_glass := StandardMaterial3D.new()
		mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_glass.albedo_color = Color(0.04, 0.05, 0.07, 0.25 + tint_val * 0.72)
		mat_glass.metallic = 0.6
		mat_glass.roughness = 0.08
		body_mesh.set_surface_override_material(1, mat_glass)

	# 3. Wheel Rim Paint
	var raw_rim = paint.get("rim_color", [0.85, 0.85, 0.88, 1.0])
	var rim_color := Color(raw_rim[0], raw_rim[1], raw_rim[2], 1.0)
	var mat_rim := StandardMaterial3D.new()
	mat_rim.albedo_color = rim_color
	mat_rim.metallic = 0.88
	mat_rim.roughness = 0.20

	var wheel_mesh_names := [
		"WheelFrontLeft/FrontLeftWheel/Muscle wheel front left",
		"WheelFrontRight/FrontRightWheel/Muscle wheel front right",
		"WheelRearLeft/RearLeftWheel/Muscle wheel rear left",
		"WheelRearRight/RearRightWheel/Muscle wheel rear right"
	]
	for path in wheel_mesh_names:
		var w_mesh := vehicle.get_node_or_null(path) as MeshInstance3D
		if w_mesh:
			w_mesh.set_surface_override_material(1, mat_rim)

static func _apply_stance(vehicle: RigidBody3D, stance: Dictionary, car_id: String = "simcade_car") -> void:
	var f_len: float = stance.get("front_spring_length", 0.15)
	var r_len: float = stance.get("rear_spring_length", 0.20)
	var f_camber_deg: float = stance.get("front_camber", 0.0)
	var r_camber_deg: float = stance.get("rear_camber", 0.0)
	var f_offset: float = stance.get("front_offset", 0.0)
	var r_offset: float = stance.get("rear_offset", 0.0)
	var stiffness_mult: float = stance.get("stiffness", 1.0)

	var base_track_x := BASE_WHEEL_X
	if car_id == "lada_vaz_2110":
		base_track_x = 0.725
	elif car_id == "priora":
		base_track_x = 0.718

	# 1. Update Vehicle properties if present
	if "front_spring_length" in vehicle:
		vehicle.front_spring_length = f_len
	if "rear_spring_length" in vehicle:
		vehicle.rear_spring_length = r_len
	if "front_camber" in vehicle:
		vehicle.front_camber = deg_to_rad(absf(f_camber_deg))
	if "rear_camber" in vehicle:
		vehicle.rear_camber = deg_to_rad(absf(r_camber_deg))

	# 2. Update Wheels & RayCast positions/lengths
	var wheels_info := [
		{"name": "WheelFrontLeft", "node_path": "WheelFrontLeft/FrontLeftWheel", "is_front": true, "is_left": true},
		{"name": "WheelFrontRight", "node_path": "WheelFrontRight/FrontRightWheel", "is_front": true, "is_left": false},
		{"name": "WheelRearLeft", "node_path": "WheelRearLeft/RearLeftWheel", "is_front": false, "is_left": true},
		{"name": "WheelRearRight", "node_path": "WheelRearRight/RearRightWheel", "is_front": false, "is_left": false},
	]

	for item in wheels_info:
		var ray := vehicle.get_node_or_null(item["name"]) as RayCast3D
		if not ray:
			continue

		var spring_len := f_len if item["is_front"] else r_len
		var offset := f_offset if item["is_front"] else r_offset
		var camber_deg := f_camber_deg if item["is_front"] else r_camber_deg

		# Apply Offset (Track Width) to RayCast3D X position based on car track width
		var sign_x := -1.0 if item["is_left"] else 1.0
		ray.position.x = sign_x * (base_track_x + offset)


		# Apply Spring length & RayCast target
		if "spring_length" in ray:
			ray.spring_length = spring_len
			var tire_rad := float(ray.get("tire_radius")) if "tire_radius" in ray else 0.355
			ray.set_target_position(Vector3.DOWN * (spring_len + tire_rad))
			if "max_spring_length" in ray:
				ray.max_spring_length = spring_len
			if "spring_rate" in ray:
				ray.spring_rate *= stiffness_mult

		# Visual Camber tilt on Wheel Node
		var w_node := vehicle.get_node_or_null(item["node_path"]) as Node3D
		if w_node:
			# Camber tilts top of wheel inward
			# Left wheel rotates positive Z, right wheel rotates negative Z for top-inward
			var camber_rad := deg_to_rad(absf(camber_deg))
			w_node.rotation.z = (camber_rad if item["is_left"] else -camber_rad)

static func _apply_engine(vehicle: RigidBody3D, engine_cfg: Dictionary) -> void:
	var eng_id: String = engine_cfg.get("engine_id", "stock_25")
	var spec: Dictionary = ENGINES.get(eng_id, ENGINES["stock_25"])
	
	if "max_torque" in vehicle:
		vehicle.max_torque = spec["torque"]
	if "max_rpm" in vehicle:
		vehicle.max_rpm = spec["max_rpm"]
	if "idle_rpm" in vehicle:
		vehicle.idle_rpm = spec["idle_rpm"]
	if "clutch_out_rpm" in vehicle:
		vehicle.clutch_out_rpm = spec["clutch_rpm"]

	# Drivetrain: RWD vs AWD
	var drivetrain: String = engine_cfg.get("drivetrain", "rwd")
	if "front_torque_split" in vehicle:
		vehicle.front_torque_split = 0.5 if drivetrain == "awd" else 0.0

	# Final Drive
	var final_drive: float = engine_cfg.get("final_drive", 3.45)
	if "final_drive" in vehicle:
		vehicle.final_drive = final_drive

## Swaps or configures the visual mesh and active spinning/steering wheels
static func swap_vehicle_mesh(veh: Node, car_id: String) -> void:
	if not is_instance_valid(veh):
		return

	# 1. Clean up any previously added custom visual nodes
	_cleanup_custom_visuals(veh)

	# 2. Reference to default meshes in simcade_car.tscn
	var default_mesh_paths = [
		"Muscle",
		"WheelFrontLeft/FrontLeftWheel/Muscle wheel front left",
		"WheelFrontRight/FrontRightWheel/Muscle wheel front right",
		"WheelRearLeft/RearLeftWheel/Muscle wheel rear left",
		"WheelRearRight/RearRightWheel/Muscle wheel rear right",
	]

	# Base positions for default GEVP simcade_car suspension
	var default_suspension = {
		"WheelFrontLeft": Vector3(-0.924808, 0.0879494, -1.44939),
		"WheelFrontRight": Vector3(0.924808, 0.0879494, -1.44939),
		"WheelRearLeft": Vector3(-0.924808, 0.0879494, 1.44939),
		"WheelRearRight": Vector3(0.924808, 0.0879494, 1.44939)
	}

	if car_id == "simcade_car":
		# Show all default meshes
		for path in default_mesh_paths:
			var n = veh.get_node_or_null(path)
			if n:
				n.visible = true
		# Reset suspension positions
		for w_name in default_suspension:
			var w = veh.get_node_or_null(w_name)
			if w:
				w.position = default_suspension[w_name]
		return

	# Custom car selected: Hide default body and default wheels
	for path in default_mesh_paths:
		var n = veh.get_node_or_null(path)
		if n:
			n.visible = false

	var glb_path := ""
	var body_offset := Vector3.ZERO
	var suspension_coords := {}

	if car_id == "lada_vaz_2110":
		glb_path = "res://lada_vaz_2110_rigged.glb"
		body_offset = Vector3(0.0, -0.197, 0.0)
		suspension_coords = {
			"WheelFrontLeft": Vector3(-0.747, 0.088, -1.316),
			"WheelFrontRight": Vector3(0.714, 0.088, -1.316),
			"WheelRearLeft": Vector3(-0.733, 0.088, 1.132),
			"WheelRearRight": Vector3(0.700, 0.088, 1.132)
		}
	elif car_id == "priora":
		glb_path = "res://priora_rigged.glb"
		body_offset = Vector3(0.0, 0.0, 0.0)
		suspension_coords = {
			"WheelFrontLeft": Vector3(-0.718, 0.083, -1.160),
			"WheelFrontRight": Vector3(0.718, 0.083, -1.160),
			"WheelRearLeft": Vector3(-0.706, 0.065, 1.334),
			"WheelRearRight": Vector3(0.717, 0.065, 1.334)
		}

	if glb_path == "":
		return

	var glb_scene = load(glb_path)
	if not glb_scene:
		push_warning("[VehicleTuningApplicator] Could not load GLB: " + glb_path)
		return

	var model_root = glb_scene.instantiate()
	_unset_owner_recursive(model_root)

	# 1. Attach Body
	var body_node = model_root.get_node_or_null("Body")
	if body_node:
		model_root.remove_child(body_node)
		body_node.name = "CustomCarBody"
		body_node.position = body_offset
		_unset_owner_recursive(body_node)
		veh.add_child(body_node)
	else:
		model_root.name = "CustomCarBody"
		model_root.position = body_offset
		_unset_owner_recursive(model_root)
		veh.add_child(model_root)
		return


	# 2. Attach each of the 4 wheels to the corresponding wheel_node
	var wheel_mapping = {
		"Wheel_FL": "WheelFrontLeft/FrontLeftWheel",
		"Wheel_FR": "WheelFrontRight/FrontRightWheel",
		"Wheel_RL": "WheelRearLeft/RearLeftWheel",
		"Wheel_RR": "WheelRearRight/RearRightWheel"
	}

	for mesh_wheel_name in wheel_mapping:
		var wheel_mesh = model_root.get_node_or_null(mesh_wheel_name)
		var target_path = wheel_mapping[mesh_wheel_name]
		var target_node = veh.get_node_or_null(target_path)
		if wheel_mesh and target_node:
			model_root.remove_child(wheel_mesh)
			wheel_mesh.name = "Custom" + mesh_wheel_name
			wheel_mesh.position = Vector3.ZERO
			wheel_mesh.rotation = Vector3.ZERO
			wheel_mesh.scale = Vector3.ONE
			_unset_owner_recursive(wheel_mesh)
			target_node.add_child(wheel_mesh)

	# 3. Adjust suspension RayCast3D positions to match real wheel track & wheelbase
	for w_name in suspension_coords:
		var w = veh.get_node_or_null(w_name)
		if w:
			w.position = suspension_coords[w_name]

	# Free temporary model_root now that children have been reparented
	model_root.queue_free()
	print("[VehicleTuningApplicator] Rigged vehicle active with spinning/turning wheels: ", car_id)

static func _cleanup_custom_visuals(veh: Node) -> void:
	# Remove custom body
	for child in veh.get_children():
		if "CustomCarBody" in child.name or "CarVisualMesh" in child.name:
			veh.remove_child(child)
			child.queue_free()

	# Remove custom wheels from suspension wheel nodes
	var wheel_paths = [
		"WheelFrontLeft/FrontLeftWheel",
		"WheelFrontRight/FrontRightWheel",
		"WheelRearLeft/RearLeftWheel",
		"WheelRearRight/RearRightWheel"
	]
	for wp in wheel_paths:
		var w_node = veh.get_node_or_null(wp)
		if w_node:
			for child in w_node.get_children():
				if "CustomWheel" in child.name or "Wheel_" in child.name:
					w_node.remove_child(child)
					child.queue_free()

static func _unset_owner_recursive(node: Node) -> void:
	if not is_instance_valid(node):
		return
	node.owner = null
	for child in node.get_children():
		_unset_owner_recursive(child)



