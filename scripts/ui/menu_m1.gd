extends Node3D

## Main menu for the M1 slice: Priora on a lit podium, dark UI, five buttons.

const SHOWCASE_SCENE := "res://scenes/showcase_bridge.tscn"
const BACKDROP_SHADER := preload("res://scripts/shaders/m1_backdrop.gdshader")
const SHADOW_SHADER := preload("res://scripts/shaders/m1_shadow.gdshader")

var _camera: Camera3D
var _car: Vehicle
var _angle := 0.85
var _toast: Label
var _toast_tween: Tween
var _ui_root: Control
var _loading := false

func _ready() -> void:
	_build_environment()
	_build_stage()
	_build_car()
	_build_camera()
	_build_ui()

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("2b394c")
	sky_material.sky_horizon_color = Color("4b5d75")
	sky_material.ground_bottom_color = Color("10141a")
	sky_material.ground_horizon_color = Color("1c2430")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.95
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.glow_bloom = 0.08
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	world_environment.add_to_group("quality_environment")

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key.light_color = Color("fff2df")
	key.light_energy = 3.6
	key.shadow_enabled = true
	add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(4.5, 3.2, -4.0)
	fill.light_color = Color("9fc4ff")
	fill.light_energy = 7.0
	fill.omni_range = 14.0
	add_child(fill)

	var rim := SpotLight3D.new()
	rim.position = Vector3(-5.0, 5.5, 7.0)
	rim.rotation_degrees = Vector3(-52.0, 42.0, 0.0)
	rim.light_color = Color("ffd9a0")
	rim.light_energy = 10.0
	rim.spot_range = 20.0
	rim.spot_angle = 28.0
	rim.shadow_enabled = true
	add_child(rim)

