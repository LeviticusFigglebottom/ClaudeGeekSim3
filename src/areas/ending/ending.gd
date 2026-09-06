extends AreaBase
## The endings, one scene each, chosen by Game.ending_kind (and by the spawn
## the game arrives at). The player is held in a scripted scene: no walking,
## free to look about within an arc, the eyes where the scene puts them.
##
##   whole      room 5½ at night, from the bed: the two of you agree, and
##              somebody says your name. Waking up.
##   limbo      the last square: the pieces turn, the board is the ward, the
##              square is the bed, and you stay. Coming to terms.
##   unplugged  the last stage, the plug in your hand: the screens go to
##              dots, the one on the bed is not in shadow any more, the line
##              holds, the sheet comes up. What it is.
##   m          room 5½ in the afternoon, from the chair: the roses, the
##              book, the photograph, the reading, the light going across the
##              wall; then the book by the door and the way out. The visitor.
##
## Every scene ends with a card and the title screen. The save is left
## in the flat, so continuing goes on from the bed there, with the flag set.

const GREEN := "wall/plaster_green"
const CHECK := "wall/tile_checker"
const TILE := "wall/tile_white"
const PLATE := "metal/plate"
const RED := Color(0.82, 0.24, 0.3)

var kind := "whole"
var _nodes := {}
var _lights := {}
var _done := false


func build() -> void:
	can_wake = false
	# the spawn names the scene when the game arrives; the verifier builds the default
	kind = Game.ending_kind if Game.ending_kind != "" else "whole"
	if World.current_spawn_id in ["whole", "limbo", "unplugged", "m"]:
		kind = World.current_spawn_id
	match kind:
		"limbo":
			_build_limbo()
		"unplugged":
			_build_unplugged()
		"m":
			_build_room(true)
			add_spawn("default", Vector3(2.5, 0.1, 2.6), 90.0)
		_:
			_build_room(false)
			add_spawn("default", Vector3(2.5, 0.1, 2.6), 90.0)
	for k in ["whole", "limbo", "unplugged", "m"]:
		if not spawns.has(k):
			add_spawn(k, spawns["default"].origin, 0.0)


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if player() == null or _done:
		return
	_done = true
	Audio.set_ambience("")
	match kind:
		"limbo":
			_run_limbo()
		"unplugged":
			_run_unplugged()
		"m":
			_run_m()
		_:
			_run_whole()


# --- helpers --------------------------------------------------------------------------------

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _say(lines: Array, who: String = "") -> void:
	if World.hud:
		await World.hud.say(who, lines)


func _tween_light(l: Light3D, energy: float, dur: float, color: Variant = null) -> void:
	if l == null:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "light_energy", energy, dur)
	if color != null:
		tw.tween_property(l, "light_color", color, dur)


func _tween_head(y: float, pitch: float, dur: float) -> void:
	var p := player()
	if p == null:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p.head, "position:y", y, dur)
	tw.tween_method(func(v: float) -> void: p.set_look(p.yaw, v), p.pitch, pitch, dur)


