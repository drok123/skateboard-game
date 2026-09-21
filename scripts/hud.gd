extends CanvasLayer
## Minimal skate HUD: speed, combo stub, trick toast, dismissible controls hint.
## High-contrast warm daylight UI over pale concrete (#C8C4BC).

signal combo_changed(value: int)
signal toast_shown(text: String)
signal controls_hint_dismissed()

@export var player_path: NodePath = NodePath("../Player")
@export var hint_grace_sec: float = 0.75
@export var toast_hold_sec: float = 0.9
@export var toast_fade_sec: float = 0.4

var combo: int = 0

@onready var _speed_label: Label = $Margin/Root/TopRow/SpeedPanel/SpeedMargin/SpeedLabel
@onready var _combo_label: Label = $Margin/Root/TopRow/ComboPanel/ComboMargin/ComboLabel
@onready var _toast_label: Label = $Margin/Root/ToastAnchor/ToastPanel/ToastMargin/ToastLabel
@onready var _toast_panel: PanelContainer = $Margin/Root/ToastAnchor/ToastPanel
@onready var _hint_panel: PanelContainer = $Margin/Root/HintRow/HintPanel
@onready var _pause_overlay: Control = $PauseOverlay
@onready var _resume_button: Button = $PauseOverlay/Center/PausePanel/PauseMargin/VBox/ResumeButton
@onready var _quit_button: Button = $PauseOverlay/Center/PausePanel/PauseMargin/VBox/QuitButton

var _player: CharacterBody3D
var _trick_system: Node
var _tricks_connected: bool = false
var _toast_tween: Tween
var _hint_grace_done: bool = false
var _hint_dismissed: bool = false


func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_resume_button.pressed.connect(_resume_game)
	_quit_button.pressed.connect(_quit_game)
	_toast_panel.modulate.a = 0.0
	_toast_label.text = ""
	_set_combo_label(0)
	_resolve_player()
	# Short delay so the hint is readable before move/jump can dismiss it.
	get_tree().create_timer(hint_grace_sec).timeout.connect(_on_hint_grace_done)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	_try_connect_trick_system()
	_update_speed()
	_try_dismiss_hint_from_play()


func show_toast(text: String) -> void:
	## Public API — show a fading trick-name toast (lower third).
	if text.is_empty():
		return
	_toast_label.text = text
	toast_shown.emit(text)
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(toast_hold_sec)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, toast_fade_sec)


func set_combo(value: int) -> void:
	## Public API — set combo counter (stub for later trick scoring).
	combo = maxi(value, 0)
	_set_combo_label(combo)
	combo_changed.emit(combo)


func add_combo(amount: int = 1) -> void:
	## Public API — bump combo (stub).
	set_combo(combo + amount)


func reset_combo() -> void:
	## Public API — clear combo (stub).
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
	if player_path != NodePath() and has_node(player_path):
		_player = get_node(player_path) as CharacterBody3D
	if _player == null:
		var nodes := get_tree().get_nodes_in_group("player")
		if not nodes.is_empty():
			_player = nodes[0] as CharacterBody3D
	# TrickSystem may appear after player; connect once when found.
	_try_connect_trick_system()


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
	if _trick_system.has_signal("combo_changed"):
		_trick_system.combo_changed.connect(_on_trick_combo_changed)
	if _trick_system.has_signal("bailed"):
		_trick_system.bailed.connect(_on_trick_bailed)
	_tricks_connected = true


func _pretty_trick_name(trick_name: String) -> String:
	## underscores → spaces, capitalize words (kickflip → Kickflip, frontside_180 → Frontside 180).
	return trick_name.capitalize()


func _on_trick_started(trick_name: String) -> void:
	show_toast(_pretty_trick_name(trick_name))


func _on_trick_combo_changed(multiplier: int, _total_score: int) -> void:
	set_combo(multiplier)


func _on_trick_bailed() -> void:
	reset_combo()


func _update_speed() -> void:
	var speed := 0.0
	if _player:
		var h := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
		speed = h.length()
	_speed_label.text = "SPEED  %.1f" % speed


func _set_combo_label(value: int) -> void:
	_combo_label.text = "COMBO  %d" % value


func _on_hint_grace_done() -> void:
	_hint_grace_done = true


func _try_dismiss_hint_from_play() -> void:
	if _hint_dismissed or not _hint_grace_done:
		return
	var moving := (
		Input.is_action_pressed("move_forward")
		or Input.is_action_pressed("move_back")
		or Input.is_action_pressed("move_left")
		or Input.is_action_pressed("move_right")
	)
	var jumped := Input.is_action_just_pressed("jump")
	if moving or jumped:
		dismiss_controls_hint()


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

	if _hint_dismissed or not _hint_grace_done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_H or event.keycode == KEY_H:
			dismiss_controls_hint()
			get_viewport().set_input_as_handled()


func _pause_game() -> void:
	_pause_overlay.visible = true
	get_tree().paused = true


func _resume_game() -> void:
	get_tree().paused = false
	_pause_overlay.visible = false


func _quit_game() -> void:
	get_tree().quit()
