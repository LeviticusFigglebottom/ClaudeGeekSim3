extends AreaBase
## The Hollow Wood — an old wood under a moon that does not move. Giant trees,
## mushrooms lighting dirt paths, a hermit who speaks in riddles, three standing
## stones that want their fires lit in the right order, a dry well that fills
## when it rains, and a nest in the canopy that only wings can reach.
##
## Everything important sits on the flat path network at y = 0; the hills are
## between the paths. Terrain height comes from `_height`, so props off the
## paths ask it where the ground is.

const SIZE := 140.0
const TILES := 4
const TILE_RES := 11
const PATH_FLAT := 7.0
const PATH_BLEND := 14.0

const GATE := Vector3(0, 0, 62)
const CROSS := Vector3(0, 0, 30)
const HUT := Vector3(-27, 0, 9)
const STONES := Vector3(25, 0, 12)
const WELL := Vector3(-8, 0, -14)
const CANOPY := Vector3(-32, 0, -38)
const CLEARING := Vector3(12, 0, -42)
const DEAD_GROVE := Vector3(32, 0, -32)
const ROAD := Vector3(62, 0, 0)
const POND := Vector3(38, 0, 6)

## Dirt paths: pairs of ground points (x, z).
const PATHS := [
	[Vector2(0, 62), Vector2(0, 30)],
	[Vector2(0, 30), Vector2(-27, 14)],
	[Vector2(0, 30), Vector2(25, 12)],
	[Vector2(25, 12), Vector2(62, 0)],
	[Vector2(0, 30), Vector2(-8, -14)],
	[Vector2(-8, -14), Vector2(12, -42)],
	[Vector2(-8, -14), Vector2(-32, -38)],
	[Vector2(12, -42), Vector2(32, -32)],
]
## Flat clearings: centre (x, z) and radius.
const CLEARINGS := [
	[Vector2(0, 62), 5.0], [Vector2(0, 30), 5.0], [Vector2(-27, 9), 7.0], [Vector2(25, 12), 11.0],
	[Vector2(-8, -14), 7.0], [Vector2(-32, -38), 8.0], [Vector2(12, -42), 6.0], [Vector2(32, -32), 10.0],
	[Vector2(62, 0), 4.0],
]
## Brazier indices in the order the stones want them lit.
const ORDER := [0, 1, 2]

var puzzle: Puzzle = null
var braziers: Array = []
var lit_order: Array = []
var cage: Node3D = null
var cage_readable: Readable = null
var lantern_pickup: Pickup = null
var well_water: MeshInstance3D = null
var well_readable: Readable = null
var rain: CPUParticles3D = null
var raining := false
var well_filled := false
var figure_seen := false
var tree_spots: Array = []


func build() -> void:
	Realm.apply(self, "forest", {"ambient_energy": 0.9, "fog_density": 0.03, "sky_opts": {"detail_strength": 0.5}})
	_terrain()
	_paths()
	_gate()
	_hut()
	_stones()
	_well()
	_canopy()
	_road()
	_clearing()
	_dead_grove()
	_trees()
	_path_lights()
	_extras()


# --- ground -------------------------------------------------------------------

func _hills(x: float, z: float) -> float:
	return 1.3 * sin(x * 0.075 + 0.4) * cos(z * 0.068) + 0.7 * sin(x * 0.19 + z * 0.11 + 1.3) + 0.35 * cos(x * 0.31 - z * 0.27) + 0.25 * sin(z * 0.43 + x * 0.05)


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Distance to the nearest path or clearing edge (0 on a path).
func _path_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 1.0e9
	for seg in PATHS:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		best = minf(best, _seg_dist(p, a, b))
	for c in CLEARINGS:
		var centre: Vector2 = c[0]
		var r: float = c[1]
		best = minf(best, maxf(p.distance_to(centre) - r, 0.0))
	return best


func _height(x: float, z: float) -> float:
	var d := _path_dist(x, z)
	var t := smoothstep(PATH_FLAT, PATH_BLEND, d)
	var e := maxf(absf(x), absf(z))
	var h := (_hills(x, z) + 7.0 * smoothstep(54.0, 68.0, e)) * t
	h += 5.0 * smoothstep(64.0, 70.0, e)
	var pd := Vector2(x, z).distance_to(Vector2(POND.x, POND.z))
	h -= 1.3 * (1.0 - smoothstep(2.5, 7.0, pd))
	return h


func _color(x: float, z: float, h: float) -> Color:
	var d := _path_dist(x, z)
	var path_t := 1.0 - smoothstep(1.4, 5.0, d)
	var hi := clampf(h * 0.22 + 0.55, 0.0, 1.0)
	var c := Color(0.5, 0.66, 0.52).lerp(Color(0.86, 0.96, 0.82), hi)
	c = c.lerp(Color(0.66, 0.52, 0.36), path_t)
	var e := maxf(absf(x), absf(z))
	return c.lerp(Color(0.2, 0.28, 0.26), smoothstep(50.0, 68.0, e))


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, _height(x, z), z)


func _terrain() -> void:
	var tile := SIZE / TILES
	for j in TILES:
		for i in TILES:
			var cx := -SIZE * 0.5 + tile * (i + 0.5)
			var cz := -SIZE * 0.5 + tile * (j + 0.5)
			var t := Kit.terrain(self, Vector3(cx, 0, cz), Vector2(tile, tile), TILE_RES, _height, "nature/grass_dark", {"color_fn": _color, "tile": 3.0, "surface": "grass"})
			t.name = "Terrain_%d_%d" % [i, j]
	# the wood does not end; it just stops letting you through
	Kit.blocker(self, Vector3(0, 10, -68), Vector3(SIZE + 6, 30, 2))
	Kit.blocker(self, Vector3(0, 10, 68), Vector3(SIZE + 6, 30, 2))
	Kit.blocker(self, Vector3(-68, 10, 0), Vector3(2, 30, SIZE + 6))
	Kit.blocker(self, Vector3(68, 10, 0), Vector3(2, 30, SIZE + 6))


