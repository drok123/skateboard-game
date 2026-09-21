extends Node
## Beta: AnimationPlayer stubs + named trick_started toasts.
## Physics owns pop/land notify timing; air-key upgrades rename the active trick.
## Idle/push are real AnimationPlayer library entries (subtle scale/Y on MeshPivot/Emily).
## Soft secondary motion is NOT implemented here — see docs/soft-motion-rigging.md.

signal trick_started(trick_name: String)
signal trick_landed(trick_name: String, score: int)
signal combo_changed(multiplier: int, total_score: int)
signal bailed()

@export var combo_window_sec := 2.0

## Paths relative to Player (AnimationPlayer.root_node = parent).
const EMILY_SCALE_PATH := NodePath("MeshPivot/Emily:scale")
const EMILY_Y_PATH := NodePath("MeshPivot/Emily:position:y")

var _anim: AnimationPlayer
var _active_trick := ""
var _combo_mult := 1
var _combo_score := 0
var _combo_timer := 0.0
var _pose_tween: Tween
var _emily: Node3D
var _emily_rest_scale := Vector3.ONE
var _emily_rest_y := 0.0
var _airborne_open := false
var _grind_toast_sent := false
var _board: MeshInstance3D
var _flip_tween: Tween
var _board_spin_y := 0.0
var _air_elapsed := 0.0


func _ready() -> void:
	var body := get_parent()
	if body and body.has_signal("grind_ended"):
		if not body.grind_ended.is_connected(notify_grind_ended):
			body.grind_ended.connect(notify_grind_ended)
	_anim = get_parent().get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _anim == null:
		_anim = AnimationPlayer.new()
		_anim.name = "AnimationPlayer"
		get_parent().add_child(_anim)
	_ensure_stub_library()
	call_deferred("_bind_emily_pose")
	if _anim.has_animation("idle"):
		_anim.play("idle")


func _unhandled_input(event: InputEvent) -> void:
	if not _airborne_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var trick: Variant = TrickClips.AIR_TRICK_KEYS.get(event.physical_keycode)
		if trick != null:
			_upgrade_air_trick(str(trick))
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_loco_clip()
	_try_wish_air_upgrade()
	_apply_board_spin(delta)
	if _combo_mult <= 1:
		return
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo_mult = 1
		_combo_score = 0
		combo_changed.emit(_combo_mult, _combo_score)


## Idle vs push clip while grounded — keeps toast/loco readable before skinned anims.
func _update_loco_clip() -> void:
	if _airborne_open or _active_trick != "":
		return
	var body := get_parent() as CharacterBody3D
	if body == null or _anim == null:
		return
	if not body.is_on_floor():
		return
	var speed := Vector3(body.velocity.x, 0.0, body.velocity.z).length()
	var want := "push" if speed > 1.5 else "idle"
	if _anim.current_animation == want:
		return
	if _anim.has_animation(want):
		_anim.play(want)


func _bind_emily_pose() -> void:
	_emily = get_parent().get_node_or_null("MeshPivot/Emily") as Node3D
	if _emily == null:
		return
	var mesh := _emily.get_node_or_null("EmilyMesh") as Node3D
	if mesh:
		_emily = mesh
	_emily_rest_scale = _emily.scale
	_emily_rest_y = _emily.position.y
	_board = get_parent().get_node_or_null("MeshPivot/Board") as MeshInstance3D
	_play_idle_pose()


func _ensure_stub_library() -> void:
	var lib_name := &""
	var lib: AnimationLibrary
	if _anim.has_animation_library(lib_name):
		lib = _anim.get_animation_library(lib_name)
	else:
		lib = AnimationLibrary.new()
		_anim.add_animation_library(lib_name, lib)
	for clip_name in TrickClips.all_stub_names():
		if lib.has_animation(clip_name):
			var existing := lib.get_animation(clip_name)
			# Upgrade empty idle/push stubs to readable tracks.
			if clip_name in ["idle", "push"] and existing.get_track_count() == 0:
				_fill_locomotion_stub(existing, clip_name)
			continue
		var anim := Animation.new()
		anim.length = float(TrickClips.STUB_LENGTHS.get(clip_name, 0.4))
		anim.loop_mode = (
			Animation.LOOP_LINEAR if clip_name in ["idle", "push"] else Animation.LOOP_NONE
		)
		if clip_name in ["idle", "push"]:
			_fill_locomotion_stub(anim, clip_name)
		lib.add_animation(clip_name, anim)


