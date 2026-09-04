class_name Interactable
extends Area3D
## Base class for anything the player can look at and press [E] on.
##
## An Interactable is an Area3D on physics layer 3 ("Interact") that the
## player's interaction ray can hit. Subclasses override `_on_interact()` or
## callers pass an `on_interact` Callable. Visual props are added as children.

@export var prompt := "Look"
@export var enabled := true
@export var one_shot := false
var used := false
var on_interact: Callable
## The glow kind ("" for none); derived from the subclass unless set.
var aura_kind := "auto"
var _aura_box: Array = []


func _init() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true


func prompt_text() -> String:
	return prompt


func can_focus() -> bool:
	return enabled and not (one_shot and used)


func interact(player: Node) -> void:
	if not can_focus():
		return
	used = true
	if on_interact.is_valid():
		on_interact.call(player, self)
	else:
		_on_interact(player)


func _on_interact(_player: Node) -> void:
	pass


## Add a box collision shape (what the interaction ray hits).
func add_box(size: Vector3, offset: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = offset
	add_child(cs)
	_aura_box = [size, offset]
	call_deferred("_ensure_aura")
	return cs


func _ensure_aura() -> void:
	if not is_inside_tree() or _aura_box.is_empty() or get_node_or_null("Aura") != null:
		return
	var kind := aura_kind
	if kind == "auto":
		var script: Script = get_script()
		var cls := String(script.get_global_name()).to_lower() if script else ""
		match cls:
			"readable": kind = "readable"
			"pickup": kind = "pickup"
			"door", "mirror", "bed": kind = "door"
			"npc": kind = "npc"
			"switch", "brazier": kind = "switch"
			_: kind = "generic"
		if "walk_through" in self and get("walk_through"):
			kind = ""
	if kind == "":
		return
	Aura.attach(self, _aura_box[0], _aura_box[1], kind)


## Quick interactable: a box you can look at that runs `cb.call(player, interactable)`.
static func make(parent: Node, pos: Vector3, size: Vector3, prompt_text_: String, cb: Callable, opts: Dictionary = {}) -> Interactable:
	var it := Interactable.new()
	it.prompt = prompt_text_
	it.on_interact = cb
	it.position = pos
	it.one_shot = bool(opts.get("one_shot", false))
	it.name = String(opts.get("name", "Interactable"))
	if opts.has("yaw"):
		it.rotation.y = deg_to_rad(float(opts.yaw))
	it.add_box(size, opts.get("offset", Vector3(0, size.y * 0.5, 0)))
	parent.add_child(it)
	if opts.has("model"):
		Props.place(it, String(opts.model), Vector3.ZERO, 0.0, float(opts.get("scale", 1.0)), {"collision": String(opts.get("collision", "box"))})
	return it
