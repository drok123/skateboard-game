extends Node3D
## Venice Beach skatepark blockout: street plaza N, snake bowls CW, clover SE.

const StairsSetScene := preload("res://scenes/parks/modules/stairs_set.tscn")
const LedgeScene := preload("res://scenes/parks/modules/ledge.tscn")
const FlatbarScene := preload("res://scenes/parks/modules/flatbar.tscn")
const BankQpScene := preload("res://scenes/parks/modules/bank_qp.tscn")
const BowlSegmentScene := preload("res://scenes/parks/modules/bowl_segment.tscn")
const CopingEdgeScene := preload("res://scenes/parks/modules/coping_edge.tscn")
const PerimeterWallScene := preload("res://scenes/parks/modules/perimeter_wall.tscn")
const PlanterRoundScene := preload("res://scenes/parks/modules/planter_round.tscn")

## Playable concrete pad (X × Z). Deck top at Y = 0.
const DECK_SIZE := Vector2(48.0, 40.0)
const WALL_H := 1.1
const SPAWN_POS := Vector3(-18.0, 1.2, 4.0)


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_build_sand_apron()
	_build_deck_plates()
	_build_perimeter()
	_build_street_plaza()
	_build_snake_bowls()
	_build_clover_bowl()
	_build_palms()
	_build_zones()
	# Spawn marker (Mission Flow / debug)
	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.position = SPAWN_POS
	add_child(spawn)


func _build_sand_apron() -> void:
	# Outside pad + visible under bowl openings (~8 m beyond walls).
	PropKit.add_box(
		self,
		Vector3(DECK_SIZE.x + 16.0, 0.3, DECK_SIZE.y + 16.0),
		Vector3(0.0, -0.35, 0.0),
		PropKit.COLOR_SAND,
		PackedStringArray(["out_of_bounds"])
	)


func _build_deck_plates() -> void:
	# Concrete deck as plates that leave holes for snake (CW) and clover (SE).
	# Full extents: x -24..24, z -20..20. Deck thickness 0.4, top at Y=0.
	# Keep plates coarse — no lip-ring spam; coping lips seal the rim.
	var plates: Array = [
		# North street plaza
		[Vector3(48.0, 0.4, 14.0), Vector3(0.0, -0.2, 13.0)],
		# South strip (south of clover hole)
		[Vector3(48.0, 0.4, 5.0), Vector3(0.0, -0.2, -17.5)],
		# West entrance / west of snake — covers spawn (-18, ~0, 4)
		[Vector3(11.0, 0.4, 22.0), Vector3(-18.5, -0.2, -4.0)],
		# East strip (east of clover)
		[Vector3(8.0, 0.4, 22.0), Vector3(20.0, -0.2, -4.0)],
		# Bridge between snake and clover (east of snake B)
		[Vector3(4.0, 0.4, 12.0), Vector3(4.0, -0.2, -1.0)],
		# North of clover / east of snake
		[Vector3(12.0, 0.4, 8.0), Vector3(10.0, -0.2, 1.0)],
		# South-west apron (west of clover, south of snake)
		[Vector3(14.0, 0.4, 7.0), Vector3(-6.0, -0.2, -11.5)],
		# Far NE corner fill
		[Vector3(10.0, 0.4, 8.0), Vector3(14.0, -0.2, 6.0)],
		# Plaza→snake flat (north of snake lips, south of plaza plate)
		[Vector3(14.0, 0.4, 2.5), Vector3(-5.0, -0.2, 5.5)],
		# Snake→clover teach-line flat
		[Vector3(6.0, 0.4, 4.0), Vector3(2.5, -0.2, -6.0)],
		# Clover east apron
		[Vector3(3.0, 0.4, 10.0), Vector3(16.0, -0.2, -10.0)],
		# Clover south fill
		[Vector3(10.0, 0.4, 2.5), Vector3(8.0, -0.2, -15.0)],
	]
	for p in plates:
		PropKit.add_box(
			self,
			p[0],
			p[1],
			PropKit.COLOR_CONCRETE,
			PackedStringArray(["deck"])
		)


