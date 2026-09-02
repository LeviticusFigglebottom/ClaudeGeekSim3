extends AreaBase
## The Halden Arms — the corridor outside your flat. Hospital-green walls, a
## carpet the colour of an old plaster, fluorescent lights that hum. It goes
## around: walk far enough and you pass your own door again. Flat 7 is your
## flat, mirrored. The lift has been coming for some time. The stairs go down
## to the Waiting Halls.

const LOOP := 44.0
const W := 3.0
const H := 2.7
var lift_calls := 0
var flicker: OmniLight3D = null


func build() -> void:
	can_wake = false
	Realm.apply(self, "corridor")
	var wall_tex := "wall/plaster_green"
	Kit.floor(self, Vector3(LOOP * 0.5, 0, 0), Vector2(LOOP + 8.0, W), "wall/carpet_house", {"tile": 1.5})
	Kit.ceiling(self, Vector3(LOOP * 0.5, H, 0), Vector2(LOOP + 8.0, W), "wall/ceiling_tile", {"tile": 1.2})
	Kit.wall(self, Vector3(-4, 0, -W * 0.5), Vector3(LOOP + 4, 0, -W * 0.5), H, wall_tex, {"name": "NorthWall"})
	Kit.wall(self, Vector3(LOOP + 4, 0, W * 0.5), Vector3(-4, 0, W * 0.5), H, wall_tex, {"name": "SouthWall"})
	# doors: odd numbers north, even south; 5½ is where you live
	var numbers := [1, 2, 3, 4, 5, "5½", 6, 7, 8, 9, 10, 11, 12]
	for i in numbers.size():
		var n = numbers[i]
		var x := 2.0 + i * 3.2
		var north := (i % 2 == 0)
		var z := (-W * 0.5 + 0.16) if north else (W * 0.5 - 0.16)
		var yaw := 180.0 if north else 0.0
		var pos := Vector3(x, 0, z)
		if str(n) == "5½":
			Door.create(self, pos, yaw, "apartment", "front", {"kind": "wood", "label": "Flat 5½ — home", "name": "Flat5Half", "on_open": func(_d: Node) -> void: Game.set_flag("in_flat_seven", false)})
			Kit.sign(self, "signs/five_half", pos + Vector3(0, 1.95, -0.05 if north else 0.05), yaw, Vector2(0.32, 0.32))
			add_spawn("flat_door", pos + Vector3(0, 0.1, 0.9 if north else -0.9), yaw + 180.0)
			add_spawn("default", pos + Vector3(0, 0.1, 0.9 if north else -0.9), yaw + 180.0)
		elif n == 7:
			Door.create(self, pos, yaw, "apartment", "front", {"kind": "wood", "label": "Flat 7", "name": "Flat7", "on_open": func(_d: Node) -> void: Game.set_flag("in_flat_seven", true)})
			Kit.label(self, "7", pos + Vector3(0, 1.95, -0.06 if north else 0.06), yaw, 40, Color(0.85, 0.8, 0.7), "display", {"pixel_size": 0.01})
		else:
			var it := Interactable.make(self, pos, Vector3(1.2, 2.3, 0.5), "Knock on flat %s" % str(n), _on_knock, {"name": "Flat%s" % str(n), "yaw": yaw, "model": "door_wood", "collision": "none"})
			it.set_meta("number", n)
			Kit.blocker(self, pos + Vector3(0, 1.1, 0), Vector3(1.0, 2.2, 0.12))
			Kit.label(self, str(n), pos + Vector3(0, 1.95, -0.06 if north else 0.06), yaw, 40, Color(0.85, 0.8, 0.7), "display", {"pixel_size": 0.01})
	# lights
	for i in 8:
		var x := 1.0 + i * 6.0
		Props.place(self, "fluorescent_light", Vector3(x, H - 0.02, 0), 0.0, 1.0, {"collision": "none"})
		var l := Kit.light(self, Vector3(x, H - 0.4, 0), Color(0.85, 0.95, 0.9), 0.7, 6.0)
		if i == 4:
			flicker = l
	# stairwell alcove on the north side near the end of the loop
	var sx := 38.0
	Kit.floor(self, Vector3(sx, 0, -W * 0.5 - 2.5), Vector2(3.0, 5.0), "wall/concrete", {"tile": 1.5})
	Kit.ceiling(self, Vector3(sx, H, -W * 0.5 - 2.5), Vector2(3.0, 5.0), "wall/concrete_dark")
	Kit.wall(self, Vector3(sx - 1.5, 0, -W * 0.5 - 5.0), Vector3(sx - 1.5, 0, -W * 0.5), H, "wall/concrete")
	Kit.wall(self, Vector3(sx + 1.5, 0, -W * 0.5), Vector3(sx + 1.5, 0, -W * 0.5 - 5.0), H, "wall/concrete")
	Kit.wall(self, Vector3(sx + 1.5, 0, -W * 0.5 - 5.0), Vector3(sx - 1.5, 0, -W * 0.5 - 5.0), H, "wall/concrete")
	# opening in the north wall for the alcove
	var nw := get_node_or_null("NorthWall")
	if nw:
		nw.queue_free()
		Kit.wall(self, Vector3(-4, 0, -W * 0.5), Vector3(sx - 1.5, 0, -W * 0.5), H, wall_tex)
		Kit.wall(self, Vector3(sx + 1.5, 0, -W * 0.5), Vector3(LOOP + 4, 0, -W * 0.5), H, wall_tex)
	Kit.stairs(self, Vector3(sx, 0, -W * 0.5 - 1.2), 0.0, 2.6, 8, -0.3, 0.4, "wall/concrete", {"name": "StairsDown"})
	Kit.floor(self, Vector3(sx, -2.4, -W * 0.5 - 5.0), Vector2(3.0, 2.0), "wall/concrete")
	Door.create(self, Vector3(sx, -2.4, -W * 0.5 - 5.85), 0.0, "offices", "from_stairs", {"kind": "iron", "label": "A fire door. It says NOT AN EXIT.", "name": "StairDoor", "sets_flag": "visited_offices_via_stairs"})
	Kit.sign(self, "signs/exit_wrong", Vector3(sx, H - 0.35, -W * 0.5 - 0.2), 0.0, Vector2(0.9, 0.36), {"unshaded": true})
	Kit.sign(self, "signs/halden_arms", Vector3(sx - 1.45, 1.7, -W * 0.5 - 2.5), -90.0, Vector2(1.0, 0.5))
	Kit.light(self, Vector3(sx, H - 0.4, -W * 0.5 - 2.5), Color(0.9, 1.0, 0.9), 0.6, 5.0)
	add_spawn("from_stairs", Vector3(sx, 0.1, -W * 0.5 - 0.6), 180.0)
	# the lift, south side: it arrives after three calls, and it is not a lift
	var lx := 20.4
	Interactable.make(self, Vector3(lx, 0, W * 0.5 - 0.3), Vector3(1.8, 2.4, 0.6), "Call the lift", _on_lift, {"name": "Lift"})
	Kit.sign(self, "signs/now_serving", Vector3(lx, 2.55, W * 0.5 - 0.02), 0.0, Vector2(0.8, 0.4), {"unshaded": true})
	var lift_door := Door.create(self, Vector3(lx, 0, W * 0.5 - 0.16), 0.0, "static", "lift", {"kind": "none", "label": "Get in the lift", "name": "LiftDoor", "fade_color": Color.WHITE, "fade_duration": 0.3, "sound": "static_burst", "requires_flag": "lift_open", "locked_text": "The lift has not arrived. Call it."})
	lift_door.add_box(Vector3(1.6, 2.3, 0.6), Vector3(0, 1.15, 0))
	if Game.has_flag("lift_open"):
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 2.3)
		Kit.add_mesh(lift_door, q, Kit.static_mat({"brightness": 0.5}), Vector3(0, 1.15, 0.1), {"solid": false, "rotation": Vector3(0, 180, 0)})
	else:
		lift_door.enabled = false
		Kit.box(self, Vector3(lx, 1.2, W * 0.5 + 0.05), Vector3(1.8, 2.4, 0.1), "metal/plate", {"name": "LiftDoors"})
	# graffiti, a window at the far end, and the loop
	Kit.sign(self, "signs/graffiti_door", Vector3(29.0, 1.5, W * 0.5 - 0.02), 0.0, Vector2(1.6, 0.4))
	Props.place(self, "window_night", Vector3(-3.9, 1.5, 0), -90.0, 1.0, {"collision": "none"})
	Props.place(self, "plant_pot", Vector3(-3.4, 0, -1.0), 0.0, 1.0, {"collision": "none"})
	SeamlessTeleport.link(self, Vector3(LOOP + 2.0, 0, 0), -90.0, Vector3(-2.0, 0, 0), -90.0, Vector3(0.6, 3.0, W), {"name": "Loop", "count_flag": "corridor_loops", "on_teleport": _on_loop})
	Kit.blocker(self, Vector3(-4.1, H * 0.5, 0), Vector3(0.2, H, W))
	Kit.blocker(self, Vector3(LOOP + 4.1, H * 0.5, 0), Vector3(0.2, H, W))
	Kit.wall(self, Vector3(-4, 0, W * 0.5), Vector3(-4, 0, -W * 0.5), H, wall_tex)
	Kit.wall(self, Vector3(LOOP + 4, 0, -W * 0.5), Vector3(LOOP + 4, 0, W * 0.5), H, wall_tex)
	if Game.count("corridor_loops") >= 2 and Game.count("usher_sightings") < 9:
		Usher.spawn(self, Vector3(LOOP - 1.0, 0, 0), {"appear_delay": 2.5, "radius": 50.0})
	Puzzle.declare(self, "lift", "lift_open", [], "call the lift three times")
	Dog.maybe_spawn(self, Vector3(12, 0.1, 0))


