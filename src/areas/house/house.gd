extends AreaBase
## The Nowhere House — a house alone in a dark field with no road. Each visit
## it is a slightly different house (myhouse.wad, with love):
##   visit 1  the house
##   visit 2  the house, mirrored; a door in the hall that was not there; the
##            Tin Mouse in the dog's bowl
##   visit 3+ the bathroom is enormous; the kitchen has a STAFF ONLY door into
##            the Waiting Halls; the basement stair goes down to the Cistern
## Always: the dog, the journal, the photographs, the backwards door, the attic.
##
## Built as ONE map (0.5 m cells, real wall cells, per-room textures) from a
## rasterised floor plan, so there are no seams between rooms to leak through.

const CELL := 0.5
const H := 2.7
const ORIGIN := Vector3(-11.0, 0.0, -7.5)
const W := 44
const D := 30

var mirrored := false
var big_bath := false
var basement_seam: SeamlessTeleport = null
var bedroom_seam: SeamlessTeleport = null
var empty_frame: Interactable = null


func build() -> void:
	mirrored = (visit_count == 2)
	big_bath = visit_count >= 3
	Realm.apply(self, "house", {"ambient_energy": 0.75, "sky_opts": {"detail_strength": 0.9, "detail_scale": 10.0}})
	_field()
	_plan()
	_hall()
	_living()
	_kitchen()
	_bedroom_a()
	_bathroom()
	_bedroom_b()
	_corridor_and_basement()
	if visit_count >= 2:
		_bedroom_corridor()
	_attic(_m(11.0, 7.0))
	_roof_and_porch()
	add_spawn("field", _m(11.0, 16.5, 0.1), _yaw(0.0))
	add_spawn("default", _m(11.0, 16.5, 0.1), _yaw(0.0))
	add_spawn("porch", _m(11.0, 10.2, 0.1), _yaw(0.0))
	Dog.maybe_spawn(self, _m(11.0, 8.2, 0.15), true)
	if visit_count >= 2 and not Game.has_note("house_mirrored"):
		Game.note("house_mirrored", "The house, the other way round", "Everything is where it was, on the wrong side. Hot is on the left now. Nobody moved the taps.")


# --- coordinates (plan metres -> world, mirror-aware) --------------------------

func _m(x: float, z: float, y: float = 0.0) -> Vector3:
	var wx := ORIGIN.x + x
	if mirrored:
		wx = -wx
	return Vector3(wx, y, ORIGIN.z + z)


func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(-x if mirrored else x, y, z)


func _yaw(y: float) -> float:
	return -y if mirrored else y


# --- the plan ----------------------------------------------------------------

func _plan() -> void:
	var rects := [
		[19, 1, 25, 29, "h"],    # hall            x 9.5-12.5  z 0.5-14.5
		[1, 3, 18, 10, "l"],     # living          x 0.5-9.0   z 1.5-5.0
		[7, 11, 17, 14, "u"],    # hidden room     x 3.5-8.5   z 5.5-7.0
		[1, 15, 18, 29, "k"],    # kitchen         x 0.5-9.0   z 7.5-14.5
		[26, 1, 43, 12, "a"],    # bedroom A       x 13-21.5   z 0.5-6.0
		[26, 13, 33, 21, "b"],   # bathroom        x 13-16.5   z 6.5-10.5
		[34, 13, 43, 21, "c"],   # bedroom B       x 17-21.5   z 6.5-10.5
		[26, 22, 43, 25, "g"],   # back corridor   x 13-21.5   z 11-12.5
	]
	var doors := [
		[21, 29, "D"], [22, 29, "D"],   # front door (south)
		[21, 0, "D"], [22, 0, "D"],     # back door (north)
		[18, 6, "D"], [18, 7, "D"],     # hall -> living
		[18, 19, "D"], [18, 20, "D"],   # hall -> kitchen
		[25, 6, "D"], [25, 7, "D"],     # hall -> bedroom A
		[25, 22, "D"], [25, 23, "D"], [25, 24, "D"],  # hall -> back corridor
		[28, 21, "D"], [29, 21, "D"],   # corridor -> bathroom
		[37, 21, "D"], [38, 21, "D"],   # corridor -> bedroom B
		[43, 23, "D"], [43, 24, "D"],   # corridor -> basement stair (east)
	]
	if visit_count >= 2:
		rects.append([26, 26, 43, 29, "s"])          # the room that was not there
		doors.append([25, 27, "D"])
		doors.append([25, 28, "D"])
		doors.append([43, 27, "D"])
		doors.append([43, 28, "D"])
	if visit_count >= 3:
		doors.append([0, 20, "D"])
		doors.append([0, 21, "D"])                    # kitchen wing: STAFF ONLY
	var rows := MapBuilder.rasterize(W, D, rects, doors)
	if mirrored:
		rows = MapBuilder.mirrored(rows)
	var rooms := {
		"h": {"floor": "wood/planks_house", "wall": "wall/wallpaper_damask", "ceiling": "wall/ceiling_plaster"},
		"l": {"floor": "wall/carpet_house", "wall": "wall/wallpaper_floral", "ceiling": "wall/ceiling_plaster"},
		"u": {"floor": "wood/planks_dark", "wall": "wall/hallway_grey", "ceiling": "wall/hallway_black"},
		"k": {"floor": "wall/tile_checker", "wall": "wall/plaster_house", "ceiling": "wall/plaster_white"},
		"a": {"floor": "wall/carpet_house", "wall": "wall/wallpaper_brown", "ceiling": "wall/ceiling_plaster"},
		"b": {"floor": "wall/tile_checker", "wall": "wall/tile_bath", "ceiling": "wall/plaster_white"},
		"c": {"floor": "wall/carpet_house", "wall": "wall/wallpaper_floral", "ceiling": "wall/ceiling_plaster"},
		"g": {"floor": "wood/planks_house", "wall": "wall/wallpaper_damask", "ceiling": "wall/ceiling_plaster"},
		"s": {"floor": "wood/planks_house", "wall": "wall/wallpaper_damask", "ceiling": "wall/ceiling_plaster"},
	}
	MapBuilder.build(self, rows, {
		"cell": CELL, "height": H, "origin": ORIGIN, "door_h": 2.1, "tile": 2.0,
		"floor": "wood/planks_house", "wall": "wood/planks_wall", "ceiling": "wall/ceiling_plaster",
		"rooms": rooms, "outer_faces": true, "name": "House",
	})


# --- the field ------------------------------------------------------------------

