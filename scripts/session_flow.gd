extends Node
## Lightweight Venice teach-line goals (G1–G4). Soft prompts only — free skate always OK.

signal goal_changed(goal_id: String, title: String, hint: String)
signal goal_cleared(goal_id: String, title: String)
signal session_complete()

const GOAL_ORDER := ["G1", "G2", "G3", "G4"]

# Crisp HUD copy — short title + one action.
const GOALS := {
	"G1": {
		"title": "Warm-up",
		"hint": "Grind the flatbar or stairs hubba",
	},
	"G2": {
		"title": "Bowl pump",
		"hint": "Carve the snake, exit to street with speed",
	},
	"G3": {
		"title": "Hero loop",
		"hint": "Transfer into the clover and carve a loop",
	},
	"G4": {
		"title": "Stair gap",
		"hint": "Hit stairs B with speed and land past them",
	},
}

# Tuned for beta reliability (soft clears, not sticky).
const SNAKE_DWELL_SEC := 1.0
const CLOVER_DWELL_SEC := 1.8
const EXIT_SPEED_MIN := 3.5
const GAP_SPEED_MIN := 4.5
const GAP_LAND_SPEED_MIN := 1.5
const GAP_ARM_SEC := 2.5
const STREET_GRIND_PROXIMITY := 2.2

## Plaza grind props only — ignore west planter / bowl coping for G1.
const STREET_GRIND_NAMES := ["Flatbar", "StairsA", "Ledge", "LongLedge"]

var _player: CharacterBody3D
var _active_index: int = 0
var _complete: bool = false

var _in_street := false
var _in_snake := false
var _in_clover := false
var _in_stairs_b := false

var _snake_time := 0.0
var _clover_time := 0.0
var _visited_snake := false
var _g2_pumped := false

var _gap_armed := false
var _gap_arm_timer := 0.0
var _gap_was_airborne := false

var _zones_wired := false


func _ready() -> void:
	add_to_group("session_flow")
	set_physics_process(true)
	call_deferred("_boot")


func _boot() -> void:
	_resolve_player()
	_wire_zones()
	_refresh_hud()


func _physics_process(delta: float) -> void:
	if _complete:
		return
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
		return
	if not _zones_wired:
		_wire_zones()
		if not _zones_wired:
			return

	_update_zone_dwell(delta)
	_tick_gap_arm(delta)
	_evaluate_active_goal()


func get_active_goal_id() -> String:
	if _complete or _active_index >= GOAL_ORDER.size():
		return ""
	return GOAL_ORDER[_active_index]


func skip_goal() -> void:
	## Free skate / skip — advance without forcing a line.
	if _complete:
		return
	_advance("skipped")


func _resolve_player() -> void:
	var nodes := get_tree().get_nodes_in_group("player")
	if not nodes.is_empty():
		_player = nodes[0] as CharacterBody3D


func _wire_zones() -> void:
	var names := ["zone_street", "zone_snake", "zone_clover", "zone_stairs_b"]
	var found := 0
	for zone_name in names:
		var nodes := get_tree().get_nodes_in_group(zone_name)
		if nodes.is_empty():
			continue
		var area := nodes[0] as Area3D
		if area == null:
			continue
		# Player lives on collision_layer 2.
		area.collision_mask = area.collision_mask | 2
		area.monitoring = true
		if not area.body_entered.is_connected(_on_zone_body_entered.bind(zone_name)):
			area.body_entered.connect(_on_zone_body_entered.bind(zone_name))
		if not area.body_exited.is_connected(_on_zone_body_exited.bind(zone_name)):
			area.body_exited.connect(_on_zone_body_exited.bind(zone_name))
		if _player and area.overlaps_body(_player):
			_set_zone(zone_name, true)
		found += 1
	_zones_wired = found == names.size()


func _on_zone_body_entered(body: Node, zone_name: String) -> void:
	if body != _player:
		return
	_set_zone(zone_name, true)


func _on_zone_body_exited(body: Node, zone_name: String) -> void:
	if body != _player:
		return
	_set_zone(zone_name, false)


func _set_zone(zone_name: String, inside: bool) -> void:
	match zone_name:
		"zone_street":
			_in_street = inside
		"zone_snake":
			_in_snake = inside
			if inside:
				_visited_snake = true
			else:
				_snake_time = 0.0
		"zone_clover":
			_in_clover = inside
			if not inside:
				_clover_time = 0.0
		"zone_stairs_b":
			_in_stairs_b = inside


func _update_zone_dwell(delta: float) -> void:
	if _in_snake:
		_snake_time += delta
		if _snake_time >= SNAKE_DWELL_SEC:
			_g2_pumped = true
	if _in_clover:
		_clover_time += delta


func _tick_gap_arm(delta: float) -> void:
	if _gap_armed:
		_gap_arm_timer -= delta
		if _gap_arm_timer <= 0.0:
			_gap_armed = false
			_gap_was_airborne = false


func _horizontal_speed() -> float:
	if _player == null:
		return 0.0
	return Vector3(_player.velocity.x, 0.0, _player.velocity.z).length()


