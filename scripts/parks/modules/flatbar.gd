extends Node3D
## Low flatbar rail for street plaza grinds.

@export var length: float = 5.0
@export var bar_size: float = 0.12
@export var height: float = 0.45
@export var with_legs: bool = true


func _ready() -> void:
	_rebuild()


func _clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.free()


func _rebuild() -> void:
	_clear_children()
	# Bar along +X, grindable.
	PropKit.add_box(
		self,
		Vector3(length, maxf(bar_size, 0.16), maxf(bar_size, 0.16)),
		Vector3(0.0, height, 0.0),
		PropKit.COLOR_METAL,
		PackedStringArray(["grindable"])
	)
	if with_legs:
		var leg_h := height - bar_size * 0.5
		var inset := length * 0.35
		for x in [-inset, inset]:
			PropKit.add_box(
				self,
				Vector3(0.08, leg_h, 0.08),
				Vector3(x, leg_h * 0.5, 0.0),
				PropKit.COLOR_METAL
			)
