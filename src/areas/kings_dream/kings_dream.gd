extends AreaBase
## The King's Dream — the Red King's dream, and you are a thing in it. The
## structure is the chess problem from Through the Looking-Glass: eight squares,
## each a biome ninety metres across and hedged on every side, with a brook on
## the far edge of each. Crossing a brook is a seam; the banks are a hundred
## and thirty metres apart in world space and the world changes as you step.
## Beyond the hedges the rest of the board is painted on. Two brooks run
## backwards, and the board is dealt differently on the second visit.
##
## This file owns the board: the square origins, the hedges, the fords, the
## seams, the spawns, the exit and the hooks. What stands inside each square is
## built by one file per square (sq_garden.gd and the rest), which never make
## a spawn or a door.

const GAP := 130.0            # between the origins of neighbouring squares
const SEAM_SIZE := Vector3(KD.SQ + 2.0, 8.0, 1.4)

## One entry per square, in the order of the ranks of the book. Index is the
## square's fixed place in world space; the order they are walked in changes.
const DEFS := [
	{"id": "garden", "ambience": "forest", "rank": "the second square", "name": "the Garden of Live Flowers", "y": 0.0,
		"ground": "nature/grass_dream", "tint": Color(1.0, 1.0, 0.92), "hedge": Color(1.0, 1.0, 0.95),
		"water": Color(0.9, 0.78, 1.0, 0.75), "paint": Color(0.62, 0.8, 0.32),
		"fog": Color("#f6c9b8"), "fog_density": 0.009, "ambient": Color("#f8ddc8"), "bg": Color("#4a2a58"), "sun": Color("#fff2cf"), "sky": Color(1.0, 1.0, 1.0)},
	{"id": "carriage", "ambience": "corridor", "rank": "the third square", "name": "the Carriage", "y": 9.0,
		"ground": "ground/gravel", "tint": Color(0.95, 0.9, 0.85), "hedge": Color(0.85, 0.9, 0.75),
		"water": Color(0.8, 0.8, 0.9, 0.75), "paint": Color(0.55, 0.5, 0.45),
		"fog": Color("#d9c1a6"), "fog_density": 0.013, "ambient": Color("#e6d0b8"), "bg": Color("#4a3040"), "sun": Color("#ffe8c0"), "sky": Color(0.95, 0.85, 0.8)},
	{"id": "wood", "ambience": "hallway", "rank": "the fourth square", "name": "the Wood Where Things Have No Names", "y": -7.0,
		"ground": "wall/hallway_grey", "tint": Color(0.9, 0.9, 0.95), "hedge": Color(0.7, 0.72, 0.8),
		"water": Color(0.7, 0.7, 0.8, 0.8), "paint": Color(0.42, 0.42, 0.48),
		"fog": Color("#c4bccd"), "fog_density": 0.02, "ambient": Color("#cfc8dc"), "bg": Color("#2a2434"), "sun": Color("#e0dcf0"), "sky": Color(0.75, 0.72, 0.85)},
	{"id": "river", "ambience": "cistern", "rank": "the fifth square", "name": "the Shop and the River", "y": 4.0,
		"ground": "ground/sand", "tint": Color(1.0, 0.98, 0.9), "hedge": Color(0.9, 1.0, 0.9),
		"water": Color(0.75, 0.62, 1.0, 0.8), "paint": Color(0.6, 0.78, 0.8),
		"fog": Color("#bfe3dc"), "fog_density": 0.011, "ambient": Color("#d4ece8"), "bg": Color("#1e3a44"), "sun": Color("#fff3dd"), "sky": Color(0.8, 1.0, 0.95)},
	{"id": "wall", "ambience": "city", "rank": "the sixth square", "name": "the Wall", "y": 16.0,
		"ground": "stone/cobble_city", "tint": Color(0.95, 0.95, 1.0), "hedge": Color(0.75, 0.85, 0.8),
		"water": Color(0.6, 0.7, 0.85, 0.85), "paint": Color(0.45, 0.5, 0.6),
		"fog": Color("#a8b6c8"), "fog_density": 0.012, "ambient": Color("#c0c8d8"), "bg": Color("#2a2f3a"), "sun": Color("#dfe4f0"), "sky": Color(0.75, 0.8, 0.9)},
	{"id": "table", "ambience": "tavern", "rank": "the seventh square", "name": "the Tea Table", "y": -12.0,
		"ground": "nature/grass_pale", "tint": Color(1.0, 0.95, 0.75), "hedge": Color(1.0, 0.95, 0.7),
		"water": Color(1.0, 0.9, 0.7, 0.8), "paint": Color(0.82, 0.72, 0.4),
		"fog": Color("#f0d6a0"), "fog_density": 0.032, "ambient": Color("#f6e2b8"), "bg": Color("#5a3a20"), "sun": Color("#ffe0a0"), "sky": Color(1.0, 0.9, 0.7)},
	{"id": "trial", "ambience": "furnace", "rank": "the eighth square, nearly", "name": "the Croquet Ground", "y": 6.0,
		"ground": "ground/red_dream", "tint": Color(1.0, 0.9, 0.9), "hedge": Color(0.9, 0.6, 0.55),
		"water": Color(1.0, 0.6, 0.55, 0.8), "paint": Color(0.7, 0.22, 0.2),
		"fog": Color("#e06a5a"), "fog_density": 0.013, "ambient": Color("#f0a090"), "bg": Color("#3a0a10"), "sun": Color("#ffb090"), "sky": Color(1.0, 0.65, 0.6)},
	{"id": "eighth", "ambience": "nexus", "rank": "the eighth square", "name": "the Eighth Square", "y": 22.0,
		"ground": "stone/blocks_nexus", "tint": Color(1.0, 1.0, 1.05), "hedge": Color(0.8, 0.8, 1.0),
		"water": Color(0.7, 0.7, 1.0, 0.8), "paint": Color(0.35, 0.32, 0.55),
		"fog": Color("#c8bfe6"), "fog_density": 0.011, "ambient": Color("#d8d0f0"), "bg": Color("#1a1430"), "sun": Color("#e8e0ff"), "sky": Color(0.85, 0.8, 1.0)},
]