func _field() -> void:
	var noise_fn := func(x: float, z: float) -> float:
		var dx := maxf(0.0, absf(x) - 15.0)
		var dz := maxf(0.0, absf(z) - 13.0)
		var edge := clampf(Vector2(dx, dz).length() / 6.0, 0.0, 1.0)
		var h := sin(x * 0.11) * 0.25 + cos(z * 0.09 + x * 0.03) * 0.3
		# hollows only: the corridor of bedrooms and the enormous bathroom stand
		# on this field further out, and nothing may rise through their floors
		return lerpf(-0.14, minf(h - 0.05, -0.14), edge)
	# the ground is cut away where the basement stair goes down through it; a
	# concrete apron round the bulkhead covers the edges of the cut
	var sx := -1.0 if mirrored else 1.0
	# (the terrain's cells are 2 m; the cut comes out as x 10..18, z 2..6, and
	# the stairwell stands in it at x 11..15.8, z 3.7..5.3)
	var hole := Rect2(10.5 if sx > 0 else -18.5, 2.0, 8.0, 4.0)
	Kit.terrain(self, Vector3(0, -0.02, 0), Vector2(220, 220), 110, noise_fn, "nature/grass_dark", {"tile": 3.0, "holes": [hole]})
	Kit.floor(self, Vector3(sx * 15.5, -0.1, 2.8), Vector2(5.0, 1.6), "wall/concrete", {"tile": 1.5})
	Kit.floor(self, Vector3(sx * 15.5, -0.1, 5.7), Vector2(5.0, 0.6), "wall/concrete", {"tile": 1.5})
	Kit.floor(self, Vector3(sx * 16.95, -0.1, 4.5), Vector2(2.1, 1.8), "wall/concrete", {"tile": 1.5})
	Kit.box(self, Vector3(sx * 14.0, -3.5, 4.0), Vector3(8.4, 0.4, 4.4), "wall/concrete_dark", {"tile": 2.0, "solid": false})
	# the yard's dirt, in three pieces round the stairwell's cut
	Kit.floor(self, Vector3(0, -0.06, -4.2), Vector2(26, 15.6), "ground/dirt", {"tile": 3.0})
	Kit.floor(self, Vector3(0, -0.06, 8.7), Vector2(26, 6.6), "ground/dirt", {"tile": 3.0})
	Kit.floor(self, Vector3(-sx * 1.0, -0.06, 4.5), Vector2(24, 1.8), "ground/dirt", {"tile": 3.0})
	Kit.scatter(40, rng, Vector3.ZERO, Vector2(100, 100), func(_i: int, p: Vector3) -> void:
		if p.length() < 20.0 or p.distance_to(Vector3(-3, 0, 24)) < 3.0:
			# nothing solid lands on the spawn beside the lone door
			return
		var m := "bush_1" if rng.randf() < 0.6 else "rock_1"
		Props.place(self, m, p, rng.randf_range(0, 360), rng.randf_range(0.7, 1.4), {"collision": "none" if m == "bush_1" else "box"}), 20.0)
	Props.place(self, "tree_dead_2", Vector3(18, 0, 8), 20.0, 1.0)
	Props.place(self, "tree_dead_1", Vector3(-21, 0, -14), 200.0, 1.2)
	var lone := Vector3(-3, 0, 26)
	Door.create(self, lone, 180.0, "nexus", "from_house", {"kind": "white", "label": "A door standing in the field", "name": "LoneDoor", "fade_duration": 1.0})
	Kit.box(self, lone + Vector3(0, 2.32, 0), Vector3(1.4, 0.12, 0.3), "wood/planks_white")
	Kit.light(self, lone + Vector3(0, 2.6, 1.0), Color(0.8, 0.85, 1.0), 0.8, 6.0)
	add_spawn("from_nexus", lone + Vector3(0, 0.1, -2.0), 0.0)
	Kit.box(self, Vector3(4.0, 0.55, 15.0), Vector3(0.08, 1.1, 0.08), "wood/planks_dark")
	Kit.box(self, Vector3(4.0, 1.25, 15.0), Vector3(0.3, 0.3, 0.5), "metal/plate")
	Readable.create(self, Vector3(4.0, 1.25, 15.0), 0.0, "The mailbox", ["The mailbox has no number.", "Someone has written yours on it, in pencil: 5½."], {"name": "Mailbox", "size": Vector3(0.5, 0.6, 0.7), "note_key": "mailbox", "note_title": "The mailbox", "note_text": "The house has no number. It has been given yours."})
	if Props.exists("fluorescent_light"):
		Props.place(self, "fluorescent_light", Vector3(10, 75, -30), 20.0, 40.0, {"collision": "none", "emission_energy": 0.3})
	Kit.particles(self, Vector3(0, 2, 12), "fog", Vector3(40, 1, 40), 24)
	Kit.light(self, Vector3(0, 30, 0), Color(0.6, 0.65, 0.8), 0.4, 80.0)


# --- rooms ----------------------------------------------------------------------

