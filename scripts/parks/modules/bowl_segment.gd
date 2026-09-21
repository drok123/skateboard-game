extends Node3D
## Arc bowl wall as stacked wedges. Origin at deck center of the arc.

@export var radius: float = 5.0
@export var depth: float = 2.4
@export var arc_deg: float = 90.0
@export var slices: int = 8
@export var wall_thickness: float = 0.4


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	slices = maxi(slices, 3)
	var arc := deg_to_rad(arc_deg)
	var start := -arc * 0.5
	var step := arc / float(slices)
	var chord := 2.0 * radius * sin(step * 0.5)
	# Approximate transition: vertical slabs rotated around Y, sunk to floor.
	for i in range(slices):
		var a := start + step * (float(i) + 0.5)
		var x := sin(a) * radius
		var z := -cos(a) * radius
		PropKit.add_box(
			self,
			Vector3(chord, depth, wall_thickness),
			Vector3(x, -depth * 0.5, z),
			PropKit.COLOR_CONCRETE_COOL,
			PackedStringArray(["bowl", "deck"]),
			Vector3(0.0, a, 0.0)
		)
	# Floor pad under the arc (simple disc sector as boxes)
	var floor_r := radius - wall_thickness
	PropKit.add_cylinder(
		self,
		maxf(floor_r * 0.55, 1.0),
		0.2,
		Vector3(0.0, -depth + 0.1, 0.0),
		PropKit.COLOR_CONCRETE_COOL,
		PackedStringArray(["bowl", "deck"]),
		16
	)
