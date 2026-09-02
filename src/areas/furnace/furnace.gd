extends AreaBase
## The Furnace — below the below. An iron cathedral under everything else,
## lit from underneath. A pit of slow fire in the great hall with a grate
## bridge across it; a giant chained to the east wall, holding out, in one
## enormous hand, a kitchen knife; a forge where something is always being
## made; a gallery where a choir of shadows sings one note; a corridor of
## cages. You get here through the bathroom mirror. You leave by the iron
## door, which, from this side, has always been unbolted.
##
## ONE rasterised map (2 m cells, H 6.5); the pit is a `pit` region with its
## own faces, lava and a fall.

const CELL := 2.0
const H := 6.5
const ORIGIN := Vector3(-30.0, 0.0, -24.0)
const W := 30
const D := 22
const PIT_DEPTH := 3.0

var giant: Node3D = null
var choir: Array = []
var choir_singing := true
var _sing_t := 0.0
var pit_center := Vector3.ZERO


func build() -> void:
	Realm.apply(self, "furnace", {"ambient": "#8a2a2e", "ambient_energy": 1.35, "fog_density": 0.02})
	_plan()
	_anteroom()
	_mirror_chamber()
	_great_hall()
	_pit()
	_giant()
	_forge()
	_choir_gallery()
	_cages()
	Puzzle.declare(self, "furnace_knife", "", [], "the knife is in the chained giant's open hand; it is holding it out to you")
	Puzzle.declare(self, "furnace_maiden", "furnace_maiden_opened", [], "open the iron maiden in the forge", {"item": "candle_stub"})
	Puzzle.declare(self, "furnace_gallows", "gallows_cut", ["keepsake:knife"], "cut the rope on the gallows in the cage corridor")


# --- coordinates -----------------------------------------------------------------------

func _m(x: float, z: float, y: float = 0.0) -> Vector3:
	return Vector3(ORIGIN.x + x, y, ORIGIN.z + z)


func _cell(cx: float, cz: float, y: float = 0.0) -> Vector3:
	return _m((cx + 0.5) * CELL, (cz + 0.5) * CELL, y)


func _fire(pos: Vector3, energy: float = 1.4, reach: float = 9.0, color: Color = Color(1.0, 0.5, 0.2)) -> OmniLight3D:
	return Kit.light(self, pos, color, energy, reach)


# --- the plan --------------------------------------------------------------------------------

func _plan() -> void:
	var rects := [
		[1, 9, 6, 14, "a"],      # the anteroom (iron door)
		[1, 1, 6, 6, "m"],       # the mirror chamber
		[2, 6, 4, 9, "t"],       # the tunnel between them
		[8, 3, 22, 15, "h"],     # the great hall
		[12, 7, 18, 11, "p"],    # the pit (no floor)
		[8, 16, 22, 19, "c"],    # the choir gallery
		[24, 3, 29, 10, "f"],    # the forge
		[24, 12, 29, 20, "g"],   # the cages
	]
	var doors := [
		[6, 11, "D"], [7, 11, "D"],    # anteroom -> hall
		[22, 6, "D"], [23, 6, "D"],    # hall -> forge
		[12, 15, "D"], [17, 15, "D"],  # hall -> gallery
		[22, 17, "D"], [23, 17, "D"],  # gallery -> cages
	]
	var rows := MapBuilder.rasterize(W, D, rects, doors)
	var rooms := {
		"a": {"floor": "ground/ash", "wall": "stone/blocks_furnace", "ceiling": "stone/blocks_dark"},
		"m": {"floor": "stone/marble_black", "wall": "stone/blocks_furnace", "ceiling": "stone/blocks_dark"},
		"t": {"floor": "ground/ash", "wall": "stone/blocks_furnace", "ceiling": "stone/blocks_dark"},
		"h": {"floor": "ground/ash", "wall": "stone/blocks_furnace", "ceiling": "metal/rust"},
		"p": {"floor": "ground/ash", "wall": "stone/blocks_furnace", "ceiling": "metal/rust"},
		"c": {"floor": "organic/flesh_dark", "wall": "organic/flesh", "ceiling": "organic/flesh_dark"},
		"f": {"floor": "stone/blocks_dark", "wall": "brick/dark", "ceiling": "metal/rust"},
		"g": {"floor": "ground/ash", "wall": "metal/iron", "ceiling": "metal/grate"},
	}
	MapBuilder.build(self, rows, {
		"cell": CELL, "height": H, "origin": ORIGIN, "door_h": 4.0, "tile": 2.5,
		"floor": "ground/ash", "wall": "stone/blocks_furnace", "ceiling": "stone/blocks_dark",
		"rooms": rooms, "pit": "p", "outer_faces": true, "name": "Furnace",
	})


