extends SceneTree
## Run: godot --headless --path . --script tools/test_gameplay.gd

var failures := 0
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func tick(frames: int, push: float = 0.0, brake: float = 0.0, steer: float = 0.0) -> void:
	for frame in frames:
		await physics_frame
		player.call("apply_riding_input", steer, push, brake, false, 1.0 / 60.0)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(500, 1, 500)
	collision.shape = box
	floor_body.add_child(collision)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	for child in player.get_children():
		if child.get_script() and child.get_script().resource_path.ends_with("player_input.gd"):
			child.set_physics_process(false)
	player.global_position = Vector3(0, 1.5, 0)
	await tick(90)
	check(player.is_on_floor(), "player settles on flat ground")
	await tick(120, 1.0)
	var pushed: float = player.call("get_horizontal_speed")
	check(pushed > 5.0, "cadenced pushing builds riding speed")
	await tick(60)
	var coasted: float = player.call("get_horizontal_speed")
	check(coasted > pushed * 0.8 and coasted < pushed, "release coasts with modest rolling resistance")
	await tick(45, 0.0, 1.0)
	check(float(player.call("get_horizontal_speed")) < coasted * 0.25, "brake stops faster than coasting")
	await tick(45, 0.0, 1.0)
	check(float(player.call("get_signed_speed")) < -0.25, "holding brake after stopping enters a slow reverse")
	var facing_before_idle_steer: float = player.call("get_facing_yaw")
	player.velocity = Vector3.ZERO
	await tick(30, 0.0, 0.0, 1.0)
	check(absf(angle_difference(facing_before_idle_steer, float(player.call("get_facing_yaw")))) < 0.01, "idle steering does not spin the board in place")
	await tick(90, 1.0)
	var before_pop: float = player.call("get_horizontal_speed")
	await physics_frame
	player.call("apply_riding_input", 0.0, 0.0, 0.0, true, 1.0 / 60.0)
	check(player.velocity.y > 0.0, "ollie leaves ground")
	check(float(player.call("get_horizontal_speed")) <= before_pop + 0.01, "ollie does not manufacture forward speed")
	await tick(60)
	check(player.is_on_floor(), "ollie lands")
	check(float(player.call("get_horizontal_speed")) > before_pop * 0.85, "clean landing preserves momentum")
	var tricks: Node = player.get_node("TrickSystem")
	tricks.set_process(false)
	tricks.call("notify_bailed")
	tricks.call("notify_trick_started", "ollie")
	tricks.call("notify_trick_landed")
	check(int(tricks.get("_combo_score")) > 0, "first landed ollie awards points")
	tricks.call("_process", 3.0)
	check(int(tricks.get("_combo_score")) == 0, "single-trick combo expires")
	tricks.call("notify_trick_started", "ollie")
	Input.action_press("move_right")
	tricks.call("_process", 0.01)
	check(tricks.get("_active_trick") == "ollie", "air steering does not trigger an unwanted trick")
	Input.action_release("move_right")
	tricks.call("_upgrade_air_trick", "kickflip")
	tricks.call("_upgrade_air_trick", "tre")
	check(tricks.get("_active_trick") == "kickflip", "air trick is committed, not overwritten by spam")
	tricks.call("notify_trick_landed")
	check(int(tricks.get("_combo_score")) == 0, "uncaught flip landing awards no points")
	tricks.call("notify_trick_started", "ollie")
	tricks.call("_upgrade_air_trick", "kickflip")
	tricks.call("_process", 0.5)
	tricks.call("notify_trick_landed")
	check(int(tricks.get("_combo_score")) >= 350, "completed flip scores on landing")
	tricks.call("notify_bailed")
	tricks.call("notify_grind_started", "Flatbar")
	tricks.call("_process", 0.5)
	tricks.call("notify_grind_ended")
	check(int(tricks.get("_combo_score")) >= 150, "sustained grind scores on exit")
	var flow: Node = load("res://scripts/session_flow.gd").new()
	world.add_child(flow)
	flow.set_physics_process(false)
	flow.set("_player", player)
	flow.set("_in_street", true)
	check(not bool(flow.call("_touching_street_grindable")), "warm-up requires actual grind state")
	flow.set("_active_index", 3)
	flow.set("_gap_armed", true)
	flow.set("_gap_was_airborne", false)
	player.velocity = Vector3(0, 0, 8)
	flow.call("_try_stair_gap")
	check(not bool(flow.get("_complete")), "rolling past stairs does not award an airborne gap")
	player.call("reset_to_spawn")
	check(player.velocity == Vector3.ZERO and not bool(player.call("is_grinding")), "respawn resets motion and grind state")
	var rail := StaticBody3D.new()
	rail.add_to_group("grindable")
	var rail_shape := CollisionShape3D.new()
	var rail_box := BoxShape3D.new()
	rail_box.size = Vector3(0.12, 0.12, 10)
	rail_shape.shape = rail_box
	rail.add_child(rail_shape)
	rail.position = Vector3(30, 1, 0)
	world.add_child(rail)
	await physics_frame
	player.position = Vector3(32, 1.12, 0)
	player.velocity = Vector3(0, -0.2, 5)
	player.set("_grind_cooldown", 0.0)
	await tick(1)
	check(not bool(player.call("is_grinding")), "rail cannot attract a rider from two metres away")
	player.position = Vector3(30, 1.12, 0)
	player.velocity = Vector3(0, -0.2, 5)
	await tick(1)
	check(bool(player.call("is_grinding")), "descending onto a rail top locks a grind")
	await physics_frame
	player.call("apply_riding_input", 0.0, 0.0, 0.0, true, 1.0 / 60.0)
	check(not bool(player.call("is_grinding")) and player.velocity.y > 0, "rail ollie exits without immediate relock")
	print("Gameplay regression failures: ", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
