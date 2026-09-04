extends AreaBase
## The Ossuary — a maze of bone-walled galleries under everything. Four ways in:
## the well from the Hollow Wood, the sewer from the Drowned City, the stair at
## the end of the Hallway, and the Anteroom's bone door. Sparse candles. The way
## to the reflecting pool is written on the walls, but only the lantern reads it,
## and the bridge across the chasm is only there when you can see it.
##
## Map: cell 2 m, 34 x 34 cells, origin at (-34, 0, -34). Column c is x = -34 +
## (c + 0.5) * 2, row r is z = -34 + (r + 0.5) * 2. Built as nine masked
## sub-maps so every mesh sees only the lights near it.

const CELL := 2.0
const H := 3.2
const ORIGIN := Vector3(-34, 0, -34)
const LOWER_Y := -5.2

const ROWS := [
	"##################################",
	"###......L########################",
	"###.#####.################.P.   .D",
	"###.#####.#...######.#####.#######",
	"###.#####.###.######.#####.#######",
	"#########.###.#####.............##",
	"#########.###.########.###.####.##",
	"#########.###.########..t#.#....##",
	"#########.###...######.###.###..##",
	"#########.###..............####.##",
	"#########.#######.####.###.####.##",
	"#########.#######.####.###.####.##",
	"#W.....................u........##",
	"###.######.#.####D################",
	"###.######.#.#.......#######~~~~~#",
	"#.#.#......#.#.......#######.....#",
	"#.#.########.#..................S#",
	"#.#..........#.......#######.....#",
	"#.#.##.BBBBB.#.......#######~~~~~#",
	"#...##.BfCfB.#.......#############",
	"###.###BfffB.###D#################",
	"###..BBBBGBBBBB#.........#########",
	"###.BafbfffcfdB#.#######.######.##",
	"###.BfffffffffB#.#######.######.##",
	"###.BfffffffffB#.#######.####...##",
	"###.BfffffffffB#.#######.######.##",
	"###.BffffAffffB#.#######D######.##",
	"###.BfffffffffB#.#####......###.##",
	"###.BfffffffffB#.#####......###.##",
	"###.BBBBBDBBBB......##..K.......##",
	"###.#####.####......##......######",
	"###.................##############",
	"##############..N...##############",
	"##################################",
]

## The pit under the chasm and the crawl passage that loops back up.
const LOWER_ROWS := [
	"",
	"                            #####",
	"                            #xxx#",
	"                             #.#",
	"                             #.#",
	"                             #.#",
	"                             #.#",
	"                        ######.#",
	"                        #......#",
	"                        ########",
]

const NAMES_ORDER := ["halden", "annis", "morrow", "elspeth"]
## Gravestone columns along the chapel's north wall and whose name stands there.
const GRAVES := [[5, "morrow"], [7, "elspeth"], [11, "halden"], [13, "annis"]]

var puzzle: Puzzle = null
var candle_lit: Dictionary = {}
var candle_nodes: Dictionary = {}
var candle_lights: Dictionary = {}
var name_order: Array = []
var gate_blocker: StaticBody3D = null
var gate_bars: Node3D = null
var coffin_lid: Node3D = null
var coffin_open := false
var wall_tex := "organic/bones"


func build() -> void:
	Realm.apply(self, "catacombs", {"ambient_energy": 0.42, "fog_density": 0.055})
	_maze()
	_lower()
	_chasm()
	_entrances()
	_chapel()
	_coffin_room()
	_pool_chamber()
	_guidance()
	_dressing()
	if visit_count >= 1 and Game.count("usher_sightings") < 9:
		Usher.spawn(self, _c(23, 12), {"appear_delay": 3.0, "radius": 40.0})
	Dog.maybe_spawn(self, _c(16, 30))


# --- geometry helpers --------------------------------------------------------------

## Floor-level centre of a cell.
func _c(col: int, row: int) -> Vector3:
	return ORIGIN + Vector3((col + 0.5) * CELL, 0, (row + 0.5) * CELL)


func _lower_c(col: int, row: int) -> Vector3:
	return _c(col, row) + Vector3(0, LOWER_Y, 0)


static func _is_wall(ch: String) -> bool:
	return ch == "#" or ch == "B"


## The full map with everything outside the rectangle turned to void, except the
## wall cells that face floor inside it (so their faces still get built).
func _sub_rows(c0: int, r0: int, c1: int, r1: int) -> Array:
	var h := ROWS.size()
	var w := 0
	for r in ROWS:
		w = maxi(w, String(r).length())
	var out: Array = []
	for r in h:
		var line := String(ROWS[r])
		var s := ""
		for c in w:
			var ch := line[c] if c < line.length() else " "
			var inside := c >= c0 and c <= c1 and r >= r0 and r <= r1
			if inside:
				s += ch
			elif _is_wall(ch):
				var keep := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nc: int = c + d.x
					var nr: int = r + d.y
					if nc >= c0 and nc <= c1 and nr >= r0 and nr <= r1 and nr >= 0 and nr < h:
						var nline := String(ROWS[nr])
						var nch := nline[nc] if nc < nline.length() else " "
						if nch != " " and not _is_wall(nch):
							keep = true
				s += ch if keep else " "
			else:
				s += " "
		out.append(s)
	return out


func _maze() -> void:
	var bounds := [0, 11, 22, 33]
	for j in 3:
		for i in 3:
			var c0: int = bounds[i] + (1 if i > 0 else 0)
			var c1: int = bounds[i + 1]
			var r0: int = bounds[j] + (1 if j > 0 else 0)
			var r1: int = bounds[j + 1]
			MapBuilder.build(self, _sub_rows(c0, r0, c1, r1), {
				"cell": CELL, "height": H, "origin": ORIGIN, "name": "Map_%d_%d" % [i, j],
				"floor": "ground/dirt", "wall": wall_tex, "ceiling": "stone/blocks_dark",
				"walls": {"B": "stone/blocks_dark"}, "floors": {"f": "stone/flagstone", "A": "stone/flagstone", "C": "stone/flagstone", "G": "stone/flagstone", "a": "stone/flagstone", "b": "stone/flagstone", "c": "stone/flagstone", "d": "stone/flagstone", "D": "stone/flagstone"},
				"water": "nature/water_dark", "water_floor": "ground/mud", "water_opts": {"tint": Color(0.45, 0.6, 0.45, 0.85), "speed": 0.03},
				"no_ceiling": "LS", "open_edges": true, "door_h": 2.3, "tile": 2.0,
			})


