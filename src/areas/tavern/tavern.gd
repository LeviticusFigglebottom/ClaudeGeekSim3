extends AreaBase
## The Last Lamp — the tavern at the end of every road. Warm where nothing
## else is. A taproom of faceless patrons, a bard playing a song with no end, a
## barkeep with a riddle, a trade and a room he will not let. A kitchen nook
## with a back door that goes somewhere different every time. A cellar. A
## rented room upstairs whose bed opens onto the Slow Sea. Behind the bar, a
## hole only the Tin Mouse fits through, and under the floorboards a second
## tavern, three times too large.

const CELL := 2.0
const H := 3.4
const ORIGIN := Vector3(-8, 0, -10)
## The undertavern is built far from the inn, at three times the scale.
const UT := Vector3(50, 0, -50)
const WARM := Color(1.0, 0.78, 0.5)
const CANDLE := Color(1.0, 0.85, 0.6)
const BACK_DOOR_TARGETS := [["forest", "clearing"], ["city", "alley"], ["house", "field"], ["sea", "shore"]]
const PORTRAIT_BEFORE := ["A man in a good coat, holding a lamp. His eyes follow you. That is what portraits do.", "This one is doing it from slightly further away than it was."]
const PORTRAIT_AFTER := ["Where the portrait was, there is a painting of a door.", "It is painted from the other side."]

var fire_light: OmniLight3D = null
var flames: Array = []
var bard: NPC = null
var bard_sign: Readable = null
var portrait_a: Node3D = null
var portrait_b: Node3D = null
var portrait_readable: Readable = null
var rope: Node3D = null
var rain: CPUParticles3D = null
var _t := 0.0


func build() -> void:
	Realm.apply(self, "tavern", {"ambient_energy": 0.92, "ambient": "#7a5a3c", "fog_density": 0.02})
	_ground_floor()
	_upstairs()
	_cellar()
	_outside()
	_undertavern()
	Puzzle.declare(self, "tavern_riddle", "riddle_solved", [], "answer the barkeep's riddle", {"item": "coin"})
	Puzzle.declare(self, "moonlight_trade", "", ["item:moonlight"], "trade a bottle of moonlight to the barkeep", {"keepsake": "umbrella"})
	Puzzle.declare(self, "tavern_room", "tavern_room", ["item:coin"], "show the barkeep the coin of the sea")
	if Game.has_flag("bard_stopped"):
		_stop_bard(true)


# --- ground floor ---------------------------------------------------------------

