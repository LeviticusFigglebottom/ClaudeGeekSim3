extends AreaBase
## The Clocktower — every hour is the same hour. A round tower over the
## Drowned City with a spiral of platforms and two great gears to ride,
## a pendulum the size of a tree, a clock face on the inside of the wall
## whose hands only move when nobody is looking, and, at the top, the
## Hourglass, which stops all of it.
##
## Both entrances (the city door and the Anteroom's key door) arrive at the
## bottom. The door at the top goes back to the Anteroom. Falling only costs
## you the climb.

const R := 9.0
const WALL_H := 36.0

var top_y := 26.0
## where the spiral arrives at the top (degrees, 0 = +X); the landing keeps clear of it
var top_angle := 112.0
var hour_cw: Clockwork = null
var minute_cw: Clockwork = null
var pendulum_cw: Clockwork = null
var gears: Array = []
var _tick_t := 0.0


func build() -> void:
	Realm.apply(self, "clocktower", {"ambient_energy": 0.9, "fog_density": 0.018})
	_shell()
	_climb()
	_top()
	_ground()
	Puzzle.declare(self, "clocktower_climb", "", [], "walk the spiral; ride the gears where it stops")


# --- the tower shell ---------------------------------------------------------------------------------

func _shell() -> void:
	Kit.round_wall(self, Vector3.ZERO, R, WALL_H, 24, "stone/blocks_clocktower", {"tile": 3.0, "name": "TowerWall"})
	Kit.ring(self, Vector3.ZERO, 0.0, R + 0.4, 24, "stone/flagstone_castle", {"tile": 2.0})
	Kit.ring(self, Vector3(0, WALL_H, 0), 0.0, R + 0.4, 24, "wood/planks_dark", {"down": true, "tile": 2.0})
	# windows with the city's night behind them
	for w in [[60.0, 7.0], [180.0, 13.0], [300.0, 19.0], [120.0, 25.0]]:
		var ang: float = w[0]
		var y: float = w[1]
		Kit.sign(self, "props/window_night", Kit.polar(R - 0.12, ang, y), Kit.yaw_to_center(ang), Vector2(1.4, 2.4))
		Kit.light(self, Kit.polar(R - 1.0, ang, y), Color(0.55, 0.65, 1.0), 0.9, 7.0)
	# wall gears, turning slowly
	for g in [[20.0, 5.0, 8.0, 1.6], [230.0, 11.0, -6.0, 1.2], [95.0, 17.0, 5.0, 1.4], [330.0, 23.0, -9.0, 1.8]]:
		var ang: float = g[0]
		var y: float = g[1]
		var spd: float = g[2]
		var sc: float = g[3]
		var axis := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		# the gear is a disc drawn at 1.5 m up its own model: hung so the disc's
		# centre is the axle, flat against the wall, facing the room
		var cw := Clockwork.create(self, Kit.polar(R - 0.5, ang, y), {"mode": "rotate", "axis": axis, "speed_deg": spd, "name": "WallGear"})
		Props.place(cw.body, "gear_big", Vector3(0, -1.5 * sc, 0), Kit.yaw_to_center(ang), sc, {"collision": "none"})
		gears.append(cw)
	Kit.particles(self, Vector3(0, 10, 0), "motes", Vector3(7.0, 9.0, 7.0), 60)


# --- the climb ---------------------------------------------------------------------------------------

