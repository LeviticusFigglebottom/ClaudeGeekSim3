extends AreaBase
## The Nowhere House — a house alone in a dark field with no road. Each visit
## it is a slightly different house (myhouse.wad, with love):
##   visit 1  the house
##   visit 2  the house, mirrored; a door in the hall that was not there; the
##            Tin Mouse in the dog's bowl
##   visit 3+ the bathroom is enormous; the kitchen has a STAFF ONLY door into
##            the Waiting Halls; the basement stair goes down to the Cistern
## Always: the dog, the journal, the photographs, the backwards door, the attic.

const CELL := 1.5
const H := 2.7
var mirrored := false
var _origin := Vector3(-12.0, 0, -9.0)
var journal_lines: Array = []
var basement_seam: SeamlessTeleport = null
var bedroom_seam: SeamlessTeleport = null
var attic_ladder: Node3D = null
var empty_frame: Interactable = null


func build() -> void:
	mirrored = (visit_count == 2)
	var big_bath := visit_count >= 3
	Realm.apply(self, "house", {"ambient_energy": 0.7, "sky_opts": {"detail_strength": 0.9, "detail_scale": 10.0}})
	_field()
	# --- rooms (thin-walled maps; 'O' cells join rooms) ---
	var hall := _room([
		"D.D",
		"..",
		"..",
		"OO",
		"c.",
		".x",
		"w.",
		".O",
		"O.",
		".O",
		"D ",
	], 6, 0, {"floor": "wood/planks_house", "wall": "wall/wallpaper_damask"})
	var living := _room([
		"t.f..",
		"j...O",
		"..s.p",
	], 1, 2, {"floor": "wall/carpet_house", "wall": "wall/wallpaper_floral"})
	var kitchen := _room([
		"r.k..",
		"w...O",
		"d.t..",
	], 1, 7, {"floor": "wall/tile_checker", "wall": "wall/plaster_house", "ceiling": "wall/plaster_white"})
	var bed_a := _room([
		"..w..m",
		"O.b...",
		"W....n",
	], 8, 2, {"floor": "wall/carpet_house", "wall": "wall/wallpaper_brown"})
	var bath := _room([
		"s.",
		"O.",
		"a.",
	], 8, 6, {"floor": "wall/tile_checker", "wall": "wall/tile_bath", "ceiling": "wall/plaster_white"})
	var spur := _room(["..O"], 8, 9, {"floor": "wood/planks_house", "wall": "wall/wallpaper_damask"})
	var bed_b := _room([
		"..w",
		"b..",
		"O.h",
	], 11, 7, {"floor": "wall/carpet_house", "wall": "wall/wallpaper_floral"})
	var hidden := _room([
		"...",
		"..u",
	], 3, 5, {"floor": "wood/planks_dark", "wall": "wall/hallway_grey", "ceiling": "wall/hallway_black"})

	# --- hall ---
	var front_door: Vector3 = _cellpos(6, 10)
	var back_door := _cellpos(6, 0)
	var basement_door := _cellpos(8, 0)
	Props.place(self, "door_white", front_door + _v(0, 0, CELL * 0.5 - 0.2), _yaw(0.0), 1.0, {"collision": "none", "name": "FrontDoorProp"})
	var leaf := Props.part(get_node("FrontDoorProp"), "Leaf")
	if leaf:
		leaf.rotation.y = deg_to_rad(-100.0)
	Props.place(self, "coat_rack", _cellpos(7, 8) + _v(0.45, 0, 0), 0.0, 1.0)
	var clock: Vector3 = hall.first.call("c")
	var gc := Props.place(self, "clock_grandfather", clock + _v(-CELL * 0.5 + 0.25, 0, 0), _yaw(-90.0), 1.0)
	var pend := Props.part(gc, "Pendulum")
	if pend:
		var cw := Clockwork.create(gc, pend.position, {"mode": "oscillate", "axis": Vector3(0, 0, 1), "amplitude_deg": 14.0, "period": 2.0, "name": "PendulumSwing"})
		pend.get_parent().remove_child(pend)
		cw.body.add_child(pend)
		pend.position = Vector3.ZERO
	Readable.create(self, clock + _v(-CELL * 0.5 + 0.3, 1.5, 0), _yaw(-90.0), "The grandfather clock", ["The clock says half past five.", "It has said half past five every time you have looked. It ticks anyway."], {"name": "ClockRead", "size": Vector3(0.7, 1.4, 0.7), "note_key": "house_clock", "note_title": "The clock in the hall", "note_text": "Half past five. Always. It ticks anyway."})
	for i in 4:
		Kit.light(self, _cellpos(7, 1 + i * 3) + Vector3(-0.75, H - 0.15, 0), Color(1.0, 0.88, 0.7), 1.0, 6.0)
	# photographs along the hall (they change)
	var photos := ["photo_0", "photo_1", "photo_2"]
	if visit_count == 2:
		photos = ["photo_1", "photo_3", "photo_2"]
	elif visit_count >= 3:
		photos = ["photo_4", "photo_3", "photo_3"]
	for i in 3:
		Props.place(self, photos[i], _cellpos(6, 3 + i * 2) + _v(-CELL * 0.5 + 0.03, 1.6, 0), _yaw(-90.0), 1.0, {"collision": "none"})
	if visit_count == 2 and not Game.has_note("house_photos_2"):
		Game.note("house_photos_2", "The photographs, second visit", "One of the family is scratched out now. The porch in the middle photograph is empty. Somebody moved the photographs, and everything else, to the other side of the house.")
	if visit_count >= 3 and not Game.has_note("house_photos_3"):
		Game.note("house_photos_3", "The photographs, third visit", "There is an extra person on the porch. Two of the frames show nobody at all. The house is running out of family.")
	# the door that was not there (visit 2+)
	var xdoor: Vector3 = hall.first.call("x")
	if visit_count >= 2:
		_bedroom_corridor(xdoor)
	else:
		Kit.sign(self, "wood/door_dark", xdoor + _v(CELL * 0.5 - 0.02, 1.1, 0), _yaw(90.0), Vector2(0.9, 2.1), {"tint": Color(0.35, 0.3, 0.3)})
		Readable.create(self, xdoor + _v(CELL * 0.5 - 0.1, 1.1, 0), _yaw(90.0), "A door-shaped stain", ["The wallpaper here is a slightly different colour, in the shape of a door.", "There is no door."], {"name": "DoorStain", "size": Vector3(0.3, 2.0, 1.0)})
	# the backwards door (always): a door you can only enter walking backwards
	var wdoor: Vector3 = hall.first.call("w")
	Kit.sign(self, "wood/door_dark", wdoor + _v(-CELL * 0.5 + 0.02, 1.1, 0), _yaw(-90.0), Vector2(0.9, 2.1), {"tint": Color(0.6, 0.55, 0.5)})
	Kit.label(self, "?", wdoor + _v(-CELL * 0.5 + 0.03, 1.95, 0), _yaw(-90.0), 32, Color(0.5, 0.45, 0.4), "display", {"pixel_size": 0.01})
	var hidden_in: Vector3 = hidden.first.call("u")
	var back_trig := Kit.trigger(self, wdoor + _v(-0.2, 1.0, 0), Vector3(1.0, 2.2, 1.2), _on_backwards, {"name": "BackwardsTrigger"})
	back_trig.set_meta("dest", hidden_in + _v(-0.4, 0.0, 0))
	Readable.create(self, wdoor + _v(-CELL * 0.5 + 0.1, 1.1, 0), _yaw(-90.0), "A door with no handle", ["A door with no handle on this side.", "There is no handle on the other side either. You get the feeling it opens for people who are not looking at it."], {"name": "BackDoorRead", "size": Vector3(0.3, 2.0, 1.0)})
	# hidden room contents
	Props.place(self, "chair", hidden.first.call("u") + _v(-1.4, 0, 0.2), _yaw(90.0), 1.0)
	Usher.spawn(self, hidden.first.call("u") + _v(-1.4, 0, 0.2), {"start_visible": true, "vanish_delay": 4.0, "radius": 6.0})
	Readable.create(self, _cellpos(3, 5) + _v(0.2, 1.4, -CELL * 0.5 + 0.1), _yaw(0.0), "Writing on the wall", ["YOU CAME IN BACKWARDS. GOOD.", "THIS ROOM IS NOT ON THE PLAN. NEITHER ARE YOU."], {"name": "HiddenWriting", "size": Vector3(1.2, 1.0, 0.2), "note_key": "backwards_room", "note_title": "The backwards room", "note_text": "A room that only opens to people walking backwards. Someone tall was sitting in it, waiting to be looked at."})
	Kit.light(self, _cellpos(4, 5) + Vector3(0, H - 0.3, 0.7), Color(0.6, 0.6, 0.8), 0.6, 4.0)
	var out_trig := Kit.trigger(self, hidden_in + _v(0.4, 1.0, 0), Vector3(0.5, 2.2, 1.2), _on_backwards_out, {"name": "BackwardsOut"})
	out_trig.set_meta("dest", wdoor + _v(0.3, 0.0, 0))
	Kit.label(self, "out", hidden_in + _v(CELL * 0.5 - 0.05, 1.8, 0), _yaw(90.0), 28, Color(0.5, 0.5, 0.6), "body", {"pixel_size": 0.01})

	# --- mud room, back door, basement ---
	Props.place(self, "door_white", back_door + _v(0, 0, -CELL * 0.5 + 0.2), _yaw(180.0), 1.0, {"collision": "none", "name": "BackDoorProp"})
	var bleaf := Props.part(get_node("BackDoorProp"), "Leaf")
	if bleaf:
		bleaf.rotation.y = deg_to_rad(-100.0)
	Props.place(self, "shoe_pile" if Props.exists("shoe_pile") else "crate_small", back_door + _v(0.55, 0, 0.5), 20.0, 0.6, {"collision": "none"})
	_basement(basement_door)

	# --- living room ---
	var tv_pos: Vector3 = living.first.call("t") + _v(0, 0, -CELL * 0.5 + 0.45)
	Props.place(self, "dresser", tv_pos, _yaw(0.0), 0.9)
	var tv := Props.place(self, "tv_crt", tv_pos + _v(0, 0.9, 0), _yaw(180.0), 1.0, {"collision": "none"})
	var screen := Props.part(tv, "Screen")
	if screen is MeshInstance3D:
		var face := visit_count >= 2
		(screen as MeshInstance3D).set_surface_override_material(0, Kit.mat("props/tv_face", {"unshaded": true, "emission": Color(0.4, 0.4, 0.4), "emission_energy": 0.5}) if face else Kit.static_mat({"brightness": 0.7}))
	Kit.light(self, tv_pos + _v(0, 1.3, 1.0), Color(0.7, 0.8, 1.0), 0.7, 5.0)
	Readable.create(self, tv_pos + _v(0, 1.2, 0), _yaw(0.0), "The television", ["The television is on. Nobody turned it on.", "It shows snow." if visit_count < 2 else "It shows a face in the snow. The face is watching a programme about you."], {"name": "HouseTV", "size": Vector3(0.9, 0.7, 0.7)})
	var frames: Vector3 = living.first.call("f")
	Props.place(self, "painting_house", frames + _v(0, 1.8, -CELL * 0.5 + 0.03), _yaw(0.0), 0.9, {"collision": "none"})
	Readable.create(self, frames + _v(0, 1.8, -CELL * 0.5 + 0.1), _yaw(0.0), "The painting", ["A painting of this house, in this field, at night.", "In the painting, the light in the attic is on."], {"name": "HousePainting", "size": Vector3(1.0, 1.0, 0.2)})
	# the empty frame
	empty_frame = Interactable.make(self, frames + _v(1.5, 1.6, -CELL * 0.5 + 0.1), Vector3(0.6, 0.6, 0.2), "An empty frame", _on_frame, {"name": "EmptyFrame"})
	if Game.has_flag("photo_returned"):
		Props.place(empty_frame, "photo_2", Vector3(0, 0, -0.07), 0.0, 1.0, {"collision": "none"})
		empty_frame.prompt = "The photograph, returned"
	else:
		Kit.box(empty_frame, Vector3(0, 0, -0.05), Vector3(0.5, 0.5, 0.04), "wood/planks_dark", {"solid": false})
		Kit.box(empty_frame, Vector3(0, 0, -0.075), Vector3(0.42, 0.42, 0.01), "wall/paper", {"solid": false, "tint": Color(0.8, 0.78, 0.7)})
	var shelf: Vector3 = living.first.call("j") + _v(-CELL * 0.5 + 0.2, 0, 0)
	Props.place(self, "bookshelf", shelf, _yaw(-90.0), 1.0)
	_journal(shelf + _v(0.35, 1.2, 0))
	var sofa: Vector3 = living.first.call("s")
	Props.place(self, "sofa", sofa + _v(0, 0, 0.3), _yaw(0.0), 1.0)
	Props.place(self, "rug_house", living.first.call("f") + _v(0, 0, 1.4), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "lamp_floor", living.first.call("p") + _v(0.3, 0, 0.2), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, living.first.call("p") + _v(0.3, 1.8, 0.2), Color(1.0, 0.85, 0.6), 1.1, 6.5)
	Props.place(self, "window_night", living.first.call("p") + _v(CELL * 0.5 - 0.08, 1.5, -0.2), _yaw(-90.0), 1.0, {"collision": "none"})
	Props.place(self, "telephone", living.first.call("s") + _v(1.6, 0.0, -0.4), 0.0, 1.0, {"collision": "none"})

	# --- kitchen ---
	var fridge: Vector3 = kitchen.first.call("r") + _v(0, 0, -CELL * 0.5 + 0.36)
	Props.place(self, "fridge", fridge, _yaw(0.0), 1.0)
	Readable.create(self, fridge + _v(0, 1.3, 0.38), _yaw(0.0), "The note on the fridge", ["Dear whoever is reading this:", "the bathroom got bigger again. I moved the photos.", "Feed the dog.", "  - M."], {"name": "HouseFridgeNote", "sign": "signs/note_house", "sign_size": Vector2(0.4, 0.4), "size": Vector3(0.5, 0.5, 0.1), "note_key": "house_fridge", "note_title": "M.'s note", "note_text": "The bathroom got bigger again. Feed the dog. - M."})
	var counter: Vector3 = kitchen.first.call("k") + _v(0, 0, -CELL * 0.5 + 0.32)
	Props.place(self, "kitchen_counter", counter, _yaw(0.0), 1.0)
	Props.place(self, "kitchen_sink", counter + _v(1.6, 0, 0), _yaw(0.0), 1.0)
	Props.place(self, "stove", counter + _v(-1.4, 0, 0), _yaw(0.0), 1.0)
	Props.place(self, "cupboard" if Props.exists("cupboard") else "dresser", counter + _v(0, 1.6 if Props.exists("cupboard") else 0.0, 0), _yaw(0.0), 0.8, {"collision": "none"})
	Interactable.make(self, counter + _v(0, 1.7, 0.3), Vector3(1.0, 0.6, 0.4), "Open the cupboard", _on_cupboard, {"name": "Cupboard"})
	Props.place(self, "frame_calendar", kitchen.first.call("k") + _v(1.4, 1.8, -CELL * 0.5 + 0.03), _yaw(0.0), 1.0, {"collision": "none"})
	var table: Vector3 = kitchen.first.call("t") + _v(0.2, 0, 0)
	Props.place(self, "kitchen_table" if Props.exists("kitchen_table") else "table_round", table, 0.0, 1.0)
	Props.place(self, "chair", table + _v(0.9, 0, 0), _yaw(90.0), 1.0)
	Props.place(self, "chair", table + _v(-0.9, 0, 0), _yaw(-90.0), 1.0)
	var bowl: Vector3 = kitchen.first.call("d") + _v(-CELL * 0.5 + 0.4, 0, 0.3)
	Props.place(self, "dog_bowl" if Props.exists("dog_bowl") else "mug", bowl, 0.0, 1.0 if Props.exists("dog_bowl") else 2.0, {"collision": "none"})
	if visit_count >= 2:
		Pickup.create(self, bowl + _v(0, 0.05, 0), {"keepsake": "mouse", "name": "TinMouse"})
	else:
		Readable.create(self, bowl, 0.0, "The dog's bowl", ["The dog's bowl. Empty.", "Something small and tin has been chewing at the rim."], {"name": "BowlRead", "size": Vector3(0.6, 0.4, 0.6)})
	Kit.light(self, kitchen.first.call("t") + _v(0, H - 0.15, 0), Color(1.0, 0.95, 0.85), 1.4, 7.5)
	var wing: Vector3 = kitchen.first.call("w")
	if visit_count >= 3:
		Door.create(self, wing + _v(-CELL * 0.5 + 0.16, 0, 0), _yaw(-90.0), "offices", "from_house", {"kind": "white", "label": "STAFF ONLY", "name": "WingDoor", "fade_color": Color(0.85, 0.76, 0.42), "fade_duration": 0.9, "sets_flag": "found_staff_door"})
		Kit.sign(self, "signs/take_a_number", wing + _v(-CELL * 0.5 + 0.03, 2.3, 0), _yaw(-90.0), Vector2(0.6, 0.3))
		Kit.light(self, wing + _v(0.5, 2.2, 0), Color(1.0, 0.95, 0.6), 0.8, 4.0)
		if not Game.has_note("staff_only"):
			Game.note("staff_only", "STAFF ONLY", "There is a door in the kitchen that says STAFF ONLY. You do not have staff. You do not have a kitchen that size.")
	add_spawn("from_offices", wing + _v(1.0, 0.1, 0), _yaw(-90.0))
	Puzzle.declare(self, "house_visits", "", [], "come back to the house; it changes", {})

	# --- bedroom A ---
	var bed_pos: Vector3 = bed_a.first.call("b") + _v(0, 0, -0.3)
	Props.place(self, "bed_double", bed_pos, _yaw(0.0), 1.0)
	Readable.create(self, bed_pos + _v(0, 0.8, 0), _yaw(0.0), "The bed", ["The bed is made. Nobody has slept in it.", "The pillow has a dent the shape of someone's absence."], {"name": "BedARead", "size": Vector3(1.6, 0.6, 2.0)})
	var w1: Vector3 = bed_a.first.call("w")
	Props.place(self, "window_night", w1 + _v(0, 1.5, -CELL * 0.5 + 0.08), _yaw(180.0), 1.0, {"collision": "none"})
	var mir: Vector3 = bed_a.first.call("m")
	Mirror.create(self, mir + _v(CELL * 0.5 - 0.06, 1.55, 0), _yaw(90.0), "", "default", {"name": "BedroomMirror", "lines_without": ["The mirror shows the bedroom.", "You are not in it. The door behind you is open. You did not open it."]})
	Props.place(self, "dresser", bed_a.first.call("n") + _v(CELL * 0.5 - 0.3, 0, 0), _yaw(90.0), 1.0)
	Props.place(self, "lamp_desk", bed_a.first.call("n") + _v(CELL * 0.5 - 0.3, 1.0, 0), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, bed_a.first.call("n") + _v(0, 1.6, 0), Color(1.0, 0.85, 0.65), 0.9, 6.0)
	var ward: Vector3 = bed_a.first.call("W") + _v(-CELL * 0.5 + 0.35, 0, 0.2)
	var wardrobe := Props.place(self, "wardrobe", ward, _yaw(-90.0), 1.0)
	var wd := Door.create(self, ward + _v(0.45, 0, 0), _yaw(-90.0), "hallway", "side", {"kind": "none", "label": "Look in the wardrobe", "name": "WardrobeDoor", "requires_flag": "hallway_measured", "locked_text": "Coats. Only coats. They smell of the flat.", "fade_duration": 1.0})
	wd.add_box(Vector3(1.0, 2.2, 0.8), Vector3(0, 1.1, 0))

	# --- bathroom (small) ---
	var sink: Vector3 = bath.first.call("s")
	Props.place(self, "sink", sink + _v(0, 0, -CELL * 0.5 + 0.3), _yaw(0.0), 1.0)
	Props.place(self, "bathroom_cabinet" if Props.exists("bathroom_cabinet") else "mirror_wall", sink + _v(0, 1.6, -CELL * 0.5 + 0.06), _yaw(180.0) if Props.exists("bathroom_cabinet") else _yaw(0.0), 1.0, {"collision": "none"})
	Props.place(self, "toilet", sink + _v(0.9, 0, 0.3), _yaw(90.0), 1.0)
	Props.place(self, "bathtub", bath.first.call("a") + _v(0, 0, CELL * 0.5 - 0.42), _yaw(0.0), 1.0)
	var bath_door: Vector3 = _cellpos(8, 7)
	Kit.light(self, bath_door + _v(0.5, H - 0.2, 0), Color(0.8, 0.95, 1.0), 0.8, 5.0)
	if big_bath:
		_big_bathroom(bath_door)
	else:
		Readable.create(self, bath.first.call("a") + _v(0.8, 0.5, 0), 0.0, "Measure the bathroom by eye", ["The bathroom is the size of a bathroom.", "You count the tiles anyway. Forty-one along the long wall. You will count again next time."], {"name": "BathMeasure", "size": Vector3(0.6, 0.6, 0.6), "note_key": "bath_41", "note_title": "Forty-one tiles", "note_text": "The bathroom's long wall has forty-one tiles. Remember that."})

	# --- bedroom B (child's room) ---
	var bb: Vector3 = bed_b.first.call("b") + _v(-0.2, 0, -0.45)
	Props.place(self, "bed_single", bb, _yaw(0.0), 1.0)
	Props.place(self, "window_night", bed_b.first.call("w") + _v(0, 1.5, -CELL * 0.5 + 0.08), _yaw(180.0), 1.0, {"collision": "none"})
	Props.place(self, "crate_small", bed_b.first.call("w") + _v(-0.6, 0, 0.4), 30.0, 0.6)
	Kit.sign(self, "props/painting_house", bed_b.first.call("w") + _v(0.5, 1.2, -CELL * 0.5 + 0.03), _yaw(0.0), Vector2(0.5, 0.5))
	Readable.create(self, bed_b.first.call("w") + _v(0.5, 1.2, -CELL * 0.5 + 0.1), _yaw(0.0), "A crayon drawing", ["A crayon drawing of the house. A crayon drawing of a tall man beside the house.", "The tall man is drawn in one colour, then the other colour, down the middle."], {"name": "Crayon", "size": Vector3(0.5, 0.5, 0.2), "note_key": "crayon", "note_title": "The crayon drawing", "note_text": "A child drew the house, and beside it the tall one, half in each colour."})
	Kit.light(self, bb + _v(0.8, H - 0.2, 0.8), Color(1.0, 0.8, 0.9), 0.8, 5.0)
	var hole: Vector3 = bed_b.first.call("h") + _v(CELL * 0.5 - 0.02, 0, 0.3)
	Kit.mouse_gap(self, hole, _yaw(90.0), Vector2(0.45, 0.4))
	_between_walls(hole)

	# --- attic ---
	_attic(_cellpos(6, 4))
	# --- exterior shell, porch, roof ---
	_exterior()
	# spawns
	var porch_out := front_door + _v(0, 0, 4.5)
	add_spawn("field", front_door + _v(0, 0.1, 9.0), _yaw(0.0))
	add_spawn("default", front_door + _v(0, 0.1, 9.0), _yaw(0.0))
	add_spawn("porch", porch_out + Vector3(0, 0.1, 0), _yaw(0.0))
	Dog.maybe_spawn(self, front_door + _v(2.5, 0.1, 5.0), true)
	if visit_count >= 2 and not Game.has_note("house_mirrored"):
		Game.note("house_mirrored", "The house, the other way round", "Everything is where it was, on the wrong side. Hot is on the left now. Nobody moved the taps.")


