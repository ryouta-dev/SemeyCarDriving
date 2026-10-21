class_name CarDetails
extends RefCounted

## Small cosmetic attachments that belong to the car rather than the world:
## licence plates and the rear brake/reverse light sources.

const PLATE_TEXTURE := "res://assets/priora_plate.png"


static func attach_plates(vehicle: Vehicle) -> void:
	if not is_instance_valid(vehicle):
		return
	var texture := load(PLATE_TEXTURE) as Texture2D
	if texture == null:
		return
	var body := vehicle.get_node_or_null("CustomBody")
	if body == null:
		return
	var bounds := _world_aabb(body)
	if bounds.size == Vector3.ZERO:
		return
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.55
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var center_x: float = bounds.get_center().x
	var plate_y: float = bounds.position.y + bounds.size.y * 0.30
	var rear := Vector3(center_x, plate_y, bounds.end.z + 0.03)
	var front := Vector3(center_x, plate_y, bounds.position.z - 0.03)
	for entry in [[rear, 0.0], [front, PI]]:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.52, 0.13)
		var plate := MeshInstance3D.new()
		plate.name = "Plate"
		plate.mesh = quad
		plate.material_override = material
		plate.position = vehicle.to_local(entry[0])
		plate.rotation.y = entry[1]
		vehicle.add_child(plate)

static func _world_aabb(root: Node) -> AABB:
	var bounds := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var box: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


static func attach_rear_lights(vehicle: Vehicle) -> Node3D:
	if not is_instance_valid(vehicle):
		return null
	var root := Node3D.new()
	root.name = "RearLights"
	var brake := OmniLight3D.new()
	brake.name = "Brake"
	brake.position = Vector3(0.0, 0.62, 2.24)
	brake.light_color = Color("ff2a18")
	brake.omni_range = 3.2
	brake.light_energy = 0.0
	brake.shadow_enabled = false
	root.add_child(brake)
	var reverse := OmniLight3D.new()
	reverse.name = "Reverse"
	reverse.position = Vector3(0.0, 0.55, 2.24)
	reverse.light_color = Color("f2f6ff")
	reverse.omni_range = 2.4
	reverse.light_energy = 0.0
	reverse.shadow_enabled = false
	root.add_child(reverse)
	vehicle.add_child(root)
	return root


static func update_rear_lights(root: Node3D, vehicle: Vehicle) -> void:
	if not is_instance_valid(root) or not is_instance_valid(vehicle):
		return
	var braking: bool = vehicle.brake_input > 0.05 or vehicle.handbrake_input > 0.05
	var brake := root.get_node_or_null("Brake") as OmniLight3D
	if brake != null:
		brake.light_energy = 2.6 if braking else 0.0
	var reverse := root.get_node_or_null("Reverse") as OmniLight3D
	if reverse != null:
		reverse.light_energy = 2.0 if vehicle.current_gear == -1 else 0.0
