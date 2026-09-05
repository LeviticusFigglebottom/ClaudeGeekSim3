class_name Mirror
extends Interactable
## A mirror that does not show you. With the Mirror Shard held up to it, it
## becomes a door to the other side.

@export var target_area := ""
@export var target_spawn := "default"
@export var model := "mirror_wall"
## With this item held instead, the mirror opens somewhere else (and sets alt_flag).
@export var alt_item := ""
@export var alt_area := ""
@export var alt_spawn := "default"
@export var alt_flag := ""
var lines_without: Array = ["The mirror shows the room behind you.", "It does not show you."]
var lines_with_shard: Array = ["Through the shard the mirror is a doorway, and the room on the other side is waiting."]


func _ready() -> void:
	if model != "":
		Props.place(self, model, Vector3.ZERO, 0.0, 1.0, {"collision": "none"})
	add_box(Vector3(1.2, 1.4, 0.5), Vector3(0, 0, 0))
	prompt = "Look into the mirror"


func _on_interact(_player: Node) -> void:
	if alt_item != "" and alt_area != "" and Game.has_item(alt_item):
		Audio.sfx("shard", global_position, -2.0)
		if alt_flag != "":
			Game.set_flag(alt_flag, true)
		Game.set_flag("mirror_crossed", true)
		World.travel(alt_area, alt_spawn, {"color": Color(0.1, 0.1, 0.12), "duration": 1.2})
		return
	if Game.mirror_sight and target_area != "":
		Audio.sfx("shard", global_position, -2.0)
		Game.set_flag("mirror_crossed", true)
		World.travel(target_area, target_spawn, {"color": Color(0.65, 0.95, 0.93), "duration": 1.0})
		return
	if Game.has_keepsake("shard"):
		Game.toast.emit("Hold the shard up to it. (Look through it with the Mirror Shard.)")
	if World.hud:
		await World.hud.say("", lines_without)


static func create(parent: Node, pos: Vector3, yaw_deg: float, target_area_: String = "", target_spawn_: String = "default", opts: Dictionary = {}) -> Mirror:
	var m := Mirror.new()
	m.target_area = target_area_
	m.target_spawn = target_spawn_
	m.position = pos
	m.rotation.y = deg_to_rad(yaw_deg)
	m.name = String(opts.get("name", "Mirror"))
	if opts.has("model"):
		m.model = opts.model
	if opts.has("lines_without"):
		m.lines_without = opts.lines_without
	for k in ["alt_item", "alt_area", "alt_spawn", "alt_flag"]:
		if opts.has(k):
			m.set(k, opts[k])
	parent.add_child(m)
	return m
