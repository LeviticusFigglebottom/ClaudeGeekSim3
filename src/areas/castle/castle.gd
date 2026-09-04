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
	l.set_meta("base", energy)
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
	# the basin is dry: dust where the water was, and a great many clock hands in it
	Kit.ring(self, fountain + Vector3(0, 0.47, 0), 0.4, 2.08, 12, "ground/ash", {"solid": false, "tile": 1.5})
	for i in 14:
		var a := i * 25.7 + rng.randf_range(-10.0, 10.0)
		var r := 0.7 + rng.randf_range(0.0, 1.2)
		Props.place(self, "clock_hand", fountain + Kit.polar(r, a, 0.48), rng.randf_range(0.0, 360.0), 0.12 + rng.randf_range(0.0, 0.16), {"collision": "none"})
	for i in 5:
		var a2 := i * 72.0 + rng.randf_range(-25.0, 25.0)
		Props.place(self, "clock_hand", fountain + Kit.polar(2.7 + rng.randf_range(0.0, 0.5), a2, 0.01), rng.randf_range(0.0, 360.0), 0.16, {"collision": "none"})
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
	Kit.particles(self, Vector3(0, 3.0, 6.0), "motes", Vector3(9.0, 2.0, 5.0), 60)
	Kit.light(self, Vector3(0, 12.0, 6.0), MOON, 0.5, 30.0)


# --- the great hall ------------------------------------------------------------------

func _great_hall() -> void:
	# the lights that matter most come first
	for z in [-3.5, -9.5]:
		var zz: float = float(z)
		Props.place(self, "chandelier", Vector3(0, 3.3, zz), 0.0, 1.0, {"collision": "none"})
		Kit.light(self, Vector3(0, 3.0, zz), WARM, 1.7, 13.0)
	_hearth(Vector3(-6.5, 0, -0.4))
	# pillars, with torches on their inward faces
	for px in [-5.5, 5.5]:
		for pz in [-4.5, -11.5]:
			var p := Vector3(float(px), 0, float(pz))
			Props.place(self, "pillar_castle", p, 0.0, 1.5, {"collision": "cylinder", "collision_scale": 1.0})
			var inward := -signf(float(px))
			_torch(p + Vector3(inward * 1.0, 2.4, 0), 90.0 if inward < 0.0 else -90.0, 1.0, 7.0)
	_torch(Vector3(-7.5, 2.3, -12.84), 180.0)
	_torch(Vector3(7.5, 2.3, -12.84), 180.0)
	_torch(Vector3(-9.2, 2.3, -0.16), 0.0)
	_torch(Vector3(9.2, 2.3, -0.16), 0.0)
	# side tables laid for a feast nobody will eat: everything on them is stone
	var tables := [[9.3, -10.0, 8.2], [9.3, -2.3, 8.2], [-9.3, -10.0, -8.2], [-9.3, -2.3, -8.2]]
	for t in tables:
		var tx: float = float(t[0])
		var tz: float = float(t[1])
		var bx: float = float(t[2])
		Props.place(self, "table_long", Vector3(tx, 0, tz), 90.0, 1.0)
		Props.place(self, "bench", Vector3(bx, 0, tz), 90.0, 1.0)
		Props.place(self, "candelabra", Vector3(tx, 0.8, tz), 0.0, 1.0, {"collision": "none"})
		Kit.light(self, Vector3(tx, 1.7, tz), CANDLE, 0.7, 4.5)
		_petrified("mug", Vector3(tx + 0.2, 0.8, tz - 0.9), 30.0, 1.0, "none")
		_petrified("bottle", Vector3(tx - 0.2, 0.8, tz + 0.7), 0.0, 1.0, "none")
		_petrified("skull", Vector3(tx - 0.1, 0.8, tz + 1.2), rng.randf_range(0.0, 360.0), 1.0, "none")
	Readable.create(self, Vector3(9.3, 0.8, -10.0), 90.0, "Look at the feast", [
		"Bread, a goose, a pie the size of a shield, apples. All of it stone.",
		"The goose has been carved from a harder stone than the bread, out of respect.",
		"Somebody has set a skull at every third place. It is not clear whether they are the guests or the courses.",
	], {"name": "FeastLook", "size": Vector3(1.0, 0.6, 3.0), "note_key": "stone_feast", "note_title": "The stone feast", "note_text": "The great hall is laid for a feast of stone bread and stone geese, with a skull at every third place."})
	# banners and hangings
	Props.place(self, "banner_key", Vector3(-4.5, 5.4, -12.96), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "banner_eye", Vector3(4.5, 5.4, -12.96), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "tapestry", Vector3(10.96, 4.9, -6.0), 90.0, 1.0, {"collision": "none"})
	Props.place(self, "banner_key", Vector3(-10.96, 5.4, -10.0), -90.0, 1.0, {"collision": "none"})
	Props.place(self, "banner_eye", Vector3(-10.96, 5.4, -2.3), -90.0, 1.0, {"collision": "none"})
	Props.place(self, "banner_eye", Vector3(10.96, 5.4, -10.0), 90.0, 1.0, {"collision": "none"})
	Props.place(self, "banner_key", Vector3(10.96, 5.4, -2.3), 90.0, 1.0, {"collision": "none"})
	# ceiling beams
	for bz in [-2.0, -6.0, -10.0]:
		Kit.box(self, Vector3(0, H - 0.2, float(bz)), Vector3(22.0, 0.4, 0.4), "wood/planks_dark", {"solid": false})
	# the words above the throne room door
	Readable.create(self, Vector3(0, 4.3, -12.96), 180.0, "Read the words above the door", [
		"THE KING IS ASLEEP.",
		"Under it, in chalk, much smaller: he has been asleep since before the door. the door is younger than the sleep.",
	], {"name": "HallSign", "sign": "signs/king_asleep", "sign_size": Vector2(2.4, 1.2), "size": Vector3(2.4, 1.2, 0.2)})
	# the stone knights by the throne room door; one of them will speak, to the right person
	knight = NPC.create(self, Vector3(-3.4, 0, -12.2), 180.0, "Sir Aldric", {
		"model": "statue_knight", "face_player": false, "name": "Knight", "prompt": "The stone knight",
		"lines": ["A stone knight. Its visor is pointed slightly past you, at something behind your shoulder.", "It does not talk to people without crowns. You can tell."],
		"reactions": {
			"crown": [
				"The stone knight creaks. \"Majesty,\" it says, from somewhere inside the helm. \"You are up early.\"",
				"\"The King sleeps. We keep the hours for him. Do not let anyone wind the clocks; the Steward tried, and look at the fountain.\"",
				"\"The rooms that turn were built to keep you out, Majesty. They keep you in just as well. It depends which side you start on.\"",
			],
			"bell": ["The knight's helm turns toward the bell with a sound like a millstone.", "\"Not that one,\" it says. \"That one wakes things.\""],
			"knife": ["\"You cannot cut stone,\" says nobody. The knight does not move. The visor slit is a little darker than it was."],
			"hourglass": ["\"Ah,\" says the stone. \"You have the sand. Then the rooms will hold still for you. They never held still for me.\""],
		},
	})
	Readable.create(self, Vector3(-3.4, 0.15, -11.4), 0.0, "Read the plinth", [
		"SIR ALDRIC OF THE THIRD HOUR. HE KEPT IT.",
		"Somebody has scratched, underneath: he is still keeping it. that is why it is always the third hour.",
	], {"name": "KnightPlinth", "size": Vector3(1.2, 0.3, 0.4), "note_key": "sir_aldric", "note_title": "Sir Aldric", "note_text": "A stone knight in the great hall keeps the third hour. He only speaks to the crowned."})
	Props.place(self, "statue_knight", Vector3(3.4, 0, -12.2), 180.0, 1.0)
	Kit.particles(self, Vector3(0, 3.0, -6.5), "motes", Vector3(10.0, 2.5, 6.0), 90)
	# the corridor to the bedchambers and the chapel are both signposted
	Kit.label(self, "the chapel of the clock", Vector3(10.96, 3.9, -6.0), 90.0, 24, Color(0.7, 0.66, 0.8), "body", {"pixel_size": 0.012})
	Kit.label(self, "the bedchambers", Vector3(-10.96, 3.9, -6.0), -90.0, 24, Color(0.7, 0.66, 0.8), "body", {"pixel_size": 0.012})
	# somebody tall stands at the back of the hall on later visits, if the King was disturbed
	if visit_count >= 2 and Game.has_flag("king_disturbed") and Game.count("usher_sightings") < 9:
		Usher.spawn(self, Vector3(-8.5, 0, -12.0), {"appear_delay": 3.0, "radius": 22.0})


