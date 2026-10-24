class_name CarDetails
extends RefCounted

## Small cosmetic attachments that belong to the car rather than the world:
## licence plates, the rear brake/reverse light sources, and the emissive
## head/tail light lenses used by the M1 showcase.

const PLATE_TEXTURE := "res://assets/priora_plate.png"

## Warm white of the front light lenses.
const HEAD_LIGHT_COLOR := Color("fff3d6")
## Red of the rear light lenses.
const TAIL_LIGHT_COLOR := Color("ff2a18")
## Quad size (metres) of the rear and front lenses.
const TAIL_LENS_SIZE := Vector2(0.22, 0.085)
const HEAD_LENS_SIZE := Vector2(0.26, 0.09)
## Emission energies: tail lenses idle as parking lights and brighten under
## braking, head lenses only glow while the headlights are switched on.
const TAIL_PARK_ENERGY := 0.9
const TAIL_BRAKE_ENERGY := 3.2
const HEAD_LENS_ENERGY := 2.8
## Lens anchors as fractions of the body AABB, tuned on the Priora: the lamps
## sit at about 55% of the body height at the rear and 45% at the front.
const LENS_TRACK_FRACTION := 0.26
const TAIL_HEIGHT_FRACTION := 0.55
const HEAD_HEIGHT_FRACTION := 0.45


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


## Attaches the emissive light lenses to the car body: two red lenses on the
## rear face ("TailLeft", "TailRight") and two warm white lenses on the front
## face ("HeadLeft", "HeadRight"), all grouped under a "LightLenses" node.
##
## Lens positions are derived from the "CustomBody" AABB instead of hardcoding
## Priora dimensions, so the same code fits any imported car model. Calling it
## twice returns the existing node rather than duplicating lenses; it returns
## null when the vehicle is invalid or the body mesh is missing.
static func attach_light_lenses(vehicle: Vehicle) -> Node3D:
	if not is_instance_valid(vehicle):
		return null
	var existing := vehicle.get_node_or_null("LightLenses") as Node3D
	if existing != null:
		return existing
	var body := vehicle.get_node_or_null("CustomBody")
	if body == null:
		return null
	var bounds := _world_aabb(body)
	if bounds.size == Vector3.ZERO:
		return null
	var root := Node3D.new()
	root.name = "LightLenses"
	vehicle.add_child(root)
	var center_x: float = bounds.get_center().x
	var half_track: float = bounds.size.x * LENS_TRACK_FRACTION
	var tail_y: float = bounds.position.y + bounds.size.y * TAIL_HEIGHT_FRACTION
	var head_y: float = bounds.position.y + bounds.size.y * HEAD_HEIGHT_FRACTION
	var tail_z: float = bounds.end.z + 0.04
	var head_z: float = bounds.position.z - 0.04
	_add_lens(root, vehicle, "TailLeft",
		Vector3(center_x - half_track, tail_y, tail_z), 0.0,
		TAIL_LIGHT_COLOR, TAIL_LENS_SIZE, TAIL_PARK_ENERGY)
	_add_lens(root, vehicle, "TailRight",
		Vector3(center_x + half_track, tail_y, tail_z), 0.0,
		TAIL_LIGHT_COLOR, TAIL_LENS_SIZE, TAIL_PARK_ENERGY)
	_add_lens(root, vehicle, "HeadLeft",
		Vector3(center_x - half_track, head_y, head_z), PI,
		HEAD_LIGHT_COLOR, HEAD_LENS_SIZE, 0.0)
	_add_lens(root, vehicle, "HeadRight",
		Vector3(center_x + half_track, head_y, head_z), PI,
		HEAD_LIGHT_COLOR, HEAD_LENS_SIZE, 0.0)
	return root


## Drives the lens emission every frame: tail lenses stay lit as parking lights
## and flare up while braking (foot brake or handbrake), head lenses follow the
## headlight switch. Missing nodes or materials are skipped, never asserted.
static func update_light_lenses(root: Node3D, vehicle: Vehicle, headlights_on: bool) -> void:
	if not is_instance_valid(root) or not is_instance_valid(vehicle):
		return
	var braking: bool = vehicle.brake_input > 0.05 or vehicle.handbrake_input > 0.05
	var tail_energy: float = TAIL_BRAKE_ENERGY if braking else TAIL_PARK_ENERGY
	var head_energy: float = HEAD_LENS_ENERGY if headlights_on else 0.0
	_set_lens_energy(root, "TailLeft", tail_energy)
	_set_lens_energy(root, "TailRight", tail_energy)
	_set_lens_energy(root, "HeadLeft", head_energy)
	_set_lens_energy(root, "HeadRight", head_energy)


## Creates one outward-facing emissive quad lens under the given root.
static func _add_lens(parent: Node3D, vehicle: Vehicle, lens_name: String,
		world_position: Vector3, yaw: float, color: Color, size: Vector2,
		energy: float) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var lens := MeshInstance3D.new()
	lens.name = lens_name
	lens.mesh = quad
	lens.material_override = _lens_material(color, energy)
	lens.position = vehicle.to_local(world_position)
	lens.rotation.y = yaw
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(lens)


## Builds a private material per lens so each light can change its emission
## independently of the others.
static func _lens_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("16161a")
	material.metallic = 0.0
	material.roughness = 0.4
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


## Sets the emission energy of one lens, ignoring anything that is missing.
static func _set_lens_energy(root: Node3D, lens_name: String, energy: float) -> void:
	var lens := root.get_node_or_null(lens_name) as MeshInstance3D
	if lens == null:
		return
	var material := lens.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission_energy_multiplier = energy
