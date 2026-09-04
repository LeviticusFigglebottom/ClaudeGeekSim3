extends Node
## Coplanar-surface audit: builds every area (and the visits that build
## differently), gathers every axis-aligned triangle of every mesh in world
## space, and reports pairs of triangles from different meshes that lie in the
## same plane, face the same way and overlap. Those are the surfaces that
## flicker against each other (z-fighting). Run with
##   godot --headless --path . res://tools/coplanar.tscn -- [--area=<id>] [--near=<m>]
## Exit status 1 when any coplanar overlap is found.

const EXTRA_VISITS := {"house": [2, 3], "kings_dream": [2, 3], "sea": [2], "castle": [2]}
const FIGHT := 0.012      # closer than this: the same plane
const CELL := 4.0
var near := 0.0           # also list pairs closer than this (0 = off)
var only := ""
var total_fights := 0
var total_near := 0
var total_same := 0


func _ready() -> void:
	print("[coplanar] start")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--area="):
			only = a.substr(7)
		elif a.begins_with("--near="):
			near = float(a.substr(7))
	World.quiet = true
	var holder := Node3D.new()
	holder.name = "AreaRoot"
	add_child(holder)
	World.area_root = holder
	for id in AreaRegistry.AREAS:
		if only != "" and id != only:
			continue
		if id == "workshop" and only == "":
			continue
		await _audit(holder, id, 1)
		for n in EXTRA_VISITS.get(id, []):
			await _audit(holder, id, int(n))
	print("[coplanar] %d coplanar overlaps, %d near misses, %d identical-looking overlaps ignored" % [total_fights, total_near, total_same])
	get_tree().quit(1 if total_fights > 0 else 0)


func _audit(holder: Node3D, id: String, visit: int) -> void:
	Game.visits[id] = visit - 1
	var info: Dictionary = AreaRegistry.AREAS[id]
	var ps := load(String(info.get("scene", ""))) as PackedScene
	if ps == null:
		return
	MapBuilder.reset_registry()
	Kit.reset_gaps()
	var area := ps.instantiate() as AreaBase
	holder.add_child(area)
	await get_tree().process_frame
	# every square of the dream is built; only the current one is shown
	for c in area.get_children():
		if c is Node3D and c.name.begins_with("Square"):
			c.visible = true
	var tag := id if visit == 1 else "%s (visit %d)" % [id, visit]
	print("[coplanar] built %s" % tag)
	var meshes: Array = []
	_collect(area, meshes)
	var t0 := Time.get_ticks_msec()
	var tris: Array = []      # [mesh index, axis, sign, coord, poly (PackedVector2Array), bbox Rect2]
	for mi in meshes.size():
		_triangles(meshes[mi], mi, tris)
	var t1 := Time.get_ticks_msec()
	var found := _pairs(tris, meshes, tag)
	print("[coplanar] %s: %d meshes, %d flat triangles, gathered in %d ms, paired in %d ms" % [tag, meshes.size(), tris.size(), t1 - t0, Time.get_ticks_msec() - t1])
	if found > 0:
		print("[coplanar] %s: %d overlapping mesh pairs" % [tag, found])
	holder.remove_child(area)
	area.free()


func _collect(node: Node, out: Array) -> void:
	# halos (Aura) float in front of what they mark; the workshop is the prop
	# gallery, not a place
	if node is MeshInstance3D and node.mesh != null and not (node is Aura):
		out.append(node)
	for c in node.get_children():
		_collect(c, out)


func _triangles(mi: MeshInstance3D, index: int, out: Array) -> void:
	var mesh: Mesh = mi.mesh
	var xf := mi.global_transform
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var n := idx.size() if idx.size() > 0 else verts.size()
		var i := 0
		while i + 2 < n:
			var ia: int = idx[i] if idx.size() > 0 else i
			var ib: int = idx[i + 1] if idx.size() > 0 else i + 1
			var ic: int = idx[i + 2] if idx.size() > 0 else i + 2
			var a := xf * verts[ia]
			var b := xf * verts[ib]
			var c := xf * verts[ic]
			var tuv := PackedVector2Array([uvs[ia], uvs[ib], uvs[ic]]) if uvs.size() > ic else PackedVector2Array()
			i += 3
			# front faces are wound clockwise as seen, so the right-hand normal
			# points away from the viewer: flip it to get the facing
			var nrm := (c - a).cross(b - a)
			var l := nrm.length()
			if l < 1e-6:
				continue
			nrm /= l
			var axis := -1
			for k in 3:
				if absf(nrm[k]) > 0.9995:
					axis = k
			if axis < 0:
				continue
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			var poly := PackedVector2Array([Vector2(a[u], a[v]), Vector2(b[u], b[v]), Vector2(c[u], c[v])])
			var r := Rect2(poly[0], Vector2.ZERO).expand(poly[1]).expand(poly[2])
			if r.size.x < 0.02 or r.size.y < 0.02:
				continue
			out.append([index, axis, 1 if nrm[axis] > 0 else -1, (a[axis] + b[axis] + c[axis]) / 3.0, poly, r, tuv])