# --- helpers ---------------------------------------------------------------

func _room(rows: Array, col: int, row: int, opts: Dictionary) -> Dictionary:
	var o := {"cell": CELL, "height": H, "ceiling": "wall/ceiling_plaster", "door_h": 2.1}
	for k in opts:
		o[k] = opts[k]
	var r := rows
	var w := 0
	for line in rows:
		w = maxi(w, String(line).length())
	if mirrored:
		r = MapBuilder.mirrored(rows)
		o["origin"] = Vector3(-(_origin.x + (col + w) * CELL), 0, _origin.z + row * CELL)
	else:
		o["origin"] = _origin + Vector3(col * CELL, 0, row * CELL)
	return MapBuilder.build(self, r, o)


func _cellpos(col: int, row: int) -> Vector3:
	var p := _origin + Vector3((col + 0.5) * CELL, 0, (row + 0.5) * CELL)
	if mirrored:
		p.x = -p.x
	return p


func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(-x if mirrored else x, y, z)


func _yaw(y: float) -> float:
	return -y if mirrored else y


func _field() -> void:
	var noise_fn := func(x: float, z: float) -> float:
		# flat under the house and porch (a 30 x 26 m pad), rolling beyond it
		var dx := maxf(0.0, absf(x) - 15.0)
		var dz := maxf(0.0, absf(z + 1.0) - 13.0)
		var edge := clampf(Vector2(dx, dz).length() / 6.0, 0.0, 1.0)
		var h := sin(x * 0.11) * 0.25 + cos(z * 0.09 + x * 0.03) * 0.3
		return lerpf(-0.08, h - 0.05, edge)
	Kit.terrain(self, Vector3(0, -0.02, 0), Vector2(220, 220), 44, noise_fn, "nature/grass_dark", {"tile": 3.0})
	# the house sits on a flat pad
	Kit.floor(self, Vector3(0, 0.0, -1.5), Vector2(24, 20), "ground/dirt", {"tile": 3.0})
	Kit.scatter(40, rng, Vector3.ZERO, Vector2(100, 100), func(_i: int, p: Vector3) -> void:
		var d := p.length()
		if d < 18.0:
			return
		var m := "bush_1" if rng.randf() < 0.6 else "rock_1"
		Props.place(self, m, p, rng.randf_range(0, 360), rng.randf_range(0.7, 1.4), {"collision": "none" if m == "bush_1" else "box"}), 18.0)
	Props.place(self, "tree_dead_2", Vector3(16, 0, 6), 20.0, 1.0)
	Props.place(self, "tree_dead_1", Vector3(-20, 0, -14), 200.0, 1.2)
	# the lone door in the field, which is the way back to the Anteroom
	var lone := Vector3(-3, 0, 22)
	Door.create(self, lone, 180.0, "nexus", "from_house", {"kind": "white", "label": "A door standing in the field", "name": "LoneDoor", "fade_duration": 1.0})
	Kit.box(self, lone + Vector3(0, 2.32, 0), Vector3(1.4, 0.12, 0.3), "wood/planks_white")
	Kit.light(self, lone + Vector3(0, 2.6, 1.0), Color(0.8, 0.85, 1.0), 0.8, 6.0)
	add_spawn("from_nexus", lone + Vector3(0, 0.1, -2.0), 0.0)
	# a mailbox with no number
	Kit.box(self, Vector3(3.5, 0.55, 14.0), Vector3(0.08, 1.1, 0.08), "wood/planks_dark")
	Kit.box(self, Vector3(3.5, 1.25, 14.0), Vector3(0.3, 0.3, 0.5), "metal/plate")
	Readable.create(self, Vector3(3.5, 1.25, 14.0), 0.0, "The mailbox", ["The mailbox has no number.", "Someone has written yours on it, in pencil: 5½."], {"name": "Mailbox", "size": Vector3(0.5, 0.6, 0.7), "note_key": "mailbox", "note_title": "The mailbox", "note_text": "The house has no number. It has been given yours."})
	# the sky has a light fitting in it
	if Props.exists("fluorescent_light"):
		Props.place(self, "fluorescent_light", Vector3(10, 75, -30), 20.0, 40.0, {"collision": "none", "emission_energy": 0.3})
	else:
		Kit.box(self, Vector3(10, 75, -30), Vector3(48, 3, 12), "wall/plaster_white", {"solid": false, "unshaded": true, "tint": Color(0.7, 0.7, 0.65)})
	Kit.particles(self, Vector3(0, 2, 8), "fog", Vector3(40, 1, 40), 24)
	Kit.light(self, Vector3(0, 30, 0), Color(0.6, 0.65, 0.8), 0.4, 80.0)


