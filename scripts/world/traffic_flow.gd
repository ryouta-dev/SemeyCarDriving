class_name TrafficFlow
extends Node3D

## Visual-only bridge traffic for the M1 showcase: nine cars cruise along the
## suspension bridge lanes and wrap around to the opposite end of the deck.
##
## The bridge itself is built by [BridgeBuilder]; this node owns only light
## meshes and a simple Z-axis loop. It adds no physics bodies, no collision
## shapes and never creates or frees nodes after [method _ready], so it stays
## cheap enough for mobile. Cars are authored from primitives (boxes and
## cylinders), so no binary assets or licence-registry entries are involved.
##
## Node layout produced by [method _ready]:
##   TrafficFlow
##   └─ Cars
##      ├─ Car_01 … Car_09
##      │  ├─ Body            (BoxMesh, body paint)
##      │  ├─ Cabin           (BoxMesh, dark glass)
##      │  ├─ Wheels          (MultiMeshInstance3D, four CylinderMesh wheels)
##      │  ├─ TailLight_L/R   (emissive red)
##      │  └─ HeadLight_L/R   (emissive warm)
##      └─ …
##
## Right-hand traffic: the -X lanes drive towards +Z (near bank), the +X lanes
## towards -Z (far bank). Lane +6.0 belongs to the player car and is left empty.

## Seed of the deterministic fleet: the same cars appear in the same lanes on
## every run and on every capture.
const SEED := 20261024

## Loop bounds along Z. The asphalt in [BridgeBuilder] spans Z_START 60 to
## Z_END -1100, so cars wrap a little inside the deck edges and never leave it.
const Z_MIN := -1090.0
const Z_MAX := 70.0

## Top surface of the bridge asphalt: the deck top sits 0.12 m above y = 0.
const ROAD_Y := 0.12

## Cruise speed range in m/s, spread per lane by the fixed seed.
const SPEED_MIN := 18.0
const SPEED_MAX := 25.0

## Minimum Z gap between two cars of one lane. Cars in a lane share a single
## speed, so the initial gap is preserved forever on the loop and they never
## catch up with each other.
const GAP_MIN := 300.0
const GAP_RANGE := 220.0

## Lane centres on the bridge X axis, excluding the player's +6.0 lane.
const LANES: Array[float] = [-9.8, -6.0, -2.0, 2.0, 9.8]

## Cars per lane, index-aligned with [constant LANES]: six towards +Z and three
## towards -Z, nine in total.
const CARS_PER_LANE: Array[int] = [2, 2, 2, 2, 1]

## Fixed body paint palette (hex colours), picked by spawn index so the fleet
## looks identical on every run.
const PALETTE: Array[String] = [
	"b9bec6", # silver
	"2f4f6f", # dark blue
	"9c2b2b", # red
	"e8e6df", # white
	"2f6f5e", # teal
	"c9a24a", # sand
	"3c4048", # graphite
	"6a4d74", # purple
	"c16a2d", # orange
]

## Car proportions in metres. The model is authored facing -Z: headlights sit at
## the front (-Z), tail lights at the rear (+Z). The model origin is on the
## ground, wheels included, so the car node only has to be lifted to [constant
## ROAD_Y].
const BODY_SIZE := Vector3(1.8, 0.62, 4.4)
const BODY_Y := 0.61
const BODY_HALF_LENGTH := 2.2
const CABIN_SIZE := Vector3(1.55, 0.52, 2.0)
const CABIN_Y := 1.16
const CABIN_Z := 0.15
const WHEEL_RADIUS := 0.34
const WHEEL_WIDTH := 0.24
const WHEEL_X := 0.88
const WHEEL_Z := 1.42
const LIGHT_SIZE := Vector3(0.34, 0.12, 0.06)
const LIGHT_X := 0.62
const TAIL_Y := 0.80
const HEAD_Y := 0.68

## One traffic car: a plain [Node3D] plus its cruise state. No physics body and
## no collision — the deck is flat, so Z-only motion is enough.
class TrafficCar:
	extends Node3D

	## Cruise speed in m/s; shared by all cars of the lane.
	var speed := 20.0

	## +1.0 for +Z lanes, -1.0 for -Z lanes.
	var direction := 1.0

	## Move along Z and wrap to the opposite end of the bridge when the car
	## leaves the deck. Bounds are passed in so the inner class stays
	## independent from the owner script's constants.
	func advance(delta: float, z_min: float, z_max: float) -> void:
		position.z += direction * speed * delta
		if position.z < z_min:
			position.z = z_max
		elif position.z > z_max:
			position.z = z_min

## Root for the fleet; the scene test and other systems address it as "Cars".
var _cars_root: Node3D

## Spawned cars in palette order. Each car owns its speed and direction.
var _cars: Array[TrafficCar] = []

## Geometry and material resources shared by the whole fleet (built once).
var _tire_material: StandardMaterial3D
var _glass_material: StandardMaterial3D
var _tail_material: StandardMaterial3D
var _head_material: StandardMaterial3D
var _wheel_mesh: CylinderMesh


func _ready() -> void:
	_build_fleet()

## Number of traffic cars in the fleet (nine by design).
func car_count() -> int:
	return _cars.size()

