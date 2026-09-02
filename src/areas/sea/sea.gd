extends AreaBase
## The Slow Sea — a tide that takes a hundred years. A pale shore under a sky
## that cannot decide between lilac, rose and teal; a purple sea you can wade
## into; giant stone faces asleep in the sand (one of them talks in its
## sleep); a broken pier of grey planks with a white door at its end; and a
## helix of pastel platforms, some of them drifting, climbing over the shallows
## to the Moth Wings. Walk far enough along the beach and you arrive where you
## started.
##
## Return visits: the faces open their eyes, the sky starts on a different
## colour, and something enormous has come up out of the deep water.

const WRAP := 116.0            # the shore repeats every 116 m (the seams sit at ±58)
const SEAM_X := 58.0
const DECK := 0.9              # pier deck height
const PIER_X := 25.5
const TOP_Y := 11.75           # the highest platform
const CYCLE := 150.0           # seconds for the sky to go lilac -> rose -> teal -> lilac

const MINT := Color(0.78, 0.96, 0.88)
const ROSE := Color(0.98, 0.8, 0.88)
const LILAC := Color(0.82, 0.74, 0.98)
const CREAM := Color(1.0, 0.96, 0.9)

## Sky palette: [background, fog, ambient, sky tint]
const PALETTE := [
	[Color("2b1a47"), Color("b7a6f0"), Color("b7a6f0"), Color(1.0, 1.0, 1.0)],
	[Color("3a1a35"), Color("cf94b4"), Color("d8a2be"), Color(1.0, 0.84, 0.9)],
	[Color("12303a"), Color("78bcb6"), Color("88c6bf"), Color(0.72, 0.96, 0.9)],
]

## The climb: [top-centre (x, top height, z), kind] — "moving" entries carry the far end of their drift.
const CHAIN := [
	[Vector3(4.0, 1.0, -3.0), "large"],
	[Vector3(11.24, 1.75, -4.94), "medium"],
	[Vector3(14.39, 2.5, -9.45), "medium"],
	[Vector3(14.39, 3.25, -13.85), "small"],
	[Vector3(11.87, 4.0, -17.45), "medium"],
	[Vector3(6.65, 4.55, -18.37), "moving", Vector3(-0.24, 4.55, -19.59)],
	[Vector3(-5.46, 5.1, -18.67), "medium"],
	[Vector3(-9.0, 5.85, -14.46), "medium"],
	[Vector3(-9.38, 6.6, -10.08), "small"],
	[Vector3(-7.18, 7.35, -6.27), "medium"],
	[Vector3(-1.96, 7.9, -5.35), "moving", Vector3(4.93, 7.9, -4.13)],
	[Vector3(9.52, 8.45, -6.78), "medium"],
	[Vector3(11.4, 9.2, -11.95), "medium"],
	[Vector3(9.2, 9.95, -15.76), "small"],
	[Vector3(4.9, 10.5, -15.76), "moving", Vector3(-3.1, 10.5, -15.76)],
	[Vector3(-7.16, 11.05, -12.35), "medium"],
	[Vector3(-14.66, 11.75, -12.35), "large"],
]

var env: Environment = null
var sky: MeshInstance3D = null
var ghosts: Node3D = null
var water: MeshInstance3D = null
var faces: Array = []            # {root, sleep, awake, sad, state}
var watcher: Dictionary = {}
var sleeper: NPC = null
var moth: NPC = null
var moth_wings: Node3D = null
var lantern_writing: Readable = null
var rain: CPUParticles3D = null
var _t := 0.0
var _phase0 := 0.0
var _listens := 0


func build() -> void:
	var r := Realm.apply(self, "sea", {"fog_density": 0.0075, "sky_opts": {"band_strength": 0.03, "band_speed": 0.15}})
	env = r.get("env")
	sky = r.get("sky")
	_phase0 = float((visit_count - 1) % 3) / 3.0
	ghosts = Node3D.new()
	ghosts.name = "Ghosts"
	add_child(ghosts)
	_ground()
	_sea()
	_seams()
	_faces()
	_shore()
	_pier(0.0, true)
	_pier(-WRAP, false)
	_pier(WRAP, false)
	_platforms(0.0, true)
	_platforms(-WRAP, false)
	_platforms(WRAP, false)
	_sky_things()
	add_spawn("default", Vector3(0.0, 0.1, 5.0), 0.0)
	add_spawn("shore", Vector3(12.0, 0.1, 6.0), 0.0)
	Puzzle.declare(self, "sea_climb", "", [], "climb the drifting platforms to the highest one")
	Dog.maybe_spawn(self, Vector3(-3.0, 0.1, 7.0))
	if visit_count >= 3 and Game.count("usher_sightings") < 9:
		Usher.spawn(self, Vector3(PIER_X, DECK, -27.0), {"appear_delay": 2.5, "radius": 30.0})


# --- ground and water ---------------------------------------------------------

## Sand. Flat between the waterline and the first dunes, sloping into the sea
## to the north, rising to a wall of dunes to the south. Periodic in x so the
## seam at ±58 is invisible.
func _height(x: float, z: float) -> float:
	var h := 0.0
	var k := TAU / WRAP
	if z > 5.0:
		var t := z - 5.0
		h += 0.35 * (1.0 - cos(x * k * 3.0 + z * 0.12)) * smoothstep(0.0, 10.0, t)
		h += 0.6 * (0.5 + 0.5 * sin(x * k * 5.0 - z * 0.2)) * smoothstep(4.0, 16.0, t)
		h += 9.0 * smoothstep(34.0, 66.0, z)
		h += 2.0 * (0.5 + 0.5 * sin(x * k * 2.0 + 1.0)) * smoothstep(40.0, 70.0, z)
	elif z < -3.0:
		var d := -3.0 - z
		h -= 0.08 * d
		h -= 7.0 * smoothstep(18.0, 42.0, d)
		h -= 3.0 * smoothstep(50.0, 70.0, d)
	return h


func _color(x: float, z: float, _h: float) -> Color:
	var k := TAU / WRAP
	var dry := Color(0.99, 0.93, 0.9)
	var wet := Color(0.74, 0.62, 0.78)
	var dune := Color(0.97, 0.8, 0.9)
	var c := wet.lerp(dry, smoothstep(-7.0, 0.5, z))
	c = c.lerp(dune, smoothstep(10.0, 40.0, z))
	c = c.lerp(Color(0.38, 0.3, 0.55), 1.0 - smoothstep(-40.0, -14.0, z))
	c = c.lerp(Color(0.9, 0.84, 0.95), 0.12 * (0.5 + 0.5 * sin(x * k * 9.0 + z * 0.5)))
	return c


