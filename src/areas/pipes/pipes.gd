extends AreaBase
## The Waterworks — where the water went. Under the drain at the bottom of
## the Cistern's great bath: a shaft, then pipes the size of corridors, then
## halls of white and cyan tile with channels cut through them and the water
## going somewhere, in no hurry. At the far end a square room with a square
## block in the middle of it and nothing on the block at all. Walk round it
## the way the water goes and the door you came in by is not there any more;
## keep going round and the block gives up a doorway, and a stair inside that
## keeps going up until it, too, gives up. At the top, a shard of dark glass
## on a pedestal, meant for the mirror in the Keep's bedchamber, and a hatch
## back up to the bath.
##
## Holding R wakes you. No route needs a fall.

const CELL := 1.0
const H := 4.0
const ORIGIN := Vector3(-32.0, 0.0, -27.0)
const W := 64
const D := 54
const BLOCK := Vector3(9.0, 0.0, 41.0)    # plan metres: the turning room's block centre
const TOWER_H := 13.5
const LAPS_NEEDED := 3
const LOOPS_NEEDED := 3
const CYAN := Color(0.6, 0.95, 0.95)
const TILE := "wall/tile_white"
const PLATE := "metal/plate"

var opened := false
var entrance_sealed := false
var door_face := 1              # the face of the block the doorway appears in: +1 east, -1 west
var seals := {}
var entrance_seal: Node3D = null
var stair_seam: SeamlessTeleport = null
var _last_angle := 0.0
var _have_angle := false
var _progress := 0.0            # degrees walked round the block, the water's way
var _laps_told := 0


func build() -> void:
	can_wake = true
	opened = Game.has_flag("pipes_opened")
	Realm.apply(self, "pipes", {})
	_plan()
	_shaft_room()
	_pipe(13, 7, 31, 10)
	_hall_one()
	_pipe(42, 17, 45, 31)
	_hall_two()
	_pipe(18, 40, 23, 43)
	_turning_room()
	_tower()
	add_spawn("from_cistern", _m(8.0, 8.0, 0.1), 0.0)
	add_spawn("default", _m(8.0, 8.0, 0.1), 0.0)
	Puzzle.declare(self, "pipes_turns", "pipes_opened", ["flag:cistern_drained"], "in the turning room, go round the block the way the water goes, three times, until it gives up a doorway")
	Puzzle.declare(self, "pipes_stair", "", ["flag:pipes_opened"], "climb the stair inside the block until it ends")
	Puzzle.declare(self, "pipes_glass", "picked_dark_glass", ["flag:pipes_opened"], "the dark glass on the pedestal at the top of the stair", {"item": "dark_glass"})


# --- coordinates: plan metres -> world -------------------------------------------------------

func _m(x: float, z: float, y: float = 0.0) -> Vector3:
	return Vector3(ORIGIN.x + x, y, ORIGIN.z + z)


func _lamp(x: float, z: float, energy: float = 0.9, reach: float = 9.0, y: float = H - 0.5) -> void:
	Kit.light(self, _m(x, z, y), CYAN, energy, reach)


# --- the plan --------------------------------------------------------------------------------

