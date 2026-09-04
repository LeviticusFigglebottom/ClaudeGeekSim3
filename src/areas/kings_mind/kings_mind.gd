extends AreaBase
## The King's Mind — above his sleep. You come up the beanstalk out of the
## garden onto the top of it, and there are more stalks, a forest of them,
## going up out of cloud with nothing under the cloud, their tops joined by
## leaves you can walk along. At the far end, a keep whose walls are grey
## matter, and inside it a labyrinth of bookshelves on two floors: everything
## he has ever been told, shelved by who told him. At the end of the second
## floor, a bedroom the size of a hall, and in it the Red King as he is: no
## crown, no colour, lying very still. A vase by the bed with nothing in it.
## It wants the three paper roses.
##
## Falling off anything lands you in the Static. No route needs a fall.

const STALKS := [Vector3(0, 0, 0), Vector3(16, 2.5, -16), Vector3(34, 5, -30), Vector3(22, 8, -50), Vector3(0, 10, -64)]
const TOP_R := 5.5
const KEEP_Y := 10.0
const KEEP_ORIGIN := Vector3(-19.0, KEEP_Y, -121.0)
const KEEP_W := 19
const CELL := 2.0
const H1 := 4.5
const H2 := 4.0
const PINK := Color(1.0, 0.8, 0.9)
const CANDLE := Color(1.0, 0.85, 0.6)

var vase_pos := Vector3.ZERO
var vase_node: Node3D = null


func build() -> void:
	can_wake = true
	Realm.apply(self, "kings_mind", {"sky_opts": {"band_strength": 0.03, "band_speed": 0.05}})
	_sky_and_cloud()
	_stalks()
	_bridges()
	_keep()
	add_spawn("from_beanstalk", STALKS[0] + Vector3(0, 0.1, 3.0), 0.0)
	add_spawn("default", STALKS[0] + Vector3(0, 0.1, 3.0), 0.0)
	Door.create(self, STALKS[0] + Vector3(0, 0, 5.0), 180.0, "kings_dream", "hilltop", {"kind": "none", "label": "Climb back down the stalk", "name": "StalkDown", "fade_color": Color(0.85, 0.95, 0.8), "fade_duration": 1.2, "sound": "wind_gust"})
	Kit.label(self, "down", STALKS[0] + Vector3(0, 1.6, 5.0), 180.0, 22, Color(0.9, 1.0, 0.85), "body", {"pixel_size": 0.012})
	Readable.create(self, STALKS[0] + Vector3(-3.0, 1.0, 0), 90.0, "Look down", [
		"Cloud, and the stalk going down into it, and under the cloud, nothing that has been decided on yet.",
		"The other stalks come up out of it the way thoughts do: one, then another near it, then a crowd of them further off, going the same way.",
	], {"name": "LookDown", "size": Vector3(1.0, 1.5, 2.0), "note_key": "kings_mind_in", "note_title": "Above the dream", "note_text": "The beanstalk came out above the King's sleep, into a forest of stalks standing in cloud. Their tops are joined by leaves and the leaves lead to a keep whose walls are brain."})
	Usher.spawn(self, STALKS[3] + Vector3(-3.5, 0, 0), {"appear_delay": 3.0})


# --- the sky, and the cloud that is the floor of it ----------------------------------------