## Subtle breathe / push sway on the Emily root — readable on unskinned mesh.
## Not soft-body secondary (hair/jiggle); that waits for Skeleton3D + materials.
func _fill_locomotion_stub(anim: Animation, clip_name: String) -> void:
	if clip_name == "idle":
		anim.length = 1.8
		anim.loop_mode = Animation.LOOP_LINEAR
		var t_scale := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_scale, EMILY_SCALE_PATH)
		anim.track_set_interpolation_type(t_scale, Animation.INTERPOLATION_CUBIC)
		anim.track_insert_key(t_scale, 0.0, Vector3.ONE)
		anim.track_insert_key(t_scale, 0.9, Vector3(1.0, 0.978, 1.0))
		anim.track_insert_key(t_scale, 1.8, Vector3.ONE)
		var t_y := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_y, EMILY_Y_PATH)
		anim.track_set_interpolation_type(t_y, Animation.INTERPOLATION_CUBIC)
		anim.track_insert_key(t_y, 0.0, 0.0)
		anim.track_insert_key(t_y, 0.9, 0.012)
		anim.track_insert_key(t_y, 1.8, 0.0)
	elif clip_name == "push":
		anim.length = 0.6
		anim.loop_mode = Animation.LOOP_LINEAR
		var t_scale := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_scale, EMILY_SCALE_PATH)
		anim.track_set_interpolation_type(t_scale, Animation.INTERPOLATION_CUBIC)
		anim.track_insert_key(t_scale, 0.0, Vector3.ONE)
		anim.track_insert_key(t_scale, 0.18, Vector3(1.02, 0.96, 1.02))
		anim.track_insert_key(t_scale, 0.4, Vector3(0.99, 1.03, 0.99))
		anim.track_insert_key(t_scale, 0.6, Vector3.ONE)
		var t_y := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_y, EMILY_Y_PATH)
		anim.track_set_interpolation_type(t_y, Animation.INTERPOLATION_CUBIC)
		anim.track_insert_key(t_y, 0.0, 0.0)
		anim.track_insert_key(t_y, 0.18, -0.018)
		anim.track_insert_key(t_y, 0.4, 0.008)
		anim.track_insert_key(t_y, 0.6, 0.0)


## Player Controller / Physics may call this for ground locomotion clips.
func play_locomotion(clip_name: String) -> void:
	if clip_name not in TrickClips.LOCOMOTION:
		return
	if _airborne_open:
		return
	if clip_name == "idle":
		_play_idle_pose()
	else:
		_kill_pose_tween()
		_play_clip(clip_name)



func notify_trick_started(trick_name: String = "ollie") -> void:
	# Named grind path — Physics may still call this with "grind" / rail keys.
	if trick_name == "grind" or trick_name in ["flatbar", "stairs_hubba", "ledge", "Flatbar", "StairsA", "LongLedge", "Ledge"]:
		notify_grind_started(trick_name if trick_name != "grind" else "")
		return
	_active_trick = trick_name
	_air_elapsed = 0.0
	_airborne_open = true
	_grind_toast_sent = false
	trick_started.emit(trick_name)
	_play_clip(trick_name)
	if trick_name == "ollie":
		_play_ollie_pose()



## Physics grind enter — toast Flatbar / StairsA / LongLedge when known.
func notify_grind_started(rail_name: String = "") -> void:
	# Physics owns lock enter toast + juice; emit pretty grind for HUD/combo listeners.
	# HUD debounces identical Physics call_group + signal double-fire (~0.35s).
	if _grind_toast_sent and _active_trick == "grind":
		return
	var label := rail_name.strip_edges()
	if label == "":
		label = _resolve_nearby_street_rail()
	label = _toast_rail_label(label)
	# Last resort: still show Grind so QA sees feedback even if label miss.
	var toast := "Grind — %s" % label if label != "" else "Grind"
	_active_trick = "grind"
	_airborne_open = false
	_air_elapsed = 0.0
	_grind_toast_sent = true
	_play_clip("grind")
	# Exact QA string — HUD passes Grind* through; may upgrade bare "Grind" if we resolved a rail.
	trick_started.emit(toast)