func _ground_floor() -> void:
	var rows := [
		"##D##    #",
		"#k..#....#",
		"#...D....#",
		"#####....#",
		"#........#",
		"#f.......#",
		"#.......:#",
		"#...@...:#",
		"#.......:#",
		"####D#####",
	]
	MapBuilder.build(self, rows, {"cell": CELL, "height": H, "origin": ORIGIN, "floor": "wood/planks_warm",
		"wall": "wall/plaster_tavern", "ceiling": "wood/planks_dark", "open_edges": true, "door_h": 2.3, "name": "Ground"})
	# the eight lights that matter most come first (the renderer keeps eight per mesh)
	fire_light = Kit.light(self, Vector3(-4.9, 1.1, 1.0), Color(1.0, 0.55, 0.2), 2.2, 12.0)
	Kit.light(self, Vector3(1.0, 2.2, 3.0), WARM, 1.9, 13.0)
	var lantern_spots := [Vector3(-3.0, H - 0.05, 4.0), Vector3(-1.5, H - 0.05, -1.0), Vector3(6.5, H - 0.05, 4.0), Vector3(7.0, H - 0.05, -0.8)]
	for p in lantern_spots:
		var lp: Vector3 = p
		Props.place(self, "lantern_hanging", lp, 0.0, 1.0, {"collision": "none"})
		Kit.light(self, lp + Vector3(0, -1.45, 0), WARM, 1.2, 8.0)
	Kit.light(self, Vector3(4.5, 2.7, -3.5), WARM, 1.4, 9.0)
	Kit.light(self, Vector3(-3.0, 1.9, -5.5), WARM, 1.2, 8.0)
	# ceiling beams across the taproom and along it
	for zb in [-1.0, 1.5, 4.0, 6.5]:
		var bz: float = float(zb)
		Kit.box(self, Vector3(2.0, H - 0.15, bz), Vector3(16.0, 0.3, 0.3), "wood/planks_dark", {"solid": false})
	Kit.box(self, Vector3(2.0, H - 0.32, 3.0), Vector3(0.3, 0.34, 10.0), "wood/planks_dark", {"solid": false})
	Kit.box(self, Vector3(6.0, H - 0.15, -5.0), Vector3(0.3, 0.3, 6.0), "wood/planks_dark", {"solid": false})
	# the back wall behind the bar is built by hand so it can have a hole in it
	# the opening is 0.8 m tall: the small player is 0.5 m, and 0.5 wedged shut
	Kit.box(self, Vector3(6.0, 2.1, -8.15), Vector3(8.0, 2.6, 0.3), "wall/plaster_tavern")
	Kit.box(self, Vector3(3.825, 0.4, -8.15), Vector3(3.65, 0.8, 0.3), "wall/plaster_tavern")
	Kit.box(self, Vector3(8.175, 0.4, -8.15), Vector3(3.65, 0.8, 0.3), "wall/plaster_tavern")
	Kit.box(self, Vector3(3.825, 0.9, -8.0), Vector3(3.55, 0.16, 0.06), "wood/planks_dark", {"solid": false})
	Kit.box(self, Vector3(8.175, 0.9, -8.0), Vector3(3.55, 0.16, 0.06), "wood/planks_dark", {"solid": false})
	Kit.mouse_gap(self, Vector3(6.0, 0, -8.0), 180.0, Vector2(0.7, 0.78), {"carve": false})
	# the mouse tunnel behind the wall
	# the floor runs in under the wall to meet the taproom's, or a mouse falls through the slot
	Kit.floor(self, Vector3(6.0, -0.02, -10.05), Vector2(0.7, 4.3), "wood/planks_dark")
	Kit.ceiling(self, Vector3(6.0, 0.8, -10.2), Vector2(0.7, 4.0), "wood/planks_dark")
	Kit.box(self, Vector3(5.5, 0.4, -10.2), Vector3(0.3, 0.8, 4.0), "wood/planks_dark")
	Kit.box(self, Vector3(6.5, 0.4, -10.2), Vector3(0.3, 0.8, 4.0), "wood/planks_dark")
	Kit.box(self, Vector3(6.0, 0.4, -12.35), Vector3(0.7, 0.8, 0.3), "wood/planks_dark")
	# lit well enough from the taproom side that the hole reads as a way, not a mark
	Kit.light(self, Vector3(6.0, 0.6, -8.7), WARM, 0.9, 2.5)
	Kit.light(self, Vector3(6.0, 0.65, -10.2), WARM, 0.8, 3.0)
	Kit.light(self, Vector3(6.0, 0.65, -11.6), WARM, 0.6, 2.5)
	SeamlessTeleport.link(self, Vector3(6.0, 0, -12.0), 0.0, UT + Vector3(0, 0, 11.4), 0.0, Vector3(2.0, 2.0, 0.4), {"name": "MouseSeam", "on_teleport": _on_mouse_seam})

	# --- the bar ---
	Props.place(self, "bar_counter", Vector3(4.0, 0, -2.4), 180.0, 1.0)
	Props.place(self, "keg", Vector3(7.2, 0, -2.4), 90.0, 1.0)
	Props.place(self, "barrel", Vector3(8.35, 0, -2.6), 0.0, 1.0)
	Props.place(self, "mug", Vector3(2.8, 1.16, -2.1), 20.0, 1.0, {"collision": "none"})
	Props.place(self, "mug", Vector3(5.1, 1.16, -2.2), -40.0, 1.0, {"collision": "none"})
	Props.place(self, "candle", Vector3(3.9, 1.16, -2.0), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "stool", Vector3(3.4, 0, -1.45), 0.0, 1.0)
	Props.place(self, "stool", Vector3(5.2, 0, -1.45), 0.0, 1.0)
	_shelf(Vector3(4.0, 0, -7.85))
	_shelf(Vector3(8.0, 0, -7.85))
	Props.place(self, "barrel", Vector3(9.2, 0, -7.2), 0.0, 1.0)
	Props.place(self, "crate", Vector3(9.3, 0, -5.4), 15.0, 1.0)
	Props.place(self, "crate_small", Vector3(9.3, 0.9, -5.4), -10.0, 1.0, {"collision": "none"})
	# the menu chalkboard and the riddle note
	var menu_lines: Array = ["TODAY: nothing", "TOMORROW: nothing, warmed"]
	if visit_count >= 2:
		menu_lines.append("Under it, in a different hand: YESTERDAY: you.")
	Readable.create(self, Vector3(3.0, 1.55, -7.9), 180.0, "Read the chalkboard", menu_lines,
		{"name": "Menu", "model": "sign_menu", "collision": "none", "size": Vector3(1.1, 0.8, 0.2), "offset": Vector3(0, 0.4, 0),
		"note_key": "tavern_menu", "note_title": "The menu at the Last Lamp", "note_text": "Today: nothing. Tomorrow: nothing, warmed."})
	Readable.create(self, Vector3(6.4, 1.6, -7.92), 180.0, "Read the note pinned to the wall", [
		"A note in the barkeep's hand, pinned where the patrons cannot reach it:",
		"I have doors but no house, a well but no water, and everyone waits in me. What am I?",
		"Under it: ONE COIN. NO CLUES. NO REFUNDS.",
	], {"name": "RiddleNote", "sign": "signs/note_tavern", "sign_size": Vector2(0.5, 0.5), "size": Vector3(0.6, 0.6, 0.1),
		"note_key": "tavern_riddle_note", "note_title": "The barkeep's riddle", "note_text": "Doors but no house. A well but no water. Everyone waits in it."})

	# --- people ---
	var keep := NPC.create(self, Vector3(4.0, 0, -3.5), 180.0, "The Barkeep", {"model": "barkeep", "face_player": true,
		"lines": ["He does not have a face. He has a very good apron."], "on_talk": _barkeep_talk, "name": "Barkeep"})
	_stand_in(keep, "barkeep")
	_bard_stage()

	# --- the hearth ---
	_hearth(Vector3(-5.9, 0, 1.0))
	Props.place(self, "rug_tavern", Vector3(-3.6, 0.005, 1.0), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "chair", Vector3(-4.2, 0, -0.5), 150.0, 1.0)
	Props.place(self, "chair", Vector3(-4.2, 0, 2.5), 30.0, 1.0)

	# --- tables and the people at them ---
	var t1 := Vector3(-1.0, 0, 0.6)
	var t2 := Vector3(-2.6, 0, 3.8)
	var t3 := Vector3(2.2, 0, 3.4)
	var t4 := Vector3(5.8, 0, 1.0)
	_round_table(t1, [0.0, 120.0, 240.0])
	_round_table(t2, [60.0, 180.0, 300.0])
	_round_table(t3, [30.0, 150.0, 270.0])
	_round_table(t4, [0.0, 90.0, 200.0])
	Props.place(self, "table_long", Vector3(5.0, 0, 6.2), 0.0, 1.0)
	Props.place(self, "bench", Vector3(5.0, 0, 5.2), 0.0, 1.0)
	Props.place(self, "bench", Vector3(5.0, 0, 7.2), 0.0, 1.0)
	Props.place(self, "stool", Vector3(3.2, 0, 6.2), 0.0, 1.0)
	Props.place(self, "candle", Vector3(4.2, 0.8, 6.2), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "bottle", Vector3(5.7, 0.8, 6.0), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "mug", Vector3(5.3, 0.8, 6.5), 70.0, 1.0, {"collision": "none"})
	_patrons(t1, t2, t4)

	# --- windows, hangings, the chandelier ---
	Props.place(self, "chandelier", Vector3(1.0, 2.35, 3.0), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "window_lit", Vector3(-3.0, 1.7, 7.92), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "window_lit", Vector3(4.5, 1.7, 7.92), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "window_lit", Vector3(-5.92, 1.7, 5.4), -90.0, 1.0, {"collision": "none"})
	Props.place(self, "tapestry", Vector3(-1.5, 3.2, -1.92), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "torch_wall", Vector3(9.9, 1.6, -0.5), 90.0, 1.0, {"collision": "none"})
	Props.place(self, "clock_grandfather", Vector3(-5.7, 0, -1.4), -90.0, 1.0)
	Props.place(self, "coat_rack", Vector3(2.9, 0, 7.6), 0.0, 1.0)
	Kit.particles(self, Vector3(1.0, 2.0, 3.0), "motes", Vector3(7.0, 1.2, 5.0), 60)
	rain = Kit.particles(self, Vector3(1.0, H - 0.4, 3.0), "rain", Vector3(7.0, 0.2, 5.0), 260)
	rain.emitting = Game.umbrella_open
	# the portrait whose eyes follow you, and what it is when you are not looking
	_portrait()

	# --- the front door ---
	var door_pos := Vector3(1.0, 0, 9.0)
	Door.create(self, door_pos, 0.0, "nexus", "from_tavern", {"kind": "red", "label": "Out", "name": "FrontDoor", "fade_color": Color(0.05, 0.02, 0.0)})
	Kit.box(self, Vector3(0.22, 1.15, 9.0), Vector3(0.44, 2.3, 0.3), "wood/planks_dark")
	Kit.box(self, Vector3(1.78, 1.15, 9.0), Vector3(0.44, 2.3, 0.3), "wood/planks_dark")
	add_spawn("from_nexus", door_pos + Vector3(0, 0.1, -1.7), 0.0)
	add_spawn("default", door_pos + Vector3(0, 0.1, -1.7), 0.0)

	# --- the kitchen nook ---
	Props.place(self, "kitchen_counter", Vector3(-3.0, 0, -7.55), 0.0, 1.0)
	Props.place(self, "stove", Vector3(-1.3, 0, -7.55), 0.0, 1.0)
	Props.place(self, "candle_cluster", Vector3(-3.4, 0.92, -7.5), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "barrel", Vector3(-5.4, 0, -4.6), 0.0, 0.9)
	Props.place(self, "crate", Vector3(-5.35, 0, -6.3), 10.0, 1.0)
	Props.place(self, "bottle", Vector3(-2.4, 0.92, -7.6), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "bottle", Vector3(-2.2, 0.92, -7.4), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "lantern_hanging", Vector3(-3.0, H - 0.05, -5.5), 0.0, 1.0, {"collision": "none"})
	Readable.create(self, Vector3(-1.3, 0.95, -7.3), 0.0, "Look in the pot", [
		"Something is simmering. It has been simmering since before the tavern.",
		"It smells of nothing, warmly.",
	], {"name": "Pot", "size": Vector3(0.8, 0.6, 0.6), "sound": "drip"})
	# the back door: it goes somewhere
	Door.create(self, Vector3(-5.84, 0, -5.0), -90.0, "", "", {"kind": "dark", "label": "The back door. It goes somewhere.", "name": "BackDoor",
		"fade_color": Color(0.01, 0.01, 0.02), "fade_duration": 1.3, "unstable": _back_door_target, "possible_targets": BACK_DOOR_TARGETS})
	Kit.light(self, Vector3(-5.0, 2.2, -5.0), Color(0.55, 0.6, 0.85), 0.5, 3.5)
	# a stair down to the cellar leaves through the kitchen's north door
	Kit.stairs(self, Vector3(-3.0, 0, -10.0), 0.0, 1.9, 14, -0.243, 0.32, "wood/planks_dark", {"name": "CellarStairs"})
	Kit.box(self, Vector3(-3.0, -0.13, -9.86), Vector3(1.9, 0.26, 0.28), "wood/planks_dark")

	# --- the stair up ---
	Kit.stairs(self, Vector3(9.0, 0, 8.0), 0.0, 1.9, 14, 0.243, 0.32, "wood/planks_warm", {"name": "Stairs"})
	Kit.box(self, Vector3(8.02, 1.2, 5.3), Vector3(0.16, 2.4, 3.6), "wood/planks_dark")
	Kit.box(self, Vector3(9.0, 3.3, 2.76), Vector3(2.0, 0.2, 1.52), "wood/planks_warm")
	Kit.box(self, Vector3(10.15, 4.8, 5.0), Vector3(0.3, 2.8, 6.0), "wall/plaster_tavern")
	Kit.box(self, Vector3(8.0, 4.8, 5.0), Vector3(0.3, 2.8, 6.0), "wall/plaster_tavern")
	Kit.box(self, Vector3(9.0, 4.8, 8.15), Vector3(2.3, 2.8, 0.3), "wall/plaster_tavern")
	Kit.ceiling(self, Vector3(9.0, 6.2, 5.0), Vector2(2.3, 6.0), "wood/planks_dark")
	Kit.light(self, Vector3(9.0, 4.6, 5.5), WARM, 0.8, 6.0)
	if not Game.has_flag("tavern_room"):
		rope = Node3D.new()
		rope.name = "Rope"
		add_child(rope)
		Kit.cylinder(rope, Vector3(7.75, 0, 7.0), 0.04, 0.95, "metal/brass", {"segments": 6, "solid": false})
		Kit.cylinder(rope, Vector3(7.75, 0, 7.95), 0.04, 0.95, "metal/brass", {"segments": 6, "solid": false})
		Kit.box(rope, Vector3(7.75, 0.86, 7.48), Vector3(0.05, 0.05, 0.95), "fabric/cloth_red", {"solid": false})
		Kit.blocker(rope, Vector3(8.8, 1.2, 7.6), Vector3(2.4, 2.4, 1.2))
		Readable.create(rope, Vector3(7.7, 0.5, 7.5), 90.0, "The stair is roped off.", [
			"The stair is roped off. A small brass plate: RESIDENTS ONLY.",
			"You are not a resident. You are barely a guest.",
		], {"name": "RopeSign", "size": Vector3(0.5, 1.2, 1.0)})
	Dog.maybe_spawn(self, Vector3(-2.5, 0.1, 2.0))