func _hearth(pos: Vector3) -> void:
	var fp := Props.place(self, "fireplace", pos, 0.0, 1.0, {"name": "Hearth"})
	var f := Props.part(fp, "Fire")
	if f:
		flames.append(f)
	var l := Kit.light(self, pos + Vector3(0, 1.1, -1.2), Color(1.0, 0.55, 0.2), 2.0, 11.0)
	l.set_meta("base", 2.0)
	fire_lights.append(l)
	Kit.particles(self, pos + Vector3(0, 0.6, -0.3), "embers", Vector3(0.6, 0.2, 0.3), 16)
	Props.place(self, "rug_red", pos + Vector3(0, 0.005, -1.9), 0.0, 1.0, {"collision": "none"})
	Readable.create(self, pos + Vector3(0, 0.6, -0.9), 180.0, "Warm your hands", [
		"The fire is burning. It gives no heat at all. Your hands go in and come out the same temperature.",
		"There is a great deal of ash. Somebody has been sweeping it into the shape of a clock face, and somebody else keeps walking through it.",
	], {"name": "HearthLook", "size": Vector3(2.0, 1.2, 0.8), "sound": "brazier", "note_key": "cold_hearth", "note_title": "The cold hearth", "note_text": "The fire in the great hall burns without heat. The ash has been swept into a clock face."})


# --- the throne room ----------------------------------------------------------------

func _throne_room() -> void:
	# the dais, and the steps up to it
	Kit.box(self, Vector3(0, 0.2, -21.5), Vector3(6.0, 0.4, 4.0), "stone/marble_black", {"tile": 1.5})
	Kit.stairs(self, Vector3(0, 0, -18.5), 0.0, 6.0, 2, 0.2, 0.5, "stone/marble_black", {"name": "DaisSteps", "tile": 1.5})
	var throne_pos := Vector3(0, 0.4, -22.3)
	Props.place(self, "throne", throne_pos, 180.0, 1.6, {"collision": "box", "name": "Throne"})
	var seat := throne_pos + Vector3(0, 1.15, 0)
	if visit_count < 2:
		king = _king(seat, 180.0)
	else:
		Readable.create(self, seat, 180.0, "The empty throne", [
			"The throne is empty. The velvet is still warm.",
			"The dent in the cushion is the shape of somebody who has got up, at last, to go and lie down properly.",
		], {"name": "EmptyThrone", "size": Vector3(2.0, 1.2, 1.2), "note_key": "empty_throne", "note_title": "The empty throne", "note_text": "The second time, the King was not on his throne. The cushion was still warm."})
	# candles on the dais, braziers below it, a cold light over the whole thing
	for sx in [-1.9, 1.9]:
		Props.place(self, "candelabra", Vector3(float(sx), 0.4, -20.2), 0.0, 1.0, {"collision": "none"})
		Kit.light(self, Vector3(float(sx), 1.4, -20.2), CANDLE, 0.8, 4.5)
	for i in 2:
		var bp := Vector3(-4.3 + 8.6 * i, 0, -20.0)
		Brazier.create(self, bp, {"lit": true, "toggleable": false, "index": 2 + i, "light_energy": 1.4, "light_range": 9.0, "name": "ThroneBrazier%d" % i})
		Kit.particles(self, bp + Vector3(0, 1.7, 0), "embers", Vector3(0.3, 0.2, 0.3), 12)
	Kit.light(self, Vector3(0, 4.6, -22.0), COLD, 1.0, 8.0)
	_torch(Vector3(-4.5, 2.4, -24.84), 180.0)
	_torch(Vector3(4.5, 2.4, -24.84), 180.0)
	_torch(Vector3(-4.0, 2.4, -14.16), 0.0)
	_torch(Vector3(4.0, 2.4, -14.16), 0.0)
	# pillars and the guard of stone
	for sx in [-5.0, 5.0]:
		Props.place(self, "pillar_castle", Vector3(float(sx), 0, -17.0), 0.0, 1.5, {"collision": "cylinder"})
	Props.place(self, "statue_knight", Vector3(-5.3, 0, -21.5), -90.0, 1.0)
	Props.place(self, "statue_knight", Vector3(5.3, 0, -21.5), 90.0, 1.0)
	Props.place(self, "banner_key", Vector3(-2.8, 5.5, -24.96), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "banner_key", Vector3(2.8, 5.5, -24.96), 180.0, 1.0, {"collision": "none"})
	Kit.label(self, "do not wake him", Vector3(0, 3.9, -24.9), 180.0, 26, Color(0.75, 0.68, 0.85), "body", {"pixel_size": 0.012})
	# the Steward's note, pinned by the door
	Readable.create(self, Vector3(-3.5, 1.6, -14.05), 0.0, "Read the note pinned by the door", [
		"A note pinned by the door, in a careful hand:",
		"The King sleeps so the Keep may stand. Wake him and the hours will fall out of the clock like teeth.",
		"  - the Steward",
		"The pin is a clock hand.",
	], {"name": "StewardNote", "sign": "signs/note_king", "sign_size": Vector2(0.55, 0.55), "size": Vector3(0.6, 0.6, 0.15),
		"note_key": "steward_note", "note_title": "The Steward's note", "note_text": "The King sleeps so the Keep may stand. Wake him and the hours will fall out of the clock like teeth. - the Steward"})
	# the tapestry behind the throne, and the hollow behind the tapestry
	Cuttable.create(self, Vector3(0, 0, -24.85), 0.0, Vector3(2.0, 3.4, 0.2), {"tex": "fabric/tapestry", "flag": "tapestry_cut", "cut_text": "Cut the tapestry", "name": "Tapestry", "on_cut": _on_tapestry_cut})
	Readable.create(self, Vector3(1.75, 1.6, -24.8), 0.0, "Look at the tapestry", [
		"A tapestry of the keep, every window lit. In one window, very small, someone is asleep in a bed that is not a throne.",
		"When the torches gutter, the wall behind it sounds hollow.",
	], {"name": "TapestryLook", "size": Vector3(0.9, 2.0, 0.2), "note_key": "tapestry_look", "note_title": "The tapestry behind the throne", "note_text": "Behind the throne hangs a tapestry of the keep with every window lit, and behind the tapestry the wall is hollow. Something sharp would settle it."})
	Kit.particles(self, Vector3(0, 2.5, -19.5), "motes", Vector3(5.0, 2.0, 4.0), 50)
	if visit_count >= 2 and Game.has_flag("king_disturbed") and Game.count("usher_sightings") < 9:
		Usher.spawn(self, Vector3(4.2, 0, -15.6), {"appear_delay": 3.0, "radius": 18.0})