func _build_perimeter() -> void:
	# Rounded-rect ring of wall segments. Gap on west for entrance (~z 1..7).
	var half_x := DECK_SIZE.x * 0.5  # 24
	var half_z := DECK_SIZE.y * 0.5  # 20
	var seg := 4.0
	# North wall (z = +half_z)
	_wall_run(Vector3(0.0, 0.0, half_z), half_x * 2.0, 0.0, seg)
	# South wall (z = -half_z)
	_wall_run(Vector3(0.0, 0.0, -half_z), half_x * 2.0, PI, seg)
	# East wall (x = +half_x)
	_wall_run(Vector3(half_x, 0.0, 0.0), half_z * 2.0, -PI * 0.5, seg)
	# West wall with entrance gap around z=4
	_wall_run_west_with_gap(half_x, half_z, seg)


func _wall_run(center: Vector3, total_len: float, yaw: float, seg_len: float) -> void:
	var n := maxi(int(ceil(total_len / seg_len)), 1)
	var actual := total_len / float(n)
	var axis := Vector3(cos(yaw), 0.0, -sin(yaw))  # along-wall direction
	var start := center - axis * (total_len * 0.5)
	for i in range(n):
		var t := (float(i) + 0.5) / float(n)
		var pos := start + axis * (total_len * t)
		var w = PerimeterWallScene.instantiate()
		w.length = actual
		w.wall_height = WALL_H
		w.rail_grindable = false
		w.position = pos
		w.rotation.y = yaw
		add_child(w)


func _wall_run_west_with_gap(half_x: float, half_z: float, seg_len: float) -> void:
	# West face at x = -half_x, along +Z from -half_z to +half_z. Gap z 1..7.
	var x := -half_x
	var spans: Array = [
		[-half_z, 1.0],
		[7.0, half_z],
	]
	for span in spans:
		var z0: float = span[0]
		var z1: float = span[1]
		var total := z1 - z0
		if total < 0.5:
			continue
		var n := maxi(int(ceil(total / seg_len)), 1)
		var actual := total / float(n)
		for i in range(n):
			var z := z0 + actual * (float(i) + 0.5)
			var w = PerimeterWallScene.instantiate()
			w.length = actual
			w.wall_height = WALL_H
			w.rail_grindable = false
			w.position = Vector3(x, 0.0, z)
			w.rotation.y = PI * 0.5  # wall faces outward (-X)
			add_child(w)


func _build_street_plaza() -> void:
	# North plaza street obstacles.
	# Stairs A — 3-step + hubba (west of plaza)
	var stairs_a = StairsSetScene.instantiate()
	stairs_a.name = "StairsA"
	stairs_a.step_count = 3
	stairs_a.width = 3.0
	stairs_a.with_hubba = true
	stairs_a.with_handrail = false
	stairs_a.position = Vector3(-10.0, 0.0, 10.0)
	stairs_a.rotation.y = 0.0  # climb toward +Z (north)
	add_child(stairs_a)

	# Stairs B — 4–5 set + handrail
	var stairs_b = StairsSetScene.instantiate()
	stairs_b.name = "StairsB"
	stairs_b.step_count = 5
	stairs_b.width = 3.5
	stairs_b.with_hubba = false
	stairs_b.with_handrail = true
	stairs_b.position = Vector3(-4.0, 0.0, 10.0)
	stairs_b.rotation.y = 0.0
	add_child(stairs_b)

	# Long ledge / planter
	var ledge = LedgeScene.instantiate()
	ledge.name = "LongLedge"
	ledge.length = 7.0
	ledge.depth = 0.45
	ledge.height = 0.55
	ledge.position = Vector3(4.0, 0.0, 13.5)
	ledge.rotation.y = 0.0  # along +X
	add_child(ledge)

	# Flatbar
	var bar = FlatbarScene.instantiate()
	bar.name = "Flatbar"
	bar.length = 5.0
	bar.height = 0.45
	bar.position = Vector3(11.0, 0.0, 11.0)
	add_child(bar)

	# Small bank / QP feeding back to flat (faces west into plaza)
	var bank = BankQpScene.instantiate()
	bank.name = "StreetBank"
	bank.width = 4.0
	bank.height = 1.2
	bank.angle_deg = 30.0
	bank.position = Vector3(16.0, 0.0, 8.0)
	bank.rotation.y = PI * 0.5  # slope along local +Z → world -X (into plaza)
	add_child(bank)

	# Flow: plaza → snake (south into bowls)
	var into_snake = BankQpScene.instantiate()
	into_snake.name = "PlazaToSnakeBank"
	into_snake.width = 5.0
	into_snake.height = 1.0
	into_snake.angle_deg = 26.0
	into_snake.position = Vector3(-6.0, 0.0, 6.2)
	into_snake.rotation.y = PI  # slope along local +Z → world -Z (into snake)
	add_child(into_snake)

	# Short N–S guide ledge marking the street→snake line
	var guide = LedgeScene.instantiate()
	guide.name = "FlowGuideLedge"
	guide.length = 3.5
	guide.depth = 0.35
	guide.height = 0.4
	guide.position = Vector3(1.0, 0.0, 7.0)
	guide.rotation.y = PI * 0.5  # along +Z
	add_child(guide)