func _paths() -> void:
	for seg in PATHS:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var yaw := Kit.dir_to_yaw(Vector3(dir.x, 0, dir.y))
		var n := int(length / 2.8)
		for i in n + 1:
			var p := a + dir * minf(i * 2.8, length)
			var off := Vector2(-dir.y, dir.x) * rng.randf_range(-0.35, 0.35)
			Kit.floor(self, Vector3(p.x + off.x, 0.03, p.y + off.y), Vector2(2.3 + rng.randf_range(-0.2, 0.5), 3.3), "ground/dirt", {"solid": false, "yaw": yaw + rng.randf_range(-7.0, 7.0), "thick": 0.04, "tile": 2.0, "cast_shadow": false})
	Kit.ring(self, CROSS + Vector3(0, 0.025, 0), 0.0, 4.5, 12, "ground/dirt", {"solid": false})
	Kit.ring(self, STONES + Vector3(0, 0.025, 0), 0.0, 8.0, 16, "ground/gravel", {"solid": false, "tile": 1.5})
	Kit.ring(self, HUT + Vector3(0, 0.025, 0), 0.0, 5.5, 12, "ground/dirt", {"solid": false})


# --- the gate from the Anteroom ---------------------------------------------------

func _gate() -> void:
	Kit.arch(self, GATE, 0.0, 2.2, 3.4, "stone/blocks_nexus", {"depth": 1.0, "post": 0.7, "top": 0.7, "tile": 1.0})
	Kit.floor(self, GATE + Vector3(0, 0.04, -2.2), Vector2(3.4, 4.4), "nature/grass_moss", {"solid": false, "thick": 0.04})
	Door.create(self, GATE, 0.0, "nexus", "from_forest", {"kind": "dark", "label": "Back to the Anteroom", "name": "GateDoor"})
	Kit.label(self, "THE ANTEROOM", GATE + Vector3(0, 4.6, -0.6), 0.0, 40, Color(0.7, 0.9, 0.85), "display", {"pixel_size": 0.016})
	Kit.light(self, GATE + Vector3(0, 3.4, -2.0), Color(0.5, 1.0, 0.85), 1.7, 12.0)
	# behind the gate the wood has grown shut
	Kit.box(self, GATE + Vector3(0, 2.6, 1.3), Vector3(4.0, 5.2, 0.8), "nature/roots", {"tile": 1.5})
	Props.place(self, "mushroom_glow_small", GATE + Vector3(-1.9, 0, -1.6), 30.0, 1.2, {"collision": "none"})
	Props.place(self, "mushroom_glow_small", GATE + Vector3(2.0, 0, -2.4), 200.0, 0.9, {"collision": "none"})
	Props.place(self, "fern_cluster", GATE + Vector3(2.6, 0, -0.9), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "rock_2", GATE + Vector3(-3.4, 0, -0.6), 40.0, 1.0)
	Props.place(self, "tree_oak_2", GATE + Vector3(-6.5, -0.2, 1.0), 20.0, 1.0, {"collision": "cylinder", "collision_scale": 0.22})
	Props.place(self, "tree_pine_2", GATE + Vector3(6.8, -0.2, 0.5), 200.0, 0.9, {"collision": "cylinder", "collision_scale": 0.22})
	add_spawn("from_nexus", GATE + Vector3(0, 0.1, -3.2), 0.0)
	add_spawn("default", GATE + Vector3(0, 0.1, -3.2), 0.0)
	Dog.maybe_spawn(self, GATE + Vector3(2.0, 0.1, -5.0))


# --- the hermit's hut ---------------------------------------------------------

func _hut() -> void:
	var solved := Game.has_flag("forest_braziers")
	var r := 2.5
	if Props.exists("hermit_hut"):
		Props.place(self, "hermit_hut", HUT, 180.0, 1.5, {"collision": "none", "name": "Hut"})
		r = 2.2
		# eight segments starting on a centre, so the one on the door (90°) is the gap
		_ring_blockers(HUT, r + 0.2, 3.6, 8, 90.0, 44.0, 0.0)
		Kit.ring(self, HUT + Vector3(0, 0.03, 0), 0.0, r + 0.1, 10, "wood/planks_dark", {"solid": false})
	else:
		Kit.ring(self, HUT + Vector3(0, 0.03, 0), 0.0, 2.9, 12, "wood/planks_dark", {"solid": false})
		Kit.round_wall(self, HUT, 2.7, 2.7, 10, "stone/cobble_mossy", {"gaps": [[90.0, 42.0]], "tile": 1.5})
		Kit.cylinder(self, HUT + Vector3(0, 2.6, 0), 3.5, 2.4, "wood/thatch", {"top_radius": 0.15, "segments": 10, "solid": false, "tile": 1.5})
		Kit.box(self, HUT + Vector3(0, 2.3, 2.7), Vector3(2.4, 0.5, 0.35), "wood/planks_dark")
		Kit.cylinder(self, HUT + Vector3(1.6, 3.6, -1.2), 0.3, 2.2, "stone/cobble_grey", {"segments": 6, "solid": false})
	var door_pos := HUT + Vector3(0, 0, r + 0.4)
	Kit.light(self, HUT + Vector3(0, 2.1, 0), Color(1.0, 0.75, 0.45), 1.6, 9.0)
	Kit.light(self, door_pos + Vector3(1.2, 2.6, 1.4), Color(1.0, 0.7, 0.4), 1.5, 11.0)
	Props.place(self, "lantern_post", door_pos + Vector3(1.6, 0, 1.0), 0.0, 0.85, {"collision": "cylinder"})
	Props.place(self, "candle_cluster", HUT + Vector3(1.2, 0, -0.9), 0.0, 1.3, {"collision": "none"})
	Props.place(self, "stool", HUT + Vector3(1.5, 0, 0.6), 30.0, 1.0)
	Props.place(self, "barrel", HUT + Vector3(-1.6, 0, 1.0), 0.0, 0.8)
	Props.place(self, "crate_small", HUT + Vector3(-1.7, 0, -1.0), 25.0, 1.0)
	Props.place(self, "rug_house", HUT + Vector3(0, 0.02, 0.5), 0.0, 0.8, {"collision": "none"})
	Props.place(self, "bottle", HUT + Vector3(1.4, 0.02, 1.4), 0.0, 1.0, {"collision": "none"})
	Kit.particles(self, HUT + Vector3(0, 1.5, 0), "motes", Vector3(2, 1.5, 2), 25)
	# the caged lantern at the back
	var cage_pos := HUT + Vector3(0, 0, -1.3)
	Kit.box(self, cage_pos + Vector3(0, 0.15, 0), Vector3(1.0, 0.3, 1.0), "stone/blocks_dark", {"tile": 1.0})
	cage = Props.place(self, "cage", cage_pos + Vector3(0, 0.3, 0), 0.0, 0.6, {"collision": "none", "name": "Cage"})
	cage.visible = not solved
	lantern_pickup = Pickup.create(self, cage_pos + Vector3(0, 0.3, 0), {"keepsake": "lantern", "requires_flag": "forest_braziers", "name": "Pickup_lantern"})
	if not solved:
		lantern_pickup.visible = false
		lantern_pickup.enabled = false
		cage_readable = Readable.create(self, cage_pos + Vector3(0, 0, 0.85), 0.0, "Look at the cage", [
			"The lantern hangs in an iron cage. The cage has no door.",
			"It is lit. There is no oil in it. The hermit does not look at it, the way you do not look at a clock you are waiting on.",
		], {"name": "CageLook", "size": Vector3(1.2, 1.6, 0.5), "note_key": "lantern_cage", "note_title": "The caged lantern", "note_text": "In the hermit's hut a lantern burns inside an iron cage with no door. The hermit says the stones remember the order."})
	# the hermit
	var hermit_model := "hermit" if Props.exists("hermit") else "patron_seated"
	var npc := NPC.create(self, HUT + Vector3(-1.1, 0, -0.2), 150.0, "the Hermit", {
		"model": hermit_model, "name": "Hermit", "flee_knife": true, "on_talk": _hermit_talk,
		"lines": [
			"You want the light. Everyone who comes in wants the light.",
			"The stones remember the order. The moss remembers the stones.",
			"One was struck by the tree that fell. Fire it first. It has waited a long time to be first.",
			"One looks at the water all day and never drinks. Fire it second.",
			"The one with moss on its shoulder is last. It is always last. It likes it.",
			"Get it wrong and the wood will tell you. It is not subtle.",
		],
		"reactions": {
			"crown": ["A paper crown. In here.", "Sit down, your majesty. Mind the roof. It is not fooled either, but it is polite."],
			"knife": ["Put that away.", "I am not a conversation. There is nothing in me to cut short."],
			"lantern": ["Yes. That is the one.", "Mind the moths. They know what it is for."],
			"bell": ["The stones heard that.", "They are not impressed. They have heard bells before."],
			"umbrella": ["Open that in here and I will put you out in the weather you make."],
		},
	})
	if not Props.exists(hermit_model):
		_kit_figure(npc, Color(0.42, 0.36, 0.28))
	add_spawn("hut", door_pos + Vector3(0, 0.1, 3.0), 0.0)


