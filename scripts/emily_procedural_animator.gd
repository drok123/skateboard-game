extends Node
## Video-reference procedural rider animation for Emily's lightweight 18-bone rig.
## The skater-test reference supplies timing/body-language; all motion is authored
## here against this project's own skeleton and remains independent of the board.

@export var response_rate := 14.0
@export var stance_crouch := 0.025
@export var push_cycle_seconds := 0.88

var _emily: Node3D
var _player: CharacterBody3D
var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _left_target: Node3D
var _right_target: Node3D
var _left_ik: SkeletonIK3D
var _right_ik: SkeletonIK3D
var _time := 0.0
var _push_clock := 0.0
var _air_clock := 0.0
var _land_clock := 99.0
var _was_grounded := true


func _ready() -> void:
	process_priority = 90
	_emily = get_parent() as Node3D
	var walk: Node = _emily
	while walk and not (walk is CharacterBody3D):
		walk = walk.get_parent()
	_player = walk as CharacterBody3D
	call_deferred("_bind_rig")


func _bind_rig() -> void:
	if _emily and _emily.has_method("get_skeleton"):
		_skeleton = _emily.call("get_skeleton") as Skeleton3D
	if _skeleton == null:
		return
	for bone_name in [
		"Root", "Hips", "Spine", "Chest", "Neck", "Head",
		"UpperArm.L", "LowerArm.L", "Hand.L",
		"UpperArm.R", "LowerArm.R", "Hand.R",
		"Thigh.L", "Shin.L", "Foot.L", "Thigh.R", "Shin.R", "Foot.R"
	]:
		var index := _skeleton.find_bone(bone_name)
		if index >= 0:
			_bones[bone_name] = index
	_setup_foot_ik()


func _process(delta: float) -> void:
	if _skeleton == null:
		_bind_rig()
		if _skeleton == null:
			return
	_time += delta
	var grounded := _player == null or _player.is_on_floor()
	if grounded and not _was_grounded:
		_land_clock = 0.0
	if not grounded:
		_air_clock += delta
	else:
		_air_clock = 0.0
	_land_clock += delta
	_was_grounded = grounded

	var pose := _base_pose()
	var steer := _read_float("get_steer_input", 0.0)
	var pushing := _read_bool("is_pushing", false)
	var push_phase := _read_float("get_push_phase", -1.0)
	if pushing:
		if push_phase < 0.0:
			_push_clock = fmod(_push_clock + delta, push_cycle_seconds)
			push_phase = _push_clock / push_cycle_seconds
		else:
			_push_clock = push_phase * push_cycle_seconds
		_apply_push(pose, push_phase)
		_update_push_targets(push_phase)
	else:
		_push_clock = 0.0
		_apply_cruise(pose, steer)
		_set_foot_targets(Vector3(-0.09, 0.14, -0.29), Vector3(0.09, 0.14, 0.29), 0.72)

	var trick := _active_trick()
	if not grounded or trick != "" and trick != "grind":
		_apply_air(pose, _air_clock, trick)
		_set_ik_influence(0.18)
	elif _land_clock < 0.42:
		_apply_land(pose, _land_clock / 0.42)
		_set_ik_influence(0.82)
	elif trick == "grind":
		_apply_grind(pose, steer)

	_apply_pose(pose, delta)


func _setup_foot_ik() -> void:
	if _left_ik != null or _skeleton == null or _emily == null:
		return
	if not _bones.has("Thigh.L") or not _bones.has("Foot.L") or not _bones.has("Thigh.R") or not _bones.has("Foot.R"):
		return
	_left_target = Node3D.new()
	_left_target.name = "LeftFootDeckTarget"
	_emily.add_child(_left_target)
	_right_target = Node3D.new()
	_right_target.name = "RightFootDeckTarget"
	_emily.add_child(_right_target)
	_left_ik = _make_leg_ik("LeftLegIK", &"Thigh.L", &"Foot.L", _left_target)
	_right_ik = _make_leg_ik("RightLegIK", &"Thigh.R", &"Foot.R", _right_target)
	_set_foot_targets(Vector3(-0.09, 0.14, -0.29), Vector3(0.09, 0.14, 0.29), 0.72)


