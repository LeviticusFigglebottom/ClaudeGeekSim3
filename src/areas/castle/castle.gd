extends AreaBase
## The Keep of Hours — a gothic keep at night where every clock has stopped.
## A courtyard open to the sky, a great hall laid for sleepers, a throne room
## where the King sleeps and must not be woken, a chapel of stopped time, two
## bedchambers, and three impossible things: rooms whose walls turn so their
## doorways only line up at moments (the Hourglass steadies them), a tapestry
## behind the throne that hides the King's dream, and a library that does not
## end.
##
## The keep is ONE rasterised map (1 m cells, real wall cells, per-room floors
## and ceilings, outer faces drawn). The turning rooms and the library are
## separate structures hung on doorway cells of that map: they meet it only at
## a doorway and bring their own edge walls.
##
## World layout (metres): the gate at z=11.5 on the south; the courtyard z 1..11;
## the great hall z -13..0; the throne room z -25..-14; the chapel x 12..21; the
## west wing x -20..-12; the library north of the chapel; the turning rooms west
## of the courtyard; the King's dream north of everything, up a stair, in the sky.

const CELL := 1.0
const H := 6.0
const DOOR_H := 3.4
const ORIGIN := Vector3(-21, 0, -30)
const W := 43
const D := 42

const WARM := Color(1.0, 0.72, 0.42)
const CANDLE := Color(1.0, 0.85, 0.6)
const COLD := Color(0.62, 0.66, 0.95)
const MOON := Color(0.72, 0.7, 0.95)
const PETRIFIED := Color(0.6, 0.6, 0.66)

## The turning rooms: a rotating inner wall inside a fixed stone sleeve.
const R_WALL := 3.5
const R_SLEEVE := 4.05
const ROOM_H := 4.0
const SLEEVE_SEGS := 24
const WALL_SEGS := 16
const HOURS_Z := 6.5
const VEST_LEN := 2.3
const PASS_LEN := 1.6
const ROOM_SPEEDS := [12.0, -10.0, 14.0]

## The library aisle: x 14..20, from the chapel's north wall at z=-13 to z=-54.
const LIB_X := 17.0
const LIB_ROWS := 40

var king: NPC = null
var knight: NPC = null
var fire_lights: Array = []
var flames: Array = []
var open_book: Node3D = null
var closed_book: Node3D = null
var chest_lid: Node3D = null
var chest_it: Interactable = null
var chest_pos := Vector3.ZERO
var usher_summoned := false
var steadied := false
var _t := 0.0


func build() -> void:
	Realm.apply(self, "castle", {"ambient_energy": 0.9, "sky_opts": {"detail_strength": 0.9}})
	_plan()
	_courtyard()
	_great_hall()
	_throne_room()
	_kings_dream()
	_chapel()
	_west_wing()
	_library()
	_turning_rooms()
	Puzzle.declare(self, "castle_rooms", "", [], "wait for the turning rooms to line up; the hourglass steadies them")
	Puzzle.declare(self, "castle_tapestry", "tapestry_cut", ["keepsake:knife"], "cut the tapestry behind the throne")
	Puzzle.declare(self, "castle_king", "king_disturbed", [], "whisper to the sleeping King three times; something tall comes to see")
	add_spawn("default", Vector3(0, 0.1, 9.0), 0.0)
	add_spawn("from_nexus", Vector3(0, 0.1, 9.0), 0.0)
	add_spawn("hall", Vector3(0, 0.1, -2.0), 0.0)
	add_spawn("throne", Vector3(0, 0.1, -16.5), 0.0)
	add_spawn("chapel", Vector3(13.5, 0.1, -6.0), -90.0)
	add_spawn("library", Vector3(LIB_X, 0.1, -16.0), 0.0)
	add_spawn("hours", Vector3(-11.15, 0.1, HOURS_Z), 90.0)
	add_spawn("dream", Vector3(0, 3.1, -36.5), 0.0)
	add_spawn("wardrobe", Vector3(-17.6, 0.1, -3.0), 0.0)
	Dog.maybe_spawn(self, Vector3(2.4, 0.1, 7.2))


