extends Node3D
## Long grind ledge / hubba. Top edge tagged grindable.

@export var length: float = 7.0
@export var depth: float = 0.45
@export var height: float = 0.55
@export var is_hubba: bool = false


func _ready() -> void:
	_rebuild()


func _clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.free()


func _rebuild() -> void:
	_clear_children()
	# Body along +X. Origin at ground center.
	var body_h := height
	if is_hubba:
		body_h = maxf(height, 0.7)
	PropKit.add_box(
		self,
		Vector3(length, body_h, depth),
		Vector3(0.0, body_h * 0.5, 0.0),
		PropKit.COLOR_CONCRETE,
		PackedStringArray(["deck"])
	)
	PropKit.add_box(
		self,
		Vector3(length, 0.22, depth * 0.95),  # fatter grind lip for detect
		Vector3(0.0, body_h + 0.06, 0.0),
		PropKit.COLOR_METAL,
		PackedStringArray(["grindable"])
	)
