extends AreaBase
## The Cistern — the bathhouse of a god who never came back. White tile to the
## ceiling, cyan tile to the horizon, water on every floor. A great sunken
## bath in a hall the size of a cathedral, and behind it corridors of
## knee-deep water that go round, and one that only goes on. Somebody in
## the corridors is reading aloud from a journal you know. Follow the voice
## and there is a torn page at the end of it.
##
## The drain at the far end goes down to the Nowhere House's basement (the
## basement stair goes down to here, so: down is the same as down).
##
## Built as ONE rasterised map on a 2 m grid (H 4.5); the basin uses the
## MapBuilder's water cells (floor drops 0.6 m) with tiled rims and ramps.

const CELL := 2.0
const H := 4.5
const ORIGIN := Vector3(-28.0, 0.0, -22.0)
const W := 28
const D := 22

var water_level := 0.12
var drained := false          # the well in the Anteroom has been given all nine keepsakes
var float_node: Node3D = null
var _float_spots: Array = []
var _float_i := 0
var rain: CPUParticles3D = null
var voice_step := 0


func build() -> void:
	drained = Game.has_flag("cistern_drained")
	water_level = 0.12 if visit_count < 2 else 0.3
	Realm.apply(self, "cistern", {"ambient_energy": 1.0})
	_plan()
	_entry_hall()
	_pool_hall()
	_corridors()
	_shower_alcove()
	_drain_room()
	_voice()
	_presences()
	Puzzle.declare(self, "cistern_loops", "cistern_shell_found", [], "walk the corridor that only goes on until it gives up")
	Puzzle.declare(self, "cistern_page", "", [], "follow the voice reading aloud through the flooded corridors", {"item": "page"})
	Puzzle.declare(self, "cistern_great_drain", "", ["flag:cistern_drained"], "with the water gone, the drain at the bottom of the great bath goes down", {"route": "pipes:from_cistern"})


# --- coordinates: plan metres -> world -------------------------------------------------------

func _m(x: float, z: float, y: float = 0.0) -> Vector3:
	return Vector3(ORIGIN.x + x, y, ORIGIN.z + z)


func _cell(cx: float, cz: float, y: float = 0.0) -> Vector3:
	return _m((cx + 0.5) * CELL, (cz + 0.5) * CELL, y)


func _lamp(x: float, z: float, energy: float = 1.1, reach: float = 11.0, y: float = H - 0.4) -> void:
	Kit.light(self, _m(x, z, y), Color(0.82, 0.96, 1.0), energy, reach)
	Kit.box(self, _m(x, z, H - 0.06), Vector3(0.9, 0.12, 0.9), "wall/plaster_white", {"unshaded": true, "tint": Color(1.6, 1.7, 1.7), "solid": false})


## Flooded floor: a water plane over a rectangle of cells (x0, z0 inclusive; x1, z1 exclusive).
func _flood(x0: int, z0: int, x1: int, z1: int) -> void:
	if drained:
		return
	var c := _m((x0 + x1) * 0.5 * CELL, (z0 + z1) * 0.5 * CELL, water_level)
	Kit.water(self, c, Vector2((x1 - x0) * CELL, (z1 - z0) * CELL), "nature/water_cistern", {"tint": Color(1, 1, 1, 0.55), "subdiv": 6})


# --- the plan -------------------------------------------------------------------------------------

