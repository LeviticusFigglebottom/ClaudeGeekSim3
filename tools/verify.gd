extends Node
## Headless verification for ANTEROOM. Runs as a scene so the autoloads exist:
##
##   godot --headless --path . res://tools/verify.tscn
##
## 1. Loads every GDScript in src/ and tools/ (parse errors fail the run).
## 2. Checks the area registry: every scene exists and instantiates.
## 3. Builds every area and collects Doors, Pickups, Puzzles, Beds, Mirrors and
##    spawn points, then checks that every door leads to a real area and spawn.
## 4. Solves the world graph: starting from the first sleep with nothing, can
##    the dreamer reach every (non-hidden) area and every keepsake?
## 5. Round-trips a save file.
## Exit code 1 on any failure. `--verbose` prints the graph.

var failures: Array = []
var warnings: Array = []
var verbose := false
var graph: Dictionary = {}


func _ready() -> void:
	verbose = "--verbose" in OS.get_cmdline_user_args()
	print("== ANTEROOM headless verification ==")
	_check_scripts()
	await _check_registry_and_build()
	_check_graph_targets()
	_solve_routes()
	_check_save_roundtrip()
	_report()


func fail(msg: String) -> void:
	failures.append(msg)
	printerr("FAIL: " + msg)


func warn(msg: String) -> void:
	warnings.append(msg)
	print("warn: " + msg)


func ok(msg: String) -> void:
	print("  ok  " + msg)


# --- 1. scripts --------------------------------------------------------------

