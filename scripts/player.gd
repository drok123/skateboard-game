extends CharacterBody3D
## Beta skate feel: push, carve lean, ollie pop, landing stick, grind stick.
## Player Controller feeds wish + jump via apply_movement; Physics owns velocity.

signal sfx_ollie()
signal sfx_land(impact: float)
signal grind_started()
signal grind_ended()

# --- Tuned for readable beta feel ---
const MAX_SPEED := 16.0
const PUSH_ACCEL := 28.0
const CARVE_ACCEL := 10.0
const FRICTION := 5.5
const BRAKE_FRICTION := 16.0
const TURN_SPEED := 2.6
const TURN_SPEED_FAST := 5.2
const JUMP_VELOCITY := 9.8
const OLLIE_FORWARD_BOOST := 2.8
const AIR_CONTROL := 0.22
const AIR_TURN := 1.35
const GRAVITY := 22.0
const GRAVITY_UP := 16.0  # Session hang — lighter while rising
const MAX_FALL := -40.0
const LAND_STICK := 0.62
const CARVE_LEAN_MAX := 0.52
const SECONDARY_RECOVER_RATE := 1.8
const GRIND_MIN_SPEED := 1.6
const GRIND_FRICTION := 0.7
const GRIND_SNAP := 28.0
const GRIND_OLLIE_BOOST := 3.0
const GRIND_MIN_NORMAL_Y := 0.22  # allow thin-bar edge tops; still reject walls
const GRIND_FOOT_CLEAR := 0.04
const STREET_RAIL_NAMES := ["Flatbar", "StairsA", "Ledge", "LongLedge"]
const GRIND_PROXIMITY := 3.5
const SPEED_MPH_SCALE := 2.15  # game units → readable HUD mph

@onready var mesh: Node3D = $MeshPivot
@onready var board: MeshInstance3D = $MeshPivot/Board
@onready var _emily: Node3D = get_node_or_null("MeshPivot/Emily") as Node3D
@onready var rider: MeshInstance3D = $MeshPivot/Rider
@onready var _tricks: Node = get_node_or_null("TrickSystem")
@onready var _sfx_ollie: AudioStreamPlayer3D = get_node_or_null("SfxOllie")
@onready var _sfx_land: AudioStreamPlayer3D = get_node_or_null("SfxLand")
@onready var _sfx_grind_start: AudioStreamPlayer3D = get_node_or_null("SfxGrindStart")
@onready var _sfx_grind_loop: AudioStreamPlayer3D = get_node_or_null("SfxGrindLoop")
@onready var _sfx_grind_exit: AudioStreamPlayer3D = get_node_or_null("SfxGrindExit")

var _facing := 0.0
var _was_on_floor := true
var _airborne := false
var _active_air_trick := ""
var _secondary_intensity := 1.0
var _board_lean := 0.0
var _grinding := false
var _grind_axis := Vector3(1.0, 0.0, 0.0)
var _land_tween: Tween
var _grind_grace := 0.0


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
		var g := GRAVITY_UP if velocity.y > 0.0 else GRAVITY
		velocity.y = maxf(velocity.y - g * delta, MAX_FALL)
		_airborne = true
	elif on_floor and velocity.y < 0.0:
		land_impact = clampf((-velocity.y) / 18.0, 0.15, 1.0)
		velocity.y = 0.0

	# Land when leaving air (not only floor-edge) so FOV punch always fires after ollie.
	if on_floor and not _grinding and (_airborne or not _was_on_floor):
		var impact := land_impact if land_impact > 0.2 else 0.7
		_on_landed(impact)

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

		# skate. Flick-It arcs: responsive yaw at low speed, stable at high (-Mi9EKoBCSg).
		var turn := AIR_TURN
		if on_floor:
			var spd_t := clampf(speed / MAX_SPEED, 0.0, 1.0)
			# Low speed → FAST (responsive); high speed → TURN_SPEED (stable).
			turn = lerpf(TURN_SPEED_FAST, TURN_SPEED, spd_t)
		_facing = lerp_angle(_facing, wish_angle, turn * delta)
		if mesh:
			mesh.rotation.y = _facing

		# Couple horizontal velocity toward facing so carve arcs read (board goes where you look).
		if on_floor and speed > 1.0:
			var face_dir := Vector3(sin(_facing), 0.0, cos(_facing))
			var couple := lerpf(0.55, 0.22, clampf(speed / MAX_SPEED, 0.0, 1.0))
			horizontal = horizontal.lerp(face_dir * speed, couple * delta * 8.0)

		var turn_dir := wrapf(wish_angle - _facing, -PI, PI)
		var lean_target := 0.0
		var turning := absf(turn_dir) > 0.08
		var moving := speed > 1.2 or wish.length_squared() > 0.15
		if turning and moving:
			lean_target = clampf(-turn_dir * 1.9, -CARVE_LEAN_MAX, CARVE_LEAN_MAX)
			lean_target *= clampf(speed / 3.5, 0.4, 1.0)
			if not on_floor:
				lean_target *= 0.3
			# Light Session bleed — keep skate. arc readability (not mushy brake).
			if on_floor:
				var bleed := 1.0 - clampf(absf(turn_dir) * 0.35, 0.0, 0.16)
				horizontal *= bleed
		_board_lean = lerpf(_board_lean, lean_target, 11.0 * delta)
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

