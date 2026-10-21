shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Soft radial contact shadow under the showroom car. Cheaper and more stable
// than relying on a blurry directional shadow at this distance.

uniform float strength = 0.65;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float distance = length(uv);
	ALBEDO = vec3(0.0);
	ALPHA = smoothstep(1.0, 0.1, distance) * strength;
}
