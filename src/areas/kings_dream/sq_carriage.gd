class_name KDCarriage
extends RefCounted
## The third square: the Carriage. You cross a brook and you are on a train,
## and the train is the corridor of the Halden Arms with the doors numbered on
## both sides and no end to it. Door 5½ is here, locked, with a keypad. The
## guard wants a ticket and the dispenser gives you the same number every
## time. The train does not stop: the corridor repeats through a seam, and
## only while the hour is held does the far end have an end, which is a door
## onto a platform between stations that is not on the board at all.
##
## Quotes the Halden Arms, the Waiting Halls and Flat 5½.

const W := 3.4
const H := 2.9
const Z_BACK := 34.0          # the rear door, just inside the gate
const LOOP_A := -26.0         # walking north past here...
const LOOP_B := -2.0          # ...puts you here, still walking north
const Z_FRONT := -30.0        # the guard's van, beyond the loop
const PLATFORM := Vector3(0, 0, -36.0)
const WALL := "wall/plaster_green"
const CARPET := "wall/carpet_house"
const LAMP := Color(0.85, 0.95, 0.9)


static func build(area: AreaBase, root: Node3D, ctx: Dictionary) -> Dictionary:
	var d: Dictionary = ctx.def
	var state := {"seam": null, "scenery": [], "t": 0.0, "clack": 0.0, "van": null}
	# the gates stand on their own strips; the train runs on a trackbed three metres
	# down, which is where you land if you step off, with stairs back up
	Kit.floor(root, Vector3(0, 0, 41.0), Vector2(KD.SQ + 2.0, 9.0), String(d.ground), {"tint": d.tint, "tile": 2.0, "thick": 0.2})
	Kit.floor(root, Vector3(0, 0, -41.0), Vector2(KD.SQ + 2.0, 9.0), String(d.ground), {"tint": d.tint, "tile": 2.0, "thick": 0.2})
	Kit.floor(root, Vector3(0, 0, 36.0), Vector2(6.0, 4.0), "wall/concrete", {"tile": 1.5, "thick": 0.2})
	_trackbed(area, root, d)
	_carriage(area, root, state)
	_doors(area, root, state)
	_scenery(area, root, state)
	_platform(area, root, state)
	var out := {}
	out["gates"] = {"N": false, "S": true}
	out["on_process"] = func(delta: float) -> void:
		_tick(state, delta)
	out["on_freeze"] = func(frozen: bool) -> void:
		_freeze(state, frozen)
	out["usher"] = Vector3(0, 0, -34.0)
	return out


# --- the corridor that is a carriage -------------------------------------------------

