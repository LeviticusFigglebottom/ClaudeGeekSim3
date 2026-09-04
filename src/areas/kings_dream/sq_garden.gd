class_name KDGarden
extends RefCounted
## The second square: the Garden of Live Flowers. Where you land. Warm
## afternoon light and too many colours. Beds of paper roses folded from
## pages, all blank, planted in rows, and three thin figures painting them the
## wrong red. The flowers talk; they are the sleeping faces of the Slow Sea,
## grown on stems, and their directions do not agree. At the centre a hedge
## maze that is a maze from the ground and a word from the air, and in the
## middle of the word the rose nobody painted.
##
## Quotes the Hollow Wood (the trees, the mushrooms, the maze), the field of
## the Nowhere House (the mailbox, the dead tree) and the Slow Sea (the faces).
## Built by the area; makes no spawn and no door.

const LAWN := Vector3(0, 0, 30)
const MAZE_ORIGIN := Vector3(-27.5, 0, -27.0)   # top-left corner of the maze grid
const CELL := 2.2
const MAZE_HEDGE := 2.4
const HILL := Vector3(36.0, 0, -14.0)
const HILL_TOP := 24.0
const SHAFT_TOP := 58.0

## Blocky five-by-five letters, read as paths cut through the hedge.
const GLYPHS := {
	"W": ["10001", "10001", "10101", "10101", "11111"],
	"A": ["01110", "10001", "11111", "10001", "10001"],
	"K": ["10011", "10110", "11100", "10110", "10011"],
	"E": ["11111", "10000", "11110", "10000", "11111"],
	"S": ["11111", "10000", "11111", "00001", "11111"],
	"T": ["11111", "00100", "00100", "00100", "00100"],
	"Y": ["10001", "10001", "11111", "00100", "00100"],
}

## What the flowers say. [name, position, yaw, lines]
const FLOWERS := [
	["The Tiger-lily", Vector3(-8.0, 0, 12.0), 20.0, [
		"\"The brook is that way,\" says the Tiger-lily, and does not say which way.",
		"\"It is always that way. Do not listen to the Rose. The Rose has never been anywhere.\"",
	]],
	["The Rose", Vector3(8.5, 0, 14.0), -30.0, [
		"\"North is behind you,\" says the Rose. \"Turn round.\"",
		"You turn round. \"Now it is in front of you,\" says the Rose. \"You see? It is very simple. Everyone gets there in the end by going the wrong way.\"",
	]],
	["The Daisy", Vector3(-14.0, 0, 2.0), 60.0, [
		"\"The maze is a word,\" says the Daisy. \"No it isn't. It is. It isn't.\"",
		"It is arguing with itself, and losing, and winning.",
	]],
	["The Violet", Vector3(16.0, 0, -1.0), -70.0, [
		"\"Go back,\" says the Violet. \"No. Come here. No. Stay exactly where you are and I will come to you.\"",
		"It does not come to you. It is a flower.",
	]],
	["The Larkspur", Vector3(-30.0, 0, 20.0), 40.0, [
		"The Larkspur says nothing. Its eyes are shut. Its mouth is shut.",
		"It is breathing, which flowers do, and it is breathing in your rhythm, which flowers do not.",
	]],
]


static func build(area: AreaBase, root: Node3D, ctx: Dictionary) -> Dictionary:
	var d: Dictionary = ctx.def
	var visit: int = ctx.visit
	var state := {"faces": [], "roses": [], "painters": [], "red": Color(0.82, 0.24, 0.3)}
	# the ground: too green, and warm
	Kit.floor(root, Vector3.ZERO, Vector2(KD.SQ, KD.SQ), String(d.ground), {"tint": d.tint, "tile": 2.0, "thick": 0.2})
	_lawn(area, root, state)
	_shaft(area, root)
	_paths(root)
	_beds(area, root, state, visit)
	_painters(area, root, state)
	_flowers(area, root, state)
	_queen(area, root)
	_maze(area, root, state, visit)
	_hill(area, root)
	_field(area, root)
	_wood(area, root)
	_charm(area, root)
	_lights(root)
	var out := {}
	out["fall_top"] = LAWN + Vector3(0, SHAFT_TOP, 0)
	out["on_freeze"] = func(frozen: bool) -> void:
		for f in state.faces:
			KD.set_face(f, "awake" if frozen else f.get("rest", "sleep"))
	# crossed back into from the wall: the painters have finished, and it is the wrong red
	out["on_return"] = func() -> void:
		_return(area, state)
	out["usher"] = Vector3(-28.0, 0, -30.0)
	return out


# --- the arrival lawn and the shaft above it ---------------------------------------