# --- the plan ----------------------------------------------------------------------

func _plan() -> void:
	# rects are [x0, z0, x1, z1, room] in cells; x1/z1 exclusive. World = cell + ORIGIN.
	var rects := [
		[20, 1, 22, 4, "p"],      # passage behind the throne   x -1..1    z -29..-26
		[15, 5, 27, 16, "t"],     # throne room                 x -6..6    z -25..-14
		[20, 5, 22, 16, "s"],     # its carpet
		[10, 17, 32, 30, "h"],    # great hall                  x -11..11  z -13..0
		[20, 17, 22, 30, "r"],    # the runner
		[33, 18, 42, 29, "k"],    # chapel of the clock         x 12..21   z -12..-1
		[7, 18, 9, 29, "w"],      # west corridor               x -14..-12 z -12..-1
		[1, 18, 6, 23, "a"],      # bedchamber A                x -20..-15 z -12..-7
		[1, 24, 6, 29, "b"],      # bedchamber B                x -20..-15 z -6..-1
		[12, 31, 30, 41, ":"],    # courtyard, open to the sky  x -9..9    z 1..11
	]
	var doors := [
		[20, 41, "D"], [21, 41, "D"],                                  # the gate (south edge)
		[19, 30, "D"], [20, 30, "D"], [21, 30, "D"], [22, 30, "D"],    # courtyard -> hall
		[20, 16, "D"], [21, 16, "D"],                                  # hall -> throne room
		[20, 4, "D"], [21, 4, "D"],                                    # throne room -> passage (the tapestry)
		[20, 0, "D"], [21, 0, "D"],                                    # passage -> the stair into the sky (north edge)
		[32, 23, "D"], [32, 24, "D"],                                  # hall -> chapel
		[37, 17, "D"], [38, 17, "D"],                                  # chapel -> library (north edge)
		[9, 23, "D"], [9, 24, "D"],                                    # hall -> west corridor
		[6, 19, "D"], [6, 20, "D"],                                    # corridor -> bedchamber A
		[6, 25, "D"], [6, 26, "D"],                                    # corridor -> bedchamber B
		[11, 36, "D"],                                                 # courtyard -> the turning rooms (west edge)
	]
	var rows := MapBuilder.rasterize(W, D, rects, doors)
	var rooms := {
		"p": {"floor": "stone/flagstone_castle", "ceiling": "stone/blocks_dark"},
		"t": {"floor": "stone/marble_black", "ceiling": "stone/blocks_dark"},
		"s": {"floor": "wall/carpet_red", "ceiling": "stone/blocks_dark"},
		"h": {"floor": "stone/flagstone_castle", "ceiling": "wood/planks_dark"},
		"r": {"floor": "wall/carpet_red", "ceiling": "wood/planks_dark"},
		"k": {"floor": "stone/smooth_pale", "ceiling": "stone/blocks_dark"},
		"w": {"floor": "stone/flagstone_castle", "ceiling": "wood/planks_dark"},
		"a": {"floor": "wood/planks_dark", "ceiling": "wood/planks_dark"},
		"b": {"floor": "wood/planks_dark", "ceiling": "wood/planks_dark"},
		":": {"floor": "stone/flagstone_castle"},
	}
	MapBuilder.build(self, rows, {
		"cell": CELL, "height": H, "origin": ORIGIN, "door_h": DOOR_H, "tile": 2.0,
		"floor": "stone/flagstone_castle", "wall": "stone/blocks_castle", "ceiling": "stone/blocks_dark",
		"rooms": rooms, "outer_faces": true, "name": "Keep",
	})


## A wall torch with its light. yaw faces away from the wall it hangs on.
func _torch(pos: Vector3, yaw: float, energy: float = 1.1, range_: float = 8.0) -> OmniLight3D:
	Props.place(self, "torch_wall", pos, yaw, 1.0, {"collision": "none"})
	var l := Kit.light(self, pos + Kit.yaw_to_dir(yaw) * 0.35 + Vector3(0, 0.75, 0), WARM, energy, range_)
	fire_lights.append(l)
	return l