func _sky_and_cloud() -> void:
	# a sea of cloud far below: flat, pale, no collision, and the fall goes through it
	Kit.floor(self, Vector3(10, -34.0, -50), Vector2(420, 420), "", {"tint": Color(0.9, 0.84, 0.92), "unshaded": true, "solid": false, "depth_bias": 0.0})
	Kit.particles(self, Vector3(10, -8, -50), "fog", Vector3(120, 4, 120), 60)
	Kit.particles(self, Vector3(10, 3, -40), "motes", Vector3(60, 8, 80), 50)
	for k in 14:
		var a := k * 47.0
		var rr := 24.0 + (k % 5) * 9.0
		Props.place(self, "cloud", Vector3(10, -6.0 - (k % 4) * 3.0, -50) + Kit.polar(rr, a), a, 3.0 + (k % 3), {"collision": "none"})
	# the forest: stalks with no way onto them, further off, going up out of the cloud
	for k in 22:
		var a := k * 61.0 + 20.0
		var rr := 42.0 + (k % 6) * 11.0
		var p := Vector3(14, 0, -55) + Kit.polar(rr, a)
		if _near_walkway(p):
			continue
		var top := 4.0 + (k % 7) * 4.0 - 8.0
		Kit.cylinder(self, p + Vector3(0, -80, 0), 2.0 + (k % 3) * 0.6, 80.0 + top - 0.4, "nature/stalk", {"segments": 8, "tile": 3.0, "solid": false, "tint": Color(0.85, 0.95, 0.85)})
		Kit.cylinder(self, p + Vector3(0, top - 0.4, 0), 4.0 + (k % 3), 0.4, "nature/hedge", {"segments": 10, "tile": 1.5, "solid": false, "tint": Color(0.8, 1.0, 0.75)})
		for j in 3:
			Props.place(self, "beanstalk_leaf", p + Kit.polar(1.8, j * 120.0 + a, top - 0.2), -(j * 120.0 + a) - 90.0, 1.3, {"collision": "none"})
	Kit.light(self, Vector3(10, 30, -50), Color(0.9, 0.8, 1.0), 0.5, 160.0)


# --- the stalks you walk on ------------------------------------------------------------

func _stalks() -> void:
	for i in STALKS.size():
		var c: Vector3 = STALKS[i]
		Kit.cylinder(self, c + Vector3(0, -80, 0), 3.0, 79.6, "nature/stalk", {"segments": 10, "tile": 3.0, "tint": Color(0.95, 1.0, 0.9)})
		Kit.cylinder(self, c + Vector3(0, -0.4, 0), TOP_R, 0.4, "nature/hedge", {"segments": 14, "tile": 1.5, "tint": Color(0.8, 1.0, 0.75)})
		for j in 6:
			var a := j * 60.0 + i * 17.0
			Props.place(self, "beanstalk_leaf", c + Kit.polar(2.2, a, -0.15), -a - 90.0, 1.4, {"collision": "none"})
		Kit.light(self, c + Vector3(0, 3.0, 0), PINK, 0.9, 12.0)
		# invisible walls round the leaf's rim, with gaps where the leaves join
		var gaps: Array = []
		if i > 0:
			gaps.append(_angle_to(c, STALKS[i - 1]))
		if i < STALKS.size() - 1:
			gaps.append(_angle_to(c, STALKS[i + 1]))
		else:
			gaps.append(_angle_to(c, Vector3(0, KEEP_Y, -76.0)))
		if i == 0:
			gaps.append(_angle_to(c, c + Vector3(0, 0, 8)))
		for k in 16:
			var a := k * 22.5 + 11.25
			var open := false
			for g in gaps:
				if absf(wrapf(a - float(g), -180.0, 180.0)) < 24.0:
					open = true
			if open:
				continue
			_fence(c + Kit.polar(TOP_R - 0.2, a, 1.5), Vector3(2.2, 3.0, 0.12), -(a + 90.0))


## True when a point is within reach of a stalk top or a branch of the way to the keep.
static func _near_walkway(p: Vector3) -> bool:
	var pts: Array = STALKS.duplicate()
	pts.append(Vector3(0, KEEP_Y, -76.0))
	for i in pts.size():
		var c: Vector3 = pts[i]
		if Vector2(p.x - c.x, p.z - c.z).length() < TOP_R + 9.0:
			return true
		if i < pts.size() - 1:
			var d: Vector3 = pts[i + 1]
			var a2 := Vector2(c.x, c.z)
			var b2 := Vector2(d.x, d.z)
			var q := Vector2(p.x, p.z)
			var t := clampf((q - a2).dot(b2 - a2) / maxf((b2 - a2).length_squared(), 0.001), 0.0, 1.0)
			if q.distance_to(a2.lerp(b2, t)) < 9.0:
				return true
	return false


static func _angle_to(from: Vector3, to: Vector3) -> float:
	return rad_to_deg(atan2(to.z - from.z, to.x - from.x))