func get_facing_yaw() -> float:
	## Radians; +Z forward. Player Controller behind-board cam should yaw with this.
	return _facing


func get_facing_forward() -> Vector3:
	return Vector3(sin(_facing), 0.0, cos(_facing))


func get_velocity_yaw() -> float:
	var h := Vector3(velocity.x, 0.0, velocity.z)
	if h.length_squared() < 0.25:
		return _facing
	return atan2(h.x, h.z)


func get_cam_yaw() -> float:
	## Blend facing + velocity for skate. follow (readable carve without stuck orbit).
	var vyaw := get_velocity_yaw()
	var hspd := Vector3(velocity.x, 0.0, velocity.z).length()
	var w := clampf(hspd / 6.0, 0.0, 0.65)
	return lerp_angle(_facing, vyaw, w)



func get_horizontal_speed() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()


func get_speed_mph() -> float:
	## HUD-facing speed so playtest never reads as a dead 0 while rolling.
	return get_horizontal_speed() * SPEED_MPH_SCALE




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
	var speed_ok := speed >= GRIND_MIN_SPEED * 0.4 or _grinding
	var can_lock := hit.has("axis") and speed_ok
	if can_lock:
		_grind_axis = hit["axis"]
		var pt: Vector3 = hit["point"]
		# Sit on rail top — origin ≈ feet; never lerp into the collider (QA sink).
		var target_y := pt.y - GRIND_FOOT_CLEAR
		_grind_grace = 0.22
		if not _grinding:
			_grinding = true
			_airborne = false
			grind_started.emit()
			_play_sfx_grind_start()
			var rail := str(hit.get("rail", ""))
			if rail == "" and hit.get("collider") is Node:
				rail = _street_rail_label(hit.get("collider") as Node)
			if _tricks and _tricks.has_method("notify_grind_started"):
				_tricks.notify_grind_started(rail)
			elif _tricks and _tricks.has_method("notify_trick_started"):
				_tricks.notify_trick_started("grind" if rail == "" else rail)
			global_position.y = target_y
		else:
			global_position.y = lerpf(global_position.y, target_y, 0.55)
		velocity.y = 0.0
		return
	if _grinding:
		_grind_grace -= get_physics_process_delta_time()
		if _grind_grace > 0.0:
			velocity.y = 0.0
			return
		_grinding = false
		grind_ended.emit()
		_play_sfx_grind_end()


func _find_grind_collision() -> Dictionary:
	## Top-face grindables only (Skater XL ledge clarity). Side hits caused geo sink.
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null or not (collider is Node):
			continue
		if not (collider as Node).is_in_group("grindable"):
			continue
		var n := col.get_normal()
		if n.y < GRIND_MIN_NORMAL_Y:
			continue
		var axis := Vector3.UP.cross(n)
		if axis.length_squared() < 0.01:
			# Flat-ish top: rail runs along velocity / facing.
			axis = Vector3(velocity.x, 0.0, velocity.z)
		axis.y = 0.0
		if axis.length_squared() < 0.01:
			axis = Vector3(sin(_facing), 0.0, cos(_facing))
		axis = axis.normalized()
		return {
			"axis": axis,
			"point": col.get_position(),
			"normal": n,
			"rail": _street_rail_label(collider as Node),
		}
	# Thin plaza bars often miss top-face slides — proximity for Flatbar/StairsA/LongLedge.
	return _find_grind_by_proximity()


