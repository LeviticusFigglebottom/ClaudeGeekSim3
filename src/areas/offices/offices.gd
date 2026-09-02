extends AreaBase
## The Waiting Halls — please take a number. A yellow office that nobody works
## in, lit by fluorescent tubes that never quite stop humming. There is a
## waiting room where a number is always being served and it is never yours,
## a cubicle floor, an archive where the family's missing photograph is filed
## under your flat number, a break room with a STAFF ONLY door into the
## Nowhere House, a fire door down to the Halden Arms, and a corridor of
## cubicles that goes round.
##
## Built as ONE rasterised map (1 m cells, real wall cells, per-room textures).

const H := 2.7
const ORIGIN := Vector3(-20.0, 0.0, -15.0)
const W := 40
const D := 30
const WAITS_NEEDED := 3

var display_label: Label3D = null
var serving := 0
var _tick := 0.0
var shadow: Node3D = null
var _shadow_spots: Array = []
var _shadow_step := 0
var copies := 0


func build() -> void:
	Realm.apply(self, "offices", {"ambient_energy": 1.05})
	serving = Game.count("offices_serving")
	_plan()
	_cubicles()
	_waiting_room()
	_archive()
	_reception()
	_break_room()
	_numbered_doors()
	_loop_corridor()
	_presences()
	add_spawn("default", _c(20.0, 16.5, 0.1), 0.0)
	Puzzle.declare(self, "offices_number", "number_called", [], "take a number and wait; your number comes round on the third wait")
	Puzzle.declare(self, "offices_photo", "offices_photo_taken", [], "the archive drawer filed under your flat number", {"item": "photo"})
	Puzzle.declare(self, "offices_vending", "offices_biscuit", [], "press B4 on the vending machine in the waiting room", {"item": "dog_biscuit"})


# --- coordinates: plan metres -> world ------------------------------------------

func _c(x: float, z: float, y: float = 0.0) -> Vector3:
	return Vector3(ORIGIN.x + x, y, ORIGIN.z + z)


func _fluor(x: float, z: float, energy: float = 0.9, reach: float = 7.5) -> void:
	Props.place(self, "fluorescent_light", _c(x, z, H - 0.02), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, _c(x, z, H - 0.35), Color(1.0, 0.97, 0.85), energy, reach)


# --- the plan ----------------------------------------------------------------------

func _plan() -> void:
	var rects := [
		[2, 2, 26, 9, "c"],      # cubicle floor      x 2-26   z 2-9
		[14, 10, 26, 20, "w"],   # waiting room       x 14-26  z 10-20
		[2, 10, 13, 20, "a"],    # archive            x 2-13   z 10-20
		[27, 10, 38, 13, "r"],   # reception corridor x 27-38  z 10-13
		[27, 14, 38, 20, "k"],   # break room         x 27-38  z 14-20
		[14, 21, 26, 25, "s"],   # the numbered doors x 14-26  z 21-25
		[2, 26, 38, 29, "l"],    # the corridor that goes round  x 2-38 z 26-29
	]
	var doors := [
		[20, 9, "D"],                     # cubicles -> waiting
		[6, 9, "D"],                      # cubicles -> archive
		[13, 14, "D"], [13, 15, "D"],     # archive -> waiting
		[26, 11, "D"], [26, 12, "D"],     # waiting -> reception
		[32, 13, "D"], [33, 13, "D"],     # reception -> break room
		[19, 20, "D"], [20, 20, "D"],     # waiting -> numbered doors
		[19, 25, "D"], [20, 25, "D"],     # numbered doors -> the loop
	]
	var rows := MapBuilder.rasterize(W, D, rects, doors)
	var rooms := {
		"c": {"floor": "wall/carpet_office", "wall": "wall/wallpaper_office", "ceiling": "wall/ceiling_tile"},
		"w": {"floor": "wall/carpet_office", "wall": "wall/plaster_yellow", "ceiling": "wall/ceiling_tile"},
		"a": {"floor": "wall/concrete", "wall": "wall/plaster_cream", "ceiling": "wall/ceiling_tile"},
		"r": {"floor": "wall/carpet_office", "wall": "wall/wallpaper_office", "ceiling": "wall/ceiling_tile"},
		"k": {"floor": "wall/tile_checker", "wall": "wall/plaster_yellow", "ceiling": "wall/plaster_white"},
		"s": {"floor": "wall/carpet_office", "wall": "wall/wallpaper_office", "ceiling": "wall/ceiling_tile"},
		"l": {"floor": "wall/carpet_office", "wall": "wall/wallpaper_office", "ceiling": "wall/ceiling_tile"},
	}
	MapBuilder.build(self, rows, {
		"cell": 1.0, "height": H, "origin": ORIGIN, "door_h": 2.1, "tile": 2.0,
		"floor": "wall/carpet_office", "wall": "wall/plaster_yellow", "ceiling": "wall/ceiling_tile",
		"rooms": rooms, "outer_faces": true, "name": "Offices",
	})


