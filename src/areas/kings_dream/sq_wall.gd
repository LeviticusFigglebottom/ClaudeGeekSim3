class_name KDWall
extends RefCounted
## The sixth square: the Wall. A flooded street of the Drowned City runs north
## between its bone-coloured houses, and across it, high up, one wall with
## someone very round sitting on it. He explains every sign in the game and
## every explanation is wrong and internally perfect. The wall can only be
## reached by gliding from the ruined tower, and when you reach him he falls.
## He always falls. Afterwards all the king's horses and all the king's men
## come, and they are the Ossuary's bone knights, unhurried, and they cannot
## put him together.
##
## On the wall's west end a terrace, and a brook across it that runs back to
## the garden: the square builds that ford itself because it is fourteen
## metres up.
##
## Quotes the Drowned City and the Ossuary.

const STREET_W := 12.0
const STREET_Y := -0.4
const WALL_Z := -6.0
const WALL_H := 14.0
const WALL_T := 3.0
const TOWER := Vector3(13.0, 0, 12.0)
const TOWER_H := 22.0
const TERRACE_X := -38.0
const BONE := Color(0.95, 0.92, 0.85)
const COLD := Color(0.75, 0.85, 1.0)
const LAMP := Color(1.0, 0.85, 0.6)


static func build(area: AreaBase, root: Node3D, ctx: Dictionary) -> Dictionary:
	var d: Dictionary = ctx.def
	var state := {"egg": null, "fallen": false, "npc": null, "knights": [], "shards": null}
	Kit.floor(root, Vector3.ZERO, Vector2(KD.SQ, KD.SQ), String(d.ground), {"tint": d.tint, "tile": 2.0, "thick": 0.2})
	_street(area, root)
	_wall(area, root, state)
	_tower(area, root)
	_egg(area, root, state)
	_lights(root)
	var out := {}
	if ctx.fords.has("WALL"):
		var f: Dictionary = ctx.fords["WALL"]
		var other: Dictionary = (ctx.area as Node).DEFS[int(f.other)]
		out["WALL"] = _terrace(area, root, d, other)
	out["usher"] = Vector3(-20.0, 0, -36.0)
	return out


# --- the flooded street ----------------------------------------------------------------

static func _street(area: AreaBase, root: Node3D) -> void:
	var rng := area.rng
	var hw := STREET_W * 0.5
	# the street is lower than the square and the water lies on it
	Kit.floor(root, Vector3(0, STREET_Y, 0), Vector2(STREET_W + 8.0, KD.SQ - 14.0), "stone/cobble_city", {"tile": 1.5, "thick": 0.2})
	Kit.water(root, Vector3(0, 0.0, 0), Vector2(STREET_W + 8.0, KD.SQ - 14.0), "nature/water_dark", {"tint": Color(0.55, 0.62, 0.75, 0.8), "uv_scale": 0.3, "speed": 0.01, "swell": 0.03})
	Kit.ramp(root, Vector3(0, 0, 38.0), 0.0, STREET_W + 8.0, 3.0, STREET_Y, "stone/cobble_city", {"tile": 1.5})
	Kit.ramp(root, Vector3(0, 0, -38.0), 180.0, STREET_W + 8.0, 3.0, STREET_Y, "stone/cobble_city", {"tile": 1.5})
	# houses either side, bone-coloured, shuttered, taller than they should be
	for side in [-1.0, 1.0]:
		var z := 34.0
		while z > -34.0:
			var depth := rng.randf_range(6.0, 9.0)
			var h := rng.randf_range(7.0, 13.0)
			var w := rng.randf_range(5.0, 8.0)
			if absf(z - WALL_Z) < 6.0:
				z -= depth + 0.5
				continue
			var x: float = side * (hw + 4.0 + w * 0.5)
			var c := Vector3(x, h * 0.5, z - depth * 0.5)
			Kit.box(root, c, Vector3(w, h, depth), "stone/blocks_city", {"tile": 2.5, "tint": Color(1.0, 0.98, 0.92)})
			Kit.box(root, c + Vector3(0, h * 0.5 + 0.6, 0), Vector3(w + 0.6, 1.2, depth + 0.6), "wood/planks_dark", {"tile": 2.0, "tint": Color(0.5, 0.45, 0.45), "solid": false})
			var fx: float = side * (hw + 4.0) - side * 0.02
			for k in int(h / 3.2):
				var wy := 2.2 + k * 3.2
				if wy > h - 1.0:
					break
				Kit.sign(root, "props/window_lit" if rng.randf() < 0.4 else "props/window_night", Vector3(fx, wy, z - depth * 0.5 + rng.randf_range(-1.5, 1.5)), 90.0 if side > 0 else -90.0, Vector2(1.0, 1.3))
			z -= depth + 0.5
	# the street's furniture, half under water
	for zz in [26.0, 8.0, -20.0, -30.0]:
		var sx: float = -hw + 1.0 if int(zz) % 2 == 0 else hw - 1.0
		Props.place(root, "lantern_post_city", Vector3(sx, STREET_Y, zz), 0.0, 1.0, {"collision": "cylinder"})
		Kit.light(root, Vector3(sx, STREET_Y + 3.2, zz), LAMP, 1.0, 9.0)
	Props.place(root, "cart_broken", Vector3(3.0, STREET_Y, 20.0), 30.0, 1.0)
	Props.place(root, "banner_eye", Vector3(-hw - 3.9, 6.0, 26.0), -90.0, 1.0, {"collision": "none"})
	Props.place(root, "gargoyle", Vector3(hw + 3.6, 9.5, -22.0), -90.0, 1.0, {"collision": "none"})
	Readable.create(root, Vector3(-3.0, 0.6, 30.0), 0.0, "The street", [
		"A street of the Drowned City, ankle deep, then knee deep, then ankle deep again, as if it had not decided.",
		"The houses are the bone colour they always were. The water has been higher than this; it always has.",
	], {"name": "StreetLook", "size": Vector3(4.0, 1.4, 2.0), "note_key": "dream_street", "note_title": "The flooded street", "note_text": "The sixth square is a street of the Drowned City under water, with a wall across it high up, and someone very round sitting on the wall."})


