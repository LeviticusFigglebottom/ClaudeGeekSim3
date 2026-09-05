extends AreaBase
## The Last Rank — where the promotion goes. A pawn that reaches the last
## rank becomes whatever it is told to be. This is the board from the King's
## dream with the corruption showing through: squares missing, squares of
## static, pieces standing in for people. One rank of eight squares, from the
## first breath to the last, walked in order, and at the far end a square
## with nothing on it, which is where you stand if you stay.
##
## Falling off the board lands in the Static, as everywhere. No route needs
## a fall. Holding R wakes you, and should feel like cheating.

const SQ := 14.0
const RANK := 8
const FILES := 3            # files of board either side of the rank
const WORDS := ["BORN", "SMALL", "TAUGHT", "KEPT", "LOVED", "HOME", "KEPT AGAIN", ""]
const WHITE := "stone/marble_white"
const BLACK := "stone/marble_black"
const WARM := Color(1.0, 0.9, 0.75)
const COLD := Color(0.8, 0.8, 1.0)
const RED := Color(0.75, 0.2, 0.2)
const IVORY := Color(0.95, 0.93, 0.85)


func build() -> void:
	can_wake = true
	Realm.apply(self, "promotion", {"sky_opts": {"band_strength": 0.06, "band_speed": 0.2}})
	_board()
	_fences()
	for i in RANK:
		_station(i)
	add_spawn("from_banquet", Vector3(0, 0.1, 5.5), 0.0)
	add_spawn("default", Vector3(0, 0.1, 5.5), 0.0)
	Kit.particles(self, Vector3(0, 3, -50), "motes", Vector3(12, 3, 60), 60)
	Usher.spawn(self, Vector3(3.0, 0, -7.0 * SQ - 2.0), {"appear_delay": 4.0, "radius": 80.0})
	Puzzle.declare(self, "last_rank", "ending_limbo", [], "walk the rank from the first square to the eighth and stand on the last")


# --- the board ------------------------------------------------------------------------------

func _sq_centre(i: int) -> Vector3:
	return Vector3(0, 0, -i * SQ)


## Tiles on either side of the rank, some missing, some static: the board is
## being forgotten from the edges in.
func _board() -> void:
	for f in range(-FILES, FILES + 1):
		for r in range(-1, RANK + 1):
			var c := Vector3(f * SQ, 0, -r * SQ)
			var on_rank := f == 0 and r >= 0 and r < RANK
			var h := hash(Vector2i(f, r)) ^ Game.run_seed
			var tex := WHITE if (f + r) % 2 == 0 else BLACK
			if not on_rank:
				var roll := (h % 100)
				var edge := absi(f) + (1 if r < 0 or r >= RANK else 0)
				if roll < 18 * edge:
					continue    # a square that is not there any more
				if roll % 7 == 3:
					Kit.floor(self, c, Vector2(SQ, SQ), "common/static", {"mat": Kit.static_mat({"brightness": 0.35, "scale": 60.0, "tint": Color(0.8, 0.8, 0.9)}), "thick": 0.4, "surface": "metal"})
					continue
			Kit.floor(self, c, Vector2(SQ, SQ), tex, {"tile": 2.0, "thick": 0.4, "tint": Color(1.0, 1.0, 1.0) if on_rank else Color(0.8, 0.78, 0.82)})
			if on_rank and r < RANK - 1:
				Kit.label(self, WORDS[r], c + Vector3(0, 0.03, SQ * 0.5 - 1.6), 0.0, 36, Color(0.55, 0.5, 0.6) if tex == WHITE else Color(0.5, 0.48, 0.55), "display", {"pixel_size": 0.018, "outline": 0, "flat": true})
	# the pieces that got knocked off, lying on the edge squares
	for k in 9:
		var p := Vector3((-FILES + (k % (FILES * 2 + 1))) * SQ + 2.0, 0, -(k * 1.7) * SQ * 0.5)
		if absf(p.x) < SQ * 0.5 + 1.0:
			continue
		var piece := Props.place(self, ["chess_pawn", "chess_knight", "chess_queen"][k % 3], p + Vector3(0, 0.5, 0), k * 40.0, 2.2, {"collision": "none", "tint": IVORY if k % 2 == 0 else RED, "rotation": Vector3(90, k * 40.0, 0)})
		if k % 3 == 1:
			_corrupt(piece)


