extends Camera3D
## Smooth third-person follow camera for the skateboarder.

@export var target_path: NodePath
@export var offset := Vector3(0.0, 4.5, 8.0)
@export var look_offset := Vector3(0.0, 1.2, 0.0)
@export var follow_speed := 6.0
@export var look_speed := 10.0

var _target: Node3D
var _look_target: Node3D


func _ready() -> void:
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		_target = get_tree().get_first_node_in_group("player") as Node3D
	# Prefer chest LookTarget when Player Controller has placed one.
	if _target:
		var look := _target.get_node_or_null("MeshPivot/LookTarget") as Node3D
		if look:
			_look_target = look



func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var desired := _target.global_position + offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
	var look_at_pos := (_look_target.global_position if _look_target else _target.global_position + look_offset)
	var from := global_transform
	var to := global_transform.looking_at(look_at_pos, Vector3.UP)
	global_transform = from.interpolate_with(to, 1.0 - exp(-look_speed * delta))
