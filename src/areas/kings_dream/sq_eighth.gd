class_name KDEighth
extends RefCounted
## The eighth square. A rotunda that is the Anteroom, but the twelve doors are
## all open and all show static, and the room is, subtly, the mirrored one:
## the doors run the other way round and the plaque reads backwards. In it,
## besides the banquet: an empty hospital bed you know from somewhere, a
## chair beside it with a letter from M, and a chessboard on a table with a
## game nearly over. At the centre nothing is put on your head, and the
## banquet starts anyway: the candles grow, the food introduces itself,
## everything accelerates, and the Usher comes to the board. Then it is your
## move, and the two moves are ends: concede (the plug) or checkmate (the
## last rank). Doing nothing is allowed. The cloth is only the way back.
##
## Quotes the Anteroom, the Static, the Other Anteroom and the Workshop. The
## brook beyond the rotunda runs back to the wood.

const R := 13.0
const CENTRE := Vector3(0, 0, 0)
const DOOR_NAMES := ["forest", "city", "tavern", "house", "castle", "sea", "catacombs", "furnace", "cistern", "offices", "clocktower", "static"]
const CANDLE := Color(1.0, 0.85, 0.6)
const COLD := Color(0.6, 0.7, 1.0)


static func build(area: AreaBase, root: Node3D, ctx: Dictionary) -> Dictionary:
	var d: Dictionary = ctx.def
	var state := {"crowned": false, "candles": [], "turn": null, "lights": [], "t": 0.0, "speed": 0.0, "guests": [], "root": root, "dressed": false}
	Kit.floor(root, Vector3.ZERO, Vector2(KD.SQ, KD.SQ), String(d.ground), {"tint": d.tint, "tile": 2.0, "thick": 0.2})
	_approach(area, root)
	_rotunda(area, root, state)
	_banquet(area, root, state)
	_plinth(area, root)
	_bed(area, root)
	_board(area, root, state)
	var out := {}
	out["exit"] = {"pos": Vector3(0, 0, -5.3), "yaw": 0.0}
	# no vanishing Usher here: once the banquet begins he stands at the board
	out["on_process"] = func(delta: float) -> void:
		_tick(state, delta)
	return out


# --- the approach --------------------------------------------------------------------

static func _approach(area: AreaBase, root: Node3D) -> void:
	var tint := Color(1.0, 1.0, 1.05)
	Kit.floor(root, Vector3(0, 0.1, 26.0), Vector2(4.0, 24.0), "stone/marble_black", {"tint": tint, "tile": 1.5, "thick": 0.12})
	Kit.floor(root, Vector3(0, 0.1, -26.0), Vector2(4.0, 24.0), "stone/marble_black", {"tint": tint, "tile": 1.5, "thick": 0.12})
	# chess pieces stand along the way in, the ranks you have walked
	var rng := area.rng
	for i in 8:
		var z := 36.0 - i * 3.0
		var model: String = ["chess_pawn", "chess_pawn", "chess_knight", "chess_pawn", "chess_queen", "chess_pawn", "chess_knight", "chess_pawn"][i]
		var red := i % 2 == 1
		Props.place(root, model, Vector3(-4.0, 0, z), 90.0, 2.2, {"collision": "cylinder", "tint": Color(0.85, 0.2, 0.25) if red else Color(1, 1, 1)})
		Props.place(root, model, Vector3(4.0, 0, z), -90.0, 2.2, {"collision": "cylinder", "tint": Color(1, 1, 1) if red else Color(0.85, 0.2, 0.25)})
		if i % 3 == 0:
			Kit.light(root, Vector3(0, 3.5, z), COLD, 0.8, 9.0)
	Readable.create(root, Vector3(-3.0, 1.0, 30.0), 90.0, "Look at the pieces", [
		"Pawns, knights, a queen, in two colours, standing along the path in the order you met them. One pawn is missing from the white side.",
		"That is you. You have been walking. That is what pawns do, until the last rank.",
	], {"name": "PiecesLook", "size": Vector3(1.6, 2.6, 4.0), "note_key": "dream_pieces", "note_title": "The pieces", "note_text": "Chess pieces line the way into the eighth square, in the order you met them. One white pawn is missing. You have been walking, which is what pawns do, until the last rank."})
	for i in 5:
		Props.place(root, "cloud", Vector3(rng.randf_range(-30.0, 30.0), rng.randf_range(9.0, 16.0), rng.randf_range(-36.0, 36.0)), rng.randf_range(0, 360), 1.6, {"collision": "none"})
	Kit.light(root, Vector3(0, 4.0, 38.0), COLD, 1.0, 14.0)
	Kit.light(root, Vector3(0, 4.0, -38.0), COLD, 1.0, 14.0)