## The sleeping King. He lies where he is put; he does not turn to face anyone.
func _king(pos: Vector3, yaw: float) -> NPC:
	var n := NPC.create(self, pos, yaw, "The King", {
		"model": "king_sleeping", "face_player": false, "turn_to_bell": false, "name": "King",
		"prompt": "Whisper to the King", "on_talk": _king_talk,
		"lines": ["The King is asleep."],
	})
	return n


# --- the King's dream: behind the tapestry, a stair out of the keep into the sky ----

func _kings_dream() -> void:
	var top_y := 3.0
	Kit.stairs(self, Vector3(0, 0, -30.0), 0.0, 2.0, 12, 0.25, 0.4, "stone/flagstone_castle", {"name": "DreamStair", "tile": 1.0})
	for sx in [-1.15, 1.15]:
		Kit.box(self, Vector3(float(sx), 2.6, -32.4), Vector3(0.3, 5.2, 4.8), "stone/blocks_castle", {"affine": 0.02})
	var land := Vector3(0, top_y, -36.4)
	Kit.floor(self, land, Vector2(2.6, 3.2), "stone/flagstone_castle")
	for sx in [-1.15, 1.15]:
		Kit.box(self, Vector3(float(sx), top_y + 1.7, -36.4), Vector3(0.3, 3.4, 3.2), "stone/blocks_castle", {"affine": 0.02})
	Kit.light(self, Vector3(0, 4.6, -33.0), COLD, 0.9, 9.0)
	# a bedroom you know, rebuilt in stone, with no roof, hung from the sky by chains
	var c := Vector3(0, top_y, -41.5)
	var wt := "stone/smooth_pale"
	var wh := 3.4
	Kit.floor(self, c, Vector2(7.0, 7.0), "stone/smooth_grey", {"tile": 1.0})
	Kit.wall(self, c + Vector3(-3.5, 0, -3.5), c + Vector3(3.5, 0, -3.5), wh, wt)
	Kit.wall(self, c + Vector3(3.5, 0, -3.5), c + Vector3(3.5, 0, 3.5), wh, wt)
	Kit.wall(self, c + Vector3(-3.5, 0, 3.5), c + Vector3(-3.5, 0, -3.5), wh, wt)
	Kit.wall(self, c + Vector3(-3.6, 0, 3.5), c + Vector3(-1.0, 0, 3.5), wh, wt)
	Kit.wall(self, c + Vector3(1.0, 0, 3.5), c + Vector3(3.6, 0, 3.5), wh, wt)
	for corner in [Vector3(-3.3, 0, -3.3), Vector3(3.3, 0, -3.3), Vector3(-3.3, 0, 3.3), Vector3(3.3, 0, 3.3)]:
		var cp: Vector3 = corner
		Props.place(self, "chain_hanging_long", c + cp + Vector3(0, wh + 14.0, 0), 0.0, 1.0, {"collision": "none"})
	# the furniture of Flat 5½, turned to stone
	_petrified("bed_single", c + Vector3(-2.6, 0, -1.2), 0.0)
	_petrified("wardrobe", c + Vector3(2.4, 0, -3.15), 180.0)
	_petrified("desk", c + Vector3(2.9, 0, 0.8), 90.0)
	_petrified("chair", c + Vector3(2.1, 0, 0.8), -90.0)
	_petrified("lamp_desk", c + Vector3(2.9, 0.77, 0.3), 90.0, 1.0, "none")
	_petrified("telephone", c + Vector3(2.9, 0.77, 1.3), 90.0, 1.0, "none")
	_petrified("radiator", c + Vector3(-1.0, 0, -3.35), 180.0, 1.0, "none")
	_petrified("boxes_moving", c + Vector3(-2.9, 0, 2.6), 20.0)
	_petrified("window_night", c + Vector3(0.2, 1.7, -3.42), 180.0, 1.0, "none")
	_petrified("frame_calendar", c + Vector3(3.44, 1.7, -1.2), 90.0, 1.0, "none")
	_petrified("photo_1", c + Vector3(-3.44, 1.6, 0.6), -90.0, 1.0, "none")
	_petrified("rug_house", c + Vector3(0, 0.005, 0.6), 0.0, 1.0, "none")
	Readable.create(self, c + Vector3(-2.6, 0.7, -2.0), 0.0, "Read what is in the pillow", [
		"The pillow is stone. The words in it were not carved; they were slept into it, over years, the way a path is walked into a field.",
		"I AM THE ONE ASLEEP. THE KING IS WHAT I LOOK LIKE FROM INSIDE.",
		"IF THEY WAKE HIM IT IS ME THEY WAKE. LET HIM HAVE HIS HOUR.",
	], {"name": "PillowWords", "size": Vector3(0.9, 0.5, 0.8), "note_key": "kings_dream", "note_title": "The King's dream",
		"note_text": "Behind the tapestry, up a stair into the night: the bedroom of Flat 5½ rebuilt in stone and hung from the sky by chains. The words slept into the pillow say the King is the dreamer, seen from inside."})
	Readable.create(self, c + Vector3(0.2, 1.7, -3.3), 180.0, "Look out of the window", [
		"Through the window: the courtyard of the keep, seen from very high up.",
		"There is someone in it, looking up. You wave. After a moment, so do they.",
	], {"name": "DreamWindow", "size": Vector3(1.4, 1.5, 0.3), "note_key": "dream_window", "note_title": "The window in the sky", "note_text": "From the stone bedroom's window you can see yourself in the courtyard, waving back, a moment late."})
	Readable.create(self, c + Vector3(2.9, 0.9, 1.3), 90.0, "The telephone", [
		"The telephone is stone. It is ringing anyway, about once a minute, very slowly.",
		"You do not pick it up. It would be somebody asking to be woken.",
	], {"name": "DreamPhone", "size": Vector3(0.5, 0.4, 0.5), "sound": "phone_ring"})
	Kit.light(self, c + Vector3(0, 3.0, 0), COLD, 1.3, 9.0)
	Kit.light(self, c + Vector3(2.6, 1.3, 0.5), CANDLE, 0.7, 4.0)
	Kit.light(self, c + Vector3(0, 9.0, 0), MOON, 0.8, 16.0)
	Kit.particles(self, c + Vector3(0, 5.0, 0), "snow", Vector3(4.0, 1.0, 4.0), 60)
	Kit.particles(self, c + Vector3(0, 1.5, 0), "motes", Vector3(3.0, 1.5, 3.0), 30)


# --- the chapel of the clock -----------------------------------------------------------

