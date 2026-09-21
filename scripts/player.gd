extends CharacterBody3D
## Momentum-based riding with board-relative steering, pop, landing and rail locks.
## Player Controller feeds wish + jump via apply_movement; Physics owns velocity.

signal sfx_ollie()
signal sfx_land(impact: float)
signal grind_started()
signal grind_ended()
signal push_stroke(power: float)
signal riding_input_changed(steer: float, pushing: bool, brake: float)

# Riding values use metres and seconds.
const MAX_SPEED := 12.0
const PUSH_CYCLE_SECONDS := 0.72
const PUSH_IMPULSE := 2.85
const PUSH_IMPULSE_AT_MAX_SPEED := 0.28
const FRICTION := 0.38
const BRAKE_FRICTION := 9.5
const REVERSE_SPEED := 2.2
const REVERSE_ACCEL := 4.0
const JUMP_VELOCITY := 7.2
const OLLIE_FORWARD_BOOST := 0.0
const AIR_TURN := 1.35
const GRAVITY := 22.0
const GRAVITY_UP := 22.0  # Session hang — lighter while rising
const MAX_FALL := -40.0
const LAND_STICK := 0.97
const CARVE_LEAN_MAX := 0.52
const SECONDARY_RECOVER_RATE := 1.8
const GRIND_MIN_SPEED := 0.9
const GRIND_FRICTION := 0.7
const GRIND_SNAP := 28.0
const GRIND_OLLIE_BOOST := 0.0
const GRIND_MIN_NORMAL_Y := 0.12  # allow thin-bar edge tops; still reject walls
const GRIND_FOOT_CLEAR := 0.04
const STREET_RAIL_NAMES := ["Flatbar", "StairsA", "Ledge", "LongLedge"]
const GRIND_PROXIMITY := 0.24
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
var _grind_rail := ""
var _grind_axis := Vector3(1.0, 0.0, 0.0)
var _land_tween: Tween
var _grind_grace := 0.0
var _grind_cooldown := 0.0
var _jump_buffer := 0.0
var _coyote_time := 0.0
var _mesh_rest_y := 0.0
var _board_rest_y := 0.12
var _board_rest_scale := Vector3.ONE
var _board_pitch := 0.0
var _spawn_position := Vector3.ZERO
var _pop_tween: Tween
var _push_phase := 0.0
var _push_was_down := false
var _push_power := 0.0
var _steer_input := 0.0
var _brake_input := 0.0
var _signed_speed := 0.0


func _ready() -> void:
	_ensure_sfx_streams()
	floor_snap_length = 0.25
	floor_constant_speed = false
	_mesh_rest_y = mesh.position.y
	_board_rest_y = board.position.y
	_board_rest_scale = board.scale
	call_deferred("_capture_spawn")


## Compatibility API: world-space wish is converted to steering and throttle.
func apply_movement(wish: Vector3, jump_pressed: bool, delta: float) -> void:
	var steer := 0.0
	if wish.length_squared() > 0.01:
		steer = -clampf(wrapf(atan2(wish.x, wish.z) - _facing, -PI, PI), -1.0, 1.0)
	apply_riding_input(steer, wish.length(), 0.0, jump_pressed, delta)