func _lower() -> void:
	MapBuilder.build(self, LOWER_ROWS, {
		"cell": CELL, "height": 2.6, "origin": ORIGIN + Vector3(0, LOWER_Y, 0), "name": "Lower",
		"floor": "ground/mud", "wall": "stone/blocks_dark", "ceiling": "stone/blocks_dark", "no_ceiling": "x", "tile": 2.0,
	})
	var pit := _lower_c(30, 2)
	Kit.light(self, pit + Vector3(0, 1.6, 0), Color(0.5, 0.62, 0.55), 0.55, 8.0)
	_bones(pit + Vector3(-1.6, 0, 0.4), 0.9)
	_bones(_lower_c(28, 8) + Vector3(0.3, 0, -0.5), 0.7)
	Readable.create(self, pit + Vector3(2.0, 0, 0.0), 90.0, "Read the scratches", [
		"Scratched into the stone at the height of someone lying down:",
		"THE BRIDGE IS THERE WHEN YOU CAN SEE IT. I COULD NOT SEE IT.",
		"Under that, a tally. Eleven marks. The twelfth is half finished.",
	], {"name": "PitScratches", "size": Vector3(0.4, 1.6, 1.6), "note_key": "pit_scratches", "note_title": "The pit under the chasm", "note_text": "Someone at the bottom of the chasm scratched: the bridge is there when you can see it. They counted eleven days. The passage from the pit crawls back up into the maze somehow."})
	Kit.trigger(self, pit + Vector3(0, 1.0, 0), Vector3(5.6, 2.0, 1.8), _on_fell, {"once": true, "name": "PitTrigger"})
	SeamlessTeleport.create(self, _lower_c(25, 8), 90.0, _c(24, 7), 90.0, Vector3(1.8, 2.4, 0.6), {"name": "CrawlSeam", "count_flag": "ossuary_crawls", "on_teleport": _on_crawl})
	Kit.light(self, _lower_c(30, 6) + Vector3(0, 1.8, 0), Color(0.45, 0.5, 0.45), 0.5, 7.0)
	Kit.light(self, _lower_c(26, 8) + Vector3(0, 1.8, 0), Color(0.45, 0.5, 0.45), 0.5, 7.0)


func _on_fell(_p: Node) -> void:
	Audio.sfx("land", _lower_c(30, 2), -4.0)
	Game.toast.emit("The bridge was not there. You are at the bottom of where it was not.")
	Game.note("chasm", "The chasm", "A gap in the corridor to the reflecting pool. Without the lantern lit there is no bridge, only a drop into a pit and a long crawl back.")


func _on_crawl(_p: Node) -> void:
	Game.toast.emit("The crawl comes up somewhere it should not. You do not argue.")


## The gap in the pool corridor: a hole in the floor over the pit, walls down its
## sides, and a plank bridge that only exists in lantern light.
func _chasm() -> void:
	var mid := _c(30, 2)
	var top_y := H
	# side walls from the top of the lower walls up to the ceiling
	Kit.box(self, mid + Vector3(0, (top_y + LOWER_Y + 2.6) * 0.5, -CELL * 0.5 - 0.15), Vector3(6.0, top_y - (LOWER_Y + 2.6), 0.3), wall_tex, {"tile": 2.0})
	Kit.box(self, mid + Vector3(0, (top_y + LOWER_Y + 2.6) * 0.5, CELL * 0.5 + 0.15), Vector3(6.0, top_y - (LOWER_Y + 2.6), 0.3), wall_tex, {"tile": 2.0})
	# end walls under the floor edges
	Kit.box(self, mid + Vector3(-3.0 - 0.1, (LOWER_Y + 2.6 - 0.03) * 0.5, 0), Vector3(0.2, -(LOWER_Y + 2.6) - 0.03, CELL), "stone/blocks_dark", {"tile": 2.0})
	Kit.box(self, mid + Vector3(3.0 + 0.1, (LOWER_Y + 2.6 - 0.03) * 0.5, 0), Vector3(0.2, -(LOWER_Y + 2.6) - 0.03, CELL), "stone/blocks_dark", {"tile": 2.0})
	Kit.ceiling(self, mid + Vector3(0, top_y, 0), Vector2(6.0, CELL), "stone/blocks_dark")
	# the bridge
	var bridge := Kit.box(self, mid + Vector3(0, -0.15, 0), Vector3(6.6, 0.3, 1.3), "wood/planks_grey", {"tile": 1.0, "surface": "wood", "name": "Bridge"})
	Kit.lantern_only(bridge)
	var rail := Kit.box(self, mid + Vector3(0, 0.5, 0.62), Vector3(6.6, 0.08, 0.08), "wood/planks_dark", {"solid": false})
	Kit.lantern_only(rail)
	var marker := Kit.label(self, "→ the bridge is there when you can see it →", mid + Vector3(-1.0, 2.1, -CELL * 0.5 - 0.02), 180.0, 30, Color(0.6, 1.0, 0.85), "body", {"pixel_size": 0.011})
	Kit.lantern_only(marker)
	Kit.light(self, mid + Vector3(0, 2.4, 0), Color(0.4, 0.5, 0.55), 0.45, 8.0)
	Kit.particles(self, mid + Vector3(0, 0.5, 0), "fog", Vector3(4, 0.5, 1), 6)


# --- the four ways in -----------------------------------------------------------------