func _on_knock(_p: Node, it: Node) -> void:
	Audio.sfx("wood_knock", it.global_position, -6.0)
	var n = it.get_meta("number")
	Game.bump("knocks")
	await get_tree().create_timer(1.2).timeout
	if Game.chance(0.18):
		Audio.sfx("wood_knock", it.global_position, -14.0)
		Game.note("knock_back", "Someone knocked back", "You knocked on flat %s. After a moment, something knocked back, from lower down the door than a person would." % str(n))
		Game.toast.emit("Something knocks back. Lower down the door than a person would.")
	elif Game.count("knocks") == 12:
		Game.note("knocks_12", "Twelve knocks", "Nobody in the Halden Arms answers their door. Nobody in the Halden Arms is home. You are not sure you count.")


func _on_lift(_p: Node, _it: Node) -> void:
	lift_calls += 1
	Game.bump("lift_calls")
	Audio.sfx("ui_blip", null, -8.0)
	var total := Game.count("lift_calls")
	if Game.has_flag("lift_open"):
		return
	if total >= 3:
		Game.set_flag("lift_open", true)
		Audio.sfx("static_burst", global_position, -6.0)
		Game.toast.emit("The lift arrives. It is not a lift.")
		World.reload_here("flat_door", {"duration": 0.4, "silent": true})
	elif total == 1:
		Game.toast.emit("The lift is coming. It has been coming for some time.")
	else:
		Game.toast.emit("The lift is still coming. The number above it counts in a base you do not know.")


func _on_loop(_p: Node) -> void:
	if Game.count("corridor_loops") == 1:
		Game.note("corridor_loop", "The corridor", "The Halden Arms corridor goes around. You passed your own door from the wrong side. Flat 7 has your door number, if you squint.")


func _process(_delta: float) -> void:
	if flicker:
		flicker.light_energy = 0.7 if randf() > 0.06 else 0.1