# --- the cubicle floor (x 2-26, z 2-9) ----------------------------------------------

func _cubicles() -> void:
	var n := 9
	var tint := Color(0.72, 0.74, 0.82)
	for k in n + 1:
		var px := 2.6 + k * 2.4
		Kit.box(self, _c(px, 3.3, 0.75), Vector3(0.08, 1.5, 2.6), "wall/carpet_office", {"tint": tint, "tile": 1.0})
		Kit.box(self, _c(px, 7.7, 0.75), Vector3(0.08, 1.5, 2.6), "wall/carpet_office", {"tint": tint, "tile": 1.0})
	for k in n:
		var cx := 2.6 + k * 2.4 + 1.2
		# north row: desks against the north wall, chairs facing them
		if k == 8:
			Props.place(self, "photocopier", _c(cx, 2.75), 180.0, 1.0)
			Interactable.make(self, _c(cx, 2.75, 0.9), Vector3(0.9, 1.0, 0.8), "Make a copy", _on_copy, {"name": "Copier"})
		else:
			Props.place(self, "desk_office", _c(cx, 2.75), 180.0, 1.0)
			Props.place(self, "chair_office", _c(cx, 3.75), 0.0, 1.0)
			if k % 2 == 0:
				Props.place(self, "tv_crt", _c(cx - 0.2, 2.7, 0.76), 180.0, 0.5, {"collision": "none"})
			if k % 3 == 1:
				Props.place(self, "phone_office", _c(cx + 0.45, 2.75, 0.76), 180.0, 1.0, {"collision": "none"})
		# south row: desks against the south wall (skipping the two doorways)
		if k == 1 or k == 7:
			continue
		if k == 8:
			Props.place(self, "water_cooler", _c(cx, 8.4), 0.0, 1.0)
			Interactable.make(self, _c(cx, 8.4, 0.9), Vector3(0.6, 1.4, 0.6), "Drink", _on_drink, {"name": "Cooler"})
		else:
			Props.place(self, "desk_office", _c(cx, 8.25), 0.0, 1.0)
			Props.place(self, "chair_office", _c(cx, 7.25), 180.0, 1.0)
			if k % 2 == 1:
				Props.place(self, "tv_crt", _c(cx + 0.2, 8.3, 0.76), 0.0, 0.5, {"collision": "none"})
	for x in [4.5, 9.5, 14.5, 19.5, 24.0]:
		_fluor(x, 5.5)
	# memos pinned to partitions
	Readable.create(self, _c(5.05, 3.0, 1.25), -90.0, "A memo", ["MEMO: all staff.", "The number being served is not the number on your ticket. This is intentional. Please continue to wait.", "  - Management"], {"name": "Memo1", "sign": "signs/note_offices", "sign_size": Vector2(0.32, 0.32), "size": Vector3(0.1, 0.4, 0.4)})
	Readable.create(self, _c(12.25, 3.0, 1.25), 90.0, "A memo", ["MEMO: whoever keeps taking the photographs out of the archive:", "put them back. The family in them is not yours.", "  - M."], {"name": "Memo2", "sign": "signs/note_offices", "sign_size": Vector2(0.32, 0.32), "size": Vector3(0.1, 0.4, 0.4), "note_key": "offices_memo_m", "note_title": "A memo signed M.", "note_text": "Someone called M. works here. M. also left a note on the fridge in the Nowhere House."})
	Readable.create(self, _c(21.75, 7.9, 1.25), 90.0, "A memo", ["MEMO: the corridor behind the numbered doors is not to be used as a shortcut.", "It is not a shortcut. It is the same corridor."], {"name": "Memo3", "sign": "signs/note_offices", "sign_size": Vector2(0.32, 0.32), "size": Vector3(0.1, 0.4, 0.4)})
	# the monitor that is watching you back
	Readable.create(self, _c(3.6, 2.7, 0.95), 180.0, "A monitor", ["The monitor shows snow.", "In the snow, for a moment, the back of somebody's head. They are sitting where you are sitting."], {"name": "Monitor", "size": Vector3(0.5, 0.5, 0.5), "note_key": "offices_monitor", "note_title": "The monitor", "note_text": "Every monitor in the Waiting Halls shows snow. One of them showed the back of a head, in this chair."})
	Kit.sign(self, "signs/exit_wrong", _c(14.0, 2.08, 2.3), 180.0, Vector2(0.8, 0.32), {"unshaded": true})
	Kit.sign(self, "signs/exit", _c(2.08, 5.5, 2.3), -90.0, Vector2(0.8, 0.32), {"unshaded": true})


