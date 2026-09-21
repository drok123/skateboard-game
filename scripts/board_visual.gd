extends MeshInstance3D
## Replaces the fat slab BoxMesh with a readable skateboard: thin deck, trucks, wheels.
## Physics still owns Board node path + lean/tilt on this node.

const DECK_SIZE := Vector3(0.52, 0.04, 1.28)
const TRUCK_SIZE := Vector3(0.42, 0.05, 0.12)
const WHEEL_RADIUS := 0.045
const WHEEL_WIDTH := 0.055


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	# Clear procedural children; keep this MeshInstance as deck.
	for c in get_children():
		c.queue_free()

	var deck := BoxMesh.new()
	deck.size = DECK_SIZE
	mesh = deck

	var mat_deck := StandardMaterial3D.new()
	mat_deck.albedo_color = Color(0.42, 0.28, 0.16)  # wood top read
	mat_deck.roughness = 0.65
	material_override = mat_deck

	var mat_grip := StandardMaterial3D.new()
	mat_grip.albedo_color = Color(0.12, 0.12, 0.13)
	mat_grip.roughness = 0.95

	# Thin grip tape on top
	var grip := MeshInstance3D.new()
	grip.name = "GripTape"
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(DECK_SIZE.x * 0.92, 0.008, DECK_SIZE.z * 0.92)
	grip.mesh = grip_mesh
	grip.position = Vector3(0.0, DECK_SIZE.y * 0.5 + 0.004, 0.0)
	grip.material_override = mat_grip
	add_child(grip)

	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.55, 0.55, 0.58)
	mat_metal.metallic = 0.7
	mat_metal.roughness = 0.35

	var mat_wheel := StandardMaterial3D.new()
	mat_wheel.albedo_color = Color(0.85, 0.85, 0.88)
	mat_wheel.roughness = 0.4

	for z_sign in [-1.0, 1.0]:
		var truck := MeshInstance3D.new()
		truck.name = "Truck_%s" % ("nose" if z_sign > 0.0 else "tail")
		var tmesh := BoxMesh.new()
		tmesh.size = TRUCK_SIZE
		truck.mesh = tmesh
		truck.position = Vector3(0.0, -DECK_SIZE.y * 0.5 - TRUCK_SIZE.y * 0.5, z_sign * 0.38)
		truck.material_override = mat_metal
		add_child(truck)

		for x_sign in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel_%s_%s" % [truck.name, "L" if x_sign < 0.0 else "R"]
			var wmesh := CylinderMesh.new()
			wmesh.top_radius = WHEEL_RADIUS
			wmesh.bottom_radius = WHEEL_RADIUS
			wmesh.height = WHEEL_WIDTH
			wmesh.radial_segments = 10
			wheel.mesh = wmesh
			# Cylinder default is Y-up; lay on X for axle.
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(
				x_sign * (TRUCK_SIZE.x * 0.5 + WHEEL_WIDTH * 0.35),
				-DECK_SIZE.y * 0.5 - TRUCK_SIZE.y - WHEEL_RADIUS * 0.15,
				z_sign * 0.38
			)
			wheel.material_override = mat_wheel
			add_child(wheel)
