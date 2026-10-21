class_name VehicleTuningApplicator
extends RefCounted

const ENGINES := {
	"stock_25": {
		"name": "2.5L I4 Stock",
		"desc": "260 Nm / 6500 RPM — базовый",
		"torque": 260.0,
		"max_rpm": 6500.0,
		"idle_rpm": 800.0,
		"clutch_rpm": 2500.0,
		"pitch_scale": 1.0
	},
	"v6_35": {
		"name": "3.5L V6 VVT-i",
		"desc": "370 Nm / 6800 RPM",
		"torque": 370.0,
		"max_rpm": 6800.0,
		"idle_rpm": 750.0,
		"clutch_rpm": 2800.0,
		"pitch_scale": 1.08
	},
	"jz_turbo": {
		"name": "3.0L 2JZ-GTE Turbo",
		"desc": "620 Nm / 7800 RPM — дрифт",
		"torque": 620.0,
		"max_rpm": 7800.0,
		"idle_rpm": 900.0,
		"clutch_rpm": 3400.0,
		"pitch_scale": 1.18
	},
	"v8_beast": {
		"name": "6.2L V8 Supercharged",
		"desc": "850 Nm / 7200 RPM",
		"torque": 850.0,
		"max_rpm": 7200.0,
		"idle_rpm": 700.0,
		"clutch_rpm": 3200.0,
		"pitch_scale": 0.88
	}
}

const WHEEL_NAMES := ["WheelFrontLeft", "WheelFrontRight", "WheelRearLeft", "WheelRearRight"]
const VISUAL_WHEELS := ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]

## Which model variant a quality preset should use. "high" keeps the full-detail
## GLB; balanced and low share the lighter one so mid-range phones get the same
## silhouette at a fraction of the vertex/draw cost.
static func variant_for_quality(quality: String) -> String:
	return "high" if quality == "high" else "low"

static func apply_tuning(vehicle: Vehicle, raw_profile: Dictionary) -> void:
	if not is_instance_valid(vehicle):
		return
	var profile := ProfileManager.validate_profile(raw_profile)
	var definition := VehicleDefinition.get_definition(profile["car"]["selected_car"])
	if definition == null:
		return
	var variant := variant_for_quality(String(profile["settings"]["quality"]))
	var changed_car := String(vehicle.get_meta("car_id", "")) != definition.id
	var changed_variant := String(vehicle.get_meta("visual_variant", "")) != variant
	if changed_car or changed_variant:
		_configure_vehicle(vehicle, definition, variant)
		# The body/wheels were rebuilt from a fresh scene: force stance and paint
		# to reapply against the new nodes instead of trusting the old signatures.
		vehicle.set_meta("tuning_physics_signature", "")
		vehicle.set_meta("tuning_paint_signature", "")
	var physics_signature := JSON.stringify([profile["stance"], profile["engine"], profile["handling"], profile["progression"]["brake_level"], definition.id])
	if vehicle.get_meta("tuning_physics_signature", "") != physics_signature:
		_apply_stance(vehicle, definition, profile["stance"])
		_apply_engine(vehicle, profile["engine"])
		_apply_handling(vehicle, profile["handling"]["preset"])
		vehicle.brake_force_multiplier = 1.0 + 0.12 * int(profile["progression"]["brake_level"])
		if vehicle.has_method("recalculate_physics"):
			vehicle.recalculate_physics()
		vehicle.set_meta("tuning_physics_signature", physics_signature)
	var paint_signature := JSON.stringify([profile["paint"], definition.id, variant])
	if vehicle.get_meta("tuning_paint_signature", "") != paint_signature:
		_apply_visuals(vehicle, definition, profile["paint"])
		vehicle.set_meta("tuning_paint_signature", paint_signature)

static func _find(root: Node, node_name: String) -> Node3D:
	if root.name == node_name and root is Node3D:
		return root
	for child in root.get_children():
		var found := _find(child, node_name)
		if found != null:
			return found
	return null