func _ground() -> void:
	var xs := [-104.0, -52.0, 0.0, 52.0, 104.0]
	var zs := [[-47.5, 45.0, 10], [-5.0, 40.0, 22], [52.5, 75.0, 14]]
	for x in xs:
		for zt in zs:
			var cx: float = x
			var cz: float = zt[0]
			var d: float = zt[1]
			var res: int = zt[2]
			Kit.terrain(self, Vector3(cx, 0, cz), Vector2(52.0, d), res, _height, "ground/sand", {"color_fn": _color, "tile": 3.0, "surface": "sand"})
	# the dunes do not end; they just stop letting you through. the sea likewise.
	Kit.blocker(self, Vector3(0, 12, 74), Vector3(280, 40, 2))
	Kit.blocker(self, Vector3(0, 8, -46), Vector3(280, 40, 2))
	Kit.blocker(self, Vector3(-126, 12, 10), Vector3(2, 40, 160))
	Kit.blocker(self, Vector3(126, 12, 10), Vector3(2, 40, 160))


func _sea() -> void:
	water = Kit.water(self, Vector3(0, -0.15, -95), Vector2(600, 190), "nature/water_sea",
		{"tint": Color(0.52, 0.36, 0.83, 0.8), "speed": 0.004, "swell": 0.05, "uv_scale": 60.0, "subdiv": 24, "name": "SlowSea"})
	water.extra_cull_margin = 64.0
	Kit.particles(self, Vector3(0, 0.6, -14), "fog", Vector3(40, 0.4, 8), 14)
	_motes(self, Vector3(0, 2.0, 4), "motes", Vector3(30, 2.0, 8), 60, Color(1.0, 0.85, 0.95, 0.55))


## Walk east past the end of the beach and you are at its western end, still
## walking east. Size is in the seam's LOCAL frame: x across (world z here), y up, z depth.
func _seams() -> void:
	SeamlessTeleport.link(self, Vector3(SEAM_X, -3.0, 8.0), -90.0, Vector3(-SEAM_X, -3.0, 8.0), -90.0, Vector3(84, 46, 1.0),
		{"name": "ShoreWrap", "count_flag": "sea_wraps", "on_teleport": _on_wrap})


func _on_wrap(_p: Node) -> void:
	var n := Game.count("sea_wraps")
	if n == 3:
		Game.toast.emit("You have passed the same sleeping face three times. It has not noticed.")
		Game.note("sea_wraps", "The shore goes round", "Walk along the Slow Sea for long enough and you pass the pier again, and the bed, and the face. The beach is a loop. Nobody has told the tide.")


# --- props that repeat across the seam -------------------------------------------

## A prop plus two collision-less copies a beach-length east and west, so the
## view across the seam matches.
func _prop(model: String, pos: Vector3, yaw: float, scale: float, opts: Dictionary = {}) -> Node3D:
	var inst := Props.place(self, model, pos, yaw, scale, opts)
	var go := opts.duplicate()
	go["collision"] = "none"
	go.erase("name")
	for dx in [-WRAP, WRAP]:
		Props.place(ghosts, model, pos + Vector3(float(dx), 0, 0), yaw, scale, go)
	return inst


## Motes in a pastel colour.
func _motes(parent: Node, pos: Vector3, kind: String, extent: Vector3, amount: int, color: Color) -> CPUParticles3D:
	var p := Kit.particles(parent, pos, kind, extent, amount)
	var m := p.material_override as StandardMaterial3D
	if m != null:
		m.albedo_color = color
	return p


# --- the faces ------------------------------------------------------------------

## A giant stone face half-buried in the sand. Three variants live under one
## root; `state` picks which is visible. Returns the dictionary.
func _face(pos: Vector3, yaw: float, scale: float, tilt: float, state: String, name_: String, tint: Color = Color.WHITE) -> Dictionary:
	var root := Node3D.new()
	root.name = name_
	root.position = pos
	root.rotation.y = deg_to_rad(yaw)
	add_child(root)
	var f := {"root": root, "state": state, "pos": pos}
	for kind in ["sleep", "awake", "sad"]:
		var inst := Props.place(root, "face_sea_" + kind, Vector3.ZERO, 0.0, scale, {"collision": "none", "rotation": Vector3(tilt, 0, 0), "name": kind, "tint": tint})
		inst.visible = (kind == state)
		f[kind] = inst
	for dx in [-WRAP, WRAP]:
		Props.place(ghosts, "face_sea_" + state, pos + Vector3(float(dx), 0, 0), 0.0, scale, {"collision": "none", "rotation": Vector3(tilt, yaw, 0), "tint": tint})
	faces.append(f)
	return f


func _set_face(f: Dictionary, state: String) -> void:
	f["state"] = state
	for kind in ["sleep", "awake", "sad"]:
		var n: Node3D = f[kind]
		n.visible = (kind == state)


