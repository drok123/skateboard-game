extends MeshInstance3D
## Street deck extras parented to `$MeshPivot/Board`.
## Board stays a MeshInstance3D so player.gd can lean/pitch this node; trucks and
## wheels are children so they ride the same rotation. No GLB required.

const DECK_SIZE := Vector3(0.52, 0.04, 1.28)
const TRUCK_SIZE := Vector3(0.42, 0.05, 0.12)
const WHEEL_RADIUS := 0.082
const WHEEL_WIDTH := 0.090
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
	# Inset underside so the slightly lighter top rim reads from the side.
	_add_box(
		"DeckUnderside",
		Vector3(DECK_SIZE.x - 0.012, 0.018, DECK_SIZE.z - 0.03),
		Vector3(0.0, -DECK_SIZE.y * 0.25, 0.0),
		_mat_deck_underside()
	)
	# Simple dark NY block — Zoo York-inspired silhouette, no asset copy.
	_add_box(
		"UndersideNY",
		Vector3(0.20, 0.008, 0.26),
		Vector3(0.0, -DECK_SIZE.y * 0.25 - 0.011, 0.0),
		_mat_underside_mark()
	)
	_add_top_graphic()
	var z_front := WHEELBASE * 0.5
	var truck_y := -DECK_SIZE.y * 0.5 - TRUCK_SIZE.y * 0.5
	var truck_mat := _mat_truck()
	_add_box("TruckFront", TRUCK_SIZE, Vector3(0.0, truck_y, z_front), truck_mat)
	_add_box("TruckBack", TRUCK_SIZE, Vector3(0.0, truck_y, -z_front), truck_mat)
	var wheel_mat := _mat_wheel()
	# Hang wheels just outside the hanger so larger disks clear trucks and deck.
	var wheel_x := TRUCK_SIZE.x * 0.5 + WHEEL_WIDTH * 0.52
	var wheel_y := -DECK_SIZE.y * 0.5 - TRUCK_SIZE.y - WHEEL_RADIUS * 0.55
	_add_wheel("WheelFL", Vector3(-wheel_x, wheel_y, z_front), wheel_mat)
	_add_wheel("WheelFR", Vector3(wheel_x, wheel_y, z_front), wheel_mat)
	_add_wheel("WheelBL", Vector3(-wheel_x, wheel_y, -z_front), wheel_mat)
	_add_wheel("WheelBR", Vector3(wheel_x, wheel_y, -z_front), wheel_mat)


func _add_top_graphic() -> void:
	## High-contrast procedural graphic so the deck reads at mid camera — not a brown slab.
	## Sits on the top face; does not change deck_thickness() (Board mesh only).
	var top_y := DECK_SIZE.y * 0.5
	var grip := _mat_grip()
	var stripe := _mat_stripe()
	var mark := _mat_logo_mark()
	_add_box(
		"GripTape",
		Vector3(DECK_SIZE.x * 0.90, 0.006, DECK_SIZE.z * 0.88),
		Vector3(0.0, top_y + 0.004, 0.0),
		grip
	)
	_add_box(
		"CenterStripe",
		Vector3(0.08, 0.007, DECK_SIZE.z * 0.72),
		Vector3(0.0, top_y + 0.008, 0.0),
		stripe
	)
	_add_box(
		"LogoBlock",
		Vector3(0.22, 0.008, 0.28),
		Vector3(0.0, top_y + 0.010, DECK_SIZE.z * 0.28),
		stripe
	)
	_add_box(
		"LogoMark",
		Vector3(0.12, 0.009, 0.16),
		Vector3(0.0, top_y + 0.012, DECK_SIZE.z * 0.28),
		mark
	)


func _add_box(node_name: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
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
	## Dark wood rails/top under grip — contrast vs white popsicle underside.
	return _named_mat("Mat_deck_top", Color(0.20, 0.14, 0.10), 0.90)


func _mat_deck_underside() -> StandardMaterial3D:
	## White popsicle underside — Zoo York-inspired read (no asset copy).
	return _named_mat("Mat_deck_underside", Color(0.94, 0.94, 0.96), 0.78)


func _mat_underside_mark() -> StandardMaterial3D:
	## Dark NY block on white deck.
	return _named_mat("Mat_underside_mark", Color(0.08, 0.08, 0.09), 0.88)


func _mat_truck() -> StandardMaterial3D:
	## Silver hangers — cooler metal so white urethane disks separate.
	return _named_mat("Mat_truck", Color(0.62, 0.64, 0.68), 0.38, 0.72)


func _mat_wheel() -> StandardMaterial3D:
	## Bright white urethane, matte. Albedo ~0.95; four disks at mid camera.
	return _named_mat("Mat_wheel", Color(0.95, 0.95, 0.97), 0.80)


func _mat_grip() -> StandardMaterial3D:
	## Dark matte grip tape — contrast vs wood rails at the deck edge.
	return _named_mat("Mat_grip", Color(0.07, 0.07, 0.08), 0.96)


func _mat_stripe() -> StandardMaterial3D:
	## Warm cream stripe / logo plate — mid-distance pop, not neon.
	return _named_mat("Mat_stripe", Color(0.88, 0.82, 0.70), 0.78)


func _mat_logo_mark() -> StandardMaterial3D:
	## Charcoal inner mark on the cream plate.
	return _named_mat("Mat_logo_mark", Color(0.10, 0.10, 0.11), 0.90)
