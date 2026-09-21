class_name PropKit
extends RefCounted
## Shared helpers for collision-friendly skate park primitives.
## Palette from docs/style-bible.md (lightweight, not a beauty pass).


## Pale Venice deck concrete (#C8C4BC).
const COLOR_CONCRETE := Color(0.784, 0.769, 0.737)
## Cooler bowl / underside read (#8E959A).
const COLOR_CONCRETE_COOL := Color(0.557, 0.584, 0.604)
## Coping / rails / fence metal (#A8ADB2).
const COLOR_METAL := Color(0.659, 0.678, 0.698)
## Beach apron sand (#D9C7A0).
const COLOR_SAND := Color(0.851, 0.780, 0.627)
const COLOR_SOIL := Color(0.28, 0.2, 0.12)
## Palm trunk (warm brown).
const COLOR_PALM := Color(0.42, 0.32, 0.18)
## Palm frond accent (#3F6B45) — use sparingly.
const COLOR_PALM_FROND := Color(0.247, 0.420, 0.271)


static func mat(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func mat_for(color: Color) -> StandardMaterial3D:
	## Pick rough/metal defaults from palette role.
	if color.is_equal_approx(COLOR_METAL):
		return mat_metal_visual()
	if color.is_equal_approx(COLOR_SAND):
		return mat(color, 0.92, 0.0)
	if color.is_equal_approx(COLOR_PALM_FROND):
		return mat(color, 0.88, 0.0)
	return mat(color, 0.85, 0.0)


static func mat_metal_visual() -> StandardMaterial3D:
	## Non-grindable rails / legs: same #A8ADB2, duller (feel/debug tell).
	return mat(COLOR_METAL, 0.62, 0.32)


static func mat_grind_metal() -> StandardMaterial3D:
	## Grindable lips (coping / flatbar / hubba): same #A8ADB2, shinier.
	return mat(COLOR_METAL, 0.28, 0.78)


static func _has_grindable(groups: PackedStringArray) -> bool:
	for g in groups:
		if g == "grindable":
			return true
	return false


static func _material_for_body(color: Color, groups: PackedStringArray) -> StandardMaterial3D:
	if _has_grindable(groups) and color.is_equal_approx(COLOR_METAL):
		return mat_grind_metal()
	return mat_for(color)


static func add_box(
	parent: Node3D,
	size: Vector3,
	pos: Vector3,
	color: Color,
	groups: PackedStringArray = PackedStringArray(),
	rot: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	for g in groups:
		body.add_to_group(g)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh_i := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_i.mesh = box
	mesh_i.material_override = _material_for_body(color, groups)
	body.add_child(mesh_i)
	parent.add_child(body)
	return body


static func add_cylinder(
	parent: Node3D,
	radius: float,
	height: float,
	pos: Vector3,
	color: Color,
	groups: PackedStringArray = PackedStringArray(),
	radial_segments: int = 16
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	for g in groups:
		body.add_to_group(g)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)
	var mesh_i := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = radial_segments
	mesh_i.mesh = cyl
	mesh_i.material_override = _material_for_body(color, groups)
	body.add_child(mesh_i)
	parent.add_child(body)
	return body