func _plan() -> void:
	var rects := [
		[1, 1, 8, 6, "e"],       # entry hall (dry)
		[9, 1, 27, 13, "p"],     # the great bath hall
		[12, 3, 24, 10, "~"],    # the basin (floor drops 0.6)
		[1, 7, 8, 9, "f"],       # west corridor
		[1, 9, 3, 21, "f"],      # south-west corridor
		[3, 19, 27, 21, "f"],    # south corridor
		[25, 14, 27, 19, "f"],   # east corridor
		[12, 14, 14, 18, "o"],   # the corridor that only goes on
		[18, 14, 20, 18, "f"],   # a dead end with a bench
		[4, 11, 8, 14, "h"],     # the showers
		[21, 15, 24, 18, "g"],   # the drain room
	]
	var doors := [
		[8, 3, "D"], [8, 4, "D"],     # entry -> bath hall
		[4, 6, "D"],                  # entry -> west corridor
		[25, 13, "D"], [26, 13, "D"], # bath hall -> east corridor
		[12, 18, "D"],                # south corridor -> the corridor that only goes on
		[18, 18, "D"],                # south corridor -> dead end
		[3, 12, "D"],                 # south-west corridor -> showers
		[24, 16, "D"],                # east corridor -> drain room
	]
	if visit_count >= 2:
		doors.append([12, 13, "D"])   # the corridor that only went on now goes through
	var rows := MapBuilder.rasterize(W, D, rects, doors)
	var rooms := {
		"e": {"floor": "wall/tile_checker", "wall": "wall/tile_cyan", "ceiling": "wall/plaster_white"},
		"p": {"floor": "wall/tile_white", "wall": "wall/tile_white", "ceiling": "wall/plaster_white"},
		"f": {"floor": "wall/tile_white", "wall": "wall/tile_cyan", "ceiling": "wall/plaster_white"},
		"o": {"floor": "wall/tile_white", "wall": "wall/tile_white", "ceiling": "wall/plaster_white"},
		"h": {"floor": "wall/tile_checker", "wall": "wall/tile_bath", "ceiling": "wall/plaster_white"},
		"g": {"floor": "wall/concrete", "wall": "wall/tile_cyan", "ceiling": "wall/concrete_dark"},
	}
	MapBuilder.build(self, rows, {
		"cell": CELL, "height": H, "origin": ORIGIN, "door_h": 3.0, "tile": 2.0,
		"floor": "wall/tile_white", "wall": "wall/tile_cyan", "ceiling": "wall/plaster_white",
		"water": "nature/water_cistern", "water_floor": "wall/tile_cyan",
		"water_opts": {"tint": Color(1, 1, 1, 0.6), "subdiv": 2}, "no_water": drained,
		"rooms": rooms, "outer_faces": true, "name": "Cistern",
	})


# --- the entry hall (cells x 1-8, z 1-6) --------------------------------------------------------

func _entry_hall() -> void:
	# the tiled door back to the Anteroom, in the west wall
	Door.create(self, _m(2.16, 7.0), -90.0, "nexus", "from_cistern", {"kind": "white", "label": "A tiled door", "name": "TiledDoor", "fade_color": Color(0.1, 0.3, 0.32), "fade_duration": 0.9})
	Kit.light(self, _m(3.2, 7.0, 3.0), Color(0.9, 1.0, 1.0), 0.9, 6.0)
	add_spawn("from_nexus", _m(3.6, 7.0, 0.1), -90.0)
	add_spawn("default", _m(8.0, 7.0, 0.1), -90.0)
	for z in [3.4, 10.6]:
		Props.place(self, "tiled_bench", _m(6.0, z), 0.0 if z < 7.0 else 180.0, 1.0)
		Props.place(self, "tiled_bench", _m(11.0, z), 0.0 if z < 7.0 else 180.0, 1.0)
	Props.place(self, "pool_float", _m(13.5, 10.6, 0.05), 20.0, 1.0, {"collision": "none"})
	Readable.create(self, _m(6.0, 2.2, 1.8), 180.0, "A tiled sign", ["NO RUNNING. NO DIVING. NO REMEMBERING.", "The last word has been added in a different grout."], {"name": "RulesSign", "size": Vector3(1.6, 0.8, 0.3), "sign": "wall/paper", "sign_size": Vector2(1.2, 0.5)})
	Readable.create(self, _m(11.0, 2.2, 1.6), 180.0, "A tide mark", ["A brown line runs round the walls at the height of your chest.", "Above it, a second line at the height of your eyes. Above that, a third, fainter, that you have to look up for."], {"name": "TideMark", "size": Vector3(2.0, 1.2, 0.3), "note_key": "cistern_tide", "note_title": "Tide marks", "note_text": "The Cistern has been fuller than this. Three times at least, each time higher. The bath in the flat has a ring like it."})
	Readable.create(self, _m(2.2, 4.0, 1.5), -90.0, "A locker", ["A tiled locker with no door. Inside: one shoe, a towel folded with hospital precision, a key with no number.", "You leave the key. Something in the water would want it."], {"name": "Locker", "size": Vector3(0.4, 1.4, 1.0)})
	Kit.sign(self, "props/rune_ring", _m(2.05, 4.0, 1.5), -90.0, Vector2(0.8, 1.4), {"tint": Color(0.7, 0.8, 0.8)})
	_lamp(6.0, 7.0)
	_lamp(12.0, 7.0)
	Kit.particles(self, _m(8.0, 7.0, 2.0), "motes", Vector3(6.0, 1.5, 4.0), 24)