func _hall() -> void:
	# front and back doors stand open
	var fd := Props.place(self, "door_white", _m(11.0, 14.55), _yaw(0.0), 1.0, {"collision": "none", "name": "FrontDoorProp"})
	var leaf := Props.part(fd, "Leaf")
	if leaf:
		leaf.rotation.y = deg_to_rad(-100.0)
	var bd := Props.place(self, "door_white", _m(11.0, 0.45), _yaw(180.0), 1.0, {"collision": "none", "name": "BackDoorProp"})
	var bleaf := Props.part(bd, "Leaf")
	if bleaf:
		bleaf.rotation.y = deg_to_rad(-100.0)
	Props.place(self, "coat_rack", _m(12.2, 13.7), 0.0, 1.0)
	Props.place(self, "shoe_pile" if Props.exists("shoe_pile") else "crate_small", _m(12.1, 1.0), 20.0, 0.6, {"collision": "none"})
	# the grandfather clock, stuck at half past five
	var gc := Props.place(self, "clock_grandfather", _m(9.75, 4.0), _yaw(-90.0), 1.0)
	var pend := Props.part(gc, "Pendulum")
	if pend:
		var cw := Clockwork.create(gc, pend.position, {"mode": "oscillate", "axis": Vector3(0, 0, 1), "amplitude_deg": 14.0, "period": 2.0, "name": "PendulumSwing"})
		pend.get_parent().remove_child(pend)
		cw.body.add_child(pend)
		pend.position = Vector3.ZERO
	Readable.create(self, _m(9.85, 4.0, 1.5), _yaw(-90.0), "The grandfather clock", ["The clock says half past five.", "It has said half past five every time you have looked. It ticks anyway."], {"name": "ClockRead", "size": Vector3(0.7, 1.4, 0.7), "note_key": "house_clock", "note_title": "The clock in the hall", "note_text": "Half past five. Always. It ticks anyway."})
	for z in [2.0, 6.0, 10.0, 13.5]:
		Kit.light(self, _m(11.0, z, H - 0.15), Color(1.0, 0.88, 0.7), 1.0, 6.0)
	# photographs along the west wall (they change)
	var photos := ["photo_0", "photo_1", "photo_2"]
	if visit_count == 2:
		photos = ["photo_1", "photo_3", "photo_2"]
	elif visit_count >= 3:
		photos = ["photo_4", "photo_3", "photo_3"]
	var pz := [5.0, 8.5, 11.5]
	for i in 3:
		Props.place(self, photos[i], _m(9.53, pz[i], 1.6), _yaw(-90.0), 1.0, {"collision": "none"})
	if visit_count == 2 and not Game.has_note("house_photos_2"):
		Game.note("house_photos_2", "The photographs, second visit", "One of the family is scratched out now. The porch in the middle photograph is empty. Somebody moved the photographs, and everything else, to the other side of the house.")
	if visit_count >= 3 and not Game.has_note("house_photos_3"):
		Game.note("house_photos_3", "The photographs, third visit", "There is an extra person on the porch. Two of the frames show nobody at all. The house is running out of family.")
	# the door that was not there: on the first visit, only a stain
	if visit_count < 2:
		Kit.sign(self, "wood/door_dark", _m(12.47, 14.0, 1.1), _yaw(90.0), Vector2(0.9, 2.1), {"tint": Color(0.35, 0.3, 0.3)})
		Readable.create(self, _m(12.4, 14.0, 1.1), _yaw(90.0), "A door-shaped stain", ["The wallpaper here is a slightly different colour, in the shape of a door.", "There is no door."], {"name": "DoorStain", "size": Vector3(0.3, 2.0, 1.0)})
	# the backwards door (always): a door that only opens to people walking backwards into it
	Kit.sign(self, "wood/door_dark", _m(9.53, 6.25, 1.1), _yaw(-90.0), Vector2(0.9, 2.1), {"tint": Color(0.6, 0.55, 0.5)})
	Kit.label(self, "?", _m(9.54, 6.25, 1.95), _yaw(-90.0), 32, Color(0.5, 0.45, 0.4), "display", {"pixel_size": 0.01})
	var back_trig := Kit.trigger(self, _m(10.2, 6.25, 1.0), Vector3(1.4, 2.2, 1.8), _on_backwards, {"name": "BackwardsTrigger", "continuous": true})
	back_trig.set_meta("dest", _m(6.3, 6.25))
	Readable.create(self, _m(9.6, 6.25, 1.1), _yaw(-90.0), "A door with no handle", ["A door with no handle on this side.", "There is no handle on the other side either. You get the feeling it opens for people who are not looking at it."], {"name": "BackDoorRead", "size": Vector3(0.3, 2.0, 1.0)})
	# the hidden room
	Props.place(self, "chair", _m(5.0, 6.25), _yaw(90.0), 1.0)
	Usher.spawn(self, _m(5.0, 6.25), {"start_visible": true, "vanish_delay": 4.0, "radius": 6.0})
	Readable.create(self, _m(6.0, 5.6, 1.4), _yaw(0.0), "Writing on the wall", ["YOU CAME IN BACKWARDS. GOOD.", "THIS ROOM IS NOT ON THE PLAN. NEITHER ARE YOU."], {"name": "HiddenWriting", "size": Vector3(1.2, 1.0, 0.2), "note_key": "backwards_room", "note_title": "The backwards room", "note_text": "A room that only opens to people walking backwards. Someone tall was sitting in it, waiting to be looked at."})
	Kit.light(self, _m(6.0, 6.25, H - 0.3), Color(0.6, 0.6, 0.8), 0.7, 4.0)
	var out_trig := Kit.trigger(self, _m(8.25, 6.25, 1.0), Vector3(0.5, 2.2, 1.4), _on_backwards_out, {"name": "BackwardsOut"})
	out_trig.set_meta("dest", _m(10.2, 6.25))
	Kit.label(self, "out", _m(8.45, 6.25, 1.8), _yaw(90.0), 28, Color(0.5, 0.5, 0.6), "body", {"pixel_size": 0.01})


func _living() -> void:
	var tv_pos := _m(3.0, 1.95)
	Props.place(self, "dresser", tv_pos, _yaw(180.0), 0.9)
	var tv := Props.place(self, "tv_crt", tv_pos + Vector3(0, 0.9, 0), _yaw(180.0), 1.0, {"collision": "none"})
	var screen := Props.part(tv, "Screen")
	if screen is MeshInstance3D:
		var face := visit_count >= 2
		(screen as MeshInstance3D).set_surface_override_material(0, Kit.mat("props/tv_face", {"unshaded": true, "emission": Color(0.4, 0.4, 0.4), "emission_energy": 0.5}) if face else Kit.static_mat({"brightness": 0.7}))
	Kit.light(self, tv_pos + Vector3(0, 1.3, 1.0), Color(0.7, 0.8, 1.0), 0.7, 5.0)
	Readable.create(self, tv_pos + Vector3(0, 1.2, 0), _yaw(0.0), "The television", ["The television is on. Nobody turned it on.", "It shows snow." if visit_count < 2 else "It shows a face in the snow. The face is watching a programme about you."], {"name": "HouseTV", "size": Vector3(0.9, 0.7, 0.7)})
	Props.place(self, "painting_house", _m(6.0, 1.53, 1.8), _yaw(180.0), 0.9, {"collision": "none"})
	Readable.create(self, _m(6.0, 1.6, 1.8), _yaw(0.0), "The painting", ["A painting of this house, in this field, at night.", "In the painting, the light in the attic is on."], {"name": "HousePainting", "size": Vector3(1.0, 1.0, 0.2)})
	empty_frame = Interactable.make(self, _m(7.6, 1.6, 1.6), Vector3(0.6, 0.6, 0.2), "An empty frame", _on_frame, {"name": "EmptyFrame"})
	if Game.has_flag("photo_returned"):
		Props.place(empty_frame, "photo_2", Vector3(0, 0, -0.07), 0.0, 1.0, {"collision": "none"})
		empty_frame.prompt = "The photograph, returned"
	else:
		Kit.box(empty_frame, Vector3(0, 0, -0.05), Vector3(0.5, 0.5, 0.04), "wood/planks_dark", {"solid": false})
		Kit.box(empty_frame, Vector3(0, 0, -0.085), Vector3(0.42, 0.42, 0.01), "wall/paper", {"solid": false, "tint": Color(0.8, 0.78, 0.7)})
	Props.place(self, "bookshelf", _m(0.72, 3.4), _yaw(-90.0), 1.0)
	_journal(_m(1.1, 3.4, 1.2))
	Props.place(self, "sofa", _m(3.6, 4.2), _yaw(0.0), 1.0)
	Props.place(self, "rug_house", _m(3.6, 3.1, 0.02), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "lamp_floor", _m(8.4, 4.5), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, _m(8.4, 4.5, 1.8), Color(1.0, 0.85, 0.6), 1.2, 6.5)
	Props.place(self, "dresser", _m(6.6, 4.6), _yaw(180.0), 0.6)
	Props.place(self, "telephone", _m(6.6, 4.6, 0.62), _yaw(180.0), 1.0, {"collision": "none"})
	Props.place(self, "window_night", _m(8.0, 1.55, 1.5), _yaw(180.0), 1.0, {"collision": "none"})
	Kit.light(self, _m(4.5, 3.2, H - 0.15), Color(1.0, 0.9, 0.75), 0.9, 6.0)