static func _configure_vehicle(vehicle: Vehicle, definition: VehicleDefinition, variant: String) -> void:
	if not vehicle.has_meta("private_tuning_dictionaries"):
		vehicle.coefficient_of_friction = vehicle.coefficient_of_friction.duplicate()
		vehicle.lateral_grip_assist = vehicle.lateral_grip_assist.duplicate()
		vehicle.set_meta("private_tuning_dictionaries", true)
	# Destroy only previously created visual nodes, never the physics chassis.
	var previous := vehicle.get_node_or_null("CustomBody")
	if previous != null:
		vehicle.remove_child(previous)
		previous.queue_free()
	for name in WHEEL_NAMES:
		var old_wheel = vehicle.get_node_or_null(name)
		if old_wheel == null:
			continue
		for child in old_wheel.wheel_node.get_children():
			if child.name == "CustomWheel":
				old_wheel.wheel_node.remove_child(child)
				child.queue_free()
	var template := vehicle.get_node_or_null("Muscle") as MeshInstance3D
	var visual_path := definition.visual_path
	if not visual_path.is_empty() and variant == "low" and not definition.visual_path_low.is_empty():
		visual_path = definition.visual_path_low
	var visual_applied := false
	if not visual_path.is_empty():
		visual_applied = _attach_visual(vehicle, definition, visual_path)
	# The GEVP placeholder body/wheels stay visible only when no custom model is
	# mounted (no path configured, or the GLB failed to load).
	if template != null:
		template.visible = not visual_applied
	for name in WHEEL_NAMES:
		var wheel = vehicle.get_node_or_null(name)
		if wheel == null:
			continue
		for child in wheel.wheel_node.get_children():
			if child is GeometryInstance3D and child.name != "CustomWheel":
				child.visible = not visual_applied
	vehicle.vehicle_mass = definition.mass_kg
	vehicle.front_tire_radius = definition.tire_radius
	vehicle.rear_tire_radius = definition.tire_radius
	vehicle.front_tire_width = definition.tire_width
	vehicle.rear_tire_width = definition.rear_tire_width
	var collider := vehicle.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null:
		var box := BoxShape3D.new()
		box.size = definition.collider_size
		collider.shape = box
		collider.position = definition.collider_center
	for i in range(4):
		var ray = vehicle.get_node_or_null(WHEEL_NAMES[i])
		if ray == null:
			continue
		var half_track := definition.front_half_track if i < 2 else definition.rear_half_track
		ray.position = Vector3((-1.0 if i % 2 == 0 else 1.0) * half_track,
			definition.wheel_anchor_y, definition.front_z if i < 2 else definition.rear_z)
	vehicle.set_meta("car_id", definition.id)
	vehicle.set_meta("visual_variant", variant)

## Move the imported Body and the four Wheel_* meshes into the GEVP chassis.
## Returns false (and leaves the chassis untouched) when the GLB cannot provide a
## Body, so a missing/renamed asset degrades to the placeholder instead of leaving
## the car with the previous model's mass and collider.
static func _attach_visual(vehicle: Vehicle, definition: VehicleDefinition, path: String) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Cannot load selected car visual: %s" % path)
		return false
	var imported := packed.instantiate()
	var body := _find(imported, "Body")
	if body == null:
		imported.free()
		push_warning("Selected car has no Body node: %s" % path)
		return false
	body.get_parent().remove_child(body)
	body.name = "CustomBody"
	# Detach the owner: the node comes from another scene and its owner would
	# otherwise dangle once `imported` is freed ("owner ... inconsistent" warning).
	body.owner = null
	body.position = definition.visual_offset
	vehicle.add_child(body)
	for i in range(4):
		var mesh := _find(imported, VISUAL_WHEELS[i])
		var wheel = vehicle.get_node_or_null(WHEEL_NAMES[i])
		if mesh != null and wheel != null:
			mesh.get_parent().remove_child(mesh)
			mesh.name = "CustomWheel"
			mesh.owner = null
			mesh.transform = Transform3D.IDENTITY
			wheel.wheel_node.add_child(mesh)
	imported.free()
	return true

static func _apply_stance(vehicle: Vehicle, definition: VehicleDefinition, stance: Dictionary) -> void:
	vehicle.front_spring_length = stance["front_spring_length"]
	vehicle.rear_spring_length = stance["rear_spring_length"]
	vehicle.front_camber = deg_to_rad(absf(stance["front_camber"]))
	vehicle.rear_camber = deg_to_rad(absf(stance["rear_camber"]))
	vehicle.suspension_stiffness_multiplier = stance["stiffness"]
	for i in range(4):
		var ray = vehicle.get_node_or_null(WHEEL_NAMES[i])
		if ray == null:
			continue
		var half_track := definition.front_half_track if i < 2 else definition.rear_half_track
		var offset: float = stance["front_offset"] if i < 2 else stance["rear_offset"]
		ray.position.x = (-1.0 if i % 2 == 0 else 1.0) * (half_track + offset)
		# Physical ray rotation supplies camber; avoid adding the same tilt twice.
		ray.wheel_node.rotation.z = 0.0