# --- the waiting room (x 14-26, z 10-20) ---------------------------------------------

func _waiting_room() -> void:
	# the number being served, on the north wall
	Props.place(self, "number_display", _c(23.0, 10.2, 2.0), 180.0, 1.8, {"collision": "none"})
	display_label = Kit.label(self, "", _c(23.0, 10.42, 2.0), 180.0, 22, Color(1.0, 0.35, 0.25), "display", {"pixel_size": 0.011, "outline": 2})
	_update_display()
	Kit.sign(self, "signs/your_call", _c(23.0, 10.06, 1.35), 180.0, Vector2(0.9, 0.36))
	Readable.create(self, _c(23.0, 10.4, 1.5), 180.0, "Now serving", ["NOW SERVING: a number that is not yours.", "It has never been yours. It has been very close."], {"name": "DisplayRead", "size": Vector3(1.2, 0.8, 0.3)})
	# take a number
	Props.place(self, "ticket_dispenser", _c(16.5, 10.55), 180.0, 1.0)
	Kit.sign(self, "signs/take_a_number", _c(16.5, 10.06, 2.05), 180.0, Vector2(0.9, 0.45))
	Interactable.make(self, _c(16.5, 10.6, 1.0), Vector3(0.6, 1.2, 0.6), "Take a number", _on_ticket, {"name": "Ticket"})
	# rows of chairs facing the display
	for z in [13.5, 15.5, 17.5]:
		for x in [17.0, 23.0]:
			Props.place(self, "waiting_chairs", _c(x, z), 0.0, 1.0)
			Interactable.make(self, _c(x, z, 0.5), Vector3(2.4, 0.9, 0.8), "Sit and wait", _on_sit, {"name": "Chairs_%d_%d" % [int(x), int(z)]})
	# the machines
	Props.place(self, "vending_machine", _c(25.4, 18.3), 90.0, 1.0)
	Interactable.make(self, _c(25.3, 18.3, 1.0), Vector3(0.8, 1.8, 1.0), "Press B4", _on_vending, {"name": "Vending"})
	Kit.light(self, _c(24.6, 18.3, 1.2), Color(0.8, 0.9, 1.0), 0.6, 3.0)
	Props.place(self, "water_cooler", _c(25.4, 15.0), 90.0, 1.0)
	Interactable.make(self, _c(25.3, 15.0, 0.9), Vector3(0.6, 1.4, 0.6), "Drink", _on_drink, {"name": "Cooler2"})
	for p in [Vector2(14.6, 10.6), Vector2(25.4, 10.6), Vector2(14.6, 19.4), Vector2(25.4, 19.4)]:
		Props.place(self, "potted_plant_fake", _c(p.x, p.y), 0.0, 1.0, {"collision": "none"})
	# the clock: half past five, like every clock you have ever trusted
	Kit.sign(self, "metal/clock_face", _c(14.08, 15.0, 2.0), -90.0, Vector2(0.7, 0.7))
	Readable.create(self, _c(14.2, 15.0, 2.0), -90.0, "The clock", ["Half past five.", "You wait a while, to be fair to it. Half past five."], {"name": "Clock", "size": Vector3(0.2, 0.7, 0.7), "note_key": "offices_clock", "note_title": "Half past five", "note_text": "The clock in the Waiting Halls says half past five. So does the one in the Nowhere House. So, you suspect, does yours."})
	Kit.sign(self, "signs/exit_wrong", _c(20.5, 10.06, 2.35), 180.0, Vector2(0.8, 0.32), {"unshaded": true})
	Kit.sign(self, "signs/exit_wrong", _c(25.92, 11.9, 2.35), 90.0, Vector2(0.8, 0.32), {"unshaded": true})
	Kit.sign(self, "wall/paper", _c(14.08, 12.0, 1.6), -90.0, Vector2(0.5, 0.7), {"tint": Color(0.9, 0.85, 0.7)})
	Readable.create(self, _c(14.2, 12.0, 1.6), -90.0, "A notice", ["NOTICE TO THE PUBLIC", "Tickets are not transferable. Tickets are not refundable. Tickets are not, strictly, tickets.", "Please have your number ready. Please have your reasons ready."], {"name": "Notice", "size": Vector3(0.2, 0.7, 0.5)})
	for p in [Vector2(17, 12), Vector2(23, 12), Vector2(17, 17.5), Vector2(23, 17.5)]:
		_fluor(p.x, p.y)
	Kit.particles(self, _c(20.0, 15.0, 1.5), "motes", Vector3(5.0, 1.2, 4.5), 30)