func _pairs(tris: Array, meshes: Array, tag: String) -> int:
	# spatial hash per plane orientation: key = axis, sign, cell x, cell y
	var grid := {}
	for t in tris.size():
		var tri: Array = tris[t]
		var r: Rect2 = tri[5]
		var x0 := floori(r.position.x / CELL)
		var x1 := floori(r.end.x / CELL)
		var y0 := floori(r.position.y / CELL)
		var y1 := floori(r.end.y / CELL)
		if (x1 - x0 + 1) * (y1 - y0 + 1) > 4000:
			continue
		for gx in range(x0, x1 + 1):
			for gy in range(y0, y1 + 1):
				var key := Vector4i(tri[1] * 2 + (1 if tri[2] > 0 else 0), gx, gy, 0)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(t)
	var seen := {}
	var report := {}   # "a|b" -> {count, area, at, near}
	var limit := maxf(near, FIGHT)
	for key in grid:
		var bucket: Array = grid[key]
		bucket.sort_custom(func(p: int, q: int) -> bool: return tris[p][3] < tris[q][3])
		for i in bucket.size():
			var ti: Array = tris[bucket[i]]
			var j := i + 1
			while j < bucket.size():
				var tj: Array = tris[bucket[j]]
				var gap: float = tj[3] - ti[3]
				if gap > limit:
					break
				j += 1
				if ti[0] == tj[0]:
					continue
				if not meshes[ti[0]].is_visible_in_tree() or not meshes[tj[0]].is_visible_in_tree():
					continue
				var pk := Vector2i(mini(bucket[i], bucket[j - 1]), maxi(bucket[i], bucket[j - 1]))
				if seen.has(pk):
					continue
				seen[pk] = true
				var ri: Rect2 = ti[5]
				var rj: Rect2 = tj[5]
				var ov := ri.intersection(rj)
				if ov.size.x < 0.03 or ov.size.y < 0.03:
					continue
				var inter := Geometry2D.intersect_polygons(ti[4], tj[4])
				var area := 0.0
				for poly in inter:
					area += absf(_poly_area(poly))
				if area < 0.004:
					continue
				var a: int = mini(ti[0], tj[0])
				var b: int = maxi(ti[0], tj[0])
				if ti[1] == 1 and ti[2] < 0 and _rests_on(meshes[a], ti[3]) and _rests_on(meshes[b], ti[3]):
					# two things standing on the same ground: their undersides are never seen
					continue
				if meshes[a].name == "PaintedBoard" or meshes[b].name == "PaintedBoard":
					continue
				var rk := "%d|%d" % [a, b]
				if not report.has(rk):
					report[rk] = {"count": 0, "area": 0.0, "at": inter[0][0], "axis": ti[1], "coord": ti[3], "gap": gap, "near": gap > FIGHT, "same": true}
				var rep: Dictionary = report[rk]
				rep.count += 1
				rep.area += area
				rep.gap = minf(rep.gap, gap)
				rep.near = rep.near and gap > FIGHT
				# two faces that draw the very same picture (same texture, tint and
				# world-space uv) cannot be told apart when they flicker
				if rep.same and not _same_look(ti, tj, meshes[ti[0]], meshes[tj[0]], inter[0][0]):
					rep.same = false
				if rep.same == false and absf(_bias(meshes[ti[0]]) - _bias(meshes[tj[0]])) > 0.0001:
					# one is drawn nearer the eye than the other: settled
					rep.same = true
				if rep.get("shimmer", true) and _mat_key(meshes[ti[0]]) != _mat_key(meshes[tj[0]]):
					rep.shimmer = false
	var keys := report.keys()
	keys.sort_custom(func(p: String, q: String) -> bool: return report[p].area > report[q].area)
	var found := 0
	for k in keys:
		var rep: Dictionary = report[k]
		var ids: PackedStringArray = String(k).split("|")
		var ma: MeshInstance3D = meshes[int(ids[0])]
		var mb: MeshInstance3D = meshes[int(ids[1])]
		var axis_name: String = ["x", "y", "z"][int(rep.axis)]
		var where := Vector3.ZERO
		var ax: int = int(rep.axis)
		var u: int = (ax + 1) % 3
		var v: int = (ax + 2) % 3
		where[ax] = float(rep.coord)
		where[u] = float(rep.at.x)
		where[v] = float(rep.at.y)
		if rep.same:
			total_same += 1
			continue
		if rep.get("shimmer", false) and rep.area < 1.0:
			# the same texture twice, offset: a faint shimmer on a small patch
			total_same += 1
			continue
		if rep.near:
			total_near += 1
			print("[coplanar] NEAR %s: %s=%.3f (gap %.3f) at %s, %.2f m2: %s  ~  %s" % [tag, axis_name, rep.coord, rep.gap, _fmt(where), rep.area, _describe(ma), _describe(mb)])
		else:
			total_fights += 1
			found += 1
			print("[coplanar] %s %s: %s=%.3f at %s, %.2f m2: %s  ~  %s" % ["SHIMMER" if rep.get("shimmer", false) else "FIGHT", tag, axis_name, rep.coord, _fmt(where), rep.area, _describe(ma), _describe(mb)])
	return found


