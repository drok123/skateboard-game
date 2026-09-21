extends SceneTree
## Developer helper: render a clean aerial preview of the generated park.

const OUTPUT_PATH := "res://../outputs/venice-park-native-preview.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var park_scene := load("res://scenes/parks/venice_beach.tscn") as PackedScene
	world.add_child(park_scene.instantiate())

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.72, 0.84)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.84)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	world.add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.70)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	world.add_child(sun)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 49.0, -1.5)
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	camera.fov = 52.0
	camera.current = true
	world.add_child(camera)

	await process_frame
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error := image.save_png(absolute)
	print("Park preview: %s (%s)" % [absolute, error_string(error)])
	quit(0 if error == OK else 1)
