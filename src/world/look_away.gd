class_name LookAway
extends Node3D
## Fires when the player has NOT looked at this spot for `delay` seconds while
## standing within `radius`. Things change when you are not looking.
## With `when_seen` true it fires instead when the player looks straight at it.

@export var radius := 12.0
@export var delay := 1.5
@export var dot_threshold := 0.55
@export var once := true
@export var when_seen := false
@export var require_seen_first := false
var on_trigger: Callable
var _unseen := 0.0
var _seen_ever := false
var _fired := false


func _process(delta: float) -> void:
	var p := Game.player as Player
	if p == null or _fired:
		return
	var to := global_position - p.eye_position()
	var dist := to.length()
	if dist > radius or dist < 0.01:
		_unseen = 0.0
		return
	var looking := to.normalized().dot(p.look_dir()) > dot_threshold
	if looking:
		_seen_ever = true
	if when_seen:
		_unseen = _unseen + delta if looking else 0.0
	else:
		if require_seen_first and not _seen_ever:
			return
		_unseen = 0.0 if looking else _unseen + delta
	if _unseen >= delay:
		_unseen = 0.0
		if once:
			_fired = true
		if on_trigger.is_valid():
			on_trigger.call(self)


static func create(parent: Node, pos: Vector3, cb: Callable, opts: Dictionary = {}) -> LookAway:
	var l := LookAway.new()
	l.position = pos
	l.on_trigger = cb
	l.name = String(opts.get("name", "LookAway"))
	for k in ["radius", "delay", "dot_threshold", "once", "when_seen", "require_seen_first"]:
		if opts.has(k):
			l.set(k, opts[k])
	parent.add_child(l)
	return l
