extends AreaBase
## The Hallway — what is behind the closet once the dream has leaked. A black
## corridor that is longer than the flat, wider than the building and taller
## than the roof. It grows as you walk. It repeats itself. With a tape measure
## you can prove that it should not fit, and the difference is a number the
## front door wants.
##
## Side doors appear only after you have measured; the far end has a stair
## that goes down forever (three times) and a door far too large for a flat.

const SEG_LEN := 7.5
const SEGMENTS := 12
var seam: SeamlessTeleport = null
var stair_seam: SeamlessTeleport = null
var growl_timer: Timer = null


func build() -> void:
	can_wake = false
	Realm.apply(self, "hallway")
	var wall_tex := "wall/hallway_black"
	var floor_tex := "wall/hallway_grey"
	# closet interior: narrow, low, full of coats
	var cw := 1.3
	Kit.floor(self, Vector3(0, 0, 1.5), Vector2(cw, 3.0), "wood/planks_white")
	Kit.ceiling(self, Vector3(0, 2.2, 1.5), Vector2(cw, 3.0), "wall/ceiling_plaster")
	Kit.wall(self, Vector3(-cw * 0.5, 0, 3.0), Vector3(-cw * 0.5, 0, 0.0), 2.2, "wall/plaster_cream")
	Kit.wall(self, Vector3(cw * 0.5, 0, 0.0), Vector3(cw * 0.5, 0, 3.0), 2.2, "wall/plaster_cream")
	Kit.wall(self, Vector3(cw * 0.5, 0, 3.0), Vector3(-cw * 0.5, 0, 3.0), 2.2, "wall/plaster_cream")
	Props.place(self, "coat_rack", Vector3(-0.35, 0, 2.3), 0.0, 0.9)
	Props.place(self, "crate_small", Vector3(0.35, 0, 2.5), 20.0, 1.0)
	Kit.light(self, Vector3(0, 1.9, 2.0), Color(1.0, 0.9, 0.75), 0.7, 4.0)
	Kit.light(self, Vector3(0, 2.0, -1.5), Color(0.6, 0.65, 0.85), 0.6, 6.0)
	Door.create(self, Vector3(0, 0, 2.95), 180.0, "apartment", "closet", {"kind": "white", "label": "Back into the bedroom", "name": "ClosetBack", "walk_through": false})
	add_spawn("entrance", Vector3(0, 0.1, 1.2), 0.0)
	add_spawn("default", Vector3(0, 0.1, 1.2), 0.0)
	# where the back of the closet should be, there is no back.
	# the hallway proper: grows from a slit to a nave
	var z := 0.0
	var prev_w := cw
	var prev_h := 2.2
	for i in SEGMENTS:
		var t := float(i) / (SEGMENTS - 1)
		if i >= 7 and i <= 10:
			t = 7.0 / (SEGMENTS - 1)
		var w := lerpf(1.4, 5.5, t)
		var h := lerpf(2.6, 9.5, t)
		var z0 := z
		var z1 := z - SEG_LEN
		Kit.floor(self, Vector3(0, 0, (z0 + z1) * 0.5), Vector2(w, SEG_LEN), floor_tex, {"tile": 1.5})
		Kit.ceiling(self, Vector3(0, h, (z0 + z1) * 0.5), Vector2(w, SEG_LEN), wall_tex)
		Kit.wall(self, Vector3(-w * 0.5, 0, z0), Vector3(-w * 0.5, 0, z1), h, wall_tex, {"tile": 3.0})
		Kit.wall(self, Vector3(w * 0.5, 0, z1), Vector3(w * 0.5, 0, z0), h, wall_tex, {"tile": 3.0})
		# step walls where it widens
		if w > prev_w + 0.01:
			Kit.wall(self, Vector3(-prev_w * 0.5, 0, z0), Vector3(-w * 0.5, 0, z0), h, wall_tex, {"tile": 3.0})
			Kit.wall(self, Vector3(w * 0.5, 0, z0), Vector3(prev_w * 0.5, 0, z0), h, wall_tex, {"tile": 3.0})
			Kit.box(self, Vector3(0, (prev_h + h) * 0.5, z0), Vector3(w, h - prev_h, 0.2), wall_tex, {"tile": 3.0})
		# a cold dim light in every segment, so it is never quite black: you can
		# always see the floor and the walls, just not what is written on them
		Kit.light(self, Vector3(0, minf(h - 0.5, 3.2), (z0 + z1) * 0.5), Color(0.55, 0.6, 0.8), 0.75 if i % 2 == 0 else 0.5, w + 7.0)
		prev_w = w
		prev_h = h
		z = z1
	var end_z := z
	# measuring point, before it grows
	Interactable.make(self, Vector3(0.55, 1.0, -6.0), Vector3(0.3, 1.5, 1.2), "Measure the hallway", _on_measure, {"name": "MeasurePoint"})
	Kit.label(self, "|", Vector3(0.66, 1.2, -6.0), 90.0, 40, Color(0.6, 0.6, 0.6), "body", {"pixel_size": 0.01})
	Puzzle.declare(self, "hallway_measure", "hallway_measured", ["item:tape_measure"], "measure the hallway with the tape from the kitchen drawer", {"item": "door_code"})
	# inscriptions you only see by lantern light
	var insc := Node3D.new()
	insc.name = "Inscriptions"
	add_child(insc)
	Kit.label(insc, "THIS IS NOT FOR YOU", Vector3(-1.4, 1.6, -30.0), -90.0, 48, Color(0.8, 0.1, 0.1), "display", {"pixel_size": 0.012})
	Kit.label(insc, "5 ½", Vector3(2.2, 2.0, -60.0), 90.0, 90, Color(0.8, 0.75, 0.6), "title", {"pixel_size": 0.014})
	Kit.label(insc, "the house is six feet wrong", Vector3(-2.7, 3.5, -82.0), -90.0, 40, Color(0.6, 0.6, 0.7), "body", {"pixel_size": 0.012})
	Kit.lantern_only(insc)
	# side door to the field (only after measuring)
	if Game.has_flag("hallway_measured"):
		var sw := lerpf(1.4, 5.5, 6.0 / (SEGMENTS - 1)) * 0.5
		Door.create(self, Vector3(sw - 0.16, 0, -46.0), 90.0, "house", "field", {"kind": "dark", "label": "A door that was not there before", "name": "FieldDoor", "fade_color": Color(0.02, 0.03, 0.08), "fade_duration": 1.2})
		Kit.light(self, Vector3(sw - 1.0, 2.2, -46.0), Color(0.6, 0.7, 1.0), 0.6, 4.0)
		add_spawn("side", Vector3(sw - 1.4, 0.1, -46.0), 90.0)
	else:
		add_spawn("side", Vector3(0, 0.1, -46.0), 0.0)
	# the loop: segment 10 folds back onto segment 7 (twice)
	seam = SeamlessTeleport.create(self, Vector3(0, 0, -75.0), 0.0, Vector3(0, 0, -52.5), 0.0, Vector3(7, 10, 0.6), {"name": "LoopSeam", "count_flag": "hallway_loops", "on_teleport": _on_loop})
	if Game.count("hallway_loops") >= 2:
		seam.enabled = false
	# the landing at the end
	var lw := 5.5
	var landing_z := end_z - 6.0
	# the landing floor, with a hole where the stair shaft goes down (x -7..-2.9, z landing_z-4..landing_z)
	Kit.floor(self, Vector3(0, 0, landing_z + 3.0), Vector2(14.0, 6.0), floor_tex, {"tile": 1.5})
	Kit.floor(self, Vector3(0, 0, landing_z - 5.0), Vector2(14.0, 2.0), floor_tex, {"tile": 1.5})
	Kit.floor(self, Vector3(2.05, 0, landing_z - 2.0), Vector2(9.9, 4.0), floor_tex, {"tile": 1.5})
	Kit.ceiling(self, Vector3(0, 9.5, landing_z), Vector2(14.0, 12.0), wall_tex)
	Kit.wall(self, Vector3(-7, 0, end_z), Vector3(-7, 0, landing_z - 6.0), 9.5, wall_tex, {"tile": 3.0})
	Kit.wall(self, Vector3(7, 0, landing_z - 6.0), Vector3(7, 0, end_z), 9.5, wall_tex, {"tile": 3.0})
	Kit.wall(self, Vector3(-lw * 0.5, 0, end_z), Vector3(-7, 0, end_z), 9.5, wall_tex, {"tile": 3.0})
	Kit.wall(self, Vector3(7, 0, end_z), Vector3(lw * 0.5, 0, end_z), 9.5, wall_tex, {"tile": 3.0})
	Kit.wall(self, Vector3(-7, 0, landing_z - 6.0), Vector3(7, 0, landing_z - 6.0), 9.5, wall_tex, {"tile": 3.0})
	var big := Door.create(self, Vector3(0, 0, landing_z - 5.85), 0.0, "nexus", "from_hallway", {"kind": "big", "label": "A door far too large for a flat", "name": "BigDoor", "sets_flag": "hallway_end", "fade_duration": 1.4})
	Kit.light(self, Vector3(0, 4.0, landing_z - 4.0), Color(0.5, 0.55, 0.9), 0.9, 10.0)
	add_spawn("end", Vector3(0, 0.1, landing_z - 4.0), 180.0)
	Kit.label(self, "you are late", Vector3(0, 5.2, landing_z - 5.8), 0.0, 44, Color(0.5, 0.5, 0.6), "display", {"pixel_size": 0.012})
	# the stair that goes down forever (three times)
	_build_stair(Vector3(-5.0, 0, landing_z), wall_tex, floor_tex)
	Kit.particles(self, Vector3(0, 3, -40), "motes", Vector3(3, 3, 40), 40)
	Puzzle.declare(self, "hallway_loops", "", [], "walk the far end twice")
	Puzzle.declare(self, "hallway_stair", "", [], "go down the stair at the end until it is embarrassed (three times)", {"route": "catacombs:from_stairs"})