func _exterior() -> void:
	var x0 := _origin.x + 1.0 * CELL - 0.4
	var x1 := _origin.x + 14.0 * CELL + 0.4
	var z0 := _origin.z + 0.0 * CELL - 0.4
	var z1 := _origin.z + 10.0 * CELL + 0.4
	if mirrored:
		var t := x0
		x0 = -x1
		x1 = -t
	var tex := "wood/planks_wall"
	var door_x := _cellpos(6, 10).x
	# south wall with a gap for the front door
	Kit.wall(self, Vector3(x0, 0, z1), Vector3(door_x - 0.8, 0, z1), H + 0.3, tex, {"tint": Color(0.75, 0.7, 0.65)})
	Kit.wall(self, Vector3(door_x + 0.8, 0, z1), Vector3(x1, 0, z1), H + 0.3, tex, {"tint": Color(0.75, 0.7, 0.65)})
	Kit.wall(self, Vector3(x1, 0, z1), Vector3(x1, 0, z0), H + 0.3, tex, {"tint": Color(0.7, 0.65, 0.6)})
	var bx := _cellpos(6, 0).x
	Kit.wall(self, Vector3(x1, 0, z0), Vector3(bx + 0.8, 0, z0), H + 0.3, tex, {"tint": Color(0.7, 0.65, 0.6)})
	Kit.wall(self, Vector3(bx - 0.8, 0, z0), Vector3(x0, 0, z0), H + 0.3, tex, {"tint": Color(0.7, 0.65, 0.6)})
	Kit.wall(self, Vector3(x0, 0, z0), Vector3(x0, 0, z1), H + 0.3, tex, {"tint": Color(0.7, 0.65, 0.6)})
	# roof: two pitched halves
	var w := x1 - x0
	var mid := (x0 + x1) * 0.5
	var depth := (z1 - z0) * 0.5 + 0.6
	Kit.ramp(self, Vector3(mid, H + 0.3, z1 + 0.6), 0.0, w + 1.2, depth, 3.2, "stone/blocks_dark", {"tile": 1.5})
	Kit.ramp(self, Vector3(mid, H + 0.3, z0 - 0.6), 180.0, w + 1.2, depth, 3.2, "stone/blocks_dark", {"tile": 1.5})
	Kit.box(self, Vector3(mid + 5.0, H + 4.0, (z0 + z1) * 0.5), Vector3(1.0, 2.6, 1.0), "brick/dark")
	# porch
	var pz := z1 + 2.2
	Kit.floor(self, Vector3(door_x, 0.15, pz), Vector2(7.0, 4.0), "wood/planks_grey", {"thick": 0.3})
	for px in [door_x - 3.2, door_x + 3.2]:
		Kit.box(self, Vector3(px, 1.5, pz + 1.7), Vector3(0.2, 3.0, 0.2), "wood/planks_grey")
	Kit.box(self, Vector3(door_x, 3.1, pz), Vector3(7.4, 0.2, 4.4), "wood/planks_grey")
	Kit.stairs(self, Vector3(door_x, 0.0, pz + 2.0), 180.0, 3.0, 1, 0.15, 0.6, "wood/planks_grey")
	Props.place(self, "lantern_hanging", Vector3(door_x + 1.2, 3.0, pz), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, Vector3(door_x + 1.2, 2.4, pz), Color(1.0, 0.85, 0.55), 1.6, 9.0)
	Props.place(self, "chair", Vector3(door_x - 2.2, 0.3, pz - 0.5), _yaw(150.0), 1.0)
	# windows on the facade
	Props.place(self, "window_lit", Vector3(door_x - 4.5, 1.6, z1 + 0.05), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "window_night", Vector3(door_x + 4.5, 1.6, z1 + 0.05), 180.0, 1.0, {"collision": "none"})