func _faces() -> void:
	var awake := visit_count >= 2
	# The Sleeper: the one that talks. Buried to the nose, leaning back, dreaming upward.
	var sp := Vector3(16.0, -5.0, 13.0)
	var sleeper_face := _face(sp, 20.0, 2.2, 18.0, "awake" if awake else "sleep", "SleeperFace")
	Kit.light(self, sp + Vector3(0, 8.0, -4.0), Color(1.0, 0.8, 0.95), 1.3, 16.0)
	var lines: Array = []
	if visit_count == 1:
		lines = [
			"The face is asleep. Its breathing moves the sand. Between breaths it says, without waking:",
			"\"...the tide is late. it is always late. that is what a tide is...\"",
			"\"...do not wake me. i am dreaming you, and it is going well...\"",
		]
	elif visit_count == 2:
		lines = [
			"The eyes are open. They were not open last time. They do not move to follow you. They do not have to.",
			"\"You came back,\" it says. \"Everyone comes back. The sea is very patient about it.\"",
			"\"The wings are at the top. They were always at the top. Nobody said you had to be.\"",
		]
	else:
		lines = [
			"\"Third time. Or the hundredth. I lose count between tides.\"",
			"\"Lie down on the shore. You will wake somewhere warm. It is not here. That is the point of here.\"",
		]
	sleeper = NPC.create(self, Vector3(sp.x, 0.0, sp.z), 20.0, "The Sleeper", {
		"model": "", "face_player": false, "turn_to_bell": false, "prompt": "Listen to the face", "name": "Sleeper", "lines": lines,
		"reactions": {
			"wings": ["\"You found them. They were mine, once. They are dusty because I was.\"", "\"Go up. Come down slowly. That is all wings are for.\""],
			"bell": ["The eyelids twitch at the bell. Sand runs off them.", "\"Not that one. The big one. When the big one rings, I get up.\""],
			"knife": ["\"You cannot cut a face out of a beach. Others have tried. They are the smaller rocks.\""],
			"lantern": ["\"Put that out. I can see it through my eyelids. It looks like morning and I am not ready.\""],
			"crown": ["\"Majesty,\" it says, and the sand around it bows a little.", "\"The paper is showing.\""],
			"umbrella": ["\"Open it. Please. It has not rained here in a hundred years and the tide needs the encouragement.\""],
			"hourglass": ["\"Turn it and the platforms hold still. The sea does not notice. The sea has never moved fast enough to notice.\""],
			"mouse": ["\"...a mouse. On my beach. Well. Everything is small from here.\""],
			"shard": ["\"Through that, I am awake. Do not tell me what I am looking at.\""],
		},
		"on_talk": _sleeper_talk,
	})
	sleeper.add_box(Vector3(11.0, 6.5, 2.6), Vector3(0, 3.2, -0.4))
	sleeper.set_meta("face", sleeper_face)

	# The Sad one, far along the beach to the west. Not asleep. Not anything.
	var sad := Vector3(-40.0, -4.6, 10.0)
	_face(sad, -35.0, 1.6, 30.0, "sad", "SadFace")
	Kit.light(self, sad + Vector3(0, 6.0, -3.5), Color(0.75, 0.8, 1.0), 1.0, 13.0)
	Readable.create(self, Vector3(sad.x, 0.0, sad.z), -35.0, "Look at the sad face", [
		"This one is not asleep. Its eyes are open and wet and the sand under them is darker.",
		"It is looking at the sea. It has been looking at the sea since before there was one.",
		"It does not say anything. It has said everything already, a long time ago, and is waiting for a reply.",
	], {"name": "SadLook", "size": Vector3(8.0, 5.0, 2.4), "offset": Vector3(0, 2.4, -0.3),
		"note_key": "sea_sad_face", "note_title": "The sad face", "note_text": "A stone face at the west end of the shore, eyes open, looking at the sea. Waiting for an answer to something it said before there was a sea."})

	# The Watcher: half in the water, west of the platforms. It is asleep until you look away.
	var wp := Vector3(-26.0, -4.2, -9.0)
	watcher = _face(wp, -150.0, 1.4, 12.0, "awake" if awake else "sleep", "Watcher")
	Kit.light(self, wp + Vector3(0, 5.0, 3.0), Color(0.9, 0.75, 1.0), 1.0, 12.0)
	Readable.create(self, Vector3(wp.x, -0.3, wp.z), -150.0, "Look at the face in the water", [
		"A face in the shallows, sunk to the chin. The water around it does not move. Nothing here moves.",
		"Its eyes are closed. You are almost sure its eyes are closed." if not awake else "Its eyes are open. It is looking exactly where you are standing, which is not where you were standing a moment ago.",
	], {"name": "WatcherLook", "size": Vector3(7.0, 4.5, 2.0), "offset": Vector3(0, 2.2, -0.3)})
	if not awake and not Game.has_flag("sea_watcher_turned"):
		LookAway.create(self, wp + Vector3(0, 6.0, 0), _on_watcher_unseen, {"name": "WatcherWatch", "radius": 34.0, "delay": 2.5, "require_seen_first": true, "once": true, "dot_threshold": 0.6})
	elif Game.has_flag("sea_watcher_turned"):
		_set_face(watcher, "awake")

	# Visit two: something enormous has come up out of the deep water. Visit three: it is closer.
	if visit_count >= 2:
		var rz := -80.0 if visit_count == 2 else -56.0
		var rp := Vector3(-12.0, -22.0, rz)
		_face(rp, 180.0, 6.0, 8.0, "awake", "Risen", Color(0.42, 0.34, 0.56))
		Kit.light(self, rp + Vector3(0, 20.0, 12.0), Color(1.0, 0.7, 0.9), 2.5, 45.0)
		if not Game.has_note("sea_risen"):
			Game.note("sea_risen", "Something out at sea", "The second time, there was a face out in the deep water, taller than the pier is long, with its eyes open. It was not there before. The tide brought it, at the tide's speed.")


func _sleeper_talk(_p: Node, _npc: Node) -> bool:
	Game.note("sea_sleeper", "The face that talks in its sleep", "A stone face buried to the nose in the sand of the Slow Sea. It talks without waking. It says it is dreaming you and that it is going well.")
	return false


func _on_watcher_unseen(_l: Node) -> void:
	if watcher.is_empty():
		return
	_set_face(watcher, "awake")
	var root: Node3D = watcher.root
	var d := player_pos() - root.global_position
	root.rotation.y = atan2(-d.x, -d.z)
	Game.set_flag("sea_watcher_turned", true)
	Audio.sfx("stone_grind", root.global_position + Vector3(0, 3, 0), -2.0)
	Game.toast.emit("Behind you, sand pours off something that has just turned its head.")
	Game.note("sea_watcher", "The face in the water", "The face in the shallows was asleep while you looked at it. When you looked away it turned to face you and opened its eyes. It is still facing you. It will be, wherever you stand.")


# --- the shore ----------------------------------------------------------------

