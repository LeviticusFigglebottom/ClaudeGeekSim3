class_name KD
## The parts every square of the King's Dream is made of: the measurements of a
## square, its hedges, the fords where a brook crosses an edge, the painted
## board beyond the hedges, and a few figures that recur (faces on stems, small
## figures, hedge blocks). The area script owns the brooks themselves; the
## square files build what stands between them.

const SQ := 90.0          # a square is ninety metres across
const HALF := 45.0
const HEDGE_H := 3.4
const HEDGE_T := 1.2
const BROOK := 41.5       # from the centre of a square to the centre line of a brook
const BROOK_W := 3.0
const GATE := 38.0        # the inner hedge line, with the gap in it, before a ford
const GATE_W := 8.0
const RIM := 45.6         # the perimeter hedge
const FENCE_H := 60.0     # invisible: nothing glides off the board

## The four edges. `dir` points out of the square, `yaw` faces the same way.
const EDGES := {
	"N": {"dir": Vector3(0, 0, -1), "yaw": 0.0},
	"S": {"dir": Vector3(0, 0, 1), "yaw": 180.0},
	"E": {"dir": Vector3(1, 0, 0), "yaw": -90.0},
	"W": {"dir": Vector3(-1, 0, 0), "yaw": 90.0},
}

const HEDGE_TINT := Color(1.0, 1.0, 1.0)


static func edge_dir(edge: String) -> Vector3:
	return EDGES[edge].dir


static func edge_yaw(edge: String) -> float:
	return float(EDGES[edge].yaw)


## A point `along` metres out from the centre on `edge`, `across` metres to the
## right of the edge's midline (as seen looking out), `y` up.
static func at(edge: String, along: float, across: float = 0.0, y: float = 0.0) -> Vector3:
	var d := edge_dir(edge)
	var right := Vector3(-d.z, 0, d.x)
	return d * along + right * across + Vector3(0, y, 0)


# --- hedges ---------------------------------------------------------------------

## A clipped hedge between two ground points.
static func hedge(parent: Node, from: Vector3, to: Vector3, opts: Dictionary = {}) -> MeshInstance3D:
	var o := {"thick": float(opts.get("thick", HEDGE_T)), "tile": 1.6, "tint": opts.get("tint", HEDGE_TINT)}
	if opts.has("name"):
		o["name"] = opts.name
	if opts.has("solid"):
		o["solid"] = opts.solid
	return Kit.wall(parent, from, to, float(opts.get("height", HEDGE_H)), String(opts.get("tex", "nature/hedge")), o)


## A single hedge block (the maze and the borders are made of these).
static func hedge_block(parent: Node, pos: Vector3, size: Vector3, opts: Dictionary = {}) -> MeshInstance3D:
	var o := {"tile": 1.6, "tint": opts.get("tint", HEDGE_TINT)}
	if opts.has("solid"):
		o["solid"] = opts.solid
	return Kit.box(parent, pos + Vector3(0, size.y * 0.5, 0), size, String(opts.get("tex", "nature/hedge")), o)


## The perimeter hedge of a square, all four sides, with an invisible fence
## above it so a glide cannot leave the board.
static func rim(parent: Node, y: float, tint: Color = HEDGE_TINT) -> void:
	var r := RIM
	var e := HALF + 1.2
	var corners := [Vector3(-e, y, -r), Vector3(e, y, -r), Vector3(e, y, r), Vector3(-e, y, r)]
	var sides := [[Vector3(-e, y, -r), Vector3(e, y, -r)], [Vector3(e, y, -r), Vector3(e, y, r)], [Vector3(e, y, r), Vector3(-e, y, r)], [Vector3(-e, y, r), Vector3(-e, y, -r)]]
	for s in sides:
		hedge(parent, s[0], s[1], {"tint": tint})
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var mid := (a + b) * 0.5 + Vector3(0, FENCE_H * 0.5, 0)
		var horizontal := absf(a.x - b.x) > absf(a.z - b.z)
		Kit.blocker(parent, mid, Vector3(SQ + 4.0 if horizontal else 1.0, FENCE_H, 1.0 if horizontal else SQ + 4.0))


