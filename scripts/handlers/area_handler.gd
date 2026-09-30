class_name AreaHandler
extends OSMWayHandler

const OSMWayHandlerScript := preload("res://scripts/osm_way_handler.gd")
const PolygonUtilsScript := preload("res://scripts/polygon_utils.gd")

## Closed land-cover rings (landuse/natural/leisure, plus closed amenity/shop/
## power/area:highway and selected man_made footprints) → flat colored ground,
## with scrub and forest getting scattered vegetation (PolygonUtils).
##
## Registered LAST among the way handlers so more specific features (power
## lines, gantries, parking, ...) claim their closed rings first.

## Closed man_made values that describe a ground footprint (treatment plants,
## works, reservoirs, reinforced embankment slopes, ...) rather than a point
## structure or linear feature.
const _MAN_MADE_AREA_VALUES := {
	"wastewater_plant": true, "water_works": true, "works": true,
	"reservoir_covered": true, "storage_tank": true, "wastewater": true,
	"reinforced_slope": true, "pier": true, "bunker_silo": true,
	# Coastal flood-defence structures authored as closed footprints render as
	# flat colored ground (rock/stone/concrete banks). Their open linear variants
	# carry no fillable surface — the manager's _is_ignorable_way silences those.
	"breakwater": true, "groyne": true,
}


func handler_name() -> String:
	return "area"


static func is_area(way) -> bool:
	if way.tags.has("landuse") or way.tags.has("natural") or way.tags.has("leisure"):
		return true
	# Closed amenity/shop/power/area:highway/man_made/tourism/playground rings
	# render as flat colored ground. Open (linear) variants carry no fillable
	# surface — the manager's _is_ignorable_way suppresses their skip noise.
	if not OSMWayHandlerScript.is_closed_way(way):
		return false
	# Tourism grounds (camp_site, caravan_site, chalet plots) and playground
	# equipment footprints are closed land-cover rings.
	if way.tags.has("tourism") or way.tags.has("playground"):
		return true
	if _MAN_MADE_AREA_VALUES.has(way.tags.get("man_made", "")):
		return true
	# Historic footprints (forts, castles, archaeological sites) are closed
	# ground rings — often earthwork ramparts (historic=fort + ruins=yes) with no
	# other feature tag. Render them as colored ground.
	if way.tags.has("historic"):
		return true
	return way.tags.has("amenity") or way.tags.has("shop") \
		or way.tags.has("power") or way.tags.has("area:highway")


func matches(way, _ctx) -> bool:
	return is_area(way)


func build(way, ctx) -> Node3D:
	if PolygonUtilsScript.is_scrub(way.tags):
		return _build_scrub(way, ctx)
	if PolygonUtilsScript.is_forest(way.tags):
		return _build_forest(way, ctx)
	return _build_area(way, ctx)


func _build_scrub(way, ctx) -> Node3D:
	var points := PolygonUtilsScript.way_to_points(way.node_ids, ctx.osm_data.nodes)
	var priority := roundi(PolygonUtilsScript.ground_render_priority(
		way.tags, PolygonUtilsScript.polygon_area_xz(points)))
	var node := PolygonUtilsScript.build_scrub_area(
		points, ctx.height_provider(), ctx.grid_step, 0.01, ctx.tile_clip, priority)
	if node != null:
		node.name = "Scrub_%d" % way.id
	return node


func _build_forest(way, ctx) -> Node3D:
	var points := PolygonUtilsScript.way_to_points(way.node_ids, ctx.osm_data.nodes)
	var priority := roundi(PolygonUtilsScript.ground_render_priority(
		way.tags, PolygonUtilsScript.polygon_area_xz(points)))
	var node := PolygonUtilsScript.build_forest_area(
		points, ctx.height_provider(), ctx.grid_step, 0.01, ctx.tile_clip, priority)
	if node != null:
		node.name = "Forest_%d" % way.id
	return node


func _build_area(way, ctx) -> MeshInstance3D:
	var points := PolygonUtilsScript.way_to_points(way.node_ids, ctx.osm_data.nodes)
	var color := PolygonUtilsScript.get_area_color(way.tags)
	# Painter's-algorithm layer rank: class order + smaller-patch tiebreak, so a
	# small grass patch inside a park paints last and wins over the big polygon
	# it sits in (see PolygonUtils.ground_render_priority). Kills coplanar
	# z-fighting because the ground material also drops depth-write.
	var priority := roundi(PolygonUtilsScript.ground_render_priority(
		way.tags, PolygonUtilsScript.polygon_area_xz(points)))
	var mesh_instance: MeshInstance3D
	if ctx.has_terrain:
		mesh_instance = PolygonUtilsScript.build_terrain_draped_mesh(
			points, color, ctx.osm_data.height_provider, ctx.grid_step, 0.01, ctx.tile_clip, priority)
	else:
		mesh_instance = PolygonUtilsScript.build_flat_polygon_mesh(points, color, 0.01, true, priority)
	if mesh_instance != null:
		mesh_instance.name = "Area_%d" % way.id
	return mesh_instance