func _shore() -> void:
	# the bed that came with you from the inn (or takes you there)
	var bed_pos := Vector3(-8.0, 0.0, 3.0)
	Bed.create(self, bed_pos, 0.0, "tavern", "from_sea", {"model": "bed_inn", "sleep_text": "Lie down on the shore", "name": "ShoreBed"})
	for dx in [-WRAP, WRAP]:
		Props.place(ghosts, "bed_inn", bed_pos + Vector3(float(dx), 0, 0), 0.0, 1.0, {"collision": "none"})
	add_spawn("from_tavern", bed_pos + Vector3(2.3, 0.1, 0.4), 0.0)
	_prop("lantern_post", bed_pos + Vector3(-1.6, 0, 1.4), 30.0, 0.9, {"collision": "cylinder"})
	Kit.light(self, bed_pos + Vector3(-1.4, 2.8, 1.2), Color(1.0, 0.9, 0.75), 1.4, 10.0)
	Readable.create(self, bed_pos + Vector3(0, 0.5, -0.4), 0.0, "Look at the bed", [
		"The bed from the rented room, standing on the sand as if it had always been there. The sheets are damp.",
		"The pillow still has the shape of your head in it. You have not lain down yet." if visit_count == 1 else "The pillow has the shape of two heads in it now. You only brought one.",
	], {"name": "BedLook", "size": Vector3(1.4, 0.6, 2.2), "offset": Vector3(0, 0.6, 0)})
	# writing in the sand beside the bed
	_sand_text("THE TIDE IS LATE", bed_pos + Vector3(4.2, 0.02, 3.4), 0.0, 40, Color(0.55, 0.42, 0.55))
	_sand_text("wait here", bed_pos + Vector3(4.2, 0.02, 4.4), 0.0, 26, Color(0.55, 0.42, 0.55))
	Readable.create(self, bed_pos + Vector3(4.2, 0.0, 3.8), 0.0, "Read the writing in the sand", [
		"Written in the sand with a finger, in letters a metre tall: THE TIDE IS LATE.",
		"Under it, smaller, more recently: wait here.",
		"The sea has not reached it. The sea has not reached anything.",
	], {"name": "SandWriting", "size": Vector3(4.0, 0.4, 1.6), "offset": Vector3(0, 0.2, 0),
		"note_key": "sea_sand_writing", "note_title": "Writing in the sand", "note_text": "THE TIDE IS LATE, in letters a metre tall. wait here. The sea has not reached it and is in no hurry to."})
	# writing that is only there in lantern light
	var lw := _sand_text("you were here before the sea was", bed_pos + Vector3(-4.0, 0.02, 7.0), 0.0, 24, Color(0.9, 0.7, 0.4))
	Kit.lantern_only(lw)
	lantern_writing = Readable.create(self, bed_pos + Vector3(-4.0, 0.0, 7.0), 0.0, "Read the faint writing", [
		"Only in the lantern's light: a line of footprints, and beside them, older than the other writing:",
		"you were here before the sea was. you left the door open. that is why it is slow.",
	], {"name": "LanternWriting", "size": Vector3(4.0, 0.4, 1.0), "offset": Vector3(0, 0.2, 0),
		"note_key": "sea_lantern_writing", "note_title": "Older writing", "note_text": "Under the lantern, older writing in the sand: you were here before the sea was. You left the door open. That is why it is slow."})
	lantern_writing.enabled = Game.lantern_lit

	# a message in a bottle at the waterline
	var bp := Vector3(-14.0, 0.1, -3.4)
	_prop("bottle", bp, 0.0, 2.6, {"collision": "none", "rotation": Vector3(0, 40, 78)})
	var bottle_lines: Array = [
		"A bottle the size of your forearm, half in the sand. There is a paper in it. You do not need to open it; the paper turns to face you.",
		"\"If you are reading this, the sea brought it. The sea brings everything, eventually. I am sending myself next. Look for a face.\"",
		"The bottle is warm.",
	]
	if visit_count >= 2:
		bottle_lines = ["The bottle is empty now. The paper is gone.", "Out in the deep water, something with a face has arrived."]
	Readable.create(self, bp + Vector3(-0.3, 0, 0), 0.0, "Read the message in the bottle", bottle_lines,
		{"name": "BottleMessage", "size": Vector3(1.4, 0.7, 0.8), "offset": Vector3(0, 0.3, 0), "sound": "page",
		"note_key": "sea_bottle", "note_title": "A message in a bottle", "note_text": "The sea brings everything, eventually. Whoever wrote it was sending themselves next, and said to look for a face."})

	# a shell you can listen to
	var shell_pos := Vector3(3.0, 0.0, 9.5)
	Readable.create(self, shell_pos, 160.0, "Hold the shell to your ear", [], {"name": "ListenShell", "model": "shell", "scale": 2.4, "collision": "box",
		"size": Vector3(2.4, 2.0, 1.4), "offset": Vector3(0.6, 1.0, 0), "sound": "wind_gust", "on_read": _on_shell})
	Kit.light(self, shell_pos + Vector3(0.6, 1.6, 0), ROSE, 0.7, 5.0)
	# smaller shells everywhere
	for i in 14:
		var x := rng.randf_range(-48.0, 48.0)
		var z := rng.randf_range(-2.5, 11.0)
		if absf(x - 3.0) < 3.0 and absf(z - 9.5) < 3.0:
			continue
		_prop("shell", Vector3(x, _height(x, z), z), rng.randf_range(0.0, 360.0), rng.randf_range(0.7, 1.5), {"collision": "none"})
	# glowing orbs half-sunk in the sand, and the lights they make
	for op in [Vector3(-3.0, -0.25, 11.0), Vector3(20.0, -0.3, 4.0), Vector3(-24.0, -0.2, 2.0), Vector3(36.0, -0.3, 8.0)]:
		var p: Vector3 = op
		_prop("orb", p, 0.0, 1.3, {"collision": "none"})
		Kit.light(self, p + Vector3(0, 1.0, 0), CREAM, 1.1, 8.0)
	# half-sunk pastel ruins
	_prop("pillar_pastel", Vector3(-30.0, -2.4, 6.0), 0.0, 1.0, {"collision": "none", "rotation": Vector3(0, 0, 24)})
	_prop("pillar_pastel", Vector3(-33.0, -3.6, 9.0), 0.0, 1.0, {"collision": "none", "rotation": Vector3(-12, 0, -8)})
	_prop("pillar_pastel", Vector3(30.0, -1.2, 8.0), 0.0, 1.0, {"collision": "cylinder"})
	_prop("pillar_broken", Vector3(33.5, 0.0, 6.0), 40.0, 1.0, {"collision": "cylinder"})
	Readable.create(self, Vector3(30.0, 0.0, 8.0), 0.0, "Read the pillar", [
		"Letters go round the pillar, most of them under the sand. What is left reads: ...AND THE SEA WAS ASKED TO WAIT, AND IT...",
		"You could dig. You would be digging for a hundred years.",
	], {"name": "PillarText", "size": Vector3(1.6, 3.8, 1.6), "offset": Vector3(0, 1.9, 0)})
	_prop("stair_pastel", Vector3(-19.0, 0.0, 9.0), 140.0, 1.0, {"collision": "trimesh"})
	_prop("rock_pale", Vector3(40.0, -0.2, 2.5), 60.0, 1.4, {"collision": "box", "tint": Color(0.95, 0.85, 1.0)})
	_prop("boulder", Vector3(-46.0, -0.8, 4.0), 20.0, 0.8, {"collision": "box", "tint": Color(0.9, 0.85, 1.0)})
	_prop("rock_pale", Vector3(46.0, -0.2, 9.0), 200.0, 1.1, {"collision": "box", "tint": Color(1.0, 0.85, 0.95)})
	# the cocoon under the arch (the secret): closed until you hold wings
	_cocoon_secret(Vector3(-14.0, 0.0, 8.5))
	# a small moth that flees the knife
	moth = NPC.create(self, Vector3(6.5, 1.3, 6.0), 200.0, "A Small Moth", {"model": "moth_giant", "flee_knife": true, "name": "SmallMoth", "prompt": "Talk to the moth",
		"lines": [
			"The moth is the size of a hand. It is looking at you the way moths look at lamps.",
			"\"The big wings are up there,\" it says, meaning the top. \"We grew out of them. You could grow into them.\"",
			"\"Do not bring the sharp thing near me. I am mostly dust.\"",
		],
		"reactions": {
			"wings": ["\"Oh,\" says the moth. \"You are one of us now. Sort of. From the back.\""],
			"lantern": ["The moth cannot help itself. It circles the lantern, apologising.", "\"Sorry. Sorry. It is in my nature. Sorry.\""],
			"knife": ["The moth goes very still.", "\"I said,\" it says, from a little further away."],
			"bell": ["\"Ring it at the top,\" the moth says. \"Everything up there is listening. Down here it is only me.\""],
		}})
	if moth.body != null:
		moth.body.scale = Vector3.ONE * 0.36
	_motes(self, Vector3(6.5, 1.5, 6.0), "motes", Vector3(1.5, 1.0, 1.5), 16, Color(0.9, 0.85, 1.0, 0.6))