## The inner hedge line before a ford, with a gap in the middle of it.
static func gate(parent: Node, edge: String, y: float, tint: Color = HEDGE_TINT, gap_w: float = GATE_W) -> void:
	var hw := gap_w * 0.5
	hedge(parent, at(edge, GATE, -HALF - 0.6, y), at(edge, GATE, -hw, y), {"tint": tint})
	hedge(parent, at(edge, GATE, hw, y), at(edge, GATE, HALF + 0.6, y), {"tint": tint})


## Everything a brook needs on one edge of a square except the seam: the bank
## you approach on, the pebbled bed, the water, and the far bank dressed as
## the square the brook leads to. Returns where the seam goes (local).
static func ford(parent: Node, edge: String, y: float, this_def: Dictionary, other_def: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var ns := edge == "N" or edge == "S"
	var strip := func(along: float, depth: float, tex: String, tint: Color, lift: float) -> void:
		var size := Vector2(SQ + 2.0, depth) if ns else Vector2(depth, SQ + 2.0)
		Kit.floor(parent, at(edge, along, 0.0, y + lift), size, tex, {"tint": tint, "tile": 2.0, "thick": 0.05})
	if bool(opts.get("gate", true)):
		gate(parent, edge, y, this_def.get("hedge", HEDGE_TINT), float(opts.get("gap", GATE_W)))
	# the near bank
	strip.call(GATE + 1.0, 2.0, String(this_def.ground), this_def.get("tint", Color.WHITE), 0.04)
	# the bed and the water
	strip.call(BROOK, BROOK_W, "ground/pebbles", Color(0.9, 0.95, 1.0), 0.03)
	var wsize := Vector2(SQ + 2.0, BROOK_W) if ns else Vector2(BROOK_W, SQ + 2.0)
	var water := Kit.water(parent, at(edge, BROOK, 0.0, y + 0.16), wsize, "nature/water_sea", {"tint": opts.get("water", this_def.get("water", Color(0.8, 0.85, 1.0, 0.75))), "uv_scale": 0.5, "speed": 0.05, "swell": 0.02})
	water.name = "Brook_" + edge
	# the far bank, which is the other square's
	strip.call(BROOK + BROOK_W * 0.5 + 1.3, 2.6, String(other_def.ground), other_def.get("tint", Color.WHITE), 0.04)
	# stones on both banks
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(edge) + int(y * 7.0) + hash(String(this_def.id))
	for i in 14:
		var across := rng.randf_range(-HALF + 2.0, HALF - 2.0)
		var side := BROOK - BROOK_W * 0.5 - 0.3 if i % 2 == 0 else BROOK + BROOK_W * 0.5 + 0.3
		Props.place(parent, "rock_%d" % (1 + i % 3), at(edge, side, across, y), rng.randf_range(0.0, 360.0), rng.randf_range(0.25, 0.5), {"collision": "none"})
	# a light at the crossing, so the water is never black
	Kit.light(parent, at(edge, BROOK, 0.0, y + 3.0), opts.get("light", Color(1.0, 0.92, 0.8)), 0.9, 12.0)
	return {"pos": at(edge, BROOK, 0.0, y), "yaw": edge_yaw(edge)}


# --- the painted board ------------------------------------------------------------

## The other files of the board: flat colour beyond the hedges, receding into
## the fog, with dark hedge lines and pale brooks painted between them. One
## mesh, no collision, nothing to reach.
static func painted_board(parent: Node, y: float, colours: Array, seed_: int) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var pitch := SQ + 8.0
	var quads: Array = []
	var cols: Array = []
	var flat := func(cx: float, cz: float, w: float, d: float, col: Color) -> void:
		var x0 := cx - w * 0.5
		var x1 := cx + w * 0.5
		var z0 := cz - d * 0.5
		var z1 := cz + d * 0.5
		quads.append([Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector3.UP])
		cols.append(col)
	var hedge_col := Color(0.16, 0.36, 0.18)
	var brook_col := Color(0.62, 0.7, 0.9)
	for i in range(-3, 4):
		for j in range(-3, 4):
			if i == 0 and j == 0:
				continue
			var c: Color = colours[rng.randi() % colours.size()]
			flat.call(i * pitch, j * pitch, SQ, SQ, c)
			# hedge lines on the north and east sides, a brook between them and the next square
			flat.call(i * pitch, j * pitch - HALF - 0.8, SQ + 3.0, 1.6, hedge_col)
			flat.call(i * pitch + HALF + 0.8, j * pitch, 1.6, SQ + 3.0, hedge_col)
			flat.call(i * pitch, j * pitch - HALF - 4.0, SQ, 3.0, brook_col)
			flat.call(i * pitch + HALF + 4.0, j * pitch, 3.0, SQ, brook_col)
	var mesh := Kit.mesh_from_quads(quads, cols)
	var mi := Kit.add_mesh(parent, mesh, Kit.vertex_mat({"unshaded": true}), Vector3(0, y - 0.6, 0), {"solid": false, "name": "PaintedBoard", "cast_shadow": false})
	return mi


# --- recurring things ---------------------------------------------------------------

## A sleeping face from the Slow Sea, grown on a stem. Returns {root, sleep, awake, sad}.
static func face_on_stem(parent: Node, pos: Vector3, yaw: float, scale: float, state: String = "sleep", tint: Color = Color.WHITE) -> Dictionary:
	var root := Node3D.new()
	root.name = "FaceStem"
	root.position = pos
	root.rotation.y = deg_to_rad(yaw)
	parent.add_child(root)
	var stem_h := 1.6 * scale
	Kit.cylinder(root, Vector3.ZERO, 0.08 * scale, stem_h, "", {"tint": Color(0.35, 0.6, 0.3), "segments": 5, "solid": true, "surface": "grass"})
	for k in 5:
		var a := k * 72.0
		var leaf := Kit.box(root, Kit.polar(0.28 * scale, a, stem_h * 0.35), Vector3(0.5 * scale, 0.02, 0.18 * scale), "", {"tint": Color(0.4, 0.7, 0.35), "solid": false})
		leaf.rotation.y = deg_to_rad(-a)
		leaf.rotation.z = 0.35
	var f := {"root": root, "state": state}
	for kind in ["sleep", "awake", "sad"]:
		var inst := Props.place(root, "face_sea_" + kind, Vector3(0, stem_h, 0), 0.0, scale * 0.16, {"collision": "none", "name": kind, "tint": tint})
		inst.visible = (kind == state)
		f[kind] = inst
	return f


static func set_face(f: Dictionary, state: String) -> void:
	f["state"] = state
	for kind in ["sleep", "awake", "sad"]:
		var n: Node3D = f[kind]
		n.visible = (kind == state)


## A thin flat-coloured figure (the painters, the jury, the guests who are not there).
static func figure(parent: Node, pos: Vector3, yaw: float, col: Color, height: float = 1.8) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = deg_to_rad(yaw)
	root.name = "Figure"
	parent.add_child(root)
	var s := height / 1.8
	var m := Kit.flat(col)
	Kit.box(root, Vector3(0, 0.85 * s, 0), Vector3(0.44 * s, 1.3 * s, 0.26 * s), "", {"mat": m, "solid": false})
	Kit.box(root, Vector3(0, 1.72 * s, 0), Vector3(0.26 * s, 0.3 * s, 0.26 * s), "", {"mat": Kit.flat(col.lightened(0.2)), "solid": false})
	Kit.box(root, Vector3(-0.14 * s, 0.25 * s, 0), Vector3(0.14 * s, 0.5 * s, 0.18 * s), "", {"mat": m, "solid": false})
	Kit.box(root, Vector3(0.14 * s, 0.25 * s, 0), Vector3(0.14 * s, 0.5 * s, 0.18 * s), "", {"mat": m, "solid": false})
	Kit.box(root, Vector3(-0.3 * s, 1.0 * s, -0.05 * s), Vector3(0.1 * s, 0.7 * s, 0.1 * s), "", {"mat": m, "solid": false})
	Kit.box(root, Vector3(0.3 * s, 1.0 * s, -0.05 * s), Vector3(0.1 * s, 0.7 * s, 0.1 * s), "", {"mat": m, "solid": false})
	Kit.blocker(root, Vector3(0, 0.9 * s, 0), Vector3(0.5 * s, 1.8 * s, 0.4 * s), Kit.L_WORLD, "carpet")
	return root


## Text lying flat on the ground, readable from `yaw`'s side.
static func ground_text(parent: Node, text: String, pos: Vector3, yaw: float, size: int, color: Color, kind: String = "display") -> Label3D:
	var l := Kit.label(parent, text, pos + Vector3(0, 0.06, 0), yaw, size, color, kind, {"pixel_size": 0.02, "outline": 0})
	l.rotation_degrees = Vector3(-90.0, yaw, 0.0)
	return l