## The march, by square index: the ranks in order, the same on every visit,
## so the board a player learns is the board they come back to.
const ORDER := [0, 1, 2, 3, 4, 5, 6, 7]
## Brooks that run backwards: [from square, from edge, to square, to edge]. "WALL" is
## the brook on top of the wall in the sixth square, which the square builds itself.
const BACKS := [[4, "WALL", 0, "E"], [7, "N", 2, "W"]]

## The north brook of each square is hedged shut until that square's own
## business is done: no square is walked through.
const GATE_FLAGS := {
	"garden": ["maze_walked", "The hedge is thick here and does not part. There is a word in this garden you have not read from the air, and walked."],
	"wood": ["dream_king_reached", "The hedge does not part. You have not reached him, under the tree, where the trunks breathe."],
	"river": ["dream_rush", "The hedge does not part. On the far bank grows one rush that does not fade, and you have not picked it."],
	"wall": ["dream_egg_fell", "The hedge does not part. Nothing has fallen off the wall yet."],
	"table": ["dream_seated", "The hedge does not part. Nobody has sat down at the table."],
	"trial": ["dream_charge_read", "The hedge does not part. The sentence has not been read, and it is not read at this speed."],
}

var sq: Array = []            # per square index: {node, origin, def, anchors, fords}
var order: Array = []
var current := -1
var env: Environment = null
var sun: DirectionalLight3D = null
var sky: MeshInstance3D = null
var brooks_built := 0
var _palette_tween: Tween = null
var _pending_notes: Array = []
var _t := 0.0


func build() -> void:
	var r := Realm.apply(self, "kings_dream", {"sky_opts": {"band_strength": 0.04, "band_speed": 0.12}})
	env = r.get("env")
	sun = r.get("sun")
	sky = r.get("sky")
	if sun:
		sun.directional_shadow_max_distance = 90.0
	order = ORDER
	_plan_fords()
	for i in DEFS.size():
		_build_square(i)
	_build_brooks()
	_exit()
	var g: Dictionary = sq[0]
	add_spawn("from_king", g.origin + Vector3(0, 0.1, 30.0), 0.0)
	add_spawn("default", g.origin + Vector3(0, 0.1, 30.0), 0.0)
	Puzzle.declare(self, "kings_dream_march", "dream_reached_eighth", ["keepsake:wings", "keepsake:hourglass"], "walk the board from the second square to the eighth; every brook is a square")
	var start := 0
	for i in DEFS.size():
		# tools/shot.sh --flag=kd_start_<id> renders a square other than the first
		if Game.has_flag("kd_start_" + String(DEFS[i].id)):
			start = i
	_set_current(start, false)


# --- the plan: which edges carry brooks, and where they go --------------------------

