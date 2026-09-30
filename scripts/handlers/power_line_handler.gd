class_name PowerLineHandler
extends OSMWayHandler

## Overhead power cable ways (transmission line, distribution minor_line, cable)
## → drooping catenary (OSMInfrastructureBuilder).
##
## Closed power rings (substations/generators) are NOT power lines; they fall
## through to AreaHandler. This handler must therefore be registered BEFORE
## AreaHandler so the closed-ring exclusion resolves the same way the original
## if-elif chain did.

const OSMWayHandlerScript := preload("res://scripts/osm_way_handler.gd")

const _POWER_LINE_VALUES := {
	"line": true, "minor_line": true, "cable": true,
}


func handler_name() -> String:
	return "power_line"


static func is_power_line(way) -> bool:
	if OSMWayHandlerScript.is_closed_way(way):
		return false
	return _POWER_LINE_VALUES.has(way.tags.get("power", ""))


func matches(way, _ctx) -> bool:
	return is_power_line(way)


func build(way, ctx) -> Node3D:
	return ctx.infrastructure_builder.build_power_line(way, ctx.osm_data)