func _back_door_target() -> Array:
	var pick: Array = BACK_DOOR_TARGETS[Game.rng.randi_range(0, BACK_DOOR_TARGETS.size() - 1)]
	Game.bump("back_door_used")
	Game.note("back_door", "The back door", "The back door of the Last Lamp opens onto a different place each time. The barkeep does not seem to know this, or mind.")
	return pick


func _shelf(pos: Vector3) -> void:
	if Props.exists("wall_shelf"):
		Props.place(self, "wall_shelf", pos + Vector3(0, 1.4, 0), 180.0, 1.0, {"collision": "none"})
	else:
		Kit.box(self, pos + Vector3(0, 1.4, 0.16), Vector3(2.4, 0.06, 0.32), "wood/planks_dark", {"solid": false})
		Kit.box(self, pos + Vector3(0, 2.1, 0.16), Vector3(2.4, 0.06, 0.32), "wood/planks_dark", {"solid": false})
	if Props.exists("tankard_rack"):
		Props.place(self, "tankard_rack", pos + Vector3(0, 2.3, 0.05), 180.0, 1.0, {"collision": "none"})
	for i in 5:
		var x := -1.0 + i * 0.5
		Props.place(self, "bottle", pos + Vector3(x, 1.43, 0.18), float(i * 37), 1.0, {"collision": "none"})
		if i % 2 == 0:
			Props.place(self, "mug", pos + Vector3(x + 0.2, 2.13, 0.16), float(i * 50), 1.0, {"collision": "none"})


func _round_table(pos: Vector3, stool_angles: Array) -> void:
	Props.place(self, "table_round", pos, 0.0, 1.0, {"collision": "cylinder"})
	Props.place(self, "candle", pos + Vector3(0.12, 0.78, -0.1), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "mug", pos + Vector3(-0.25, 0.78, 0.2), 30.0, 1.0, {"collision": "none"})
	for a in stool_angles:
		var ang := float(a)
		Props.place(self, "stool", pos + Kit.polar(0.95, ang), 0.0, 1.0)


func _hearth(pos: Vector3) -> void:
	var glow := Color(1.0, 0.55, 0.2)
	if Props.exists("fireplace"):
		var fp := Props.place(self, "fireplace", pos, -90.0, 1.0)
		var f := Props.part(fp, "Fire")
		if f:
			flames.append(f)
	else:
		# a stone surround built into the west wall, a mantel, logs and a fire of cones
		Kit.box(self, pos + Vector3(0.35, 1.2, -1.15), Vector3(0.7, 2.4, 0.5), "brick/dark")
		Kit.box(self, pos + Vector3(0.35, 1.2, 1.15), Vector3(0.7, 2.4, 0.5), "brick/dark")
		Kit.box(self, pos + Vector3(0.35, 2.05, 0), Vector3(0.7, 0.7, 2.8), "brick/dark")
		Kit.box(self, pos + Vector3(0.45, 2.45, 0), Vector3(0.95, 0.12, 3.1), "wood/planks_dark")
		Kit.box(self, pos + Vector3(0.6, 0.06, 0), Vector3(1.2, 0.12, 2.8), "stone/smooth_grey")
		Kit.box(self, pos + Vector3(0.05, 0.9, 0), Vector3(0.1, 1.6, 1.8), "brick/dark", {"solid": false, "tint": Color(0.35, 0.3, 0.3)})
		Kit.box(self, pos + Vector3(0.35, 0.22, -0.2), Vector3(0.7, 0.16, 0.16), "nature/bark_oak", {"solid": false})
		Kit.box(self, pos + Vector3(0.35, 0.36, 0.15), Vector3(0.7, 0.16, 0.16), "nature/bark_dead", {"solid": false, "rotation": Vector3(0, 12, 0)})
		var fire := Node3D.new()
		fire.name = "Fire"
		fire.position = pos + Vector3(0.35, 0.3, 0)
		add_child(fire)
		var inner := Color(1.0, 0.85, 0.45)
		Kit.cylinder(fire, Vector3(0, 0, 0), 0.34, 0.9, "", {"top_radius": 0.02, "segments": 5, "solid": false, "unshaded": true, "tint": glow, "emission": glow, "emission_energy": 0.8})
		Kit.cylinder(fire, Vector3(0.12, 0, 0.18), 0.22, 0.6, "", {"top_radius": 0.02, "segments": 5, "solid": false, "unshaded": true, "tint": inner, "emission": inner, "emission_energy": 0.9})
		Kit.cylinder(fire, Vector3(-0.1, 0, -0.22), 0.2, 0.7, "", {"top_radius": 0.02, "segments": 5, "solid": false, "unshaded": true, "tint": glow, "emission": glow, "emission_energy": 0.8})
		flames.append(fire)
		Props.place(self, "candle_tall", pos + Vector3(0.45, 2.5, -1.0), 0.0, 1.0, {"collision": "none"})
		Props.place(self, "bottle", pos + Vector3(0.5, 2.5, 0.9), 0.0, 1.0, {"collision": "none"})
	Kit.particles(self, pos + Vector3(0.35, 0.5, 0), "embers", Vector3(0.3, 0.2, 0.7), 16)
	Readable.create(self, pos + Vector3(0.6, 0.6, 0), -90.0, "Warm your hands", [
		"The fire is the warmest thing you have ever stood near. It makes no sound.",
		"There is no chimney. The smoke goes up and simply stops being smoke.",
	], {"name": "Hearth", "size": Vector3(0.8, 1.2, 1.8), "sound": "brazier",
		"note_key": "hearth", "note_title": "The hearth at the Last Lamp", "note_text": "A fire with no sound and no chimney. Everything here is warm. That is the point."})


func _bard_stage() -> void:
	var pos := Vector3(-4.4, 0, 6.6)
	if Props.exists("stage_small"):
		Props.place(self, "stage_small", pos, 0.0, 1.0)
	else:
		Kit.box(self, pos + Vector3(0, 0.15, 0), Vector3(3.0, 0.3, 2.2), "wood/planks_dark")
		Kit.box(self, pos + Vector3(0, 0.04, -1.25), Vector3(3.0, 0.08, 0.3), "wood/planks_dark")
	Props.place(self, "candle_tall", pos + Vector3(-1.3, 0.3, 0.9), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "candle_tall", pos + Vector3(1.3, 0.3, 0.9), 0.0, 1.0, {"collision": "none"})
	bard = NPC.create(self, pos + Vector3(0, 0.3, -0.2), 0.0, "The Bard", {"model": "bard", "face_player": false, "name": "Bard",
		"lines": [
			"The song has no end. It has a middle, which is where you came in.",
			"Everyone asks what it is about. It is about four minutes, so far, and then it keeps going.",
			"He does not stop playing to say this. His hands are somewhere else, being hands.",
		],
		"reactions": {
			"bell": ["He sees the bell before you ring it.", "\"Don't,\" he says, and keeps playing, slightly faster."],
			"crown": ["\"A crown! I have a verse for crowns.\"", "It is the same verse."],
			"knife": ["\"You can't cut a song,\" he says. \"People have tried. It just goes quiet for a bit.\""],
		}})
	_stand_in(bard, "bard")
	bard_sign = Readable.create(self, pos + Vector3(0, 0.3, -0.95), 0.0, "Read the chalked sign", [
		"Chalked on the front of the stage: TONIGHT — THE SONG (cont.)",
		"The 'cont.' has been re-chalked many times. The chalk under it is worn into a groove.",
	], {"name": "BardSign", "size": Vector3(1.2, 0.5, 0.3), "offset": Vector3(0, 0.1, 0)})
	Kit.label(self, "TONIGHT: THE SONG (cont.)", pos + Vector3(0, 0.18, -1.12), 0.0, 22, Color(0.9, 0.86, 0.75), "body", {"pixel_size": 0.008, "outline": 6})