func _plan_fords() -> void:
	sq = []
	for i in DEFS.size():
		sq.append({"def": DEFS[i], "origin": Vector3(i * GAP, float(DEFS[i].y), 0.0), "fords": {}, "anchors": {}, "node": null, "index": i})
	for k in order.size() - 1:
		var a: int = order[k]
		var b: int = order[k + 1]
		sq[a].fords["N"] = {"kind": "leave", "other": b, "other_edge": "S", "two_way": true}
		sq[b].fords["S"] = {"kind": "arrive", "other": a, "other_edge": "N", "two_way": true}
	for bk in BACKS:
		var a: int = bk[0]
		var ea: String = bk[1]
		var b: int = bk[2]
		var eb: String = bk[3]
		sq[a].fords[ea] = {"kind": "leave_back", "other": b, "other_edge": eb, "two_way": false}
		sq[b].fords[eb] = {"kind": "arrive_back", "other": a, "other_edge": ea, "two_way": false}


## Which square file builds which square.
func _builder(id: String) -> Variant:
	match id:
		"garden": return KDGarden
		"carriage": return KDCarriage
		"wood": return KDWood
		"river": return KDRiver
		"wall": return KDWall
		"table": return KDTable
		"trial": return KDTrial
		"eighth": return KDEighth
	return null


func _build_square(i: int) -> void:
	var s: Dictionary = sq[i]
	var d: Dictionary = s.def
	var node := Node3D.new()
	node.name = "Square_" + String(d.id)
	node.position = s.origin
	add_child(node)
	s["node"] = node
	KD.rim(node, 0.0, d.hedge)
	var paints: Array = []
	for other in DEFS:
		if other.id != d.id:
			paints.append(other.paint)
	KD.painted_board(node, 0.0, paints, hash(String(d.id)))
	# the square's own contents
	var ctx := {"index": i, "def": d, "visit": visit_count, "fords": s.fords, "order": order, "march": order.find(i), "area": self}
	var anchors: Dictionary = {}
	var builder = _builder(String(d.id))
	if builder != null:
		anchors = builder.build(self, node, ctx)
	s["anchors"] = anchors
	# fords on every edge that carries a brook (the wall builds its own)
	var edge_y: Dictionary = anchors.get("edge_y", {})
	for edge in s.fords:
		if edge == "WALL":
			continue
		var f: Dictionary = s.fords[edge]
		var other: Dictionary = DEFS[int(f.other)]
		var fo := {"gate": bool(anchors.get("gates", {}).get(edge, true)), "other_gates": s.fords.keys()}
		var anchor := KD.ford(node, edge, float(edge_y.get(edge, 0.0)), d, other, fo)
		anchors[edge] = anchor
		if edge == "N" and f.kind == "leave" and GATE_FLAGS.has(String(d.id)):
			_gate_ford(node, float(edge_y.get(edge, 0.0)), d, GATE_FLAGS[String(d.id)])
	# someone tall, further away in every square
	var far: float = 18.0 + 6.0 * float(order.find(i))
	if Game.count("usher_sightings") < 9 and not anchors.has("usher"):
		Usher.spawn(node, Vector3(-far * 0.7, 0, -far * 0.6), {"appear_delay": 3.0 + order.find(i), "radius": 60.0})
	elif anchors.has("usher") and Game.count("usher_sightings") < 9:
		Usher.spawn(node, anchors.usher, {"appear_delay": 2.0, "radius": 60.0})
	node.visible = false


## A hedge grown across the gap in a square's north gate, and a wall you
## cannot see above it, until the square's flag is set; then, as you come to
## it, it lets you through.
func _gate_ford(node: Node3D, y: float, d: Dictionary, spec: Array) -> void:
	var flag := String(spec[0])
	var hint := String(spec[1])
	if Game.has_flag(flag):
		return
	var gate := Node3D.new()
	gate.name = "Gate_N"
	node.add_child(gate)
	var at := KD.at("N", KD.GATE, 0.0, y)
	KD.hedge_block(gate, at + Vector3(0, KD.HEDGE_H * 0.5, 0), Vector3(KD.GATE_W + 1.0, KD.HEDGE_H, KD.HEDGE_T + 0.24), {"tint": d.get("hedge", KD.HEDGE_TINT)})
	Kit.blocker(gate, at + Vector3(0, 20.0, 0), Vector3(KD.GATE_W + 1.0, 40.0, KD.HEDGE_T))
	var last := {"t": -100.0}
	Kit.trigger(node, at + Vector3(0, 1.5, 0), Vector3(16.0, 3.0, 9.0), func(_p: Node) -> void:
		if not is_instance_valid(gate):
			return
		if Game.has_flag(flag):
			Audio.sfx("grow", gate.global_position, -6.0)
			Game.toast.emit("The hedge parts.")
			gate.queue_free()
			return
		var now := Time.get_ticks_msec() / 1000.0
		if now - float(last.t) > 8.0:
			last.t = now
			Game.toast.emit(hint), {"name": "GateWatch_N", "continuous": true})


