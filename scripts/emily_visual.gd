extends Node3D
## Playable Emily under MeshPivot — stance mesh, feet on deck, never the white T-pose.
## Capsule Rider is lean proxy only (forced hidden). Prefers skinned GLB when present; never T-pose.
##
## Node contract (see docs/character-rig.md):
##   Emily (this) → EmilyMesh (imported GLB root) → optional Skeleton3D (future)
##               → BoardSocket (Marker3D at deck contact)

const STANCE_GLB := "res://assets/characters/emily_skater_stance.glb"
const SKINNED_GLB := "res://assets/characters/emily_skater_skinned.glb"
## T-pose source kept on disk for Art — do NOT load it as the playable visual.
const TPOSE_GLB := "res://assets/characters/emily_skater.glb"
const BOARD_SOCKET_NAME := "BoardSocket"
const MESH_NAME := "EmilyMesh"

## Deck top in MeshPivot space (Board center + half thickness).
@export var deck_top_y := 0.14
@export var sole_sink := 0.02
@export var yaw_offset := PI
@export var model_scale := 0.92
## Material policy (skate. readability):
## 1) Prefer authored/textured GLB materials.
## 2) Named surfaces (skin/hair/cloth) → style-bible slot colors.
## 3) Single untextured mesh → dark athletic stand-in so she pops in sunny Venice
##    (not blue/gray mannequin; not full-body skin wash). Skin/hair wait on UV slots.
@export var body_albedo := Color(0.82, 0.64, 0.52, 1.0)  ## sun-kissed skin
@export var hair_albedo := Color(0.72, 0.62, 0.42, 1.0)  ## honey/ash blonde
@export var clothing_albedo := Color(0.10, 0.11, 0.13, 1.0)  ## dark athletic kit
@export var body_roughness := 0.72
@export var force_silhouette_block := false  ## debug: force clothing block on every surface
## Optional override; default prefers SKINNED_GLB then STANCE_GLB. Never T-pose.
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
	if board.has_method("deck_thickness"):
		half_thick = float(board.call("deck_thickness")) * 0.5
	else:
		half_thick = _deck_half_thickness(board)
	board.position = Vector3(0.0, deck_top_y - half_thick, 0.0)


func _deck_half_thickness(board: MeshInstance3D) -> float:
	## Deck mesh only (BoxMesh.size.y or AABB) — ignore child trucks/wheels.
	var mesh := board.mesh
	if mesh is BoxMesh:
		return maxf((mesh as BoxMesh).size.y * 0.5, 0.001)
	if mesh != null:
		var aabb := mesh.get_aabb()
		if aabb.size.y > 0.001:
			return aabb.size.y * 0.5
	return 0.04


func _load_emily() -> void:
	# Drop previous mesh only — keep BoardSocket marker across hot-reload.
	for child in get_children():
		if child.name == BOARD_SOCKET_NAME:
			continue
		child.queue_free()
	skeleton = null

	var path := SKINNED_GLB if FileAccess.file_exists(SKINNED_GLB) or ResourceLoader.exists(SKINNED_GLB) else STANCE_GLB
	if skinned_glb_path != "" and (FileAccess.file_exists(skinned_glb_path) or ResourceLoader.exists(skinned_glb_path)):
		path = skinned_glb_path
	var root := _import_glb(path)
	if root == null and path != STANCE_GLB:
		push_warning("Skinned Emily failed (%s) — falling back to stance" % path)
		root = _import_glb(STANCE_GLB)
	if root == null:
		push_error("Playable Emily missing stance GLB at %s — refusing T-pose fallback" % STANCE_GLB)
		_ensure_board_socket(Vector3(0.0, deck_top_y - sole_sink, 0.0))
		return

	root.name = MESH_NAME
	root.scale = Vector3.ONE * model_scale
	root.rotation.y = yaw_offset
	_apply_prototype_material(root)  # real-mats path + sunny silhouette stand-in
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
	# Mild crouch is baked in stance GLB verts only — no script pitch/Z (Physics + P0).
	root.rotation.x = 0.0


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
	## Real-materials path for Character Rigging + skate. sunny silhouette now.
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.material_override = null
		if force_silhouette_block:
			mi.material_override = _make_mat(clothing_albedo, 0.92, 0.2)
			continue
		if _apply_named_slot_materials(mi):
			continue
		if _mesh_has_authored_look(mi):
			continue
		# Single untextured sculpt: dark athletic kit reads at gameplay distance
		# under Venice sun (style bible clothing block). Not blue/gray plastic.
		mi.material_override = _make_mat(clothing_albedo, 0.9, 0.22)