## Board-relative input: push builds speed, steering carves, release keeps rolling.
func apply_riding_input(steer: float, push: float, brake: float, jump_pressed: bool, delta: float) -> void:
	if global_position.y < -12.0:
		reset_to_spawn()
		return
	steer = clampf(steer, -1.0, 1.0)
	push = clampf(push, 0.0, 1.0)
	brake = clampf(brake, 0.0, 1.0)
	_steer_input = steer
	_brake_input = brake
	_update_push_cycle(push, delta)
	riding_input_changed.emit(steer, push > 0.05, brake)
	var on_floor := is_on_floor()
	_grind_cooldown = maxf(0.0, _grind_cooldown - delta)
	_jump_buffer = 0.12 if jump_pressed else maxf(0.0, _jump_buffer - delta)
	_coyote_time = 0.09 if on_floor else maxf(0.0, _coyote_time - delta)
	var popped := false
	if _jump_buffer > 0.0 and (on_floor or _grinding or _coyote_time > 0.0):
		_do_ollie(_grinding)
		_jump_buffer = 0.0
		_coyote_time = 0.0
		popped = true
	if not on_floor and not _grinding:
		velocity.y = maxf(velocity.y - GRAVITY * delta, MAX_FALL)
		_airborne = true
	elif on_floor and not popped:
		velocity.y = 0.0

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal.length()
	var grounded := on_floor and not popped
	if _grinding:
		horizontal = _grind_move(horizontal, Vector3.ZERO, delta)
	else:
		var forward := get_facing_forward()
		var forward_speed := horizontal.dot(forward)
		var speed_abs := absf(forward_speed)
		var steer_authority := clampf((speed_abs - 0.25) / 1.8, 0.0, 1.0)
		var turn_rate := lerpf(1.75, 0.8, clampf(speed_abs / MAX_SPEED, 0.0, 1.0)) if grounded else AIR_TURN
		var reverse_sign := -1.0 if forward_speed < -0.05 else 1.0
		_facing = wrapf(_facing - steer * turn_rate * steer_authority * reverse_sign * delta, -PI, PI)
		if grounded:
			# Rebuild from the freshly-carved heading. Grip removes sideways drift while
			# preserving signed momentum, including predictable low-speed reverse.
			forward = get_facing_forward()
			forward_speed = horizontal.dot(forward)
			forward_speed = move_toward(forward_speed, 0.0, FRICTION * delta)
			if brake > 0.05:
				if forward_speed > 0.3:
					forward_speed = move_toward(forward_speed, 0.0, BRAKE_FRICTION * brake * delta)
				else:
					forward_speed = move_toward(forward_speed, -REVERSE_SPEED, REVERSE_ACCEL * brake * delta)
			var push_power := _consume_push_stroke()
			if push_power > 0.0 and brake < 0.1:
				if forward_speed < 0.0:
					# A forward push cleanly changes direction instead of consuming a
					# whole animation cycle merely to cancel a tiny reverse roll.
					forward_speed = minf(MAX_SPEED, forward_speed + PUSH_IMPULSE * push_power)
				else:
					var speed_ratio := clampf(forward_speed / MAX_SPEED, 0.0, 1.0)
					var impulse_scale := lerpf(1.0, PUSH_IMPULSE_AT_MAX_SPEED, speed_ratio)
					forward_speed = minf(MAX_SPEED, forward_speed + PUSH_IMPULSE * impulse_scale * push_power)
				push_stroke.emit(push_power)
			horizontal = forward * forward_speed
			# Gravity along banks adds downhill speed and makes uphill lines cost momentum.
			var downhill := Vector3.DOWN.slide(get_floor_normal()) * GRAVITY
			horizontal += Vector3(downhill.x, 0.0, downhill.z) * delta
			_signed_speed = forward_speed
		else:
			_signed_speed = horizontal.dot(forward)
		# In air, body yaw changes without steering the ballistic trajectory.
		var lean_target := steer * CARVE_LEAN_MAX * clampf(speed / 6.0, 0.0, 1.0) if grounded else 0.0
		_board_lean = lerpf(_board_lean, lean_target, 1.0 - exp(-10.0 * delta))
	if mesh:
		mesh.rotation.y = _facing
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var impact_speed := maxf(-velocity.y, 0.0)
	move_and_slide()
	_update_grind_state()
	if is_on_floor() and not _grinding and _airborne and not popped:
		_on_landed(clampf(impact_speed / 16.0, 0.15, 1.0))
	_update_board_visuals(delta, (is_on_floor() and not popped) or _grinding)
	_recover_secondary(delta)
	_was_on_floor = is_on_floor()


func set_secondary_intensity(amount: float) -> void:
	_secondary_intensity = clampf(amount, 0.0, 1.0)


func get_secondary_intensity() -> float:
	return _secondary_intensity


func is_grinding() -> bool:
	return _grinding


func get_grind_rail() -> String:
	## Active plaza rail label for Mission G1 / HUD.
	return _grind_rail

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


func get_push_phase() -> float:
	return _push_phase


func is_pushing() -> bool:
	return _push_was_down


func get_steer_input() -> float:
	return _steer_input


func get_brake_input() -> float:
	return _brake_input


func get_signed_speed() -> float:
	return _signed_speed


func _update_push_cycle(push: float, delta: float) -> void:
	var pushing := push > 0.05 and is_on_floor() and not _grinding
	if not pushing:
		_push_phase = 0.0
		_push_was_down = false
		_push_power = 0.0
		return
	_push_power = push
	if not _push_was_down:
		# A tap always gives one responsive stroke. Holding repeats at a readable
		# foot cadence for keyboard and controller accessibility.
		_push_phase = 1.0
		_push_was_down = true
		return
	_push_phase += delta / PUSH_CYCLE_SECONDS