func _journal(pos: Vector3) -> void:
	var lines: Array = []
	match visit_count:
		1:
			lines = ["Day 1. The bathroom is the same size as yesterday. Good.", "M. says the photographs have moved. M. moves them."]
		2:
			lines = ["Day 2. The house is on the wrong side of itself.", "I checked the taps. Hot is on the left now. Nobody moved the taps.", "There is a door in the hall. I do not remember a door in the hall."]
		_:
			lines = ["Day 3. The bathroom. I measured it. I will not write the number.", "There is a door in the kitchen that says STAFF ONLY. We do not have staff.", "We do not have a kitchen that size."]
	if Game.has_item("page"):
		lines.append("A page has been put back in. The handwriting changes halfway down: the house is the same house. it is the same house. it is the same house.")
	Readable.create(self, pos, _yaw(-90.0), "Read the house journal", lines, {"name": "HouseJournal", "size": Vector3(0.5, 0.6, 0.6), "note_key": "house_journal_%d" % mini(visit_count, 3), "note_title": "The house journal, day %d" % mini(visit_count, 3), "note_text": " ".join(lines)})


func _basement(bdoor: Vector3) -> void:
	# through the doorway at the hall's north end: a stair down eastward, a concrete
	# room, and a second stair that keeps going down
	var top := bdoor + _v(CELL * 0.5, 0, 0)
	var stair_yaw := _yaw(-90.0)
	# a short walled landing so the stairwell has sides and a ceiling
	Kit.floor(self, top + _v(0.4, 0, 0), Vector2(0.8, CELL), "wall/concrete")
	Kit.ceiling(self, top + _v(2.5, 2.4, 0), Vector2(5.0, CELL), "wall/concrete_dark")
	Kit.wall(self, top + _v(0, 0, -CELL * 0.5), top + _v(5.0, 0, -CELL * 0.5), 2.4, "wall/concrete", {"thick": 0.2})
	Kit.wall(self, top + _v(5.0, 0, CELL * 0.5), top + _v(0, 0, CELL * 0.5), 2.4, "wall/concrete", {"thick": 0.2})
	Kit.stairs(self, top + _v(0.8, 0, 0), stair_yaw, 1.4, 10, -0.3, 0.4, "wall/concrete", {"name": "BasementStairs"})
	var room_c := top + _v(7.3, -3.0, 0)
	var m := MapBuilder.build(self, [
		"....",
		"..b.",
		"....",
	], {"cell": CELL, "height": 2.4, "origin": room_c + Vector3(-3.0, 0, -2.25), "y": 0.0, "floor": "wall/concrete", "wall": "wall/concrete_dark", "ceiling": "wall/concrete_dark", "name": "Basement"})
	var b: Vector3 = m.first.call("b")
	Props.place(self, "boxes_moving" if Props.exists("boxes_moving") else "crate", b + Vector3(0.8, 0, -0.8), 20.0, 1.0)
	Props.place(self, "crate_small", b + Vector3(-1.0, 0, 0.9), 70.0, 1.0)
	Kit.light(self, b + Vector3(0, 2.1, 0), Color(1.0, 0.9, 0.7), 0.7, 5.0)
	Readable.create(self, b + Vector3(-1.2, 1.2, -1.4), 0.0, "Writing on the pipe", ["Someone has written on the pipe: DOWN IS THE SAME AS DOWN."], {"name": "PipeWriting", "size": Vector3(0.8, 0.5, 0.3)})
	add_spawn("basement", top + _v(-0.9, 0.1, 0), _yaw(90.0))
	# the second flight, which loops onto the first
	var second_top := b + _v(2.2, 0, 0)
	Kit.stairs(self, second_top, _yaw(-90.0), 1.4, 10, -0.3, 0.4, "wall/concrete", {"name": "BasementStairs2"})
	var bottom := second_top + _v(4.4, -3.0, 0)
	Kit.floor(self, bottom, Vector2(2.4, 2.4), "wall/concrete")
	Kit.ceiling(self, bottom + Vector3(0, 2.4, 0), Vector2(2.4, 2.4), "wall/concrete_dark")
	Kit.wall(self, bottom + _v(-1.2, 0, -1.2), bottom + _v(1.2, 0, -1.2), 2.4, "wall/concrete_dark")
	Kit.wall(self, bottom + _v(1.2, 0, 1.2), bottom + _v(-1.2, 0, 1.2), 2.4, "wall/concrete_dark")
	Kit.wall(self, bottom + _v(1.2, 0, -1.2), bottom + _v(1.2, 0, 1.2), 2.4, "wall/concrete_dark")
	var loops := Game.count("house_basement_loops")
	basement_seam = SeamlessTeleport.create(self, bottom + _v(-0.6, 0, 0), _yaw(-90.0), top + _v(0.4, 0, 0), _yaw(-90.0), Vector3(2.0, 2.5, 0.6), {"name": "BasementSeam", "count_flag": "house_basement_loops", "one_way": false, "on_teleport": _on_basement_loop})
	if loops >= 3:
		basement_seam.enabled = false
		Door.create(self, bottom + _v(1.0, 0, 0), _yaw(-90.0), "cistern", "from_basement", {"kind": "white", "label": "A tiled door at the bottom of the stairs", "name": "CisternDoor", "fade_color": Color(0.2, 0.5, 0.55), "fade_duration": 1.0})
		Kit.light(self, bottom + Vector3(0, 2.0, 0), Color(0.5, 0.9, 0.9), 1.0, 5.0)
	else:
		Kit.light(self, bottom + Vector3(0, 2.0, 0), Color(0.9, 0.85, 0.7), 0.4, 4.0)