# --- the rotunda, mirrored -------------------------------------------------------------

static func _rotunda(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var c := CENTRE
	Kit.ring(root, c + Vector3(0, 0.12, 0), 0.0, R + 1.0, 36, "stone/blocks_nexus")
	Kit.ring(root, c + Vector3(0, 0.14, 0), 3.2, 4.6, 36, "stone/marble_black", {"solid": false})
	Kit.ring(root, c + Vector3(0, 0.12, 0), R + 1.0, R + 3.0, 36, "stone/marble_black", {"tint": Color(0.8, 0.8, 0.9)})
	# the wall, with the way in at the south and the way out at the north
	Kit.round_wall(root, c, R, 9.0, 36, "stone/blocks_nexus", {"gaps": [[90.0, 16.0], [270.0, 16.0]]})
	Kit.ring(root, c + Vector3(0, 9.0, 0), 5.0, R + 1.0, 36, "stone/blocks_nexus", {"down": true})
	Kit.ring(root, c + Vector3(0, 9.0, 0), 4.6, 5.4, 36, "metal/brass", {"solid": false})
	# the rune ring, the wrong way round
	var q := QuadMesh.new()
	q.size = Vector2(9.0, 9.0)
	Kit.add_mesh(root, q, Kit.mat("props/rune_ring_floor", {"unshaded": false}), c + Vector3(0, 0.15, 0), {"solid": false, "rotation": Vector3(-90, 0, 180)})
	# no well: the place it stood is where the crown is put on
	Kit.ring(root, c + Vector3(0, 0.17, 0), 0.0, 1.4, 16, "stone/marble_white", {"solid": false})
	Kit.light(root, c + Vector3(0, 2.5, 0), Color(0.5, 0.6, 1.0), 1.2, 9.0)
	# the plaque, mirrored
	Kit.box(root, c + Vector3(-6.0, 0.5, -2.2), Vector3(1.2, 1.0, 0.4), "stone/blocks_nexus")
	Readable.create(root, c + Vector3(-6.0, 1.05, -2.0), 0.0, "Read the plaque", [
		".EREH TIAW .YLRAE ERA UOY",
		"It is the plaque. It is the other plaque. Under it, scratched, backwards: the doors are the waiting. Under that, forwards, new: they were.",
	], {"name": "Plaque", "sign": "signs/plaque_mirror", "sign_size": Vector2(1.0, 0.5), "size": Vector3(1.2, 0.6, 0.2), "note_key": "dream_plaque_mirror", "note_title": "The plaque at the end", "note_text": "The rotunda at the eighth square is the Anteroom, and subtly the mirrored one: the plaque reads backwards and the doors run the other way round. All twelve are open and all twelve show static."})
	# pillars and cold lanterns
	for i in 12:
		var a := i * 30.0
		if absf(wrapf(a - 90.0, -180.0, 180.0)) < 20.0 or absf(wrapf(a - 270.0, -180.0, 180.0)) < 20.0:
			continue    # nothing stands in the way in or the way out
		Props.place(root, "pillar_nexus", c + Kit.polar(R - 1.6, a), 0.0, 1.0, {"collision": "cylinder"})
		Props.place(root, "lantern_hanging_cold", c + Kit.polar(R - 4.0, a, 6.5), 0.0, 1.0, {"collision": "none"})
		var l := Kit.light(root, c + Kit.polar(R - 4.0, a, 5.6), Color(0.6, 0.85, 0.85), 0.55, 7.0)
		state.lights.append(l)
	# the twelve doors, in the mirrored order, each an arch full of static
	for i in DOOR_NAMES.size():
		var a := 255.0 - i * 30.0     # the Anteroom goes the other way; the doors sit between the ways in and out
		for gap in [90.0, 270.0]:
			var off := wrapf(a - gap, -180.0, 180.0)
			if absf(off) < 18.0:
				a += 7.0 * signf(off)     # and their names clear of the openings
		var id: String = DOOR_NAMES[i]
		var yaw := Kit.yaw_to_center(a)
		Kit.arch(root, c + Kit.polar(R - 0.9, a), yaw, 1.5, 2.8, "stone/blocks_nexus", {"depth": 0.7, "post": 0.45, "top": 0.5, "pointed": true})
		var sq := QuadMesh.new()
		sq.size = Vector2(1.5, 2.8)
		var door := Node3D.new()
		door.name = "StaticDoor_" + id
		door.position = c + Kit.polar(R - 0.7, a)
		door.rotation.y = deg_to_rad(yaw)
		root.add_child(door)
		Kit.add_mesh(door, sq, Kit.static_mat({"brightness": 0.9}), Vector3(0, 1.4, 0), {"solid": false, "rotation": Vector3(0, 180, 0)})
		Kit.label(root, World.area_name(id), c + Kit.polar(R - 1.35, a, 3.7), yaw, 26, Color(0.85, 0.8, 0.65), "display", {"pixel_size": 0.014})
		Kit.light(root, c + Kit.polar(R - 2.2, a, 3.2), Color(0.8, 0.8, 0.8), 0.7, 6.0)
		if i % 3 == 0:
			Props.place(root, "tv_crt", c + Kit.polar(R - 2.4, a + 9.0, 0.12), yaw + 30.0, 0.9, {"collision": "box"})
		Interactable.make(root, c + Kit.polar(R - 1.0, a), Vector3(1.6, 2.8, 0.9), "Step into the static", func(_p: Node, _it: Node) -> void:
			Game.toast.emit("Every door out of the King's dream is the same door, and it is between channels.")
			Audio.sfx("static_burst", null, -4.0)
			World.fall_out(), {"name": "Static_" + id, "yaw": yaw, "offset": Vector3(0, 1.4, 0)})
	Readable.create(root, c + Kit.polar(R - 2.6, 0.0), Kit.yaw_to_center(0.0), "Look at the doors", [
		"Twelve doors and every one of them open, and behind every one of them the grey and the hiss.",
		"They are in the wrong order. The Hollow Wood is where the Static should be. You have stood in a room like this from the other side of a mirror.",
	], {"name": "DoorsLook", "size": Vector3(2.0, 2.6, 2.0)})
	Kit.particles(root, c + Vector3(0, 3, 0), "motes", Vector3(10, 3, 10), 70)
	for k in 6:
		var orb := Clockwork.create(root, c + Vector3(0, 5.0 + k * 0.5, 0), {"mode": "rotate", "axis": Vector3.UP, "speed_deg": 6.0 + k * 2.0, "name": "Orb%d" % k})
		Props.place(orb.body, "orb", Kit.polar(6.0 + k * 0.8, k * 60.0), 0.0, 0.6, {"collision": "none"})
	# the centre, where the well should be: nothing is put on your head, and
	# the banquet starts anyway
	Kit.trigger(root, c + Vector3(0, 1.0, 0), Vector3(3.0, 3.0, 3.0), func(_p: Node) -> void:
		_centre(area, state), {"name": "CentreSpot", "once": true})
	Puzzle.declare(area, "dream_centre", "dream_banquet_begun", [], "stand where the well should be, at the centre of the last square")


static func _centre(area: AreaBase, state: Dictionary) -> void:
	if state.crowned:
		return
	state.crowned = true
	Audio.sfx("clock_chime", null, -4.0)
	if World.hud:
		await World.hud.say("", [
			"This is where the well should be, and where something should be put on your head. Nothing is. Nobody is here to do it.",
			"The doors round the room hiss, very quietly, the way a television does in another flat. Behind you, the table has laid itself.",
		])
	Game.set_flag("dream_banquet_begun", true)
	Game.note("dream_eighth", "The eighth square", "At the centre of the last square, where the Anteroom's well should be, nothing was put on your head. The banquet started anyway, and went faster and faster until there was nothing to do but take hold of the cloth and pull.")
	Game.toast.emit("Nothing is put on your head. The banquet does not mind.")
	_start_banquet(area, state)


# --- the banquet -----------------------------------------------------------------------

static func _banquet(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var c := CENTRE
	# a long table across the north half of the rotunda, laid for pieces
	var tp := c + Vector3(0, 0, -7.0)
	Props.place(root, "table_feast", tp, 90.0, 1.4, {"collision": "box"})
	Kit.box(root, tp + Vector3(0, 0.95, 0), Vector3(9.4, 0.06, 2.6), "fabric/sheet", {"tint": Color(1.0, 0.98, 0.94), "solid": false, "tile": 1.5})
	# the cloth hangs over the south edge, which is the thing to pull
	Kit.box(root, tp + Vector3(0, 0.55, 1.35), Vector3(9.4, 0.8, 0.06), "fabric/sheet", {"tint": Color(0.98, 0.96, 0.92), "solid": false, "tile": 1.5})
	# guests: pieces, and the White Queen asleep at the head
	var guests := [["chess_pawn", -3.6, false], ["chess_knight", -1.2, true], ["chess_pawn", 1.2, false], ["chess_knight", 3.6, true]]
	for g in guests:
		var x := float(g[1])
		var red: bool = g[2]
		Props.place(root, "chair_white", tp + Vector3(x, 0, -2.6), 180.0, 1.0, {"collision": "box"})
		var piece := Props.place(root, String(g[0]), tp + Vector3(x, 0.0, -2.5), 180.0, 1.6, {"collision": "none", "tint": Color(0.85, 0.2, 0.25) if red else Color(1, 1, 1)})
		state.guests.append(piece)
	Props.place(root, "chair_white", tp + Vector3(-6.2, 0, 0), -90.0, 1.2, {"collision": "box"})
	Props.place(root, "chess_queen", tp + Vector3(-6.0, 0, 0), -90.0, 1.9, {"collision": "cylinder", "tint": Color(1, 1, 1)})
	Readable.create(root, tp + Vector3(-6.0, 1.2, 0), -90.0, "The White Queen", [
		"Asleep at the head of the table, upright, the way only a piece can sleep.",
		"She snores in a very small voice. \"...jam tomorrow,\" she says. \"...never jam today.\"",
	], {"name": "WhiteQueen", "size": Vector3(1.4, 2.4, 1.4)})
	# the dishes, on a slow lazy susan that will not stay slow
	var turn := Clockwork.create(root, tp + Vector3(0.6, 1.0, 0), {"mode": "rotate", "axis": Vector3.UP, "speed_deg": 6.0, "name": "Susan"})
	state.turn = turn
	Kit.ring(turn.body, Vector3.ZERO, 0.0, 1.1, 12, "stone/marble_white", {"solid": false})
	var dishes := [["mug", "the pudding"], ["bottle", "the wine"], ["shell", "the mutton"], ["mushroom_red", "the mushroom"], ["item_biscuit", "the biscuit"], ["teacup_stack", "the tea"]]
	for i in dishes.size():
		var a := i * 60.0
		Props.place(turn.body, String(dishes[i][0]), Kit.polar(0.75, a, 0.02), a, 1.2, {"collision": "none"})
	Readable.create(root, tp + Vector3(0.6, 1.3, 1.0), 0.0, "Be introduced to the food", [
		"\"Allow me to introduce you,\" says the mutton. \"Pudding: the guest. The guest: pudding.\" It does not use your name. It does not have it. The pudding does not mind.",
		"It is not etiquette to cut anyone you have been introduced to. The knife in your pocket, if you have it, agrees.",
	], {"name": "FoodLook", "size": Vector3(2.8, 1.4, 1.4), "note_key": "dream_food", "note_title": "The food introduces itself", "note_text": "At the banquet in the eighth square the mutton introduces you to the pudding. It is not etiquette to cut anyone you have been introduced to."})
	# candles that will grow to the ceiling
	for x in [-3.0, -1.0, 2.2, 4.0]:
		var cn := Props.place(root, "candle_tall", tp + Vector3(x, 1.0, 0.7), 0.0, 1.0, {"collision": "none"})
		state.candles.append(cn)
		Kit.light(root, tp + Vector3(x, 1.8, 0.7), CANDLE, 0.7, 5.0)
	Kit.light(root, tp + Vector3(0, 4.0, 0), CANDLE, 1.2, 12.0)
	Readable.create(root, tp + Vector3(3.0, 0.5, 1.6), 0.0, "Look at the table", [
		"A table laid for a coronation, for pieces. Nobody has told you where to sit and every place is yours.",
		"The cloth hangs over the edge nearest you. It is the only thing in the room that looks like it would come away if pulled.",
	], {"name": "TableLook", "size": Vector3(2.0, 1.2, 1.0)})
	if Game.has_flag("dream_banquet_begun"):
		_dress_banquet(state)


## Once the banquet has begun: the Usher comes to the board, the closest he
## has ever stood, and stands across it from your chair.
static func _dress_banquet(state: Dictionary) -> void:
	if state.dressed:
		return
	state.dressed = true
	var root: Node3D = state.root
	if root == null or not is_instance_valid(root):
		return
	var ct := BOARD
	Props.place(root, "usher", ct + Vector3(0, 0, -1.9), 180.0, 1.0, {"collision": "none", "name": "UsherAtBoard"})
	Kit.light(root, ct + Vector3(0, 2.8, -1.6), COLD, 0.6, 5.0)
	Readable.create(root, ct + Vector3(0, 1.4, -1.9), 180.0, "The Usher", [
		"Across the board, at last, near enough to see. A coat, a hat, and under the hat a face you know from the mirror in the flat.",
		"He is not pointing at you. He is pointing at the pawn on the seventh, and then, without hurry, at the bed.",
	], {"name": "UsherLook", "size": Vector3(1.4, 2.8, 1.2), "note_key": "usher_board", "note_title": "The Usher at the board", "note_text": "Once the banquet began the Usher came and stood across the board from your chair, the closest he has ever been, with your face. He pointed at the pawn on the seventh rank, and at the bed."})


# --- the bed, and the letter ---------------------------------------------------------------

const BED := Vector3(-7.0, 0, 3.6)
const BOARD := Vector3(6.6, 0, 2.0)

## An empty hospital bed, made up, that is the most familiar thing in the
## room; a monitor beside it showing static, with a cable to a socket on the
## pillar; and a chair by it with a letter from M.
static func _bed(area: AreaBase, root: Node3D) -> void:
	var b := BED
	Props.place(root, "bed_iron", b, 90.0, 1.0)
	# the drip stand at the foot, the monitor on its post at the head
	Kit.cylinder(root, b + Vector3(1.2, 0, 0.9), 0.03, 1.9, "metal/brass", {"segments": 6})
	Kit.box(root, b + Vector3(1.2, 1.75, 0.9), Vector3(0.18, 0.3, 0.1), "fabric/sheet", {"solid": false, "tint": Color(0.9, 0.95, 1.0)})
	Kit.cylinder(root, b + Vector3(1.2, 0.02, 0.9), 0.3, 0.04, "metal/plate", {"segments": 8, "solid": false})
	var post := b + Vector3(-0.6, 0, -1.1)
	Kit.cylinder(root, post, 0.04, 1.1, "metal/iron", {"segments": 6, "tint": Color(0.5, 0.5, 0.55)})
	Kit.cylinder(root, post + Vector3(0, 0.02, 0), 0.3, 0.04, "metal/plate", {"segments": 8, "solid": false})
	var tv := Props.place(root, "tv_crt", post + Vector3(0, 1.1, 0), 180.0, 0.55, {"collision": "none"})
	var screen := Props.part(tv, "Screen")
	if screen is MeshInstance3D:
		(screen as MeshInstance3D).set_surface_override_material(0, Kit.static_mat({"brightness": 0.8, "scale": 100.0}))
	Kit.light(root, post + Vector3(0, 1.8, 0.6), Color(0.8, 0.85, 1.0), 0.7, 5.0)
	Kit.light(root, b + Vector3(0, 3.0, 0), Color(0.9, 0.92, 1.0), 0.8, 7.0)
	# the socket on the pillar behind the bed, and the cable to it
	var a := 165.0
	var socket := CENTRE + Kit.polar(R - 2.2, a, 0.5)
	Kit.box(root, socket, Vector3(0.5, 0.5, 0.12), "metal/plate", {"solid": false, "tint": Color(0.55, 0.55, 0.6), "rotation": Vector3(0, 90.0 - a, 0)})
	Kit.box(root, socket + Kit.polar(-0.08, a), Vector3(0.2, 0.2, 0.1), "metal/iron", {"solid": false, "tint": Color(0.15, 0.15, 0.17), "rotation": Vector3(0, 90.0 - a, 0)})
	Kit.light(root, socket + Kit.polar(-1.2, a, 0.6), COLD, 0.5, 4.0)
	var pts := [post + Vector3(0, 0.05, 0), Vector3(-9.4, 0.05, 2.7), socket + Kit.polar(-0.16, a)]
	for k in pts.size() - 1:
		_cable(root, pts[k], pts[k + 1])
	Readable.create(root, socket + Kit.polar(-0.6, a), Kit.yaw_to_center(a), "The socket", [
		"A socket on the pillar behind the bed, and the cable from the monitor in it, and the cable warm.",
		"Everything in the room that hisses is on the other end of it.",
	], {"name": "SocketLook", "size": Vector3(1.0, 1.0, 1.0)})
	Readable.create(root, b + Vector3(0, 0.9, 0), 90.0, "The bed", [
		"An iron bed with hospital corners, made up and empty, a dent in the pillow the shape of a head. It is the most familiar thing in the room and you could not say from where.",
		"The monitor beside it shows static. The cable from it runs to the wall. Nobody is in the bed, and it does not feel like nobody.",
	], {"name": "BedLook", "size": Vector3(2.6, 1.4, 1.6), "note_key": "dream_bed", "note_title": "The empty bed", "note_text": "In the rotunda at the end of the dream stands an empty hospital bed you know from somewhere, a dent in the pillow, a monitor beside it showing static, and a cable from the monitor to the wall. A chair by it has a letter on the seat, signed M."})
	# the chair, and the letter on it
	var ch := b + Vector3(0.4, 0, -1.9)
	Props.place(root, "chair", ch, 180.0, 1.0)
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	Kit.add_mesh(root, q, Kit.mat("signs/note_m", {"double": true}), ch + Vector3(0, 0.49, 0.05), {"solid": false, "rotation": Vector3(-90, 0, 0)})
	Readable.create(root, ch + Vector3(0, 0.7, 0), 0.0, "A letter on the chair", [
		"A folded page on the seat, in a hand you know from a note in a house and from the tiles of a shower. It is not addressed.",
		"\"I sat here again today. I read to you; you did not hear, or you did and it was a garden. The roses are from the book you liked. I have stopped asking them how long. Whatever you decide, I was here.\"",
		"It is signed with one letter: M.",
	], {"name": "LetterM", "size": Vector3(1.0, 1.0, 1.0), "note_key": "letter_m", "note_title": "The letter from M", "note_text": "On the chair by the empty bed at the end of the dream, a letter, signed M: I sat here again today. I read to you. The roses are from the book you liked. Whatever you decide, I was here."})
	area.rng.randf()


# --- the board -----------------------------------------------------------------------------

const WHITE := "stone/marble_white"
const BLACK := "stone/marble_black"
const IVORY := Color(0.95, 0.93, 0.85)
const RED := Color(0.85, 0.2, 0.25)

## A chessboard the size of a table, with a game nearly over on it: your pawn
## on the seventh, his king in the corner. Your chair on the south side.
static func _board(area: AreaBase, root: Node3D, state: Dictionary) -> void:
	var ct := BOARD
	Kit.box(root, ct + Vector3(0, 0.86, 0), Vector3(3.2, 0.08, 2.6), "wood/planks_dark", {"tile": 1.0})
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Kit.box(root, ct + Vector3(sx * 1.45, 0.41, sz * 1.15), Vector3(0.12, 0.82, 0.12), "wood/planks_dark", {"solid": false})
	Kit.box(root, ct + Vector3(0, 0.905, 0), Vector3(2.02, 0.03, 2.02), "wood/planks_dark", {"solid": false, "tint": Color(0.6, 0.55, 0.5)})
	var sq := 0.24
	for f in 8:
		for r in 8:
			var p := ct + Vector3((f - 3.5) * sq, 0.93, (3.5 - r) * sq)
			Kit.box(root, p, Vector3(sq, 0.02, sq), WHITE if (f + r) % 2 == 1 else BLACK, {"solid": false, "faces": ["py"], "tile": sq})
	# file a is the west, rank 1 is your side
	var at := func(file: int, rank: int) -> Vector3:
		return ct + Vector3((file - 3.5) * sq, 0.94, (3.5 - (rank - 1)) * sq)
	# mate in one for the pawn: the white king on g6 and the pawn on f7, the red
	# king on h8 with nowhere to go once the pawn is a queen on f8
	var pieces := [["chess_pawn", 5, 7, false], ["chess_king", 6, 6, false], ["chess_king", 7, 8, true], ["chess_pawn", 7, 6, true]]
	for pc in pieces:
		var model := String(pc[0])
		if not Props.exists(model):
			model = "chess_pawn"
		Props.place(root, model, at.call(int(pc[1]), int(pc[2])), 0.0 if not pc[3] else 180.0, 0.34, {"collision": "none", "tint": RED if pc[3] else IVORY})
	# the taken pieces, lying on the table's margin beside the board
	for k in 5:
		var sx := -1.0 if k < 3 else 1.0
		var zz := -0.7 + (k % 3) * 0.55
		Props.place(root, ["chess_pawn", "chess_knight", "chess_queen", "chess_pawn", "chess_knight"][k], ct + Vector3(sx * 1.32, 0.95, zz), 90.0 + k * 40.0, 0.28, {"collision": "none", "tint": IVORY if k % 2 == 0 else RED, "rotation": Vector3(90, 90.0 + k * 40.0, 0)})
	Kit.light(root, ct + Vector3(0, 2.6, 0), Color(1.0, 0.95, 0.85), 1.0, 7.0)
	Props.place(root, "chair", ct + Vector3(0, 0, 1.75), 0.0, 1.0)
	Interactable.make(root, ct + Vector3(0, 1.1, 0), Vector3(2.5, 1.2, 2.5), "The board", func(_p: Node, _it: Node) -> void:
		_on_board(state), {"name": "Board"})
	Puzzle.declare(area, "dream_board", "", ["flag:dream_banquet_begun"], "once the banquet has begun, sit at the board: it is your move")


## Your move. "Do nothing" comes first and is selected, so nothing is chosen
## by accident; the other two say they are ends and ask again.
static func _on_board(state: Dictionary) -> void:
	if World.hud == null:
		return
	if not Game.has_flag("dream_banquet_begun"):
		await World.hud.say("", [
			"A board on a table, and a game on it nearly over: your pawn on the seventh, your king beside it, his king in the corner with one pawn left to it, and the taken pieces lying along the edge.",
			"It is not your move. Not yet. The chair on your side has been pulled out.",
		])
		Game.note("dream_board", "The board", "In the rotunda at the end of the dream, a chessboard on a table with a game nearly over: your pawn on the seventh rank, the red king in the corner. A chair pulled out on your side.")
		return
	var i: int = await World.hud.ask("", "Your move, and it is the last one either way. The king in the corner is you, the way the ward sees you: still, in a bed, with nowhere to go. Checkmate is the pawn to the eighth, and it leaves him exactly there, with nowhere to go, for good: it is coming to terms with it. Conceding is laying the king down, and the plug that goes with it is yours. Neither can be taken back, and the board says so. Doing nothing is allowed.", [
		"Do nothing. Leave the board as it is.",
		"Concede. Lay the king down, and pull the plug on yourself. (an ending)",
		"Checkmate. Trap the king where he lies, and come to terms with it. (an ending)",
	])
	if i != 1 and i != 2:
		return
	var y: int = await World.hud.ask("", "There is no coming back from this one. Are you sure?", ["No.", "Yes."])
	if y != 1:
		return
	state.speed = 0.0
	if i == 1:
		Game.set_flag("plug_pulled", true)
		Game.note("plug", "Concede", "At the board at the end of the dream you laid the king down, which is you, in the bed, and the plug that goes with him is yours to pull. The monitor by the empty bed went to a dot.")
		World.travel("static_end", "from_banquet", {"color": Color.WHITE, "duration": 1.8})
	else:
		Game.set_flag("promotion_taken", true)
		Game.note("promotion", "Checkmate", "At the board at the end of the dream you took the pawn to the eighth rank and mated the king, who is you, in the bed, as the ward sees you: nowhere to go, and staying there. The promotion is coming to terms with that.")
		World.travel("promotion", "from_banquet", {"color": Color(0.1, 0.06, 0.14), "duration": 1.8})


## A straight run of cable between two points, in the square's own space
## (the square sits hundreds of metres from the world origin, so no global
## look-at here).
static func _cable(root: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var seg := Kit.cylinder(root, Vector3.ZERO, 0.06, d.length(), "metal/iron", {"solid": false, "segments": 6, "tint": Color(0.3, 0.3, 0.33)})
	var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
	seg.transform = Transform3D(Basis.looking_at(d.normalized(), up) * Basis(Vector3.RIGHT, PI * 0.5), (a + b) * 0.5)


static func _start_banquet(_area: AreaBase, state: Dictionary) -> void:
	state.speed = 1.0
	_dress_banquet(state)
	for cn in state.candles:
		var n: Node3D = cn
		if is_instance_valid(n):
			var tw := n.create_tween()
			tw.tween_property(n, "scale", Vector3(1.0, 9.0, 1.0), 40.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Game.toast.emit("The candles begin to grow. The dishes begin to turn faster. Everything, kindly, begins to hurry.")


## Everything accelerates, once you are crowned, until you pull.
static func _tick(state: Dictionary, delta: float) -> void:
	if Game.time_frozen or state.speed <= 0.0:
		return
	state.t += delta
	state.speed = minf(state.speed + delta * 0.12, 8.0)
	var turn: Clockwork = state.turn
	if turn != null and is_instance_valid(turn):
		turn.speed_deg = 6.0 * state.speed * state.speed
	var flick := 0.55 + 0.35 * sin(state.t * state.speed * 2.0)
	for l in state.lights:
		var ol: OmniLight3D = l
		if is_instance_valid(ol):
			ol.light_energy = flick
	for g in state.guests:
		var n: Node3D = g
		if is_instance_valid(n):
			n.position.y = absf(sin(state.t * state.speed)) * 0.08 * state.speed
	if fmod(state.t, 3.0) < delta:
		Audio.set_ambience_pitch(1.0 + 0.06 * state.speed)


# --- the plinth, from the Workshop ------------------------------------------------------

static func _plinth(area: AreaBase, root: Node3D) -> void:
	var p := CENTRE + Vector3(8.0, 0, 6.0)
	Kit.box(root, p + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0), "stone/marble_white", {"tile": 1.0})
	Kit.light(root, p + Vector3(0, 2.2, 0), Color(1.0, 0.95, 0.85), 0.8, 5.0)
	Kit.label(root, "the occupant of 5½", p + Vector3(0, 0.6, 0.52), 0.0, 14, Color(0.3, 0.28, 0.25), "body", {"pixel_size": 0.008, "outline": 0})
	Readable.create(root, p + Vector3(0, 1.1, 0), 0.0, "Read the plate on the plinth", [
		"A plinth like the ones in the room where the props are kept. Nothing on it. A plate on the front, in brass: THE OCCUPANT OF 5½.",
		"Every other plinth in that room has something on it. This one is waiting for you to stand still long enough.",
	], {"name": "Plinth", "size": Vector3(1.2, 1.6, 1.2), "note_key": "dream_plinth", "note_title": "The empty plinth", "note_text": "At the banquet stands one plinth from the Workshop with nothing on it. The name plate says the occupant of 5½. It is waiting for you to stand still."})
	area.rng.randf()
