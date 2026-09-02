class_name MapBuilder
## Builds interiors (and street grids) from ASCII maps. The fastest way to
## author a lot of architecture: draw it.
##
## Legend
##   '#'  wall cell — a full-height textured block
##   '.'  floor cell — floor + ceiling
##   ' '  void — nothing; a floor cell beside void grows an edge wall unless
##        opts.open_edges is true
##   'D'  doorway — floor, no walls, and a lintel above door height
##   '~'  water floor (opts.water texture) — no ceiling change
##   ':'  floor open to the sky (no ceiling)
##   '@'  floor + spawn marker "@"
##   any other letter/digit: floor + marker, recorded in result.markers[char]
##   characters listed in opts.walls behave like '#' with another texture
##   characters listed in opts.floors are floor cells with another texture
##
## opts: cell (2.0), height (3.0), origin (Vector3 of the map's top-left corner),
## y (0.0), floor, wall, ceiling ("" for none), water, door_h (2.2), tile,
## floors {ch: tex}, walls {ch: tex}, no_ceiling "chars", open_edges (bool),
## wall_tops (bool), tint (Color), name
##
## Returns a Dictionary: markers {ch: [Vector3, ...]} (floor-level centres),
## cells {Vector2i: ch}, cell (float), origin (Vector3), root (Node3D), size (Vector2i),
## and helper Callables: center(col, row) -> Vector3.

## Doorway cells of every map built since `reset_registry()`; the verifier
## checks that nothing solid stands in them. Each entry: {pos, cell, height}.
static var doorways: Array = []

static func reset_registry() -> void:
	doorways = []


