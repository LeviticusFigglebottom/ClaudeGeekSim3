extends AreaBase
## St. Nowhere — the hospital above the Other Anteroom. Green paint to
## shoulder height and white above, fluorescent tubes that hum, a lobby with a
## visitors' book, wards of iron beds, a chapel, a nurses' station nobody is
## at, a morgue, a theatre, and past a sign that says VISITING HOURS ARE OVER
## a corridor that goes on to a room numbered 5½. It is visited more than
## once, and it is worse each time: the lights give out, the water comes in,
## and the tall one stops keeping his distance.
##
## Visit 1: sign the book. Visit 2 (book signed): the far corridor is open and
## goes round twice before it ends at a wall with 5½ scratched in it. Visit 3:
## the door in that wall, and the bed, and the one in it.
##
## Built as ONE rasterised map (1 m cells). Holding R wakes you.

const CELL := 1.0
const H := 3.0
const ORIGIN := Vector3(-35.0, 0.0, -25.0)
const W := 70
const D := 50
const GREEN := "wall/plaster_green"
const TILE := "wall/tile_white"
const CHECK := "wall/tile_checker"
const LOOPS_NEEDED := 2

var decay := 0
var far_open := false
var room_open := false
var loop_seam: SeamlessTeleport = null
var _flicker: Array = []
var _t := 0.0
var _scaring := false


func build() -> void:
	can_wake = true
	decay = visit_count
	far_open = visit_count >= 2 and Game.has_flag("hospital_book_read")
	room_open = far_open and visit_count >= 3
	Realm.apply(self, "hospital", {"fog_density": 0.045 + 0.01 * mini(decay, 3)})
	_plan()
	_lobby()
	_corridors()
	_wards()
	_chapel()
	_station()
	_theatre()
	if far_open:
		_morgue()
		_far_corridor()
	if room_open:
		_room()
	_presences()
	add_spawn("from_mirror", _c(37.0, 4.0, 0.1), 180.0)
	add_spawn("default", _c(37.0, 4.0, 0.1), 180.0)
	Puzzle.declare(self, "hospital_book", "hospital_book_read", [], "sign the visitors' book at the desk in the lobby")


# --- coordinates: plan metres -> world ------------------------------------------------------

func _c(x: float, z: float, y: float = 0.0) -> Vector3:
	return Vector3(ORIGIN.x + x, y, ORIGIN.z + z)


func _fluor(x: float, z: float, energy: float = 0.9, reach: float = 8.0, flicker: bool = false) -> void:
	Props.place(self, "fluorescent_light", _c(x, z, H - 0.02), 0.0, 1.0, {"collision": "none"})
	var l := Kit.light(self, _c(x, z, H - 0.35), Color(0.95, 1.0, 0.92), energy, reach)
	if flicker or (decay >= 2 and hash(Vector2i(int(x), int(z))) % 3 == 0):
		_flicker.append(l)


# --- the plan ---------------------------------------------------------------------------------