static func _carriage(_area: AreaBase, root: Node3D, _state: Dictionary) -> void:
	var z0 := Z_BACK
	var z1 := Z_FRONT - 4.0
	var mid := (z0 + z1) * 0.5
	var len := z0 - z1
	Kit.floor(root, Vector3(0, 0, mid), Vector2(W, len), CARPET, {"tile": 1.5})
	Kit.ceiling(root, Vector3(0, H, mid), Vector2(W, len), "wall/ceiling_tile", {"tile": 1.2})
	# the walls, in four-metre modules: doors on solid ones, windows cut in the others
	var zz := z0
	var m := 0
	while zz > z1:
		var za := zz
		var zb := maxf(zz - 4.0, z1)
		for side in [-1.0, 1.0]:
			var x: float = side * W * 0.5
			var a := Vector3(x, 0, za if side < 0 else zb)
			var b := Vector3(x, 0, zb if side < 0 else za)
			if m % 2 == 0:
				Kit.wall(root, a, b, H, WALL)
			else:
				# sill, lintel and two piers round an opening the size of the window frame,
				# 1.1 to 2.3 m up, so the frame sits in the hole and not beside it
				var zc := (za + zb) * 0.5
				Kit.box(root, Vector3(x, 0.55, zc), Vector3(0.2, 1.1, za - zb), WALL, {"tile": 2.0})
				Kit.box(root, Vector3(x, 2.6, zc), Vector3(0.2, 0.6, za - zb), WALL, {"tile": 2.0})
				Kit.box(root, Vector3(x, 1.7, (za + zc + 0.55) * 0.5), Vector3(0.2, 1.2, za - zc - 0.55), WALL, {"tile": 2.0})
				Kit.box(root, Vector3(x, 1.7, (zb + zc - 0.55) * 0.5), Vector3(0.2, 1.2, zc - 0.55 - zb), WALL, {"tile": 2.0})
				Kit.blocker(root, Vector3(x, 1.7, zc), Vector3(0.1, 1.2, 1.1))
		zz -= 4.0
		m += 1
	# the outside of the carriage: dark green coachwork, a roof, and wheels that never turn
	Kit.box(root, Vector3(0, H + 0.4, mid), Vector3(W + 1.0, 0.8, len + 1.0), "wood/planks_dark", {"tint": Color(0.5, 0.6, 0.45), "solid": false, "tile": 2.0})
	Kit.box(root, Vector3(-W * 0.5 - 0.35, H * 0.5, mid), Vector3(0.3, H, len + 1.0), "wood/planks_dark", {"faces": ["nx"], "tint": Color(0.35, 0.5, 0.35), "solid": false, "tile": 2.0})
	Kit.box(root, Vector3(W * 0.5 + 0.35, H * 0.5, mid), Vector3(0.3, H, len + 1.0), "wood/planks_dark", {"faces": ["px"], "tint": Color(0.35, 0.5, 0.35), "solid": false, "tile": 2.0})
	Kit.box(root, Vector3(0, -0.6, mid), Vector3(W + 1.0, 1.0, len + 1.0), "metal/iron", {"solid": false, "tile": 2.0})
	for k in 8:
		var z := z0 - 4.0 - k * 8.0
		for sx in [-1.0, 1.0]:
			Kit.cylinder(root, Vector3(sx * (W * 0.5 + 0.55), -1.2, z), 0.6, 0.3, "metal/iron", {"solid": false, "segments": 10, "rotation": Vector3(0, 0, 90)})
	# the rear door, open, that you came in by
	Kit.wall(root, Vector3(W * 0.5, 0, z0), Vector3(1.0, 0, z0), H, WALL)
	Kit.wall(root, Vector3(-1.0, 0, z0), Vector3(-W * 0.5, 0, z0), H, WALL)
	Kit.box(root, Vector3(0, H - 0.3, z0), Vector3(2.0, 0.6, 0.2), WALL)
	Kit.label(root, "THE HALDEN ARMS", Vector3(0, 2.35, z0 + 0.12), 180.0, 22, Color(0.85, 0.8, 0.7), "display", {"pixel_size": 0.01})
	Kit.sign(root, "signs/halden_arms", Vector3(0, 1.4, z0 + 0.12), 180.0, Vector2(1.4, 0.5))
	# lights every eight metres, the flat ones
	var k := 0
	var z := z0 - 3.0
	while z > z1:
		Props.place(root, "fluorescent_light", Vector3(0, H - 0.02, z), 0.0, 1.0, {"collision": "none"})
		Kit.light(root, Vector3(0, H - 0.4, z), LAMP, 0.8 if k % 3 != 1 else 0.45, 7.0)
		z -= 8.0
		k += 1
	# seats between the doors on the east side, and windows above them, both sides
	z = z0 - 6.0
	while z > z1 + 4.0:
		Props.place(root, "carriage_seat", Vector3(W * 0.5 - 0.42, 0, z), 90.0, 1.0, {"collision": "box"})
		Props.place(root, "crate_small", Vector3(-W * 0.5 + 0.35, 0, z + 1.6), 15.0, 0.7, {"collision": "box", "tint": Color(0.8, 0.7, 0.6)})
		Props.place(root, "carriage_window", Vector3(W * 0.5 - 0.08, 1.7, z), 90.0, 1.0, {"collision": "none"})
		Props.place(root, "carriage_window", Vector3(-W * 0.5 + 0.08, 1.7, z), -90.0, 1.0, {"collision": "none"})
		z -= 8.0
	Kit.particles(root, Vector3(0, 1.5, mid), "motes", Vector3(1.2, 1.0, len * 0.5), 60)
	Readable.create(root, Vector3(W * 0.5 - 0.4, 1.7, z0 - 14.0), 90.0, "Look out of the window", [
		"Country going past, painted, in squares. Then a town, with a church and a clock tower, and the clock says half past five.",
		"It comes round again. The clock still says half past five. It is the same town every time and it has not noticed.",
	], {"name": "WindowLook", "size": Vector3(0.3, 1.2, 1.2), "note_key": "dream_window", "note_title": "The town outside the train", "note_text": "A town goes past the carriage windows with a clock tower that says half past five. It comes round again, the same town, and does not notice."})


