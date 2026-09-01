class_name Cuttable
extends StaticBody3D
## Something the Kitchen Knife can cut: a tapestry, vines, a curtain, a rope.
## Blocks the way until cut; remembers being cut through a flag.

@export var flag := ""
@export var cut_text := "Cut"
var on_cut: Callable
var _cut := false


func _ready() -> void:
	collision_layer = Kit.L_WORLD | Kit.L_CUTTABLE
	collision_mask = 0
	set_meta("surface", "carpet")
	if flag != "" and Game.has_flag(flag):
		queue_free()


func add_box(size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = offset
	add_child(cs)


func cut(_player: Node) -> void:
	if _cut:
		return
	_cut = true
	Audio.sfx("knife_cut", global_position, -2.0)
	if flag != "":
		Game.set_flag(flag, true)
	if on_cut.is_valid():
		on_cut.call(self)
	var tw := create_tween()
	tw.tween_property(self, "scale:y", 0.02, 0.5)
	tw.tween_callback(queue_free)


## Interactable-style prompt so the player sees what the knife can do.
func prompt_text() -> String:
	return cut_text if Game.active_is("knife") else "It is in the way. (Something sharp might help.)"


func interact(_player: Node) -> void:
	if Game.active_is("knife"):
		cut(_player)
	else:
		Game.toast.emit("It is in the way.")


func can_focus() -> bool:
	return not _cut


static func create(parent: Node, pos: Vector3, yaw_deg: float, size: Vector3, opts: Dictionary = {}) -> Cuttable:
	var c := Cuttable.new()
	c.position = pos
	c.rotation.y = deg_to_rad(yaw_deg)
	c.name = String(opts.get("name", "Cuttable"))
	c.flag = String(opts.get("flag", ""))
	c.cut_text = String(opts.get("cut_text", "Cut"))
	if opts.has("on_cut"):
		c.on_cut = opts.on_cut
	c.add_box(size, opts.get("offset", Vector3(0, size.y * 0.5, 0)))
	parent.add_child(c)
	c.collision_layer = Kit.L_WORLD | Kit.L_CUTTABLE | Kit.L_INTERACT
	if opts.has("model"):
		Props.place(c, String(opts.model), opts.get("model_offset", Vector3.ZERO), 0.0, float(opts.get("scale", 1.0)), {"collision": "none"})
	if opts.has("tex"):
		Kit.sign(c, String(opts.tex), Vector3(0, size.y * 0.5, 0), 0.0, Vector2(size.x, size.y), {"solid": false, "double": true})
	return c