# --- the anteroom (x 2-12, z 18-28 plan) -------------------------------------------------------

func _anteroom() -> void:
	var c := _cell(3, 11)
	Door.create(self, _m(2.16, 23.0), -90.0, "nexus", "from_furnace", {"kind": "iron", "label": "The iron door. Unbolted, from this side.", "name": "IronDoor", "fade_color": Color(0.2, 0.02, 0.02), "fade_duration": 0.9, "sound": "door_heavy"})
	add_spawn("from_nexus", _m(4.0, 23.0, 0.1), -90.0)
	add_spawn("default", _m(4.0, 23.0, 0.1), -90.0)
	Brazier.create(self, _m(3.0, 20.0), {"lit": true, "toggleable": false})
	Brazier.create(self, _m(3.0, 26.0), {"lit": true, "toggleable": false})
	Props.place(self, "chain_hanging_long", c + Vector3(2.0, H - 0.1, -2.0), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "chain_hanging", c + Vector3(-1.0, H - 0.1, 2.5), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "bone_pile", _m(10.0, 26.5), 40.0, 1.0, {"collision": "none"})
	Readable.create(self, _m(6.0, 18.2, 2.0), 180.0, "Words over the arch", ["Hammered into the iron, letter by letter, by somebody with a lot of time: BELOW THE BELOW.", "Under it, smaller: and below that, you."], {"name": "ArchWords", "size": Vector3(2.0, 1.0, 0.4), "note_key": "furnace_arch", "note_title": "Below the below", "note_text": "Over the arch in the Furnace: BELOW THE BELOW. And below that, you."})
	Kit.label(self, "BELOW THE BELOW", _m(6.0, 18.06, 2.6), 180.0, 40, Color(0.9, 0.5, 0.3), "title", {"pixel_size": 0.014})
	Kit.water(self, _m(9.5, 21.0, 0.04), Vector2(2.4, 1.8), "nature/water_blood", {"tint": Color(1, 1, 1, 0.8), "subdiv": 2})
	Readable.create(self, _m(9.5, 21.0, 0.3), 0.0, "A puddle", ["It is not water. It is warm. It is very slightly moving, toward the hall."], {"name": "Puddle", "size": Vector3(2.0, 0.5, 1.6)})
	Kit.particles(self, c + Vector3(0, 2.5, 0), "ash", Vector3(4.0, 2.0, 4.0), 30)


# --- the mirror chamber (x 2-12, z 2-12 plan) -----------------------------------------------------