func _patrons(t1: Vector3, t2: Vector3, t4: Vector3) -> void:
	var specs := [
		[Vector3(3.4, 0, -1.45), 0.0, "A Patron at the Bar", ["\"It's warm,\" he says, to nobody. \"That's the point.\"", "He has been saying it for a while. It is still true."], {}, false],
		[t1 + Kit.polar(0.95, 0.0), Kit.dir_to_yaw(-Kit.polar(1.0, 0.0)), "A Woman with a Mug", ["\"Don't answer his riddle,\" she says. \"He only has the one, and then what will he do?\"", "Her mug is full. It has always been full."], {"mouse": ["She looks down. It takes her a moment to find you.", "\"You're very small. Is that on purpose?\""]}, false],
		[t2 + Kit.polar(0.95, 300.0), Kit.dir_to_yaw(-Kit.polar(1.0, 300.0)), "A Patron by the Stage", ["\"He's been playing since I got here,\" the patron says. \"I got here before him.\""], {}, true],
		[t4 + Kit.polar(0.95, 0.0), Kit.dir_to_yaw(-Kit.polar(1.0, 0.0)), "A Patron in the Corner", ["The patron does not look up. There is nothing on the patron to look up with.", "\"Coming or going?\" he asks. You are not sure. \"Same,\" he says."], {}, false],
		[Vector3(3.2, 0, 6.2), -90.0, "A Quiet Patron", ["Nothing. A nod. The nod is warm too."], {"crown": ["The quiet patron stands, bows, sits. \"Majesty.\" Then, quieter: \"It's paper, isn't it. Doesn't matter. Doesn't matter here.\""]}, false],
	]
	var i := 0
	for s in specs:
		var spec: Array = s
		var pos: Vector3 = spec[0]
		var yaw: float = float(spec[1])
		var nm: String = spec[2]
		var lines: Array = spec[3]
		var reacts: Dictionary = spec[4]
		var flee: bool = bool(spec[5])
		var n := NPC.create(self, pos, yaw, nm, {"model": "patron_seated", "lines": lines, "reactions": reacts, "flee_knife": flee, "face_player": false, "name": "Patron%d" % i})
		_stand_in(n, "patron", i)
		i += 1


func _portrait() -> void:
	var pos := Vector3(-5.94, 1.85, 3.2)
	portrait_a = Props.place(self, "painting_portrait", pos, -90.0, 1.0, {"collision": "none", "name": "Portrait"})
	portrait_b = Props.place(self, "painting_door", pos, -90.0, 1.0, {"collision": "none", "name": "PortraitDoor"})
	var swapped := Game.has_flag("portrait_swapped")
	portrait_a.visible = not swapped
	portrait_b.visible = swapped
	portrait_readable = Readable.create(self, pos, -90.0, "Look at the portrait", PORTRAIT_AFTER if swapped else PORTRAIT_BEFORE,
		{"name": "PortraitLook", "size": Vector3(0.3, 1.2, 1.2), "offset": Vector3.ZERO})
	if not swapped:
		LookAway.create(self, pos, _on_portrait_unseen, {"radius": 11.0, "delay": 2.5, "require_seen_first": true, "once": true, "name": "PortraitWatch"})


func _on_portrait_unseen(_l: Node) -> void:
	Game.set_flag("portrait_swapped", true)
	if portrait_a != null:
		portrait_a.visible = false
	if portrait_b != null:
		portrait_b.visible = true
	if portrait_readable != null:
		portrait_readable.lines = PORTRAIT_AFTER
	Audio.sfx("creak", Vector3(-5.9, 1.8, 3.2), -8.0)
	Game.toast.emit("Something on the wall changes while you are not looking at it.")
	Game.note("portrait", "The portrait by the hearth", "A man with a lamp, in a good coat. When you looked away for long enough he was a door. Nobody in the taproom noticed. Nobody in the taproom has eyes.")


# --- upstairs ---------------------------------------------------------------------

func _upstairs() -> void:
	var rows := [
		"#######",
		"#r..#L#",
		"#...D.#",
		"#...#.#",
		"#####.#",
		"    #.#",
	]
	MapBuilder.build(self, rows, {"cell": CELL, "height": 2.8, "origin": Vector3(-2, H, -10), "floor": "wood/planks_warm",
		"wall": "wall/plaster_tavern", "ceiling": "wood/planks_dark", "open_edges": true, "door_h": 2.1, "name": "Upstairs"})
	# landing
	Props.place(self, "lantern_hanging", Vector3(9.0, H + 2.75, -4.0), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, Vector3(9.0, H + 1.3, -4.0), WARM, 1.1, 8.0)
	Kit.light(self, Vector3(9.0, H + 1.6, 1.0), WARM, 0.6, 5.0)
	Props.place(self, "rug_red", Vector3(9.0, H + 0.005, -3.0), 0.0, 0.7, {"collision": "none"})
	Props.place(self, "painting_landscape", Vector3(9.94, H + 1.7, -6.5), 90.0, 1.0, {"collision": "none"})
	Props.place(self, "chair", Vector3(9.4, H, -8.5), 200.0, 1.0)
	Props.place(self, "plant_pot", Vector3(8.4, H, -0.5), 0.0, 1.0, {"collision": "none"})
	Readable.create(self, Vector3(9.9, H + 1.7, -6.5), 90.0, "Look at the landscape", [
		"A painting of a road at night, and at the end of it a lamp.",
		"You know the road. You have never seen it from this end.",
	], {"name": "LandscapeLook", "size": Vector3(0.2, 1.1, 1.1), "offset": Vector3.ZERO})
	# the rented room
	var bed_pos := Vector3(1.4, H, -6.85)
	Bed.create(self, bed_pos, 0.0, "sea", "from_tavern", {"model": "bed_inn", "sleep_text": "Sleep in the rented bed", "name": "InnBed"})
	add_spawn("from_sea", bed_pos + Vector3(1.7, 0.1, 0.5), -90.0)
	Readable.create(self, bed_pos + Vector3(0, 0.75, -0.7), 0.0, "Read the note on the pillow", [
		"A note on the pillow, folded twice:",
		"The tide comes in while you sleep. Do not worry about the bed. The bed knows the way.",
		"P.S. Breakfast is nothing. It will be warmed.",
	], {"name": "PillowNote", "size": Vector3(0.6, 0.3, 0.5), "sign": "signs/note_house", "sign_size": Vector2(0.3, 0.3), "offset": Vector3(0, 0.15, 0),
		"note_key": "pillow_note", "note_title": "The note on the pillow", "note_text": "The tide comes in while you sleep. The bed knows the way."})
	Props.place(self, "window_night", Vector3(4.0, H + 1.55, -7.92), 180.0, 1.0, {"collision": "none"})
	Readable.create(self, Vector3(4.0, H + 1.55, -7.85), 180.0, "Look out of the window", [
		"Through the window: the sea. Pink, and very slow.",
		"There is no sea outside the tavern. It is very close.",
	], {"name": "RoomWindow", "size": Vector3(1.4, 1.5, 0.2), "offset": Vector3.ZERO})
	Kit.light(self, Vector3(4.0, H + 1.6, -7.2), Color(0.75, 0.7, 1.0), 0.6, 5.0)
	Props.place(self, "dresser", Vector3(2.2, H, -2.5), 0.0, 0.9)
	Props.place(self, "candle_tall", Vector3(2.2, H + 0.9, -2.5), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, Vector3(2.4, H + 1.6, -3.2), CANDLE, 1.0, 6.0)
	Props.place(self, "chair", Vector3(3.6, H, -3.0), 40.0, 1.0)
	Props.place(self, "rug_house", Vector3(3.2, H + 0.005, -5.0), 90.0, 1.0, {"collision": "none"})
	Props.place(self, "painting_house", Vector3(0.06, H + 1.7, -3.5), -90.0, 0.8, {"collision": "none"})
	Props.place(self, "coat_rack", Vector3(5.6, H, -2.5), 0.0, 1.0)
	# the usher waits on the landing, second time round
	if visit_count >= 2 and Game.count("usher_sightings") < 9:
		Usher.spawn(self, Vector3(9.0, H, -7.0), {"appear_delay": 3.0, "radius": 16.0})


# --- cellar -------------------------------------------------------------------------