func _black(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = Kit.flat(Color(0.05, 0.05, 0.06), {"unshaded": true})
	for ch in node.get_children():
		_black(ch)


func _screen(tv: Node, mat: Material) -> void:
	var screen := Props.part(tv, "Screen")
	if screen is MeshInstance3D:
		(screen as MeshInstance3D).set_surface_override_material(0, mat)


## The end: the colour, the card over nothing, the save left in the flat,
## and the title.
func _finish(color: Color, title: String, sub: String) -> void:
	var hud = World.hud
	if hud == null:
		return
	await hud.fade_out(color, 4.0)
	Audio.set_ambience("")
	visible = false
	Realm.apply(self, "waking", {"bg": "#" + color.to_html(false), "ambient": "#" + color.to_html(false), "ambient_energy": 1.0, "fog_density": 0.0, "sun": null, "sky": ""})
	hud.fade_in(0.8)
	await _wait(1.2)
	hud.show_area_name(title, sub)
	await _wait(6.4)
	await hud.fade_out(Color.BLACK, 2.0)
	var p := player()
	if p:
		p.set_scene_lock(false)
		p.set_frozen(true)
	Game.reset_toggles()
	World.current_area_id = "apartment"
	World.current_spawn_id = "bed"
	Game.set_flag("has_woken", true)
	Game.save()
	await _wait(0.6)
	hud.show_title()


# --- room 5½ as it is -------------------------------------------------------------------------

## The room the whole game has been drawn from: a bed, a chair with a shape
## in it, a cabinet with a vase and three paper roses, a photograph, a book
## with a ribbon in it, a drip, a set on a crate, a clock at half past five,
## a chart by the door, and a window with the night or the afternoon in it.
func _build_room(daylight: bool) -> void:
	Realm.apply(self, "hospital", {"fog_density": 0.02, "ambient_energy": 0.9 if daylight else 0.55, "bg": "#d9d4c4" if daylight else "#3a4240"})
	var W := 7.0
	var zn := -4.0
	var zs := 5.0
	var H := 3.0
	Kit.floor(self, Vector3(0, 0, (zn + zs) * 0.5), Vector2(W, zs - zn), CHECK, {"tile": 1.0})
	Kit.ceiling(self, Vector3(0, H, (zn + zs) * 0.5), Vector2(W, zs - zn), "wall/ceiling_tile", {"tile": 1.5})
	Kit.wall(self, Vector3(-W * 0.5, 0, zs), Vector3(-W * 0.5, 0, zn), H, GREEN, {"tile": 2.0})
	Kit.wall(self, Vector3(W * 0.5, 0, zn), Vector3(W * 0.5, 0, zs), H, GREEN, {"tile": 2.0})
	Kit.wall(self, Vector3(-W * 0.5, 0, zn), Vector3(W * 0.5, 0, zn), H, GREEN, {"tile": 2.0})
	Kit.wall(self, Vector3(W * 0.5, 0, zs), Vector3(-W * 0.5, 0, zs), H, GREEN, {"tile": 2.0})
	# the door, north
	_nodes["door"] = Props.place(self, "door_white", Vector3(0, 0, zn + 0.08), 0.0, 1.0, {"collision": "box", "name": "RoomDoor"})
	Kit.sign(self, "wall/paper", Vector3(-1.6, 1.6, zn + 0.03), 180.0, Vector2(0.5, 0.7), {"tint": Color(0.95, 0.94, 0.88)})
	Kit.label(self, "5½", Vector3(-1.6, 1.72, zn + 0.05), 180.0, 40, Color(0.2, 0.2, 0.22), "display", {"pixel_size": 0.008, "outline": 0})
	Kit.label(self, "5½", Vector3(0.62, 2.15, zn + 0.05), 180.0, 30, Color(0.25, 0.25, 0.25), "display", {"pixel_size": 0.01, "outline": 0})
	Kit.sign(self, "metal/clock_face", Vector3(1.9, 2.3, zn + 0.03), 180.0, Vector2(0.8, 0.8))
	# the visitors' book on its stand by the door
	var lect := Props.place(self, "lectern", Vector3(-2.4, 0, zn + 1.0), 20.0, 0.9)
	_nodes["lectern"] = lect
	Kit.sign(self, "signs/book_cover", Vector3(-2.4, 1.06, zn + 1.0), 0.0, Vector2(0.34, 0.24), {"rotation": Vector3(-70, 20, 0)})
	# the bed, head to the north
	_nodes["bed"] = Props.place(self, "bed_iron", Vector3(0, 0, 0), 0.0, 1.1, {"collision": "none", "name": "Bed"})
	# the drip
	Kit.cylinder(self, Vector3(-1.2, 0, -0.9), 0.03, 1.9, "metal/brass", {"segments": 6, "solid": false})
	Kit.box(self, Vector3(-1.2, 1.75, -0.9), Vector3(0.18, 0.3, 0.1), "fabric/sheet", {"solid": false, "tint": Color(0.9, 0.95, 1.0)})
	Kit.cylinder(self, Vector3(-1.2, 0.02, -0.9), 0.3, 0.04, PLATE, {"segments": 8, "solid": false})
	# the chair with the shape in it
	_nodes["chair"] = Props.place(self, "chair", Vector3(1.6, 0, 0.4), 90.0, 1.0)
	# the cabinet: the vase and the roses, the photograph, the book
	Kit.box(self, Vector3(1.7, 0.3, -1.1), Vector3(0.6, 0.6, 0.5), "wood/planks_dark", {"tile": 1.0})
	Props.place(self, "vase", Vector3(1.6, 0.6, -1.2), 0.0, 1.0, {"collision": "none"})
	for k in 3:
		var rose := Props.place(self, "rose_paper_planted", Vector3(1.6, 0.96, -1.2) + Kit.polar(0.05, k * 120.0), k * 120.0, 0.9, {"collision": "none"})
		if rose:
			rose.rotation.z = deg_to_rad(-12.0)
	_nodes["photo"] = Props.place(self, "item_photo", Vector3(1.88, 0.66, -1.0), -60.0, 0.9, {"collision": "none", "rotation": Vector3(-75, -60, 0)})
	Kit.box(self, Vector3(1.75, 0.63, -0.95), Vector3(0.3, 0.05, 0.22), "wood/planks_dark", {"solid": false, "tint": Color(0.35, 0.25, 0.2)})
	Kit.sign(self, "signs/book_cover_2", Vector3(1.75, 0.656, -0.95), 0.0, Vector2(0.28, 0.2), {"rotation": Vector3(-90, 0, 0)})
	Kit.box(self, Vector3(1.75, 0.66, -0.84), Vector3(0.02, 0.005, 0.09), "", {"solid": false, "tint": Color(0.7, 0.15, 0.15)})
	# the set on the crate: the last channel
	Props.place(self, "crate", Vector3(-1.7, 0, 1.6), 0.0, 0.7)
	var tv := Props.place(self, "tv_crt", Vector3(-1.7, 0.6, 1.6), 55.0, 0.8, {"collision": "none"})
	_nodes["tv"] = tv
	_screen(tv, Kit.static_mat({"brightness": 0.8}))
	_lights["tv"] = Kit.light(self, Vector3(-1.5, 1.2, 1.4), Color(0.8, 0.85, 1.0), 0.6, 4.0)
	# the window, south
	if daylight:
		Kit.box(self, Vector3(0, 1.7, zs - 0.03), Vector3(1.7, 1.7, 0.04), "", {"solid": false, "mat": Kit.flat(Color(0.98, 0.96, 0.88), {"unshaded": true})})
		for k in 2:
			Kit.box(self, Vector3(0, 1.7, zs - 0.06), Vector3(0.05 if k == 0 else 1.7, 1.7 if k == 0 else 0.05, 0.04), "", {"solid": false, "tint": Color(0.9, 0.9, 0.9)})
		_lights["window"] = Kit.light(self, Vector3(0, 1.9, zs - 0.6), Color(1.0, 0.93, 0.78), 1.5, 9.0)
	else:
		Kit.sign(self, "props/window_night", Vector3(0, 1.7, zs - 0.03), 0.0, Vector2(1.7, 1.7))
		_lights["window"] = Kit.light(self, Vector3(0, 1.9, zs - 0.6), Color(0.55, 0.65, 1.0), 0.4, 7.0)
	# the tube, the red light that is for when the tube fails
	Props.place(self, "fluorescent_light", Vector3(0, H - 0.02, 0.5), 0.0, 1.0, {"collision": "none"})
	_lights["tube"] = Kit.light(self, Vector3(0, H - 0.35, 0.5), Color(0.95, 1.0, 0.92), 1.1 if not daylight else 0.7, 9.0)
	_lights["red"] = Kit.light(self, Vector3(0, H - 0.5, -2.0), Color(1.0, 0.25, 0.2), 0.0, 7.0)
	Props.place(self, "radiator", Vector3(2.9, 0, 3.6), 90.0, 1.0)
	Kit.particles(self, Vector3(0, 1.5, 0.5), "motes", Vector3(5.0, 2.0, 7.0), 30)


# --- whole: waking up ---------------------------------------------------------------------------

func _run_whole() -> void:
	var p := player()
	# lying in the bed, head on the pillow, looking at the ceiling
	p.global_position = Vector3(0, 0.34, -0.55)
	p.set_scene_lock(true, PI, 1.05, deg_to_rad(70.0), -0.2, 1.45, 0.42)
	# the tube is unsteady; the red light is on, a little
	_lights["red"].light_energy = 0.35
	var flick := create_tween().set_loops()
	flick.tween_property(_lights["tube"], "light_energy", 0.5, 0.08)
	flick.tween_property(_lights["tube"], "light_energy", 1.1, 0.35)
	flick.tween_interval(1.3)
	flick.tween_property(_lights["tube"], "light_energy", 0.7, 0.05)
	flick.tween_property(_lights["tube"], "light_energy", 1.1, 0.2)
	flick.tween_interval(2.1)
	await _wait(4.0)
	await _say([
		"The ceiling. Tiles, and the one that is stained, and the tube that hums. You know this ceiling. You have counted its tiles from underneath for longer than you have been anyone else.",
		"On the pillow, by your head, the crown. It is a paper crown. It was always a paper crown.",
	])
	var crown := Props.place(self, "item_crown", Vector3(-0.42, 0.62, -0.75), 20.0, 1.0, {"collision": "none"})
	await _wait(2.5)
	# the tall one, at the foot of the bed, with his hat off
	var usher := Props.place(self, "usher", Vector3(0, 0, 2.3), 0.0, 1.0, {"collision": "none", "name": "TheTallOne"})
	var ulight := Kit.light(self, Vector3(0, 2.2, 2.0), Color(0.9, 0.9, 1.0), 0.0, 6.0)
	_tween_light(ulight, 1.2, 1.5)
	Audio.sfx("static_burst", null, -14.0)
	await _wait(1.0)
	await _say([
		"He stands where he always stood, one room ahead, except that there is no next room. He takes his hat off. He has your face. He always had.",
		"He does not climb in. He was never outside.",
	])
	# the merge: he comes to the bed and is not there, and the crown is not there
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_property(usher, "position", Vector3(0, 0.2, 0.2), 5.0)
	tw.tween_property(usher, "scale", Vector3(0.05, 0.05, 0.05), 5.0)
	tw.tween_property(crown, "scale", Vector3(0.02, 0.02, 0.02), 4.0)
	tw.tween_property(ulight, "light_energy", 0.0, 5.0)
	for k in 5:
		Audio.sfx("heartbeat", null, -8.0 + k * 1.5)
		await _wait(1.0)
	flick.kill()
	_tween_light(_lights["tube"], 1.2, 1.5)
	_tween_light(_lights["red"], 0.0, 1.5)
	usher.visible = false
	crown.visible = false
	await _say([
		"The two of you agree on it. It takes less time than it took to disagree.",
	])
	# the set finds a channel
	Audio.sfx("tv_on", null, -6.0)
	_screen(_nodes["tv"], Kit.mat("signs/test_card", {"unshaded": true}))
	_tween_light(_lights["tv"], 0.9, 1.0, Color(0.9, 0.95, 1.0))
	await _wait(2.0)
	await _say(["The set beside the bed finds a channel. The tone from the machine changes, once, and somewhere down the corridor a nurse looks up."])
	# somebody sits down in the chair
	Audio.sfx("door_open", null, -10.0)
	await _wait(1.6)
	var m := Props.place(self, "patron_seated", Vector3(1.6, 0, 0.4), 90.0, 1.0, {"collision": "none", "name": "M"})
	m.visible = true
	await _wait(0.6)
	Audio.sfx("write", null, -10.0)
	await _wait(1.2)
	Audio.sfx("page", null, -8.0)
	await _say([
		"Somebody sits down in the chair. The chair has her shape and she fits it. You can hear the pen on its chain, and then the book closing, and then nothing, because she has seen your eyes.",
	])
	await _say([
		"Your name.",
		"In the tone you would use for something you were no longer sure was dead.",
	], "M")
	# the light comes up through the window, and you open your eyes
	_tween_light(_lights["window"], 3.0, 6.0, Color(1.0, 0.95, 0.85))
	_tween_light(_lights["tube"], 2.0, 6.0)
	Audio.sfx("wake", null, -4.0)
	await _wait(3.0)
	Game.set_flag("game_finished", true)
	await _finish(Color(0.98, 0.97, 0.94), "ANTEROOM", "you open your eyes.")


# --- limbo: the last square --------------------------------------------------------------------

func _build_limbo() -> void:
	Realm.apply(self, "promotion", {"fog_density": 0.02, "bg": "#0e0a16"})
	Kit.floor(self, Vector3(0, -0.02, 0), Vector2(60.0, 60.0), "common/static", {"mat": Kit.static_mat({"brightness": 0.1, "scale": 400.0, "tint": Color(0.7, 0.68, 0.8)})})
	# the rank of eight squares behind you, and the raised one under you
	for i in 8:
		var col := Color(0.92, 0.9, 0.96) if i % 2 == 0 else Color(0.14, 0.1, 0.18)
		Kit.floor(self, Vector3(0, 0.0, 3.5 + 3.5 * i), Vector2(3.2, 3.2), "wall/tile_white", {"tile": 1.0, "tint": col, "thick": 0.05})
	Kit.floor(self, Vector3(0, 0.12, 0), Vector2(3.2, 3.2), "wall/tile_white", {"tile": 1.0, "thick": 0.12, "tint": Color(1.0, 1.0, 1.0), "name": "LastSquare"})
	_lights["square"] = Kit.light(self, Vector3(0, 4.0, 0), Color(1.0, 1.0, 1.0), 1.4, 10.0)
	Kit.particles(self, Vector3(0, 1.5, 0), "motes", Vector3(2.0, 2.0, 2.0), 40)
	# the giant pawns either side, the toppled queen, the stone
	for sx in [-5.5, 5.5]:
		Props.place(self, "chess_pawn", Vector3(sx, 0, 1.0), 0.0, 2.4, {"collision": "none", "tint": RED})
	Props.place(self, "chess_queen", Vector3(-3.5, 0.55, 5.5), 0.0, 2.4, {"collision": "none", "tint": RED, "rotation": Vector3(0, 30, 90)})
	Props.place(self, "gravestone_you", Vector3(3.5, 0, 4.5), 200.0, 1.1, {"collision": "none"})
	# the pieces along the rank, facing away; they will turn
	var ring: Array = []
	for i in 8:
		var a := i * 45.0 + 22.5
		var model := "chess_pawn" if i % 2 == 0 else "chess_knight"
		var piece := Props.place(self, model, Kit.polar(8.5, a), a + 90.0, 1.3, {"collision": "none", "tint": RED if i % 3 == 0 else Color(0.95, 0.93, 0.9)})
		ring.append(piece)
	_nodes["ring"] = ring
	# the ward, not there yet: beds in two rows, a wall with the clock and the tube
	var ward := Node3D.new()
	ward.name = "Ward"
	ward.visible = false
	add_child(ward)
	for i in 3:
		for sx in [-4.2, 4.2]:
			Props.place(ward, "bed_iron", Vector3(sx, 0, -4.0 - i * 3.6), 0.0, 1.0, {"collision": "none"})
			Props.place(ward, "chair", Vector3(sx + (1.5 if sx > 0 else -1.5), 0, -3.6 - i * 3.6), -90.0 if sx > 0 else 90.0, 0.9, {"collision": "none"})
	Kit.wall(ward, Vector3(-9.0, 0, -15.0), Vector3(9.0, 0, -15.0), 3.0, GREEN, {"tile": 2.0, "solid": false})
	Kit.sign(ward, "metal/clock_face", Vector3(0, 2.3, -14.87), 180.0, Vector2(1.0, 1.0))
	Kit.label(ward, "WARD", Vector3(-4.0, 2.4, -14.87), 180.0, 30, Color(0.3, 0.35, 0.3), "display", {"pixel_size": 0.012})
	for x in [-4.2, 0.0, 4.2]:
		Props.place(ward, "fluorescent_light", Vector3(x, 3.0, -8.0), 0.0, 1.0, {"collision": "none"})
	_lights["ward"] = Kit.light(ward, Vector3(0, 2.6, -8.0), Color(0.95, 1.0, 0.92), 0.0, 14.0)
	_nodes["ward"] = ward
	# the bed the square is, under you, not there yet
	var bed := Props.place(self, "bed_iron", Vector3(0, 0.12, 0), 0.0, 1.1, {"collision": "none", "name": "TheBed"})
	bed.visible = false
	_nodes["bed"] = bed
	var chair := Props.place(self, "chair", Vector3(1.7, 0.12, 0.4), 90.0, 1.0, {"collision": "none"})
	chair.visible = false
	_nodes["chair"] = chair
	add_spawn("default", Vector3(0, 0.3, 0), 0.0)


func _run_limbo() -> void:
	var p := player()
	p.global_position = Vector3(0, 0.24, 0)
	p.set_scene_lock(true, 0.0, 0.0, PI, -1.2, 1.2)
	await _wait(3.5)
	await _say(["You stand on the square. Nothing is put on your head. Nothing needs to be. You are the king in the corner, and you know it now, and knowing it is the promotion."])
	# the pieces turn to face you
	Audio.sfx("stone_grind", null, -8.0)
	for piece in _nodes["ring"]:
		var n := piece as Node3D
		var to := Kit.dir_to_yaw(Vector3.ZERO - n.position)
		var tw := create_tween()
		tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "rotation:y", deg_to_rad(to), 2.5 + randf() * 1.5)
	await _wait(3.5)
	await _say(["The pieces along the rank turn, all of them, the way a ward turns when somebody's eyes move under the lids."])
	# the ward comes up around the board
	var ward: Node3D = _nodes["ward"]
	ward.visible = true
	_tween_light(_lights["ward"], 1.2, 4.0)
	_tween_light(_lights["square"], 0.7, 4.0, Color(0.95, 1.0, 0.92))
	Audio.sfx("tv_on", null, -14.0)
	await _wait(4.0)
	await _say(["The board was the ward with the lights off. The squares were beds. The square you are standing on is a bed, and it was always a bed, and a king in the corner does not stand."])
	# lie down: the square becomes the bed, and the view goes to the ceiling
	_nodes["bed"].visible = true
	_nodes["chair"].visible = true
	p.set_scene_lock(true, PI, 0.0, deg_to_rad(80.0), -0.2, 1.45, 1.55)
	p.global_position = Vector3(0, 0.46, -0.55)
	_tween_head(0.42, 1.05, 4.5)
	Audio.sfx("sleep", null, -8.0)
	await _wait(5.0)
	# the tall one sits down by the bed and stays
	var sitter := Props.place(self, "patron_seated", Vector3(1.7, 0.12, 0.4), 90.0, 1.0, {"collision": "none", "name": "TheOneWhoStays"})
	_black(sitter)
	Audio.sfx("creak", null, -10.0)
	await _wait(1.5)
	await _say([
		"The one who walked ahead of you sits down. There is nowhere ahead to walk to, and he knows it, and now so do you. He keeps you company. That is what he was for.",
	])
	var crown := Props.place(self, "item_crown", Vector3(0.05, 0.72, 0.35), 15.0, 1.0, {"collision": "none"})
	Audio.sfx("pickup", null, -14.0)
	await _wait(1.5)
	await _say(["Somebody puts the paper crown on the blanket. It stays there."])
	# the afternoons: the light goes across and back, three times; somebody comes and goes
	var m := Props.place(self, "patron_seated", Vector3(-1.7, 0.12, 0.4), -90.0, 1.0, {"collision": "none", "name": "M"})
	m.visible = false
	for k in 3:
		_tween_light(_lights["ward"], 1.4, 2.5, Color(1.0, 0.93, 0.8))
		await _wait(2.0)
		m.visible = true
		Audio.sfx("page", null, -10.0)
		await _wait(2.5)
		_tween_light(_lights["ward"], 0.6, 2.5, Color(0.7, 0.75, 0.95))
		await _wait(2.0)
		m.visible = false
		Audio.sfx("clock_chime", null, -14.0)
		await _wait(1.0)
	_tween_light(_lights["ward"], 1.0, 2.0, Color(0.95, 1.0, 0.92))
	await _say([
		"Somebody comes in the afternoons. She reads. The light goes across the wall and back. It is half past five, and then it is half past five.",
		"That is what there is, and you have agreed to it. The board keeps you. The bed keeps you. Nothing is finished with you, and nothing needs to be.",
	])
	crown.visible = true
	await _wait(2.0)
	await _finish(Color(0.1, 0.07, 0.14), "THE LAST RANK", "you stay.")


