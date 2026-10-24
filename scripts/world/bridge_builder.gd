class_name BridgeBuilder
extends RefCounted

## Builds the suspension bridge for the M1 slice from primitives. The real
## Semey bridge (OSM way 44080309) is 1141 m with 3 lanes each way plus
## footways; these proportions follow it, while pylons and cables are authored
## because OSM stores only the centreline.

const Z_START := 60.0
const Z_END := -1100.0
const LENGTH := 1160.0
const DECK_MID := -520.0
const WIDTH := 26.0
const TOWER_Z := [-240.0, -760.0]
const TOWER_TOP := 52.0
const TOWER_LEG_X := 13.6
const CABLE_X := 13.35
const ANCHOR_A := 50.0
const ANCHOR_B := -1090.0
const DECK_Y := 1.0

static func build(parent: Node3D) -> void:
	var concrete := _mat(Color("d8d3ca"), 0.82, 0.02)
	concrete.albedo_texture = _noise_texture()
	concrete.uv1_scale = Vector3(3, 60, 1)
	var asphalt := _mat(Color("44494f"), 0.92, 0.0)
	asphalt.albedo_texture = _noise_texture()
	asphalt.uv1_scale = Vector3(6, 220, 1)
	var metal := _mat(Color("c8ccd3"), 0.42, 0.80)
	metal.albedo_texture = _noise_texture()
	metal.uv1_scale = Vector3(1.5, 1.5, 1.5)
	var paint := _mat(Color("e9e5d8"), 0.72, 0.0)
	var lamp := _mat(Color("d9d4c6"), 0.45, 0.0)
	lamp.emission_enabled = true
	lamp.emission = Color("ffd9a0")
	lamp.emission_energy_multiplier = 1.4
	_deck(parent, concrete, asphalt)
	_railings(parent, metal)
	_markings(parent, paint)
	_surface_details(parent, paint, metal)
	_towers(parent, concrete, metal)
	_tower_details(parent, concrete, metal)
	_deck_girders(parent, concrete)
	_cables(parent, metal)
	_km_posts(parent, paint)
	_lamps(parent, metal, lamp)

static func _noise_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.18
	noise.fractal_octaves = 3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.66, 0.66, 0.66))
	ramp.set_color(1, Color(1, 1, 1))
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp
	return texture

# ── Helpers ──────────────────────────────────────────────────────────────────

static func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

