class_name Player
extends CharacterBody3D
## The dreamer. First-person controller with an interaction ray and the
## keepsake behaviours (glide, shrink, lantern, bell, knife, hourglass...).
##
## The Player node is persistent: it lives in Main's SubViewport and is moved
## between areas by World.travel(). Areas never own it.

signal interacted(target: Node)
signal focus_changed(target: Node)

const WALK_SPEED := 4.2
const SPRINT_SPEED := 6.8
const SMALL_SPEED := 2.4
const CROUCH_SPEED := 2.0
const ACCEL := 16.0
const DECEL := 20.0
const AIR_CONTROL := 0.4
const JUMP_VELOCITY := 6.4
const GRAVITY := 18.0
const GLIDE_GRAVITY := 2.4
const GLIDE_MAX_FALL := 1.8
const FLAP_VELOCITY := 5.5
const MAX_FLAPS := 3
const MOUSE_SENS := 0.0021
const WAKE_HOLD := 1.6
const FALL_LIMIT := -90.0
const STEP_DISTANCE := 2.2

const STAND_HEIGHT := 1.7
const STAND_RADIUS := 0.35
const CROUCH_HEIGHT := 1.0
const SMALL_HEIGHT := 0.5
const SMALL_RADIUS := 0.14
const HEAD_STAND := 1.55
const HEAD_CROUCH := 0.88
const HEAD_SMALL := 0.42

## Physics layer bits (see project.godot [layer_names]).
const L_WORLD := 1
const L_PLAYER := 2
const L_INTERACT := 4
const L_TRIGGER := 8
const L_BIG_ONLY := 16
const L_MIRROR_ONLY := 32
const L_CUTTABLE := 64
const L_NPC := 128
const L_NORMAL_ONLY := 256
const L_LANTERN_ONLY := 512

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var ray: RayCast3D = $Head/Camera/InteractRay
@onready var lantern: OmniLight3D = $Head/Lantern
@onready var collider: CollisionShape3D = $Collision
@onready var steps: AudioStreamPlayer3D = $Steps

var yaw := 0.0
var pitch := 0.0
var frozen := false
var input_locked := false
var focus: Node = null
var wake_hold := 0.0
var bob_t := 0.0
var step_accum := 0.0
var crouching := false
var gliding := false
var flaps_left := MAX_FLAPS
var noclip := false
var last_safe_position := Vector3.ZERO
var _safe_timer := 0.0
var _capsule := CapsuleShape3D.new()
var _stand_query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	Game.player = self
	collider.shape = _capsule
	collision_layer = L_PLAYER
	Game.small_changed.connect(_on_small_changed)
	Game.lantern_changed.connect(_on_lantern_changed)
	Game.mirror_sight_changed.connect(_on_mirror_changed)
	Game.keepsake_equipped.connect(_on_equipped)
	_apply_body()
	_refresh_masks()
	set_look(0.0)


# --- look ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if frozen or input_locked:
		return
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			rotate_look(-event.relative.x * MOUSE_SENS, -event.relative.y * MOUSE_SENS)
		return
	if event.is_action_pressed("interact"):
		if event is InputEventMouseButton and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
		try_interact()
	elif event.is_action_pressed("use_keepsake"):
		use_keepsake()
	elif event.is_action_pressed("keepsake_next"):
		Game.cycle_keepsake(1)
	elif event.is_action_pressed("keepsake_prev"):
		Game.cycle_keepsake(-1)
	elif event.is_action_pressed("crouch"):
		_toggle_crouch()


func rotate_look(dyaw: float, dpitch: float) -> void:
	yaw = wrapf(yaw + dyaw, -PI, PI)
	pitch = clampf(pitch + dpitch, -1.45, 1.45)
	rotation.y = yaw
	head.rotation.x = pitch


func set_look(new_yaw: float, new_pitch: float = 0.0) -> void:
	yaw = new_yaw
	pitch = new_pitch
	rotation.y = yaw
	head.rotation.x = pitch


## Place the player at a transform (spawn points face -Z).
func teleport_to(t: Transform3D) -> void:
	global_position = t.origin
	var fwd := -t.basis.z
	if fwd.length_squared() > 0.001:
		set_look(atan2(-fwd.x, -fwd.z))
	velocity = Vector3.ZERO
	last_safe_position = t.origin
	flaps_left = MAX_FLAPS
	gliding = false
	_safe_timer = 0.0


## Move by a delta transform (seamless teleports): keeps look direction relative.
func shift_by(delta_t: Transform3D) -> void:
	var new_t := delta_t * global_transform
	global_position = new_t.origin
	var fwd := -new_t.basis.z
	set_look(atan2(-fwd.x, -fwd.z), pitch)
	velocity = delta_t.basis * velocity
	last_safe_position = global_position


func set_frozen(f: bool) -> void:
	frozen = f
	if f:
		velocity = Vector3.ZERO
		focus = null
		focus_changed.emit(null)


