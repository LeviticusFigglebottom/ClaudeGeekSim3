extends AreaBase
## Off Air — the Static with the set turned off. Where pulling the plug goes.
## The same eight things as the last rank, born to buried, but here every one
## of them is a television showing snow, and the snow is the ground, and the
## way between them is the only firm thing. At the end a bed, and on the bed
## the one who ushered you, and a cable from him to a socket in a wall of
## snow, and the plug is in your hand.
##
## No route needs a fall. Holding R wakes you.

const SIZE := 200.0
const STEP := 13.0
const GREY := Color(0.62, 0.62, 0.66)
const PALE := Color(0.82, 0.82, 0.86)
const WORDS := ["BORN", "SMALL", "TAUGHT", "KEPT", "LOVED", "HOME", "KEPT AGAIN", "OFF"]


func build() -> void:
	can_wake = true
	Realm.apply(self, "static", {"fog_density": 0.02, "ambient_energy": 1.1})
	Kit.floor(self, Vector3(0, 0, -50), Vector2(SIZE, SIZE), "common/static", {"mat": Kit.static_mat({"brightness": 0.34, "scale": 400.0, "tint": Color(0.8, 0.8, 0.86)}), "surface": "snow", "tile": 4.0})
	# the firm way: a strip of plate the sets stand along
	Kit.floor(self, Vector3(0, 0.03, -3.5 * STEP), Vector2(4.0, 8.0 * STEP + 8.0), "metal/plate", {"tile": 2.0, "thick": 0.06, "tint": PALE})
	for i in 8:
		_station(i)
	_bed()
	add_spawn("from_banquet", Vector3(0, 0.1, 5.0), 0.0)
	add_spawn("default", Vector3(0, 0.1, 5.0), 0.0)
	Kit.light(self, Vector3(0, 12, -45), Color(0.8, 0.8, 0.9), 0.6, 120.0)
	Kit.particles(self, Vector3(0, 2, -45), "motes", Vector3(10, 3, 60), 50)
	Puzzle.declare(self, "off_air", "ending_unplugged", [], "walk the sets to the bed at the end and pull the plug")


## A television the size of a wardrobe, showing snow, with the station's one
## thing in front of it, grey and half sunk in the snow.
func _tv_set(pos: Vector3, yaw: float, scale: float = 2.6) -> void:
	var tv := Props.place(self, "tv_crt", pos, yaw, scale, {"collision": "box", "tint": GREY})
	var screen := Props.part(tv, "Screen")
	if screen is MeshInstance3D:
		(screen as MeshInstance3D).set_surface_override_material(0, Kit.static_mat({"brightness": 0.75, "scale": 90.0}))
	Kit.light(self, pos + Vector3(0, 1.4 * scale, 0) + Kit.yaw_to_dir(yaw) * 1.2, Color(0.85, 0.85, 0.95), 0.9, 7.0)


