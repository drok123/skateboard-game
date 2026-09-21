extends CharacterBody3D
## Skate feel: push, carve lean, ollie pop, landing stick.
## Player Controller feeds wish + jump via apply_movement; Physics owns velocity.

const MAX_SPEED := 12.5
const PUSH_ACCEL := 18.0
const CARVE_ACCEL := 10.0
const FRICTION := 6.5
const BRAKE_FRICTION := 14.0
const TURN_SPEED := 2.8
const TURN_SPEED_FAST := 4.2
const JUMP_VELOCITY := 6.8
const OLLIE_FORWARD_BOOST := 1.4
const AIR_CONTROL := 0.28
const AIR_TURN := 1.6
const GRAVITY := 22.0
const MAX_FALL := -32.0
const LAND_STICK := 0.82
const CARVE_LEAN_MAX := 0.38
const SECONDARY_RECOVER_RATE := 1.8

@onready var mesh: Node3D = $MeshPivot
@onready var board: MeshInstance3D = $MeshPivot/Board
@onready var rider: MeshInstance3D = $MeshPivot/Rider
@onready var _tricks: Node = get_node_or_null("TrickSystem")

var _facing := 0.0
var _was_on_floor := true
var _airborne := false
var _active_air_trick := ""
var _secondary_intensity := 1.0
var _board_lean := 0.0


# Input → apply_movement lives on PlayerInput (Player Controller).


## Public API for Player Controller: wish is world XZ intent (-1..1), jump_pressed is edge.
func apply_movement(wish: Vector3, jump_pressed: bool, delta: float) -> void:
	wish.y = 0.0
	if wish.length_squared() > 1.0:
		wish = wish.normalized()

	var on_floor := is_on_floor()

	# Gravity
	if not on_floor:
		velocity.y = maxf(velocity.y - GRAVITY * delta, MAX_FALL)
		_airborne = true
	elif velocity.y < 0.0:
		velocity.y = 0.0

	# Landing stick: floor after air
	if on_floor and not _was_on_floor:
		_on_landed()

	# Ollie pop
	if jump_pressed and on_floor:
		_do_ollie()

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal.length()
	var control := 1.0 if on_floor else AIR_CONTROL

	if wish.length_squared() > 0.01:
		var wish_angle := atan2(wish.x, wish.z)
		var facing_delta := absf(wrapf(wish_angle - _facing, -PI, PI))
		var aligned := 1.0 - clampf(facing_delta / (PI * 0.5), 0.0, 1.0)
		# Push hard when aimed forward; carve when steering across velocity.
		var accel := lerpf(CARVE_ACCEL, PUSH_ACCEL, aligned)
		var target := wish * MAX_SPEED
		horizontal = horizontal.move_toward(target, accel * control * delta)

		var turn := TURN_SPEED
		if on_floor:
			turn = lerpf(TURN_SPEED, TURN_SPEED_FAST, clampf(speed / MAX_SPEED, 0.0, 1.0))
		else:
			turn = AIR_TURN
		_facing = lerp_angle(_facing, wish_angle, turn * delta)
		if mesh:
			mesh.rotation.y = _facing

		# Carve lean into the turn (board roll)
		var turn_dir := wrapf(wish_angle - _facing, -PI, PI)
		var lean_target := clampf(-turn_dir * 1.8, -CARVE_LEAN_MAX, CARVE_LEAN_MAX)
		if not on_floor:
			lean_target *= 0.35
		_board_lean = lerpf(_board_lean, lean_target, 10.0 * delta)
	else:
		var fric := FRICTION if speed > 2.0 else BRAKE_FRICTION
		horizontal = horizontal.move_toward(Vector3.ZERO, fric * control * delta)
		_board_lean = lerpf(_board_lean, 0.0, 8.0 * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	_update_board_visuals(delta, on_floor)
	_recover_secondary(delta)

	move_and_slide()
	_was_on_floor = is_on_floor()


## Soft-motion gate for spring bones (1 = full, 0 = locked for catch/land).
func set_secondary_intensity(amount: float) -> void:
	_secondary_intensity = clampf(amount, 0.0, 1.0)


func get_secondary_intensity() -> float:
	return _secondary_intensity


func _do_ollie() -> void:
	velocity.y = JUMP_VELOCITY
	# Keep forward pop so ollies feel like a skate, not a hop.
	var forward := Vector3(sin(_facing), 0.0, cos(_facing))
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal += forward * OLLIE_FORWARD_BOOST
	if horizontal.length() > MAX_SPEED * 1.05:
		horizontal = horizontal.limit_length(MAX_SPEED * 1.05)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_airborne = true
	_active_air_trick = "ollie"
	_ollie_squash()
	set_secondary_intensity(0.55)
	if _tricks and _tricks.has_method("notify_trick_started"):
		_tricks.notify_trick_started("ollie")


func _on_landed() -> void:
	# Stick the landing: bleed a little speed, kill bounce.
	velocity.x *= LAND_STICK
	velocity.z *= LAND_STICK
	velocity.y = 0.0
	_board_lean *= 0.3
	_land_squash()
	set_secondary_intensity(0.0)
	if _airborne and _active_air_trick != "":
		if _tricks and _tricks.has_method("notify_trick_landed"):
			_tricks.notify_trick_landed(_active_air_trick)
		_active_air_trick = ""
	_airborne = false


func _update_board_visuals(delta: float, on_floor: bool) -> void:
	if board == null:
		return
	var pitch := 0.0
	if not on_floor:
		pitch = clampf(-velocity.y * 0.028, -0.4, 0.22)
	board.rotation.x = lerpf(board.rotation.x, pitch, 12.0 * delta)
	board.rotation.z = lerpf(board.rotation.z, _board_lean, 12.0 * delta)
	if rider:
		rider.rotation.x = board.rotation.x * 0.45
		rider.rotation.z = board.rotation.z * 0.7
	if mesh:
		# Slight body lean with carve without fighting yaw.
		mesh.rotation.z = lerpf(mesh.rotation.z, _board_lean * 0.5, 10.0 * delta)


func _recover_secondary(delta: float) -> void:
	if _secondary_intensity >= 1.0:
		return
	_secondary_intensity = minf(_secondary_intensity + SECONDARY_RECOVER_RATE * delta, 1.0)


func _ollie_squash() -> void:
	if mesh == null:
		return
	var tw := create_tween()
	tw.tween_property(mesh, "scale", Vector3(1.12, 0.78, 1.12), 0.05)
	tw.tween_property(mesh, "scale", Vector3.ONE, 0.14)


func _land_squash() -> void:
	if mesh == null:
		return
	var tw := create_tween()
	tw.tween_property(mesh, "scale", Vector3(1.18, 0.72, 1.18), 0.05)
	tw.tween_property(mesh, "scale", Vector3.ONE, 0.16)