# --- unplugged: the plug ---------------------------------------------------------------------------

func _build_unplugged() -> void:
	Realm.apply(self, "static", {"bg": "#101014", "ambient": "#5a5a68", "ambient_energy": 0.9, "fog": "#101014", "fog_density": 0.018, "sky": ""})
	Kit.floor(self, Vector3(0, -0.5, 0), Vector2(160.0, 160.0), "common/static", {"mat": Kit.static_mat({"brightness": 0.08, "scale": 500.0, "tint": Color(0.6, 0.6, 0.7)})})
	var c := Vector3.ZERO
	Kit.cylinder(self, c - Vector3(0, 0.5, 0), 9.0, 0.5, TILE, {"tile": 1.5, "tint": Color(0.85, 0.85, 0.9), "segments": 24})
	Kit.ring(self, c + Vector3(0, 0.02, 0), 8.6, 9.0, 24, "metal/iron", {"solid": false, "tint": Color(0.3, 0.3, 0.32)})
	Props.place(self, "bed_iron", c + Vector3(0, 0, -1.0), 0.0, 1.1, {"collision": "none"})
	var usher := Props.place(self, "usher", c + Vector3(0, 0.95, -0.1), 0.0, 0.7, {"collision": "none", "rotation": Vector3(90, 0, 180), "name": "TheOneOnTheBed"})
	_black(usher)
	_nodes["usher"] = usher
	var king := Props.place(self, "king_coma", c + Vector3(0, 0.62, -0.8), 90.0, 1.3, {"collision": "none", "name": "TheKing"})
	king.visible = false
	_nodes["king"] = king
	var sheet := Kit.box(self, c + Vector3(0, 0.72, 0.9), Vector3(1.1, 0.06, 0.2), "fabric/sheet", {"solid": false, "tint": Color(0.92, 0.92, 0.9), "name": "Sheet"})
	sheet.visible = false
	_nodes["sheet"] = sheet
	_nodes["chair"] = Props.place(self, "chair", c + Vector3(2.4, 0, -0.6), 90.0, 1.0, {"collision": "none"})
	Props.place(self, "crate", c + Vector3(-2.6, 0, -1.8), 0.0, 0.8)
	var tv := Props.place(self, "tv_crt", c + Vector3(-2.6, 0.7, -1.8), 70.0, 1.0, {"collision": "none"})
	_nodes["tv"] = tv
	_screen(tv, Kit.static_mat({"brightness": 0.9, "scale": 120.0}))
	_lights["tv"] = Kit.light(self, c + Vector3(-2.6, 1.4, -1.8), Color(0.75, 0.8, 1.0), 0.8, 5.0)
	# the dot, and the line it becomes, on the screen
	var dot := Kit.box(self, c + Vector3(-2.6, 1.0, -1.8), Vector3(0.04, 0.04, 0.04), "", {"solid": false, "mat": Kit.flat(Color(0.7, 1.0, 0.8), {"unshaded": true}), "name": "Dot"})
	dot.rotation.y = deg_to_rad(70.0)
	dot.visible = false
	_nodes["dot"] = dot
	# the wall, the socket, the cable end in your hand
	Kit.box(self, c + Vector3(0, 12.0, -16.0), Vector3(40.0, 26.0, 1.2), "common/static", {"mat": Kit.static_mat({"brightness": 0.14, "scale": 260.0, "tint": Color(0.7, 0.7, 0.8)})})
	var socket := c + Vector3(0, 1.0, -15.35)
	Kit.box(self, socket, Vector3(2.4, 2.4, 0.16), PLATE, {"tint": Color(0.6, 0.6, 0.66)})
	Kit.box(self, socket + Vector3(0, 0, 0.12), Vector3(0.8, 0.8, 0.14), "metal/iron", {"tint": Color(0.12, 0.12, 0.14)})
	_lights["socket"] = Kit.light(self, socket + Vector3(0, 2.0, 3.0), Color(0.7, 0.75, 0.95), 1.2, 10.0)
	var pts := [c + Vector3(-2.9, 0.4, -1.8), c + Vector3(-2.0, 0.05, -6.0), c + Vector3(-0.6, 0.05, -12.0), c + Vector3(0.4, 0.3, -13.2)]
	for k in pts.size() - 1:
		var p0: Vector3 = pts[k]
		var p1: Vector3 = pts[k + 1]
		var d := p1 - p0
		var seg := Kit.cylinder(self, Vector3.ZERO, 0.12, d.length(), "metal/iron", {"solid": false, "segments": 6, "tint": Color(0.12, 0.12, 0.14)})
		seg.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), (p0 + p1) * 0.5)
	# the last light, on a cable from nowhere
	_lights["spot"] = Kit.spot(self, c + Vector3(0, 10.0, 0), c, Color(1.0, 0.98, 0.92), 7.0, 18.0, 34.0)
	Kit.cylinder(self, c + Vector3(0, 10.0, 0), 0.35, 0.6, "metal/iron", {"solid": false, "tint": Color(0.2, 0.2, 0.22), "segments": 8})
	Kit.cylinder(self, c + Vector3(0, 10.6, 0), 0.06, 30.0, "metal/iron", {"solid": false, "tint": Color(0.2, 0.2, 0.22), "segments": 5})
	# out in the dark, everything still lit
	var far: Array = []
	for i in 22:
		var a := i * 16.4 + 7.0
		var r := 22.0 + (i * 7) % 26
		var pos := Kit.polar(r, a, -0.5)
		var set := Props.place(self, "tv_crt", pos, a + 180.0 + (i * 37) % 40 - 20, 1.0 + (i % 3) * 0.3, {"collision": "none"})
		_screen(set, Kit.static_mat({"brightness": 0.7}))
		var l := Kit.light(self, pos + Vector3(0, 0.6, 0), Color(0.75, 0.8, 1.0), 0.9, 7.0)
		far.append({"tv": set, "light": l})
	_nodes["far"] = far
	# where you stand with the plug: a landing of the same tile by the wall
	Kit.floor(self, c + Vector3(0, 0, -12.5), Vector2(7.0, 6.0), TILE, {"tile": 1.5, "tint": Color(0.85, 0.85, 0.9)})
	add_spawn("default", c + Vector3(0.4, 0.1, -12.6), 180.0)