func _climb() -> void:
	var y := 1.1
	var a := 200.0
	var i := 0
	var count := 0
	while count < 27:
		if count == 8 or count == 17:
			# a great gear to ride: its top a small step up, then the spiral continues
			var gear_top := y - 0.95 + 0.6
			var gc := Kit.polar(5.4, a + 14.0, gear_top)
			var cw := Clockwork.create(self, gc, {"mode": "rotate", "axis": Vector3.UP, "speed_deg": 8.0 if count == 8 else -6.5, "platform": true, "name": "RideGear%d" % count})
			cw.add_shape(Vector3(5.6, 0.6, 5.6), Vector3(0, -0.3, 0))
			# laid flat: the disc's centre sits on the axle at the platform's top
			Props.place(cw.body, "gear_big", Vector3(0, 0.0, 1.5 * 2.6), 0.0, 2.6, {"collision": "none", "rotation": Vector3(-90, 0, 0)})
			gears.append(cw)
			Kit.light(self, gc + Vector3(0, 2.5, 0), Color(1.0, 0.8, 0.5), 0.9, 8.0)
			Readable.create(self, gc + Vector3(0, 0.4, 0), 0.0, "The great gear", ["Teeth the size of gravestones. It turns because the tower turns it; the tower turns because the clock does; the clock turns because of the gear.", "You are standing on the reason."], {"name": "GearRead%d" % count, "size": Vector3(3.0, 0.6, 3.0)})
			y = gear_top + 0.35
			a += 52.0
			count += 2
			continue
		var landing := (count % 7 == 6)
		var length := 4.6 if landing else 3.2
		if landing:
			Kit.box(self, Kit.polar(7.4, a, y - 0.15), Vector3(length, 0.3, 2.0), "wood/planks_dark", {"yaw": Kit.yaw_to_center(a), "tile": 1.0, "name": "Step%d" % count})
		else:
			# each step is a plank tilted along the way, its far end at the next step's height: a ramp you walk
			var tilt := -rad_to_deg(atan2(0.95, length))
			var pos := Kit.polar(7.4, a, y - 0.15 + 0.475)
			Kit.box(self, pos, Vector3(Vector2(length, 0.95).length(), 0.3, 2.0), "wood/planks_dark", {"rotation": Vector3(0, Kit.yaw_to_center(a), tilt), "tile": 1.0, "name": "Step%d" % count})
		# a brass bracket under each step
		Kit.box(self, Kit.polar(8.3, a, y - 0.55), Vector3(0.3, 0.6, 0.3), "metal/brass", {"yaw": Kit.yaw_to_center(a), "solid": false})
		if count % 4 == 0:
			Props.place(self, "lantern_hanging", Kit.polar(R - 0.6, a, y + 2.3), 0.0, 1.0, {"collision": "none"})
			Kit.light(self, Kit.polar(R - 1.2, a, y + 1.9), Color(1.0, 0.82, 0.5), 1.0, 8.0)
		if landing:
			_landing_thing(count, Kit.polar(7.0, a, y), a)
		y += 0.95
		a += 24.0
		count += 1
		i += 1
	# the landing is level with the last step, and open above the last three
	top_y = y - 0.95
	top_angle = wrapf(a - 24.0, 0.0, 360.0)


func _landing_thing(idx: int, pos: Vector3, ang: float) -> void:
	var yaw := Kit.yaw_to_center(ang)
	match idx:
		6:
			Props.place(self, "candle_cluster", pos + Vector3(0, 0, 0), 0.0, 1.0, {"collision": "none"})
			Kit.light(self, pos + Vector3(0, 0.8, 0), Color(1.0, 0.75, 0.4), 0.7, 5.0)
			Readable.create(self, pos + Vector3(0, 0.4, 0), yaw, "Scratched into the step", ["I HAVE CLIMBED THIS TOWER EVERY DAY. IT IS ONE DAY.", "Below it, in a steadier hand: the hourglass is at the top. so is the bottom."], {"name": "StepWords", "size": Vector3(1.4, 0.6, 1.4), "note_key": "clocktower_step", "note_title": "One day", "note_text": "Scratched into a step of the Clocktower: I have climbed this tower every day. It is one day."})
		13:
			Props.place(self, "chest", pos, yaw + 180.0, 0.8)
			Interactable.make(self, pos + Vector3(0, 0.5, 0), Vector3(1.0, 0.8, 0.8), "Open the chest", func(_p: Node, it: Node) -> void:
				Audio.sfx("creak", it.global_position, -8.0)
				if Game.has_flag("clocktower_chest"):
					Game.toast.emit("Cogs. Springs. A little dust that used to be a spring.")
					return
				Game.set_flag("clocktower_chest", true)
				Game.toast.emit("Cogs, springs, and a clock hand with your name engraved on it. You leave it. It is not yours yet.")
				Game.note("clocktower_chest", "The chest on the landing", "A chest halfway up the Clocktower, full of cogs and springs and one clock hand with your name on it."), {"name": "LandingChest"})
		20:
			Props.place(self, "lectern", pos, yaw + 180.0, 0.9)
			Readable.create(self, pos + Vector3(0, 1.0, 0), yaw, "The keeper's ledger", ["Wound: yes. Oiled: yes. Time: half past five.", "Wound: yes. Oiled: yes. Time: half past five.", "The entries go on for pages. The handwriting gets older."], {"name": "Ledger", "size": Vector3(0.8, 0.8, 0.8), "sound": "page", "note_key": "clocktower_ledger", "note_title": "The keeper's ledger", "note_text": "Wound, oiled, half past five. Every page. The handwriting gets older but the time does not."})


