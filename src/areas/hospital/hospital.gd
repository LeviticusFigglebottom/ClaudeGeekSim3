extends AreaBase
## St. Nowhere — the hospital above the Other Anteroom. Green paint to
## shoulder height and white above, fluorescent tubes that hum, and too many
## corridors. Two floors: a lobby with a visitors' book, four wards, a chapel,
## a nurses' station, a pharmacy, a stair; below the back corridor a morgue, a
## theatre, an x-ray room, a children's ward, a laundry; upstairs two more
## wards and a records room, and a corridor that comes down without a stair.
## Six memories are hidden in it. Each one found puts the tall one nearer, and
## the lights lower, and with all six the far door at the end of the spine is
## a door, and past it, round twice, room 5½: the bed, and the one in it, half
## under the sheet and half in the coat. Lying down is waking up.
##
## Built as two rasterised maps (1 m cells). Holding R wakes you.

const CELL := 1.0
const H := 3.0
const ORIGIN := Vector3(-50.0, 0.0, -40.0)
const UP := 3.2
const W := 100
const D := 80
const GREEN := "wall/plaster_green"
const TILE := "wall/tile_white"
const CHECK := "wall/tile_checker"
const LOOPS_NEEDED := 2
const MEMORIES := 6

var far_open := false
var loop_seam: SeamlessTeleport = null
var floor_seam: SeamlessTeleport = null
var _flicker: Array = []
var _reds: Array = []
var _t := 0.0
var _scaring := false
var _dark := false


func build() -> void:
	can_wake = true
	far_open = Game.has_flag("memories_all")
	Realm.apply(self, "hospital", {"fog_density": 0.04 + 0.008 * mini(Game.count("memories"), 6)})
	_plan()
	_upper_plan()
	_lobby()
	_corridors()
	_wards()
	_chapel()
	_station()
	_pharmacy()
	_stair()
	_theatre()
	_morgue()
	_xray()
	_children()
	_laundry()
	_upstairs()
	if far_open:
		_far_corridor()
		_room()
	_memories()
	_presences()
	add_spawn("from_mirror", _c(50.0, 4.0, 0.1), 180.0)
	add_spawn("default", _c(50.0, 4.0, 0.1), 180.0)
	add_spawn("far", _c(50.0, 40.0, 0.1), 180.0)
	Puzzle.declare(self, "hospital_book", "hospital_book_read", [], "sign the visitors' book at the desk in the lobby")
	Puzzle.declare(self, "hospital_memories", "memories_all", [], "find the six memories hidden about the hospital, upstairs and down")
	if _dark_now():
		_go_dark(true)


# --- coordinates: plan metres -> world ------------------------------------------------------

func _c(x: float, z: float, y: float = 0.0) -> Vector3:
	return Vector3(ORIGIN.x + x, y, ORIGIN.z + z)


func _fluor(x: float, z: float, y: float = 0.0, energy: float = 0.9, reach: float = 8.0) -> void:
	Props.place(self, "fluorescent_light", _c(x, z, y + H - 0.02), 0.0, 1.0, {"collision": "none"})
	var l := Kit.light(self, _c(x, z, y + H - 0.35), Color(0.95, 1.0, 0.92), energy, reach)
	_flicker.append(l)
	if hash(Vector2i(int(x), int(z))) % 2 == 0:
		var r := Kit.light(self, _c(x, z, y + H - 0.5), Color(1.0, 0.25, 0.2), 0.0, 7.0)
		_reds.append(r)


func _dark_now() -> bool:
	return Game.count("memories") >= 4


# --- the plans ---------------------------------------------------------------------------------

