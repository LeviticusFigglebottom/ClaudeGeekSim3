class_name Switch
extends Interactable
## A lever or button that toggles a flag and/or calls back.

@export var flag := ""
@export var state := false
@export var one_way := false
@export var on_text := "Pull the lever"
@export var off_text := "Push the lever back"
var on_toggle: Callable
var handle: MeshInstance3D = null


func _ready() -> void:
	if flag != "":
		state = Game.has_flag(flag)
	var base := Kit.box(self, Vector3(0, 0.6, 0), Vector3(0.3, 1.2, 0.3), "metal/iron", {"solid": true})
	base.name = "Base"
	handle = Kit.box(self, Vector3(0, 1.1, 0), Vector3(0.06, 0.6, 0.06), "wood/planks_dark", {"solid": false})
	handle.position = Vector3(0, 1.15, -0.1)
	Kit.box(handle, Vector3(0, 0.32, 0), Vector3(0.12, 0.12, 0.12), "fabric/cloth_red", {"solid": false})
	_apply_visual(false)
	add_box(Vector3(0.8, 1.6, 0.8), Vector3(0, 0.8, 0))


func _apply_visual(animate: bool) -> void:
	var target := deg_to_rad(-45.0 if state else 45.0)
	if animate:
		var tw := create_tween()
		tw.tween_property(handle, "rotation:x", target, 0.3)
	else:
		handle.rotation.x = target


func prompt_text() -> String:
	return off_text if state else on_text


func can_focus() -> bool:
	return enabled and not (one_way and state)


func _on_interact(_player: Node) -> void:
	state = not state
	if flag != "":
		Game.set_flag(flag, state)
	Audio.sfx("lever", global_position, -4.0)
	_apply_visual(true)
	if on_toggle.is_valid():
		on_toggle.call(state)


static func create(parent: Node, pos: Vector3, yaw_deg: float, opts: Dictionary = {}) -> Switch:
	var s := Switch.new()
	s.position = pos
	s.rotation.y = deg_to_rad(yaw_deg)
	s.name = String(opts.get("name", "Switch"))
	for k in ["flag", "one_way", "on_text", "off_text", "state"]:
		if opts.has(k):
			s.set(k, opts[k])
	if opts.has("on_toggle"):
		s.on_toggle = opts.on_toggle
	parent.add_child(s)
	return s