func _street_rail_label(node: Node) -> String:
	var n := node
	while n:
		var name_str := String(n.name)
		for want in STREET_RAIL_NAMES:
			if name_str == want or name_str.begins_with(want):
				return want
		n = n.get_parent()
	return ""


func _find_grind_by_proximity() -> Dictionary:
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if speed < GRIND_MIN_SPEED * 0.35 and not _grinding:
		return {}
	var best: Node3D = null
	var best_d := GRIND_PROXIMITY
	var best_top := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("grindable"):
		if not (node is Node3D):
			continue
		if _street_rail_label(node) == "":
			continue
		var n3 := node as Node3D
		var closest := _closest_grind_point(n3)
		var d: float = closest["d"]
		var top: Vector3 = closest["top"]
		if d < best_d:
			best_d = d
			best = n3
			best_top = top
	if best == null:
		return {}
	var forward := Vector3(velocity.x, 0.0, velocity.z)
	if forward.length_squared() < 0.01:
		forward = Vector3(sin(_facing), 0.0, cos(_facing))
	forward = forward.normalized()
	return {
		"axis": forward,
		"point": best_top,
		"normal": Vector3.UP,
		"rail": _street_rail_label(best),
	}


## Closest point on grindable box collision (handles long Flatbar ends).
func _closest_grind_point(n3: Node3D) -> Dictionary:
	var best_d := INF
	var best_top := n3.global_position + Vector3(0.0, 0.45, 0.0)
	var found := false
	for cs in n3.find_children("*", "CollisionShape3D", true, false):
		if not (cs is CollisionShape3D):
			continue
		var shape_node := cs as CollisionShape3D
		if shape_node.shape == null or not (shape_node.shape is BoxShape3D):
			continue
		var box := shape_node.shape as BoxShape3D
		var xf := shape_node.global_transform
		var local := xf.affine_inverse() * global_position
		var half := box.size * 0.5
		var clamped := Vector3(
			clampf(local.x, -half.x, half.x),
			clampf(local.y, -half.y, half.y),
			clampf(local.z, -half.z, half.z)
		)
		var world := xf * clamped
		var d := Vector3(global_position.x - world.x, 0.0, global_position.z - world.z).length()
		var dy := absf(global_position.y - world.y)
		if dy > 1.35:
			continue
		if d < best_d:
			best_d = d
			# Top of box in world space.
			var top_local := Vector3(clamped.x, half.y, clamped.z)
			best_top = xf * top_local
			found = true
	if not found:
		var d0 := Vector3(
			global_position.x - n3.global_position.x,
			0.0,
			global_position.z - n3.global_position.z
		).length()
		return {"d": d0, "top": best_top}
	return {"d": best_d, "top": best_top}


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
	if _grinding or (_sfx_grind_loop and _sfx_grind_loop.playing):
		_play_sfx_grind_end()
	_grinding = false
	_airborne = true
	_active_air_trick = "ollie"
	_ollie_squash()
	set_secondary_intensity(0.55)
	_play_sfx_ollie()
	# Tiny pop punch — Session-like board tick, not a big cam slam.
	var cam_pop := get_tree().get_first_node_in_group("follow_camera") as Node
	if cam_pop and cam_pop.has_method("apply_punch"):
		cam_pop.call("apply_punch", 0.28, 0.07)
	if _tricks and _tricks.has_method("notify_trick_started"):
		_tricks.notify_trick_started("ollie")


func _on_landed(impact: float = 0.35) -> void:
	velocity.x *= LAND_STICK
	velocity.z *= LAND_STICK
	velocity.y = 0.0
	_board_lean *= 0.3
	set_secondary_intensity(0.0)
	_play_sfx_land(impact)
	if _airborne and _active_air_trick != "":
		# Empty name → TrickSystem keeps air-key upgrades (kickflip etc.).
		if _tricks and _tricks.has_method("notify_trick_landed"):
			_tricks.notify_trick_landed("")
		_active_air_trick = ""
	_airborne = false
	# After TrickSystem land pose starts — overwrite with camera-readable squash on EmilyMesh/Board.
	_land_squash(impact)


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
	tw.tween_property(mesh, "scale", Vector3(1.16, 0.68, 1.16), 0.05)
	tw.tween_property(mesh, "scale", Vector3(0.96, 1.12, 0.96), 0.08)
	tw.tween_property(mesh, "scale", Vector3.ONE, 0.12)