# --- the great bath hall (cells x 9-27, z 1-13; basin x 12-24, z 3-10) ----------------------------

func _pool_hall() -> void:
	# tiled rims round the basin, so the drop is a bath and not a hole
	var bx0 := 12.0 * CELL
	var bx1 := 24.0 * CELL
	var bz0 := 3.0 * CELL
	var bz1 := 10.0 * CELL
	var rim := "wall/tile_cyan"
	Kit.box(self, _m((bx0 + bx1) * 0.5, bz0 + 0.05, -0.3), Vector3(bx1 - bx0, 0.6, 0.1), rim, {"faces": ["pz"], "solid": false})
	Kit.box(self, _m((bx0 + bx1) * 0.5, bz1 - 0.05, -0.3), Vector3(bx1 - bx0, 0.6, 0.1), rim, {"faces": ["nz"], "solid": false})
	Kit.box(self, _m(bx0 + 0.05, (bz0 + bz1) * 0.5, -0.3), Vector3(0.1, 0.6, bz1 - bz0), rim, {"faces": ["px"], "solid": false})
	Kit.box(self, _m(bx1 - 0.05, (bz0 + bz1) * 0.5, -0.3), Vector3(0.1, 0.6, bz1 - bz0), rim, {"faces": ["nx"], "solid": false})
	# ramps in at the west and east ends, ladders elsewhere
	Kit.ramp(self, _m(bx0 + 2.0, (bz0 + bz1) * 0.5, -0.6), 90.0, 3.0, 2.0, 0.6, "wall/tile_white")
	Kit.ramp(self, _m(bx1 - 2.0, (bz0 + bz1) * 0.5, -0.6), -90.0, 3.0, 2.0, 0.6, "wall/tile_white")
	for x in [bx0 + 6.0, (bx0 + bx1) * 0.5, bx1 - 6.0]:
		Props.place(self, "pool_ladder", _m(x, bz0 + 0.3), 180.0, 1.0, {"collision": "none"})
		Props.place(self, "pool_ladder", _m(x, bz1 - 0.3), 0.0, 1.0, {"collision": "none"})
	# tiled pillars along the dry margins
	for i in 6:
		var x := bx0 + 2.0 + i * 4.4
		Props.place(self, "pillar_tiled", _m(x, bz0 - 2.5), 0.0, 1.0, {"collision": "cylinder"})
		Props.place(self, "pillar_tiled", _m(x, bz1 + 2.5), 0.0, 1.0, {"collision": "cylinder"})
	# the lifeguard's chair, and the lifeguard, who has climbed down
	Props.place(self, "lifeguard_chair", _m((bx0 + bx1) * 0.5, bz1 + 3.6), 0.0, 1.0)
	Readable.create(self, _m((bx0 + bx1) * 0.5, bz1 + 3.6, 2.2), 0.0, "The lifeguard's log", ["LOG. Day one: nobody drowned.", "Day two: nobody drowned.", "Day four hundred: nobody drowned. I have started to wonder whether that is the point of me.", "Day (illegible): somebody came up."], {"name": "LifeguardLog", "size": Vector3(1.2, 1.6, 1.2), "note_key": "cistern_log", "note_title": "The lifeguard's log", "note_text": "Nobody drowned in the Cistern for four hundred days. Then somebody came up."})
	NPC.create(self, _m((bx0 + bx1) * 0.5 + 2.4, bz1 + 3.2), 0.0, "The Lifeguard", {
		"model": "figure_shadow", "face_player": true, "flee_knife": true,
		"lines": ["Nobody is in the water. There is no water.", "Somebody came up. Now somebody has to go down. I do not think it is me.", "I do not know what I am for now."] if drained else ["You are not supposed to be in the water in your clothes.", "You are not supposed to be in the water.", "Nobody is supposed to be in the water. That is what the water is for."],
		"reactions": {
			"umbrella": ["An umbrella. Indoors. The god used to hate that.", "It would rain, to make a point."],
			"mouse": ["Small things go down the drain. That is where the small things went."],
			"lantern": ["Put that out. You will see what is at the bottom, and then so will it."],
			"shard": ["Do not hold that over the water.", "The water has enough of its own reflections to be getting on with."],
		},
	})
	# the far wall: a great drain and the god's tap
	Props.place(self, "fountain_head", _m(bx1 + 4.0, bz0 - 1.95, 2.4), 180.0, 2.0, {"collision": "none"})
	if drained:
		Readable.create(self, _m(bx1 + 4.0, bz0 - 1.5, 2.0), 180.0, "The tap", ["A tap the size of a door, not dripping.", "It has stopped. Nothing here has ever stopped before."], {"name": "GodTap", "size": Vector3(1.6, 1.6, 1.0)})
	else:
		Kit.particles(self, _m(bx1 + 4.0, bz0 - 1.4, 1.6), "rain", Vector3(0.3, 0.8, 0.3), 30)
		Kit.water(self, _m(bx1 + 4.0, bz0 - 0.9, 0.06), Vector2(3.0, 2.0), "nature/water_cistern", {"tint": Color(1, 1, 1, 0.5), "subdiv": 2})
		Readable.create(self, _m(bx1 + 4.0, bz0 - 1.5, 2.0), 180.0, "The tap", ["A tap the size of a door, dripping.", "The drip takes a long time to fall, and when it lands it is already gone."], {"name": "GodTap", "size": Vector3(1.6, 1.6, 1.0), "sound": "drip"})
	Props.place(self, "drain_grate", _m(bx0 - 3.0, bz1 + 1.0, 0.01), 0.0, 1.5, {"collision": "none"})
	Readable.create(self, _m(bx0 - 3.0, bz1 + 1.0, 0.3), 0.0, "A drain", ["Hair, and a ring, and the sound of a much bigger room underneath."], {"name": "Drain1", "size": Vector3(1.2, 0.5, 1.2)})
	# a float that is somewhere else when you look back
	_float_spots = [_m(bx0 + 5.0, bz0 + 4.0, -0.2), _m(bx1 - 6.0, bz1 - 3.0, -0.2), _m((bx0 + bx1) * 0.5, (bz0 + bz1) * 0.5, -0.2), _m(bx0 + 3.0, bz1 - 2.0, -0.2)]
	float_node = Props.place(self, "pool_float", _float_spots[0], 30.0, 1.0, {"collision": "none", "name": "WanderingFloat"})
	LookAway.create(self, _float_spots[0], _on_float_unseen, {"delay": 1.5, "radius": 30.0, "once": false, "require_seen_first": true, "name": "FloatWatch"})
	# the bath's writing, on the bottom, readable only when you are in it
	Readable.create(self, _m((bx0 + bx1) * 0.5, (bz0 + bz1) * 0.5, -0.4), 0.0, "Tiles on the bottom", ["Spelled out in darker tiles on the bottom of the bath: A HUNDRED YEARS IS NOT LONG TO HOLD YOUR BREATH.", "The tiles continue under the ladder, where you cannot read them."], {"name": "BottomTiles", "size": Vector3(4.0, 0.6, 2.0), "note_key": "cistern_bottom", "note_title": "The bottom of the bath", "note_text": "Written in darker tiles on the bottom of the great bath: A HUNDRED YEARS IS NOT LONG TO HOLD YOUR BREATH."})
	if visit_count >= 2 and Props.exists("figure_shadow"):
		Props.place(self, "figure_shadow", _m((bx0 + bx1) * 0.5, bz1 + 3.6, 1.7), 0.0, 0.8, {"collision": "none", "name": "ChairShadow"})
	if drained:
		_dry_bottom(bx0, bx1, bz0, bz1)
	else:
		add_spawn("from_pipes", _m((bx0 + bx1) * 0.5 + 2.4, (bz0 + bz1) * 0.5 + 1.2, -0.55), 90.0)
	# lamps
	for i in 4:
		for j in 3:
			_lamp(bx0 - 1.0 + i * 8.6, bz0 - 1.0 + j * 8.0, 1.2, 12.0)
	_lamp(bx1 + 3.5, 7.0)
	Kit.particles(self, _m((bx0 + bx1) * 0.5, (bz0 + bz1) * 0.5, 1.5), "motes", Vector3(10.0, 1.5, 6.0), 40)
	Kit.label(self, "DEEP END", _m(bx1 - 1.0, bz0 - 1.98, 2.6), 180.0, 36, Color(0.3, 0.5, 0.55), "display", {"pixel_size": 0.012})
	Kit.label(self, "DEEP END", _m(bx0 + 1.0, bz0 - 1.98, 2.6), 180.0, 36, Color(0.3, 0.5, 0.55), "display", {"pixel_size": 0.012})


