extends Camera3D
## Smooth third-person follow camera for the skateboarder.

@export var target_path: NodePath
@export var offset := Vector3(0.0, 4.5, 8.0)
@export var look_offset := Vector3(0.0, 1.2, 0.0)
@export var follow_speed := 6.0
@export var look_speed := 10.0

var _target: Node3D
var _look_target: Node3D
var _base_fov := 75.0
var _punch_offset := Vector3.ZERO
var _punch_fov_add := 0.0


func _ready() -> void:
	add_to_group("follow_camera")
	_base_fov = fov
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		_target = get_tree().get_first_node_in_group("player") as Node3D
	# Prefer chest LookTarget when Player Controller has placed one.
	if _target:
		var look := _target.get_node_or_null("MeshPivot/LookTarget") as Node3D
		if look:
			_look_target = look


## Land / impact punch — FOV kick + camera dip (must read at default follow cam).
func apply_punch(strength: float, duration: float = 0.22) -> void:
	strength = clampf(strength, 0.0, 1.5)
	if strength < 0.05:
		return
	_punch_offset = Vector3(0.0, -0.55 * strength, 0.12 * strength)
	_punch_fov_add = 14.0 * strength
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "_punch_offset", Vector3.ZERO, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_punch_fov_add", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var desired := _target.global_position + offset + _punch_offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
	var look_at_pos := (_look_target.global_position if _look_target else _target.global_position + look_offset)
	var from := global_transform
	var to := global_transform.looking_at(look_at_pos, Vector3.UP)
	global_transform = from.interpolate_with(to, 1.0 - exp(-look_speed * delta))
	fov = _base_fov + _punch_fov_add
