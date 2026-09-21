extends Node3D
## Venice Beach skatepark blockout: street plaza SOUTH (−Z), bowl cluster NORTH (+Z).
## Orientation: Z+ = north. Simple bowls only (cylinder floor + 8 wall slabs + 4 coping).
## Venice: bowls N / street S. QA2: dark pits + bank transitions, orange sand, fewer perimeter segs.

const StairsSetScene := preload("res://scenes/parks/modules/stairs_set.tscn")
const LedgeScene := preload("res://scenes/parks/modules/ledge.tscn")
const FlatbarScene := preload("res://scenes/parks/modules/flatbar.tscn")
const ManualPadScene := preload("res://scenes/parks/modules/manual_pad.tscn")
const BankQpScene := preload("res://scenes/parks/modules/bank_qp.tscn")
const PerimeterWallScene := preload("res://scenes/parks/modules/perimeter_wall.tscn")
const PlanterRoundScene := preload("res://scenes/parks/modules/planter_round.tscn")

## Playable concrete pad (X × Z). Deck top at Y = 0.
const DECK_SIZE := Vector2(48.0, 40.0)
const WALL_H := 1.1
## Stronger beach read vs white deck (QA readability).
const COLOR_SAND_APRON := Color(0.95, 0.72, 0.38)
const COLOR_BOWL_FLOOR := Color(0.28, 0.32, 0.36)
const COLOR_DECK := Color(0.86, 0.84, 0.80)
## South street entrance, facing north (+Z) into the park.
const SPAWN_POS := Vector3(-6.0, 1.2, -16.0)


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
	# Wide beach surround (~12 m beyond walls) under/around perimeter — still OOB.
	# Slightly lower than deck so concrete lip stays readable (don't bury the deck).
	PropKit.add_box(
		self,
		Vector3(DECK_SIZE.x + 24.0, 0.28, DECK_SIZE.y + 24.0),
		Vector3(0.0, -0.42, 0.0),
		COLOR_SAND_APRON,
		PackedStringArray(["out_of_bounds"])
	)
	# Thin sand berm just outside the wall ring (visual beach pile-up, still OOB).
	# Berm skipped — edge box strips read as white slab clutter in QA.



func _build_deck_plates() -> void:
	# Coarse deck plates: solid south street; holes only for north bowls — no apron filler spam.
	var plates: Array = [
		# Solid south street plaza (z −20 .. 0)
		[Vector3(48.0, 0.4, 20.0), Vector3(0.0, -0.2, -10.0)],
		# North strip beyond bowls (z ~16..20)
		[Vector3(48.0, 0.4, 4.0), Vector3(0.0, -0.2, 18.0)],
		# West of snake bowls
		[Vector3(12.0, 0.4, 16.0), Vector3(-18.0, -0.2, 8.0)],
		# East of clover / east planter pad
		[Vector3(8.0, 0.4, 16.0), Vector3(20.0, -0.2, 8.0)],
		# Mid strip south of bowls / north of street (leaves bowl openings north)
		[Vector3(48.0, 0.4, 4.0), Vector3(0.0, -0.2, 2.0)],
		# NE corner past clover lip
		[Vector3(10.0, 0.4, 6.0), Vector3(14.0, -0.2, 16.0)],
		# NW corner past snake lip
		[Vector3(10.0, 0.4, 6.0), Vector3(-14.0, -0.2, 14.0)],
	]
	for p in plates:
		PropKit.add_box(
			self,
			p[0],
			p[1],
			COLOR_DECK,
			PackedStringArray(["deck"])
		)


func _build_perimeter() -> void:
	# Rounded-rect ring of wall segments. Gap on south for entrance near spawn.
	var half_x := DECK_SIZE.x * 0.5  # 24
	var half_z := DECK_SIZE.y * 0.5  # 20
	var seg := 12.0
	# North wall (z = +half_z)
	_wall_run(Vector3(0.0, 0.0, half_z), half_x * 2.0, 0.0, seg)
	# East wall (x = +half_x)
	_wall_run(Vector3(half_x, 0.0, 0.0), half_z * 2.0, -PI * 0.5, seg)
	# West wall (x = -half_x)
	_wall_run(Vector3(-half_x, 0.0, 0.0), half_z * 2.0, PI * 0.5, seg)
	# South wall with entrance gap around spawn x≈−6
	_wall_run_south_with_gap(half_x, half_z, seg)


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