static func _uv_at(tri: Array, p: Vector2) -> Vector2:
	var poly: PackedVector2Array = tri[4]
	var uv: PackedVector2Array = tri[6]
	if uv.size() < 3:
		return Vector2(NAN, NAN)
	var v0 := poly[1] - poly[0]
	var v1 := poly[2] - poly[0]
	var v2 := p - poly[0]
	var den := v0.x * v1.y - v1.x * v0.y
	if absf(den) < 1e-9:
		return Vector2(NAN, NAN)
	var l1 := (v2.x * v1.y - v1.x * v2.y) / den
	var l2 := (v0.x * v2.y - v2.x * v0.y) / den
	return uv[0] + (uv[1] - uv[0]) * l1 + (uv[2] - uv[0]) * l2


static func _bias(mi: MeshInstance3D) -> float:
	var mat := mi.material_override
	if mat == null and mi.mesh.get_surface_count() > 0:
		mat = mi.mesh.surface_get_material(0)
	if mat is ShaderMaterial:
		var b = mat.get_shader_parameter("depth_bias")
		return float(b) if b != null else 0.0
	return 0.0


static func _mat_key(mi: MeshInstance3D) -> String:
	var mat := mi.material_override
	if mat == null and mi.mesh.get_surface_count() > 0:
		mat = mi.mesh.surface_get_material(0)
	if mat is ShaderMaterial:
		var t = mat.get_shader_parameter("albedo_tex")
		var tp: String = t.resource_path if t is Texture2D else "none"
		return "%s|%s|%s|%s|%s|%s" % [mat.shader.resource_path, tp, mat.get_shader_parameter("tint"), mat.get_shader_parameter("uv_scale"), mat.get_shader_parameter("uv_offset"), mat.get_shader_parameter("emission")]
	return "other:%d" % (mat.get_instance_id() if mat != null else 0)


static func _same_look(ti: Array, tj: Array, ma: MeshInstance3D, mb: MeshInstance3D, p: Vector2) -> bool:
	if _mat_key(ma) != _mat_key(mb):
		return false
	var ua := _uv_at(ti, p)
	var ub := _uv_at(tj, p)
	if is_nan(ua.x) or is_nan(ub.x):
		return false
	return ua.distance_to(ub) < 0.002


static func _rests_on(mi: MeshInstance3D, y: float) -> bool:
	var aabb := mi.global_transform * mi.mesh.get_aabb()
	return aabb.size.y > 0.02 and absf(aabb.position.y - y) < 0.02


static func _poly_area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


static func _fmt(v: Vector3) -> String:
	return "(%.1f, %.2f, %.1f)" % [v.x, v.y, v.z]


static func _describe(mi: MeshInstance3D) -> String:
	var tex := ""
	var mat := mi.material_override
	if mat == null and mi.mesh.get_surface_count() > 0:
		mat = mi.mesh.surface_get_material(0)
	if mat is StandardMaterial3D and mat.albedo_texture != null:
		tex = mat.albedo_texture.resource_path.get_file().get_basename()
	elif mat is ShaderMaterial:
		var t = mat.get_shader_parameter("albedo_tex")
		tex = t.resource_path.get_file().get_basename() if t is Texture2D else "shader"
	elif mat != null:
		tex = "vertex"
	var aabb := mi.global_transform * mi.mesh.get_aabb()
	var path := String(mi.get_path())
	var parts := path.split("/")
	var short := "/".join(parts.slice(maxi(0, parts.size() - 3)))
	var hidden := "" if mi.is_visible_in_tree() else " (hidden)"
	return "%s[%s]%s aabb %s..%s" % [short, tex, hidden, _fmt(aabb.position), _fmt(aabb.end)]