## The bottom of the great bath with the water gone: what it was keeping, and
## the drain the size of a door that was under all of it. The way down through
## it is the fourth road, and its end is not made yet.
func _dry_bottom(bx0: float, bx1: float, bz0: float, bz1: float) -> void:
	var cx := (bx0 + bx1) * 0.5
	var cz := (bz0 + bz1) * 0.5
	var c := _m(cx, cz, -0.59)
	Kit.cylinder(self, c - Vector3(0, 0.03, 0), 1.5, 0.025, "stone/blocks_dark", {"solid": false, "segments": 24, "mat": Kit.flat(Color(0.02, 0.02, 0.03), {"unshaded": true})})
	Props.place(self, "drain_grate", c + Vector3(0, 0.01, 0), 0.0, 3.2, {"collision": "none", "name": "GreatDrainGrate"})
	Kit.light(self, c + Vector3(0, 1.6, 0), Color(0.5, 0.7, 0.75), 0.9, 8.0)
	var down := Door.create(self, c, 0.0, "pipes", "from_cistern", {"kind": "none", "label": "Go down the drain", "name": "GreatDrainDown", "fade_color": Color.BLACK, "fade_duration": 1.5, "sound": "splash"})
	down.add_box(Vector3(2.6, 1.2, 2.6), Vector3(0, 0.5, 0))
	Readable.create(self, c + Vector3(2.2, 0.5, 0), 0.0, "Look down the drain", [
		"The drain at the bottom of the bath, the size of a door, with no water over it for the first time in a hundred years.",
		"Air comes up out of it, warm, in a slow rhythm: once for every four of your breaths. Whatever is down there is breathing, and you know the rate.",
	], {"name": "GreatDrainLook", "size": Vector3(1.4, 1.0, 2.0), "note_key": "cistern_great_drain", "note_title": "The drain the size of a door", "note_text": "At the bottom of the emptied bath in the Cistern is a drain the size of a door. Warm air comes up out of it once for every four of your breaths. It goes down to the Waterworks."})
	add_spawn("from_pipes", c + Vector3(2.4, 0.05, 1.2), 90.0)
	# what the water was keeping
	var kept := ["bottle", "mug", "teacup_stack", "shell", "candle", "bottle", "mug"]
	for k in kept.size():
		var p := _m(bx0 + 2.0 + k * 3.1, bz0 + 1.2 + (k % 3) * 2.6, -0.6)
		Props.place(self, String(kept[k]), p, k * 50.0, 0.9, {"collision": "none"})
	Readable.create(self, _m(bx0 + 4.0, bz0 + 2.4, -0.3), 0.0, "What the water was keeping", [
		"Under where the water was: a shoe, a ring, cups, a key with no number, a great many small things that went down and did not fit down the drain.",
		"A tide mark on the inside of the bath, one, at the very top. It was full once and never fuller.",
		"Under the ladder the tiles go on: ...TO HOLD YOUR BREATH. THE OTHER HALF OF YOU IS HOLDING IT TOO.",
	], {"name": "DryBottom", "size": Vector3(4.0, 1.0, 3.0), "note_key": "cistern_dry", "note_title": "The bath, empty", "note_text": "The great bath in the Cistern has drained. On the bottom, what the water was keeping, and the rest of the writing under the ladder: the other half of you is holding it too. In the middle, a drain the size of a door."})


