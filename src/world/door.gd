class_name Door
extends Interactable
## A door (or archway, or hole) that takes the player to another area.
##
## Doors can require a keepsake, an item or a flag; they can be walk-through
## (no prompt), and they can be *unstable*: the target is decided when you open
## them (the tavern's back door goes somewhere different every time). Unstable
## doors list their `possible_targets` so the world-graph verifier can see them.

@export var target_area := ""
@export var target_spawn := "default"
@export var requires_keepsake := ""
@export var requires_item := ""
@export var requires_flag := ""
@export var forbids_flag := ""
@export var locked_text := "It will not open."
@export var consume_item := false
## Visual: wood | white | dark | red | iron | big | none
@export var kind := "wood"
@export var walk_through := false
@export var label := ""
@export var fade_color := Color.BLACK
@export var fade_duration := 0.7
@export var sound := "door_open"
@export var sets_flag := ""
var unstable: Callable
var possible_targets: Array = []
var leaf: Node3D = null
var blocker: StaticBody3D = null
var on_open: Callable


func _ready() -> void:
	if kind != "none":
		var model := "door_" + kind
		if Props.exists(model):
			var p := Props.place(self, model, Vector3.ZERO, 0.0, 1.0, {"collision": "none"})
			leaf = Props.part(p, "Leaf")
	if not walk_through:
		var w := 1.6 if kind == "big" else 1.0
		var h := 3.2 if kind == "big" else 2.2
		if kind != "none":
			blocker = Kit.blocker(self, Vector3(0, h * 0.5, 0), Vector3(w, h, 0.12), Kit.L_WORLD, "wood")
		add_box(Vector3(w + 0.4, h + 0.2, 0.9), Vector3(0, h * 0.5, 0))
	else:
		monitoring = true
		collision_mask = 2
		add_box(Vector3(1.6, 2.4, 1.0), Vector3(0, 1.2, 0))
		body_entered.connect(_on_body_entered)
	if prompt == "Look":
		prompt = "Open the door"


func prompt_text() -> String:
	if label != "":
		return label
	return prompt


func can_focus() -> bool:
	return enabled and not walk_through


func requirements_met() -> bool:
	if not unstable.is_valid() and target_area != "" and not World.is_open(target_area):
		return false
	if requires_keepsake != "" and not Game.has_keepsake(requires_keepsake):
		return false
	if requires_item != "" and not Game.has_item(requires_item):
		return false
	if requires_flag != "" and not Game.has_flag(requires_flag):
		return false
	if forbids_flag != "" and Game.has_flag(forbids_flag):
		return false
	return true


func resolve_target() -> Array:
	if unstable.is_valid():
		var t = unstable.call()
		if t is Array and t.size() >= 2:
			return t
		return []
	if target_area == "":
		return []
	return [target_area, target_spawn]


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not World.traveling and requirements_met():
		go(body)


func _on_interact(player: Node) -> void:
	if not requirements_met():
		if not unstable.is_valid() and target_area != "" and not World.is_open(target_area):
			Game.toast.emit("The door is painted on. Whatever is behind it has not been dreamt yet.")
		else:
			Game.toast.emit(locked_text)
		Audio.sfx("door_locked", global_position, -6.0)
		return
	go(player)


func go(_player: Node) -> void:
	if World.traveling:
		return
	var target := resolve_target()
	if target.is_empty():
		Game.toast.emit("It opens onto a wall.")
		Audio.sfx("door_locked", global_position, -6.0)
		return
	if consume_item and requires_item != "":
		Game.take_item(requires_item)
	if sets_flag != "":
		Game.set_flag(sets_flag, true)
	Game.stats.doors += 1
	Audio.sfx(sound, global_position, -4.0)
	if leaf != null:
		var tw := create_tween()
		tw.tween_property(leaf, "rotation:y", deg_to_rad(-105.0), 0.45).set_ease(Tween.EASE_OUT)
	if on_open.is_valid():
		on_open.call(self)
	World.travel(String(target[0]), String(target[1]), {"color": fade_color, "duration": fade_duration})


## Build a door. yaw: the direction the door faces (0 = -Z).
## opts: kind, label, requires_keepsake, requires_item, requires_flag, forbids_flag,
## locked_text, consume_item, walk_through, fade_color, fade_duration, sound, sets_flag,
## unstable (Callable -> [area, spawn]), possible_targets (Array), name, prompt, on_open
static func create(parent: Node, pos: Vector3, yaw_deg: float, target_area_: String, target_spawn_: String = "default", opts: Dictionary = {}) -> Door:
	var d := Door.new()
	d.target_area = target_area_
	d.target_spawn = target_spawn_
	d.position = pos
	d.rotation.y = deg_to_rad(yaw_deg)
	d.name = String(opts.get("name", "Door_" + target_area_))
	for k in ["kind", "label", "requires_keepsake", "requires_item", "requires_flag", "forbids_flag", "locked_text", "consume_item", "walk_through", "fade_color", "fade_duration", "sound", "sets_flag", "prompt"]:
		if opts.has(k):
			d.set(k, opts[k])
	if opts.has("unstable"):
		d.unstable = opts.unstable
	if opts.has("possible_targets"):
		d.possible_targets = opts.possible_targets
	if opts.has("on_open"):
		d.on_open = opts.on_open
	parent.add_child(d)
	return d
