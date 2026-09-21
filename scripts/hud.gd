extends CanvasLayer
## Skate HUD: speed, line score, trick feedback, and recoverable controls help.
## High-contrast warm daylight UI over pale concrete (#C8C4BC).

signal combo_changed(value: int)
signal toast_shown(text: String)
signal controls_hint_dismissed()

@export var player_path: NodePath = NodePath("../Player")
@export var hint_grace_sec: float = 0.75
@export var toast_hold_sec: float = 0.7
@export var toast_grind_hold_sec: float = 1.0
@export var toast_debounce_sec: float = 0.35
@export var toast_fade_sec: float = 0.25
@export var toast_punch_scale: float = 1.06
@export var toast_punch_sec: float = 0.08

var combo: int = 0
var _combo_score: int = 0

@onready var _speed_label: Label = $Margin/Root/TopRow/SpeedPanel/SpeedMargin/SpeedLabel
@onready var _combo_panel: PanelContainer = $Margin/Root/TopRow/ComboPanel
@onready var _combo_label: Label = $Margin/Root/TopRow/ComboPanel/ComboMargin/ComboLabel
@onready var _goal_label: Label = $Margin/Root/GoalRow/GoalPanel/GoalMargin/GoalLabel
@onready var _toast_label: Label = $Margin/Root/ToastAnchor/ToastPanel/ToastMargin/ToastLabel
@onready var _toast_panel: PanelContainer = $Margin/Root/ToastAnchor/ToastPanel
@onready var _hint_panel: PanelContainer = $Margin/Root/HintRow/HintPanel
@onready var _pause_overlay: Control = $PauseOverlay
@onready var _resume_button: Button = $PauseOverlay/Center/PausePanel/PauseMargin/VBox/ResumeButton
@onready var _quit_button: Button = $PauseOverlay/Center/PausePanel/PauseMargin/VBox/QuitButton

var _player: Node
var _trick_system: Node
var _tricks_connected: bool = false
var _toast_tween: Tween
var _last_toast_text: String = ""
var _last_toast_msec: int = -999999
var _hint_grace_done: bool = false
var _hint_dismissed: bool = false
var _last_pos: Vector3 = Vector3.ZERO
var _have_last_pos: bool = false


func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_resume_button.pressed.connect(_resume_game)
	_quit_button.pressed.connect(_quit_game)
	_toast_panel.modulate.a = 0.0
	_toast_panel.scale = Vector2.ONE
	_toast_panel.resized.connect(_center_toast_pivot)
	_center_toast_pivot()
	_toast_label.text = ""
	_set_combo_label(0)
	set_objective("Warm-up street — Push the plaza")
	_resolve_player()
	# Short delay before accepting help toggles.
	get_tree().create_timer(hint_grace_sec).timeout.connect(_on_hint_grace_done)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	_try_connect_trick_system()
	# Controls remain available until explicitly hidden with H.


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	if not get_tree().paused:
		_update_speed(delta)


func _center_toast_pivot() -> void:
	_toast_panel.pivot_offset = _toast_panel.size * 0.5


func show_toast(text: String) -> void:
	## Public API — show a fading trick-name toast (lower third).
	if text.is_empty():
		return
	var pretty := _format_toast_text(text)
	if pretty.is_empty():
		return
	# Debounce Physics + Tricks double-fire of the same grind/trick callout.
	var now_msec := Time.get_ticks_msec()
	if pretty == _last_toast_text and (now_msec - _last_toast_msec) < int(toast_debounce_sec * 1000.0):
		return
	_last_toast_text = pretty
	_last_toast_msec = now_msec
	_toast_label.text = pretty
	toast_shown.emit(pretty)
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	# Keep punch centered even before first layout pass.
	_toast_panel.pivot_offset = _toast_panel.size * 0.5
	_toast_panel.modulate.a = 1.0
	_toast_panel.scale = Vector2.ONE
	var hold := toast_grind_hold_sec if _is_grind_toast(pretty) else toast_hold_sec
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "scale", Vector2.ONE * toast_punch_scale, toast_punch_sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.set_parallel(false)
	_toast_tween.tween_property(_toast_panel, "scale", Vector2.ONE, toast_punch_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_toast_tween.tween_interval(hold)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, toast_fade_sec)


func set_objective(text: String) -> void:
	## Public API — one-line session goal / hint (Mission Flow).
	if _goal_label == null:
		return
	_goal_label.text = text if not text.is_empty() else "Free skate"


func set_combo(value: int) -> void:
	## Public API — set combo multiplier.
	combo = maxi(value, 0)
	_set_combo_label(combo)
	combo_changed.emit(combo)


func add_combo(amount: int = 1) -> void:
	## Public API — bump combo multiplier.
	set_combo(combo + amount)


func reset_combo() -> void:
	## Public API — clear combo multiplier.
	set_combo(0)


func get_combo() -> int:
	return combo


func dismiss_controls_hint() -> void:
	## Public API / key path — hide the on-screen controls hint.
	if _hint_dismissed:
		return
	_hint_dismissed = true
	_hint_panel.visible = false
	controls_hint_dismissed.emit()


func _resolve_player() -> void:
	var candidate: Node = null
	if player_path != NodePath() and has_node(player_path):
		candidate = get_node(player_path)
	if candidate == null:
		var nodes := get_tree().get_nodes_in_group("player")
		if not nodes.is_empty():
			candidate = nodes[0]
	if candidate == null:
		var found := get_tree().root.find_child("Player", true, false)
		if found is Node:
			candidate = found
	if candidate != null and _is_speed_source(candidate):
		if _player != candidate:
			_have_last_pos = false
		_player = candidate
	else:
		_player = null
	# TrickSystem may appear after player; connect once when found.
	_try_connect_trick_system()