func _entrances() -> void:
	# south: the Anteroom's bone door
	var n := _c(16, 32)
	Kit.arch(self, n + Vector3(0, 0, 0.55), 0.0, 1.4, 2.6, "organic/bones", {"depth": 0.6, "post": 0.3, "top": 0.4, "tile": 1.0})
	Door.create(self, n + Vector3(0, 0, 0.7), 0.0, "nexus", "from_catacombs", {"kind": "dark", "label": "Back to the Anteroom", "name": "NexusDoor"})
	_lamp(_c(14, 31) + Vector3(0.3, 0, 0.3))
	_lamp(_c(19, 31) + Vector3(-0.3, 0, 0.3))
	Kit.label(self, "EVERYONE IS HERE", n + Vector3(0, 2.75, 0.4), 0.0, 30, Color(0.75, 0.7, 0.55), "display", {"pixel_size": 0.011})
	add_spawn("from_nexus", _c(16, 30) + Vector3(0, 0.1, 0.4), 0.0)
	add_spawn("default", _c(16, 30) + Vector3(0, 0.1, 0.4), 0.0)
	# north: the ladder up the well shaft
	var l := _c(9, 1)
	var shaft_top := 9.5
	var sh := shaft_top - H
	Kit.box(self, l + Vector3(0, H + sh * 0.5, -CELL * 0.5 - 0.15), Vector3(CELL + 0.6, sh, 0.3), "stone/cobble_grey", {"tile": 1.0})
	Kit.box(self, l + Vector3(0, H + sh * 0.5, CELL * 0.5 + 0.15), Vector3(CELL + 0.6, sh, 0.3), "stone/cobble_grey", {"tile": 1.0})
	Kit.box(self, l + Vector3(-CELL * 0.5 - 0.15, H + sh * 0.5, 0), Vector3(0.3, sh, CELL), "stone/cobble_grey", {"tile": 1.0})
	Kit.box(self, l + Vector3(CELL * 0.5 + 0.15, H + sh * 0.5, 0), Vector3(0.3, sh, CELL), "stone/cobble_grey", {"tile": 1.0})
	Kit.ceiling(self, l + Vector3(0, shaft_top, 0), Vector2(CELL + 0.6, CELL + 0.6), "stone/cobble_grey")
	_ladder(l + Vector3(0, 0, -CELL * 0.5 + 0.12), 0.0, shaft_top - 0.6)
	Door.create(self, l + Vector3(0, 0, -CELL * 0.5 + 0.35), 180.0, "forest", "well_top", {"kind": "none", "label": "Climb the ladder", "name": "WellLadder", "fade_color": Color(0.05, 0.12, 0.1), "fade_duration": 1.2, "sound": "creak"})
	Kit.light(self, l + Vector3(0, shaft_top - 0.8, 0), Color(0.55, 0.75, 0.8), 1.0, 9.0)
	Kit.particles(self, l + Vector3(0, 5.0, 0), "rain", Vector3(0.3, 2.0, 0.3), 24)
	Kit.water(self, l + Vector3(0, 0.02, 0), Vector2(1.6, 1.6), "nature/water_dark", {"tint": Color(0.5, 0.6, 0.7, 0.6), "subdiv": 2})
	_lamp(_c(9, 3) + Vector3(0.6, 0, 0))
	add_spawn("from_well", l + Vector3(0, 0.1, 0.9), 180.0)
	# east: the sewer grate
	var s := _c(32, 16)
	Kit.box(self, s + Vector3(0, H + sh * 0.5, -CELL * 0.5 - 0.15), Vector3(CELL + 0.6, sh, 0.3), "brick/dark", {"tile": 1.0})
	Kit.box(self, s + Vector3(0, H + sh * 0.5, CELL * 0.5 + 0.15), Vector3(CELL + 0.6, sh, 0.3), "brick/dark", {"tile": 1.0})
	Kit.box(self, s + Vector3(-CELL * 0.5 - 0.15, H + sh * 0.5, 0), Vector3(0.3, sh, CELL), "brick/dark", {"tile": 1.0})
	Kit.box(self, s + Vector3(CELL * 0.5 + 0.15, H + sh * 0.5, 0), Vector3(0.3, sh, CELL), "brick/dark", {"tile": 1.0})
	Kit.sign(self, "metal/grate", s + Vector3(0, shaft_top - 0.05, 0), 0.0, Vector2(2.0, 2.0), {"rotation": Vector3(90, 0, 0), "double": true})
	Kit.ceiling(self, s + Vector3(0, shaft_top + 0.1, 0), Vector2(CELL + 0.6, CELL + 0.6), "brick/dark")
	_ladder(s + Vector3(CELL * 0.5 - 0.12, 0, 0), -90.0, shaft_top - 0.4)
	Door.create(self, s + Vector3(CELL * 0.5 - 0.35, 0, 0), 90.0, "city", "sewer_top", {"kind": "iron", "label": "Up the sewer ladder", "name": "SewerDoor", "fade_color": Color(0.1, 0.12, 0.14), "fade_duration": 1.0, "sound": "door_heavy"})
	Kit.light(self, s + Vector3(0, shaft_top - 1.0, 0), Color(0.6, 0.7, 0.6), 0.9, 8.0)
	Kit.particles(self, s + Vector3(-0.4, 4.0, 0.3), "rain", Vector3(0.25, 1.5, 0.25), 20)
	if Props.exists("drain_grate"):
		Props.place(self, "drain_grate", _c(30, 16), 0.0, 1.0, {"collision": "none"})
	else:
		Kit.sign(self, "metal/grate", _c(30, 16) + Vector3(0, 0.02, 0), 0.0, Vector2(1.2, 1.2), {"rotation": Vector3(-90, 0, 0)})
	_lamp(_c(29, 15) + Vector3(-0.5, 0, 0.6))
	_lamp(_c(31, 17) + Vector3(0.4, 0, -0.6))
	Readable.create(self, _c(28, 16) + Vector3(-0.8, 0, 0), -90.0, "Read the brick", ["Chalked on the brick, in a hand that was in a hurry: DO NOT DRINK. DO NOT LISTEN.", "The water in the channels is going somewhere. It is not in a hurry."], {"name": "SewerChalk", "size": Vector3(0.3, 2.0, 1.6), "note_key": "sewer_chalk", "note_title": "The sewer end of the Ossuary", "note_text": "A brick chamber with two channels of slow water and a ladder up to the Drowned City. Do not drink, do not listen."})
	add_spawn("from_sewer", _c(30, 16) + Vector3(0.6, 0.1, 0), 90.0)
	# west: the small door to the stair
	var w := _c(1, 12)
	Door.create(self, w + Vector3(-CELL * 0.5 + 0.16, 0, 0), -90.0, "hallway", "stairs", {"kind": "wood", "label": "The stair up", "name": "StairDoor", "fade_duration": 1.0})
	Kit.label(self, "5 ½", w + Vector3(-CELL * 0.5 + 0.09, 2.5, 0), -90.0, 30, Color(0.7, 0.65, 0.5), "display", {"pixel_size": 0.01})
	_lamp(_c(2, 12) + Vector3(0.4, 0, -0.6))
	add_spawn("from_stairs", _c(2, 12) + Vector3(-0.2, 0.1, 0), -90.0)


func _ladder(pos: Vector3, yaw: float, top: float) -> void:
	var root := Node3D.new()
	root.name = "Ladder"
	root.position = pos
	root.rotation.y = deg_to_rad(yaw)
	add_child(root)
	Kit.box(root, Vector3(-0.35, top * 0.5, 0), Vector3(0.07, top, 0.07), "wood/planks_dark", {"solid": false})
	Kit.box(root, Vector3(0.35, top * 0.5, 0), Vector3(0.07, top, 0.07), "wood/planks_dark", {"solid": false})
	var y := 0.45
	while y < top:
		Kit.box(root, Vector3(0, y, 0.02), Vector3(0.76, 0.06, 0.06), "wood/planks_grey", {"solid": false})
		y += 0.42