# --- the top ------------------------------------------------------------------------------------------

func _top() -> void:
	var ty := top_y
	var open_sector := [[top_angle - 24.0, 150.0]]
	Kit.ring(self, Vector3(0, ty, 0), 3.0, R - 0.15, 24, "wood/planks_dark", {"tile": 2.0, "name": "TopRing", "gaps": open_sector})
	Kit.ring(self, Vector3(0, ty - 0.3, 0), 3.0, R - 0.15, 24, "wood/planks_dark", {"down": true, "tile": 2.0, "solid": false, "gaps": open_sector})
	Kit.round_wall(self, Vector3(0, ty - 0.3, 0), 3.0, 0.3, 24, "metal/brass", {"outward": true, "gaps": open_sector})
	Kit.round_wall(self, Vector3(0, ty, 0), 3.0, 0.9, 24, "metal/brass", {"gaps": open_sector})
	# what stands on the landing sits away from where the stair comes up
	var face_a := wrapf(top_angle + 100.0, 0.0, 360.0)
	var door_a := wrapf(top_angle + 155.0, 0.0, 360.0)
	var glass_a := wrapf(top_angle + 205.0, 0.0, 360.0)
	var bell_a := wrapf(top_angle + 255.0, 0.0, 360.0)
	# the clock face, and the hands that move when you are not looking
	# a seven-metre dial is flat and the wall is round: it stands 0.9 m proud
	# of the wall on an iron drum, or the wall would cut all but a strip of it
	var face_c := Kit.polar(R - 0.97, face_a, ty + 4.0)
	Kit.cylinder(self, Kit.polar(R - 0.3, face_a, ty + 4.0) - Vector3(0, 0.6, 0), 3.55, 1.2, "metal/iron", {"rotation": Vector3(90, Kit.yaw_to_center(face_a), 0), "tint": Color(0.45, 0.42, 0.4), "segments": 24, "tile": 2.0})
	Kit.sign(self, "metal/clock_face", face_c, Kit.yaw_to_center(face_a), Vector2(7.0, 7.0), {"unshaded": true})
	Kit.light(self, Kit.polar(R - 3.0, face_a, ty + 4.0), Color(1.0, 0.9, 0.7), 1.3, 9.0)
	var hc := Kit.polar(R - 1.15, face_a, ty + 4.0)
	var axis := Vector3(cos(deg_to_rad(face_a)), 0, sin(deg_to_rad(face_a)))
	hour_cw = Clockwork.create(self, hc, {"mode": "rotate", "axis": axis, "speed_deg": 0.0 if visit_count >= 2 else 0.4, "name": "HourHand"})
	var hh := Props.place(hour_cw.body, "clock_hand", Vector3.ZERO, 0.0, 1.6, {"collision": "none"})
	hh.rotation.y = deg_to_rad(Kit.yaw_to_center(face_a))
	hour_cw.body.rotate(axis, deg_to_rad(165.0 if visit_count < 2 else 60.0))
	minute_cw = Clockwork.create(self, hc + Kit.polar(-0.05, face_a), {"mode": "rotate", "axis": axis, "speed_deg": 0.0 if visit_count >= 2 else 4.0, "name": "MinuteHand"})
	var mh := Props.place(minute_cw.body, "clock_hand", Vector3.ZERO, 0.0, 2.3, {"collision": "none"})
	mh.rotation.y = deg_to_rad(Kit.yaw_to_center(face_a))
	minute_cw.body.rotate(axis, deg_to_rad(90.0))
	LookAway.create(self, hc, _on_face_unseen, {"delay": 2.5, "radius": 16.0, "once": false, "require_seen_first": true, "name": "FaceWatch"})
	Readable.create(self, Kit.polar(R - 1.7, face_a, ty + 1.6), Kit.yaw_to_center(face_a), "The clock", ["Half past five.", "You look away, and look back. Half past five, but the hands have moved to say it differently."], {"name": "ClockRead", "size": Vector3(3.0, 3.0, 1.2), "note_key": "clocktower_face", "note_title": "The clock face", "note_text": "The clock in the Clocktower says half past five, like every clock. Its hands move when you are not looking, and arrive back at half past five."})
	# the hourglass on its lectern
	var lp := Kit.polar(5.6, glass_a, ty)
	Props.place(self, "lectern", lp, Kit.yaw_to_center(glass_a) + 180.0, 1.0)
	Pickup.create(self, lp + Vector3(0, 1.15, 0), {"keepsake": "hourglass", "name": "Hourglass"})
	Kit.light(self, lp + Vector3(0, 2.0, 0), Color(1.0, 0.85, 0.5), 1.4, 7.0)
	Readable.create(self, lp + Vector3(0, 0.6, 0), Kit.yaw_to_center(glass_a), "The lectern", ["A brass plate: TURN ONCE. TURN BACK. DO NOT TURN TWICE.", "Somebody has scratched out DO NOT."], {"name": "LecternRead", "size": Vector3(1.0, 0.8, 1.0)})
	# the bell
	var bp := Kit.polar(5.6, bell_a, ty)
	Props.place(self, "bell_tower_frame", bp, Kit.yaw_to_center(bell_a), 1.1)
	Props.place(self, "bell_huge", bp + Vector3(0, 0.9, 0), 0.0, 0.8, {"collision": "none"})
	Interactable.make(self, bp + Vector3(0, 1.6, 0), Vector3(1.6, 1.8, 1.6), "Ring the great bell", _on_great_bell, {"name": "GreatBell"})
	Kit.light(self, bp + Vector3(0, 2.6, 0), Color(1.0, 0.8, 0.5), 0.8, 7.0)
	# the door back to the Anteroom
	Door.create(self, Kit.polar(R - 0.34, door_a, ty), Kit.yaw_to_center(door_a), "nexus", "from_clocktower", {"kind": "big", "label": "A door at the top of the tower", "name": "TopDoor", "fade_duration": 1.0})
	Kit.light(self, Kit.polar(R - 1.4, door_a, ty + 2.4), Color(1.0, 0.85, 0.55), 1.0, 7.0)
	Kit.sign(self, "signs/plaque_anteroom", Kit.polar(R - 0.15, door_a + 15.0, ty + 1.8), Kit.yaw_to_center(door_a + 15.0), Vector2(1.0, 0.6))
	Readable.create(self, Kit.polar(R - 0.4, door_a + 15.0, ty + 1.8), Kit.yaw_to_center(door_a + 15.0), "A plaque", ["THE TOP OF THE TOWER IS THE BOTTOM OF THE SKY.", "Under it, a hand-drawn arrow pointing down. Under the arrow: same door."], {"name": "TopPlaque", "size": Vector3(1.0, 0.6, 0.4)})
	# a landing light where the stair arrives, so the last steps read as steps
	Kit.light(self, Kit.polar(6.0, top_angle, ty + 2.2), Color(1.0, 0.85, 0.55), 1.1, 8.0)
	# the pendulum, hanging from the top ring's rim into the shaft
	pendulum_cw = Clockwork.create(self, Vector3(0, ty - 0.4, 0), {"mode": "oscillate", "axis": Vector3(0, 0, 1), "amplitude_deg": 9.0, "period": 3.4 if visit_count < 2 else 100000.0, "name": "Pendulum"})
	Props.place(pendulum_cw.body, "pendulum_big", Vector3(0, -0.2, 0), 0.0, 4.0, {"collision": "none"})
	Kit.light(self, Vector3(0, ty - 8.0, 0), Color(1.0, 0.85, 0.6), 1.0, 9.0)
	Kit.particles(self, Vector3(0, ty + 1.5, 0), "motes", Vector3(7.0, 1.5, 7.0), 30)
	if visit_count >= 2 and not Game.has_note("clocktower_still"):
		Game.note("clocktower_still", "The tower, stopped", "The second time, the pendulum in the Clocktower is still, and the hands have stopped at a different half past five.")


