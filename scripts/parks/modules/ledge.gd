extends Node3D
## Long grind ledge / hubba. Top edge tagged grindable.

@export var length: float = 7.0
@export var depth: float = 0.45
@export var height: float = 0.55
@export var is_hubba: bool = false


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
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
		Vector3(length, 0.12, depth * 0.9),
		Vector3(0.0, body_h + 0.06, 0.0),
		PropKit.COLOR_METAL,
		PackedStringArray(["grindable"])
	)
