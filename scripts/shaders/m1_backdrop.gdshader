shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Studio backdrop gradient for the main menu: dark floor fading into a
// slightly lighter upper wall, no textures, no environment dependency.

uniform vec3 top_color : source_color = vec3(0.10, 0.15, 0.20);
uniform vec3 bottom_color : source_color = vec3(0.03, 0.04, 0.06);

void fragment() {
	ALBEDO = mix(bottom_color, top_color, clamp(UV.y, 0.0, 1.0));
}
