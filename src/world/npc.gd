class_name NPC
extends Interactable
## Someone (or something) to talk to. Lines depend on the keepsake you hold;
## `on_talk` handles riddles, trades and other special conversations.

@export var npc_name := "Someone"
var lines: Array = ["..."]
var reactions: Dictionary = {}
var on_talk: Callable
@export var model := "patron_seated"
@export var face_player := true
@export var flee_knife := false
@export var turn_to_bell := true
var talked := 0
var body: Node3D = null
var head: Node3D = null
var _target_yaw := 0.0
var _fled := false


func _ready() -> void:
	if Props.exists(model):
		body = Props.place(self, model, Vector3.ZERO, 0.0, 1.0, {"collision": "none"})
		head = Props.part(body, "Head")
	var b := Props.bounds(body) if body else AABB(Vector3.ZERO, Vector3(0.6, 1.8, 0.6))
	add_box(Vector3(maxf(b.size.x, 0.6), maxf(b.size.y, 1.0), maxf(b.size.z, 0.6)), b.get_center())
	if flee_knife:
		collision_layer |= Kit.L_INTERACT
	if prompt == "Look":
		prompt = "Talk to " + npc_name
	_target_yaw = rotation.y
	Game.bell_rung.connect(_on_bell)
	set_process(face_player)


func _process(delta: float) -> void:
	var p := Game.player as Player
	if p == null or body == null:
		return
	var d := p.global_position - global_position
	d.y = 0.0
	if d.length() < 7.0 and d.length() > 0.1:
		var want := atan2(-d.x, -d.z)
		body.rotation.y = lerp_angle(body.rotation.y, want - rotation.y, 4.0 * delta)


func _on_bell(origin: Vector3) -> void:
	if not turn_to_bell or body == null:
		return
	var d := origin - global_position
	d.y = 0.0
	if d.length() > 0.1:
		body.rotation.y = atan2(-d.x, -d.z) - rotation.y
	Game.bump("bell_heard_" + npc_name)


func say(ls: Array) -> void:
	if World.hud:
		await World.hud.say(npc_name, ls)


func _on_interact(player: Node) -> void:
	talked += 1
	Game.bump("talked_" + npc_name.to_lower().replace(" ", "_"))
	if on_talk.is_valid():
		var handled = await on_talk.call(player, self)
		if handled:
			return
	var k := Game.active_keepsake
	if k != "" and reactions.has(k):
		await say(reactions[k])
	else:
		await say(lines)


## The Kitchen Knife: some conversations can be cut.
func cut(_player: Node) -> void:
	if not flee_knife or _fled:
		return
	_fled = true
	Game.set_flag("cut_" + npc_name.to_lower().replace(" ", "_"), true)
	Audio.sfx("whisper", global_position, -4.0)
	enabled = false
	if body:
		var tw := create_tween()
		tw.tween_property(body, "scale", Vector3(1, 0.01, 1), 0.6)
		tw.tween_callback(queue_free)


## opts: model, lines, reactions, on_talk, face_player, flee_knife, prompt, name, yaw
static func create(parent: Node, pos: Vector3, yaw_deg: float, npc_name_: String, opts: Dictionary = {}) -> NPC:
	var n := NPC.new()
	n.npc_name = npc_name_
	n.position = pos
	n.rotation.y = deg_to_rad(yaw_deg)
	n.name = String(opts.get("name", "NPC_" + npc_name_.replace(" ", "_")))
	for k in ["model", "lines", "reactions", "face_player", "flee_knife", "prompt", "turn_to_bell"]:
		if opts.has(k):
			n.set(k, opts[k])
	if opts.has("on_talk"):
		n.on_talk = opts.on_talk
	parent.add_child(n)
	return n