func _plan() -> void:
	var rects := [
		[4, 4, 12, 12, "s"],        # the shaft room
		[13, 7, 31, 10, "p"],       # pipe one, east
		[32, 2, 54, 16, "h"],       # hall one
		[34, 8, 52, 10, "~"],       # its channel
		[42, 17, 45, 31, "p"],      # pipe two, south
		[24, 32, 62, 52, "h"],      # hall two, the junction
		[26, 38, 60, 40, "~"],
		[26, 46, 60, 48, "~"],
		[34, 34, 36, 50, "~"],
		[50, 34, 52, 50, "~"],
		[18, 40, 23, 43, "p"],      # pipe three, west
		[1, 33, 17, 49, "t"],       # the turning room
		[6, 38, 12, 44, "b"],       # the block's footprint: no ceiling, the tower rises through it
	]
	var doors := [
		[12, 8, "D"], [31, 8, "D"],
		[43, 16, "D"], [43, 31, "D"],
		[23, 41, "D"], [17, 41, "D"],
	]
	var rows := MapBuilder.rasterize(W, D, rects, doors)
	var rooms := {
		"s": {"floor": "wall/tile_checker", "wall": "wall/tile_cyan", "ceiling": "wall/plaster_white"},
		"p": {"floor": PLATE, "wall": PLATE, "ceiling": PLATE},
		"h": {"floor": TILE, "wall": "wall/tile_cyan", "ceiling": "wall/plaster_white"},
		"t": {"floor": "wall/tile_checker", "wall": TILE, "ceiling": "wall/plaster_white"},
		"b": {"floor": "wall/tile_checker", "wall": TILE, "ceiling": "wall/plaster_white"},
	}
	MapBuilder.build(self, rows, {
		"cell": CELL, "height": H, "origin": ORIGIN, "door_h": 3.0, "tile": 2.0,
		"floor": TILE, "wall": "wall/tile_cyan", "ceiling": "wall/plaster_white",
		"water": "nature/water_cistern", "water_floor": TILE,
		"water_opts": {"tint": Color(0.75, 0.95, 1.0, 0.45), "subdiv": 2},
		"floors": {"b": "wall/tile_checker"}, "no_ceiling": "sb",
		"rooms": rooms, "outer_faces": true, "name": "Waterworks",
	})


# --- the shaft you came down ------------------------------------------------------------------

func _shaft_room() -> void:
	var c := _m(8.0, 8.0)
	# a ceiling with a hole in it, and the pipe coming down through the hole
	Kit.ceiling(self, _m(8.0, 5.15, H), Vector2(8.0, 2.3), "wall/plaster_white", {"tile": 2.0})
	Kit.ceiling(self, _m(8.0, 10.85, H), Vector2(8.0, 2.3), "wall/plaster_white", {"tile": 2.0})
	Kit.ceiling(self, _m(5.15, 8.0, H), Vector2(2.3, 3.4), "wall/plaster_white", {"tile": 2.0})
	Kit.ceiling(self, _m(10.85, 8.0, H), Vector2(2.3, 3.4), "wall/plaster_white", {"tile": 2.0})
	var pivot := Node3D.new()
	pivot.name = "DownPipe"
	pivot.position = c + Vector3(0, 3.2, 0)
	add_child(pivot)
	Kit.round_wall(pivot, Vector3.ZERO, 1.6, 40.0, 14, PLATE, {"solid": false, "tile": 2.0, "tint": Color(0.6, 0.68, 0.7)})
	Kit.particles(self, c + Vector3(0, 3.0, 0), "rain", Vector3(1.2, 0.4, 1.2), 60)
	Kit.water(self, c + Vector3(0, 0.08, 0), Vector2(3.6, 3.6), "nature/water_cistern", {"tint": Color(1, 1, 1, 0.5), "subdiv": 2})
	Kit.light(self, c + Vector3(0, 6.0, 0), CYAN, 1.2, 12.0)
	_lamp(5.0, 5.0)
	_lamp(11.0, 11.0)
	Readable.create(self, c + Vector3(0, 1.6, -1.8), 0.0, "Look up the pipe", [
		"The pipe you came down, going up further than the light goes. Water is still coming down it, thinly, the last of what was in the bath.",
		"You are not going back up it. Down is the same as down, and this is where down went.",
	], {"name": "DownPipeLook", "size": Vector3(2.0, 2.0, 1.6), "note_key": "pipes", "note_title": "The Waterworks", "note_text": "Under the drain at the bottom of the great bath: a shaft, and pipes the size of corridors, and halls of white and cyan tile with the water going somewhere in no hurry."})
	Kit.label(self, "OUTFLOW", _m(8.0, 4.02, 2.6), 180.0, 36, Color(0.3, 0.5, 0.55), "display", {"pixel_size": 0.012})


