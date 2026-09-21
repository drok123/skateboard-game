extends Node
## Lightweight Venice teach-line goals (G1–G4). Soft prompts only — free skate always OK.

signal goal_changed(goal_id: String, title: String, hint: String)
signal goal_cleared(goal_id: String, title: String)
signal session_complete()

const GOAL_ORDER := ["G1", "G2", "G3", "G4"]

const GOALS := {
	"G1": {
		"title": "Warm-up street",
		"hint": "Push the plaza — grind or ollie the flatbar / hubba",
	},
	"G2": {
		"title": "Bowl pump",
		"hint": "Drop the snake bowls, carve, exit back to street with speed",
	},
	"G3": {
		"title": "Hero loop",
		"hint": "Snake into the clover — carve a full loop",
	},
	"G4": {
		"title": "Stair gap",
		"hint": "Carry speed into stairs B and clear the set",
	},
}

const SNAKE_DWELL_SEC := 1.2
const CLOVER_DWELL_SEC := 2.5
const EXIT_SPEED_MIN := 4.0
const GAP_SPEED_MIN := 5.5
const GRIND_PROXIMITY := 1.8

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
		# Seed overlap if player already inside.
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


func _horizontal_speed() -> float:
	if _player == null:
		return 0.0
	return Vector3(_player.velocity.x, 0.0, _player.velocity.z).length()


func _touching_grindable() -> bool:
	if _player == null:
		return false
	# Prefer slide contacts (fat grind volumes from Props).
	for i in _player.get_slide_collision_count():
		var col := _player.get_slide_collision(i)
		var collider := col.get_collider()
		if collider is Node and (collider as Node).is_in_group("grindable"):
			return true
	# Proximity fallback while grind physics is still light.
	for node in get_tree().get_nodes_in_group("grindable"):
		if node is Node3D:
			var n3 := node as Node3D
			var d := _player.global_position.distance_to(n3.global_position)
			if d <= GRIND_PROXIMITY and _in_street:
				return true
	return false


func _evaluate_active_goal() -> void:
	var id := get_active_goal_id()
	if id.is_empty():
		return
	match id:
		"G1":
			if _in_street and _touching_grindable():
				_advance("cleared")
		"G2":
			if _g2_pumped and _in_street and _horizontal_speed() >= EXIT_SPEED_MIN:
				_advance("cleared")
		"G3":
			if _visited_snake and _in_clover and _clover_time >= CLOVER_DWELL_SEC:
				_advance("cleared")
		"G4":
			_try_stair_gap()


func _try_stair_gap() -> void:
	var speed := _horizontal_speed()
	if _in_stairs_b and speed >= GAP_SPEED_MIN:
		_gap_armed = true
		_gap_arm_timer = 2.0
	if _gap_armed and not _in_stairs_b and _player.is_on_floor() and speed >= 2.0:
		_gap_armed = false
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
		get_tree().call_group("hud", "set_objective", "Free skate — Venice lines unlocked")
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
