class_name CarDetails
extends RefCounted

## Small cosmetic attachments that belong to the car rather than the world:
## licence plates, the rear brake/reverse light sources and the emissive rear
## optics used by the M1 showcase.

const PLATE_TEXTURE := "res://assets/priora_plate.png"

## Red of the rear light lenses.
const TAIL_LIGHT_COLOR := Color("ff2a18")
## Material name of the imported rear optics: its surfaces drive the tail lamps.
const TAIL_LAMP_MATERIAL := "priora_optik_rear"
## Emission energies: parking lights when idle, brighter under braking.
const TAIL_PARK_ENERGY := 1.0
const TAIL_BRAKE_ENERGY := 3.4


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
		reverse.light_energy = 2.0 if vehicle.current_gear == Transmission.GEAR_REVERSE else 0.0


## Makes the car lights glow.
##
## The rear lamps use the imported model's own optics material
## ([constant TAIL_LAMP_MATERIAL]): duplicating it and driving its emission makes
## the actual lamp geometry glow, so the lights stay flush with the body instead
## of floating quads. Headlights are lit by the spot lights in the scene, so no
## extra geometry is added for them. Calling it twice returns the existing node;
## it returns null when the vehicle is invalid or the body is missing.
static func attach_light_lenses(vehicle: Vehicle) -> Node3D:
	if not is_instance_valid(vehicle):
		return null
	var existing := vehicle.get_node_or_null("LightLenses") as Node3D
	if existing != null:
		return existing
	var body := vehicle.get_node_or_null("CustomBody")
	if body == null:
		return null
	var root := Node3D.new()
	root.name = "LightLenses"
	vehicle.add_child(root)
	root.set_meta("tail_materials", _tail_lamp_materials(body))
	return root


## Returns one private emissive duplicate of the rear optics material per body
## surface that uses it, so the tail lamps can glow without touching any other
## car that shares the imported material.
static func _tail_lamp_materials(body: Node) -> Array[StandardMaterial3D]:
	var materials: Array[StandardMaterial3D] = []
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var material := instance.get_active_material(surface) as StandardMaterial3D
			if material == null or String(material.resource_name) != TAIL_LAMP_MATERIAL:
				continue
			var glow := material.duplicate() as StandardMaterial3D
			glow.emission_enabled = true
			glow.emission = TAIL_LIGHT_COLOR
			glow.emission_energy_multiplier = TAIL_PARK_ENERGY
			instance.set_surface_override_material(surface, glow)
			materials.append(glow)
	return materials


## Drives the tail lamp emission every frame: parking lights when idle, brighter
## while braking (foot brake or handbrake). Missing materials are skipped.
static func update_light_lenses(root: Node3D, vehicle: Vehicle) -> void:
	if not is_instance_valid(root) or not is_instance_valid(vehicle):
		return
	var braking: bool = vehicle.brake_input > 0.05 or vehicle.handbrake_input > 0.05
	var tail_energy: float = TAIL_BRAKE_ENERGY if braking else TAIL_PARK_ENERGY
	for material in root.get_meta("tail_materials", []):
		var tail_material := material as StandardMaterial3D
		if tail_material != null:
			tail_material.emission_energy_multiplier = tail_energy