## A pipe the size of a corridor: a tube drawn inside a rasterised corridor
## (the map's walls keep the collision), ribbed, with a run of water down
## the bottom of it and a lamp every few metres.
func _pipe(x0: int, z0: int, x1: int, z1: int) -> void:
	var along_x := (x1 - x0) > (z1 - z0)
	var length := float(x1 - x0) if along_x else float(z1 - z0)
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var pivot := Node3D.new()
	pivot.name = "Pipe_%d_%d" % [x0, z0]
	if along_x:
		pivot.position = _m(float(x0), cz, 1.5)
		pivot.rotation.z = deg_to_rad(-90.0)
	else:
		pivot.position = _m(cx, float(z1), 1.5)
		pivot.rotation.x = deg_to_rad(-90.0)
	add_child(pivot)
	Kit.round_wall(pivot, Vector3.ZERO, 1.45, length, 14, PLATE, {"solid": false, "tile": 2.0, "tint": Color(0.62, 0.7, 0.72)})
	var n := int(length / 4.0)
	for k in n:
		var t := (k + 0.5) * 4.0
		var rib := Node3D.new()
		rib.position = Vector3(0, t, 0)
		pivot.add_child(rib)
		Kit.round_wall(rib, Vector3.ZERO, 1.36, 0.16, 14, "metal/iron", {"solid": false, "tile": 1.0, "tint": Color(0.5, 0.55, 0.58)})
		if k % 2 == 0:
			var lp := _m(float(x0) + t, cz, 2.3) if along_x else _m(cx, float(z1) - t, 2.3)
			Kit.light(self, lp, CYAN, 0.55, 6.0)
	var wsize := Vector2(length, 1.1) if along_x else Vector2(1.1, length)
	Kit.water(self, _m(cx, cz, 0.12), wsize, "nature/water_cistern", {"tint": Color(1, 1, 1, 0.5), "subdiv": 2})


## A footbridge over a channel: a slab with a rail either side, lit.
func _bridge(x: float, z: float, along_x: bool) -> void:
	var size := Vector3(3.0, 0.16, 1.4) if along_x else Vector3(1.4, 0.16, 3.0)
	Kit.box(self, _m(x, z, 0.08), size, "wood/planks_warm", {"tile": 1.0})
	for s in [-1.0, 1.0]:
		var off := Vector3(0, 0.6, s * 0.62) if along_x else Vector3(s * 0.62, 0.6, 0)
		var rail := Vector3(3.0, 0.06, 0.06) if along_x else Vector3(0.06, 0.06, 3.0)
		Kit.box(self, _m(x, z, 0.0) + off + Vector3(0, 0.3, 0), rail, "metal/brass", {"solid": false})
		for e in [-1.2, 1.2]:
			var post := Vector3(e, 0, 0) if along_x else Vector3(0, 0, e)
			Kit.box(self, _m(x, z, 0.16) + off + post - Vector3(0, 0.15, 0), Vector3(0.06, 0.9, 0.06), "metal/brass", {"solid": false})
	Kit.light(self, _m(x, z, 2.2), CYAN, 0.6, 6.0)


# --- hall one: the channel -----------------------------------------------------------------------

func _hall_one() -> void:
	for k in 4:
		var x := 37.0 + k * 4.0
		Props.place(self, "pillar_tiled", _m(x, 6.5), 0.0, 1.0, {"collision": "cylinder"})
		Props.place(self, "pillar_tiled", _m(x, 11.5), 0.0, 1.0, {"collision": "cylinder"})
	_bridge(40.0, 9.0, false)
	_bridge(47.0, 9.0, false)
	for i in 3:
		for j in 2:
			_lamp(35.0 + i * 8.0, 4.5 + j * 9.0)
	for z in [8.5, 9.5]:
		Kit.light(self, _m(43.0, z, 0.6), CYAN, 0.5, 12.0)
	Props.place(self, "tiled_bench", _m(44.0, 3.0), 0.0, 1.0)
	Props.place(self, "pool_float", _m(36.0, 9.0, -0.35), 20.0, 1.0, {"collision": "none"})
	Readable.create(self, _m(36.0, 9.0, 0.2), 0.0, "The channel", [
		"A channel cut through the hall, knee-deep, moving. It is the water from the bath, still going. It went down a drain the size of a door and it is still only this.",
		"Somebody has put footbridges over it, and rails on the footbridges, as if anyone were expected.",
	], {"name": "ChannelLook", "size": Vector3(2.0, 1.2, 2.4)})
	Kit.particles(self, _m(43.0, 9.0, 1.5), "motes", Vector3(18.0, 1.5, 10.0), 40)