static func _box(parent: Node, box_size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

static func _add_box_collider(body: StaticBody3D, box_size: Vector3, position: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	collision.position = position
	body.add_child(collision)

static func _multimesh(parent: Node, mesh: Mesh, transforms: Array, material: Material, bounds: AABB) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.custom_aabb = bounds
	parent.add_child(instance)
	return instance

static func _segment_transform(a: Vector3, b: Vector3, radius: float) -> Transform3D:
	var direction := b - a
	var length := direction.length()
	if length < 0.001:
		return Transform3D.IDENTITY
	var y_axis := direction / length
	var x_axis := y_axis.cross(Vector3.UP)
	if x_axis.length() < 0.001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	var basis := Basis(x_axis, y_axis, z_axis) * Basis.from_scale(Vector3(radius, length, radius))
	return Transform3D(basis, (a + b) * 0.5)

# ── Deck, railings, markings ─────────────────────────────────────────────────

static func _deck(parent: Node3D, concrete: Material, asphalt: Material) -> void:
	var body := StaticBody3D.new()
	body.name = "BridgeDeck"
	parent.add_child(body)
	var deck_size := Vector3(WIDTH, 1.2, LENGTH)
	_box(body, deck_size, Vector3(0, -0.6, DECK_MID), concrete)
	_add_box_collider(body, deck_size, Vector3(0, -0.6, DECK_MID))
	_box(body, Vector3(WIDTH - 2.0, 0.12, LENGTH), Vector3(0, 0.06, DECK_MID), asphalt)
	# The carriageway visual sits 0.12 m above the deck box, so the wheels must
	# collide with it, not with the deck: otherwise the car is drawn sunk into the
	# asphalt by that much and the body clips through the road while driving.
	_add_box_collider(body, Vector3(WIDTH - 2.0, 0.12, LENGTH), Vector3(0, 0.06, DECK_MID))
	for x: float in [-12.2, 12.2]:
		var walk_size := Vector3(1.6, 0.3, LENGTH)
		_box(body, walk_size, Vector3(x, 0.15, DECK_MID), concrete)
		_add_box_collider(body, walk_size, Vector3(x, 0.15, DECK_MID))

static func _railings(parent: Node3D, metal: Material) -> void:
	var posts: Array[Transform3D] = []
	for x: float in [-13.15, 13.15]:
		_box(parent, Vector3(0.14, 1.05, LENGTH), Vector3(x, 0.75, DECK_MID), metal)
		_box(parent, Vector3(0.26, 0.08, LENGTH), Vector3(x, 1.34, DECK_MID), metal)
		_box(parent, Vector3(0.55, 0.75, LENGTH), Vector3(x, -0.55, DECK_MID), metal)
		var z: float = 56.0
		while z > -1096.0:
			posts.append(Transform3D(Basis.from_scale(Vector3(0.1, 1.1, 0.1)), Vector3(x, 0.75, z)))
			z -= 4.0
		var body := StaticBody3D.new()
		parent.add_child(body)
		_add_box_collider(body, Vector3(0.3, 1.3, LENGTH), Vector3(x, 0.65, DECK_MID))
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3.ONE
	_multimesh(parent, post_mesh, posts, metal, AABB(Vector3(-14, 0, -1100), Vector3(28, 2, 1200)))

static func _markings(parent: Node3D, paint: Material) -> void:
	# Solid centre pair and edge lines.
	for x: float in [-0.18, 0.18]:
		_box(parent, Vector3(0.12, 0.02, LENGTH - 4.0), Vector3(x, 0.13, DECK_MID), paint)
	for x: float in [-11.7, 11.7]:
		_box(parent, Vector3(0.12, 0.02, LENGTH - 4.0), Vector3(x, 0.13, DECK_MID), paint)
	# Dashed lane separators: four boundaries, one MultiMesh draw call.
	var transforms: Array[Transform3D] = []
	for x: float in [-8.0, -4.0, 4.0, 8.0]:
		var z: float = 50.0
		while z > -1090.0:
			transforms.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.13, z)))
			z -= 9.0
	var dash := BoxMesh.new()
	dash.size = Vector3(0.14, 0.02, 3.2)
	_multimesh(parent, dash, transforms, paint, AABB(Vector3(-14, 0, -1100), Vector3(28, 2, 1200)))

static func _surface_details(parent: Node3D, paint: Material, metal: Material) -> void:
	# Expansion joints every 40 m: a thin dark seam across the carriageway.
	var joints: Array[Transform3D] = []
	var z: float = 40.0
	while z > -1085.0:
		joints.append(Transform3D(Basis.IDENTITY, Vector3(0, 0.135, z)))
		z -= 40.0
	var joint_mesh := BoxMesh.new()
	joint_mesh.size = Vector3(25.4, 0.03, 0.35)
	_multimesh(parent, joint_mesh, joints, metal, AABB(Vector3(-13, 0, -1100), Vector3(26, 1, 1200)))
	# Direction arrows: each lane points the way traffic travels on that side.
	var arrow_material := _mat(Color("e9e5d8"), 0.65, 0.0)
	arrow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var arrows: Array[Transform3D] = []
	for lane: float in [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0]:
		var reverse: bool = lane < 0.0
		for i in range(9):
			var lane_z: float = (20.0 - i * 120.0) if not reverse else (-20.0 - i * 120.0)
			var basis := Basis(Vector3.UP, PI) if reverse else Basis.IDENTITY
			arrows.append(Transform3D(basis, Vector3(lane, 0.145, lane_z)))
	_multimesh(parent, _arrow_mesh(), arrows, arrow_material, AABB(Vector3(-12, 0, -1100), Vector3(24, 1, 1200)))

