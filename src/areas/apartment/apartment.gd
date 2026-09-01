extends AreaBase
## Flat 5½ — the waking world. A small flat on the third floor of the Halden
## Arms: bedroom, kitchen, hall, bathroom, living room. Sleep in the bed to
## dream. Once you have dreamt and woken with something in your hands, the
## closet is no longer a closet.
##
## Entering from flat 7 across the corridor gives you the same flat, mirrored.

const CELL := 1.4
const H := 2.8

var mirrored := false
var tv_screen: MeshInstance3D = null
var tv_on := false
var tv_light: OmniLight3D = null
var _origin := Vector3(-11.2, 0, -7.7)


func build() -> void:
	can_wake = false
	mirrored = Game.has_flag("in_flat_seven")
	Realm.apply(self, "waking", {"ambient_energy": 0.75, "fog_density": 0.012})
	var wall_stripe := "wall/wallpaper_stripe"
	var wall_cream := "wall/plaster_cream"
	var bedroom := _room([
		".w...",
		"..b..",
		"C...d",
		"    O",
	], 1, 1, {"floor": "wall/carpet_apartment", "wall": wall_stripe})
	var kitchen := _room([
		".f..s..",
		".......",
		"t.....W",
		"  O    ",
	], 8, 1, {"floor": "wall/tile_terracotta", "wall": wall_cream})
	var hall := _room([
		"    D    D    ",
		"h....p.......F",
		"  D     D     ",
	], 1, 4, {"floor": "wood/planks_warm", "wall": wall_cream})
	var bath := _room([
		"  O  ",
		".....",
		"m...t",
		"..a..",
	], 1, 6, {"floor": "wall/tile_checker", "wall": "wall/tile_bath", "ceiling": "wall/plaster_white"})
	var living := _room([
		" O     ",
		".......",
		"..v..s.",
		"...p...",
	], 8, 6, {"floor": "wall/carpet_apartment", "wall": wall_cream})

	# --- bedroom ---
	var bed_pos: Vector3 = bedroom.first.call("b") + _v(0, 0, -0.35)
	Bed.create(self, bed_pos, _yaw(0.0), "nexus", "default", {"model": "bed_single", "sleep_text": "Sleep"})
	add_spawn("bed", bed_pos + _v(1.4, 0.1, 0.6), _yaw(180.0))
	add_spawn("default", bed_pos + _v(1.4, 0.1, 0.6), _yaw(180.0))
	var win: Vector3 = bedroom.first.call("w")
	Props.place(self, "window_night", win + _v(0, 1.5, -CELL * 0.5 + 0.08), _yaw(180.0), 1.0, {"collision": "none"})
	Kit.light(self, win + _v(0, 1.6, 0.4), Color(0.5, 0.6, 0.9), 0.35, 4.0)
	var desk_pos: Vector3 = bedroom.first.call("d") + _v(CELL * 0.5 - 0.45, 0, 0)
	Props.place(self, "desk", desk_pos, _yaw(90.0), 1.0)
	Props.place(self, "lamp_desk", desk_pos + _v(0, 0.77, -0.35), _yaw(90.0), 1.0, {"collision": "none"})
	Kit.light(self, desk_pos + _v(-0.4, 1.3, 0), Color(1.0, 0.85, 0.6), 0.9, 5.0)
	Interactable.make(self, desk_pos + _v(-0.1, 0.8, 0.2), Vector3(0.5, 0.2, 0.4), "Read your journal", func(_p: Node, _i: Node) -> void:
		if World.hud:
			World.hud.toggle_journal(), {"name": "Journal"})
	Props.place(self, "chair", desk_pos + _v(-0.7, 0, 0.1), _yaw(-90.0), 1.0)
	Props.place(self, "bookshelf_white", bedroom.first.call("d") + _v(CELL * 0.5 - 0.2, 0, -1.3), _yaw(90.0), 1.0)
	Props.place(self, "painting_door", desk_pos + _v(0.4, 1.9, 0), _yaw(90.0), 0.8, {"collision": "none"})
	Props.place(self, "rug_house", bedroom.first.call("b") + _v(0, 0, 1.5), _yaw(0.0), 1.0, {"collision": "none"})
	# the closet
	var closet: Vector3 = bedroom.first.call("C") + _v(-CELL * 0.5 + 0.16, 0, 0)
	var closet_door := Door.create(self, closet, _yaw(-90.0), "hallway", "entrance", {
		"kind": "white", "label": "Open the closet", "requires_flag": "has_woken",
		"locked_text": "A closet. Coats, a shoebox, the smell of dust. It is exactly as deep as a closet.",
		"fade_color": Color.BLACK, "fade_duration": 1.0, "sets_flag": "hallway_found", "name": "Closet"})
	if Game.has_flag("has_woken") and not Game.has_flag("hallway_found"):
		Kit.light(self, closet + _v(0.5, 1.0, 0), Color(0.7, 0.8, 1.0), 0.5, 2.5)
	add_spawn("closet", closet + _v(1.0, 0.1, 0), _yaw(-90.0))
	Kit.light(self, bedroom.first.call("b") + _v(0, H - 0.2, 1.0), Color(1.0, 0.9, 0.75), 0.7, 6.0)

	# --- kitchen ---
	var fridge: Vector3 = kitchen.first.call("f") + _v(0, 0, -CELL * 0.5 + 0.36)
	Props.place(self, "fridge", fridge, _yaw(0.0), 1.0)
	Readable.create(self, fridge + _v(0, 1.3, 0.38), _yaw(0.0), "Read the note on the fridge", [
		"things to do:",
		"- sleep",
		"- measure the closet",
		"- do NOT open the closet",
		"- sleep",
		"The last one is crossed out. You do not remember crossing it out.",
	], {"name": "FridgeNote", "sign": "signs/note_apartment", "sign_size": Vector2(0.4, 0.4), "size": Vector3(0.5, 0.5, 0.1), "note_key": "fridge_note", "note_title": "The note on the fridge", "note_text": "Sleep. Measure the closet. Do not open the closet. Sleep."})
	var counter: Vector3 = kitchen.first.call("s") + _v(0, 0, -CELL * 0.5 + 0.32)
	Props.place(self, "kitchen_counter", counter, _yaw(0.0), 1.0)
	Props.place(self, "stove", counter + _v(1.4, 0, 0), _yaw(0.0), 1.0)
	Props.place(self, "kitchen_sink", counter + _v(-1.7, 0, 0), _yaw(0.0), 1.0)
	Interactable.make(self, counter + _v(0, 0.7, 0.35), Vector3(1.0, 0.3, 0.3), "Open the drawer", _on_drawer, {"name": "Drawer"})
	var table: Vector3 = kitchen.first.call("t") + _v(0.3, 0, 0)
	Props.place(self, "table_round", table, 0.0, 1.0)
	Props.place(self, "chair", table + _v(0.8, 0, 0), _yaw(90.0), 1.0)
	Props.place(self, "chair", table + _v(-0.8, 0, 0.1), _yaw(-90.0), 1.0)
	Props.place(self, "mug", table + _v(0.1, 0.78, 0.1), 0.0, 1.0, {"collision": "none"})
	var kwin: Vector3 = kitchen.first.call("W")
	Props.place(self, "window_night", kwin + _v(CELL * 0.5 - 0.08, 1.5, 0), _yaw(-90.0), 1.0, {"collision": "none"})
	Props.place(self, "frame_calendar", kitchen.first.call("f") + _v(1.6, 1.7, -CELL * 0.5 + 0.03), _yaw(0.0), 1.0, {"collision": "none"})
	Kit.light(self, kitchen.first.call("t") + _v(1.5, H - 0.2, -0.5), Color(1.0, 0.95, 0.8), 0.8, 6.5)
	Puzzle.declare(self, "tape_measure", "", ["flag:has_woken"], "the kitchen drawer, after the first dream", {"item": "tape_measure"})

	# --- hall ---
	var front: Vector3 = hall.first.call("F") + _v(CELL * 0.5 - 0.16, 0, 0)
	Door.create(self, front, _yaw(90.0), "corridor", "flat_door", {
		"kind": "wood", "label": "The front door", "requires_item": "door_code",
		"locked_text": "The door is stuck. There is a keypad on it that was not there when you moved in. It wants a number.",
		"name": "FrontDoor", "sets_flag": "left_the_flat"})
	Kit.sign(self, "signs/five_half", front + _v(-0.05, 1.9, 0), _yaw(90.0), Vector2(0.32, 0.32))
	Kit.sign(self, "props/keypad", front + _v(-0.05, 1.3, 0.7), _yaw(90.0), Vector2(0.3, 0.3))
	add_spawn("front", front + _v(-1.2, 0.1, 0), _yaw(90.0))
	Props.place(self, "coat_rack", hall.first.call("F") + _v(-0.9, 0, 0.5), 0.0, 1.0)
	var phone: Vector3 = hall.first.call("p") + _v(0, 0, -CELL * 0.5 + 0.3)
	Props.place(self, "dresser", phone, _yaw(0.0), 0.7)
	Props.place(self, "telephone", phone + _v(0, 0.7, 0), _yaw(0.0), 1.0, {"collision": "none"})
	Readable.create(self, phone + _v(0, 0.8, 0), _yaw(0.0), "The telephone", ["The telephone has no cord.", "It rings, sometimes, when you are in another room."], {"name": "Phone", "size": Vector3(0.6, 0.5, 0.5), "sound": "phone_ring"})
	var photo_a := "props/photo_1"
	if visit_count >= 4 or Game.stats.wakes >= 3:
		photo_a = "props/photo_4"
		if not Game.has_note("photo_extra"):
			Game.note("photo_extra", "One more in the photograph", "There is one more person on the porch in the hall photograph. They are standing slightly apart. You do not remember them and they do not have a face.")
	Props.place(self, "photo_1", hall.first.call("h") + _v(2.8, 1.7, -CELL * 0.5 + 0.03), _yaw(0.0), 1.0, {"collision": "none", "name": "HallPhotoA"})
	var pa := get_node_or_null("HallPhotoA")
	if pa:
		var pic := Props.part(pa, "Picture")
		if pic and pic is MeshInstance3D:
			(pic as MeshInstance3D).set_surface_override_material(0, Kit.mat(photo_a, {"vertex_color": true}))
	Props.place(self, "photo_2", hall.first.call("h") + _v(7.5, 1.7, -CELL * 0.5 + 0.03), _yaw(0.0), 1.0, {"collision": "none"})
	Props.place(self, "radiator", hall.first.call("h") + _v(5.0, 0, CELL * 0.5 - 0.1), _yaw(180.0), 1.0)
	for i in 3:
		Kit.light(self, hall.first.call("h") + _v(2.5 + i * 4.5, H - 0.2, 0), Color(1.0, 0.9, 0.75), 0.55, 5.0)
	Dog.maybe_spawn(self, hall.first.call("h") + _v(1.0, 0.1, 0))
	if Game.count("usher_sightings") >= 2 and Game.count("usher_sightings") < 9:
		Usher.spawn(self, hall.first.call("h") + _v(0.2, 0, 0), {"appear_delay": 3.0})

	# --- bathroom ---
	var mirror_pos: Vector3 = bath.first.call("m") + _v(-CELL * 0.5 + 0.06, 1.55, 0)
	Props.place(self, "sink", bath.first.call("m") + _v(-CELL * 0.5 + 0.3, 0, 0), _yaw(-90.0), 1.0)
	Mirror.create(self, mirror_pos, _yaw(-90.0), "mirror_nexus", "default", {"name": "BathroomMirror"})
	add_spawn("mirror", bath.first.call("m") + _v(0.9, 0.1, 0), _yaw(90.0))
	Props.place(self, "toilet", bath.first.call("t") + _v(CELL * 0.5 - 0.35, 0, 0), _yaw(90.0), 1.0)
	Props.place(self, "bathtub", bath.first.call("a") + _v(0, 0, CELL * 0.5 - 0.42), _yaw(0.0), 1.0)
	Kit.light(self, bath.first.call("t") + _v(-0.7, H - 0.2, -0.5), Color(0.8, 0.95, 1.0), 0.7, 5.0)
	Readable.create(self, bath.first.call("a") + _v(0.9, 0.5, 0), 0.0, "Look in the bath", ["There is a ring of tide around the inside of the bath, at a height you could not have filled it to."], {"name": "BathLook", "size": Vector3(0.6, 0.6, 0.6), "note_key": "bath_ring", "note_title": "The bath", "note_text": "A tide ring higher than the taps."})

	# --- living room ---
	var tv_pos: Vector3 = living.first.call("v") + _v(0, 0, -CELL * 0.5 + 0.45)
	Props.place(self, "dresser", tv_pos + _v(0, 0, 0.05), _yaw(0.0), 0.9)
	var tv := Props.place(self, "tv_crt", tv_pos + _v(0, 0.9, 0), _yaw(180.0), 1.0, {"collision": "none"})
	var screen := Props.part(tv, "Screen")
	if screen is MeshInstance3D:
		tv_screen = screen
	tv_light = Kit.light(self, tv_pos + _v(0, 1.4, 1.0), Color(0.7, 0.8, 1.0), 0.0, 5.0)
	Interactable.make(self, tv_pos + _v(0, 1.2, 0), Vector3(0.9, 0.7, 0.7), "Turn the television on", _on_tv, {"name": "TV"})
	var sofa: Vector3 = living.first.call("s")
	Props.place(self, "sofa", sofa + _v(0.6, 0, 0.5), _yaw(0.0), 1.0)
	Props.place(self, "rug_house", living.first.call("v") + _v(1.0, 0, 1.6), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "lamp_floor", living.first.call("p") + _v(2.6, 0, 0.3), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, living.first.call("p") + _v(2.6, 1.8, 0.3), Color(1.0, 0.85, 0.6), 0.9, 6.0)
	Props.place(self, "painting_house", living.first.call("p") + _v(0, 1.7, CELL * 0.5 - 0.03), _yaw(180.0), 1.0, {"collision": "none"})
	Props.place(self, "photo_0", living.first.call("p") + _v(-1.6, 1.6, CELL * 0.5 - 0.03), _yaw(180.0), 1.0, {"collision": "none"})
	Props.place(self, "bookshelf", living.first.call("s") + _v(1.9, 0, -CELL * 0.5 + 0.2), _yaw(0.0), 1.0)
	Props.place(self, "plant_pot", living.first.call("v") + _v(-2.0, 0, -CELL * 0.5 + 0.4), 0.0, 1.0, {"collision": "none"})
	Readable.create(self, living.first.call("p") + _v(0, 1.7, CELL * 0.5 - 0.1), _yaw(180.0), "Look at the painting", ["A house in a field at night. One window lit.", "You have never seen this house. You know exactly where the light switch is."], {"name": "HousePainting", "size": Vector3(1.0, 1.0, 0.2), "note_key": "house_painting", "note_title": "The painting of the house", "note_text": "A house alone in a field. You know its light switch."})

	if Game.is_night() and not tv_on:
		_set_tv(true, false)
	if mirrored:
		Game.note("flat_seven", "Flat 7", "Flat 7 is your flat. Every room is where it should be, on the wrong side. The photographs are the same. The people in them are not.")
	Kit.particles(self, hall.first.call("h") + _v(6, 1.5, 0), "motes", Vector3(9, 1.2, 1), 30)


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
		o["origin"] = _origin + Vector3(-(col + w) * CELL, 0, row * CELL) + Vector3(2 * -_origin.x, 0, 0)
	else:
		o["origin"] = _origin + Vector3(col * CELL, 0, row * CELL)
	return MapBuilder.build(self, r, o)


