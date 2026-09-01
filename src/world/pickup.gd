class_name Pickup
extends Interactable
## Something to take: a keepsake or a key item. Spins, glows, disappears when
## taken, and never comes back (unless `once` is false).
##
## `requires_keepsake` / `requires_flag` are hints for the route verifier: they
## describe what the player must have to physically reach this pickup (a ledge
## that needs the Moth Wings), not a lock on the pickup itself.

@export var keepsake := ""
@export var item := ""
@export var count := 1
@export var once := true
@export var requires_keepsake := ""
@export var requires_item := ""
@export var requires_flag := ""
@export var key := ""
@export var model := ""
@export var glow := Color(1, 0.9, 0.6)
var visual: Node3D = null
var _t := 0.0


func _ready() -> void:
	if key == "":
		key = "picked_%s_%s" % [keepsake if keepsake != "" else item, name]
	if once and (Game.has_flag(key) or (keepsake != "" and Game.has_keepsake(keepsake))):
		queue_free()
		return
	var m := model
	if m == "":
		m = "item_" + (keepsake if keepsake != "" else item)
	if Props.exists(m):
		visual = Props.place(self, m, Vector3(0, 0.25, 0), 0.0, 1.0, {"collision": "none", "emission_energy": 0.8})
	else:
		visual = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		(visual as MeshInstance3D).mesh = sm
		(visual as MeshInstance3D).material_override = Kit.flat(glow, {"unshaded": true})
		visual.position.y = 0.45
		add_child(visual)
	var col := glow
	if keepsake != "" and Game.KEEPSAKES.has(keepsake):
		col = Game.KEEPSAKES[keepsake].color
	Kit.light(self, Vector3(0, 0.9, 0), col, 0.9, 3.5)
	add_box(Vector3(0.9, 1.2, 0.9), Vector3(0, 0.6, 0))
	if prompt == "Look":
		prompt = "Take " + (Game.keepsake_name(keepsake) if keepsake != "" else Game.item_name(item))
	set_process(true)


func _process(delta: float) -> void:
	if visual == null:
		return
	_t += delta
	visual.rotation.y += delta * 1.2
	visual.position.y = 0.25 + sin(_t * 2.0) * 0.06


func _on_interact(_player: Node) -> void:
	if keepsake != "":
		Game.gain_keepsake(keepsake)
		Audio.sfx("pickup", null, -2.0)
	else:
		Game.gain_item(item, count)
		Audio.sfx("pickup_item", null, -4.0)
	Game.set_flag(key, true)
	queue_free()


## opts: keepsake | item, count, key, model, requires_keepsake, requires_item, requires_flag, name, prompt, once
static func create(parent: Node, pos: Vector3, opts: Dictionary) -> Pickup:
	var p := Pickup.new()
	p.position = pos
	p.name = String(opts.get("name", "Pickup_" + String(opts.get("keepsake", opts.get("item", "thing")))))
	for k in ["keepsake", "item", "count", "key", "model", "requires_keepsake", "requires_item", "requires_flag", "prompt", "once"]:
		if opts.has(k):
			p.set(k, opts[k])
	parent.add_child(p)
	return p
