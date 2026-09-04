class_name KDTable
extends RefCounted
## The seventh square: the Tea Table. Every clock in ANTEROOM says half past
## five, and this is why. A ring of a table so long it vanishes into the fog
## in both directions, laid for far more people than sit at it, and the whole
## top turning slowly so the guests never keep the same cups. One chair is
## empty and it is always one seat ahead of you. The Hourglass stops the table
## and the chair, and sitting down is the only way to be told.
##
## Quotes the Clocktower (its keeper is here), the Last Lamp (the fare) and
## the Anteroom (the instruction to wait, on a plaque in the middle).

const R_IN := 26.0
const R_OUT := 29.5
const R_CHAIR := 31.0
const TABLE_H := 0.78
const SEGS := 36
const GOLD := Color(1.0, 0.85, 0.55)

## Who sits at the table: [name, angle, model, tint, lines]
const GUESTS := [
	["The Keeper", 200.0, "hermit", Color(1, 1, 1), [
		"\"It was half past five when he fell asleep,\" says the Keeper. He has a cup and it is empty and he drinks from it.",
		"\"Every clock you have ever trusted stopped then. Mine, the one in the flat, the one in the halls. They are all his.\"",
	]],
	["The Hare", 240.0, "patron_seated", Color(0.85, 0.75, 0.6), [
		"\"No room,\" says the Hare, at a table with room for two hundred. \"No room, no room.\"",
		"He moves a cup one place to the left. The table moves it back.",
	]],
	["The Sleeper", 160.0, "patron_seated", Color(0.7, 0.7, 0.85), [
		"Asleep with his face in a saucer. Between breaths he says: \"...twinkle, twinkle...\"",
		"\"Do not wake him,\" says nobody, and you were not going to.",
	]],
	["The Occupant", 290.0, "patron_seated", Color(0.6, 0.62, 0.7), [
		"Someone in a coat with the collar up, who does not turn round. On the place card: THE OCCUPANT OF 5½.",
		"You do not go round to see the face. You are fairly sure whose it is.",
	]],
]

## Place cards at empty chairs: [angle, text]
const CARDS := [
	[20.0, "for the King (asleep)"], [50.0, "for the Queen (running, will be late)"], [80.0, "for somebody tall"],
	[110.0, "reserved"], [130.0, "for the dog"], [330.0, "for the one who painted them"], [350.0, "for you. no. for you."],
]


static func build(area: AreaBase, root: Node3D, ctx: Dictionary) -> Dictionary:
	var d: Dictionary = ctx.def
	var state := {"chair": null, "chair_angle": 0.0, "seated": false, "table": null, "t": 0.0, "sit": null}
	Kit.floor(root, Vector3.ZERO, Vector2(KD.SQ, KD.SQ), String(d.ground), {"tint": d.tint, "tile": 2.0, "thick": 0.2})
	_table(area, root, state)
	_chairs(area, root, state)
	_middle(area, root)
	_edges(area, root)
	var out := {}
	out["on_process"] = func(delta: float) -> void:
		_tick(area, state, delta)
	out["on_freeze"] = func(frozen: bool) -> void:
		if frozen and not state.seated:
			Game.toast.emit("The table stops. The cups stop. The empty chair, for once, stays where it is.")
	# the ring leaves paths to every gate along the diagonals; the gates are standard
	return out


# --- the table that turns --------------------------------------------------------