func _chapel() -> void:
	var second := visit_count >= 2
	# the great clock on the east wall, stopped at half past five (until it is not)
	Kit.sign(self, "metal/clock_face", Vector3(20.96, 3.6, -6.0), 90.0, Vector2(3.6, 3.6))
	_clock_hand(Vector3(20.86, 3.6, -6.0), 165.5 if second else 165.0, 0.38)
	_clock_hand(Vector3(20.78, 3.6, -6.0), 186.0 if second else 180.0, 0.56)
	Kit.light(self, Vector3(19.0, 3.8, -6.0), COLD, 1.3, 9.0)
	var clock_lines: Array = [
		"The great clock says half past five.",
		"It has said half past five since before the keep. Something behind the face is still trying; you can hear it, like a moth in a jar.",
	]
	if second:
		clock_lines = [
			"The great clock says twenty-nine minutes to six.",
			"It has moved. One minute. Nobody wound it. You do not remember it moving, and you had the feeling you were looking at it the whole time.",
		]
	Readable.create(self, Vector3(20.8, 2.0, -6.0), 90.0, "Look at the great clock", clock_lines, {
		"name": "GreatClock", "size": Vector3(0.4, 3.4, 3.6), "offset": Vector3(0, 1.7, 0), "sound": "gear_tick",
		"note_key": "great_clock_2" if second else "great_clock", "note_title": "The great clock" + (", again" if second else ""),
		"note_text": "The great clock in the chapel has moved one minute since you were last here. Nobody wound it." if second else "The great clock in the chapel is stopped at half past five. Something behind the face is still trying.",
	})
	# the pendulum, swinging in front of the clock by clockwork (the Hourglass stops it)
	var pend := Clockwork.create(self, Vector3(16.5, 5.9, -6.0), {"mode": "oscillate", "axis": Vector3(1, 0, 0), "amplitude_deg": 9.0, "period": 3.0, "name": "PendulumSwing"})
	Props.place(pend.body, "pendulum_big", Vector3.ZERO, 90.0, 0.8, {"collision": "none"})
	# gears on the north wall that turn for nothing
	var g1 := Clockwork.create(self, Vector3(14.6, 1.6, -11.86), {"mode": "rotate", "axis": Vector3(0, 0, 1), "speed_deg": 5.0, "name": "GearTurn"})
	Props.place(g1.body, "gear_big", Vector3(0, -1.5, 0), 0.0, 1.0, {"collision": "none"})
	var g2 := Clockwork.create(self, Vector3(19.0, 2.9, -11.86), {"mode": "rotate", "axis": Vector3(0, 0, 1), "speed_deg": -8.0, "name": "GearTurn2"})
	Props.place(g2.body, "gear_big", Vector3(0, -0.9, 0), 0.0, 0.6, {"collision": "none"})
	Readable.create(self, Vector3(14.6, 1.6, -11.6), 180.0, "Look at the gear", [
		"The gear turns. Nothing is connected to it. It is turning for practice.",
		"Chalked on the wall beside it: THIS ONE IS NOT THE PROBLEM.",
	], {"name": "GearLook", "size": Vector3(2.4, 2.4, 0.4), "offset": Vector3.ZERO, "sound": "gear_tick", "note_key": "gear", "note_title": "The practice gear", "note_text": "In the chapel a great gear turns, connected to nothing. Somebody chalked beside it that it is not the problem."})
	# pews facing the clock, an altar under it, a lectern with the Book of Hours
	for bx in [14.0, 18.0]:
		Props.place(self, "bench", Vector3(float(bx), 0, -10.4), 90.0, 1.0)
	for bx in [14.0, 16.0, 18.0]:
		Props.place(self, "bench", Vector3(float(bx), 0, -2.6), 90.0, 1.0)
	Props.place(self, "altar", Vector3(20.2, 0, -6.0), 90.0, 1.0)
	Props.place(self, "candle_cluster", Vector3(20.2, 1.39, -6.6), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "candle_cluster", Vector3(20.2, 1.39, -5.4), 40.0, 1.0, {"collision": "none"})
	Kit.light(self, Vector3(19.7, 2.0, -6.0), CANDLE, 1.0, 6.0)
	var lect := Vector3(19.4, 0, -4.0)
	Props.place(self, "lectern", lect, 90.0, 1.0)
	_book_on(lect, 90.0, "signs/book_cover")
	var hours_lines: Array = [
		"A BOOK OF HOURS. Each page is an hour of the day, illuminated. Every page is the same hour.",
		"Half past five. The margins are full of tiny sleeping figures drawn in gold, and one tall figure in a coat, drawn in nothing.",
		"The last page has been torn out.",
	]
	if second:
		hours_lines[2] = "The last page has been torn out. Somebody has written in the gap, very small: 5:31."
	Readable.create(self, lect + Vector3(0, 1.0, 0), 90.0, "Read the Book of Hours", hours_lines, {"name": "BookOfHours", "size": Vector3(0.7, 0.6, 0.7), "note_key": "book_of_hours", "note_title": "The Book of Hours", "note_text": "Every page of the Book of Hours is the same hour: half past five, with a tall figure in the margin drawn in nothing. The last page has been torn out."})
	# a great hourglass whose sand stopped halfway
	var hg := Vector3(19.8, 0, -10.8)
	Props.place(self, "hourglass_big", hg, 0.0, 1.0, {"collision": "cylinder"})
	Kit.light(self, hg + Vector3(0, 1.5, 0), Color(1.0, 0.95, 0.8), 0.8, 5.0)
	Readable.create(self, hg + Vector3(-0.6, 0, 0.6), 0.0, "Look at the hourglass", [
		"A glass as tall as you are. The sand has stopped halfway through the neck, a grain wide, and hangs there.",
		"It is not stuck. It is waiting for something smaller than itself to tell it what to do.",
	], {"name": "HourglassLook", "size": Vector3(0.8, 2.0, 0.8), "note_key": "great_hourglass", "note_title": "The great hourglass", "note_text": "In the chapel a hourglass as tall as you has its sand stopped in the neck. It is waiting for a smaller hourglass."})
	_torch(Vector3(12.8, 2.3, -11.84), 180.0)
	_torch(Vector3(20.3, 2.3, -11.84), 180.0)
	_torch(Vector3(13.2, 2.3, -1.16), 0.0)
	_torch(Vector3(20.0, 2.3, -1.16), 0.0)
	Kit.label(self, "the library", Vector3(LIB_X, 4.2, -11.96), 180.0, 26, Color(0.7, 0.66, 0.8), "body", {"pixel_size": 0.012})
	Kit.particles(self, Vector3(16.5, 3.0, -6.0), "motes", Vector3(4.0, 2.0, 5.0), 40)
	# hook for later: ringing the Small Bell here three times might start the clock (see on_bell)


## A clock hand on the east wall, pointing `deg` clockwise from twelve.
func _clock_hand(pivot_pos: Vector3, deg: float, scale: float) -> void:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	pivot.rotation.x = deg_to_rad(deg)
	add_child(pivot)
	Props.place(pivot, "clock_hand", Vector3.ZERO, 0.0, scale, {"collision": "none", "rotation": Vector3(90, 0, 0)})


## A flat book lying on a lectern that faces `yaw`.
func _book_on(lectern_pos: Vector3, yaw: float, tex: String) -> MeshInstance3D:
	return Kit.sign(self, tex, lectern_pos + Vector3(0, 1.12, 0) + Kit.yaw_to_dir(yaw) * 0.02, 0.0, Vector2(0.36, 0.46), {"rotation": Vector3(-67, 180 + yaw, 0)})


# --- the west wing: a corridor and two bedchambers ----------------------------------------