func _station(i: int) -> void:
	var c := Vector3(0, 0, -i * STEP)
	var sx := 1.0 if i % 2 == 0 else -1.0
	_tv_set(c + Vector3(sx * 5.0, 0, 0), sx * 90.0)
	if i < 7:
		_tv_set(c + Vector3(-sx * 5.5, 0, -4.0), -sx * 90.0, 1.6)
	Kit.label(self, WORDS[i], c + Vector3(0, 0.06, 3.0), 0.0, 30, PALE, "display", {"pixel_size": 0.016, "outline": 0, "flat": true})
	var g := {"tint": GREY}
	match i:
		0:
			Props.place(self, "bed_single", c + Vector3(sx * 2.4, -0.35, 0), 0.0, 0.6, g)
			for k in 3:
				Props.place(self, "chess_pawn", c + Vector3(sx * 2.4 + (k - 1) * 0.6, 0.9, 0), 0.0, 0.35, {"collision": "none", "tint": PALE})
		1:
			Props.place(self, "chess_pawn", c + Vector3(sx * 2.6, -0.3, 0.5), 0.0, 1.6, g)
			Props.place(self, "chair", c + Vector3(sx * 3.4, -0.2, -1.5), 30.0, 0.6, g)
		2:
			Props.place(self, "desk_office", c + Vector3(sx * 2.6, -0.3, 0), 0.0, 0.85, g)
			Kit.sign(self, "metal/clock_face", c + Vector3(sx * 5.0, 3.2, 2.2), sx * 90.0, Vector2(0.9, 0.9), {"tint": GREY})
		3:
			Props.place(self, "filing_cabinet", c + Vector3(sx * 2.6, -0.4, 0.6), 0.0, 1.0, g)
			Props.place(self, "ticket_dispenser", c + Vector3(sx * 2.8, -0.3, -1.4), 0.0, 1.0, {"collision": "none", "tint": GREY})
		4:
			Props.place(self, "table_round", c + Vector3(sx * 2.6, -0.3, 0), 0.0, 1.0, g)
			Props.place(self, "chair", c + Vector3(sx * 3.6, -0.3, 0), sx * 90.0, 1.0, g)
			Props.place(self, "rose_paper_planted", c + Vector3(sx * 2.6, 0.5, 0), 0.0, 1.2, {"collision": "none", "tint": PALE})
		5:
			Props.place(self, "door_white", c + Vector3(sx * 2.6, -0.3, 0), -sx * 60.0, 1.0, g)
			Kit.box(self, c + Vector3(sx * 3.4, 0.55, 1.6), Vector3(0.08, 1.1, 0.08), "metal/plate", {"tint": GREY})
			Kit.box(self, c + Vector3(sx * 3.4, 1.25, 1.6), Vector3(0.3, 0.3, 0.5), "metal/plate", {"tint": GREY})
		6:
			Props.place(self, "bed_iron", c + Vector3(sx * 2.6, -0.25, 0), 0.0, 1.0, g)
			Props.place(self, "chair", c + Vector3(sx * 4.0, -0.2, 0.8), sx * 90.0, 1.0, g)
		7:
			Props.place(self, "gravestone_blank", c + Vector3(sx * 2.8, -0.2, 0.5), sx * 30.0, 1.0, g)
	if i == 2 or i == 5:
		Readable.create(self, c + Vector3(0, 1.0, 0), 0.0, "Look at the sets", [
			"Sets showing snow, one to each thing. The things are grey and half under, the way things get under snow that is not cold.",
			"The snow is not falling. It is what is left when the picture is taken away, and it goes down for ever.",
		], {"name": "Sets%d" % i, "size": Vector3(3.0, 2.0, 2.0), "note_key": "off_air", "note_title": "Off air", "note_text": "Pulling the plug goes to the Static with the set turned off: the eight things of the last rank again, each one a television showing snow, and at the end a bed."})


