class_name Brazier
extends Interactable
## A brazier (or torch, or candle) that can be lit and snuffed. Emits `toggled`.

signal toggled(lit: bool)

@export var lit := false
@export var toggleable := true
@export var model := "brazier"
@export var light_color := Color(1.0, 0.6, 0.25)
@export var light_energy := 1.6
@export var light_range := 9.0
@export var index := 0
var fire: Node3D = null
var light: OmniLight3D = null
var prop: Node3D = null


func _ready() -> void:
	prop = Props.place(self, model, Vector3.ZERO, 0.0, 1.0, {"collision": "cylinder"})
	fire = Props.part(prop, "Fire")
	light = Kit.light(self, Vector3(0, 1.6, 0), light_color, light_energy, light_range)
	add_box(Vector3(1.4, 2.2, 1.4), Vector3(0, 1.1, 0))
	_apply()
	set_process(true)


func _process(delta: float) -> void:
	if light and lit:
		light.light_energy = light_energy * (0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.013 + float(index)))


func _apply() -> void:
	if fire:
		fire.visible = lit
	if light:
		light.visible = lit


func set_lit(v: bool, silent: bool = false) -> void:
	if lit == v:
		return
	lit = v
	_apply()
	if not silent:
		Audio.sfx("brazier" if lit else "lantern_off", global_position, -4.0)
	toggled.emit(lit)


func prompt_text() -> String:
	if not toggleable:
		return "The fire is not yours."
	return "Snuff the fire" if lit else "Light the fire"


func can_focus() -> bool:
	return enabled and toggleable


func _on_interact(_player: Node) -> void:
	set_lit(not lit)


static func create(parent: Node, pos: Vector3, opts: Dictionary = {}) -> Brazier:
	var b := Brazier.new()
	b.position = pos
	b.name = String(opts.get("name", "Brazier"))
	for k in ["lit", "toggleable", "model", "light_color", "light_energy", "light_range", "index"]:
		if opts.has(k):
			b.set(k, opts[k])
	parent.add_child(b)
	return b