func _kitchen() -> void:
	var fridge := _m(1.0, 7.9)
	Props.place(self, "fridge", fridge, _yaw(180.0), 1.0)
	Readable.create(self, fridge + _v(0, 1.3, 0.4), _yaw(180.0), "The note on the fridge", ["Dear whoever is reading this:", "the bathroom got bigger again. I moved the photos.", "Feed the dog.", "  - M."], {"name": "HouseFridgeNote", "sign": "signs/note_house", "sign_size": Vector2(0.4, 0.4), "size": Vector3(0.5, 0.5, 0.1), "note_key": "house_fridge", "note_title": "M.'s note", "note_text": "The bathroom got bigger again. Feed the dog. - M."})
	Props.place(self, "kitchen_counter", _m(4.0, 7.85), _yaw(180.0), 1.0)
	Props.place(self, "kitchen_sink", _m(2.3, 7.85), _yaw(180.0), 1.0)
	Props.place(self, "stove", _m(5.7, 7.85), _yaw(180.0), 1.0)
	if Props.exists("cupboard"):
		Props.place(self, "cupboard", _m(4.0, 7.55, 1.6), _yaw(180.0), 0.9, {"collision": "none"})
	Interactable.make(self, _m(4.0, 7.85, 1.7), Vector3(1.0, 0.6, 0.5), "Open the cupboard", _on_cupboard, {"name": "Cupboard"})
	Props.place(self, "frame_calendar", _m(7.0, 7.53, 1.8), _yaw(180.0), 1.0, {"collision": "none"})
	Props.place(self, "kitchen_table" if Props.exists("kitchen_table") else "table_round", _m(4.5, 11.0), 0.0, 1.0)
	Props.place(self, "chair", _m(5.5, 11.0), _yaw(90.0), 1.0)
	Props.place(self, "chair", _m(3.5, 11.0), _yaw(-90.0), 1.0)
	var bowl := _m(1.2, 13.8)
	Props.place(self, "dog_bowl" if Props.exists("dog_bowl") else "mug", bowl, 0.0, 1.0 if Props.exists("dog_bowl") else 2.0, {"collision": "none"})
	if visit_count >= 2:
		Pickup.create(self, bowl + Vector3(0, 0.05, 0), {"keepsake": "mouse", "name": "TinMouse"})
	else:
		Readable.create(self, bowl, 0.0, "The dog's bowl", ["The dog's bowl. Empty.", "Something small and tin has been chewing at the rim."], {"name": "BowlRead", "size": Vector3(0.6, 0.4, 0.6)})
	Kit.light(self, _m(4.5, 11.0, H - 0.15), Color(1.0, 0.95, 0.85), 1.4, 7.5)
	Kit.light(self, _m(3.0, 8.5, H - 0.15), Color(1.0, 0.95, 0.85), 0.8, 5.0)
	Props.place(self, "window_night", _m(0.55, 9.0, 1.5), _yaw(-90.0), 1.0, {"collision": "none"})
	if visit_count >= 3:
		Door.create(self, _m(0.55, 10.5), _yaw(-90.0), "offices", "from_house", {"kind": "white", "label": "STAFF ONLY", "name": "WingDoor", "fade_color": Color(0.85, 0.76, 0.42), "fade_duration": 0.9, "sets_flag": "found_staff_door"})
		Kit.sign(self, "signs/take_a_number", _m(0.53, 10.5, 2.35), _yaw(-90.0), Vector2(0.6, 0.3))
		Kit.light(self, _m(1.2, 10.5, 2.2), Color(1.0, 0.95, 0.6), 0.8, 4.0)
		if not Game.has_note("staff_only"):
			Game.note("staff_only", "STAFF ONLY", "There is a door in the kitchen that says STAFF ONLY. You do not have staff. You do not have a kitchen that size.")
	add_spawn("from_offices", _m(1.8, 10.5, 0.1), _yaw(-90.0))
	Puzzle.declare(self, "house_visits", "", [], "come back to the house; the second time the Tin Mouse is in the dog's bowl", {"keepsake": "mouse"})


func _bedroom_a() -> void:
	var bed_pos := _m(17.5, 1.65)
	Props.place(self, "bed_double", bed_pos, _yaw(0.0), 1.0)
	Readable.create(self, bed_pos + Vector3(0, 0.8, 0), _yaw(0.0), "The bed", ["The bed is made. Nobody has slept in it.", "The pillow has a dent the shape of someone's absence."], {"name": "BedARead", "size": Vector3(1.6, 0.6, 2.0)})
	Props.place(self, "window_night", _m(15.0, 0.55, 1.5), _yaw(180.0), 1.0, {"collision": "none"})
	Mirror.create(self, _m(21.45, 3.0, 1.55), _yaw(90.0), "", "default", {"name": "BedroomMirror", "lines_without": ["The mirror shows the bedroom.", "You are not in it. The door behind you is open. You did not open it."]})
	Props.place(self, "dresser", _m(20.5, 5.7), _yaw(0.0), 1.0)
	Props.place(self, "lamp_desk", _m(20.5, 5.7, 1.0), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, _m(20.0, 5.0, 1.6), Color(1.0, 0.85, 0.65), 1.1, 6.0)
	Kit.light(self, _m(17.0, 3.5, H - 0.15), Color(1.0, 0.9, 0.75), 0.8, 6.0)
	Props.place(self, "wardrobe", _m(13.45, 4.8), _yaw(-90.0), 1.0)
	var wd := Door.create(self, _m(13.9, 4.8), _yaw(-90.0), "hallway", "side", {"kind": "none", "label": "Look in the wardrobe", "name": "WardrobeDoor", "requires_flag": "hallway_measured", "locked_text": "Coats. Only coats. They smell of the flat.", "fade_duration": 1.0})
	wd.add_box(Vector3(0.8, 2.2, 1.2), Vector3(0, 1.1, 0))


func _bathroom() -> void:
	Props.place(self, "sink", _m(13.8, 6.85), _yaw(180.0), 1.0)
	if Props.exists("bathroom_cabinet"):
		Props.place(self, "bathroom_cabinet", _m(13.8, 6.55, 1.6), _yaw(180.0), 1.0, {"collision": "none"})
	else:
		Props.place(self, "mirror_wall", _m(13.8, 6.58, 1.6), _yaw(0.0), 1.0, {"collision": "none"})
	Props.place(self, "toilet", _m(15.7, 6.95), _yaw(180.0), 1.0)
	Props.place(self, "bathtub", _m(13.45, 9.2), _yaw(90.0), 1.0)
	Kit.light(self, _m(14.75, 8.5, H - 0.2), Color(0.8, 0.95, 1.0), 1.0, 5.0)
	var bath_door := _m(14.5, 10.75)
	if big_bath:
		_big_bathroom(bath_door)
	else:
		Readable.create(self, _m(15.6, 9.2, 0.5), 0.0, "Measure the bathroom by eye", ["The bathroom is the size of a bathroom.", "You count the tiles anyway. Forty-one along the long wall. You will count again next time."], {"name": "BathMeasure", "size": Vector3(0.6, 0.6, 0.6), "note_key": "bath_41", "note_title": "Forty-one tiles", "note_text": "The bathroom's long wall has forty-one tiles. Remember that."})


