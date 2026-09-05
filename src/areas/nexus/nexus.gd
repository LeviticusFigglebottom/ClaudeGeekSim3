extends AreaBase
## The Anteroom — the hub. A rotunda of twelve doors around a well, under an
## oculus of indigo sky. Doors to places you have not dreamt of yet are
## painted shut; they open as the world remembers them. Yume Nikki's Nexus, in
## a colder building.

const R := 13.0
const DOORS := [
	# id, angle (0 = +X, 90 = +Z), kind, requires ({}), lock text, light colour
	["forest", 270, "dark", {}, "", Color(0.5, 1.0, 0.85)],
	["city", 300, "iron", {}, "", Color(0.8, 0.85, 1.0)],
	["tavern", 330, "red", {}, "", Color(1.0, 0.7, 0.35)],
	["house", 0, "white", {"requires_flag": "visited_house"}, "A door painted on the wall. Someone painted a house behind it. You have not been there yet.", Color(0.9, 0.9, 1.0)],
	["castle", 30, "big", {"requires_flag": "nexus_bell_rung"}, "A door this heavy needs to be reminded that it is a door. Something that rings would do it; the Drowned City keeps a small one under its cathedral.", Color(0.8, 0.6, 1.0)],
	["sea", 60, "none", {"requires_flag": "visited_sea"}, "The archway is full of painted water. It is not wet yet.", Color(1.0, 0.75, 0.9)],
	["catacombs", 90, "dark", {"requires_flag": "visited_catacombs"}, "Bones are mortared across the opening. From the other side, maybe.", Color(1.0, 0.6, 0.3)],
	["furnace", 120, "iron", {"requires_flag": "visited_furnace"}, "The iron is warm. It is bolted from below.", Color(1.0, 0.3, 0.15)],
	["cistern", 150, "white", {"requires_flag": "visited_cistern"}, "Tiles, floor to lintel. Water runs down them from nowhere.", Color(0.55, 0.9, 0.9)],
	["offices", 180, "white", {"requires_flag": "visited_offices"}, "A number is printed on the door: 0000. Please wait.", Color(1.0, 0.95, 0.8)],
	["clocktower", 210, "iron", {"requires_item": "tower_key"}, "A keyhole shaped like a clock hand. You have nothing that shape.", Color(1.0, 0.85, 0.5)],
	["static", 240, "none", {}, "", Color(0.8, 0.8, 0.8)],
]

var castle_door: Door = null
var workshop_door: Node3D = null


