extends Camera3D
## skate. bar (P0 Turning & camera): behind-board follow, yaw with facing/velocity,
## gentle look-ahead into turns. Cite p14MSdRtNIo / -Mi9EKoBCSg — no asset copy.
## FOV land punch stays Session-weight Pass — do not soften.

@export var target_path: NodePath
@export var height := 3.35
@export var distance := 7.0
@export var look_height := 1.2
@export var look_ahead := 2.8
@export var follow_speed := 9.0
@export var yaw_follow_speed := 8.0
@export var look_speed := 10.0
## 0 = face MeshPivot only; 1 = velocity yaw only.
@export var velocity_yaw_blend := 0.5
@export var min_speed_for_vel_yaw := 1.25

var _target: Node3D
var _look_target: Node3D
var _body: CharacterBody3D
var _mesh: Node3D
var _yaw := 0.0
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
		_mesh = _target.get_node_or_null("MeshPivot") as Node3D
		var look := _target.get_node_or_null("MeshPivot/LookTarget") as Node3D
		if look:
			_look_target = look
		_yaw = _facing_yaw()
		# Snap behind board on first frame so we never start world-locked on +Z.
		global_position = _desired_position(_yaw)
		look_at(_look_position(_yaw), Vector3.UP)


## Session land punch — unmistakable FOV kick (PASS bar). Do not soften for skate. cam.
func apply_punch(strength: float, duration: float = 0.28) -> void:
	strength = clampf(strength, 0.0, 1.6)
	if strength < 0.05:
		return
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	_punch_offset = Vector3(0.0, -0.55 * strength, 0.12 * strength)
	_punch_fov_add = 14.0 * strength
	_punch_tween = create_tween()
	_punch_tween.set_parallel(true)
	_punch_tween.tween_property(self, "_punch_offset", Vector3.ZERO, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "_punch_fov_add", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var desired_yaw := _blend_yaw()
	_yaw = lerp_angle(_yaw, desired_yaw, 1.0 - exp(-yaw_follow_speed * delta))

	var desired := _desired_position(_yaw) + _punch_offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))

	var look_at_pos := _look_position(_yaw)
	var from := global_transform
	var to := global_transform.looking_at(look_at_pos, Vector3.UP)
	global_transform = from.interpolate_with(to, 1.0 - exp(-look_speed * delta))
	fov = _base_fov + _punch_fov_add


func _facing_yaw() -> float:
	if _mesh:
		return _mesh.rotation.y
	if _target:
		return _target.rotation.y
	return _yaw


func _blend_yaw() -> float:
	var face := _facing_yaw()
	if _body == null:
		return face
	var horiz := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	var speed := horiz.length()
	if speed < min_speed_for_vel_yaw:
		return face
	var vel_yaw := atan2(horiz.x, horiz.z)
	# Prefer facing when nearly aligned; blend toward velocity when carving off-axis.
	var misalign := absf(wrapf(vel_yaw - face, -PI, PI))
	var blend := velocity_yaw_blend * clampf(misalign / 0.85, 0.35, 1.0)
	blend *= clampf(speed / 6.0, 0.4, 1.0)
	return lerp_angle(face, vel_yaw, blend)


func _forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


func _desired_position(yaw: float) -> Vector3:
	var forward := _forward(yaw)
	return _target.global_position - forward * distance + Vector3.UP * height


func _look_position(yaw: float) -> Vector3:
	var forward := _forward(yaw)
	var base: Vector3
	if _look_target:
		base = _look_target.global_position
	else:
		base = _target.global_position + Vector3.UP * look_height
	# Gentle look-ahead into the carve (skate. plaza cam energy).
	return base + forward * look_ahead