func _wall_run_south_with_gap(half_x: float, half_z: float, seg_len: float) -> void:
	# South face at z = -half_z, along +X from -half_x to +half_x. Gap x −10..−2 (near spawn).
	var z := -half_z
	var spans: Array = [
		[-half_x, -10.0],
		[-2.0, half_x],
	]
	for span in spans:
		var x0: float = span[0]
		var x1: float = span[1]
		var total := x1 - x0
		if total < 0.5:
			continue
		var n := maxi(int(ceil(total / seg_len)), 1)
		var actual := total / float(n)
		for i in range(n):
			var x := x0 + actual * (float(i) + 0.5)
			var w = PerimeterWallScene.instantiate()
			w.length = actual
			w.wall_height = WALL_H
			w.rail_grindable = false
			w.position = Vector3(x, 0.0, z)
			w.rotation.y = PI  # wall faces outward (−Z)
			add_child(w)


func _build_street_plaza() -> void:
	# South plaza street obstacles (z roughly −16..−4).
	# Stairs A — 3-step + hubba (SW)
	var stairs_a = StairsSetScene.instantiate()
	stairs_a.name = "StairsA"
	stairs_a.step_count = 3
	stairs_a.width = 3.0
	stairs_a.with_hubba = true
	stairs_a.with_handrail = false
	stairs_a.position = Vector3(-10.0, 0.0, -12.0)
	stairs_a.rotation.y = 0.0  # climb toward +Z (north / into park)
	add_child(stairs_a)

	# Stairs B — 5-set + handrail
	var stairs_b = StairsSetScene.instantiate()
	stairs_b.name = "StairsB"
	stairs_b.step_count = 5
	stairs_b.width = 3.5
	stairs_b.with_hubba = false
	stairs_b.with_handrail = true
	stairs_b.position = Vector3(-2.0, 0.0, -12.0)
	stairs_b.rotation.y = 0.0
	add_child(stairs_b)

	# Long ledge / planter
	var ledge = LedgeScene.instantiate()
	ledge.name = "LongLedge"
	ledge.length = 7.0
	ledge.depth = 0.45
	ledge.height = 0.55
	ledge.position = Vector3(5.0, 0.0, -8.0)
	ledge.rotation.y = 0.0  # along +X
	add_child(ledge)

	# Flatbar
	var bar = FlatbarScene.instantiate()
	bar.name = "Flatbar"
	bar.length = 5.0
	bar.height = 0.45
	bar.position = Vector3(11.0, 0.0, -10.0)
	add_child(bar)

	# Small bank / QP in SE street
	var bank = BankQpScene.instantiate()
	bank.name = "StreetBank"
	bank.width = 4.0
	bank.height = 1.2
	bank.angle_deg = 30.0
	bank.position = Vector3(14.0, 0.0, -6.0)
	bank.rotation.y = PI * 0.5  # slope along local +Z → world −X (into plaza)
	add_child(bank)

	# --- Density extras (cap: 2 pads/ledges + 1 bank). XL-simple lines, readable gaps. ---
	# ManualPad — mid plaza north of stairs; leaves spawn corridor (−6,−16) open
	var pad = ManualPadScene.instantiate()
	pad.name = "ManualPad"
	pad.length = 3.5
	pad.width = 2.2
	pad.height = 0.28
	pad.with_grind_lip = true
	pad.position = Vector3(0.5, 0.0, -5.5)
	pad.rotation.y = 0.0
	add_child(pad)

	# Ledge2 — SE street line, clear gap from Flatbar / StreetBank
	var ledge2 = LedgeScene.instantiate()
	ledge2.name = "Ledge2"
	ledge2.length = 5.0
	ledge2.depth = 0.4
	ledge2.height = 0.5
	ledge2.position = Vector3(8.0, 0.0, -14.0)
	ledge2.rotation.y = 0.0
	add_child(ledge2)

	# StreetBank2 — far SW turnaround only (not maximalist clutter)
	var bank2 = BankQpScene.instantiate()
	bank2.name = "StreetBank2"
	bank2.width = 3.5
	bank2.height = 1.0
	bank2.angle_deg = 28.0
	bank2.position = Vector3(-16.0, 0.0, -8.0)
	bank2.rotation.y = -PI * 0.5  # slope along local +Z → world +X (into plaza)
	add_child(bank2)

	# Flow: street → bowls (near z ≈ 0), climb north into snake — wider for aerial read
	var into_snake = BankQpScene.instantiate()
	into_snake.name = "PlazaToSnakeBank"
	into_snake.width = 6.0
	into_snake.height = 1.15
	into_snake.angle_deg = 26.0
	into_snake.position = Vector3(-4.0, 0.0, -1.0)
	into_snake.rotation.y = 0.0  # slope along local +Z → world +Z (into bowls)
	add_child(into_snake)