static func build(parent: Node, rows: Array, opts: Dictionary = {}) -> Dictionary:
	var cell := float(opts.get("cell", 2.0))
	var height := float(opts.get("height", 3.0))
	var origin: Vector3 = opts.get("origin", Vector3.ZERO)
	var y0 := float(opts.get("y", 0.0))
	var floor_tex := String(opts.get("floor", "stone/flagstone"))
	var wall_tex := String(opts.get("wall", "stone/blocks_grey"))
	var ceil_tex := String(opts.get("ceiling", "wall/ceiling_plaster"))
	var water_tex := String(opts.get("water", "nature/water_dark"))
	var door_h := float(opts.get("door_h", 2.2))
	var tile := float(opts.get("tile", Kit.default_tile))
	var floors: Dictionary = opts.get("floors", {})
	var walls: Dictionary = opts.get("walls", {})
	var no_ceiling := String(opts.get("no_ceiling", ""))
	var open_edges := bool(opts.get("open_edges", false))
	var wall_tops := bool(opts.get("wall_tops", ceil_tex == ""))
	var outer_faces := bool(opts.get("outer_faces", false))
	# thin edge walls draw their outer face too (for maps that stand alone; rooms that abut other maps must leave this off)
	var double_thin := bool(opts.get("double_thin", false))
	var mat_opts: Dictionary = {}
	if opts.has("tint"):
		mat_opts["tint"] = opts.tint

	var root := Node3D.new()
	root.name = String(opts.get("name", "Map"))
	root.position = origin
	parent.add_child(root)

	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	var grid: Dictionary = {}
	for r in h:
		var line := String(rows[r])
		for c in w:
			var ch := line[c] if c < line.length() else " "
			grid[Vector2i(c, r)] = ch

	var is_wall := func(ch: String) -> bool:
		return ch == "#" or walls.has(ch)
	var is_open := func(ch: String) -> bool:
		return ch == "D" or ch == "O"
	var is_floor := func(ch: String) -> bool:
		return ch != " " and not is_wall.call(ch)
	var get := func(c: int, r: int) -> String:
		return String(grid.get(Vector2i(c, r), " "))

	# quads per material key
	var buckets: Dictionary = {}   # key -> {tex, quads, kind}
	var add_quad := func(key: String, texn: String, kind: String, q: Array) -> void:
		if not buckets.has(key):
			buckets[key] = {"tex": texn, "quads": [], "kind": kind}
		buckets[key].quads.append(q)

	var markers: Dictionary = {}
	var shapes: Array = []   # [Vector3 center, Vector3 size, surface]
	var water_cells: Array = []
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # N E S W

	for r in h:
		for c in w:
			var ch: String = get.call(c, r)
			if ch == " ":
				continue
			var cx := (c + 0.5) * cell
			var cz := (r + 0.5) * cell
			var x0 := c * cell
			var x1 := (c + 1) * cell
			var z0 := r * cell
			var z1 := (r + 1) * cell
			if is_wall.call(ch):
				var wt: String = walls.get(ch, wall_tex)
				var touches := false
				for d in dirs:
					var nch: String = get.call(c + d.x, r + d.y)
					if is_floor.call(nch) or (outer_faces and nch == " "):
						touches = true
						var q := _wall_face(x0, x1, z0, z1, y0, y0 + height, d, tile)
						add_quad.call("wall:" + wt, wt, "wall", q)
				if wall_tops and touches:
					add_quad.call("wall:" + wt, wt, "wall", _top_face(x0, x1, z0, z1, y0 + height, tile))
				if touches:
					shapes.append([Vector3(cx, y0 + height * 0.5, cz), Vector3(cell, height, cell), Kit.surface_of(wt)])
				continue
			# floor-like cell
			var ft := floor_tex
			var open_above := ch == ":" or no_ceiling.contains(ch)
			if ch == "~":
				water_cells.append(Vector3(cx, y0, cz))
				ft = String(opts.get("water_floor", "ground/mud"))
			elif floors.has(ch):
				ft = String(floors[ch])
			var fy := y0 - (0.6 if ch == "~" else 0.0)
			add_quad.call("floor:" + ft, ft, "floor", _face(Vector3(x0, fy, z0), Vector3(x1, fy, z0), Vector3(x1, fy, z1), Vector3(x0, fy, z1), Vector2(x0 / tile, z0 / tile), Vector2(x1 / tile, z0 / tile), Vector2(x1 / tile, z1 / tile), Vector2(x0 / tile, z1 / tile), Vector3.UP))
			if ceil_tex != "" and not open_above:
				add_quad.call("ceil:" + ceil_tex, ceil_tex, "ceil", _face(Vector3(x0, y0 + height, z1), Vector3(x1, y0 + height, z1), Vector3(x1, y0 + height, z0), Vector3(x0, y0 + height, z0), Vector2(x0 / tile, z1 / tile), Vector2(x1 / tile, z1 / tile), Vector2(x1 / tile, z0 / tile), Vector2(x0 / tile, z0 / tile), Vector3.DOWN))
			if ch == "D" or ch == "O":
				doorways.append({"pos": origin + Vector3(cx, y0, cz), "cell": cell, "height": door_h, "map": String(opts.get("name", "Map"))})
			if ch == "D":
				# lintel: block above the door opening
				var ly0 := y0 + door_h
				var lq := Kit.box_quads(Vector3(cx, (ly0 + y0 + height) * 0.5, cz), Vector3(cell, y0 + height - ly0, cell), tile, [], Vector3.ZERO)
				for q in lq:
					add_quad.call("wall:" + wall_tex, wall_tex, "wall", q)
				shapes.append([Vector3(cx, (ly0 + y0 + height) * 0.5, cz), Vector3(cell, y0 + height - ly0, cell), Kit.surface_of(wall_tex)])
			if ch != "." and ch != "~" and ch != ":" and ch != "D" and ch != "O":
				if not markers.has(ch):
					markers[ch] = []
				markers[ch].append(origin + Vector3(cx, y0, cz))
			# edge walls beside void (thin, sitting just outside the floor edge).
			# Doorway cells only wall their sides (perpendicular to the way through).
			if not open_edges:
				var axis_ns := false
				if is_open.call(ch):
					axis_ns = is_floor.call(get.call(c, r - 1)) or is_floor.call(get.call(c, r + 1))
				for d in dirs:
					var nch: String = get.call(c + d.x, r + d.y)
					if is_open.call(ch):
						var perpendicular: bool = (d.y == 0) if axis_ns else (d.x == 0)
						if not perpendicular:
							continue
					if nch == " ":
						var q := _wall_face(x0 + d.x * cell, x1 + d.x * cell, z0 + d.y * cell, z1 + d.y * cell, y0, y0 + height, -d, tile)
						add_quad.call("wall:" + wall_tex, wall_tex, "wall", q)
						if double_thin:
							# outer face of the thin wall (0.3 m out, facing away from the room)
							var qo := _wall_face(x0 + d.x * 0.3, x1 + d.x * 0.3, z0 + d.y * 0.3, z1 + d.y * 0.3, y0, y0 + height, d, tile)
							add_quad.call("wall:" + wall_tex, wall_tex, "wall", qo)
						var wc := Vector3(cx + d.x * (cell * 0.5 + 0.15), y0 + height * 0.5, cz + d.y * (cell * 0.5 + 0.15))
						shapes.append([wc, Vector3(cell if d.x == 0 else 0.3, height, cell if d.y == 0 else 0.3), Kit.surface_of(wall_tex)])

	# commit meshes
	for key in buckets:
		var b: Dictionary = buckets[key]
		var mesh := Kit.mesh_from_quads(b.quads)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = Kit.mat(b.tex, mat_opts)
		mi.name = key.replace(":", "_").replace("/", "_")
		if opts.has("layer"):
			mi.layers = int(opts.layer)
		root.add_child(mi)
		if b.kind != "wall" and bool(opts.get("collision", true)):
			var body := StaticBody3D.new()
			body.collision_layer = int(opts.get("collision_layer", Kit.L_WORLD))
			body.collision_mask = 0
			body.set_meta("surface", Kit.surface_of(b.tex))
			var cs := CollisionShape3D.new()
			cs.shape = mesh.create_trimesh_shape()
			body.add_child(cs)
			mi.add_child(body)
	if bool(opts.get("collision", true)) and shapes.size() > 0:
		var wbody := StaticBody3D.new()
		wbody.name = "WallBodies"
		wbody.collision_layer = int(opts.get("collision_layer", Kit.L_WORLD))
		wbody.collision_mask = 0
		wbody.set_meta("surface", Kit.surface_of(wall_tex))
		for s in shapes:
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = s[1]
			cs.shape = bs
			cs.position = s[0]
			wbody.add_child(cs)
		root.add_child(wbody)
	for wc in water_cells:
		Kit.water(root, wc + Vector3(0, -0.15, 0), Vector2(cell, cell), water_tex, opts.get("water_opts", {}))

	var result := {
		"markers": markers, "cells": grid, "cell": cell, "origin": origin, "root": root,
		"size": Vector2i(w, h), "height": height, "y": y0,
	}
	result["center"] = func(col: int, row: int) -> Vector3:
		return origin + Vector3((col + 0.5) * cell, y0, (row + 0.5) * cell)
	result["first"] = func(ch: String) -> Vector3:
		var arr: Array = markers.get(ch, [])
		return arr[0] if arr.size() > 0 else origin
	return result