# --- the flooded corridors -------------------------------------------------------------------------

func _corridors() -> void:
	_flood(1, 7, 8, 9)
	_flood(1, 9, 3, 21)
	_flood(3, 19, 27, 21)
	_flood(25, 14, 27, 19)
	_flood(12, 14, 14, 18)
	_flood(18, 14, 20, 18)
	_flood(4, 11, 8, 14)
	_flood(21, 15, 24, 18)
	# lamps every few metres, a few of them dead
	var lamp_cells := [[4, 7.5], [1.5, 12], [1.5, 17], [5, 19.5], [10, 19.5], [15, 19.5], [20, 19.5], [25, 19.5], [25.5, 15.5], [12.5, 15.5], [18.5, 15.5], [22, 16.5]]
	var k := 0
	for lc in lamp_cells:
		k += 1
		if k % 5 == 0:
			continue
		_lamp((float(lc[0]) + 0.5) * CELL, (float(lc[1]) + 0.5) * CELL, 1.0, 10.0)
	# drains and benches and things left behind
	Props.place(self, "drain_grate", _cell(1.5, 14, 0.01), 0.0, 1.2, {"collision": "none"})
	Props.place(self, "drain_grate", _cell(15, 19.5, 0.01), 90.0, 1.2, {"collision": "none"})
	Props.place(self, "tiled_bench", _cell(18.5, 14.3), 180.0, 1.0)
	Readable.create(self, _cell(18.5, 14.3, 0.8), 180.0, "A bench at a dead end", ["Somebody has sat here long enough to leave a shape.", "On the wall beside it, in wet fingerprints: I COUNTED THE TILES. DO NOT COUNT THE TILES."], {"name": "DeadEndBench", "size": Vector3(2.0, 1.0, 1.0), "note_key": "cistern_bench", "note_title": "Do not count the tiles", "note_text": "Somebody in the Cistern counted the tiles and wrote on the wall telling you not to. You counted forty-one in a bathroom once."})
	Props.place(self, "pool_float", _cell(9, 19.7, 0.15), 70.0, 1.0, {"collision": "none"})
	Props.place(self, "shell", _cell(1.5, 10, 0.12), 0.0, 1.4, {"collision": "none"})
	Readable.create(self, _cell(1.5, 10, 0.3), 0.0, "A shell", ["You hold it to your ear. The sound of a very large room, and, underneath, the sea; and, underneath that, a bathroom tap running."], {"name": "Shell1", "size": Vector3(0.8, 0.5, 0.8), "sound": "drip"})
	# the corridor that only goes on: a seam that folds its far end back onto its near end
	var o_near := _cell(12.5, 17.2)
	var o_far := _cell(12.5, 14.4)
	var seam := SeamlessTeleport.create(self, o_far, 0.0, o_near, 0.0, Vector3(3.6, H, 0.6), {"name": "OnlyOn", "count_flag": "cistern_loops", "on_teleport": _on_only_on})
	if Game.count("cistern_loops") >= 3 or visit_count >= 2:
		seam.enabled = false
		if not Game.has_flag("cistern_shell_found"):
			Props.place(self, "orb", _cell(12.5, 14.2, 0.6), 0.0, 0.6, {"collision": "none", "name": "OrbShell"})
			Kit.light(self, _cell(12.5, 14.2, 1.2), Color(0.6, 1.0, 1.0), 1.2, 5.0)
			Interactable.make(self, _cell(12.5, 14.2, 0.6), Vector3(0.8, 0.8, 0.8), "Take the glass float", func(_p: Node, it: Node) -> void:
				Game.set_flag("cistern_shell_found", true)
				Audio.sfx("pickup", it.global_position, -6.0)
				Game.note("cistern_orb", "The glass float", "At the end of the corridor that only went on there was a glass float, the kind fishermen lose. It is warm. It hums when you are near water, which is always.")
				Game.toast.emit("A glass float. It hums when you are near water.")
				it.queue_free()
				var orb := get_node_or_null("OrbShell")
				if orb:
					orb.queue_free(), {"name": "OrbTake"})
	Readable.create(self, _cell(12.5, 17.5, 1.6), 180.0, "Writing on the tile", ["Scratched into the tile at the mouth of the corridor: it only goes on.", "Underneath, in a different hand: until it doesn't."], {"name": "OnlyOnSign", "size": Vector3(1.6, 0.8, 0.3)})
	Kit.sign(self, "wall/paper", _cell(12.5, 17.98, 1.6), 0.0, Vector2(1.0, 0.5), {"tint": Color(0.8, 0.9, 0.9)})


