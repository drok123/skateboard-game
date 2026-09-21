extends SceneTree
## Run: godot --headless --path . --script tools/test_venice_park.gd

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/parks/venice_beach.tscn") as PackedScene
	_check(scene != null, "Venice scene loads")
	if scene == null:
		quit(1)
		return
	var park := scene.instantiate()
	root.add_child(park)
	await process_frame
	await physics_frame
	var surface := park.get_node_or_null("VeniceRideSurface") as StaticBody3D
	_check(surface != null, "continuous ride surface is generated")
	_check(surface != null and surface.is_in_group("deck") and surface.is_in_group("bowl"), "ride surface keeps deck and bowl groups")
	_check(park.get_node_or_null("StairsA") != null and park.get_node_or_null("StairsB") != null, "mission stair names are preserved")
	_check(park.get_node_or_null("LongLedge") != null and park.get_node_or_null("Flatbar") != null, "street grind targets are preserved")
	_check(park.get_node_or_null("PalmTerrace") != null, "southeast palm terrace landmark exists")
	for zone_name in ["zone_street", "zone_snake", "zone_clover", "zone_stairs_b"]:
		_check(not get_nodes_in_group(zone_name).is_empty(), "%s remains wired" % zone_name)
	var space := root.get_world_3d().direct_space_state
	_check_height(space, Vector3(-6.0, 4.0, -16.0), -0.15, 0.15, "spawn street stays at grade")
	_check_height(space, Vector3(-12.0, 4.0, 9.7), -2.7, -2.3, "west kidney has a deep rideable floor")
	_check_height(space, Vector3(11.2, 4.0, 10.0), -3.2, -2.8, "east hero bowl reaches intended depth")
	_check_height(space, Vector3(7.0, 4.0, 9.0), -0.35, -0.05, "east bowl transfer island remains raised")
	print("Venice park regression failures: %d" % failures)
	park.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)


func _check_height(space: PhysicsDirectSpaceState3D, from: Vector3, min_y: float, max_y: float, label: String) -> void:
	var query := PhysicsRayQueryParameters3D.create(from, Vector3(from.x, -5.0, from.z))
	var hit := space.intersect_ray(query)
	var y := float(hit.get("position", Vector3(0.0, -99.0, 0.0)).y)
	_check(not hit.is_empty() and y >= min_y and y <= max_y, "%s (%.2f m)" % [label, y])


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)