func _west_wing() -> void:
	# the corridor (x -14..-12, z -12..-1) has a low ceiling like everything in the wing
	Kit.ceiling(self, Vector3(-13.0, 3.6, -6.5), Vector2(2.0, 11.0), "wood/planks_dark")
	Kit.ceiling(self, Vector3(-17.5, 3.6, -9.5), Vector2(5.0, 5.0), "wood/planks_dark")
	Kit.ceiling(self, Vector3(-17.5, 3.6, -3.5), Vector2(5.0, 5.0), "wood/planks_dark")
	Props.place(self, "rug_red", Vector3(-13.0, 0.005, -6.5), 0.0, 1.0, {"collision": "none"})
	_torch(Vector3(-12.16, 2.1, -9.6), 90.0, 1.0, 7.0)
	_torch(Vector3(-12.16, 2.1, -3.0), 90.0, 1.0, 7.0)
	# a portrait, turned to face the wall
	Props.place(self, "painting_portrait", Vector3(-13.97, 1.6, -7.0), 90.0, 1.0, {"collision": "none"})
	Readable.create(self, Vector3(-13.9, 1.6, -7.0), -90.0, "The portrait", [
		"A portrait, turned to face the wall. From the back it is a portrait of a wall.",
		"You could turn it round. You have the feeling it was turned by somebody who knew the face, and did not want it watching the corridor.",
	], {"name": "TurnedPortrait", "size": Vector3(0.2, 1.2, 1.2), "offset": Vector3.ZERO, "note_key": "turned_portrait", "note_title": "The turned portrait", "note_text": "In the west corridor a portrait has been turned to face the wall by somebody who knew the face."})
	# bedchamber A (x -20..-15, z -12..-7): an iron bed, a wardrobe, an arrow slit
	var bed_a := Vector3(-19.4, 0, -9.6)
	Props.place(self, "bed_iron", bed_a, 0.0, 1.0)
	Props.place(self, "wardrobe", Vector3(-16.8, 0, -11.65), 180.0, 1.0)
	Props.place(self, "crate_small", Vector3(-18.6, 0, -11.6), 10.0, 1.0)
	Props.place(self, "candle_tall", Vector3(-18.6, 0.5, -11.6), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, Vector3(-18.6, 1.4, -11.3), CANDLE, 0.9, 5.0)
	Props.place(self, "stool", Vector3(-17.0, 0, -8.2), 30.0, 1.0)
	Props.place(self, "window_night", Vector3(-19.94, 1.9, -8.0), -90.0, 1.0, {"collision": "none"})
	Kit.light(self, Vector3(-19.2, 2.0, -8.0), COLD, 0.7, 4.5)
	_torch(Vector3(-15.4, 2.1, -11.84), 180.0, 1.0, 6.0)
	if visit_count >= 2:
		# the King has gone to bed
		king = _king(bed_a + Vector3(0, 0.55, 0.1), 90.0)
		Kit.label(self, "shh", Vector3(-19.9, 2.6, -9.6), -90.0, 22, Color(0.6, 0.58, 0.7), "body", {"pixel_size": 0.012})
	else:
		Readable.create(self, bed_a + Vector3(0, 0.6, -0.8), 0.0, "Look under the pillow", [
			"Under the pillow: a note, folded small.",
			"I HAVE GONE TO SIT ON THE THRONE FOR A WHILE. IF I AM NOT BACK, I AM STILL THERE. DO NOT MOVE ME.",
			"It is in the King's hand. It is in your hand, too; the writing is yours.",
		], {"name": "PillowNote", "size": Vector3(0.9, 0.5, 0.7), "note_key": "under_pillow", "note_title": "Under the King's pillow", "note_text": "A note in your own handwriting: I have gone to sit on the throne for a while. If I am not back, I am still there."})
	# bedchamber B (x -20..-15, z -6..-1): the chest, the mirror, the wardrobe you come out of
	Props.place(self, "bed_iron", Vector3(-19.4, 0, -4.0), 0.0, 1.0)
	Props.place(self, "wardrobe", Vector3(-18.4, 0, -1.34), 0.0, 1.0, {"name": "SecretWardrobe"})
	Readable.create(self, Vector3(-18.4, 1.2, -1.9), 0.0, "Open the wardrobe", [
		"The wardrobe is full of one coat, many times.",
		"At the back, where the wall should be, it smells of old paper and dust. A shelf, maybe. A long way off.",
	], {"name": "WardrobeLook", "size": Vector3(1.2, 2.0, 0.5), "sound": "creak", "note_key": "wardrobe_back", "note_title": "The back of the wardrobe", "note_text": "The wardrobe in the second bedchamber has no back, only a smell of old paper a long way off."})
	Props.place(self, "desk", Vector3(-16.0, 0, -1.36), 0.0, 1.0)
	Props.place(self, "chair", Vector3(-16.0, 0, -2.2), 180.0, 1.0)
	Props.place(self, "candle_tall", Vector3(-16.4, 0.77, -1.4), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, Vector3(-16.4, 1.6, -1.8), CANDLE, 0.9, 5.0)
	_torch(Vector3(-19.84, 2.2, -2.2), -90.0, 1.0, 6.0)
	Mirror.create(self, Vector3(-15.8, 1.1, -5.95), 180.0, "mirror_nexus", "default", {"name": "ChamberMirror", "model": "mirror_tall", "lines_without": [
		"The mirror shows the bedchamber. It shows the bed.",
		"There is somebody in the bed in the mirror. There is nobody in the bed behind you. You check twice.",
	]})
	Kit.light(self, Vector3(-15.8, 2.2, -5.2), COLD, 0.7, 4.5)
	# the chest, and the candle stub that has been lit from both ends
	chest_pos = Vector3(-17.0, 0, -5.62)
	var chest := Props.place(self, "chest", chest_pos, 180.0, 1.0, {"name": "Chest"})
	chest_lid = Props.part(chest, "Lid")
	chest_it = Interactable.make(self, chest_pos + Vector3(0, 0.35, 0), Vector3(1.0, 0.8, 0.7), "Open the chest", _on_chest, {"name": "ChestOpen"})
	if Game.has_flag("castle_chest_open"):
		_open_chest(false)


# --- the library that does not end -----------------------------------------------------