## Doors numbered on both sides, and 5½ among them. The corridor repeats.
static func _doors(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var numbers := ["3", "4", "5", "5½", "6", "7"]
	var z := Z_BACK - 2.0
	var i := 0
	while z > Z_FRONT - 2.0:
		var n: String = numbers[i % numbers.size()]
		var west := (i % 2 == 0)
		if int((Z_BACK - z) / 4.0) % 2 == 1:
			# a window module: no door here
			z -= 4.0
			i += 1
			continue
		var x := (-W * 0.5 + 0.16) if west else (W * 0.5 - 0.16)
		var yaw := -90.0 if west else 90.0
		var pos := Vector3(x, 0, z)
		if n == "5½":
			_door_five_half(area, root, pos, yaw, west)
		else:
			var it := Interactable.make(root, pos, Vector3(0.5, 2.3, 1.2), "Knock on %s" % n, func(_p: Node, it2: Node) -> void:
				_knock(String(it2.get_meta("number"))), {"name": "Flat%s_%d" % [n, i], "yaw": yaw, "model": "door_wood", "collision": "none"})
			it.set_meta("number", n)
			Kit.blocker(root, pos + Vector3(0, 1.1, 0), Vector3(0.12, 2.2, 1.0))
			Kit.label(root, n, pos + Vector3(0.06 if west else -0.06, 1.95, 0), yaw, 40, Color(0.85, 0.8, 0.7), "display", {"pixel_size": 0.01})
		z -= 4.0
		i += 1
	# the chorus, painted small along the skirting
	var chorus := ["she must go back as luggage", "as luggage", "back", "by post", "the same number every time", "as luggage"]
	for k in chorus.size():
		var cz := Z_BACK - 5.0 - k * 5.5
		Kit.label(root, chorus[k], Vector3(-W * 0.5 + 0.03, 0.3, cz), -90.0, 14, Color(0.55, 0.5, 0.45), "body", {"pixel_size": 0.009, "outline": 0})
	# the ticket dispenser, which is a Waiting Halls one, bolted to the wall
	var tp := Vector3(W * 0.5 - 0.35, 0, Z_BACK - 3.4)
	Props.place(root, "ticket_dispenser", tp, 90.0, 1.0, {"collision": "cylinder"})
	Kit.sign(root, "signs/take_a_number", Vector3(W * 0.5 - 0.02, 2.1, Z_BACK - 3.4), 90.0, Vector2(0.7, 0.35))
	Interactable.make(root, tp + Vector3(0, 0.9, 0), Vector3(0.6, 1.2, 0.6), "Take a ticket", func(_p: Node, _it: Node) -> void:
		_ticket(area), {"name": "Ticket"})
	# the guard, half way along, examining everyone
	var gp := Vector3(0.9, 0, Z_BACK - 18.0)
	NPC.create(root, gp, 0.0, "The Guard", {"model": "barkeep", "name": "Guard", "prompt": "Show the Guard your ticket", "on_talk": func(_p: Node, n: NPC) -> bool:
		await _guard(n)
		return true, "lines": ["\"Ticket,\" says the Guard."]})
	Kit.light(root, gp + Vector3(0, 2.2, 0), Color(1.0, 0.9, 0.8), 0.6, 4.0)
	# the loop: the corridor repeats, and the train does not stop
	state.seam = SeamlessTeleport.create(area, area.sq[ctx_index(area)].origin + Vector3(0, 0, LOOP_A), 0.0, area.sq[ctx_index(area)].origin + Vector3(0, 0, LOOP_B), 0.0, Vector3(W, H, 0.6), {"name": "CarriageLoop", "count_flag": "dream_train_loops", "on_teleport": func(_p: Node) -> void:
		var n := Game.count("dream_train_loops")
		if n == 2:
			Game.toast.emit("You have passed door 5½ twice. The train has not passed anything.")
		elif n == 4:
			Game.toast.emit("It does not stop. Something would have to make it.")
			Game.note("dream_train", "The train that does not stop", "The carriage is the Halden Arms corridor, numbered on both sides, and it repeats. Door 5½ is on it, locked, with a keypad. The train does not stop for anyone; it would take something that stops everything.")})
	Puzzle.declare(area, "dream_train", "dream_off_train", ["keepsake:hourglass"], "hold the hour and walk to the front of the train, which has a front while it is held")


## Under the train: ballast, sleepers and rails, and the drop from the strips
## hedged so you do not take it by accident. Stairs at both ends come back up.
static func _trackbed(area: AreaBase, root: Node3D, d: Dictionary) -> void:
	var y := -3.0
	Kit.floor(root, Vector3(0, y, 0), Vector2(KD.SQ + 2.0, 73.0), "ground/gravel", {"tint": Color(0.7, 0.68, 0.7), "tile": 2.0, "thick": 0.3})
	# the faces of the strips, so the drop is a wall and not a hole in the world
	Kit.box(root, Vector3(0, y * 0.5, 36.5), Vector3(KD.SQ + 2.0, -y, 0.3), "wall/concrete_dark", {"tile": 2.0})
	Kit.box(root, Vector3(0, y * 0.5, -36.5), Vector3(KD.SQ + 2.0, -y, 0.3), "wall/concrete_dark", {"tile": 2.0})
	var k := 0
	var z := 34.0
	while z > -34.0:
		Kit.box(root, Vector3(0, y + 0.1, z), Vector3(6.0, 0.2, 0.5), "wood/planks_dark", {"tint": Color(0.5, 0.45, 0.4), "solid": false})
		z -= 1.4
		k += 1
	for sx in [-1.2, 1.2]:
		Kit.box(root, Vector3(float(sx), y + 0.3, 0), Vector3(0.14, 0.2, 68.0), "metal/iron", {"solid": false})
	# hedges along the inner edge of both strips, with gaps for the gangway and the stairs
	var hedge_tint: Color = d.hedge
	for side in [1.0, -1.0]:
		var hz: float = 36.5 * side
		KD.hedge(root, Vector3(-KD.HALF - 1.2, 0, hz), Vector3(-3.2, 0, hz), {"tint": hedge_tint, "height": 2.2, "thick": 0.8})
		KD.hedge(root, Vector3(3.2, 0, hz), Vector3(7.0, 0, hz), {"tint": hedge_tint, "height": 2.2, "thick": 0.8})
		KD.hedge(root, Vector3(9.4, 0, hz), Vector3(KD.HALF + 1.2, 0, hz), {"tint": hedge_tint, "height": 2.2, "thick": 0.8})
		# a stair from the trackbed up to the strip
		var foot := Vector3(8.2, y, 36.0 * side - 5.6 * side)
		Kit.stairs(root, foot, 180.0 if side > 0 else 0.0, 1.8, 12, -y / 12.0, 0.45, "wall/concrete", {"tile": 1.0, "name": "TrackStair%d" % int(side)})
		Kit.light(root, Vector3(8.2, y + 3.0, 33.0 * side), LAMP, 0.9, 8.0)
	# rails either side of the gangway, so the way into the carriage is a way and not an edge
	for sx in [-3.1, 3.1]:
		Kit.box(root, Vector3(float(sx), 0.5, 36.0), Vector3(0.1, 1.0, 4.4), "metal/iron")
	Readable.create(root, Vector3(0, y + 0.5, 30.0), 0.0, "The track", [
		"Sleepers and two rails, going both ways into the fog. The rails are warm. Nothing is on them; the train is beside them, which is not where trains go.",
		"Steps at either end lead back up to the strips. Somebody expected people to fall.",
	], {"name": "TrackLook", "size": Vector3(4.0, 1.5, 4.0)})
	Kit.light(root, Vector3(0, y + 2.5, 0), Color(0.8, 0.85, 1.0), 0.8, 14.0)
	area.rng.randf()


static func ctx_index(_area: AreaBase) -> int:
	return 1


static func _door_five_half(area: AreaBase, root: Node3D, pos: Vector3, yaw: float, west: bool) -> void:
	Props.place(root, "door_wood", pos, yaw, 1.0, {"collision": "none"})
	Kit.blocker(root, pos + Vector3(0, 1.1, 0), Vector3(0.12, 2.2, 1.0))
	var out := 0.06 if west else -0.06
	Kit.sign(root, "signs/five_half", pos + Vector3(out, 1.95, 0), yaw, Vector2(0.32, 0.32))
	Kit.sign(root, "props/keypad", pos + Vector3(out, 1.3, 0.62), yaw, Vector2(0.18, 0.24))
	Kit.light(root, pos + Vector3(out * 12.0, 2.2, 0), Color(1.0, 0.85, 0.7), 0.6, 4.0)
	Readable.create(root, pos, yaw, "Your own front door", [
		"Door 5½. Your door, on a train. The keypad is the one you know. It wants four digits.",
		"You know four digits. You put them in. It does not open. From inside, a voice that is yours says: not from this side.",
	], {"name": "Door5Half", "size": Vector3(0.5, 2.3, 1.2), "sound": "door_locked", "note_key": "dream_door_5half", "note_title": "Door 5½ on the train", "note_text": "Your own front door is on the train, locked, with the keypad. The code you know does not open it. Somebody inside, with your voice, says: not from this side."})
	area.rng.randf()


static func _knock(n: String) -> void:
	Audio.sfx("wood_knock", null, -6.0)
	var replies := ["Nobody answers. Behind the door, the train.", "Somebody inside says \"as luggage\" and nothing else.", "A chair is pulled back, and pushed in again.", "The number %s is repeated back to you, through the wood, wrongly." % n]
	Game.toast.emit(replies[Game.bump("dream_knocks") % replies.size()])


static func _ticket(area: AreaBase) -> void:
	Audio.sfx("page", null, -8.0)
	if World.hud:
		await World.hud.say("", ["The dispenser gives you a ticket. It says 5½.", "You take another. It says 5½. The roll is very long and every one of them says 5½."])
	Game.set_flag("dream_ticket", true)
	Game.note("dream_ticket", "The ticket", "The ticket dispenser on the train gives the same number every time. 5½. The Guard does not think much of it.")
	area.rng.randf()


static func _guard(n: NPC) -> void:
	if Game.active_is("hourglass"):
		await n.say([
			"The Guard looks at the hourglass in your hand and, for the first time, at you.",
			"\"That,\" he says. \"Turn that, and the country stops, and a train that is not moving has a front. Go and look at it while it lasts.\"",
		])
		return
	if not Game.has_flag("dream_ticket"):
		await n.say(["\"Ticket,\" says the Guard, and looks at you through a telescope, then through a microscope, then through opera glasses.", "\"No ticket,\" he says. \"You'll have to go back as luggage.\" He does not say back where.", "\"There is a dispenser by the door you came in by,\" he says. \"It will give you a number. It is always the same number. Bring it anyway.\""])
		return
	if Game.active_is("crown"):
		await n.say(["The Guard looks at the crown, then at the ticket. \"Your Majesty travels as luggage,\" he says, \"like everyone.\""])
		return
	await n.say([
		"You show the ticket. He looks at it through a telescope, then a microscope, then opera glasses.",
		"\"5½,\" he says. \"That is not a number. That is an address.\" He punches it anyway. The punch says 5½.",
		"\"Wrong way round,\" he says. \"You must go back as luggage.\" Behind every door, softly, in chorus: as luggage.",
		"\"And before you ask,\" he says, \"this train does not stop. Not for anyone. If you wanted off, you would need to stop everything at once, and I have only ever seen one thing that does that. Glass. Sand in it. Runs sideways.\"",
	])
	Game.set_flag("dream_guard_seen", true)
	Game.note("dream_guard", "The Guard", "The Guard on the train punches a ticket that says 5½ and says you must go back as luggage. The train does not stop for anyone; to get off you would have to stop everything at once, and only the Hourglass does that.")


# --- the world going past the windows -------------------------------------------------

## Two rings of painted country, far out either side, turning slowly the
## other way, so the board goes past every window in one direction and never
## comes round.
static func _scenery(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var rng := area.rng
	var cols: Array = []
	for d in (area as Node).DEFS:
		cols.append(d.paint)
	for side in [-1.0, 1.0]:
		var pivot := Vector3(side * 160.0, 0, 0)
		var cw := Clockwork.create(root, pivot, {"mode": "rotate", "axis": Vector3.UP, "speed_deg": side * 1.6, "name": "Scenery%s" % ("W" if side < 0 else "E")})
		var quads: Array = []
		var qcols: Array = []
		var n := 28
		var r := 118.0
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var p0 := Vector3(cos(a0) * r, -2.0, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, -2.0, sin(a1) * r)
			var h := rng.randf_range(6.0, 16.0)
			var c: Color = cols[rng.randi() % cols.size()]
			# a wall of country facing the pivot's centre (the train side)
			var q := [p0, p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), p1, Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector3.ZERO]
			if side > 0:
				q = [p1, p1 + Vector3(0, h, 0), p0 + Vector3(0, h, 0), p0, Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector3.ZERO]
			quads.append(q)
			qcols.append(c)
			# a hedge line along the foot of it
			var g := [p0, p0 + Vector3(0, 1.6, 0), p1 + Vector3(0, 1.6, 0), p1, Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector3.ZERO]
			if side > 0:
				g = [p1, p1 + Vector3(0, 1.6, 0), p0 + Vector3(0, 1.6, 0), p0, Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector3.ZERO]
			quads.append(g)
			qcols.append(Color(0.16, 0.36, 0.18))
		var mi := Kit.add_mesh(cw.body, Kit.mesh_from_quads(quads, qcols), Kit.vertex_mat({"unshaded": true, "double": true}), Vector3.ZERO, {"solid": false, "cast_shadow": false, "name": "Country"})
		state.scenery.append(cw)
		mi.extra_cull_margin = 400.0
		# a town in front of the country: houses, a church, trees, and a clock tower
		# that says half past five every time it comes round
		var town_r := r - 6.0
		var a_town := PI if side > 0 else 0.0
		for k in 9:
			var a := a_town + (k - 4) * 0.032
			var hp := Vector3(cos(a) * town_r, -2.0, sin(a) * town_r)
			var hh := rng.randf_range(4.0, 8.0)
			var house := Kit.box(cw.body, hp + Vector3(0, hh * 0.5, 0), Vector3(3.0 + rng.randf() * 2.0, hh, 3.0), "stone/blocks_city", {"tile": 2.5, "solid": false, "tint": Color(1.0, 0.95, 0.9)})
			house.rotation.y = -a
			Kit.box(cw.body, hp + Vector3(0, hh + 0.5, 0), Vector3(4.0, 1.0, 3.6), "wood/planks_dark", {"tint": Color(0.5, 0.35, 0.35), "solid": false}).rotation.y = -a
		var ta := a_town + 0.02
		var tp := Vector3(cos(ta) * (town_r - 3.0), -2.0, sin(ta) * (town_r - 3.0))
		Kit.box(cw.body, tp + Vector3(0, 9.0, 0), Vector3(3.2, 18.0, 3.2), "stone/blocks_clocktower", {"tile": 2.5, "solid": false})
		Kit.box(cw.body, tp + Vector3(0, 19.0, 0), Vector3(4.0, 2.0, 4.0), "metal/brass", {"tile": 2.0, "solid": false})
		var face_dir: float = -side
		var face := Kit.sign(cw.body, "metal/clock_face", tp + Vector3(face_dir * 1.62, 15.0, 0), -90.0 if face_dir > 0 else 90.0, Vector2(2.4, 2.4))
		face.name = "TownClock"
		Kit.light(cw.body, tp + Vector3(face_dir * 3.0, 15.0, 0), Color(1.0, 0.9, 0.7), 1.2, 12.0)
		for k in 14:
			var a := a_town + rng.randf_range(-0.25, 0.25)
			var tr := town_r - rng.randf_range(2.0, 12.0)
			Props.place(cw.body, ["tree_oak_1", "tree_pine_1", "tree_autumn"][k % 3], Vector3(cos(a) * tr, -2.0, sin(a) * tr), rng.randf_range(0, 360), rng.randf_range(1.2, 2.2), {"collision": "none"})
	Kit.box(root, Vector3(0, -3.2, 0), Vector3(30.0, 0.2, 200.0), "ground/gravel", {"solid": false, "tint": Color(0.6, 0.6, 0.65), "tile": 3.0})


# --- the front of the train, which exists while the hour is held --------------------------

static func _platform(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	# the guard's van: a short dark room with a door at the front
	var z0 := Z_FRONT - 4.0
	Kit.wall(root, Vector3(W * 0.5, 0, z0), Vector3(1.0, 0, z0), H, WALL)
	Kit.wall(root, Vector3(-1.0, 0, z0), Vector3(-W * 0.5, 0, z0), H, WALL)
	Kit.box(root, Vector3(0, H - 0.3, z0), Vector3(2.0, 0.6, 0.2), WALL)
	Kit.label(root, "there is no next carriage", Vector3(0, 2.35, z0 + 0.12), 0.0, 16, Color(0.6, 0.55, 0.5), "body", {"pixel_size": 0.009})
	Kit.light(root, Vector3(0, H - 0.4, z0 + 2.0), Color(1.0, 0.8, 0.7), 0.7, 5.0)
	# the platform, in nothing
	var p := PLATFORM
	Kit.floor(root, p + Vector3(0, 0, -1.0), Vector2(10.0, 8.0), "wall/concrete", {"tile": 1.5})
	Kit.box(root, p + Vector3(0, -0.6, -1.0), Vector3(10.0, 1.0, 8.0), "wall/concrete_dark", {"solid": false, "tile": 1.5})
	Props.place(root, "waiting_chairs", p + Vector3(-3.5, 0, -2.0), 90.0, 1.0)
	Props.place(root, "lantern_post_city", p + Vector3(3.5, 0, -2.5), 0.0, 1.0, {"collision": "cylinder"})
	Kit.light(root, p + Vector3(3.5, 3.0, -2.5), Color(1.0, 0.9, 0.75), 1.1, 9.0)
	Kit.box(root, p + Vector3(3.5, 1.5, -4.0), Vector3(0.1, 3.0, 0.1), "metal/iron")
	Readable.create(root, p + Vector3(3.5, 2.3, -4.0), 0.0, "Read the station sign", [
		"BETWEEN. That is the whole name of the station. It is between stations, and it is not on the board.",
		"Nobody gets off here. You have. The train, held still, waits with the patience of a thing that does not know it has stopped.",
	], {"name": "BetweenSign", "sign": "signs/kd_between", "sign_size": Vector2(1.2, 0.45), "size": Vector3(1.3, 0.6, 0.3), "note_key": "dream_between", "note_title": "Between", "note_text": "You held the hour and the train had a front, and beyond it a platform called BETWEEN, which is not on the board. From it, a brook. Off its edge, nothing."})
	Kit.trigger(root, p + Vector3(0, 1.0, 0), Vector3(8.0, 3.0, 6.0), func(_p: Node) -> void:
		if not Game.has_flag("dream_off_train"):
			Game.set_flag("dream_off_train", true)
			Game.toast.emit("You have got off a train that does not stop, between stations."), {"name": "OffTrain", "once": true})
	# the strip to the brook
	Kit.floor(root, Vector3(0, 0, -39.5), Vector2(6.0, 3.0), "wall/concrete", {"tile": 1.5})
	area.rng.randf()
	state.van = z0


static func _tick(state: Dictionary, delta: float) -> void:
	if Game.time_frozen:
		return
	state.t += delta
	state.clack += delta
	if state.clack > 1.1:
		state.clack = 0.0
		var p := Game.player as Player
		if p != null:
			Audio.sfx("step_metal", p.global_position + Vector3(0, -1.5, 3.0), -18.0)


static func _freeze(state: Dictionary, frozen: bool) -> void:
	var seam: SeamlessTeleport = state.seam
	if seam != null and is_instance_valid(seam):
		seam.enabled = not frozen
	if frozen:
		Game.toast.emit("The country outside the windows stops. The corridor, for the first time, has an end.")
