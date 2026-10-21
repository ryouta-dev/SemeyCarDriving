class_name VehicleDefinition
extends Resource

@export var id := "simcade_car"
@export var display_name := "Muscle / Simcade"
@export_file("*.glb") var visual_path := ""
## Optional lighter copy of the same car, used for the balanced/low quality
## presets. Empty means "always use visual_path" (no low-poly variant shipped).
@export_file("*.glb") var visual_path_low := ""
@export var visual_offset := Vector3.ZERO
@export var mass_kg := 1500.0
@export var tire_radius := 0.355
@export var tire_width := 245.0
@export var rear_tire_width := 275.0
@export var front_half_track := 0.924808
@export var rear_half_track := 0.924808
@export var front_z := -1.44939
@export var rear_z := 1.44939
@export var wheel_anchor_y := 0.0879494
@export var collider_size := Vector3(2.1, 1.436, 5.35)
@export var collider_center := Vector3(0.0, 0.719, -0.043)
@export var paint_materials := PackedStringArray(["car_paint", "paint", "priora_skin"])
@export var glass_materials := PackedStringArray(["car_windshield_glass", "vehicle_vehglass.002"])
@export var rim_materials := PackedStringArray(["rims", "priora_wheel5"])

const CATALOG := {
	"simcade_car": "res://data/vehicles/simcade_car.tres",
	"lada_vaz_2110": "res://data/vehicles/lada_vaz_2110.tres",
	"priora": "res://data/vehicles/priora.tres"
}

static func get_definition(car_id: String) -> VehicleDefinition:
	return load(CATALOG.get(car_id, CATALOG["simcade_car"])) as VehicleDefinition
