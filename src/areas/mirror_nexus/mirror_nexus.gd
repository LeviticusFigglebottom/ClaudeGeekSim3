extends AreaBase
## The Other Anteroom — the Anteroom as the bathroom mirror shows it. Reversed,
## drained of colour, and mostly painted shut. Only three ways out: the iron
## door down to the Furnace, the mirror back to the flat, and a crack in the
## wall that lets you into the real Anteroom from the wrong side.

const R := 13.0
const TOP_Y := 20.4

var open := false        # the dark glass has been held to the Keep's mirror: no roof


func build() -> void:
	open = Game.has_flag("mirror_open")
	Realm.apply(self, "mirror", {"ambient_energy": 1.2, "ambient": "#6aa0a0", "fog_density": 0.02 if not open else 0.012, "sky_opts": {"tint": Color(0.6, 0.9, 0.9)}})
	var tint := Color(0.55, 0.8, 0.8)
	Kit.ring(self, Vector3.ZERO, 0.0, R + 1.0, 36, "stone/blocks_nexus", {"tint": tint})
	Kit.round_wall(self, Vector3.ZERO, R, 9.0, 36, "stone/blocks_nexus", {"tint": tint})
	if not open:
		Kit.ring(self, Vector3(0, 9.0, 0), 5.0, R + 1.0, 36, "stone/blocks_nexus", {"down": true, "tint": tint})
	var q := QuadMesh.new()
	q.size = Vector2(9.0, 9.0)
	Kit.add_mesh(self, q, Kit.mat("props/rune_ring_floor", {"tint": tint}), Vector3(0, 0.03, 0), {"solid": false, "rotation": Vector3(-90, 180, 0)})
	# the well is a mirror here: the way home
	Kit.cylinder(self, Vector3.ZERO, 1.6, 0.9, "stone/marble_black", {"tint": tint})
	Mirror.create(self, Vector3(0, 1.9, 0), 180.0, "apartment", "mirror", {"model": "mirror_tall", "name": "HomeMirror", "lines_without": ["The mirror shows a bathroom. Yours.", "You are not in it. You are in here."]})
	Kit.light(self, Vector3(0, 3.0, 0), Color(0.6, 1.0, 1.0), 2.2, 14.0)
	# reversed plaque
	Kit.box(self, Vector3(0, 0.5, -4.2), Vector3(1.2, 1.0, 0.4), "stone/blocks_nexus", {"tint": tint})
	Readable.create(self, Vector3(0, 1.05, -4.0), 0.0, "Read the plaque", [".ETAL ERA UOY .EREH TIAW", "You can read it. That is the worrying part."], {"name": "PlaqueMirror", "sign": "signs/plaque_mirror", "sign_size": Vector2(1.0, 0.5), "size": Vector3(1.2, 0.6, 0.2), "note_key": "plaque_mirror", "note_title": "The other plaque", "note_text": "You are late. Wait here. On this side the waiting has already happened."})
	# twelve arches, painted shut, reversed names
	for i in 12:
		var angle := -(i * 30.0 + 270.0)
		var yaw := Kit.yaw_to_center(angle)
		Kit.arch(self, Kit.polar(R - 0.9, angle), yaw, 1.5, 2.8, "stone/blocks_nexus", {"depth": 0.7, "post": 0.45, "top": 0.5, "tint": tint})
		var nm := World.area_name(AreaRegistry.ids()[mini(i + 4, AreaRegistry.ids().size() - 1)])
		Kit.label(self, nm.reverse(), Kit.polar(R - 1.35, angle, 3.7), yaw, 40, Color(0.7, 0.9, 0.9), "display", {"pixel_size": 0.016})
		Kit.box(self, Kit.polar(R - 0.5, angle, 1.4), Vector3(1.5, 2.8, 0.15), "wood/door_dark", {"tint": Color(0.4, 0.6, 0.6), "yaw": yaw})
		Props.place(self, "pillar_nexus", Kit.polar(R - 1.6, angle + 15.0), 0.0, 1.0, {"collision": "cylinder", "tint": tint})
		Kit.light(self, Kit.polar(R - 3.5, angle, 5.0), Color(0.5, 0.9, 0.9), 1.1, 9.0)
	# the three real exits
	var fa := -120.0
	Door.create(self, Kit.polar(R - 0.45, fa), Kit.yaw_to_center(fa), "furnace", "from_mirror", {"kind": "iron", "label": "Down", "name": "Door_furnace", "fade_color": Color(0.3, 0.02, 0.02), "fade_duration": 1.2})
	Kit.light(self, Kit.polar(R - 2.2, fa, 3.0), Color(1.0, 0.3, 0.15), 1.6, 9.0)
	Kit.particles(self, Kit.polar(R - 2.0, fa, 0.3), "embers", Vector3(1.5, 0.5, 1.5), 20)
	add_spawn("from_furnace", Kit.polar(R - 3.2, fa, 0.1), Kit.yaw_to_center(fa))
	var ca := -60.0
	var crack := Door.create(self, Kit.polar(R - 0.4, ca), Kit.yaw_to_center(ca), "nexus", "from_mirror", {"kind": "none", "label": "Squeeze through the crack", "name": "Crack", "fade_color": Color.WHITE, "fade_duration": 0.9})
	crack.add_box(Vector3(1.0, 2.6, 0.8), Vector3(0, 1.3, 0))
	Kit.label(self, "|", Kit.polar(R - 0.2, ca, 1.4), Kit.yaw_to_center(ca), 160, Color(1, 1, 1), "body", {"pixel_size": 0.02})
	Kit.light(self, Kit.polar(R - 1.5, ca, 1.5), Color(1, 1, 1), 1.0, 5.0)
	add_spawn("default", Vector3(0, 0.1, 5.0), 180.0)
	add_spawn("open", Vector3(0, 0.1, 5.0), 180.0)
	Puzzle.declare(self, "mirror_up", "", ["flag:mirror_open"], "with the roof off, walk the platforms round and up to the door at the top", {"route": "hospital:from_mirror"})
	if open:
		_spiral()
	else:
		add_spawn("top", Vector3(0, 0.1, 5.0), 180.0)
	# what exists only in mirror-sight: a walkway up to the oculus
	var walk := Node3D.new()
	walk.name = "MirrorWalk"
	add_child(walk)
	for k in 8:
		Kit.box(walk, Kit.polar(4.0 + k * 0.9, 90.0 + k * 20.0, 1.0 + k * 0.9), Vector3(1.6, 0.2, 1.6), "stone/marble_white", {"tint": Color(0.6, 1.0, 1.0)})
	Kit.mirror_only(walk)
	Readable.create(self, Kit.polar(10.3, 230.0, 8.0), Kit.yaw_to_center(230.0), "Look through the oculus", ["Above the oculus there is another Anteroom, and above that another.", "Each one is slightly more tired."], {"name": "Oculus", "size": Vector3(1.6, 1.0, 1.6), "note_key": "mirror_stack", "note_title": "The stacked Anterooms", "note_text": "Through the mirrored oculus: rooms above rooms, all waiting."})
	if not open:
		Kit.mirror_only(get_node("Oculus"))
	Usher.spawn(self, Vector3(-4, 0, 3), {"start_visible": true, "vanish_delay": 3.0})
	Kit.particles(self, Vector3(0, 3, 0), "motes", Vector3(10, 3, 10), 50)
	Game.note("mirror_side", "The other side", "Through the shard the bathroom mirror was a door, and the room behind it was the Anteroom, reversed. Every door is painted shut except the one going down.")