func _is_street_grind_prop(node: Node) -> bool:
	if node == null:
		return false
	# Bowl coping is not the warm-up plaza line.
	if node.is_in_group("coping"):
		return false
	var n := node
	while n:
		var name_str := String(n.name)
		for want in STREET_GRIND_NAMES:
			if name_str == want or name_str.begins_with(want):
				return true
		n = n.get_parent()
	return false


func _touching_street_grindable() -> bool:
	if _player == null or not _in_street:
		return false
	# Physics grind lock on a plaza rail = G1 clear (toast path separate).
	if _player.has_method("is_grinding") and _player.call("is_grinding"):
		if _player.has_method("get_grind_rail"):
			var rail := str(_player.call("get_grind_rail"))
			if rail != "" and _name_is_street_rail(rail):
				return true
		# Locked while in street zone — soft beta clear.
		return true
	# Prefer fat slide contacts from Props.
	for i in _player.get_slide_collision_count():
		var col := _player.get_slide_collision(i)
		var collider = col.get_collider()
		if collider is Node and (collider as Node).is_in_group("grindable"):
			if _is_street_grind_prop(collider as Node):
				return true
	# Closest-point proximity (long Flatbar ends miss center-distance).
	for node in get_tree().get_nodes_in_group("grindable"):
		if node is Node3D and _is_street_grind_prop(node):
			if _xz_near_grind_box(node as Node3D, STREET_GRIND_PROXIMITY):
				return true
	return false


func _name_is_street_rail(name_str: String) -> bool:
	for want in STREET_GRIND_NAMES:
		if name_str == want or name_str.begins_with(want):
			return true
	return false


func _xz_near_grind_box(n3: Node3D, max_d: float) -> bool:
	var best := INF
	var feet := _player.global_position
	for cs in n3.find_children("*", "CollisionShape3D", true, false):
		if not (cs is CollisionShape3D):
			continue
		var shape_node := cs as CollisionShape3D
		if shape_node.shape == null or not (shape_node.shape is BoxShape3D):
			continue
		var box := shape_node.shape as BoxShape3D
		var xf := shape_node.global_transform
		var local := xf.affine_inverse() * feet
		var half := box.size * 0.5
		var clamped := Vector3(
			clampf(local.x, -half.x, half.x),
			clampf(local.y, -half.y, half.y),
			clampf(local.z, -half.z, half.z)
		)
		var world := xf * clamped
		var d := Vector3(feet.x - world.x, 0.0, feet.z - world.z).length()
		var top := xf * Vector3(clamped.x, half.y, clamped.z)
		if absf(feet.y - top.y) > 1.6:
			continue
		best = minf(best, d)
	if best == INF:
		best = Vector3(feet.x - n3.global_position.x, 0.0, feet.z - n3.global_position.z).length()
	return best <= max_d


func _evaluate_active_goal() -> void:
	var id := get_active_goal_id()
	if id.is_empty():
		return
	match id:
		"G1":
			if _touching_street_grindable():
				_advance("cleared")
		"G2":
			if _g2_pumped and _in_street and not _in_snake and _horizontal_speed() >= EXIT_SPEED_MIN:
				_advance("cleared")
		"G3":
			if _visited_snake and _in_clover and _clover_time >= CLOVER_DWELL_SEC:
				_advance("cleared")
		"G4":
			_try_stair_gap()


func _try_stair_gap() -> void:
	var speed := _horizontal_speed()
	var airborne := _player != null and not _player.is_on_floor()
	# Arm on a committed pass through stairs B (speed, preferably air).
	if _in_stairs_b and speed >= GAP_SPEED_MIN:
		_gap_armed = true
		_gap_arm_timer = GAP_ARM_SEC
		if airborne:
			_gap_was_airborne = true
	# Clear: leave the volume and land flat with leftover speed.
	if _gap_armed and not _in_stairs_b and _player.is_on_floor() and speed >= GAP_LAND_SPEED_MIN:
		# Prefer a real gap (was airborne) but allow fast roll-clear for soft beta.
		if _gap_was_airborne or speed >= GAP_SPEED_MIN:
			_gap_armed = false
			_gap_was_airborne = false
			_advance("cleared")


func _advance(_reason: String) -> void:
	var cleared_id := get_active_goal_id()
	if cleared_id.is_empty():
		return
	var cleared_title: String = GOALS[cleared_id]["title"]
	goal_cleared.emit(cleared_id, cleared_title)
	get_tree().call_group("hud", "show_toast", "Nice — %s" % cleared_title)

	_active_index += 1
	if _active_index >= GOAL_ORDER.size():
		_complete = true
		session_complete.emit()
		get_tree().call_group("hud", "set_objective", "Free skate — lines unlocked")
		get_tree().call_group("hud", "show_toast", "Session clear — free skate")
		return

	_refresh_hud()
	var next_id := get_active_goal_id()
	var next_title: String = GOALS[next_id]["title"]
	get_tree().call_group("hud", "show_toast", "Next: %s" % next_title)


func _refresh_hud() -> void:
	var id := get_active_goal_id()
	if id.is_empty():
		get_tree().call_group("hud", "set_objective", "Free skate")
		return
	var title: String = GOALS[id]["title"]
	var hint: String = GOALS[id]["hint"]
	goal_changed.emit(id, title, hint)
	get_tree().call_group("hud", "set_objective", "%s — %s" % [title, hint])