## Pawns the size of houses line both sides of the rank, and walls you cannot
## see stand above them: a piece keeps to its file.
func _fences() -> void:
	var z0 := SQ * 0.5 + 1.0
	var z1 := -(RANK - 0.5) * SQ - 1.0
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * (SQ * 0.5 + 2.2)
		var z := z0 - 3.5
		var k := 0
		while z > z1:
			var pawn := Props.place(self, "chess_pawn", Vector3(x, 0, z), 0.0, 4.5 + (k % 3) * 0.6, {"collision": "cylinder", "tint": IVORY if k % 2 == 0 else RED})
			if k % 5 == 2:
				_corrupt(pawn)
			z -= 7.0
			k += 1
		Kit.blocker(self, Vector3(sx * (SQ * 0.5 + 0.5), 3.0, (z0 + z1) * 0.5), Vector3(1.0, 6.0, z0 - z1))
	Kit.blocker(self, Vector3(0, 3.0, z0 + 0.5), Vector3(SQ + 2.0, 6.0, 1.0))
	Kit.blocker(self, Vector3(0, 3.0, z1 - 0.5), Vector3(SQ + 2.0, 6.0, 1.0))
	# behind the first square, the rank you came from, painted out
	Kit.box(self, Vector3(0, 2.5, z0 + 2.0), Vector3(SQ + 4.0, 5.0, 0.6), "common/static", {"mat": Kit.static_mat({"brightness": 0.25, "scale": 80.0}), "solid": false})