func _bedroom_corridor(xdoor: Vector3) -> void:
	# through the door that was not there: a corridor of identical child bedrooms, looping
	var start := xdoor + _v(CELL * 0.5, 0, 0)
	var length := 30.0
	var dirx := -1.0 if mirrored else 1.0
	var c0 := start
	Kit.floor(self, c0 + Vector3(dirx * length * 0.5, 0, 0), Vector2(length, 1.6), "wood/planks_house", {"tile": 1.5})
	Kit.ceiling(self, c0 + Vector3(dirx * length * 0.5, H, 0), Vector2(length, 1.6), "wall/ceiling_plaster")
	Kit.wall(self, c0 + Vector3(0, 0, 0.8), c0 + Vector3(dirx * length, 0, 0.8), H, "wall/wallpaper_damask", {"tile": 1.5})
	for k in 6:
		var rx := c0.x + dirx * (3.0 + k * 4.5)
		# a bedroom on the north side of the corridor
		Kit.floor(self, Vector3(rx, 0, c0.z - 2.6), Vector2(3.6, 3.6), "wall/carpet_house")
		Kit.ceiling(self, Vector3(rx, H, c0.z - 2.6), Vector2(3.6, 3.6), "wall/ceiling_plaster")
		Kit.wall(self, Vector3(rx - 1.8, 0, c0.z - 4.4), Vector3(rx + 1.8, 0, c0.z - 4.4), H, "wall/wallpaper_floral")
		Kit.wall(self, Vector3(rx - 1.8, 0, c0.z - 0.8), Vector3(rx - 1.8, 0, c0.z - 4.4), H, "wall/wallpaper_floral")
		Kit.wall(self, Vector3(rx + 1.8, 0, c0.z - 4.4), Vector3(rx + 1.8, 0, c0.z - 0.8), H, "wall/wallpaper_floral")
		Kit.wall(self, Vector3(rx - 1.8, 0, c0.z - 0.8), Vector3(rx - 0.6, 0, c0.z - 0.8), H, "wall/wallpaper_damask")
		Kit.wall(self, Vector3(rx + 0.6, 0, c0.z - 0.8), Vector3(rx + 1.8, 0, c0.z - 0.8), H, "wall/wallpaper_damask")
		Kit.box(self, Vector3(rx, H - 0.3, c0.z - 0.8), Vector3(1.2, 0.6, 0.2), "wall/wallpaper_damask")
		Props.place(self, "bed_single", Vector3(rx - 0.8, 0, c0.z - 3.4), 0.0, 1.0)
		Props.place(self, "window_night", Vector3(rx + 0.9, 1.5, c0.z - 4.32), 180.0, 1.0, {"collision": "none"})
		Kit.sign(self, "props/painting_house", Vector3(rx + 1.2, 1.3, c0.z - 4.3), 0.0, Vector2(0.5, 0.5))
		Kit.light(self, Vector3(rx, H - 0.2, c0.z - 2.6), Color(1.0, 0.8, 0.9), 0.7, 5.0)
		# corridor wall segments between rooms
		Kit.wall(self, Vector3(rx + 1.8, 0, c0.z - 0.8), Vector3(rx + 2.7, 0, c0.z - 0.8), H, "wall/wallpaper_damask")
		Kit.wall(self, Vector3(rx - 2.7, 0, c0.z - 0.8), Vector3(rx - 1.8, 0, c0.z - 0.8), H, "wall/wallpaper_damask")
	Kit.wall(self, c0 + Vector3(dirx * length, 0, -0.8), c0 + Vector3(dirx * length, 0, 0.8), H, "wall/wallpaper_damask")
	Kit.wall(self, c0 + Vector3(0, 0, -0.8), c0 + Vector3(dirx * (3.0 - 1.8), 0, -0.8), H, "wall/wallpaper_damask")
	Kit.wall(self, c0 + Vector3(dirx * (3.0 + 5 * 4.5 + 2.7), 0, -0.8), c0 + Vector3(dirx * length, 0, -0.8), H, "wall/wallpaper_damask")
	# the corridor sits outside the house: give it an outer shell so nothing shows through
	Kit.box(self, c0 + Vector3(dirx * length * 0.5, H + 0.15, -2.6), Vector3(length + 0.4, 0.3, 6.0), "stone/blocks_dark", {"solid": false})
	Readable.create(self, Vector3(c0.x + dirx * 3.0, 1.0, c0.z - 3.4), 0.0, "The child's bed", ["The same bed. The same window. The same drawing.", "Every room along this corridor is the same room. You are not sure the corridor is not also the same room."], {"name": "SameRoom", "size": Vector3(1.2, 0.8, 2.0), "note_key": "same_room", "note_title": "The door that was not there", "note_text": "Behind the door that was not there: a corridor of the same child's bedroom, over and over."})
	# the loop: from room 5 back to room 2
	var seam_x := c0.x + dirx * (3.0 + 4 * 4.5 + 2.2)
	var back_x := c0.x + dirx * (3.0 + 1 * 4.5 + 2.2)
	var fyaw := _yaw(-90.0)
	bedroom_seam = SeamlessTeleport.create(self, Vector3(seam_x, 0, c0.z), fyaw, Vector3(back_x, 0, c0.z), fyaw, Vector3(0.6, 2.6, 1.6), {"name": "BedroomLoop", "count_flag": "house_bedroom_loops", "on_teleport": _on_bedroom_loop})
	if Game.count("house_bedroom_loops") >= 4:
		bedroom_seam.enabled = false
	# the far end comes out in the hall, from the other side of the door that was not there
	SeamlessTeleport.create(self, Vector3(c0.x + dirx * (length - 0.5), 0, c0.z), fyaw, xdoor + _v(-0.4, 0, 0), _yaw(90.0), Vector3(0.6, 2.6, 1.6), {"name": "BedroomEnd"})
	Kit.light(self, c0 + Vector3(dirx * 1.5, H - 0.2, 0), Color(1.0, 0.9, 0.7), 0.7, 5.0)
	if not Game.has_note("door_not_there"):
		Game.note("door_not_there", "A door in the hall", "There is a door in the hall that was not there the first time. It opens onto more house than the house has.")


