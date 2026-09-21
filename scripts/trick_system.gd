extends Node
## Owns AnimationPlayer stub clips + score/combo signal surface.
## Physics fires trick_started / trick_landed / bailed; this plays matching clips
## and (later) drives board-flip tweens + secondary-motion damp on catch.

signal trick_started(trick_name: String)
signal trick_landed(trick_name: String, score: int)
signal combo_changed(multiplier: int, total_score: int)
signal bailed()

const BOARD_PATH := ^"../MeshPivot/Board"

@export var combo_window_sec := 2.0

var _anim: AnimationPlayer
var _active_trick := ""
var _combo_mult := 1
var _combo_score := 0
var _combo_timer := 0.0


func _ready() -> void:
	_anim = get_parent().get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _anim == null:
		_anim = AnimationPlayer.new()
		_anim.name = "AnimationPlayer"
		get_parent().add_child(_anim)
	_ensure_stub_library()
	if _anim.has_animation("idle"):
		_anim.play("idle")


func _process(delta: float) -> void:
	if _combo_mult <= 1:
		return
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo_mult = 1
		_combo_score = 0
		combo_changed.emit(_combo_mult, _combo_score)


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
			continue
		var anim := Animation.new()
		anim.length = float(TrickClips.STUB_LENGTHS.get(clip_name, 0.4))
		anim.loop_mode = (
			Animation.LOOP_LINEAR if clip_name in ["idle", "push"] else Animation.LOOP_NONE
		)
		lib.add_animation(clip_name, anim)


## Call from Physics on ollie pop (or when a named trick begins).
func notify_trick_started(trick_name: String = "ollie") -> void:
	_active_trick = trick_name
	trick_started.emit(trick_name)
	_play_clip(trick_name)


## Call from Physics on successful land after an air trick.
func notify_trick_landed(trick_name: String = "") -> void:
	var name := trick_name if trick_name != "" else _active_trick
	if name == "":
		name = "ollie"
	_play_clip("land")
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
	_active_trick = ""
	# Hook for Physics secondary-motion damp (no-op until skinned springs exist).
	_damp_secondary_for_catch()


func notify_bailed() -> void:
	_active_trick = ""
	_combo_mult = 1
	_combo_score = 0
	_combo_timer = 0.0
	bailed.emit()
	combo_changed.emit(_combo_mult, _combo_score)
	_play_clip("idle")


func _play_clip(clip_name: String) -> void:
	if _anim == null:
		return
	if _anim.has_animation(clip_name):
		_anim.play(clip_name)


func _base_score(trick_name: String) -> int:
	match trick_name:
		"ollie":
			return 100
		"frontside_180", "backside_180", "backside_shuv":
			return 200
		"kickflip", "heelflip":
			return 350
		_:
			return 100


func _damp_secondary_for_catch() -> void:
	var physics := get_parent()
	if physics and physics.has_method("set_secondary_intensity"):
		physics.call("set_secondary_intensity", 0.0)