func _list_files(dir: String, ext: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir.path_join(f)
		if d.current_is_dir():
			if not f.begins_with("."):
				_list_files(p, ext, out)
		elif f.ends_with(ext):
			out.append(p)
		f = d.get_next()
	d.list_dir_end()


func _check_scripts() -> void:
	var scripts: Array = []
	_list_files("res://src", ".gd", scripts)
	_list_files("res://tools", ".gd", scripts)
	var n := 0
	for s in scripts:
		var res := load(s)
		if res == null or not (res is GDScript):
			fail("script failed to load: " + s)
			continue
		var gs: GDScript = res
		if not gs.can_instantiate() and not gs.is_abstract():
			# scripts extending SceneTree etc. still report can_instantiate true; a false here means compile errors
			fail("script does not compile: " + s)
			continue
		n += 1
	ok("%d scripts compile" % n)
	var shaders: Array = []
	_list_files("res://src/shaders", ".gdshader", shaders)
	for sh in shaders:
		var r := load(sh)
		if r == null:
			fail("shader failed to load: " + sh)
	ok("%d shaders load" % shaders.size())


# --- 2/3. registry & area builds ---------------------------------------------

func _check_registry_and_build() -> void:
	World.quiet = true
	var holder := Node3D.new()
	holder.name = "AreaRoot"
	add_child(holder)
	World.area_root = holder
	for id in AreaRegistry.AREAS:
		var info: Dictionary = AreaRegistry.AREAS[id]
		var path := String(info.get("scene", ""))
		if not ResourceLoader.exists(path):
			fail("area '%s': scene missing: %s" % [id, path])
			continue
		var ps := load(path) as PackedScene
		if ps == null:
			fail("area '%s': scene does not load" % id)
			continue
		var t0 := Time.get_ticks_msec()
		var inst := ps.instantiate()
		if not (inst is AreaBase):
			fail("area '%s': root is not an AreaBase" % id)
			inst.free()
			continue
		MapBuilder.reset_registry()
		Kit.reset_gaps()
		holder.add_child(inst)
		var area: AreaBase = inst
		var entry := {"spawns": area.spawns.keys(), "doors": [], "pickups": [], "puzzles": [], "readables": 0, "npcs": 0, "hidden": bool(info.get("hidden", false)), "can_wake": area.can_wake}
		_collect(area, entry)
		graph[id] = entry
		if not area.spawns.has("default"):
			fail("area '%s' has no 'default' spawn" % id)
		var dt := Time.get_ticks_msec() - t0
		ok("area %-12s built in %4d ms: %2d spawns, %2d doors, %2d pickups, %2d puzzles, %2d readables, %2d npcs" % [id, dt, entry.spawns.size(), entry.doors.size(), entry.pickups.size(), entry.puzzles.size(), entry.readables, entry.npcs])
		# let the physics server register the geometry, then probe it
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check_physics(id, area)
		holder.remove_child(area)
		area.free()


## Physical sanity: every spawn point must fit a standing player, must have
## ground under it, and every doorway cell must be free of solid obstacles.
func _check_physics(id: String, area: AreaBase) -> void:
	var space := area.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = capsule
	q.collision_mask = 1 | 16 | 256
	for sid in area.spawns:
		var t: Transform3D = area.spawns[sid]
		q.transform = Transform3D(Basis(), t.origin + Vector3(0, 0.95, 0))
		var hits := space.intersect_shape(q, 4)
		if hits.size() > 0:
			var names: Array = []
			for h in hits:
				names.append(_describe(h.collider))
			fail("area '%s' spawn '%s' at %s is inside solid geometry: %s" % [id, sid, t.origin, names])
		var ray := PhysicsRayQueryParameters3D.create(t.origin + Vector3(0, 0.5, 0), t.origin + Vector3(0, -3.0, 0), 1 | 16 | 256 | 512)
		if space.intersect_ray(ray).is_empty():
			fail("area '%s' spawn '%s' at %s has no ground within 3 m below it" % [id, sid, t.origin])
	# a seam that already contains a spawn point fires the moment the player lands
	for seam in area.find_children("*", "SeamlessTeleport", true, false):
		for sid in area.spawns:
			var t: Transform3D = area.spawns[sid]
			if seam.call("_contains", t.origin + Vector3(0, 0.9, 0)):
				fail("area '%s' seam '%s' overlaps spawn '%s' at %s (check the seam's local size: x across, z depth)" % [id, seam.name, sid, t.origin])
	var box := BoxShape3D.new()
	var blocked := 0
	for dw in MapBuilder.doorways:
		var cell: float = dw.cell
		box.size = Vector3(cell * 0.5, 1.6, cell * 0.5)
		var bq := PhysicsShapeQueryParameters3D.new()
		bq.shape = box
		bq.collision_mask = 1
		bq.transform = Transform3D(Basis(), dw.pos + Vector3(0, 0.3 + 0.75, 0))
		var hits := space.intersect_shape(bq, 6)
		var solid: Array = []
		for h in hits:
			var c: Object = h.collider
			# the map's own lintel and floor sit above/below the probe; a Door's own
			# blocker is the door itself; anything else is an obstacle
			if c is StaticBody3D and (c as Node).name == "WallBodies":
				continue
			if _under_door(c as Node):
				continue
			solid.append(_describe(c))
		if solid.size() > 0:
			blocked += 1
			fail("area '%s' doorway at %s (%s) is blocked by %s" % [id, dw.pos, dw.map, solid])
	if blocked == 0:
		ok("area %-12s %d doorways clear, %d spawns probed" % [id, MapBuilder.doorways.size(), area.spawns.size()])
	_check_mouse_gaps(id, space)


## A mouse-hole is only a hole if the small player fits through it and lands on
## something. Player.SMALL_HEIGHT is 0.5 and SMALL_RADIUS 0.14, so we sweep a
## slightly smaller capsule from the mouth to `depth` metres beyond it.
func _check_mouse_gaps(id: String, space: PhysicsDirectSpaceState3D) -> void:
	if Kit.mouse_gaps.is_empty():
		return
	var cap := CapsuleShape3D.new()
	cap.height = 0.5
	cap.radius = 0.13
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1 | 256          # world, but NOT big-only (16)
	var clear := 0
	for g in Kit.mouse_gaps:
		var pos: Vector3 = g.pos
		var fwd: Vector3 = Basis(Vector3.UP, deg_to_rad(float(g.yaw))) * Vector3(0, 0, -1)
		var depth: float = float(g.depth)
		var stuck: Array = []
		var no_floor: Array = []
		var steps := 12
		for i in range(-1, steps + 1):
			# march both ways: the crawl may run behind the mouth or in front of it
			for sgn in [1.0, -1.0]:
				var p: Vector3 = pos + fwd * (sgn * depth * float(i) / float(steps))
				if i < 0:
					p = pos
				q.transform = Transform3D(Basis(), p + Vector3(0, 0.26, 0))
				if space.intersect_shape(q, 1).size() > 0:
					stuck.append([sgn, p])
				var ray := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.3, 0), p + Vector3(0, -1.5, 0), 1 | 256 | 512)
				if space.intersect_ray(ray).is_empty():
					no_floor.append([sgn, p])
				if i < 0:
					break
		# at least one of the two directions has to be walkable end to end
		var bad_fwd := 0
		var bad_back := 0
		for e in stuck + no_floor:
			if float(e[0]) > 0.0:
				bad_fwd += 1
			else:
				bad_back += 1
		if bad_fwd > 0 and bad_back > 0:
			fail("area '%s' mouse-hole at %s has no crawlable side: %d blocked ahead, %d behind (the small player is 0.5 m tall)" % [id, pos, bad_fwd, bad_back])
		else:
			clear += 1
	if clear == Kit.mouse_gaps.size():
		ok("area %-12s %d mouse-hole(s) crawlable at small size" % [id, clear])


