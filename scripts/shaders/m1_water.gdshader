shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// River surface for the M1 slice: large vertex swells, two scales of procedural
// ripple normals and a fresnel mix so the Forward+ sky and the sun reflect in it.
// Ripples fade with distance, otherwise the far water shimmers and aliases.

uniform vec3 deep_color : source_color = vec3(0.015, 0.062, 0.095);
uniform vec3 shallow_color : source_color = vec3(0.055, 0.185, 0.245);
uniform float wave_scale = 0.05;
uniform float wave_speed = 0.55;
uniform float wave_height = 0.22;
uniform float ripple_scale = 1.5;
uniform float roughness_value = 0.05;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float swell = sin(world_pos.x * wave_scale + TIME * wave_speed)
		* cos(world_pos.z * wave_scale * 1.27 + TIME * wave_speed * 0.73);
	float chop = sin(world_pos.x * wave_scale * 2.7 + world_pos.z * wave_scale * 1.9
		+ TIME * wave_speed * 1.9);
	VERTEX.y += (swell * 0.72 + chop * 0.28) * wave_height;
}

void fragment() {
	float t = TIME;
	float f1 = clamp(140.0 / max(length(world_pos - CAMERA_POSITION_WORLD), 1.0), 0.12, 1.0);
	float nx = sin(world_pos.x * ripple_scale + t * 1.2) * 0.42
		+ sin(world_pos.x * ripple_scale * 2.3 - world_pos.z * ripple_scale * 1.7 + t * 2.1) * 0.26
		+ sin(world_pos.x * ripple_scale * 0.37 + world_pos.z * ripple_scale * 0.53 + t * 0.31) * 0.32;
	float nz = cos(world_pos.z * ripple_scale * 1.35 + t * 0.95) * 0.42
		+ cos(world_pos.x * ripple_scale * 1.9 + world_pos.z * ripple_scale * 2.5 + t * 1.75) * 0.26
		+ cos(world_pos.x * ripple_scale * 0.61 - world_pos.z * ripple_scale * 0.41 + t * 0.23) * 0.32;
	vec3 normal = normalize(vec3(nx * 0.08 * f1, 1.0, nz * 0.08 * f1));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.5);
	ALBEDO = mix(deep_color, shallow_color, clamp(0.32 + 0.68 * fresnel, 0.0, 1.0));
	METALLIC = mix(0.92, 0.30, fresnel);
	ROUGHNESS = mix(roughness_value, 0.22, fresnel);
	SPECULAR = 1.0;
}
