extends Node3D
## Perimeter wall segment with non-grindable visual rail on top.

@export var length: float = 4.0
@export var wall_height: float = 1.1
@export var wall_thickness: float = 0.25
@export var rail_height: float = 0.2
@export var rail_grindable: bool = false


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	PropKit.add_box(
		self,
		Vector3(length, wall_height, wall_thickness),
		Vector3(0.0, wall_height * 0.5, 0.0),
		PropKit.COLOR_CONCRETE,
		PackedStringArray(["deck"])
	)
	var rail_groups := PackedStringArray()
	if rail_grindable:
		rail_groups.append("grindable")
	PropKit.add_box(
		self,
		Vector3(length, rail_height, 0.08),
		Vector3(0.0, wall_height + rail_height * 0.5, 0.0),
		PropKit.COLOR_METAL,
		rail_groups
	)