func _cellar() -> void:
	var rows := [
		"#####",
		"#...#",
		"#...#",
		"#...#",
		"##:##",
		"##:##",
	]
	var y := -H
	MapBuilder.build(self, rows, {"cell": CELL, "height": 2.8, "origin": Vector3(-8, y, -22), "floor": "stone/cobble_grey",
		"wall": "brick/dark", "ceiling": "wood/planks_dark", "open_edges": true, "name": "Cellar", "tile": 1.5})
	# the stairwell above the cellar's ceiling, up to the kitchen door
	Kit.box(self, Vector3(-5.0, 1.1, -12.0), Vector3(2.0, 3.4, 4.0), "brick/dark", {"tile": 1.5})
	Kit.box(self, Vector3(-1.0, 1.1, -12.0), Vector3(2.0, 3.4, 4.0), "brick/dark", {"tile": 1.5})
	Kit.box(self, Vector3(-3.0, 1.1, -14.15), Vector3(2.0, 3.4, 0.3), "brick/dark", {"tile": 1.5})
	Kit.ceiling(self, Vector3(-3.0, 2.8, -12.0), Vector2(2.0, 4.0), "wood/planks_dark")
	Kit.light(self, Vector3(-3.0, 1.2, -11.0), WARM, 0.3, 4.0)
	# what is kept down here
	Props.place(self, "keg", Vector3(-5.2, y, -20.8), 90.0, 1.0)
	Props.place(self, "keg", Vector3(-5.2, y, -19.6), 90.0, 1.0)
	Props.place(self, "keg", Vector3(-5.2, y + 0.9, -20.2), 90.0, 1.0, {"collision": "none"})
	Props.place(self, "barrel", Vector3(-0.8, y, -20.9), 0.0, 1.0)
	Props.place(self, "barrel", Vector3(-0.7, y, -19.7), 0.0, 0.9)
	Props.place(self, "crate", Vector3(-1.0, y, -16.0), 25.0, 1.0)
	Props.place(self, "crate_small", Vector3(-5.2, y, -16.2), 0.0, 1.0)
	Props.place(self, "crate_small", Vector3(-5.2, y + 0.5, -16.2), 30.0, 1.0, {"collision": "none"})
	Props.place(self, "bottle", Vector3(-1.0, y + 0.9, -16.0), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "lantern_hanging_cold", Vector3(-3.0, y + 2.75, -18.0), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, Vector3(-3.0, y + 1.4, -18.0), Color(0.6, 0.85, 0.85), 0.9, 8.0)
	Kit.light(self, Vector3(-4.5, y + 0.9, -20.5), Color(1.0, 0.6, 0.35), 0.5, 4.0)
	Kit.particles(self, Vector3(-3.0, y + 1.2, -18.0), "motes", Vector3(2.5, 1.0, 3.0), 25)
	Readable.create(self, Vector3(-5.2, y + 0.9, -20.2), 90.0, "Read the labels on the kegs", [
		"The kegs are labelled by year. The years are not in order, and one of them has not happened yet.",
		"That one is empty. Somebody has been drinking ahead.",
	], {"name": "KegLabels", "size": Vector3(1.2, 1.4, 2.4), "offset": Vector3(0, 0.2, 0),
		"note_key": "cellar_kegs", "note_title": "The cellar of the Last Lamp", "note_text": "Kegs labelled by year, out of order. One year has not happened yet and is already empty."})
	# the small iron door in the north wall: warm, and bolted from below until
	# the rope in the Furnace is cut
	Door.create(self, Vector3(-3.0, y, -19.86), 180.0, "furnace", "from_tavern", {"kind": "iron", "label": "A small iron door. Warm.", "name": "FurnaceDoor", "requires_flag": "gallows_cut", "locked_text": "An iron door, warm to the touch, bolted from the other side. Something a long way below is humming.", "fade_color": Color(0.2, 0.02, 0.02), "fade_duration": 1.2, "sound": "door_heavy"})
	add_spawn("from_furnace", Vector3(-3.0, y + 0.1, -18.5), 180.0)
	if Game.has_flag("gallows_cut"):
		NPC.create(self, Vector3(-4.4, y, -17.6), 70.0, "The one who was humming", {
			"name": "Hummer", "model": "patron_seated", "face_player": true, "flee_knife": false,
			"lines": ["Told you. The tab stands.", "I came up the stairs that are not all there. Do not look down on the third one. There is no third one.", "The barkeep has not noticed I am back. I am taking that as a kindness."],
			"reactions": {"knife": ["Put that away. It has done its bit."], "bell": ["Ring that upstairs. He will pretend not to hear it."], "umbrella": ["Weather. Indoors. Now I have seen everything twice."]},
		})
	Readable.create(self, Vector3(-1.0, y + 0.95, -16.0), 0.0, "An empty bottle", [
		"An ordinary bottle, uncorked, kept apart from the others.",
		"Whatever was in it was not a liquid. The inside of the glass is still faintly bright.",
	], {"name": "EmptyBottle", "size": Vector3(0.4, 0.5, 0.4), "sound": "ui_blip"})


# --- outside the front door ----------------------------------------------------------

func _outside() -> void:
	Kit.floor(self, Vector3(1.0, 0, 13.0), Vector2(12.0, 6.0), "stone/cobble_grey", {"tile": 1.5})
	# the inn's face: the walls of the map have no outside, so give them one
	Kit.box(self, Vector3(-4.0, 2.4, 10.15), Vector3(8.0, 4.8, 0.3), "wood/planks_wall")
	Kit.box(self, Vector3(7.0, 2.4, 10.15), Vector3(10.0, 4.8, 0.3), "wood/planks_wall")
	Kit.box(self, Vector3(1.0, 3.55, 10.15), Vector3(2.0, 2.5, 0.3), "wood/planks_wall")
	Kit.box(self, Vector3(2.0, 5.0, 10.7), Vector3(21.0, 0.5, 1.5), "wood/thatch")
	Props.place(self, "window_lit", Vector3(-3.0, 1.7, 10.36), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "window_lit", Vector3(4.5, 1.7, 10.36), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "sign_last_lamp", Vector3(3.4, 0, 12.6), 0.0, 1.0, {"collision": "cylinder"})
	Props.place(self, "sign_no_vacancy", Vector3(-3.4, 0, 12.4), 0.0, 1.0, {"collision": "cylinder"})
	Props.place(self, "lantern_hanging", Vector3(1.0, 4.7, 10.6), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, Vector3(1.0, 3.0, 11.0), WARM, 1.6, 9.0)
	Props.place(self, "lantern_post", Vector3(-5.5, 0, 14.8), 30.0, 1.0, {"collision": "cylinder"})
	Kit.light(self, Vector3(-5.2, 3.0, 14.6), WARM, 1.0, 8.0)
	Props.place(self, "barrel", Vector3(6.2, 0, 11.4), 0.0, 1.0)
	Props.place(self, "tree_dead_1", Vector3(7.5, 0, 15.2), 70.0, 0.9, {"collision": "cylinder", "collision_scale": 0.3})
	Props.place(self, "rock_1", Vector3(-1.5, 0, 15.5), 20.0, 1.0)
	var vacancy_line := "It has said this for years. The lamp above it is the last lamp. After this there are no more."
	if Game.has_flag("tavern_room"):
		vacancy_line = "Someone has added, underneath, in chalk: except the one."
	Readable.create(self, Vector3(-3.4, 0, 12.4), 0.0, "Read the sign", ["NO VACANCY.", vacancy_line],
		{"name": "VacancySign", "size": Vector3(1.6, 3.2, 0.6), "offset": Vector3(0.6, 1.6, 0)})
	Kit.particles(self, Vector3(1.0, 1.0, 13.0), "fog", Vector3(7.0, 0.4, 3.0), 10)
	# the road ends here. beyond the porch is nothing at all.
	Kit.blocker(self, Vector3(1.0, 2.0, 16.15), Vector3(12.4, 4.0, 0.3))
	Kit.blocker(self, Vector3(-5.15, 2.0, 13.0), Vector3(0.3, 4.0, 6.4))
	Kit.blocker(self, Vector3(7.15, 2.0, 13.0), Vector3(0.3, 4.0, 6.4))
	Kit.label(self, "the road ends here", Vector3(1.0, 0.9, 15.7), 0.0, 30, Color(0.45, 0.4, 0.32), "body", {"pixel_size": 0.01})


# --- the undertavern (for the Tin Mouse) -----------------------------------------------