func _make_leg_ik(node_name: String, root_bone: StringName, tip_bone: StringName, target: Node3D) -> SkeletonIK3D:
	var ik := SkeletonIK3D.new()
	ik.name = node_name
	ik.root_bone = root_bone
	ik.tip_bone = tip_bone
	ik.max_iterations = 16
	ik.min_distance = 0.002
	ik.override_tip_basis = false
	_skeleton.add_child(ik)
	ik.target_node = ik.get_path_to(target)
	ik.start()
	return ik


func _set_foot_targets(left: Vector3, right: Vector3, influence: float) -> void:
	if _left_target:
		_left_target.position = left
	if _right_target:
		_right_target.position = right
	_set_ik_influence(influence)


func _set_ik_influence(value: float) -> void:
	if _left_ik:
		_left_ik.influence = value
	if _right_ik:
		_right_ik.influence = value


func _update_push_targets(phase: float) -> void:
	var t := fposmod(phase, 1.0)
	var left := Vector3(-0.06, 0.14, -0.29)
	var right := Vector3(0.09, 0.14, 0.29)
	if t < 0.18:
		right = right.lerp(Vector3(0.34, 0.26, 0.05), smoothstep(0.0, 0.18, t))
	elif t < 0.35:
		right = Vector3(0.34, 0.03, lerpf(0.05, -0.12, smoothstep(0.18, 0.35, t)))
	elif t < 0.68:
		right = Vector3(0.34, 0.03, lerpf(-0.12, 0.56, smoothstep(0.35, 0.68, t)))
	else:
		right = Vector3(0.34, 0.03, 0.56).lerp(Vector3(0.09, 0.14, 0.29), smoothstep(0.68, 1.0, t))
	_set_foot_targets(left, right, 0.86)


func _base_pose() -> Dictionary:
	return {
		"Hips:p": Vector3(0.0, -stance_crouch, 0.0),
		"Hips:r": Vector3(-4.0, 0.0, 0.0),
		"Spine:r": Vector3(8.0, 0.0, 0.0),
		"Chest:r": Vector3(-4.0, 0.0, 0.0),
		"Neck:r": Vector3(-2.0, 0.0, 0.0),
		"Head:r": Vector3(2.0, 0.0, 0.0),
		"UpperArm.L:r": Vector3(-8.0, 0.0, 20.0),
		"LowerArm.L:r": Vector3(-12.0, 0.0, 2.0),
		"UpperArm.R:r": Vector3(7.0, 0.0, -24.0),
		"LowerArm.R:r": Vector3(-15.0, 0.0, -2.0),
		# Opposing thigh angles place the feet fore/aft on the deck instead of
		# leaving the generated rig in its narrow mannequin stance.
		"Thigh.L:r": Vector3(24.0, 0.0, -3.0),
		"Thigh.L:p": Vector3(0.0, 0.0, -0.11),
		"Shin.L:r": Vector3(-34.0, 0.0, 0.0),
		"Foot.L:r": Vector3(10.0, -24.0, 0.0),
		"Thigh.R:r": Vector3(-21.0, 0.0, 3.0),
		"Thigh.R:p": Vector3(0.0, 0.0, 0.11),
		"Shin.R:r": Vector3(32.0, 0.0, 0.0),
		"Foot.R:r": Vector3(-11.0, 24.0, 0.0),
	}


func _apply_cruise(pose: Dictionary, steer: float) -> void:
	var breathe := sin(_time * 2.4)
	pose["Hips:p"] += Vector3(0.0, breathe * 0.004, 0.0)
	pose["Hips:r"] += Vector3(0.0, steer * 2.0, -steer * 5.0)
	pose["Chest:r"] += Vector3(0.0, -steer * 5.0, steer * 8.0)
	pose["Head:r"] += Vector3(0.0, steer * 2.0, -steer * 3.0)
	pose["UpperArm.L:r"] += Vector3(0.0, 0.0, -steer * 9.0 + breathe * 2.0)
	pose["UpperArm.R:r"] += Vector3(0.0, 0.0, -steer * 7.0 - breathe * 2.0)