func forward() -> Vector3:
	return -global_transform.basis.z


func look_dir() -> Vector3:
	return -camera.global_transform.basis.z


func eye_position() -> Vector3:
	return camera.global_position


# --- movement -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	if frozen:
		return
	_update_focus()
	_handle_wake(delta)
	if noclip:
		_noclip_move(delta)
		return
	var on_floor := is_on_floor()
	var wish := Vector3.ZERO
	if not input_locked:
		var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		wish = (global_transform.basis * Vector3(inp.x, 0.0, inp.y))
		wish.y = 0.0
		if wish.length_squared() > 1.0:
			wish = wish.normalized()
	var speed := WALK_SPEED
	if Game.small:
		speed = SMALL_SPEED
	elif crouching:
		speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint") and not input_locked:
		speed = SPRINT_SPEED
	var target := wish * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := (ACCEL if wish.length_squared() > 0.0 else DECEL) * (1.0 if on_floor else AIR_CONTROL)
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var wings := Game.active_is("wings")
	gliding = false
	if on_floor:
		flaps_left = MAX_FLAPS
		if not input_locked and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY * (0.7 if Game.small else 1.0)
			Audio.sfx("jump", global_position, -12.0)
	else:
		if wings and not input_locked:
			if Input.is_action_just_pressed("jump") and flaps_left > 0:
				flaps_left -= 1
				velocity.y = maxf(velocity.y, 0.0) + FLAP_VELOCITY
				Audio.sfx("flap", global_position, -6.0)
			if Input.is_action_pressed("jump") and velocity.y < 0.0:
				gliding = true
		if gliding:
			velocity.y = maxf(velocity.y - GLIDE_GRAVITY * delta, -GLIDE_MAX_FALL)
		else:
			velocity.y -= GRAVITY * delta
	move_and_slide()

	_footsteps(delta, on_floor)
	_headbob(delta, on_floor, horizontal.length())
	_track_safe(delta, on_floor)
	if global_position.y < FALL_LIMIT and not World.traveling:
		World.fall_out()


func _noclip_move(delta: float) -> void:
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := camera.global_transform.basis * Vector3(inp.x, 0.0, inp.y)
	if Input.is_action_pressed("jump"):
		dir.y += 1.0
	if Input.is_action_pressed("crouch"):
		dir.y -= 1.0
	global_position += dir * (SPRINT_SPEED * 2.0) * delta


func _track_safe(delta: float, on_floor: bool) -> void:
	if on_floor:
		_safe_timer += delta
		if _safe_timer > 0.8:
			last_safe_position = global_position
			_safe_timer = 0.0
	else:
		_safe_timer = 0.0


## Put the player back on the last solid ground they stood on for a while.
func recover() -> void:
	global_position = last_safe_position + Vector3.UP * 0.2
	velocity = Vector3.ZERO


func _footsteps(delta: float, on_floor: bool) -> void:
	if not on_floor:
		return
	var h := Vector2(velocity.x, velocity.z).length()
	if h < 0.5:
		step_accum = STEP_DISTANCE * 0.6
		return
	step_accum += h * delta
	Game.stats.distance += h * delta
	var dist := STEP_DISTANCE * (0.45 if Game.small else 1.0)
	if step_accum >= dist:
		step_accum = 0.0
		var surface := "stone"
		var col := get_last_slide_collision()
		if col != null and col.get_collider() != null:
			var c: Object = col.get_collider()
			if c.has_meta("surface"):
				surface = String(c.get_meta("surface"))
		Audio.sfx("step_" + surface, global_position, -14.0 if not Game.small else -22.0, 0.12)


func _headbob(delta: float, on_floor: bool, speed: float) -> void:
	var base := _head_height()
	if on_floor and speed > 0.5:
		bob_t += delta * speed * 2.2
		head.position.y = base + sin(bob_t) * 0.035 * (0.5 if Game.small else 1.0)
		head.position.x = cos(bob_t * 0.5) * 0.012
	else:
		head.position.y = lerpf(head.position.y, base, 8.0 * delta)
		head.position.x = lerpf(head.position.x, 0.0, 8.0 * delta)


# --- body size ------------------------------------------------------------

func _head_height() -> float:
	if Game.small:
		return HEAD_SMALL
	return HEAD_CROUCH if crouching else HEAD_STAND


func _apply_body() -> void:
	var h := STAND_HEIGHT
	var r := STAND_RADIUS
	if Game.small:
		h = SMALL_HEIGHT
		r = SMALL_RADIUS
	elif crouching:
		h = CROUCH_HEIGHT
	_capsule.height = h
	_capsule.radius = r
	collider.position.y = h * 0.5
	head.position.y = _head_height()
	camera.near = 0.02 if Game.small else 0.05
	if lantern:
		lantern.omni_range = 5.0 if Game.small else 13.0