static func _under_door(n: Node) -> bool:
	var p := n
	while p != null and not (p is AreaBase):
		if p is Door:
			return true
		p = p.get_parent()
	return false


static func _describe(o: Object) -> String:
	var n := o as Node
	if n == null:
		return str(o)
	var path := n.name
	var parent := n.get_parent()
	var depth := 0
	while parent != null and depth < 3 and not (parent is AreaBase):
		path = parent.name + "/" + path
		parent = parent.get_parent()
		depth += 1
	return path


func _collect(node: Node, entry: Dictionary) -> void:
	if node is Door:
		var d: Door = node
		var targets: Array = []
		if d.unstable.is_valid():
			targets = d.possible_targets.duplicate()
			if targets.is_empty():
				warn("unstable door '%s' lists no possible_targets" % d.name)
		elif d.target_area != "":
			targets = [[d.target_area, d.target_spawn]]
		entry.doors.append({"name": d.name, "targets": targets, "req": _reqs(d.requires_keepsake, d.requires_item, d.requires_flag), "sets_flag": d.sets_flag, "forbids": d.forbids_flag})
	elif node is Bed:
		var b: Bed = node
		if b.target_area != "":
			entry.doors.append({"name": b.name, "targets": [[b.target_area, b.target_spawn]], "req": [], "sets_flag": "", "forbids": ""})
	elif node is Mirror:
		var m: Mirror = node
		if m.target_area != "":
			entry.doors.append({"name": m.name, "targets": [[m.target_area, m.target_spawn]], "req": ["keepsake:shard"], "sets_flag": "", "forbids": ""})
	elif node is Pickup:
		var p: Pickup = node
		entry.pickups.append({"name": p.name, "keepsake": p.keepsake, "item": p.item, "req": _reqs(p.requires_keepsake, p.requires_item, p.requires_flag)})
	elif node is Puzzle:
		var z: Puzzle = node
		entry.puzzles.append({"id": z.id, "sets_flag": z.sets_flag, "req": z.requires.duplicate(), "grants_item": z.grants_item, "grants_keepsake": z.grants_keepsake})
		if z.grants_route != "":
			var parts := z.grants_route.split(":")
			if parts.size() == 2:
				entry.doors.append({"name": "Puzzle_" + z.id, "targets": [[parts[0], parts[1]]], "req": z.requires.duplicate(), "sets_flag": "", "forbids": ""})
			else:
				fail("puzzle '%s' grants_route '%s' is not area:spawn" % [z.id, z.grants_route])
	elif node is Readable:
		entry.readables += 1
		var r: Readable = node
		if r.flag_on_read != "":
			entry.puzzles.append({"id": "read_" + r.name, "sets_flag": r.flag_on_read, "req": [], "grants_item": "", "grants_keepsake": ""})
	elif node is NPC:
		entry.npcs += 1
	for c in node.get_children():
		_collect(c, entry)


func _reqs(k: String, i: String, f: String) -> Array:
	var out: Array = []
	if k != "":
		out.append("keepsake:" + k)
	if i != "":
		out.append("item:" + i)
	if f != "":
		out.append("flag:" + f)
	return out