func _build_stair(pos: Vector3, wall_tex: String, floor_tex: String) -> void:
	# a square shaft with a flight down each wall; the bottom seam sends you back to the top
	var shaft := Node3D.new()
	shaft.name = "Shaft"
	shaft.position = pos
	add_child(shaft)
	var size := 4.0
	var depth := 8.0
	Kit.box(shaft, Vector3(0, -depth * 0.5, 0.1), Vector3(size + 0.4, depth, 0.2), wall_tex, {"faces": ["nz"], "tile": 3.0})
	Kit.box(shaft, Vector3(0, -depth * 0.5, -size), Vector3(size + 0.4, depth, 0.2), wall_tex, {"faces": ["nz", "pz"], "tile": 3.0})
	Kit.box(shaft, Vector3(-size * 0.5 - 0.1, -depth * 0.5, -size * 0.5), Vector3(0.2, depth, size), wall_tex, {"faces": ["px"], "tile": 3.0})
	Kit.box(shaft, Vector3(size * 0.5 + 0.1, -depth * 0.5, -size * 0.5), Vector3(0.2, depth, size), wall_tex, {"faces": ["nx"], "tile": 3.0})
	# the landing floor has a hole above the shaft (see build()); the first flight starts at floor level
	Kit.stairs(shaft, Vector3(size * 0.5 - 0.6, 0.0, 0.0), 0.0, 1.2, 12, -0.25, 0.33, floor_tex, {"name": "FlightA"})
	Kit.stairs(shaft, Vector3(0.6 - size * 0.5, -3.0, -size), 180.0, 1.2, 12, -0.25, 0.33, floor_tex, {"name": "FlightB"})
	Kit.floor(shaft, Vector3(-size * 0.5 + 0.6, -3.0, -size + 0.6), Vector2(1.2, 1.2), floor_tex)
	Kit.floor(shaft, Vector3(size * 0.5 - 0.6, -6.0, -0.6), Vector2(1.2, 1.2), floor_tex)
	Kit.light(shaft, Vector3(0, -2.0, -size * 0.5), Color(0.5, 0.55, 0.7), 0.5, 7.0)
	# bottom → top seam (looks the same: the shaft repeats)
	stair_seam = SeamlessTeleport.create(shaft, Vector3(size * 0.5 - 0.6, -6.0, -0.6), 0.0, Vector3(size * 0.5 - 0.6, 0.0, 0.6), 0.0, Vector3(1.4, 2.5, 0.5), {"name": "StairSeam", "count_flag": "stairs_loops", "one_way": false, "on_teleport": _on_stair_loop})
	if Game.count("stairs_loops") >= 3:
		stair_seam.enabled = false
		Door.create(shaft, Vector3(size * 0.5 - 0.6, -6.0, -1.15), 0.0, "catacombs", "from_stairs", {"kind": "dark", "label": "A door at the bottom of the stairs", "name": "StairDoor"})
		Kit.light(shaft, Vector3(size * 0.5 - 0.6, -4.5, -1.0), Color(1.0, 0.6, 0.3), 0.8, 5.0)
	add_spawn("stairs", pos + Vector3(size * 0.5 - 0.6, 0.1, 1.5), 0.0)