func _undertavern() -> void:
	var s := 3.0
	var W := 18.0
	var D := 14.0
	var c := UT
	var wood := "wood/planks_dark"
	Kit.floor(self, c, Vector2(W, D), "wood/planks_warm", {"tile": 6.0})
	Kit.ceiling(self, c + Vector3(0, 4.5, 0), Vector2(W, D), wood, {"tile": 6.0})
	Kit.box(self, c + Vector3(0, 2.25, -D * 0.5 - 0.3), Vector3(W + 1.2, 4.5, 0.6), wood, {"tile": 6.0})
	Kit.box(self, c + Vector3(-W * 0.5 - 0.3, 2.25, 0), Vector3(0.6, 4.5, D), wood, {"tile": 6.0})
	Kit.box(self, c + Vector3(W * 0.5 + 0.3, 2.25, 0), Vector3(0.6, 4.5, D), wood, {"tile": 6.0})
	# south wall with the tunnel mouth (1.8 m: the hole behind the bar, seen from the other side)
	Kit.box(self, c + Vector3(-(W * 0.25 + 0.45), 2.25, D * 0.5 + 0.3), Vector3(W * 0.5 - 0.9, 4.5, 0.6), wood, {"tile": 6.0})
	Kit.box(self, c + Vector3((W * 0.25 + 0.45), 2.25, D * 0.5 + 0.3), Vector3(W * 0.5 - 0.9, 4.5, 0.6), wood, {"tile": 6.0})
	Kit.box(self, c + Vector3(0, 3.15, D * 0.5 + 0.3), Vector3(1.8, 2.7, 0.6), wood, {"tile": 6.0})
	# the tunnel (three times the one behind the bar)
	var tz := c.z + D * 0.5 + 0.6 + 6.0
	# the floor runs on through the wall's thickness to the room's edge, or a
	# mouse falls through the slot under the mouth
	Kit.floor(self, Vector3(c.x, 0, tz - 0.3), Vector2(1.8, 12.6), wood, {"tile": 6.0})
	Kit.ceiling(self, Vector3(c.x, 1.8, tz), Vector2(1.8, 12.0), wood, {"tile": 6.0})
	Kit.box(self, Vector3(c.x - 1.35, 0.9, tz), Vector3(0.9, 1.8, 12.0), wood, {"tile": 6.0})
	Kit.box(self, Vector3(c.x + 1.35, 0.9, tz), Vector3(0.9, 1.8, 12.0), wood, {"tile": 6.0})
	Kit.box(self, Vector3(c.x, 0.9, tz + 6.45), Vector3(1.8, 1.8, 0.9), wood, {"tile": 6.0})
	Kit.light(self, Vector3(c.x, 1.2, tz), WARM, 0.6, 6.0)
	# light through the floorboards above
	for i in 5:
		var x := c.x - 6.0 + i * 3.0
		Kit.box(self, Vector3(x, 4.45, c.z - 2.0 + (i % 2) * 3.0), Vector3(2.4, 0.06, 0.12), "", {"solid": false, "unshaded": true, "tint": Color(1.0, 0.85, 0.55), "emission": Color(1.0, 0.8, 0.5), "emission_energy": 1.0})
	Kit.light(self, c + Vector3(-4.0, 3.5, -2.0), WARM, 1.6, 12.0)
	Kit.light(self, c + Vector3(4.0, 3.5, 1.0), WARM, 1.6, 12.0)
	Kit.light(self, c + Vector3(0, 2.0, 5.0), Color(1.0, 0.7, 0.45), 0.9, 8.0)
	# giant furniture
	var table := c + Vector3(2.0, 0, -2.0)
	Props.place(self, "table_round", table, 0.0, s, {"collision": "cylinder"})
	Kit.ramp(self, table + Vector3(0, 0, 6.25), 0.0, 1.3, 4.6, 2.34, "wood/planks_warm", {"name": "Board"})
	Kit.box(self, table + Vector3(-0.9, 0.12, 6.4), Vector3(0.5, 0.24, 0.5), "", {"tint": Color(0.85, 0.72, 0.5)})
	Props.place(self, "mug", table + Vector3(-0.6, 2.34, 0.9), 40.0, s, {"collision": "cylinder"})
	Props.place(self, "candle", table + Vector3(0.9, 2.34, -0.6), 0.0, s, {"collision": "none"})
	Kit.light(self, table + Vector3(0.9, 3.5, -0.6), CANDLE, 1.2, 7.0)
	Pickup.create(self, table + Vector3(0.1, 2.34, -0.3), {"item": "rose", "requires_keepsake": "mouse", "name": "PaperRose", "key": "picked_rose_tavern", "prompt": "Take the paper rose"})
	Props.place(self, "stool", c + Vector3(-2.5, 0, 3.0), 0.0, s, {"collision": "box"})
	Props.place(self, "stool", c + Vector3(6.5, 0, 3.5), 30.0, s, {"collision": "box"})
	Props.place(self, "mug", c + Vector3(-6.0, 0, -4.5), -20.0, s, {"collision": "cylinder"})
	Props.place(self, "bottle", c + Vector3(-6.5, 0, 2.5), 0.0, s, {"collision": "cylinder"})
	Props.place(self, "bottle", c + Vector3(-5.6, 0, 3.6), 0.0, s, {"collision": "cylinder"})
	Props.place(self, "candle", c + Vector3(6.0, 0, -5.0), 0.0, s, {"collision": "cylinder"})
	Kit.light(self, c + Vector3(6.0, 1.3, -5.0), CANDLE, 1.0, 6.0)
	Props.place(self, "keg", c + Vector3(-6.5, 0, -1.5), 90.0, s, {"collision": "box"})
	# crumbs
	var crumb := Color(0.86, 0.74, 0.5)
	for i in 14:
		var p := c + Vector3(rng.randf_range(-7.5, 7.5), 0, rng.randf_range(-5.5, 5.0))
		var sz := rng.randf_range(0.15, 0.45)
		Kit.box(self, p + Vector3(0, sz * 0.5, 0), Vector3(sz * rng.randf_range(0.8, 1.6), sz, sz), "", {"tint": crumb.darkened(rng.randf_range(0.0, 0.3)), "rotation": Vector3(0, rng.randf_range(0, 360), 0)})
	# the mice
	var mouse_model: String = "item_mouse" if Props.exists("item_mouse") else "dog"
	var mouse_scale: float = 2.5 if mouse_model == "item_mouse" else 0.4
	var m1 := NPC.create(self, c + Vector3(-1.0, 0, 3.6), 180.0, "A Mouse", {"model": mouse_model, "lines": [
		"\"Oh,\" says the mouse. \"You're one of the big ones, only not.\"",
		"\"We have a tavern too. Ours is under theirs. Theirs is under something else. Nobody's asked what.\"",
	], "name": "Mouse1"})
	var m2 := NPC.create(self, c + Vector3(5.5, 0, -4.2), 240.0, "Another Mouse", {"model": mouse_model, "lines": [
		"\"The rose on the table isn't ours,\" the mouse says. \"It fell through the boards. Paper. Folded from a page.\"",
		"\"We don't read. We were going to keep it anyway. You can have it if you can get up there.\"",
	], "name": "Mouse2"})
	var m3 := NPC.create(self, c + Vector3(-6.0, 0, -5.5), 120.0, "The Oldest Mouse", {"model": mouse_model, "lines": [
		"\"The barkeep upstairs has no face,\" says the oldest mouse. \"We've had a look. Under the floor you can see up through the knots in the wood.\"",
		"\"He has a very good apron,\" it adds, with something like loyalty.",
	], "reactions": {"bell": ["The oldest mouse flinches at the bell and then pretends it didn't.", "\"We heard that one before. It rang for a long time. Then the sea came in.\""]}, "name": "Mouse3"})
	for m in [m1, m2, m3]:
		var npc: NPC = m
		if npc.body != null:
			npc.body.scale = Vector3.ONE * mouse_scale
		else:
			_stand_in(npc, "mouse")
	Readable.create(self, c + Vector3(-8.6, 0.8, -1.0), -90.0, "Read the scratches on the wall", [
		"Scratched into the skirting, very small, very neat:",
		"WE ARE ALSO WAITING. WE DO NOT KNOW WHAT FOR. IT IS WARM.",
		"Under it, a tally. It has been kept for a long time.",
	], {"name": "MouseScratches", "size": Vector3(0.4, 1.4, 2.0), "offset": Vector3(0, 0.2, 0),
		"note_key": "undertavern_scratches", "note_title": "The scratches under the floor", "note_text": "We are also waiting. We do not know what for. It is warm."})
	Readable.create(self, c + Vector3(6.0, 0.4, -5.0), 0.0, "A candle as tall as you", [
		"A candle as tall as you are. It has been burning as long as the one upstairs.",
		"Somebody carried it down here. Somebody your size.",
	], {"name": "GiantCandle", "size": Vector3(0.5, 1.2, 0.5)})
	Kit.particles(self, c + Vector3(0, 2.0, 0), "motes", Vector3(8.0, 2.0, 6.0), 50)


func _on_mouse_seam(_p: Node) -> void:
	if not Game.has_note("undertavern"):
		Game.toast.emit("The tunnel gets bigger. Or you get smaller. It is hard to say which.")
	Game.note("undertavern", "Under the tavern", "Behind the bar there is a hole the size of a fist. Through it, the same tavern, three times too large, and mice who have also been waiting.")


