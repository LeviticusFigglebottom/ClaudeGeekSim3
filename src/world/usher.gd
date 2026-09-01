class_name Usher
extends Node3D
## The Usher: a tall figure in a coat who stands where you were not looking.
## Look straight at it for a moment and it is gone. It never speaks. It points.
## Sightings are counted; the journal notices after the first.

@export var appear_delay := 2.0
@export var vanish_delay := 1.4
@export var radius := 40.0
@export var start_visible := false
var body: Node3D = null
var _seen := 0.0
var _unseen := 0.0
var _visible := false
var _done := false


func _ready() -> void:
	if Props.exists("usher"):
		body = Props.place(self, "usher", Vector3.ZERO, 0.0, 1.0, {"collision": "none"})
	else:
		body = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 2.7, 0.3)
		(body as MeshInstance3D).mesh = bm
		(body as MeshInstance3D).material_override = Kit.flat(Color(0.05, 0.05, 0.06), {"unshaded": true})
		body.position.y = 1.35
		add_child(body)
	_visible = start_visible
	body.visible = _visible


func _process(delta: float) -> void:
	var p := Game.player as Player
	if p == null or _done or body == null:
		return
	var to := global_position + Vector3(0, 1.6, 0) - p.eye_position()
	var dist := to.length()
	if dist > radius:
		return
	var looking := to.normalized().dot(p.look_dir()) > 0.93
	if not _visible:
		_unseen = 0.0 if looking else _unseen + delta
		if _unseen >= appear_delay:
			_visible = true
			body.visible = true
			# face the player
			var d := p.global_position - global_position
			body.rotation.y = atan2(-d.x, -d.z)
	else:
		if looking and dist < radius:
			_seen += delta
			if _seen >= vanish_delay:
				_vanish()
		else:
			_seen = maxf(0.0, _seen - delta * 0.5)


func _vanish() -> void:
	_done = true
	body.visible = false
	Audio.sfx("whisper", global_position, -6.0)
	var n := Game.bump("usher_sightings")
	if n == 1:
		Game.note("usher", "Someone tall", "There was someone standing there. A coat. A hat. Half a face. When you looked properly there was not.")
	elif n == 5:
		Game.note("usher_5", "The Usher", "You have seen the tall one five times now. It has not moved closer. It has not moved further away. It is pointing at something you have not found yet.")
	Game.toast.emit("...")


static func spawn(parent: Node, pos: Vector3, opts: Dictionary = {}) -> Usher:
	var u := Usher.new()
	u.position = pos
	u.name = "Usher"
	for k in ["appear_delay", "vanish_delay", "radius", "start_visible"]:
		if opts.has(k):
			u.set(k, opts[k])
	parent.add_child(u)
	return u
