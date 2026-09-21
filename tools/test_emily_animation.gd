extends SceneTree
## Run: godot --headless --path . --script tools/test_emily_animation.gd

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/player.tscn") as PackedScene
	_check(packed != null, "player scene loads")
	if packed == null:
		quit(1)
		return
	var player := packed.instantiate()
	root.add_child(player)
	await process_frame
	await process_frame
	var emily := player.get_node("MeshPivot/Emily") as Node3D
	var skeleton := emily.call("get_skeleton") as Skeleton3D
	_check(skeleton != null, "Emily exposes a live Skeleton3D")
	if skeleton:
		for name in ["Hips", "Spine", "Chest", "Head", "UpperArm.L", "UpperArm.R", "Thigh.L", "Shin.L", "Foot.L", "Thigh.R", "Shin.R", "Foot.R"]:
			_check(skeleton.find_bone(name) >= 0, "rig includes %s" % name)
		var animator := emily.get_node("ProceduralAnimator")
		animator.set_process(false)
		var stance: Dictionary = animator.call("_base_pose")
		animator.call("_apply_pose", stance, 1.0)
		var hips := skeleton.find_bone("Hips")
		_check(skeleton.get_bone_pose_position(hips).y < -0.01, "stance uses hip weight instead of root squash")
		var air_pose: Dictionary = animator.call("_base_pose")
		animator.call("_apply_air", air_pose, 0.26, "kickflip")
		animator.call("_apply_pose", air_pose, 1.0)
		var shin := skeleton.find_bone("Shin.L")
		_check(skeleton.get_bone_pose_rotation(shin).get_angle() > 0.4, "air pose visibly tucks the front knee")
	var mesh_root := emily.get_node("EmilyMesh") as Node3D
	_check(mesh_root != null and mesh_root.position.y > 0.85, "mesh origin is lifted so feet meet the deck")
	player.queue_free()
	await process_frame
	print("Emily animation assertions: %d failures" % failures)
	quit(1 if failures else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)