# --- stand-in figures (used until the figure models exist) ------------------------------

## Builds a blocky body under an NPC whose model is missing, so the room is never empty.
func _stand_in(npc: NPC, kind: String, seed_: int = 0) -> void:
	if npc.body != null:
		return
	var b := Node3D.new()
	b.name = "StandIn"
	npc.add_child(b)
	npc.body = b
	npc.add_box(Vector3(0.7, 1.7, 0.7), Vector3(0, 0.85, 0))
	var skin := Color(0.9, 0.82, 0.7)
	match kind:
		"barkeep":
			var shirt := Color(0.55, 0.5, 0.42)
			var trous := Color(0.22, 0.2, 0.18)
			_bx(b, Vector3(-0.1, 0.43, 0), Vector3(0.16, 0.86, 0.18), trous)
			_bx(b, Vector3(0.1, 0.43, 0), Vector3(0.16, 0.86, 0.18), trous)
			_bx(b, Vector3(0, 1.16, 0), Vector3(0.44, 0.62, 0.26), shirt)
			_bx(b, Vector3(-0.28, 1.12, 0), Vector3(0.11, 0.6, 0.11), shirt)
			_bx(b, Vector3(0.28, 1.12, 0), Vector3(0.11, 0.6, 0.11), shirt)
			_bx(b, Vector3(0, 0.86, -0.15), Vector3(0.36, 0.92, 0.04), Color(0.94, 0.92, 0.86))
			_bx(b, Vector3(0, 1.32, -0.14), Vector3(0.3, 0.3, 0.03), Color(0.94, 0.92, 0.86))
			_sphere(b, Vector3(0, 1.67, 0), 0.14, skin)
		"bard":
			var tunic := Color(0.36, 0.24, 0.5)
			var hose := Color(0.42, 0.34, 0.22)
			_bx(b, Vector3(-0.1, 0.42, 0), Vector3(0.15, 0.84, 0.17), hose)
			_bx(b, Vector3(0.1, 0.42, 0), Vector3(0.15, 0.84, 0.17), hose)
			_bx(b, Vector3(0, 1.12, 0), Vector3(0.42, 0.6, 0.24), tunic)
			_bx(b, Vector3(-0.3, 1.05, -0.18), Vector3(0.1, 0.1, 0.4), tunic)
			_bx(b, Vector3(0.3, 1.1, -0.18), Vector3(0.1, 0.1, 0.4), tunic)
			_bx(b, Vector3(0.02, 0.92, -0.32), Vector3(0.36, 0.5, 0.1), Color(0.6, 0.4, 0.2))
			_bx(b, Vector3(0.24, 1.22, -0.32), Vector3(0.06, 0.34, 0.06), Color(0.35, 0.22, 0.12), Vector3(0, 0, -35))
			_sphere(b, Vector3(0, 1.62, 0), 0.13, skin)
			_bx(b, Vector3(0, 1.8, 0), Vector3(0.3, 0.1, 0.3), Color(0.22, 0.42, 0.24))
			_bx(b, Vector3(0.1, 1.95, 0), Vector3(0.03, 0.3, 0.03), Color(0.85, 0.22, 0.2), Vector3(0, 0, -30))
		"patron":
			var cols := [Color(0.42, 0.38, 0.34), Color(0.3, 0.36, 0.42), Color(0.45, 0.3, 0.28), Color(0.35, 0.4, 0.3), Color(0.4, 0.34, 0.44)]
			var cloth: Color = cols[seed_ % cols.size()]
			var trous := Color(0.22, 0.2, 0.19)
			_bx(b, Vector3(-0.1, 0.5, -0.2), Vector3(0.15, 0.15, 0.44), trous)
			_bx(b, Vector3(0.1, 0.5, -0.2), Vector3(0.15, 0.15, 0.44), trous)
			_bx(b, Vector3(-0.1, 0.22, -0.4), Vector3(0.14, 0.44, 0.14), trous)
			_bx(b, Vector3(0.1, 0.22, -0.4), Vector3(0.14, 0.44, 0.14), trous)
			_bx(b, Vector3(0, 0.88, 0), Vector3(0.42, 0.6, 0.24), cloth)
			_bx(b, Vector3(-0.27, 0.9, -0.05), Vector3(0.11, 0.42, 0.11), cloth)
			_bx(b, Vector3(0.27, 0.9, -0.05), Vector3(0.11, 0.42, 0.11), cloth)
			_sphere(b, Vector3(0, 1.36, 0), 0.13, skin)
			_sphere(b, Vector3(0, 1.42, 0.01), 0.125, Color(0.25, 0.17, 0.1), Vector3(1.05, 0.6, 1.05))
		"mouse":
			var tin := Color(0.72, 0.68, 0.6)
			_sphere(b, Vector3(0, 0.27, 0), 0.25, tin, Vector3(0.85, 0.75, 1.3))
			_sphere(b, Vector3(-0.14, 0.5, -0.12), 0.09, Color(0.8, 0.7, 0.68), Vector3(1, 1, 0.3))
			_sphere(b, Vector3(0.14, 0.5, -0.12), 0.09, Color(0.8, 0.7, 0.68), Vector3(1, 1, 0.3))
			_bx(b, Vector3(0, 0.2, 0.55), Vector3(0.04, 0.04, 0.6), Color(0.55, 0.5, 0.45), Vector3(15, 0, 0))
			_bx(b, Vector3(0, 0.6, 0.05), Vector3(0.2, 0.05, 0.04), Color(0.5, 0.48, 0.45))
			_bx(b, Vector3(0, 0.5, 0.05), Vector3(0.04, 0.2, 0.04), Color(0.5, 0.48, 0.45))