# --- hall two: the junction ----------------------------------------------------------------------

func _hall_two() -> void:
	for i in 5:
		for j in 3:
			var x := 29.0 + i * 7.0
			var z := 35.5 + j * 7.0
			if absf(x - 35.0) < 1.5 or absf(x - 51.0) < 1.5 or absf(z - 39.0) < 1.5 or absf(z - 47.0) < 1.5:
				continue
			Props.place(self, "pillar_tiled", _m(x, z), 0.0, 1.0, {"collision": "cylinder"})
	for i in 5:
		for j in 3:
			_lamp(28.0 + i * 8.0, 35.0 + j * 7.5)
	# lights down in the channels, so the water is water and not a hole
	for x in [30.0, 43.0, 56.0]:
		for z in [39.0, 47.0]:
			Kit.light(self, _m(x, z, 0.4), CYAN, 0.5, 9.0)
	for z in [36.0, 43.0]:
		for x in [35.0, 51.0]:
			Kit.light(self, _m(x, z, 0.4), CYAN, 0.5, 9.0)
	# footbridges where the walkways cross the channels
	_bridge(43.0, 39.0, false)
	_bridge(43.0, 47.0, false)
	_bridge(35.0, 43.0, true)
	_bridge(51.0, 43.0, true)
	_bridge(28.5, 39.0, false)
	_bridge(57.5, 47.0, false)
	var wheel := Props.place(self, "gear_big", _m(61.9, 43.0, 1.6), -90.0, 0.35, {"collision": "none", "tint": Color(0.5, 0.15, 0.12)})
	if wheel:
		wheel.rotation.z = deg_to_rad(90.0)
	Usher.spawn(self, _m(59.0, 36.0), {"appear_delay": 3.0, "radius": 40.0})
	Kit.particles(self, _m(43.0, 42.0, 1.5), "motes", Vector3(34.0, 1.5, 18.0), 60)


# --- the turning room ---------------------------------------------------------------------------

## A square room with a blank tiled block in the middle of it, taller than
## the room. Nothing to read, nothing to press. Going round it the way the
## water goes is the whole of it.
func _turning_room() -> void:
	var c := _m(BLOCK.x, BLOCK.z)
	for p in [[3.0, 35.0], [15.0, 35.0], [3.0, 47.0], [15.0, 47.0]]:
		_lamp(float(p[0]), float(p[1]), 1.0, 10.0)
	# the block: four faces; the east and west can hold a doorway, sealed until the block gives up
	var tile_opts := {"tile": 2.0}
	Kit.box(self, c + Vector3(0, TOWER_H * 0.5, -2.85), Vector3(6.0, TOWER_H, 0.3), TILE, tile_opts)
	Kit.box(self, c + Vector3(0, TOWER_H * 0.5, 2.85), Vector3(6.0, TOWER_H, 0.3), TILE, tile_opts)
	for s: float in [1.0, -1.0]:
		var x: float = s * 2.85
		Kit.box(self, c + Vector3(x, TOWER_H * 0.5, -1.7), Vector3(0.3, TOWER_H, 2.0), TILE, tile_opts)
		Kit.box(self, c + Vector3(x, TOWER_H * 0.5, 1.7), Vector3(0.3, TOWER_H, 2.0), TILE, tile_opts)
		Kit.box(self, c + Vector3(x, 2.6 + (TOWER_H - 2.6) * 0.5, 0), Vector3(0.3, TOWER_H - 2.6, 1.4), TILE, tile_opts)
		var seal := Kit.box(self, c + Vector3(x, 1.3, 0), Vector3(0.3, 2.6, 1.4), TILE, {"tile": 2.0, "name": "Seal_%s" % ("E" if s > 0 else "W")})
		seals[int(s)] = seal
	# the way in, which will not be there
	var e := _m(17.5, 41.0)
	entrance_seal = Node3D.new()
	entrance_seal.name = "EntranceSeal"
	add_child(entrance_seal)
	Kit.box(entrance_seal, e + Vector3(0, H * 0.5, 0), Vector3(1.0, H, 1.0), TILE, {"tile": 2.0})
	entrance_seal.visible = false
	_set_solid(entrance_seal, false)
	_apply_seals()
	Kit.particles(self, c + Vector3(0, 2.0, 0), "motes", Vector3(14.0, 2.5, 14.0), 40)


