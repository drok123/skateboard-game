extends Node
## Board-relative controls. Left stick only carves; face buttons push/brake so
## throttle never fights steering. Right stick remains reserved for tricks.

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D
var _pad_jump_held := false
var _reset_held := false


func _physics_process(delta: float) -> void:
	if _body == null or not _body.has_method("apply_riding_input"):
		return
	var steer := Input.get_axis("move_left", "move_right")
	var push := Input.get_action_strength("move_forward")
	var brake := Input.get_action_strength("move_back")
	var pad_jump := false
	var reset_pressed := Input.is_physical_key_pressed(KEY_R)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var device := pads[0]
		var stick_x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		steer = _shaped_axis(stick_x)
		# Xbox labels: X pushes, B foot-brakes/reverses, A pops. The left
		# trigger adds analog braking without claiming either trick stick.
		push = maxf(push, 1.0 if Input.is_joy_button_pressed(device, JOY_BUTTON_X) else 0.0)
		brake = maxf(brake, 1.0 if Input.is_joy_button_pressed(device, JOY_BUTTON_B) else 0.0)
		var trigger := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)
		if trigger > 0.05:
			brake = maxf(brake, trigger)
		pad_jump = Input.is_joy_button_pressed(device, JOY_BUTTON_A)
		reset_pressed = reset_pressed or Input.is_joy_button_pressed(device, JOY_BUTTON_BACK)
	if reset_pressed and not _reset_held:
		_body.reset_to_spawn()
	_reset_held = reset_pressed
	var jump_pressed := Input.is_action_just_pressed("jump") or (pad_jump and not _pad_jump_held)
	_pad_jump_held = pad_jump
	_body.apply_riding_input(steer, push, brake, jump_pressed, delta)


func _shaped_axis(value: float) -> float:
	const DEADZONE := 0.16
	if absf(value) <= DEADZONE:
		return 0.0
	var normalized := (absf(value) - DEADZONE) / (1.0 - DEADZONE)
	# Softer around center for line corrections, full authority at the edge.
	return signf(value) * pow(normalized, 1.35)