func _hermit_talk(_player: Node, npc: Node) -> bool:
	var n := npc as NPC
	if n == null:
		return false
	Game.note("hermit", "The hermit", "A hooded old man in a hut in the Hollow Wood, keeping a lantern in a cage with no door. He speaks about the standing stones in the way people speak about relatives.")
	if Game.has_keepsake("lantern"):
		n.lines = ["You brought it back to show me. Kind. Wrong, but kind.", "Some things only exist in its light. Some things only stop existing. Try not to learn which the hard way."]
	elif Game.has_flag("forest_braziers"):
		n.lines = ["You did it in the right order. I heard the stones sigh.", "Take the light. It was never mine to keep. I only kept it."]
	return false


## A plain figure for people whose models are not here yet.
func _kit_figure(parent: Node, col: Color) -> void:
	var m := Kit.flat(col)
	Kit.box(parent, Vector3(0, 0.85, 0), Vector3(0.5, 1.3, 0.34), "", {"mat": m, "solid": false})
	Kit.box(parent, Vector3(0, 1.72, 0), Vector3(0.28, 0.32, 0.28), "", {"mat": Kit.flat(col.lightened(0.15)), "solid": false})
	Kit.box(parent, Vector3(-0.16, 0.25, 0), Vector3(0.16, 0.5, 0.2), "", {"mat": m, "solid": false})
	Kit.box(parent, Vector3(0.16, 0.25, 0), Vector3(0.16, 0.5, 0.2), "", {"mat": m, "solid": false})


func _ring_blockers(centre: Vector3, radius: float, height: float, segments: int, gap_angle: float, gap_width: float, phase: float = 0.5) -> void:
	var chord := 2.0 * radius * sin(PI / segments) + 0.3
	for i in segments:
		var a := 360.0 * (i + phase) / segments
		if absf(wrapf(a - gap_angle, -180.0, 180.0)) < gap_width * 0.5:
			continue
		var b := Kit.blocker(self, centre + Kit.polar(radius, a, height * 0.5), Vector3(chord, height, 0.3))
		b.rotation.y = deg_to_rad(-(a + 90.0))


# --- the standing stones -------------------------------------------------------

