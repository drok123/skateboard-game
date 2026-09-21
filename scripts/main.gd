extends Node3D
## Builds a tiny skate park from primitives and wires the player + camera.


func _ready() -> void:
	_build_park()
	var player := $Player as CharacterBody3D
	if player:
		player.add_to_group("player")
	var cam := $FollowCamera as Camera3D
	if cam and player:
		cam.set("target_path", cam.get_path_to(player))


func _build_park() -> void:
	var park := $Park
	# Ground
	_add_box(park, Vector3(40, 0.5, 40), Vector3(0, -0.25, 0), Color(0.22, 0.45, 0.28))
	# Quarter-pipe-ish wedges (rotated boxes)
	_add_ramp(park, Vector3(6, 0.4, 8), Vector3(-10, 0.5, -6), deg_to_rad(-22), Color(0.55, 0.55, 0.6))
	_add_ramp(park, Vector3(6, 0.4, 8), Vector3(10, 0.5, 6), deg_to_rad(22), Color(0.55, 0.55, 0.6))
	# Funbox
	_add_box(park, Vector3(4, 1.2, 4), Vector3(0, 0.6, -8), Color(0.7, 0.35, 0.25))
	_add_ramp(park, Vector3(4, 0.35, 3), Vector3(0, 0.9, -5.2), deg_to_rad(-28), Color(0.65, 0.4, 0.3))
	_add_ramp(park, Vector3(4, 0.35, 3), Vector3(0, 0.9, -10.8), deg_to_rad(28), Color(0.65, 0.4, 0.3))
	# Rails / ledges
	_add_box(park, Vector3(8, 0.35, 0.45), Vector3(-4, 0.55, 8), Color(0.75, 0.75, 0.8))
	_add_box(park, Vector3(0.45, 0.35, 6), Vector3(8, 0.55, -2), Color(0.75, 0.75, 0.8))
	# Boundary walls (low)
	_add_box(park, Vector3(40, 2, 0.5), Vector3(0, 1, -20), Color(0.35, 0.35, 0.4))
	_add_box(park, Vector3(40, 2, 0.5), Vector3(0, 1, 20), Color(0.35, 0.35, 0.4))
	_add_box(park, Vector3(0.5, 2, 40), Vector3(-20, 1, 0), Color(0.35, 0.35, 0.4))
	_add_box(park, Vector3(0.5, 2, 40), Vector3(20, 1, 0), Color(0.35, 0.35, 0.4))


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh_i := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_i.mesh = box
	mesh_i.material_override = _mat(color)
	body.add_child(mesh_i)
	parent.add_child(body)


func _add_ramp(parent: Node3D, size: Vector3, pos: Vector3, pitch: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.x = pitch
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh_i := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_i.mesh = box
	mesh_i.material_override = _mat(color)
	body.add_child(mesh_i)
	parent.add_child(body)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m