static func _face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, uvd: Vector2, n: Vector3) -> Array:
	return [a, b, c, d, uva, uvb, uvc, uvd, n]


## Face of the wall cell [x0,x1]x[z0,z1] that faces direction d (toward the neighbour).
static func _wall_face(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, d: Vector2i, tile: float) -> Array:
	var hgt := y1 - y0
	if d == Vector2i(0, -1):   # north face at z0, normal -Z
		return _face(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector2(-x1 / tile, hgt / tile), Vector2(-x0 / tile, hgt / tile), Vector2(-x0 / tile, 0), Vector2(-x1 / tile, 0), Vector3(0, 0, -1))
	if d == Vector2i(0, 1):    # south face at z1, normal +Z
		return _face(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector2(x0 / tile, hgt / tile), Vector2(x1 / tile, hgt / tile), Vector2(x1 / tile, 0), Vector2(x0 / tile, 0), Vector3(0, 0, 1))
	if d == Vector2i(1, 0):    # east face at x1, normal +X
		return _face(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector2(-z1 / tile, hgt / tile), Vector2(-z0 / tile, hgt / tile), Vector2(-z0 / tile, 0), Vector2(-z1 / tile, 0), Vector3(1, 0, 0))
	# west face at x0, normal -X
	return _face(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector2(z0 / tile, hgt / tile), Vector2(z1 / tile, hgt / tile), Vector2(z1 / tile, 0), Vector2(z0 / tile, 0), Vector3(-1, 0, 0))


static func _top_face(x0: float, x1: float, z0: float, z1: float, y: float, tile: float) -> Array:
	return _face(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector2(x0 / tile, z0 / tile), Vector2(x1 / tile, z0 / tile), Vector2(x1 / tile, z1 / tile), Vector2(x0 / tile, z1 / tile), Vector3.UP)


## Mirror a map horizontally (the Nowhere House on its second visit).
static func mirrored(rows: Array) -> Array:
	var out: Array = []
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	for r in rows:
		var s := String(r)
		while s.length() < w:
			s += " "
		out.append(s.reverse())
	return out