func _mirror_chamber() -> void:
	var c := _cell(3, 3)
	var gate := Door.create(self, _m(7.0, 2.2), 180.0, "mirror_nexus", "from_furnace", {"kind": "none", "label": "The mirror gate", "name": "MirrorGate", "requires_keepsake": "shard", "locked_text": "A mirror the size of a door. It shows the chamber. It does not show a way, and it does not show you.", "fade_color": Color(0.5, 0.9, 0.9), "fade_duration": 0.8, "sound": "shard"})
	gate.add_box(Vector3(2.0, 3.6, 0.6), Vector3(0, 1.8, 0))
	Props.place(self, "mirror_tall", _m(7.0, 2.3), 180.0, 1.8, {"collision": "none"})
	add_spawn("from_mirror", _m(7.0, 5.0, 0.1), 180.0)
	Kit.light(self, _m(7.0, 4.0, 3.0), Color(0.5, 0.9, 0.95), 1.2, 8.0)
	for i in 8:
		var p := c + Kit.polar(3.2, i * 45.0)
		Props.place(self, "candle_tall", p, 0.0, 1.0, {"collision": "none"})
		_fire(p + Vector3(0, 1.2, 0), 0.5, 4.0, Color(1.0, 0.7, 0.4))
	var ring_sign := Kit.sign(self, "props/rune_ring_floor", c + Vector3(0, 0.02, 0), 0.0, Vector2(6.0, 6.0), {"tint": Color(1.0, 0.6, 0.5)})
	ring_sign.rotation_degrees = Vector3(-90, 0, 0)
	Readable.create(self, c + Vector3(0, 0.3, 0), 0.0, "A ring on the floor", ["A ring of letters in the black marble, going the wrong way round.", "Read backwards, from the inside: EVERYTHING BELOW IS A REFLECTION OF SOMETHING ABOVE. FIND THE SOMETHING."], {"name": "FloorRing", "size": Vector3(3.0, 0.5, 3.0), "note_key": "furnace_ring", "note_title": "The ring on the floor", "note_text": "In the mirror chamber of the Furnace, in backwards letters: everything below is a reflection of something above."})
	Props.place(self, "pillar_flesh", _m(3.0, 3.0), 0.0, 1.0, {"collision": "cylinder"})
	Props.place(self, "pillar_flesh", _m(11.0, 3.0), 90.0, 1.0, {"collision": "cylinder"})
	Props.place(self, "eye_stalk", _m(2.4, 9.0), -90.0, 1.0, {"collision": "none"})
	Readable.create(self, _m(2.8, 9.0, 1.2), -90.0, "Something growing from the wall", ["An eye on a stalk, the height of your face. It follows you.", "When you hold up the shard it looks at that instead, and looks relieved."], {"name": "EyeStalk", "size": Vector3(0.8, 1.2, 0.8)})
	# the tunnel south
	_fire(_m(6.0, 15.0, 4.0), 0.9, 7.0)
	Props.place(self, "chain_hanging", _m(5.0, 14.0, H - 0.1), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "chain_hanging_long", _m(7.0, 16.5, H - 0.1), 0.0, 1.0, {"collision": "none"})


# --- the great hall (x 16-44, z 6-30 plan; pit x 24-36, z 14-22) --------------------------------------

func _great_hall() -> void:
	pit_center = _m(30.0, 18.0)
	# braziers round the pit, and pillars of flesh between them
	var spots := [Vector2(20, 9), Vector2(40, 9), Vector2(20, 27), Vector2(40, 27), Vector2(30, 9), Vector2(30, 27)]
	for s in spots:
		Brazier.create(self, _m(s.x, s.y), {"lit": true, "toggleable": false, "light_energy": 1.4, "light_range": 11.0})
	for s in [Vector2(18, 13), Vector2(18, 23), Vector2(42, 13), Vector2(42, 23)]:
		Props.place(self, "pillar_flesh", _m(s.x, s.y), 0.0, 1.3, {"collision": "cylinder"})
	# chains and cages from the iron ceiling
	var rng2 := rng
	for i in 10:
		var p := _m(18.0 + rng2.randf() * 24.0, 8.0 + rng2.randf() * 20.0, H - 0.1)
		if absf(p.x - pit_center.x) < 7.0 and absf(p.z - pit_center.z) < 5.0:
			p.y = H - 0.1
		Props.place(self, "chain_hanging_long" if i % 2 == 0 else "chain_hanging", p, rng2.randf_range(0, 360), 1.0, {"collision": "none"})
	Props.place(self, "cage", _m(21.0, 12.0, 2.6), 20.0, 0.9, {"collision": "none"})
	Props.place(self, "chain_hanging", _m(21.0, 12.0, H - 0.1), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "cage", _m(39.0, 24.0, 3.2), -30.0, 0.8, {"collision": "none"})
	Props.place(self, "chain_hanging", _m(39.0, 24.0, H - 0.1), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "spike_cluster", _m(17.0, 28.5), 0.0, 1.2)
	Props.place(self, "spike_cluster", _m(43.0, 7.5), 120.0, 1.0)
	Props.place(self, "meat_hook", _m(24.0, 8.0, H - 0.1), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "meat_hook", _m(36.0, 28.0, H - 0.1), 40.0, 1.0, {"collision": "none"})
	Readable.create(self, _m(17.0, 18.0, 1.6), -90.0, "Scratches on the wall", ["Tally marks, in groups of five, all the way up the wall and, when you look, all the way along the ceiling.", "Somebody counted the hours here. There are more marks than there have been hours."], {"name": "Tally", "size": Vector3(0.4, 2.0, 3.0), "note_key": "furnace_tally", "note_title": "Tally marks", "note_text": "Somebody in the Furnace counted the hours in fives. There are more marks than there have been hours."})
	Kit.particles(self, pit_center + Vector3(0, 3.0, 0), "ash", Vector3(14.0, 3.0, 12.0), 60)
	for s in [Vector2(20, 12), Vector2(20, 24), Vector2(40, 12), Vector2(40, 24), Vector2(30, 8), Vector2(30, 28)]:
		_fire(_m(s.x, s.y, H - 1.2), 1.8, 14.0, Color(1.0, 0.45, 0.25))
	Kit.label(self, "BELOW", _m(30.0, 6.06, 4.5), 180.0, 60, Color(0.8, 0.35, 0.2), "title", {"pixel_size": 0.016})