func _toggle_crouch() -> void:
	if Game.small:
		return
	if crouching:
		if _can_stand():
			crouching = false
			_apply_body()
	else:
		crouching = true
		_apply_body()


func _can_stand() -> bool:
	var space := get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.height = STAND_HEIGHT
	shape.radius = STAND_RADIUS - 0.02
	_stand_query.shape = shape
	_stand_query.transform = Transform3D(Basis(), global_position + Vector3(0, STAND_HEIGHT * 0.5 + 0.02, 0))
	_stand_query.collision_mask = L_WORLD
	_stand_query.exclude = [get_rid()]
	return space.intersect_shape(_stand_query, 1).is_empty()


func _on_small_changed(small: bool) -> void:
	if small:
		crouching = false
	_apply_body()
	_refresh_masks()
	Audio.sfx("shrink" if small else "grow", global_position, -6.0)


func _on_lantern_changed(lit: bool) -> void:
	lantern.visible = lit
	_refresh_masks()
	Audio.sfx("lantern_on" if lit else "lantern_off", global_position, -8.0)


func _on_mirror_changed(active: bool) -> void:
	_refresh_masks()
	Audio.sfx("shard", global_position, -8.0)


func _on_equipped(id: String) -> void:
	# Switching keepsakes puts the previous one away.
	if id != "lantern":
		Game.lantern_lit = false
	if id != "shard":
		Game.mirror_sight = false
	if id != "mouse":
		Game.small = false
	if id != "umbrella":
		Game.umbrella_open = false
	if id != "hourglass":
		Game.time_frozen = false


## Recompute what the player collides with and what the camera can see.
func _refresh_masks() -> void:
	var mask := L_WORLD
	if not Game.small:
		mask |= L_BIG_ONLY
	if Game.mirror_sight:
		mask |= L_MIRROR_ONLY
	else:
		mask |= L_NORMAL_ONLY
	if Game.lantern_lit:
		mask |= L_LANTERN_ONLY
	collision_mask = mask
	if camera:
		camera.set_cull_mask_value(2, Game.lantern_lit)
		camera.set_cull_mask_value(3, Game.mirror_sight)
		camera.set_cull_mask_value(4, not Game.mirror_sight)


# --- interaction ----------------------------------------------------------

func _update_focus() -> void:
	var target: Node = null
	if ray.is_colliding():
		target = _find_interactable(ray.get_collider())
		if target != null and target.has_method("can_focus") and not target.can_focus():
			target = null
	if target != focus:
		focus = target
		focus_changed.emit(focus)


static func _find_interactable(obj: Object) -> Node:
	var n := obj as Node
	while n != null:
		if n.has_method("interact") and n.has_method("prompt_text"):
			return n
		n = n.get_parent()
	return null


func try_interact() -> void:
	if focus == null:
		return
	interacted.emit(focus)
	focus.interact(self)


func use_keepsake() -> void:
	match Game.active_keepsake:
		"":
			Game.toast.emit("You are holding nothing.")
		"lantern":
			Game.lantern_lit = not Game.lantern_lit
		"bell":
			Audio.sfx("bell_small", global_position, -2.0)
			Game.ring_bell(global_position)
		"knife":
			_cut()
		"hourglass":
			Game.time_frozen = not Game.time_frozen
			Audio.sfx("hourglass", global_position, -6.0)
		"umbrella":
			Game.umbrella_open = not Game.umbrella_open
			Audio.sfx("umbrella", global_position, -6.0)
		"shard":
			Game.mirror_sight = not Game.mirror_sight
		"mouse":
			Game.small = not Game.small
		"wings":
			Game.toast.emit("The wings twitch. (Hold jump in the air to glide; press jump again to flap.)")
		"crown":
			Game.toast.emit("You straighten the crown. Nothing here is fooled, except the things that are.")


func _cut() -> void:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + look_dir() * 2.4
	var q := PhysicsRayQueryParameters3D.create(from, to, L_CUTTABLE | L_INTERACT | L_NPC)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	Audio.sfx("knife_swing", global_position, -8.0)
	if hit.is_empty():
		return
	var n := hit.collider as Node
	while n != null:
		if n.has_method("cut"):
			n.cut(self)
			return
		n = n.get_parent()


# --- waking ---------------------------------------------------------------

func _handle_wake(delta: float) -> void:
	if input_locked:
		wake_hold = 0.0
		return
	if Input.is_action_pressed("wake"):
		var area := World.current_area
		if area != null and "can_wake" in area and not area.can_wake:
			if wake_hold == 0.0:
				Game.toast.emit("You are already awake.")
			wake_hold = 0.001
			return
		wake_hold += delta
		if wake_hold >= WAKE_HOLD and not World.traveling:
			wake_hold = 0.0
			World.wake()
	else:
		wake_hold = 0.0


func wake_progress() -> float:
	return clampf(wake_hold / WAKE_HOLD, 0.0, 1.0)