func _build_snake_bowls() -> void:
	# 2 linked shallow kidneys, center-west. Depth ~-1.6..-2.2.
	var snake := Node3D.new()
	snake.name = "SnakeBowls"
	add_child(snake)

	var a_c := Vector3(-8.0, 0.0, -1.0)
	var b_c := Vector3(-2.0, 0.0, 1.5)
	# Bowl A (west, shallower) — skip east arc into B
	_place_bowl_cluster(snake, a_c, 4.5, 1.8, b_c)
	# Bowl B (east of A) — skip west arc into A
	_place_bowl_cluster(snake, b_c, 4.0, 2.1, a_c)
	# Small connector hip / saddle between A and B
	PropKit.add_box(
		snake,
		Vector3(2.5, 0.35, 3.0),
		Vector3(-5.0, -1.0, 0.2),
		PropKit.COLOR_CONCRETE,
		PackedStringArray(["bowl", "deck"])
	)
	# Transition bank toward clover (SE)
	var feed = BankQpScene.instantiate()
	feed.name = "SnakeToCloverBank"
	feed.width = 4.0
	feed.height = 1.4
	feed.angle_deg = 28.0
	feed.position = Vector3(1.0, -0.15, -3.5)
	feed.rotation.y = -PI * 0.35
	snake.add_child(feed)


func _place_bowl_cluster(
	parent: Node3D,
	center: Vector3,
	radius: float,
	depth: float,
	sibling_center: Vector3 = Vector3.INF
) -> void:
	# Four ~90° arcs; skip the one facing a sibling lobe so peanuts don't explode.
	var arcs: Array = [0.0, PI * 0.5, PI, PI * 1.5]
	for yaw in arcs:
		if sibling_center != Vector3.INF:
			# Outward mid-arc direction in XZ (matches bowl_segment polar).
			var outward := Vector3(sin(yaw), 0.0, -cos(yaw))
			var to_sib := sibling_center - center
			to_sib.y = 0.0
			if to_sib.length_squared() > 0.01 and outward.dot(to_sib.normalized()) > 0.55:
				continue
		var seg = BowlSegmentScene.instantiate()
		seg.radius = radius
		seg.depth = depth
		seg.arc_deg = 90.0
		seg.slices = 5
		seg.face_run_frac = 0.38
		seg.include_floor_pad = false
		seg.position = center
		seg.rotation.y = yaw
		parent.add_child(seg)
	# Single floor disc sized to the inner transition edge.
	var floor_r := radius * 0.62
	PropKit.add_cylinder(
		parent,
		floor_r,
		0.3,
		center + Vector3(0.0, -depth + 0.15, 0.0),
		PropKit.COLOR_CONCRETE,
		PackedStringArray(["bowl", "deck"]),
		20
	)
	# Coping ring (8 straight segments) — also provides a thin deck lip strip
	var cope_n := 8
	for i in range(cope_n):
		var a := TAU * float(i) / float(cope_n)
		if sibling_center != Vector3.INF:
			var pos_xz := Vector2(sin(a) * radius, -cos(a) * radius)
			var sib_xz := Vector2(sibling_center.x - center.x, sibling_center.z - center.z)
			if (pos_xz - sib_xz).length() < radius * 0.55:
				continue
		var c = CopingEdgeScene.instantiate()
		c.length = (TAU * radius) / float(cope_n) * 0.92
		c.position = center + Vector3(sin(a) * radius, 0.0, -cos(a) * radius)
		c.rotation.y = a
		parent.add_child(c)