## The tower inside the block: a stair that goes round and up, wide and
## shallow, a seam that sends it round again, and at the top the glass and
## the hatch.
func _tower() -> void:
	var c := _m(BLOCK.x, BLOCK.z)
	Kit.ceiling(self, c + Vector3(0, TOWER_H, 0), Vector2(5.4, 5.4), "wall/plaster_white", {"tile": 2.0})
	var loop_h := 5.0
	for k in 2:
		var y0 := loop_h * k
		# along the north wall going east, up 2.5; along the south wall going west, up 2.5
		Kit.stairs(self, c + Vector3(-2.5, y0, -1.95), -90.0, 1.7, 10, 0.25, 0.4, TILE, {"name": "FlightA%d" % k, "tile": 1.0})
		Kit.floor(self, c + Vector3(2.15, y0 + 2.5, -0.1), Vector2(1.3, 3.5), TILE, {"tile": 1.0})
		Kit.stairs(self, c + Vector3(2.5, y0 + 2.5, 1.95), 90.0, 1.7, 10, 0.25, 0.4, TILE, {"name": "FlightB%d" % k, "tile": 1.0})
		if k == 0:
			Kit.floor(self, c + Vector3(-2.15, y0 + 5.0, 0.1), Vector2(1.3, 3.5), TILE, {"tile": 1.0})
		Kit.light(self, c + Vector3(0, y0 + 2.2, 0), CYAN, 0.9, 7.0)
		Kit.light(self, c + Vector3(0, y0 + 4.6, 0), CYAN, 0.9, 7.0)
	# the top: a platform over the north half, the pedestal, the hatch
	Kit.floor(self, c + Vector3(0, 10.0, -0.5), Vector2(5.4, 4.0), TILE, {"tile": 1.0})
	Kit.light(self, c + Vector3(0, 12.5, -0.5), Color(0.9, 0.95, 1.0), 1.2, 8.0)
	Kit.box(self, c + Vector3(0, 10.5, -1.5), Vector3(0.6, 1.0, 0.6), "stone/marble_black", {"tile": 1.0})
	Pickup.create(self, c + Vector3(0, 11.15, -1.5), {"item": "dark_glass", "key": "picked_dark_glass", "model": "item_shard", "prompt": "Take the dark glass", "name": "DarkGlass"})
	Readable.create(self, c + Vector3(0, 11.0, -0.6), 0.0, "The pedestal", [
		"A pedestal of black marble at the top of a stair that did not want to end, and on it, until you take it, a shard of glass that shows nothing. Not you, not the room. Not even the light.",
		"It is the shape of the shard you already carry, turned over. It wants a mirror the way the other one did, and it wants a particular mirror: the one in a bedchamber, that shows a bed with somebody in it.",
	], {"name": "PedestalLook", "size": Vector3(1.6, 1.4, 1.2), "note_key": "dark_glass", "note_title": "The dark glass", "note_text": "At the top of the stair in the turning room, on a black pedestal, a shard of glass that shows nothing at all. It is the mirror shard turned over. It wants the mirror in the Keep's bedchamber."})
	Door.create(self, c + Vector3(0, 10.0, -2.55), 180.0, "cistern", "from_pipes", {"kind": "iron", "label": "A hatch, and a ladder up", "name": "Hatch", "fade_color": Color.BLACK, "fade_duration": 1.2, "sound": "door_heavy"})
	# the seam: the foot of the second loop is the foot of the first
	stair_seam = SeamlessTeleport.create(self, c + Vector3(-2.7, loop_h, -1.95), -90.0, c + Vector3(-2.7, 0.0, -1.95), -90.0, Vector3(1.9, 2.6, 0.5), {"name": "StairSeam", "count_flag": "pipes_stair_loops", "on_teleport": _on_stair_loop})
	if Game.count("pipes_stair_loops") >= LOOPS_NEEDED:
		stair_seam.enabled = false
	Puzzle.declare(self, "pipes_stair_loops", "", ["flag:pipes_opened"], "the stair goes round three times before it ends")