func _stones() -> void:
	var solved := Game.has_flag("forest_braziers")
	puzzle = Puzzle.declare(self, "forest_braziers", "forest_braziers", [], "light the braziers in the order carved on the stones")
	var angles := [210.0, 330.0, 90.0]
	var texts := [
		["THE FALLEN TREE POINTS. WHAT IT POINTS AT BURNS FIRST.", "Under it, smaller: it fell on purpose. You can tell by how it lies."],
		["THE ONE THAT FACES THE WATER BURNS SECOND.", "It has never once looked away from the pond. Neither has the pond."],
		["THE MOSS-SIDE STONE BURNS LAST.", "The moss remembers the stones. The stones remember the order. Nobody remembers who carved this."],
	]
	var notes := ["First: the stone the fallen tree points at.", "Second: the stone that faces the water.", "Last: the stone with moss on its shoulder."]
	for i in 3:
		var a: float = angles[i]
		var spos := STONES + Kit.polar(6.5, a)
		var yaw := Kit.yaw_to_center(a)
		Props.place(self, "standing_stone_tall", spos, yaw + rng.randf_range(-12.0, 12.0), 1.0, {"collision": "box", "name": "Stone%d" % i})
		Readable.create(self, spos, yaw, "Read the stone", texts[i], {"name": "StoneText%d" % i, "size": Vector3(2.0, 5.2, 2.0), "note_key": "stone_%d" % i, "note_title": "The standing stones", "note_text": notes[i]})
		var b := Brazier.create(self, STONES + Kit.polar(3.4, a), {"index": i, "lit": solved, "toggleable": not solved, "name": "Brazier%d" % i})
		b.toggled.connect(_on_brazier.bind(i))
		braziers.append(b)
	# the fallen tree points at stone 0
	var a_pos := STONES + Kit.polar(6.5, angles[0])
	var tree_base := a_pos + Kit.polar(8.5, 200.0)
	var d := (a_pos - tree_base).normalized()
	Props.place(self, "tree_dead_1", tree_base + Vector3(0, 0.4, 0), 0.0, 1.0, {"collision": "none", "rotation": Vector3(90.0, rad_to_deg(atan2(d.x, d.z)), 0.0), "name": "FallenTree"})
	Props.place(self, "rock_3", tree_base + Vector3(0.8, 0, 0.9), 0.0, 1.0)
	# the moss-side stone (index 2, at 90°)
	var b_pos := STONES + Kit.polar(6.5, angles[2])
	Kit.ring(self, b_pos + Vector3(0, 0.035, 0), 0.0, 2.6, 10, "nature/grass_moss", {"solid": false})
	Kit.box(self, b_pos + Vector3(0.1, 5.2, 0), Vector3(1.1, 0.25, 1.1), "nature/grass_moss", {"solid": false, "tile": 1.0})
	Props.place(self, "fern_cluster", b_pos + Vector3(1.4, 0, 0.9), 0.0, 1.1, {"collision": "none"})
	Props.place(self, "fern_cluster", b_pos + Vector3(-1.3, 0, 1.1), 60.0, 0.9, {"collision": "none"})
	Props.place(self, "bush_1", b_pos + Vector3(0.2, 0, 2.0), 0.0, 0.8, {"collision": "none"})
	# the pond the water-stone faces (index 1, at 330°)
	Kit.water(self, POND + Vector3(0, -0.35, 0), Vector2(9.0, 8.0), "nature/water_dark", {"tint": Color(0.65, 0.82, 0.9, 0.85), "speed": 0.01, "swell": 0.03})
	Kit.light(self, POND + Vector3(0, 2.2, 0), Color(0.6, 0.85, 1.0), 1.0, 10.0)
	Props.place(self, "mushroom_glow_big", POND + Vector3(-4.4, 0, 3.2), 0.0, 0.8, {"collision": "cylinder"})
	Props.place(self, "rock_pale", POND + Vector3(3.6, -0.3, -3.6), 30.0, 1.0)
	Kit.particles(self, POND + Vector3(0, 0.6, 0), "fog", Vector3(5, 0.4, 5), 8)
	# the middle: a flat stone, a pale light
	Kit.box(self, STONES + Vector3(0, 0.15, 0), Vector3(1.4, 0.3, 1.4), "stone/smooth_grey", {"tile": 1.0})
	Readable.create(self, STONES + Vector3(0, 0.3, 0), 0.0, "Read the flat stone", [
		"THREE FIRES. ONE ORDER. THE STONES ARE PATIENT. THE WOOD IS NOT.",
		"Each stone has its clue carved on it. Each brazier stands before its stone.",
	], {"name": "FlatStone", "size": Vector3(1.4, 0.5, 1.4), "note_key": "stones_ring", "note_title": "The ring of stones", "note_text": "Three tall stones, three braziers. Light the fires in the order the carvings describe. Get it wrong and every fire goes out at once."})
	Kit.light(self, STONES + Vector3(0, 6.0, 0), Color(0.7, 0.9, 1.0), 1.0, 14.0)
	Kit.particles(self, STONES + Vector3(0, 0.8, 0), "fog", Vector3(9, 0.5, 9), 12)
	add_spawn("stones", STONES + Vector3(0.0, 0.1, 8.5), 0.0)


func _on_brazier(lit: bool, i: int) -> void:
	if puzzle == null or puzzle.is_solved():
		return
	if not lit:
		if lit_order.has(i):
			lit_order.clear()
			_snuff_all()
		return
	var expected: int = ORDER[lit_order.size()]
	if i == expected:
		lit_order.append(i)
		if lit_order.size() == ORDER.size():
			_solve_stones()
		else:
			Game.toast.emit("The stone behind it is satisfied. For now.")
	else:
		lit_order.clear()
		Audio.sfx("growl", STONES + Vector3(0, 1.0, 0), -2.0)
		Game.bump("growls_heard")
		Game.toast.emit("Every fire goes out at once. Under the stones, something growls, low, like a door.")
		get_tree().create_timer(0.7).timeout.connect(_snuff_all)


func _snuff_all() -> void:
	if not is_inside_tree() or (puzzle != null and puzzle.is_solved()):
		return
	for b in braziers:
		var br := b as Brazier
		if br != null and is_instance_valid(br) and br.lit:
			br.set_lit(false, true)
	lit_order.clear()


func _solve_stones() -> void:
	puzzle.solve("The stones are satisfied.")
	for b in braziers:
		var br := b as Brazier
		if br != null:
			br.toggleable = false
	Audio.sfx("stone_grind", HUT, -4.0)
	Game.note("stones_order", "The order of the stones", "Fallen tree, then water, then moss. The braziers burned in that order and the cage in the hermit's hut remembered how to open.")
	_reveal_lantern()


func _reveal_lantern() -> void:
	if cage != null and is_instance_valid(cage):
		var tw := create_tween()
		tw.tween_property(cage, "scale", Vector3(0.01, 0.01, 0.01), 0.8).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			if is_instance_valid(cage):
				cage.visible = false)
	if cage_readable != null and is_instance_valid(cage_readable):
		cage_readable.enabled = false
		cage_readable.visible = false
	if lantern_pickup != null and is_instance_valid(lantern_pickup):
		lantern_pickup.visible = true
		lantern_pickup.enabled = true
	Game.toast.emit("In the hut, iron creaks. The cage has remembered how to open.")


# --- the dry well -----------------------------------------------------------------