func _big_bathroom(bath_door: Vector3) -> void:
	# through the bathroom door, the bathroom is enormous (visit 3+)
	var origin := Vector3(60, 0, -20)
	var rows := [
		"##############",
		"#..a..a..a..a#",
		"#............#",
		"#.~~~~~~~~~~.#",
		"#.~~~~~~~~~~.#",
		"#............#",
		"#..a..a..a..a#",
		"#............#",
		"#s.s.s.s.s.s.#",
		"#......E.....#",
		"##############",
	]
	var m := MapBuilder.build(self, rows, {"cell": 2.0, "height": 7.0, "origin": origin, "floor": "wall/tile_checker", "wall": "wall/tile_bath", "ceiling": "wall/plaster_white", "water": "nature/water_cistern", "water_floor": "wall/tile_white", "name": "BigBathroom"})
	for p in m.markers.get("a", []):
		Props.place(self, "bathtub", p, 0.0, 1.3)
	for p in m.markers.get("s", []):
		Props.place(self, "sink", p + Vector3(0, 0, 0.6), 180.0, 1.0)
		Props.place(self, "mirror_wall", p + Vector3(0, 1.6, 0.94), 180.0, 1.0, {"collision": "none"})
	for i in 4:
		Kit.light(self, origin + Vector3(4 + i * 6, 6.5, 8), Color(0.8, 0.95, 1.0), 1.4, 12.0)
		Kit.light(self, origin + Vector3(4 + i * 6, 6.5, 14), Color(0.8, 0.95, 1.0), 1.4, 12.0)
	var e: Vector3 = m.first.call("E")
	Readable.create(self, e + Vector3(2, 1.2, 0), 0.0, "Count the tiles", ["You count the tiles along the long wall.", "You stop at four hundred. The wall does not."], {"name": "BigBathCount", "size": Vector3(1.0, 1.0, 1.0), "note_key": "bath_400", "note_title": "Four hundred tiles", "note_text": "The bathroom's long wall had forty-one tiles. Now you stop counting at four hundred. The bathroom got bigger again."})
	Usher.spawn(self, origin + Vector3(14, 0, 4), {"appear_delay": 2.0})
	# seams: bathroom doorway <-> big bathroom entrance (E)
	var in_yaw := _yaw(-90.0)
	SeamlessTeleport.create(self, bath_door + _v(0.2, 0, 0), in_yaw, e + Vector3(0, 0, 0.6), 0.0, Vector3(0.6, 2.4, 1.4), {"name": "BigBathIn"})
	SeamlessTeleport.create(self, e + Vector3(0, 0, 0.9), 180.0, bath_door + _v(-0.6, 0, 0), _yaw(90.0), Vector3(1.6, 2.4, 0.6), {"name": "BigBathOut"})