# --- the wall, and the signs on it ---------------------------------------------------------

static func _wall(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var arch_w := 5.0
	var arch_h := 5.5
	var tex := "stone/blocks_city"
	var e := KD.HALF + 1.2
	# two piers and a lintel; walkable top
	for side in [-1.0, 1.0]:
		var x0 := arch_w * 0.5 if side > 0 else -e
		var x1 := e if side > 0 else -arch_w * 0.5
		Kit.box(root, Vector3((x0 + x1) * 0.5, WALL_H * 0.5, WALL_Z), Vector3(x1 - x0, WALL_H, WALL_T), tex, {"tile": 2.5, "tint": Color(0.92, 0.9, 0.88)})
	Kit.box(root, Vector3(0, (arch_h + WALL_H) * 0.5, WALL_Z), Vector3(arch_w + 0.2, WALL_H - arch_h, WALL_T), tex, {"tile": 2.5, "tint": Color(0.92, 0.9, 0.88)})
	Kit.arch(root, Vector3(0, STREET_Y, WALL_Z), 0.0, arch_w, arch_h, "stone/blocks_dark", {"depth": WALL_T + 0.4, "post": 0.4, "top": 0.4, "pointed": true})
	# a low parapet along the top's north side, and none on the south, which is the drop
	Kit.box(root, Vector3(0, WALL_H + 0.4, WALL_Z - WALL_T * 0.5 + 0.2), Vector3(e * 2.0, 0.8, 0.4), tex, {"tile": 2.5})
	Kit.light(root, Vector3(0, WALL_H + 2.5, WALL_Z), COLD, 1.3, 16.0)
	Kit.light(root, Vector3(0, arch_h - 1.0, WALL_Z), LAMP, 1.0, 8.0)
	# every sign you have read, nailed to the south face in a row, for him to explain
	var signs := [["signs/last_lamp", Vector2(1.6, 0.5)], ["signs/take_a_number", Vector2(1.2, 0.6)], ["signs/plaque_anteroom", Vector2(1.4, 0.7)], ["signs/five_half", Vector2(0.6, 0.6)], ["signs/exit_wrong", Vector2(1.0, 0.4)], ["signs/no_vacancy", Vector2(1.2, 0.6)], ["signs/king_asleep", Vector2(1.4, 0.7)], ["signs/halden_arms", Vector2(1.6, 0.6)]]
	for i in signs.size():
		var x := -14.0 + i * 4.0
		if absf(x) < 3.5:
			x += 4.0 * signf(x + 0.1)
		Kit.sign(root, signs[i][0], Vector3(x, 7.5 + (i % 2) * 1.6, WALL_Z + WALL_T * 0.5 + 0.03), 0.0, signs[i][1])
	Readable.create(root, Vector3(-8.0, 1.5, WALL_Z + WALL_T * 0.5 + 1.0), 0.0, "Look up at the signs", [
		"Every sign you have read, nailed to the wall in a row, too high to read. THE LAST LAMP. TAKE A NUMBER. WAIT HERE. 5½. NO VACANCY. THE KING IS ASLEEP.",
		"Above them, on the top of the wall, a round shape with its legs over the edge.",
	], {"name": "SignsLook", "size": Vector3(6.0, 2.5, 2.0), "note_key": "dream_signs", "note_title": "The signs on the wall", "note_text": "Every sign in the game is nailed to the south face of the wall in the sixth square. The round one on top explains them, and every explanation is wrong and perfect."})
	Props.place(root, "bone_pile", Vector3(-6.0, STREET_Y, WALL_Z + 3.5), 20.0, 1.0, {"collision": "none"})
	Puzzle.declare(area, "dream_wall", "dream_egg_fell", ["keepsake:wings"], "glide from the ruined tower to the top of the wall and speak to the one sitting on it")
	state.wall_top = WALL_H


# --- the tower to glide from ----------------------------------------------------------------

static func _tower(area: AreaBase, root: Node3D) -> void:
	var c := TOWER
	var s := 7.0
	var tex := "stone/blocks_city"
	var flights := 7
	var rise := TOWER_H / flights
	# four walls, the north-west corner open at the top for the leap
	for wl in [[Vector3(-s * 0.5, 0, s * 0.5), Vector3(-s * 0.5, 0, -s * 0.5)], [Vector3(s * 0.5, 0, -s * 0.5), Vector3(s * 0.5, 0, s * 0.5)], [Vector3(s * 0.5, 0, s * 0.5), Vector3(-s * 0.5, 0, s * 0.5)]]:
		Kit.wall(root, c + wl[0], c + wl[1], TOWER_H, tex, {"thick": 0.5, "tile": 2.5, "tint": Color(0.9, 0.88, 0.85)})
	# the north wall stops short of the top
	Kit.wall(root, c + Vector3(-s * 0.5, 0, -s * 0.5), c + Vector3(s * 0.5, 0, -s * 0.5), TOWER_H - 3.5, tex, {"thick": 0.5, "tile": 2.5, "tint": Color(0.9, 0.88, 0.85)})
	# the door at the south, at street level
	Kit.blocker(root, c + Vector3(0, 1.2, s * 0.5), Vector3(2.0, 2.4, 0.6), 0)
	Kit.box(root, c + Vector3(-2.2, 1.2, s * 0.5), Vector3(2.6, 2.4, 0.5), tex, {"tile": 2.5, "solid": false, "tint": Color(0.0, 0.0, 0.0, 0.0)})
	Kit.floor(root, c, Vector2(s, s), "stone/flagstone", {"tile": 1.5})
	# a hole in the south wall to get in by
	Kit.box(root, c + Vector3(0, 1.3, s * 0.5), Vector3(2.0, 2.6, 0.8), "", {"tint": Color(0.05, 0.05, 0.06), "solid": false, "unshaded": true})
	# flights up the inside, one along each wall in turn, landings at the corners
	var corners := [Vector3(-s * 0.5 + 0.8, 0, s * 0.5 - 0.8), Vector3(-s * 0.5 + 0.8, 0, -s * 0.5 + 0.8), Vector3(s * 0.5 - 0.8, 0, -s * 0.5 + 0.8), Vector3(s * 0.5 - 0.8, 0, s * 0.5 - 0.8)]
	for i in flights:
		var a: Vector3 = c + corners[i % 4] + Vector3(0, i * rise, 0)
		var b: Vector3 = c + corners[(i + 1) % 4] + Vector3(0, (i + 1) * rise, 0)
		var dd := b - a
		dd.y = 0.0
		var steps := 12
		Kit.stairs(root, a, Kit.dir_to_yaw(dd.normalized()), 1.4, steps, rise / steps, dd.length() / steps, "stone/flagstone", {"tile": 1.0, "name": "TowerFlight%d" % i})
		Kit.floor(root, a, Vector2(1.6, 1.6), "stone/flagstone", {"tile": 1.0})
		if i % 2 == 0:
			Kit.light(root, c + Vector3(0, i * rise + 2.0, 0), LAMP, 0.9, 8.0)
	# the top: a platform with the north-west corner open toward the wall
	var top: Vector3 = c + corners[flights % 4] + Vector3(0, TOWER_H, 0)
	Kit.floor(root, top, Vector2(1.6, 1.6), "stone/flagstone", {"tile": 1.0})
	Kit.floor(root, c + Vector3(0, TOWER_H, 0), Vector2(s, s), "stone/flagstone", {"tile": 1.5})
	Props.place(root, "bell_tower_frame", c + Vector3(0, TOWER_H, 0), 0.0, 0.8, {"collision": "none"})
	Kit.light(root, c + Vector3(0, TOWER_H + 3.0, 0), COLD, 1.2, 12.0)
	Readable.create(root, c + Vector3(0, TOWER_H, -2.0), 0.0, "Look out from the tower", [
		"From the top of the tower the wall is below you and ahead of you, and the round one on it has not looked up.",
		"It is not further than a fall, if you fall slowly, and you have something for falling slowly.",
	], {"name": "TowerLook", "size": Vector3(3.0, 1.5, 1.0)})
	Puzzle.declare(area, "dream_tower", "", [], "climb the ruined tower in the sixth square")


# --- the egg ---------------------------------------------------------------------------------

static func _egg(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var p := Vector3(0, WALL_H, WALL_Z + 0.4)
	var egg := Node3D.new()
	egg.name = "TheRoundOne"
	egg.position = p
	root.add_child(egg)
	Props.place(egg, "egg_large", Vector3.ZERO, 180.0, 1.9, {"collision": "none"})
	state.egg = egg
	var npc := NPC.create(root, p + Vector3(0, 0, -1.0), 180.0, "Someone very round", {"model": "none", "name": "RoundOne", "prompt": "Ask him what the signs mean", "face_player": false})
	npc.on_talk = func(_p: Node, n: NPC) -> bool:
		await _explain(area, state, n)
		return true
	state.npc = npc
	Kit.light(egg, Vector3(0, 3.0, 0), Color(1.0, 0.95, 0.85), 1.0, 8.0)
	# the landing on the wall counts as reaching him
	Kit.trigger(root, p + Vector3(0, 1.0, 0), Vector3(30.0, 4.0, WALL_T), func(_pl: Node) -> void:
		if not Game.has_flag("dream_wall_reached"):
			Game.set_flag("dream_wall_reached", true)
			Game.toast.emit("You are on the wall. He has not looked round. He is very sure of his balance."), {"name": "WallReached", "once": true})


## He explains a sign per visit. Then he falls. He always falls.
static func _explain(area: AreaBase, state: Dictionary, n: NPC) -> void:
	var k := Game.bump("dream_egg_explained")
	var lines: Array
	match k:
		1:
			lines = [
				"\"THE LAST LAMP,\" he says, without turning round. \"It means the lamp that came last. There was a first one, and the others, and then that. I chose the meaning. It does me very well.\"",
				"\"When I use a word,\" he says, \"it means just what I choose it to mean. The question is which is to be master. I pay them extra on Saturdays.\"",
			]
		2:
			lines = [
				"\"YOU ARE EARLY. WAIT HERE,\" he says. \"Early means late, in here. Wait means go. Here means the other place. You see how clear it is, once it is explained.\"",
				"\"TAKE A NUMBER means give one back. NO VACANCY means come in. THE KING IS ASLEEP means -\" he stops. \"That one means what it says. I could not make it mean anything else. I tried.\"",
			]
		_:
			lines = [
				"\"5½,\" he says. \"That means you. It has always meant you. It is the only word on the wall I did not have to pay.\"",
				"He leans back to look at the sky, which is a thing one should not do on a wall.",
			]
	if Game.active_is("crown"):
		lines.append("\"A crown,\" he says. \"That means a hat that is sorry about it.\"")
	await n.say(lines)
	Game.note("dream_egg", "The one on the wall", "Someone very round sits on the wall in the sixth square and explains every sign in the game. When he uses a word it means what he chooses it to mean; he pays them extra. 5½, he says, has always meant you. Then he falls. He always falls.")
	if k >= 2 and not state.fallen:
		_fall(area, state)


static func _fall(area: AreaBase, state: Dictionary) -> void:
	state.fallen = true
	Game.set_flag("dream_egg_fell", true)
	var egg: Node3D = state.egg
	var npc: NPC = state.npc
	if npc:
		npc.enabled = false
	Audio.sfx("wind_gust", egg.global_position, -4.0)
	var tw := egg.create_tween()
	tw.set_parallel(true)
	tw.tween_property(egg, "position", egg.position + Vector3(0, -WALL_H + 0.4, -WALL_T - 4.0), 1.5).set_ease(Tween.EASE_IN)
	tw.tween_property(egg, "rotation:x", -PI * 0.9, 1.5)
	tw.chain().tween_callback(func() -> void:
		_shatter(area, state))


static func _shatter(area: AreaBase, state: Dictionary) -> void:
	var egg: Node3D = state.egg
	var root: Node3D = egg.get_parent()
	var at := egg.position
	egg.queue_free()
	Audio.sfx("glass_break", root.to_global(at), -2.0)
	var rng := area.rng
	var shards := Node3D.new()
	shards.name = "Shards"
	shards.position = Vector3(at.x, STREET_Y, at.z)
	root.add_child(shards)
	for i in 9:
		var sp := Vector3(rng.randf_range(-2.5, 2.5), 0.1 + rng.randf_range(0.0, 0.4), rng.randf_range(-2.5, 2.5))
		var sh := Kit.box(shards, sp, Vector3(rng.randf_range(0.5, 1.2), 0.2, rng.randf_range(0.5, 1.0)), "", {"tint": BONE, "solid": false})
		sh.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0, TAU), rng.randf_range(-0.5, 0.5))
	Kit.box(shards, Vector3(0, 0.3, 0), Vector3(1.2, 0.5, 1.2), "", {"tint": Color(0.75, 0.25, 0.3), "solid": false})
	state.shards = shards
	Readable.create(shards, Vector3(0, 0.5, 0), 0.0, "Look at the pieces", [
		"Pieces, the colour of bone, and the sash. He has not said anything, which is the first time.",
		"Nobody heard it happen. Everybody comes anyway.",
	], {"name": "Pieces", "size": Vector3(4.0, 1.4, 4.0)})
	Game.toast.emit("He falls. He was always going to. Everything on the street, softly, hears it.")
	# the king's men, unhurried
	area.get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if not is_instance_valid(root):
			return
		_kings_men(area, root, shards.position, state))