# --- the pit ---------------------------------------------------------------------------------------------

func _pit() -> void:
	var x0 := 24.0
	var x1 := 36.0
	var z0 := 14.0
	var z1 := 22.0
	var tex := "stone/blocks_furnace"
	var mid_y := -PIT_DEPTH * 0.5
	Kit.box(self, _m((x0 + x1) * 0.5, z0 + 0.05, mid_y), Vector3(x1 - x0, PIT_DEPTH, 0.1), tex, {"faces": ["pz"], "solid": false, "tile": 2.5})
	Kit.box(self, _m((x0 + x1) * 0.5, z1 - 0.05, mid_y), Vector3(x1 - x0, PIT_DEPTH, 0.1), tex, {"faces": ["nz"], "solid": false, "tile": 2.5})
	Kit.box(self, _m(x0 + 0.05, (z0 + z1) * 0.5, mid_y), Vector3(0.1, PIT_DEPTH, z1 - z0), tex, {"faces": ["px"], "solid": false, "tile": 2.5})
	Kit.box(self, _m(x1 - 0.05, (z0 + z1) * 0.5, mid_y), Vector3(0.1, PIT_DEPTH, z1 - z0), tex, {"faces": ["nx"], "solid": false, "tile": 2.5})
	Kit.floor(self, _m((x0 + x1) * 0.5, (z0 + z1) * 0.5, -PIT_DEPTH), Vector2(x1 - x0, z1 - z0), "ground/lava", {"unshaded": true, "emission": Color(1.0, 0.45, 0.1), "emission_energy": 1.4, "solid": false, "tile": 3.0})
	_fire(pit_center + Vector3(0, -1.2, 0), 3.2, 20.0, Color(1.0, 0.45, 0.15))
	_fire(pit_center + Vector3(-4.0, 0.6, 0), 1.2, 9.0, Color(1.0, 0.5, 0.2))
	_fire(pit_center + Vector3(4.0, 0.6, 0), 1.2, 9.0, Color(1.0, 0.5, 0.2))
	Kit.particles(self, pit_center + Vector3(0, -1.5, 0), "embers", Vector3(5.5, 1.0, 3.5), 70)
	# the fall
	Kit.trigger(self, pit_center + Vector3(0, -PIT_DEPTH + 0.9, 0), Vector3(x1 - x0 - 0.4, 1.6, z1 - z0 - 0.4), func(_p: Node) -> void:
		Game.bump("furnace_falls")
		World.fall_out(), {"name": "PitFall"})
	# a grate bridge across, with chains for a railing
	Kit.box(self, pit_center + Vector3(0, -0.1, 0), Vector3(x1 - x0 + 0.6, 0.2, 1.8), "metal/grate", {"tile": 1.0, "name": "Bridge"})
	for i in 5:
		var bx := x0 + 1.5 + i * 2.25
		Props.place(self, "chain_hanging_long", _m(bx, 17.1, H - 0.1), 0.0, 1.0, {"collision": "none"})
		Props.place(self, "chain_hanging_long", _m(bx, 18.9, H - 0.1), 0.0, 1.0, {"collision": "none"})
	Readable.create(self, pit_center + Vector3(0, 0.4, 0), 0.0, "The pit", ["Slow fire, a long way down. It is not burning anything. It is waiting to.", "The heat comes up through the grate in a way that feels like being looked at."], {"name": "PitRead", "size": Vector3(2.0, 0.8, 1.6), "note_key": "furnace_pit", "note_title": "The pit", "note_text": "A pit of slow fire under the great hall of the Furnace. It is not burning anything yet."})


