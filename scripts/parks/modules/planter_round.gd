extends Node3D
## Circular planter curb + optional palm trunk. Collision on curb only.

@export var radius: float = 1.5
@export var curb_height: float = 0.35
@export var curb_thickness: float = 0.25
@export var palm_count: int = 1
@export var palm_height: float = 9.0
@export var grindable_curb: bool = true


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	# Outer curb ring approximated as cylinder shell (solid for v1 collision)
	var groups := PackedStringArray(["deck"])
	if grindable_curb:
		groups.append("grindable")
	PropKit.add_cylinder(
		self,
		radius,
		curb_height,
		Vector3(0.0, curb_height * 0.5, 0.0),
		PropKit.COLOR_CONCRETE,
		groups,
		20
	)
	# Soil disc slightly inset / lower
	PropKit.add_cylinder(
		self,
		maxf(radius - curb_thickness, 0.4),
		0.08,
		Vector3(0.0, curb_height - 0.02, 0.0),
		PropKit.COLOR_SOIL,
		PackedStringArray(),
		16
	)
	# Visual-only palms (tiny collision to avoid snagging board)
	palm_count = maxi(palm_count, 0)
	for i in range(palm_count):
		var ang := TAU * float(i) / float(maxi(palm_count, 1))
		var pr := radius * 0.35 if palm_count > 1 else 0.0
		var px := cos(ang) * pr
		var pz := sin(ang) * pr
		PropKit.add_cylinder(
			self,
			0.18,
			palm_height,
			Vector3(px, curb_height + palm_height * 0.5, pz),
			PropKit.COLOR_PALM,
			PackedStringArray(),
			8
		)
		# Lightweight frond mass (accent green from style bible)
		PropKit.add_cylinder(
			self,
			1.1,
			0.55,
			Vector3(px, curb_height + palm_height + 0.15, pz),
			PropKit.COLOR_PALM_FROND,
			PackedStringArray(),
			10
		)