static func _arrow_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array([
		Vector3(-0.22, 0, 1.0), Vector3(0.22, 0, 1.0), Vector3(0.22, 0, 0.0),
		Vector3(-0.22, 0, 1.0), Vector3(0.22, 0, 0.0), Vector3(-0.22, 0, 0.0),
		Vector3(-0.8, 0, 0.0), Vector3(0.8, 0, 0.0), Vector3(0, 0, -1.2),
	])
	var normals := PackedVector3Array()
	for i in range(vertices.size()):
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# ── Towers and cables ────────────────────────────────────────────────────────

static func _towers(parent: Node3D, concrete: Material, metal: Material) -> void:
	for z: float in TOWER_Z:
		for x: float in [-TOWER_LEG_X, TOWER_LEG_X]:
			_box(parent, Vector3(3.2, 55.0, 4.2), Vector3(x, 27.5, z), concrete)
		_box(parent, Vector3(31.0, 2.8, 4.4), Vector3(0, 50.4, z), concrete)
		_box(parent, Vector3(31.0, 1.5, 3.6), Vector3(0, 26.0, z), concrete)
		_box(parent, Vector3(31.0, 0.5, 4.6), Vector3(0, 52.1, z), metal)

static func _cable_y(z: float) -> float:
	if z >= TOWER_Z[0]:
		return lerpf(DECK_Y, TOWER_TOP, clampf(inverse_lerp(ANCHOR_A, TOWER_Z[0], z), 0.0, 1.0))
	if z >= TOWER_Z[1]:
		var t: float = clampf(inverse_lerp(TOWER_Z[0], TOWER_Z[1], z), 0.0, 1.0)
		var sag: float = 26.0 * (1.0 - pow(2.0 * t - 1.0, 2.0))
		return TOWER_TOP - sag
	return lerpf(TOWER_TOP, DECK_Y, clampf(inverse_lerp(TOWER_Z[1], ANCHOR_B, z), 0.0, 1.0))

static func _cables(parent: Node3D, metal: Material) -> void:
	var transforms: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		var x: float = side * CABLE_X
		# Main cable: anchor → tower → sag → tower → anchor.
		var points: PackedVector3Array = []
		var z: float = ANCHOR_A
		while z >= ANCHOR_B:
			points.append(Vector3(x, _cable_y(z), z))
			z -= 10.0
		for i in range(1, points.size()):
			transforms.append(_segment_transform(points[i - 1], points[i], 0.18))
		# Hangers from cable down to the deck.
		z = 40.0
		while z > -1080.0:
			var cable_y: float = _cable_y(z)
			transforms.append(_segment_transform(Vector3(x, cable_y, z), Vector3(x, DECK_Y, z), 0.06))
			z -= 20.0
	var cable_mesh := CylinderMesh.new()
	cable_mesh.top_radius = 1.0
	cable_mesh.bottom_radius = 1.0
	cable_mesh.height = 1.0
	cable_mesh.radial_segments = 5
	cable_mesh.rings = 1
	cable_mesh.cap_top = false
	cable_mesh.cap_bottom = false
	_multimesh(parent, cable_mesh, transforms, metal, AABB(Vector3(-20, -2, -1110), Vector3(40, 60, 1180)))

static func _lamps(parent: Node3D, metal: Material, lamp: Material) -> void:
	var poles: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var z: float = 40.0
	while z > -1080.0:
		for x: float in [-14.0, 14.0]:
			poles.append(Transform3D(Basis.from_scale(Vector3(0.11, 8.5, 0.11)), Vector3(x, 4.25, z)))
			heads.append(Transform3D(Basis.from_scale(Vector3(0.85, 0.22, 0.4)), Vector3(x - signf(x) * 0.45, 8.55, z)))
		z -= 40.0
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 1.0
	pole_mesh.bottom_radius = 1.0
	pole_mesh.height = 1.0
	pole_mesh.radial_segments = 6
	_multimesh(parent, pole_mesh, poles, metal, AABB(Vector3(-16, 0, -1100), Vector3(32, 10, 1200)))
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3.ONE
	_multimesh(parent, head_mesh, heads, lamp, AABB(Vector3(-16, 8, -1100), Vector3(32, 2, 1200)))