func _well() -> void:
	Kit.ring(self, WELL + Vector3(0, 0.025, 0), 0.0, 5.5, 14, "ground/dirt", {"solid": false})
	Props.place(self, "well", WELL, 0.0, 1.0, {"collision": "cylinder", "collision_scale": 0.75, "name": "Well"})
	well_readable = Readable.create(self, WELL + Vector3(0, 0, -1.7), 180.0, "Look into the well", [
		"Dry. Dry all the way down, which is further than a well should go.",
		"At the bottom something pale is arranged in a ring. It might be bones. It might be teeth.",
		"A wind comes up out of it, smelling of rain that has not happened yet.",
	], {"name": "WellLook", "size": Vector3(1.6, 1.4, 0.7), "note_key": "dry_well", "note_title": "The dry well", "note_text": "A dry well in a clearing of the Hollow Wood. Too deep. Something pale at the bottom, arranged in a ring. It wants weather."})
	Door.create(self, WELL + Vector3(0, 0, 1.6), 180.0, "catacombs", "from_well", {
		"kind": "none", "label": "Climb down into the well", "requires_keepsake": "umbrella",
		"locked_text": "The well is dry. The bottom is a long way down and it is not water. You would need weather.",
		"name": "WellDoor", "fade_color": Color(0.02, 0.03, 0.05), "fade_duration": 1.2, "sound": "splash"})
	well_water = Kit.water(self, WELL + Vector3(0, -0.6, 0), Vector2(1.5, 1.5), "nature/water_dark", {"tint": Color(0.6, 0.75, 0.9, 0.9), "speed": 0.03, "swell": 0.02, "subdiv": 2})
	well_water.visible = false
	Kit.light(self, WELL + Vector3(0, 3.6, 0), Color(0.6, 0.8, 1.0), 1.2, 11.0)
	Props.place(self, "rock_1", WELL + Vector3(3.2, 0, -2.4), 70.0, 1.0)
	Props.place(self, "rock_3", WELL + Vector3(-2.8, 0, 2.6), 10.0, 1.2)
	Props.place(self, "fern_cluster", WELL + Vector3(-3.4, 0, -1.0), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "bush_2", WELL + Vector3(4.2, 0, 2.0), 0.0, 0.7, {"collision": "none"})
	Props.place(self, "mushroom_glow_small", WELL + Vector3(2.0, 0, 2.6), 0.0, 1.4, {"collision": "none"})
	Kit.light(self, WELL + Vector3(2.0, 0.8, 2.6), Color(0.45, 1.0, 0.9), 1.0, 7.0)
	Kit.particles(self, WELL + Vector3(0, 0.7, 0), "fog", Vector3(7, 0.5, 7), 10)
	add_spawn("well_top", WELL + Vector3(2.6, 0.1, 0.6), 180.0)


func on_umbrella(open: bool) -> void:
	if open:
		_start_rain()
	else:
		raining = false
		if rain != null and is_instance_valid(rain):
			rain.emitting = false


func _start_rain() -> void:
	if raining or not is_inside_tree():
		return
	raining = true
	if rain == null:
		rain = Kit.particles(self, player_pos() + Vector3(0, 11, 0), "rain", Vector3(26, 3, 26), 700)
		rain.name = "Rain"
	rain.emitting = true
	Audio.sfx("thunder", null, -2.0)
	Game.toast.emit("The umbrella opens. The wood takes it as an instruction.")
	if not well_filled:
		get_tree().create_timer(6.0).timeout.connect(_fill_well)


func _fill_well() -> void:
	if well_filled or not is_inside_tree():
		return
	well_filled = true
	if well_water != null and is_instance_valid(well_water):
		well_water.visible = true
		var tw := create_tween()
		tw.tween_property(well_water, "position:y", 0.72, 5.0).set_trans(Tween.TRANS_SINE)
	Audio.sfx("splash", WELL, -4.0)
	Game.toast.emit("Down in the well, water rises to meet the rain.")
	Game.note("well_rain", "The well and the rain", "The dry well in the Hollow Wood fills when it rains. It fills from the bottom, as if the rain were coming up. With the umbrella open you can climb down into it.")
	if well_readable != null and is_instance_valid(well_readable):
		well_readable.lines = ["Black water, right up to the rim, with the rain landing on it.", "It is not reflecting the sky. It is reflecting a ceiling."]


# --- the canopy ---------------------------------------------------------------------

func _canopy() -> void:
	var base := CANOPY
	Kit.ring(self, base + Vector3(0, 0.03, 0), 0.0, 6.0, 14, "nature/roots", {"solid": false, "tile": 2.5})
	Props.place(self, "tree_giant", base + Vector3(0, -0.2, 0), 35.0, 1.0, {"collision": "cylinder", "collision_scale": 0.16, "name": "CanopyTree"})
	tree_spots.append(base)
	var y := 1.0
	var n := 8
	var a := 200.0
	for i in n:
		a = 200.0 + i * 50.0
		_platform(base + Kit.polar(5.4, a, y), a, 2.6)
		y += 2.35
	var a_out := 200.0 + n * 50.0
	for k in 2:
		_platform(base + Kit.polar(8.0 + k * 2.7, a_out, y), a_out, 2.4)
		y += 2.3
	var nest := base + Kit.polar(13.3, a_out, y)
	Kit.box(self, nest - Vector3(0, 0.3, 0), Vector3(4.2, 0.6, 4.2), "nature/roots", {"tile": 1.5, "yaw": -a_out})
	Kit.box(self, base + Kit.polar(6.7, a_out, y - 0.75), Vector3(14.0, 0.6, 0.6), "nature/bark_oak", {"tile": 1.0, "yaw": -a_out, "solid": false})
	for extra in [Vector2(40.0, 9.0), Vector2(120.0, 14.0), Vector2(290.0, 11.0)]:
		var e: Vector2 = extra
		Kit.box(self, base + Kit.polar(4.5, e.x, e.y), Vector3(9.0, 0.5, 0.5), "nature/bark_oak", {"tile": 1.0, "yaw": -e.x, "solid": false})
	for k in 5:
		var cp := nest + Vector3(rng.randf_range(-1.5, 1.5), 3.2, rng.randf_range(-1.5, 1.5))
		_cocoon(cp)
	_cocoon(base + Kit.polar(4.5, 120.0, 16.5))
	_cocoon(base + Kit.polar(4.5, 290.0, 13.5))
	Pickup.create(self, nest, {"item": "moonlight", "model": "bottle_moonlight", "requires_keepsake": "wings", "name": "Pickup_moonlight"})
	Readable.create(self, nest + Vector3(1.4, 0, 0.8), 0.0, "Look at the cocoons", [
		"The cocoons are empty. Whatever slept in them was the size of a person, and has gone.",
		"One is still warm. The bottle of moonlight was left in the middle of the nest like an apology.",
	], {"name": "Cocoons", "size": Vector3(1.0, 1.6, 1.0), "note_key": "moths", "note_title": "The moth nest", "note_text": "A nest of empty cocoons at the top of a giant tree in the Hollow Wood. Something person-sized slept in them. A bottle of moonlight was left there."})
	Kit.light(self, nest + Vector3(0, 2.6, 0), Color(0.8, 0.78, 1.0), 1.4, 10.0)
	Kit.particles(self, nest + Vector3(0, 1.5, 0), "motes", Vector3(3, 2, 3), 40)
	Kit.light(self, base + Vector3(0, 3.0, 5.0), Color(0.55, 0.9, 0.85), 1.1, 10.0)
	Props.place(self, "mushroom_glow_big", base + Vector3(4.2, 0, 4.6), 0.0, 1.0, {"collision": "cylinder"})
	Props.place(self, "mushroom_glow_small", base + Kit.polar(5.6, 200.0), 0.0, 1.5, {"collision": "none"})
	Readable.create(self, base + Kit.polar(4.2, 200.0), Kit.yaw_to_center(200.0) + 180.0, "Look up", [
		"Branches go up around the trunk like a stair that has forgotten to be one.",
		"The first is easy. The rest are not for legs.",
	], {"name": "LookUp", "size": Vector3(1.2, 2.0, 1.2), "note_key": "canopy_stair", "note_title": "The canopy stair", "note_text": "Branches spiral up the giant tree at the western edge of the Hollow Wood. The gaps are not for legs. Something with wings could manage."})
	add_spawn("nest", nest + Vector3(0, 0.1, 1.2), 0.0)
	add_spawn("canopy", base + Kit.polar(9.0, 200.0, 0.1), Kit.yaw_to_center(200.0))


