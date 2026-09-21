extends Node3D
## Venice Beach-inspired native park surface based on the supplied aerials and the
## authorized skater-test builder. It is a playable interpretation, not survey data.

const StairsSetScene := preload("res://scenes/parks/modules/stairs_set.tscn")
const LedgeScene := preload("res://scenes/parks/modules/ledge.tscn")
const FlatbarScene := preload("res://scenes/parks/modules/flatbar.tscn")
const ManualPadScene := preload("res://scenes/parks/modules/manual_pad.tscn")
const BankQpScene := preload("res://scenes/parks/modules/bank_qp.tscn")
const PlanterRoundScene := preload("res://scenes/parks/modules/planter_round.tscn")

const PARK_WIDTH := 48.0
const PARK_DEPTH := 40.0
const CORNER_RADIUS := 5.0
const SURFACE_RESOLUTION := 0.5
const SPAWN_POS := Vector3(-6.0, 1.2, -16.0)
const COLOR_DECK := Color(0.58, 0.57, 0.54)
const COLOR_FEATURE := Color(0.66, 0.65, 0.61)
const COLOR_METAL := Color(0.09, 0.105, 0.12)
const COLOR_SAND := Color(0.82, 0.68, 0.43)

var _deck_material: Material


func _ready() -> void:
	var concrete_shader := load("res://materials/park/concrete_procedural.gdshader") as Shader
	if concrete_shader:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = concrete_shader
		_deck_material = shader_material
	else:
		_deck_material = PropKit.mat(COLOR_DECK, 0.96, 0.0)
		_deck_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_build_sand_surround()
	_build_ride_surface()
	_build_street_plaza()
	_build_coping()
	_build_perimeter_details()
	_build_palms()
	_build_zones()
	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.position = SPAWN_POS
	add_child(spawn)


func _build_sand_surround() -> void:
	# Separate beach patches cannot show through the recessed bowl bottoms.
	PropKit.add_box(self, Vector3(20.0, 0.25, 66.0), Vector3(-34.0, -0.28, 0.0), COLOR_SAND, PackedStringArray(["out_of_bounds"]))
	PropKit.add_box(self, Vector3(20.0, 0.25, 66.0), Vector3(34.0, -0.28, 0.0), COLOR_SAND, PackedStringArray(["out_of_bounds"]))
	PropKit.add_box(self, Vector3(48.0, 0.25, 13.0), Vector3(0.0, -0.28, 26.5), COLOR_SAND, PackedStringArray(["out_of_bounds"]))
	PropKit.add_box(self, Vector3(48.0, 0.25, 13.0), Vector3(0.0, -0.28, -26.5), COLOR_SAND, PackedStringArray(["out_of_bounds"]))
	PropKit.add_box(self, Vector3(82.0, 0.2, 70.0), Vector3(0.0, -3.8, 0.0), COLOR_SAND, PackedStringArray(["out_of_bounds"]))


func _build_ride_surface() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x_steps := int(ceil(PARK_WIDTH / SURFACE_RESOLUTION))
	var z_steps := int(ceil(PARK_DEPTH / SURFACE_RESOLUTION))
	var x_min := -PARK_WIDTH * 0.5
	var z_min := -PARK_DEPTH * 0.5
	var dx := PARK_WIDTH / float(x_steps)
	var dz := PARK_DEPTH / float(z_steps)
	for zi in range(z_steps):
		var z0 := z_min + float(zi) * dz
		var z1 := z0 + dz
		for xi in range(x_steps):
			var x0 := x_min + float(xi) * dx
			var x1 := x0 + dx
			var center := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			if not _inside_footprint(center.x, center.y):
				continue
			var a := Vector3(x0, _surface_height(x0, z0), z0)
			var b := Vector3(x1, _surface_height(x1, z0), z0)
			var c := Vector3(x1, _surface_height(x1, z1), z1)
			var d := Vector3(x0, _surface_height(x0, z1), z1)
			_add_triangle(st, a, b, c)
			_add_triangle(st, a, c, d)
	st.generate_normals()
	var mesh := st.commit() as ArrayMesh
	if mesh == null:
		push_error("Venice park surface generation failed")
		return
	_add_mesh_static("VeniceRideSurface", mesh, _deck_material, PackedStringArray(["deck", "bowl"]))


func _inside_footprint(x: float, z: float) -> bool:
	var qx := absf(x) - (PARK_WIDTH * 0.5 - CORNER_RADIUS)
	var qz := absf(z) - (PARK_DEPTH * 0.5 - CORNER_RADIUS)
	var outside := Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length() + minf(maxf(qx, qz), 0.0) - CORNER_RADIUS
	return outside <= 0.0 or Vector2(x - 21.0, z + 7.0).length() <= 5.1