func _apply_push(pose: Dictionary, phase: float) -> void:
	var t := fposmod(phase, 1.0)
	var stroke := sin(t * TAU)
	var lift := maxf(0.0, -sin(t * TAU))
	# Weight stays over the planted front foot while the rear foot leaves the deck,
	# plants beside it, sweeps back, then arcs onto the rear bolts.
	pose["Hips:p"] += Vector3(-0.018, -0.018 * absf(stroke), 0.012 * stroke)
	pose["Hips:r"] += Vector3(5.0, 8.0 * lift, -3.0)
	pose["Spine:r"] += Vector3(7.0, -5.0 * lift, 0.0)
	pose["Chest:r"] += Vector3(-2.0, 7.0 * lift, 5.0 * stroke)
	pose["Thigh.L:r"] += Vector3(8.0, 0.0, -2.0)
	pose["Shin.L:r"] += Vector3(-10.0, 0.0, 0.0)
	pose["Thigh.R:r"] += Vector3(-34.0 * stroke - 18.0 * lift, 0.0, 12.0 * lift)
	pose["Shin.R:r"] += Vector3(42.0 * lift + 18.0 * maxf(stroke, 0.0), 0.0, 0.0)
	pose["Foot.R:r"] += Vector3(-18.0 * stroke, -22.0 * lift, 0.0)
	pose["UpperArm.L:r"] += Vector3(18.0 * stroke, 0.0, -10.0 * stroke)
	pose["UpperArm.R:r"] += Vector3(-24.0 * stroke, 0.0, -14.0 * stroke)


func _apply_air(pose: Dictionary, elapsed: float, trick: String) -> void:
	var pop := smoothstep(0.0, 0.10, minf(elapsed, 0.10))
	var tuck := smoothstep(0.08, 0.28, elapsed)
	var descending := _player != null and _player.velocity.y < -0.7
	var catch_amount := smoothstep(0.0, 5.0, -_player.velocity.y) if descending else 0.0
	var crouch := 0.10 * tuck * (1.0 - 0.55 * catch_amount)
	pose["Hips:p"] = Vector3(0.0, -crouch + 0.035 * pop, 0.02)
	pose["Hips:r"] = Vector3(-10.0 + 13.0 * tuck, 0.0, 0.0)
	pose["Spine:r"] = Vector3(15.0 - 7.0 * pop, 0.0, 0.0)
	pose["Chest:r"] = Vector3(-8.0, 0.0, 0.0)
	pose["Neck:r"] = Vector3(-5.0, 0.0, 0.0)
	pose["Head:r"] = Vector3(8.0, 0.0, 0.0)
	# Jamie reference: front knee leads, rear follows; arms open asymmetrically.
	pose["Thigh.L:r"] = Vector3(-39.0 * tuck, 0.0, -7.0)
	pose["Shin.L:r"] = Vector3(70.0 * tuck, 0.0, 0.0)
	pose["Thigh.R:r"] = Vector3(-30.0 * tuck, 0.0, 8.0)
	pose["Shin.R:r"] = Vector3(61.0 * tuck, 0.0, 0.0)
	pose["Foot.L:r"] = Vector3(-19.0 * tuck, -20.0, 0.0)
	pose["Foot.R:r"] = Vector3(-13.0 * tuck, 20.0, 0.0)
	pose["UpperArm.L:r"] = Vector3(-34.0, 0.0, 42.0 * tuck)
	pose["LowerArm.L:r"] = Vector3(-28.0, 0.0, 12.0)
	pose["UpperArm.R:r"] = Vector3(24.0, 0.0, -58.0 * tuck)
	pose["LowerArm.R:r"] = Vector3(-36.0, 0.0, -8.0)
	if trick in ["kickflip", "tre"]:
		pose["Thigh.L:r"] += Vector3(8.0, -12.0, -8.0)
		pose["Foot.L:r"] += Vector3(7.0, -24.0, -12.0)
	elif trick == "heelflip":
		pose["Thigh.L:r"] += Vector3(5.0, 13.0, 10.0)
		pose["Foot.L:r"] += Vector3(10.0, 28.0, 13.0)
	elif trick in ["backside_shuv", "backside_180", "frontside_180"]:
		pose["Hips:r"] += Vector3(0.0, -10.0, 0.0)
		pose["Thigh.R:r"] += Vector3(0.0, 16.0, 0.0)
	if descending:
		pose["Hips:p"] += Vector3(0.0, 0.045 * catch_amount, 0.0)
		pose["Thigh.L:r"] = (pose["Thigh.L:r"] as Vector3).lerp(Vector3(5.0, 0.0, -3.0), catch_amount)
		pose["Thigh.R:r"] = (pose["Thigh.R:r"] as Vector3).lerp(Vector3(8.0, 0.0, 3.0), catch_amount)