# --- the archive (x 2-13, z 10-20) ---------------------------------------------------

func _archive() -> void:
	var rows := [[11.0, 180.0], [13.0, 0.0], [17.0, 180.0], [19.4, 0.0]]
	for r in rows:
		var z: float = r[0]
		var yaw: float = r[1]
		for i in 12:
			var x := 3.2 + i * 0.8
			Props.place(self, "filing_cabinet", _c(x, z), yaw, 1.0)
	# the drawer with your number on it
	var drawer := _c(3.2, 17.0)
	Kit.sign(self, "signs/five_half", drawer + Vector3(0, 1.05, 0.34), 0.0, Vector2(0.18, 0.18))
	Interactable.make(self, drawer + Vector3(0, 0.9, 0.2), Vector3(0.7, 1.2, 0.6), "Open the drawer marked 5½", _on_drawer, {"name": "PhotoDrawer"})
	Kit.light(self, drawer + Vector3(0.6, 1.4, 0.9), Color(1.0, 0.9, 0.7), 0.5, 3.0)
	# labels on the rows, in a filing system nobody explained
	Kit.label(self, "A — HALDEN", _c(7.5, 10.12, 1.9), 180.0, 22, Color(0.2, 0.18, 0.15), "body", {"pixel_size": 0.01})
	Kit.label(self, "HOUSES (NOWHERE)", _c(7.5, 19.9, 1.9), 0.0, 22, Color(0.2, 0.18, 0.15), "body", {"pixel_size": 0.01})
	Readable.create(self, _c(7.5, 10.4, 1.4), 180.0, "A cabinet label", ["HALDEN ARMS, 3rd FLOOR.", "Every flat has a drawer. Flat 5½ has two.", "The second drawer is filed under HOUSES."], {"name": "LabelA", "size": Vector3(1.0, 0.6, 0.4)})
	Readable.create(self, _c(10.0, 13.0, 1.2), 0.0, "A cabinet, ajar", ["Photographs. Hundreds. Families on porches, families at tables, families in fields with no roads.", "None of the faces is a face you know, until it is."], {"name": "Ajar", "size": Vector3(0.8, 0.6, 0.6), "sound": "page"})
	Readable.create(self, _c(6.0, 19.4, 1.2), 0.0, "A cabinet", ["The drawer is full of water.", "There is a photograph floating in it: a bathroom, and someone measuring it."], {"name": "WetDrawer", "size": Vector3(0.8, 0.6, 0.6), "note_key": "offices_wet_drawer", "note_title": "A drawer of water", "note_text": "A filing cabinet full of water, and in it a photograph of someone measuring a bathroom. Forty-one tiles, maybe."})
	for p in [Vector2(5, 12), Vector2(10, 12), Vector2(5, 15), Vector2(10, 15), Vector2(5, 18.2), Vector2(10, 18.2)]:
		_fluor(p.x, p.y, 0.8, 6.0)
	Kit.sign(self, "signs/exit_wrong", _c(12.92, 17.0, 2.3), 90.0, Vector2(0.8, 0.32), {"unshaded": true})


# --- the reception corridor (x 27-38, z 10-13) and the fire door -----------------------

