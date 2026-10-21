class_name QualitySettings
extends RefCounted

static func apply(viewport: Viewport, preset: String) -> void:
	viewport.msaa_3d = Viewport.MSAA_DISABLED if preset == "low" else (Viewport.MSAA_4X if preset == "high" else Viewport.MSAA_2X)
	# Balanced renders slightly below native so the low-poly variant plus the
	# light budget can hold 60 FPS on mid-range phones; high stays native.
	viewport.scaling_3d_scale = 0.75 if preset == "low" else (0.9 if preset == "balanced" else 1.0)
	Engine.max_fps = 30 if preset == "low" else 60
	if viewport.is_inside_tree():
		for light in viewport.get_tree().get_nodes_in_group("quality_sun"):
			if light is DirectionalLight3D:
				light.set_meta("allow_shadows", preset != "low")
			light.shadow_enabled = preset != "low"
	# Keep 120 Hz vehicle simulation until real-device stability tests justify 60 Hz.