func _on_measure(_p: Node, _it: Node) -> void:
	if not Game.has_item("tape_measure"):
		if World.hud:
			await World.hud.say("", ["You would need something to measure with.", "The wall on the other side of this is twenty-one feet long. You know that. You have hung pictures on it."])
		return
	Audio.sfx("tape_measure", global_position, -4.0)
	if World.hud:
		await World.hud.say("", [
			"You walk the tape along the wall to where the closet should end, and past it.",
			"Twenty-seven feet, four inches.",
			"The bedroom wall it runs behind is twenty-one feet long. You measured it when you hung the picture.",
			"The difference is six feet, four inches. You write 0604 on the back of your hand, because you do not trust anything else to remember it.",
		])
	if not Game.has_flag("hallway_measured"):
		Game.set_flag("hallway_measured", true)
		Game.gain_item("door_code")
		Game.note("measured", "The hallway measured", "Inside: 27 ft 4 in. Outside: 21 ft. The flat is six feet and four inches wrong. Next time you come here there will be a door in the wall on the right. You are sure of it.")
		Game.toast.emit("Something behind the wall on the right takes note.")


func _on_loop(_p: Node) -> void:
	var n := Game.count("hallway_loops")
	if n == 1:
		Game.toast.emit("You have the feeling you have walked this part already.")
	elif n >= 2:
		if seam:
			seam.enabled = false
		Game.note("hallway_loop", "The part that repeats", "Two lengths of the hallway are the same length of hallway. On the third pass it gave up pretending.")