func _bedroom_b() -> void:
	Props.place(self, "bed_single", _m(17.8, 7.7), _yaw(0.0), 1.0)
	Props.place(self, "window_night", _m(19.6, 6.55, 1.5), _yaw(180.0), 1.0, {"collision": "none"})
	Props.place(self, "crate_small", _m(20.9, 7.3), 30.0, 0.6)
	Kit.sign(self, "props/painting_house", _m(20.6, 6.53, 1.2), _yaw(0.0), Vector2(0.5, 0.5))
	Readable.create(self, _m(20.6, 6.6, 1.2), _yaw(0.0), "A crayon drawing", ["A crayon drawing of the house. A crayon drawing of a tall man beside the house.", "The tall man is drawn in one colour, then the other colour, down the middle."], {"name": "Crayon", "size": Vector3(0.5, 0.5, 0.2), "note_key": "crayon", "note_title": "The crayon drawing", "note_text": "A child drew the house, and beside it the tall one, half in each colour."})
	Kit.light(self, _m(19.2, 8.5, H - 0.2), Color(1.0, 0.8, 0.9), 1.0, 5.0)
	var hole := _m(21.48, 9.5)
	Kit.mouse_gap(self, hole, _yaw(90.0), Vector2(0.62, 0.75))
	_between_walls(hole)


func _corridor_and_basement() -> void:
	Kit.light(self, _m(15.0, 11.75, H - 0.15), Color(1.0, 0.88, 0.7), 1.3, 6.0)
	Kit.light(self, _m(20.0, 11.75, H - 0.15), Color(1.0, 0.88, 0.7), 1.3, 6.0)
	Props.place(self, "radiator", _m(17.0, 12.35), _yaw(0.0), 1.0)
	# the basement: a walled stairwell east of the house going down three metres
	# to a concrete room, and out of the room's far end a second stair that keeps
	# going down. Laid out end to end so nothing stands across either flight:
	#   landing 0..0.8 | stair A 0.8..4.8 | room 4.8..16.8 | stair B 16.8..20.8 | bottom
	var top := _m(22.0, 12.0)
	var dx := -1.0 if mirrored else 1.0
	Kit.floor(self, top + Vector3(dx * 0.4, 0, 0), Vector2(0.8, 1.6), "wall/concrete")
	Kit.ceiling(self, top + Vector3(dx * 2.4, 2.4, 0), Vector2(4.8, 1.6), "wall/concrete_dark")
	# the stairwell is a closed shaft: side walls the whole way down, and an end
	# wall above the room's ceiling, so no sky or field shows through it
	var shaft_end := top.x + dx * 4.8
	Kit.wall(self, Vector3(top.x, -3.2, top.z - 0.8), Vector3(shaft_end, -3.2, top.z - 0.8), 5.6, "wall/concrete", {"thick": 0.2})
	Kit.wall(self, Vector3(shaft_end, -3.2, top.z + 0.8), Vector3(top.x, -3.2, top.z + 0.8), 5.6, "wall/concrete", {"thick": 0.2})
	Kit.wall(self, Vector3(shaft_end, -0.7, top.z - 0.7), Vector3(shaft_end, -0.7, top.z + 0.7), 3.1, "wall/concrete_dark", {"thick": 0.2})
	Kit.light(self, top + Vector3(dx * 3.0, 1.0, 0), Color(0.9, 0.85, 0.7), 0.7, 5.0)
	# the stairwell's outside shell: every face but the one in the doorway, which
	# used to be drawn across the opening and made the way down look like a wall
	Kit.box(self, top + Vector3(dx * 2.4, 1.25, 0), Vector3(4.8, 2.5, 1.4), "wall/concrete", {"faces": ["px" if dx > 0 else "nx", "pz", "nz", "py"], "solid": false, "tint": Color(0.6, 0.6, 0.62)})
	Kit.light(self, top + Vector3(dx * 0.6, 2.0, 0), Color(0.9, 0.85, 0.7), 0.9, 4.0)
	Kit.label(self, "down", top + Vector3(dx * 0.05, 2.25, 0), _yaw(90.0), 22, Color(0.55, 0.55, 0.6), "body", {"pixel_size": 0.01})
	Kit.stairs(self, top + Vector3(dx * 0.8, 0, 0), _yaw(-90.0), 1.4, 10, -0.3, 0.4, "wall/concrete", {"name": "BasementStairs"})
	# the room: a doorway cell at each end, the first met by the bottom of stair
	# A, the second opening straight onto the top of stair B
	var rows := ["D..b...D", " ...... "] if not mirrored else ["D...b..D", " ...... "]
	rows = [" ...... ", rows[0], " ...... "]
	var origin := Vector3(top.x + dx * 4.8 if not mirrored else top.x - 4.8 - 12.0, -3.0, top.z - 2.25)
	var m := MapBuilder.build(self, rows, {"cell": CELL * 3.0, "height": 2.4, "origin": origin, "floor": "wall/concrete", "wall": "wall/concrete_dark", "ceiling": "wall/concrete_dark", "name": "Basement", "double_thin": true})
	var b: Vector3 = m.first.call("b")
	Props.place(self, "boxes_moving" if Props.exists("boxes_moving") else "crate", b + Vector3(1.2, 0, -1.2), 20.0, 1.0)
	Props.place(self, "crate_small", b + Vector3(-1.4, 0, 1.2), 70.0, 1.0)
	Kit.light(self, b + Vector3(0, 2.1, 0), Color(1.0, 0.9, 0.7), 0.8, 6.0)
	Kit.light(self, b + Vector3(dx * 4.0, 2.1, 0), Color(1.0, 0.9, 0.7), 0.6, 5.0)
	Readable.create(self, b + Vector3(-1.6, 1.2, -2.1), 0.0, "Writing on the pipe", ["Someone has written on the pipe: DOWN IS THE SAME AS DOWN."], {"name": "PipeWriting", "size": Vector3(0.8, 0.5, 0.3)})
	add_spawn("basement", top + Vector3(-dx * 1.4, 0.1, 0), _yaw(90.0))
	# stair B: down out of the room's far doorway, in a shaft of its own whose
	# ceiling is the room's ceiling carried on
	var second_top := Vector3(top.x + dx * 16.8, -3.0, top.z)
	Kit.stairs(self, second_top, _yaw(-90.0), 1.4, 10, -0.3, 0.4, "wall/concrete", {"name": "BasementStairs2"})
	var shaft2_end := second_top.x + dx * 5.6
	Kit.wall(self, Vector3(second_top.x, -6.2, top.z - 0.8), Vector3(shaft2_end, -6.2, top.z - 0.8), 5.6, "wall/concrete", {"thick": 0.2})
	Kit.wall(self, Vector3(shaft2_end, -6.2, top.z + 0.8), Vector3(second_top.x, -6.2, top.z + 0.8), 5.6, "wall/concrete", {"thick": 0.2})
	Kit.ceiling(self, Vector3(second_top.x + dx * 2.8, -0.6, top.z), Vector2(5.6, 1.6), "wall/concrete_dark")
	Kit.box(self, Vector3(second_top.x + dx * 2.8, -6.45, top.z), Vector3(5.6, 0.3, 1.8), "wall/concrete_dark", {"solid": false})
	Kit.light(self, Vector3(second_top.x + dx * 2.0, -1.2, top.z), Color(0.9, 0.85, 0.7), 0.6, 5.0)
	var bottom := second_top + Vector3(dx * 4.8, -3.0, 0)
	Kit.floor(self, bottom, Vector2(1.6, 1.6), "wall/concrete")
	Kit.wall(self, bottom + Vector3(dx * 0.8, -0.2, -0.7), bottom + Vector3(dx * 0.8, -0.2, 0.7), 5.5, "wall/concrete_dark", {"thick": 0.2})
	var loops := Game.count("house_basement_loops")
	Puzzle.declare(self, "house_basement", "", [], "walk the basement stair down until it gives up (three times)", {"route": "cistern:from_basement"})
	basement_seam = SeamlessTeleport.create(self, bottom + Vector3(-dx * 0.3, 0, 0), _yaw(-90.0), top + Vector3(dx * 0.4, 0, 0), _yaw(-90.0), Vector3(1.6, 2.5, 0.5), {"name": "BasementSeam", "count_flag": "house_basement_loops", "one_way": false, "on_teleport": _on_basement_loop})
	if loops >= 3:
		basement_seam.enabled = false
		Door.create(self, bottom + Vector3(dx * 0.65, 0, 0), _yaw(-90.0), "cistern", "from_basement", {"kind": "white", "label": "A tiled door at the bottom of the stairs", "name": "CisternDoor", "fade_color": Color(0.2, 0.5, 0.55), "fade_duration": 1.0})
		Kit.light(self, bottom + Vector3(0, 2.0, 0), Color(0.5, 0.9, 0.9), 1.0, 5.0)
	else:
		Kit.light(self, bottom + Vector3(0, 2.0, 0), Color(0.9, 0.85, 0.7), 0.5, 4.0)


