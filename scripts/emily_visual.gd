extends Node3D
## Playable Emily under MeshPivot — stance mesh, feet on deck, never the white T-pose.
## Capsule Rider is lean proxy only (forced hidden). Skinned + textured rig replaces this later.
##
## Node contract (see docs/character-rig.md):
##   Emily (this) → EmilyMesh (imported GLB root) → optional Skeleton3D (future)
##               → BoardSocket (Marker3D at deck contact)

const STANCE_GLB := "res://assets/characters/emily_skater_stance.glb"
## T-pose source kept on disk for Art — do NOT load it as the playable visual.
const TPOSE_GLB := "res://assets/characters/emily_skater.glb"
const BOARD_SOCKET_NAME := "BoardSocket"
const MESH_NAME := "EmilyMesh"

## Deck top in MeshPivot space (Board center + half thickness).
@export var deck_top_y := 0.16
@export var sole_sink := 0.02
@export var yaw_offset := PI
@export var model_scale := 0.92
## High-contrast athletic block vs pale Venice concrete (#C8C4BC).
## Single mesh / no UVs yet — dark matte stand-in until Character Rigging splits skin/hair/clothing.
@export var body_albedo := Color(0.14, 0.15, 0.17, 1.0)
@export var body_roughness := 0.9
## Future skinned GLB path (unused until Art ships weights). Keep stance for playable.
@export_file("*.glb") var skinned_glb_path := ""

## Cached after import — null while unskinned stance mesh is live.
var skeleton: Skeleton3D = null


func _ready() -> void:
	# Kill white mannequin / capsule before any await or GLB I/O.
	_suppress_placeholders()
	_sync_board_deck()
	_load_emily()


func get_skeleton() -> Skeleton3D:
	return skeleton


func get_board_socket() -> Marker3D:
	return get_node_or_null(BOARD_SOCKET_NAME) as Marker3D


func get_emily_mesh() -> Node3D:
	return get_node_or_null(MESH_NAME) as Node3D


func _suppress_placeholders() -> void:
	var rider := get_node_or_null("../Rider") as Node3D
	if rider:
		rider.visible = false
		# Keep node for Physics lean; strip mesh so a failed load can't flash the capsule.
		if rider is MeshInstance3D:
			(rider as MeshInstance3D).mesh = null


func _sync_board_deck() -> void:
	var board := get_node_or_null("../Board") as MeshInstance3D
	if board == null:
		return
	var half_thick := 0.04
	if board.mesh is BoxMesh:
		half_thick = (board.mesh as BoxMesh).size.y * 0.5
	board.position = Vector3(0.0, deck_top_y - half_thick, 0.0)


func _load_emily() -> void:
	# Drop previous mesh only — keep BoardSocket marker across hot-reload.
	for child in get_children():
		if child.name == BOARD_SOCKET_NAME:
			continue
		child.queue_free()
	skeleton = null

	var root := _import_glb(STANCE_GLB)
	if root == null:
		push_error("Playable Emily missing stance GLB at %s — refusing T-pose fallback" % STANCE_GLB)
		_ensure_board_socket(Vector3(0.0, deck_top_y - sole_sink, 0.0))
		return

	root.name = MESH_NAME
	root.scale = Vector3.ONE * model_scale
	root.rotation.y = yaw_offset
	_apply_prototype_material(root)
	add_child(root)

	skeleton = _find_skeleton(root)
	if skeleton:
		# Future: bone-based feet / BoardSocket attach. Unskinned path stays AABB.
		pass

	var aabb := _mesh_aabb(root)
	if aabb.size == Vector3.ZERO:
		root.position = Vector3(0.0, deck_top_y, 0.0)
		_ensure_board_socket(Vector3(0.0, deck_top_y - sole_sink, 0.0))
		return
	var feet_y := aabb.position.y
	root.position = Vector3(
		-aabb.position.x - aabb.size.x * 0.5,
		(deck_top_y - sole_sink) - feet_y,
		-aabb.position.z - aabb.size.z * 0.5
	)
	# Deck contact under Emily — handoff point for future BoneAttachment.
	_ensure_board_socket(Vector3(0.0, deck_top_y - sole_sink, 0.0))


func _ensure_board_socket(local_pos: Vector3) -> void:
	var socket := get_node_or_null(BOARD_SOCKET_NAME) as Marker3D
	if socket == null:
		socket = Marker3D.new()
		socket.name = BOARD_SOCKET_NAME
		add_child(socket)
	socket.position = local_pos


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	var found := node.find_children("*", "Skeleton3D", true, false)
	if found.size() > 0:
		return found[0] as Skeleton3D
	return null


func _apply_prototype_material(node: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_albedo
	mat.roughness = body_roughness
	mat.metallic = 0.0
	mat.specular = 0.25
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi:
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _import_glb(path: String) -> Node3D:
	if path == TPOSE_GLB:
		push_warning("Refusing to load T-pose Emily as playable visual")
		return null
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		push_warning("Emily GLB missing: %s" % path)
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		push_warning("Emily GLB load failed (%s): %s" % [err, path])
		return null
	var root := doc.generate_scene(state)
	if root == null:
		push_warning("Emily GLB empty scene: %s" % path)
	return root as Node3D


func _mesh_aabb(node: Node) -> AABB:
	var merged := AABB()
	var any := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local := mi.get_aabb()
		var xf := mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != node:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var world_aabb := _xform_aabb(xf, local)
		if not any:
			merged = world_aabb
			any = true
		else:
			merged = merged.merge(world_aabb)
	return merged if any else AABB()


func _xform_aabb(xf: Transform3D, aabb: AABB) -> AABB:
	var corners: Array[Vector3] = []
	for i in 8:
		var c := aabb.position + Vector3(
			aabb.size.x if (i & 1) else 0.0,
			aabb.size.y if (i & 2) else 0.0,
			aabb.size.z if (i & 4) else 0.0
		)
		corners.append(xf * c)
	var out := AABB(corners[0], Vector3.ZERO)
	for j in range(1, 8):
		out = out.expand(corners[j])
	return out