func _run_unplugged() -> void:
	var p := player()
	p.global_position = Vector3(0.4, 0.0, -12.6)
	p.set_scene_lock(true, PI, 0.1, deg_to_rad(85.0), -1.0, 0.9)
	Audio.set_ambience("static", 0.2)
	await _wait(3.0)
	await _say(["The plug is in your hand. It is warm, and then it is not."])
	# every screen still lit goes to a dot
	Audio.sfx("tv_off", null, -6.0)
	var far: Array = _nodes["far"]
	for i in far.size():
		var e: Dictionary = far[i]
		_screen(e.tv, Kit.flat(Color(0.03, 0.03, 0.04), {"unshaded": true}))
		_tween_light(e.light, 0.0, 0.6)
		if i % 4 == 0:
			Audio.sfx("tv_off", null, -16.0)
		await _wait(0.18)
	_screen(_nodes["tv"], Kit.flat(Color(0.03, 0.03, 0.04), {"unshaded": true}))
	_nodes["dot"].visible = true
	_tween_light(_lights["tv"], 0.25, 1.0, Color(0.7, 1.0, 0.8))
	await _wait(1.5)
	await _say(["Every screen still lit goes to a dot, and the dots stay a while, and go."])
	Audio.set_ambience("", 2.0)
	_tween_light(_lights["socket"], 0.2, 3.0)
	await _wait(2.5)
	await _say(["The hiss stops. For the first time since you fell asleep, nothing is between channels, because there are no channels."])
	# the one on the bed is not in shadow any more
	_nodes["usher"].visible = false
	_nodes["king"].visible = true
	_tween_light(_lights["spot"], 5.0, 2.0, Color(0.95, 0.95, 1.0))
	await _wait(2.0)
	await _say([
		"The one on the bed is not black any more. He was only ever in shadow. It is the King's face, and it is yours, and the sheet is a hospital sheet, and the band on his wrist has your name on it after all.",
	])
	# the heart, slowing; the dot with it; then the line
	var gaps := [1.0, 1.0, 1.3, 1.6, 2.1, 2.8, 3.6]
	var dot: Node3D = _nodes["dot"]
	for g in gaps:
		Audio.sfx("heartbeat", null, -6.0)
		dot.scale = Vector3(1.8, 1.8, 1.8)
		var tw := create_tween()
		tw.tween_property(dot, "scale", Vector3.ONE, 0.4)
		_tween_light(_lights["spot"], _lights["spot"].light_energy * 0.85, g)
		await _wait(g)
	var line := create_tween()
	line.tween_property(dot, "scale", Vector3(11.0, 1.0, 1.0), 1.2)
	await _wait(1.5)
	await _say(["The monitor draws its dot out into a line and holds it there."])
	# the sheet comes up
	var sheet: Node3D = _nodes["sheet"]
	sheet.visible = true
	var stw := create_tween()
	stw.set_parallel(true)
	stw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	stw.tween_property(sheet, "position", Vector3(0, 1.0, -0.4), 4.0)
	stw.tween_property(sheet, "scale", Vector3(1.0, 1.0, 12.0), 4.0)
	Audio.sfx("curtain", null, -10.0)
	await _wait(4.5)
	await _say(["Somebody you cannot see draws the sheet up. The hands are careful. They have done it before, for other people, and they are not in a hurry."])
	# somebody sits down
	var m := Props.place(self, "patron_seated", Vector3(2.4, 0, -0.6), 90.0, 1.0, {"collision": "none", "name": "M"})
	Audio.sfx("creak", null, -12.0)
	await _wait(2.0)
	await _say([
		"Somebody sits down in the chair. She does not say your name. There is nobody to say it to. She sits anyway, for the length of an afternoon.",
		"It was always going to be you, and it was always going to be your hand on the plug, and it was.",
	])
	m.visible = true
	_tween_light(_lights["spot"], 0.0, 5.0)
	_tween_light(_lights["tv"], 0.0, 5.0)
	_tween_light(_lights["socket"], 0.0, 5.0)
	Audio.sfx("tv_off", null, -3.0)
	await _wait(4.0)
	await _finish(Color(0.0, 0.0, 0.0), "OFF AIR", "and that is all.")


