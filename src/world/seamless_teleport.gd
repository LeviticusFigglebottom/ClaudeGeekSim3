class_name SeamlessTeleport
extends Area3D
## Non-euclidean glue. When the player walks through this volume moving in its
## forward direction (-Z), they are moved by the transform that maps this
## trigger onto `dest`, keeping their velocity and view. With identical
## geometry at both ends the seam is invisible: corridors that loop, streets
## that wrap, stairs that never end.

var dest: Node3D = null
var on_teleport: Callable
@export var size := Vector3(4, 4, 0.6)
@export var count_flag := ""
@export var one_way := true
@export var enabled := true
static var _last_time := 0


var _born := 0


func _contains(world_pos: Vector3) -> bool:
	var local := global_transform.affine_inverse() * world_pos
	var m := 0.6
	return absf(local.x) <= size.x * 0.5 + m and local.y >= -m and local.y <= size.y + m and absf(local.z) <= size.z * 0.5 + m


func _ready() -> void:
	_born = Time.get_ticks_msec()
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0, size.y * 0.5, 0)
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not enabled or dest == null or not (body is Player):
		return
	var p: Player = body
	var now := Time.get_ticks_msec()
	if now - _last_time < 200:
		return
	# Guard against stale overlap pairs (the player is placed after the area is
	# built): only act when the player really is inside this box right now.
	if now - _born < 400 or not _contains(p.global_position):
		return
	if one_way:
		var fwd := -global_transform.basis.z
		var v := p.velocity
		v.y = 0.0
		if v.length_squared() > 0.01 and v.normalized().dot(fwd) < 0.0:
			return
	var delta := dest.global_transform * global_transform.affine_inverse()
	p.shift_by(delta)
	_last_time = now
	if count_flag != "":
		Game.bump(count_flag)
	if on_teleport.is_valid():
		on_teleport.call(p)


## A one-way seam: crossing `from_pos` heading `from_yaw` puts you at `to_pos` heading `to_yaw`.
static func create(parent: Node, from_pos: Vector3, from_yaw: float, to_pos: Vector3, to_yaw: float, size_: Vector3 = Vector3(4, 4, 0.6), opts: Dictionary = {}) -> SeamlessTeleport:
	var t := SeamlessTeleport.new()
	t.size = size_
	t.position = from_pos
	t.rotation.y = deg_to_rad(from_yaw)
	t.name = String(opts.get("name", "Seam"))
	t.count_flag = String(opts.get("count_flag", ""))
	t.one_way = bool(opts.get("one_way", true))
	var marker := Node3D.new()
	marker.name = t.name + "_Dest"
	marker.position = to_pos
	marker.rotation.y = deg_to_rad(to_yaw)
	parent.add_child(marker)
	t.dest = marker
	if opts.has("on_teleport"):
		t.on_teleport = opts.on_teleport
	parent.add_child(t)
	return t


## A two-way loop between A (facing a_yaw) and B (facing b_yaw): walking forward
## out of A arrives at B; walking backward out of B arrives at A.
static func link(parent: Node, a_pos: Vector3, a_yaw: float, b_pos: Vector3, b_yaw: float, size_: Vector3 = Vector3(4, 4, 0.6), opts: Dictionary = {}) -> Array:
	var a := create(parent, a_pos, a_yaw, b_pos, b_yaw, size_, opts)
	var b := create(parent, b_pos, b_yaw + 180.0, a_pos, a_yaw + 180.0, size_, opts)
	return [a, b]