func build() -> void:
	Realm.apply(self, "nexus", {"sky_opts": {"detail_strength": 0.7, "detail_scale": 8.0}})
	# floor, wall, ceiling ring with an oculus
	Kit.ring(self, Vector3.ZERO, 0.0, R + 1.0, 36, "stone/blocks_nexus")
	Kit.ring(self, Vector3(0, 0.02, 0), 3.2, 4.6, 36, "stone/marble_black", {"solid": false})
	Kit.round_wall(self, Vector3.ZERO, R, 9.0, 36, "stone/blocks_nexus")
	Kit.ring(self, Vector3(0, 9.0, 0), 5.0, R + 1.0, 36, "stone/blocks_nexus", {"down": true})
	Kit.ring(self, Vector3(0, 9.0, 0), 4.6, 5.4, 36, "metal/brass", {"solid": false})
	# rune ring on the floor
	var q := QuadMesh.new()
	q.size = Vector2(9.0, 9.0)
	Kit.add_mesh(self, q, Kit.mat("props/rune_ring_floor", {"unshaded": false}), Vector3(0, 0.03, 0), {"solid": false, "rotation": Vector3(-90, 0, 0)})
	# the well
	var well := Props.place(self, "well", Vector3.ZERO, 0.0, 1.3, {"collision": "cylinder"})
	well.name = "Well"
	Readable.create(self, Vector3(0, 0, 0), 0.0, "Look into the well", [], {"name": "WellLook", "size": Vector3(2.8, 1.2, 2.8), "on_read": _on_well, "sound": "drip"})
	var all_nine: Array = []
	for k in Game.KEEPSAKES.keys():
		all_nine.append("keepsake:" + String(k))
	Puzzle.declare(self, "nexus_well", "cistern_drained", all_nine, "hold all nine keepsakes over the well in the Anteroom at once")
	Kit.light(self, Vector3(0, 2.5, 0), Color(0.5, 0.6, 1.0), 1.2, 9.0)
	# plaque
	Kit.box(self, Vector3(0, 0.5, 4.2), Vector3(1.2, 1.0, 0.4), "stone/blocks_nexus")
	Readable.create(self, Vector3(0, 1.05, 4.0), 180.0, "Read the plaque", [
		"YOU ARE EARLY. WAIT HERE.",
		"Under it, scratched with something sharp: \"waited. still waiting. the doors are the waiting.\"",
	], {"name": "Plaque", "sign": "signs/plaque_anteroom", "sign_size": Vector2(1.0, 0.5), "size": Vector3(1.2, 0.6, 0.2), "note_key": "plaque", "note_title": "The plaque in the Anteroom", "note_text": "You are early. Wait here. Somebody else waited too, and scratched about it."})
	# pillars and cold lanterns between the doors
	for i in 12:
		var a := i * 30.0 + 15.0
		Props.place(self, "pillar_nexus", Kit.polar(R - 1.6, a), 0.0, 1.0, {"collision": "cylinder"})
		Props.place(self, "lantern_hanging_cold", Kit.polar(R - 4.0, a, 6.5), 0.0, 1.0, {"collision": "none"})
		Kit.light(self, Kit.polar(R - 4.0, a, 5.6), Color(0.6, 0.85, 0.85), 0.55, 7.0)
	# the doors
	for d in DOORS:
		_door(d)
	# hidden thirteenth door
	workshop_door = Door.create(self, Kit.polar(R - 0.6, 255.0, 0.0), Kit.yaw_to_center(255.0), "workshop", "default", {"kind": "white", "label": "A very small door", "name": "Door_workshop"})
	workshop_door.scale = Vector3(0.5, 0.5, 0.5)
	workshop_door.visible = Game.has_flag("workshop_open")
	workshop_door.enabled = Game.has_flag("workshop_open")
	# spawns
	add_spawn("default", Vector3(0, 0.1, 6.0), 0.0)
	add_spawn("from_hallway", Kit.polar(R - 3.5, 255.0, 0.1), Kit.yaw_to_center(255.0))
	add_spawn("from_workshop", Kit.polar(R - 3.5, 255.0, 0.1), Kit.yaw_to_center(255.0))
	add_spawn("from_mirror", Vector3(0, 0.1, -6.0), 180.0)
	# the King's dream lets go of you here, beside the well, with no door to show for it
	add_spawn("from_kings_dream", Vector3(-4.6, 0.1, 0.0), -90.0)
	Kit.particles(self, Vector3(0, 3, 0), "motes", Vector3(10, 3, 10), 70)
	Puzzle.declare(self, "nexus_bell", "nexus_bell_rung", ["keepsake:bell"], "ring the Small Bell in the Anteroom")
	Puzzle.declare(self, "workshop_secret", "workshop_open", ["keepsake:bell"], "ring the bell thirteen times where the doors can hear it")
	if visit_count >= 2 and Game.count("usher_sightings") < 9:
		Usher.spawn(self, Kit.polar(R - 3.0, 255.0), {"appear_delay": 4.0})
	Dog.maybe_spawn(self, Vector3(3, 0.1, 5))
	if Game.has_flag("visited_house") and not Game.has_flag("visited_house_nexus_note"):
		Game.set_flag("visited_house_nexus_note", true)
		Game.note("house_door", "A door that remembers", "The painted door to the house is a real door now. The Anteroom collects the places you have been.")