func _surface_height(x: float, z: float) -> float:
	var y := 0.0
	# Deep west kidney, central linked snake, and east hero kidney/clover.
	y = minf(y, _ellipse_bowl(x, z, Vector2(-12.0, 9.7), Vector2(8.4, 8.7), 2.55, 0.68))
	y = minf(y, _ellipse_bowl(x, z, Vector2(-15.0, 14.0), Vector2(4.7, 4.2), 2.15, 0.63))
	y = minf(y, _ellipse_bowl(x, z, Vector2(-2.2, 8.5), Vector2(5.3, 7.6), 1.55, 0.61))
	y = minf(y, _ellipse_bowl(x, z, Vector2(1.5, 14.0), Vector2(4.2, 4.5), 1.30, 0.58))
	y = minf(y, _ellipse_bowl(x, z, Vector2(11.2, 10.0), Vector2(7.4, 8.7), 3.05, 0.66))
	y = minf(y, _ellipse_bowl(x, z, Vector2(15.0, 14.2), Vector2(4.4, 4.5), 2.60, 0.61))
	y = minf(y, _ellipse_bowl(x, z, Vector2(16.4, 5.0), Vector2(3.6, 4.2), 1.25, 0.56))
	# Raised central island creates the paired transfer channels seen in the aerial.
	y = _raise_island(y, x, z, Vector2(7.0, 9.0), Vector2(2.0, 5.4), -0.18, 0.50)
	if z < 3.2:
		var plaza_blend := _smooth01(clampf((3.2 - z) / 3.2, 0.0, 1.0))
		y = lerpf(y, 0.0, plaza_blend)
	return y


func _ellipse_bowl(x: float, z: float, center: Vector2, radii: Vector2, depth: float, bottom_ratio: float) -> float:
	var radius := Vector2((x - center.x) / radii.x, (z - center.y) / radii.y).length()
	if radius >= 1.0:
		return 0.0
	var inner := clampf(bottom_ratio, 0.05, 0.9)
	if radius <= inner:
		return -depth + 0.025 * depth * pow(radius / inner, 2.0)
	var t := clampf((radius - inner) / (1.0 - inner), 0.0, 1.0)
	return -depth * sqrt(maxf(0.0, 1.0 - t * t))


func _raise_island(current_y: float, x: float, z: float, center: Vector2, radii: Vector2, top_y: float, inner_ratio: float) -> float:
	var radius := Vector2((x - center.x) / radii.x, (z - center.y) / radii.y).length()
	if radius >= 1.0:
		return current_y
	var blend := 1.0
	if radius > inner_ratio:
		blend = 1.0 - _smooth01((radius - inner_ratio) / (1.0 - inner_ratio))
	return lerpf(current_y, maxf(current_y, top_y), blend)


func _build_street_plaza() -> void:
	var stairs_a = StairsSetScene.instantiate()
	stairs_a.name = "StairsA"
	stairs_a.step_count = 4
	stairs_a.width = 4.2
	stairs_a.tread = 0.46
	stairs_a.with_hubba = true
	stairs_a.position = Vector3(-14.2, 0.0, -14.2)
	add_child(stairs_a)
	var stairs_b = StairsSetScene.instantiate()
	stairs_b.name = "StairsB"
	stairs_b.step_count = 6
	stairs_b.width = 5.0
	stairs_b.tread = 0.48
	stairs_b.with_hubba = false
	stairs_b.with_handrail = true
	stairs_b.position = Vector3(-7.8, 0.0, -13.8)
	add_child(stairs_b)
	var bank = BankQpScene.instantiate()
	bank.name = "CenterBank"
	bank.width = 6.2
	bank.height = 0.9
	bank.angle_deg = 16.0
	bank.position = Vector3(0.0, 0.0, -10.2)
	add_child(bank)
	var pad = ManualPadScene.instantiate()
	pad.name = "ManualPad"
	pad.length = 5.4
	pad.width = 2.1
	pad.height = 0.32
	pad.position = Vector3(1.5, 0.0, -15.2)
	add_child(pad)
	var ledge = LedgeScene.instantiate()
	ledge.name = "LongLedge"
	ledge.length = 7.8
	ledge.depth = 0.7
	ledge.height = 0.48
	ledge.position = Vector3(10.3, 0.0, -11.0)
	add_child(ledge)
	var ledge_low = LedgeScene.instantiate()
	ledge_low.name = "Ledge2"
	ledge_low.length = 4.8
	ledge_low.depth = 0.62
	ledge_low.height = 0.28
	ledge_low.position = Vector3(8.2, 0.0, -15.0)
	add_child(ledge_low)
	var rail = FlatbarScene.instantiate()
	rail.name = "Flatbar"
	rail.length = 4.4
	rail.height = 0.42
	rail.position = Vector3(4.8, 0.0, -12.4)
	add_child(rail)
	var roll_in = BankQpScene.instantiate()
	roll_in.name = "PlazaToSnakeBank"
	roll_in.width = 7.2
	roll_in.height = 0.7
	roll_in.angle_deg = 14.0
	roll_in.position = Vector3(-1.0, 0.0, -1.6)
	add_child(roll_in)


