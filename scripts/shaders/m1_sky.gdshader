shader_type sky;

// Procedural day sky with drifting fBm clouds and a sun disc driven by the
// first DirectionalLight3D. No HDRI, no downloaded assets.

uniform vec3 zenith_color : source_color = vec3(0.18, 0.38, 0.62);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.86, 0.92);
uniform vec3 ground_color : source_color = vec3(0.22, 0.25, 0.28);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.78);
uniform float sun_size = 0.0015;
uniform float sun_glow = 0.35;
uniform float cloud_coverage = 0.38;
uniform float cloud_scale = 1.4;
uniform float cloud_speed = 0.004;
uniform float cloud_opacity = 0.85;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float height = clamp(direction.y, -1.0, 1.0);
	vec3 color = mix(horizon_color, zenith_color, smoothstep(0.0, 0.55, height));
	color = mix(ground_color, color, smoothstep(-0.10, 0.02, height));

	if (LIGHT0_ENABLED) {
		float sun = dot(direction, LIGHT0_DIRECTION);
		float disc = smoothstep(1.0 - sun_size, 1.0, sun);
		float glow = pow(max(sun, 0.0), 350.0) * sun_glow;
		color += sun_color * (disc * 6.0 + glow);
	}

	if (height > 0.02) {
		vec2 uv = direction.xz / (height + 0.10) * cloud_scale;
		uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.55);
		float clouds = fbm(uv * 1.7);
		clouds = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.32, clouds);
		float fade = smoothstep(0.02, 0.22, height);
		vec3 cloud_color = mix(vec3(0.70, 0.75, 0.82), vec3(1.0), clouds);
		color = mix(color, cloud_color, clouds * cloud_opacity * fade);
	}

	COLOR = color;
}