# --- the giant ------------------------------------------------------------------------------------------

func _giant() -> void:
	var gp := _m(41.0, 18.0)
	if Game.has_keepsake("knife") and visit_count >= 2:
		Props.place(self, "chain_hanging_long", gp + Vector3(0, H - 0.1, -2.0), 0.0, 1.4, {"collision": "none"})
		Props.place(self, "chain_hanging_long", gp + Vector3(0, H - 0.1, 2.0), 0.0, 1.4, {"collision": "none"})
		Readable.create(self, gp + Vector3(-1.0, 1.5, 0), 90.0, "The empty chains", ["The chains are here. The giant is not.", "The links are not broken. Whatever held it was never the chains."], {"name": "EmptyChains", "size": Vector3(2.0, 3.0, 4.0), "note_key": "furnace_giant_gone", "note_title": "The empty chains", "note_text": "The giant that gave you the knife is gone from the Furnace. Its chains are intact. Something else was holding it."})
		return
	giant = Props.place(self, "giant_chained", gp, 90.0, 1.5, {"collision": "none", "name": "Giant"})
	Kit.blocker(self, gp + Vector3(0.4, 1.5, 0), Vector3(3.0, 3.0, 3.6))
	var hand := Props.part(giant, "Hand")
	var hand_pos: Vector3 = gp + Vector3(-2.6, 0.9, 0)
	if hand:
		hand_pos = hand.global_position + Vector3(0, 0.35, 0)
	Pickup.create(self, hand_pos, {"keepsake": "knife", "name": "KitchenKnife"})
	_fire(hand_pos + Vector3(-0.6, 0.8, 0), 1.2, 6.0, Color(1.0, 0.8, 0.6))
	Props.place(self, "chain_hanging_long", gp + Vector3(0, H - 0.1, -2.6), 0.0, 1.4, {"collision": "none"})
	Props.place(self, "chain_hanging_long", gp + Vector3(0, H - 0.1, 2.6), 0.0, 1.4, {"collision": "none"})
	NPC.create(self, gp + Vector3(-2.2, 0, 1.6), 90.0, "The Giant", {
		"model": "chain_hanging", "face_player": false, "turn_to_bell": false,
		"lines": ["(It does not speak. It holds out its hand, palm up, with something small and bright in it.)", "(A kitchen knife. Your kitchen knife. The one from the drawer.)", "(It nods, very slowly, at the knife, and then at you.)"],
		"reactions": {
			"knife": ["(It looks at the knife in your hand. It looks at its own empty hand.)", "(It closes the hand, and for the first time in a long time, rests.)"],
			"bell": ["(At the bell it turns its whole head, which takes a while, and something like a smile happens.)"],
			"crown": ["(It sees the crown and lowers its eyes, and then its head, and then the rest of it, as far as the chains allow.)"],
		},
	})
	Readable.create(self, gp + Vector3(-3.0, 3.5, 0), 90.0, "The giant", ["Chained at the wrists and the neck to the east wall, kneeling, because the ceiling is too low for it to stand.", "It is holding out its hand. There is a kitchen knife in it, which is small enough in that hand to be a splinter.", "It has been holding it out for a very long time."], {"name": "GiantRead", "size": Vector3(2.0, 3.0, 4.0), "note_key": "furnace_giant", "note_title": "The giant", "note_text": "A giant chained to the wall of the Furnace, kneeling, holding out a kitchen knife on its palm. It wants you to take it. It has wanted that for a long time."})


# --- the forge (x 48-58, z 6-20 plan) -------------------------------------------------------------------

