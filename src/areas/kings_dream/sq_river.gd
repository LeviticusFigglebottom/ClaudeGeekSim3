class_name KDRiver
extends RefCounted
## The fifth square: the Shop and the River. A tavern that sells nothing; its
## shelves are full until you look at them, and only while the hour is held
## do they stay full long enough to read a label. Behind the bar the floor
## becomes a boat's deck without a seam, and the deck drifts out on water
## the Slow Sea's colour and the Cistern's temperature, to an island. From
## the island's rock the far bank is a glide away, and on the far bank grows
## the one rush that does not fade. The far bank is a tiled quay with tide
## marks at three heights, and the way on is up there.
##
## Quotes the Last Lamp, the Slow Sea and the Cistern.

const SHOP := Vector3(0, 0, 22.0)
const SHOP_W := 14.0
const SHOP_D := 16.0
const SHOP_H := 3.4
const BANK_Z := 12.0          # the near bank ends here
const QUAY_Z := -16.0         # the far bank begins here
const QUAY_Y := 2.5
const BED_Y := -1.2
const ISLAND := Vector3(2.0, 0, -1.0)
const ISLAND_TOP := 7.0
const WATER := Color(0.45, 0.3, 0.85, 0.92)
const CANDLE := Color(1.0, 0.85, 0.6)
const MINT := Color(0.78, 0.96, 0.9)


static func build(area: AreaBase, root: Node3D, ctx: Dictionary) -> Dictionary:
	var d: Dictionary = ctx.def
	var state := {"shelves": [], "labels": [], "boat": null, "t": 0.0, "area": area}
	# the near bank (sand), the river bed, and the quay
	Kit.floor(root, Vector3(0, 0, (BANK_Z + KD.HALF) * 0.5), Vector2(KD.SQ, KD.HALF - BANK_Z), String(d.ground), {"tint": d.tint, "tile": 2.0, "thick": 0.2})
	Kit.floor(root, Vector3(0, BED_Y, (BANK_Z + QUAY_Z) * 0.5), Vector2(KD.SQ, BANK_Z - QUAY_Z), "ground/mud", {"tint": Color(0.7, 0.65, 0.8), "tile": 2.0, "thick": 0.2})
	Kit.water(root, Vector3(0, 0.0, (BANK_Z + QUAY_Z) * 0.5), Vector2(KD.SQ + 2.0, BANK_Z - QUAY_Z), "nature/water_sea", {"tint": WATER, "uv_scale": 0.3, "speed": 0.03, "swell": 0.05})
	# the bank slopes into the water
	Kit.ramp(root, Vector3(0, 0, BANK_Z), 0.0, KD.SQ, 3.0, BED_Y, "ground/sand", {"tint": Color(0.95, 0.9, 0.85), "tile": 2.0})
	_quay(area, root)
	_shop(area, root, state)
	_boat(area, root, state)
	_island(area, root)
	_rushes(area, root)
	_charm(area, root, state)
	_lights(root)
	var out := {}
	out["edge_y"] = {"N": QUAY_Y}
	out["on_process"] = func(delta: float) -> void:
		state.t += delta
		if not Game.time_frozen and state.t - float(state.get("gull", 0.0)) > 24.0:
			state["gull"] = state.t
			Audio.sfx("seagull_wrong", Vector3(area.rng.randf_range(-30.0, 30.0), 8.0, -4.0) + root.global_position, -10.0)
	out["on_freeze"] = func(frozen: bool) -> void:
		_freeze(state, frozen)
	out["usher"] = Vector3(-30.0, QUAY_Y, -30.0)
	return out


# --- the shop that sells nothing ----------------------------------------------------------