func _sand_text(text: String, pos: Vector3, yaw: float, size: int, color: Color) -> Label3D:
	var l := Kit.label(self, text, pos, yaw, size, color, "body", {"pixel_size": 0.012, "outline": 0})
	l.rotation_degrees = Vector3(-90.0, yaw, 0.0)
	return l


func _on_shell(_r: Node) -> void:
	_listens += 1
	Game.bump("sea_shell_listens")
	var lines: Array = ["You hold the shell to your ear. It sounds like the sea. Not this sea. A faster one, somewhere with weather."]
	if _listens == 2:
		lines = ["This time there is a voice under the water, very small, saying a number over and over.", "You cannot make out the number. You are fairly sure it is going up."]
	elif _listens >= 3:
		lines = ["The shell has gone quiet. Whatever was in it has finished.", "When you put it down it is warm on the side that was against your head, and on the other side too."]
		Game.note("sea_shell", "The shell", "A shell on the shore of the Slow Sea. Inside it: a faster sea, a small voice counting upward, and then nothing. It was warm on both sides.")
	get_tree().create_timer(0.9).timeout.connect(func() -> void: Audio.sfx("whisper", Vector3(3.0, 1.0, 9.5), -12.0))
	if World.hud:
		await World.hud.say("", lines)


## The cocoon under the pastel arch. Closed on every visit until the Moth
## Wings are held; then it has already opened, and what was inside is light.
func _cocoon_secret(p: Vector3) -> void:
	_prop("arch_pastel", p, 0.0, 1.0, {"collision": "none"})
	Kit.blocker(self, p + Vector3(-1.75, 1.0, 0), Vector3(0.6, 2.0, 0.6))
	Kit.blocker(self, p + Vector3(1.75, 1.0, 0), Vector3(0.6, 2.0, 0.6))
	if Game.has_keepsake("wings"):
		# open: the husk lies on the sand in two halves and the arch holds a light instead
		Props.place(self, "cocoon", p + Vector3(-0.9, 0.35, 0.4), 0.0, 1.0, {"collision": "none", "rotation": Vector3(0, 30, 98)})
		Props.place(self, "cocoon", p + Vector3(0.6, 0.3, -0.3), 0.0, 0.7, {"collision": "none", "rotation": Vector3(0, -140, 84)})
		_prop("orb", p + Vector3(0, 2.3, 0), 0.0, 1.0, {"collision": "none"})
		Kit.light(self, p + Vector3(0, 2.8, 0), Color(1.0, 0.95, 0.8), 1.8, 10.0)
		_motes(self, p + Vector3(0, 2.4, 0), "motes", Vector3(1.2, 1.2, 1.2), 30, Color(1.0, 0.95, 0.75, 0.8))
		Readable.create(self, p + Vector3(0, 0, 0.2), 0.0, "Look at the open cocoon", [
			"The cocoon has split down the middle. Whatever was in it is out. It was the size of you.",
			"Where it hung there is a light now, the colour of the wings on your back. It hums, very slightly, in time with them.",
			"In the lining of the husk, in the smallest writing: thank you for carrying them.",
		], {"name": "CocoonOpen", "size": Vector3(2.4, 1.6, 1.6), "offset": Vector3(0, 0.6, 0), "flag_on_read": "sea_cocoon_opened",
			"note_key": "sea_cocoon_open", "note_title": "The cocoon, opened", "note_text": "With the Moth Wings on your back, the cocoon under the arch had already opened. Something your size climbed out and left a light behind, and a note: thank you for carrying them."})
	else:
		_prop("cocoon", p + Vector3(0, 3.85, 0), 0.0, 1.0, {"collision": "none"})
		Kit.light(self, p + Vector3(0, 2.6, 0.8), Color(0.9, 0.85, 1.0), 0.6, 5.0)
		Readable.create(self, p + Vector3(0, 0, 0.2), 0.0, "Look at the cocoon", [
			"A cocoon hangs from the arch by a chain. It is the size of a person. It is warm.",
			"Something inside it moves, once, the way a sleeper moves when a name is said.",
			"There is no seam. It is waiting for something before it opens. You do not have it yet.",
		], {"name": "CocoonClosed", "size": Vector3(1.6, 2.8, 1.2), "offset": Vector3(0, 2.2, 0),
			"note_key": "sea_cocoon", "note_title": "The cocoon under the arch", "note_text": "A person-sized cocoon hanging from a pastel arch on the shore. Warm. Waiting for something before it opens. Perhaps for wings."})


# --- the pier -------------------------------------------------------------------

