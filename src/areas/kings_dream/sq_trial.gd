class_name KDTrial
extends RefCounted
## The eighth square, nearly: the Croquet Ground and the Trial. Red ground,
## red light, the Furnace's heat without its fire. The mallets hang on hooks.
## The game has rules and nobody will say them, and the score on a Waiting
## Halls board only goes up. A trench of heat cuts the ground in two, and the
## only way over is the glide with a flap at the top of it.
##
## Beyond, a courtroom. Somebody is on trial, and it takes a while to work
## out that it is you, and nobody says so. The jury are shadows at desks. The
## sentence is read before the evidence, and the charge can be read only while
## the reading is held still.
##
## Quotes the Furnace, the Waiting Halls and the Ossuary.

const TRENCH_Z0 := 4.0
const TRENCH_Z1 := -6.0
const TRENCH_Y := -6.0
const MOUND := Vector3(0, 0, 10.0)
const MOUND_H := 3.6
const COURT := Vector3(0, 0, -25.0)
const RED := Color(1.0, 0.45, 0.35)
const EMBER := Color(1.0, 0.6, 0.3)


static func build(area: AreaBase, root: Node3D, ctx: Dictionary) -> Dictionary:
	var d: Dictionary = ctx.def
	var state := {"score": 0, "board": null, "t": 0.0, "read_t": 0.0, "reading": 0, "charge": null, "in_court": false}
	Kit.floor(root, Vector3(0, 0, (TRENCH_Z0 + KD.HALF) * 0.5), Vector2(KD.SQ, KD.HALF - TRENCH_Z0), String(d.ground), {"tint": d.tint, "tile": 2.0, "thick": 0.2})
	Kit.floor(root, Vector3(0, 0, (TRENCH_Z1 - KD.HALF) * 0.5), Vector2(KD.SQ, KD.HALF + TRENCH_Z1), String(d.ground), {"tint": d.tint, "tile": 2.0, "thick": 0.2})
	_ground(area, root, state)
	_trench(area, root)
	_court(area, root, state)
	var out := {}
	out["on_process"] = func(delta: float) -> void:
		_tick(area, state, delta)
	out["on_freeze"] = func(frozen: bool) -> void:
		if state.charge:
			(state.charge as Readable).enabled = frozen
		if frozen and state.in_court:
			Game.toast.emit("The reading stops mid-word. The charge sheet, for once, holds still.")
	out["usher"] = Vector3(-34.0, 0, 30.0)
	return out


# --- the croquet ground ---------------------------------------------------------------