# ── Structural details ───────────────────────────────────────────────────────

## Piers, capitals, cable saddles and braces so the 55 m pylons read as concrete
## towers rather than bare boxes when seen from the water or the embankment.
static func _tower_details(parent: Node3D, concrete: Material, metal: Material) -> void:
	var root := Node3D.new()
	root.name = "TowerDetails"
	parent.add_child(root)
	for z: float in TOWER_Z:
		for x: float in [-TOWER_LEG_X, TOWER_LEG_X]:
			# Pier footing standing in the river below the leg.
			_box(root, Vector3(7.0, 9.2, 9.4), Vector3(x, -4.4, z), concrete)
			# Capital under the deck and the saddle housing on top.
			_box(root, Vector3(4.6, 1.0, 5.2), Vector3(x, -1.4, z), concrete)
			_box(root, Vector3(4.4, 0.6, 5.0), Vector3(x, 51.0, z), concrete)
			_box(root, Vector3(3.8, 0.8, 4.4), Vector3(x, 51.7, z), metal)
		# Cross tie below the deck and diagonal struts up to the capitals.
		_box(root, Vector3(27.4, 0.9, 1.2), Vector3(0, -4.4, z), concrete)
		for side: float in [-1.0, 1.0]:
			var strut := _box(root, Vector3(0.55, 9.0, 0.7), Vector3(side * 9.2, -5.0, z), concrete)
			strut.rotation_degrees.z = side * 26.0
	# Abutment anchor blocks just inside both ends of the deck.
	for z: float in [57.0, -1097.0]:
		for x: float in [-11.8, 11.8]:
			_box(root, Vector3(3.2, 2.6, 4.4), Vector3(x, 0.2, z), concrete)

## Longitudinal girders and cross diaphragms under the deck.
static func _deck_girders(parent: Node3D, concrete: Material) -> void:
	var root := Node3D.new()
	root.name = "DeckGirders"
	parent.add_child(root)
	for x: float in [-11.0, -5.5, 0.0, 5.5, 11.0]:
		_box(root, Vector3(0.7, 1.5, LENGTH - 8.0), Vector3(x, -1.75, DECK_MID), concrete)
	var ribs: Array[Transform3D] = []
	var z: float = 30.0
	while z > -1090.0:
		ribs.append(Transform3D(Basis.IDENTITY, Vector3(0, -2.35, z)))
		z -= 40.0
	var rib_mesh := BoxMesh.new()
	rib_mesh.size = Vector3(WIDTH - 2.0, 0.55, 0.6)
	_multimesh(root, rib_mesh, ribs, concrete, AABB(Vector3(-13, -3, -1100), Vector3(26, 3, 1200)))

## Kilometre posts along both footways, white with a dark band, every 100 m.
static func _km_posts(parent: Node3D, paint: Material) -> void:
	var root := Node3D.new()
	root.name = "KmPosts"
	parent.add_child(root)
	var posts: Array[Transform3D] = []
	var bands: Array[Transform3D] = []
	var z: float = 40.0
	while z > -1090.0:
		for x: float in [-11.9, 11.9]:
			posts.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.75, z)))
			bands.append(Transform3D(Basis.IDENTITY, Vector3(x, 1.05, z)))
		z -= 100.0
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.22, 0.9, 0.18)
	_multimesh(root, post_mesh, posts, paint, AABB(Vector3(-13, 0, -1100), Vector3(26, 2, 1200)))
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.24, 0.18, 0.2)
	var dark := _mat(Color("2b2f34"), 0.75, 0.0)
	_multimesh(root, band_mesh, bands, dark, AABB(Vector3(-13, 0, -1100), Vector3(26, 2, 1200)))