func _between_walls(hole: Vector3) -> void:
	# the space between the walls: a mouse-sized passage from bedroom B's skirting board
	var start := hole + _v(0.3, 0, 0)
	var dirx := -1.0 if mirrored else 1.0
	var len := 6.0
	Kit.floor(self, start + Vector3(dirx * len * 0.5, 0, 0), Vector2(len, 0.5), "wood/planks_dark", {"tile": 0.5})
	Kit.ceiling(self, start + Vector3(dirx * len * 0.5, 0.45, 0), Vector2(len, 0.5), "wood/planks_dark", {"tile": 0.5})
	Kit.wall(self, start + Vector3(0, 0, -0.25), start + Vector3(dirx * len, 0, -0.25), 0.45, "wood/planks_dark", {"tile": 0.5})
	Kit.wall(self, start + Vector3(dirx * len, 0, 0.25), start + Vector3(0, 0, 0.25), 0.45, "wood/planks_dark", {"tile": 0.5})
	var room := start + Vector3(dirx * (len + 1.0), 0, 0)
	Kit.floor(self, room, Vector2(2.0, 2.0), "wood/planks_dark", {"tile": 0.5})
	Kit.ceiling(self, room + Vector3(0, 0.45, 0), Vector2(2.0, 2.0), "wood/planks_dark", {"tile": 0.5})
	Kit.wall(self, room + Vector3(-1, 0, -1), room + Vector3(1, 0, -1), 0.45, "wood/planks_dark", {"tile": 0.5})
	Kit.wall(self, room + Vector3(1, 0, -1), room + Vector3(1, 0, 1), 0.45, "wood/planks_dark", {"tile": 0.5})
	Kit.wall(self, room + Vector3(1, 0, 1), room + Vector3(-1, 0, 1), 0.45, "wood/planks_dark", {"tile": 0.5})
	Kit.wall(self, room + Vector3(-1, 0, 1), room + Vector3(-1, 0, -1), 0.45, "wood/planks_dark", {"tile": 0.5})
	Kit.light(self, room + Vector3(0, 0.35, 0), Color(1.0, 0.8, 0.5), 0.5, 2.5)
	Props.place(self, "candle", room + Vector3(0.5, 0, 0.4), 0.0, 0.5, {"collision": "none"})
	Readable.create(self, room + Vector3(-0.4, 0.15, -0.4), 0.0, "A very small note", ["THE HOUSE KEEPS ITS SPARE ROOMS IN HERE.", "PLEASE DO NOT TAKE MORE THAN ONE."], {"name": "SpareRooms", "size": Vector3(0.3, 0.2, 0.3), "note_key": "spare_rooms", "note_title": "Between the walls", "note_text": "Behind the skirting board, a passage for someone very small. The house keeps its spare rooms there. Please do not take more than one."})
	Pickup.create(self, room + Vector3(0.4, 0, -0.3), {"item": "candle_stub", "requires_keepsake": "mouse", "name": "WallCandle", "key": "picked_candle_house"})


