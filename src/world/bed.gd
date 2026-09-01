class_name Bed
extends Interactable
## Sleep here. Beds are how you enter the dream (and how some dreams start
## somewhere else).

@export var target_area := "nexus"
@export var target_spawn := "default"
@export var model := "bed_single"
@export var sleep_text := "Sleep"
var on_sleep: Callable


func _ready() -> void:
	if model != "":
		Props.place(self, model, Vector3.ZERO, 0.0, 1.0, {"collision": "box", "surface": "carpet"})
	add_box(Vector3(1.6, 1.2, 2.2), Vector3(0, 0.6, 0))
	prompt = sleep_text


func _on_interact(player: Node) -> void:
	Game.bump("sleeps")
	Audio.sfx("sleep", null, -4.0)
	if on_sleep.is_valid():
		var handled = await on_sleep.call(player, self)
		if handled:
			return
	if target_area != "":
		World.travel(target_area, target_spawn, {"color": Color.BLACK, "duration": 2.2})


static func create(parent: Node, pos: Vector3, yaw_deg: float, target_area_: String, target_spawn_: String = "default", opts: Dictionary = {}) -> Bed:
	var b := Bed.new()
	b.target_area = target_area_
	b.target_spawn = target_spawn_
	b.position = pos
	b.rotation.y = deg_to_rad(yaw_deg)
	b.name = String(opts.get("name", "Bed"))
	for k in ["model", "sleep_text"]:
		if opts.has(k):
			b.set(k, opts[k])
	if opts.has("on_sleep"):
		b.on_sleep = opts.on_sleep
	parent.add_child(b)
	return b