## The bed at the end, the one who ushered you on it, the set that watches
## him, and the cable from the set to the socket in the wall.
func _bed() -> void:
	var c := Vector3(0, 0, -8 * STEP - 6.0)
	var floor_ := Kit.floor(self, c, Vector2(12.0, 10.0), "wall/tile_white", {"tile": 1.5, "thick": 0.1, "tint": Color(0.85, 0.85, 0.9)})
	floor_.name = "WardFloor"
	Props.place(self, "bed_iron", c + Vector3(0, 0, -1.0), 0.0, 1.1)
	# lying on his back, feet at the foot of the bed, head on the pillow
	var usher := Props.place(self, "usher", c + Vector3(0, 0.95, -0.1), 0.0, 0.7, {"collision": "none", "rotation": Vector3(90, 0, 180), "name": "TheOneOnTheBed"})
	_black(usher)
	Props.place(self, "chair", c + Vector3(2.4, 0, -0.6), 90.0, 1.0)
	# the set that watches him, on its trolley, and the cable to the wall
	Props.place(self, "crate", c + Vector3(-2.6, 0, -1.8), 0.0, 0.8)
	var tv := Props.place(self, "tv_crt", c + Vector3(-2.6, 0.7, -1.8), 70.0, 1.0, {"collision": "none"})
	var screen := Props.part(tv, "Screen")
	if screen is MeshInstance3D:
		(screen as MeshInstance3D).set_surface_override_material(0, Kit.static_mat({"brightness": 0.9, "scale": 120.0}))
	Kit.cylinder(self, c + Vector3(-1.4, 0.75, -1.0), 0.03, 1.2, "metal/iron", {"solid": false, "segments": 5, "rotation": Vector3(0, 0, 90)})
	# the wall of snow behind, the socket in it, the cable running down to it
	Kit.box(self, c + Vector3(-5.0, 2.0, -3.0), Vector3(0.6, 4.0, 10.0), "common/static", {"mat": Kit.static_mat({"brightness": 0.42, "scale": 80.0, "tint": Color(0.85, 0.85, 0.9)})})
	var socket := c + Vector3(-4.68, 0.5, -2.0)
	Kit.box(self, socket, Vector3(0.06, 0.3, 0.3), "metal/plate")
	Kit.box(self, socket + Vector3(0.06, 0, 0), Vector3(0.1, 0.16, 0.16), "metal/iron", {"tint": Color(0.2, 0.2, 0.22)})
	var a := c + Vector3(-2.9, 0.4, -1.8)
	var cable_pts := [a, a + Vector3(-0.6, -0.35, -0.1), a + Vector3(-1.2, -0.38, -0.2), socket + Vector3(0.2, -0.05, 0.1)]
	for k in cable_pts.size() - 1:
		var p0: Vector3 = cable_pts[k]
		var p1: Vector3 = cable_pts[k + 1]
		var mid := (p0 + p1) * 0.5
		var d := p1 - p0
		var seg := Kit.cylinder(self, Vector3.ZERO, 0.03, d.length(), "metal/iron", {"solid": false, "segments": 5, "tint": Color(0.15, 0.15, 0.16)})
		seg.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), mid)
	Interactable.make(self, socket + Vector3(0.3, 0, 0), Vector3(0.8, 0.8, 0.8), "The plug", _on_plug, {"name": "Plug"})
	Kit.light(self, c + Vector3(0, 3.2, -1.0), Color(0.9, 0.92, 1.0), 1.2, 9.0)
	Kit.light(self, c + Vector3(-2.6, 1.4, -1.8), Color(0.75, 0.8, 1.0), 0.8, 5.0)
	Readable.create(self, c + Vector3(0, 0.9, -0.3), 0.0, "Look at the one on the bed", [
		"The one who walked ahead of you in every place you have been, lying still, with his face to the ceiling. He has your face. Everything here has told you that already.",
		"There is a band on his wrist with nothing written on it, and under nothing, in your handwriting, a tick.",
		"The set beside him shows snow. The cable from it goes to the wall.",
	], {"name": "OnTheBed", "size": Vector3(2.2, 1.4, 2.6), "note_key": "usher_bed", "note_title": "The one on the bed", "note_text": "At the end of the sets, on an iron bed: the Usher, still, with your face. A cable runs from the set beside him to a socket in the wall of snow."})


func _black(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = Kit.flat(Color(0.05, 0.05, 0.06), {"unshaded": true})
	for ch in node.get_children():
		_black(ch)


func _on_plug(_p: Node, _it: Node) -> void:
	if World.hud == null:
		return
	var i: int = await World.hud.ask("", "The plug is warm. The set is the only thing keeping the picture on, and the picture is him, and he is you. This is an ending. Pull it?", ["No. Leave it in.", "Pull the plug."])
	if i != 1:
		return
	var y: int = await World.hud.ask("", "There is no coming back from this one. Are you sure?", ["No.", "Yes."])
	if y != 1:
		return
	await Ending.play("unplugged", "Off air", [
		"You pull the plug. The set does not go dark at once. It goes to a dot, and the dot stays a while, and then that goes too.",
		"The snow stops going down. For the first time since you fell asleep, nothing is between channels, because there are no channels.",
		"The one on the bed does not move. He was never going to. It was always going to be you.",
	], Color.WHITE)