## An invisible wall: a box you cannot see, drawn nowhere, standing where a rail would.
func _fence(pos: Vector3, size: Vector3, yaw: float) -> void:
	var b := Kit.blocker(self, Vector3.ZERO, size)
	b.position = pos
	b.rotation.y = deg_to_rad(yaw)


# --- the leaves between them -----------------------------------------------------------

func _bridges() -> void:
	for i in STALKS.size() - 1:
		_bridge(STALKS[i], STALKS[i + 1])
	# the last leaf goes to the keep's gate
	var e: Vector3 = STALKS[STALKS.size() - 1]
	var gate := Vector3(0, KEEP_Y, -76.0)
	_bridge(e, gate + Vector3(0, 0, 0.6), true)


## A branch grown from one stalk to the next: a thick limb you walk along the
## top of, its edges raised into a lip, leaves hanging off both sides, and a
## wall you cannot see above the lip. It starts well inside one leaf and ends
## well inside the next, so there is no seam to fall through.
func _bridge(a: Vector3, b: Vector3, to_gate: bool = false) -> void:
	var flat := b - a
	flat.y = 0.0
	var dir := flat.normalized()
	var right := Vector3(-dir.z, 0, dir.x)
	var p0 := a + dir * (TOP_R - 1.6)
	var p1 := b - (dir * (TOP_R - 1.6) if not to_gate else -dir * 0.8)
	var run := p1 - p0
	run.y = 0.0
	var length := run.length()
	var rise := b.y - a.y
	var yaw := Kit.dir_to_yaw(dir)
	var pitch := rad_to_deg(atan2(rise, length))
	var slope := Vector2(length, rise).length()
	var thick := 1.0
	var w := 3.2
	# the limb: its top is the way; it sits a hair above the leaves it joins
	var mid := (p0 + p1) * 0.5 + Vector3(0, rise * 0.5, 0)
	Kit.box(self, mid + Vector3(0, 0.04 - thick * 0.5, 0), Vector3(w, thick, slope), "nature/stalk", {"rotation": Vector3(pitch, yaw, 0), "tint": Color(0.85, 1.0, 0.8), "tile": 1.5, "surface": "grass"})
	for sx in [-1.0, 1.0]:
		Kit.box(self, mid + right * (sx * (w * 0.5 - 0.15)) + Vector3(0, 0.2, 0), Vector3(0.3, 0.4, slope), "nature/hedge", {"rotation": Vector3(pitch, yaw, 0), "tint": Color(0.7, 0.95, 0.65), "tile": 1.2})
		var f := Kit.blocker(self, Vector3.ZERO, Vector3(0.2, 3.2, slope))
		f.position = mid + right * (sx * (w * 0.5 + 0.05)) + Vector3(0, 1.6, 0)
		f.rotation_degrees = Vector3(pitch, yaw, 0)
	# leaves and tendrils along it, hanging out over the drop
	var n := int(length / 4.0)
	for i in n:
		var t := (i + 0.5) / n
		var p := p0.lerp(p1, t) + Vector3(0, rise * t, 0)
		var sx := 1.0 if i % 2 == 0 else -1.0
		Props.place(self, "beanstalk_leaf", p + right * (sx * (w * 0.5 - 0.2)) + Vector3(0, -0.1, 0), yaw + sx * 80.0 + (i * 13.0), 1.1 + (i % 3) * 0.15, {"collision": "none"})
		if i % 2 == 1:
			Kit.cylinder(self, p + right * (-sx * (w * 0.5 + 0.1)) + Vector3(0, -1.2, 0), 0.12, 1.3, "nature/stalk", {"segments": 6, "solid": false, "top_radius": 0.05})
	Kit.light(self, mid + Vector3(0, 2.5, 0), PINK, 0.6, 10.0)


# --- the keep ----------------------------------------------------------------------------