func _on_stair_loop(_p: Node) -> void:
	var n := Game.count("stairs_loops")
	Audio.sfx("creak", global_position, -8.0)
	if n == 1:
		Game.toast.emit("The stair keeps going down.")
	elif n == 2:
		Game.toast.emit("The stair keeps going down. You are almost sure you have passed this step.")
	elif n >= 3 and stair_seam:
		stair_seam.enabled = false
		Game.toast.emit("The stair, embarrassed, ends.")
		World.reload_here("stairs", {"duration": 0.3, "silent": true})


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	Game.set_flag("hallway_found", true)
	growl_timer = Timer.new()
	growl_timer.wait_time = 45.0
	growl_timer.autostart = true
	growl_timer.timeout.connect(func() -> void:
		Audio.sfx("growl", player_pos() + Vector3(0, 2, -12), -4.0)
		Game.bump("growls_heard"))
	add_child(growl_timer)
	var five := Timer.new()
	five.wait_time = 330.0
	five.one_shot = true
	five.autostart = true
	five.timeout.connect(func() -> void:
		Game.note("five_and_a_half", "Five and a half minutes", "You have been in the hallway for five and a half minutes. It has been five and a half minutes for a long time.")
		Usher.spawn(self, player_pos() + Vector3(0, 0, -9), {"appear_delay": 1.0}))
	add_child(five)