func _build_snake_bowls() -> void:
	var snake := Node3D.new()
	snake.name = "SnakeBowls"
	add_child(snake)
	# Two dark pits only — no wall-slab rings / hip filler boxes
	_place_simple_bowl(snake, Vector3(-6.0, 0.0, 8.0), 4.5, 1.8)
	_place_simple_bowl(snake, Vector3(1.0, 0.0, 10.0), 4.0, 2.1)
	var feed = BankQpScene.instantiate()
	feed.name = "SnakeToCloverBank"
	feed.width = 5.0
	feed.height = 1.5
	feed.angle_deg = 28.0
	feed.position = Vector3(4.5, -0.15, 10.5)
	feed.rotation.y = -PI * 0.55
	snake.add_child(feed)


func _place_simple_bowl(parent: Node3D, center: Vector3, radius: float, depth: float) -> void:
	## Dark pit + 4 inward banks — reads as a bowl hole, not a white slab ring.
	PropKit.add_cylinder(
		parent,
		radius * 0.92,
		0.45,
		center + Vector3(0.0, -depth + 0.22, 0.0),
		COLOR_BOWL_FLOOR,
		PackedStringArray(["bowl", "deck"]),
		24
	)
	# Thick dark side pad under the banks so you don't fall through
	PropKit.add_cylinder(
		parent,
		radius * 0.55,
		depth * 0.85,
		center + Vector3(0.0, -depth * 0.45, 0.0),
		COLOR_BOWL_FLOOR,
		PackedStringArray(["bowl", "deck"]),
		16
	)
	var bank_w := maxf(radius * 1.15, 3.5)
	var bank_h := minf(depth * 0.85, 2.2)
	for i in range(4):
		var a := TAU * float(i) / 4.0
		var bank = BankQpScene.instantiate()
		bank.name = "BowlBank_%d" % i
		bank.width = bank_w
		bank.height = bank_h
		bank.angle_deg = 34.0
		# Sit on rim; face inward (local +Z toward center)
		bank.position = center + Vector3(sin(a) * (radius * 0.15), 0.0, -cos(a) * (radius * 0.15))
		bank.rotation.y = a + PI  # slope toward bowl center
		parent.add_child(bank)
	# Single dark metal lip ring as 4 long edges (grindable)
	for i in range(4):
		var a := TAU * float(i) / 4.0 + PI * 0.25
		PropKit.add_box(
			parent,
			Vector3((TAU * radius) / 4.0 * 0.95, 0.14, 0.22),
			center + Vector3(sin(a) * radius, 0.07, -cos(a) * radius),
			Color(0.25, 0.26, 0.28),
			PackedStringArray(["grindable", "coping"]),
			Vector3(0.0, a, 0.0)
		)


func _build_clover_bowl() -> void:
	var clover := Node3D.new()
	clover.name = "CloverBowl"
	add_child(clover)
	var center := Vector3(8.0, 0.0, 11.0)
	# Hero bowl — slightly larger for aerial silhouette; still one clean cylinder
	_place_simple_bowl(clover, center, 5.5, 2.8)
	var hip = BankQpScene.instantiate()
	hip.name = "CloverHip"
	hip.width = 4.5
	hip.height = 1.7
	hip.angle_deg = 32.0
	hip.position = center + Vector3(-5.8, 0.0, -3.2)
	hip.rotation.y = PI * 0.35
	clover.add_child(hip)


func _build_palms() -> void:
	# East cluster — one raised planter (Props owns thin-trunk planter_round)
	var east = PlanterRoundScene.instantiate()
	east.name = "PalmClusterEast"
	east.radius = 3.0
	east.curb_height = 0.4
	east.palm_count = 5
	east.palm_height = 6.5
	east.grindable_curb = true
	east.position = Vector3(16.0, 0.0, 0.0)
	east.rotation = Vector3.ZERO
	add_child(east)

	# A few singles along SE street edge
	var se_spots: Array = [
		Vector3(14.0, 0.0, -8.0),
		Vector3(17.0, 0.0, -12.0),
		Vector3(12.5, 0.0, -15.5),
	]
	for i in range(se_spots.size()):
		var p = PlanterRoundScene.instantiate()
		p.name = "PalmSE_%d" % i
		p.radius = 1.4
		p.palm_count = 1
		p.palm_height = 6.0 + float(i) * 0.4
		p.grindable_curb = true
		p.position = se_spots[i]
		p.rotation = Vector3.ZERO
		add_child(p)


func _build_zones() -> void:
	# Mission Flow Area3D volumes — group name == node name (names kept exact).
	# zone_snake / zone_clover cover north bowls; street south.
	_add_zone("zone_street", Vector3(0.0, 2.0, -10.0), Vector3(42.0, 6.0, 20.0))
	_add_zone("zone_snake", Vector3(-5.0, 0.0, 10.0), Vector3(20.0, 8.0, 16.0))
	_add_zone("zone_clover", Vector3(8.0, -0.5, 11.0), Vector3(17.0, 8.0, 15.0))
	_add_zone("zone_stairs_b", Vector3(-2.0, 1.5, -11.0), Vector3(6.0, 4.0, 6.0))


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