func _attic(hatch_below: Vector3) -> void:
	var hatch := hatch_below + Vector3(0, H, 0)
	Props.place(self, "attic_hatch" if Props.exists("attic_hatch") else "crate_small", hatch + Vector3(0, -0.02 if Props.exists("attic_hatch") else -0.5, 0), 0.0, 1.0, {"collision": "none"})
	var attic_floor := hatch + Vector3(0, 0.3, 0)
	Kit.floor(self, attic_floor + Vector3(0, 0, -1.0), Vector2(4.0, 6.0), "wood/planks_grey", {"tile": 1.5})
	Kit.ceiling(self, attic_floor + Vector3(0, 2.2, -1.0), Vector2(4.0, 6.0), "wood/planks_dark", {"tile": 1.5})
	Kit.wall(self, attic_floor + Vector3(-2, 0, 2), attic_floor + Vector3(-2, 0, -4), 2.2, "wood/planks_dark", {"tile": 1.5})
	Kit.wall(self, attic_floor + Vector3(2, 0, -4), attic_floor + Vector3(2, 0, 2), 2.2, "wood/planks_dark", {"tile": 1.5})
	Kit.wall(self, attic_floor + Vector3(-2, 0, -4), attic_floor + Vector3(2, 0, -4), 2.2, "wood/planks_dark", {"tile": 1.5})
	Kit.wall(self, attic_floor + Vector3(2, 0, 2), attic_floor + Vector3(-2, 0, 2), 2.2, "wood/planks_dark", {"tile": 1.5})
	Props.place(self, "boxes_moving" if Props.exists("boxes_moving") else "crate", attic_floor + Vector3(-1.2, 0, -2.5), 15.0, 1.0)
	Props.place(self, "crate_small", attic_floor + Vector3(1.2, 0, -3.0), 40.0, 1.0)
	Props.place(self, "coat_rack", attic_floor + Vector3(1.4, 0, 1.2), 0.0, 1.0)
	Kit.light(self, attic_floor + Vector3(0, 2.0, -1), Color(1.0, 0.85, 0.6), 0.9, 6.0)
	Readable.create(self, attic_floor + Vector3(-1.2, 0.8, -2.5), 0.0, "The box of photographs", ["A box of photographs. All of them are of the porch.", "None of them have anyone on it. Not yet."], {"name": "PhotoBox", "size": Vector3(1.0, 0.8, 1.0), "note_key": "photo_box", "note_title": "The box of photographs", "note_text": "A box of photographs of the porch, with nobody on it. Not yet."})
	var win := attic_floor + Vector3(0, 1.3, -3.9)
	Kit.sign(self, "props/window_night", win, 0.0, Vector2(1.0, 1.0))
	Readable.create(self, win, 0.0, "Look out of the attic window", ["From the attic window you can see the field, and the sky above the field.", "The sky has a light fitting in it. It is switched off. Somebody is being careful about the bill."], {"name": "AtticWindow", "size": Vector3(1.0, 1.0, 0.4), "note_key": "sky_fitting", "note_title": "The light fitting in the sky", "note_text": "From the attic you saw it: the sky over the field has a light fitting in it, switched off."})
	# the hatch: reachable with the Moth Wings, or by the ladder once the photograph is returned
	var hatch_it := Interactable.make(self, hatch + Vector3(0, -0.3, 0), Vector3(1.2, 0.5, 1.2), "The attic hatch", _on_hatch, {"name": "AtticHatch"})
	hatch_it.set_meta("attic_pos", attic_floor + Vector3(0, 0.1, 0.5))
	if Game.has_flag("photo_returned"):
		attic_ladder = Kit.stairs(self, hatch_below + Vector3(0, 0, 1.2), 0.0, 0.8, 9, 0.33, 0.3, "wood/planks_grey", {"name": "AtticLadder"})
	# the attic floor has a hole above the hatch so you can drop down
	Kit.blocker(self, attic_floor + Vector3(0, -0.15, 0.6), Vector3(0.1, 0.1, 0.1), Kit.L_WORLD)


func _on_backwards(p: Node) -> void:
	var player := p as Player
	if player == null:
		return
	# walking backwards through the door: velocity opposes facing
	var fwd := player.forward()
	var v := player.velocity
	v.y = 0.0
	if v.length() > 0.5 and v.normalized().dot(fwd) < -0.5:
		var t: Node = get_node("BackwardsTrigger")
		var dest: Vector3 = t.get_meta("dest")
		player.global_position = dest + Vector3(0, 0.1, 0)
		Audio.sfx("door_creak_long", dest, -6.0)
		Game.bump("backwards_entries")
	else:
		if Game.count("backwards_hint") == 0:
			Game.bump("backwards_hint")
			Game.toast.emit("The door does not open for people facing it.")


func _on_backwards_out(p: Node) -> void:
	var player := p as Player
	if player == null:
		return
	var t: Node = get_node("BackwardsOut")
	var dest: Vector3 = t.get_meta("dest")
	player.global_position = dest + Vector3(0, 0.1, 0)
	Audio.sfx("door_close", dest, -8.0)


func _on_basement_loop(_p: Node) -> void:
	var n := Game.count("house_basement_loops")
	Audio.sfx("creak", player_pos(), -8.0)
	if n == 1:
		Game.toast.emit("The stair goes down to a room with a stair going down.")
	elif n == 2:
		Game.toast.emit("Down is the same as down.")
	elif n >= 3 and basement_seam:
		basement_seam.enabled = false
		Game.note("basement", "The basement", "Three flights down, the basement gave up and put a tiled door at the bottom. There is water behind it.")
		World.reload_here("basement", {"duration": 0.3, "silent": true})


func _on_bedroom_loop(_p: Node) -> void:
	var n := Game.count("house_bedroom_loops")
	if n >= 4 and bedroom_seam:
		bedroom_seam.enabled = false
		Game.toast.emit("The corridor, having made its point, ends.")


func _on_frame(_p: Node, it: Node) -> void:
	if Game.has_flag("photo_returned"):
		if World.hud:
			await World.hud.say("", ["The family on the porch, back where they belong.", "One of them is looking at you. That is new."])
		return
	if Game.has_item("photo"):
		Game.take_item("photo")
		Game.set_flag("photo_returned", true)
		Audio.sfx("photo_click", it.global_position, -4.0)
		Game.note("photo_returned", "The photograph returned", "You put the missing photograph back in its frame. Somewhere above you, a ladder let itself down.")
		Game.toast.emit("Above you, something wooden unfolds.")
		World.reload_here("porch", {"duration": 0.4, "silent": true})
	else:
		if World.hud:
			await World.hud.say("", ["An empty frame. The wallpaper behind it is brighter than the rest.", "Whatever was in it has been taken somewhere with filing cabinets."])


func _on_cupboard(_p: Node, it: Node) -> void:
	if not Game.has_flag("house_biscuit"):
		Game.set_flag("house_biscuit", true)
		Game.gain_item("dog_biscuit")
		Audio.sfx("wood_knock", it.global_position, -10.0)
		if World.hud:
			await World.hud.say("", ["Tins with no labels. A box of dog biscuits, shaped like bones.", "You take one. The dog would want you to."])
	else:
		if World.hud:
			await World.hud.say("", ["Tins with no labels."])


func _on_hatch(p: Node, it: Node) -> void:
	var player := p as Player
	if player == null:
		return
	if Game.has_flag("photo_returned") or Game.active_is("wings"):
		var pos: Vector3 = it.get_meta("attic_pos")
		player.global_position = pos
		Audio.sfx("door_creak_long", pos, -6.0)
		Game.set_flag("attic_seen", true)
	else:
		if World.hud:
			await World.hud.say("", ["The attic hatch. Too high to reach, and no ladder.", "If you could fly. Or if the house liked you more."])
