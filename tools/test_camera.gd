extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var rider := CharacterBody3D.new()
	rider.add_to_group("player")
	world.add_child(rider)
	var camera := Camera3D.new()
	camera.set_script(load("res://scripts/follow_camera.gd"))
	world.add_child(camera)
	camera.set_physics_process(false)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 8.0, 0.5)
	collision.shape = box
	wall.add_child(collision)
	world.add_child(wall)
	wall.position = Vector3(0.0, 3.0, -3.0)
	await physics_frame
	await physics_frame
	var desired := Vector3(0.0, 3.35, -7.0)
	var blocked: Vector3 = camera.call("_safe_position", desired)
	_check(blocked.z > -2.75, "Camera sweep must stop in front of wall including its radius.")
	_check(blocked.z < -1.0, "Camera should preserve useful follow distance near obstruction.")
	wall.queue_free()
	await physics_frame
	await physics_frame
	var clear: Vector3 = camera.call("_safe_position", desired)
	_check(clear.distance_to(desired) < 0.01, "Unobstructed camera must preserve requested follow position.")
	rider.position = Vector3(50.0, 0.0, 0.0)
	camera.call("_physics_process", 1.0 / 60.0)
	_check(absf(camera.global_position.x - 50.0) < 0.01, "Teleport must snap camera to new rider location in one tick.")
	_check(camera.global_position.distance_to(rider.global_position) < 9.0, "Camera cannot lag behind respawn.")
	print("Camera regression: %d failures" % failures)
	quit(1 if failures > 0 else 0)