func _forge() -> void:
	var c := _m(53.0, 13.0)
	Props.place(self, "furnace_mouth", _m(57.2, 13.0), 90.0, 1.4)
	_fire(_m(55.5, 13.0, 1.6), 2.6, 13.0, Color(1.0, 0.55, 0.2))
	Kit.particles(self, _m(56.0, 13.0, 1.5), "embers", Vector3(1.0, 1.0, 2.0), 30)
	Readable.create(self, _m(56.2, 13.0, 1.4), 90.0, "The furnace mouth", ["Fire, and behind the fire, a room, and in the room a table laid for dinner.", "The plates are warm. Nobody has come down to eat."], {"name": "FurnaceMouth", "size": Vector3(1.6, 2.0, 2.4), "note_key": "furnace_mouth", "note_title": "The furnace mouth", "note_text": "Inside the furnace in the Furnace: a room with a table laid for dinner. The plates are warm."})
	Props.place(self, "anvil", c + Vector3(-2.0, 0, 0), 0.0, 1.0)
	Interactable.make(self, c + Vector3(-2.0, 0.6, 0), Vector3(1.2, 0.8, 0.8), "Strike the anvil", func(_p: Node, it: Node) -> void:
		Audio.sfx("stone_grind", it.global_position, -4.0)
		Game.bump("anvil_strikes")
		if Game.count("anvil_strikes") == 7:
			Game.toast.emit("On the seventh strike the anvil rings like a bell, and somewhere above, a dog barks.")
			Game.note("furnace_anvil", "The anvil", "Struck seven times, the anvil in the Furnace rang like a bell. Something upstairs heard it.")
		else:
			Game.toast.emit("The anvil rings. The ring goes down instead of up."), {"name": "Anvil"})
	Props.place(self, "iron_maiden", _m(50.0, 7.0), 180.0, 1.0)
	Interactable.make(self, _m(50.0, 7.6, 1.2), Vector3(1.2, 2.4, 1.0), "Open the iron maiden", _on_maiden, {"name": "IronMaiden"})
	Props.place(self, "spike_cluster", _m(57.0, 19.0), 30.0, 0.9)
	Props.place(self, "meat_hook", _m(50.0, 17.0, H - 0.1), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "meat_hook", _m(52.0, 18.0, H - 0.1), 60.0, 1.0, {"collision": "none"})
	Props.place(self, "chain_hanging", _m(54.0, 8.0, H - 0.1), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "table_long", _m(52.5, 18.5), 0.0, 0.9)
	Props.place(self, "candle_cluster", _m(52.5, 18.5, 0.8), 0.0, 1.0, {"collision": "none"})
	_fire(_m(52.5, 18.5, 1.6), 0.8, 6.0, Color(1.0, 0.75, 0.45))
	Readable.create(self, _m(52.5, 18.5, 0.9), 0.0, "The workbench", ["Laid out on the bench: a door handle, a tap, a tooth, a key with no number, and a photograph frame with nothing in it.", "All of them yours, or shaped like yours."], {"name": "Workbench", "size": Vector3(2.4, 0.6, 1.0), "note_key": "furnace_bench", "note_title": "The workbench", "note_text": "On the bench in the Furnace's forge: things from your flat, or things shaped like them, being made or unmade."})
	NPC.create(self, _m(54.5, 10.5), 90.0, "The Stoker", {
		"model": "figure_shadow", "face_player": true, "flee_knife": true,
		"lines": ["Don't stand there. You're in the draught.", "Everything up there comes down here eventually to be made again. Doors. Taps. Faces.", "You'll want the knife. It's the giant's to give. Ask nicely, or don't ask; it doesn't mind."],
		"reactions": {
			"knife": ["Ah. It gave it you. Then I've no call to be standing near you.", "(It moves to the far side of the anvil, and stays there.)"],
			"lantern": ["Put that away. There's enough light in here to see by and then some."],
			"mouse": ["Small. Good. Small things don't get put in the furnace. Small things get lost, which is better."],
			"umbrella": ["It doesn't rain here. It has tried."],
		},
	})
	Brazier.create(self, _m(49.0, 12.0), {"lit": true, "toggleable": false, "light_energy": 1.0})
	Kit.sign(self, "signs/graffiti_wake", _m(48.06, 15.0, 2.2), -90.0, Vector2(1.8, 0.5))


# --- the choir gallery (x 16-44, z 32-38 plan) ---------------------------------------------------------