static func _kings_men(area: AreaBase, root: Node3D, at: Vector3, state: Dictionary) -> void:
	Audio.sfx("stone_grind", root.to_global(at), -4.0)
	for i in 6:
		var a := i * 60.0 + 30.0
		var kp := at + Kit.polar(4.5, a)
		var knight := Props.place(root, "statue_knight_bone", kp, Kit.yaw_to_center(a), 1.0, {"collision": "cylinder"})
		state.knights.append(knight)
		if i % 2 == 0:
			Props.place(root, "statue_knight_bone", kp + Kit.polar(2.5, a), Kit.yaw_to_center(a), 1.0, {"collision": "cylinder", "tint": Color(0.9, 0.9, 0.85)})
	Kit.light(root, at + Vector3(0, 3.0, 0), Color(1.0, 0.7, 0.4), 1.0, 10.0)
	Readable.create(root, at + Vector3(0, 0.8, 4.0), 0.0, "All the king's men", [
		"They have come. They are the Ossuary's knights, bone under the armour, and they are unhurried, and they stand round the pieces the way people stand round a hole.",
		"They cannot put him together. They are not trying very hard. They were asked, and they came, and that is what horses and men are for.",
	], {"name": "KingsMen", "size": Vector3(6.0, 2.0, 2.0), "note_key": "dream_kings_men", "note_title": "All the king's men", "note_text": "After he fell, the Ossuary's bone knights came and stood round the pieces, unhurried. They cannot put him together. They were asked, and they came."})
	Game.toast.emit("All the king's horses and all the king's men. Unhurried. They stand round him.")
	area.rng.randf()


