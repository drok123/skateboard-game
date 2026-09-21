extends Node3D
## Instances the Venice Beach park blockout and wires player + camera.

const VeniceBeachScene := preload("res://scenes/parks/venice_beach.tscn")
const SPAWN_POS := Vector3(-6.0, 1.2, -16.0)


func _ready() -> void:
	_build_park()
	var player := $Player as CharacterBody3D
	if player:
		player.add_to_group("player")
		player.global_position = SPAWN_POS
		# Face north (+Z) into the park from the south street entrance.
		player.rotation.y = 0.0
	var cam := $FollowCamera as Camera3D
	if cam and player:
		cam.set("target_path", cam.get_path_to(player))
	_boot_session_flow()


func _boot_session_flow() -> void:
	## Mission Flow: soft G1–G4 teach goals over Venice zones.
	if has_node("SessionFlow"):
		return
	var sf := Node.new()
	sf.name = "SessionFlow"
	sf.set_script(load("res://scripts/session_flow.gd"))
	add_child(sf)


func _build_park() -> void:
	var park := $Park
	for c in park.get_children():
		c.queue_free()
	var venice = VeniceBeachScene.instantiate()
	venice.name = "VeniceBeach"
	park.add_child(venice)
