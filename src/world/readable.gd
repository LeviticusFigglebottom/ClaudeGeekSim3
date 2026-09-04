class_name Readable
extends Interactable
## A note, sign, plaque, book or inscription: shows dialogue lines when read.

@export var speaker := ""
var lines: Array = []
@export var note_key := ""
@export var note_title := ""
@export var note_text := ""
@export var flag_on_read := ""
@export var sound := "page"
var on_read: Callable


func _on_interact(_player: Node) -> void:
	Audio.sfx(sound, null, -10.0)
	if lines.size() > 0 and World.hud:
		await World.hud.say(speaker, lines)
	if flag_on_read != "":
		Game.set_flag(flag_on_read, true)
	if note_key != "":
		Game.note(note_key, note_title, note_text)
	if on_read.is_valid():
		on_read.call(self)


## opts: sign (texture for a flat sign, with size Vector2), model (a prop), yaw, size (collision),
## note_key/title/text, flag_on_read, speaker, sound, name, on_read, offset, layer
static func create(parent: Node, pos: Vector3, yaw_deg: float, prompt_: String, lines_: Array, opts: Dictionary = {}) -> Readable:
	var r := Readable.new()
	r.prompt = prompt_
	r.lines = lines_
	r.position = pos
	r.rotation.y = deg_to_rad(yaw_deg)
	r.name = String(opts.get("name", "Readable"))
	for k in ["speaker", "note_key", "note_title", "note_text", "flag_on_read", "sound"]:
		if opts.has(k):
			r.set(k, opts[k])
	if opts.has("on_read"):
		r.on_read = opts.on_read
	var size: Vector3 = opts.get("size", Vector3(1.0, 1.0, 0.4))
	r.add_box(size, opts.get("offset", Vector3(0, size.y * 0.5, 0)))
	parent.add_child(r)
	if opts.has("sign"):
		var s: Vector2 = opts.get("sign_size", Vector2(1.0, 0.5))
		var mo := {"solid": false}
		if opts.has("layer"):
			mo["layer"] = opts.layer
		# a touch in front of the readable's own plane, so a note pinned on a
		# wall never lies in the wall's face
		Kit.sign(r, String(opts.sign), Vector3(0, size.y * 0.5, -0.015), 0.0, s, mo)
	if opts.has("model"):
		Props.place(r, String(opts.model), Vector3.ZERO, 0.0, float(opts.get("scale", 1.0)), {"collision": String(opts.get("collision", "box"))})
	return r
