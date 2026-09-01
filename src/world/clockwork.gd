class_name Clockwork
extends Node3D
## Anything that moves by clockwork: rotating hands, swinging pendulums,
## drifting platforms. All of it stops while the Hourglass is turned.
##
## mode: "rotate" (spin around `axis` at `speed_deg`/s), "oscillate" (rotate
## between -amplitude and +amplitude around `axis` with `period`), "path"
## (move a platform between `points`). Geometry goes under `body` so the
## player can ride it.

@export var mode := "rotate"
@export var axis := Vector3.UP
@export var speed_deg := 20.0
@export var amplitude_deg := 30.0
@export var period := 4.0
@export var points: Array = []
@export var platform := false
var body: Node3D = null
var _t := 0.0
var _seg := 0
var _seg_t := 0.0
var _initial_rot: Basis


func _ready() -> void:
	if platform:
		var ab := AnimatableBody3D.new()
		ab.sync_to_physics = true
		ab.collision_layer = Kit.L_WORLD
		ab.collision_mask = 0
		ab.set_meta("surface", "stone")
		add_child(ab)
		body = ab
	else:
		body = Node3D.new()
		add_child(body)
	_initial_rot = body.transform.basis
	if points.size() > 0:
		body.position = points[0]


## Add a box collision to the moving body (for platforms).
func add_shape(size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	if body is AnimatableBody3D:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = offset
		body.add_child(cs)


func _physics_process(delta: float) -> void:
	if Game.time_frozen:
		return
	_t += delta
	match mode:
		"rotate":
			body.rotate(axis.normalized(), deg_to_rad(speed_deg) * delta)
		"oscillate":
			var a := deg_to_rad(amplitude_deg) * sin(_t * TAU / period)
			body.transform.basis = _initial_rot.rotated(axis.normalized(), a)
		"path":
			if points.size() < 2:
				return
			var a: Vector3 = points[_seg]
			var b: Vector3 = points[(_seg + 1) % points.size()]
			var seg_len := a.distance_to(b)
			var spd := maxf(0.1, speed_deg) * 0.1
			_seg_t += delta * spd / maxf(seg_len, 0.01)
			if _seg_t >= 1.0:
				_seg_t = 0.0
				_seg = (_seg + 1) % points.size()
				a = points[_seg]
				b = points[(_seg + 1) % points.size()]
			body.position = a.lerp(b, smoothstep(0.0, 1.0, _seg_t))


static func create(parent: Node, pos: Vector3, opts: Dictionary = {}) -> Clockwork:
	var c := Clockwork.new()
	c.position = pos
	c.name = String(opts.get("name", "Clockwork"))
	for k in ["mode", "axis", "speed_deg", "amplitude_deg", "period", "points", "platform"]:
		if opts.has(k):
			c.set(k, opts[k])
	parent.add_child(c)
	return c