func _bedroom_corridor() -> void:
	# the room that was not there, and beyond it a corridor of the same child's
	# bedroom over and over (it loops until it has made its point)
	Readable.create(self, _m(17.0, 13.75, 1.4), _yaw(180.0), "A small room", ["A small room with nothing in it, which was not here before.", "The door on its far side is the same door as the one you came in by. You can tell by the scratches."], {"name": "SpareRoom", "size": Vector3(1.4, 1.2, 0.4), "note_key": "door_not_there", "note_title": "A door in the hall", "note_text": "There is a door in the hall that was not there the first time. It opens onto more house than the house has."})
	Kit.light(self, _m(17.0, 13.75, H - 0.2), Color(1.0, 0.9, 0.7), 0.8, 5.0)
	var c0 := _m(22.0, 14.0)
	var dirx := -1.0 if mirrored else 1.0
	var length := 30.0
	Kit.floor(self, c0 + Vector3(dirx * length * 0.5, 0, 0), Vector2(length, 1.6), "wood/planks_house", {"tile": 1.5})
	Kit.ceiling(self, c0 + Vector3(dirx * length * 0.5, H, 0), Vector2(length, 1.6), "wall/ceiling_plaster")
	Kit.wall(self, c0 + Vector3(dirx * length, 0, -0.8), c0 + Vector3(0, 0, -0.8), H, "wall/wallpaper_damask", {"tile": 1.5})
	Kit.wall(self, c0 + Vector3(dirx * length, 0, 0.8), c0 + Vector3(dirx * length, 0, -0.8), H, "wall/wallpaper_damask")
	Kit.wall(self, c0 + Vector3(dirx * 1.2, 0, 0.8), c0 + Vector3(0, 0, 0.8), H, "wall/wallpaper_damask")
	Kit.wall(self, c0 + Vector3(dirx * length, 0, 0.8), c0 + Vector3(dirx * (3.0 + 5 * 4.5 + 2.7), 0, 0.8), H, "wall/wallpaper_damask")
	# the rooms hang off the south side of the corridor (north of it is the crawl
	# behind bedroom B's skirting, which they used to be built straight through)
	var rz := c0.z + 2.6          # room centre
	var rn := c0.z + 0.8          # the room's wall on the corridor
	var rf := c0.z + 4.4          # the far wall
	for k in 6:
		var rx := c0.x + dirx * (3.0 + k * 4.5)
		Kit.floor(self, Vector3(rx, 0, rz), Vector2(3.6, 3.6), "wall/carpet_house")
		Kit.ceiling(self, Vector3(rx, H, rz), Vector2(3.6, 3.6), "wall/ceiling_plaster")
		Kit.wall(self, Vector3(rx + 1.8, 0, rf), Vector3(rx - 1.8, 0, rf), H, "wall/wallpaper_floral")
		Kit.wall(self, Vector3(rx - 1.8, 0, rf), Vector3(rx - 1.8, 0, rn), H, "wall/wallpaper_floral")
		Kit.wall(self, Vector3(rx + 1.8, 0, rn), Vector3(rx + 1.8, 0, rf), H, "wall/wallpaper_floral")
		Kit.wall(self, Vector3(rx - 0.6, 0, rn), Vector3(rx - 1.8, 0, rn), H, "wall/wallpaper_damask")
		Kit.wall(self, Vector3(rx + 1.8, 0, rn), Vector3(rx + 0.6, 0, rn), H, "wall/wallpaper_damask")
		Kit.box(self, Vector3(rx, H - 0.3, rn), Vector3(1.2, 0.6, 0.2), "wall/wallpaper_damask")
		Props.place(self, "bed_single", Vector3(rx - 0.8, 0, rf - 1.0), 180.0, 1.0)
		Props.place(self, "window_night", Vector3(rx + 0.9, 1.5, rf - 0.08), 0.0, 1.0, {"collision": "none"})
		Kit.sign(self, "props/painting_house", Vector3(rx + 1.2, 1.3, rf - 0.1), 180.0, Vector2(0.5, 0.5))
		Kit.light(self, Vector3(rx, H - 0.2, rz), Color(1.0, 0.8, 0.9), 0.8, 5.0)
		Kit.wall(self, Vector3(rx + 2.7, 0, rn), Vector3(rx + 1.8, 0, rn), H, "wall/wallpaper_damask")
		Kit.wall(self, Vector3(rx - 1.8, 0, rn), Vector3(rx - 2.7, 0, rn), H, "wall/wallpaper_damask")
	Kit.box(self, c0 + Vector3(dirx * length * 0.5, H + 0.15, 2.6), Vector3(length + 0.4, 0.3, 6.0), "stone/blocks_dark", {"solid": false})
	Kit.box(self, c0 + Vector3(dirx * length * 0.5, H * 0.5, 4.7), Vector3(length + 0.4, H, 0.3), "wood/planks_wall", {"solid": false})
	Readable.create(self, Vector3(c0.x + dirx * 3.0, 1.0, rf - 1.0), 180.0, "The child's bed", ["The same bed. The same window. The same drawing.", "Every room along this corridor is the same room. You are not sure the corridor is not also the same room."], {"name": "SameRoom", "size": Vector3(1.2, 0.8, 2.0), "note_key": "same_room", "note_title": "The same room", "note_text": "Behind the door that was not there: a corridor of the same child's bedroom, over and over."})
	var seam_x := c0.x + dirx * (3.0 + 4 * 4.5 + 2.2)
	var back_x := c0.x + dirx * (3.0 + 1 * 4.5 + 2.2)
	var fyaw := _yaw(-90.0)
	bedroom_seam = SeamlessTeleport.create(self, Vector3(seam_x, 0, c0.z), fyaw, Vector3(back_x, 0, c0.z), fyaw, Vector3(1.6, 2.6, 0.6), {"name": "BedroomLoop", "count_flag": "house_bedroom_loops", "on_teleport": _on_bedroom_loop})
	if Game.count("house_bedroom_loops") >= 4:
		bedroom_seam.enabled = false
	# the far end comes out in the hall, from the other side of the door that was not there
	SeamlessTeleport.create(self, Vector3(c0.x + dirx * (length - 0.5), 0, c0.z), fyaw, _m(12.0, 14.0), _yaw(90.0), Vector3(1.6, 2.6, 0.6), {"name": "BedroomEnd"})
	Kit.light(self, c0 + Vector3(dirx * 1.5, H - 0.2, 0), Color(1.0, 0.9, 0.7), 0.8, 5.0)