func _plan() -> void:
	var rects := [
		[30, 2, 44, 12, "l"],      # the lobby
		[2, 13, 68, 16, "c"],      # the main corridor
		[4, 17, 20, 28, "a"],      # ward A
		[24, 17, 40, 28, "b"],     # ward B
		[44, 17, 52, 28, "k"],     # the chapel
		[56, 17, 66, 24, "n"],     # the nurses' station
		[2, 29, 68, 32, "w"],      # the back corridor
		[4, 33, 16, 45, "g"],      # the morgue
		[20, 33, 34, 45, "o"],     # the theatre
		[40, 33, 68, 36, "f"],     # the far corridor
		[58, 37, 68, 47, "r"],     # room 5½
	]
	var doors := [
		[37, 12, "D"],
		[12, 16, "D"], [32, 16, "D"], [48, 16, "D"], [61, 16, "D"],
		[12, 28, "D"], [32, 28, "D"], [48, 28, "D"],
		[27, 32, "D"],
	]
	if far_open:
		doors.append([10, 32, "D"])
		doors.append([54, 32, "D"])
	if room_open:
		doors.append([63, 36, "D"])
	var rows := MapBuilder.rasterize(W, D, rects, doors)
	var rooms := {
		"l": {"floor": CHECK, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"c": {"floor": TILE, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"a": {"floor": TILE, "wall": TILE, "ceiling": "wall/ceiling_tile"},
		"b": {"floor": TILE, "wall": TILE, "ceiling": "wall/ceiling_tile"},
		"k": {"floor": "wood/planks_dark", "wall": "wall/plaster_cream", "ceiling": "wall/plaster_white"},
		"n": {"floor": CHECK, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"w": {"floor": TILE, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"g": {"floor": "wall/concrete", "wall": TILE, "ceiling": "wall/concrete_dark"},
		"o": {"floor": TILE, "wall": TILE, "ceiling": "wall/plaster_white"},
		"f": {"floor": TILE, "wall": GREEN, "ceiling": "wall/ceiling_tile"},
		"r": {"floor": TILE, "wall": TILE, "ceiling": "wall/ceiling_tile"},
	}
	MapBuilder.build(self, rows, {
		"cell": CELL, "height": H, "origin": ORIGIN, "door_h": 2.2, "tile": 2.0,
		"floor": TILE, "wall": GREEN, "ceiling": "wall/ceiling_tile",
		"rooms": rooms, "outer_faces": true, "name": "Hospital",
	})


# --- the lobby -------------------------------------------------------------------------------

func _lobby() -> void:
	# the way back down, in the north wall
	Door.create(self, _c(37.0, 2.4), 0.0, "mirror_nexus", "top", {"kind": "dark", "label": "The way you came up", "name": "Door_down", "fade_color": Color(0.65, 0.95, 0.93), "fade_duration": 1.0})
	Kit.sign(self, "signs/hospital_name", _c(37.0, 2.02, 2.5), 180.0, Vector2(2.4, 0.6))
	# the desk, and the book on it
	Props.place(self, "desk_office", _c(33.0, 6.0), 90.0, 1.1)
	Props.place(self, "chair_office", _c(31.8, 6.0), -90.0, 1.0)
	Props.place(self, "phone_office", _c(33.0, 0.8, 5.2), 90.0, 1.0, {"collision": "none"})
	Kit.box(self, _c(33.1, 0.79, 6.5), Vector3(0.42, 0.05, 0.3), "signs/book_cover", {"solid": false})
	Interactable.make(self, _c(33.1, 0.9, 6.5), Vector3(0.8, 0.6, 0.8), "The visitors' book", _on_book, {"name": "VisitorsBook"})
	Kit.label(self, "RECEPTION", _c(33.0, 6.0, 2.3), 90.0, 22, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	Props.place(self, "waiting_chairs", _c(40.5, 4.0), 90.0, 1.0)
	Props.place(self, "waiting_chairs", _c(40.5, 8.5), 90.0, 1.0)
	Props.place(self, "potted_plant_fake", _c(42.5, 2.8), 0.0, 1.0, {"collision": "cylinder"})
	Props.place(self, "ticket_dispenser", _c(31.0, 10.5), 90.0, 1.0, {"collision": "cylinder"})
	Props.place(self, "number_display", _c(37.0, 2.6, 11.9), 0.0, 1.0, {"collision": "none"})
	# the lift that is coming
	Kit.box(self, _c(43.85, 1.25, 6.5), Vector3(0.3, 2.5, 2.2), "metal/plate", {"tint": Color(0.7, 0.72, 0.7)})
	Kit.box(self, _c(43.7, 1.25, 6.5), Vector3(0.02, 2.3, 0.04), "metal/iron", {"solid": false, "tint": Color(0.2, 0.2, 0.2)})
	Kit.box(self, _c(43.7, 1.1, 5.0), Vector3(0.04, 0.12, 0.12), "metal/brass", {"solid": false})
	Interactable.make(self, _c(43.4, 1.1, 5.0), Vector3(0.6, 0.6, 0.6), "Call the lift", _on_lift, {"name": "Lift"})
	Kit.label(self, "LIFT", _c(43.75, 6.5, 2.7), 90.0, 22, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	for p in [[33.0, 4.0], [33.0, 9.0], [40.0, 4.0], [40.0, 9.0]]:
		_fluor(float(p[0]), float(p[1]))
	Readable.create(self, _c(37.0, 1.4, 8.0), 0.0, "Look round the lobby", [
		"A lobby with a desk and a book and chairs bolted to the floor. Green paint to shoulder height, white above, a line between where a hand could reach.",
		"There is a smell of soap over the top of another smell. The number over the door to the wards says 5½. It has said it for some time.",
	], {"name": "LobbyLook", "size": Vector3(4.0, 2.0, 4.0), "note_key": "hospital", "note_title": "St. Nowhere", "note_text": "Above the Other Anteroom, up the platforms, a hospital: green paint to shoulder height, a lobby with a visitors' book, wards, a chapel, and a sign that says visiting hours are over."})


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
	Game.note("hospital_book", "The visitors' book", "The visitors' book in the hospital lobby: every day, in the afternoon, room 5½, one letter, M, in your hand. You signed today's line. The sign on the door to the far corridor says visiting hours are over. Come back.")
	Game.toast.emit("You sign. The pen knows the letter before you do.")
	await World.hud.say("", ["You sign. The sign over the far door still says VISITING HOURS ARE OVER.", "It will say something else when you come back. Places like this run on coming back."])


func _on_lift(_p: Node, _it: Node) -> void:
	Audio.sfx("ui_blip", global_position, -10.0)
	Game.bump("hospital_lift")
	if World.hud:
		await World.hud.say("", ["The button lights. Somewhere above, a long way above, a cable takes the strain.", "The lift is coming. It has been coming since before you pressed the button. It is a very tall building."])


# --- corridors -------------------------------------------------------------------------------

func _corridors() -> void:
	for x in range(6, 68, 8):
		_fluor(float(x), 14.5)
		_fluor(float(x), 30.5)
	Kit.sign(self, "signs/ward_a", _c(12.0, 16.98, 2.5), 0.0, Vector2(1.0, 0.5))
	Kit.sign(self, "signs/ward_b", _c(32.0, 16.98, 2.5), 0.0, Vector2(1.0, 0.5))
	Kit.sign(self, "signs/ward_quiet", _c(48.0, 16.98, 2.5), 0.0, Vector2(1.0, 0.5))
	Kit.label(self, "NURSES", _c(61.0, 16.98, 2.5), 0.0, 22, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	# the far door's sign, on the back corridor's south wall
	Kit.sign(self, "signs/ward_visiting" if not far_open else "signs/ward_hours", _c(54.0, 31.98, 2.5), 0.0, Vector2(1.6, 0.6))
	if not far_open:
		Readable.create(self, _c(54.0, 1.4, 31.4), 180.0, "A door that is a wall", [
			"Where a door should be, a wall, and over the wall a sign: VISITING HOURS ARE OVER.",
			"Under the paint, the shape of a door. It has been painted over more than once. Places like this run on coming back.",
		], {"name": "FarWall", "size": Vector3(2.0, 2.0, 1.0)})
	# a gurney, a wheelchair's worth of absence, a bucket
	Props.place(self, "bed_iron", _c(20.0, 14.5), 90.0, 0.9, {"tint": Color(0.85, 0.85, 0.85)})
	Props.place(self, "crate_small", _c(50.0, 30.6), 20.0, 0.7)
	if decay >= 2:
		for x in range(8, 66, 6):
			Kit.water(self, _c(float(x), 30.5, 0.02), Vector2(4.5, 2.8), "nature/water_cistern", {"tint": Color(0.7, 0.75, 0.7, 0.5), "subdiv": 2})
		Readable.create(self, _c(20.0, 1.0, 30.5), 0.0, "Water on the floor", ["Water on the floor of the back corridor, a finger deep, going the same way as the corridor.", "It is coming from under the door at the far end, which is the door that is not there."], {"name": "FloorWater", "size": Vector3(4.0, 1.0, 2.6)})
	Readable.create(self, _c(37.0, 1.4, 14.5), 0.0, "The corridor", [
		"A corridor with a line down the middle of the floor, and doors off it, and a hum. The hum is the lights, or it is the building thinking.",
		"You have walked this corridor. Not this one: the one it is a copy of. You had a bunch of paper roses in your hand and you were counting doors.",
	], {"name": "CorridorLook", "size": Vector3(6.0, 2.0, 2.6)})


# --- the wards -------------------------------------------------------------------------------

func _wards() -> void:
	for ward in [[4.0, 20.0, "A"], [24.0, 40.0, "B"]]:
		var x0 := float(ward[0])
		var x1 := float(ward[1])
		var n := 0
		for k in 5:
			var x := x0 + 2.0 + k * 3.0
			for side in [0, 1]:
				var z := 19.2 if side == 0 else 25.8
				var yaw := 0.0 if side == 0 else 180.0
				n += 1
				var bed := Props.place(self, "bed_iron", _c(x, z), yaw, 1.0)
				# a shape under the sheet in some beds, more each visit
				var occupied := (hash(Vector2i(int(x), side)) + decay * 7) % 5 < decay
				if occupied:
					Kit.box(self, _c(x, 0.78, z + (0.2 if side == 0 else -0.2)), Vector3(0.5, 0.22, 1.5), "fabric/sheet", {"solid": false, "tint": Color(0.9, 0.9, 0.88)})
				if k % 2 == 0:
					Kit.cylinder(self, _c(x + 0.7, z + (1.0 if side == 0 else -1.0)), 0.03, 1.9, "metal/brass", {"segments": 6})
				# curtain rails and curtains, some drawn
				var drawn := (hash(Vector2i(int(x) * 3, side + decay)) % 3) == 0
				if drawn:
					Kit.box(self, _c(x + 0.95, 1.3, z), Vector3(0.04, 2.2, 2.6), "fabric/sheet", {"tint": Color(0.75, 0.85, 0.8), "tile": 1.5})
				if bed and side == 0 and k == 2:
					Readable.create(self, _c(x, 0.9, z + 1.2), 0.0, "A bed in ward " + String(ward[2]), [
						"An iron bed, made with hospital corners, a chart on a clip at the foot with nothing on it but a line going down.",
						"You have lain in one of these. You are not sure it was not this one.",
					], {"name": "Bed" + String(ward[2]), "size": Vector3(1.4, 1.2, 1.2)})
		for k in 3:
			_fluor(x0 + 2.5 + k * 5.0, 22.5)
	Kit.label(self, "WARD A", _c(12.0, 17.02, 2.5), 180.0, 26, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	Kit.label(self, "WARD B", _c(32.0, 17.02, 2.5), 180.0, 26, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	Props.place(self, "water_cooler", _c(19.0, 22.5), -90.0, 1.0)
	Props.place(self, "filing_cabinet", _c(39.0, 22.5), -90.0, 1.0)


func _chapel() -> void:
	for k in 4:
		Props.place(self, "bench", _c(46.0, 19.5 + k * 2.0), 90.0, 0.8, {"tint": Color(0.7, 0.6, 0.5)})
		Props.place(self, "bench", _c(50.0, 19.5 + k * 2.0), 90.0, 0.8, {"tint": Color(0.7, 0.6, 0.5)})
	Props.place(self, "lectern", _c(48.0, 27.0), 0.0, 1.0)
	Props.place(self, "candle_cluster", _c(46.5, 27.2), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "candle_cluster", _c(49.5, 27.2), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, _c(48.0, 1.6, 26.5), Color(1.0, 0.85, 0.6), 1.0, 7.0)
	Kit.sign(self, "props/window_night", _c(48.0, 1.8, 27.9), 0.0, Vector2(1.4, 1.8))
	Readable.create(self, _c(48.0, 1.2, 26.4), 0.0, "The chapel", [
		"Eight benches and a lectern and a window that shows night, which is the only thing it has ever shown. A book on the lectern, open at nothing.",
		"Somebody has sat in the back row a long time. The bench remembers the shape. It is the shape from the chair by the bed.",
	], {"name": "ChapelLook", "size": Vector3(3.0, 2.0, 2.0), "note_key": "hospital_chapel", "note_title": "The chapel", "note_text": "A chapel in the hospital with a window that shows night. Somebody has sat in the back row long enough to leave a shape, and it is the shape from the chair by the King's bed."})
	if decay >= 3:
		Kit.box(self, _c(48.0, 0.25, 22.0), Vector3(1.6, 0.5, 0.5), "wood/planks_dark", {"rotation": Vector3(0, 30, 80)})


func _station() -> void:
	Props.place(self, "desk_office", _c(59.0, 20.0), 0.0, 1.0)
	Props.place(self, "desk_office", _c(62.5, 20.0), 0.0, 1.0)
	Props.place(self, "chair_office", _c(59.0, 18.6), 180.0, 1.0)
	Props.place(self, "phone_office", _c(62.5, 0.76, 20.0), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "filing_cabinet", _c(65.2, 18.5), -90.0, 1.0)
	Props.place(self, "filing_cabinet", _c(65.2, 20.0), -90.0, 1.0)
	Kit.sign(self, "metal/clock_face", _c(61.0, 2.3, 17.02), 180.0, Vector2(0.9, 0.9))
	_fluor(61.0, 20.5)
	Readable.create(self, _c(61.0, 1.0, 21.5), 0.0, "The nurses' station", [
		"Two desks, a phone that does not ring, a clock that says half past five. A chart pinned to the wall: one name, one room, and under ROOM, 5½.",
		"Under VISITOR, one letter, over and over, down the page and off the bottom.",
	], {"name": "StationLook", "size": Vector3(4.0, 1.4, 2.0)})


func _theatre() -> void:
	Kit.box(self, _c(27.0, 0.45, 39.0), Vector3(0.8, 0.9, 2.2), "metal/plate", {"tint": Color(0.8, 0.82, 0.8)})
	Props.place(self, "chandelier", _c(27.0, 2.4, 39.0), 0.0, 0.6, {"collision": "none"})
	Kit.light(self, _c(27.0, 2.2, 39.0), Color(1.0, 1.0, 0.95), 1.4, 7.0)
	for k in 3:
		Props.place(self, "crate_small", _c(22.0 + k * 1.2, 43.5), 0.0, 0.6, {"tint": Color(0.7, 0.72, 0.7)})
	Props.place(self, "sink", _c(32.5, 34.5), 90.0, 1.0)
	Readable.create(self, _c(27.0, 1.2, 40.6), 0.0, "The theatre", [
		"A table under a lamp, and the lamp on, and nothing on the table. Trays of nothing. A sink with the tap dripping.",
		"Whatever was done here was done, and it did not take.",
	], {"name": "TheatreLook", "size": Vector3(2.4, 1.6, 2.0)})
	if decay >= 2:
		Kit.water(self, _c(27.0, 39.0, 0.02), Vector2(5.0, 5.0), "nature/water_cistern", {"tint": Color(0.7, 0.75, 0.7, 0.5), "subdiv": 2})


func _morgue() -> void:
	for k in 4:
		for j in 2:
			Kit.box(self, _c(4.4, 0.5 + j * 0.8, 35.5 + k * 1.2), Vector3(0.6, 0.7, 1.0), "metal/plate", {"tint": Color(0.75, 0.78, 0.78)})
			Kit.box(self, _c(4.1, 0.5 + j * 0.8, 35.5 + k * 1.2), Vector3(0.04, 0.06, 0.3), "metal/iron", {"solid": false})
	Kit.box(self, _c(10.0, 0.45, 40.0), Vector3(0.8, 0.9, 2.2), "metal/plate", {"tint": Color(0.8, 0.82, 0.8)})
	Kit.box(self, _c(10.0, 0.98, 40.0), Vector3(0.7, 0.24, 1.9), "fabric/sheet", {"solid": false, "tint": Color(0.9, 0.9, 0.88)})
	Kit.light(self, _c(10.0, 2.5, 40.0), Color(0.7, 0.85, 0.9), 0.8, 8.0)
	Readable.create(self, _c(10.0, 1.2, 41.4), 0.0, "A sheet over a shape", [
		"A table, a sheet, a shape under the sheet the length of you. You do not lift it. You know what a hat looks like under a sheet.",
		"The drawers along the wall are labelled with one letter each, and it is the same letter.",
	], {"name": "MorgueLook", "size": Vector3(1.8, 1.6, 2.6), "note_key": "hospital_morgue", "note_title": "The morgue", "note_text": "The morgue in the hospital, open on the second visit: a sheet over a shape the length of you, with a hat under it, and drawers all labelled with the same letter."})


# --- the far corridor, and the room -----------------------------------------------------------

func _far_corridor() -> void:
	for x in [42.0, 50.0, 58.0, 66.0]:
		_fluor(x, 34.5, 0.8, 7.0, decay >= 3)
	# the corridor goes round: x 62 is x 46 again, twice
	loop_seam = SeamlessTeleport.create(self, _c(62.0, 34.5), -90.0, _c(46.0, 34.5), -90.0, Vector3(3.0, 3.0, 0.6), {"name": "FarLoop", "count_flag": "hospital_loops", "on_teleport": _on_far_loop})
	if Game.count("hospital_loops") >= LOOPS_NEEDED:
		loop_seam.enabled = false
	Kit.label(self, "5½", _c(67.98, 34.5, 1.8), 90.0, 60, Color(0.25, 0.25, 0.25), "display", {"pixel_size": 0.012})
	if not room_open:
		Readable.create(self, _c(67.0, 1.4, 34.5), -90.0, "The end of the corridor", [
			"The corridor ends. Scratched into the paint of the end wall, with something not made for scratching: 5½.",
			"Behind the wall, something is breathing, once for every four of your breaths. There is no door. Not yet. Come back.",
		], {"name": "FarEnd", "size": Vector3(1.0, 2.0, 2.6), "note_key": "hospital_far", "note_title": "The end of the far corridor", "note_text": "The far corridor of the hospital goes round twice and ends at a wall with 5½ scratched into it. Behind it, breathing, once for every four of your breaths. There is no door yet. Come back."})
	Puzzle.declare(self, "hospital_loops", "", ["flag:hospital_book_read"], "the far corridor goes round twice before it ends")
	Kit.water(self, _c(54.0, 34.5, 0.02), Vector2(26.0, 2.8), "nature/water_cistern", {"tint": Color(0.7, 0.75, 0.7, 0.5), "subdiv": 2})


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
	var c := _c(63.0, 42.0)
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
	Kit.sign(self, "props/window_night", _c(63.0, 1.6, 46.9), 0.0, Vector2(1.6, 1.6))
	Kit.sign(self, "signs/ward_room", _c(63.0, 2.5, 37.02), 180.0, Vector2(0.6, 0.6))
	Kit.light(self, c + Vector3(0, 2.6, 0), Color(0.95, 0.95, 1.0), 1.1, 8.0)
	Kit.light(self, c + Vector3(-1.6, 1.2, 1.4), Color(0.8, 0.85, 1.0), 0.6, 4.0)
	Interactable.make(self, c + Vector3(0, 0.9, 0.2), Vector3(2.4, 1.4, 2.6), "The one in the bed", _on_bed, {"name": "BedLook"})
	Puzzle.declare(self, "hospital_whole", "ending_whole", ["flag:hospital_book_read"], "in room 5½, lie down beside the one in the bed: the fourth ending")


func _on_bed(_p: Node, _it: Node) -> void:
	if World.hud == null:
		return
	await World.hud.say("", [
		"The one in the bed is two people, and they are lying in it as one person. Half of him is under a sheet with hospital corners, with the King's face turned to the wall. Half of him is in a coat, with a hat on the pillow, with your face turned to the door.",
		"The set shows static. The roses are in the vase, three of them. The chair has your shape in it, and the book downstairs has your letter in it, and you have been here every day.",
		"There is room in the bed. There was always only one of you.",
	])
	Game.note("hospital_bed", "Room 5½", "At the end of the far corridor, in room 5½: one bed, and the one in it half under the sheet and half in the coat, the King's face and yours. Three roses in the vase. The chair with your shape. There is room in the bed.")
	var i: int = await World.hud.ask("", "Lie down beside him, and be one of you. This is the end of it. Lie down?", ["No. Not yet.", "Lie down. (an ending)"])
	if i != 1:
		return
	var y: int = await World.hud.ask("", "There is no coming back from this one. Are you sure?", ["No.", "Yes."])
	if y != 1:
		return
	await Ending.play("whole", "Whole", [
		"You lie down. There is room, because the bed was made for one and there was always only one of you.",
		"The sheet is on your left and the coat is on your right and then it is neither, and the set beside the bed finds a channel.",
		"Somebody sits down in the chair. You can hear the pen on the chain.",
	], Color.WHITE)


# --- presences, and the tall one who stops keeping his distance ------------------------------

func _presences() -> void:
	Usher.spawn(self, _c(64.0, 14.5), {"appear_delay": 3.0, "radius": 50.0})
	if decay >= 2:
		_scare(_c(24.0, 14.5), Vector3(2.6, 3.0, 2.6))
		_scare(_c(32.0, 24.0), Vector3(4.0, 3.0, 2.6))
	if decay >= 3:
		_scare(_c(40.0, 30.5), Vector3(2.6, 3.0, 2.6))
		_scare(_c(58.0, 34.5), Vector3(2.6, 3.0, 2.6))
	Kit.particles(self, _c(37.0, 14.5, 1.5), "motes", Vector3(60.0, 1.5, 2.0), 40)


func _scare(pos: Vector3, size: Vector3) -> void:
	Kit.trigger(self, pos + Vector3(0, 1.4, 0), size, func(_p: Node) -> void:
		_scare_now(), {"once": true, "name": "Scare_%d" % int(pos.x)})


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
	var pos := p.global_position + fwd * 1.6
	var u := Props.place(self, "usher", pos, Kit.dir_to_yaw(-fwd), 1.0, {"collision": "none", "name": "Scare"})
	Audio.sfx("static_burst", pos, -3.0)
	Audio.sfx("heartbeat", null, -6.0)
	var n := Game.bump("usher_scares")
	if World.hud:
		World.hud.fade_out(Color(0.85, 0.85, 0.85), 0.04)
		await get_tree().create_timer(0.08).timeout
		World.hud.fade_in(0.35)
	await get_tree().create_timer(0.55).timeout
	if is_instance_valid(u):
		u.queue_free()
	_scaring = false
	if n == 1:
		Game.note("usher_close", "He has stopped keeping his distance", "In the hospital the tall one stopped standing where you were not looking. He was there, right there, with your face, for less than a second.")


func _process(delta: float) -> void:
	if _flicker.is_empty():
		return
	_t += delta
	for l in _flicker:
		var ol: OmniLight3D = l
		if is_instance_valid(ol):
			var k := sin(_t * 17.0 + ol.position.x) * sin(_t * 5.3 + ol.position.z)
			ol.light_energy = 0.9 if k > -0.55 else 0.1


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	Game.set_flag("visited_hospital", true)
	if n == 2:
		Game.note("hospital_2", "The second visit", "The hospital, the second time: some of the lights have given out and water has come in under the far door, which is a door now. The morgue is open.")
	if n >= 3 and not Game.has_note("hospital_3"):
		Game.note("hospital_3", "The third visit", "The hospital, the third time: the far corridor has a door in its end wall, and the door has a number on it, and the number is yours.")
