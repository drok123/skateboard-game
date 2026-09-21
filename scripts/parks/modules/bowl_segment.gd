extends Node3D
## Arc bowl transition as pitched slabs (outer band only) + optional floor pad.
## Origin at deck center of the arc. include_floor_pad defaults false — parent places one floor.

@export var radius: float = 5.0
@export var depth: float = 2.4
@export var arc_deg: float = 90.0
@export var slices: int = 6
@export var wall_thickness: float = 0.45
## Fraction of radius used for the QP face. Keep <0.5 so slabs don't meet in the center.
@export var face_run_frac: float = 0.38
@export var include_floor_pad: bool = false


func _ready() -> void:
	_rebuild()


func _clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.free()


func _rebuild() -> void:
	_clear_children()
	slices = maxi(slices, 3)
	radius = maxf(radius, 1.5)
	depth = maxf(depth, 0.5)
	face_run_frac = clampf(face_run_frac, 0.2, 0.55)
	var arc := deg_to_rad(arc_deg)
	var start := -arc * 0.5
	var step := arc / float(slices)
	var chord := 2.0 * radius * sin(step * 0.5)
	var face_run := radius * face_run_frac
	var slope_len := sqrt(face_run * face_run + depth * depth)
	var pitch := atan2(depth, face_run)
	for i in range(slices):
		var a := start + step * (float(i) + 0.5)
		var mid_r := radius - face_run * 0.5
		var x := sin(a) * mid_r
		var z := -cos(a) * mid_r
		var y := -depth * 0.5
		# One StaticBody per slice — no duplicate pads.
		PropKit.add_box(
			self,
			Vector3(maxf(chord, 0.55), wall_thickness, slope_len),
			Vector3(x, y, z),
			PropKit.COLOR_CONCRETE_COOL,
			PackedStringArray(["bowl", "deck"]),
			Vector3(pitch, a, 0.0)
		)
	if include_floor_pad:
		var floor_r := radius * (1.0 - face_run_frac) * 0.9
		PropKit.add_cylinder(
			self,
			maxf(floor_r, 1.0),
			0.22,
			Vector3(0.0, -depth + 0.11, 0.0),
			PropKit.COLOR_CONCRETE_COOL,
			PackedStringArray(["bowl", "deck"]),
			16
		)