func _pier(off: float, real: bool) -> void:
	var x := PIER_X + off
	var wood := "wood/planks_grey"
	var o := {"tile": 1.0}
	if not real:
		o["solid"] = false
	# the deck, in four pieces with the sea showing between them
	var sections := [[2.3, -6.0, 3.0, 0.0], [-7.3, -14.0, 3.0, 0.0], [-15.4, -22.0, 2.0, -0.5], [-23.2, -34.5, 3.0, 0.0]]
	for s in sections:
		var z0: float = s[0]
		var z1: float = s[1]
		var w: float = s[2]
		var dx: float = s[3]
		Kit.box(self, Vector3(x + dx, DECK - 0.1, (z0 + z1) * 0.5), Vector3(w, 0.2, z0 - z1), wood, o)
	# posts down into the water
	var z := 1.0
	while z > -35.0:
		for sx in [-1.6, 1.6]:
			var px := x + float(sx)
			var floor_y := _height(px, z) - 0.5
			var top := DECK + 1.05
			Kit.box(self, Vector3(px, (floor_y + top) * 0.5, z), Vector3(0.28, top - floor_y, 0.28), wood, o)
		z -= 4.0
	# rails, where they are left
	for rr in [[-1.6, 2.3, -6.0], [-1.6, -7.3, -14.0], [1.6, -23.2, -34.5], [-1.6, -23.2, -34.5], [1.6, -7.3, -10.0]]:
		var rx: float = rr[0]
		var rz0: float = rr[1]
		var rz1: float = rr[2]
		Kit.box(self, Vector3(x + rx, DECK + 1.0, (rz0 + rz1) * 0.5), Vector3(0.1, 0.1, rz0 - rz1), wood, {"tile": 1.0, "solid": false})
	# planks that gave up, hanging into the gaps
	Kit.box(self, Vector3(x + 0.8, DECK - 0.5, -6.6), Vector3(0.6, 0.12, 1.6), wood, {"tile": 1.0, "solid": false, "rotation": Vector3(38, 0, 0)})
	Kit.box(self, Vector3(x - 0.9, DECK - 0.6, -14.7), Vector3(0.6, 0.12, 1.7), wood, {"tile": 1.0, "solid": false, "rotation": Vector3(-42, 0, 6)})
	Kit.box(self, Vector3(x + 1.1, DECK - 0.4, -18.0), Vector3(0.7, 0.12, 3.0), wood, {"tile": 1.0, "solid": false, "rotation": Vector3(0, 0, -50)})
	if not real:
		Props.place(ghosts, "door_white", Vector3(x, DECK, -33.2), 180.0, 1.0, {"collision": "none"})
		return
	# the way up from the sand
	Kit.stairs(self, Vector3(x, 0, 3.6), 0.0, 3.0, 4, 0.225, 0.32, wood, {"tile": 1.0, "name": "PierStairs"})
	_prop("lantern_post", Vector3(x + 2.4, 0, 4.6), -20.0, 1.0, {"collision": "cylinder"})
	Kit.light(self, Vector3(x + 2.2, 3.0, 4.4), Color(1.0, 0.9, 0.75), 1.3, 10.0)
	# lanterns on brackets over the deck
	for lz in [-10.0, -27.0]:
		var lp := Vector3(x - 1.5, DECK + 2.7, float(lz))
		Kit.box(self, lp + Vector3(0.4, 0.1, 0), Vector3(0.9, 0.08, 0.08), wood, {"tile": 1.0, "solid": false})
		Props.place(self, "lantern_hanging", lp + Vector3(0.8, 0, 0), 0.0, 1.0, {"collision": "none"})
		Kit.light(self, lp + Vector3(0.8, -1.3, 0), Color(1.0, 0.85, 0.65), 1.3, 9.0)
	# the door at the end, facing back down the pier
	var dp := Vector3(x, DECK, -33.2)
	Door.create(self, dp, 180.0, "nexus", "from_sea", {"kind": "white", "label": "A white door at the end of the pier", "name": "PierDoor", "fade_color": Color(0.92, 0.88, 1.0), "fade_duration": 1.0})
	Kit.box(self, dp + Vector3(0, 2.4, 0), Vector3(1.5, 0.14, 0.3), "wood/planks_white", {"tile": 1.0})
	Kit.light(self, dp + Vector3(0, 2.6, 1.2), Color(0.95, 0.9, 1.0), 1.5, 9.0)
	Kit.label(self, "THE ANTEROOM", dp + Vector3(0, 2.9, 0.2), 180.0, 28, Color(0.9, 0.86, 1.0), "display", {"pixel_size": 0.012})
	add_spawn("from_nexus", dp + Vector3(0, 0.1, 2.7), 180.0)
	_motes(self, Vector3(x, DECK + 1.5, -28.0), "motes", Vector3(2.0, 1.5, 6.0), 24, Color(1.0, 0.9, 1.0, 0.5))
	# plaques on the rail posts
	_plaque(Vector3(x - 1.4, DECK + 1.35, 1.0), -90.0, "THE PIER", [
		"A brass plate on the first post, polished by hands: THE PIER. BUILT FOR A TIDE THAT NEVER CAME.",
		"Under it, scratched: it is still coming. give it time.",
	], "sea_pier_plaque", "The pier", "Built for a tide that never came. It is still coming. Give it time.")
	_plaque(Vector3(x - 1.4, DECK + 1.35, -8.0), -90.0, "MIND THE GAP", [
		"A brass plate: MIND THE GAP.",
		"Somebody has added, in the same brass, the same engraving: THE GAP DOES NOT MIND YOU.",
	], "", "", "")
	var tide_lines: Array = [
		"A tide table, painted on a board and repainted many times:",
		"HIGH TIDE — soon.  LOW TIDE — now.  NEXT TIDE — the year 2126.",
		"The paint on 'soon' is the freshest.",
	]
	if visit_count >= 2:
		tide_lines = ["The tide table has been repainted since you were here.", "HIGH TIDE — sooner.  LOW TIDE — still.  NEXT TIDE — it has been moved forward. Somebody is in a hurry, at last."]
	_plaque(Vector3(x + 1.4, DECK + 1.35, -25.0), 90.0, "TIDES", tide_lines, "sea_tide_table", "The tide table", "High tide: soon. Low tide: now. Next tide: 2126. The paint on 'soon' is the freshest.")
	_plaque(Vector3(x - 1.4, DECK + 1.35, -31.0), -90.0, "DEPARTURES", [
		"DEPARTURES: THE ANTEROOM.",
		"ARRIVALS: a dash, where a word has been painted over and over until the board is thick with it.",
	], "", "", "")
	# under the pier, in the water, something somebody dropped
	var chest_pos := Vector3(x - 0.5, _height(x - 0.5, -12.0) + 0.05, -12.0)
	_prop("chest", chest_pos, 30.0, 1.0, {"collision": "box"})
	Readable.create(self, chest_pos, 30.0, "Open the chest", [
		"A chest under the pier, in the water, that nobody has opened because nobody has waded out this far.",
		"Inside: sand. Under the sand: more sand, warmer. Under that, the sound of a bell, very far down.",
		"You close it. It is better closed. The bell agrees.",
	], {"name": "PierChest", "size": Vector3(1.0, 0.8, 0.7), "offset": Vector3(0, 0.35, 0), "sound": "creak",
		"note_key": "sea_chest", "note_title": "The chest under the pier", "note_text": "Under the pier, in the water, a chest full of sand with a bell ringing very far down inside it. You closed it. It seemed to prefer that."})


func _plaque(pos: Vector3, yaw: float, title: String, lines: Array, note_key: String, note_title: String, note_text: String) -> void:
	var back := Kit.yaw_to_dir(yaw)
	Kit.box(self, pos - back * 0.03, Vector3(0.5, 0.3, 0.04), "metal/brass", {"tile": 0.5, "solid": false, "yaw": yaw})
	Kit.label(self, title, pos + back * 0.005, yaw, 18, Color(0.25, 0.2, 0.12), "body", {"pixel_size": 0.006, "outline": 0, "double": false})
	var o := {"name": "Plaque_" + title.replace(" ", "_"), "size": Vector3(0.7, 0.5, 0.3), "offset": Vector3.ZERO}
	if note_key != "":
		o["note_key"] = note_key
		o["note_title"] = note_title
		o["note_text"] = note_text
	Readable.create(self, pos, yaw, "Read the plaque", lines, o)


# --- the platforms --------------------------------------------------------------