func _consume_push_stroke() -> float:
	if not _push_was_down or _push_phase < 1.0:
		return 0.0
	_push_phase = fmod(_push_phase, 1.0)
	return _push_power




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
	if _grind_cooldown > 0.0 or velocity.y > 0.5:
		return
	var hit := _find_grind_collision()
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var speed_ok := speed >= GRIND_MIN_SPEED * 0.4 or _grinding
	var can_lock := hit.has("axis") and speed_ok
	if not _grinding and _tricks and _tricks.has_method("is_trick_caught"):
		can_lock = can_lock and bool(_tricks.call("is_trick_caught"))
	if can_lock:
		_grind_axis = _rail_axis(hit.get("collider") as Node3D, hit["axis"])
		var pt: Vector3 = hit["point"]
		# Sit on rail top — origin ≈ feet; never lerp into the collider (QA sink).
		var target_y := pt.y + GRIND_FOOT_CLEAR
		_grind_grace = 0.22
		if not _grinding:
			_grinding = true
			_airborne = false
			_active_air_trick = ""
			grind_started.emit()
			_play_sfx_grind_start()
			var rail := str(hit.get("rail", ""))
			if rail == "" and hit.get("collider") is Node:
				rail = _street_rail_label(hit.get("collider") as Node)
			_grind_rail = rail
			# Physics owns grind toast + juice punch; notify Tricks for combo/clips.
			var toast := "Grind" if rail == "" else "Grind — %s" % rail
			get_tree().call_group("hud", "show_toast", toast)
			# skate. lock-in punch — same frame as grind toast + SFX.
			var cam_g := get_tree().get_first_node_in_group("follow_camera") as Node
			if cam_g and cam_g.has_method("apply_juice_punch"):
				cam_g.call("apply_juice_punch", &"grind", 0.75)
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
		_grind_rail = ""
		grind_ended.emit()
		_play_sfx_grind_end()


func _find_grind_collision() -> Dictionary:
	## Top-face slides first; ray + proximity catch thin plaza lips (G1).
	var slide := _find_grind_by_slide()
	if slide.has("axis"):
		return slide
	var ray := _find_grind_by_ray()
	if ray.has("axis"):
		return ray
	return _find_grind_by_proximity()


func _find_grind_by_slide() -> Dictionary:
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
			"collider": collider,
		}
	return {}


func _find_grind_by_ray() -> Dictionary:
	## Downward probe from knees — locks when skating onto Flatbar / hubba without a top-face slide.
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var origin := global_position + Vector3(0.0, 0.18, 0.0)
	var dest := global_position + Vector3(0.0, -0.18, 0.0)
	var q := PhysicsRayQueryParameters3D.create(origin, dest)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	var collider = hit.get("collider")
	if collider == null or not (collider is Node):
		return {}
	if not (collider as Node).is_in_group("grindable"):
		return {}
	var n: Vector3 = hit.get("normal", Vector3.UP)
	if n.y < GRIND_MIN_NORMAL_Y:
		return {}
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if speed < GRIND_MIN_SPEED * 0.25 and not _grinding:
		return {}
	var axis := Vector3(velocity.x, 0.0, velocity.z)
	if axis.length_squared() < 0.01:
		axis = Vector3(sin(_facing), 0.0, cos(_facing))
	axis = axis.normalized()
	return {
		"axis": axis,
		"point": hit.get("position", global_position),
		"normal": n,
		"rail": _street_rail_label(collider as Node),
		"collider": collider,
	}


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
		var n3 := node as Node3D
		if (n3 as Node).is_in_group("coping"):
			continue
		var closest := _closest_grind_point(n3)
		var d: float = closest["d"]
		var top: Vector3 = closest["top"]
		# Choose the nearest physical rail within the small catch radius.
		var score := d
		if score < best_d:
			best_d = score
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
		"collider": best,
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
		var top_world := xf * Vector3(clamped.x, half.y, clamped.z)
		var dy := absf(global_position.y - top_world.y)
		if dy > 0.3:
			continue
		if d < best_d:
			best_d = d
			# Top of box in world space.
			var top_local := Vector3(clamped.x, half.y, clamped.z)
			best_top = xf * top_local
			found = true
	if not found:
		return {"d": INF, "top": best_top}
	return {"d": best_d, "top": best_top}