func _on_plinth(_p: Node, _it: Node) -> void:
	if World.hud == null:
		return
	if Game.has_flag("crypt_candle_placed"):
		await World.hud.say("", ["The black candle stands on the plinth, burning at both ends and the middle, and not getting any shorter.", "The three niches are empty now. The fourth still has its chair."])
		return
	if not Game.has_item("candle_stub"):
		await World.hud.say("", ["A plinth with a ring of old wax on it, where a candle stood for a long time and was taken.", "The three niches with bones in them face it, the way an audience faces a stage that has not been used lately."])
		return
	Game.take_item("candle_stub")
	Game.set_flag("crypt_candle_placed", true)
	await World.hud.say("", [
		"You stand the black stub in the ring of wax it left. It lights itself, at both ends and the middle, which is not how candles work.",
		"The three names on the stones outside go quiet in a way you can feel through the floor.",
		"In the niches the bones stir, and settle, and slide forward off their shelves into your hands, all three, light as kindling. The fourth niche does not move. The chair in it is still facing out.",
	])
	Game.gain_item("bones")
	Audio.sfx("whisper", null, -6.0)
	Game.note("crypt_bones", "The candle and the bones", "The black candle from the forge went back on the plinth in the crypt of the four, and the three niches gave up their bones. Bone that light wants breaking. There is an anvil in the forge.")


# --- the chapel of the four names --------------------------------------------------------

func _chapel() -> void:
	var solved := Game.has_flag("ossuary_names")
	puzzle = Puzzle.declare(self, "ossuary_names", "ossuary_names", [], "light the candles for the four names in the order they went down the well")
	var wall_z := ORIGIN.z + 22 * CELL
	for g in GRAVES:
		var col: int = g[0]
		var who: String = g[1]
		var base := Vector3(_c(col, 22).x, 0, wall_z + 0.5)
		Props.place(self, "gravestone_" + who, base, 180.0, 1.1, {"collision": "box", "name": "Grave_" + who})
		var cpos := base + Vector3(0, 0, 0.9)
		var lit := solved
		candle_lit[who] = lit
		var stub := Kit.cylinder(self, cpos, 0.05, 0.16, "", {"mat": Kit.flat(Color(0.92, 0.88, 0.78)), "segments": 6, "solid": false})
		stub.name = "Stub_" + who
		var candle := Props.place(self, "candle", cpos + Vector3(0, 0.1, 0), 0.0, 1.3, {"collision": "none", "name": "Candle_" + who})
		candle.visible = lit
		candle_nodes[who] = candle
		var light := Kit.light(self, cpos + Vector3(0, 0.7, 0), Color(1.0, 0.72, 0.4), 0.9, 5.0)
		light.visible = lit
		candle_lights[who] = light
		var pretty := who.capitalize()
		Interactable.make(self, cpos, Vector3(0.7, 0.9, 0.7), "Light the candle for " + pretty, _on_candle.bind(who), {"name": "CandleFor_" + who})
		Kit.label(self, pretty.to_upper(), base + Vector3(0, 1.45, 0.1), 180.0, 22, Color(0.75, 0.7, 0.55), "body", {"pixel_size": 0.009})
	# the altar and its riddle
	var altar := _c(9, 26)
	if Props.exists("altar"):
		Props.place(self, "altar", altar, 0.0, 1.0, {"collision": "box", "name": "Altar"})
	else:
		Kit.box(self, altar + Vector3(0, 0.47, 0), Vector3(1.6, 0.94, 0.8), "stone/blocks_dark", {"tile": 1.0})
		Kit.box(self, altar + Vector3(0, 0.99, 0), Vector3(1.72, 0.1, 0.92), "stone/smooth_grey", {"tile": 1.0})
		Kit.box(self, altar + Vector3(0, 1.055, 0), Vector3(0.5, 0.02, 0.94), "fabric/cloth_red", {"solid": false, "tile": 1.0})
		Props.place(self, "candle_tall", altar + Vector3(-0.55, 1.04, 0), 0.0, 1.0, {"collision": "none"})
		Props.place(self, "candle_tall", altar + Vector3(0.55, 1.04, 0), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, altar + Vector3(0, 1.9, 0), Color(1.0, 0.7, 0.4), 1.1, 7.0)
	Readable.create(self, altar + Vector3(0, 1.1, 0), 0.0, "Read the altar", [
		"Cut into the altar stone, the letters filled with old wax:",
		"FOUR WENT DOWN THE WELL AND ARE BURIED HERE IN THE ORDER THEY STOPPED COMING BACK.",
		"Halden slept first, in the well. Annis followed him down.",
		"Morrow waited a year. Elspeth is still deciding.",
		"Light them in the order they slept, and the gate will remember it is only iron.",
	], {"name": "AltarRiddle", "size": Vector3(1.7, 0.6, 0.9), "note_key": "altar_riddle", "note_title": "The four names", "note_text": "Halden slept first, in the well. Annis followed him down. Morrow waited a year. Elspeth is still deciding. Light their candles in that order."})
	Props.place(self, "bench", _c(7, 27), 90.0, 1.0)
	Props.place(self, "bench", _c(11, 27), -90.0, 1.0)
	Props.place(self, "gravestone_blank", _c(5, 28) + Vector3(0, 0, 0.5), 180.0, 1.0)
	Props.place(self, "gravestone_you", _c(13, 28) + Vector3(0, 0, 0.5), 180.0, 1.0)
	Readable.create(self, _c(13, 28) + Vector3(0, 0, 0.5), 180.0, "Read the small stone", ["The stone has your name on it. The dates are blank.", "Someone has chalked underneath: NOT YET."], {"name": "YourStone", "size": Vector3(1.0, 1.2, 0.8), "note_key": "your_stone", "note_title": "A stone with your name", "note_text": "In the chapel of the Ossuary there is a gravestone with your name on it. The dates are blank. Someone chalked: not yet."})
	_lamp(_c(5, 24) + Vector3(-0.5, 0, 0))
	_lamp(_c(13, 24) + Vector3(0.5, 0, 0))
	_lamp(_c(9, 28) + Vector3(0.9, 0, 0.6))
	Props.place(self, "chain_hanging", _c(9, 24) + Vector3(0, H, 0), 0.0, 0.45, {"collision": "none"})
	Kit.particles(self, _c(9, 25) + Vector3(0, 1.5, 0), "motes", Vector3(7, 1.5, 5), 40)
	# the gate into the crypt
	var gpos := _c(9, 21)
	if not solved:
		gate_blocker = Kit.blocker(self, gpos + Vector3(0, H * 0.5, 0), Vector3(CELL, H, 0.4))
		gate_blocker.name = "GateBlocker"
		if Props.exists("portcullis"):
			gate_bars = Props.place(self, "portcullis", gpos + Vector3(0, 0, 0), 0.0, 0.66, {"collision": "none", "name": "GateBars"})
		else:
			gate_bars = Kit.sign(self, "metal/bars", gpos + Vector3(0, H * 0.5, 0), 0.0, Vector2(CELL, H), {"double": true, "name": "GateBars"})
		Interactable.make(self, gpos + Vector3(0, 0, 0.6), Vector3(1.6, 2.0, 0.4), "Try the gate", func(_p: Node, _i: Node) -> void:
			Audio.sfx("chain_rattle", gpos, -6.0)
			Game.toast.emit("Iron, and cold, and bolted from a side you cannot see. The names on the stones are watching."), {"name": "GateTry"})
	# the crypt beyond
	var crypt := _c(9, 19)
	Kit.box(self, crypt + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 1.0), "stone/blocks_dark", {"tile": 1.0})
	# the plinth: the black candle from the forge was taken from here and is
	# owed back; put on it, the three niches give up their bones
	if Game.has_flag("crypt_candle_placed"):
		Props.place(self, "candle_cluster", crypt + Vector3(0, 0.6, 0), 0.0, 0.5, {"collision": "none", "tint": Color(0.15, 0.12, 0.14)})
		Kit.light(self, crypt + Vector3(0, 1.0, 0), Color(0.6, 0.4, 0.9), 0.7, 4.0)
	Interactable.make(self, crypt + Vector3(0, 0.75, 0), Vector3(1.2, 1.0, 1.2), "The plinth", _on_plinth, {"name": "CryptPlinth"})
	Puzzle.declare(self, "crypt_bones", "crypt_candle_placed", ["flag:ossuary_names", "item:candle_stub"], "put the black candle from the forge back on the plinth in the crypt of the four", {"item": "bones"})
	Readable.create(self, crypt + Vector3(0, 0, -0.85), 180.0, "Read the crypt wall", [
		"Four niches. Four names. Three of them have bones in.",
		"The fourth niche is swept clean and there is a chair in it, facing out.",
	], {"name": "CryptWall", "size": Vector3(1.8, 2.0, 0.3), "note_key": "crypt", "note_title": "The crypt of the four", "note_text": "Behind the iron gate in the Ossuary chapel: four niches, three with bones. The fourth is swept and has a chair in it, facing out. A candle stub was left on the plinth, burnt from both ends."})
	Kit.light(self, crypt + Vector3(0, 2.2, 0), Color(1.0, 0.65, 0.35), 0.8, 6.0)
	Props.place(self, "chair", _c(10, 19) + Vector3(0.3, 0, -0.3), 200.0, 1.0)
	_bones(_c(8, 19) + Vector3(-0.3, 0, -0.4), 0.8)
	_bones(_c(8, 20) + Vector3(-0.3, 0, 0.4), 0.6)
	add_spawn("chapel", _c(9, 29) + Vector3(0, 0.1, 0.6), 0.0)


