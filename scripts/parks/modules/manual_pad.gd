extends Node3D
## Low flat manual pad for street plaza density. Optional grindable metal lip.

@export var length: float = 3.5
@export var width: float = 2.2
@export var height: float = 0.28
@export var with_grind_lip: bool = true


func _ready() -> void:
	_rebuild()


func _clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.free()


func _rebuild() -> void:
	_clear_children()
	length = maxf(length, 1.0)
	width = maxf(width, 0.8)
	height = maxf(height, 0.12)
	PropKit.add_box(
		self,
		Vector3(length, height, width),
		Vector3(0.0, height * 0.5, 0.0),
		PropKit.COLOR_CONCRETE,
		PackedStringArray(["deck"])
	)
	if with_grind_lip:
		PropKit.add_box(
			self,
			Vector3(length, 0.1, 0.12),
			Vector3(0.0, height + 0.05, width * 0.5),
			PropKit.COLOR_METAL,
			PackedStringArray(["grindable"])
		)