func _door(d: Array) -> void:
	var id: String = d[0]
	var angle := float(d[1])
	var kind: String = d[2]
	var reqs: Dictionary = d[3]
	var lock_text: String = d[4]
	var col: Color = d[5]
	var yaw := Kit.yaw_to_center(angle)
	var base := Kit.polar(R - 0.45, angle)
	var arch_tex := "stone/blocks_nexus"
	var floor_tex := ""
	match id:
		"forest":
			floor_tex = "nature/grass_moss"
		"city":
			floor_tex = "stone/cobble_city"
			arch_tex = "stone/blocks_city"
		"tavern":
			floor_tex = "wall/carpet_tavern"
			arch_tex = "wood/planks_wall"
		"house":
			floor_tex = "wall/carpet_house"
			arch_tex = "wall/wallpaper_damask"
		"castle":
			floor_tex = "wall/carpet_red"
			arch_tex = "stone/blocks_castle"
		"sea":
			floor_tex = "ground/sand"
			arch_tex = "stone/blocks_sea"
		"catacombs":
			floor_tex = "ground/dirt"
			arch_tex = "organic/bones"
		"furnace":
			floor_tex = "ground/ash"
			arch_tex = "stone/blocks_furnace"
		"cistern":
			floor_tex = "wall/tile_checker"
			arch_tex = "wall/tile_white"
		"offices":
			floor_tex = "wall/carpet_office"
			arch_tex = "wall/plaster_yellow"
		"clocktower":
			floor_tex = "stone/blocks_clocktower"
			arch_tex = "metal/brass"
		"static":
			floor_tex = "common/static"
			arch_tex = "metal/iron"
	# floor patch and arch
	var patch_pos := Kit.polar(R - 2.4, angle, 0.015)
	Kit.floor(self, patch_pos, Vector2(3.2, 3.6), floor_tex, {"solid": false, "yaw": yaw, "thick": 0.03})
	var arch_h := 3.6 if kind == "big" else 2.8
	var arch_w := 2.0 if kind == "big" else 1.5
	Kit.arch(self, Kit.polar(R - 0.9, angle), yaw, arch_w, arch_h, arch_tex, {"depth": 0.7, "post": 0.45, "top": 0.5, "pointed": id != "offices" and id != "static"})
	var opts := {"kind": kind, "name": "Door_" + id, "label": "Go to " + World.area_name(id) if id != "static" else "Step into the static"}
	if reqs.has("requires_flag"):
		opts["requires_flag"] = reqs.requires_flag
	if reqs.has("requires_item"):
		opts["requires_item"] = reqs.requires_item
	if lock_text != "":
		opts["locked_text"] = lock_text
	if id == "static":
		opts["fade_color"] = Color.WHITE
		opts["fade_duration"] = 0.2
		opts["sound"] = "static_burst"
	var door := Door.create(self, base, yaw, id, "from_nexus", opts)
	if id == "castle":
		castle_door = door
	if kind == "none":
		# a portal surface in the archway
		var q := QuadMesh.new()
		q.size = Vector2(1.5, 2.8)
		var m: Material
		if id == "static":
			m = Kit.static_mat({"brightness": 0.9})
		else:
			m = Kit.mat("nature/water_sea", {"unshaded": true, "scroll": Vector2(0.02, 0.05), "emission": Color(0.4, 0.3, 0.5), "emission_energy": 0.5})
		Kit.add_mesh(door, q, m, Vector3(0, 1.4, 0), {"solid": false, "rotation": Vector3(0, 180, 0)})
	# carved name above the arch and a coloured light
	# the pillars stand 15 degrees either side of the door: a long name is set
	# smaller so its ends stay in front of the wall and not inside a pillar
	var name_size := mini(40, int(40.0 * 12.0 / maxf(12.0, float(World.area_name(id).length()))))
	Kit.label(self, World.area_name(id), Kit.polar(R - 1.35, angle, arch_h + 0.9), yaw, name_size, Color(0.85, 0.8, 0.65), "display", {"pixel_size": 0.016})
	Kit.light(self, Kit.polar(R - 2.2, angle, 3.2), col, 0.9, 7.0)
	# decorations per realm
	var left := Kit.polar(R - 1.8, angle - 8.0)
	var right := Kit.polar(R - 1.8, angle + 8.0)
	match id:
		"forest":
			Props.place(self, "mushroom_glow_small", left, 20.0, 1.2, {"collision": "none"})
			Props.place(self, "mushroom_glow_small", right + Vector3(0.3, 0, 0), 200.0, 0.8, {"collision": "none"})
			Props.place(self, "fern_cluster", right, 0.0, 1.0, {"collision": "none"})
			Props.place(self, "bush_1", left + Kit.polar(1.2, angle - 30.0), 40.0, 0.7, {"collision": "none"})
		"city":
			Props.place(self, "lantern_post_city", left, yaw, 0.8, {"collision": "cylinder"})
			Props.place(self, "rock_3", right, 70.0, 1.0)
			Props.place(self, "banner_eye", Kit.polar(R - 0.3, angle + 14.0, 5.5), yaw, 1.0, {"collision": "none"})
		"tavern":
			Props.place(self, "sign_last_lamp", left + Kit.polar(0.4, angle), yaw + 20.0, 0.75, {"collision": "cylinder"})
			Props.place(self, "barrel", right, 0.0, 0.9)
			Props.place(self, "lantern_hanging", Kit.polar(R - 1.4, angle, arch_h + 1.2), 0.0, 1.0, {"collision": "none"})
		"house":
			Props.place(self, "photo_0", Kit.polar(R - 0.15, angle - 10.0, 1.7), yaw, 1.0, {"collision": "none"})
			Props.place(self, "coat_rack", right, 0.0, 1.0)
		"castle":
			Props.place(self, "statue_knight", left + Kit.polar(0.5, angle - 30.0), yaw + 30.0, 1.0)
			Props.place(self, "statue_knight", right + Kit.polar(0.5, angle + 30.0), yaw - 30.0, 1.0)
			Props.place(self, "banner_key", Kit.polar(R - 0.3, angle - 13.0, 6.0), yaw, 1.0, {"collision": "none"})
			Props.place(self, "banner_key", Kit.polar(R - 0.3, angle + 13.0, 6.0), yaw, 1.0, {"collision": "none"})
		"sea":
			Props.place(self, "pillar_marble", left, 0.0, 0.6, {"collision": "cylinder"})
			Props.place(self, "pillar_marble", right, 0.0, 0.6, {"collision": "cylinder"})
		"catacombs":
			Props.place(self, "gravestone_blank", left, yaw + 15.0, 1.0)
			Props.place(self, "candle_cluster", right, 0.0, 1.4, {"collision": "none"})
			Props.place(self, "gravestone_you", right + Kit.polar(0.7, angle + 20.0), yaw - 20.0, 1.0)
		"furnace":
			Props.place(self, "chain_hanging", Kit.polar(R - 1.2, angle - 10.0, 9.0), 0.0, 1.0, {"collision": "none"})
			Props.place(self, "chain_hanging", Kit.polar(R - 1.6, angle + 11.0, 9.0), 0.0, 1.2, {"collision": "none"})
			Props.place(self, "cage", right + Kit.polar(0.6, angle + 20.0), 0.0, 0.7, {"collision": "box"})
			Kit.particles(self, Kit.polar(R - 2.0, angle, 0.3), "embers", Vector3(1.5, 0.5, 1.5), 18)
		"cistern":
			Props.place(self, "pillar_tiled", left, 0.0, 0.7, {"collision": "cylinder"})
			Props.place(self, "pillar_tiled", right, 0.0, 0.7, {"collision": "cylinder"})
			Kit.water(self, Kit.polar(R - 2.4, angle, 0.04), Vector2(3.0, 3.4), "nature/water_cistern", {"tint": Color(1, 1, 1, 0.55)})
		"offices":
			Kit.sign(self, "signs/take_a_number", Kit.polar(R - 0.15, angle + 12.0, 1.8), yaw, Vector2(1.0, 0.5))
			Props.place(self, "chair_white", left, yaw + 90.0, 1.0)
			Props.place(self, "plant_pot", right, 0.0, 1.0, {"collision": "none"})
		"clocktower":
			Kit.sign(self, "metal/clock_face", Kit.polar(R - 0.15, angle, arch_h + 2.2), yaw, Vector2(1.6, 1.6))
			Kit.sign(self, "metal/gear", Kit.polar(R - 0.15, angle - 12.0, 2.0), yaw, Vector2(1.0, 1.0))
			Props.place(self, "clock_grandfather", right + Kit.polar(0.3, angle + 12.0), yaw - 10.0, 1.0)
		"static":
			Props.place(self, "tv_crt", left, yaw + 25.0, 1.0)
			Props.place(self, "tv_crt", right, yaw - 30.0, 1.2)
			Props.place(self, "tv_crt", left + Vector3(0, 0.62, 0), yaw + 10.0, 0.8, {"collision": "none"})
	add_spawn("from_" + id, Kit.polar(R - 3.2, angle, 0.1), yaw)