## Static over every face of a thing: a piece the board is forgetting.
func _corrupt(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = Kit.static_mat({"brightness": 0.55, "scale": 40.0, "tint": Color(0.9, 0.9, 1.0)})
	for c in node.get_children():
		_corrupt(c)


# --- the stations ---------------------------------------------------------------------------

func _station(i: int) -> void:
	var c := _sq_centre(i)
	match i:
		0: _born(c)
		1: _small(c)
		2: _taught(c)
		3: _kept(c)
		4: _loved(c)
		5: _home(c)
		6: _kept_again(c)
		7: _last(c)


func _born(c: Vector3) -> void:
	# a cot the size of a room, with rails, and a mobile of pieces turning over it
	var w := 5.0
	var d := 3.4
	Kit.box(self, c + Vector3(0, 0.3, 0), Vector3(w, 0.6, d), "wood/planks_white", {"tile": 1.5})
	Kit.box(self, c + Vector3(0, 0.75, 0), Vector3(w - 0.4, 0.3, d - 0.4), "fabric/sheet", {"tile": 1.5})
	for sx in [-1.0, 1.0]:
		for k in 9:
			Kit.box(self, c + Vector3(-w * 0.5 + 0.3 + k * (w - 0.6) / 8.0, 1.3, sx * d * 0.5), Vector3(0.08, 1.4, 0.08), "wood/planks_white", {"solid": false})
		Kit.box(self, c + Vector3(0, 2.0, sx * d * 0.5), Vector3(w, 0.1, 0.1), "wood/planks_white", {"solid": false})
	Kit.blocker(self, c + Vector3(0, 1.0, 0), Vector3(w, 2.0, d))
	var turn := Clockwork.create(self, c + Vector3(0, 4.2, 0), {"mode": "rotate", "axis": Vector3.UP, "speed_deg": 9.0, "name": "Mobile"})
	Kit.cylinder(turn.body, Vector3(0, -0.05, 0), 0.06, 0.1, "metal/brass", {"solid": false, "segments": 6})
	for k in 4:
		var arm := Kit.polar(1.3, k * 90.0)
		Kit.box(turn.body, arm * 0.5, Vector3(absf(arm.x) + 0.06, 0.05, absf(arm.z) + 0.06), "wood/planks_white", {"solid": false})
		Kit.cylinder(turn.body, arm + Vector3(0, -0.9, 0), 0.015, 0.9, "metal/brass", {"solid": false, "segments": 4})
		Props.place(turn.body, ["chess_pawn", "chess_knight", "chess_queen", "chess_pawn"][k], arm + Vector3(0, -1.35, 0), k * 90.0, 0.45, {"collision": "none", "tint": IVORY if k % 2 == 0 else RED})
	Kit.light(self, c + Vector3(2.4, 0.5, 1.6), WARM, 0.9, 7.0)
	Kit.light(self, c + Vector3(0, 5.5, 0), COLD, 0.8, 12.0)
	Readable.create(self, c + Vector3(0, 1.0, d * 0.5 + 0.6), 0.0, "Look into the cot", [
		"A cot the size of a room. The sheet is turned down. The pieces over it go round and never come down.",
		"Whatever is in it is the size of a room as well, and is you, and has not decided anything yet.",
	], {"name": "Cot", "size": Vector3(3.0, 1.6, 1.2), "note_key": "rank_born", "note_title": "The last rank", "note_text": "The promotion is a rank of eight squares on a board that is being forgotten from the edges in. The first square is a cot. The pieces above it go round."})


func _small(c: Vector3) -> void:
	# hopscotch, in the pattern that goes one, two, one, two
	var z := c.z + 4.0
	var n := 1
	var pattern := [1, 2, 1, 2, 1, 2]
	for row in pattern.size():
		var cols: int = pattern[row]
		for k in cols:
			var x := (k - (cols - 1) * 0.5) * 1.5
			Kit.floor(self, Vector3(c.x + x, 0.02, z), Vector2(1.3, 1.3), WHITE, {"tint": Color(0.95, 0.9, 1.0), "thick": 0.04, "tile": 1.0, "overlay": true})
			Kit.label(self, str(n), Vector3(c.x + x, 0.05, z), 0.0, 32, Color(0.35, 0.3, 0.45), "display", {"pixel_size": 0.014, "outline": 0, "flat": true})
			n += 1
		z -= 1.5
	# you, and one of the tall ones
	Props.place(self, "chess_pawn", c + Vector3(-4.2, 0, 1.0), 0.0, 1.6, {"collision": "cylinder", "tint": IVORY})
	Props.place(self, "chess_pawn", c + Vector3(-5.2, 0, -1.4), 0.0, 4.2, {"collision": "cylinder", "tint": IVORY})
	Props.place(self, "chair", c + Vector3(4.0, 0, -2.0), 200.0, 0.6)
	Kit.sign(self, "props/painting_house", c + Vector3(4.6, 0.6, -3.5), 20.0, Vector2(0.9, 0.9))
	Kit.light(self, c + Vector3(0, 4.0, 0), WARM, 0.8, 10.0)
	Readable.create(self, c + Vector3(-4.2, 0.9, 1.0), 0.0, "The small piece", [
		"A pawn as tall as you were, beside one as tall as they were. Neither of them has moved since.",
		"Somebody has chalked the squares. The chalk is fresh. Nobody is small enough to play any more.",
	], {"name": "SmallPiece", "size": Vector3(1.2, 1.8, 1.2)})


func _taught(c: Vector3) -> void:
	for row in 2:
		for k in 3:
			var p := c + Vector3(-2.6 + k * 2.6, 0, -1.0 + row * 2.4)
			Props.place(self, "desk_office", p, 0.0, 0.85)
			Props.place(self, "chair_office", p + Vector3(0, 0, 1.0), 180.0, 0.85)
	# the board with the rules on it, and the clock that says the same as every clock here
	Kit.box(self, c + Vector3(0, 1.8, -5.6), Vector3(4.6, 2.2, 0.16), "stone/blocks_dark", {"tint": Color(0.25, 0.3, 0.28)})
	Kit.sign(self, "signs/kd_rules", c + Vector3(0, 1.8, -5.5), 180.0, Vector2(2.6, 1.9))
	Kit.sign(self, "metal/clock_face", c + Vector3(3.6, 2.4, -5.5), 180.0, Vector2(1.0, 1.0))
	Kit.light(self, c + Vector3(0, 4.5, -2.0), COLD, 1.0, 11.0)
	Readable.create(self, c + Vector3(0, 1.6, -5.0), 0.0, "Read the board", [
		"THE RULES OF THE GAME. 1. YOU ARE PLAYING. 2. The rest is torn off, as it was on the croquet ground.",
		"Six desks, all facing it. The chairs are turned round, as if the lesson were behind you.",
	], {"name": "Rules", "size": Vector3(4.0, 2.0, 1.0)})


func _kept(c: Vector3) -> void:
	for k in 4:
		Props.place(self, "filing_cabinet", c + Vector3(-5.5 + k * 1.3, 0, -5.0), 0.0, 1.0)
	Props.place(self, "desk_office", c + Vector3(1.5, 0, -1.0), 180.0, 1.0)
	Props.place(self, "chair_office", c + Vector3(1.5, 0, 0.2), 0.0, 1.0)
	Props.place(self, "phone_office", c + Vector3(2.0, 0.76, -1.1), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "water_cooler", c + Vector3(5.0, 0, -4.5), 0.0, 1.0)
	var td := Props.place(self, "ticket_dispenser", c + Vector3(-5.0, 0, 3.0), 90.0, 1.0, {"collision": "cylinder"})
	_corrupt(Props.part(td, "Body") if Props.part(td, "Body") != null else null)
	Kit.box(self, c + Vector3(-5.0, 1.0, 3.7), Vector3(0.08, 2.0, 0.08), "metal/plate", {"solid": false})
	Kit.sign(self, "signs/take_a_number", c + Vector3(-5.0, 2.15, 3.65), 180.0, Vector2(0.7, 0.35))
	for k in 5:
		var p := c + Vector3(-6.0 + (k * 2.9), 0.03, 4.5 - (k % 2) * 6.0)
		Kit.floor(self, p, Vector2(1.6, 1.6), "common/static", {"mat": Kit.static_mat({"brightness": 0.4, "scale": 30.0}), "thick": 0.06, "solid": false, "overlay": true})
	Kit.light(self, c + Vector3(0, 4.5, 0), Color(0.9, 0.95, 1.0), 1.0, 11.0)
	Readable.create(self, c + Vector3(1.5, 0.9, -1.0), 0.0, "The desk", [
		"A desk, and on it the day's number, which is the same as yesterday's. The phone does not ring. It has never had to.",
		"The floor is going. Where it has gone there is only the picture of a floor, and the picture is static.",
	], {"name": "Desk", "size": Vector3(1.6, 1.2, 1.2)})


func _loved(c: Vector3) -> void:
	Props.place(self, "table_round", c, 0.0, 1.0)
	Props.place(self, "chair", c + Vector3(-1.1, 0, 0), -90.0, 1.0)
	Props.place(self, "chair", c + Vector3(1.1, 0, 0), 90.0, 1.0)
	Props.place(self, "mug", c + Vector3(-0.3, 0.8, 0.1), 20.0, 1.0, {"collision": "none"})
	Props.place(self, "mug", c + Vector3(0.3, 0.8, -0.1), 200.0, 1.0, {"collision": "none"})
	Props.place(self, "chess_queen", c + Vector3(-3.6, 0, -4.0), 30.0, 1.8, {"collision": "cylinder", "tint": IVORY})
	Props.place(self, "chess_queen", c + Vector3(-2.4, 0, -4.4), -30.0, 1.8, {"collision": "cylinder", "tint": RED})
	for k in 3:
		Props.place(self, "rose_paper_planted", c + Kit.polar(2.6, k * 120.0 + 60.0), k * 120.0, 1.4, {"collision": "none"})
	Kit.light(self, c + Vector3(0, 2.6, 0), WARM, 1.1, 8.0)
	Readable.create(self, c + Vector3(0, 0.9, 0.9), 0.0, "The table for two", [
		"Two chairs, two mugs, both warm. Nobody is sitting in either and it does not feel like nobody.",
		"Two queens stand together at the edge of the square, one of each colour, which is not how the game is played.",
	], {"name": "TableForTwo", "size": Vector3(1.6, 1.2, 1.6)})


func _home(c: Vector3) -> void:
	# the lone door from the field, the mailbox with your number, and a window into nothing
	var door := Props.place(self, "door_white", c + Vector3(0, 0, -3.0), 0.0, 1.0)
	Kit.box(self, c + Vector3(0, 2.32, -3.0), Vector3(1.4, 0.12, 0.3), "wood/planks_white")
	Kit.box(self, c + Vector3(3.5, 1.35, -3.0), Vector3(3.0, 2.7, 0.2), "wood/planks_wall", {"tile": 1.5})
	Kit.sign(self, "props/window_night", c + Vector3(3.5, 1.5, -2.88), 180.0, Vector2(1.0, 1.0))
	Kit.box(self, c + Vector3(-4.0, 0.55, 1.5), Vector3(0.08, 1.1, 0.08), "wood/planks_dark")
	Kit.box(self, c + Vector3(-4.0, 1.25, 1.5), Vector3(0.3, 0.3, 0.5), "metal/plate")
	Readable.create(self, c + Vector3(-4.0, 1.25, 1.5), 0.0, "The mailbox", ["The mailbox from the field. The number on it is still yours, still in pencil: 5½.", "Nothing has come. Nothing was going to."], {"name": "Mailbox", "size": Vector3(0.6, 0.6, 0.7)})
	Props.place(self, "chair", c + Vector3(1.8, 0, 1.0), 160.0, 1.0)
	Props.place(self, "lantern_post", c + Vector3(-1.8, 0, 3.6), 0.0, 1.0, {"collision": "cylinder"})
	Kit.light(self, c + Vector3(-1.8, 2.8, 3.6), WARM, 1.0, 9.0)
	Dog.maybe_spawn(self, c + Vector3(3.0, 0.1, 3.0))
	if door:
		var leaf := Props.part(door, "Leaf")
		if leaf:
			leaf.rotation.y = deg_to_rad(-40.0)
	Readable.create(self, c + Vector3(0, 1.1, -2.2), 0.0, "The door", [
		"The white door from the field, standing on its own, a little open. Through it, the other side of the square.",
		"Beside it a window that shows night, which is the only thing it has ever shown.",
	], {"name": "HomeDoor", "size": Vector3(1.6, 2.2, 1.0)})


func _kept_again(c: Vector3) -> void:
	Props.place(self, "bed_iron", c + Vector3(0, 0, -1.0), 0.0, 1.0)
	Props.place(self, "chair", c + Vector3(2.2, 0, 0.6), 90.0, 1.0)
	# the drip, and the set that watches
	Kit.cylinder(self, c + Vector3(-1.4, 0, -1.6), 0.03, 1.9, "metal/brass", {"segments": 6})
	Kit.box(self, c + Vector3(-1.4, 1.75, -1.6), Vector3(0.18, 0.3, 0.1), "fabric/sheet", {"solid": false, "tint": Color(0.9, 0.95, 1.0)})
	Kit.cylinder(self, c + Vector3(-1.4, 0.02, -1.6), 0.3, 0.04, "metal/plate", {"segments": 8, "solid": false})
	Props.place(self, "crate", c + Vector3(-2.2, 0, 0.4), 0.0, 0.7)
	var tv := Props.place(self, "tv_crt", c + Vector3(-2.2, 0.6, 0.4), 60.0, 0.9, {"collision": "none"})
	var screen := Props.part(tv, "Screen")
	if screen is MeshInstance3D:
		(screen as MeshInstance3D).set_surface_override_material(0, Kit.static_mat({"brightness": 0.7}))
	Kit.sign(self, "metal/clock_face", c + Vector3(0, 2.6, -5.5), 180.0, Vector2(1.0, 1.0))
	Kit.box(self, c + Vector3(0, 1.4, -5.6), Vector3(6.0, 2.8, 0.16), "wall/plaster_white", {"tile": 1.5, "tint": Color(0.9, 0.92, 0.95)})
	Kit.light(self, c + Vector3(0, 3.5, -1.0), Color(0.9, 0.95, 1.0), 1.0, 10.0)
	Kit.light(self, c + Vector3(-2.2, 1.2, 0.4), Color(0.8, 0.85, 1.0), 0.6, 4.0)
	Readable.create(self, c + Vector3(0, 0.9, -1.0), 0.0, "The bed", [
		"An iron bed, made with hospital corners. A chair beside it, facing it, with a dent in the cushion the shape of somebody who sat a long time.",
		"The set on the crate shows static. The clock on the wall says half past five, like the clock in the town outside the train, like every clock you have seen since you fell asleep.",
	], {"name": "IronBed", "size": Vector3(2.0, 1.4, 2.6), "note_key": "rank_bed", "note_title": "The seventh square", "note_text": "The seventh square of the last rank is an iron bed with hospital corners, a chair that somebody sat in a long time, and a set showing static. The clock says half past five."})


func _last(c: Vector3) -> void:
	# the toppled piece, the stone with your name, and the square with nothing on it
	Props.place(self, "chess_queen", c + Vector3(-3.5, 0.55, 2.5), 0.0, 2.4, {"collision": "none", "tint": RED, "rotation": Vector3(0, 30, 90)})
	Props.place(self, "gravestone_you", c + Vector3(3.5, 0, 1.5), 200.0, 1.1, {"collision": "box"})
	Readable.create(self, c + Vector3(3.5, 0.6, 1.5), 200.0, "Read the stone", ["The stone from the Ossuary, with your name on it. The dates are still blank.", "The chalk underneath has been rubbed out."], {"name": "YourStoneAgain", "size": Vector3(1.0, 1.2, 0.8)})
	var last := c + Vector3(0, 0, -3.5)
	Kit.floor(self, last + Vector3(0, 0.12, 0), Vector2(3.2, 3.2), WHITE, {"tile": 1.0, "thick": 0.12, "tint": Color(1.0, 1.0, 1.0)})
	Kit.light(self, last + Vector3(0, 4.0, 0), Color(1.0, 1.0, 1.0), 1.4, 9.0)
	Kit.particles(self, last + Vector3(0, 1.5, 0), "motes", Vector3(2.0, 2.0, 2.0), 40)
	Interactable.make(self, last + Vector3(0, 1.0, 0), Vector3(2.6, 2.0, 2.6), "Stand on the last square", _on_last, {"name": "LastSquare"})


func _on_last(_p: Node, _it: Node) -> void:
	if World.hud == null:
		return
	var i: int = await World.hud.ask("", "The eighth square. A pawn that stands here is promoted: it becomes whatever it is told to be, and it never leaves the board. This is an ending. Stand on it?", ["No. Not yet.", "Stand on it, and stay."])
	if i != 1:
		return
	var y: int = await World.hud.ask("", "There is no coming back from this one. Are you sure?", ["No.", "Yes."])
	if y != 1:
		return
	await Ending.play("limbo", "The last rank", [
		"You stand on the square. Nothing is put on your head. Nothing needs to be.",
		"The pieces along the rank turn, all of them, the way a room turns when somebody important comes in.",
		"You are a piece now. The board will keep you. It keeps everything it has not finished with, and it has not finished with you.",
	], Color(0.95, 0.93, 0.9))