func _reception() -> void:
	Props.place(self, "waiting_chairs", _c(30.0, 10.6), 180.0, 1.0)
	Interactable.make(self, _c(30.0, 10.6, 0.5), Vector3(2.4, 0.9, 0.8), "Sit and wait", _on_sit, {"name": "Chairs_hall"})
	Props.place(self, "potted_plant_fake", _c(35.5, 10.5), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "phone_wall", _c(29.5, 12.9, 1.3), 0.0, 1.0, {"collision": "none"})
	Readable.create(self, _c(29.5, 12.8, 1.3), 0.0, "The wall phone", ["It rings as you reach for it.", "Somebody breathing, then a number read out slowly: five. And a half.", "Then the tone."], {"name": "WallPhone", "size": Vector3(0.4, 0.5, 0.3), "sound": "phone_ring", "note_key": "offices_phone", "note_title": "The wall phone", "note_text": "A wall phone in the Waiting Halls. It rang. Someone read your number out and hung up."})
	# the fire door down to the Halden Arms
	Door.create(self, _c(37.84, 11.5), 90.0, "corridor", "from_stairs", {"kind": "iron", "label": "A fire door. It says NOT AN EXIT.", "name": "FireDoor", "sound": "door_heavy"})
	Kit.sign(self, "signs/exit_wrong", _c(37.9, 11.5, 2.4), 90.0, Vector2(0.8, 0.32), {"unshaded": true})
	Kit.light(self, _c(36.8, 11.5, 2.2), Color(0.9, 1.0, 0.9), 0.7, 4.0)
	add_spawn("from_stairs", _c(36.3, 11.5, 0.1), 90.0)
	for x in [29.0, 33.0, 36.5]:
		_fluor(x, 11.5, 0.85, 6.5)
	Kit.sign(self, "signs/take_a_number", _c(33.0, 10.06, 1.9), 180.0, Vector2(0.9, 0.45))


# --- the break room (x 27-38, z 14-20) and the STAFF ONLY door -------------------------

func _break_room() -> void:
	Props.place(self, "kitchen_counter", _c(29.5, 14.4), 180.0, 1.0)
	Props.place(self, "kitchen_sink", _c(31.0, 14.4), 180.0, 1.0)
	Props.place(self, "fridge", _c(36.8, 14.45), 180.0, 1.0)
	Readable.create(self, _c(36.8, 14.9, 1.3), 180.0, "The fridge", ["A note on the fridge: PLEASE LABEL YOUR FOOD.", "Every container inside is labelled with the same name. It is not a name you can read twice."], {"name": "BreakFridge", "size": Vector3(0.7, 0.8, 0.4), "sign": "signs/note_offices", "sign_size": Vector2(0.3, 0.3)})
	Props.place(self, "tv_crt", _c(30.3, 14.35, 0.92), 180.0, 0.8, {"collision": "none"})
	Props.place(self, "frame_calendar", _c(34.5, 14.06, 1.7), 180.0, 1.0, {"collision": "none"})
	Readable.create(self, _c(34.5, 14.2, 1.7), 180.0, "The calendar", ["Every day on the calendar is the same day.", "Somebody has circled it anyway."], {"name": "Calendar", "size": Vector3(0.5, 0.6, 0.2)})
	Props.place(self, "kitchen_table", _c(32.5, 17.0), 0.0, 1.0)
	Props.place(self, "chair", _c(33.6, 17.0), 90.0, 1.0)
	Props.place(self, "chair", _c(31.4, 17.0), -90.0, 1.0)
	Props.place(self, "mug", _c(32.3, 17.0, 0.78), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "mug", _c(32.8, 17.15, 0.78), 40.0, 1.0, {"collision": "none"})
	Props.place(self, "potted_plant_fake", _c(27.6, 19.4), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "filing_cabinet", _c(28.0, 19.4), 0.0, 1.0)
	Props.place(self, "boxes_moving" if Props.exists("boxes_moving") else "crate_small", _c(37.2, 19.2), 15.0, 0.8)
	# the way back into the house, from the wrong side
	Door.create(self, _c(33.0, 19.84), 0.0, "house", "from_offices", {"kind": "white", "label": "STAFF ONLY", "name": "StaffDoor", "fade_color": Color(0.05, 0.08, 0.16), "fade_duration": 0.9, "sets_flag": "offices_back_way"})
	Kit.label(self, "STAFF ONLY", _c(33.0, 19.86, 2.35), 0.0, 26, Color(0.85, 0.2, 0.15), "display", {"pixel_size": 0.011})
	add_spawn("from_house", _c(33.0, 18.4, 0.1), 0.0)
	Readable.create(self, _c(30.6, 19.86, 1.5), 0.0, "A poster", ["A poster of a field at night. A house in it, one window lit.", "Underneath: YOUR HOME IS OUR PRIORITY."], {"name": "Poster", "size": Vector3(0.9, 1.0, 0.2), "sign": "props/painting_house", "sign_size": Vector2(0.8, 0.8)})
	for x in [29.5, 35.0]:
		_fluor(x, 17.0, 0.9, 6.5)
	Kit.light(self, _c(30.3, 14.7, 1.4), Color(0.7, 0.8, 1.0), 0.4, 3.0)


# --- the numbered doors (x 14-26, z 21-25) --------------------------------------------

