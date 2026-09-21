extends Node
## Board-relative keyboard controls and a standard gamepad fallback.

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
		var stick_y := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		if absf(stick_x) > 0.18:
			steer = signf(stick_x) * (absf(stick_x) - 0.18) / 0.82
		push = maxf(push, maxf(0.0, (-stick_y - 0.18) / 0.82))
		brake = maxf(brake, maxf(0.0, (stick_y - 0.18) / 0.82))
		pad_jump = Input.is_joy_button_pressed(device, JOY_BUTTON_A)
		reset_pressed = reset_pressed or Input.is_joy_button_pressed(device, JOY_BUTTON_BACK)
	if reset_pressed and not _reset_held:
		_body.reset_to_spawn()
	_reset_held = reset_pressed
	var jump_pressed := Input.is_action_just_pressed("jump") or (pad_jump and not _pad_jump_held)
	_pad_jump_held = pad_jump
	_body.apply_riding_input(steer, push, brake, jump_pressed, delta)