static func _lawn(area: AreaBase, root: Node3D, _state: Dictionary) -> void:
	Kit.ring(root, LAWN + Vector3(0, 0.1, 0), 0.0, 6.5, 20, "nature/grass_moss", {"tint": Color(1.1, 1.05, 0.8), "solid": false, "tile": 1.5})
	# a fairy ring of pale mushrooms where you land, from the Hollow Wood
	for i in 14:
		var a := i * (360.0 / 14.0)
		Props.place(root, "mushroom_pale" if i % 3 != 0 else "mushroom_glow_small", LAWN + Kit.polar(5.4, a), area.rng.randf_range(0, 360), area.rng.randf_range(0.6, 1.1), {"collision": "none"})
	# the signpost that disagrees with itself
	var sp := LAWN + Vector3(-5.0, 0, -3.0)
	Props.place(root, "signpost_contradictory", sp, 0.0, 1.0, {"collision": "cylinder"})
	var arms := ["THE WOOD", "ALSO THE WOOD", "THE WOOD (BACK)", "you are the wood"]
	for i in arms.size():
		var a := i * PI * 0.5 + 0.35
		var u := Vector3(cos(a), 0, -sin(a))
		var n := Vector3(sin(a), 0, cos(a))
		var lp := sp + u * 0.13 + Vector3(0, 1.5 + i * 0.34, 0)
		for sgn in [1.0, -1.0]:
			Kit.label(root, arms[i], lp + n * sgn * 0.06, Kit.dir_to_yaw(n * sgn), 10, Color(0.35, 0.25, 0.3), "body", {"pixel_size": 0.008, "outline": 0, "double": false})
	Readable.create(root, sp, 0.0, "Read the signpost", [
		"Four arms. THE WOOD. ALSO THE WOOD. THE WOOD (BACK). And one, lower down, in a different hand: you are the wood.",
		"They point four ways. Three of them are right.",
	], {"name": "Signpost", "size": Vector3(0.8, 2.6, 0.8), "note_key": "dream_signpost", "note_title": "The signpost in the garden", "note_text": "Four arms, all pointing at the wood, all pointing different ways. The fourth says you are the wood. In here, directions are opinions."})
	# the instruction you arrive to
	KD.ground_text(root, "you are early. wait here.", LAWN + Vector3(0, 0, 4.2), 0.0, 34, Color(0.45, 0.5, 0.3))
	KD.ground_text(root, "no. go on.", LAWN + Vector3(0, 0, 5.4), 0.0, 22, Color(0.55, 0.35, 0.35), "body")


## The rabbit hole: a square tube of shelves hanging in the sky over the lawn,
## with something from every realm on them and every label on the wrong shelf.
static func _shaft(area: AreaBase, root: Node3D) -> void:
	var shaft := Node3D.new()
	shaft.name = "Shaft"
	shaft.position = LAWN
	root.add_child(shaft)
	var w := 6.0
	var y0 := 7.0
	var y1 := SHAFT_TOP + 6.0
	var h := y1 - y0
	var mid := (y0 + y1) * 0.5
	var tex := "wood/book_spines"
	var tint := Color(1.0, 0.92, 0.85)
	Kit.box(shaft, Vector3(0, mid, -w * 0.5), Vector3(w, h, 0.3), tex, {"faces": ["pz", "nz"], "tint": tint, "solid": false, "tile": 1.0})
	Kit.box(shaft, Vector3(0, mid, w * 0.5), Vector3(w, h, 0.3), tex, {"faces": ["pz", "nz"], "tint": tint, "solid": false, "tile": 1.0})
	Kit.box(shaft, Vector3(-w * 0.5, mid, 0), Vector3(0.3, h, w), tex, {"faces": ["px", "nx"], "tint": tint, "solid": false, "tile": 1.0})
	Kit.box(shaft, Vector3(w * 0.5, mid, 0), Vector3(0.3, h, w), tex, {"faces": ["px", "nx"], "tint": tint, "solid": false, "tile": 1.0})
	# from outside it is a pale chimney hanging in the sky, not a trunk
	Kit.box(shaft, Vector3(0, mid, 0), Vector3(w + 0.34, h, w + 0.34), "wood/planks_white", {"faces": ["px", "nx", "pz", "nz"], "tint": Color(1.0, 0.94, 0.9), "solid": false, "tile": 2.0})
	# the museum: [prop, scale, the label it should not have]
	var exhibits := [
		["tv_crt", 0.6, "THE HOLLOW WOOD"], ["skull", 1.0, "THE SLOW SEA"], ["bottle_moonlight", 1.2, "THE FURNACE"],
		["gear_big", 0.25, "FLAT 5½"], ["dog_bowl", 1.0, "THE KEEP OF HOURS"], ["lantern_hanging", 0.7, "THE WAITING HALLS"],
		["shell", 0.9, "THE OSSUARY"], ["candle_cluster", 0.9, "THE DROWNED CITY"], ["item_key", 1.5, "THE NOWHERE HOUSE"],
		["mushroom_red", 0.8, "THE CISTERN"], ["telephone", 0.9, "THE CLOCKTOWER"], ["mug", 1.2, "THE STATIC"],
		["photo_2", 0.8, "THE LAST LAMP"], ["clock_hand", 0.5, "THE HALLWAY"], ["item_biscuit", 1.6, "THE ANTEROOM"],
		["gravestone_blank", 0.5, "THE WORKSHOP"], ["cocoon", 0.4, "THE HALDEN ARMS"], ["tv_crt", 0.5, "THE OTHER ANTEROOM"],
	]
	var walls := [[Vector3(0, 0, -w * 0.5 + 0.45), 0.0], [Vector3(w * 0.5 - 0.45, 0, 0), 90.0], [Vector3(0, 0, w * 0.5 - 0.45), 180.0], [Vector3(-w * 0.5 + 0.45, 0, 0), -90.0]]
	for i in exhibits.size():
		var e: Array = exhibits[i]
		var wl: Array = walls[i % 4]
		var y := y0 + 3.0 + float(i) * ((h - 6.0) / exhibits.size())
		var wp: Vector3 = wl[0]
		var yaw := float(wl[1])
		var shelf := Kit.box(shaft, wp + Vector3(0, y - 0.05, 0), Vector3(1.6, 0.08, 0.7) if i % 2 == 0 else Vector3(0.7, 0.08, 1.6), "wood/planks_white", {"solid": false})
		shelf.rotation.y = 0.0
		var p := Props.place(shaft, String(e[0]), wp + Vector3(0, y, 0), yaw + 180.0, float(e[1]), {"collision": "none"})
		if String(e[0]) == "lantern_hanging" or String(e[0]) == "cocoon":
			p.position.y = y + 1.4
		Kit.label(shaft, String(e[2]), wp + Vector3(0, y + 1.0, 0) + Kit.yaw_to_dir(yaw + 180.0) * 0.1, yaw + 180.0, 14, Color(0.95, 0.9, 0.8), "body", {"pixel_size": 0.01, "outline": 3})
		if i % 3 == 0:
			Kit.light(shaft, Vector3(0, y + 0.5, 0), Color(1.0, 0.85, 0.7), 0.7, 6.0)
	Kit.light(shaft, Vector3(0, y0 + 1.0, 0), Color(1.0, 0.9, 0.85), 1.0, 9.0)
	Kit.label(shaft, "down is the same as down", Vector3(0, y1 - 1.5, -w * 0.5 + 0.3), 0.0, 22, Color(0.9, 0.85, 0.75), "body", {"pixel_size": 0.012})
	Kit.particles(shaft, Vector3(0, mid, 0), "motes", Vector3(2.5, h * 0.5, 2.5), 120)
	area.rng.randf()