func _choir_gallery() -> void:
	for i in 7:
		var x := 19.0 + i * 3.6
		var f := Props.place(self, "figure_shadow", _m(x, 37.2), 0.0, 1.0 + 0.08 * (i % 3), {"collision": "none", "name": "Chorister%d" % i})
		choir.append(f)
	NPC.create(self, _m(30.0, 36.0), 0.0, "The Choir", {
		"model": "figure_shadow", "face_player": false, "flee_knife": false,
		"lines": ["(One note. All of them, the same note, for as long as you stand there.)", "(It is the note the fluorescent lights hum in the Halden Arms. It is the note the fridge makes.)", "(You realise you have been humming it since you arrived.)"],
		"reactions": {
			"bell": ["(The note stops. Seven heads turn to the bell.)", "(In the silence, one of them says, very quietly: thank you.)"],
			"knife": ["(The note goes up a semitone, and stays there.)"],
			"crown": ["(The note becomes a chord.)"],
		},
	})
	Kit.light(self, _m(30.0, 35.0, 4.5), Color(0.8, 0.4, 0.7), 2.0, 14.0)
	Kit.light(self, _m(20.0, 35.0, 4.0), Color(0.6, 0.3, 0.5), 0.9, 9.0)
	Kit.light(self, _m(40.0, 35.0, 4.0), Color(0.6, 0.3, 0.5), 0.9, 9.0)
	for x in [18.5, 41.5]:
		Props.place(self, "eye_stalk", _m(x, 33.0), 90.0 if x < 30.0 else -90.0, 1.0, {"collision": "none"})
	Readable.create(self, _m(30.0, 37.9, 2.6), 0.0, "Words behind the choir", ["Written on the flesh of the wall in letters that heal over as you read them: WE SING SO THAT IT DOES NOT WAKE.", "You do not ask what."], {"name": "ChoirWords", "size": Vector3(4.0, 1.4, 0.3), "note_key": "furnace_choir", "note_title": "The choir", "note_text": "Seven shadows in the Furnace sing one note so that something does not wake. The bell stops them, briefly. They thank you."})
	Kit.particles(self, _m(30.0, 35.0, 3.0), "motes", Vector3(12.0, 2.0, 2.0), 30)


# --- the cages (x 48-58, z 24-40 plan) ---------------------------------------------------------------

