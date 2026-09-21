extends Node3D
## Circular planter: collision on curb ring only. Soil + palms are visual.

@export var radius: float = 1.5
@export var curb_height: float = 0.35
@export var curb_thickness: float = 0.28
@export var palm_count: int = 1
@export var palm_height: float = 9.0
@export var grindable_curb: bool = true
@export var curb_segments: int = 12


func _ready() -> void:
	_rebuild()


func _clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.free()


func _rebuild() -> void:
	_clear_children()
	curb_segments = maxi(curb_segments, 6)
	radius = maxf(radius, 0.6)
	var groups := PackedStringArray(["deck"])
	if grindable_curb:
		groups.append("grindable")
	# Curb as ring of boxes (hollow — no solid disc blocking the pad).
	var inner := maxf(radius - curb_thickness, 0.2)
	var mid_r := (radius + inner) * 0.5
	var seg_len := TAU * mid_r / float(curb_segments) * 1.02
	for i in range(curb_segments):
		var a := TAU * float(i) / float(curb_segments)
		PropKit.add_box(
			self,
			Vector3(seg_len, curb_height, curb_thickness),
			Vector3(sin(a) * mid_r, curb_height * 0.5, -cos(a) * mid_r),
			PropKit.COLOR_CONCRETE,
			groups,
			Vector3(0.0, a, 0.0)
		)
	# Soil disc — visual only (no StaticBody)
	var soil := MeshInstance3D.new()
	var soil_mesh := CylinderMesh.new()
	soil_mesh.top_radius = inner * 0.98
	soil_mesh.bottom_radius = inner * 0.98
	soil_mesh.height = 0.06
	soil_mesh.radial_segments = 16
	soil.mesh = soil_mesh
	soil.position = Vector3(0.0, curb_height - 0.04, 0.0)
	soil.rotation = Vector3.ZERO
	soil.material_override = PropKit.mat_for(PropKit.COLOR_SOIL)
	add_child(soil)
	# Palms — visual only, always world-upright (no pitch/roll)
	palm_count = maxi(palm_count, 0)
	for i in range(palm_count):
		var ang := TAU * float(i) / float(maxi(palm_count, 1))
		var pr := radius * 0.28 if palm_count > 1 else 0.0
		var px := cos(ang) * pr
		var pz := sin(ang) * pr
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.16
		trunk_mesh.bottom_radius = 0.2
		trunk_mesh.height = palm_height
		trunk_mesh.radial_segments = 8
		trunk.mesh = trunk_mesh
		trunk.position = Vector3(px, curb_height + palm_height * 0.5, pz)
		trunk.rotation = Vector3.ZERO
		trunk.material_override = PropKit.mat_for(PropKit.COLOR_PALM)
		add_child(trunk)
		var frond := MeshInstance3D.new()
		var frond_mesh := CylinderMesh.new()
		frond_mesh.top_radius = 0.05
		frond_mesh.bottom_radius = 1.1
		frond_mesh.height = 1.6
		frond_mesh.radial_segments = 6
		frond.mesh = frond_mesh
		# Crown sits on trunk top, upright (inverted cone)
		frond.position = Vector3(px, curb_height + palm_height + 0.2, pz)
		frond.rotation = Vector3.ZERO
		frond.material_override = PropKit.mat_for(PropKit.COLOR_PALM_FROND)
		add_child(frond)