# --- the brooks -----------------------------------------------------------------

func _seam_at(i: int, edge: String, inward: bool) -> Dictionary:
	var s: Dictionary = sq[i]
	var a: Dictionary = s.anchors.get(edge, {})
	if a.is_empty():
		push_error("kings_dream: square %s has no anchor for edge %s" % [s.def.id, edge])
		return {"pos": s.origin, "yaw": 0.0}
	var yaw := float(a.yaw) + (180.0 if inward else 0.0)
	return {"pos": s.origin + a.pos, "yaw": yaw}


func _build_brooks() -> void:
	var done: Dictionary = {}
	for i in sq.size():
		for edge in sq[i].fords:
			var f: Dictionary = sq[i].fords[edge]
			if f.kind != "leave" and f.kind != "leave_back":
				continue
			var j := int(f.other)
			var key := "%d%s" % [i, edge]
			if done.has(key):
				continue
			done[key] = true
			var a := _seam_at(i, edge, false)
			var b := _seam_at(j, String(f.other_edge), true)
			var nm := "Brook_%s_%s_to_%s" % [sq[i].def.id, edge, sq[j].def.id]
			SeamlessTeleport.create(self, a.pos, a.yaw, b.pos, b.yaw, SEAM_SIZE, {"name": nm, "on_teleport": _arrive.bind(j, i, f.kind == "leave_back")})
			brooks_built += 1
			if f.two_way:
				SeamlessTeleport.create(self, b.pos, b.yaw + 180.0, a.pos, a.yaw + 180.0, SEAM_SIZE, {"name": nm + "_back", "on_teleport": _arrive.bind(i, j, false)})


## Stepping out of a brook onto the far bank of another square.
func _arrive(_p: Node, j: int, from_i: int, backwards: bool) -> void:
	if j == current:
		return
	_set_current(j, true)
	var n := Game.bump("dream_brooks_crossed")
	var d: Dictionary = sq[j].def
	Audio.sfx("step_water", player_pos(), -10.0)
	if n == 1:
		Game.note("dream_brook", "The first brook", "You stepped over a stream no wider than a bed and the world on the other side was a different world. The hedges did not mind. In the book it was the same: every brook is a square, and every square is a move.")
	if backwards:
		var a: Dictionary = sq[j].anchors
		if a.has("on_return"):
			(a.on_return as Callable).call()
		Game.set_flag("dream_back_" + String(d.id), true)
		Game.note("dream_back_" + String(d.id), "A brook that runs backwards", "The brook out of %s put you back in %s, from a side you had not come in by. It is not the square you crossed. Crossing it changed it." % [sq[from_i].def.name, d.name])
	elif String(d.id) == "wood":
		Game.toast.emit(String(d.rank) + ": ")
	else:
		Game.toast.emit(String(d.rank) + ": " + String(d.name))
	Game.set_flag("dream_reached_" + String(d.id), true)
	_flush_notes()


## The wood will not let the journal write. Notes made there are kept until the
## player is somewhere that has names again.
func defer_note(key: String, title: String, text: String) -> void:
	if current >= 0 and String(sq[current].def.id) == "wood" and not Game.has_flag("dream_back_wood"):
		for n in _pending_notes:
			if n[0] == key:
				return
		_pending_notes.append([key, title, text])
		return
	Game.note(key, title, text)


func _flush_notes() -> void:
	if _pending_notes.is_empty():
		return
	for n in _pending_notes:
		Game.note(n[0], n[1], "(Written afterwards. The wood would not let you write it there.) " + n[2])
	_pending_notes.clear()
	Game.toast.emit("Your hand remembers what it could not write in the wood.")


func _process(delta: float) -> void:
	if not built or current < 0:
		return
	_t += delta
	var a: Dictionary = sq[current].anchors
	if a.has("on_process"):
		(a.on_process as Callable).call(delta)