func _on_candle(_p: Node, it: Node, who: String) -> void:
	if puzzle.is_solved():
		Game.toast.emit("The candle is lit. It has been lit for some time.")
		return
	var was_lit: bool = candle_lit.get(who, false)
	if was_lit:
		_set_candle(who, false)
		name_order.clear()
		_snuff_candles()
		Game.toast.emit("You pinch it out. The order forgets itself.")
		return
	_set_candle(who, true)
	Audio.sfx("brazier", it.global_position, -14.0)
	name_order.append(who)
	var ok := true
	for i in name_order.size():
		if String(name_order[i]) != String(NAMES_ORDER[i]):
			ok = false
	if not ok:
		Audio.sfx("whisper", it.global_position, -2.0)
		Game.toast.emit("A breath from nowhere. Every candle goes out. That was not the order.")
		name_order.clear()
		get_tree().create_timer(0.6).timeout.connect(_snuff_candles)
		return
	if name_order.size() == NAMES_ORDER.size():
		_solve_names()
	else:
		Game.toast.emit("The flame stands very straight. Something is counting.")


func _set_candle(who: String, lit: bool) -> void:
	candle_lit[who] = lit
	var n: Node3D = candle_nodes.get(who, null)
	if n != null and is_instance_valid(n):
		n.visible = lit
	var l: OmniLight3D = candle_lights.get(who, null)
	if l != null and is_instance_valid(l):
		l.visible = lit


func _snuff_candles() -> void:
	if not is_inside_tree() or puzzle.is_solved():
		return
	for who in candle_nodes:
		_set_candle(String(who), false)
	name_order.clear()


func _solve_names() -> void:
	puzzle.solve("The names are in order. Somewhere close, a gate forgets it is locked.")
	Audio.sfx("stone_grind", _c(9, 21), -3.0)
	Game.note("gate_open", "The iron gate", "Halden, Annis, Morrow, Elspeth. The candles burned in that order and the gate in the chapel remembered it was only iron.")
	if gate_blocker != null and is_instance_valid(gate_blocker):
		gate_blocker.queue_free()
		gate_blocker = null
	if gate_bars != null and is_instance_valid(gate_bars):
		var tw := create_tween()
		tw.tween_property(gate_bars, "position:y", gate_bars.position.y + H, 1.6).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(gate_bars.queue_free)
	var gt := get_node_or_null("GateTry")
	if gt != null:
		gt.queue_free()


# --- the coffin room ---------------------------------------------------------------

