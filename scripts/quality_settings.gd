class_name QualitySettings
extends RefCounted

static func apply(viewport: Viewport, preset: String) -> void:
	viewport.msaa_3d = Viewport.MSAA_DISABLED if preset == "low" else (Viewport.MSAA_4X if preset == "high" else Viewport.MSAA_2X)
	# Balanced renders slightly below native so the low-poly variant plus the
	# light budget can hold 60 FPS on mid-range phones; high stays native.
	viewport.scaling_3d_scale = 0.75 if preset == "low" else (0.9 if preset == "balanced" else 1.0)
	Engine.max_fps = 30 if preset == "low" else 60
	if viewport.is_inside_tree():
		var tree := viewport.get_tree()
		for light in tree.get_nodes_in_group("quality_sun"):
			if light is DirectionalLight3D:
				light.set_meta("allow_shadows", preset != "low")
				light.shadow_enabled = preset != "low"
		for node in tree.get_nodes_in_group("quality_environment"):
			if node is WorldEnvironment and node.environment != null:
				_apply_environment(node.environment, preset)

## Forward+ effects scale with the preset. SSAO stays on for high/balanced,
## SSR and volumetric fog are high-only, glow fades towards low.
static func _apply_environment(environment: Environment, preset: String) -> void:
	environment.ssao_enabled = preset != "low"
	environment.ssao_intensity = 1.4 if preset == "high" else 1.0
	environment.ssr_enabled = preset == "high"
	environment.volumetric_fog_enabled = preset == "high"
	environment.glow_enabled = true
	environment.glow_intensity = 0.65 if preset == "high" else (0.45 if preset == "balanced" else 0.25)
	# Keep 120 Hz vehicle simulation until real-device stability tests justify 60 Hz.
