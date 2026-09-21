extends Node3D
## Straight coping segment for bowl lips. Grindable metal edge on concrete lip.

@export var length: float = 2.0
@export var coping_size: float = 0.14
@export var lip_width: float = 0.35
@export var lip_thickness: float = 0.12


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	# Concrete lip deck strip along +X; bowl side faces -Z
	PropKit.add_box(
		self,
		Vector3(length, lip_thickness, lip_width),
		Vector3(0.0, -lip_thickness * 0.5, 0.0),
		PropKit.COLOR_CONCRETE,
		PackedStringArray(["deck", "coping"])
	)
	# Metal coping bar on the inner edge
	PropKit.add_box(
		self,
		Vector3(length, coping_size, coping_size),
		Vector3(0.0, 0.0, -lip_width * 0.5),
		PropKit.COLOR_METAL,
		PackedStringArray(["grindable", "coping"])
	)