# --- paths, beds, painters -------------------------------------------------------------

static func _paths(root: Node3D) -> void:
	var tint := Color(1.0, 0.95, 0.85)
	# from the lawn north to the mouth of the maze, and out to the beds either side
	Kit.floor(root, Vector3(0, 0.1, 12.0), Vector2(4.0, 28.0), "ground/gravel", {"tint": tint, "tile": 1.5, "thick": 0.12})
	Kit.floor(root, Vector3(0, 0.12, 18.0), Vector2(60.0, 3.0), "ground/gravel", {"tint": tint, "tile": 1.5, "thick": 0.12})
	# and north of the maze, to the gate
	Kit.floor(root, Vector3(0, 0.1, -32.4), Vector2(4.0, 11.2), "ground/gravel", {"tint": tint, "tile": 1.5, "thick": 0.12})
	Kit.floor(root, Vector3(-32.0, 0.1, -15.0), Vector2(3.0, 40.0), "ground/gravel", {"tint": tint, "tile": 1.5, "thick": 0.12})
	Kit.floor(root, Vector3(32.0, 0.1, -15.0), Vector2(3.0, 40.0), "ground/gravel", {"tint": tint, "tile": 1.5, "thick": 0.12})
	Kit.floor(root, Vector3(0, 0.12, -33.0), Vector2(66.0, 3.0), "ground/gravel", {"tint": tint, "tile": 1.5, "thick": 0.12})