func notify_grind_ended() -> void:
	if _active_trick == "grind":
		_active_trick = ""
	_grind_toast_sent = false



func _toast_rail_label(raw: String) -> String:
	var key := raw.strip_edges()
	if key == "":
		return ""
	var lower := key.to_lower().replace(" ", "_")
	match lower:
		"flatbar", "flat_bar":
			return "Flatbar"
		"stairsa", "stairs_a", "stairs_hubba", "hubba":
			return "StairsA"
		"longledge", "long_ledge":
			return "LongLedge"
		"ledge":
			return "Ledge"
		"grind":
			return ""
		_:
			# Already Flatbar / StairsA / etc.
			for want in ["Flatbar", "StairsA", "Ledge", "LongLedge"]:
				if key == want or key.begins_with(want):
					return want
			return key


func _resolve_nearby_street_rail() -> String:
	var body := get_parent() as Node3D
	if body == null:
		return ""
	var best := ""
	var best_d := 3.5
	for node in get_tree().get_nodes_in_group("grindable"):
		if not (node is Node3D):
			continue
		var n3 := node as Node3D
		var label := ""
		var walk: Node = n3
		while walk:
			var ns := String(walk.name)
			for want in ["Flatbar", "StairsA", "Ledge", "LongLedge"]:
				if ns == want or ns.begins_with(want):
					label = want
					break
			if label != "":
				break
			walk = walk.get_parent()
		if label == "":
			continue
		var d: float = body.global_position.distance_to(n3.global_position)
		if d < best_d:
			best_d = d
			best = label
	return best


func notify_trick_landed(trick_name: String = "") -> void:
	var name := trick_name if trick_name != "" else _active_trick
	if name == "":
		name = "ollie"
	_airborne_open = false
	_grind_toast_sent = false
	_play_clip("land")
	_play_land_pose()
	if _combo_timer > 0.0:
		_combo_mult = mini(_combo_mult + 1, 8)
	else:
		_combo_mult = 1
	var base := _base_score(name)
	var gained := base * _combo_mult
	_combo_score += gained
	_combo_timer = combo_window_sec
	trick_landed.emit(name, gained)
	combo_changed.emit(_combo_mult, _combo_score)
	_land_toast(name, gained)
	_reset_board_spin()
	_active_trick = ""
	_damp_secondary_for_catch()


func notify_bailed() -> void:
	_airborne_open = false
	_grind_toast_sent = false
	_active_trick = ""
	_combo_mult = 1
	_combo_score = 0
	_combo_timer = 0.0
	bailed.emit()
	combo_changed.emit(_combo_mult, _combo_score)
	_play_clip("idle")
	_play_idle_pose()


func _upgrade_air_trick(trick_name: String) -> void:
	if not _airborne_open:
		return
	if trick_name == _active_trick:
		return
	_active_trick = trick_name
	var body := get_parent()
	if body and body.has_method("set_air_trick"):
		body.set_air_trick(trick_name)
	trick_started.emit(trick_name)
	_play_clip(trick_name)
	_play_flip_pose(trick_name)


func _play_clip(clip_name: String) -> void:
	if _anim and _anim.has_animation(clip_name):
		_anim.play(clip_name)


func _kill_pose_tween() -> void:
	if _pose_tween and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = null

## Physics calls this so camera-readable land squash on EmilyMesh/Board isn't overwritten.
func suppress_pose_for_land(seconds: float = 0.4) -> void:
	_kill_pose_tween()
	if _anim:
		_anim.stop()
	if _emily:
		# Leave Emily at rest; Physics tweens EmilyMesh locally.
		_emily.scale = _emily_rest_scale
		_emily.position.y = _emily_rest_y
	# Resume idle after impact window.
	var tree := get_tree()
	if tree:
		tree.create_timer(seconds).timeout.connect(_play_idle_pose)


func _play_idle_pose() -> void:
	if _emily == null:
		return
	_kill_pose_tween()
	# Restore EmilyMesh rest; idle breathe is AnimationPlayer tracks on MeshPivot/Emily.
	_emily.scale = _emily_rest_scale
	_emily.position.y = _emily_rest_y
	_play_clip("idle")


