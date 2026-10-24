extends Node3D

## M1 showcase zone: the Semey suspension bridge and its embankment.
## Everything here is authored from primitives and CC0-free materials so the
## first slice has zero paid dependencies.

const PRIORA := "priora"
const SPAWN_POSITION := Vector3(6.0, 1.0, -150.0)
const RESET_Y := -30.0
const PIER_X := 120.0
const PIER_GAP := 5.0
const SKY_SHADER := preload("res://scripts/shaders/m1_sky.gdshader")
const WATER_SHADER := preload("res://scripts/shaders/m1_water.gdshader")

var vehicle: Vehicle
var camera_rig: VehicleCameraRig
var hud: HUDM1
var controller: DriveController
var headlights: Node3D
var engine_sound: EngineSound
var rear_lights: Node3D
var light_lenses: Node3D
var traffic: TrafficFlow

var _profile: Dictionary

func _ready() -> void:
	# The M1 slice always drives the stock Priora: a saved 0.0.4 garage profile
	# could carry an extreme stance or a swapped engine and break the hero car.
	_profile = ProfileManager.get_default_profile()
	_profile["car"]["selected_car"] = PRIORA
	_profile["settings"]["quality"] = "high"
	_profile["paint"] = {
		"color": [0.72, 0.73, 0.75, 1.0],
		"finish": "metallic",
		"tint_alpha": 0.35,
		"rim_color": [0.8, 0.81, 0.83, 1.0],
		"rim_finish": "metallic",
	}
	_build_environment()
	_build_water_and_banks()
	BridgeBuilder.build(self)
	_build_embankment()
	_build_promenade_props()
	_build_city()
	_spawn_car()
	_build_headlights()
	_spawn_traffic()
	_setup_camera()
	_setup_hud()
	_setup_audio()
	_setup_controller()

func _build_environment() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky_material.set_shader_parameter("zenith_color", Color("3c6f9e"))
	sky_material.set_shader_parameter("horizon_color", Color("dfeaf3"))
	sky_material.set_shader_parameter("ground_color", Color("3b424a"))
	sky_material.set_shader_parameter("sun_color", Color("fff1dc"))
	sky_material.set_shader_parameter("sun_size", 0.0012)
	sky_material.set_shader_parameter("sun_glow", 0.45)
	sky_material.set_shader_parameter("cloud_coverage", 0.34)
	sky_material.set_shader_parameter("cloud_scale", 1.2)
	sky_material.set_shader_parameter("cloud_opacity", 0.9)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	environment.glow_bloom = 0.05
	environment.fog_enabled = true
	environment.fog_light_color = Color("c7d7e5")
	environment.fog_density = 0.0007
	environment.fog_aerial_perspective = 0.2
	environment.fog_sky_affect = 0.2
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.3
	environment.ssao_radius = 1.2
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	world_environment.add_to_group("quality_environment")

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	sun.light_color = Color("fff0dc")
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 600.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.16
	sun.directional_shadow_split_3 = 0.42
	add_child(sun)

