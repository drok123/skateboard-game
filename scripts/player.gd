extends CharacterBody3D
## Beta skate feel: push, carve lean, ollie pop, landing stick, grind stick.
## Player Controller feeds wish + jump via apply_movement; Physics owns velocity.

signal sfx_ollie()
signal sfx_land(impact: float)

# --- Tuned for readable beta feel ---
const MAX_SPEED := 13.5
const PUSH_ACCEL := 22.0
const CARVE_ACCEL := 12.0
const FRICTION := 5.5
const BRAKE_FRICTION := 16.0
const TURN_SPEED := 3.1
const TURN_SPEED_FAST := 4.8
const JUMP_VELOCITY := 7.2
const OLLIE_FORWARD_BOOST := 1.8
const AIR_CONTROL := 0.32
const AIR_TURN := 1.9
const GRAVITY := 24.0
const MAX_FALL := -34.0
const LAND_STICK := 0.88
const CARVE_LEAN_MAX := 0.42
const SECONDARY_RECOVER_RATE := 1.8
const GRIND_MIN_SPEED := 3.5
const GRIND_FRICTION := 1.2
const GRIND_SNAP := 18.0
const GRIND_OLLIE_BOOST := 2.2

@onready var mesh: Node3D = $MeshPivot
@onready var board: MeshInstance3D = $MeshPivot/Board
@onready var rider: MeshInstance3D = $MeshPivot/Rider
@onready var _tricks: Node = get_node_or_null("TrickSystem")
@onready var _sfx_ollie: AudioStreamPlayer3D = get_node_or_null("SfxOllie")
@onready var _sfx_land: AudioStreamPlayer3D = get_node_or_null("SfxLand")

var _facing := 0.0
var _was_on_floor := true
var _airborne := false
var _active_air_trick := ""
var _secondary_intensity := 1.0
var _board_lean := 0.0
var _grinding := false
var _grind_axis := Vector3(1.0, 0.0, 0.0)


func _ready() -> void:
	_ensure_sfx_streams()


## Public API for Player Controller: wish is world XZ intent (-1..1), jump_pressed is edge.
func apply_movement(wish: Vector3, jump_pressed: bool, delta: float) -> void:
	wish.y = 0.0
	if wish.length_squared() > 1.0:
		wish = wish.normalized()

	var on_floor := is_on_floor()
	var land_impact := 0.0

	if not on_floor and not _grinding:
		velocity.y = maxf(velocity.y - GRAVITY * delta, MAX_FALL)
		_airborne = true
	elif on_floor and velocity.y < 0.0:
		land_impact = clampf((-velocity.y) / 18.0, 0.15, 1.0)
		velocity.y = 0.0

	if on_floor and not _was_on_floor and not _grinding:
		_on_landed(land_impact)

	if jump_pressed and (on_floor or _grinding):
		_do_ollie(_grinding)

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal.length()
	var control := 1.0 if (on_floor or _grinding) else AIR_CONTROL

	if _grinding:
		horizontal = _grind_move(horizontal, wish, delta)
	elif wish.length_squared() > 0.01:
		var wish_angle := atan2(wish.x, wish.z)
		var facing_delta := absf(wrapf(wish_angle - _facing, -PI, PI))
		var aligned := 1.0 - clampf(facing_delta / (PI * 0.5), 0.0, 1.0)
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

		var turn_dir := wrapf(wish_angle - _facing, -PI, PI)
		# Lean only while carving/accelerating — upright at rest (P0 idle lean).
		var lean_target := 0.0
		var turning := absf(turn_dir) > 0.12
		var moving := speed > 2.0 or wish.length_squared() > 0.25
		if turning and moving:
			lean_target = clampf(-turn_dir * 1.6, -CARVE_LEAN_MAX, CARVE_LEAN_MAX)
			lean_target *= clampf(speed / 5.0, 0.25, 1.0)
			if not on_floor:
				lean_target *= 0.35
		_board_lean = lerpf(_board_lean, lean_target, 14.0 * delta)
	else:
		var fric := FRICTION if speed > 2.0 else BRAKE_FRICTION
		horizontal = horizontal.move_toward(Vector3.ZERO, fric * control * delta)
		_board_lean = lerpf(_board_lean, 0.0, 16.0 * delta)
		if absf(_board_lean) < 0.02:
			_board_lean = 0.0

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	_update_board_visuals(delta, on_floor or _grinding)
	_recover_secondary(delta)

	move_and_slide()
	_update_grind_state()
	_was_on_floor = is_on_floor()


func set_secondary_intensity(amount: float) -> void:
	_secondary_intensity = clampf(amount, 0.0, 1.0)


func get_secondary_intensity() -> float:
	return _secondary_intensity


func is_grinding() -> bool:
	return _grinding


## Tricks upgrades the in-air name (kickflip/heelflip/180/shuv/tre) after ollie pop.
func set_air_trick(trick_name: String) -> void:
	if trick_name == "":
		return
	_active_air_trick = trick_name


func _grind_move(horizontal: Vector3, wish: Vector3, delta: float) -> Vector3:
	# Slide along rail axis; wish only nudges balance, not off-rail strafe.
	var along := _grind_axis
	if horizontal.dot(along) < 0.0:
		along = -along
	var speed := maxf(horizontal.length(), GRIND_MIN_SPEED)
	speed = maxf(speed - GRIND_FRICTION * delta, GRIND_MIN_SPEED * 0.85)
	if wish.length_squared() > 0.01:
		var wish_along := wish.dot(along)
		speed = minf(speed + wish_along * 4.0 * delta, MAX_SPEED * 1.05)
		_facing = lerp_angle(_facing, atan2(along.x, along.z), 6.0 * delta)
		if mesh:
			mesh.rotation.y = _facing
	_board_lean = lerpf(_board_lean, 0.0, 6.0 * delta)
	velocity.y = move_toward(velocity.y, 0.0, GRIND_SNAP * delta)
	return along * speed