func _play_ollie_pose() -> void:
	if _emily == null:
		return
	_kill_pose_tween()
	_pose_tween = create_tween()
	_pose_tween.tween_property(
		_emily, "scale", _emily_rest_scale * Vector3(1.06, 0.82, 1.06), 0.06
	)
	_pose_tween.parallel().tween_property(
		_emily, "position:y", _emily_rest_y - 0.04, 0.06
	)
	_pose_tween.tween_property(
		_emily, "scale", _emily_rest_scale * Vector3(0.96, 1.08, 0.96), 0.12
	)
	_pose_tween.parallel().tween_property(
		_emily, "position:y", _emily_rest_y + 0.02, 0.12
	)


func _play_flip_pose(trick_name: String) -> void:
	_start_board_spin(trick_name)
	if _emily == null:
		return
	_kill_pose_tween()
	var lean := 1.04
	if trick_name in ["kickflip", "heelflip", "tre"]:
		lean = 1.08
	_pose_tween = create_tween()
	_pose_tween.tween_property(
		_emily, "scale", _emily_rest_scale * Vector3(lean, 0.9, lean), 0.1
	)
	_pose_tween.tween_property(
		_emily, "scale", _emily_rest_scale * Vector3(0.98, 1.05, 0.98), 0.2
	)


func _play_land_pose() -> void:
	# Readable land squash is Physics-owned (EmilyMesh/Board). Keep toast/combo only.
	_kill_pose_tween()
	if _emily:
		_emily.scale = _emily_rest_scale
		_emily.position.y = _emily_rest_y


func _base_score(trick_name: String) -> int:
	match trick_name:
		"grind":
			return 150
		"ollie":
			return 100
		"frontside_180", "backside_180", "backside_shuv":
			return 200
		"kickflip", "heelflip":
			return 350
		"tre":
			return 500
		_:
			return 100



## Air wish (WASD) upgrades ollie → named trick so Space+steer feels like skating.
func _try_wish_air_upgrade() -> void:
	if not _airborne_open or _active_trick != "ollie":
		return
	_air_elapsed += get_process_delta_time()
	# Ignore hold-from-push for a beat so plain Space stays an ollie.
	if _air_elapsed < 0.16:
		return
	var wish := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if wish.length_squared() < 0.45:
		return
	if absf(wish.x) >= absf(wish.y):
		_upgrade_air_trick("kickflip" if wish.x > 0.0 else "heelflip")
	elif wish.y > 0.0:
		_upgrade_air_trick("frontside_180")
	else:
		_upgrade_air_trick("backside_shuv")


## Board.rotation.y only — Physics owns x (pitch) and z (lean).
func _start_board_spin(trick_name: String) -> void:
	if _board == null:
		_board = get_parent().get_node_or_null("MeshPivot/Board") as MeshInstance3D
	if _board == null:
		return
	var turns := 1.0
	match trick_name:
		"backside_shuv", "frontside_180", "backside_180":
			turns = 0.5
		"tre":
			turns = 1.5
		"kickflip", "heelflip":
			turns = 1.0
		_:
			turns = 0.0
	if turns <= 0.0:
		return
	var dir := -1.0 if trick_name in ["heelflip", "frontside_180"] else 1.0
	_board_spin_y = 0.0
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_tween = create_tween()
	_flip_tween.tween_method(_set_board_spin_y, 0.0, dir * turns * TAU, 0.35)


func _set_board_spin_y(angle: float) -> void:
	_board_spin_y = angle


func _apply_board_spin(_delta: float) -> void:
	if _board == null:
		return
	# Re-apply each frame so Physics pitch/lean lerps don't clear an unread y.
	_board.rotation.y = _board_spin_y


func _reset_board_spin() -> void:
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_tween = null
	_board_spin_y = 0.0
	if _board:
		_board.rotation.y = 0.0


func _land_toast(trick_name: String, gained: int) -> void:
	var pretty := TrickClips.pretty_name(trick_name)
	var msg := "+%d %s" % [gained, pretty]
	get_tree().call_group("hud", "show_toast", msg)


func _damp_secondary_for_catch() -> void:
	# Intensity hook for future soft motion only — no jiggle on unskinned mesh.
	var physics := get_parent()
	if physics and physics.has_method("set_secondary_intensity"):
		physics.call("set_secondary_intensity", 0.0)