## A prop that has been turned to stone (the King's dream is furnished this way).
func _petrified(model: String, pos: Vector3, yaw: float, scale: float = 1.0, collision: String = "box") -> Node3D:
	return Props.place(self, model, pos, yaw, scale, {"collision": collision, "tint": PETRIFIED})


# --- the courtyard -----------------------------------------------------------------

func _courtyard() -> void:
	# the gate: a heavy door in the south wall; behind it there is only more gate
	var gate := Vector3(0, 0, 11.5)
	Door.create(self, gate, 0.0, "nexus", "from_castle", {"kind": "big", "label": "The gate, back to the Anteroom", "name": "Gate", "fade_color": Color(0.06, 0.04, 0.12), "sound": "door_heavy"})
	Kit.box(self, Vector3(0, 3.1, 12.7), Vector3(3.0, 6.2, 1.4), "stone/blocks_dark")
	for sx in [-1.0, 1.0]:
		Kit.box(self, Vector3(sx * 0.96, 1.7, 11.5), Vector3(0.08, 3.4, 1.0), "stone/blocks_castle", {"tile": 1.0})
	Props.place(self, "portcullis", Vector3(0, 2.25, 10.94), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, Vector3(0, 3.4, 9.8), MOON, 0.9, 7.0)
	Readable.create(self, Vector3(3.6, 2.2, 10.96), 0.0, "Read the sign by the gate", [
		"Painted on a board by the gate, in gold that has gone brown: THE KING IS ASLEEP.",
		"Under it, smaller, in a hurry: do not wake him. do not wake him. do not.",
	], {"name": "GateSign", "sign": "signs/king_asleep", "sign_size": Vector2(1.6, 0.8), "size": Vector3(1.6, 0.8, 0.2),
		"note_key": "gate_sign", "note_title": "The sign by the gate", "note_text": "The King is asleep. Do not wake him. Somebody wrote it three times."})
	Kit.label(self, "THE KEEP OF HOURS", Vector3(0, 4.7, 1.03), 180.0, 44, Color(0.8, 0.72, 0.9), "title", {"pixel_size": 0.016})
	# torches on the four walls
	for z in [3.5, 8.5]:
		_torch(Vector3(-8.85, 2.1, z), -90.0)
		_torch(Vector3(8.85, 2.1, z), 90.0)
	for x in [-5.5, 5.5]:
		_torch(Vector3(x, 2.1, 10.84), 0.0)
		_torch(Vector3(x, 2.1, 1.16), 180.0)
	# braziers just inside the gate; their fire is not yours
	for i in 2:
		var bp := Vector3(-3.0 + 6.0 * i, 0, 9.4)
		Brazier.create(self, bp, {"lit": true, "toggleable": false, "index": i, "light_energy": 1.5, "light_range": 10.0, "name": "CourtBrazier%d" % i})
		Kit.particles(self, bp + Vector3(0, 1.7, 0), "embers", Vector3(0.3, 0.2, 0.3), 14)
	# the dry fountain, and what it is full of instead
	var fountain := Vector3(-5.2, 0, 6.2)
	Props.place(self, "fountain", fountain, 0.0, 1.0, {"collision": "cylinder", "collision_scale": 0.85, "name": "Fountain"})
	for i in 6:
		var a := i * 60.0 + rng.randf_range(-20.0, 20.0)
		Props.place(self, "clock_hand", fountain + Kit.polar(2.9 + rng.randf_range(0.0, 0.5), a, 0.01), rng.randf_range(0.0, 360.0), 0.2, {"collision": "none"})
	Readable.create(self, fountain + Vector3(0, 0.5, 2.9), 0.0, "Look into the dry fountain", [
		"The fountain is dry. It has been dry so long the stone has forgotten what it was for.",
		"In the basin, where the water would be, there are clock hands. Hundreds. Small ones, from wristwatches. Big ones, from towers.",
		"None of them point at anything. A few have spilled over the rim.",
	], {"name": "FountainLook", "size": Vector3(2.2, 1.0, 0.8), "note_key": "dry_fountain", "note_title": "The dry fountain", "note_text": "The fountain in the keep's courtyard is full of clock hands instead of water. None of them point at anything."})
	Kit.light(self, fountain + Vector3(0, 3.0, 0), COLD, 0.8, 8.0)
	# the Hour Knight, twice the size of a knight, watching the gate
	var big := Vector3(5.5, 0, 6.2)
	Props.place(self, "statue_knight_big", big, 180.0, 1.0, {"collision": "box", "name": "HourKnight"})
	Readable.create(self, big + Vector3(0, 0.3, 1.5), 180.0, "Read the plinth", [
		"THE HOUR KNIGHT. HE KEEPS THE GATE. HE DOES NOT KEEP THE TIME; NOBODY DOES, NOW.",
		"The sword has been sharpened recently. Stone on stone. You can see the marks.",
	], {"name": "HourKnightPlinth", "size": Vector3(2.4, 0.6, 0.8), "note_key": "hour_knight", "note_title": "The Hour Knight", "note_text": "A knight twice the size of a knight guards the gate of the keep. Somebody sharpens his stone sword."})
	# gargoyles on plinths in the corners, all looking at the middle
	for corner in [Vector3(-8.2, 0, 1.8), Vector3(8.2, 0, 1.8), Vector3(-8.2, 0, 10.2), Vector3(8.2, 0, 10.2)]:
		var cp: Vector3 = corner
		Kit.box(self, cp + Vector3(0, 0.5, 0), Vector3(0.9, 1.0, 0.9), "stone/blocks_dark", {"tile": 1.0})
		Props.place(self, "gargoyle", cp + Vector3(0, 1.0, 0), Kit.dir_to_yaw(Vector3(0, 0, 6.0) - cp), 1.0, {"collision": "none"})
	Readable.create(self, Vector3(-8.2, 1.3, 1.8), 0.0, "Look at the gargoyle", [
		"The gargoyle has its hands over its ears.",
		"All four of them do. Whatever they are not listening to, they have not been listening to it for a very long time.",
	], {"name": "GargoyleLook", "size": Vector3(1.0, 1.2, 1.0), "offset": Vector3(0, 0.4, 0), "note_key": "gargoyles", "note_title": "The gargoyles", "note_text": "Four gargoyles in the courtyard, all with their hands over their ears."})
	# knights flanking the door into the hall
	Props.place(self, "statue_knight", Vector3(-3.4, 0, 1.75), 180.0, 1.0)
	Props.place(self, "statue_knight", Vector3(3.4, 0, 1.75), 180.0, 1.0)
	Props.place(self, "banner_key", Vector3(-6.0, 5.4, 1.04), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "banner_eye", Vector3(6.0, 5.4, 1.04), 180.0, 1.0, {"collision": "none"})
	# clutter: a cart that will not be going anywhere, rubble, stores
	Props.place(self, "cart_broken", Vector3(6.6, 0, 9.2), 40.0, 1.0, {"collision": "box"})
	Props.place(self, "rubble_pile", Vector3(-7.4, 0, 9.6), 15.0, 1.0, {"collision": "box"})
	Props.place(self, "barrel", Vector3(-8.3, 0, 5.0), 0.0, 1.0)
	Props.place(self, "crate", Vector3(8.3, 0, 3.4), 20.0, 1.0)
	Props.place(self, "crate_small", Vector3(8.3, 0.9, 3.4), -15.0, 1.0, {"collision": "none"})
	# the small door in the west wall, to the rooms that turn
	Kit.label(self, "the hours", Vector3(-8.96, 3.9, HOURS_Z), -90.0, 26, Color(0.7, 0.66, 0.8), "body", {"pixel_size": 0.012})
	Kit.light(self, Vector3(-8.4, 3.2, HOURS_Z), COLD, 0.7, 5.0)
	# weather that is not weather
	Kit.particles(self, Vector3(0, 0.6, 6.0), "fog", Vector3(9.0, 0.4, 5.0), 14)
	Kit.particles(self, Vector3(0, 3.0, 6.0), "motes", Vector3(9.0, 2.0, 5.0), 60)
	Kit.light(self, Vector3(0, 12.0, 6.0), MOON, 0.5, 30.0)