func _bx(parent: Node, pos: Vector3, size: Vector3, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var o := {"solid": false, "tint": col}
	if rot != Vector3.ZERO:
		o["rotation"] = rot
	Kit.box(parent, pos, size, "", o)


func _sphere(parent: Node, pos: Vector3, r: float, col: Color, sc: Vector3 = Vector3.ONE) -> void:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 5
	var mi := Kit.add_mesh(parent, sm, Kit.flat(col), pos, {"solid": false})
	mi.scale = sc


# --- conversations -----------------------------------------------------------------------

func _barkeep_talk(_p: Node, _npc: Node) -> bool:
	if World.hud == null:
		return false
	if Game.active_is("crown"):
		await World.hud.say("The Barkeep", ["\"Your Majesty.\"", "He pours an ale without being asked and does not mention paying. He does not mention anything.", "It is warm."])
		Game.bump("free_ales")
		return true
	if Game.active_is("knife"):
		await World.hud.say("The Barkeep", ["\"Put that away.\"", "He does not move. He does not need to. The room does it for him."])
		return true
	var i: int = await World.hud.ask("The Barkeep", "What'll it be?", ["Ale", "A riddle", "A trade", "A room", "A rumour"])
	match i:
		0:
			await World.hud.say("The Barkeep", ["\"It's warm. Everything here is warm. That's the point.\"", "You drink it. It is."])
			Game.bump("ales")
		1:
			await _riddle()
		2:
			await _trade()
		3:
			await _room()
		4:
			await _rumour()
	return true


## What the room is saying. He listens to everyone and repeats the one thing
## that would help, sideways, and never says where he heard it.
func _rumour() -> void:
	Game.bump("rumours")
	var lines: Array = []
	var roses := Game.count("roses_placed")
	if Game.has_flag("roses_all_placed"):
		lines = ["\"Three paper flowers in a glass, by a bed that isn't in any house. He hears them, they say. Nobody's said yet what he'll do about it.\"", "He wipes a glass that was already dry.", "\"That's not a rumour. That's the end of the rumours. Come back when there's more.\""]
	elif Game.has_flag("visited_kings_mind"):
		var where: Array = []
		if not Game.has_flag("picked_rose_castle"):
			where.append("\"One's in a keep, where the books are kept behind the chair nobody sits in.\"")
		if not Game.has_flag("picked_rose_tavern"):
			where.append("\"One's under this floor. You'd have to be a good deal smaller than you are to fetch it.\"")
		if not Game.has_flag("picked_rose_maze"):
			where.append("\"One's in a hedge that spells a word, in a garden that's asleep. You'd want wings to see the word.\"")
		lines = ["\"Paper flowers. Three of them, folded from the same book. A glass by a bed is waiting for all three.\""]
		if where.is_empty():
			lines.append("\"You've got them all, I hear. So it's only the walk back up.\"")
		else:
			lines.append_array(where)
		lines.append("\"Paper keeps, so long as it's dry. %d in the glass so far, they say.\"" % roses)
	elif Game.has_flag("beanstalk_grown"):
		lines = ["\"Something on top of a tower in a garden has grown taller than the tower, and the tower's in a dream.\"", "\"Things that grow that fast are asking to be climbed. Take anything paper you've got. There's a glass up there with nothing in it.\""]
	elif Game.has_item("bonemeal"):
		lines = ["\"Old bone makes a garden grow. Everyone knows that. What they don't say is which garden.\"", "\"There's a tower in the King's sleep with a sprout on top of it that's never been fed. That's the rumour. Don't quote me.\""]
	elif Game.has_item("bones"):
		lines = ["\"Bone that light wants breaking, and there's only one anvil I know of that would take it.\"", "\"Down in the forge. Mind the giant.\""]
	elif Game.has_item("candle_stub"):
		var have := Game.item_count("candle_stub")
		lines = ["\"Candles that burn at both ends. There are four of them, they say, and they were all one candle once.\"", "\"Under the drowned city, past the four names, there's a plinth with a ring of wax on it. It wants all four. Light the names first or the gate won't have you.\""]
		if have < 4:
			var where: Array = []
			if not Game.has_flag("picked_crypt_candle"):
				where.append("one on the plinth itself")
			if not Game.has_flag("furnace_maiden_opened"):
				where.append("one in the forge, in the thing with the spikes")
			if not Game.has_flag("picked_candle_castle"):
				where.append("one in a chest in a keep")
			if not Game.has_flag("picked_candle_house"):
				where.append("one in a wall in a house, if you were small enough")
			if not where.is_empty():
				lines.append("\"You've %d. The rest: %s.\"" % [have, ", ".join(where)])
	elif Game.has_flag("visited_kings_dream"):
		lines = ["\"Under the hill, in the forge, there's an iron maiden with nobody in it.\"", "\"Open it anyway. The last one who did came out with a candle and a look on his face.\""]
	elif Game.has_keepsake("wings") and Game.has_keepsake("hourglass"):
		if Game.has_flag("king_disturbed") and Game.has_flag("tapestry_cut"):
			lines = ["\"The king in the keep's been woken and doesn't like it. They say if you ask him again, holding the right things, he'll take you where he goes.\""]
		elif Game.has_flag("king_disturbed"):
			lines = ["\"The king in the keep's awake, more or less. There's something hanging behind him that he can't see past. Somebody with a blade could fix that.\""]
		else:
			lines = ["\"There's a king asleep in a keep who's dreaming about somebody. Nobody's dared wake him. Somebody should.\""]
	elif Game.has_keepsake("wings") or Game.has_keepsake("hourglass"):
		lines = ["\"To get into somebody's sleep you'd want to fly, and you'd want to stop the clocks. One without the other's no use.\""]
	else:
		lines = ["\"Nine things, nine places. Hold one of them and the doors know you.\"", "He does not say which doors. He may not know."]
	await World.hud.say("The Barkeep", lines)


func _riddle() -> void:
	if Game.has_flag("riddle_solved"):
		await World.hud.say("The Barkeep", ["\"You already know the answer. You're standing in it, more or less.\""])
		return
	var a: int = await World.hud.ask("The Barkeep", "\"I have doors but no house, a well but no water, and everyone waits in me. What am I?\"", ["A hallway", "The Anteroom", "A grave", "A dream"])
	if a == 1:
		Game.set_flag("riddle_solved", true)
		await World.hud.say("The Barkeep", [
			"He nods, once, as if you have confirmed a suspicion.",
			"He puts a coin on the bar. It has a wave on both sides.",
			"\"That's the last one. Spend it on something that isn't here.\"",
		])
		Audio.sfx("riddle_correct", null, -4.0)
		Game.gain_item("coin")
		Game.note("tavern_riddle", "The barkeep's riddle", "Doors, a dry well, everyone waiting. The Anteroom. He paid you a coin for saying it out loud.")
		return
	var dry: Array = [
		"\"A hallway. Hm. A hallway comes with a house. Come back when you've thought about it.\"",
		"",
		"\"A grave. Only if you're unlucky. You're not, yet.\"",
		"\"A dream. Everything's a dream. That's not an answer, it's an excuse.\"",
	]
	var line: String = String(dry[a]) if a >= 0 and a < dry.size() else String(dry[3])
	await World.hud.say("The Barkeep", [line])
	Game.bump("riddle_wrong")


func _trade() -> void:
	if Game.has_keepsake("umbrella"):
		await World.hud.say("The Barkeep", ["\"We've traded. The umbrella's yours. Don't open it in here.\"", "He looks at the ceiling as if it has let him down before."])
		return
	if Game.has_item("moonlight"):
		Game.take_item("moonlight")
		await World.hud.say("The Barkeep", [
			"He takes the bottle in both hands and holds it up to the lamp. The lamp gets dimmer. The bottle does not.",
			"\"That'll do,\" he says, and it is the warmest thing he has said.",
			"From under the bar he brings out a black umbrella, furled, dry, and puts it in your hands.",
			"\"Don't open it in here.\"",
		])
		Game.gain_keepsake("umbrella")
		Audio.sfx("riddle_correct", null, -4.0)
		Game.note("moonlight_trade", "The trade", "A bottle of moonlight for a black umbrella. He held the bottle up to the lamp and the lamp lost.")
		return
	await World.hud.say("The Barkeep", ["\"Bring me moonlight in a bottle and we'll talk. There's a tree that catches it, if you can get high enough.\""])


func _room() -> void:
	if Game.has_flag("tavern_room"):
		await World.hud.say("The Barkeep", ["\"It's yours. Top of the stairs.\""])
		return
	if Game.has_item("coin"):
		await World.hud.say("The Barkeep", [
			"You show him the coin. He looks at it for a long time. He does not take it.",
			"\"The room upstairs. It's been taken for years. Tonight it isn't.\"",
			"Behind you, very quietly, a rope is unhooked.",
		])
		Game.set_flag("tavern_room", true)
		if rope != null and is_instance_valid(rope):
			rope.queue_free()
			rope = null
		Audio.sfx("creak", Vector3(8.0, 1.0, 7.5), -6.0)
		Game.note("tavern_room", "The rented room", "The barkeep let you the room at the top of the stairs. He looked at the coin and did not take it. The bed, he implied, goes somewhere.")
		return
	await World.hud.say("The Barkeep", ["\"The room upstairs is taken. It has been taken for years.\""])


func _stop_bard(silent: bool) -> void:
	Game.set_flag("bard_stopped", true)
	if bard != null and is_instance_valid(bard):
		bard.lines = ["The bard is not playing. His hands are in the shape of playing, and stay there.", "\"It'll come back,\" he says. \"It always has. That's the trouble with it.\""]
		bard.reactions = {}
	if bard_sign != null and is_instance_valid(bard_sign):
		bard_sign.lines = ["Chalked on the front of the stage: TONIGHT — THE SONG", "The 'cont.' has been rubbed out. The groove it left is still there."]
	if not silent:
		Audio.sfx("whisper", Vector3(-4.4, 1.0, 6.6), -6.0)
		Game.toast.emit("The bard stops. The silence is, somehow, the same song.")
		Game.note("bard_stopped", "The song that ended", "You rang the bell in the Last Lamp and the bard stopped playing. Nobody had heard the room without the song. It sounded like waiting.")


# --- hooks ----------------------------------------------------------------------------------

func on_bell(_origin: Vector3) -> void:
	if not Game.has_flag("bard_stopped"):
		_stop_bard(false)


func on_umbrella(open: bool) -> void:
	if rain != null:
		rain.emitting = open
	if open:
		Audio.sfx("rain", Vector3(1.0, 3.0, 3.0), -10.0)
		Game.toast.emit("It begins to rain, indoors, politely.")
		Game.note("rain_indoors", "Rain in the taproom", "You opened the umbrella in the Last Lamp and it rained on the tables. The patrons did not move. The fire did not go out. Everything stayed warm.")


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if spawn_id == "from_sea":
		Game.note("woke_at_inn", "Waking at the inn", "You lay down on the Slow Sea and woke in the rented room. The sheets are damp. The window still shows the sea, a little closer.")
	if n == 1:
		Game.note("last_lamp", "The Last Lamp", "A tavern at the end of every road. The barkeep has no face and a very good apron. The bard is playing a song with no end. It is warm. That is the point.")


func _process(delta: float) -> void:
	_t += delta
	if fire_light != null:
		fire_light.light_energy = 2.0 + 0.35 * sin(_t * 9.0) + 0.25 * sin(_t * 23.0 + 1.3)
	for f in flames:
		var n := f as Node3D
		if n != null:
			n.scale = Vector3(1.0 + 0.06 * sin(_t * 11.0), 1.0 + 0.12 * sin(_t * 7.0 + 0.5), 1.0 + 0.06 * cos(_t * 9.0))
