extends CharacterBody3D
## Controllable skateboarder: WASD/arrows move, Space ollies.

const SPEED := 10.0
const ACCEL := 14.0
const FRICTION := 8.0
const TURN_SPEED := 3.5
const JUMP_VELOCITY := 7.5
const AIR_CONTROL := 0.35
const GRAVITY := 18.0
const MAX_FALL := -30.0

@onready var mesh: Node3D = $MeshPivot
@onready var board: MeshInstance3D = $MeshPivot/Board
@onready var rider: MeshInstance3D = $MeshPivot/Rider

var _facing := 0.0


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, MAX_FALL)
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	# Ollie / jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_ollie_squash()

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Vector3(input_dir.x, 0.0, input_dir.y)
	if wish.length_squared() > 1.0:
		wish = wish.normalized()

	var control := 1.0 if is_on_floor() else AIR_CONTROL
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	if wish.length_squared() > 0.01:
		var target := wish * SPEED
		horizontal = horizontal.move_toward(target, ACCEL * control * delta)
		_facing = lerp_angle(_facing, atan2(wish.x, wish.z), TURN_SPEED * delta)
		mesh.rotation.y = _facing
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, FRICTION * control * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# Slight board tilt while airborne
	if board:
		var tilt := clampf(-velocity.y * 0.03, -0.35, 0.25) if not is_on_floor() else 0.0
		board.rotation.x = lerpf(board.rotation.x, tilt, 10.0 * delta)
		if rider:
			rider.rotation.x = board.rotation.x * 0.5

	move_and_slide()


func _ollie_squash() -> void:
	if mesh == null:
		return
	var tw := create_tween()
	tw.tween_property(mesh, "scale", Vector3(1.15, 0.75, 1.15), 0.06)
	tw.tween_property(mesh, "scale", Vector3.ONE, 0.12)