func _on_stair_loop(_p: Node) -> void:
	var n := Game.count("pipes_stair_loops")
	Audio.sfx("creak", global_position, -8.0)
	if n == 1:
		Game.toast.emit("The stair keeps going up.")
	elif n == 2:
		Game.toast.emit("The stair keeps going up. That is the same crack in the same tile.")
	elif n >= LOOPS_NEEDED and stair_seam:
		stair_seam.enabled = false
		Game.toast.emit("The stair, having made its point, ends.")
		Game.note("pipes_stair", "The stair in the block", "The stair inside the block went round three times, the same crack in the same tile each time, before it agreed to have a top.")


# --- the turning -----------------------------------------------------------------------------------

func _apply_seals() -> void:
	for s in seals.keys():
		_set_solid(seals[s], not (opened and int(s) == door_face))


func _set_solid(node: Node, on: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.visible = on
	_set_bodies(node, on)


func _set_bodies(node: Node, on: bool) -> void:
	if node is StaticBody3D:
		(node as StaticBody3D).collision_layer = Kit.L_WORLD if on else 0
	for ch in node.get_children():
		_set_bodies(ch, on)


## Going round the block the way the water goes. A quarter of the way round,
## the doorway you came in by is a wall. Three times round, the block gives
## up a doorway on the face you are nearest, and the stair is inside it.
func _process(_delta: float) -> void:
	if opened:
		return
	var p := player()
	if p == null or World.traveling:
		return
	var c := _m(BLOCK.x, BLOCK.z)
	var d := p.global_position - c
	if absf(d.x) > 9.0 or absf(d.z) > 9.0:
		_have_angle = false
		return
	var a := rad_to_deg(atan2(d.z, d.x))
	if not _have_angle:
		_have_angle = true
		_last_angle = a
		return
	var delta := wrapf(a - _last_angle, -180.0, 180.0)
	_last_angle = a
	_progress = maxf(0.0, _progress + delta)
	if not entrance_sealed and _progress >= 90.0:
		entrance_sealed = true
		_set_solid(entrance_seal, true)
		Audio.sfx("stone_grind", c, -6.0)
		Game.toast.emit("Behind you, the way you came in is a wall.")
	var laps := int(_progress / 360.0)
	if laps > _laps_told and laps < LAPS_NEEDED:
		_laps_told = laps
		Game.toast.emit(["", "Once round. The block has nothing on it.", "Twice round. It is not a block. It is a thing that is waiting."][laps])
	if _progress >= 360.0 * LAPS_NEEDED:
		door_face = 1 if d.x >= 0.0 else -1
		_open(c)


func _open(c: Vector3) -> void:
	opened = true
	Game.set_flag("pipes_opened", true)
	_apply_seals()
	Audio.sfx("door_heavy", c, -4.0)
	Game.toast.emit("The block gives up. There is a doorway in it, and a stair.")
	Game.note("pipes_turned", "The block gives up", "You went round the block in the turning room the way the water goes, and the way in closed behind you, and on the third time round the block opened and there was a stair inside.")