# --- the ground floor ------------------------------------------------------------------------------------

func _ground() -> void:
	# doors in: the city, and the Anteroom's key door (the one you came in by)
	Door.create(self, Kit.polar(R - 0.34, 270.0, 0.0), Kit.yaw_to_center(270.0), "city", "from_tower", {"kind": "iron", "label": "Down to the street", "name": "CityDoor", "sound": "door_heavy"})
	add_spawn("from_city", Kit.polar(6.8, 270.0, 0.1), Kit.yaw_to_center(270.0))
	Door.create(self, Kit.polar(R - 0.34, 0.0, 0.0), Kit.yaw_to_center(0.0), "nexus", "from_clocktower", {"kind": "big", "label": "The keyhole door, from the inside", "name": "NexusDoor", "fade_duration": 1.0})
	add_spawn("from_nexus", Kit.polar(6.8, 0.0, 0.1), Kit.yaw_to_center(0.0))
	add_spawn("default", Kit.polar(6.8, 0.0, 0.1), Kit.yaw_to_center(0.0))
	Kit.light(self, Kit.polar(6.5, 270.0, 2.6), Color(1.0, 0.85, 0.55), 1.0, 7.0)
	Kit.light(self, Kit.polar(6.5, 0.0, 2.6), Color(1.0, 0.85, 0.55), 1.0, 7.0)
	# the great hourglass in the middle, and the works
	Props.place(self, "hourglass_big", Vector3(0, 0, 0), 0.0, 2.2)
	Kit.light(self, Vector3(0, 2.4, 0), Color(1.0, 0.8, 0.45), 1.6, 10.0)
	Readable.create(self, Vector3(0, 1.4, 0), 0.0, "The great hourglass", ["Sand runs from the top bulb to the bottom, and from the bottom bulb to the top, at the same time.", "It has been doing this for as long as it has been half past five."], {"name": "BigHourglass", "size": Vector3(2.4, 2.8, 2.4), "note_key": "clocktower_hourglass", "note_title": "The great hourglass", "note_text": "The hourglass at the bottom of the Clocktower runs both ways at once. A smaller one, at the top, runs the way you turn it."})
	for g in [[45.0, 3.0], [135.0, 2.4], [225.0, 3.2]]:
		var ang: float = g[0]
		var sc: float = g[1]
		var cw := Clockwork.create(self, Kit.polar(5.2, ang, 0.35), {"mode": "rotate", "axis": Vector3.UP, "speed_deg": 10.0 * (1.0 if int(ang) % 90 == 45 else -1.0), "name": "FloorGear"})
		Props.place(cw.body, "gear_big", Vector3(0, 0.0, 1.5 * sc * 0.5), 0.0, sc * 0.5, {"collision": "none", "rotation": Vector3(-90, 0, 0)})
		gears.append(cw)
	Props.place(self, "clock_grandfather", Kit.polar(R - 0.7, 315.0, 0.0), Kit.yaw_to_center(315.0), 1.1)
	Readable.create(self, Kit.polar(R - 0.9, 315.0, 1.4), Kit.yaw_to_center(315.0), "A grandfather clock", ["Half past five. It ticks. Inside the case, instead of a pendulum, a very small tower with a very small clock in it, which says half past five."], {"name": "SmallClock", "size": Vector3(0.9, 2.0, 0.9)})
	Props.place(self, "chain_hanging_long", Kit.polar(3.5, 160.0, 12.0), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "chain_hanging_long", Kit.polar(3.0, 40.0, 9.0), 0.0, 1.0, {"collision": "none"})
	# the keeper
	NPC.create(self, Kit.polar(4.2, 120.0), Kit.yaw_to_center(120.0), "The Keeper", {
		"model": "hermit", "face_player": true, "flee_knife": true,
		"lines": ["Every hour is the same hour. That is not a complaint. It makes the winding easy.", "Up top there is a smaller glass than this one. Turn it and everything stops to think.", "Mind the gears. They do not mind you."],
		"reactions": {
			"hourglass": ["Ah. You have it. Then you know what stopping feels like from the inside.", "Bring it back when you are done with the world. I will be here. It will be half past five."],
			"wings": ["Wings. You will not need the gears, then. The gears will be disappointed."],
			"crown": ["Your majesty. The tower is yours. It always was; it was just waiting for the hat."],
			"bell": ["Ring that up top, by the big one, and see what the big one says back."],
		},
	})
	Kit.sign(self, "wall/paper", Kit.polar(R - 0.15, 200.0, 1.8), Kit.yaw_to_center(200.0), Vector2(0.8, 0.6), {"tint": Color(0.9, 0.85, 0.7)})
	Readable.create(self, Kit.polar(R - 0.4, 200.0, 1.8), Kit.yaw_to_center(200.0), "A notice", ["THE STAIRS ARE OUT. USE THE STAIRS.", "In pencil underneath: the gears go round. so do you."], {"name": "StairsNotice", "size": Vector3(0.8, 0.6, 0.4)})
	Kit.particles(self, Vector3(0, 1.5, 0), "motes", Vector3(6.0, 1.0, 6.0), 20)