func _build_water_and_banks() -> void:
	var water_material := ShaderMaterial.new()
	water_material.shader = WATER_SHADER
	water_material.set_shader_parameter("deep_color", Color("0b1f2a"))
	water_material.set_shader_parameter("shallow_color", Color("17414c"))
	water_material.set_shader_parameter("wave_height", 0.12)
	water_material.set_shader_parameter("ripple_scale", 0.9)
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(4000.0, 4000.0)
	water_mesh.subdivide_width = 64
	water_mesh.subdivide_depth = 64
	var water := MeshInstance3D.new()
	water.name = "River"
	water.mesh = water_mesh
	water.material_override = water_material
	water.position = Vector3(0.0, -8.0, -520.0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	var bank_material := _material(Color("6d7463"), 0.95, 0.0)
	var concrete := _material(Color("b8b4ab"), 0.85, 0.0)
	var asphalt := _material(Color("30343a"), 0.92, 0.0)
	_bank(Vector3(0, -5, 230), Vector3(700, 10, 340), bank_material)
	_bank(Vector3(0, -5, -1250), Vector3(700, 10, 300), bank_material)
	# Approach roads on both banks.
	_box(self, Vector3(26, 0.12, 140), Vector3(0, 0.06, 130), asphalt)
	_box(self, Vector3(26, 0.12, 100), Vector3(0, 0.06, -1150), asphalt)
	_box(self, Vector3(0.12, 0.02, 140), Vector3(0, 0.13, 130), _material(Color("e9e5d8"), 0.7, 0.0))

func _bank(center: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = center
	add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	body.add_child(instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _build_embankment() -> void:
	var concrete := _material(Color("bcb7ad"), 0.82, 0.0)
	var dark := _material(Color("6f6a62"), 0.9, 0.0)
	var paint := _material(Color("e9e5d8"), 0.7, 0.0)
	# Promenade slab and edge parapet.
	_box(self, Vector3(420, 0.2, 26), Vector3(0, 0.1, 72), concrete)
	var parapet := StaticBody3D.new()
	parapet.position = Vector3(0, 0.55, 58.8)
	add_child(parapet)
	var parapet_shape := CollisionShape3D.new()
	var parapet_box := BoxShape3D.new()
	# Collision stays continuous so a car cannot slip through the stair gap.
	parapet_box.size = Vector3(420, 1.1, 0.5)
	parapet_shape.shape = parapet_box
	parapet.add_child(parapet_shape)
	# The visible wall has a gap where the stairs go down to the river pier.
	for span: Vector2 in _parapet_spans():
		_box(parapet, Vector3(span.y - span.x, 1.1, 0.5), Vector3((span.x + span.y) * 0.5, 0.0, 0.0), concrete)
	# Benches.
	for i in range(6):
		_box(self, Vector3(2.2, 0.45, 0.6), Vector3(-150 + i * 60, 0.35, 67), dark)
	# Trees: one MultiMesh for trunks, one for crowns.
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	for i in range(15):
		var x: float = -168.0 + i * 24.0
		var z: float = 82.0 + float(i % 2) * 2.0
		trunks.append(Transform3D(Basis.from_scale(Vector3(0.18, 4.2, 0.18)), Vector3(x, 2.1, z)))
		crowns.append(Transform3D(Basis.from_scale(Vector3(2.6, 2.2, 2.6)), Vector3(x, 5.4, z)))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 1.0
	trunk_mesh.bottom_radius = 1.0
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 5
	_multimesh(self, trunk_mesh, trunks, dark)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	_multimesh(self, crown_mesh, crowns, _material(Color("3f5a38"), 0.9, 0.0))
	# Promenade lamps (emissive heads, no dynamic lights in daylight).
	var poles: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	for i in range(11):
		var x: float = -200.0 + i * 40.0
		poles.append(Transform3D(Basis.from_scale(Vector3(0.1, 6.5, 0.1)), Vector3(x, 3.25, 63.5)))
		heads.append(Transform3D(Basis.from_scale(Vector3(0.7, 0.18, 0.34)), Vector3(x, 6.55, 63.2)))
	_multimesh(self, truncate_cylinder(6), poles, dark)
	var lamp_material := _material(Color("d9d4c6"), 0.45, 0.0)
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("ffd9a0")
	lamp_material.emission_energy_multiplier = 1.2
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3.ONE
	_multimesh(self, head_mesh, heads, lamp_material)
	for span: Vector2 in _parapet_spans():
		_box(self, Vector3(span.y - span.x, 0.25, 0.3), Vector3((span.x + span.y) * 0.5, 0.86, 58.8), paint)

## Visible parapet runs, split around the pedestrian stair gap.
static func _parapet_spans() -> Array[Vector2]:
	var spans: Array[Vector2] = []
	var half: float = PIER_GAP * 0.5
	spans.append(Vector2(-210.0, PIER_X - half))
	spans.append(Vector2(PIER_X + half, 210.0))
	return spans

## Small promenade props: litter bins, bushes and the river pier with its stair
## flight. All are MultiMesh batches except the pier and the cheek walls.
func _build_promenade_props() -> void:
	var root := Node3D.new()
	root.name = "EmbankmentProps"
	add_child(root)
	var metal := _material(Color("2f3438"), 0.55, 0.6)
	var concrete := _material(Color("bcb7ad"), 0.82, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261024
	var bins: Array[Transform3D] = []
	for i in range(6):
		bins.append(Transform3D(Basis.from_scale(Vector3(0.24, 0.78, 0.24)), Vector3(-150.0 + i * 60.0 + 2.4, 0.39, 66.6)))
	_multimesh(root, truncate_cylinder(8), bins, metal)
	# Low bushes along the back edge of the promenade.
	var bushes: Array[Transform3D] = []
	for i in range(26):
		var scale: float = rng.randf_range(0.75, 1.25)
		bushes.append(Transform3D(
			Basis.from_scale(Vector3(1.5, 0.95, 1.5) * scale),
			Vector3(-190.0 + i * 15.2, 0.55 * scale, 84.0 + rng.randf_range(-1.2, 1.2))))
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 1.0
	bush_mesh.height = 1.8
	_multimesh(root, bush_mesh, bushes, _material(Color("46613c"), 0.95, 0.0))
	# Stone revetment wall below the promenade, covering the raw bank face.
	for span: Vector2 in _parapet_spans():
		_box(root, Vector3(span.y - span.x, 8.6, 0.8), Vector3((span.x + span.y) * 0.5, -4.2, 58.2), concrete)
	_pier_and_stairs(root, concrete, metal)

func _pier_and_stairs(root: Node3D, concrete: Material, metal: Material) -> void:
	var pier_y := -6.0
	_box(root, Vector3(15.0, 0.5, 10.4), Vector3(PIER_X, pier_y - 0.25, 51.0), concrete)
	# Piers holding the landing up, from below the waterline to the slab.
	for side: float in [-1.0, 1.0]:
		for dz: float in [-4.2, 3.8]:
			_box(root, Vector3(0.7, 2.6, 0.7), Vector3(PIER_X + side * 6.4, pier_y - 1.2, 51.0 + dz), concrete)
	# Safety rail on the water side of the pier.
	var rail := _box(root, Vector3(14.6, 0.08, 0.08), Vector3(PIER_X, pier_y + 0.95, 46.2), metal)
	rail.name = "PierRail"
	var posts: Array[Transform3D] = []
	for i in range(6):
		posts.append(Transform3D(Basis.from_scale(Vector3(0.07, 0.95, 0.07)), Vector3(PIER_X - 7.0 + i * 2.8, pier_y + 0.47, 46.2)))
	_multimesh(root, truncate_cylinder(6), posts, metal)
	# Stair flight from the promenade slab down to the pier: 12 treads.
	var drop: float = 6.0 / 12.0
	var run: float = 12.0 * 0.42
	var steps: Array[Transform3D] = []
	for i in range(12):
		var tread_y: float = 0.2 - (i + 1) * drop
		steps.append(Transform3D(Basis.IDENTITY, Vector3(PIER_X, tread_y - drop * 0.5, 58.4 - (i + 0.5) * 0.42)))
	var step_mesh := BoxMesh.new()
	step_mesh.size = Vector3(PIER_GAP, drop, 0.42)
	_multimesh(root, step_mesh, steps, concrete)
	# Sloped cheek walls framing the flight.
	var rise: float = 6.0
	var length: float = sqrt(run * run + rise * rise)
	var slope_deg: float = rad_to_deg(atan2(rise, run))
	for side: float in [-1.0, 1.0]:
		var wall := _box(root, Vector3(0.35, 0.7, length), Vector3(PIER_X + side * (PIER_GAP * 0.5 + 0.2), -2.8, 58.4 - run * 0.5), concrete)
		wall.rotation_degrees.x = 180.0 - slope_deg

## Visual traffic on the bridge. The flow node owns its own cars and motion.
func _spawn_traffic() -> void:
	traffic = TrafficFlow.new()
	traffic.name = "Traffic"
	add_child(traffic)

func _build_city() -> void:
	var transforms: Array[Transform3D] = []
	var near_transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	for i in range(34):
		var x: float = rng.randf_range(-280.0, 280.0)
		var z: float = rng.randf_range(-1330.0, -1140.0)
		var height: float = rng.randf_range(18.0, 66.0)
		var width: float = rng.randf_range(14.0, 30.0)
		var depth: float = rng.randf_range(12.0, 24.0)
		transforms.append(Transform3D(Basis.from_scale(Vector3(width, height, depth)), Vector3(x, height * 0.5, z)))
	for i in range(14):
		var x: float = rng.randf_range(-260.0, 260.0)
		var z: float = rng.randf_range(180.0, 330.0)
		var height: float = rng.randf_range(15.0, 48.0)
		near_transforms.append(Transform3D(Basis.from_scale(Vector3(rng.randf_range(14.0, 26.0), height, rng.randf_range(12.0, 20.0))), Vector3(x, height * 0.5, z)))
	var building_mesh := BoxMesh.new()
	building_mesh.size = Vector3.ONE
	var building_material := _material(Color("8d99a6"), 0.9, 0.0)
	_multimesh(self, building_mesh, transforms, building_material)
	_multimesh(self, building_mesh, near_transforms, _material(Color("7f8a96"), 0.9, 0.0))

func _spawn_car() -> void:
	var packed := load("res://addons/gevp/scenes/simcade_car.tscn") as PackedScene
	if packed == null:
		push_error("Showcase: cannot load vehicle scene")
		return
	vehicle = packed.instantiate() as Vehicle
	vehicle.name = "PlayerCar"
	vehicle.freeze = true
	vehicle.set_physics_process(false)
	add_child(vehicle)
	VehicleTuningApplicator.apply_tuning(vehicle, _profile)
	vehicle.global_position = SPAWN_POSITION
	vehicle.global_rotation = Vector3.ZERO
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	vehicle.previous_global_position = vehicle.global_position
	vehicle.freeze = false
	vehicle.set_physics_process(true)
	CarDetails.attach_plates(vehicle)
	rear_lights = CarDetails.attach_rear_lights(vehicle)
	light_lenses = CarDetails.attach_light_lenses(vehicle)

func _build_headlights() -> void:
	if vehicle == null:
		return
	headlights = Node3D.new()
	headlights.name = "Headlights"
	vehicle.add_child(headlights)
	for x: float in [-0.72, 0.72]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(x, 0.72, -2.1)
		spot.rotation_degrees = Vector3(-3.0, 0.0, 0.0)
		spot.spot_range = 45.0
		spot.spot_angle = 30.0
		spot.light_energy = 0.0
		spot.visible = false
		spot.shadow_enabled = false
		headlights.add_child(spot)

func _setup_camera() -> void:
	camera_rig = VehicleCameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.target = vehicle
	add_child(camera_rig)

func _setup_hud() -> void:
	hud = HUDM1.new()
	hud.name = "HUD"
	hud.vehicle = vehicle
	hud.camera_rig = camera_rig
	hud.headlights = headlights
	add_child(hud)

func _setup_audio() -> void:
	if vehicle != null:
		engine_sound = EngineSound.new()
		engine_sound.name = "EngineSound"
		vehicle.add_child(engine_sound)
	add_child(AmbienceM1.new())

func _setup_controller() -> void:
	controller = DriveController.new()
	controller.name = "DriveController"
	controller.vehicle = vehicle
	controller.hud = hud
	controller.engine_sound = engine_sound
	add_child(controller)

func _physics_process(_delta: float) -> void:
	if vehicle == null:
		return
	if vehicle.global_position.y < RESET_Y or not vehicle.global_position.is_finite():
		reset_car()

func _process(_delta: float) -> void:
	CarDetails.update_rear_lights(rear_lights, vehicle)
	CarDetails.update_light_lenses(light_lenses, vehicle)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_car()

func reset_car() -> void:
	if vehicle == null:
		return
	vehicle.freeze = true
	vehicle.global_position = SPAWN_POSITION
	vehicle.global_rotation = Vector3.ZERO
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	vehicle.previous_global_position = vehicle.global_position
	vehicle.freeze = false

# в”Ђв”Ђ Shared helpers в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _box(parent: Node, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _multimesh(parent: Node, mesh: Mesh, transforms: Array, material: Material) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.custom_aabb = AABB(Vector3(-400, -10, -1400), Vector3(800, 120, 1800))
	parent.add_child(instance)

func truncate_cylinder(segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh
