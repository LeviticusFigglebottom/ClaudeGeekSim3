extends AreaBase
## Off Air — where conceding goes. The station is shutting down. Out in a dark
## with nothing under it, eight sets the size of rooms hang in the black, each
## one a channel still on, and between them, on cables, the road: eight
## stages where the same life was played, being struck. Dust sheets over the
## furniture, tape on the floor, crates stencilled with what was in them. Every
## stage has one spotlight and one screen, and as you leave it the light goes
## out behind you and the screen goes to a dot: a channel off the air. The
## countdown on the card in the sky comes down with you. At the end, the last
## light, a bed, the one who ushered you lying on it with your face, a monitor,
## and a cable running to a socket in a wall the size of a building. The plug
## is the ending.
##
## The screens out in the dark drift. Falling off anything lands in the Static.
## No route needs a fall. Holding R wakes you.

const STEP := 28.0
const WORDS := ["BORN", "SMALL", "TAUGHT", "KEPT", "LOVED", "HOME", "KEPT AGAIN", "OFF"]
const GREY := Color(0.55, 0.55, 0.6)
const PALE := Color(0.82, 0.82, 0.86)
const COLD := Color(0.75, 0.8, 1.0)
const PLATE := "metal/plate"
const DARK := Color(0.72, 0.72, 0.78)

var stages: Array = []        # per stage: {c, spot, screen, lamp, on}
var countdown: Label3D = null
var channels_on := 8


func build() -> void:
	can_wake = true
	Realm.apply(self, "static", {"bg": "#030308", "ambient": "#6a6a80", "ambient_energy": 1.15, "fog": "#06060c", "fog_density": 0.003, "sky": ""})
	# a floor of static far below, which is what you fall towards
	Kit.floor(self, Vector3(0, -34.0, -3.5 * STEP), Vector2(600.0, 600.0), "common/static", {"mat": Kit.static_mat({"brightness": 0.22, "scale": 900.0, "tint": Color(0.7, 0.7, 0.8)}), "solid": false})
	for i in 8:
		_stage(i)
	for i in 7:
		_cable_bridge(_stage_pos(i), _stage_pos(i + 1))
	_final()
	_drift()
	_card()
	add_spawn("from_banquet", _stage_pos(0) + Vector3(0, 0.1, 5.0), 0.0)
	add_spawn("default", _stage_pos(0) + Vector3(0, 0.1, 5.0), 0.0)
	Puzzle.declare(self, "off_air", "ending_unplugged", [], "walk the stages to the bed at the end and pull the plug")


func _stage_pos(i: int) -> Vector3:
	return Vector3(sin(i * 1.1) * 12.0, i * 1.6, -i * STEP)


# --- a stage being struck --------------------------------------------------------------------

func _stage(i: int) -> void:
	var c := _stage_pos(i)
	var half := 7.0
	var floor_ := Kit.floor(self, c, Vector2(half * 2.0, half * 2.0), PLATE, {"tile": 2.0, "thick": 0.5, "tint": DARK})
	floor_.name = "Stage%d" % i
	# a lip, and walls you cannot see above it, open where the cables come and go
	for sx in [-1.0, 1.0]:
		Kit.box(self, c + Vector3(sx * (half - 0.15), 0.15, 0), Vector3(0.3, 0.3, half * 2.0), "metal/iron", {"tint": Color(0.4, 0.4, 0.42)})
		Kit.blocker(self, c + Vector3(sx * (half + 0.05), 2.0, 0), Vector3(0.2, 4.0, half * 2.0))
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			Kit.box(self, c + Vector3(sx * (half * 0.5 + 1.05), 0.15, sz * (half - 0.15)), Vector3(half - 2.8, 0.3, 0.3), "metal/iron", {"tint": Color(0.4, 0.4, 0.42)})
			Kit.blocker(self, c + Vector3(sx * (half * 0.5 + 1.2), 2.0, sz * (half + 0.05)), Vector3(half - 2.4, 4.0, 0.2))
	# tape on the floor: a cross where the thing stood, and the stage's number
	for k in 2:
		Kit.box(self, c + Vector3(0, 0.012, 0), Vector3(2.4, 0.02, 0.1), "", {"tint": Color(0.9, 0.85, 0.3), "solid": false, "rotation": Vector3(0, 45.0 + k * 90.0, 0)})
	Kit.label(self, str(8 - i), c + Vector3(-4.5, 0.03, 4.5), 0.0, 60, Color(0.9, 0.85, 0.3), "display", {"pixel_size": 0.02, "outline": 0, "flat": true})
	Kit.label(self, WORDS[i], c + Vector3(0, 0.03, 5.6), 0.0, 32, PALE, "display", {"pixel_size": 0.016, "outline": 0, "flat": true})
	# the crate it is being packed into, stencilled
	var crate := Props.place(self, "crate", c + Vector3(4.6, 0, -4.2), 20.0 + i * 7.0, 1.3)
	Kit.label(self, WORDS[i], c + Vector3(4.6, 0.8, -4.2) + Kit.polar(0.72, -20.0 - i * 7.0 - 90.0), 20.0 + i * 7.0 + 180.0, 18, Color(0.15, 0.15, 0.15), "body", {"pixel_size": 0.01, "outline": 0})
	# the screen, a set the size of a room at the back, still on; the spotlight over the middle
	var side := 1.0 if i % 2 == 0 else -1.0
	var tv := Props.place(self, "tv_crt", c + Vector3(side * (half + 4.2), 0, -1.5), side * 90.0, 4.2, {"collision": "none", "tint": GREY})
	var screen := Props.part(tv, "Screen")
	if screen is MeshInstance3D:
		(screen as MeshInstance3D).set_surface_override_material(0, Kit.static_mat({"brightness": 0.8, "scale": 140.0}))
	var lamp := Kit.light(self, c + Vector3(side * (half + 1.5), 3.5, -1.5), Color(0.8, 0.8, 0.95), 1.0, 12.0)
	var spot := Kit.spot(self, c + Vector3(0, 9.0, 0), c, Color(1.0, 0.97, 0.9), 10.0, 18.0, 40.0)
	var fill := Kit.light(self, c + Vector3(0, 4.5, 0), Color(0.95, 0.93, 0.88), 2.0, 15.0)
	Kit.cylinder(self, c + Vector3(0, 9.0, 0), 0.35, 0.6, "metal/iron", {"solid": false, "tint": Color(0.2, 0.2, 0.22), "segments": 8})
	Kit.cylinder(self, c + Vector3(0, 9.6, 0), 0.06, 30.0, "metal/iron", {"solid": false, "tint": Color(0.2, 0.2, 0.22), "segments": 5})
	stages.append({"c": c, "spot": spot, "screen": screen, "lamp": lamp, "fill": fill, "on": true})
	_struck(i, c)
	# arriving here puts the last stage out
	Kit.trigger(self, c + Vector3(0, 1.5, 0), Vector3(half * 2.0 - 1.0, 3.0, half * 2.0 - 1.0), func(_p: Node) -> void:
		_arrive(i), {"name": "Arrive%d" % i, "once": true})
	Kit.particles(self, c + Vector3(0, 2.0, 0), "motes", Vector3(12.0, 2.5, 12.0), 30)


## What is left of each thing once the set is being struck.
func _struck(i: int, c: Vector3) -> void:
	var g := {"tint": GREY}
	match i:
		0:
			# the cot under a dust sheet, the mobile's pieces in a box
			Props.place(self, "bed_single", c + Vector3(-1.2, 0, 0.4), 90.0, 0.7, g)
			Kit.box(self, c + Vector3(-1.2, 0.62, 0.4), Vector3(1.9, 0.5, 1.2), "fabric/sheet", {"solid": false, "tint": Color(0.85, 0.85, 0.85)})
			Props.place(self, "crate_small", c + Vector3(2.0, 0, 1.0), 30.0, 1.0)
			for k in 3:
				Props.place(self, ["chess_pawn", "chess_knight", "chess_queen"][k], c + Vector3(2.0 + (k - 1) * 0.25, 0.62, 1.0), 0.0, 0.22, {"collision": "none", "tint": PALE, "rotation": Vector3(90, k * 50.0, 0)})
		1:
			# hopscotch in tape, and a chair too small
			for row in 5:
				Kit.box(self, c + Vector3(-2.0 + row * 0.9, 0.012, 1.5), Vector3(0.8, 0.02, 0.8), "", {"tint": Color(0.9, 0.85, 0.3), "solid": false})
				Kit.box(self, c + Vector3(-2.0 + row * 0.9, 0.036, 1.5), Vector3(0.66, 0.02, 0.66), "", {"tint": DARK, "solid": false})
			Props.place(self, "chair", c + Vector3(2.4, 0, -1.6), 200.0, 0.55, g)
			Props.place(self, "chess_pawn", c + Vector3(-3.0, 0, -2.0), 0.0, 1.2, g)
		2:
			# the desk with its chair on top, the rules board face down
			Props.place(self, "desk_office", c + Vector3(0, 0, -1.0), 0.0, 0.85, g)
			Props.place(self, "chair_office", c + Vector3(0, 0.75, -1.0), 30.0, 0.85, {"collision": "none", "tint": GREY, "rotation": Vector3(180, 30, 0)})
			Kit.box(self, c + Vector3(-2.8, 0.08, 1.6), Vector3(2.6, 0.16, 1.9), "stone/blocks_dark", {"tint": Color(0.3, 0.32, 0.3)})
			Kit.sign(self, "metal/clock_face", c + Vector3(2.6, 0.03, 1.8), 0.0, Vector2(0.9, 0.9), {"rotation": Vector3(-90, 0, 0)})
		3:
			# the cabinet on its side, the number that was being served
			Props.place(self, "filing_cabinet", c + Vector3(-1.6, 0.3, -1.0), 0.0, 1.0, {"collision": "box", "tint": GREY, "rotation": Vector3(0, 0, 90)})
			Props.place(self, "ticket_dispenser", c + Vector3(2.0, 0, 0.6), -40.0, 1.0, {"collision": "cylinder", "tint": GREY})
			Props.place(self, "number_display", c + Vector3(0, 1.2, -6.7), 0.0, 1.0, {"collision": "none"})
		4:
			# two chairs stacked, two mugs on the floor
			Props.place(self, "chair", c + Vector3(0, 0, 0.5), 0.0, 1.0, g)
			Props.place(self, "chair", c + Vector3(0.05, 1.02, 0.5), 170.0, 1.0, {"collision": "none", "tint": GREY, "rotation": Vector3(180, 170, 0)})
			Props.place(self, "mug", c + Vector3(-1.4, 0.0, -0.6), 20.0, 1.0, {"collision": "none"})
			Props.place(self, "mug", c + Vector3(-1.1, 0.0, -0.9), 200.0, 1.0, {"collision": "none"})
			Props.place(self, "crate_small", c + Vector3(2.2, 0, -1.4), 0.0, 1.0)
			Props.place(self, "rose_paper_planted", c + Vector3(2.2, 0.6, -1.4), 0.0, 1.0, {"collision": "none", "tint": PALE})
		5:
			# the front door laid flat like a struck flat, the mailbox knocked over
			Props.place(self, "door_white", c + Vector3(-0.5, 0.12, 0.5), 0.0, 1.0, {"collision": "none", "tint": Color(0.8, 0.8, 0.82), "rotation": Vector3(90, 0, 0)})
			Kit.box(self, c + Vector3(2.6, 0.2, -1.0), Vector3(0.08, 1.1, 0.08), "metal/plate", {"tint": GREY, "rotation": Vector3(0, 0, 75)})
			Kit.box(self, c + Vector3(3.15, 0.3, -1.0), Vector3(0.3, 0.3, 0.5), "metal/plate", {"tint": GREY, "rotation": Vector3(0, 0, 75)})
		6:
			# the iron bed stripped to its frame, the drip, the chair
			Props.place(self, "bed_iron", c + Vector3(0, 0, -0.5), 0.0, 1.0, {"tint": Color(0.5, 0.5, 0.55)})
			Kit.cylinder(self, c + Vector3(-1.4, 0.0, -1.2), 0.03, 1.9, "metal/brass", {"segments": 6, "tint": GREY})
			Props.place(self, "chair", c + Vector3(2.0, 0, 0.4), 90.0, 1.0, g)
		7:
			# a circle of light on the floor with nobody in it, and the outline of where they were
			Kit.cylinder(self, c + Vector3(0, 0.03, 0), 2.6, 0.02, "", {"tint": Color(0.95, 0.95, 1.0), "solid": false, "segments": 24})
			for seg in [[Vector3(-0.35, 0, 1.0), Vector3(0.35, 0, 1.0)], [Vector3(-0.4, 0, 1.0), Vector3(-0.5, 0, -0.2)], [Vector3(0.4, 0, 1.0), Vector3(0.5, 0, -0.2)], [Vector3(-0.5, 0, -0.2), Vector3(-0.25, 0, -1.2)], [Vector3(0.5, 0, -0.2), Vector3(0.25, 0, -1.2)], [Vector3(-0.25, 0, -1.2), Vector3(0.25, 0, -1.2)]]:
				var p0: Vector3 = c + seg[0] + Vector3(0, 0.07, 0)
				var p1: Vector3 = c + seg[1] + Vector3(0, 0.07, 0)
				var d := p1 - p0
				var tape := Kit.box(self, (p0 + p1) * 0.5, Vector3(0.08, 0.02, d.length()), "", {"tint": Color(0.9, 0.85, 0.3), "solid": false})
				tape.rotation.y = atan2(-d.x, -d.z)
			Kit.cylinder(self, c + Vector3(0, 0.06, -1.7), 0.32, 0.02, "", {"tint": Color(0.9, 0.85, 0.3), "solid": false, "segments": 12})
			Props.place(self, "gravestone_blank", c + Vector3(3.0, 0.2, 2.0), 30.0, 1.0, {"collision": "none", "tint": GREY, "rotation": Vector3(90, 30, 0)})
	if i == 1 or i == 4 or i == 6:
		Readable.create(self, c + Vector3(0, 1.0, 3.0), 0.0, "Look at the stage", [
			"A stage with its set half struck. Tape on the floor where the thing stood, a sheet over what is left, a crate with its name on it.",
			"The set at the back is still on. It is the last thing they turn off, and they are turning them off behind you.",
		], {"name": "Stage%dLook" % i, "size": Vector3(4.0, 2.0, 2.0), "note_key": "off_air", "note_title": "Off air", "note_text": "Conceding goes to the station shutting down: eight stages out in the dark, on cables, where the same life was played and is being struck, and behind you the lights going out and the channels going off one by one. At the end, a bed."})