func _platform(p: Vector3, angle: float, w: float) -> void:
	Kit.box(self, p - Vector3(0, 0.25, 0), Vector3(w, 0.5, w), "nature/bark_oak", {"tile": 1.5, "yaw": -angle})
	var r := Vector2(p.x - CANOPY.x, p.z - CANOPY.z).length()
	Kit.box(self, CANOPY + Kit.polar(r * 0.5, angle, p.y - 0.55), Vector3(r + 0.6, 0.45, 0.45), "nature/bark_oak", {"tile": 1.0, "yaw": -angle, "solid": false})


func _cocoon(top: Vector3) -> void:
	if Props.exists("cocoon"):
		Props.place(self, "cocoon", top, rng.randf_range(0.0, 360.0), 1.0, {"collision": "none"})
		return
	var cm := CapsuleMesh.new()
	cm.radius = 0.38
	cm.height = 2.0
	Kit.add_mesh(self, cm, Kit.mat("fabric/sheet", {"tint": Color(0.8, 0.78, 0.72)}), top - Vector3(0, 1.7, 0), {"solid": false})
	Kit.sign(self, "metal/chain", top - Vector3(0, 0.35, 0), 0.0, Vector2(0.12, 0.7))


# --- the road east ----------------------------------------------------------------

func _road() -> void:
	Kit.arch(self, ROAD, 90.0, 2.4, 3.6, "stone/blocks_city", {"depth": 1.0, "post": 0.7, "top": 0.6, "tile": 1.0})
	Door.create(self, ROAD, 90.0, "city", "west_gate", {"kind": "none", "label": "The road to the city", "name": "RoadDoor", "fade_color": Color(0.16, 0.18, 0.22), "fade_duration": 1.0})
	Kit.label(self, "THE DROWNED CITY", ROAD + Vector3(-0.6, 4.7, 0), 90.0, 40, Color(0.75, 0.8, 0.9), "display", {"pixel_size": 0.016})
	Kit.light(self, ROAD + Vector3(-2.0, 3.5, 0), Color(0.75, 0.8, 1.0), 1.5, 11.0)
	Props.place(self, "lantern_post_city", ROAD + Vector3(-3.2, 0, 2.4), 0.0, 0.9, {"collision": "cylinder"})
	Kit.floor(self, ROAD + Vector3(-1.0, 0.04, 0), Vector2(3.6, 4.0), "stone/cobble_mossy", {"solid": false, "thick": 0.04, "yaw": 90.0})
	Kit.floor(self, ROAD + Vector3(4.0, 0.03, 0), Vector2(3.0, 6.0), "stone/cobble_city", {"solid": false, "thick": 0.04, "yaw": 90.0})
	Kit.blocker(self, ROAD + Vector3(4.6, 2.0, 0), Vector3(0.4, 4.0, 4.0))
	Props.place(self, "tree_pine_1", ROAD + Vector3(3.0, -0.2, -3.6), 0.0, 1.1, {"collision": "cylinder", "collision_scale": 0.22})
	Props.place(self, "tree_pine_1", ROAD + Vector3(3.4, -0.2, 3.8), 90.0, 1.0, {"collision": "cylinder", "collision_scale": 0.22})
	Kit.sign(self, "signs/graffiti_wake", ROAD + Vector3(-1.05, 2.2, -1.5), 90.0, Vector2(1.2, 0.36))
	add_spawn("road", ROAD + Vector3(-3.5, 0.1, 0), 90.0)


# --- the clearing (where the tavern's back door lands you) ------------------------

func _clearing() -> void:
	Kit.ring(self, CLEARING + Vector3(0, 0.025, 0), 0.0, 4.8, 12, "nature/grass_moss", {"solid": false})
	for i in 9:
		var a := i * 40.0 + rng.randf_range(-8.0, 8.0)
		Props.place(self, "mushroom_red", CLEARING + Kit.polar(3.6 + rng.randf_range(-0.3, 0.3), a), rng.randf_range(0.0, 360.0), rng.randf_range(0.8, 1.3), {"collision": "none"})
	Kit.light(self, CLEARING + Vector3(0, 1.6, 0), Color(1.0, 0.55, 0.45), 1.2, 9.0)
	Kit.light(self, CLEARING + Vector3(0, 6.0, 0), Color(0.7, 0.85, 1.0), 0.9, 14.0)
	_signpost(CLEARING + Vector3(1.8, 0, 1.6))
	Kit.particles(self, CLEARING + Vector3(0, 1.5, 0), "motes", Vector3(4, 1.5, 4), 40)
	Props.place(self, "rock_2", CLEARING + Vector3(-4.8, 0, -3.6), 20.0, 0.9)
	add_spawn("clearing", CLEARING + Vector3(0, 0.1, 0.5), Kit.dir_to_yaw(WELL - CLEARING))