## Two beds of paper roses. The near end of each has been painted.
static func _beds(area: AreaBase, root: Node3D, state: Dictionary, visit: int) -> void:
	var red: Color = state.red
	for side in [-1.0, 1.0]:
		var bed_c := Vector3(side * 21.0, 0, 10.0)
		var size := Vector2(16.0, 12.0)
		Kit.floor(root, bed_c + Vector3(0, 0.12, 0), size, "ground/dirt", {"tint": Color(1.1, 0.95, 0.85), "tile": 1.5, "thick": 0.14})
		var hx := size.x * 0.5
		var hz := size.y * 0.5
		var border := "wood/planks_white"
		Kit.box(root, bed_c + Vector3(0, 0.12, -hz), Vector3(size.x + 0.3, 0.24, 0.3), border)
		Kit.box(root, bed_c + Vector3(0, 0.12, hz), Vector3(size.x + 0.3, 0.24, 0.3), border)
		Kit.box(root, bed_c + Vector3(-hx, 0.12, 0), Vector3(0.3, 0.24, size.y), border)
		Kit.box(root, bed_c + Vector3(hx, 0.12, 0), Vector3(0.3, 0.24, size.y), border)
		var rows := 7
		var cols := 10
		var painted_cols := 3 if side < 0 else 4
		for r in rows:
			for c in cols:
				var x := -hx + 1.0 + c * ((size.x - 2.0) / (cols - 1))
				var z := -hz + 1.0 + r * ((size.y - 2.0) / (rows - 1))
				var p := bed_c + Vector3(x, 0.12, z)
				# painting starts from the end nearest the path and works outward
				var from_path := (cols - 1 - c) if side < 0 else c
				var painted := from_path < painted_cols
				var tint := red if painted else Color(1.0, 0.98, 0.94)
				var rose := Props.place(root, "rose_paper_planted", p, area.rng.randf_range(0, 360), area.rng.randf_range(2.2, 2.9), {"collision": "none", "tint": tint})
				state.roses.append({"node": rose, "painted": painted})
		# what the beds say
		var rp := bed_c + Vector3(-side * (hx - 0.5), 0.0, hz - 1.0)
		Readable.create(root, rp, 0.0, "Look at the roses", [
			"Roses in rows. Every one is folded from a page, and every page is blank.",
			"The near ones have been painted red. It is not a red you would choose. It is the red of a brick.",
			"You look for one with writing on it. There is not one. You look for a while.",
		], {"name": "BedLook%d" % int(side), "size": Vector3(1.4, 1.0, 1.4), "note_key": "dream_roses", "note_title": "The paper roses", "note_text": "Two beds of roses folded from blank pages, planted in rows, being painted the colour of a brick. None of them is the one with writing on it. That one is not in a bed."})
	# a wheelbarrow of paint that is the wrong colour
	var pot := Vector3(-10.5, 0, 17.0)
	Props.place(root, "barrel", pot, 0.0, 0.7, {"collision": "cylinder", "tint": Color(0.9, 0.85, 0.8)})
	Kit.ring(root, pot + Vector3(0, 0.62, 0), 0.0, 0.26, 10, "", {"tint": red, "solid": false})
	Readable.create(root, pot + Vector3(0, 0.4, 0), 0.0, "Look in the barrel", [
		"Paint. The red of a brick, of a scab, of the door across the landing.",
		"A brush stands in it. On the handle, in pencil, somebody has written 5½ and crossed it out.",
	], {"name": "PaintBarrel", "size": Vector3(1.0, 0.9, 1.0)})
	if visit >= 2:
		Kit.label(root, "still", Vector3(-10.5, 1.3, 16.3), 0.0, 18, Color(0.7, 0.2, 0.2), "body", {"pixel_size": 0.01})