func _library() -> void:
	# a separate map: its own walls, hung on the chapel's north doorway through two open cells
	var rows: Array = ["########"]
	for i in LIB_ROWS:
		rows.append("#......#")
	rows.append("###OO###")
	var ld := rows.size()
	var lorigin := Vector3(ORIGIN.x + 34, 0, -13.0 - ld)
	MapBuilder.build(self, rows, {"cell": 1.0, "height": 5.5, "origin": lorigin, "door_h": DOOR_H, "tile": 2.0,
		"floor": "stone/flagstone_castle", "wall": "stone/blocks_castle", "ceiling": "wood/planks_dark", "name": "Library"})
	var z_far := lorigin.z + 1.0
	# shelves every two metres, both sides, all the way; the same shelf, mostly
	for k in 20:
		var z := -15.0 - 2.0 * k
		Props.place(self, "bookshelf_tall", Vector3(14.18, 0, z), 90.0, 1.0, {"collision": "box"})
		Props.place(self, "bookshelf_tall", Vector3(19.82, 0, z), -90.0, 1.0, {"collision": "box"})
	for k in 5:
		var z := -16.0 - 6.0 * k
		Props.place(self, "lantern_hanging", Vector3(LIB_X, 5.45, z), 0.0, 1.0, {"collision": "none"})
		Kit.light(self, Vector3(LIB_X, 4.1, z), CANDLE, 1.1, 8.0)
	Kit.light(self, Vector3(LIB_X, 3.0, -14.5), COLD, 0.7, 6.0)
	# the plaque by the way in
	Kit.label(self, "NO BOOK LEAVES. NO READER, EITHER.", Vector3(15.0, 2.5, -13.96), 0.0, 20, Color(0.78, 0.72, 0.9), "body", {"pixel_size": 0.01})
	Readable.create(self, Vector3(15.0, 1.6, -13.9), 0.0, "Read the plaque", [
		"THE LIBRARY. NO BOOK LEAVES. NO READER, EITHER, WHICH IS WHY THE PAGES ARE ALL STILL HERE.",
		"Under it, a tally, kept in pencil, of people who went up the aisle. There is no tally of people who came back.",
	], {"name": "LibraryPlaque", "size": Vector3(1.6, 1.0, 0.2), "note_key": "library_plaque", "note_title": "The library plaque", "note_text": "No book leaves the keep's library. No reader, either. There is a tally of people who went up the aisle and none of people who came back."})
	# the seam: forty metres up the aisle you are twenty-four metres back, and the shelves agree
	SeamlessTeleport.create(self, Vector3(LIB_X, 0, -44.0), 0.0, Vector3(LIB_X, 0, -20.0), 0.0, Vector3(6.0, 4.5, 0.6), {"name": "LibraryLoop", "count_flag": "library_loops", "on_teleport": _on_library_loop})
	# a lectern with a book of doors (and its twin beyond the seam, so the aisle repeats properly)
	for lz in [-24.0, -48.0]:
		var lp := Vector3(15.6, 0, float(lz))
		Props.place(self, "lectern", lp, -90.0, 1.0)
		_book_on(lp, -90.0, "signs/book_cover")
		Props.place(self, "candle", lp + Vector3(0.0, 1.05, -0.32), 0.0, 1.0, {"collision": "none"})
		Kit.light(self, lp + Vector3(0.4, 1.5, 0), CANDLE, 0.6, 3.5)
	Readable.create(self, Vector3(15.6, 1.0, -24.0), -90.0, "Read the Book of Doors", [
		"A BOOK OF DOORS. Every door in the keep, drawn from the other side.",
		"Page 5½ is the door you came in by. It is drawn open, and there is a corridor behind it with a light at the end that the artist has scribbled out.",
		"The last page is a bookshelf. Somebody has drawn a handle on it.",
	], {"name": "BookOfDoors", "size": Vector3(0.7, 0.6, 0.7), "note_key": "book_of_doors", "note_title": "The Book of Doors", "note_text": "Every door in the keep drawn from the other side. The last page is a bookshelf with a handle drawn on it."})
	# the shy book: open when you are not looking, shut when you are
	var shy := Vector3(15.6, 0, -32.0)
	Props.place(self, "lectern", shy, -90.0, 1.0)
	var top := shy + Vector3(0.02, 1.12, 0)
	closed_book = Node3D.new()
	closed_book.name = "ClosedBook"
	closed_book.position = top
	add_child(closed_book)
	Kit.sign(closed_book, "signs/book_cover_2", Vector3.ZERO, 0.0, Vector2(0.36, 0.46), {"rotation": Vector3(-67, 90, 0)})
	open_book = Node3D.new()
	open_book.name = "OpenBook"
	open_book.position = top
	add_child(open_book)
	for pz in [-0.11, 0.11]:
		Kit.sign(open_book, "wall/paper", Vector3(0, 0, float(pz)), 0.0, Vector2(0.2, 0.46), {"rotation": Vector3(-67, 90, 0), "tint": Color(0.92, 0.88, 0.8)})
	open_book.visible = false
	LookAway.create(self, top, _book_closes, {"name": "BookWatch", "when_seen": true, "delay": 0.25, "once": false, "radius": 9.0, "dot_threshold": 0.9})
	LookAway.create(self, top, _book_opens, {"name": "BookUnwatch", "delay": 1.4, "once": false, "radius": 9.0, "dot_threshold": 0.9})
	Readable.create(self, shy + Vector3(0, 1.0, 0), -90.0, "Read the book", [
		"The book is shut. You are fairly sure it was open when you were not looking at it.",
		"You open it. The pages are blank, and warm, like a chair somebody has just got up from.",
	], {"name": "ShyBook", "size": Vector3(0.7, 0.6, 0.7), "note_key": "shy_book_read", "note_title": "The book that shuts", "note_text": "A book in the library that is open when you are not looking and shut when you are. Its pages are blank and warm."})
	Kit.light(self, shy + Vector3(0.5, 1.6, 0), CANDLE, 0.5, 3.0)
	# deep in the loop, a rose folded from a page
	var rose := Vector3(18.4, 0, -38.0)
	Props.place(self, "lectern", rose, 90.0, 1.0)
	Pickup.create(self, rose + Vector3(0, 1.15, 0), {"item": "rose", "name": "PaperRose", "key": "picked_rose_castle", "prompt": "Take the paper rose"})
	Readable.create(self, rose + Vector3(0, 0.35, 0.6), 90.0, "The torn book", [
		"The book on this lectern has had a page torn out and folded, carefully, many times.",
		"What is left of the page reads: ...and the king dreamed of a garden, and in the garden a single...",
	], {"name": "TornBook", "size": Vector3(0.7, 0.6, 0.4), "note_key": "torn_page", "note_title": "The torn page", "note_text": "Deep in the library, a page torn from a book and folded into a rose. The rest of the page was about a king dreaming of a garden."})
	Kit.light(self, rose + Vector3(-0.5, 1.7, 0), Color(1.0, 0.8, 0.85), 0.6, 4.0)
	# the shelf that is a door (one book has been pushed in)
	Door.create(self, Vector3(14.75, 0, -43.0), -90.0, "castle", "wardrobe", {"kind": "none", "label": "One book on this shelf has been pushed in", "name": "ShelfDoor", "fade_color": Color(0.05, 0.03, 0.02), "fade_duration": 1.0, "sound": "creak"})
	Kit.label(self, "5½", Vector3(14.37, 2.4, -43.0), -90.0, 18, Color(0.75, 0.7, 0.6), "body", {"pixel_size": 0.01})
	Props.place(self, "candle", Vector3(14.6, 0, -42.1), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, Vector3(14.9, 0.6, -42.1), CANDLE, 0.5, 3.0)
	# past the seam the aisle goes dark, and stays dark
	Kit.box(self, Vector3(LIB_X, 2.75, z_far + 0.5), Vector3(6.0, 5.5, 0.3), "", {"solid": false, "unshaded": true, "tint": Color(0.01, 0.01, 0.015)})
	Kit.particles(self, Vector3(LIB_X, 2.5, -30.0), "motes", Vector3(2.5, 2.0, 16.0), 80)
	if visit_count >= 2 and Game.count("usher_sightings") < 9:
		Usher.spawn(self, Vector3(LIB_X, 0, -50.0), {"appear_delay": 3.0, "radius": 30.0})


# --- the turning rooms ------------------------------------------------------------------------

func _turning_rooms() -> void:
	var half_gap := deg_to_rad(180.0 / SLEEVE_SEGS)
	var hw := R_SLEEVE * sin(half_gap)
	var eo := R_SLEEVE * cos(half_gap)
	var wall_h := ROOM_H + 0.4
	var vx0 := -10.0
	var vx1 := vx0 - VEST_LEN
	# the vestibule off the courtyard's west door
	_passage(vx0, vx1, hw, wall_h)
	var vmid := (vx0 + vx1) * 0.5
	Kit.label(self, "THE HOURS TURN. WAIT FOR YOURS.", Vector3(vmid, 2.4, HOURS_Z - hw + 0.02), 180.0, 20, Color(0.78, 0.72, 0.9), "body", {"pixel_size": 0.01})
	Readable.create(self, Vector3(vmid, 1.5, HOURS_Z - hw + 0.12), 180.0, "Read the wall", [
		"THE HOURS TURN. WAIT FOR YOURS.",
		"Scratched under it by several hands: waited. waited. it came round. it went round again. I am still here. so is the wall.",
	], {"name": "HoursPlaque", "size": Vector3(1.8, 1.0, 0.2), "note_key": "hours_plaque", "note_title": "The rooms that turn", "note_text": "West of the courtyard, three round rooms whose walls turn. The doorways only line up at moments. The hourglass, if you have it, steadies them."})
	Kit.light(self, Vector3(vmid, 3.6, HOURS_Z), COLD, 0.8, 5.0)
	var cx := vx1 - eo
	for i in 3:
		var c := Vector3(cx, 0, HOURS_Z)
		_turning_room(i, c, wall_h)
		if i < 2:
			_passage(c.x - eo, c.x - eo - PASS_LEN, hw, wall_h)
		cx -= eo * 2.0 + PASS_LEN