func _signpost(p: Vector3) -> void:
	var model := ""
	for m in ["signpost_forest", "signpost"]:
		if Props.exists(String(m)):
			model = String(m)
			break
	if model != "":
		Props.place(self, model, p, 20.0, 1.0, {"collision": "cylinder"})
	else:
		Kit.box(self, p + Vector3(0, 1.2, 0), Vector3(0.14, 2.4, 0.14), "wood/planks_grey", {"tile": 1.0})
	var boards := [["the anteroom", Kit.dir_to_yaw(GATE - p)], ["the well", Kit.dir_to_yaw(WELL - p)], ["the road", Kit.dir_to_yaw(ROAD - p)]]
	for i in boards.size():
		var b: Array = boards[i]
		var text: String = b[0]
		var yaw: float = b[1]
		var h := 1.55 + i * 0.32
		var dir := Kit.yaw_to_dir(yaw)
		var centre := p + Vector3(0, h, 0) + dir * 0.4
		if model == "":
			Kit.box(self, centre, Vector3(0.95, 0.22, 0.05), "wood/planks_grey", {"tile": 1.0, "yaw": yaw + 90.0, "solid": false})
		var front := Kit.yaw_to_dir(yaw - 90.0)
		Kit.label(self, text + " →", centre + front * 0.04, yaw - 90.0, 22, Color(0.92, 0.86, 0.7), "body", {"pixel_size": 0.008, "outline": 6, "double": false})
		Kit.label(self, "← " + text, centre - front * 0.04, yaw + 90.0, 22, Color(0.92, 0.86, 0.7), "body", {"pixel_size": 0.008, "outline": 6, "double": false})
	Readable.create(self, p, 0.0, "Read the signpost", [
		"THE ANTEROOM. THE WELL. THE ROAD.",
		"Lower down, smaller, in a different hand: none of these are the way out.",
	], {"name": "Signpost", "size": Vector3(0.9, 2.5, 0.9), "note_key": "signpost", "note_title": "The signpost in the clearing", "note_text": "A signpost in a ring of red mushrooms: the Anteroom, the well, the road. Someone added that none of them are the way out."})


# --- the dead grove ---------------------------------------------------------------

func _dead_grove() -> void:
	Kit.ring(self, DEAD_GROVE + Vector3(0, 0.02, 0), 0.0, 9.5, 14, "ground/ash", {"solid": false, "tile": 3.0})
	for i in 10:
		var a := i * 36.0 + rng.randf_range(-12.0, 12.0)
		var p := DEAD_GROVE + Kit.polar(rng.randf_range(3.0, 8.5), a)
		Props.place(self, "tree_dead_1" if i % 3 != 0 else "tree_dead_2", _ground(p.x, p.z) - Vector3(0, 0.1, 0), rng.randf_range(0.0, 360.0), rng.randf_range(0.85, 1.2), {"collision": "cylinder", "collision_scale": 0.3})
		tree_spots.append(p)
	var fpos := DEAD_GROVE + Vector3(1.5, 0, -2.0)
	var fig := Node3D.new()
	fig.name = "Figure"
	fig.position = fpos
	add_child(fig)
	if Props.exists("figure_shadow"):
		Props.place(fig, "figure_shadow", Vector3.ZERO, Kit.dir_to_yaw(CLEARING - fpos), 1.0, {"collision": "none"})
	else:
		var dark := Kit.flat(Color(0.02, 0.02, 0.03), {"unshaded": true})
		Kit.box(fig, Vector3(0, 0.95, 0), Vector3(0.5, 1.9, 0.3), "", {"mat": dark, "solid": false})
		Kit.box(fig, Vector3(0, 2.06, 0), Vector3(0.26, 0.3, 0.26), "", {"mat": dark, "solid": false})
	Kit.lantern_only(fig)
	LookAway.create(self, fpos + Vector3(0, 1.4, 0), _on_figure_seen, {"name": "FigureWatch", "when_seen": true, "delay": 1.2, "once": false, "radius": 18.0, "dot_threshold": 0.9})
	Kit.particles(self, DEAD_GROVE + Vector3(0, 0.8, 0), "fog", Vector3(9, 0.6, 9), 14)
	Kit.particles(self, DEAD_GROVE + Vector3(0, 3, 0), "ash", Vector3(9, 3, 9), 40)
	Kit.light(self, DEAD_GROVE + Vector3(0, 4.0, 0), Color(0.55, 0.6, 0.7), 0.7, 14.0)
	Props.place(self, "rock_2", DEAD_GROVE + Vector3(-3.0, 0, 3.5), 0.0, 1.1)
	Props.place(self, "rock_pale", DEAD_GROVE + Vector3(4.0, 0, 1.0), 80.0, 0.8)
	add_spawn("grove", DEAD_GROVE + Vector3(-7.0, 0.1, 6.0), Kit.dir_to_yaw(fpos - (DEAD_GROVE + Vector3(-7, 0, 6))))


func _on_figure_seen(_l: Node) -> void:
	if not Game.lantern_lit or figure_seen:
		return
	figure_seen = true
	Audio.sfx("whisper", DEAD_GROVE, -4.0)
	Game.bump("figure_sightings")
	Game.note("dead_grove_figure", "Something with the dead trees", "Something stands with the dead trees only when you bring light. It does not move. It is not one of the trees. When the lantern is out it is not there, which is worse.")
	Game.toast.emit("It is standing very still. It was not there without the light.")


# --- trees, undergrowth, lights ------------------------------------------------------