## Coming onto a stage puts the one before it out: its light goes, its screen
## goes to a dot and then to nothing, and the card in the sky counts down.
func _arrive(i: int) -> void:
	if i == 0:
		return
	var prev: Dictionary = stages[i - 1]
	if not bool(prev.on):
		return
	prev.on = false
	channels_on -= 1
	Audio.sfx("tv_off", prev.c + Vector3(0, 2.0, -8.0), -4.0)
	var spot: SpotLight3D = prev.spot
	var lamp: OmniLight3D = prev.lamp
	var tw := create_tween().set_parallel(true)
	if is_instance_valid(spot):
		tw.tween_property(spot, "light_energy", 0.0, 1.2)
	if is_instance_valid(lamp):
		tw.tween_property(lamp, "light_energy", 0.0, 0.4)
	var fill: Node = prev.get("fill")
	if fill is OmniLight3D and is_instance_valid(fill):
		tw.tween_property(fill, "light_energy", 0.12, 1.2)
	var screen: Node = prev.screen
	if screen is MeshInstance3D and is_instance_valid(screen):
		(screen as MeshInstance3D).set_surface_override_material(0, Kit.flat(Color(0.03, 0.03, 0.04), {"unshaded": true}))
	if countdown:
		countdown.text = str(channels_on)
	match i:
		1:
			Game.toast.emit("Behind you, the light goes out on the first stage, and the screen goes to a dot.")
		4:
			Game.toast.emit("Four channels left. They are being turned off in the order you walked.")
		7:
			Game.toast.emit("One channel left, and it is the one you are standing under.")