# --- the terrace, and the brook that runs backwards ------------------------------------------------

static func _terrace(area: AreaBase, root: Node3D, this_def: Dictionary, other_def: Dictionary) -> Dictionary:
	var y := WALL_H
	var z0 := WALL_Z - 6.0
	var z1 := WALL_Z + 1.5
	var cz := (z0 + z1) * 0.5
	var depth := z1 - z0
	# the wall's top widens into a terrace at its west end, hedged
	Kit.floor(root, Vector3((TERRACE_X - KD.HALF - 1.2) * 0.5, y, cz), Vector2(KD.HALF + 1.2 + TERRACE_X, depth), "nature/grass_dream", {"tint": this_def.tint, "tile": 2.0, "thick": 0.4})
	KD.hedge(root, Vector3(TERRACE_X, y, z0), Vector3(-KD.HALF - 1.2, y, z0), {"height": 2.4})
	KD.hedge(root, Vector3(-KD.HALF - 1.2, y, z1), Vector3(TERRACE_X, y, z1), {"height": 2.4})
	KD.hedge(root, Vector3(TERRACE_X - 0.6, y, z0), Vector3(TERRACE_X - 0.6, y, WALL_Z - 1.0), {"height": 2.4})
	KD.hedge(root, Vector3(TERRACE_X - 0.6, y, WALL_Z + 1.0), Vector3(TERRACE_X - 0.6, y, z1), {"height": 2.4})
	# the brook across the terrace, walking west
	var bx := -KD.BROOK
	Kit.floor(root, Vector3(bx, y + 0.03, cz), Vector2(KD.BROOK_W, depth), "ground/pebbles", {"tile": 1.0, "thick": 0.05})
	Kit.water(root, Vector3(bx, y + 0.16, cz), Vector2(KD.BROOK_W, depth), "nature/water_sea", {"tint": other_def.get("water", Color(0.8, 0.85, 1.0, 0.75)), "uv_scale": 0.5, "speed": 0.05, "swell": 0.02})
	Kit.floor(root, Vector3(bx - KD.BROOK_W * 0.5 - 1.3, y + 0.04, cz), Vector2(2.6, depth), String(other_def.ground), {"tint": other_def.get("tint", Color.WHITE), "tile": 2.0, "thick": 0.05})
	Kit.light(root, Vector3(bx, y + 3.0, cz), Color(1.0, 0.92, 0.8), 0.9, 10.0)
	Readable.create(root, Vector3(TERRACE_X - 2.0, y, cz + 2.5), 0.0, "A brook on a wall", [
		"A stream running along the top of the wall, in the grass, going west. There is no reason for it to be up here and it is.",
		"On its far side the grass is the garden's colour. You have been there. It is not there any more; it is here.",
	], {"name": "WallBrook", "size": Vector3(2.0, 1.2, 2.0), "note_key": "dream_wall_brook", "note_title": "The brook on the wall", "note_text": "At the west end of the wall's top there is a terrace with a brook across it, running back toward the garden. A brook that runs backwards leads to a square you have crossed, changed."})
	Puzzle.declare(area, "dream_wall_brook", "", ["keepsake:wings"], "walk the top of the wall to its west end, where a brook runs back to the garden")
	return {"pos": Vector3(bx, y, cz), "yaw": 90.0}


static func _lights(root: Node3D) -> void:
	Kit.light(root, Vector3(0, 4.0, 36.0), COLD, 1.0, 14.0)
	Kit.light(root, Vector3(0, 4.0, -36.0), COLD, 1.0, 14.0)
	Kit.light(root, Vector3(-14.0, 6.0, 0), Color(0.9, 0.85, 0.8), 0.9, 18.0)
	Kit.light(root, Vector3(14.0, 6.0, -20.0), Color(0.9, 0.85, 0.8), 0.9, 18.0)
	Kit.particles(root, Vector3(0, 1.0, 0), "fog", Vector3(10.0, 0.5, 40.0), 30)
	Kit.particles(root, Vector3(0, 3.0, 10.0), "rain", Vector3(12.0, 2.0, 30.0), 200)
