extends Node
## Player Controller: input map → wish + jump edge → Physics.apply_movement.
## Also drives TrickSystem ground locomotion (idle/push) per character-rig contract.
## Wish is world XZ (matches Physics API). Camera-relative steering can layer later.

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var _tricks: Node = get_parent().get_node_or_null("TrickSystem")

var _loco := ""


func _physics_process(delta: float) -> void:
	if _body == null or not _body.has_method("apply_movement"):
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Vector3(input_dir.x, 0.0, input_dir.y)
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	var jump_pressed := Input.is_action_just_pressed("jump")
	_body.apply_movement(wish, jump_pressed, delta)
	_update_locomotion(wish)


func _update_locomotion(wish: Vector3) -> void:
	if _tricks == null or not _tricks.has_method("play_locomotion"):
		return
	# Air / trick clips own the pose while airborne.
	if _body.has_method("is_on_floor") and not _body.is_on_floor():
		_loco = ""
		return
	if _body.has_method("is_grinding") and _body.is_grinding():
		_loco = ""
		return
	var next := "push" if wish.length_squared() > 0.04 else "idle"
	if next == _loco:
		return
	_loco = next
	_tricks.play_locomotion(next)