func _coffin_room() -> void:
	var k := _c(24, 29)
	if Props.exists("coffin"):
		var inst := Props.place(self, "coffin", k, 90.0, 1.0, {"collision": "box", "name": "Coffin"})
		coffin_lid = Props.part(inst, "Lid")
	else:
		Kit.box(self, k + Vector3(0, 0.25, 0), Vector3(1.9, 0.5, 0.8), "wood/planks_dark", {"tile": 1.0, "name": "Coffin"})
		var pivot := Node3D.new()
		pivot.name = "CoffinLid"
		pivot.position = k + Vector3(0, 0.52, -0.4)
		add_child(pivot)
		Kit.box(pivot, Vector3(0, 0.04, 0.4), Vector3(1.96, 0.08, 0.84), "wood/planks_grey", {"solid": false, "tile": 1.0})
		coffin_lid = pivot
	Interactable.make(self, k, Vector3(2.0, 1.0, 1.0), "Open the coffin", _open_coffin, {"name": "CoffinOpen"})
	Kit.box(self, k + Vector3(0, 0.1, 0), Vector3(2.2, 0.2, 1.1), "stone/blocks_dark", {"tile": 1.0})
	_lamp(_c(22, 27) + Vector3(-0.5, 0, -0.5))
	_lamp(_c(27, 30) + Vector3(0.5, 0, 0.5))
	Kit.light(self, k + Vector3(0, 2.6, 0), Color(0.6, 0.55, 0.5), 0.6, 8.0)
	_sarcophagus(_c(23, 28) + Vector3(-0.2, 0, -0.5), 0.0)
	_sarcophagus(_c(26, 28) + Vector3(0.2, 0, -0.5), 0.0)
	_urn(_c(22, 30) + Vector3(-0.4, 0, 0.5))
	_urn(_c(22, 30) + Vector3(0.2, 0, 0.7))
	_urn(_c(27, 27) + Vector3(0.5, 0, -0.5))
	_bones(_c(26, 30) + Vector3(0.5, 0, 0.5), 1.0)
	Props.place(self, "chain_hanging", _c(24, 28) + Vector3(0.6, H, 0), 0.0, 0.5, {"collision": "none"})
	Props.place(self, "cage", _c(22, 28) + Vector3(-0.6, 0, 0.6), 0.0, 0.5, {"collision": "none"})
	Kit.particles(self, k + Vector3(0, 1.4, 0), "motes", Vector3(5, 1.2, 4), 30)
	add_spawn("coffin", _c(24, 26) + Vector3(0, 0.1, 0.4), 0.0)


func _open_coffin(_p: Node, it: Node) -> void:
	if coffin_open:
		Game.toast.emit("It is open. The card has not changed its mind.")
		return
	coffin_open = true
	Audio.sfx("door_creak_long", it.global_position, -6.0)
	if coffin_lid != null and is_instance_valid(coffin_lid):
		var tw := create_tween()
		tw.tween_property(coffin_lid, "rotation:z", deg_to_rad(105.0), 1.8).set_ease(Tween.EASE_OUT)
		await tw.finished
	if World.hud:
		await World.hud.say("", [
			"Inside, on a cushion of dust, a card. It says RESERVED.",
			"There is no name on the card. There is a smudge where a name would go, about the size of your thumb.",
		])
	Game.note("coffin_reserved", "Reserved", "A coffin in the Ossuary with a card inside: RESERVED. No name, only a thumb-sized smudge where one would go. You closed nothing. It stays open.")
	var i := it as Interactable
	if i != null:
		i.prompt = "Look into the coffin"


# --- the reflecting pool ---------------------------------------------------------------

func _pool_chamber() -> void:
	var exit_c := _c(33, 2)
	var c := Vector3(exit_c.x + 1.0 + 2.5 + 7.0, 0, exit_c.z)
	# the short corridor out of the maze
	var cor := Vector3(exit_c.x + 1.0 + 1.35, 0, exit_c.z)
	Kit.floor(self, cor, Vector2(2.7, CELL), "stone/flagstone")
	Kit.ceiling(self, cor + Vector3(0, H, 0), Vector2(2.7, CELL), "stone/blocks_dark")
	Kit.box(self, cor + Vector3(-0.2, H * 0.5, -CELL * 0.5 - 0.1), Vector3(2.3, H, 0.2), wall_tex)
	Kit.box(self, cor + Vector3(-0.2, H * 0.5, CELL * 0.5 + 0.1), Vector3(2.3, H, 0.2), wall_tex)
	# the chamber
	Kit.ring(self, c, 4.9, 8.6, 24, "stone/flagstone", {"tile": 2.0})
	Kit.ring(self, c + Vector3(0, -0.45, 0), 0.0, 5.0, 24, "ground/mud", {"surface": "water"})
	Kit.round_wall(self, c + Vector3(0, -0.45, 0), 4.9, 0.45, 24, "stone/blocks_dark", {"tile": 1.0})
	Kit.round_wall(self, c, 7.0, 5.0, 24, wall_tex, {"gaps": [[180.0, 30.0]], "tile": 2.0})
	Kit.box(self, c + Vector3(-7.0, H + (5.0 - H) * 0.5, 0), Vector3(0.4, 5.0 - H, 4.0), wall_tex)
	Kit.box(self, c + Vector3(-7.0, H * 0.5, -CELL * 0.5 - 0.5), Vector3(0.4, H, 1.0), wall_tex)
	Kit.box(self, c + Vector3(-7.0, H * 0.5, CELL * 0.5 + 0.5), Vector3(0.4, H, 1.0), wall_tex)
	Kit.ring(self, c + Vector3(0, 5.0, 0), 0.0, 8.8, 24, "stone/blocks_dark", {"down": true, "tile": 2.0})
	Kit.water(self, c + Vector3(0, -0.12, 0), Vector2(9.8, 9.8), "nature/water_dark", {"tint": Color(0.72, 0.84, 0.9, 0.85), "speed": 0.004, "swell": 0.012, "glow": 0.15, "subdiv": 4})
	Kit.cylinder(self, c + Vector3(0, -0.45, 0), 0.55, 0.85, "stone/marble_black", {"segments": 8, "tile": 1.0})
	Pickup.create(self, c + Vector3(0, 0.4, 0), {"keepsake": "shard", "requires_keepsake": "lantern", "name": "Pickup_shard"})
	Readable.create(self, c + Vector3(-5.6, 0, 0), 90.0, "Look into the pool", [
		"The pool shows the ceiling of a different room.",
		"Plaster, a crack, a light fitting with no bulb in it. A ceiling you have lain under. It does not show you.",
		"In the middle of the water, on a black stone, a piece of a mirror is showing something else again.",
	], {"name": "PoolLook", "size": Vector3(0.8, 1.2, 2.4), "note_key": "pool", "note_title": "The reflecting pool", "note_text": "A still pool at the far end of the Ossuary. It reflects the ceiling of a different room, one you have lain under. A shard of mirror waits on a stone in the middle."})
	Kit.light(self, c + Vector3(0, 3.2, 0), Color(0.6, 0.9, 0.95), 1.3, 12.0)
	for i in 4:
		var a := 45.0 + i * 90.0
		_lamp(c + Kit.polar(6.2, a))
	for i in 3:
		Props.place(self, "chain_hanging", c + Kit.polar(2.6, 30.0 + i * 120.0, 5.0), 0.0, 0.7, {"collision": "none"})
	_bones(c + Kit.polar(6.0, 20.0), 1.1)
	_bones(c + Kit.polar(6.4, 300.0), 0.8)
	_urn(c + Kit.polar(6.4, 100.0))
	_urn(c + Kit.polar(6.5, 250.0))
	Props.place(self, "pillar_broken", c + Kit.polar(6.0, 145.0), 0.0, 0.9, {"collision": "cylinder"})
	Props.place(self, "statue_kneeling", c + Kit.polar(6.2, 60.0), Kit.yaw_to_center(60.0), 0.9)
	Kit.particles(self, c + Vector3(0, 1.5, 0), "motes", Vector3(5, 2, 5), 50)
	Kit.particles(self, c + Vector3(0, 0.2, 0), "fog", Vector3(5, 0.3, 5), 8)
	Kit.label(self, "THE POOL SHOWS THE CEILING OF A DIFFERENT ROOM", c + Vector3(6.9, 2.6, 0), 90.0, 26, Color(0.7, 0.85, 0.85), "body", {"pixel_size": 0.011})
	add_spawn("pool", c + Vector3(-6.0, 0.1, 0), -90.0)