## A perfect maze w by h (both odd): '#' outside, 'B' bookshelf walls inside, '.' ways.
func _maze(w: int, h: int) -> Array:
	var g: Array = []
	for r in h:
		var row: Array = []
		for c in w:
			row.append("#")
		g.append(row)
	var stack: Array = [Vector2i(1, 1)]
	g[1][1] = "."
	var dirs := [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
	while stack.size() > 0:
		var cur: Vector2i = stack.back()
		var open: Array = []
		for d in dirs:
			var n: Vector2i = cur + d
			if n.x > 0 and n.x < w - 1 and n.y > 0 and n.y < h - 1 and g[n.y][n.x] == "#":
				open.append(d)
		if open.is_empty():
			stack.pop_back()
			continue
		var d: Vector2i = open[rng.randi() % open.size()]
		g[cur.y + d.y / 2][cur.x + d.x / 2] = "."
		g[cur.y + d.y][cur.x + d.x] = "."
		stack.append(cur + d)
	for r in range(1, h - 1):
		for c in range(1, w - 1):
			if g[r][c] == "#":
				g[r][c] = "B"
	return g


static func _row(chars: Array) -> String:
	var s := ""
	for ch in chars:
		s += String(ch)
	return s


func _keep() -> void:
	var W := KEEP_W
	var hall := "#" + ".".repeat(W - 2) + "#"
	# --- the ground floor: a hall along the north with the stair in it, the maze, the gate
	var m1 := _maze(W, 21)
	var rows1: Array = []
	rows1.append("#".repeat(W))
	var h1 := hall
	# the stair up runs east along the hall from cell 10 to 13; no ceiling over it
	h1 = h1.substr(0, 10) + ":::" + h1.substr(13)
	rows1.append(h1)
	m1[0][9] = "D"
	m1[20][9] = "D"
	for r in m1:
		rows1.append(_row(r))
	var map1 := MapBuilder.build(self, rows1, {"cell": CELL, "height": H1, "origin": KEEP_ORIGIN, "door_h": 3.0, "tile": 2.0,
		"floor": "wood/planks_dark", "wall": "organic/brain", "ceiling": "wood/planks_dark", "walls": {"B": "wood/book_wall"},
		"outer_faces": true, "name": "MindGround", "tint": Color(1.0, 0.95, 0.98)})
	# --- the upper floor: the hall again with the stair's well cut out of it, a smaller maze, the bedroom
	var m2 := _maze(W, 15)
	var rows2: Array = []
	rows2.append("#".repeat(W))
	var h2 := hall
	h2 = h2.substr(0, 10) + "ppp" + h2.substr(13)
	rows2.append(h2)
	m2[0][9] = "D"
	var exit_col := 15
	m2[14][exit_col] = "D"
	for r in m2:
		rows2.append(_row(r))
	for k in 4:
		rows2.append(hall)
	rows2.append("#".repeat(W))
	var o2 := KEEP_ORIGIN + Vector3(0, H1, 0)
	MapBuilder.build(self, rows2, {"cell": CELL, "height": H2, "origin": o2, "door_h": 3.0, "tile": 2.0,
		"floor": "wood/planks_dark", "wall": "organic/brain", "ceiling": "organic/brain", "walls": {"B": "wood/book_wall"},
		"outer_faces": true, "pit": "p", "name": "MindUpper", "tint": Color(1.0, 0.95, 0.98)})
	# the stair between the floors, in the hall, east from cell 10
	var stair_foot := KEEP_ORIGIN + Vector3(10.0 * CELL, 0, 1.5 * CELL)
	Kit.stairs(self, stair_foot, -90.0, 1.6, 15, H1 / 15.0, 0.4, "wood/planks_dark", {"tile": 1.0, "name": "MindStair"})
	Kit.light(self, stair_foot + Vector3(3.0, 3.5, 0), CANDLE, 1.0, 8.0)
	# the outside: a brain roof over the lot, and the gate's plate
	var roof_c := KEEP_ORIGIN + Vector3(W * CELL * 0.5, H1 + H2 + 0.3, 11.5 * CELL)
	Kit.box(self, roof_c, Vector3(W * CELL + 0.6, 0.6, 23.0 * CELL + 0.6), "organic/brain", {"tile": 2.5, "solid": false})
	for k in 8:
		var a := k * 45.0
		Kit.box(self, roof_c + Vector3(0, 0.7, 0) + Kit.polar(11.0 + (k % 2) * 4.0, a), Vector3(3.0, 1.2 + (k % 3) * 0.6, 3.0), "organic/brain", {"tile": 2.0, "solid": false})
	var gate := Vector3(0, KEEP_Y, -76.0)
	Kit.sign(self, "signs/km_plate", gate + Vector3(-2.2, 2.4, 0.1), 180.0, Vector2(1.6, 0.8))
	Readable.create(self, gate + Vector3(-2.2, 2.4, 0.2), 180.0, "Read the plate by the gate", [
		"HIS MAJESTY IS NOT RECEIVING.",
		"Under it, in a different hand, scratched: he never was.",
	], {"name": "GatePlate", "size": Vector3(1.8, 1.0, 0.5)})
	Kit.light(self, gate + Vector3(0, 3.6, 1.0), CANDLE, 1.2, 9.0)
	Kit.light(self, gate + Vector3(0, 3.0, -3.0), PINK, 0.9, 9.0)
	# lamps through the maze, and a sign about the shelves
	_maze_lamps(m1, KEEP_ORIGIN + Vector3(0, 0, 2.0 * CELL), H1 - 0.6)
	_maze_lamps(m2, o2 + Vector3(0, 0, 2.0 * CELL), H2 - 0.6)
	var shelf_sign := KEEP_ORIGIN + Vector3(9.5 * CELL, 1.9, 19.5 * CELL + 0.9)
	Readable.create(self, shelf_sign, 0.0, "Read the shelf label", [
		"EVERYTHING HE HAS BEEN TOLD. SHELVED BY WHO TOLD HIM.",
		"The spines have no titles. Some of them have your handwriting on them, which you have not done yet.",
	], {"name": "ShelfLabel", "sign": "signs/km_shelf", "sign_size": Vector2(0.9, 0.7), "size": Vector3(1.0, 0.8, 0.3), "note_key": "kings_mind_shelves", "note_title": "The shelves in his head", "note_text": "The keep in the King's mind is a labyrinth of bookshelves on two floors: everything he has been told, shelved by who told him. None of the books have titles. Some have your handwriting."})
	Puzzle.declare(self, "kings_mind_maze", "", [], "find the way through the shelves to the bedroom on the upper floor")
	_bedroom(o2 + Vector3(9.5 * CELL, 0, 18.5 * CELL))


func _maze_lamps(m: Array, origin: Vector3, y: float) -> void:
	var k := 0
	for r in m.size():
		for c in m[r].size():
			if m[r][c] != ".":
				continue
			k += 1
			if k % 6 != 3:
				continue
			var p := origin + Vector3((c + 0.5) * CELL, y, (r + 0.5) * CELL)
			Kit.light(self, p, CANDLE if k % 2 == 0 else PINK, 0.8, 7.0)
			Props.place(self, "candle_cluster", p - Vector3(0, y - 0.02, 0), 0.0, 0.8, {"collision": "none"})


# --- the bedroom, and the King as he is --------------------------------------------------

func _bedroom(c: Vector3) -> void:
	# the room is four cells deep along z (rows 17..20) and the width of the keep
	var bed := c + Vector3(0, 0, -1.0)
	Props.place(self, "bed_double", bed, 0.0, 1.3)
	Props.place(self, "king_coma", bed + Vector3(0.0, 0.62, 0.2), 90.0, 1.3, {"collision": "none"})
	for sx in [-8.0, 8.0]:
		Props.place(self, "bookshelf_tall", c + Vector3(sx, 0, -2.6), 0.0, 1.0)
		Props.place(self, "candle_tall", c + Vector3(sx * 0.6, 0, 2.4), 0.0, 1.0, {"collision": "none"})
		Kit.light(self, c + Vector3(sx * 0.6, 1.6, 2.4), CANDLE, 1.1, 9.0)
	Kit.light(self, bed + Vector3(0, 3.2, 0), PINK, 1.0, 10.0)
	Readable.create(self, bed + Vector3(0, 1.0, 0.2), 0.0, "Look at the King", [
		"No crown. No red. A man of no particular size, under a sheet, breathing about once for every four of yours.",
		"His eyes move under the lids. Somewhere below all this a garden is happening, and a train, and a trial, and he is doing all of it.",
		"He is not asleep, exactly. Asleep is something you can be woken from.",
	], {"name": "KingLook", "size": Vector3(2.6, 1.4, 2.6), "note_key": "kings_mind_king", "note_title": "The King as he is", "note_text": "At the end of the labyrinth in his head, in a bedroom the size of a hall, the Red King lies under a sheet with no crown and no colour, breathing once for every four of your breaths. Not asleep: asleep can be woken. There is a vase by the bed with nothing in it."})
	# the table by the bed, and the vase
	var table := bed + Vector3(2.2, 0, 0.3)
	Props.place(self, "stool", table, 0.0, 1.1)
	vase_pos = table + Vector3(0, 0.5, 0)
	vase_node = Props.place(self, "vase", vase_pos, 0.0, 1.2, {"collision": "none"})
	for i in Game.count("roses_placed"):
		_rose_in_vase(i)
	Interactable.make(self, vase_pos + Vector3(0, 0.3, 0), Vector3(0.9, 1.2, 0.9), "The vase", _on_vase, {"name": "Vase"})
	Kit.light(self, vase_pos + Vector3(0, 1.2, 0), Color(1.0, 0.95, 0.85), 0.8, 5.0)
	Puzzle.declare(self, "kings_mind_roses", "roses_all_placed", ["item:rose"], "put the three paper roses in the vase by his bed")
	Usher.spawn(self, c + Vector3(-7.0, 0, 1.5), {"appear_delay": 1.5})


func _rose_in_vase(i: int) -> void:
	var a := i * 120.0 + 30.0
	var rose := Props.place(self, "rose_paper_planted", vase_pos + Kit.polar(0.05, a, 0.36), a, 0.9, {"collision": "none"})
	rose.rotation.z = deg_to_rad(-12.0)
	rose.rotation.x = deg_to_rad(6.0)


func _on_vase(_p: Node, _it: Node) -> void:
	if World.hud == null:
		return
	var n := Game.count("roses_placed")
	if n >= 3:
		await World.hud.say("", ["Three paper roses in a cream vase with a blue band. They do not need water. He breathes, once, for every four of yours, and the petals move with it."])
		return
	if not Game.has_item("rose"):
		var lines: Array = ["A vase with nothing in it, by the bed. It has the look of something that has been empty a long time and is used to it."]
		if n > 0:
			lines = ["%d paper rose%s in the vase. There is room for %s." % [n, "s" if n > 1 else "", "two more" if n == 1 else "one more"]]
		lines.append("Paper flowers would do. He would not know the difference, and it is the difference that matters.")
		await World.hud.say("", lines)
		return
	Game.take_item("rose")
	n = Game.bump("roses_placed")
	_rose_in_vase(n - 1)
	Audio.sfx("whisper", null, -8.0)
	match n:
		1:
			await World.hud.say("", ["You stand the paper rose in the vase. It smells of dust and, faintly, of rain.", "His breathing does not change. Something in the shelves outside does: a book, somewhere, being put back."])
			Game.note("roses_1", "The first rose", "One paper rose in the vase by the King's bed. A book, somewhere in the labyrinth, was put back on its shelf.")
		2:
			await World.hud.say("", ["The second rose leans against the first. Two pages from the same book, folded by different hands.", "His hand, on the sheet, closes a little. It may be nothing. You decide it is not nothing."])
			Game.note("roses_2", "The second rose", "Two roses in the vase. His hand closed on the sheet, a little.")
		_:
			Game.set_flag("roses_all_placed", true)
			await World.hud.say("", [
				"The third rose. The vase is full, if three is full, and it is.",
				"He breathes in. It takes a long time. When it comes out, the candles by the door bend toward the bed, all of them, and stay bent.",
				"He has not opened his eyes. But he knows there are flowers, and he knows who brought them, and for the first time since you came into his sleep he is not dreaming about you.",
				"He is waiting for you.",
			])
			Game.note("roses_3", "Three roses", "All three paper roses stand in the vase by the King's bed. He knows they are there and who brought them. He has stopped dreaming about you. He is waiting. What for, nobody has said yet.")


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	Game.set_flag("visited_kings_mind", true)
	if n == 1:
		Game.toast.emit("This is not his dream. This is where he keeps it.")
