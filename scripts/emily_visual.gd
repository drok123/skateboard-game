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
@export var deck_top_y := 0.14
@export var sole_sink := 0.02
@export var yaw_offset := PI
@export var model_scale := 0.92
## Material policy (P0): prefer imported GLB materials; else style-bible sun-kissed skin.
## Dark athletic block only when force_silhouette_block is true (debug / extreme washout).
@export var body_albedo := Color(0.82, 0.64, 0.52, 1.0)  ## sun-kissed skin stand-in
@export var hair_albedo := Color(0.72, 0.62, 0.42, 1.0)  ## honey/ash blonde (future slots)
@export var clothing_albedo := Color(0.14, 0.15, 0.17, 1.0)  ## dark athletic (future slots)
@export var body_roughness := 0.72
@export var force_silhouette_block := false
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
		root.rotation.x = 0.0
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
	# Upright at rest (P0: no back lean). Tiny forward offset for stance silhouette only.
	root.rotation.x = deg_to_rad(-2.0)  # slight forward crouch, never back
	root.position.z += 0.02


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
	## Prefer real GLB materials. Only invent a style-bible stand-in when the mesh
	## has no textured / authored albedo (current stance GLB is untextured).
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.material_override = null
		if force_silhouette_block:
			mi.material_override = _make_mat(clothing_albedo, 0.9, 0.2)
			continue
		if _mesh_has_authored_look(mi):
			continue
		# Untextured single-material sculpt → sun-kissed skin (not blue mannequin).
		mi.material_override = _make_mat(body_albedo, body_roughness, 0.35)


func _make_mat(albedo: Color, roughness: float, specular: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.specular = specular
	return mat


func _mesh_has_authored_look(mi: MeshInstance3D) -> bool:
	if mi.mesh == null:
		return false
	# Any surface material with a texture or non-default named look counts as authored.
	for surf in range(mi.mesh.get_surface_count()):
		var mat := mi.get_active_material(surf)
		if mat == null:
			continue
		if mat is BaseMaterial3D:
			var bm := mat as BaseMaterial3D
			if bm.albedo_texture != null:
				return true
			# Explicit non-white albedo from the GLB counts (future textured exports).
			var c := bm.albedo_color
			var near_white := c.r > 0.95 and c.g > 0.95 and c.b > 0.95
			var near_gray := absf(c.r - c.g) < 0.02 and absf(c.g - c.b) < 0.02 and c.r > 0.45 and c.r < 0.75
			if not near_white and not near_gray:
				return true
	return false


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