# --- guidance you can only read by lantern light -----------------------------------------

## A word on the face of a wall cell, toward the floor cell on `face` ("n","s","e","w").
func _mark(col: int, row: int, face: String, text: String) -> void:
	var p := _c(col, row) + Vector3(0, 2.15, 0)
	var yaw := 0.0
	match face:
		"s":
			p += Vector3(0, 0, CELL * 0.5 + 0.04)
			yaw = 180.0
		"n":
			p += Vector3(0, 0, -CELL * 0.5 - 0.04)
			yaw = 0.0
		"e":
			p += Vector3(CELL * 0.5 + 0.04, 0, 0)
			yaw = -90.0
		"w":
			p += Vector3(-CELL * 0.5 - 0.04, 0, 0)
			yaw = 90.0
	var l := Kit.label(self, text, p, yaw, 44, Color(0.6, 1.0, 0.85), "display", {"pixel_size": 0.012})
	Kit.lantern_only(l)


func _guidance() -> void:
	_mark(15, 28, "s", "↑ this way")
	_mark(16, 13, "s", "↑ the pool")
	_mark(17, 11, "s", "→ →")
	_mark(26, 13, "n", "↑ turn here")
	_mark(27, 11, "s", "↑")
	_mark(25, 2, "e", "→")
	_mark(27, 1, "s", "→ the pool")
	_mark(30, 11, "n", "not this way")
	_mark(3, 13, "n", "no")
	_mark(9, 11, "s", "↓ the pool is south, then east")
	# bone piles that glow only for the lantern
	for p in [_c(22, 12) + Vector3(0, 0, -0.6), _c(26, 8) + Vector3(0.6, 0, 0), _c(28, 2) + Vector3(0, 0, 0.6), _c(16, 24) + Vector3(0.6, 0, 0)]:
		var pos: Vector3 = p
		var pile := Node3D.new()
		pile.position = pos
		add_child(pile)
		if Props.exists("bone_pile"):
			Props.place(pile, "bone_pile", Vector3.ZERO, rng.randf_range(0.0, 360.0), 0.8, {"collision": "none", "unshaded": true, "tint": Color(0.7, 1.0, 0.85)})
		else:
			var glow := Kit.mat("organic/bones", {"unshaded": true, "tint": Color(0.7, 1.0, 0.85)})
			Kit.box(pile, Vector3(0, 0.18, 0), Vector3(0.9, 0.36, 0.7), "organic/bones", {"mat": glow, "solid": false})
			Kit.box(pile, Vector3(0.2, 0.42, -0.1), Vector3(0.4, 0.2, 0.4), "organic/bones", {"mat": glow, "solid": false})
		Kit.lantern_only(pile)


# --- dressing --------------------------------------------------------------------------

func _lamp(pos: Vector3) -> void:
	if Props.exists("ossuary_lamp"):
		Props.place(self, "ossuary_lamp", pos, rng.randf_range(0.0, 360.0), 1.0, {"collision": "none"})
		Kit.light(self, pos + Vector3(0, 1.1, 0), Color(1.0, 0.6, 0.3), 0.85, 6.5)
	else:
		Kit.box(self, pos + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.5), "organic/bones", {"tile": 1.0})
		Props.place(self, "candle_cluster", pos + Vector3(0, 0.6, 0), rng.randf_range(0.0, 360.0), 1.2, {"collision": "none"})
		Kit.light(self, pos + Vector3(0, 1.1, 0), Color(1.0, 0.6, 0.3), 0.85, 6.5)


func _bones(pos: Vector3, scale: float) -> void:
	if Props.exists("bone_pile"):
		Props.place(self, "bone_pile", pos, rng.randf_range(0.0, 360.0), scale, {"collision": "none"})
		if Props.exists("skull") and rng.randf() < 0.6:
			Props.place(self, "skull", pos + Vector3(0.5 * scale, 0, 0.3 * scale), rng.randf_range(0.0, 360.0), 1.0, {"collision": "none"})
		return
	Kit.box(self, pos + Vector3(0, 0.16 * scale, 0), Vector3(0.9, 0.32, 0.7) * scale, "organic/bones", {"tile": 0.7, "solid": false})
	Kit.box(self, pos + Vector3(0.15 * scale, 0.4 * scale, -0.1 * scale), Vector3(0.45, 0.18, 0.4) * scale, "organic/bones", {"tile": 0.7, "solid": false})


func _urn(pos: Vector3) -> void:
	if Props.exists("urn"):
		Props.place(self, "urn", pos, rng.randf_range(0.0, 360.0), 1.0, {"collision": "cylinder"})
	else:
		Kit.cylinder(self, pos, 0.24, 0.85, "wall/tile_terracotta", {"top_radius": 0.14, "segments": 7, "tile": 1.0})


func _sarcophagus(pos: Vector3, yaw: float) -> void:
	if Props.exists("sarcophagus"):
		Props.place(self, "sarcophagus", pos, yaw, 1.0, {"collision": "box"})
	else:
		Kit.box(self, pos + Vector3(0, 0.4, 0), Vector3(2.2, 0.8, 0.9), "stone/smooth_grey", {"tile": 1.0, "yaw": yaw})
		Kit.box(self, pos + Vector3(0, 0.88, 0), Vector3(2.3, 0.16, 1.0), "stone/smooth_pale", {"tile": 1.0, "yaw": yaw})