func _platforms(off: float, real: bool) -> void:
	var col := "cylinder" if real else "none"
	var parent: Node = self if real else ghosts
	for i in CHAIN.size():
		var e: Array = CHAIN[i]
		var top: Vector3 = e[0]
		var kind: String = e[1]
		var pos := Vector3(top.x + off, top.y - 0.5, top.z)
		if kind == "moving":
			var dest: Vector3 = e[2]
			var cw := Clockwork.create(parent, pos, {"mode": "path", "points": [Vector3.ZERO, Vector3(dest.x - top.x, 0, dest.z - top.z)], "platform": real, "speed_deg": 8.0, "name": "Drift%d" % i})
			Props.place(cw.body, "platform_disc_medium", Vector3.ZERO, 0.0, 1.0, {"collision": "none"})
			if real:
				cw.add_shape(Vector3(2.8, 0.5, 2.8), Vector3(0, 0.25, 0))
				var rim := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 2.0
				cyl.height = 0.5
				rim.shape = cyl
				rim.position = Vector3(0, 0.25, 0)
				cw.body.add_child(rim)
				Props.place(cw.body, "orb", Vector3(0, 0.5, 0), 0.0, 0.6, {"collision": "none"})
				Kit.light(cw.body, Vector3(0, 1.4, 0), CREAM, 1.0, 7.0)
				Props.place(cw.body, "cloud", Vector3(0.3, -1.6, 0), rng.randf_range(0.0, 360.0), 1.1, {"collision": "none"})
			continue
		var model := "platform_disc_" + kind
		Props.place(parent, model, pos, float(i * 37 % 360), 1.0, {"collision": col})
		if top.y < 5.6 and kind != "small":
			# low platforms rest on pillars sunk in the sand
			Props.place(parent, "pillar_pastel", Vector3(pos.x, pos.y - 5.0, pos.z), 0.0, 1.0, {"collision": "none"})
		if not real:
			continue
		match i:
			0:
				_prop("arch_pastel", Vector3(pos.x, top.y, pos.z - 2.0), 90.0, 1.0, {"collision": "none"})
				Kit.light(self, Vector3(pos.x, top.y + 3.5, pos.z), LILAC, 1.2, 10.0)
			3, 8, 13:
				Props.place(self, "cloud", pos + Vector3(0, -1.9, 0), float(i * 50), 1.3, {"collision": "none"})
			7, 12:
				Props.place(self, "orb", pos + Vector3(1.2, 0.5, -0.8), 0.0, 0.7, {"collision": "none"})
				Kit.light(self, pos + Vector3(1.2, 1.5, -0.8), CREAM, 1.0, 8.0)
				Props.place(self, "cocoon", pos + Vector3(-1.0, -0.05, 0.9), 0.0, 1.0, {"collision": "none"})
			15:
				Props.place(self, "cocoon", pos + Vector3(0.8, -0.05, -0.8), 0.0, 1.0, {"collision": "none"})
				Props.place(self, "cocoon", pos + Vector3(-1.2, -0.05, 0.6), 0.0, 0.8, {"collision": "none"})
			16:
				_summit(Vector3(pos.x, top.y, pos.z))
	if not real:
		return
	# the way up from the beach onto the first disc
	var stair_base := Vector3(4.0, 0.0, 2.6)
	Kit.stairs(self, stair_base, 0.0, 2.4, 5, 0.2, 0.32, "stone/blocks_sea", {"tint": MINT, "tile": 1.0, "name": "ClimbStairs"})
	_sand_text("UP", stair_base + Vector3(0, 0.02, 1.4), 0.0, 44, Color(0.6, 0.45, 0.6))
	Readable.create(self, stair_base + Vector3(0, 0, 1.4), 0.0, "Read the writing", [
		"Written in the sand at the bottom of the steps: UP.",
		"An arrow points at the sky. It is the only direction the platforms go.",
		"Some of the platforms are drifting. They come back. Everything here comes back; it just takes a while.",
	], {"name": "UpSign", "size": Vector3(2.0, 0.4, 1.4), "offset": Vector3(0, 0.2, 0),
		"note_key": "sea_platforms", "note_title": "The platforms over the sea", "note_text": "A chain of pastel platforms climbs over the shallows of the Slow Sea. Some drift. At the top, the small moth says, are the big wings."})
	_motes(self, Vector3(2.0, 6.0, -11.0), "motes", Vector3(14.0, 6.0, 9.0), 90, Color(1.0, 0.9, 1.0, 0.5))
	# lights among the platforms so the climb is never in the dark
	Kit.light(self, Vector3(12.0, 3.5, -12.0), ROSE, 1.2, 12.0)
	Kit.light(self, Vector3(-8.0, 6.5, -12.0), LILAC, 1.2, 12.0)
	Kit.light(self, Vector3(6.0, 9.5, -10.0), MINT, 1.2, 12.0)
	# a trigger at the top, for the journal
	Kit.trigger(self, Vector3(-14.66, TOP_Y + 1.5, -12.35), Vector3(7.0, 3.0, 7.0), _on_summit, {"once": true, "name": "SummitTrigger"})


## The highest platform: the wings, and the moth that left them.
func _summit(top: Vector3) -> void:
	Pickup.create(self, top + Vector3(0, 0, 0.6), {"keepsake": "wings", "name": "MothWings"})
	var gm := _prop("moth_giant", top + Vector3(0.4, 0.0, -2.4), 200.0, 2.2, {"collision": "none", "name": "GiantMoth"})
	moth_wings = Props.part(gm, "Wings")
	Readable.create(self, top + Vector3(0.4, 0, -2.4), 200.0, "Look at the moth", [
		"A moth the size of a boat, resting with its wings open. It is not asleep; it is doing something slower than sleep.",
		"Its wings are the colour of dust and moonlight. It does not need them. It left a pair for whoever climbed up.",
		"\"Take them,\" its stillness says. \"Come down slowly.\"",
	] if not Game.has_keepsake("wings") else [
		"The moth has closed its eyes now that the wings are gone from beside it.",
		"It is lighter, somehow. So are you.",
	], {"name": "GiantMothLook", "size": Vector3(5.0, 2.0, 4.0), "offset": Vector3(0, 0.9, 0)})
	_prop("arch_pastel", top + Vector3(-2.6, 0, 1.6), 40.0, 1.0, {"collision": "none"})
	for a in [30.0, 150.0, 270.0]:
		var p := top + Kit.polar(3.2, a)
		Props.place(self, "orb", p, 0.0, 0.8, {"collision": "none"})
	Kit.light(self, top + Vector3(0, 2.2, 0), Color(1.0, 0.92, 0.85), 1.6, 12.0)
	Kit.light(self, top + Vector3(0, 6.0, 0), LILAC, 0.8, 20.0)
	_motes(self, top + Vector3(0, 1.5, 0), "motes", Vector3(4.0, 2.0, 4.0), 50, Color(1.0, 0.95, 0.85, 0.7))
	_prop("cloud", top + Vector3(3.0, -2.2, -2.0), 20.0, 1.6, {"collision": "none"})
	_prop("cloud", top + Vector3(-3.5, -1.6, 2.5), 200.0, 1.2, {"collision": "none"})
	add_spawn("summit", top + Vector3(0, 0.1, 2.4), 0.0)