func _numbered_doors() -> void:
	# 0000: a door with nothing behind it
	Props.place(self, "door_white", _c(15.5, 24.85), 0.0, 1.0)
	Kit.label(self, "0000", _c(15.5, 24.84, 2.5), 0.0, 30, Color(0.2, 0.18, 0.15), "display", {"pixel_size": 0.011})
	Readable.create(self, _c(15.5, 24.6, 1.1), 0.0, "Door 0000", ["The door is locked.", "A voice behind it, very politely: \"Please wait.\""], {"name": "Door0000", "size": Vector3(1.0, 2.0, 0.4), "sound": "door_locked"})
	# 0001: the same waiting room, again
	Door.create(self, _c(17.5, 24.84), 0.0, "offices", "default", {"kind": "white", "label": "0001", "name": "Door0001", "fade_duration": 0.5, "on_open": func(_d: Node) -> void:
		Game.bump("offices_door_0001")
		if Game.count("offices_door_0001") == 2:
			Game.note("offices_0001", "Door 0001", "Door 0001 opens onto the waiting room you were just in. The people waiting in it have not noticed you leave.")})
	Kit.label(self, "0001", _c(17.5, 24.84, 2.5), 0.0, 30, Color(0.2, 0.18, 0.15), "display", {"pixel_size": 0.011})
	# 0604: the difference (the hallway's far end)
	Door.create(self, _c(22.5, 24.84), 0.0, "hallway", "end", {"kind": "dark", "label": "0604", "name": "Door0604", "requires_item": "door_code", "locked_text": "This is not your number. You know whose it is. You have not written it on your hand yet.", "fade_duration": 1.0})
	Kit.label(self, "0604", _c(22.5, 24.84, 2.5), 0.0, 30, Color(0.2, 0.18, 0.15), "display", {"pixel_size": 0.011})
	# 5½: your number, when it is called
	Door.create(self, _c(24.5, 24.84), 0.0, "nexus", "from_offices", {"kind": "white", "label": "5½ — your number", "name": "DoorYours", "requires_flag": "number_called", "locked_text": "Please wait until your number is called.", "fade_color": Color(0.06, 0.05, 0.12), "fade_duration": 0.9, "sets_flag": "offices_number_used"})
	Kit.sign(self, "signs/five_half", _c(24.5, 24.84, 2.5), 0.0, Vector2(0.32, 0.32))
	Kit.light(self, _c(24.5, 23.6, 2.3), Color(1.0, 0.95, 0.8), 0.8, 4.0)
	add_spawn("from_nexus", _c(24.5, 23.3, 0.1), 0.0)
	Kit.sign(self, "signs/exit_wrong", _c(20.0, 24.9, 2.4), 0.0, Vector2(0.8, 0.32), {"unshaded": true})
	Readable.create(self, _c(20.0, 21.14, 1.5), 180.0, "A sign", ["DOORS ARE SERVED IN ORDER.", "THE ORDER IS NOT NUMERICAL."], {"name": "DoorsSign", "size": Vector3(1.0, 0.6, 0.2), "sign": "wall/paper", "sign_size": Vector2(0.6, 0.4)})
	for x in [16.0, 24.0]:
		_fluor(x, 23.0, 0.85, 6.0)


# --- the corridor that goes round (x 2-38, z 26-29) ---------------------------------------

func _loop_corridor() -> void:
	for x in [5.0, 9.8, 14.6, 24.2, 29.0, 33.8]:
		Props.place(self, "desk_office", _c(x, 26.5), 180.0, 1.0)
		Props.place(self, "chair_office", _c(x, 27.4), 0.0, 1.0)
		Props.place(self, "tv_crt", _c(x - 0.2, 26.45, 0.76), 180.0, 0.5, {"collision": "none"})
	for x in [7.0, 12.0, 17.0, 22.0, 27.0, 32.0]:
		Props.place(self, "filing_cabinet", _c(x, 28.55), 0.0, 1.0)
		Props.place(self, "filing_cabinet", _c(x + 0.8, 28.55), 0.0, 1.0)
	Props.place(self, "potted_plant_fake", _c(3.0, 28.5), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "potted_plant_fake", _c(37.0, 28.5), 0.0, 1.0, {"collision": "none"})
	for x in [4.0, 9.0, 14.0, 19.0, 24.0, 29.0, 34.0]:
		_fluor(x, 27.5, 0.85, 6.5)
	# the seam: east end onto west end, both ways
	SeamlessTeleport.link(self, _c(36.6, 27.5), -90.0, _c(3.4, 27.5), -90.0, Vector3(3.0, H, 0.6), {"name": "LoopSeam", "count_flag": "offices_loops", "on_teleport": _on_loop})
	# a desk that is, on the second visit, yours
	if visit_count >= 2:
		Props.place(self, "photo_1", _c(24.6, 26.5, 0.8), 180.0, 0.6, {"collision": "none"})
		Readable.create(self, _c(24.2, 26.6, 0.9), 0.0, "A desk", ["Your name is on the desk. Your photograph is on the desk.", "The chair has been sat in. Recently. By someone your height."], {"name": "YourDesk", "size": Vector3(1.2, 0.8, 0.8), "note_key": "offices_your_desk", "note_title": "Your desk", "note_text": "There is a desk in the corridor that goes round with your name on it. Somebody has been doing your job."})
	Readable.create(self, _c(20.0, 26.14, 1.6), 180.0, "A sign", ["THIS CORRIDOR IS NOT A SHORTCUT.", "Walk it %d times and see." % (3 + Game.count("offices_loops"))], {"name": "LoopSign", "size": Vector3(1.0, 0.6, 0.2), "sign": "wall/paper", "sign_size": Vector2(0.6, 0.4)})


