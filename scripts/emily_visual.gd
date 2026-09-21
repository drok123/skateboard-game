extends Node3D
## Static emily_skater.glb under MeshPivot. Capsule Rider stays as Physics lean proxy (hidden).
## Replace with skinned import + BoneAttachments when Art ships a weighted rig.

const GLB_PATH := "res://assets/characters/emily_skater.glb"

## Model AABB is roughly Y [-0.95, 0.95]; lift so feet sit near the deck.
@export var foot_y := 0.12
@export var model_min_y := -0.95
## Many exports face -Z; our MeshPivot yaw faces +Z wish.
@export var yaw_offset := PI


func _ready() -> void:
	var rider := get_node_or_null("../Rider") as Node3D
	if rider:
		rider.visible = false
	_load_emily()


func _load_emily() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(GLB_PATH, state)
	if err != OK:
		push_warning("Emily GLB load failed (%s): %s" % [err, GLB_PATH])
		var rider := get_node_or_null("../Rider") as Node3D
		if rider:
			rider.visible = true
		return
	var root := doc.generate_scene(state)
	if root == null:
		push_warning("Emily GLB generated an empty scene")
		return
	root.name = "EmilyMesh"
	root.position = Vector3(0.0, foot_y - model_min_y, 0.0)
	root.rotation.y = yaw_offset
	add_child(root)
