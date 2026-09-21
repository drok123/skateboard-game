extends Camera3D
## skate. FIRST (P0 Turning & camera): behind-board follow via Physics get_cam_yaw(),
## look-ahead + light shoulder bias into carves. Cite p14MSdRtNIo / -Mi9EKoBCSg — no asset copy.
## FOV land punch stays Session Pass — do not soften. Never writes MeshPivot yaw.

@export var target_path: NodePath
@export var height := 3.35
@export var distance := 7.0
@export var look_height := 1.2
@export var look_ahead := 2.6
@export var look_ahead_turn := 1.8
@export var shoulder_bias := 0.55
@export var follow_speed := 9.5
@export var yaw_follow_speed := 9.0
@export var look_speed := 11.0

var _target: Node3D
var _look_target: Node3D
var _body: CharacterBody3D
var _yaw := 0.0
var _prev_yaw := 0.0
var _yaw_rate := 0.0
var _base_fov := 75.0
var _punch_offset := Vector3.ZERO
var _punch_fov_add := 0.0
var _punch_tween: Tween


func _ready() -> void:
	add_to_group("follow_camera")
	_base_fov = fov
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		_target = get_tree().get_first_node_in_group("player") as Node3D
	if _target:
		_body = _target as CharacterBody3D
		var look := _target.get_node_or_null("MeshPivot/LookTarget") as Node3D
		if look:
			_look_target = look
		_yaw = _desired_yaw()
		_prev_yaw = _yaw
		global_position = _desired_position(_yaw)
		look_at(_look_position(_yaw), Vector3.UP)


## Session land punch — unmistakable FOV kick (PASS bar). Do not soften.
func apply_punch(strength: float, duration: float = 0.28) -> void:
	strength = clampf(strength, 0.0, 1.6)
	if strength < 0.05:
		return
	_start_punch(
		Vector3(0.0, -0.55 * strength, 0.12 * strength),
		14.0 * strength,
		duration,
		Tween.TRANS_CUBIC,
	)


## skate. trailer juice — playful, honest, not carnival. Land uses apply_punch (PASS).
func apply_juice_punch(kind: StringName, strength: float = 1.0) -> void:
	strength = clampf(strength, 0.0, 1.2)
	match kind:
		&"land":
			apply_punch(clampf(strength, 0.5, 1.5), 0.32)
		&"ollie":
			# Pop lift + short FOV blossom (skate. trailer).
			_start_punch(
				Vector3(0.0, 0.1 * strength, -0.05 * strength),
				7.0 * strength,
				0.11,
				Tween.TRANS_QUAD,
			)
		&"grind":
			# Lock-in tuck with toast — light dip, no particle carnival.
			_start_punch(
				Vector3(0.0, -0.1 * strength, 0.04 * strength),
				5.0 * strength,
				0.1,
				Tween.TRANS_QUAD,
			)
		_:
			apply_punch(strength, 0.2)


func _start_punch(offset: Vector3, fov_add: float, duration: float, trans: int) -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	_punch_offset = offset
	_punch_fov_add = fov_add
	_punch_tween = create_tween()
	_punch_tween.set_parallel(true)
	_punch_tween.tween_property(self, "_punch_offset", Vector3.ZERO, duration).set_trans(trans).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "_punch_fov_add", 0.0, duration).set_trans(trans).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var desired_yaw := _desired_yaw()
	_yaw = lerp_angle(_yaw, desired_yaw, 1.0 - exp(-yaw_follow_speed * delta))
	var dyaw := wrapf(_yaw - _prev_yaw, -PI, PI)
	_yaw_rate = lerpf(_yaw_rate, dyaw / maxf(delta, 0.0001), 0.35)
	_prev_yaw = _yaw

	var desired := _desired_position(_yaw) + _punch_offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))

	var look_at_pos := _look_position(_yaw)
	var from := global_transform
	var to := global_transform.looking_at(look_at_pos, Vector3.UP)
	global_transform = from.interpolate_with(to, 1.0 - exp(-look_speed * delta))
	fov = _base_fov + _punch_fov_add


func _desired_yaw() -> float:
	if _body and _body.has_method("get_cam_yaw"):
		return float(_body.call("get_cam_yaw"))
	if _body and _body.has_method("get_facing_yaw"):
		return float(_body.call("get_facing_yaw"))
	var mesh := _target.get_node_or_null("MeshPivot") as Node3D
	if mesh:
		return mesh.rotation.y
	return _yaw


func _forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


func _right(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func _desired_position(yaw: float) -> Vector3:
	var forward := _forward(yaw)
	var right := _right(yaw)
	# Shoulder into the carve so turns feel playful (skate. plaza energy), not stuck orbit.
	var shoulder := clampf(_yaw_rate * 0.12, -1.0, 1.0) * shoulder_bias
	return _target.global_position - forward * distance + right * shoulder + Vector3.UP * height


func _look_position(yaw: float) -> Vector3:
	var forward := _forward(yaw)
	var right := _right(yaw)
	var base: Vector3
	if _look_target:
		base = _look_target.global_position
	else:
		base = _target.global_position + Vector3.UP * look_height
	var ahead := look_ahead + clampf(absf(_yaw_rate) * 0.08, 0.0, 1.0) * look_ahead_turn
	var into_turn := clampf(_yaw_rate * 0.1, -1.0, 1.0) * 0.65
	return base + forward * ahead + right * into_turn
