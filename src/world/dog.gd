class_name Dog
extends CharacterBody3D
## The dog. Found in the Nowhere House. Feed it a biscuit and it becomes your
## friend: it follows you, turns up in other places, and comes running to the
## Small Bell. It cannot be cut.

const SPEED := 3.6
const FOLLOW_DIST := 2.6
var body: Node3D = null
var head: Node3D = null
var tail: Node3D = null
var following := false
var _t := 0.0
var _target := Vector3.ZERO
var _has_target := false
var _wander_timer := 0.0
var _home := Vector3.ZERO
var interact_node: Interactable = null


func _ready() -> void:
	collision_layer = Kit.L_NPC
	collision_mask = Kit.L_WORLD
	_home = global_position
	if Props.exists("dog"):
		body = Props.place(self, "dog", Vector3.ZERO, 0.0, 1.0, {"collision": "none"})
		head = Props.part(body, "Head")
		tail = Props.part(body, "Tail")
	else:
		body = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 0.5, 0.8)
		(body as MeshInstance3D).mesh = bm
		(body as MeshInstance3D).material_override = Kit.flat(Color(0.55, 0.45, 0.35))
		body.position.y = 0.35
		add_child(body)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 0.7
	cs.shape = cap
	cs.position.y = 0.35
	add_child(cs)
	interact_node = Interactable.make(self, Vector3.ZERO, Vector3(1.0, 1.0, 1.4), "Pet the dog", _on_pet, {"name": "DogTouch"})
	following = Game.has_flag("dog_friend")
	Game.bell_rung.connect(_on_bell)
	Game.item_gained.connect(func(_id: String, _n: int) -> void: _refresh_prompt())
	_refresh_prompt()


func _refresh_prompt() -> void:
	if interact_node:
		interact_node.prompt = "Give the dog a biscuit" if (Game.has_item("dog_biscuit") and not following) else "Pet the dog"


func _on_pet(_player: Node, _it: Node) -> void:
	if Game.has_item("dog_biscuit") and not following:
		Game.take_item("dog_biscuit")
		following = true
		Game.set_flag("dog_friend", true)
		Game.note("dog", "The dog", "It ate the biscuit in one go and looked at you as if you had always been there. It follows you now. It does not seem to mind which world you are in.")
		Audio.sfx("dog_bark", global_position, -4.0)
		Game.toast.emit("The dog is your friend now.")
	else:
		Audio.sfx("dog_pant", global_position, -8.0)
		Game.bump("dog_pets")
		if Game.count("dog_pets") == 7:
			Game.note("dog_pets", "Seven pats", "The dog has been patted seven times. It has forgiven you for the closet.")
	_refresh_prompt()


func _on_bell(origin: Vector3) -> void:
	if following or global_position.distance_to(origin) < 30.0:
		_target = origin
		_has_target = true
		Audio.sfx("dog_bark", global_position, -6.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	var p := Game.player as Player
	var goal := Vector3.ZERO
	var want_move := false
	if _has_target:
		goal = _target
		want_move = global_position.distance_to(goal) > 1.2
		if not want_move:
			_has_target = false
	elif following and p != null:
		goal = p.global_position
		want_move = global_position.distance_to(goal) > FOLLOW_DIST
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(2.0, 6.0)
			_target = _home + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			_has_target = randf() < 0.5
	if want_move:
		var d := goal - global_position
		d.y = 0.0
		var dir := d.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		if body:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	move_and_slide()
	if tail:
		tail.rotation.y = sin(_t * 9.0) * (0.5 if (following or want_move) else 0.15)
	if head and p != null:
		var to := p.global_position - global_position
		if to.length() < 5.0:
			head.rotation.y = lerp_angle(head.rotation.y, clampf(atan2(-to.x, -to.z) - body.rotation.y, -1.0, 1.0), 4.0 * delta)


## Put the dog in an area. If it is your friend it appears anywhere you ask; otherwise only where `always` is true.
static func maybe_spawn(parent: Node, pos: Vector3, always: bool = false) -> Dog:
	if not always and not Game.has_flag("dog_friend"):
		return null
	var d := Dog.new()
	d.position = pos
	d.name = "Dog"
	parent.add_child(d)
	return d
