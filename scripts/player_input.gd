extends Node
## Player Controller: input map → wish + jump edge → Physics.apply_movement.
## Wish is world XZ (matches Physics API). Camera-relative steering can layer later.

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


func _physics_process(delta: float) -> void:
	if _body == null or not _body.has_method("apply_movement"):
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Vector3(input_dir.x, 0.0, input_dir.y)
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	var jump_pressed := Input.is_action_just_pressed("jump")
	_body.apply_movement(wish, jump_pressed, delta)
