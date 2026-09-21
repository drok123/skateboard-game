extends Node3D
## Modular stair set: collision boxes per step. Optional hubba ledge + handrail.

@export var step_count: int = 3
@export var width: float = 3.0
@export var riser: float = 0.18
@export var tread: float = 0.32
@export var with_hubba: bool = true
@export var hubba_width: float = 0.4
@export var with_handrail: bool = false


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	step_count = maxi(step_count, 1)
	var total_run := float(step_count) * tread
	var total_rise := float(step_count) * riser
	# Steps run along +Z, rise +Y, width along X. Origin at bottom front center.
	for i in range(step_count):
		var y := riser * 0.5 + float(i) * riser
		var z := tread * 0.5 + float(i) * tread
		PropKit.add_box(
			self,
			Vector3(width, riser, tread),
			Vector3(0.0, y, z),
			PropKit.COLOR_CONCRETE,
			PackedStringArray(["deck"])
		)
	# Landing slab at top (shallow)
	PropKit.add_box(
		self,
		Vector3(width, 0.12, 0.6),
		Vector3(0.0, total_rise + 0.06, total_run + 0.3),
		PropKit.COLOR_CONCRETE,
		PackedStringArray(["deck"])
	)
	if with_hubba:
		# Parallel grind ledge along +X side, top flush with top step.
		var hubba_h := total_rise
		PropKit.add_box(
			self,
			Vector3(hubba_width, hubba_h, total_run + 0.2),
			Vector3(width * 0.5 + hubba_width * 0.5, hubba_h * 0.5, total_run * 0.5),
			PropKit.COLOR_CONCRETE,
			PackedStringArray(["deck"])
		)
		# Thin grindable top lip
		PropKit.add_box(
			self,
			Vector3(hubba_width * 0.95, 0.12, total_run + 0.2),
			Vector3(width * 0.5 + hubba_width * 0.5, hubba_h + 0.06, total_run * 0.5),
			PropKit.COLOR_METAL,
			PackedStringArray(["grindable"])
		)
	if with_handrail:
		var rail_len := sqrt(total_run * total_run + total_rise * total_rise)
		var pitch := -atan2(total_rise, total_run)
		PropKit.add_box(
			self,
			Vector3(0.12, 0.12, rail_len),
			Vector3(-width * 0.5 - 0.15, total_rise * 0.5 + 0.7, total_run * 0.5),
			PropKit.COLOR_METAL,
			PackedStringArray(["grindable"]),
			Vector3(pitch, 0.0, 0.0)
		)
