class_name Aura
extends MeshInstance3D
## The glow on things you can use: readables, pickups, doors, people, switches,
## things the knife can cut. Faint, breathing, and each at its own tempo and
## tint, so a room full of them does not pulse in step. Brighter under the
## crosshair. Its overall opacity is the "glow on things you can use" setting.
##
## Attached automatically by Interactable.add_box and Cuttable.create.

const KINDS := {
	"readable": {"color": Color(0.95, 0.86, 0.6), "strength": 1.0},
	"pickup": {"color": Color(1.0, 0.95, 0.8), "strength": 0.75},
	"door": {"color": Color(0.62, 0.72, 1.0), "strength": 0.45},
	"npc": {"color": Color(0.95, 0.72, 0.76), "strength": 0.55},
	"switch": {"color": Color(1.0, 0.78, 0.45), "strength": 0.9},
	"cuttable": {"color": Color(1.0, 0.58, 0.5), "strength": 0.7},
	"generic": {"color": Color(0.9, 0.85, 0.7), "strength": 0.8},
}

static var _shader: Shader = null

var target: Node3D = null
var _mat: ShaderMaterial = null
var _t := 0.0


static func attach(target_: Node3D, size: Vector3, offset: Vector3, kind: String = "generic") -> Aura:
	if target_ == null or target_.get_node_or_null("Aura") != null:
		return null
	if _shader == null:
		_shader = load("res://src/shaders/aura.gdshader")
	var spec: Dictionary = KINDS.get(kind, KINDS["generic"])
	# unique to the object: its name and where it stands seed tempo, phase and tint
	var seed_v: int = absi(hash(target_.name + str(target_.position.round())))
	var a := Aura.new()
	a.name = "Aura"
	a.target = target_
	var q := QuadMesh.new()
	q.size = Vector2(maxf(size.x, size.z) * 1.15 + 0.25, size.y * 1.1 + 0.25)
	a.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _shader
	var c: Color = spec["color"]
	c = c.lerp(Color(0.65, 0.9, 1.0), float(seed_v % 17) / 17.0 * 0.22)
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("strength", float(spec["strength"]))
	m.set_shader_parameter("phase", float(seed_v % 628) / 100.0)
	m.set_shader_parameter("speed", 0.6 + float((seed_v / 628) % 100) / 100.0 * 1.0)
	m.render_priority = 10
	a.material_override = m
	a._mat = m
	a.position = offset
	a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target_.add_child(a)
	return a


func _ready() -> void:
	if Game.player and Game.player.has_signal("focus_changed"):
		Game.player.focus_changed.connect(_on_focus)
	# things that only exist under a keepsake (mirror-only, lantern-only) glow on their layer
	call_deferred("_match_layers")


func _match_layers() -> void:
	var vi := _find_visual(target)
	if vi != null:
		layers = vi.layers


func _find_visual(n: Node) -> VisualInstance3D:
	for c in n.get_children():
		if c == self:
			continue
		if c is VisualInstance3D:
			return c
		var deeper := _find_visual(c)
		if deeper != null:
			return deeper
	return null


func _on_focus(t: Node) -> void:
	if _mat:
		_mat.set_shader_parameter("focus", 1.0 if t == target else 0.0)


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.4:
		return
	_t = 0.0
	if not is_instance_valid(target):
		queue_free()
		return
	var on := true
	if target.has_method("can_focus"):
		on = bool(target.call("can_focus"))
	visible = on
