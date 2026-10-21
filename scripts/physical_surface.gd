class_name PhysicalSurface
extends RefCounted

# Explicit surface metadata is the contract between OSM and GEVP.
static func from_tags(tags: Dictionary) -> String:
	var surface: String = String(tags.get("surface", ""))
	if surface in ["grass", "grass_paver"] or tags.get("landuse", "") in ["grass", "meadow", "forest"] or tags.get("natural", "") in ["grassland", "scrub", "wood"] or tags.get("leisure", "") in ["park", "garden"]:
		return "Grass"
	if surface in ["dirt", "earth", "ground", "mud", "sand", "gravel", "fine_gravel", "compacted"] or tags.get("highway", "") in ["track", "path"]:
		return "Dirt"
	return "Road"

static func attach(root: Node3D, surface: String) -> void:
	if root == null:
		return
	var mesh_instance: MeshInstance3D = root as MeshInstance3D
	if mesh_instance != null:
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null or mesh.get_surface_count() == 0:
			return
		if mesh_instance.has_meta("physical_surface_attached"):
			return
		var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
		if shape == null:
			return
		shape.backface_collision = true
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "SurfaceCollision"
		body.set_meta("surface_type", surface)
		body.add_to_group(surface)
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		mesh_instance.add_child(body)
		mesh_instance.set_meta("physical_surface_attached", true)
		return
	for child: Node in root.get_children():
		var child_3d: Node3D = child as Node3D
		if child_3d != null and not (child is PhysicsBody3D):
			attach(child_3d, surface)