func _do_ollie(from_grind: bool = false) -> void:
	velocity.y = JUMP_VELOCITY + (0.8 if from_grind else 0.0)
	var forward := Vector3(sin(_facing), 0.0, cos(_facing))
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var boost := GRIND_OLLIE_BOOST if from_grind else OLLIE_FORWARD_BOOST
	horizontal += forward * boost
	if from_grind:
		grind_ended.emit()
	if horizontal.length() > MAX_SPEED * 1.1:
		horizontal = horizontal.limit_length(MAX_SPEED * 1.1)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if _grinding or (_sfx_grind_loop and _sfx_grind_loop.playing):
		_play_sfx_grind_end()
	_grinding = false
	_grind_rail = ""
	_grind_cooldown = 0.3
	_airborne = true
	_active_air_trick = "ollie"
	_ollie_squash()
	set_secondary_intensity(0.55)
	_play_sfx_ollie()
	# skate. trailer ollie pop — playful, not a land slam.
	var cam_pop := get_tree().get_first_node_in_group("follow_camera") as Node
	if cam_pop and cam_pop.has_method("apply_juice_punch"):
		cam_pop.call("apply_juice_punch", &"ollie", 0.85)
	elif cam_pop and cam_pop.has_method("apply_punch"):
		cam_pop.call("apply_punch", 0.35, 0.11)
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
	_board_pitch = lerpf(_board_pitch, pitch, 1.0 - exp(-12.0 * delta))
	var trick_rotation := Vector3.ZERO
	if _tricks and _tricks.has_method("get_board_trick_rotation"):
		trick_rotation = _tricks.call("get_board_trick_rotation")
	board.rotation = Vector3(_board_pitch, 0.0, _board_lean) + trick_rotation
	if rider:
		rider.rotation.x = _board_pitch * 0.45
		rider.rotation.z = _board_lean * 0.7
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
	# skate. pop squash — quick crouch→stretch, honest not carnival.
	if mesh == null:
		return
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.tween_property(mesh, "scale", Vector3(1.03, 0.9, 1.03), 0.04)
	_pop_tween.tween_property(mesh, "scale", Vector3(0.99, 1.04, 0.99), 0.07)
	_pop_tween.tween_property(mesh, "scale", Vector3.ONE, 0.1)


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
		var punch_s := clampf(0.2 + impact * 0.4, 0.2, 0.6)
		cam.call_deferred("apply_punch", punch_s, 0.34)

	if mesh == null:
		return

	var base_y := _mesh_rest_y
	var board_base_y := _board_rest_y
	var board_base_scale := _board_rest_scale

	# Small compression keeps landings readable without distorting the rider.
	mesh.scale = Vector3.ONE
	_land_tween = create_tween()
	_land_tween.set_parallel(true)
	_land_tween.tween_property(mesh, "scale", Vector3(1.03, 0.88, 1.03), 0.08)
	_land_tween.tween_property(mesh, "position:y", base_y - 0.08, 0.08)
	if board:
		_land_tween.tween_property(board, "scale", board_base_scale * Vector3.ONE, 0.09)
		_land_tween.tween_property(board, "position:y", board_base_y, 0.09)
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



func _capture_spawn() -> void:
	_spawn_position = global_position


func reset_to_spawn() -> void:
	if _grinding:
		grind_ended.emit()
	_grinding = false
	_grind_rail = ""
	_grind_grace = 0.0
	_grind_cooldown = 0.3
	_play_sfx_grind_end()
	if _tricks and _tricks.has_method("notify_bailed"):
		_tricks.call("notify_bailed")
	for tween in [_land_tween, _pop_tween]:
		if tween and tween.is_valid():
			tween.kill()
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_facing = 0.0
	_board_lean = 0.0
	_board_pitch = 0.0
	_push_phase = 0.0
	_push_was_down = false
	_push_power = 0.0
	_steer_input = 0.0
	_brake_input = 0.0
	_signed_speed = 0.0
	_jump_buffer = 0.0
	_coyote_time = 0.0
	_airborne = false
	_active_air_trick = ""
	mesh.position.y = _mesh_rest_y
	mesh.scale = Vector3.ONE
	mesh.rotation = Vector3.ZERO
	board.position.y = _board_rest_y
	board.scale = _board_rest_scale
	board.rotation = Vector3.ZERO


func _rail_axis(collider: Node3D, fallback: Vector3) -> Vector3:
	if collider == null:
		return fallback
	for child in collider.find_children("*", "CollisionShape3D", true, false):
		var shape_node := child as CollisionShape3D
		if shape_node.shape is BoxShape3D:
			var box := shape_node.shape as BoxShape3D
			var axis := shape_node.global_basis.x if box.size.x > box.size.z else shape_node.global_basis.z
			axis.y = 0.0
			if axis.length_squared() > 0.01:
				return axis.normalized()
	return fallback
