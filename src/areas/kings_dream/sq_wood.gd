class_name KDWood
extends RefCounted
## The fourth square: the Wood Where Things Have No Names. The Hallway, grown
## into a forest: its black walls stand in rows as trunks, further than the
## square is wide, in a grey fog. Nothing here has a label. The prompts on
## everything you can use are blank while you stand among the trees, and the
## journal will not write until you are out.
##
## The Red King is asleep in the middle of it, enormous, under a tree, and two
## identical figures stand beside him and explain what you are. His snoring
## moves the wood in and out, and the last stretch to him closes with every
## breath; the Hourglass holds it open.
##
## Quotes the Hallway and the Keep of Hours. Crossed back into from the eighth
## square, the names come back.

const MEET := Vector3(0, 0, 10.0)
const AVENUE_Z0 := 10.0
const AVENUE_Z1 := -20.0
const CLEARING := Vector3(0, 0, -27.0)
const TRUNK := "wall/hallway_black"
const FLOOR := "wall/hallway_grey"
const COLD := Color(0.62, 0.66, 0.95)
const WARM := Color(1.0, 0.8, 0.6)


static func build(area: AreaBase, root: Node3D, ctx: Dictionary) -> Dictionary:
	var d: Dictionary = ctx.def
	var visit: int = ctx.visit
	var state := {"labels": [], "interactables": [], "king": null, "breath": [], "t": 0.0, "twins": []}
	Kit.floor(root, Vector3.ZERO, Vector2(KD.SQ, KD.SQ), FLOOR, {"tint": Color(1.1, 1.1, 1.2), "tile": 1.5, "thick": 0.2})
	_rows(area, root, state)
	_avenue(area, root, state)
	_clearing(area, root, state, visit)
	_things(area, root, state)
	_lights(root)
	var out := {}
	out["on_process"] = func(delta: float) -> void:
		_breathe(state, delta)
	out["on_return"] = func() -> void:
		_name_everything(area, state)
	out["usher"] = Vector3(30.0, 0, -30.0)
	out["gates"] = {"S": true, "N": true, "W": true, "E": true}
	return out


# --- the rows -------------------------------------------------------------------