static func _shop(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var c := SHOP
	var hw := SHOP_W * 0.5
	var hd := SHOP_D * 0.5
	var wall := "wall/plaster_tavern"
	Kit.floor(root, c + Vector3(0, 0.1, 0), Vector2(SHOP_W, SHOP_D), "wood/planks_warm", {"tile": 1.5, "thick": 0.14})
	Kit.ceiling(root, c + Vector3(0, SHOP_H, 0), Vector2(SHOP_W, SHOP_D), "wood/planks_dark", {"tile": 1.5})
	Kit.box(root, c + Vector3(0, SHOP_H + 0.5, 0), Vector3(SHOP_W + 1.0, 1.0, SHOP_D + 1.0), "wood/thatch", {"tile": 2.0, "solid": false})
	# three walls; the south one has the door; the north side is open to the deck
	Kit.wall(root, c + Vector3(-hw, 0, hd), c + Vector3(-hw, 0, -hd), SHOP_H, wall, {"thick": 0.3})
	Kit.wall(root, c + Vector3(hw, 0, -hd), c + Vector3(hw, 0, hd), SHOP_H, wall, {"thick": 0.3})
	Kit.wall(root, c + Vector3(hw, 0, hd), c + Vector3(1.2, 0, hd), SHOP_H, wall, {"thick": 0.3})
	Kit.wall(root, c + Vector3(-1.2, 0, hd), c + Vector3(-hw, 0, hd), SHOP_H, wall, {"thick": 0.3})
	Kit.box(root, c + Vector3(0, SHOP_H - 0.35, hd), Vector3(2.6, 0.7, 0.3), wall)
	for sx in [-hw, hw]:
		Kit.box(root, c + Vector3(float(sx), SHOP_H * 0.5, -hd), Vector3(0.4, SHOP_H, 0.4), "wood/planks_dark")
	Props.place(root, "sign_last_lamp", c + Vector3(-3.0, 0, hd + 1.0), 0.0, 0.9, {"collision": "cylinder"})
	Readable.create(root, c + Vector3(0, 1.8, hd + 0.2), 180.0, "Read the sign over the door", [
		"THE LAST LAMP. we sell nothing. and we have plenty of it.",
		"The paint is fresh. The nothing, by the look of the shelves, is not.",
	], {"name": "ShopSign", "sign": "signs/kd_shop", "sign_size": Vector2(1.6, 1.2), "size": Vector3(1.8, 1.4, 0.3), "note_key": "dream_shop", "note_title": "The shop that sells nothing", "note_text": "The Last Lamp, in the fifth square, sells nothing and has plenty of it. The shelves are full until you look at them. Behind the bar the floor is a boat."})
	# the bar across the room, and the keeper behind it, knitting
	Props.place(root, "bar_counter", c + Vector3(0, 0, -1.0), 0.0, 1.0, {"collision": "box"})
	Props.place(root, "tankard_rack", c + Vector3(-hw + 0.2, 1.6, -3.0), -90.0, 1.0, {"collision": "none"})
	NPC.create(root, c + Vector3(0, 0, -2.4), 0.0, "The Shopkeeper", {"model": "barkeep", "name": "Shopkeeper", "prompt": "Ask the shopkeeper", "lines": [
		"\"What is it you want to buy?\" says the shopkeeper, knitting with more needles than you can count.",
		"\"I should like to look round first.\" \"You may look in front of you, and on both sides. You can't look all round you unless you've eyes at the back of your head.\"",
		"\"Everything we have is on the shelves,\" says the shopkeeper. \"Everything we have is nothing. It sells very well.\"",
	], "reactions": {
		"hourglass": ["\"Ah,\" says the shopkeeper. \"With that, you could look at a shelf for as long as you liked. We'd rather you didn't.\""],
		"crown": ["\"We don't serve royalty,\" says the shopkeeper, \"on account of the last one.\""],
	}})
	# shelves along both walls, full until you look at them
	var rng := area.rng
	for k in 3:
		for side in [-1.0, 1.0]:
			var sp := c + Vector3(side * (hw - 0.25), 1.5, 3.0 - k * 2.6)
			Props.place(root, "wall_shelf", sp, -90.0 if side < 0 else 90.0, 1.0, {"collision": "none"})
			var goods := Node3D.new()
			goods.name = "Goods"
			goods.position = sp + Vector3(-side * 0.25, 0.02, 0)
			root.add_child(goods)
			for j in 4:
				var gp := Vector3(0, 0, -0.75 + j * 0.5)
				Props.place(goods, ["bottle", "bottle_moonlight", "mug", "bottle"][(j + k) % 4], gp, rng.randf_range(0, 360), 0.9, {"collision": "none"})
			var watch := LookAway.create(root, sp, func(_l: Node) -> void:
				if not Game.time_frozen:
					goods.visible = false
					Game.bump("dream_shelves_emptied"), {"when_seen": true, "delay": 0.35, "once": false, "radius": 7.0, "dot_threshold": 0.92})
			LookAway.create(root, sp, func(_l: Node) -> void:
				goods.visible = true, {"delay": 1.2, "once": false, "radius": 7.0, "dot_threshold": 0.92})
			state.shelves.append({"goods": goods, "watch": watch})
			# one label, readable only while the shelf is held full
			if k == 1:
				var r := Readable.create(root, sp + Vector3(-side * 0.3, 0, 0), -90.0 if side < 0 else 90.0, "Read a label", [
					"BOTTLE OF NOTHING. Cold to hold. Lights nothing. Everybody wants one very badly.",
					"Under it, in the barkeep's hand: not for sale. not for trade. not, strictly, here.",
				] if side < 0 else [
					"MOONLIGHT (EMPTY). The label is the one from the Last Lamp, in the same hand, with the price crossed out.",
					"Where the price was, somebody has written: what have you got?",
				], {"name": "ShelfLabel%d" % int(side), "size": Vector3(0.6, 1.0, 2.2), "note_key": "dream_label", "note_title": "A label, read", "note_text": "With the hour held, the shelves of the shop that sells nothing stayed full long enough to read a label: a bottle of nothing, cold to hold, that everybody wants very badly. Not for sale. Not, strictly, here.", "flag_on_read": "dream_label_read"})
				r.enabled = false
				state.labels.append(r)
	Puzzle.declare(area, "dream_shelves", "dream_label_read", ["keepsake:hourglass"], "hold the hour in the shop that sells nothing and read one label")
	# what else is in a tavern
	Props.place(root, "barrel", c + Vector3(hw - 1.2, 0, 5.5), 0.0, 1.0)
	Props.place(root, "table_round", c + Vector3(-3.5, 0, 4.5), 0.0, 1.0)
	Props.place(root, "stool", c + Vector3(-4.6, 0, 4.5), 0.0, 1.0)
	Props.place(root, "stool", c + Vector3(-2.4, 0, 4.5), 0.0, 1.0)
	Props.place(root, "lantern_hanging", c + Vector3(0, SHOP_H - 0.05, 3.0), 0.0, 1.0, {"collision": "none"})
	Props.place(root, "lantern_hanging", c + Vector3(0, SHOP_H - 0.05, -4.5), 0.0, 1.0, {"collision": "none"})
	Kit.light(root, c + Vector3(0, SHOP_H - 0.8, 3.0), CANDLE, 1.1, 8.0)
	Kit.light(root, c + Vector3(0, SHOP_H - 0.8, -4.5), CANDLE, 1.1, 8.0)
	Kit.light(root, c + Vector3(0, 1.0, -hd - 1.0), MINT, 0.8, 7.0)
	Kit.particles(root, c + Vector3(0, 1.5, 0), "motes", Vector3(6.0, 1.5, 7.0), 40)
	Kit.sign(root, "metal/clock_face", c + Vector3(hw - 0.17, 2.2, 6.0), 90.0, Vector2(0.7, 0.7))
	Readable.create(root, c + Vector3(hw - 0.3, 2.2, 6.0), 90.0, "The clock", ["Half past five. The shop is open. The shop is always open at half past five."], {"name": "ShopClock", "size": Vector3(0.2, 0.7, 0.7)})


static func _freeze(state: Dictionary, frozen: bool) -> void:
	var area: Node = state.get("area")
	if area != null and area.has_meta("river_face"):
		KD.set_face(area.get_meta("river_face"), "awake" if frozen else "sleep")
	for s in state.shelves:
		(s.goods as Node3D).visible = true
	for r in state.labels:
		(r as Readable).enabled = frozen
	if frozen:
		Game.toast.emit("The shelves stay full. You could read a label, if you were quick, which you no longer need to be.")


# --- the deck that drifts ---------------------------------------------------------------

static func _boat(_area: AreaBase, root: Node3D, state: Dictionary) -> void:
	# the boat rides a hand above the water, so its deck is never in the water's plane
	var start := SHOP + Vector3(0, 0.12, -SHOP_D * 0.5 - 5.0)
	var cw := Clockwork.create(root, start, {"mode": "path", "points": [Vector3.ZERO, Vector3(0, 0, -13.0)], "speed_deg": 6.0, "platform": true, "name": "Boat"})
	state.boat = cw
	var deck := cw.body
	var L := 10.0
	var Wd := 6.0
	Kit.box(deck, Vector3(0, -0.1, 0), Vector3(Wd, 0.2, L), "wood/planks_warm", {"tile": 1.5, "solid": false})
	cw.add_shape(Vector3(Wd, 0.2, L), Vector3(0, -0.1, 0))
	# hull, rails, a prow, a lantern; the deck is the shop's floor, continued
	Kit.box(deck, Vector3(0, -0.9, 0), Vector3(Wd + 0.4, 1.6, L + 0.4), "wood/planks_dark", {"tile": 1.5, "solid": false})
	Kit.box(deck, Vector3(0, -0.6, -L * 0.5 - 1.6), Vector3(1.6, 1.4, 3.2), "wood/planks_dark", {"tile": 1.5, "solid": false})
	for sx in [-Wd * 0.5, Wd * 0.5]:
		Kit.box(deck, Vector3(float(sx), 0.5, 0), Vector3(0.12, 1.0, L), "wood/planks_dark", {"solid": false})
		cw.add_shape(Vector3(0.2, 1.0, L), Vector3(float(sx), 0.5, 0))
	Kit.box(deck, Vector3(0, 0.5, -L * 0.5), Vector3(Wd, 1.0, 0.12), "wood/planks_dark", {"solid": false})
	Props.place(deck, "lantern_post", Vector3(Wd * 0.5 - 0.5, 0, -L * 0.5 + 0.6), 0.0, 0.7, {"collision": "none"})
	Kit.light(deck, Vector3(Wd * 0.5 - 0.5, 2.4, -L * 0.5 + 0.6), CANDLE, 0.5, 7.0)
	Props.place(deck, "table_round", Vector3(-1.5, 0, 1.5), 0.0, 0.9, {"collision": "none"})
	Props.place(deck, "mug", Vector3(-1.5, 0.75, 1.5), 0.0, 1.0, {"collision": "none"})
	Readable.create(deck, Vector3(0, 0.3, 0), 0.0, "Look at the deck", [
		"The floorboards of the shop go on under your feet and at some point they are a deck. There was no step. There was no door.",
		"The river is the colour of the Slow Sea and, when you put a hand in, the temperature of the Cistern. It is going somewhere. So are you.",
	], {"name": "DeckLook", "size": Vector3(3.0, 1.0, 3.0), "note_key": "dream_boat", "note_title": "The shop that is a boat", "note_text": "Behind the bar of the shop that sells nothing, the floorboards keep going and become a deck, and the deck drifts out on a purple river toward an island. You did not notice the moment it stopped being a room."})
	Puzzle.declare(_area, "dream_boat", "", [], "ride the deck of the shop out to the island")


# --- the island and the glide ------------------------------------------------------------

static func _island(area: AreaBase, root: Node3D) -> void:
	var c := ISLAND
	Kit.cylinder(root, c + Vector3(0, BED_Y, 0), 7.0, 1.3, "ground/sand", {"tint": Color(0.95, 0.9, 0.85), "segments": 14, "tile": 2.0})
	Kit.cylinder(root, c + Vector3(0, BED_Y + 0.2, 0), 6.2, 1.3, "ground/sand", {"tint": Color(0.95, 0.9, 0.85), "segments": 14, "tile": 2.0})
	# the rock: a Slow Sea stack with a stair round it to a landing seven metres up
	Kit.cylinder(root, c + Vector3(0, 0.3, 0), 2.4, ISLAND_TOP - 0.3, "stone/blocks_sea", {"tint": Color(0.95, 0.85, 0.95), "segments": 10, "tile": 3.0})
	var flights := 4
	var rise := (ISLAND_TOP - 0.3) / flights
	for i in flights:
		var a0 := i * 90.0 + 45.0
		var a1 := (i + 1) * 90.0 + 45.0
		var l0 := c + Kit.polar(3.4, a0, 0.3 + i * rise)
		var l1 := c + Kit.polar(3.4, a1, 0.3 + (i + 1) * rise)
		var dd := l1 - l0
		dd.y = 0.0
		Kit.stairs(root, l0, Kit.dir_to_yaw(dd.normalized()), 1.4, 9, rise / 9, dd.length() / 9, "stone/blocks_sea", {"tint": Color(1.0, 0.85, 0.9), "tile": 1.0})
		Kit.floor(root, l0, Vector2(1.6, 1.6), "stone/blocks_sea", {"tint": Color(0.95, 0.9, 0.95), "tile": 1.0})
	var top := c + Kit.polar(3.4, flights * 90.0 + 45.0, ISLAND_TOP)
	Kit.floor(root, top, Vector2(1.6, 1.6), "stone/blocks_sea", {"tint": Color(0.95, 0.9, 0.95), "tile": 1.0})
	Kit.floor(root, (top + c + Vector3(0, ISLAND_TOP, 0)) * 0.5, Vector2(1.4, 3.6), "stone/blocks_sea", {"tint": Color(0.95, 0.9, 0.95), "tile": 1.0, "yaw": Kit.dir_to_yaw((c - top).normalized()) + 90.0})
	Kit.ring(root, c + Vector3(0, ISLAND_TOP + 0.02, 0), 0.0, 2.4, 10, "stone/blocks_sea", {"tint": Color(1.0, 0.9, 0.95), "solid": false})
	var face := KD.face_on_stem(root, c + Vector3(-4.5, BED_Y + 1.2, 2.0), 30.0, 1.1, "sleep", Color(0.9, 0.85, 1.0))
	area.set_meta("river_face", face)
	Kit.light(root, c + Vector3(0, ISLAND_TOP + 2.5, 0), MINT, 1.2, 12.0)
	Readable.create(root, c + Vector3(0, ISLAND_TOP, -1.6), 0.0, "Look across", [
		"From the top of the rock the far bank is a tiled wall with a ledge on top, and on the ledge, one green thing standing up.",
		"It is further than a jump. It is not further than a fall, if you fall slowly.",
	], {"name": "IslandLook", "size": Vector3(2.0, 1.4, 1.0)})
	Puzzle.declare(area, "dream_river", "dream_rush", ["keepsake:wings"], "glide from the island's rock to the far bank of the river and pick the rush that does not fade")


# --- rushes, and the one that does not fade -----------------------------------------------------

static func _rushes(area: AreaBase, root: Node3D) -> void:
	var rng := area.rng
	var fades := ["You pick it. It smells of rain on a hot road. By the time you have turned round it is nothing in your hand.",
		"You pick it. It is the loveliest one. It is gone before the water has closed over where it stood.",
		"This one keeps a moment longer. Then it is a smell, and then not that."]
	for i in 12:
		var p := Vector3(rng.randf_range(-40.0, 40.0), BED_Y + 0.8, BANK_Z - rng.randf_range(0.8, 3.0))
		if absf(p.x) < 4.5:
			continue
		_rush(root, p, rng)
		if i % 3 == 0:
			Interactable.make(root, p + Vector3(0, 0.5, 0), Vector3(0.8, 1.6, 0.8), "Pick a rush", func(_p: Node, it: Node) -> void:
				Audio.sfx("page", null, -12.0)
				Game.toast.emit(fades[Game.bump("dream_rushes_faded") % fades.size()])
				it.queue_free(), {"name": "Rush%d" % i})
	# the one on the quay
	var q := Vector3(3.0, QUAY_Y, QUAY_Z - 3.0)
	_rush(root, q, rng, 1.3)
	Interactable.make(root, q + Vector3(0, 0.6, 0), Vector3(0.9, 1.8, 0.9), "Pick the rush", func(_p: Node, it: Node) -> void:
		Audio.sfx("pickup_item", null, -6.0)
		Game.set_flag("dream_rush", true)
		Game.note("dream_rush", "The rush that does not fade", "Every rush along the river fades before you reach the shore. The one on the far bank, which took the Wings to reach, does not. You keep it. You are not sure where.")
		if World.hud:
			await World.hud.say("", ["You pick it. You wait. It does not fade.", "You are not sure where you are keeping it. You are keeping it."])
		it.queue_free(), {"name": "TheRush", "one_shot": true})
	Kit.light(root, q + Vector3(0, 2.0, 0), MINT, 0.9, 6.0)


static func _rush(root: Node3D, p: Vector3, rng: RandomNumberGenerator, s: float = 1.0) -> void:
	for k in 3:
		var off := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		var h := rng.randf_range(1.4, 2.2) * s
		var stem := Kit.box(root, p + off + Vector3(0, h * 0.5, 0), Vector3(0.05, h, 0.05), "", {"tint": Color(0.4, 0.7, 0.4), "solid": false})
		stem.rotation.z = rng.randf_range(-0.12, 0.12)
		Kit.box(root, p + off + Vector3(0, h, 0), Vector3(0.09, 0.3, 0.09), "", {"tint": Color(0.45, 0.3, 0.2), "solid": false})


# --- the quay, from the Cistern ----------------------------------------------------------------

static func _quay(area: AreaBase, root: Node3D) -> void:
	var depth := KD.HALF - (-QUAY_Z)
	var cz := (QUAY_Z - KD.HALF) * 0.5
	Kit.floor(root, Vector3(0, QUAY_Y, cz), Vector2(KD.SQ, depth), "wall/tile_checker", {"tile": 1.0, "thick": 0.2})
	# the quay wall, tiled, with the tide marks
	Kit.box(root, Vector3(0, (QUAY_Y + BED_Y) * 0.5, QUAY_Z + 0.4), Vector3(KD.SQ + 2.0, QUAY_Y - BED_Y, 0.8), "wall/tile_white", {"tile": 1.0})
	for m in [[0.6, Color(0.55, 0.45, 0.35)], [1.3, Color(0.6, 0.5, 0.4)], [2.0, Color(0.7, 0.62, 0.55)]]:
		Kit.box(root, Vector3(0, float(m[0]), QUAY_Z - 0.02), Vector3(KD.SQ, 0.06, 0.04), "", {"tint": m[1], "solid": false})
	Readable.create(root, Vector3(-6.0, 1.4, QUAY_Z - 0.4), 0.0, "Tide marks", [
		"Three lines along the tiles. One at the height of a child. One at the height of a chest. One you have to look up for.",
		"The water has been higher than this. Three times at least. Each time it came higher, and each time it went away again, and nobody has told the river.",
	], {"name": "TideMarks", "size": Vector3(4.0, 2.4, 0.4), "note_key": "dream_tide", "note_title": "Tide marks on the quay", "note_text": "The far bank of the river is the Cistern's tiling, with tide marks at three heights. The water has been higher than this. It always has."})
	Props.place(root, "pool_ladder", Vector3(-12.0, QUAY_Y, QUAY_Z - 0.3), 180.0, 1.0, {"collision": "none"})
	Props.place(root, "lifeguard_chair", Vector3(14.0, QUAY_Y, QUAY_Z - 3.0), 0.0, 1.0)
	for sx in [-20.0, 20.0]:
		Props.place(root, "pillar_tiled", Vector3(float(sx), QUAY_Y, QUAY_Z - 8.0), 0.0, 1.0, {"collision": "cylinder"})
		Kit.light(root, Vector3(float(sx), QUAY_Y + 4.0, QUAY_Z - 8.0), MINT, 1.0, 12.0)
	# hedges along the quay's edges, at its height
	KD.hedge(root, Vector3(-KD.HALF - 0.6, QUAY_Y, QUAY_Z), Vector3(-KD.HALF - 0.6, QUAY_Y, -KD.RIM + 0.6), {"tint": Color(0.9, 1.0, 0.9)})
	KD.hedge(root, Vector3(KD.HALF + 0.6, QUAY_Y, -KD.RIM + 0.6), Vector3(KD.HALF + 0.6, QUAY_Y, QUAY_Z), {"tint": Color(0.9, 1.0, 0.9)})
	Kit.particles(root, Vector3(0, QUAY_Y + 0.5, QUAY_Z - 10.0), "fog", Vector3(40.0, 0.5, 8.0), 20)
	area.rng.randf()


## Shells on the sand, a gull that is wrong, and bottles the river has not taken.
static func _charm(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var rng := area.rng
	for i in 10:
		var p := Vector3(rng.randf_range(-40.0, 40.0), 0, rng.randf_range(14.0, 40.0))
		if absf(p.x - SHOP.x) < SHOP_W * 0.5 + 2.0 and absf(p.z - SHOP.z) < SHOP_D * 0.5 + 2.0:
			continue
		Props.place(root, ["shell", "rock_pale", "bottle_moonlight"][i % 3], p, rng.randf_range(0, 360), rng.randf_range(0.8, 1.4), {"collision": "none"})
	for sx in [-28.0, 30.0]:
		Props.place(root, "lantern_post", Vector3(float(sx), 0, 14.5), 0.0, 1.0, {"collision": "cylinder"})
		Kit.light(root, Vector3(float(sx), 2.8, 14.5), CANDLE, 0.9, 9.0)
	Props.place(root, "moon_face", Vector3(-30.0, 14.0, -30.0), 30.0, 1.5, {"collision": "none"})
	state["gull"] = 0.0
	Readable.create(root, Vector3(-20.0, 0.5, 30.0), 0.0, "Look at the shells", [
		"Shells, and a bottle with nothing in it, and a rock that is paler than the sand.",
		"Every so often, out over the water, a gull says the wrong thing.",
	], {"name": "Shells", "size": Vector3(3.0, 1.0, 3.0)})


static func _lights(root: Node3D) -> void:
	Kit.light(root, Vector3(0, 4.0, 36.0), Color(1.0, 0.95, 0.85), 1.0, 14.0)
	Kit.light(root, Vector3(-20.0, 3.0, 8.0), MINT, 0.9, 16.0)
	Kit.light(root, Vector3(20.0, 3.0, 8.0), MINT, 0.9, 16.0)
	Kit.light(root, Vector3(0, QUAY_Y + 4.0, -36.0), Color(1.0, 0.95, 0.85), 1.0, 14.0)
	Kit.light(root, Vector3(0, 2.0, -8.0), Color(0.75, 0.62, 1.0), 0.9, 18.0)