func _trees() -> void:
	var giants := [Vector3(-14, 0, 40), Vector3(44, 0, 30), Vector3(-50, 0, 10), Vector3(9, 0, -6), Vector3(50, 0, -12), Vector3(-20, 0, -58)]
	for gp in giants:
		var p: Vector3 = gp
		Props.place(self, "tree_giant", _ground(p.x, p.z) - Vector3(0, 0.3, 0), rng.randf_range(0.0, 360.0), rng.randf_range(0.85, 1.1), {"collision": "cylinder", "collision_scale": 0.16})
		tree_spots.append(p)
	_scatter_trees("tree_oak_1", 14)
	_scatter_trees("tree_oak_2", 11)
	_scatter_trees("tree_oak_3", 11)
	_scatter_trees("tree_pine_1", 8)
	_scatter_trees("tree_pine_2", 7)
	_scatter_props(["fern_cluster", "bush_1", "bush_2", "fern_cluster"], 34, 2.2, "none")
	_scatter_props(["rock_1", "rock_2", "rock_3", "rock_pale", "boulder"], 14, 3.0, "box")
	_scatter_props(["mushroom_pale", "mushroom_glow_small", "mushroom_pale"], 12, 1.0, "none")


func _scatter_trees(model: String, n: int) -> void:
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 40:
		tries += 1
		var x := rng.randf_range(-66.0, 66.0)
		var z := rng.randf_range(-66.0, 66.0)
		if _path_dist(x, z) < 5.0:
			continue
		var p := Vector3(x, 0, z)
		var ok := true
		for t in tree_spots:
			var tp: Vector3 = t
			if Vector2(p.x - tp.x, p.z - tp.z).length() < 7.5:
				ok = false
				break
		if not ok:
			continue
		tree_spots.append(p)
		Props.place(self, model, _ground(x, z) - Vector3(0, 0.15, 0), rng.randf_range(0.0, 360.0), rng.randf_range(0.85, 1.2), {"collision": "cylinder", "collision_scale": 0.22})
		placed += 1


func _scatter_props(models: Array, n: int, min_path: float, collision: String) -> void:
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 30:
		tries += 1
		var x := rng.randf_range(-62.0, 62.0)
		var z := rng.randf_range(-62.0, 62.0)
		if _path_dist(x, z) < min_path:
			continue
		var model: String = models[placed % models.size()]
		Props.place(self, model, _ground(x, z) - Vector3(0, 0.05, 0), rng.randf_range(0.0, 360.0), rng.randf_range(0.8, 1.3), {"collision": collision})
		placed += 1


## Glowing mushrooms along every path, lighting the way.
func _path_lights() -> void:
	var count := 0
	for seg in PATHS:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var side := Vector2(-dir.y, dir.x)
		var t := 5.0
		while t < length - 3.0:
			var s := 1.0 if count % 2 == 0 else -1.0
			var p2 := a + dir * t + side * s * 2.1
			var p := Vector3(p2.x, 0, p2.y)
			var big := count % 5 == 3
			if big:
				Props.place(self, "mushroom_glow_big", p, rng.randf_range(0.0, 360.0), rng.randf_range(0.7, 1.0), {"collision": "cylinder"})
				Kit.light(self, p + Vector3(0, 1.6, 0), Color(0.45, 1.0, 0.9), 1.5, 11.0)
			else:
				Props.place(self, "mushroom_glow_small", p, rng.randf_range(0.0, 360.0), rng.randf_range(1.0, 1.6), {"collision": "none"})
				Props.place(self, "mushroom_glow_small", p + Vector3(0.5, 0, 0.3), rng.randf_range(0.0, 360.0), rng.randf_range(0.7, 1.0), {"collision": "none"})
				Kit.light(self, p + Vector3(0, 0.9, 0), Color(0.45, 1.0, 0.9), 1.15, 8.5)
			count += 1
			t += 10.5


func _extras() -> void:
	# the Woodcutter, who has lost his axe
	var wc_pos := Vector3(3.4, 0, 45)
	var wc_model := "figure_shadow"
	var wc := NPC.create(self, wc_pos, 90.0, "the Woodcutter", {
		"model": wc_model, "name": "Woodcutter", "on_talk": _woodcutter_talk,
		"lines": [
			"Have you seen an axe? Wooden handle. It was here.",
			"I put it down to rest my arms. When I looked, the trees had closed over it.",
			"Do not put anything down in this wood. It is very tidy.",
		],
		"reactions": {
			"knife": ["That is not it. But it is close. Where did you get that?", "Keep it in your hand. Do not put it down."],
			"crown": ["Your majesty. Have you seen an axe?", "No. No, they never have."],
			"lantern": ["That light. The trees do not like it.", "Good. Neither do I."],
			"bell": ["Ring it again. Perhaps the axe will answer. Nothing else does."],
		},
	})
	if not Props.exists(wc_model):
		_kit_figure(wc, Color(0.3, 0.28, 0.26))
	Kit.cylinder(self, wc_pos + Vector3(1.3, 0, 0.7), 0.45, 0.55, "nature/bark_oak", {"segments": 7})
	Kit.light(self, wc_pos + Vector3(0, 2.4, 0), Color(0.7, 0.8, 0.75), 0.7, 6.0)
	Kit.particles(self, CROSS + Vector3(0, 0.7, 0), "fog", Vector3(8, 0.5, 8), 10)
	Kit.particles(self, HUT + Vector3(0, 0.6, 6.0), "fog", Vector3(6, 0.4, 6), 8)
	Kit.particles(self, Vector3(0, 4, 20), "motes", Vector3(30, 3, 30), 80)
	Kit.particles(self, Vector3(-10, 4, -30), "motes", Vector3(30, 3, 30), 80)
	if visit_count >= 2 and Game.count("usher_sightings") < 9:
		Usher.spawn(self, Vector3(-4.6, 0, 4.0), {"appear_delay": 4.0, "radius": 45.0})


func _woodcutter_talk(_player: Node, _npc: Node) -> bool:
	Game.note("woodcutter", "The Woodcutter", "A man without a face at the edge of the gate path, looking for an axe he put down. The trees closed over it. He says not to put anything down in this wood.")
	return false


# --- hooks --------------------------------------------------------------------------

func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if Game.umbrella_open:
		_start_rain()
	if n == 1:
		Game.note("hollow_wood", "The Hollow Wood", "A wood of giant trees under a moon that does not move. Mushrooms light the paths. Something under the standing stones is waiting to be told the right order.")


func on_lantern(lit: bool) -> void:
	if lit and not Game.has_flag("forest_lantern_lit"):
		Game.set_flag("forest_lantern_lit", true)
		Game.toast.emit("The wood leans in to see what you are carrying.")


func _process(_delta: float) -> void:
	if raining and rain != null and is_instance_valid(rain):
		rain.global_position = player_pos() + Vector3(0, 11, 0)