## Cables between the stages, and the road on them.
func _cable_bridge(a: Vector3, b: Vector3) -> void:
	var flat := b - a
	flat.y = 0.0
	var dir := flat.normalized()
	var right := Vector3(-dir.z, 0, dir.x)
	var p0 := a + dir * 6.4
	var p1 := b - dir * 6.4
	var run := p1 - p0
	var along := run.normalized()
	var mid := (p0 + p1) * 0.5
	var yaw := Kit.dir_to_yaw(dir)
	var pitch := rad_to_deg(atan2(p1.y - p0.y, Vector2(run.x, run.z).length()))
	var length := run.length() + 1.0
	Kit.box(self, mid + Vector3(0, -0.15, 0), Vector3(2.0, 0.3, length), PLATE, {"rotation": Vector3(pitch, yaw, 0), "tint": Color(0.66, 0.66, 0.72), "tile": 2.0})
	for sx in [-1.0, 1.0]:
		var rail := Kit.cylinder(self, Vector3.ZERO, 0.16, length, "metal/iron", {"solid": false, "segments": 6, "tint": Color(0.15, 0.15, 0.17)})
		rail.transform = Transform3D(Basis.looking_at(along, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), mid + right * (sx * 1.15) + Vector3(0, 0.9, 0))
		var post_n := int(length / 4.0)
		for k in post_n:
			var t := (k + 0.5) / post_n
			Kit.box(self, p0.lerp(p1, t) + right * (sx * 1.15) + Vector3(0, 0.45, 0), Vector3(0.08, 0.9, 0.08), "metal/iron", {"solid": false, "tint": Color(0.15, 0.15, 0.17)})
		var f := Kit.blocker(self, Vector3.ZERO, Vector3(0.2, 3.0, length))
		f.position = mid + right * (sx * 1.15) + Vector3(0, 1.5, 0)
		f.rotation_degrees = Vector3(pitch, yaw, 0)
	# the cable that carries it all, slung underneath
	var under := Kit.cylinder(self, Vector3.ZERO, 0.28, length, "metal/iron", {"solid": false, "segments": 8, "tint": Color(0.12, 0.12, 0.14)})
	under.transform = Transform3D(Basis.looking_at(along, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), mid - Vector3(0, 0.6, 0))
	Kit.light(self, mid + Vector3(0, 2.5, 0), COLD, 1.1, 16.0)
	Kit.light(self, p0 + Vector3(0, 2.0, 0), COLD, 0.7, 9.0)
	Kit.light(self, p1 + Vector3(0, 2.0, 0), COLD, 0.7, 9.0)


# --- the screens in the dark ------------------------------------------------------------------

func _drift() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for k in 44:
		var t := rng.randf()
		var c := _stage_pos(int(t * 7.0)).lerp(_stage_pos(mini(int(t * 7.0) + 1, 7)), fmod(t * 7.0, 1.0))
		var side := 1.0 if k % 2 == 0 else -1.0
		var p := c + Vector3(side * rng.randf_range(16.0, 40.0), rng.randf_range(-6.0, 18.0), rng.randf_range(-10.0, 10.0))
		var q := p + Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(-3.0, 3.0), rng.randf_range(-6.0, 6.0))
		var cw := Clockwork.create(self, p, {"mode": "path", "points": [Vector3.ZERO, q - p], "speed_deg": rng.randf_range(0.6, 1.6), "name": "Drift%d" % k})
		var tv := Props.place(cw.body, "tv_crt", Vector3.ZERO, rng.randf_range(0.0, 360.0), rng.randf_range(1.2, 3.0), {"collision": "none", "tint": GREY})
		var screen := Props.part(tv, "Screen")
		if screen is MeshInstance3D:
			(screen as MeshInstance3D).set_surface_override_material(0, Kit.static_mat({"brightness": rng.randf_range(0.5, 0.9), "scale": 100.0}))
		if k % 4 == 0:
			Kit.light(cw.body, Vector3(0, 0.5, 1.0), Color(0.7, 0.75, 0.9), 0.5, 8.0)