func _build_coping() -> void:
	# Partial arcs keep transfer mouths open instead of making false full rings.
	_add_coping_arc("WestBowlCoping", Vector2(-12.0, 9.7), Vector2(8.45, 8.75), 70.0, 300.0, 38)
	_add_coping_arc("SnakeCoping", Vector2(-2.2, 8.5), Vector2(5.35, 7.65), 85.0, 270.0, 28)
	_add_coping_arc("CloverCoping", Vector2(11.2, 10.0), Vector2(7.45, 8.75), 205.0, 480.0, 42)


func _add_coping_arc(node_name: String, center: Vector2, radii: Vector2, start_deg: float, end_deg: float, segments: int) -> void:
	var root := Node3D.new()
	root.name = node_name
	add_child(root)
	for index in range(segments):
		var a0 := deg_to_rad(lerpf(start_deg, end_deg, float(index) / float(segments)))
		var a1 := deg_to_rad(lerpf(start_deg, end_deg, float(index + 1) / float(segments)))
		var p0 := Vector3(center.x + cos(a0) * radii.x, 0.07, center.y + sin(a0) * radii.y)
		var p1 := Vector3(center.x + cos(a1) * radii.x, 0.07, center.y + sin(a1) * radii.y)
		var direction := p1 - p0
		var segment = PropKit.add_box(root, Vector3(direction.length(), 0.13, 0.13), (p0 + p1) * 0.5, COLOR_METAL, PackedStringArray(["grindable", "coping"]), Vector3(0.0, atan2(-direction.z, direction.x), 0.0))
		segment.name = "%s_%02d" % [node_name, index]


func _build_perimeter_details() -> void:
	PropKit.add_box(self, Vector3(15.0, 0.32, 0.5), Vector3(-15.7, 0.16, -19.4), COLOR_FEATURE, PackedStringArray(["deck"]))
	PropKit.add_box(self, Vector3(21.0, 0.32, 0.5), Vector3(13.5, 0.16, -19.4), COLOR_FEATURE, PackedStringArray(["deck"]))
	PropKit.add_box(self, Vector3(0.5, 0.34, 22.0), Vector3(-23.4, 0.17, -7.0), COLOR_FEATURE, PackedStringArray(["deck"]))
	PropKit.add_box(self, Vector3(0.5, 0.34, 20.0), Vector3(23.4, 0.17, -6.0), COLOR_FEATURE, PackedStringArray(["deck"]))


func _build_palms() -> void:
	var terrace = PlanterRoundScene.instantiate()
	terrace.name = "PalmTerrace"
	terrace.radius = 4.0
	terrace.curb_height = 0.42
	terrace.palm_count = 5
	terrace.palm_height = 7.0
	terrace.position = Vector3(20.5, 0.0, -7.0)
	add_child(terrace)
	for i in range(3):
		var palm = PlanterRoundScene.instantiate()
		palm.name = "PalmWest_%d" % i
		palm.radius = 1.05
		palm.palm_count = 1
		palm.palm_height = 5.8 + float(i) * 0.4
		palm.position = Vector3(-20.5 + float(i) * 2.1, 0.0, 16.5)
		add_child(palm)


func _build_zones() -> void:
	_add_zone("zone_street", Vector3(0.0, 2.0, -10.0), Vector3(43.0, 6.0, 20.0))
	_add_zone("zone_snake", Vector3(-2.0, -0.4, 9.5), Vector3(20.0, 8.0, 18.0))
	_add_zone("zone_clover", Vector3(12.0, -0.7, 10.5), Vector3(16.0, 9.0, 18.0))
	_add_zone("zone_stairs_b", Vector3(-7.8, 1.5, -12.5), Vector3(7.0, 4.0, 7.0))


func _add_zone(zone_name: String, pos: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.name = zone_name
	area.collision_layer = 0
	area.collision_mask = 2
	area.add_to_group(zone_name)
	area.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	add_child(area)


func _add_mesh_static(node_name: String, mesh: ArrayMesh, material: Material, groups: PackedStringArray) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	for group in groups:
		body.add_to_group(group)
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	var shape := mesh.create_trimesh_shape()
	if shape != null:
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
	add_child(body)
	return body


func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_uv(Vector2(a.x * 0.11, a.z * 0.11))
	st.add_vertex(a)
	st.set_uv(Vector2(b.x * 0.11, b.z * 0.11))
	st.add_vertex(b)
	st.set_uv(Vector2(c.x * 0.11, c.z * 0.11))
	st.add_vertex(c)


func _smooth01(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