func _big_bathroom(bath_door: Vector3) -> void:
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
	# walking north through the bathroom doorway lands you in the huge bathroom; and back
	SeamlessTeleport.create(self, bath_door + Vector3(0, 0, -0.1), _yaw(0.0), e + Vector3(0, 0, -1.6), 0.0, Vector3(1.2, 2.4, 0.5), {"name": "BigBathIn"})
	# the way back: a door in the south wall, and the seam just inside it
	Props.place(self, "door_white", e + Vector3(0, 0, 0.94), 0.0, 1.0, {"collision": "none"})
	Kit.label(self, "out", e + Vector3(0, 2.35, 0.9), 0.0, 28, Color(0.5, 0.6, 0.65), "body", {"pixel_size": 0.012})
	Kit.light(self, e + Vector3(0, 2.4, 0.2), Color(0.9, 1.0, 1.0), 0.9, 5.0)
	SeamlessTeleport.create(self, e + Vector3(0, 0, 0.35), 180.0, bath_door + Vector3(0, 0, 0.5), _yaw(180.0), Vector3(2.0, 2.4, 0.8), {"name": "BigBathOut"})


func _between_walls(hole: Vector3) -> void:
	var dirx := -1.0 if mirrored else 1.0
	var start := hole + Vector3(dirx * 0.3, 0, 0)
	var len := 6.0
	var ch := 0.8   # headroom: the small player is 0.5 m tall, so 0.45 used to wedge shut
	# a floor under the carved wall itself, or the crawl opens onto nothing
	Kit.floor(self, hole + Vector3(dirx * 0.8, 0, 0), Vector2(1.6, 0.7), "wood/planks_dark", {"tile": 0.5})
	Kit.floor(self, start + Vector3(dirx * len * 0.5, 0, 0), Vector2(len, 0.7), "wood/planks_dark", {"tile": 0.5})
	Kit.ceiling(self, start + Vector3(dirx * len * 0.5, ch, 0), Vector2(len, 0.7), "wood/planks_dark", {"tile": 0.5})
	Kit.wall(self, start + Vector3(0, 0, -0.35), start + Vector3(dirx * len, 0, -0.35), ch, "wood/planks_dark", {"tile": 0.5})
	Kit.wall(self, start + Vector3(dirx * len, 0, 0.35), start + Vector3(0, 0, 0.35), ch, "wood/planks_dark", {"tile": 0.5})
	var room := start + Vector3(dirx * (len + 1.0), 0, 0)
	Kit.floor(self, room, Vector2(2.0, 2.0), "wood/planks_dark", {"tile": 0.5})
	Kit.ceiling(self, room + Vector3(0, ch, 0), Vector2(2.0, 2.0), "wood/planks_dark", {"tile": 0.5})
	Kit.wall(self, room + Vector3(-1, 0, -1), room + Vector3(1, 0, -1), ch, "wood/planks_dark", {"tile": 0.5})
	Kit.wall(self, room + Vector3(1, 0, -1), room + Vector3(1, 0, 1), ch, "wood/planks_dark", {"tile": 0.5})
	Kit.wall(self, room + Vector3(1, 0, 1), room + Vector3(-1, 0, 1), ch, "wood/planks_dark", {"tile": 0.5})
	Kit.wall(self, room + Vector3(-1, 0, 1), room + Vector3(-1, 0, -1), ch, "wood/planks_dark", {"tile": 0.5})
	Kit.light(self, room + Vector3(0, ch - 0.15, 0), Color(1.0, 0.8, 0.5), 0.6, 3.0)
	Kit.light(self, start + Vector3(dirx * len * 0.5, ch - 0.15, 0), Color(1.0, 0.75, 0.45), 0.4, 3.5)
	Props.place(self, "candle", room + Vector3(0.5, 0, 0.4), 0.0, 0.5, {"collision": "none"})
	Readable.create(self, room + Vector3(-0.4, 0.15, -0.4), 0.0, "A very small note", ["THE HOUSE KEEPS ITS SPARE ROOMS IN HERE.", "PLEASE DO NOT TAKE MORE THAN ONE."], {"name": "SpareRooms", "size": Vector3(0.3, 0.2, 0.3), "note_key": "spare_rooms", "note_title": "Between the walls", "note_text": "Behind the skirting board, a passage for someone very small. The house keeps its spare rooms there. Please do not take more than one."})
	Pickup.create(self, room + Vector3(0.4, 0, -0.3), {"item": "candle_stub", "requires_keepsake": "mouse", "name": "WallCandle", "key": "picked_candle_house"})