func _build_clover_bowl() -> void:
	# Hero peanut / clover SE — deeper ~-3.0, full coping.
	var clover := Node3D.new()
	clover.name = "CloverBowl"
	add_child(clover)

	var center := Vector3(10.0, 0.0, -10.0)
	var depth := 3.0
	var w_c := center + Vector3(-2.2, 0.0, 0.6)
	var e_c := center + Vector3(2.6, 0.0, -0.6)
	# Two lobes; each skips the arc facing its sibling (no center slab explosion)
	_place_bowl_cluster(clover, w_c, 5.0, depth, e_c)
	_place_bowl_cluster(clover, e_c, 4.5, depth, w_c)
	# Shared deep floor bridge
	PropKit.add_box(
		clover,
		Vector3(6.0, 0.3, 5.0),
		center + Vector3(0.0, -depth + 0.15, 0.0),
		PropKit.COLOR_CONCRETE,
		PackedStringArray(["bowl", "deck"])
	)
	# Outer coping oval around combined footprint (fewer segs, no lip-ring boxes)
	var r_x := 7.0
	var r_z := 5.5
	var n := 10
	for i in range(n):
		var a := TAU * float(i) / float(n)
		var c = CopingEdgeScene.instantiate()
		c.length = 2.0
		c.position = center + Vector3(sin(a) * r_x, 0.0, -cos(a) * r_z)
		c.rotation.y = a
		clover.add_child(c)
	# Shallow hip toward snake (NW)
	var hip = BankQpScene.instantiate()
	hip.name = "CloverHip"
	hip.width = 4.0
	hip.height = 1.6
	hip.angle_deg = 32.0
	hip.position = center + Vector3(-5.5, 0.0, 4.0)
	hip.rotation.y = PI * 0.7
	clover.add_child(hip)


func _build_palms() -> void:
	# West cluster — one raised planter, upright trunks
	var west = PlanterRoundScene.instantiate()
	west.name = "PalmClusterWest"
	west.radius = 3.0
	west.curb_height = 0.4
	west.palm_count = 5
	west.palm_height = 10.0
	west.grindable_curb = true
	west.position = Vector3(-15.0, 0.0, 2.0)
	west.rotation = Vector3.ZERO
	add_child(west)

	# Three SE planters near clover — keep upright (no inherited tilt)
	var se_spots: Array = [
		Vector3(14.0, 0.0, -4.5),
		Vector3(17.0, 0.0, -8.0),
		Vector3(12.5, 0.0, -15.5),
	]
	for i in range(se_spots.size()):
		var p = PlanterRoundScene.instantiate()
		p.name = "PalmSE_%d" % i
		p.radius = 1.4
		p.palm_count = 1
		p.palm_height = 9.0 + float(i)
		p.grindable_curb = true
		p.position = se_spots[i]
		p.rotation = Vector3.ZERO
		add_child(p)


func _build_zones() -> void:
	# Mission Flow Area3D volumes — group name == node name.
	_add_zone("zone_street", Vector3(0.0, 2.0, 13.0), Vector3(40.0, 6.0, 14.0))
	_add_zone("zone_snake", Vector3(-5.0, 0.0, 0.0), Vector3(16.0, 8.0, 14.0))
	_add_zone("zone_clover", Vector3(10.0, -0.5, -10.0), Vector3(16.0, 8.0, 14.0))
	_add_zone("zone_stairs_b", Vector3(-4.0, 1.5, 11.0), Vector3(6.0, 4.0, 6.0))


func _add_zone(zone_name: String, pos: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.name = zone_name
	area.monitoring = true
	area.monitorable = true
	# Player CharacterBody3D uses collision_layer 2.
	area.collision_layer = 0
	area.collision_mask = 2
	area.add_to_group(zone_name)
	area.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	add_child(area)