func _check_graph_targets() -> void:
	var bad := 0
	for id in graph:
		for d in graph[id].doors:
			for t in d.targets:
				var ta := String(t[0])
				var ts := String(t[1])
				if not graph.has(ta):
					fail("area '%s' door '%s' -> unknown area '%s'" % [id, d.name, ta])
					bad += 1
				elif not (ts in graph[ta].spawns):
					fail("area '%s' door '%s' -> area '%s' has no spawn '%s' (has %s)" % [id, d.name, ta, ts, graph[ta].spawns])
					bad += 1
	if bad == 0:
		ok("every door leads to an existing area and spawn")


# --- 4. route solver ----------------------------------------------------------

func _solve_routes() -> void:
	# falling out of any dream lands in the Static, so it is always reachable
	var reachable := {AreaRegistry.STARTING_AREA: true, "static": true}
	# axioms: waking is always possible from a dream (sets has_woken); every
	# reachable area sets visited_<id> when entered.
	var have := {"flag:has_woken": "axiom"}
	var changed := true
	var steps := 0
	while changed and steps < 200:
		changed = false
		steps += 1
		for id in reachable.keys():
			if not have.has("flag:visited_" + id):
				have["flag:visited_" + id] = id
				changed = true
		for id in reachable.keys():
			var e: Dictionary = graph.get(id, {})
			if e.is_empty():
				continue
			for p in e.pickups:
				if _met(p.req, have):
					var key: String = ("keepsake:" + String(p.keepsake)) if String(p.keepsake) != "" else ("item:" + String(p.item))
					if not have.has(key):
						have[key] = id
						changed = true
			for z in e.puzzles:
				if _met(z.req, have):
					if z.sets_flag != "" and not have.has("flag:" + z.sets_flag):
						have["flag:" + z.sets_flag] = id
						changed = true
					if z.grants_item != "" and not have.has("item:" + z.grants_item):
						have["item:" + z.grants_item] = id
						changed = true
					if z.grants_keepsake != "" and not have.has("keepsake:" + z.grants_keepsake):
						have["keepsake:" + z.grants_keepsake] = id
						changed = true
			for d in e.doors:
				if not _met(d.req, have):
					continue
				if d.sets_flag != "" and not have.has("flag:" + d.sets_flag):
					have["flag:" + d.sets_flag] = id
					changed = true
				for t in d.targets:
					var ta := String(t[0])
					if graph.has(ta) and not reachable.has(ta):
						reachable[ta] = true
						changed = true
	# waking always returns to the flat
	for id in graph:
		if graph[id].hidden:
			continue
		if not reachable.has(id):
			fail("area '%s' is unreachable from the first sleep" % id)
	for k in Game.KEEPSAKES:
		if not have.has("keepsake:" + k):
			fail("keepsake '%s' cannot be obtained on any route" % k)
	if verbose:
		print("reachable: ", reachable.keys())
		print("obtained: ", have)
	var n_keep := 0
	for k in have:
		if String(k).begins_with("keepsake:"):
			n_keep += 1
	ok("route solver: %d/%d areas reachable, %d/%d keepsakes obtainable, %d items/flags" % [reachable.size(), graph.size(), n_keep, Game.KEEPSAKES.size(), have.size() - n_keep])


func _met(reqs: Array, have: Dictionary) -> bool:
	for r in reqs:
		if not have.has(String(r)):
			return false
	return true


# --- 5. save round trip -------------------------------------------------------

func _check_save_roundtrip() -> void:
	Game.new_game()
	Game.set_flag("test_flag", 3)
	Game.gain_keepsake("bell")
	Game.gain_item("coin", 2)
	Game.visit("forest")
	Game.note("t", "Test", "Body")
	var snapshot := Game.serialize()
	Game.new_game()
	Game.deserialize(snapshot)
	var good := Game.count("test_flag") == 3 and Game.has_keepsake("bell") and Game.item_count("coin") == 2 and Game.visits_to("forest") == 1 and Game.has_note("t")
	if not good:
		fail("save/load round trip lost data")
	else:
		ok("save round trip")
	var path := "user://verify_tmp_save.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(snapshot))
	f.close()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or int(parsed.get("version", -1)) != Game.SAVE_VERSION:
		fail("save file JSON invalid")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- report ------------------------------------------------------------------

func _report() -> void:
	print("== %d failures, %d warnings ==" % [failures.size(), warnings.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)