func _apply_named_slot_materials(mi: MeshInstance3D) -> bool:
	## When Rigging ships multi-surface / named mats, map style-bible slots.
	if mi.mesh == null:
		return false
	var applied := false
	for surf in range(mi.mesh.get_surface_count()):
		var mat := mi.get_active_material(surf)
		var slot := _slot_from_material(mat, mi.name)
		if slot == "":
			continue
		var stand_in: StandardMaterial3D
		match slot:
			"skin":
				stand_in = _make_mat(body_albedo, body_roughness, 0.35)
			"hair":
				stand_in = _make_mat(hair_albedo, 0.78, 0.3)
			"clothing":
				stand_in = _make_mat(clothing_albedo, 0.9, 0.2)
			_:
				continue
		# Prefer textures if present; only replace flat/default slots.
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
			applied = true
			continue
		mi.set_surface_override_material(surf, stand_in)
		applied = true
	return applied


func _slot_from_material(mat: Material, node_name: String) -> String:
	var key := node_name.to_lower()
	if mat != null:
		key += " " + mat.resource_name.to_lower()
		if mat is Resource and mat.resource_path != "":
			key += " " + mat.resource_path.get_file().to_lower()
	if "hair" in key or "scalp" in key:
		return "hair"
	if "skin" in key or "body" in key or "face" in key or "arm" in key or "leg" in key:
		return "skin"
	if "cloth" in key or "shirt" in key or "pant" in key or "top" in key or "short" in key or "outfit" in key:
		return "clothing"
	return ""


func _make_mat(albedo: Color, roughness: float, specular: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.metallic_specular = specular
	return mat


func _mesh_has_authored_look(mi: MeshInstance3D) -> bool:
	if mi.mesh == null:
		return false
	for surf in range(mi.mesh.get_surface_count()):
		var mat := mi.get_active_material(surf)
		if mat == null:
			continue
		if mat is BaseMaterial3D:
			var bm := mat as BaseMaterial3D
			if bm.albedo_texture != null:
				return true
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
	# Skin inverse binds can offset the rendered vertices from the raw mesh AABB.
	# Measure the rest pose in Emily space, including the imported root's scale/yaw.
	var merged := AABB()
	var any := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		var skin := mi.skin
		var xf := global_transform.affine_inverse() * mi.global_transform
		if skel == null or skin == null:
			var bounds := _xform_aabb(xf, mi.get_aabb())
			merged = merged.merge(bounds) if any else bounds
			any = true
			continue
		var skeleton_xf := global_transform.affine_inverse() * skel.global_transform
		var binds: Array[Transform3D] = []
		for bind_index in skin.get_bind_count():
			var bone := skin.get_bind_bone(bind_index)
			if skin.get_bind_name(bind_index) != &"":
				bone = skel.find_bone(skin.get_bind_name(bind_index))
			var pose := skel.get_bone_global_pose(bone) if bone >= 0 else Transform3D.IDENTITY
			binds.append(skeleton_xf * pose * skin.get_bind_pose(bind_index))
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences: int = weights.size() / maxi(vertices.size(), 1)
			for vertex_index in vertices.size():
				var vertex := vertices[vertex_index]
				var posed := Vector3.ZERO
				var total_weight := 0.0
				for influence in influences:
					var index := vertex_index * influences + influence
					var weight := weights[index]
					if weight <= 0.0:
						continue
					posed += (binds[bones[index]] * vertex) * weight
					total_weight += weight
				if total_weight <= 0.0:
					posed = xf * vertex
				merged = merged.expand(posed) if any else AABB(posed, Vector3.ZERO)
				any = true
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