## The well keeps count of the keepsakes. With all nine held over it at once
## it lets go of something at the bottom, and the Cistern begins to drain:
## the start of the fourth road, whose end is not made yet.
func _on_well(_r: Node) -> void:
	var n := Game.keepsakes.size()
	var lines: Array = []
	if Game.has_flag("cistern_drained"):
		lines = ["The well is not dry any more, and it is open at the bottom. Far down, water is going somewhere, a great deal of it, in no hurry.", "It is the sound of a bath the size of a cathedral emptying. It began when you held the nine things over it, and it is not finished."]
	elif n == 0:
		lines = ["The well is dry. At the bottom, very far down, something is arranged in a circle: nine empty places.", "You are holding nothing. It notices."]
	elif n < 9:
		lines = ["The well is dry. Nine places at the bottom, %d of them no longer empty." % n, "You are not sure when you put anything down there. Perhaps holding a thing is the same as putting it down, here."]
	else:
		if World.hud:
			await World.hud.say("", ["Nine places, nine things. The bottom of the well is a door now.", "It is not open yet. It is waiting for all nine at once, and there is only one way to hold nine things at once over a well."])
			var i: int = await World.hud.ask("", "Hold all nine over the well? Whatever is under the water will be under the water no longer.", ["Not yet.", "Hold them over the well."])
			if i != 1:
				return
		Game.set_flag("cistern_drained", true)
		Audio.sfx("drip", global_position, -2.0)
		lines = ["You hold them over the well, all nine, and the well takes the count, and something at the bottom gives.", "Not a door opening. A plug coming out. Far below, water begins to move, a very great deal of it, in no hurry: the sound of a bath the size of a cathedral emptying.", "The Cistern. Whatever was under the water will be there when it has gone."]
		Game.note("well_open", "The well let go", "With all nine keepsakes held over it at once, the well let go of something at the bottom, and far below a great deal of water began to move. The Cistern is draining. Whatever was under the water will be there when it has gone.")
		Game.toast.emit("Far below, a very great deal of water begins to move.")
	if World.hud:
		await World.hud.say("", lines)
	Game.note("well", "The well in the Anteroom", "A dry well with nine places at the bottom. It keeps count of what you carry.")


func on_bell(origin: Vector3) -> void:
	var n := Game.count("bells_rung")
	if not Game.has_flag("nexus_bell_rung"):
		Game.set_flag("nexus_bell_rung", true)
		Audio.sfx("stone_grind", castle_door.global_position if castle_door else origin, 0.0)
		Game.toast.emit("Somewhere in the wall, a heavy door remembers that it is a door.")
		Game.note("castle_door", "The heavy door", "Ringing the bell in the Anteroom woke the door with the banners. It leads to a keep, and the keep is asleep.")
	if n >= 13 and not Game.has_flag("workshop_open"):
		Game.set_flag("workshop_open", true)
		if workshop_door:
			workshop_door.visible = true
			workshop_door.enabled = true
		Audio.sfx("ui_confirm", null, -6.0)
		Game.toast.emit("A very small door has always been here. You are sure of it now.")
		Game.note("workshop", "The very small door", "Thirteen rings. A door the height of your knee, beside the static. It leads to where the props are kept.")


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if Game.has_keepsake("bell") and not Game.has_flag("nexus_bell_rung"):
		Game.toast.emit("The bell in your hand shifts. Across the room, the heavy door of the Keep is listening. (F to ring it.)")