func _land_squash(impact: float = 0.5) -> void:
	## Camera-readable land hit. Prefer cam FOV/dip + MeshPivot sink (don't fight TrickSystem Emily:scale).
	if _land_tween and _land_tween.is_valid():
		_land_tween.kill()

	if _tricks and _tricks.has_method("suppress_pose_for_land"):
		_tricks.call("suppress_pose_for_land", 0.55)
	var anim := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim:
		anim.stop()

	# Hard camera punch — readable even if mesh squash is contested.
	var cam := get_tree().get_first_node_in_group("follow_camera") as Node
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam and cam.has_method("apply_punch"):
		# Unmistakable FOV land punch (Session PASS bar) — cite NfY46Ho_dEo.
		var punch_s := clampf(1.05 + impact * 0.75, 1.05, 1.6)
		cam.call_deferred("apply_punch", punch_s, 0.34)

	if mesh == null:
		return

	var base_y := mesh.position.y
	var board_base_y := board.position.y if board else 0.0
	var board_base_scale := board.scale if board else Vector3.ONE

	# Whole rider assembly sinks + flattens (MeshPivot), hold, then pop back.
	mesh.scale = Vector3.ONE
	_land_tween = create_tween()
	_land_tween.set_parallel(true)
	_land_tween.tween_property(mesh, "scale", Vector3(1.55, 0.28, 1.55), 0.08)
	_land_tween.tween_property(mesh, "position:y", base_y - 0.36, 0.08)
	if board:
		_land_tween.tween_property(board, "scale", board_base_scale * Vector3(1.2, 0.35, 1.2), 0.09)
		_land_tween.tween_property(board, "position:y", board_base_y - 0.06, 0.09)
	_land_tween.set_parallel(false)
	_land_tween.tween_interval(0.10)
	_land_tween.set_parallel(true)
	_land_tween.tween_property(mesh, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_land_tween.tween_property(mesh, "position:y", base_y, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if board:
		_land_tween.tween_property(board, "scale", board_base_scale, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_land_tween.tween_property(board, "position:y", board_base_y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)



func _play_sfx_ollie() -> void:
	sfx_ollie.emit()
	if _sfx_ollie:
		_sfx_ollie.play()


func _play_sfx_land(impact: float) -> void:
	sfx_land.emit(impact)
	if _sfx_land:
		_sfx_land.volume_db = lerpf(-8.0, 0.0, clampf(impact, 0.0, 1.0))
		_sfx_land.play()


func _play_sfx_grind_start() -> void:
	if _sfx_grind_start:
		_sfx_grind_start.play()
	if _sfx_grind_loop and not _sfx_grind_loop.playing:
		_sfx_grind_loop.play()


func _play_sfx_grind_end() -> void:
	if _sfx_grind_loop and _sfx_grind_loop.playing:
		_sfx_grind_loop.stop()
	if _sfx_grind_exit:
		_sfx_grind_exit.play()


func _ensure_sfx_streams() -> void:
	if _sfx_ollie and _sfx_ollie.stream == null:
		_sfx_ollie.stream = _load_wav_stream("res://assets/audio/sfx/ollie_pop.wav")
	if _sfx_land and _sfx_land.stream == null:
		_sfx_land.stream = _load_wav_stream("res://assets/audio/sfx/land_thud.wav")
	if _sfx_grind_start and _sfx_grind_start.stream == null:
		_sfx_grind_start.stream = _load_wav_stream("res://assets/audio/sfx/grind_start.wav")
	if _sfx_grind_loop and _sfx_grind_loop.stream == null:
		var loop_stream := _load_wav_stream("res://assets/audio/sfx/grind_loop.wav")
		if loop_stream:
			loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			_sfx_grind_loop.stream = loop_stream
	if _sfx_grind_exit and _sfx_grind_exit.stream == null:
		_sfx_grind_exit.stream = _load_wav_stream("res://assets/audio/sfx/grind_exit.wav")


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