func _dressing() -> void:
	# lamps along the long gallery and at the junctions
	for spot in [[9, 12, 0.6, -0.6], [17, 12, -0.6, -0.6], [30, 12, 0.5, -0.6], [3, 2, -0.5, 0.5], [1, 17, 0.0, 0.0], [24, 21, 0.5, -0.6], [31, 24, 0.5, 0.0], [26, 4, 0.6, 0.0], [26, 10, -0.6, 0.0], [13, 8, 0.0, 0.6], [6, 17, 0.0, 0.6], [12, 15, 0.6, 0.0]]:
		var sp: Array = spot
		_lamp(_c(int(sp[0]), int(sp[1])) + Vector3(float(sp[2]), 0, float(sp[3])))
	# the central hall: broken pillars, bone piles, chains
	for pc in [[15, 15], [19, 15], [15, 18], [19, 18]]:
		var col: int = pc[0]
		var row: int = pc[1]
		Props.place(self, "pillar_broken", _c(col, row), rng.randf_range(0.0, 360.0), 0.8, {"collision": "cylinder"})
	_lamp(_c(17, 16) + Vector3(0, 0, 0.3))
	_bones(_c(14, 17) + Vector3(-0.5, 0, 0.4), 1.2)
	_bones(_c(20, 14) + Vector3(0.5, 0, -0.4), 0.9)
	_bones(_c(20, 19) + Vector3(0.5, 0, 0.5), 1.0)
	Props.place(self, "chain_hanging", _c(17, 16) + Vector3(0, H, 0), 0.0, 0.5, {"collision": "none"})
	Props.place(self, "chain_hanging", _c(15, 16) + Vector3(0.6, H, 0.4), 0.0, 0.42, {"collision": "none"})
	Props.place(self, "statue_knight_bone", _c(17, 14) + Vector3(0, 0, -0.5), 180.0, 0.9)
	Readable.create(self, _c(17, 14) + Vector3(0, 0, -0.2), 180.0, "Look at the bone knight", ["A knight made of other people. The helmet is a skull with a skull inside it.", "It is not guarding anything. It is waiting to be let out."], {"name": "BoneKnight", "size": Vector3(1.2, 2.2, 1.0), "note_key": "bone_knight", "note_title": "The bone knight", "note_text": "In the central hall of the Ossuary a knight made of other people's bones stands facing the door. It is waiting to be let out."})
	Kit.particles(self, _c(17, 16) + Vector3(0, 1.5, 0), "motes", Vector3(6, 1.5, 5), 50)
	Kit.particles(self, _c(17, 12) + Vector3(0, 0.6, 0), "fog", Vector3(20, 0.4, 1), 12)
	# niches and dead ends
	_bones(_c(3, 4) + Vector3(0, 0, 0.5), 1.0)
	_bones(_c(1, 19) + Vector3(-0.3, 0, 0.5), 0.8)
	_bones(_c(11, 3) + Vector3(-0.5, 0, 0), 1.0)
	_bones(_c(29, 24) + Vector3(-0.5, 0, 0.3), 1.1)
	_bones(_c(20, 3) + Vector3(0, 0, -0.5), 0.9)
	_bones(_c(3, 31) + Vector3(-0.5, 0, 0.3), 1.0)
	_bones(_c(8, 15) + Vector3(0, 0, -0.5), 0.9)
	_bones(_c(12, 19) + Vector3(0.4, 0, 0.5), 0.7)
	_urn(_c(2, 12) + Vector3(-0.5, 0, 0.6))
	_urn(_c(24, 7) + Vector3(0.5, 0, -0.5))
	_urn(_c(21, 12) + Vector3(0, 0, 0.6))
	_sarcophagus(_c(29, 7) + Vector3(0, 0, 0), 0.0)
	_sarcophagus(_c(15, 8) + Vector3(0, 0, 0), 90.0)
	Props.place(self, "gravestone_blank", _c(30, 24) + Vector3(0.5, 0, -0.5), 0.0, 1.0)
	Props.place(self, "gravestone_blank", _c(19, 5) + Vector3(0, 0, -0.5), 180.0, 0.9)
	Props.place(self, "cage", _c(3, 17) + Vector3(0, 0, -0.6), 0.0, 0.55, {"collision": "none"})
	Props.place(self, "chain_hanging", _c(9, 6) + Vector3(0, H, 0), 0.0, 0.45, {"collision": "none"})
	Props.place(self, "chain_hanging", _c(26, 6) + Vector3(0.5, H, 0), 0.0, 0.5, {"collision": "none"})
	Props.place(self, "torch_wall", _c(16, 21) + Vector3(-0.9, 1.6, 0), -90.0, 1.0, {"collision": "none"})
	Kit.light(self, _c(16, 21) + Vector3(-0.5, 2.0, 0), Color(1.0, 0.55, 0.25), 0.8, 6.0)
	Props.place(self, "torch_wall", _c(16, 25) + Vector3(0.9, 1.6, 0), 90.0, 1.0, {"collision": "none"})
	Kit.light(self, _c(16, 25) + Vector3(0.5, 2.0, 0), Color(1.0, 0.55, 0.25), 0.8, 6.0)
	Readable.create(self, _c(23, 12) + Vector3(0, 0, -0.9), 180.0, "Read the wall", ["Names, hundreds of them, scratched into the bone. Most have been scratched out again.", "Halfway along, in a different hand: ONE OF THESE IS YOURS. YOU WILL KNOW IT BY THE HANDWRITING."], {"name": "WallNames", "size": Vector3(3.0, 2.2, 0.3), "note_key": "wall_names", "note_title": "The wall of names", "note_text": "The long gallery of the Ossuary is scratched with hundreds of names, most crossed out. One of them is yours, by the handwriting."})
	Kit.sign(self, "signs/graffiti_wake", _c(23, 12) + Vector3(0, 1.4, -0.96), 180.0, Vector2(1.6, 0.5))


# --- hooks ----------------------------------------------------------------------------

func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if n == 1:
		Game.note("ossuary", "The Ossuary", "Galleries walled with bones under everything. Candles, a chapel of four names, a coffin marked reserved. Something down here is written for a light you may not be carrying.")
	if spawn_id == "from_well":
		Game.toast.emit("The ladder ends in the dark. The dark ends in bone.")


func on_lantern(lit: bool) -> void:
	if lit and not Game.has_flag("ossuary_lantern_seen"):
		Game.set_flag("ossuary_lantern_seen", true)
		Game.toast.emit("The walls have been written on. You can read it now.")
		Game.note("ossuary_writing", "Writing for a light", "With the lantern lit, words show on the walls of the Ossuary: arrows, warnings, the way to the pool. Without it they are only bone.")