# --- the showers, and the page ---------------------------------------------------------------------

func _shower_alcove() -> void:
	for i in 4:
		var x := 9.0 + i * 1.6
		Props.place(self, "shower_head", _m(x, 22.2, 2.6), 180.0, 1.0, {"collision": "none"})
	Kit.particles(self, _m(11.4, 22.6, 2.0), "rain", Vector3(3.0, 0.6, 0.4), 40)
	Kit.light(self, _m(12.0, 25.0, 3.6), Color(0.85, 1.0, 1.0), 1.0, 8.0)
	Props.place(self, "tiled_bench", _m(14.6, 26.6), 0.0, 1.0)
	# the torn page, on the bench, out of the water
	Pickup.create(self, _m(14.6, 26.6, 0.55), {"item": "page", "name": "TornPage"})
	Readable.create(self, _m(9.4, 27.8, 1.5), 0.0, "Wet handwriting", ["On the tile, in water that does not dry: THE HOUSE IS THE SAME HOUSE. IT IS THE SAME HOUSE.", "It is the handwriting from the journal in the Nowhere House, the second half of it."], {"name": "ShowerWriting", "size": Vector3(1.6, 0.9, 0.3), "note_key": "cistern_writing", "note_title": "The same house", "note_text": "Somebody wrote on the shower tiles in the Cistern, in the second handwriting from the house journal: the house is the same house."})