## Trunks that are the Hallway's walls, in rows five metres apart, continuing
## beyond the hedge as far as the fog allows. Solid inside the square only.
static func _rows(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var rng := area.rng
	var quads: Array = []
	var shapes: Array = []
	var ghosts: Array = []
	for ix in range(-14, 15):
		for iz in range(-12, 13):
			var x := ix * 5.0 + (2.5 if iz % 2 == 0 else 0.0)
			var z := iz * 5.0 + 2.3
			# the paths: the way in, the avenue and the clearing, the way out, and the side ways
			if absf(x) < 3.2 and z > -40.0:
				continue
			if absf(z - AVENUE_Z0) < 3.0 and absf(x) < 44.0:
				continue
			if Vector2(x - CLEARING.x, z - CLEARING.z).length() < 10.0:
				continue
			var inside := absf(x) < 43.0 and absf(z) < 36.0
			var h := rng.randf_range(7.0, 12.0)
			var w := rng.randf_range(1.0, 1.5)
			var c := Vector3(x, h * 0.5, z)
			var q := Kit.box_quads(c, Vector3(w, h, w), 3.0, ["px", "nx", "pz", "nz", "py"], Vector3.ZERO)
			if inside:
				quads.append_array(q)
				shapes.append([c, Vector3(w, h, w)])
			else:
				ghosts.append_array(q)
			if inside and rng.randf() < 0.18:
				state.labels.append([Vector3(x, 1.7, z + w * 0.5 + 0.03), 0.0, ["TREE", "A TREE", "ANOTHER TREE", "TREE (THE SAME)", "wall"][rng.randi() % 5]])
	var mat := Kit.mat(TRUNK, {"tile": 3.0})
	var mi := Kit.add_mesh(root, Kit.mesh_from_quads(quads), mat, Vector3.ZERO, {"solid": false, "name": "Trunks"})
	var body := StaticBody3D.new()
	body.name = "TrunkBodies"
	body.collision_layer = Kit.L_WORLD
	body.collision_mask = 0
	body.set_meta("surface", "stone")
	for s in shapes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s[1]
		cs.shape = bs
		cs.position = s[0]
		body.add_child(cs)
	mi.add_child(body)
	Kit.add_mesh(root, Kit.mesh_from_quads(ghosts), mat, Vector3.ZERO, {"solid": false, "name": "GhostTrunks", "cast_shadow": false})


## The last stretch: two rows of trunks that close together with every breath.
static func _avenue(_area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var n := 13
	var step := (AVENUE_Z0 - AVENUE_Z1) / n
	for side in [-1.0, 1.0]:
		var cw := Clockwork.create(root, Vector3(side * 2.1, 0, 0), {"mode": "path", "points": [Vector3.ZERO, Vector3(-side * 1.7, 0, 0)], "speed_deg": 7.0, "platform": true, "name": "Breath%s" % ("L" if side < 0 else "R")})
		for i in n:
			var z := AVENUE_Z0 - (i + 0.5) * step
			var h := 8.0 + (i % 3) * 1.5
			var size := Vector3(1.2, h, 1.2)
			Kit.box(cw.body, Vector3(0, h * 0.5, z), size, TRUNK, {"tile": 3.0, "solid": false})
			cw.add_shape(size, Vector3(0, h * 0.5, z))
		state.breath.append(cw)
	# what the avenue says, on its first trunk, only in lantern light
	var insc := Node3D.new()
	insc.name = "Inscription"
	root.add_child(insc)
	Kit.label(insc, "5 ½", Vector3(-2.1 - 0.62, 2.4, AVENUE_Z0 - 1.2), -90.0, 60, Color(0.8, 0.75, 0.6), "title", {"pixel_size": 0.012})
	Kit.label(insc, "this is not for you either", Vector3(2.1 + 0.62, 1.6, AVENUE_Z0 - 6.0), 90.0, 30, Color(0.8, 0.1, 0.1), "display", {"pixel_size": 0.011})
	Kit.lantern_only(insc)
	# lights down the avenue, cold, like the hallway's
	for i in 4:
		Kit.light(root, Vector3(0, 3.5, AVENUE_Z0 - 4.0 - i * 7.5), COLD, 1.1, 10.0)


# --- the clearing -----------------------------------------------------------------

static func _clearing(area: AreaBase, root: Node3D, state: Dictionary, visit: int) -> void:
	var c := CLEARING
	Kit.ring(root, c + Vector3(0, 0.1, 0), 0.0, 9.0, 20, "nature/grass_dark", {"tint": Color(0.75, 0.8, 0.75), "solid": false, "tile": 3.0})
	# the tree he sleeps under: a hallway wall that has decided to be a tree
	var tp := c + Vector3(0, 0, -4.5)
	Kit.box(root, tp + Vector3(0, 7.0, 0), Vector3(2.4, 14.0, 2.4), TRUNK, {"tile": 3.0})
	for k in 6:
		var a := k * 60.0 + 15.0
		var bp := tp + Kit.polar(2.6, a, 11.5 + (k % 2) * 1.2)
		var branch := Kit.box(root, bp, Vector3(3.4, 0.5, 0.5), TRUNK, {"tile": 3.0, "solid": false})
		branch.rotation.y = deg_to_rad(-a)
		Props.place(root, "bush_2", bp + Kit.polar(1.4, a, -0.4), a, 1.8, {"collision": "none", "tint": Color(0.7, 0.72, 0.85)})
	Kit.light(root, tp + Vector3(0, 13.0, 0), Color(0.75, 0.7, 0.95), 1.0, 18.0)
	# the King, enormous, or the shape of him
	var kp := c + Vector3(0, 0, -1.2)
	var lines_king: Array
	if visit < 3:
		var king := Props.place(root, "king_sleeping", kp, 180.0, 4.2, {"collision": "box", "name": "RedKing", "tint": Color(1.0, 0.9, 0.9)})
		state.king = king
		Kit.light(root, kp + Vector3(0, 3.0, 1.5), WARM, 1.4, 12.0)
		lines_king = [
			"He is asleep. He is the size of a room. His crown has slipped over one eye and it is made of stone.",
			"His breathing moves the trunks. In. Out. The gap you came through closes when he breathes in.",
			"He is dreaming, and you can hear it, faintly, like a television in another flat. It sounds like a garden.",
		]
	else:
		Kit.box(root, kp + Vector3(0, 0.05, 0), Vector3(6.0, 0.1, 2.6), "nature/grass_dark", {"tint": Color(0.45, 0.5, 0.45), "solid": false, "tile": 3.0})
		Kit.box(root, kp + Vector3(-2.6, 0.08, 0), Vector3(1.4, 0.14, 1.4), "nature/grass_dark", {"tint": Color(0.4, 0.45, 0.4), "solid": false, "tile": 3.0})
		lines_king = [
			"The grass holds his shape. Head here, hand there. It is still warm, the way a chair is warm.",
			"He has got up. Nobody saw him go. The trunks are still breathing, so somebody is still asleep somewhere.",
		]
	var kr := Readable.create(root, kp + Vector3(0, 0.6, 1.4), 0.0, "", lines_king, {"name": "KingLook", "size": Vector3(6.0, 2.0, 2.0), "sound": "sleep"})
	kr.on_read = func(_r: Node) -> void:
		if Game.active_is("crown") and World.hud:
			await World.hud.say("", ["The crown on your head is paper. The one on his is stone. Neither of you is awake."])
		area.call("defer_note", "dream_king", "The Red King", "He is asleep in the middle of the wood, enormous, under a tree. His breathing moves the trunks. He is dreaming, and it sounds like a garden." if visit < 3 else "The third time, the King was not under the tree. The grass held his shape. The trunks were still breathing.")
	state.interactables.append([kr, "The King"])
	# the two who explain him
	var tl := c + Vector3(-3.6, 0, 2.2)
	var tr := c + Vector3(3.6, 0, 2.2)
	var twin_col := Color(0.78, 0.86, 1.0)
	for spec in [[tl, -30.0, "One"], [tr, 30.0, "Other"]]:
		var npc := NPC.create(root, spec[0], float(spec[1]), "", {"model": "none", "name": "Twin_" + String(spec[2]), "prompt": "", "lines": ["..."]})
		var fig := KD.figure(npc, Vector3.ZERO, 0.0, twin_col, 1.55)
		# a round hat, a collar, the same on both
		Kit.cylinder(fig, Vector3(0, 1.62 * 1.55 / 1.8, 0), 0.22, 0.1, "", {"tint": Color(0.2, 0.2, 0.3), "solid": false, "segments": 8})
		Kit.box(fig, Vector3(0, 1.32, 0), Vector3(0.4, 0.08, 0.3), "", {"tint": Color(1, 1, 1), "solid": false})
		npc.on_talk = func(_p: Node, n: NPC) -> bool:
			await _twins_talk(area, state, n, visit)
			return true
		state.twins.append(npc)
		state.interactables.append([npc, "Talk to " + ("the one" if spec[2] == "One" else "the other")])
	Kit.light(root, c + Vector3(0, 2.5, 3.0), Color(0.85, 0.9, 1.0), 0.9, 9.0)
	Kit.particles(root, c + Vector3(0, 2.0, 0), "motes", Vector3(8.0, 2.0, 8.0), 50)
	Puzzle.declare(area, "dream_king", "dream_king_reached", ["keepsake:hourglass"], "hold the breathing wood still and reach the King under the tree")
	Kit.trigger(root, c + Vector3(0, 1.0, 2.0), Vector3(10.0, 3.0, 8.0), func(_p: Node) -> void:
		if not Game.has_flag("dream_king_reached"):
			Game.set_flag("dream_king_reached", true)
			Audio.sfx("heartbeat", null, -6.0), {"name": "ClearingReached", "once": true})


## What the two of them say. They say it kindly. It has never helped.
static func _twins_talk(area: AreaBase, state: Dictionary, n: NPC, visit: int) -> void:
	var k := Game.bump("dream_twins_talked")
	var lines: Array
	if visit >= 3:
		lines = [
			"\"He's dreaming now,\" says the one. \"He isn't,\" says the other.",
			"\"Then where -\" \"Somewhere else. It's fine. We're still here, so it's fine.\"",
			"They look at the shape in the grass. \"Contrariwise,\" says the other, and does not finish.",
		]
	elif k == 1:
		lines = [
			"\"He's dreaming now,\" says the one, \"and what do you think he's dreaming about?\"",
			"\"About you,\" says the other, before you can answer.",
			"\"And if he left off dreaming about you, where do you suppose you'd be?\"",
			"\"Nowhere,\" says the other. \"You'd go out. Like a candle.\"",
			"\"You're only a sort of thing in his dream,\" says the one, kindly. \"We tell everyone. It has never helped.\"",
		]
	elif k == 2:
		lines = [
			"\"You're still here,\" says the one. \"That's him, not you,\" says the other.",
			"\"Contrariwise,\" says the one, \"if you weren't here, who would we be explaining it to?\"",
		]
	else:
		lines = ["\"Kindly,\" says the one. \"Kindly,\" says the other. They have run out of the rest of it."]
	if Game.active_is("crown"):
		lines.append("\"Nice crown,\" says the other. \"He has one like it. His is heavier. That is the whole difference.\"")
	await n.say(lines)
	area.call("defer_note", "dream_twins", "The two who explain", "Two identical figures stand beside the sleeping King and explain, kindly, that you are a thing in his dream and would go out like a candle if he woke. They tell everyone. It has never helped.")
	state.t = state.t


# --- things with no names ------------------------------------------------------------

static func _things(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	# a stone, a sign, a clock, a door that is only a door
	var stone := Vector3(-12.0, 0, 22.0)
	Props.place(root, "rock_2", stone, 40.0, 1.6, {"collision": "box", "tint": Color(0.8, 0.8, 0.9)})
	var r1 := Readable.create(root, stone + Vector3(0, 0.6, 0.9), 0.0, "", [
		"A stone. It has no name. You try yours, quietly, to see if it is still there.",
		"It is not. It will be, later. For now you are the thing that is looking at the stone.",
	], {"name": "Stone", "size": Vector3(1.6, 1.2, 1.0)})
	r1.on_read = func(_r: Node) -> void:
		area.call("defer_note", "dream_no_name", "Where names stop", "In the wood nothing has a name, including you. You tried yours on a stone and it did not come. It came back when you left.")
	state.interactables.append([r1, "Look at the stone"])
	var sign := Vector3(14.0, 0, 20.0)
	Kit.box(root, sign + Vector3(0, 1.0, 0), Vector3(0.1, 2.0, 0.1), "wood/planks_grey")
	Kit.sign(root, "wall/paper", sign + Vector3(0, 1.8, -0.08), 0.0, Vector2(1.1, 0.6), {"tint": Color(0.9, 0.88, 0.8)})
	var r2 := Readable.create(root, sign + Vector3(0, 1.4, 0), 0.0, "", [
		"The sign is blank. You feel that it should say something and that you should know what.",
		"Somebody has scratched a line under where the word was. It is a long word.",
	], {"name": "BlankSign", "size": Vector3(1.2, 1.2, 0.5)})
	state.interactables.append([r2, "Read the sign"])
	# a clock on a trunk, from the Keep: half past five
	var clock := Vector3(-22.6, 3.2, -8.0)
	Kit.sign(root, "metal/clock_face", clock, -90.0, Vector2(1.6, 1.6))
	Kit.box(root, clock + Vector3(-0.03, 0.18, 0), Vector3(0.02, 0.44, 0.05), "", {"tint": Color(0.1, 0.1, 0.12), "solid": false})
	Kit.box(root, clock + Vector3(-0.03, -0.28, 0), Vector3(0.02, 0.6, 0.05), "", {"tint": Color(0.1, 0.1, 0.12), "solid": false})
	var r3 := Readable.create(root, clock + Vector3(-0.3, -1.6, 0), -90.0, "", [
		"A clock, on a trunk, with no name for what it is. Half past five.",
		"You do not have the word for it either, in here. You know the time anyway. The time is the only thing that came in with you.",
	], {"name": "TrunkClock", "size": Vector3(0.6, 2.4, 1.8)})
	state.interactables.append([r3, "Look at the clock"])
	Kit.light(root, clock + Vector3(-1.5, 0, 0), WARM, 0.7, 6.0)
	# a door leaning on a trunk with nothing behind it
	var dp := Vector3(24.0, 0, 2.0)
	Props.place(root, "door_white", dp, -60.0, 1.0, {"collision": "box"})
	var r4 := Readable.create(root, dp + Vector3(0, 1.0, 0), -60.0, "", [
		"A door, white, leaning against a trunk. You know what it is for. You cannot say what it is.",
		"There is nothing behind it. You open it anyway. It opens onto the wood, which is behind it.",
	], {"name": "LeaningDoor", "size": Vector3(1.4, 2.4, 0.8), "sound": "door_open"})
	state.interactables.append([r4, "Open the door"])
	# stumps and logs where the hallway has been felled, and a lantern somebody left
	var rng := area.rng
	for i in 10:
		var p := Vector3(rng.randf_range(-40.0, 40.0), 0, rng.randf_range(-34.0, 34.0))
		if absf(p.x) < 4.0 or absf(p.z - 10.0) < 4.0 or p.distance_to(CLEARING) < 11.0:
			continue
		Props.place(root, "stump" if i % 3 != 0 else "log", p, rng.randf_range(0, 360), 1.0, {"collision": "box", "tint": Color(0.75, 0.75, 0.8)})
	Props.place(root, "lantern_hanging", Vector3(-7.4, 3.2, 27.0), 0.0, 1.0, {"collision": "none"})
	Kit.light(root, Vector3(-7.4, 2.6, 27.0), Color(1.0, 0.85, 0.6), 0.9, 7.0)
	# a fawn, which is the dog with no name, if the dog has one
	Dog.maybe_spawn(root, Vector3(-6.0, 0.1, 14.0))
	area.rng.randf()


static func _lights(root: Node3D) -> void:
	Kit.light(root, MEET + Vector3(0, 4.0, 0), COLD, 1.2, 14.0)
	Kit.light(root, Vector3(0, 4.0, 34.0), COLD, 1.0, 14.0)
	Kit.light(root, Vector3(0, 4.0, -36.0), COLD, 1.0, 14.0)
	Kit.light(root, Vector3(-36.0, 4.0, 10.0), COLD, 0.9, 14.0)
	Kit.light(root, Vector3(36.0, 4.0, 10.0), COLD, 0.9, 14.0)
	Kit.light(root, Vector3(-20.0, 5.0, 25.0), Color(0.6, 0.6, 0.75), 0.9, 16.0)
	Kit.light(root, Vector3(20.0, 5.0, -10.0), Color(0.6, 0.6, 0.75), 0.9, 16.0)
	Kit.particles(root, Vector3(0, 3.0, 0), "fog", Vector3(40.0, 1.0, 40.0), 40)


## The King's chest rises and falls; the wood keeps time with it. Anyone in the
## avenue when it breathes in is at the start of the avenue again, and did not
## walk there. Held still, it stays open.
static func _breathe(state: Dictionary, delta: float) -> void:
	if Game.time_frozen:
		return
	state.t += delta
	var p := Game.player as Player
	if p != null and not state.breath.is_empty():
		var cw: Clockwork = state.breath[0]
		var root: Node3D = cw.get_parent()
		var l := root.to_local(p.global_position)
		if cw.body.position.x > 1.15 and absf(l.x) < 1.6 and l.z < AVENUE_Z0 - 0.5 and l.z > AVENUE_Z1 - 0.5:
			p.global_position = root.to_global(Vector3(0, l.y, AVENUE_Z0 + 2.0))
			p.velocity = Vector3.ZERO
			Audio.sfx("whisper", p.global_position, -8.0)
			if Game.bump("dream_breathed_out") == 1:
				Game.toast.emit("The wood breathes in. You are at the start of the avenue, and you did not walk there.")
			elif Game.count("dream_breathed_out") == 3:
				Game.toast.emit("It breathes in every time. Something would have to hold it.")
	var king: Node3D = state.king
	if king != null and is_instance_valid(king):
		king.scale = Vector3(4.2, 4.2 * (1.0 + 0.05 * sin(state.t * TAU / 8.0)), 4.2)
	var beat := fmod(state.t, 8.0)
	if beat < delta and state.t > 1.0:
		Audio.sfx("sleep", CLEARING + Vector3(0, 1.0, 0), -8.0)


## Crossed back into from the eighth square: things have names again.
static func _name_everything(area: AreaBase, state: Dictionary) -> void:
	if state.get("named", false):
		return
	state["named"] = true
	for pair in state.interactables:
		var it = pair[0]
		if is_instance_valid(it):
			it.prompt = String(pair[1])
	for lb in state.labels:
		Kit.label(area, String(lb[2]), (lb[0] as Vector3) + (area.sq[2].origin as Vector3), float(lb[1]), 14, Color(0.7, 0.72, 0.8), "body", {"pixel_size": 0.01, "outline": 2})
	Game.toast.emit("Everything in the wood has its name back. The trees are labelled TREE.")
