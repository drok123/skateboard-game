extends MeshInstance3D
## Street deck extras parented to `$MeshPivot/Board`.
## Board stays a MeshInstance3D so player.gd can lean/pitch this node; trucks and
## wheels are children so they ride the same rotation. No GLB required.
## Derron lock: black grip, white underside + procedural NY, silver trucks,
## white wheels. skate. board-first silhouette (inspiration, no asset copy).

const DECK_SIZE := Vector3(0.52, 0.04, 1.28)
const TRUCK_SIZE := Vector3(0.42, 0.05, 0.12)
const WHEEL_RADIUS := 0.084
const WHEEL_WIDTH := 0.092
const WHEELBASE := 0.76


func _ready() -> void:
	_rebuild()


func deck_thickness() -> float:
	return _mesh_height(mesh, DECK_SIZE.y)


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var deck := BoxMesh.new()
	deck.size = DECK_SIZE
	mesh = deck
	material_override = _mat_deck_top()
	# Inset white popsicle so a thin wood rail still reads from the side.
	_add_box(
		"DeckUnderside",
		Vector3(DECK_SIZE.x - 0.012, 0.018, DECK_SIZE.z - 0.03),
		Vector3(0.0, -DECK_SIZE.y * 0.25, 0.0),
		_mat_deck_underside()
	)
	_add_ny_mark()
	_add_top_graphic()
	var z_front := WHEELBASE * 0.5
	var truck_y := -DECK_SIZE.y * 0.5 - TRUCK_SIZE.y * 0.5
	var truck_mat := _mat_truck()
	_add_box("TruckFront", TRUCK_SIZE, Vector3(0.0, truck_y, z_front), truck_mat)
	_add_box("TruckBack", TRUCK_SIZE, Vector3(0.0, truck_y, -z_front), truck_mat)
	var wheel_mat := _mat_wheel()
	# Hang wheels outboard of the hanger so ~50%+ larger disks clear trucks/deck
	# and four white discs read at mid camera (skate. board-first).
	var wheel_x := TRUCK_SIZE.x * 0.5 + WHEEL_WIDTH * 0.72
	var wheel_y := -DECK_SIZE.y * 0.5 - TRUCK_SIZE.y - WHEEL_RADIUS * 0.55
	_add_wheel("WheelFL", Vector3(-wheel_x, wheel_y, z_front), wheel_mat)
	_add_wheel("WheelFR", Vector3(wheel_x, wheel_y, z_front), wheel_mat)
	_add_wheel("WheelBL", Vector3(-wheel_x, wheel_y, -z_front), wheel_mat)
	_add_wheel("WheelBR", Vector3(wheel_x, wheel_y, -z_front), wheel_mat)


func _add_top_graphic() -> void:
	## Full black grip — Derron lock. Thin wood rail stays visible at the edge.
	## Sits on the top face; does not change deck_thickness() (Board mesh only).
	var top_y := DECK_SIZE.y * 0.5
	_add_box(
		"GripTape",
		Vector3(DECK_SIZE.x * 0.94, 0.006, DECK_SIZE.z * 0.94),
		Vector3(0.0, top_y + 0.004, 0.0),
		_mat_grip()
	)


func _add_ny_mark() -> void:
	## Procedural NY block letters on the white underside.
	## Zoo York-inspired silhouette — primitive boxes only, no asset copy.
	var ny_y := -DECK_SIZE.y * 0.25 - 0.011
	var mat := _mat_underside_mark()
	var thick := 0.042
	var top := 0.18
	var bot := -0.18
	var n_x := -0.11
	var y_x := 0.11
	var n_half := 0.058
	_add_stroke("NyNLeft", Vector2(n_x - n_half, bot), Vector2(n_x - n_half, top), ny_y, thick, mat)
	_add_stroke("NyNRight", Vector2(n_x + n_half, bot), Vector2(n_x + n_half, top), ny_y, thick, mat)
	_add_stroke("NyNDiag", Vector2(n_x - n_half, top), Vector2(n_x + n_half, bot), ny_y, thick, mat)
	_add_stroke("NyYStem", Vector2(y_x, bot), Vector2(y_x, 0.02), ny_y, thick, mat)
	_add_stroke("NyYArmL", Vector2(y_x, 0.02), Vector2(y_x - 0.072, top), ny_y, thick, mat)
	_add_stroke("NyYArmR", Vector2(y_x, 0.02), Vector2(y_x + 0.072, top), ny_y, thick, mat)


func _add_stroke(node_name: String, from_xz: Vector2, to_xz: Vector2, y: float, thick: float, mat: Material) -> void:
	var dx := to_xz.x - from_xz.x
	var dz := to_xz.y - from_xz.y
	var length := maxf(sqrt(dx * dx + dz * dz), 0.001)
	_add_box(
		node_name,
		Vector3(thick, 0.008, length),
		Vector3((from_xz.x + to_xz.x) * 0.5, y, (from_xz.y + to_xz.y) * 0.5),
		mat,
		Vector3(0.0, atan2(dx, dz), 0.0)
	)


func _add_box(node_name: String, size: Vector3, pos: Vector3, mat: Material, euler: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.rotation = euler
	mi.material_override = mat
	add_child(mi)


func _add_wheel(node_name: String, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = WHEEL_RADIUS
	cyl.bottom_radius = WHEEL_RADIUS
	cyl.height = WHEEL_WIDTH
	cyl.radial_segments = 12
	mi.mesh = cyl
	mi.position = pos
	# Cylinder is Y-up; roll 90° so the axle runs along +X.
	mi.rotation.z = PI * 0.5
	mi.material_override = mat
	add_child(mi)


func _mesh_height(m: Mesh, fallback: float) -> float:
	if m is BoxMesh:
		return maxf((m as BoxMesh).size.y, 0.001)
	if m != null:
		var aabb := m.get_aabb()
		if aabb.size.y > 0.001:
			return aabb.size.y
	return fallback


func _named_mat(mat_name: String, albedo: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = mat_name
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	return m


func _mat_deck_top() -> StandardMaterial3D:
	## Dark wood rails peeking past black grip.
	return _named_mat("Mat_deck_top", Color(0.20, 0.14, 0.10), 0.90)


func _mat_deck_underside() -> StandardMaterial3D:
	## White popsicle underside — Derron / Zoo York-inspired (no asset copy).
	return _named_mat("Mat_deck_underside", Color(0.94, 0.94, 0.96), 0.78)


func _mat_underside_mark() -> StandardMaterial3D:
	## Dark NY strokes on white deck.
	return _named_mat("Mat_underside_mark", Color(0.08, 0.08, 0.09), 0.88)


func _mat_truck() -> StandardMaterial3D:
	## Silver hangers — cooler metal so white urethane disks separate.
	return _named_mat("Mat_truck", Color(0.72, 0.74, 0.78), 0.32, 0.82)


func _mat_wheel() -> StandardMaterial3D:
	## Bright white urethane, matte. Albedo ~0.95; four disks at mid camera.
	return _named_mat("Mat_wheel", Color(0.95, 0.95, 0.97), 0.80)


func _mat_grip() -> StandardMaterial3D:
	## Black matte grip tape — Derron lock; wood rail only at the edge.
	return _named_mat("Mat_grip", Color(0.05, 0.05, 0.06), 0.96)