static func _ground(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var rng := area.rng
	# hoops, in no arrangement anyone would agree to
	for i in 9:
		var p := Vector3(rng.randf_range(-30.0, 30.0), 0, rng.randf_range(12.0, 34.0))
		if absf(p.x) < 4.0 and p.z < 16.0:
			continue
		Kit.arch(root, p, rng.randf_range(0, 360), 0.9, 0.7, "metal/iron", {"depth": 0.08, "post": 0.08, "top": 0.08, "pointed": false})
	for i in 7:
		var p := Vector3(rng.randf_range(-30.0, 30.0), 0, rng.randf_range(12.0, 34.0))
		Props.place(root, "mushroom_red", p, rng.randf_range(0, 360), 0.7, {"collision": "none"})
	# the rack of mallets, hung on the Furnace's hooks
	var rack := Vector3(-16.0, 0, 30.0)
	Kit.box(root, rack + Vector3(0, 1.6, 0), Vector3(6.0, 3.2, 0.3), "stone/blocks_furnace", {"tile": 1.5})
	for k in 5:
		Props.place(root, "mallet_hook", rack + Vector3(-2.0 + k * 1.0, 2.6, 0.16), 0.0, 1.0, {"collision": "none"})
	Props.place(root, "meat_hook", rack + Vector3(2.6, 3.2, 0.3), 0.0, 1.0, {"collision": "none"})
	Kit.light(root, rack + Vector3(0, 2.5, 1.5), EMBER, 1.0, 8.0)
	Interactable.make(root, rack + Vector3(0, 1.4, 0.4), Vector3(5.0, 2.4, 0.8), "Take a mallet", func(_p: Node, _it: Node) -> void:
		Audio.sfx("chain_rattle", null, -8.0)
		if Game.bump("dream_mallet") == 1:
			Game.toast.emit("The mallet is heavier than it looks, and warm, like something that has been alive.")
			Game.note("dream_croquet", "The croquet ground", "Red ground and red light in the square before the last: the Furnace's heat without its fire. The mallets hang on hooks and are warm. The game has rules and nobody will say them. The score only goes up.")
		else:
			Game.toast.emit("It is the same mallet. They are all the same mallet."), {"name": "Mallets"})
	Readable.create(root, rack + Vector3(-3.6, 1.5, 0.3), 0.0, "Read the rules", [
		"RULES OF THE GAME. 1. You are playing. 2.",
		"The rest is torn off. Underneath, in a different hand: the rest was never written. It was played.",
	], {"name": "Rules", "sign": "signs/kd_rules", "sign_size": Vector2(1.2, 0.9), "size": Vector3(1.3, 1.0, 0.3)})
	# the scoreboard, from the Waiting Halls, that only counts up
	var bp := Vector3(18.0, 0, 28.0)
	Kit.box(root, bp + Vector3(0, 2.2, 0), Vector3(0.3, 4.4, 0.3), "metal/iron")
	Props.place(root, "number_display", bp + Vector3(0, 3.6, -0.16), 0.0, 2.2, {"collision": "none"})
	state.board = Kit.label(root, "", bp + Vector3(0, 3.85, -0.5), 0.0, 22, Color(1.0, 0.35, 0.25), "display", {"pixel_size": 0.013, "outline": 2})
	_score(state)
	Readable.create(root, bp + Vector3(0, 1.4, -0.6), 0.0, "The score", [
		"SCORE, and a number. It went up while you were reading it. It has never gone down. Nobody is ahead, because nobody else has a number.",
		"You are not sure you are playing. The board is sure.",
	], {"name": "ScoreLook", "size": Vector3(1.6, 2.4, 1.0)})
	Kit.light(root, bp + Vector3(0, 3.5, -1.5), Color(1.0, 0.5, 0.4), 1.0, 8.0)
	# the umpire
	NPC.create(root, Vector3(-6.0, 0, 24.0), 20.0, "The Umpire", {"model": "figure_shadow", "name": "Umpire", "lines": [
		"\"You are playing,\" says the Umpire.",
		"\"Am I winning?\" \"The score is going up.\" \"Is that the same thing?\" \"It is here.\"",
	], "reactions": {"crown": ["\"Her Majesty is playing,\" says the Umpire. \"Her Majesty is going up.\""], "knife": ["The Umpire looks at the knife. \"That is not a mallet,\" it says, and does not move."]}, "flee_knife": false})
	# banners on posts, a hedgehog in a cage waiting to be a ball, and spikes for the look of the place
	for post in [Vector3(-30.0, 0, 34.0), Vector3(30.0, 0, 36.0), Vector3(-34.0, 0, 12.0)]:
		Kit.box(root, post + Vector3(0, 3.0, 0), Vector3(0.14, 6.0, 0.14), "metal/iron")
		Props.place(root, "banner_eye", post + Vector3(0, 5.6, 0.1), 0.0, 1.0, {"collision": "none", "tint": Color(1.0, 0.6, 0.6)})
	var cagep := Vector3(-8.0, 0, 32.0)
	Props.place(root, "cage", cagep, 0.0, 0.8, {"collision": "box"})
	Props.place(root, "mushroom_red", cagep + Vector3(0, 0.05, 0), 0.0, 0.6, {"collision": "none"})
	Readable.create(root, cagep + Vector3(0, 0.6, 0.8), 0.0, "Look in the cage", [
		"A ball, in a cage, waiting. It is red and it has spines and it is breathing.",
		"It looks at you the way the balls in this game look at the mallets.",
	], {"name": "CagedBall", "size": Vector3(1.2, 1.2, 0.6)})
	Props.place(root, "spike_cluster", Vector3(26.0, 0, 38.0), 30.0, 1.0, {"collision": "box"})
	Props.place(root, "spike_cluster", Vector3(-36.0, 0, 26.0), 120.0, 0.8, {"collision": "box"})
	# heat: embers without fire, and a red light
	Kit.particles(root, Vector3(0, 0.5, 22.0), "embers", Vector3(30.0, 0.3, 12.0), 60)
	Kit.light(root, Vector3(0, 5.0, 24.0), RED, 1.2, 30.0)
	Kit.light(root, Vector3(-24.0, 4.0, 36.0), RED, 0.9, 18.0)
	Kit.light(root, Vector3(24.0, 4.0, 16.0), RED, 0.9, 18.0)
	# the mound, with a ramp up its south side: the tee
	var m := MOUND
	Kit.cylinder(root, m, 3.0, MOUND_H, "stone/blocks_furnace", {"tile": 2.0, "segments": 10, "top_radius": 2.6})
	Kit.ramp(root, m + Vector3(0, 0, 3.0 + 7.0), 0.0, 2.4, 7.0, MOUND_H, "stone/blocks_furnace", {"tile": 2.0})
	Kit.floor(root, m + Vector3(0, MOUND_H, 0), Vector2(5.0, 5.0), "stone/blocks_furnace", {"tile": 2.0, "thick": 0.1})
	Kit.light(root, m + Vector3(0, MOUND_H + 2.0, 0), EMBER, 1.0, 8.0)
	Readable.create(root, m + Vector3(0, MOUND_H, -1.6), 0.0, "Look across the trench", [
		"A trench of heat across the ground, ten metres of it, and the court on the far side. It shimmers. There is no fire; the Furnace lent the heat and kept the rest.",
		"From the top of the mound it is a glide with nothing to spare. The air over the trench goes up. A flap at the top of it would help.",
	], {"name": "TrenchLook", "size": Vector3(3.0, 1.5, 1.0)})
	Puzzle.declare(area, "dream_trench", "dream_trench_crossed", ["keepsake:wings"], "glide from the mound across the trench of heat, with a flap at the top of it")


static func _score(state: Dictionary) -> void:
	var l: Label3D = state.board
	if l:
		l.text = "SCORE\n%04d" % (int(state.score) % 10000)


# --- the trench of heat ---------------------------------------------------------------------

static func _trench(area: AreaBase, root: Node3D) -> void:
	var cz := (TRENCH_Z0 + TRENCH_Z1) * 0.5
	var depth := TRENCH_Z0 - TRENCH_Z1
	Kit.floor(root, Vector3(0, TRENCH_Y, cz), Vector2(KD.SQ, depth), "ground/ash", {"tint": Color(1.0, 0.6, 0.5), "tile": 2.0, "thick": 0.2})
	Kit.box(root, Vector3(0, TRENCH_Y * 0.5, TRENCH_Z0 + 0.5), Vector3(KD.SQ, -TRENCH_Y, 1.0), "stone/blocks_furnace", {"tile": 2.0})
	Kit.box(root, Vector3(0, TRENCH_Y * 0.5, TRENCH_Z1 - 0.5), Vector3(KD.SQ, -TRENCH_Y, 1.0), "stone/blocks_furnace", {"tile": 2.0})
	# heat in it, not fire
	for i in 4:
		Kit.light(root, Vector3(-30.0 + i * 20.0, TRENCH_Y + 2.0, cz), Color(1.0, 0.35, 0.2), 1.6, 14.0)
	Kit.particles(root, Vector3(0, TRENCH_Y + 1.0, cz), "embers", Vector3(44.0, 0.5, depth * 0.4), 200)
	Kit.particles(root, Vector3(0, 1.0, cz), "fog", Vector3(44.0, 0.5, depth * 0.4), 30)
	# the ends of the trench are walled: it is a trench, not a way off the board
	for sx in [-1.0, 1.0]:
		Kit.box(root, Vector3(sx * (KD.HALF + 0.5), TRENCH_Y * 0.5, cz), Vector3(1.0, -TRENCH_Y, depth + 2.0), "stone/blocks_furnace", {"tile": 2.0})
	# the way back up, for the ones who fell: a stair along the north wall at the east
	# end, rising west to the far side, and one along the south wall at the west end,
	# rising east to the side you came from
	Kit.stairs(root, Vector3(42.0, TRENCH_Y, TRENCH_Z1 + 1.0), 90.0, 1.8, 24, -TRENCH_Y / 24.0, 0.4, "stone/blocks_furnace", {"tile": 1.0, "name": "TrenchStairN"})
	Kit.floor(root, Vector3(32.0, 0.0, TRENCH_Z1 + 0.2), Vector2(2.4, 2.4), "stone/blocks_furnace", {"tile": 1.0})
	Kit.stairs(root, Vector3(-42.0, TRENCH_Y, TRENCH_Z0 - 1.0), -90.0, 1.8, 24, -TRENCH_Y / 24.0, 0.4, "stone/blocks_furnace", {"tile": 1.0, "name": "TrenchStairS"})
	Kit.floor(root, Vector3(-32.0, 0.0, TRENCH_Z0 - 0.2), Vector2(2.4, 2.4), "stone/blocks_furnace", {"tile": 1.0})
	Kit.light(root, Vector3(40.0, TRENCH_Y + 3.0, cz), EMBER, 1.0, 10.0)
	Kit.light(root, Vector3(-40.0, TRENCH_Y + 3.0, cz), EMBER, 1.0, 10.0)
	Readable.create(root, Vector3(0, TRENCH_Y + 0.6, cz), 0.0, "The bottom of the trench", [
		"Ash, warm through your shoes. No fire. It is like standing in a room somebody has just left.",
		"At each end, a stair up: east to the far side, west to the side you came from. Somebody expected people down here.",
	], {"name": "TrenchBottom", "size": Vector3(6.0, 1.5, 4.0)})
	Kit.trigger(root, Vector3(0, 1.0, TRENCH_Z1 - 3.0), Vector3(KD.SQ, 3.0, 4.0), func(_p: Node) -> void:
		if not Game.has_flag("dream_trench_crossed"):
			Game.set_flag("dream_trench_crossed", true)
			Game.toast.emit("You come down on the far side with the heat still in your coat."), {"name": "TrenchCrossed", "once": true})
	area.rng.randf()


# --- the court -------------------------------------------------------------------------------

static func _court(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var c := COURT
	var rows := MapBuilder.rasterize(11, 11, [[1, 1, 10, 10, "."]], [[5, 10, "D"], [5, 0, "D"]], [[5, 2, "b"], [5, 5, "d"]])
	var m := MapBuilder.build(root, rows, {"cell": 2.0, "height": 6.0, "origin": c + Vector3(-11.0, 0, -11.0), "door_h": 3.0, "tile": 2.0,
		"floor": "wood/planks_dark", "wall": "wall/wallpaper_damask_red", "ceiling": "wood/planks_dark", "name": "Court", "outer_faces": true})
	var bench: Vector3 = m.first.call("b")
	var dock: Vector3 = m.first.call("d")
	# the bench, raised, with the judge behind it
	Kit.box(root, bench + Vector3(0, 0.4, 0), Vector3(6.0, 0.8, 2.4), "wood/planks_dark", {"tile": 1.5})
	Kit.box(root, bench + Vector3(0, 1.4, 1.0), Vector3(6.0, 1.2, 0.3), "wood/planks_dark", {"tile": 1.5})
	var judge := NPC.create(root, bench + Vector3(0, 0.8, -0.3), 180.0, "The Bench", {"model": "figure_shadow", "name": "Judge", "prompt": "Address the bench", "turn_to_bell": false})
	judge.scale = Vector3(1.5, 1.5, 1.5)
	judge.lines = [
		"\"Sentence first,\" says the Bench. \"Verdict afterwards. Evidence when there is time. There is never time; that is the sentence.\"",
		"\"The accused will remain where the accused is. The accused is very good at that.\"",
	]
	judge.reactions = {"crown": ["\"The court notes that the accused is wearing a crown,\" says the Bench. \"The court has one like it. The court's is heavier.\""]}
	Kit.sign(root, "props/keypad", bench + Vector3(0, 2.6, 1.16), 0.0, Vector2(0.3, 0.4))
	# the dock: an iron cage, empty, with your number on the card
	Props.place(root, "cage", dock, 0.0, 1.3, {"collision": "box"})
	Readable.create(root, dock + Vector3(0, 0.8, 1.0), 0.0, "The dock", [
		"An iron cage in the middle of the room. Empty. A card on the rail: THE ACCUSED.",
		"On the back of the card, in pencil, a number you know. It is not a number. It is an address.",
	], {"name": "Dock", "size": Vector3(1.6, 1.8, 0.6), "note_key": "dream_dock", "note_title": "The dock", "note_text": "In the courtroom the dock is an iron cage, empty, with a card reading THE ACCUSED and your number on the back. Nobody says it is you. It takes a while."})
	# the jury: twelve shadows at desks, in two tiers along the east wall
	for i in 12:
		var tier := i / 6
		var jp := c + Vector3(6.5 + tier * 1.8, 0.0 + tier * 0.5, -5.0 + (i % 6) * 2.0)
		if tier == 1:
			Kit.box(root, jp + Vector3(0, 0.25, 0), Vector3(1.8, 0.5, 2.0), "wood/planks_dark", {"tile": 1.5})
		Props.place(root, "desk_office", jp, -90.0, 0.8, {"collision": "box"})
		Props.place(root, "figure_shadow", jp + Vector3(0.7, 0, 0), -90.0, 0.85, {"collision": "none"})
	Readable.create(root, c + Vector3(5.0, 1.0, 0), -90.0, "The jury", [
		"Twelve of them, at desks, and none of them has a face; they are the shadow that sits at every desk in every waiting room, twelve times.",
		"They are writing. You cannot see what. One of them writes your number and underlines it.",
	], {"name": "JuryLook", "size": Vector3(1.0, 2.0, 12.0), "note_key": "dream_jury", "note_title": "The jury", "note_text": "The jury are twelve shadows at desks, the same shadow that sits at a desk in the Waiting Halls. They write. One of them wrote your number and underlined it."})
	# benches for the public, who are not there
	for k in 3:
		Props.place(root, "waiting_chairs", c + Vector3(-5.0, 0, 2.0 + k * 2.2), 0.0, 1.0)
	# the herald reading the charge at a lectern; the sheet holds still only when the hour does
	var lp := c + Vector3(-3.0, 0, -4.0)
	Props.place(root, "lectern", lp, 40.0, 1.0)
	KD.figure(root, lp + Vector3(-0.8, 0, 0.6), 40.0, Color(0.85, 0.2, 0.25), 1.7)
	var charge := Readable.create(root, lp + Vector3(0, 1.0, 0), 40.0, "Read the charge", [
		"THE CHARGE. That the accused was somewhere, and is not there now.",
		"That the accused was dreamed, and did not object. That the accused has been carrying things that were not the accused's to carry, and has not once put them down.",
		"That the accused is early. Signed, in a hand you know, with a number you know.",
	], {"name": "Charge", "sign": "signs/kd_charge", "sign_size": Vector2(0.5, 0.5), "size": Vector3(1.0, 1.0, 0.8), "note_key": "dream_charge", "note_title": "The charge", "note_text": "Held still, the charge sheet in the courtroom reads: that the accused was somewhere and is not there now; that the accused was dreamed and did not object; that the accused has carried things that were not theirs to carry; that the accused is early. Signed with your number.", "flag_on_read": "dream_charge_read"})
	charge.enabled = false
	state.charge = charge
	Puzzle.declare(area, "dream_charge", "dream_charge_read", ["keepsake:hourglass"], "hold the hour while the sentence is read and read the charge sheet")
	# lights, red, and the trigger that starts the reading
	for p in [Vector3(0, 5.0, -6.0), Vector3(0, 5.0, 4.0), Vector3(-6.0, 4.0, -2.0), Vector3(6.0, 4.0, 2.0)]:
		Kit.light(root, c + p, Color(1.0, 0.6, 0.5), 1.0, 10.0)
	Props.place(root, "chandelier", c + Vector3(0, 5.8, 0), 0.0, 1.0, {"collision": "none"})
	Kit.trigger(root, c + Vector3(0, 2.0, 0), Vector3(18.0, 5.0, 18.0), func(_p: Node) -> void:
		state.in_court = true
		if not Game.has_flag("dream_in_court"):
			Game.set_flag("dream_in_court", true)
			Game.toast.emit("Somebody is on trial. The sentence is being read. Nobody looks at you."), {"name": "InCourt", "on_exit": func(_p: Node) -> void: state.in_court = false})
	# the way out at the north, to the last brook
	Kit.floor(root, c + Vector3(0, 0.02, -13.5), Vector2(4.0, 6.0), "ground/red_dream", {"tint": Color(1.0, 0.9, 0.9), "tile": 2.0, "thick": 0.06})
	Kit.label(root, "the sentence is: as before", c + Vector3(0, 4.2, 10.96), 0.0, 22, Color(0.9, 0.7, 0.65), "body", {"pixel_size": 0.012})
	area.rng.randf()


## The score goes up. The sentence is read, over and over, in a low voice.
static func _tick(_area: AreaBase, state: Dictionary, delta: float) -> void:
	if Game.time_frozen:
		return
	state.t += delta
	if state.t > 4.5:
		state.t = 0.0
		state.score += 1 + (randi() % 3)
		_score(state)
	if state.in_court:
		state.read_t += delta
		if state.read_t > 7.0:
			state.read_t = 0.0
			var lines := ["\"...as before,\" reads the herald. \"...and afterwards, the verdict...\"", "\"...the accused, being somewhere, and not there now...\"", "\"...sentence first. Verdict afterwards. Evidence, if any, at half past five...\"", "\"...carrying things, and not once putting them down...\""]
			Game.toast.emit(lines[state.reading % lines.size()])
			state.reading += 1
			Audio.sfx("whisper", null, -14.0)