# --- m: the chair ------------------------------------------------------------------------------

func _run_m() -> void:
	var p := player()
	# the one in the bed, half under the sheet and half in the coat, the hat on the pillow
	Props.place(self, "usher_king", Vector3(0, 0.62, 0.2), 90.0, 1.3, {"collision": "none", "name": "TheOneInTheBed"})
	Props.place(self, "usher", Vector3(-0.6, 0.62, -0.9), 0.0, 0.34, {"collision": "none", "rotation": Vector3(0, 40, 0)}).visible = false
	_lights["window"].light_color = Color(1.0, 0.93, 0.78)
	# sitting in the chair, facing the bed
	p.global_position = Vector3(1.6, 0.0, 0.4)
	p.set_scene_lock(true, PI * 0.5, -0.2, deg_to_rad(80.0), -0.95, 0.7, 1.12)
	Audio.set_ambience("apartment", 3.0)
	await _wait(3.5)
	await _say(["You sit in the chair by the bed and it fits, because from here it is yours. You are M. You have sat in it every afternoon for longer than you can count."])
	await _say([
		"Half of him is under the sheet, and half of him is in the coat you brought in from the flat because they said familiar things help. The hat is on the pillow. His face is the face on the chart, and the chart says 5½, and you have stopped asking what the half is.",
	])
	await _say(["Three roses, folded from the pages of the book he liked. You made one each visit for three visits. The nurses let you keep them, which they do not have to."])
	await _say(["The photograph from the drawer at home. In it he is standing in a doorway, about to say something. He has been about to say it for two years."])
	await _say(["The line on the set goes up and down and up. It has been doing that without your help."])
	# the reading
	Audio.sfx("page", null, -8.0)
	await _wait(0.8)
	await _say([
		"\"...and the door at the end of the hall had not been there the day before, and she measured it anyway, because measuring was what she had, and it came to six feet and one half, and she wrote that down.\"",
		"\"She did not open it. Not that day. That day she went back to bed, and slept, and in the morning it was still there, which was the worst of it, and the best.\"",
	], "M")
	Audio.sfx("page", null, -8.0)
	# the light goes across the wall; the ward goes on outside
	_tween_light(_lights["window"], 0.9, 12.0, Color(0.95, 0.7, 0.55))
	_tween_light(_lights["tube"], 1.0, 12.0)
	await _wait(3.0)
	Audio.sfx("phone_ring", null, -18.0)
	await _wait(3.0)
	Audio.sfx("door_close", null, -18.0)
	await _wait(3.0)
	await _say([
		"The light goes across the wall. A phone rings somewhere and is answered. His breathing does not change. It was never going to, and you knew that when you folded the first one.",
		"You come anyway. That is all this is: the coming anyway.",
	])
	# up, and the book by the door, and out
	p.set_scene_lock(false)
	p.global_position = Vector3(2.1, 0.0, 1.3)
	p.set_look(PI * 0.5, 0.0)
	Interactable.make(self, Vector3(-2.4, 1.0, -3.0), Vector3(1.2, 1.4, 1.2), "Sign the book, and go", _on_sign, {"name": "VisitorsBook"})
	Game.toast.emit("The book by the door, the way you always do. Then home.")


func _on_sign(_p: Node, _it: Node) -> void:
	if _nodes.has("signed"):
		return
	_nodes["signed"] = true
	var p := player()
	p.set_scene_lock(true, p.yaw, p.pitch, deg_to_rad(40.0), -1.0, 0.6)
	Audio.sfx("write", null, -6.0)
	await _wait(1.2)
	await _say(["One letter, the way you always sign it. The nurse at the desk does not look up; she knows the letter."])
	Audio.sfx("door_open", null, -6.0)
	await _wait(0.8)
	var out := Kit.light(self, Vector3(0, 1.6, -3.5), Color(1.0, 0.98, 0.9), 0.0, 8.0)
	_tween_light(out, 4.0, 3.0)
	await _wait(1.0)
	await _say(["On the way out you go past the desk, and the lift that is a lift, and the doors that are doors, and out into the afternoon, which is ordinary.", "Tomorrow you come back."])
	await _finish(Color(0.97, 0.95, 0.9), "THE VISITOR", "tomorrow you come back.")