## The card in the sky over the end, with the count of channels still on.
func _card() -> void:
	var c := _stage_pos(7) + Vector3(0, 60.0, -60.0)
	Kit.sign(self, "signs/test_card", c, 180.0, Vector2(48.0, 36.0), {"unshaded": true})
	Kit.sign(self, "signs/off_air", c + Vector3(0, -17.0, 0), 180.0, Vector2(24.0, 9.0), {"unshaded": true})
	countdown = Kit.label(self, str(channels_on), c + Vector3(0, -26.0, 0), 180.0, 160, Color(0.95, 0.95, 1.0), "display", {"pixel_size": 0.05, "outline": 0})
	Kit.light(self, c + Vector3(0, -20.0, 10.0), Color(0.8, 0.85, 1.0), 1.5, 40.0)


# --- the last stage ------------------------------------------------------------------------------

## Past the last stage, on the cable's end: the one light still on, the bed,
## the one on it, the monitor, and the wall with the socket in it.
func _final() -> void:
	var a := _stage_pos(7)
	var c := a + Vector3(0, 0.6, -STEP)
	_cable_bridge(a, c)
	Kit.cylinder(self, c - Vector3(0, 0.5, 0), 9.0, 0.5, "wall/tile_white", {"tile": 1.5, "tint": Color(0.85, 0.85, 0.9), "segments": 24})
	Kit.ring(self, c + Vector3(0, 0.02, 0), 8.6, 9.0, 24, "metal/iron", {"solid": false, "tint": Color(0.3, 0.3, 0.32)})
	var fence := Kit.round_wall(self, c, 9.0, 3.0, 24, "metal/iron", {"gaps": [[Kit.yaw_to_center(0.0) * 0.0 + 90.0, 24.0]], "solid": true, "tint": Color(0.2, 0.2, 0.22)})
	fence.visible = false
	Props.place(self, "bed_iron", c + Vector3(0, 0, -1.0), 0.0, 1.1)
	# lying on his back, feet at the foot of the bed, head on the pillow
	var usher := Props.place(self, "usher", c + Vector3(0, 0.95, -0.1), 0.0, 0.7, {"collision": "none", "rotation": Vector3(90, 0, 180), "name": "TheOneOnTheBed"})
	_black(usher)
	Props.place(self, "chair", c + Vector3(2.4, 0, -0.6), 90.0, 1.0)
	Props.place(self, "crate", c + Vector3(-2.6, 0, -1.8), 0.0, 0.8)
	var tv := Props.place(self, "tv_crt", c + Vector3(-2.6, 0.7, -1.8), 70.0, 1.0, {"collision": "none"})
	var screen := Props.part(tv, "Screen")
	if screen is MeshInstance3D:
		(screen as MeshInstance3D).set_surface_override_material(0, Kit.static_mat({"brightness": 0.9, "scale": 120.0}))
	# the wall the size of a building, dark, with the socket in it
	Kit.box(self, c + Vector3(0, 12.0, -16.0), Vector3(40.0, 26.0, 1.2), "common/static", {"mat": Kit.static_mat({"brightness": 0.14, "scale": 260.0, "tint": Color(0.7, 0.7, 0.8)})})
	var socket := c + Vector3(0, 1.0, -15.35)
	Kit.box(self, socket, Vector3(2.4, 2.4, 0.16), PLATE, {"tint": Color(0.6, 0.6, 0.66)})
	Kit.box(self, socket + Vector3(0, 0, 0.12), Vector3(0.8, 0.8, 0.14), "metal/iron", {"tint": Color(0.12, 0.12, 0.14)})
	Kit.light(self, socket + Vector3(0, 2.0, 3.0), COLD, 1.2, 10.0)
	var pts := [c + Vector3(-2.9, 0.4, -1.8), c + Vector3(-2.0, 0.05, -6.0), c + Vector3(0, 0.05, -12.0), socket + Vector3(0, 0, 0.2)]
	for k in pts.size() - 1:
		var p0: Vector3 = pts[k]
		var p1: Vector3 = pts[k + 1]
		var d := p1 - p0
		var seg := Kit.cylinder(self, Vector3.ZERO, 0.12, d.length(), "metal/iron", {"solid": false, "segments": 6, "tint": Color(0.12, 0.12, 0.14)})
		seg.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), (p0 + p1) * 0.5)
	Interactable.make(self, socket + Vector3(0, 0, 1.0), Vector3(2.0, 2.4, 1.6), "The plug", _on_plug, {"name": "Plug"})
	var spot := Kit.spot(self, c + Vector3(0, 10.0, 0), c, Color(1.0, 0.98, 0.92), 7.0, 18.0, 34.0)
	Kit.cylinder(self, c + Vector3(0, 10.0, 0), 0.35, 0.6, "metal/iron", {"solid": false, "tint": Color(0.2, 0.2, 0.22), "segments": 8})
	Kit.cylinder(self, c + Vector3(0, 10.6, 0), 0.06, 30.0, "metal/iron", {"solid": false, "tint": Color(0.2, 0.2, 0.22), "segments": 5})
	stages.append({"c": c, "spot": spot, "screen": null, "lamp": null, "on": true})
	Kit.light(self, c + Vector3(-2.6, 1.4, -1.8), Color(0.75, 0.8, 1.0), 0.8, 5.0)
	Kit.trigger(self, c + Vector3(0, 1.5, 3.0), Vector3(8.0, 3.0, 6.0), func(_p: Node) -> void:
		_arrive(8), {"name": "ArriveLast", "once": true})
	Readable.create(self, c + Vector3(0, 0.9, -0.3), 0.0, "Look at the one on the bed", [
		"The one who walked ahead of you in every place you have been, lying still, with his face to the light. He has your face. Everything here has told you that already.",
		"There is a band on his wrist with nothing written on it, and under nothing, in your handwriting, a tick.",
		"The monitor beside him is the last channel. The cable from it goes to the wall.",
	], {"name": "OnTheBed", "size": Vector3(2.2, 1.4, 2.6), "note_key": "usher_bed", "note_title": "The one on the bed", "note_text": "At the end of the stages, under the last light, on an iron bed: the Usher, still, with your face. A cable runs from the monitor beside him to a socket in a wall the size of a building."})
	Readable.create(self, socket + Vector3(0, 0, 2.4), 0.0, "The wall", [
		"A wall as tall as a building and as wide, and nothing on it but the socket. The wall is the picture between channels, up close.",
		"The cable goes into it. Everything still lit out in the dark is on the other end.",
	], {"name": "WallLook", "size": Vector3(4.0, 3.0, 2.0)})


func _black(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = Kit.flat(Color(0.05, 0.05, 0.06), {"unshaded": true})
	for ch in node.get_children():
		_black(ch)


func _on_plug(_p: Node, _it: Node) -> void:
	if World.hud == null:
		return
	var i: int = await World.hud.ask("", "The plug is warm. The monitor is the last channel, and the picture on it is him, and he is you. This is an ending. Pull it?", ["No. Leave it in.", "Pull the plug."])
	if i != 1:
		return
	var y: int = await World.hud.ask("", "There is no coming back from this one. Are you sure?", ["No.", "Yes."])
	if y != 1:
		return
	await Ending.play("unplugged", "Off air", [
		"You pull the plug. The monitor goes to a dot, and out in the dark every screen still lit goes to a dot with it, and the dots stay a while, and go.",
		"The hiss stops. For the first time since you fell asleep, nothing is between channels, because there are no channels.",
		"The one on the bed does not move. He was never going to. It was always going to be you.",
	], Color.WHITE)
