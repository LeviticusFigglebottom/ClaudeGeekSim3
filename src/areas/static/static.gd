extends AreaBase
## The Static — between channels. Where you land when you fall out of a world,
## where the lift goes, where the Usher lives. A grey plain of television snow
## with things half-buried in it. Nothing stays here, including you.

const SIZE := 160.0


func build() -> void:
	Realm.apply(self, "static", {"ambient_energy": 1.2, "fog_density": 0.012, "fog": "#7a7a7a", "bg": "#5a5a5a"})
	# the ground is static
	var ground := Kit.floor(self, Vector3.ZERO, Vector2(SIZE, SIZE), "common/static", {"mat": Kit.static_mat({"brightness": 0.32, "scale": 400.0, "tint": Color(0.85, 0.85, 0.9)}), "surface": "snow", "tile": 4.0})
	ground.name = "Ground"
	# wrap at the edges so there is no edge
	var e := SIZE * 0.5 - 4.0
	SeamlessTeleport.link(self, Vector3(e, 0, 0), -90.0, Vector3(-e, 0, 0), -90.0, Vector3(0.8, 6, SIZE), {"name": "WrapX"})
	SeamlessTeleport.link(self, Vector3(0, 0, e), 180.0, Vector3(0, 0, -e), 180.0, Vector3(SIZE, 6, 0.8), {"name": "WrapZ"})
	# televisions, stacked and scattered, all showing snow
	var stacks := [Vector3(6, 0, -8), Vector3(-9, 0, -3), Vector3(3, 0, 9), Vector3(-5, 0, 12), Vector3(14, 0, 4)]
	for i in stacks.size():
		var base: Vector3 = stacks[i]
		var n := 2 + (i % 3)
		for k in n:
			var tv := Props.place(self, "tv_crt", base + Vector3(rng.randf_range(-0.2, 0.2), k * 0.62, rng.randf_range(-0.2, 0.2)), rng.randf_range(-40, 40) + (180.0 if i % 2 == 0 else 0.0), 1.0, {"collision": "box"})
			var screen := Props.part(tv, "Screen")
			if screen is MeshInstance3D:
				var show_face: bool = Game.count("tv_face_seen") > 0 and i == 2 and k == n - 1
				(screen as MeshInstance3D).set_surface_override_material(0, Kit.mat("props/tv_face", {"unshaded": true}) if show_face else Kit.static_mat({"brightness": 0.8}))
		Kit.light(self, base + Vector3(0, n * 0.62 + 0.4, -0.6), Color(0.75, 0.8, 1.0), 1.6, 8.0)
	Kit.scatter(18, rng, Vector3.ZERO, Vector2(60, 60), func(i: int, p: Vector3) -> void:
		var tv := Props.place(self, "tv_crt", p, rng.randf_range(0, 360), 1.0, {"collision": "box"})
		var screen := Props.part(tv, "Screen")
		if screen is MeshInstance3D:
			(screen as MeshInstance3D).set_surface_override_material(0, Kit.static_mat({"brightness": 0.6}))
		, 14.0)
	# a door standing alone
	var door_pos := Vector3(0, 0, -14)
	Kit.box(self, door_pos + Vector3(0, 1.25, -0.05), Vector3(1.6, 2.5, 0.1), "wall/plaster_cream", {"faces": ["pz", "nz", "px", "nx", "py"], "tint": Color(1.2, 1.15, 1.0)})
	Door.create(self, door_pos, 0.0, "nexus", "from_static", {"kind": "white", "label": "A door with a room behind it", "name": "DoorOut", "fade_color": Color.WHITE, "fade_duration": 0.5})
	Kit.light(self, door_pos + Vector3(0, 2.8, 1.0), Color(1.0, 0.95, 0.85), 2.2, 12.0)
	add_spawn("from_nexus", door_pos + Vector3(0, 0.1, 2.0), 0.0)
	add_spawn("default", Vector3(0, 0.1, 0), 0.0)
	# the lift you arrived in
	var lift := Vector3(-10, 0, 8)
	Kit.box(self, lift + Vector3(0, 1.3, -1.0), Vector3(2.0, 2.6, 0.1), "metal/plate")
	Kit.box(self, lift + Vector3(-1.0, 1.3, 0), Vector3(0.1, 2.6, 2.0), "metal/plate")
	Kit.box(self, lift + Vector3(1.0, 1.3, 0), Vector3(0.1, 2.6, 2.0), "metal/plate")
	Kit.box(self, lift + Vector3(0, 2.6, 0), Vector3(2.0, 0.1, 2.0), "metal/plate")
	Kit.floor(self, lift, Vector2(2.0, 2.0), "wall/carpet_house")
	Kit.sign(self, "signs/now_serving", lift + Vector3(0, 2.2, -0.9), 0.0, Vector2(0.8, 0.4), {"unshaded": true})
	Kit.light(self, lift + Vector3(0, 2.3, 0), Color(0.9, 1.0, 0.9), 0.8, 4.0)
	add_spawn("lift", lift + Vector3(0, 0.1, 0.2), 180.0)
	Readable.create(self, lift + Vector3(0, 1.0, -0.7), 0.0, "The lift buttons", ["There is one button. It says 3. You are on 3.", "You have always been on 3."], {"name": "LiftButtons", "size": Vector3(0.4, 0.6, 0.3), "note_key": "lift_buttons", "note_title": "The lift", "note_text": "One button. It says 3."})
	# the Usher, at home, fully visible, pointing at the door
	Usher.spawn(self, Vector3(4, 0, -9), {"start_visible": true, "vanish_delay": 6.0, "radius": 80.0})
	for i in 3:
		if Props.exists("figure_shadow"):
			Props.place(self, "figure_shadow", Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30)), rng.randf_range(0, 360), 1.0, {"collision": "none"})
	# readables
	Readable.create(self, Vector3(6.3, 1.9, -8.0), 180.0, "Read the screen", ["Between channels there is a room.", "This is the room.", "Sit anywhere. Nothing stays."], {"name": "ScreenText", "size": Vector3(0.7, 0.6, 0.7), "note_key": "static_room", "note_title": "The room between channels", "note_text": "You fell out of a world and landed on the snow between channels. A door stood there with a room behind it. The tall one was waiting."})
	Kit.label(self, "NO SIGNAL", Vector3(0, 4.0, -20), 0.0, 96, Color(0.9, 0.9, 0.9), "body", {"pixel_size": 0.02})
	Kit.particles(self, Vector3(0, 3, 0), "snow", Vector3(40, 4, 40), 120)
	if Game.stats.falls > 0 and not Game.has_note("fell"):
		Game.note("fell", "Falling out", "You fell out of the bottom of a dream. There is snow between the channels, and a door.")


func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	Audio.sfx("static_burst", null, -8.0)