## A straight stone passage along z = HOURS_Z between two x positions (xa > xb).
func _passage(xa: float, xb: float, hw: float, wall_h: float) -> void:
	var mid := Vector3((xa + xb) * 0.5, 0, HOURS_Z)
	var length := absf(xa - xb) + 0.4
	Kit.floor(self, mid + Vector3(0, -0.01, 0), Vector2(length, hw * 2.0 + 0.3), "stone/flagstone_castle", {"tile": 2.0, "affine": 0.02})
	Kit.ceiling(self, mid + Vector3(0, wall_h + 0.01, 0), Vector2(length, hw * 2.0 + 0.3), "stone/blocks_dark", {"tile": 2.0, "affine": 0.02})
	for side in [-1.0, 1.0]:
		var zz := HOURS_Z + float(side) * (hw + 0.15)
		Kit.wall(self, Vector3(xa, 0, zz), Vector3(xb, 0, zz), wall_h, "stone/blocks_castle", {"thick": 0.3, "tile": 2.0, "affine": 0.02})


## A round room: a still floor and ceiling, a fixed sleeve wall with gaps for the
## passages, and inside it a wall that turns by clockwork with one gap in it.
func _turning_room(i: int, c: Vector3, wall_h: float) -> void:
	var rf := R_SLEEVE + 0.45
	Kit.ring(self, c, 0.0, rf, 28, "stone/flagstone_castle", {"tile": 2.0})
	Kit.ring(self, c + Vector3(0, wall_h, 0), 0.0, rf, 28, "stone/blocks_dark", {"down": true, "tile": 2.0})
	var gaps: Array = [[0.0, 30.0]]
	if i < 2:
		gaps.append([180.0, 30.0])
	Kit.round_wall(self, c, R_SLEEVE, wall_h, SLEEVE_SEGS, "stone/blocks_castle", {"gaps": gaps, "thick": 0.3, "tile": 2.0, "affine": 0.05, "name": "Sleeve%d" % i})
	# a clock face on the floor, for the wall to be the hand of
	var q := QuadMesh.new()
	q.size = Vector2(5.0 - i * 0.6, 5.0 - i * 0.6)
	Kit.add_mesh(self, q, Kit.mat("metal/clock_face", {"tint": Color(0.5, 0.46, 0.42)}), c + Vector3(0, 0.015, 0), {"solid": false, "rotation": Vector3(-90, 0, 0)})
	# the wall that turns (an AnimatableBody, so it pushes rather than swallows)
	var cw := Clockwork.create(self, c, {"mode": "rotate", "axis": Vector3.UP, "speed_deg": float(ROOM_SPEEDS[i]), "platform": true, "name": "TurningRoom%d" % i})
	_turning_wall(cw)
	cw.body.rotation.y = deg_to_rad(rng.randf_range(0.0, 360.0))
	Kit.light(self, c + Vector3(0, 3.6, 0), COLD, 0.8, 8.0)
	Kit.particles(self, c + Vector3(0, 2.0, 0), "motes", Vector3(3.0, 1.5, 3.0), 30)
	match i:
		0:
			Props.place(self, "stool", c + Vector3(1.4, 0, 1.6), 20.0, 1.0)
			Props.place(self, "candle_cluster", c + Vector3(1.9, 0, 1.2), 0.0, 1.0, {"collision": "none"})
			Kit.light(self, c + Vector3(1.9, 0.6, 1.2), CANDLE, 0.6, 3.5)
			Readable.create(self, c + Vector3(1.4, 0.3, 1.6), 0.0, "A stool", [
				"A stool, for waiting on. The seat is worn into a shape.",
				"The shape is not yours yet. Give it time. That is what it is for.",
			], {"name": "WaitingStool", "size": Vector3(0.6, 0.6, 0.6)})
		1:
			Props.place(self, "bone_pile", c + Vector3(-1.6, 0, 1.8), 40.0, 1.0, {"collision": "none"})
			Props.place(self, "skull", c + Vector3(-0.9, 0, 2.2), 200.0, 1.0, {"collision": "none"})
			Readable.create(self, c + Vector3(-1.4, 0.2, 1.9), 0.0, "Look at the bones", [
				"Bones, arranged neatly against the wall, the way you would leave your shoes.",
				"Somebody waited here for the gap to come round. It came round. They did not see it; they were watching the wrong wall.",
			], {"name": "HoursBones", "size": Vector3(1.2, 0.6, 1.0), "note_key": "hours_bones", "note_title": "The one who waited", "note_text": "In the second turning room, bones arranged neatly like shoes. They waited for the gap and watched the wrong wall."})
		2:
			Kit.box(self, c + Vector3(0, 0.35, 0), Vector3(0.8, 0.7, 0.8), "stone/marble_black", {"tile": 1.0})
			Pickup.create(self, c + Vector3(0, 0.7, 0), {"keepsake": "crown", "name": "PaperCrown"})
			Kit.light(self, c + Vector3(0, 2.6, 0), Color(1.0, 0.9, 0.5), 0.9, 6.0)
			Readable.create(self, c + Vector3(0, 0.3, 0.95), 0.0, "Read the pedestal", [
				"THE CROWN IS PAPER. THE KING IS NOT. THE DIFFERENCE IS SLEEP.",
				"Under it, in pencil: it fits everyone. that is the trouble with it.",
			], {"name": "CrownPlinth", "size": Vector3(0.8, 0.5, 0.4), "note_key": "crown_plinth", "note_title": "The paper crown's pedestal", "note_text": "The crown is paper. The King is not. The difference is sleep. It fits everyone; that is the trouble with it."})


## Panels of the turning wall under a Clockwork body: visual walls plus box collision
## shapes on the AnimatableBody so the wall shoves the player instead of passing through.
func _turning_wall(cw: Clockwork) -> void:
	var seg := 360.0 / WALL_SEGS
	for i in WALL_SEGS:
		if i < 3:
			continue   # the gap: three panels wide
		var a0 := seg * i
		var a1 := seg * (i + 1)
		var p0 := Kit.polar(R_WALL, a0)
		var p1 := Kit.polar(R_WALL, a1)
		Kit.wall(cw.body, p1, p0, ROOM_H, "stone/blocks_dark", {"solid": false, "thick": 0.24, "tile": 1.5, "affine": 0.05})
		var d := p0 - p1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(d.length() + 0.04, ROOM_H, 0.24)
		cs.shape = bs
		cs.position = (p0 + p1) * 0.5 + Vector3(0, ROOM_H * 0.5, 0)
		cs.rotation.y = atan2(-d.x, -d.z) + PI * 0.5
		cw.body.add_child(cs)
		if i % 4 == 1:
			var am := seg * (i + 0.5)
			Props.place(cw.body, "torch_wall", Kit.polar(R_WALL - 0.17, am, 2.0), Kit.yaw_to_center(am), 1.0, {"collision": "none"})
			var l := Kit.light(cw.body, Kit.polar(R_WALL - 0.7, am, 2.5), WARM, 1.0, 7.0)
			l.set_meta("base", 1.0)
			fire_lights.append(l)