func _process(delta: float) -> void:
	for car in _cars:
		car.advance(delta, Z_MIN, Z_MAX)

# ── Fleet ────────────────────────────────────────────────────────────────────

func _build_fleet() -> void:
	_cars_root = Node3D.new()
	_cars_root.name = "Cars"
	add_child(_cars_root)
	_shared_materials()
	_wheel_mesh = _build_wheel_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for lane_index in range(LANES.size()):
		var lane_x := LANES[lane_index]
		# Right-hand traffic: -X half drives towards +Z, +X half towards -Z.
		var direction := -1.0 if lane_x > 0.0 else 1.0
		# One cruise speed per lane; the seeded spread keeps the fleet varied.
		var speed := snappedf(rng.randf_range(SPEED_MIN, SPEED_MAX), 0.1)
		var z := rng.randf_range(Z_MIN, Z_MAX)
		for car_in_lane in range(CARS_PER_LANE[lane_index]):
			if car_in_lane > 0:
				# Spread the lane mates far apart, then wrap the position into
				# the loop so the whole bridge stays populated.
				z = wrapf(z + GAP_MIN + rng.randf_range(0.0, GAP_RANGE), Z_MIN, Z_MAX)
			_spawn_car(lane_x, z, speed, direction)

func _spawn_car(lane_x: float, z: float, speed: float, direction: float) -> void:
	var car_index := _cars.size()
	var car := TrafficCar.new()
	car.name = "Car_%02d" % (car_index + 1)
	car.speed = speed
	car.direction = direction
	car.position = Vector3(lane_x, ROAD_Y, z)
	# The model faces -Z, so +Z traffic is yawed 180°.
	car.rotation.y = 0.0 if direction < 0.0 else PI
	_cars_root.add_child(car)
	_add_box(car, "Body", BODY_SIZE, Vector3(0.0, BODY_Y, 0.0), _body_material(car_index))
	_add_box(car, "Cabin", CABIN_SIZE, Vector3(0.0, CABIN_Y, CABIN_Z), _glass_material)
	# Four wheels as one MultiMesh: visually four cylinders, one draw call.
	var wheels := MultiMeshInstance3D.new()
	wheels.name = "Wheels"
	wheels.multimesh = _build_wheel_multimesh()
	wheels.material_override = _tire_material
	# The wheel transforms are tiny; give the instance a car-sized AABB so it is
	# not culled by an empty or oversized bound.
	wheels.custom_aabb = AABB(Vector3(-1.2, 0.0, -1.9), Vector3(2.4, 0.8, 3.8))
	car.add_child(wheels)
	for side: float in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		_add_box(car, "TailLight_" + suffix, LIGHT_SIZE, Vector3(side * LIGHT_X, TAIL_Y, BODY_HALF_LENGTH + 0.03), _tail_material)
		_add_box(car, "HeadLight_" + suffix, LIGHT_SIZE, Vector3(side * LIGHT_X, HEAD_Y, -BODY_HALF_LENGTH - 0.03), _head_material)
	_cars.append(car)

# ── Shared resources ─────────────────────────────────────────────────────────

func _shared_materials() -> void:
	_tire_material = StandardMaterial3D.new()
	_tire_material.albedo_color = Color("1a1a1c")
	_tire_material.roughness = 0.95
	_glass_material = StandardMaterial3D.new()
	_glass_material.albedo_color = Color("1c2732")
	_glass_material.roughness = 0.12
	_glass_material.metallic = 0.55
	# Rear lamps glow red, front lamps warm white: enough to read the fleet at
	# distance without adding any dynamic lights to the scene.
	_tail_material = _emissive_material(Color("4a0f12"), Color("ff2418"), 3.2)
	_head_material = _emissive_material(Color("d8c9a8"), Color("ffe6b0"), 2.2)

func _body_material(palette_index: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(PALETTE[palette_index % PALETTE.size()])
	material.roughness = 0.38
	material.metallic = 0.35
	return material

func _emissive_material(albedo: Color, glow: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = energy
	return material

func _build_wheel_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = WHEEL_RADIUS
	mesh.bottom_radius = WHEEL_RADIUS
	mesh.height = WHEEL_WIDTH
	mesh.radial_segments = 12
	mesh.rings = 1
	return mesh

func _build_wheel_multimesh() -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _wheel_mesh
	multimesh.instance_count = 4
	# A cylinder stands on +Y by default; 90° around Z lays its axle along X so
	# the wheel can roll along the bridge. All four wheels share this basis.
	var axle_basis := Basis(Vector3.BACK, PI * 0.5)
	var index := 0
	for z: float in [-WHEEL_Z, WHEEL_Z]:
		for side: float in [-1.0, 1.0]:
			var origin := Vector3(side * WHEEL_X, WHEEL_RADIUS, z)
			multimesh.set_instance_transform(index, Transform3D(axle_basis, origin))
			index += 1
	return multimesh

# ── Helpers ──────────────────────────────────────────────────────────────────

func _add_box(parent: Node3D, node_name: String, size: Vector3, offset: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = offset
	instance.material_override = material
	parent.add_child(instance)
	return instance