func _apply_land(pose: Dictionary, normalized: float) -> void:
	var t := clampf(normalized, 0.0, 1.0)
	var compression := sin(t * PI) * (1.0 - 0.25 * t)
	pose["Hips:p"] += Vector3(0.0, -0.105 * compression, 0.025 * compression)
	pose["Hips:r"] += Vector3(-11.0 * compression, 0.0, 0.0)
	pose["Spine:r"] += Vector3(17.0 * compression, 0.0, 0.0)
	pose["Chest:r"] += Vector3(-7.0 * compression, 0.0, 0.0)
	pose["Thigh.L:r"] += Vector3(-29.0 * compression, 0.0, -4.0)
	pose["Shin.L:r"] += Vector3(51.0 * compression, 0.0, 0.0)
	pose["Thigh.R:r"] += Vector3(-25.0 * compression, 0.0, 4.0)
	pose["Shin.R:r"] += Vector3(47.0 * compression, 0.0, 0.0)
	pose["UpperArm.L:r"] += Vector3(-10.0, 0.0, 26.0 * compression)
	pose["UpperArm.R:r"] += Vector3(12.0, 0.0, -35.0 * compression)


func _apply_grind(pose: Dictionary, steer: float) -> void:
	var balance := sin(_time * 4.5) * 3.0
	pose["Hips:p"] += Vector3(0.0, -0.045, 0.0)
	pose["Hips:r"] += Vector3(-5.0, steer * 5.0, balance)
	pose["Spine:r"] += Vector3(9.0, 0.0, -balance)
	pose["UpperArm.L:r"] += Vector3(-16.0, 0.0, 45.0 + balance)
	pose["UpperArm.R:r"] += Vector3(12.0, 0.0, -52.0 + balance)


func _apply_pose(pose: Dictionary, delta: float) -> void:
	var weight := 1.0 - exp(-response_rate * delta)
	for bone_name: String in _bones:
		var index: int = _bones[bone_name]
		var degrees_value: Vector3 = pose.get(bone_name + ":r", Vector3.ZERO)
		var target_rotation := Quaternion.from_euler(Vector3(
			deg_to_rad(degrees_value.x), deg_to_rad(degrees_value.y), deg_to_rad(degrees_value.z)
		))
		_skeleton.set_bone_pose_rotation(index, _skeleton.get_bone_pose_rotation(index).slerp(target_rotation, weight))
		var target_position: Vector3 = pose.get(bone_name + ":p", Vector3.ZERO)
		_skeleton.set_bone_pose_position(index, _skeleton.get_bone_pose_position(index).lerp(target_position, weight))


func _active_trick() -> String:
	if _player == null:
		return ""
	var tricks := _player.get_node_or_null("TrickSystem")
	if tricks == null:
		return ""
	return String(tricks.get("_active_trick"))


func _read_float(method: StringName, fallback: float) -> float:
	if _player and _player.has_method(method):
		return float(_player.call(method))
	return fallback


func _read_bool(method: StringName, fallback: bool) -> bool:
	if _player and _player.has_method(method):
		return bool(_player.call(method))
	return fallback