func _on_summit(_p: Node) -> void:
	Game.set_flag("sea_summit", true)
	Game.note("sea_summit", "The highest platform", "The top of the drifting platforms over the Slow Sea. From here the shore is a line and the faces are pebbles. A moth the size of a boat is resting there, next to a pair of wings.")
	Game.toast.emit("From up here the tide looks almost as if it were moving.")


# --- sky --------------------------------------------------------------------------

func _sky_things() -> void:
	# a moon with a face, low over the sea. It hangs from the sky dome, which
	# follows the camera, so it stays where a moon should stay and the fog
	# cannot reach it.
	if sky != null:
		var moon := Props.place(sky, "moon_face", Vector3(40.0, 44.0, -120.0), 180.0, 8.0, {"collision": "none", "unshaded": true, "cast_shadow": false, "name": "Moon"})
		var mm := StandardMaterial3D.new()
		mm.albedo_texture = Kit.tex("faces/moon")
		mm.albedo_color = Color(1.0, 0.97, 0.9)
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mm.alpha_scissor_threshold = 0.5
		mm.cull_mode = BaseMaterial3D.CULL_DISABLED
		mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		if "disable_fog" in mm:
			mm.set("disable_fog", true)
		for mi in moon.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi
			if m.mesh != null:
				for si in m.mesh.get_surface_count():
					m.set_surface_override_material(si, mm)
	Kit.light(self, Vector3(30.0, 26.0, -60.0), Color(1.0, 0.9, 0.8), 1.0, 50.0)
	for cp in [Vector3(-20.0, 16.0, -30.0), Vector3(30.0, 20.0, -36.0), Vector3(-42.0, 12.0, -22.0), Vector3(48.0, 14.0, -18.0), Vector3(8.0, 24.0, -48.0), Vector3(-6.0, 9.0, 22.0), Vector3(40.0, 11.0, 26.0)]:
		var p: Vector3 = cp
		_prop("cloud", p, rng.randf_range(0.0, 360.0), rng.randf_range(2.0, 3.6), {"collision": "none", "cast_shadow": false})


func _palette(phase: float) -> Array:
	var ph := fposmod(phase, 1.0) * 3.0
	var i := int(floor(ph))
	var f := smoothstep(0.0, 1.0, ph - float(i))
	var a: Array = PALETTE[i % 3]
	var b: Array = PALETTE[(i + 1) % 3]
	var out: Array = []
	for k in 4:
		var ca: Color = a[k]
		var cb: Color = b[k]
		out.append(ca.lerp(cb, f))
	return out


func _apply_sky(phase: float) -> void:
	if env == null:
		return
	var c := _palette(phase)
	var bg: Color = c[0]
	var fog: Color = c[1]
	var amb: Color = c[2]
	env.background_color = bg
	env.fog_light_color = fog
	env.ambient_light_color = amb
	if sky != null and sky.material_override is ShaderMaterial:
		(sky.material_override as ShaderMaterial).set_shader_parameter("tint", c[3])
	if water != null and water.material_override is ShaderMaterial:
		var wc: Color = c[1]
		(water.material_override as ShaderMaterial).set_shader_parameter("tint", Color(0.3 + wc.r * 0.3, 0.2 + wc.g * 0.25, 0.55 + wc.b * 0.3, 0.8))


func _process(delta: float) -> void:
	if not built:
		return
	if Game.time_frozen:
		return
	_t += delta
	_apply_sky(_phase0 + _t / CYCLE)
	if moth != null and is_instance_valid(moth):
		moth.position.y = 1.3 + 0.18 * sin(_t * 2.3) + 0.05 * sin(_t * 7.1)
	if moth_wings != null and is_instance_valid(moth_wings):
		moth_wings.scale.y = 1.0 + 0.5 * sin(_t * 1.1)


# --- hooks ----------------------------------------------------------------------------

func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	Game.bump("sea_visits")
	_apply_sky(_phase0)
	if spawn_id == "from_tavern":
		Game.toast.emit("You wake on the shore. The bed came with you.")
	if n == 1:
		Game.note("sea_shore", "The Slow Sea", "A pale beach under a lilac sky, and a sea that is purple and does not move. Faces asleep in the sand. A pier that goes out to a door. Platforms in the air, some of them drifting.")
	elif n == 2:
		Game.note("sea_awake", "The second time", "The faces on the shore have opened their eyes. The sky is a different colour. Nothing has moved, except that.")


func on_bell(_origin: Vector3) -> void:
	# every sleeping face opens its eyes, for a while
	var woke: Array = []
	for f in faces:
		var fd: Dictionary = f
		if fd.state == "sleep":
			_set_face(fd, "awake")
			woke.append(fd)
	if woke.is_empty():
		Game.toast.emit("The bell goes out over the water and does not come back.")
		return
	Audio.sfx("stone_grind", player_pos(), -6.0)
	Game.toast.emit("All along the shore, eyes open.")
	Game.note("sea_bell", "The bell on the shore", "You rang the Small Bell on the Slow Sea and every sleeping face opened its eyes at once. They closed them again, slowly, the way a tide goes out.")
	get_tree().create_timer(7.0).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		for fd in woke:
			if visit_count < 2:
				_set_face(fd, "sleep"))


func on_umbrella(open: bool) -> void:
	if not is_inside_tree():
		return
	if rain == null:
		rain = Kit.particles(self, Vector3(0, 12, 0), "rain", Vector3(40, 3, 30), 600)
		rain.name = "Rain"
	rain.emitting = open
	if water == null:
		return
	var tw := create_tween()
	if open:
		tw.tween_property(water, "position:y", 0.3, 25.0).set_trans(Tween.TRANS_SINE)
		Audio.sfx("thunder", null, -6.0)
		Game.toast.emit("It rains on the sea. The tide, which takes a hundred years, takes the hint.")
		Game.note("sea_tide", "The tide comes in", "You opened the umbrella on the shore of the Slow Sea and it rained, and the tide came in, a little, for the first time in a hundred years. It covered the writing. It did not reach the bed.")
	else:
		tw.tween_property(water, "position:y", -0.15, 25.0).set_trans(Tween.TRANS_SINE)


func on_lantern(lit: bool) -> void:
	if lantern_writing != null and is_instance_valid(lantern_writing):
		lantern_writing.enabled = lit


func on_time_frozen(frozen: bool) -> void:
	if frozen:
		Game.toast.emit("The platforms stop drifting. The sea, which was not moving, does not notice.")

# Left for later iterations:
#  - the Risen face should speak when reached with wings (a landing platform on its brow)
#  - a second seam under the pier so that wading under it comes out under a different pier
#  - the tide (umbrella) could reveal a door under the sand where the writing was
