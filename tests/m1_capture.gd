extends SceneTree

## Dev helper: renders the menu and the bridge slice, saves two PNGs for visual
## review. Run without --headless (needs a real renderer):
##   godot --path . --script res://tests/m1_capture.gd

const OUT_DIR := "user://m1_captures"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var menu := (load("res://scenes/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await _wait(90)
	_capture("menu.png")
	menu.queue_free()
	await _wait(10)
	var zone := (load("res://scenes/showcase_bridge.tscn") as PackedScene).instantiate()
	root.add_child(zone)
	await _wait(150)
	_capture("bridge.png")
	# Third shot: the river pier and the stairs, seen from the water side.
	var sight_seer := Camera3D.new()
	sight_seer.position = Vector3(158.0, 5.0, 24.0)
	sight_seer.fov = 50.0
	root.add_child(sight_seer)
	sight_seer.look_at(Vector3(112.0, -2.0, 58.0))
	sight_seer.current = true
	await _wait(30)
	_capture("embankment.png")
	zone.queue_free()
	await _wait(5)
	quit()

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("capture failed: empty image")
		return
	var path := ProjectSettings.globalize_path(OUT_DIR + "/" + file_name)
	image.save_png(path)
	print("saved ", path, " ", image.get_width(), "x", image.get_height())