# --- conversations and callbacks ---------------------------------------------------------------

func _king_talk(_player: Node, npc: Node) -> bool:
	var n := npc as NPC
	if n == null or World.hud == null:
		return false
	if Game.active_is("crown"):
		await n.say(["The King, without opening his eyes, reaches up and straightens the crown on your head.", "\"There,\" he says. \"Now we are both wrong.\""])
		return true
	if Game.active_is("bell"):
		await n.say(["\"Not in here,\" the King says, asleep. \"Ring it in here and I will hear it in there.\""])
		return true
	if Game.has_flag("king_disturbed"):
		await n.say([
			"He is asleep. Asleep-er, if anything, the way people sleep after a fright.",
			"You do not whisper. There is somebody tall in the keep now and you would rather not draw attention.",
		])
		return true
	var where := "on his throne, sideways, the way a child sleeps in a car." if visit_count < 2 else "on the iron bed, on top of the covers, in his robes, the way a child sleeps in a car."
	var count := Game.bump("king_whispers")
	match count:
		1:
			await n.say([
				"The King is asleep " + where,
				"His crown has slipped over one eye. You whisper. He does not wake.",
				"\"...not yet,\" he says, from somewhere under the sleep. \"the hour is not yet.\"",
			])
			Game.note("king", "The sleeping King", "The King of the Keep of Hours sleeps with his crown over one eye. He talks in his sleep. He says the hour is not yet.")
		2:
			await n.say([
				"You whisper again, closer. The candles lean away from you.",
				"\"...who is that,\" the King says, not waking. \"is that me. tell him to go back to bed.\"",
			])
		_:
			Game.set_flag("king_disturbed", true)
			Audio.sfx("clock_chime", n.global_position, -2.0)
			await n.say([
				"You say it a third time, and this time you say it out loud.",
				"The King's hand closes on the arm of the throne. Every clock in the keep ticks once, together, and stops again.",
				"He does not wake. But something has been let in, to see what you did.",
			])
			Game.note("king_disturbed", "You nearly woke him", "You whispered to the King three times and the third time was not a whisper. Every clock in the keep ticked once. Something tall came to see.")
			_summon_usher()
	return true


func _summon_usher() -> void:
	if usher_summoned or not is_inside_tree():
		return
	usher_summoned = true
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var where := Vector3(3.8, 0, -15.8) if visit_count < 2 else Vector3(-13.0, 0, -3.5)
		Usher.spawn(self, where, {"appear_delay": 0.8, "radius": 24.0, "vanish_delay": 2.0})
		Game.toast.emit("Something tall has come in to see what you did."))


func _on_tapestry_cut(_c: Node) -> void:
	Audio.sfx("wind_gust", Vector3(0, 1.5, -26.0), -6.0)
	Game.toast.emit("Behind the tapestry: a stair going up, out of the keep, into the night.")
	Game.note("tapestry_cut", "Behind the tapestry", "You cut the tapestry behind the throne. Behind it a stair climbs out of the keep into the open sky, toward a room hung from chains.")


func _on_chest(_p: Node, _it: Node) -> void:
	if Game.has_flag("castle_chest_open"):
		return
	Game.set_flag("castle_chest_open", true)
	Audio.sfx("creak", chest_pos, -6.0)
	_open_chest(true)
	if World.hud:
		await World.hud.say("", ["The lid comes up with a sound like a held breath let go.", "Inside: a candle stub, black wax, lit from both ends and, somehow, the middle. Nothing else. A chest this size, for that."])


func _open_chest(animate: bool) -> void:
	if chest_lid != null and is_instance_valid(chest_lid):
		if animate:
			var tw := create_tween()
			tw.tween_property(chest_lid, "rotation:x", deg_to_rad(105.0), 0.6).set_ease(Tween.EASE_OUT)
		else:
			chest_lid.rotation.x = deg_to_rad(105.0)
	if chest_it != null and is_instance_valid(chest_it):
		chest_it.enabled = false
	Pickup.create(self, chest_pos + Vector3(0, 0.3, 0), {"item": "candle_stub", "name": "ChestCandle", "key": "picked_candle_castle"})


func _book_closes(_l: Node) -> void:
	if open_book == null or closed_book == null or not open_book.visible:
		return
	open_book.visible = false
	closed_book.visible = true
	Audio.sfx("page", closed_book.global_position, -14.0)
	if Game.bump("shy_book_closed") == 3:
		Game.note("shy_book", "The shy book", "There is a book in the library that is open whenever you are not looking at it and shut whenever you are. You have caught it three times. It has caught you more.")


func _book_opens(_l: Node) -> void:
	if open_book == null or closed_book == null or open_book.visible:
		return
	open_book.visible = true
	closed_book.visible = false


func _on_library_loop(_p: Node) -> void:
	var n := Game.count("library_loops")
	if n == 1:
		Game.toast.emit("The aisle continues. You pass the same lectern again. You did not turn round.")
	elif n == 3:
		Game.note("infinite_library", "The library does not end", "The library of the Keep of Hours goes on. You have passed the same lectern three times walking in a straight line, and you recognised a spine.")
		Game.toast.emit("You recognise a spine.")
	elif n == 6:
		Game.toast.emit("The shelves are reading you now. It is only fair.")


# --- hooks --------------------------------------------------------------------------------------

func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if n == 1:
		Game.note("keep_of_hours", "The Keep of Hours", "A keep at night where every clock has stopped at half past five. The King is asleep on his throne. Everything in the place is arranged around not waking him.")
	elif n == 2:
		Game.note("keep_second", "The keep, the second time", "The great clock has moved one minute. The King is not on his throne; he has gone to bed in the west wing, and the throne is still warm.")
	if spawn_id == "wardrobe":
		Game.toast.emit("You climb out of the back of a wardrobe, into a bedchamber.")
		Game.note("shelf_door", "The shelf and the wardrobe", "One shelf in the library has a book pushed in. Behind it, a long way off, is the back of a wardrobe in the keep's west wing.")


func on_bell(_origin: Vector3) -> void:
	var n := Game.bump("castle_bells")
	if king != null and is_instance_valid(king):
		Audio.sfx("clock_chime", king.global_position, -8.0)
		Game.toast.emit("The King's crown slips a little further over one eye. He does not wake.")
	if n == 3:
		Game.note("keep_bells", "Bells in the keep", "You have rung the Small Bell three times in the Keep of Hours. Somewhere behind the great clock, something that was trying has started trying harder.")
	# hook for later: enough bells here and the great clock starts, one tick at a time.


func on_time_frozen(frozen: bool) -> void:
	if frozen and not steadied:
		steadied = true
		Game.toast.emit("The turning rooms steady. Every wall in the keep holds its breath.")
		Game.note("hours_steadied", "The hours, steadied", "With the Hourglass turned, the rooms in the keep stop turning. The gaps in their walls stay where they are, which is all you ever wanted from a wall.")


func _process(delta: float) -> void:
	_t += delta
	for i in fire_lights.size():
		var l := fire_lights[i] as OmniLight3D
		if l != null and is_instance_valid(l):
			var base := float(l.get_meta("base", 1.0))
			l.light_energy = base * (1.0 + 0.12 * sin(_t * 9.0 + i * 1.7) + 0.06 * sin(_t * 23.0 + i))
	for f in flames:
		var n := f as Node3D
		if n != null and is_instance_valid(n):
			n.scale = Vector3(1.0 + 0.06 * sin(_t * 11.0), 1.0 + 0.12 * sin(_t * 7.0 + 0.5), 1.0 + 0.06 * cos(_t * 9.0))
