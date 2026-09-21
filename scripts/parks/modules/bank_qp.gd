extends Node3D
## Small bank / quarter-pipe face (rotated box wedge approximation).

@export var width: float = 4.0
@export var height: float = 1.2
@export var angle_deg: float = 30.0
@export var thickness: float = 0.35


func _ready() -> void:
	_rebuild()


func _clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.free()


func _rebuild() -> void:
	_clear_children()
	var pitch := deg_to_rad(-angle_deg)
	# Run length along slope projected on ground.
	var run := height / maxf(tan(deg_to_rad(angle_deg)), 0.01)
	var slab_len := sqrt(run * run + height * height)
	PropKit.add_box(
		self,
		Vector3(width, thickness, slab_len),
		Vector3(0.0, height * 0.5, run * 0.5),
		PropKit.COLOR_CONCRETE,
		PackedStringArray(["deck"]),
		Vector3(pitch, 0.0, 0.0)
	)
	# Flat deck pad at top lip
	PropKit.add_box(
		self,
		Vector3(width, 0.15, 0.5),
		Vector3(0.0, height + 0.075, run + 0.1),
		PropKit.COLOR_CONCRETE,
		PackedStringArray(["deck"])
	)