static func _apply_engine(vehicle: Vehicle, cfg: Dictionary) -> void:
	var spec: Dictionary = ENGINES[cfg["engine_id"]]
	vehicle.max_torque = spec["torque"]
	vehicle.max_rpm = spec["max_rpm"]
	vehicle.idle_rpm = spec["idle_rpm"]
	vehicle.clutch_out_rpm = spec["clutch_rpm"]
	vehicle.motor_rpm = clampf(vehicle.motor_rpm, vehicle.idle_rpm, vehicle.max_rpm)
	vehicle.front_torque_split = 0.5 if cfg["drivetrain"] == "awd" else 0.0
	vehicle.final_drive = cfg["final_drive"]
	vehicle.set_meta("engine_pitch", spec["pitch_scale"])

static func _apply_handling(vehicle: Vehicle, preset: String) -> void:
	match preset:
		"comfort":
			vehicle.coefficient_of_friction["Road"] = 2.5
			vehicle.lateral_grip_assist["Road"] = 0.22
			vehicle.countersteer_assist = 1.1
			vehicle.steering_speed = 7.0
		"drift":
			vehicle.coefficient_of_friction["Road"] = 2.1
			vehicle.lateral_grip_assist["Road"] = 0.08
			vehicle.countersteer_assist = 1.5
			vehicle.steering_speed = 10.0
		_:
			vehicle.coefficient_of_friction["Road"] = 3.0
			vehicle.lateral_grip_assist["Road"] = 0.16
			vehicle.countersteer_assist = 1.3
			vehicle.steering_speed = 9.0

static func _material(color_values: Array, finish: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color_values[0], color_values[1], color_values[2], 1.0)
	material.metallic = 0.88 if finish == "metallic" else 0.12
	material.roughness = 0.82 if finish == "matte" else 0.20
	material.clearcoat_enabled = finish != "matte"
	material.clearcoat = 0.6
	return material

static func _apply_visuals(vehicle: Vehicle, definition: VehicleDefinition, paint: Dictionary) -> void:
	var body_material := _material(paint["color"], paint["finish"])
	var rim_material := _material(paint["rim_color"], paint["rim_finish"])
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.04, 0.05, 0.07, 0.25 + float(paint["tint_alpha"]) * 0.72)
	glass.roughness = 0.08
	if definition.visual_path.is_empty():
		var body := vehicle.get_node_or_null("Muscle") as MeshInstance3D
		if body != null and body.mesh != null:
			if body.mesh.get_surface_count() > 0:
				body.set_surface_override_material(0, body_material)
			if body.mesh.get_surface_count() > 1:
				body.set_surface_override_material(1, glass)
		for name in WHEEL_NAMES:
			var ray = vehicle.get_node_or_null(name)
			if ray != null:
				for child in ray.wheel_node.get_children():
					if child is MeshInstance3D and child.mesh != null and child.mesh.get_surface_count() > 1:
						child.set_surface_override_material(1, rim_material)
	else:
		_apply_material_bindings(vehicle.get_node_or_null("CustomBody"), definition, body_material, glass, rim_material)
		for name in WHEEL_NAMES:
			var wheel = vehicle.get_node_or_null(name)
			if wheel != null:
				_apply_material_bindings(wheel.wheel_node.get_node_or_null("CustomWheel"), definition, body_material, glass, rim_material)

static func _apply_material_bindings(root: Node, definition: VehicleDefinition, body: Material, glass: Material, rims: Material) -> void:
	if root == null:
		return
	var mesh_instance: MeshInstance3D = root as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var mesh: Mesh = mesh_instance.mesh
		for index in range(mesh.get_surface_count()):
			var original: Material = mesh.surface_get_material(index)
			if original == null:
				continue
			var material_name: String = original.resource_name.to_lower()
			if material_name in definition.paint_materials:
				mesh_instance.set_surface_override_material(index, body)
			elif material_name in definition.glass_materials:
				mesh_instance.set_surface_override_material(index, glass)
			elif material_name in definition.rim_materials:
				mesh_instance.set_surface_override_material(index, rims)
	for child: Node in root.get_children():
		_apply_material_bindings(child, definition, body, glass, rims)