func _cages() -> void:
	var cage_spots := [Vector2(50.0, 26.0), Vector2(56.0, 28.5), Vector2(50.0, 31.5), Vector2(56.0, 34.0)]
	var lines := [
		["A cage, hanging. Empty.", "Somebody has scratched a calendar into the bars and given up in the second week."],
		["A cage, hanging. Inside it, a coat on a hook, swinging very slightly.", "It is the coat from the closet. It is exactly the coat."],
		["A cage, hanging, with a bell in it. The bell has no clapper.", "When you ring the Small Bell it answers anyway."],
		["A cage, hanging, and inside it, folded neatly, a tablecloth from a tavern.", "One corner is burned. The barkeep would want to know."],
	]
	for i in cage_spots.size():
		var s: Vector2 = cage_spots[i]
		Props.place(self, "cage", _m(s.x, s.y, 2.2), i * 40.0, 1.0, {"collision": "none"})
		Props.place(self, "chain_hanging", _m(s.x, s.y, H - 0.1), 0.0, 1.0, {"collision": "none"})
		Readable.create(self, _m(s.x, s.y, 2.6), 0.0, "A cage", lines[i], {"name": "Cage%d" % i, "size": Vector3(1.6, 2.0, 1.6)})
		_fire(_m(s.x, s.y, 4.2), 0.7, 6.0, Color(1.0, 0.4, 0.25))
	# the caged patron
	Props.place(self, "cage", _m(53.0, 38.0, 0.0), 0.0, 1.6, {"collision": "box"})
	NPC.create(self, _m(53.0, 38.0), 0.0, "Somebody in a cage", {
		"model": "patron_seated", "face_player": true, "flee_knife": false,
		"lines": ["I was at the Last Lamp. I went out the back door. You know how it is.", "They put me in here for the singing. I was not singing. I was humming. There is a difference and I have explained it.", "If you see the barkeep, tell him my tab stands."],
		"reactions": {
			"knife": ["That would do it. The lock is only rope. Everything here is only rope, if you have the right knife.", "(You cannot reach the rope from here. Try the gallows; it is the same rope.)"],
			"umbrella": ["Is it raining? Up there? I miss weather."],
			"mouse": ["You could get in here easily. I would not, if I were you."],
		},
	})
	# the gallows and the rope
	Props.place(self, "gallows", _m(53.0, 32.0), 0.0, 1.0)
	Cuttable.create(self, _m(53.0, 32.0, 2.0), 0.0, Vector3(0.4, 2.2, 0.4), {"tex": "metal/chain", "flag": "gallows_cut", "cut_text": "Cut the rope", "name": "GallowsRope", "on_cut": func() -> void:
		Game.note("furnace_rope", "The rope", "You cut the rope on the gallows in the Furnace. Every cage in the corridor swung open at once. The one who was humming did not leave. He said the tab stands.")
		Game.toast.emit("Every cage in the corridor swings open at once.")})
	Readable.create(self, _m(53.0, 31.0, 1.0), 0.0, "The gallows", ["A gallows with one rope. The rope runs up through a ring and away along the ceiling to every cage in the corridor.", "Cut it and nothing will hang from anything."], {"name": "GallowsRead", "size": Vector3(1.6, 1.4, 1.0)})
	Props.place(self, "spike_cluster", _m(49.0, 36.0), 70.0, 0.8)
	Props.place(self, "bone_pile", _m(57.0, 38.5), 0.0, 1.0, {"collision": "none"})
	_fire(_m(53.0, 36.0, 4.5), 1.6, 12.0, Color(1.0, 0.5, 0.3))
	_fire(_m(53.0, 26.0, 4.5), 1.4, 12.0, Color(1.0, 0.5, 0.3))
	Kit.sign(self, "signs/graffiti_door", _m(57.94, 30.0, 1.8), 90.0, Vector2(1.6, 0.4))
	if Game.has_flag("gallows_cut"):
		var opened := Props.place(self, "door_iron", _m(57.8, 36.0), 90.0, 0.8, {"collision": "none"})
		var leaf := Props.part(opened, "Leaf")
		if leaf:
			leaf.rotation.y = deg_to_rad(80.0)
		Readable.create(self, _m(57.4, 36.0, 1.2), 90.0, "A small iron door, open", ["A door you did not notice while it was shut. Behind it, stairs going up, and up, and a smell of tavern.", "(The stairs are not finished being dreamt. Next time.)"], {"name": "SmallIronDoor", "size": Vector3(0.6, 2.0, 1.2)})


# --- callbacks and hooks ------------------------------------------------------------------------------

func _on_maiden(_p: Node, _it: Node) -> void:
	Audio.sfx("door_heavy", _m(50.0, 7.0, 1.0), -6.0)
	if Game.has_flag("furnace_maiden_opened"):
		if World.hud:
			await World.hud.say("", ["Empty. Warm. The spikes on the inside are the shape of a person you are not."])
		return
	Game.set_flag("furnace_maiden_opened", true)
	if World.hud:
		await World.hud.say("", ["It opens easily. No spikes. Inside, on a little shelf: a black candle, burned from both ends and, somehow, the middle.", "You take it. The iron maiden closes itself, gently, like a book."])
	Game.gain_item("candle_stub")


func on_bell(_origin: Vector3) -> void:
	choir_singing = false
	for c in choir:
		if is_instance_valid(c):
			(c as Node3D).rotation.y += deg_to_rad(180.0)
	Game.toast.emit("The choir stops. For the first time in a long while, it listens.")
	get_tree().create_timer(9.0).timeout.connect(func() -> void:
		choir_singing = true)


func _process(delta: float) -> void:
	if not choir_singing:
		return
	_sing_t += delta
	if _sing_t > 7.0:
		_sing_t = 0.0
		Audio.sfx("whisper", _m(30.0, 36.0, 1.5), -9.0)


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if n == 1:
		Game.note("furnace", "The Furnace", "Below the below: an iron cathedral lit from underneath. A giant chained to a wall, holding out a kitchen knife. A choir singing one note so that something does not wake.")
	if spawn_id == "from_mirror" and not Game.has_note("furnace_mirror"):
		Game.note("furnace_mirror", "Through the mirror", "The bathroom mirror, held up to the shard, went through to the Other Anteroom, and from there a furnace door went down. You came out of a mirror in a chamber of black marble.")
