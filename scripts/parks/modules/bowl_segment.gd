extends Node3D
## Arc bowl transition as pitched slabs (not vertical walls) + floor pad.
## Origin at deck center of the arc; bowl opens toward local -Z from each slice.

@export var radius: float = 5.0
@export var depth: float = 2.4
@export var arc_deg: float = 90.0
@export var slices: int = 8
@export var wall_thickness: float = 0.45


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	slices = maxi(slices, 3)
	radius = maxf(radius, 1.5)
	depth = maxf(depth, 0.5)
	var arc := deg_to_rad(arc_deg)
	var start := -arc * 0.5
	var step := arc / float(slices)
	var chord := 2.0 * radius * sin(step * 0.5)
	# Transition run: most of the radius so the face meets near the floor center.
	var face_run := radius * 0.82
	var slope_len := sqrt(face_run * face_run + depth * depth)
	var pitch := atan2(depth, face_run)  # rotate around local X after yaw
	for i in range(slices):
		var a := start + step * (float(i) + 0.5)
		# Midpoint of the sloping face in polar coords (halfway down the run).
		var mid_r := radius - face_run * 0.5
		var x := sin(a) * mid_r
		var z := -cos(a) * mid_r
		var y := -depth * 0.5
		PropKit.add_box(
			self,
			Vector3(maxf(chord, 0.6), wall_thickness, slope_len),
			Vector3(x, y, z),
			PropKit.COLOR_CONCRETE_COOL,
			PackedStringArray(["bowl", "deck"]),
			Vector3(pitch, a, 0.0)
		)
	# Floor pad under the arc
	var floor_r := radius * 0.45
	PropKit.add_cylinder(
		self,
		maxf(floor_r, 1.0),
		0.22,
		Vector3(0.0, -depth + 0.11, 0.0),
		PropKit.COLOR_CONCRETE_COOL,
		PackedStringArray(["bowl", "deck"]),
		16
	)