# --- the drain room, and the way down ---------------------------------------------------------------

func _drain_room() -> void:
	var c := _cell(22, 16)
	Props.place(self, "drain_grate", c + Vector3(0, 0.01, 0), 0.0, 2.2, {"collision": "none"})
	Props.place(self, "pool_ladder", c + Vector3(-1.2, 0, 0), 90.0, 1.0, {"collision": "none"})
	var down := Door.create(self, c + Vector3(-1.2, 0, 0), 90.0, "house", "basement", {"kind": "none", "label": "Climb down the drain", "name": "DrainDown", "fade_color": Color.BLACK, "fade_duration": 1.2, "sound": "step_metal", "sets_flag": "cistern_drain_used"})
	down.add_box(Vector3(1.4, 2.4, 1.4), Vector3(0, 1.2, 0))
	Kit.light(self, c + Vector3(0, 3.0, 0), Color(0.7, 0.9, 0.9), 0.9, 8.0)
	Kit.light(self, c + Vector3(0, 0.3, 0), Color(0.3, 0.7, 0.8), 0.6, 4.0)
	Readable.create(self, c + Vector3(2.0, 1.5, -1.9), 180.0, "A sign above the drain", ["DOWN IS THE SAME AS DOWN.", "You have read that before, on a pipe, in a basement, going the other way."], {"name": "DrainSign", "size": Vector3(1.6, 0.8, 0.3), "sign": "wall/paper", "sign_size": Vector2(1.2, 0.5), "note_key": "cistern_drain", "note_title": "Down is the same as down", "note_text": "The drain in the Cistern goes down to the basement of the Nowhere House. The basement stair goes down to the Cistern. Down is the same as down."})
	Props.place(self, "urn", c + Vector3(2.2, 0, 1.6), 0.0, 1.0)
	Props.place(self, "chain_hanging", c + Vector3(1.0, H - 0.1, 1.2), 0.0, 1.0, {"collision": "none"})
	add_spawn("from_basement", c + Vector3(0.6, 0.1, 0), 90.0)