func _attic(hatch_below: Vector3) -> void:
	var hatch := hatch_below + Vector3(0, H, 0)
	Props.place(self, "attic_hatch" if Props.exists("attic_hatch") else "crate_small", hatch + Vector3(0, -0.02 if Props.exists("attic_hatch") else -0.5, 0), 0.0, 1.0, {"collision": "none"})
	# under the ridge, short enough that nothing pokes through the slope
	var attic_floor := hatch + Vector3(0, 0.3, 0)
	var ah := 1.7
	Kit.floor(self, attic_floor + Vector3(0, 0, -0.75), Vector2(4.0, 4.5), "wood/planks_grey", {"tile": 1.5})
	Kit.ceiling(self, attic_floor + Vector3(0, ah, -0.75), Vector2(4.0, 4.5), "wood/planks_dark", {"tile": 1.5})
	Kit.wall(self, attic_floor + Vector3(-2, 0, 1.5), attic_floor + Vector3(-2, 0, -3.0), ah, "wood/planks_dark", {"tile": 1.5})
	Kit.wall(self, attic_floor + Vector3(2, 0, -3.0), attic_floor + Vector3(2, 0, 1.5), ah, "wood/planks_dark", {"tile": 1.5})
	Kit.wall(self, attic_floor + Vector3(-2, 0, -3.0), attic_floor + Vector3(2, 0, -3.0), ah, "wood/planks_dark", {"tile": 1.5})
	Kit.wall(self, attic_floor + Vector3(2, 0, 1.5), attic_floor + Vector3(-2, 0, 1.5), ah, "wood/planks_dark", {"tile": 1.5})
	Props.place(self, "boxes_moving" if Props.exists("boxes_moving") else "crate", attic_floor + Vector3(-1.2, 0, -2.0), 15.0, 0.8)
	Props.place(self, "crate_small", attic_floor + Vector3(1.2, 0, -2.4), 40.0, 1.0)
	Props.place(self, "coat_rack", attic_floor + Vector3(1.4, 0, 0.9), 0.0, 0.85)
	Kit.light(self, attic_floor + Vector3(0, ah - 0.2, -0.8), Color(1.0, 0.85, 0.6), 0.9, 6.0)
	Readable.create(self, attic_floor + Vector3(-1.2, 0.7, -2.0), 0.0, "The box of photographs", ["A box of photographs. All of them are of the porch.", "None of them have anyone on it. Not yet."], {"name": "PhotoBox", "size": Vector3(1.0, 0.8, 1.0), "note_key": "photo_box", "note_title": "The box of photographs", "note_text": "A box of photographs of the porch, with nobody on it. Not yet."})
	var win := attic_floor + Vector3(0, 1.0, -2.9)
	Kit.sign(self, "props/window_night", win, 0.0, Vector2(1.0, 1.0))
	Readable.create(self, win, 0.0, "Look out of the attic window", ["From the attic window you can see the field, and the sky above the field.", "The sky has a light fitting in it. It is switched off. Somebody is being careful about the bill."], {"name": "AtticWindow", "size": Vector3(1.0, 1.0, 0.4), "note_key": "sky_fitting", "note_title": "The light fitting in the sky", "note_text": "From the attic you saw it: the sky over the field has a light fitting in it, switched off."})
	var hatch_it := Interactable.make(self, hatch + Vector3(0, -0.3, 0), Vector3(1.2, 0.5, 1.2), "The attic hatch", _on_hatch, {"name": "AtticHatch"})
	hatch_it.set_meta("attic_pos", attic_floor + Vector3(0, 0.1, 0.5))
	# and from above, the same hatch, the other way
	var below := hatch_below + Vector3(0, 0.1, 1.2)
	Interactable.make(self, attic_floor + Vector3(0, 0.15, 0), Vector3(1.4, 0.4, 1.4), "Climb back down through the hatch", func(p: Node, _it: Node) -> void:
		if p is Player:
			Audio.sfx("creak", attic_floor, -6.0)
			(p as Player).global_position = below, {"name": "AtticHatchDown"})
	if Game.has_flag("photo_returned"):
		Kit.stairs(self, hatch_below + Vector3(0, 0, 1.2), 0.0, 0.8, 9, 0.33, 0.3, "wood/planks_grey", {"name": "AtticLadder"})


func _roof_and_porch() -> void:
	var h := H + 0.1
	Kit.ramp(self, Vector3(0, h, 7.9), 0.0, 23.0, 8.0, 3.2, "stone/blocks_dark", {"tile": 1.5})
	Kit.ramp(self, Vector3(0, h, -7.9), 180.0, 23.0, 8.0, 3.2, "stone/blocks_dark", {"tile": 1.5})
	Kit.box(self, Vector3(_v(5.0, 0, 0).x, h + 3.8, 0.0), Vector3(1.0, 2.8, 1.0), "brick/dark")
	# gables: triangles under the roof's slope, drawn on both sides
	for gx in [-11.15, 11.15]:
		var a := Vector3(gx, h, -7.9)
		var b := Vector3(gx, h + 3.2, 0.0)
		var c := Vector3(gx, h, 7.9)
		Kit.quad(self, a, b, c, c, "wood/planks_wall", {"tint": Color(0.7, 0.65, 0.6), "solid": false, "double": true})
	# porch
	var door_x := _m(11.0, 0).x
	var pz := 9.7
	Kit.floor(self, Vector3(door_x, 0.12, pz), Vector2(7.0, 4.4), "wood/planks_grey", {"thick": 0.24})
	for px in [door_x - 3.2, door_x + 3.2]:
		Kit.box(self, Vector3(px, 1.5, pz + 1.9), Vector3(0.2, 3.0, 0.2), "wood/planks_grey")
	Kit.box(self, Vector3(door_x, 3.1, pz), Vector3(7.4, 0.2, 4.6), "wood/planks_grey")
	Props.place(self, "lantern_hanging", Vector3(door_x + 1.2, 3.0, pz), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, Vector3(door_x + 1.2, 2.4, pz), Color(1.0, 0.85, 0.55), 1.6, 9.0)
	Props.place(self, "chair", Vector3(door_x - 2.2, 0.24, pz - 0.6), _yaw(150.0), 1.0)
	Props.place(self, "window_lit", Vector3(door_x - 4.5, 1.6, 7.55), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "window_night", Vector3(door_x + 4.5, 1.6, 7.55), 180.0, 1.0, {"collision": "none"})


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


# --- callbacks -------------------------------------------------------------------

func _on_backwards(p: Node) -> void:
	var player := p as Player
	if player == null:
		return
	var fwd := player.forward()
	var v := player.velocity
	v.y = 0.0
	# into the hall is the way the door faces; walking backwards into it means
	# facing into the hall and pressing back. The wall stops the velocity the
	# moment you touch it, so intent is read from facing and input instead.
	var into_hall := _v(1.0, 0, 0)
	var facing_away := fwd.dot(into_hall) > 0.4
	var backing := Input.is_action_pressed("move_back") and not player.input_locked
	var moving_back := v.length() > 0.5 and v.normalized().dot(fwd) < -0.5
	if facing_away and (backing or moving_back):
		var t: Node = get_node("BackwardsTrigger")
		var dest: Vector3 = t.get_meta("dest")
		player.global_position = dest + Vector3(0, 0.1, 0)
		Audio.sfx("door_creak_long", dest, -6.0)
		Game.bump("backwards_entries")
	elif not facing_away and Game.count("backwards_hint") < 3 and (v.length() > 0.5 or Input.is_action_pressed("move_forward")):
		Game.bump("backwards_hint")
		Game.toast.emit("The door does not open for people facing it. Turn your back on it and step back.")


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
	elif World.hud:
		await World.hud.say("", ["An empty frame. The wallpaper behind it is brighter than the rest.", "Whatever was in it has been taken somewhere with filing cabinets."])


func _on_cupboard(_p: Node, it: Node) -> void:
	if not Game.has_flag("house_biscuit"):
		Game.set_flag("house_biscuit", true)
		Game.gain_item("dog_biscuit")
		Audio.sfx("wood_knock", it.global_position, -10.0)
		if World.hud:
			await World.hud.say("", ["Tins with no labels. A box of dog biscuits, shaped like bones.", "You take one. The dog would want you to."])
	elif World.hud:
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
	elif World.hud:
		await World.hud.say("", ["The attic hatch. Too high to reach, and no ladder.", "If you could fly. Or if the house liked you more: there is a frame in the living room with nothing in it, and somewhere with filing cabinets there is what was in it."])