## Two, Five and Seven, with brushes, who have been at this a long time.
static func _painters(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var specs := [
		["Two", Vector3(-11.5, 0, 6.0), 100.0, Color(0.96, 0.95, 0.92), [
			"\"We are painting them red,\" says Two, and does not stop painting. \"They were meant to be red. Somebody planted the wrong ones.\"",
			"\"Who?\" you ask. Two looks at the brush. \"Somebody,\" says Two.",
		]],
		["Five", Vector3(12.0, 0, 6.5), -100.0, Color(0.94, 0.93, 0.9), [
			"\"It is the wrong red,\" says Five, painting. \"We know. It is the only red there is in here.\"",
			"\"He has never seen a rose. He has had them described to him. This is what he thinks red is.\"",
		]],
		["Seven", Vector3(-11.0, 0, 13.5), 80.0, Color(0.9, 0.9, 0.9), [
			"Seven paints a rose, and the rose is a page, and the paint goes on the page the way ink goes on a page.",
			"\"Do not tell her,\" says Seven. \"She counts them. She does not read them. Nobody reads them.\"",
			"\"Except one,\" says Seven, quieter, \"and we cannot find it.\"",
		]],
	]
	for sp in specs:
		var nm: String = sp[0]
		var npc := NPC.create(root, sp[1], float(sp[2]), nm, {
			"model": "none", "name": "Painter_" + nm, "prompt": "Talk to " + nm, "lines": sp[4],
			"reactions": {"crown": ["\"Your Majesty,\" says %s, without looking up. \"We have nearly finished. We have nearly finished for a very long time.\"" % nm]},
		})
		var fig := KD.figure(npc, Vector3.ZERO, 0.0, sp[3], 1.9)
		# the brush, held out, red at the tip
		Kit.box(fig, Vector3(0.36, 1.05, -0.3), Vector3(0.04, 0.5, 0.04), "", {"tint": Color(0.7, 0.55, 0.35), "solid": false})
		Kit.box(fig, Vector3(0.36, 0.78, -0.3), Vector3(0.06, 0.08, 0.06), "", {"tint": state.red, "solid": false})
		state.painters.append(npc)
	Puzzle.declare(area, "dream_painters", "", [], "the three painters have been painting the roses the wrong red for a long time")


# --- the flowers that talk -------------------------------------------------------------

static func _flowers(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	for fl in FLOWERS:
		var nm: String = fl[0]
		var pos: Vector3 = fl[1]
		var yaw := float(fl[2])
		var f := KD.face_on_stem(root, pos, yaw, 1.4, "sleep", Color(1.0, 0.92, 0.95))
		f["rest"] = "sleep"
		state.faces.append(f)
		var lines: Array = fl[3]
		Readable.create(root, pos, yaw, "Listen to " + nm, lines, {"name": "Flower_" + nm.replace(" ", "_").replace("-", "_"), "size": Vector3(1.2, 2.6, 1.2), "sound": "whisper",
			"note_key": "dream_flower_" + nm.to_lower().replace(" ", "_"), "note_title": nm, "note_text": String(lines[0]).replace("\"", "")})
		# petals, which are a ring of little pastel discs
		for k in 8:
			var a := k * 45.0
			Kit.ring(root, pos + Kit.polar(0.62 * 1.4, a, 2.25), 0.0, 0.16, 6, "", {"tint": [Color(1.0, 0.75, 0.8), Color(0.85, 0.8, 1.0), Color(1.0, 0.95, 0.7)][k % 3], "solid": false, "unshaded": true})
	# the one that is not a flower: stay with it and it says so
	var lark: Dictionary = state.faces[4]
	var watch := {"t": 0.0, "said": false}
	Kit.trigger(root, FLOWERS[4][1] + Vector3(0, 1.0, 0), Vector3(7.0, 3.0, 7.0), func(_p: Node) -> void:
		if watch.said:
			return
		watch.t += 0.1
		if watch.t >= 11.0:
			watch.said = true
			KD.set_face(lark, "awake")
			lark["rest"] = "awake"
			Audio.sfx("whisper", FLOWERS[4][1], -2.0)
			if World.hud:
				await World.hud.say("The Larkspur", [
					"The eyes open. They are not a flower's eyes.",
					"\"I am not a flower,\" it says. \"I am a face somebody planted. It was a joke. It has gone on.\"",
					"\"Please do not water me. Please do not tell the painters. Please stay a little longer.\"",
				])
			Game.set_flag("dream_larkspur", true)
			Game.note("dream_larkspur", "The one that is not a flower", "Stay with the Larkspur long enough and it opens its eyes and says it is not a flower. It is a face somebody planted, as a joke, and the joke has gone on."),
		{"name": "LarkspurWatch", "continuous": true})
	Puzzle.declare(area, "dream_larkspur", "dream_larkspur", [], "stay with the flower that does not talk until it does")


# --- the Red Queen, who runs to stay in place -------------------------------------------

static func _queen(_area: AreaBase, root: Node3D) -> void:
	var qp := Vector3(6.0, 0, -2.0)
	var cw := Clockwork.create(root, qp, {"mode": "path", "points": [Vector3(0, 0, 0), Vector3(0, 0, -1.6)], "speed_deg": 60.0, "name": "RedQueen"})
	Props.place(cw.body, "chess_queen", Vector3.ZERO, 30.0, 1.9, {"collision": "none", "tint": Color(0.85, 0.2, 0.25)})
	Kit.light(root, qp + Vector3(0, 2.5, -0.8), Color(1.0, 0.5, 0.5), 0.8, 6.0)
	Kit.particles(root, qp + Vector3(0, 0.3, -0.8), "motes", Vector3(0.6, 0.3, 1.2), 20)
	Readable.create(root, qp + Vector3(0, 0, -0.8), 0.0, "Watch the Red Queen", [
		"She is running as fast as she can, and she is here.",
		"\"Faster,\" she says, to nobody, and stays where she is. It takes all the running she can do to keep in the same place.",
		"She does not look at you. You are not a piece yet.",
	], {"name": "RedQueen", "size": Vector3(1.6, 2.4, 3.0), "note_key": "dream_red_queen", "note_title": "The Red Queen", "note_text": "A red queen runs on the spot beside the path to the maze and stays exactly where she is. In here it takes all the running you can do to keep in the same place. She has not noticed you. You are not a piece yet."})


# --- the maze that is a word ---------------------------------------------------------------

static func maze_word(visit: int) -> String:
	return "WAKE" if visit % 2 == 1 else "STAY"


## Rows of the maze grid ('#' hedge, '.' path, 'R' the rose, 'E' the way in).
static func maze_rows(word: String) -> Array:
	var w := word.length() * 6 + 1
	var rows: Array = []
	for r in 9:
		rows.append([])
		for c in w:
			rows[r].append("#")
	# the letters, rows 1..5, each six columns wide with a hedge between
	for li in word.length():
		var g: Array = GLYPHS[word[li]]
		for r in 5:
			for c in 5:
				if g[r][c] == "1":
					rows[1 + r][1 + li * 6 + c] = "."
	# the corridor under the word, and the way in from the south
	for c in range(1, w - 1):
		rows[6][c] = "."
	var mid := w / 2
	rows[7][mid] = "."
	rows[8][mid] = "E"
	# dead ends off the corridor that are not letters
	for c in range(2, w - 2, 5):
		if rows[7][c] == "#" and c != mid and c != mid - 1 and c != mid + 1:
			rows[7][c] = "."
	# the rose: a chamber in the hedge between the second and third letters, at the middle row
	var gap := 1 + 2 * 6 - 1
	rows[3][gap] = "R"
	if rows[3][gap - 1] == "#":
		rows[3][gap - 1] = "."
	return rows


static func _maze(area: AreaBase, root: Node3D, _state: Dictionary, visit: int) -> void:
	var word := maze_word(visit)
	var rows := maze_rows(word)
	var h := rows.size()
	var w: int = rows[0].size()
	var tint := Color(1.0, 1.0, 0.95)
	var cell_pos := func(c: int, r: int) -> Vector3:
		return MAZE_ORIGIN + Vector3((c + 0.5) * CELL, 0, (r + 0.5) * CELL)
	# hedges, merged along each row into one block per run
	for r in h:
		var c := 0
		while c < w:
			if rows[r][c] != "#":
				c += 1
				continue
			var c0 := c
			while c < w and rows[r][c] == "#":
				c += 1
			var x0 := MAZE_ORIGIN.x + c0 * CELL
			var x1 := MAZE_ORIGIN.x + c * CELL
			var z := MAZE_ORIGIN.z + (r + 0.5) * CELL
			KD.hedge_block(root, Vector3((x0 + x1) * 0.5, 0, z), Vector3(x1 - x0, MAZE_HEDGE, CELL), {"tint": tint})
	# the paths are grass; the rose's chamber is not marked in any way
	var rose_pos := Vector3.ZERO
	for r in h:
		for c in w:
			if rows[r][c] == "R":
				rose_pos = cell_pos.call(c, r)
	Pickup.create(root, rose_pos + Vector3(0, 0.15, 0), {"item": "rose", "name": "MazeRose", "key": "picked_rose_maze", "requires_keepsake": "wings", "prompt": "Take the rose nobody painted"})
	Readable.create(root, rose_pos + Vector3(0.7, 0, 0), 0.0, "Read the rose", [
		"One rose, white, unpainted, with writing on the page it is folded from. You unfold enough to read it.",
		"...a single rose, which he had not painted, because it was already the colour it was. And the king said, that one is mine. And the rose said, no.",
		"The tear along the edge matches a book in a library that does not end.",
	], {"name": "MazeRoseRead", "size": Vector3(0.6, 0.8, 0.6), "note_key": "dream_rose_page", "note_title": "The page the rose is folded from", "note_text": "The rose at the middle of the maze is folded from the half of the page torn out of the book in the Keep's library: the king dreamed of a garden, and in the garden a single rose he had not painted, and the rose said no."})
	Kit.trigger(root, rose_pos + Vector3(0, 1.0, 0), Vector3(1.8, 2.5, 1.8), func(_p: Node) -> void:
		if not Game.has_flag("maze_walked"):
			Game.set_flag("maze_walked", true)
			Game.note("maze_walked", "The middle of the maze", "You reached the middle of the hedge maze in the garden. From the ground it is a maze. From the air it is a word, and the word is where to walk."), {"name": "MazeCentre", "once": true})
	Puzzle.declare(area, "dream_maze", "maze_walked", ["keepsake:wings"], "glide over the hedge maze in the garden, read it, then walk it", {})
	# the word is a secret and is written down nowhere; the journal only says there is one
	area.set_meta("maze_word", word)


# --- the hill you can reach, which is the point of it --------------------------------------

## A pink mound with a stair winding up its flank to a landing twenty-four
## metres up. From there the maze is a word, and the Wings will carry you over
## it. Nobody says so. The stair is just there.
static func _hill(area: AreaBase, root: Node3D) -> void:
	var tex := "stone/blocks_sea"
	var flights := 8
	var rise := HILL_TOP / flights
	var r := 6.3
	Kit.cylinder(root, HILL, 4.0, HILL_TOP, tex, {"tint": Color(1.0, 0.9, 0.95), "segments": 12, "tile": 3.0})
	Kit.cylinder(root, HILL, 4.4, 1.0, tex, {"tint": Color(0.95, 0.8, 0.9), "segments": 12, "tile": 3.0})
	Kit.ring(root, HILL + Vector3(0, HILL_TOP + 0.02, 0), 0.0, 4.0, 12, "nature/grass_moss", {"tint": Color(1.1, 1.05, 0.85), "solid": false})
	for i in flights:
		var a0 := i * 45.0
		var a1 := (i + 1) * 45.0
		var l0 := HILL + Kit.polar(r, a0, i * rise)
		var l1 := HILL + Kit.polar(r, a1, (i + 1) * rise)
		var d := l1 - l0
		d.y = 0.0
		var steps := 12
		var step_d := d.length() / steps
		Kit.stairs(root, l0, Kit.dir_to_yaw(d.normalized()), 1.7, steps, rise / steps, step_d, tex, {"tint": Color(1.0, 0.85, 0.9) if i % 2 == 0 else Color(0.85, 0.95, 0.9), "tile": 1.0, "name": "HillFlight%d" % i})
		# landings a shade above the flights' feet and the ground, never in their plane
		Kit.floor(root, l0 + Vector3(0, 0.03, 0), Vector2(1.9, 1.9), tex, {"tint": Color(0.95, 0.9, 0.95), "tile": 1.0})
		if i % 2 == 1:
			Kit.light(root, l0 + Vector3(0, 2.2, 0), Color(1.0, 0.85, 0.9), 0.7, 8.0)
	# the last flight lands on the top: a bridge from the landing to the mound
	var top_l := HILL + Kit.polar(r, flights * 45.0, HILL_TOP)
	Kit.floor(root, top_l + Vector3(0, 0.03, 0), Vector2(1.9, 1.9), tex, {"tint": Color(0.95, 0.9, 0.95), "tile": 1.0})
	Kit.floor(root, (top_l + HILL + Vector3(0, HILL_TOP, 0)) * 0.5, Vector2(1.6, r), tex, {"tint": Color(0.95, 0.9, 0.95), "tile": 1.0, "yaw": Kit.dir_to_yaw((HILL - top_l).normalized()) + 90.0})
	Props.place(root, "arch_pastel", HILL + Vector3(0, HILL_TOP, 0), 90.0, 1.2, {"collision": "none"})
	Kit.light(root, HILL + Vector3(0, HILL_TOP + 3.0, 0), Color(1.0, 0.9, 0.95), 1.2, 14.0)
	for k in 5:
		Props.place(root, "cloud", HILL + Kit.polar(7.0 + k * 1.5, k * 72.0 + 20.0, HILL_TOP + 3.0 + k * 1.2), k * 50.0, 1.4, {"collision": "none"})
	Readable.create(root, HILL + Vector3(0, HILL_TOP, 1.2), 0.0, "Look out from the hill", [
		"From the hill you can see the whole garden, which is what hills are for. In the book she could never reach it.",
		"The maze is under you. From here it is not a maze.",
		"The wind is warm and comes from below, as if something under the garden were breathing out.",
	], {"name": "HillView", "size": Vector3(2.0, 1.4, 1.0), "note_key": "dream_hill", "note_title": "The hill in the garden", "note_text": "A pink hill with a stair round it, at the east side of the garden. From the top the maze is not a maze. The wind comes up from below, warm, as if something were breathing."})
	Puzzle.declare(area, "dream_hill", "", [], "climb the pink hill on the east side of the garden and look down")


# --- the field with the mailbox, from the Nowhere House ------------------------------------

static func _field(_area: AreaBase, root: Node3D) -> void:
	var c := Vector3(-30.0, 0, -10.0)
	Kit.ring(root, c + Vector3(0, 0.1, 0), 0.0, 9.0, 18, "nature/grass_dark", {"tint": Color(1.0, 1.05, 0.95), "solid": false, "tile": 3.0})
	Props.place(root, "tree_dead_1", c + Vector3(-4.0, 0, -3.0), 40.0, 1.1)
	Props.place(root, "tree_dead_2", c + Vector3(5.0, 0, 4.0), 200.0, 0.9)
	# the mailbox: a post and a box with a flap
	var mb := c + Vector3(1.5, 0, 0.5)
	Kit.box(root, mb + Vector3(0, 0.55, 0), Vector3(0.1, 1.1, 0.1), "wood/planks_grey")
	Kit.box(root, mb + Vector3(0, 1.28, 0), Vector3(0.36, 0.36, 0.56), "metal/plate", {"tint": Color(0.8, 0.8, 0.85)})
	Kit.box(root, mb + Vector3(0, 1.28, -0.3), Vector3(0.34, 0.34, 0.04), "metal/plate", {"tint": Color(0.7, 0.7, 0.75), "solid": false})
	Kit.label(root, "5½", mb + Vector3(0, 1.3, -0.33), 0.0, 20, Color(0.25, 0.25, 0.3), "body", {"pixel_size": 0.008, "outline": 0})
	Readable.create(root, mb + Vector3(0, 1.0, 0), 0.0, "Open the mailbox", [
		"A mailbox in a field with no road. On the flap, in pencil, 5½.",
		"Inside, one letter. It is addressed to the occupant. It begins: Dear occupant of the dream. It does not go on. Somebody was interrupted, or woke up.",
	], {"name": "Mailbox", "size": Vector3(0.7, 0.7, 0.8), "sound": "creak", "note_key": "dream_mailbox", "note_title": "The mailbox in the field", "note_text": "In a corner of the garden there is a patch of the field the Nowhere House stands in, with a dead tree and a mailbox with your number on the flap. The letter inside is addressed to the occupant of the dream, and stops."})
	Kit.light(root, c + Vector3(0, 3.0, 0), Color(0.75, 0.8, 1.0), 0.8, 12.0)


# --- the Hollow Wood, gone yellow ---------------------------------------------------------------

static func _wood(area: AreaBase, root: Node3D) -> void:
	var rng := area.rng
	var trees := ["tree_oak_1", "tree_oak_2", "tree_oak_3", "tree_pine_1", "tree_autumn"]
	var tint := Color(1.15, 1.1, 0.8)
	var n := 0
	while n < 46:
		var p := Vector3(rng.randf_range(-42.0, 42.0), 0, rng.randf_range(-40.0, 40.0))
		# keep the middle, the lawn, the beds, the paths and the fords clear
		if absf(p.x) < 27.0 and p.z > -30.0 and p.z < 26.0:
			continue
		if p.distance_to(LAWN) < 9.0 or absf(p.x) < 3.5 or absf(p.z + 33.0) < 3.0 or absf(p.z - 18.0) < 3.0:
			continue
		if p.distance_to(Vector3(-30.0, 0, -10.0)) < 10.0 or p.z > 36.0 or p.z < -36.0 or absf(p.x) > 36.0:
			continue
		if p.distance_to(HILL) < 11.0:
			continue
		Props.place(root, trees[rng.randi() % trees.size()], p, rng.randf_range(0, 360), rng.randf_range(0.9, 1.5), {"collision": "cylinder", "collision_scale": 0.2, "tint": tint})
		n += 1
	for i in 30:
		var p := Vector3(rng.randf_range(-42.0, 42.0), 0, rng.randf_range(-42.0, 42.0))
		if (absf(p.x) < 28.0 and p.z > -30.0 and p.z < 36.0) or p.distance_to(HILL) < 11.0:
			continue
		Props.place(root, ["bush_1", "mushroom_glow_big", "mushroom_glow_small", "fern_cluster"][i % 4], p, rng.randf_range(0, 360), rng.randf_range(0.7, 1.3), {"collision": "none", "tint": Color(1.1, 1.0, 0.85)})
	# a moth, enormous, asleep on a tree, from the Slow Sea's summit
	Props.place(root, "moth_giant", Vector3(38.0, 5.0, -22.0), 250.0, 1.2, {"collision": "none", "rotation": Vector3(0, 250, 80)})


## Small things that make it a garden: a fountain, benches, petals on the air,
## lanterns at the way on so the gate reads as a gate.
static func _charm(area: AreaBase, root: Node3D) -> void:
	var rng := area.rng
	Props.place(root, "fountain", Vector3(-14.0, 0, 30.0), 0.0, 1.1, {"collision": "cylinder", "collision_scale": 0.8, "tint": Color(1.0, 0.95, 1.0)})
	Kit.light(root, Vector3(-14.0, 2.5, 30.0), Color(0.8, 0.9, 1.0), 0.9, 8.0)
	Readable.create(root, Vector3(-14.0, 0.8, 31.6), 0.0, "Look in the fountain", [
		"A fountain, running uphill, quietly. The water goes up the spout and does not come down.",
		"There are coins in it, all the same coin, with a wave on both faces.",
	], {"name": "Fountain", "size": Vector3(2.4, 1.2, 1.0)})
	for b in [[Vector3(14.0, 0, 32.0), -20.0], [Vector3(-6.0, 0, 14.0), 90.0]]:
		Props.place(root, "bench", b[0], float(b[1]), 1.0, {"collision": "box", "tint": Color(1.0, 0.95, 0.95)})
	# petals
	for k in 3:
		var p := Kit.particles(root, Vector3(-21.0 + k * 21.0, 3.0, 10.0), "snow", Vector3(9.0, 1.5, 7.0), 40)
		var m := p.material_override as StandardMaterial3D
		if m:
			m.albedo_color = [Color(1.0, 0.75, 0.8, 0.9), Color(0.95, 0.85, 1.0, 0.9), Color(1.0, 0.95, 0.75, 0.9)][k]
	# the way on: two lanterns flank the gap in the north hedge, and the path is lined
	for sx in [-5.5, 5.5]:
		Props.place(root, "lantern_post", Vector3(float(sx), 0, 36.5 - 72.0), 0.0, 1.0, {"collision": "cylinder"})
		Kit.light(root, Vector3(float(sx), 2.8, -35.5), Color(1.0, 0.9, 0.75), 1.1, 9.0)
	for k in 6:
		for sx in [-2.6, 2.6]:
			Props.place(root, "rose_paper_planted", Vector3(float(sx), 0.1, -28.0 - k * 1.6), rng.randf_range(0, 360), 2.4, {"collision": "none", "tint": Color(1.0, 0.98, 0.94)})
	KD.ground_text(root, "this way, probably", Vector3(0, 0, -31.0), 0.0, 24, Color(0.45, 0.5, 0.3), "body")
	Props.place(root, "signpost_contradictory", Vector3(6.0, 0, -30.0), 0.0, 0.9, {"collision": "cylinder"})


static func _lights(root: Node3D) -> void:
	Kit.light(root, LAWN + Vector3(0, 4.0, 0), Color(1.0, 0.9, 0.8), 1.2, 16.0)
	Kit.light(root, Vector3(-21.0, 3.5, 10.0), Color(1.0, 0.8, 0.8), 1.0, 18.0)
	Kit.light(root, Vector3(21.0, 3.5, 10.0), Color(1.0, 0.8, 0.8), 1.0, 18.0)
	Kit.light(root, Vector3(0, 5.0, -8.0), Color(1.0, 0.95, 0.8), 1.0, 20.0)
	Kit.light(root, Vector3(0, 6.0, -17.0), Color(0.95, 1.0, 0.85), 0.9, 26.0)
	Kit.light(root, Vector3(-32.0, 3.0, 20.0), Color(1.0, 0.9, 0.95), 0.8, 12.0)
	Kit.light(root, Vector3(32.0, 3.0, -30.0), Color(0.9, 0.95, 1.0), 0.8, 14.0)
	Kit.particles(root, Vector3(0, 3.0, 10.0), "motes", Vector3(30.0, 2.0, 25.0), 120)


## Crossed back into from the top of the wall: the painters have finished, and
## every rose in the beds is the wrong red, and they stand very still.
static func _return(area: AreaBase, state: Dictionary) -> void:
	for r in state.roses:
		var n: Node3D = r.node
		if is_instance_valid(n):
			Props.stylize(n, {"tint": state.red})
	for p in state.painters:
		var npc: NPC = p
		if is_instance_valid(npc):
			npc.lines = ["They have finished. They are standing very still, the way people stand when they have finished and have not been told what to do next.", "\"She counted them,\" says one of them. \"They were all there.\""]
			npc.reactions = {}
	Game.toast.emit("Every rose in the garden is red. The painters are standing very still.")
	area.rng.randf()