func _plan() -> void:
	var rects := [
		[40, 2, 60, 14, "l"],      # the lobby
		[88, 2, 92, 14, "t"],      # the stair
		[2, 15, 98, 18, "c"],      # the main corridor
		[4, 19, 24, 31, "a"],      # ward A
		[28, 19, 48, 31, "b"],     # ward B
		[49, 19, 52, 43, "s"],     # the spine
		[53, 19, 63, 31, "k"],     # the chapel
		[67, 19, 79, 26, "n"],     # the nurses' station
		[83, 19, 97, 26, "p"],     # the pharmacy
		[2, 44, 98, 47, "w"],      # the back corridor
		[4, 48, 18, 60, "g"],      # the morgue
		[22, 48, 36, 60, "o"],     # the theatre
		[40, 48, 46, 56, "x"],     # x-ray
		[49, 48, 52, 60, "s"],     # the spine, continued
		[56, 48, 76, 60, "y"],     # the children's ward
		[80, 48, 96, 56, "z"],     # the laundry
		[48, 61, 98, 64, "f"],     # the far corridor
		[86, 65, 98, 75, "r"],     # room 5½
	]
	var doors := [
		[50, 14, "D"], [90, 14, "D"],
		[14, 18, "D"], [38, 18, "D"], [50, 18, "D"], [57, 18, "D"], [72, 18, "D"], [89, 18, "D"],
		[50, 43, "D"],
		[10, 47, "D"], [28, 47, "D"], [43, 47, "D"], [50, 47, "D"], [66, 47, "D"], [88, 47, "D"],
	]
	if far_open:
		doors.append([50, 60, "D"])
		doors.append([92, 64, "D"])
	var rows := MapBuilder.rasterize(W, D, rects, doors)
	var rooms := {
		"l": {"floor": CHECK, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"t": {"floor": "wall/concrete", "wall": "wall/plaster_cream", "ceiling": "wall/plaster_white"},
		"c": {"floor": TILE, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"a": {"floor": TILE, "wall": TILE, "ceiling": "wall/ceiling_tile"},
		"b": {"floor": TILE, "wall": TILE, "ceiling": "wall/ceiling_tile"},
		"s": {"floor": TILE, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"k": {"floor": "wood/planks_dark", "wall": "wall/plaster_cream", "ceiling": "wall/plaster_white"},
		"n": {"floor": CHECK, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"p": {"floor": CHECK, "wall": TILE, "ceiling": "wall/ceiling_tile"},
		"w": {"floor": TILE, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"g": {"floor": "wall/concrete", "wall": TILE, "ceiling": "wall/concrete_dark"},
		"o": {"floor": TILE, "wall": TILE, "ceiling": "wall/plaster_white"},
		"x": {"floor": "wall/concrete", "wall": "wall/plaster_cream", "ceiling": "wall/concrete_dark"},
		"y": {"floor": "wall/carpet_house", "wall": "wall/wallpaper_floral", "ceiling": "wall/ceiling_tile"},
		"z": {"floor": CHECK, "wall": TILE, "ceiling": "wall/plaster_white"},
		"f": {"floor": TILE, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"r": {"floor": TILE, "wall": TILE, "ceiling": "wall/ceiling_tile"},
	}
	MapBuilder.build(self, rows, {
		"cell": CELL, "height": H, "origin": ORIGIN, "door_h": 2.2, "tile": 2.0,
		"floor": TILE, "wall": GREEN, "ceiling": "wall/ceiling_tile",
		"no_ceiling": "t",
		"rooms": rooms, "outer_faces": true, "name": "Hospital",
	})


## Upstairs: the same corridor, two more wards, the records room, a corridor
## that ends in a wall with the room number on it, and the hole the stair
## comes up through.
func _upper_plan() -> void:
	var rects := [
		[2, 15, 98, 18, "c"],
		[4, 19, 24, 31, "a"],
		[28, 19, 48, 31, "b"],
		[49, 19, 52, 43, "s"],
		[53, 19, 63, 31, "q"],
		[67, 19, 79, 26, "v"],
	]
	var doors := [
		[90, 14, "D"],
		[14, 18, "D"], [38, 18, "D"], [50, 18, "D"], [57, 18, "D"], [72, 18, "D"],
	]
	var rows := MapBuilder.rasterize(W, 48, rects, doors)
	# the stair comes up through a hole: the stair room's footprint is nothing up here
	for z in range(2, 14):
		var row: String = rows[z]
		rows[z] = row.substr(0, 88) + "    " + row.substr(92)
	var rooms := {
		"c": {"floor": TILE, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"a": {"floor": TILE, "wall": TILE, "ceiling": "wall/ceiling_tile"},
		"b": {"floor": TILE, "wall": TILE, "ceiling": "wall/ceiling_tile"},
		"s": {"floor": TILE, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"q": {"floor": "wall/carpet_office", "wall": "wall/plaster_cream", "ceiling": "wall/ceiling_tile"},
		"v": {"floor": "wall/concrete", "wall": "wall/concrete", "ceiling": "wall/concrete_dark"},
	}
	MapBuilder.build(self, rows, {
		"cell": CELL, "height": H, "origin": ORIGIN, "y": UP, "door_h": 2.2, "tile": 2.0,
		"floor": TILE, "wall": GREEN, "ceiling": "wall/ceiling_tile", "open_edges": true,
		"rooms": rooms, "outer_faces": true, "name": "HospitalUpstairs",
	})


# --- the lobby -------------------------------------------------------------------------------

func _lobby() -> void:
	Door.create(self, _c(50.0, 2.4), 0.0, "mirror_nexus", "top", {"kind": "dark", "label": "The way you came up", "name": "Door_down", "fade_color": Color(0.65, 0.95, 0.93), "fade_duration": 1.0})
	Kit.sign(self, "signs/hospital_name", _c(50.0, 2.02, 2.5), 180.0, Vector2(2.4, 0.6))
	Props.place(self, "desk_office", _c(44.0, 6.0), 90.0, 1.1)
	Props.place(self, "chair_office", _c(42.8, 6.0), -90.0, 1.0)
	Props.place(self, "phone_office", _c(44.0, 5.2, 0.8), 90.0, 1.0, {"collision": "none"})
	Kit.box(self, _c(44.1, 6.5, 0.88), Vector3(0.42, 0.05, 0.3), "signs/book_cover", {"solid": false})
	Interactable.make(self, _c(44.1, 6.5, 0.9), Vector3(0.8, 0.6, 0.8), "The visitors' book", _on_book, {"name": "VisitorsBook"})
	Props.place(self, "waiting_chairs", _c(56.5, 4.0), 90.0, 1.0)
	Props.place(self, "waiting_chairs", _c(56.5, 8.5), 90.0, 1.0)
	Props.place(self, "waiting_chairs", _c(56.5, 12.0), 90.0, 1.0)
	Props.place(self, "potted_plant_fake", _c(58.5, 2.8), 0.0, 1.0, {"collision": "cylinder"})
	Props.place(self, "ticket_dispenser", _c(41.0, 12.5), 90.0, 1.0, {"collision": "cylinder"})
	Props.place(self, "number_display", _c(50.0, 13.9, 2.6), 0.0, 1.0, {"collision": "none"})
	Kit.box(self, _c(59.85, 6.5, 1.25), Vector3(0.3, 2.5, 2.2), "metal/plate", {"tint": Color(0.7, 0.72, 0.7)})
	Kit.box(self, _c(59.67, 6.5, 1.25), Vector3(0.02, 2.3, 0.04), "metal/iron", {"solid": false, "tint": Color(0.2, 0.2, 0.2)})
	Kit.box(self, _c(59.7, 5.0, 1.1), Vector3(0.04, 0.12, 0.12), "metal/brass", {"solid": false})
	Interactable.make(self, _c(59.4, 5.0, 1.1), Vector3(0.6, 0.6, 0.6), "Call the lift", _on_lift, {"name": "Lift"})
	Kit.label(self, "LIFT", _c(59.75, 6.5, 2.7), 90.0, 22, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	Kit.sign(self, "signs/ward_hours", _c(46.0, 2.02, 2.2), 180.0, Vector2(1.4, 0.5))
	for p in [[44.0, 4.0], [44.0, 10.0], [55.0, 4.0], [55.0, 10.0]]:
		_fluor(float(p[0]), float(p[1]))
	Readable.create(self, _c(50.0, 8.0, 1.4), 0.0, "Look round the lobby", [
		"A lobby with a desk and a book and chairs bolted to the floor. Green paint to shoulder height, white above, a line between where a hand could reach.",
		"There is a smell of soap over the top of another smell. The number over the door to the wards says 5½. It has said it for some time.",
	], {"name": "LobbyLook", "size": Vector3(4.0, 2.0, 4.0), "note_key": "hospital", "note_title": "St. Nowhere", "note_text": "Above the Other Anteroom, up the platforms, a hospital: green paint to shoulder height, a lobby with a visitors' book, wards on two floors, a chapel, a morgue, and too many corridors. Six memories are hidden in it, and the far door will not open until they are found."})


func _on_book(_p: Node, _it: Node) -> void:
	if World.hud == null:
		return
	if Game.has_flag("hospital_book_read"):
		await World.hud.say("", ["The book, open at today. Your one letter at the bottom of the page, in your hand.", "Above it, the same letter, every day, for longer than the book should hold."])
		return
	await World.hud.say("", [
		"A visitors' book, open. Every line is the same: a date, a time in the afternoon, a room number, and one letter. The dates go back further than the book has pages.",
		"The room number is 5½. The letter is M. The hand is yours.",
		"There is a pen on a chain. The line for today is empty.",
	])
	var i: int = await World.hud.ask("", "Sign the book?", ["Not yet.", "Sign it: M."])
	if i != 1:
		return
	Audio.sfx("write", global_position, -6.0)
	Game.set_flag("hospital_book_read", true)
	Game.note("hospital_book", "The visitors' book", "The visitors' book in the hospital lobby: every day, in the afternoon, room 5½, one letter, M, in your hand. You signed today's line.")
	Game.toast.emit("You sign. The pen knows the letter before you do.")


func _on_lift(_p: Node, _it: Node) -> void:
	Audio.sfx("ui_blip", global_position, -10.0)
	Game.bump("hospital_lift")
	if World.hud:
		await World.hud.say("", ["The button lights. Somewhere above, a long way above, a cable takes the strain.", "The lift is coming. It has been coming since before you pressed the button. It is a very tall building."])


# --- corridors -------------------------------------------------------------------------------

func _corridors() -> void:
	for x in range(6, 98, 8):
		_fluor(float(x), 16.5)
		_fluor(float(x), 45.5)
	for z in range(22, 42, 8):
		_fluor(50.5, float(z))
	for z in [50.0, 56.0]:
		_fluor(50.5, z)
	Kit.sign(self, "signs/ward_a", _c(14.0, 17.98, 2.5), 0.0, Vector2(1.0, 0.5))
	Kit.sign(self, "signs/ward_b", _c(38.0, 17.98, 2.5), 0.0, Vector2(1.0, 0.5))
	Kit.sign(self, "signs/ward_quiet", _c(57.0, 17.98, 2.5), 0.0, Vector2(1.0, 0.5))
	Kit.label(self, "NURSES", _c(72.0, 17.98, 2.5), 0.0, 22, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	Kit.label(self, "PHARMACY", _c(89.0, 17.98, 2.5), 0.0, 22, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	Kit.label(self, "STAIRS", _c(90.0, 15.02, 2.5), 180.0, 22, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	Kit.label(self, "WARDS →", _c(50.5, 17.98, 2.5), 0.0, 22, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	Kit.label(self, "← WARDS", _c(50.5, 44.02, 2.5), 180.0, 22, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	# the far door's sign, on the spine's south wall
	Kit.sign(self, "signs/ward_visiting" if not far_open else "signs/ward_hours", _c(50.5, 59.98, 2.5), 0.0, Vector2(1.6, 0.6))
	if not far_open:
		Readable.create(self, _c(50.5, 59.4, 1.4), 0.0, "A door that is a wall", [
			"Where a door should be, a wall, and over the wall a sign: VISITING HOURS ARE OVER.",
			"Under the paint, the shape of a door. Behind it, breathing, once for every four of your breaths. It is not opening for you as you are: there are things you have not remembered.",
		], {"name": "FarWall", "size": Vector3(2.0, 2.0, 1.0)})
	Props.place(self, "bed_iron", _c(30.0, 16.5), 90.0, 0.9, {"tint": Color(0.85, 0.85, 0.85)})
	Props.place(self, "bed_iron", _c(70.0, 45.5), 90.0, 0.9, {"tint": Color(0.85, 0.85, 0.85)})
	Props.place(self, "crate_small", _c(20.0, 45.6), 20.0, 0.7)
	for x in range(8, 96, 12):
		Kit.water(self, _c(float(x), 45.5, 0.02), Vector2(6.0, 2.8), "nature/water_cistern", {"tint": Color(0.7, 0.75, 0.7, 0.45), "subdiv": 2})
	Readable.create(self, _c(50.0, 16.5, 1.4), 0.0, "The corridor", [
		"A corridor with a line down the middle of the floor, and doors off it, and a hum. The hum is the lights, or it is the building thinking.",
		"You have walked this corridor. Not this one: the one it is a copy of. You had a bunch of paper roses in your hand and you were counting doors.",
	], {"name": "CorridorLook", "size": Vector3(6.0, 2.0, 2.6)})
	Readable.create(self, _c(30.0, 45.5, 1.0), 0.0, "Water on the floor", ["Water on the floor of the back corridor, a finger deep, going the same way as the corridor.", "It is coming from under the door at the far end of the spine, which is the door that is not there."], {"name": "FloorWater", "size": Vector3(4.0, 1.0, 2.6)})


# --- the wards -------------------------------------------------------------------------------

func _ward(x0: float, x1: float, z0: float, letter: String, y: float = 0.0, occupied_every: int = 5) -> void:
	var n := 0
	for k in 6:
		var x := x0 + 2.0 + k * ((x1 - x0 - 4.0) / 5.0)
		for side in [0, 1]:
			var z := z0 + 2.2 if side == 0 else z0 + 8.8
			var yaw := 0.0 if side == 0 else 180.0
			n += 1
			Props.place(self, "bed_iron", _c(x, z, y), yaw, 1.0)
			if (hash(Vector2i(int(x), side)) + Game.count("memories") * 7) % occupied_every < 1 + Game.count("memories") / 2:
				Kit.box(self, _c(x, z + (0.2 if side == 0 else -0.2), y + 0.78), Vector3(0.44, 0.22, 1.5), "fabric/sheet", {"solid": false, "tint": Color(0.9, 0.9, 0.88)})
			if k % 2 == 0:
				Kit.cylinder(self, _c(x + 0.7, z + (1.0 if side == 0 else -1.0), y), 0.03, 1.9, "metal/brass", {"segments": 6})
			if (hash(Vector2i(int(x) * 3, side)) % 3) == 0:
				Kit.box(self, _c(x + 0.95, z, y + 1.3), Vector3(0.04, 2.2, 2.6), "fabric/sheet", {"tint": Color(0.75, 0.85, 0.8), "tile": 1.5})
	for k in 3:
		_fluor(x0 + 3.0 + k * ((x1 - x0 - 6.0) / 2.0), z0 + 5.5, y)
	Kit.label(self, "WARD " + letter, _c((x0 + x1) * 0.5, z0 + 0.02, y + 2.5), 180.0, 26, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})


func _wards() -> void:
	_ward(4.0, 24.0, 19.0, "A")
	_ward(28.0, 48.0, 19.0, "B")
	Props.place(self, "water_cooler", _c(23.0, 25.0), -90.0, 1.0)
	Props.place(self, "filing_cabinet", _c(47.0, 25.0), -90.0, 1.0)
	Readable.create(self, _c(14.0, 24.0, 0.9), 0.0, "A bed in ward A", [
		"An iron bed, made with hospital corners, a chart on a clip at the foot with nothing on it but a line going down.",
		"You have lain in one of these. You are not sure it was not this one.",
	], {"name": "BedA", "size": Vector3(1.4, 1.2, 1.2)})


func _chapel() -> void:
	for k in 4:
		Props.place(self, "bench", _c(55.5, 21.5 + k * 2.0), 90.0, 0.8, {"tint": Color(0.7, 0.6, 0.5)})
		Props.place(self, "bench", _c(60.5, 21.5 + k * 2.0), 90.0, 0.8, {"tint": Color(0.7, 0.6, 0.5)})
	Props.place(self, "lectern", _c(58.0, 30.0), 0.0, 1.0)
	Props.place(self, "candle_cluster", _c(56.0, 30.2), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "candle_cluster", _c(60.0, 30.2), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, _c(58.0, 29.5, 1.6), Color(1.0, 0.85, 0.6), 1.0, 7.0)
	Kit.sign(self, "props/window_night", _c(58.0, 30.9, 1.8), 0.0, Vector2(1.4, 1.8))
	Readable.create(self, _c(58.0, 28.4, 1.2), 0.0, "The chapel", [
		"Eight benches and a lectern and a window that shows night, which is the only thing it has ever shown. A book on the lectern, open at nothing.",
		"Somebody has sat in the back row a long time. The bench remembers the shape. It is the shape from the chair by the bed.",
	], {"name": "ChapelLook", "size": Vector3(3.0, 2.0, 2.0), "note_key": "hospital_chapel", "note_title": "The chapel", "note_text": "A chapel in the hospital with a window that shows night. Somebody has sat in the back row long enough to leave a shape, and it is the shape from the chair by the King's bed."})
	# look away from the back row and somebody is sitting in it
	LookAway.create(self, _c(55.5, 21.5, 1.0), func(_l: Node) -> void:
		_scare_now(), {"delay": 2.0, "radius": 12.0, "once": true, "require_seen_first": true, "name": "BackRow"})


func _station() -> void:
	Props.place(self, "desk_office", _c(70.0, 22.0), 0.0, 1.0)
	Props.place(self, "desk_office", _c(73.5, 22.0), 0.0, 1.0)
	Props.place(self, "chair_office", _c(70.0, 20.6), 180.0, 1.0)
	Props.place(self, "phone_office", _c(73.5, 22.0, 0.76), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "filing_cabinet", _c(78.2, 20.5), -90.0, 1.0)
	Props.place(self, "filing_cabinet", _c(78.2, 22.0), -90.0, 1.0)
	Kit.sign(self, "metal/clock_face", _c(72.0, 19.02, 2.3), 180.0, Vector2(0.9, 0.9))
	_fluor(72.0, 22.5)
	Readable.create(self, _c(72.0, 23.5, 1.0), 0.0, "The nurses' station", [
		"Two desks, a phone that does not ring, a clock that says half past five. A chart pinned to the wall: one name, one room, and under ROOM, 5½.",
		"Under VISITOR, one letter, over and over, down the page and off the bottom.",
	], {"name": "StationLook", "size": Vector3(4.0, 1.4, 2.0)})


func _pharmacy() -> void:
	for k in 3:
		Props.place(self, "bookshelf_white", _c(85.0 + k * 4.0, 25.5), 0.0, 1.0)
	Kit.box(self, _c(90.0, 21.5, 0.5), Vector3(5.0, 1.0, 0.8), "wall/tile_white", {"tile": 1.0})
	for k in 8:
		Props.place(self, "bottle", _c(88.0 + k * 0.55, 21.5, 1.0), k * 40.0, 0.8, {"collision": "none", "tint": Color(0.8, 0.9, 0.8)})
	_fluor(90.0, 22.5)
	Readable.create(self, _c(90.0, 22.5, 1.2), 0.0, "The pharmacy", [
		"Shelves of bottles with the labels turned to the wall, and a counter, and a bell on the counter you do not ring.",
		"One bottle is turned the right way. The label says the dose, and under the dose: FOR THE VISITOR.",
	], {"name": "PharmacyLook", "size": Vector3(4.0, 1.6, 2.0)})


## The stair: two flights round a stairwell, up through the hole to the
## corridor above, and a landing over the lower flight's foot.
func _stair() -> void:
	Kit.stairs(self, _c(88.85, 13.5), 0.0, 1.5, 10, 0.16, 0.4, "wall/concrete", {"name": "StairUpA", "tile": 1.0})
	Kit.floor(self, _c(90.0, 7.0, 1.6), Vector2(4.0, 5.0), "wall/concrete", {"tile": 1.0})
	Kit.stairs(self, _c(91.15, 5.5), 180.0, 1.5, 15, 0.1067, 0.4, "wall/concrete", {"name": "StairUpB", "tile": 1.0})
	Kit.floor(self, _c(90.0, 12.75, UP), Vector2(4.0, 2.5), "wall/concrete", {"tile": 1.0})
	Kit.box(self, _c(89.6, 9.5, 1.0), Vector3(0.06, 2.0, 5.0), "metal/iron", {"solid": true, "tint": Color(0.3, 0.3, 0.32)})
	Kit.light(self, _c(90.0, 10.0, 2.4), Color(0.95, 1.0, 0.92), 0.9, 8.0)
	Kit.light(self, _c(90.0, 6.0, 5.4), Color(0.95, 1.0, 0.92), 0.9, 8.0)
	Kit.sign(self, "signs/exit_wrong", _c(90.0, 2.4, 2.02), 180.0, Vector2(0.8, 0.4))


# --- the back rooms ----------------------------------------------------------------------------

func _theatre() -> void:
	Kit.box(self, _c(29.0, 54.0, 0.45), Vector3(0.8, 0.9, 2.2), "metal/plate", {"tint": Color(0.8, 0.82, 0.8)})
	Props.place(self, "chandelier", _c(29.0, 54.0, 2.4), 0.0, 0.6, {"collision": "none"})
	Kit.light(self, _c(29.0, 54.0, 2.2), Color(1.0, 1.0, 0.95), 1.4, 7.0)
	for k in 3:
		Props.place(self, "crate_small", _c(24.0 + k * 1.2, 58.5), 0.0, 0.6, {"tint": Color(0.7, 0.72, 0.7)})
	Props.place(self, "sink", _c(34.5, 49.5), 90.0, 1.0)
	Kit.water(self, _c(29.0, 54.0, 0.02), Vector2(5.0, 5.0), "nature/water_cistern", {"tint": Color(0.7, 0.75, 0.7, 0.5), "subdiv": 2})
	Readable.create(self, _c(29.0, 55.6, 1.2), 0.0, "The theatre", [
		"A table under a lamp, and the lamp on, and nothing on the table. Trays of nothing. A sink with the tap dripping.",
		"Whatever was done here was done, and it did not take.",
	], {"name": "TheatreLook", "size": Vector3(2.4, 1.6, 2.0)})


func _morgue() -> void:
	for k in 5:
		for j in 2:
			Kit.box(self, _c(4.4, 50.0 + k * 1.2, 0.5 + j * 0.8), Vector3(0.6, 0.7, 1.0), "metal/plate", {"tint": Color(0.75, 0.78, 0.78)})
			Kit.box(self, _c(4.1, 50.0 + k * 1.2, 0.5 + j * 0.8), Vector3(0.04, 0.06, 0.3), "metal/iron", {"solid": false})
	Kit.box(self, _c(11.0, 55.0, 0.45), Vector3(0.8, 0.9, 2.2), "metal/plate", {"tint": Color(0.8, 0.82, 0.8)})
	Kit.box(self, _c(11.0, 55.0, 0.98), Vector3(0.7, 0.24, 1.9), "fabric/sheet", {"solid": false, "tint": Color(0.9, 0.9, 0.88)})
	Kit.light(self, _c(11.0, 55.0, 2.5), Color(0.7, 0.85, 0.9), 0.8, 8.0)
	Readable.create(self, _c(11.0, 56.4, 1.2), 0.0, "A sheet over a shape", [
		"A table, a sheet, a shape under the sheet the length of you. You do not lift it. You know what a hat looks like under a sheet.",
		"The drawers along the wall are labelled with one letter each, and it is the same letter.",
	], {"name": "MorgueLook", "size": Vector3(1.8, 1.6, 2.6), "note_key": "hospital_morgue", "note_title": "The morgue", "note_text": "The morgue in the hospital: a sheet over a shape the length of you, with a hat under it, and drawers all labelled with the same letter."})


func _xray() -> void:
	Kit.box(self, _c(43.0, 48.15, 1.5), Vector3(2.4, 1.6, 0.1), "", {"tint": Color(0.85, 0.95, 1.0), "solid": false})
	Kit.light(self, _c(43.0, 49.0, 1.5), Color(0.8, 0.95, 1.0), 1.2, 6.0)
	Kit.box(self, _c(43.0, 52.5, 0.4), Vector3(0.8, 0.8, 2.0), "metal/plate", {"tint": Color(0.7, 0.72, 0.72)})
	Readable.create(self, _c(43.0, 49.2, 1.4), 0.0, "The lightbox", [
		"A lightbox on the wall with one film clipped to it: a skull, from the side, with the shape of a hat still on it, which a skull does not have.",
		"Written across the film in wax pencil: NO CHANGE.",
	], {"name": "Lightbox", "size": Vector3(2.6, 1.6, 1.0), "note_key": "hospital_xray", "note_title": "No change", "note_text": "In the x-ray room of the hospital, one film on the lightbox: a skull with a hat on it. Written across it: no change."})


func _children() -> void:
	for k in 6:
		var x := 58.5 + k * 3.0
		Props.place(self, "bed_single", _c(x, 50.0), 0.0, 0.7, {"tint": Color(0.95, 0.9, 0.95)})
		Props.place(self, "bed_single", _c(x, 58.0), 180.0, 0.7, {"tint": Color(0.95, 0.9, 0.95)})
	for k in 4:
		Kit.sign(self, ["props/painting_house", "props/painting_landscape", "props/painting_door", "props/painting_house"][k], _c(59.0 + k * 4.5, 48.02, 1.8), 180.0, Vector2(0.7, 0.55))
	Props.place(self, "chess_pawn", _c(66.0, 54.0), 0.0, 0.6, {"collision": "none", "tint": Color(0.9, 0.9, 0.85)})
	Props.place(self, "chess_king", _c(66.6, 54.3), 0.0, 0.6, {"collision": "none", "tint": Color(0.85, 0.2, 0.25)})
	_fluor(62.0, 54.0)
	_fluor(70.0, 54.0)
	Readable.create(self, _c(66.0, 54.0, 1.0), 0.0, "The children's ward", [
		"Small beds, and drawings on the wall: a house, a road, a door with nobody in it. The same house every time.",
		"On the floor, two pieces from a set somebody was teaching somebody to play: a pawn, and the king it has cornered.",
	], {"name": "ChildrenLook", "size": Vector3(3.0, 1.6, 3.0)})


func _laundry() -> void:
	for k in 5:
		Kit.box(self, _c(82.0 + k * 3.2, 52.0, 1.4), Vector3(0.05, 2.0, 4.0), "fabric/sheet", {"tint": Color(0.92, 0.92, 0.9), "tile": 1.5})
	Kit.box(self, _c(88.0, 52.0, 2.5), Vector3(14.0, 0.05, 0.05), "metal/iron", {"solid": false})
	_fluor(88.0, 52.0)
	Readable.create(self, _c(84.0, 50.0, 1.2), 90.0, "The laundry", [
		"Sheets hanging in rows to the far wall, all the same white, all still. You walk between them and cannot see either end.",
		"One sheet has a shape behind it. You do not go round to see. It has your shoulders.",
	], {"name": "LaundryLook", "size": Vector3(2.0, 2.0, 3.0)})
	LookAway.create(self, _c(94.0, 52.0, 1.0), func(_l: Node) -> void:
		_scare_now(), {"delay": 1.5, "radius": 10.0, "once": true, "require_seen_first": true, "name": "SheetShape"})


# --- upstairs ----------------------------------------------------------------------------------

func _upstairs() -> void:
	for x in range(6, 90, 8):
		_fluor(float(x), 16.5, UP)
	_ward(4.0, 24.0, 19.0, "C", UP, 4)
	_ward(28.0, 48.0, 19.0, "D", UP, 4)
	for z in range(22, 42, 8):
		_fluor(50.5, float(z), UP)
	Kit.label(self, "5½", _c(50.5, 42.98, UP + 1.8), 0.0, 60, Color(0.25, 0.25, 0.25), "display", {"pixel_size": 0.012})
	Readable.create(self, _c(50.5, 42.0, UP + 1.4), 0.0, "The end of the corridor upstairs", [
		"The corridor ends, upstairs, where downstairs it goes on. Scratched into the paint of the end wall: 5½. Somebody counted floors and got it wrong.",
		"You can hear the corridor below through the floor. Somebody is walking along it at your pace.",
	], {"name": "UpperEnd", "size": Vector3(2.6, 2.0, 1.0)})
	# the records room
	for k in 4:
		Props.place(self, "filing_cabinet", _c(54.5 + k * 1.3, 20.0, UP), 0.0, 1.0)
		Props.place(self, "filing_cabinet", _c(54.5 + k * 1.3, 30.0, UP), 180.0, 1.0)
	Props.place(self, "desk_office", _c(58.0, 25.0, UP), 0.0, 1.0)
	Props.place(self, "lamp_desk", _c(58.4, 25.0, UP + 0.76), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, _c(58.0, 25.0, UP + 1.6), Color(1.0, 0.9, 0.7), 0.9, 6.0)
	Kit.label(self, "RECORDS", _c(57.0, 17.98, UP + 2.5), 0.0, 22, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	Readable.create(self, _c(58.0, 24.0, UP + 1.0), 0.0, "The records", [
		"Cabinets to the ceiling, every drawer labelled with the same room number. One drawer open: a file with your name on the tab, and inside it one sheet, and on the sheet one word: VISITED.",
		"Under it, in the same hand as the book downstairs, a date for every day.",
	], {"name": "RecordsLook", "size": Vector3(3.0, 1.4, 2.0), "note_key": "hospital_records", "note_title": "The records", "note_text": "Upstairs in the hospital, in the records room, a file with your name on the tab and one word inside: visited. A date for every day."})
	# the roof stair that goes nowhere
	Kit.stairs(self, _c(70.0, 25.0, UP), 0.0, 1.4, 6, 0.25, 0.4, "wall/concrete", {"name": "RoofStair", "tile": 1.0})
	Kit.box(self, _c(70.0, 22.4, UP + 2.0), Vector3(1.6, 1.4, 0.2), "metal/plate", {"tint": Color(0.5, 0.5, 0.52)})
	Kit.label(self, "ROOF", _c(72.0, 17.98, UP + 2.5), 0.0, 22, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	Readable.create(self, _c(70.0, 23.2, UP + 1.8), 0.0, "A door at the top of the stair", [
		"Six steps up to a steel door with no handle. ROOF, on a plate. Behind it, wind, and a great many pigeons, and nothing else.",
		"It has been painted shut from the other side.",
	], {"name": "RoofDoor", "size": Vector3(1.6, 1.6, 1.0)})
	# the upstairs corridor comes down without a stair: its east end is the downstairs corridor's west end
	floor_seam = SeamlessTeleport.create(self, _c(86.0, 16.5, UP), -90.0, _c(6.0, 16.5, 0.0), -90.0, Vector3(3.0, 3.0, 0.6), {"name": "FloorSeam", "count_flag": "hospital_floor_loops", "on_teleport": _on_floor_loop})


func _on_floor_loop(_p: Node) -> void:
	var n := Game.count("hospital_floor_loops")
	Audio.sfx("creak", global_position, -8.0)
	if n == 1:
		Game.toast.emit("You are downstairs. You did not come down.")
		Game.note("hospital_floors", "Downstairs without a stair", "The corridor upstairs in the hospital keeps going and is the corridor downstairs. You did not come down anything.")
	elif n == 3:
		_scare_now()


# --- the memories ------------------------------------------------------------------------------

## Six things hidden about the building. Finding one is remembering it.
func _memories() -> void:
	_memory(_c(43.4, 7.6, 0.3), "memory_desk", "Under the desk", [
		"Taped under the reception desk, where nobody would look: the sound of a name being said, over and over, in a tone you would use for a dog you were not sure was dead.",
		"It is your name. You had forgotten it had a sound.",
	])
	_memory(_c(4.6, 50.0, 1.3), "memory_drawer", "The first drawer", [
		"In the top drawer of the morgue, nothing, and on the nothing, a smell: soap, and under the soap, the ward, and under the ward, rain on a road you walked to a house.",
		"You had forgotten the house was real.",
	])
	_memory(_c(58.0, 30.0, 1.1), "memory_lectern", "On the lectern", [
		"On the lectern in the chapel, a page that was not there before: somebody reading aloud, badly, from a book you liked, and stopping when a nurse came in, and starting again.",
		"You had forgotten being read to.",
	])
	_memory(_c(34.5, 49.5, 0.9), "memory_sink", "In the sink", [
		"In the sink in the theatre, under the drip: a tone that goes on. A machine's tone. It has been going on for as long as you have been anywhere in here.",
		"You had forgotten it was a sound and not the silence.",
	])
	_memory(_c(61.0, 50.0, 0.3), "memory_bed", "Under a small bed", [
		"Under one of the small beds: three paper roses, folded from a page, before they were put in any vase. Somebody's hands folding them, badly, on a lap, in a chair.",
		"You had forgotten whose lap.",
	])
	_memory(_c(58.0, 25.0, UP + 0.8), "memory_file", "In the file", [
		"In the file with your name on it, one thing that is not a word: the day you fell asleep. The road, the house, the door, the chair by a bed you had not yet lain in.",
		"You had forgotten there was a day. There was.",
	])


func _memory(pos: Vector3, key: String, prompt: String, lines: Array) -> void:
	if Game.has_flag(key):
		return
	var holder := Node3D.new()
	holder.name = "Memory_" + key
	holder.position = pos
	add_child(holder)
	var orb := Props.place(holder, "item_photo", Vector3.ZERO, 0.0, 0.8, {"collision": "none"})
	var cw := Clockwork.create(holder, Vector3.ZERO, {"mode": "rotate", "axis": Vector3.UP, "speed_deg": 40.0, "name": "Turn"})
	if orb:
		orb.reparent(cw.body)
		orb.position = Vector3.ZERO
	Kit.light(holder, Vector3(0, 0.3, 0), Color(1.0, 0.9, 0.7), 0.8, 3.0)
	Interactable.make(holder, Vector3.ZERO, Vector3(0.7, 0.7, 0.7), prompt, func(_p: Node, _it: Node) -> void:
		_take_memory(holder, key, lines), {"name": "Take_" + key})


func _take_memory(holder: Node3D, key: String, lines: Array) -> void:
	if Game.has_flag(key):
		return
	Game.set_flag(key, true)
	Audio.sfx("pickup", holder.global_position, -6.0)
	var n := Game.bump("memories")
	Game.gain_item("memory")
	holder.queue_free()
	if World.hud:
		await World.hud.say("", lines)
	Game.note(key, "A memory (%d of %d)" % [n, MEMORIES], String(lines[0]))
	if n >= MEMORIES:
		Game.set_flag("memories_all", true)
		Game.toast.emit("Six. Down the spine, the door that was a wall is a door.")
		Game.note("memories_all", "All six", "Six memories, and with the sixth the far door at the end of the hospital's spine is a door. Past it, room 5½.")
		await get_tree().create_timer(1.6).timeout
		World.reload_here("far", {"duration": 0.9, "silent": true})
		return
	if n == 4 and not _dark:
		_go_dark(false)
	Game.toast.emit("%d of six. Something in the building has noticed." % n)
	await get_tree().create_timer(1.2).timeout
	_scare_now()


## With four remembered, the tubes give out and the emergency lights come on.
func _go_dark(at_build: bool) -> void:
	_dark = true
	for l in _flicker:
		var ol: OmniLight3D = l
		if is_instance_valid(ol):
			if at_build:
				ol.light_energy = 0.05
			else:
				var tw := create_tween()
				tw.tween_property(ol, "light_energy", 0.05, 0.6)
	for r in _reds:
		var rl: OmniLight3D = r
		if is_instance_valid(rl):
			if at_build:
				rl.light_energy = 0.9
			else:
				var tw := create_tween()
				tw.tween_property(rl, "light_energy", 0.9, 1.5)
	if not at_build:
		Audio.sfx("tv_off", null, -3.0)
		Game.toast.emit("The lights give out. The red ones come on. They were always there.")


# --- the far corridor, and the room -----------------------------------------------------------

func _far_corridor() -> void:
	for x in [50.0, 58.0, 66.0, 74.0, 82.0, 90.0]:
		_fluor(x, 62.5)
	loop_seam = SeamlessTeleport.create(self, _c(86.0, 62.5), -90.0, _c(54.0, 62.5), -90.0, Vector3(3.0, 3.0, 0.6), {"name": "FarLoop", "count_flag": "hospital_loops", "on_teleport": _on_far_loop})
	if Game.count("hospital_loops") >= LOOPS_NEEDED:
		loop_seam.enabled = false
	Kit.label(self, "5½", _c(97.98, 62.5, 1.8), 90.0, 60, Color(0.25, 0.25, 0.25), "display", {"pixel_size": 0.012})
	Kit.sign(self, "signs/ward_room", _c(92.0, 64.02, 2.5), 0.0, Vector2(0.6, 0.6))
	Puzzle.declare(self, "hospital_loops", "", ["flag:memories_all"], "the far corridor goes round twice before it ends")
	Kit.water(self, _c(73.0, 62.5, 0.02), Vector2(48.0, 2.8), "nature/water_cistern", {"tint": Color(0.7, 0.75, 0.7, 0.5), "subdiv": 2})


func _on_far_loop(_p: Node) -> void:
	var n := Game.count("hospital_loops")
	Audio.sfx("creak", global_position, -8.0)
	if n == 1:
		Game.toast.emit("The corridor goes on. The same tube is out.")
	elif n >= LOOPS_NEEDED and loop_seam:
		loop_seam.enabled = false
		Game.toast.emit("The corridor gives up going on.")
		_scare_now()


## Room 5½: the bed, and the one in it, half under the sheet and half in the
## coat, and the chair by the bed with your shape in it.
func _room() -> void:
	var c := _c(92.0, 70.0)
	Props.place(self, "bed_iron", c, 0.0, 1.1)
	Props.place(self, "usher_king", c + Vector3(0, 0.62, 0.2), 90.0, 1.3, {"collision": "none", "name": "TheOneInTheBed"})
	Props.place(self, "chair", c + Vector3(1.6, 0, 0.4), 90.0, 1.0)
	Kit.cylinder(self, c + Vector3(-1.2, 0, -0.9), 0.03, 1.9, "metal/brass", {"segments": 6})
	Kit.box(self, c + Vector3(-1.2, 1.75, -0.9), Vector3(0.18, 0.3, 0.1), "fabric/sheet", {"solid": false, "tint": Color(0.9, 0.95, 1.0)})
	Props.place(self, "crate", c + Vector3(-1.6, 0, 1.4), 0.0, 0.7)
	var tv := Props.place(self, "tv_crt", c + Vector3(-1.6, 0.6, 1.4), 60.0, 0.8, {"collision": "none"})
	var screen := Props.part(tv, "Screen")
	if screen is MeshInstance3D:
		(screen as MeshInstance3D).set_surface_override_material(0, Kit.static_mat({"brightness": 0.8}))
	Props.place(self, "vase", c + Vector3(1.6, 0.5, -1.0), 0.0, 1.0, {"collision": "none"})
	Kit.box(self, c + Vector3(1.6, 0.25, -1.0), Vector3(0.5, 0.5, 0.5), "wood/planks_dark")
	for k in 3:
		var rose := Props.place(self, "rose_paper_planted", c + Vector3(1.6, 0.86, -1.0) + Kit.polar(0.05, k * 120.0), k * 120.0, 0.9, {"collision": "none"})
		if rose:
			rose.rotation.z = deg_to_rad(-12.0)
	Kit.sign(self, "props/window_night", _c(92.0, 74.9, 1.6), 0.0, Vector2(1.6, 1.6))
	Kit.light(self, c + Vector3(0, 2.6, 0), Color(0.95, 0.95, 1.0), 1.1, 8.0)
	Kit.light(self, c + Vector3(-1.6, 1.2, 1.4), Color(0.8, 0.85, 1.0), 0.6, 4.0)
	Interactable.make(self, c + Vector3(0, 0.9, 0.2), Vector3(2.4, 1.4, 2.6), "The one in the bed", _on_bed, {"name": "BedLook"})
	Puzzle.declare(self, "hospital_whole", "ending_whole", ["flag:memories_all"], "in room 5½, lie down in the bed: waking up, the fourth ending")


func _on_bed(_p: Node, _it: Node) -> void:
	if World.hud == null:
		return
	await World.hud.say("", [
		"The one in the bed is two people, and they are lying in it as one person. Half of him is under a sheet with hospital corners, with the King's face turned to the wall: the body, as the ward sees it. Half of him is in a coat, with a hat on the pillow, with your face turned to the door: the one who has been walking.",
		"The set shows static. The roses are in the vase, three of them. The chair has M's shape in it. The book downstairs has M's letter in it. You have all six of the things you had forgotten, and the last of them was that there was a day.",
		"There is room in the bed. There was always only one of you. Lying down is not staying. Lying down is the two halves of you agreeing, and what that is called, from the outside, is waking up.",
	])
	Game.note("hospital_bed", "Room 5½", "At the end of the far corridor, in room 5½: one bed, and the one in it half under the sheet and half in the coat, the body and the one who has been walking. There is room in the bed. Lying down there is waking up.")
	var i: int = await World.hud.ask("", "Lie down, and be one of you, and wake. This is the end of it. Lie down?", ["No. Not yet.", "Lie down. (the ending: waking up)"])
	if i != 1:
		return
	var y: int = await World.hud.ask("", "There is no coming back from this one, because there is nowhere left to come back from. Are you sure?", ["No.", "Yes."])
	if y != 1:
		return
	await Ending.play("whole", "Whole", [
		"You lie down. There is room, because the bed was made for one and there was always only one of you.",
		"The sheet is on your left and the coat is on your right and then it is neither. The set beside the bed finds a channel. The tone from the machine changes, once, and a nurse looks up.",
		"Somebody sits down in the chair. You can hear the pen on the chain. Then you can hear her say your name, in the tone you would use for something you were no longer sure was dead, and you open your eyes.",
	], Color.WHITE)


# --- presences, and the tall one who does not keep his distance -----------------------------

func _presences() -> void:
	Usher.spawn(self, _c(96.0, 16.5), {"appear_delay": 3.0, "radius": 50.0})
	Usher.spawn(self, _c(6.0, 45.5), {"appear_delay": 6.0, "radius": 40.0})
	Usher.spawn(self, _c(50.5, 40.0, UP), {"appear_delay": 4.0, "radius": 30.0})
	_scare(_c(30.0, 16.5), Vector3(2.6, 3.0, 2.6))
	_scare(_c(50.5, 34.0), Vector3(2.6, 3.0, 2.6))
	_scare(_c(64.0, 45.5), Vector3(2.6, 3.0, 2.6))
	_scare(_c(20.0, 16.5, UP), Vector3(2.6, 3.0, 2.6))
	_scare(_c(50.5, 54.0), Vector3(2.6, 3.0, 2.6))
	Kit.particles(self, _c(50.0, 16.5, 1.5), "motes", Vector3(90.0, 1.5, 2.0), 40)


func _scare(pos: Vector3, size: Vector3) -> void:
	Kit.trigger(self, pos + Vector3(0, 1.4, 0), size, func(_p: Node) -> void:
		_scare_now(), {"once": true, "name": "Scare_%d_%d" % [int(pos.x), int(pos.z)]})


## He is there, right there, the closest he can be, for less than a second.
func _scare_now() -> void:
	if _scaring:
		return
	var p := player()
	if p == null or World.traveling:
		return
	_scaring = true
	var fwd := -p.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var pos := p.global_position + fwd * 1.5
	var u := Props.place(self, "usher", pos, Kit.dir_to_yaw(-fwd), 1.0, {"collision": "none", "name": "Scare"})
	Kit.light(u, Vector3(0, 1.6, -0.6), Color(1.0, 0.95, 0.9), 2.5, 4.0)
	Audio.sfx("static_burst", pos, 0.0)
	Audio.sfx("heartbeat", null, -3.0)
	var n := Game.bump("usher_scares")
	if World.hud:
		World.hud.fade_out(Color(0.9, 0.9, 0.9), 0.04)
		await get_tree().create_timer(0.1).timeout
		World.hud.fade_in(0.4)
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(u):
		u.queue_free()
	_scaring = false
	if n == 1:
		Game.note("usher_close", "He has stopped keeping his distance", "In the hospital the tall one stopped standing where you were not looking. He was there, right there, with your face, for less than a second.")


func _process(delta: float) -> void:
	if _flicker.is_empty():
		return
	_t += delta
	var memories := Game.count("memories")
	if memories < 1 and not _dark:
		return
	for l in _flicker:
		var ol: OmniLight3D = l
		if is_instance_valid(ol):
			var k := sin(_t * 17.0 + ol.position.x) * sin(_t * 5.3 + ol.position.z)
			if _dark:
				ol.light_energy = 0.05 if k > -0.9 else 0.5
			else:
				ol.light_energy = 0.9 if k > -0.55 + memories * 0.1 else 0.1


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	Game.set_flag("visited_hospital", true)
	if n == 2 and not Game.has_note("hospital_2"):
		Game.note("hospital_2", "Back again", "The hospital again. It knows you have been before. The tubes were worse, and the water had come further in.")