func _build_stage() -> void:
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("0b0d11")
	floor_material.metallic = 0.85
	floor_material.roughness = 0.12
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(60, 60)
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = floor_material
	floor_instance.position = Vector3(0, -0.14, 0)
	add_child(floor_instance)

	var podium_material := StandardMaterial3D.new()
	podium_material.albedo_color = Color("15181d")
	podium_material.metallic = 0.65
	podium_material.roughness = 0.22
	var podium_mesh := CylinderMesh.new()
	podium_mesh.top_radius = 5.4
	podium_mesh.bottom_radius = 5.7
	podium_mesh.height = 0.16
	podium_mesh.radial_segments = 64
	var podium := MeshInstance3D.new()
	podium.mesh = podium_mesh
	podium.material_override = podium_material
	podium.position = Vector3(0, -0.08, 0)
	add_child(podium)

	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = SHADOW_SHADER
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(9.0, 5.4)
	var shadow := MeshInstance3D.new()
	shadow.mesh = shadow_mesh
	shadow.material_override = shadow_material
	shadow.position = Vector3(0, 0.004, 0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

	var backdrop_material := ShaderMaterial.new()
	backdrop_material.shader = BACKDROP_SHADER
	backdrop_material.set_shader_parameter("top_color", Color("1a2430"))
	backdrop_material.set_shader_parameter("bottom_color", Color("070a0e"))
	var backdrop_mesh := CylinderMesh.new()
	backdrop_mesh.top_radius = 22.0
	backdrop_mesh.bottom_radius = 22.0
	backdrop_mesh.height = 40.0
	backdrop_mesh.radial_segments = 64
	backdrop_mesh.cap_top = false
	backdrop_mesh.cap_bottom = false
	var backdrop := MeshInstance3D.new()
	backdrop.mesh = backdrop_mesh
	backdrop.material_override = backdrop_material
	backdrop.position = Vector3(0, 20.0, 0)
	add_child(backdrop)

	var back_fill := OmniLight3D.new()
	back_fill.position = Vector3(-5.5, 3.0, 6.0)
	back_fill.light_color = Color("a9c6ff")
	back_fill.light_energy = 1.6
	back_fill.omni_range = 8.0
	back_fill.shadow_enabled = true
	add_child(back_fill)

	var front_fill := SpotLight3D.new()
	front_fill.position = Vector3(4.2, 3.0, -5.0)
	front_fill.light_color = Color("dbe8ff")
	front_fill.light_energy = 9.0
	front_fill.spot_range = 16.0
	front_fill.spot_angle = 38.0
	add_child(front_fill)
	front_fill.look_at(Vector3(0, 0.7, 0), Vector3.UP)

	var back_rim := SpotLight3D.new()
	back_rim.position = Vector3(5.4, 4.4, -5.6)
	back_rim.light_color = Color("8fb4ff")
	back_rim.light_energy = 8.0
	back_rim.spot_range = 18.0
	back_rim.spot_angle = 30.0
	add_child(back_rim)
	back_rim.look_at(Vector3(0, 0.9, 0), Vector3.UP)

	var probe := ReflectionProbe.new()
	probe.size = Vector3(30, 16, 30)
	probe.position = Vector3(0, 5, 0)
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	add_child(probe)

func _build_car() -> void:
	var packed := load("res://addons/gevp/scenes/simcade_car.tscn") as PackedScene
	if packed == null:
		push_error("Menu: cannot load vehicle scene")
		return
	_car = packed.instantiate() as Vehicle
	_car.name = "ShowroomCar"
	_car.freeze = true
	_car.set_physics_process(false)
	add_child(_car)
	var profile := ProfileManager.get_default_profile()
	profile["car"]["selected_car"] = "priora"
	profile["settings"]["quality"] = "high"
	profile["paint"]["color"] = [0.72, 0.73, 0.75, 1.0]
	profile["paint"]["finish"] = "metallic"
	profile["paint"]["tint_alpha"] = 0.35
	VehicleTuningApplicator.apply_tuning(_car, profile)
	CarDetails.attach_plates(_car)
	_car.global_position = Vector3(0, 0.46, 0)
	_car.global_rotation = Vector3(0, -0.55, 0)

func _build_camera() -> void:
	_camera = Camera3D.new()
	# The menu camera orbits in [method _process], not in a physics step, so 3D
	# physics interpolation must stay off for it; otherwise the orbit would be
	# held one tick behind the rendered frame.
	_camera.physics_interpolation_mode = Node3D.PHYSICS_INTERPOLATION_MODE_OFF
	_camera.fov = 48.0
	_camera.near = 0.05
	_camera.far = 200.0
	_camera.current = true
	add_child(_camera)
	_update_camera(0.0)

func _update_camera(delta: float) -> void:
	_angle += delta * 0.09
	var radius := 6.2
	_camera.position = Vector3(sin(_angle) * radius, 2.25, cos(_angle) * radius)
	_camera.look_at(Vector3(0, 0.9, 0), Vector3.UP)

func _process(delta: float) -> void:
	_update_camera(delta)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MenuUI"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_ui_root = root

	var title := Label.new()
	title.text = "SEMEY"
	ThemeM1.apply_label(title, 88)
	title.position = Vector2(96, 86)
	root.add_child(title)
	var drive := Label.new()
	drive.text = "DRIVE"
	ThemeM1.apply_label(drive, 88, ThemeM1.ACCENT)
	drive.position = Vector2(96, 172)
	root.add_child(drive)
	var tagline := Label.new()
	tagline.text = "мост · набережная · Приора"
	ThemeM1.apply_label(tagline, 22, ThemeM1.MUTED, false)
	tagline.position = Vector2(100, 286)
	root.add_child(tagline)

	var buttons := VBoxContainer.new()
	buttons.position = Vector2(96, 350)
	buttons.custom_minimum_size = Vector2(360, 0)
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)
	buttons.add_child(_menu_button("ИГРАТЬ", true, _play))
	buttons.add_child(_menu_button("ГАРАЖ", false, func(): _show_toast("Гараж — в следующем этапе")))
	buttons.add_child(_menu_button("АВТОСАЛОН", false, func(): _show_toast("Автосалон — в следующем этапе")))
	buttons.add_child(_menu_button("НАСТРОЙКИ", false, func(): _show_toast("Настройки — в следующем этапе")))
	buttons.add_child(_menu_button("ВЫХОД", false, func(): get_tree().quit()))

	var footer := Label.new()
	footer.text = "0.1.0 · M1 · тестовая сборка · ассеты CC0, модели авто — прототип"
	ThemeM1.apply_label(footer, 16, ThemeM1.MUTED, false)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(100, -56)
	root.add_child(footer)

	_toast = Label.new()
	_toast.text = ""
	ThemeM1.apply_label(_toast, 24, ThemeM1.ACCENT)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position = Vector2(-300, -120)
	_toast.size = Vector2(600, 48)
	_toast.modulate.a = 0.0
	root.add_child(_toast)

func _menu_button(text: String, accent: bool, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ThemeM1.apply_button(button, accent, 30)
	button.custom_minimum_size = Vector2(360, 64)
	button.pressed.connect(action)
	return button

## The showcase builds its whole world in `_ready`, so the first frame of the new
## scene can hitch for a second while geometry and shaders compile. Painting a
## loading card for two frames before the switch keeps that hitch from looking
## like a frozen black window.
func _play() -> void:
	if _loading:
		return
	_loading = true
	var card := ColorRect.new()
	card.name = "LoadingCard"
	card.color = Color("0b0d10")
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(card)
	var label := Label.new()
	label.text = "ЗАГРУЗКА..."
	ThemeM1.apply_label(label, 34, ThemeM1.ACCENT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(label)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(SHOWCASE_SCENE)

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			_play()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()