## Mirror-aware offset (flips X when in flat 7).
func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(-x if mirrored else x, y, z)


func _yaw(y: float) -> float:
	return -y if mirrored else y


func _on_drawer(_p: Node, it: Node) -> void:
	if Game.has_flag("has_woken") and not Game.has_item("tape_measure") and not Game.has_flag("took_tape"):
		Game.set_flag("took_tape", true)
		Game.gain_item("tape_measure")
		Audio.sfx("tape_measure", it.global_position, -4.0)
		if World.hud:
			await World.hud.say("", ["Cutlery. A takeaway menu. A tape measure you do not own.", "Twenty-five feet of yellow steel. Someone has scratched a line on it at twenty-one."])
	else:
		Audio.sfx("wood_knock", it.global_position, -10.0)
		if World.hud:
			await World.hud.say("", ["Cutlery. A takeaway menu. A pencil with the end chewed."])


func _on_tv(_p: Node, it: Node) -> void:
	_set_tv(not tv_on, true)
	var i := it as Interactable
	if i:
		i.prompt = "Turn the television off" if tv_on else "Turn the television on"


func _set_tv(on: bool, sound: bool) -> void:
	tv_on = on
	if sound:
		Audio.sfx("tv_on" if on else "tv_off", tv_screen.global_position if tv_screen else global_position, -6.0)
	if tv_screen == null:
		return
	if on:
		if Game.chance(1.0 / 24.0) or (Game.is_witching_hour() and Game.chance(0.5)):
			tv_screen.set_surface_override_material(0, Kit.mat("props/tv_face", {"unshaded": true, "emission": Color(0.5, 0.5, 0.5), "emission_energy": 0.6}))
			Audio.sfx("static_burst", tv_screen.global_position, -2.0)
			Game.bump("tv_face_seen")
			Game.note("tv_face", "Channel zero", "The television showed a face for a moment. Not a programme. A face, in the static, looking out. Then weather.")
			var t := get_tree().create_timer(2.5)
			t.timeout.connect(func() -> void:
				if tv_on and is_instance_valid(tv_screen):
					tv_screen.set_surface_override_material(0, Kit.static_mat({"brightness": 0.9})))
		else:
			tv_screen.set_surface_override_material(0, Kit.static_mat({"brightness": 0.9}))
		if tv_light:
			tv_light.light_energy = 0.9
	else:
		tv_screen.set_surface_override_material(0, Kit.flat(Color(0.05, 0.05, 0.06), {"unshaded": true}))
		if tv_light:
			tv_light.light_energy = 0.0


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if spawn_id == "bed" and n > 1:
		Game.note("woke", "Waking", "You wake in your own bed with the dream still in your hands. That should not be possible. Your hands disagree.")


func _process(_delta: float) -> void:
	if tv_light and tv_on:
		tv_light.light_energy = 0.7 + 0.3 * randf()