static func _table(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var cw := Clockwork.create(root, Vector3.ZERO, {"mode": "rotate", "axis": Vector3.UP, "speed_deg": 1.6, "platform": true, "name": "Table"})
	state.table = cw
	var top := cw.body
	Kit.ring(top, Vector3(0, TABLE_H, 0), R_IN, R_OUT, SEGS, "fabric/sheet", {"tint": Color(1.0, 0.98, 0.92), "solid": false, "tile": 2.0})
	Kit.ring(top, Vector3(0, TABLE_H - 0.08, 0), R_IN - 0.2, R_OUT + 0.2, SEGS, "wood/table", {"down": true, "solid": false, "tile": 2.0})
	# the edge of the cloth hangs down
	Kit.round_wall(top, Vector3(0, TABLE_H - 0.3, 0), R_OUT + 0.15, 0.3, SEGS, "fabric/sheet", {"tint": Color(0.98, 0.95, 0.88), "solid": false})
	# collision: chords round the ring, so the player can stand on it and be carried
	var chord := 2.0 * R_OUT * sin(PI / SEGS)
	for i in SEGS:
		var a := (i + 0.5) * (360.0 / SEGS)
		var c := Kit.polar((R_IN + R_OUT) * 0.5, a, TABLE_H - 0.05)
		var shape_size := Vector3(chord + 0.4, 0.1, R_OUT - R_IN)
		# add_shape puts boxes at an offset, unrotated; rotate the body's child shape by hand
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = shape_size
		cs.shape = bs
		cs.position = c
		cs.rotation.y = deg_to_rad(-a + 90.0)
		top.add_child(cs)
	# legs, and what is on the table: pots, cups, candles, bottles from the Last Lamp
	var rng := area.rng
	for i in SEGS:
		var a := i * (360.0 / SEGS)
		Kit.cylinder(top, Kit.polar(R_IN + 0.4, a), 0.08, TABLE_H - 0.1, "wood/table", {"solid": false, "segments": 5})
		Kit.cylinder(top, Kit.polar(R_OUT - 0.4, a), 0.08, TABLE_H - 0.1, "wood/table", {"solid": false, "segments": 5})
		var mid := (R_IN + R_OUT) * 0.5
		var p := Kit.polar(mid + rng.randf_range(-1.0, 1.0), a + rng.randf_range(-3.0, 3.0), TABLE_H)
		match i % 6:
			0:
				Props.place(top, "teapot_tall", p, rng.randf_range(0, 360), 0.9, {"collision": "none"})
			1:
				Props.place(top, "teacup_stack", p, rng.randf_range(0, 360), 1.3, {"collision": "none"})
			2:
				Props.place(top, "candle_tall", p, 0.0, 1.0, {"collision": "none"})
			3:
				Props.place(top, "bottle", p, rng.randf_range(0, 360), 1.2, {"collision": "none"})
				Props.place(top, "mug", p + Kit.polar(0.5, a + 90.0), 0.0, 1.2, {"collision": "none"})
			4:
				Props.place(top, "candle_cluster", p, 0.0, 0.9, {"collision": "none"})
			5:
				Props.place(top, "teacup_stack", p, rng.randf_range(0, 360), 1.0, {"collision": "none", "tint": Color(1.0, 0.8, 0.85)})
		# a cup and saucer at every place, so the table is laid for two hundred
		var place := Kit.polar(R_OUT - 0.9, a + 5.0, TABLE_H)
		Kit.ring(top, place + Vector3(0, 0.01, 0), 0.0, 0.14, 8, "", {"tint": Color(0.98, 0.98, 0.95), "solid": false})
		Kit.cylinder(top, place, 0.07, 0.07, "", {"tint": [Color(0.98, 0.9, 0.92), Color(0.9, 0.95, 1.0), Color(1.0, 0.98, 0.85)][i % 3], "solid": false, "segments": 6})
	# the sleeper's saucer face, from the Slow Sea, on the table
	Props.place(top, "face_sea_sleep", Kit.polar(R_IN + 1.2, 160.0, TABLE_H + 0.02), 0.0, 0.1, {"collision": "none", "rotation": Vector3(-80, 160, 0)})
	# lights round the table, still, so the candles seem to pass under them
	for i in 8:
		var a := i * 45.0 + 10.0
		Kit.light(root, Kit.polar((R_IN + R_OUT) * 0.5, a, TABLE_H + 2.2), GOLD, 1.0, 10.0)
	Kit.particles(root, Vector3(0, TABLE_H + 1.0, 0), "motes", Vector3(32.0, 1.0, 32.0), 90)
	Readable.create(root, Kit.polar(R_OUT + 0.6, 300.0, 0.0), Kit.yaw_to_center(300.0), "Look at the table", [
		"A table that goes off into the fog both ways and comes back round behind you. Laid for two hundred. Four of them are here.",
		"It is turning. Slowly. The cups go by like the hours on a clock, and nobody keeps the same cup for long.",
	], {"name": "TableLook", "size": Vector3(2.0, 1.4, 1.2), "note_key": "dream_table", "note_title": "The tea table", "note_text": "A ring of a table in the seventh square, laid for two hundred, four of them present, the whole top turning slowly so nobody keeps the same cup. There is an empty chair and it is always one seat ahead of you."})


# --- chairs, guests, and the one empty chair -----------------------------------------

static func _chairs(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var taken := {}
	for g in GUESTS:
		taken[int(g[1])] = true
	for c in CARDS:
		taken[int(c[0])] = true
	for i in SEGS:
		var a := i * (360.0 / SEGS) + 5.0
		var ia := int(roundf(a - 5.0))
		if taken.has(ia) or i == 0:
			continue
		Props.place(root, "chair_white", Kit.polar(R_CHAIR, a), Kit.yaw_to_center(a), 1.0, {"collision": "box"})
	for g in GUESTS:
		var a := float(g[1]) + 5.0
		Props.place(root, "chair_white", Kit.polar(R_CHAIR, a), Kit.yaw_to_center(a), 1.0, {"collision": "box"})
		var npc := NPC.create(root, Kit.polar(R_CHAIR - 0.25, a), Kit.yaw_to_center(a), g[0], {"model": g[2], "lines": g[4], "face_player": false, "name": "Guest_" + String(g[0]).replace(" ", "_")})
		if npc.body:
			Props.stylize(npc.body, {"tint": g[3]})
		if g[0] == "The Keeper":
			npc.reactions = {"hourglass": ["\"You have it,\" says the Keeper. \"Then stop us. We have been waiting a long time to be stopped.\""]}
	for c in CARDS:
		var a := float(c[0]) + 5.0
		Props.place(root, "chair_white", Kit.polar(R_CHAIR, a), Kit.yaw_to_center(a), 1.0, {"collision": "box"})
		Kit.sign(root, "wall/paper", Kit.polar(R_CHAIR - 0.9, a, 0.9), Kit.yaw_to_center(a) + 180.0, Vector2(0.3, 0.16), {"tint": Color(0.95, 0.92, 0.85), "rotation": Vector3(-60, Kit.yaw_to_center(a) + 180.0, 0)})
		Readable.create(root, Kit.polar(R_CHAIR - 0.9, a, 0.6), Kit.yaw_to_center(a), "Read the place card", ["A folded card at an empty place. In a careful hand: " + String(c[1])], {"name": "Card_%d" % int(c[0]), "size": Vector3(0.6, 0.6, 0.6)})
	# the empty chair
	var chair := Node3D.new()
	chair.name = "EmptyChair"
	root.add_child(chair)
	Props.place(chair, "chair_white", Vector3.ZERO, 0.0, 1.0, {"collision": "none", "tint": Color(1.0, 0.95, 0.8)})
	Kit.light(chair, Vector3(0, 1.6, 0), GOLD, 0.6, 4.0)
	var sit := Interactable.make(chair, Vector3(0, 0.5, 0), Vector3(0.8, 1.1, 0.8), "Sit down", func(_p: Node, _it: Node) -> void:
		_sit(area, state), {"name": "Sit"})
	state.chair = chair
	state.sit = sit
	state.chair_angle = 35.0
	_place_chair(state)
	Puzzle.declare(area, "dream_tea", "dream_seated", ["keepsake:hourglass"], "stop the turning table and sit in the chair that is always one seat ahead of you")


static func _place_chair(state: Dictionary) -> void:
	var chair: Node3D = state.chair
	var a: float = state.chair_angle
	chair.position = Kit.polar(R_CHAIR, a)
	chair.rotation.y = deg_to_rad(Kit.yaw_to_center(a))


## The chair keeps one seat ahead of you unless time is held.
static func _tick(_area: AreaBase, state: Dictionary, delta: float) -> void:
	state.t += delta
	if state.seated or Game.time_frozen:
		return
	var p := Game.player as Player
	if p == null:
		return
	var chair: Node3D = state.chair
	var root: Node3D = chair.get_parent()
	var l := root.to_local(p.global_position)
	var pa := rad_to_deg(atan2(l.z, l.x))
	var diff := wrapf(float(state.chair_angle) - pa, -180.0, 180.0)
	if absf(diff) < 28.0 and Vector2(l.x, l.z).length() > R_OUT:
		# it goes on ahead, the way you were going
		var sgn := 1.0 if diff >= 0.0 else -1.0
		state.chair_angle = wrapf(pa + sgn * 40.0, 0.0, 360.0)
		_place_chair(state)
		if Game.bump("dream_chair_moved") == 2:
			Game.toast.emit("The empty chair is one seat further on. It was always going to be.")


## What they say when you finally sit. Short.
static func _sit(area: AreaBase, state: Dictionary) -> void:
	if not Game.time_frozen:
		Game.toast.emit("You reach the chair and the chair is one seat further on.")
		state.chair_angle = wrapf(float(state.chair_angle) + 40.0, 0.0, 360.0)
		_place_chair(state)
		return
	state.seated = true
	var p := Game.player as Player
	if p != null:
		var chair: Node3D = state.chair
		p.global_position = chair.global_position + Vector3(0, 0.55, 0)
		p.set_look(deg_to_rad(Kit.yaw_to_center(float(state.chair_angle))), -0.1)
	Game.set_flag("dream_seated", true)
	if World.hud:
		await World.hud.say("", [
			"You sit. The table is still. The cups are still. Four people look at you.",
			"\"It was half past five when he fell asleep,\" says the Keeper. \"Everything he has heard of stopped at the time it was.\"",
			"\"He turns over at half past five,\" says the Hare. \"Everyone does. That is what a clock is for.\"",
			"\"You are having tea in a stopped hour,\" says the Keeper. \"So is everyone you have ever met in here. Drink up. It does not go cold.\"",
		])
	Game.note("dream_tea", "Why it is always half past five", "The King fell asleep at half past five. Everything he had heard of stopped at the time it was, and every clock you have trusted since is one of his. At his table they have been having tea in that hour ever since. It does not go cold.")
	state.seated = false
	if state.sit:
		(state.sit as Interactable).enabled = true
	area.rng.randf()


# --- the middle of the ring ---------------------------------------------------------

static func _middle(area: AreaBase, root: Node3D) -> void:
	# a stopped clock, enormous, and the Anteroom's plaque at its foot
	Props.place(root, "clock_grandfather", Vector3(0, 0, -3.0), 0.0, 4.0, {"collision": "box"})
	Kit.light(root, Vector3(0, 6.0, 0), Color(1.0, 0.9, 0.7), 1.3, 20.0)
	Kit.box(root, Vector3(0, 0.5, 2.0), Vector3(1.2, 1.0, 0.4), "stone/blocks_nexus")
	Readable.create(root, Vector3(0, 1.05, 1.8), 0.0, "Read the plaque", [
		"YOU ARE EARLY. WAIT HERE.",
		"The same plaque. The same scratch under it. Somebody has added, in tea: \"we did.\"",
	], {"name": "Plaque", "sign": "signs/plaque_anteroom", "sign_size": Vector2(1.0, 0.5), "size": Vector3(1.2, 0.6, 0.2), "note_key": "dream_plaque", "note_title": "The plaque at the tea table", "note_text": "In the middle of the ring of the tea table, the Anteroom's plaque: you are early, wait here. Somebody has written under it, in tea: we did."})
	Readable.create(root, Vector3(0, 1.6, -1.6), 0.0, "Look at the clock", [
		"The Clocktower's clock, or its brother, four times the size. Half past five.",
		"The pendulum is not moving. The pendulum has never moved. Behind the face something is trying, like a moth in a jar.",
	], {"name": "BigClock", "size": Vector3(2.0, 3.0, 1.0)})
	Kit.particles(root, Vector3(0, 2.0, 0), "motes", Vector3(6.0, 2.0, 6.0), 30)
	# the way in over the table is the way in; a stile of a stair at one point, for the honest
	Kit.stairs(root, Vector3(0, 0, R_OUT + 1.6), 0.0, 1.4, 4, 0.2, 0.4, "wood/planks_white", {"name": "Stile"})
	area.rng.randf()


static func _edges(area: AreaBase, root: Node3D) -> void:
	# the menu on a post by the way in, and trees of the Last Lamp's courtyard
	var mp := Vector3(6.0, 0, 36.0)
	Kit.box(root, mp + Vector3(0, 1.1, 0), Vector3(0.1, 2.2, 0.1), "wood/planks_dark")
	Readable.create(root, mp + Vector3(0, 1.6, 0), 0.0, "Read the menu", [
		"TEA. tea. more tea. no room.",
		"Under it, smaller: the Last Lamp regrets that it cannot serve anything that is not tea, as it is half past five.",
	], {"name": "Menu", "sign": "signs/kd_menu", "sign_size": Vector2(0.6, 0.8), "size": Vector3(0.7, 0.9, 0.2)})
	var rng := area.rng
	for i in 22:
		var a := rng.randf_range(0, 360)
		var r := rng.randf_range(35.0, 42.0)
		var p := Kit.polar(r, a)
		if absf(p.x) < 4.0 or absf(p.z) < 4.0:
			continue
		Props.place(root, ["tree_autumn", "tree_oak_2", "tree_autumn"][i % 3], p, rng.randf_range(0, 360), rng.randf_range(0.9, 1.4), {"collision": "cylinder", "tint": Color(1.1, 0.95, 0.75)})
	for i in 4:
		var a := i * 90.0 + 45.0
		Props.place(root, "lantern_post", Kit.polar(33.5, a), 0.0, 1.0, {"collision": "cylinder"})
		Kit.light(root, Kit.polar(33.5, a, 2.8), GOLD, 0.9, 10.0)
	Kit.light(root, Vector3(0, 4.0, 38.0), GOLD, 0.9, 12.0)
	Kit.light(root, Vector3(0, 4.0, -38.0), GOLD, 0.9, 12.0)
	Kit.light(root, Vector3(38.0, 4.0, 0), GOLD, 0.9, 12.0)
	Kit.light(root, Vector3(-38.0, 4.0, 0), GOLD, 0.9, 12.0)