# --- presences ------------------------------------------------------------------------------

func _presences() -> void:
	Usher.spawn(self, _c(12.0, 5.5), {"appear_delay": 4.0, "radius": 30.0})
	Dog.maybe_spawn(self, _c(20.0, 18.5, 0.1))
	# a shadow at a desk that is closer every time you look away
	_shadow_spots = [_c(22.6, 3.75), _c(15.4, 3.75), _c(8.2, 3.75), _c(8.2, 5.5)]
	if Props.exists("figure_shadow"):
		shadow = Props.place(self, "figure_shadow", _shadow_spots[0], 0.0, 1.0, {"collision": "none", "name": "DeskShadow"})
		LookAway.create(self, _shadow_spots[0], _on_shadow_unseen, {"delay": 2.0, "radius": 16.0, "once": false, "require_seen_first": true, "name": "ShadowWatch"})


# --- the number ---------------------------------------------------------------------------------

func _update_display() -> void:
	if display_label == null:
		return
	if Game.has_flag("number_called"):
		display_label.text = "NOW SERVING\n5½"
	else:
		display_label.text = "NOW SERVING\n%04d" % (serving % 10000)


func _process(delta: float) -> void:
	_tick += delta
	if _tick > 6.5:
		_tick = 0.0
		if not Game.has_flag("number_called"):
			serving = (serving + 1 + (randi() % 3)) % 10000
			Game.bump("offices_serving", serving - Game.count("offices_serving"))
			_update_display()
			if Game.chance(0.35):
				Audio.sfx("ui_blip", _c(23.0, 10.4, 2.0), -14.0)


func _on_ticket(_p: Node, _it: Node) -> void:
	Audio.sfx("page", _c(16.5, 10.6, 1.0), -8.0)
	if Game.has_flag("offices_ticket"):
		Game.toast.emit("The machine gives you the same number again. 5½.")
		return
	Game.set_flag("offices_ticket", true)
	if World.hud:
		await World.hud.say("", ["The machine gives you a ticket.", "Your number is 5½.", "The sign says NOW SERVING %04d. It changes while you watch. It does not get closer." % (serving % 10000)])
	Game.note("offices_ticket", "A number", "The Waiting Halls gave you a number: 5½. The number being served is always something else. Sit and wait. It comes round.")


func _on_sit(_p: Node, _it: Node) -> void:
	if not Game.has_flag("offices_ticket"):
		if World.hud:
			await World.hud.say("", ["You sit. The chair is warm.", "A sign says PLEASE TAKE A NUMBER. You do not have a number."])
		return
	if Game.has_flag("number_called"):
		if World.hud:
			await World.hud.say("", ["You sit. NOW SERVING: 5½.", "That is you. Door 5½ is behind you, through the waiting room, and it is not locked any more."])
		return
	Game.bump("offices_waits")
	var n := Game.count("offices_waits")
	Audio.sfx("step_carpet", _c(20, 15, 0.5), -12.0)
	if n >= WAITS_NEEDED:
		serving = 5
		Game.set_flag("number_called", true)
		_update_display()
		Audio.sfx("ui_confirm", _c(23.0, 10.4, 2.0), -4.0)
		if World.hud:
			await World.hud.say("", ["You wait. You wait some more. The numbers go past like stations.", "A chime. NOW SERVING: 5½.", "Nobody else stands up."])
		Game.toast.emit("NOW SERVING: 5½. Door 5½ is open.")
		Game.note("offices_called", "Your number", "They called 5½ in the Waiting Halls. Door 5½ opens onto the Anteroom. The other doors are still waiting for their numbers.")
	else:
		serving = (serving + 7 + n * 3) % 10000
		Game.bump("offices_serving", serving - Game.count("offices_serving"))
		_update_display()
		var lines := [["You sit. The number changes. It is not yours.", "The person beside you has been called three times and has not moved."], ["You wait. The lights hum a chord.", "The number changes to a number with more digits than the sign has room for, and then back."]]
		if World.hud:
			await World.hud.say("", lines[(n - 1) % lines.size()])


