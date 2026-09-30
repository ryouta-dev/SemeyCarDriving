class_name GantryHandler
extends OSMWayHandler

## Sign/signal gantry spanning a road (man_made=gantry) → raised cross-beam on
## support legs (OSMInfrastructureBuilder).
##
## Closed gantry rings (rare) are left to AreaHandler, so this is registered
## before AreaHandler.

const OSMWayHandlerScript := preload("res://scripts/osm_way_handler.gd")

func handler_name() -> String:
	return "gantry"


static func is_gantry(way) -> bool:
	if OSMWayHandlerScript.is_closed_way(way):
		return false
	return way.tags.get("man_made", "") == "gantry"


func matches(way, _ctx) -> bool:
	return is_gantry(way)


func build(way, ctx) -> Node3D:
	return ctx.infrastructure_builder.build_gantry(way, ctx.osm_data)