# --- the voice: follow the reading through the corridors -------------------------------------------

func _voice() -> void:
	# each step plays the reading a little further along the way to the showers
	var steps := [
		[_cell(4, 7.5), _cell(1.5, 9.5), "…the bathroom is the same size as yesterday. good…"],
		[_cell(1.5, 10.5), _cell(1.5, 13.0), "…M. says the photographs have moved. M. moves them…"],
		[_cell(1.5, 13.5), _cell(5.0, 12.5), "…hot is on the left now. nobody moved the taps…"],
		[_cell(5.0, 12.5), _cell(7.0, 13.2), "…the house is the same house. it is the same house…"],
	]
	for i in steps.size():
		var s: Array = steps[i]
		var at: Vector3 = s[0]
		var next: Vector3 = s[1]
		var line: String = s[2]
		Kit.trigger(self, at + Vector3(0, 1.2, 0), Vector3(CELL * 1.8, 3.0, CELL * 1.8), func(_p: Node) -> void:
			if voice_step != i or Game.has_item("page"):
				return
			voice_step += 1
			Audio.sfx("whisper", next, -4.0)
			Game.toast.emit("Somebody, further along, reading aloud: %s" % line)
			if i == 0 and not Game.has_note("cistern_voice"):
				Game.note("cistern_voice", "The reading voice", "Somebody in the flooded corridors of the Cistern is reading aloud from the house journal. Always a little further along."), {"name": "Voice%d" % i, "once": true})


# --- presences --------------------------------------------------------------------------------------

func _presences() -> void:
	Usher.spawn(self, _cell(20, 19.5), {"appear_delay": 5.0, "radius": 40.0})
	Dog.maybe_spawn(self, _m(10.0, 7.0, 0.1))
	rain = Kit.particles(self, _m(20.0, 14.0, H - 0.5), "rain", Vector3(14.0, 0.5, 10.0), 160)
	rain.emitting = Game.umbrella_open


# --- hooks ------------------------------------------------------------------------------------------

func on_umbrella(open: bool) -> void:
	if rain:
		rain.emitting = open
	if open and not Game.has_note("cistern_rain"):
		Game.note("cistern_rain", "Rain indoors", "Opening the umbrella in the Cistern makes it rain from the ceiling. The lifeguard says the god used to do that to make a point.")


func _on_float_unseen(_l: Node) -> void:
	if float_node == null or not is_instance_valid(float_node):
		return
	_float_i = (_float_i + 1) % _float_spots.size()
	float_node.position = _float_spots[_float_i]
	var la := get_node_or_null("FloatWatch")
	if la:
		la.position = _float_spots[_float_i]


func _on_only_on(_p: Node) -> void:
	var n := Game.count("cistern_loops")
	Audio.sfx("splash", player_pos(), -10.0)
	if n == 1:
		Game.toast.emit("The corridor goes on. You are fairly sure it was shorter.")
	elif n == 2:
		Game.toast.emit("The corridor goes on. The same drain, the same dead lamp.")
	elif n >= 3:
		var seam := get_node_or_null("OnlyOn")
		if seam:
			seam.set("enabled", false)
		Game.toast.emit("The corridor, having made its point, ends.")
		World.reload_here("default", {"duration": 0.3, "silent": true})


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if n == 1:
		Game.note("cistern", "The Cistern", "A bathhouse for something the size of a god. White tile, cyan tile, water on every floor. The lifeguard has climbed down from the chair.")
	if n == 2:
		Game.note("cistern_higher", "Higher water", "The water in the Cistern is higher the second time. The corridor that only went on has decided to go through.")
	if drained and not Game.has_note("cistern_drained"):
		Game.note("cistern_drained", "The Cistern, drained", "The water has gone out of the Cistern, all of it, down the drain at the bottom of the great bath. The tap has stopped. The lifeguard does not know what he is for.")
		Game.toast.emit("The water has gone. All of it.")