## Only the square you are in is drawn; the others are a hundred metres off and
## behind hedges, and the fog is not to be relied on.
func _set_current(i: int, animate: bool) -> void:
	current = i
	for k in sq.size():
		var n: Node3D = sq[k].node
		if n:
			n.visible = (k == i)
	var d: Dictionary = sq[i].def
	Audio.set_ambience(String(d.get("ambience", "sea")))
	if env == null:
		return
	if _palette_tween:
		_palette_tween.kill()
	if not animate:
		env.fog_light_color = d.fog
		env.fog_density = float(d.fog_density)
		env.ambient_light_color = d.ambient
		env.background_color = d.bg
		if sun:
			sun.light_color = d.sun
		if sky and sky.material_override is ShaderMaterial:
			(sky.material_override as ShaderMaterial).set_shader_parameter("tint", d.sky)
		return
	_palette_tween = create_tween().set_parallel(true)
	_palette_tween.tween_property(env, "fog_light_color", d.fog, 1.6)
	_palette_tween.tween_property(env, "fog_density", float(d.fog_density), 1.6)
	_palette_tween.tween_property(env, "ambient_light_color", d.ambient, 1.6)
	_palette_tween.tween_property(env, "background_color", d.bg, 1.6)
	if sun:
		_palette_tween.tween_property(sun, "light_color", d.sun, 1.6)
	if sky and sky.material_override is ShaderMaterial:
		_palette_tween.tween_method(func(c: Color) -> void: (sky.material_override as ShaderMaterial).set_shader_parameter("tint", c), (sky.material_override as ShaderMaterial).get_shader_parameter("tint"), d.sky, 1.6)


# --- the way out ----------------------------------------------------------------

func _exit() -> void:
	var e: Dictionary = sq[7]
	var a: Dictionary = e.anchors.get("exit", {"pos": Vector3(0, 0, -20.0), "yaw": 0.0})
	# the cloth is the way out; the ends are played on the board in the rotunda
	Interactable.make(self, e.origin + a.pos + Vector3(0, 1.0, 0), Vector3(2.4, 2.0, 1.8), "Take hold of the cloth", _on_cloth, {"name": "Door_out", "yaw": float(a.yaw)})
	Puzzle.declare(self, "kings_dream_out", "", [], "take hold of the cloth on the banquet table and pull", {"route": "nexus:from_kings_dream"})
	Puzzle.declare(self, "kings_dream_promotion", "ending_limbo", ["flag:dream_banquet_begun"], "once the banquet has begun, at the board: checkmate, the pawn to the eighth, and the last rank", {"route": "promotion:from_banquet"})
	Puzzle.declare(self, "kings_dream_plug", "ending_unplugged", ["flag:dream_banquet_begun"], "once the banquet has begun, at the board: concede, and pull the plug", {"route": "static_end:from_banquet"})


## The cloth is the way back: pull it and the dream lets go. The two ends are
## played on the board, not here.
func _on_cloth(_p: Node, _it: Node) -> void:
	World.travel("nexus", "from_kings_dream", {"color": Color.WHITE, "duration": 1.6})


# --- hooks ----------------------------------------------------------------------

func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	Game.set_flag("visited_kings_dream", true)
	if not World.travel_started.is_connected(_on_travel_started):
		World.travel_started.connect(_on_travel_started)
	if spawn_id == "from_king":
		_fall()
	if n == 1:
		Game.note("kings_dream_in", "The King's dream", "You went into the King's sleep and it was a garden, and the garden was a square on a board. He has never been to any of the places in it. He has only heard them described.")


## Holding R works here. It should feel like the wrong thing to do: you are
## leaving somebody else's sleep while they are still in it.
func _on_travel_started(area_id: String, _spawn_id: String) -> void:
	if World.travel_started.is_connected(_on_travel_started):
		World.travel_started.disconnect(_on_travel_started)
	if area_id == "apartment" and World.current_area_id == "kings_dream":
		Game.bump("dream_woken_out")
		Game.toast.emit("You wake out of somebody else's sleep. It is like leaving a room while someone is still talking.")
		Game.note("dream_woke_out", "Waking from the King's dream", "You held R inside the King's dream and woke in the flat. He did not. Somewhere he is still dreaming the square you left, with nobody in it.")


## The rabbit hole. The King lets you in from a long way up: you fall for a
## few seconds past the shelves of his museum and land on the lawn unhurt.
func _fall() -> void:
	var p := player()
	if p == null:
		return
	var g: Dictionary = sq[0]
	var top: Vector3 = g.anchors.get("fall_top", Vector3(0, 40.0, 30.0))
	p.global_position = g.origin + top
	p.set_look(0.0, -0.9)
	p.velocity = Vector3.ZERO
	p.last_safe_position = g.origin + Vector3(0, 0.1, 30.0)
	Audio.sfx("whisper", null, -6.0)
	Game.bump("dream_falls")


func on_time_frozen(frozen: bool) -> void:
	Audio.set_ambience_pitch(0.6 if frozen else 1.0)
	for p in find_children("*", "CPUParticles3D", true, false):
		(p as CPUParticles3D).speed_scale = 0.0 if frozen else 1.0
	for s in sq:
		var a: Dictionary = s.anchors
		if a.has("on_freeze"):
			(a.on_freeze as Callable).call(frozen)
	if frozen:
		Game.bump("dream_freezes")