## With the roof off, the platforms are real: a stair of slabs going round the
## wall and up, past where the oculus was, to a landing in the open and a
## door into the next Anteroom, which is not an Anteroom.
func _spiral() -> void:
	var tint := Color(0.6, 1.0, 1.0)
	var n := 50
	var a_end := 0.0
	var r_end := 0.0
	for k in n:
		var r := 6.0 + k * 0.1
		var a := 150.0 + k * 9.0
		var y := 0.6 + k * 0.4
		Kit.box(self, Kit.polar(r, a, y - 0.1), Vector3(2.0, 0.2, 2.0), "stone/marble_white", {"tint": tint, "yaw": -a, "tile": 1.0})
		if k % 10 == 5:
			Kit.light(self, Kit.polar(r - 1.5, a, y + 1.5), Color(0.6, 1.0, 1.0), 0.8, 7.0)
		a_end = a
		r_end = r
	var top := Kit.polar(r_end, a_end + 9.0, TOP_Y - 0.1)
	Kit.cylinder(self, top - Vector3(0, 0.2, 0), 2.2, 0.3, "stone/marble_white", {"tint": tint, "segments": 12})
	Kit.arch(self, top + Vector3(0, 0.05, 0) + Kit.polar(1.6, a_end + 9.0), Kit.yaw_to_center(a_end + 9.0) + 180.0, 1.5, 2.8, "stone/blocks_nexus", {"depth": 0.5, "post": 0.45, "top": 0.5, "pointed": true, "tint": tint})
	Door.create(self, top + Vector3(0, 0.05, 0) + Kit.polar(1.6, a_end + 9.0), Kit.yaw_to_center(a_end + 9.0) + 180.0, "hospital", "from_mirror", {"kind": "dark", "label": "Up, into the next one", "name": "Door_up", "fade_color": Color(0.9, 0.95, 0.9), "fade_duration": 1.4})
	Kit.light(self, top + Vector3(0, 2.5, 0), Color(0.9, 1.0, 0.95), 1.4, 9.0)
	add_spawn("top", top + Vector3(0, 0.15, 0) - Kit.polar(1.2, a_end + 9.0), Kit.yaw_to_center(a_end + 9.0) + 180.0)
	Readable.create(self, Vector3(0, 1.4, -3.0), 0.0, "Look up", [
		"The roof is gone. Not fallen: gone, the way a thing is gone from a mirror when you turn it face down. Above the wall, the platforms that only the shard could see go round and up, and they are solid now, and the sky over them is a ceiling with a light in it.",
		"Each Anteroom above this one is slightly more tired. The one at the top is a building.",
	], {"name": "RoofLook", "size": Vector3(3.0, 2.0, 3.0), "note_key": "mirror_open", "note_title": "The roof off", "note_text": "With the dark glass held to the Keep's mirror the Other Anteroom has no roof. The platforms the shard showed are solid, and go round and up to a door into the next one, which is a hospital."})


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if open and not Game.has_note("mirror_open_in"):
		Game.note("mirror_open_in", "Through the dark glass", "The dark glass held to the bedchamber mirror opened onto the Other Anteroom with its roof off.")
	# you arrive looking through the shard; keep it that way
	if Game.has_keepsake("shard"):
		Game.equip("shard")
		Game.mirror_sight = true