func _is_speed_source(node: Node) -> bool:
	## Accept CharacterBody3D or any node exposing velocity / HUD speed helpers.
	if node is CharacterBody3D:
		return true
	if node.has_method("get_speed_mph") or node.has_method("get_horizontal_speed"):
		return true
	if "velocity" in node:
		return true
	return false


func _try_connect_trick_system() -> void:
	if _tricks_connected:
		return
	if _player == null or not is_instance_valid(_player):
		return
	_trick_system = _player.get_node_or_null("TrickSystem")
	if _trick_system == null:
		return
	if _trick_system.has_signal("trick_started"):
		_trick_system.trick_started.connect(_on_trick_started)
	if _trick_system.has_signal("trick_landed"):
		_trick_system.trick_landed.connect(_on_trick_landed)
	if _trick_system.has_signal("combo_changed"):
		_trick_system.combo_changed.connect(_on_trick_combo_changed)
	if _trick_system.has_signal("bailed"):
		_trick_system.bailed.connect(_on_trick_bailed)
	_tricks_connected = true


func _format_toast_text(raw: String) -> String:
	## Skate-readable callout. Pass through Grind — Name; map rail keys; title-case trick ids.
	var t := raw.strip_edges()
	if t.is_empty():
		return ""
	# Already pretty (Physics / TrickSystem QA strings).
	if t.begins_with("Grind") or " — " in t:
		return t
	var rail := _mapped_rail_name(t)
	if rail != "":
		return "Grind — %s" % rail
	return _pretty_trick_name(t)


func _pretty_trick_name(trick_name: String) -> String:
	## underscores → spaces, capitalize words (kickflip → Kickflip, frontside_180 → Frontside 180).
	var t := trick_name.strip_edges()
	if t.is_empty():
		return ""
	# Pass through QA grind labels already formatted by TrickSystem / Physics.
	if t.begins_with("Grind") or " — " in t:
		return t
	var rail := _mapped_rail_name(t)
	if rail != "":
		return rail
	return t.capitalize()


func _mapped_rail_name(raw: String) -> String:
	## flatbar→Flatbar, stairs_hubba/StairsA→StairsA, long_ledge/LongLedge→LongLedge, ledge→Ledge.
	var key := raw.strip_edges()
	if key.is_empty():
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
		_:
			for want in ["Flatbar", "StairsA", "LongLedge", "Ledge"]:
				if key == want or key.begins_with(want):
					return want
			return ""


func _is_grind_toast(text: String) -> bool:
	return text.begins_with("Grind") or _mapped_rail_name(text) != ""


func _on_trick_started(trick_name: String) -> void:
	# If TrickSystem already emitted Grind — Flatbar, show_toast passes it through.
	show_toast(trick_name)


func _on_trick_landed(trick_name: String, score: int) -> void:
	if trick_name.is_empty():
		show_toast("Land")
		return
	# Avoid "Grind — Flatbar — Landed" double em-dash; landings use pretty trick name.
	var pretty := _pretty_trick_name(trick_name)
	if pretty.begins_with("Grind"):
		show_toast(pretty)
	else:
		show_toast("%s — Landed +%d" % [pretty, score])


func _on_trick_combo_changed(multiplier: int, total_score: int) -> void:
	_combo_score = total_score
	set_combo(multiplier if total_score > 0 else 0)


func _on_trick_bailed() -> void:
	_combo_score = 0
	reset_combo()
	show_toast("Bailed — try that line again")


func _update_speed(delta: float = 0.0) -> void:
	var speed := 0.0
	if _player and is_instance_valid(_player):
		if _player.has_method("get_speed_mph"):
			speed = float(_player.get_speed_mph())
		elif _player.has_method("get_horizontal_speed"):
			speed = float(_player.get_horizontal_speed()) * 2.15
		elif "velocity" in _player:
			var vel: Vector3 = _player.velocity
			speed = Vector3(vel.x, 0.0, vel.z).length() * 2.15
		elif _player is CharacterBody3D:
			var real: Vector3 = (_player as CharacterBody3D).get_real_velocity()
			speed = Vector3(real.x, 0.0, real.z).length() * 2.15

		# Fallback: velocity source wrong/zero but body is actually moving.
		if speed < 0.15 and delta > 0.0 and "global_position" in _player:
			var pos: Vector3 = _player.global_position
			if _have_last_pos:
				var moved := Vector3(pos.x - _last_pos.x, 0.0, pos.z - _last_pos.z).length()
				var from_pos := (moved / delta) * 2.15
				if from_pos > speed:
					speed = from_pos
			_last_pos = pos
			_have_last_pos = true
		elif "global_position" in _player:
			_last_pos = _player.global_position
			_have_last_pos = true
	# Integer mph readout — Physics scales game units for readable playtest feedback.
	_speed_label.text = "%d mph" % int(round(speed))


func _set_combo_label(value: int) -> void:
	if _combo_panel:
		_combo_panel.visible = value > 0
	if value > 0:
		_combo_label.text = "%d pts  ·  x%d" % [_combo_score, value]
	else:
		_combo_label.text = ""


func _on_hint_grace_done() -> void:
	_hint_grace_done = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if event is InputEventKey and event.echo:
			return
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()
		return

	if not _hint_grace_done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_H or event.keycode == KEY_H:
			if _hint_dismissed:
				_hint_dismissed = false
				_hint_panel.visible = true
			else:
				dismiss_controls_hint()
			get_viewport().set_input_as_handled()


func _pause_game() -> void:
	_pause_overlay.visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func _resume_game() -> void:
	get_tree().paused = false
	_pause_overlay.visible = false


func _quit_game() -> void:
	get_tree().quit()