func _update_grind_state() -> void:
	var hit := _find_grind_collision()
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if hit.has("axis") and speed >= GRIND_MIN_SPEED * 0.65 and (not is_on_floor() or _grinding or velocity.y <= 0.5):
		_grind_axis = hit["axis"]
		if not _grinding:
			_grinding = true
			_airborne = false
			# Snap onto rail height lightly.
			if hit.has("point"):
				var pt: Vector3 = hit["point"]
				global_position.y = lerpf(global_position.y, pt.y + 0.55, 0.45)
		return
	if _grinding:
		_grinding = false


func _find_grind_collision() -> Dictionary:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null or not (collider is Node):
			continue
		if not (collider as Node).is_in_group("grindable"):
			continue
		var n := col.get_normal()
		# Rail axis ≈ along the edge: horizontal, perpendicular to outward normal.
		var axis := Vector3.UP.cross(n)
		if axis.length_squared() < 0.01:
			axis = Vector3(velocity.x, 0.0, velocity.z)
		axis.y = 0.0
		if axis.length_squared() < 0.01:
			axis = Vector3(sin(_facing), 0.0, cos(_facing))
		axis = axis.normalized()
		return {"axis": axis, "point": col.get_position(), "normal": n}
	return {}


func _do_ollie(from_grind: bool = false) -> void:
	velocity.y = JUMP_VELOCITY + (0.8 if from_grind else 0.0)
	var forward := Vector3(sin(_facing), 0.0, cos(_facing))
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var boost := GRIND_OLLIE_BOOST if from_grind else OLLIE_FORWARD_BOOST
	horizontal += forward * boost
	if from_grind:
		horizontal += _grind_axis * 1.2 * signf(horizontal.dot(_grind_axis) + 0.001)
	if horizontal.length() > MAX_SPEED * 1.1:
		horizontal = horizontal.limit_length(MAX_SPEED * 1.1)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_grinding = false
	_airborne = true
	_active_air_trick = "ollie"
	_ollie_squash()
	set_secondary_intensity(0.55)
	_play_sfx_ollie()
	if _tricks and _tricks.has_method("notify_trick_started"):
		_tricks.notify_trick_started("ollie")


func _on_landed(impact: float = 0.35) -> void:
	velocity.x *= LAND_STICK
	velocity.z *= LAND_STICK
	velocity.y = 0.0
	_board_lean *= 0.3
	_land_squash()
	set_secondary_intensity(0.0)
	_play_sfx_land(impact)
	if _airborne and _active_air_trick != "":
		# Empty name → TrickSystem keeps air-key upgrades (kickflip etc.).
		if _tricks and _tricks.has_method("notify_trick_landed"):
			_tricks.notify_trick_landed("")
		_active_air_trick = ""
	_airborne = false


func _update_board_visuals(delta: float, on_surface: bool) -> void:
	if board == null:
		return
	var pitch := 0.0
	if not on_surface:
		pitch = clampf(-velocity.y * 0.028, -0.4, 0.22)
	elif _grinding:
		pitch = -0.06
	board.rotation.x = lerpf(board.rotation.x, pitch, 12.0 * delta)
	board.rotation.z = lerpf(board.rotation.z, _board_lean, 12.0 * delta)
	if rider:
		rider.rotation.x = board.rotation.x * 0.45
		rider.rotation.z = board.rotation.z * 0.7
	if mesh:
		# Never pitch MeshPivot (idle ~45° back lean bug). Roll only while carving.
		mesh.rotation.x = 0.0
		var body_roll := _board_lean * 0.45 if absf(_board_lean) > 0.03 else 0.0
		mesh.rotation.z = lerpf(mesh.rotation.z, body_roll, 14.0 * delta)
		if absf(mesh.rotation.z) < 0.01 and body_roll == 0.0:
			mesh.rotation.z = 0.0


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


func _play_sfx_ollie() -> void:
	sfx_ollie.emit()
	if _sfx_ollie:
		_sfx_ollie.play()


func _play_sfx_land(impact: float) -> void:
	sfx_land.emit(impact)
	if _sfx_land:
		_sfx_land.volume_db = lerpf(-8.0, 0.0, clampf(impact, 0.0, 1.0))
		_sfx_land.play()
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam and cam.has_method("apply_punch"):
		cam.apply_punch(impact)

func _ensure_sfx_streams() -> void:
	if _sfx_ollie and _sfx_ollie.stream == null:
		_sfx_ollie.stream = _load_wav_stream("res://assets/audio/sfx/ollie_pop.wav")
	if _sfx_land and _sfx_land.stream == null:
		_sfx_land.stream = _load_wav_stream("res://assets/audio/sfx/land_thud.wav")


func _load_wav_stream(path: String) -> AudioStreamWAV:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("SFX missing: %s" % path)
		return null
	f.get_buffer(4)  # RIFF
	f.get_32()
	f.get_buffer(4)  # WAVE
	var sample_rate := 22050
	var bits := 16
	var channels := 1
	var pcm := PackedByteArray()
	while f.get_position() + 8 <= f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var sz := f.get_32()
		var chunk_end := f.get_position() + sz
		if id == "fmt ":
			f.get_16()
			channels = f.get_16()
			sample_rate = f.get_32()
			f.get_32()
			f.get_16()
			bits = f.get_16()
		elif id == "data":
			pcm = f.get_buffer(sz)
		f.seek(mini(chunk_end, f.get_length()))
		if chunk_end % 2 == 1 and f.get_position() < f.get_length():
			f.get_8()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels > 1
	stream.data = pcm
	return stream