func _on_drawer(_p: Node, _it: Node) -> void:
	Audio.sfx("creak", _c(3.2, 17.0, 0.9), -8.0)
	if Game.has_flag("offices_photo_taken"):
		if World.hud:
			await World.hud.say("", ["The drawer is empty now.", "There is a rectangle of less dust where the photograph was."])
		return
	Game.set_flag("offices_photo_taken", true)
	if World.hud:
		await World.hud.say("", ["Inside: one photograph, filed under your number.", "A family on a porch. One of them has been carefully scratched out.", "There is an empty frame in a house you know. You know exactly which wall."])
	Game.gain_item("photo")
	Audio.sfx("photo_click", _c(3.2, 17.0, 1.0), -6.0)


func _on_vending(_p: Node, _it: Node) -> void:
	Audio.sfx("ui_blip", _c(25.4, 18.3, 1.0), -10.0)
	if Game.has_flag("offices_biscuit"):
		Game.toast.emit("B4 is empty. The machine hums to itself.")
		return
	Game.set_flag("offices_biscuit", true)
	if World.hud:
		await World.hud.say("", ["The machine takes no money. It has been waiting for someone to press B4.", "Something drops into the tray with the noise of a bone."])
	Game.gain_item("dog_biscuit")


func _on_drink(_p: Node, _it: Node) -> void:
	Audio.sfx("drink", player_pos(), -8.0)
	Game.bump("offices_drinks")
	if Game.count("offices_drinks") == 3:
		Game.toast.emit("The water tastes of the bath. The bath in the flat, specifically.")
	else:
		Game.toast.emit("Warm water. A paper cone.")


func _on_copy(_p: Node, _it: Node) -> void:
	copies += 1
	Audio.sfx("photo_click", _c(22.4, 2.75, 1.0), -6.0)
	Game.bump("offices_copies")
	if Game.count("offices_copies") == 3:
		Game.note("offices_copier", "The photocopier", "The photocopier in the Waiting Halls prints a face every third time. Nobody has put a face on the glass.")
		Game.toast.emit("The copier prints a face. Nobody put a face on the glass.")
	else:
		Game.toast.emit("The copier prints a blank page, warm.")


func _on_shadow_unseen(_l: Node) -> void:
	if shadow == null or not is_instance_valid(shadow):
		return
	_shadow_step += 1
	if _shadow_step >= _shadow_spots.size():
		shadow.queue_free()
		shadow = null
		Game.bump("usher_sightings")
		Game.toast.emit("The chair by the door is warm.")
		return
	shadow.position = _shadow_spots[_shadow_step]
	var la := get_node_or_null("ShadowWatch")
	if la:
		la.position = _shadow_spots[_shadow_step]


func _on_loop(_p: Node) -> void:
	var n := Game.count("offices_loops")
	if n == 1:
		Game.toast.emit("The corridor goes round. The same desk, the same plant, the same nothing on the monitor.")
	elif n == 3:
		if Props.exists("figure_shadow"):
			Props.place(self, "figure_shadow", _c(29.0, 27.4), 180.0, 1.0, {"collision": "none", "name": "LoopShadow"})
		Game.note("offices_loop", "The corridor that goes round", "Behind the numbered doors there is a corridor that is its own far end. On the third time round there was somebody at one of the desks, working.")
		Game.toast.emit("Somebody is at one of the desks now. They were not, before.")
	elif n == 6:
		Game.toast.emit("The plant has been watered. You did not water it.")


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if n == 1:
		Game.note("waiting_halls", "The Waiting Halls", "An office where nothing is done, lit like a dentist's. Take a number. The number being served is never yours until, quite suddenly, it is.")
	if spawn_id == "from_house" and not Game.has_note("offices_from_house"):
		Game.note("offices_from_house", "STAFF ONLY", "The kitchen door of the Nowhere House opens onto an office break room. Somebody has labelled every container in the fridge with the same unreadable name.")
