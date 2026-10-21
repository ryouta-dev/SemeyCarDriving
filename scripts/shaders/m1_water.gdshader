shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// River surface for the M1 slice: gentle vertex waves, a fine procedural
// normal ripple and a metallic fresnel so the Forward+ sky reflects in it.

uniform vec3 deep_color : source_color = vec3(0.04, 0.12, 0.18);
uniform vec3 shallow_color : source_color = vec3(0.10, 0.27, 0.34);
uniform float wave_scale = 0.06;
uniform float wave_speed = 0.7;
uniform float wave_height = 0.10;
uniform float ripple_scale = 0.9;
uniform float roughness_value = 0.06;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float waves = sin(world_pos.x * wave_scale + TIME * wave_speed)
		* cos(world_pos.z * wave_scale * 1.3 + TIME * wave_speed * 0.7);
	VERTEX.y += waves * wave_height;
}

void fragment() {
	float r1 = sin(world_pos.x * ripple_scale + TIME * 1.3);
	float r2 = cos(world_pos.z * ripple_scale * 1.4 + TIME * 1.1);
	vec3 normal = normalize(vec3(r1 * 0.035, 1.0, r2 * 0.035));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
	ALBEDO = mix(deep_color, shallow_color, 0.4);
	METALLIC = 0.85;
	ROUGHNESS = roughness_value;
	SPECULAR = 1.0;
}