# --- callbacks and hooks --------------------------------------------------------------------------------

func _on_face_unseen(_l: Node) -> void:
	if hour_cw:
		hour_cw.body.rotate(Vector3(1, 0, 0), deg_to_rad(30.0))
	if minute_cw:
		minute_cw.body.rotate(Vector3(1, 0, 0), deg_to_rad(-140.0))
	Audio.sfx("clock_chime", Kit.polar(R - 1.0, top_angle + 100.0, top_y + 3.0), -10.0)
	Game.bump("clock_hands_moved")
	if Game.count("clock_hands_moved") == 3 and not Game.has_note("clocktower_hands"):
		Game.note("clocktower_hands", "The hands", "The hands of the clock only move while you are not looking at them. They are catching up on something.")


func _on_great_bell(_p: Node, _it: Node) -> void:
	Audio.sfx("bell_big", Kit.polar(5.6, top_angle + 255.0, top_y + 2.0), 0.0)
	Game.bump("great_bell_rung")
	var was_frozen := Game.time_frozen
	Game.time_frozen = true
	Game.toast.emit("The great bell. Everything in the tower stops to listen.")
	await get_tree().create_timer(4.0).timeout
	if not was_frozen and is_inside_tree():
		Game.time_frozen = false
	if Game.count("great_bell_rung") == 1:
		Game.note("clocktower_bell", "The great bell", "Ringing the great bell at the top of the Clocktower stops every gear for the length of the note. The Hourglass does the same, for longer, anywhere.")
	if Game.has_keepsake("bell") and Game.count("great_bell_rung") == 2:
		Game.toast.emit("Your small bell rings back, on its own, in your hand.")


func _process(delta: float) -> void:
	_tick_t += delta
	if _tick_t > 2.2:
		_tick_t = 0.0
		if not Game.time_frozen:
			Audio.sfx("gear_tick", Vector3(0, 6, 0), -14.0)


func on_time_frozen(frozen: bool) -> void:
	if frozen and not Game.has_note("clocktower_frozen"):
		Game.note("clocktower_frozen", "Stopped", "With the Hourglass turned, the Clocktower's gears stop. You can walk on them like floors.")


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if n == 1:
		Game.note("clocktower", "The Clocktower", "A round tower over the Drowned City, full of gears, with a spiral of steps and two great gears to ride. Every hour in it is the same hour.")
