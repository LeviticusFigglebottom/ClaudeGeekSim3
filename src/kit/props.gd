class_name Props
## Places generated GLB props (assets/models, from tools/gen_assets/models.py)
## and restyles their materials through the Kit so everything shares one look.
##
## Material name conventions baked into the GLBs:
##   "tex:<group>/<name>[:double]"  textured (vertex colour multiplies)
##   "glow:#rrggbb"                 unshaded, emissive
##   anything else                  lit vertex colour

const MODEL_ROOT := "res://assets/models/"
static var _cache: Dictionary = {}
static var _missing: Dictionary = {}


static func exists(model: String) -> bool:
	return ResourceLoader.exists(MODEL_ROOT + model + ".glb")


static func scene(model: String) -> PackedScene:
	if _cache.has(model):
		return _cache[model]
	var path := MODEL_ROOT + model + ".glb"
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path)
	_cache[model] = ps
	return ps


## Place a prop. opts: collision ("box"|"trimesh"|"cylinder"|"none"), name, tint (Color),
## layer (visual layers), collision_layer, surface, emission_energy, unshaded (bool), random_yaw (bool, needs rng)
static func place(parent: Node, model: String, pos: Vector3, yaw_deg: float = 0.0, scale: float = 1.0, opts: Dictionary = {}) -> Node3D:
	var ps := scene(model)
	var inst: Node3D
	if ps == null:
		if not _missing.has(model):
			_missing[model] = true
			push_warning("Props: missing model '%s'" % model)
		inst = _placeholder()
	else:
		inst = ps.instantiate()
	inst.name = String(opts.get("name", model))
	inst.position = pos
	inst.rotation.y = deg_to_rad(yaw_deg)
	if opts.has("rotation"):
		inst.rotation_degrees = opts.rotation
	inst.scale = Vector3.ONE * scale if not opts.has("scale3") else opts.scale3
	stylize(inst, opts)
	parent.add_child(inst)
	var col := String(opts.get("collision", "box"))
	if col != "none" and ps != null:
		add_collision(inst, col, opts)
	if opts.has("layer"):
		set_layers(inst, int(opts.layer))
	inst.set_meta("model", model)
	return inst


static func _placeholder() -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = Kit.flat(Color.MAGENTA, {"unshaded": true})
	mi.position.y = 0.5
	var n := Node3D.new()
	n.add_child(mi)
	return n


static func set_layers(node: Node, layers: int) -> void:
	for mi in _meshes(node):
		mi.layers = layers


static func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out


## Replace imported materials with Kit materials according to their names.
static func stylize(node: Node, opts: Dictionary = {}) -> void:
	var tint: Color = opts.get("tint", Color.WHITE)
	for mi in _meshes(node):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var src := m.get_active_material(s)
			var mname := src.resource_name if src != null else ""
			var mo := {"vertex_color": true}
			if tint != Color.WHITE:
				mo["tint"] = tint
			if opts.get("unshaded", false):
				mo["unshaded"] = true
			var mat: Material
			if mname.begins_with("tex:"):
				var texn := mname.substr(4)
				if texn.ends_with(":double"):
					texn = texn.trim_suffix(":double")
					mo["double"] = true
				if src is BaseMaterial3D and (src as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED:
					mo["double"] = true
				mat = Kit.mat(texn, mo)
			elif mname.begins_with("glow:"):
				var col := Color(mname.substr(5))
				mo["unshaded"] = true
				mo["emission"] = col
				mo["emission_energy"] = float(opts.get("emission_energy", 0.6))
				mat = Kit.flat(col * tint, mo)
			else:
				mat = Kit.mat("", mo)
			m.set_surface_override_material(s, mat)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if opts.get("cast_shadow", true) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Local-space bounds of all meshes under a prop instance.
static func bounds(inst: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	for mi in _meshes(inst):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var local: Transform3D = inst.global_transform.affine_inverse() * m.global_transform if inst.is_inside_tree() else _relative(inst, m)
		var b: AABB = local * m.mesh.get_aabb()
		if first:
			aabb = b
			first = false
		else:
			aabb = aabb.merge(b)
	return aabb


static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func add_collision(inst: Node3D, kind: String, opts: Dictionary = {}) -> void:
	var layer := int(opts.get("collision_layer", Kit.L_WORLD))
	var surface := String(opts.get("surface", "wood"))
	if kind == "trimesh":
		for mi in _meshes(inst):
			var m: MeshInstance3D = mi
			if m.mesh == null:
				continue
			var body := StaticBody3D.new()
			body.collision_layer = layer
			body.collision_mask = 0
			body.set_meta("surface", surface)
			var cs := CollisionShape3D.new()
			cs.shape = m.mesh.create_trimesh_shape()
			body.add_child(cs)
			m.add_child(body)
		return
	var b := bounds(inst)
	if b.size.length() < 0.001:
		return
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.set_meta("surface", surface)
	var cs := CollisionShape3D.new()
	if kind == "cylinder":
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf(b.size.x, b.size.z) * 0.5 * float(opts.get("collision_scale", 1.0))
		cyl.height = b.size.y
		cs.shape = cyl
	else:
		var bs := BoxShape3D.new()
		bs.size = b.size * float(opts.get("collision_scale", 1.0))
		cs.shape = bs
	cs.position = b.get_center()
	body.add_child(cs)
	inst.add_child(body)


## Find a named child (e.g. the "Leaf" of a door) inside a placed prop.
static func part(inst: Node, part_name: String) -> Node3D:
	var n := inst.find_child(part_name, true, false)
	return n as Node3D
