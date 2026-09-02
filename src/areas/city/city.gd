extends AreaBase
## The Drowned City — it forgot its name before you arrived.
##
## One long street of tall dark houses that wraps around on itself (walk off
## the east end and you come in at the west), somebody standing in the lit
## windows, a square with a fountain that runs upward, a cathedral whose crypt
## keeps four bells and one small one, a palace where stone knights let only
## the crowned through, and a lower town gone under black water to the knee.
## The second time you come the water is higher and the bridge is gone.
##
## Layout (x east, z south, north is -Z):
##   main street   z in [-4.5, 4.5], x in [-32, 32]; the seams are at x = ±32
##                 and the street repeats every 64 m (phantom copies past them)
##   gate street   south from x = 0 to the city gate (the Anteroom) at z = 23
##   west gate     north from x = -24 to the forest road at z = -22.5
##   the square    north of x in [4, 24]; the cathedral (x 8..22) beyond it,
##                 the crypt under the churchyard west of the nave
##   the palace    south of the street, x in [-25, -11]
##   drowned lane  south from x in [16, 24] down into the flooded lower town
##   the alley     south at x in [-9, -6.5] (where the tavern's back door lands)

const SH := 4.5
const SEAM_X := 32.0
const PERIOD := 64.0
const PHANTOM := 40.0
const DEPTH := 8.0
const LOW_Y := -0.55
const CHANNEL_Y := -2.6
const CRYPT_Y := -5.25
const CRYPT_C := Vector3(-11.0, CRYPT_Y, -37.5)
const CRYPT_R := 6.0
const COOL := Color(0.78, 0.85, 1.0)
const WARM := Color(1.0, 0.78, 0.5)
const CANDLE := Color(1.0, 0.85, 0.6)
const DARK := "stone/blocks_dark"
const BELL_ORDER := [0, 1, 2, 3]
const BELL_ANGLES := [270.0, 0.0, 90.0, 180.0]
const BELL_NAMES := ["XII", "III", "VI", "IX"]
const NO_NUMBER_TARGETS := [["city", "alley"], ["city", "west_gate"], ["city", "from_tower"], ["city", "sewer_top"], ["city", "default"]]

## Main-street houses: [x0, x1, height, texture, extra window faces, flags]. Height 0 = an opening.
const NORTH := [
	[-32.0, -27.0, 11.0, "stone/blocks_city", "e", ""],
	[-27.0, -21.0, 0.0, "", "", ""],                        # the west gate street
	[-21.0, -16.0, 9.0, "brick/dark", "w", ""],
	[-16.0, -12.0, 7.0, "wood/planks_dark", "", "nodoor"],  # the house with no number (one storey of windows; the balcony is the other)
	[-12.0, -6.0, 13.0, "stone/blocks_city", "", ""],
	[-6.0, 0.0, 10.0, "brick/dark", "", ""],
	[0.0, 4.0, 12.0, "stone/blocks_dark", "e", ""],
	[4.0, 24.0, 0.0, "", "", ""],                           # the square
	[24.0, 32.0, 28.0, "stone/blocks_clocktower", "w", "tower nodoor"],
]
const SOUTH := [
	[-32.0, -25.0, 10.0, "brick/dark", "", ""],
	[-25.0, -11.0, 0.0, "palace", "", ""],
	[-11.0, -9.0, 9.0, "stone/blocks_city", "e", ""],
	[-9.0, -6.5, 0.0, "", "", ""],                          # the alley
	[-6.5, -4.0, 8.0, "wood/planks_dark", "we", ""],
	[-4.0, 4.0, 0.0, "", "", ""],                           # the gate street
	[4.0, 10.0, 11.0, "stone/blocks_city", "w", ""],
	[10.0, 16.0, 9.0, "wood/planks_dark", "es", ""],
	[16.0, 24.0, 0.0, "", "", ""],                          # drowned lane
	[24.0, 32.0, 12.0, "brick/dark", "ws", ""],
]

var water_y := -0.02
var bells_puzzle: Puzzle = null
var bell_pivots: Array = []
var rung: Array = []
var bell_pickup: Pickup = null
var bell_cage: Node3D = null
var watcher: Node3D = null
var rains: Array = []


func build() -> void:
	water_y = 0.22 if visit_count >= 2 else -0.02
	Realm.apply(self, "city", {"fog_density": 0.03, "sky_opts": {"detail_strength": 0.25}})
	Kit.floor(self, Vector3(0, -9.0, 0), Vector2(260.0, 200.0), DARK, {"tile": 8.0})
	_module(0.0, false, -SEAM_X, SEAM_X)
	_module(PERIOD, true, SEAM_X, SEAM_X + PHANTOM)
	_module(-PERIOD, true, -SEAM_X - PHANTOM, -SEAM_X)
	for sx in [-1.0, 1.0]:
		Kit.box(self, Vector3(sx * (SEAM_X + PHANTOM + 0.5), 8.0, 0), Vector3(1.0, 16.0, SH * 2.0 + DEPTH * 2.0 + 2.0), DARK, {"tint": Color(0.45, 0.47, 0.52), "tile": 2.0})
	SeamlessTeleport.link(self, Vector3(SEAM_X, 0, 0), -90.0, Vector3(-SEAM_X, 0, 0), -90.0, Vector3(SH * 2.0 + 1.0, 4.0, 0.6), {"name": "Wrap", "count_flag": "city_wraps", "on_teleport": _on_wrap})
	_street_things()
	_gate_street()
	_west_gate()
	_square()
	_cathedral()
	_crypt()
	_palace()
	_alley()
	_lower_town()


# --- the main street: one module, built three times ----------------------------

func _module(ox: float, phantom: bool, lo: float, hi: float) -> void:
	var x := lo
	while x < hi - 0.01:
		var w := minf(8.0, hi - x)
		Kit.floor(self, Vector3(x + w * 0.5, 0, 0), Vector2(w, SH * 2.0), "stone/cobble_city", {"tile": 2.0})
		x += w
	_row(NORTH, -1, ox, phantom, lo, hi)
	_row(SOUTH, 1, ox, phantom, lo, hi)
	for p in [[-30.0, -1], [-12.7, -1], [-3.0, -1], [30.5, -1], [-27.0, 1], [-10.2, 1], [12.5, 1], [28.0, 1]]:
		var lx: float = ox + float(p[0])
		if lx < lo or lx > hi:
			continue
		var side := int(p[1])
		_lantern(Vector3(lx, 0, side * (SH - 1.1)), -90.0 if side < 0 else 90.0)
	for cx in [-9.0, -2.0]:
		if ox + cx > lo and ox + cx < hi:
			Props.place(self, "chain_hanging", Vector3(ox + cx, 9.0, -SH + 0.25), 0.0, 1.0, {"collision": "none"})
	if ox + 28.0 > lo and ox + 28.0 < hi:
		Props.place(self, "chain_hanging", Vector3(ox + 28.0, 10.0, SH - 0.25), 0.0, 1.0, {"collision": "none"})
	if ox - 8.8 > lo and ox - 8.8 < hi:
		Props.place(self, "banner_eye", Vector3(ox - 8.8, 7.6, -SH + 0.3), 180.0, 1.0, {"collision": "none"})
	if ox + 26.0 > lo and ox + 26.0 < hi:
		Props.place(self, "banner_eye", Vector3(ox + 26.0, 8.0, SH - 0.3), 0.0, 1.0, {"collision": "none"})


func _row(specs: Array, side: int, ox: float, phantom: bool, lo: float, hi: float) -> void:
	for s in specs:
		var spec: Array = s
		var x0 := ox + float(spec[0])
		var x1 := ox + float(spec[1])
		if x1 <= lo or x0 >= hi:
			continue
		var h := float(spec[2])
		var tex := String(spec[3])
		var flags := String(spec[5])
		var opts := {"ox": ox, "phantom": phantom, "nodoor": flags.contains("nodoor"), "tower": flags.contains("tower")}
		if tex == "":
			if phantom:
				_stub(x0, x1, side)
			continue
		if tex == "palace":
			if phantom:
				_building(x0, x1, SH, SH + DEPTH, 12.0, "stone/blocks_city", "n", opts)
			else:
				_palace_front()
			continue
		var faces := ("s" if side < 0 else "n") + String(spec[4])
		if side < 0:
			_building(x0, x1, -SH - DEPTH, -SH, h, tex, faces, opts)
		else:
			_building(x0, x1, SH, SH + DEPTH, h, tex, faces, opts)


## A solid house x0..x1, z0..z1, `h` tall: cornice, pitched roof, and on every
## face named in `faces` ("n","s","e","w") rows of windows, a door on the first.
func _building(x0: float, x1: float, z0: float, z1: float, h: float, tex: String, faces: String, opts: Dictionary = {}) -> void:
	var base := float(opts.get("base", 0.0))
	var ox := float(opts.get("ox", 0.0))
	var phantom := bool(opts.get("phantom", false))
	var tower := bool(opts.get("tower", false))
	var c := Vector3((x0 + x1) * 0.5, (base + h) * 0.5, (z0 + z1) * 0.5)
	var size := Vector3(x1 - x0, h - base, z1 - z0)
	Kit.box(self, c, size, tex, {"tile": 2.0})
	Kit.box(self, Vector3(c.x, h + 0.2, c.z), Vector3(size.x + 0.5, 0.4, size.z + 0.5), DARK, {"solid": false, "tile": 1.0})
	if tower:
		for k in 5:
			Kit.box(self, Vector3(x0 + 0.7 + k * (size.x - 1.4) / 4.0, h + 0.9, z1 - 0.45), Vector3(0.9, 1.4, 0.9), tex, {"tile": 1.0})
			Kit.box(self, Vector3(x0 + 0.45, h + 0.9, z0 + 0.7 + k * (size.z - 1.4) / 4.0), Vector3(0.9, 1.4, 0.9), tex, {"tile": 1.0})
	elif faces.contains("n") or faces.contains("s"):
		Kit.ramp(self, Vector3(c.x, h + 0.4, z1), 0.0, size.x, size.z * 0.5, 2.4, "wood/planks_dark", {"solid": false, "tile": 1.5})
		Kit.ramp(self, Vector3(c.x, h + 0.4, z0), 180.0, size.x, size.z * 0.5, 2.4, "wood/planks_dark", {"solid": false, "tile": 1.5})
	else:
		Kit.ramp(self, Vector3(x1, h + 0.4, c.z), 90.0, size.z, size.x * 0.5, 2.4, "wood/planks_dark", {"solid": false, "tile": 1.5})
		Kit.ramp(self, Vector3(x0, h + 0.4, c.z), -90.0, size.z, size.x * 0.5, 2.4, "wood/planks_dark", {"solid": false, "tile": 1.5})
	var first := true
	for f in faces:
		var fc := String(f)
		var out := _out(fc)
		var yaw := _yaw_of(fc)
		var along := Vector3(1, 0, 0) if (fc == "n" or fc == "s") else Vector3(0, 0, 1)
		var fcen := Vector3(c.x, 0, z0 if fc == "n" else z1) if along.x > 0.5 else Vector3(x1 if fc == "e" else x0, 0, c.z)
		var length := size.x if along.x > 0.5 else size.z
		var n := maxi(1, int((length - 1.4) / 2.2) + 1)
		var y := base + 2.8
		var row := 0
		while y + 1.0 < h - 0.6 and row < 4:
			for i in n:
				var p := fcen + along * ((i - (n - 1) * 0.5) * 2.2) + Vector3(0, y, 0) + out * 0.07
				var lit := _lit(p, ox)
				Props.place(self, "window_lit" if lit else "window_night", p, yaw, 1.0, {"collision": "none"})
				if lit and row < (1 if phantom else 2):
					Kit.light(self, p + out * 0.5, WARM, 0.5, 4.5)
			y += 3.0
			row += 1
		if first and length >= 3.0 and not tower and not bool(opts.get("nodoor", false)):
			var dp := fcen + along * (1.9 - length * 0.5) + out * 0.02
			Kit.sign(self, "wood/door_dark", dp + Vector3(0, base + 1.05, 0), yaw, Vector2(1.0, 2.1))
			Kit.box(self, dp + out * 0.3 + Vector3(0, base + 0.07, 0), Vector3(absf(along.x) * 1.4 + absf(out.x) * 0.6, 0.14, absf(along.z) * 1.4 + absf(out.z) * 0.6), "stone/smooth_grey", {"tile": 1.0})
		if h >= 11.0 and not tower:
			Props.place(self, "gargoyle", fcen + Vector3(0, h + 0.4, 0) + out * 0.35, yaw, 1.0, {"collision": "none"})
		if tower:
			Kit.sign(self, "metal/clock_face", fcen + Vector3(0, h * 0.72, 0) + out * 0.06, yaw, Vector2(4.6, 4.6))
			Kit.light(self, fcen + Vector3(0, h * 0.72, 0) + out * 2.0, COOL, 1.0, 12.0)
		first = false


## Which windows are lit is a fixed pattern of the house's place in the street,
## so the phantom copies past the seams light up exactly like the real thing.
func _lit(p: Vector3, ox: float) -> bool:
	var k := int(roundf((p.x - ox) * 2.0)) * 73856093 + int(roundf(p.z * 2.0)) * 19349663 + int(roundf(p.y * 2.0)) * 83492791
	k = (k ^ (k >> 13)) * 1274126177
	return posmod(k ^ (k >> 16), 100) < 34


## A side street's mouth in a phantom copy: seven metres of it, then a wall.
func _stub(x0: float, x1: float, side: int) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	Kit.floor(self, Vector3(cx, 0, side * (SH + 3.5)), Vector2(w, 7.0), "stone/cobble_city", {"tile": 2.0})
	Kit.box(self, Vector3(cx, 5.0, side * (SH + 7.2)), Vector3(w + 0.4, 10.0, 0.4), DARK, {"tile": 2.0})
	if w > 5.0:
		_lantern(Vector3(x0 + 1.2, 0, side * (SH + 5.5)), -90.0)


static func _out(f: String) -> Vector3:
	match f:
		"n": return Vector3(0, 0, -1)
		"s": return Vector3(0, 0, 1)
		"e": return Vector3(1, 0, 0)
	return Vector3(-1, 0, 0)


static func _yaw_of(f: String) -> float:
	match f:
		"n": return 0.0
		"s": return 180.0
		"e": return -90.0
	return 90.0


func _lantern(pos: Vector3, yaw: float) -> void:
	Props.place(self, "lantern_post_city", pos, yaw, 1.0, {"collision": "cylinder"})
	Kit.light(self, pos + Kit.yaw_to_dir(yaw - 90.0) * 0.5 + Vector3(0, 3.5, 0), COOL, 1.25, 9.0)


func _torch(pos: Vector3, yaw: float) -> void:
	Props.place(self, "torch_wall", pos, yaw, 1.0, {"collision": "none"})
	Kit.light(self, pos + Kit.yaw_to_dir(yaw) * 0.45 + Vector3(0, 0.7, 0), Color(1.0, 0.62, 0.3), 1.3, 8.0)


## An iron plate with words on it. The Readable is the caller's business.
func _plate(pos: Vector3, yaw: float, text: String, w: float = 2.4) -> void:
	var out := Kit.yaw_to_dir(yaw)
	Kit.box(self, pos + out * 0.03, Vector3(w, 0.5, 0.06), "metal/iron", {"solid": false, "yaw": yaw, "tile": 1.0})
	Kit.label(self, text, pos + out * 0.075, yaw, 30, Color(0.85, 0.82, 0.7), "display", {"pixel_size": 0.011, "outline": 6})


func _figure(pos: Vector3, yaw: float) -> Node3D:
	return Props.place(self, "figure_shadow", pos, yaw, 1.0, {"collision": "none"})


## Doors, signs, watchers and litter that belong only to the real street.
func _street_things() -> void:
	rains.append(Kit.particles(self, Vector3(0, 9.0, 0), "rain", Vector3(33.0, 2.0, 5.0), 420))
	# two names for one street
	_plate(Vector3(-29.5, 3.1, -SH + 0.05), 180.0, "KING'S WAY", 2.8)
	Readable.create(self, Vector3(-29.5, 3.1, -SH + 0.2), 180.0, "Read the street sign", [
		"KING'S WAY. The plate is older than the wall it is bolted to.",
		"Somebody has scratched out KING and written it back in, smaller.",
	], {"name": "SignKings", "size": Vector3(2.8, 0.6, 0.4), "offset": Vector3.ZERO, "note_key": "city_street_name", "note_title": "The long street", "note_text": "The long street is called King's Way at one end and Queen's Way at the other. It is the same street. It goes round."})
	_plate(Vector3(27.0, 3.1, SH - 0.05), 0.0, "QUEEN'S WAY", 3.0)
	Readable.create(self, Vector3(27.0, 3.1, SH - 0.2), 0.0, "Read the street sign", [
		"QUEEN'S WAY. Under it, older paint: KING'S WAY. Under that, a name that has been scraped off the stone entirely.",
		"You have walked this street. It is the same street. It did not say so.",
	], {"name": "SignQueens", "size": Vector3(3.0, 0.6, 0.4), "offset": Vector3.ZERO})
	# the house with no number, whose door opens on the city again, elsewhere
	Door.create(self, Vector3(-14.0, 0, -SH), 180.0, "", "", {"kind": "dark", "label": "A house with no number", "name": "NoNumberDoor",
		"unstable": _no_number_target, "possible_targets": NO_NUMBER_TARGETS, "fade_color": Color(0.02, 0.02, 0.03), "fade_duration": 1.3, "sound": "door_creak_long"})
	Kit.label(self, "12", Vector3(-19.1, 2.5, -SH + 0.04), 180.0, 40, Color(0.8, 0.78, 0.7), "body", {"pixel_size": 0.012})
	Kit.label(self, "16", Vector3(-10.1, 2.5, -SH + 0.04), 180.0, 40, Color(0.8, 0.78, 0.7), "body", {"pixel_size": 0.012})
	Readable.create(self, Vector3(-12.85, 1.5, -SH + 0.15), 180.0, "A door with no number", [
		"The houses either side are 12 and 16. This one has a nail where a number was.",
		"The door is not locked. You can tell from here. It has the look of a door that has been opened from inside, recently, by someone who did not come out.",
	], {"name": "NoNumberRead", "size": Vector3(0.6, 1.6, 0.3), "offset": Vector3.ZERO, "note_key": "city_no_number", "note_title": "The house with no number", "note_text": "Between 12 and 16 on the long street there is a house with a nail where its number was. Its door opens onto the city again, somewhere else in it."})
	# a watcher on its balcony
	Kit.box(self, Vector3(-14.0, 5.0, -SH + 0.4), Vector3(2.2, 0.14, 0.8), DARK, {"solid": false, "tile": 1.0})
	Props.place(self, "window_lit", Vector3(-14.0, 5.8, -SH + 0.07), 180.0, 1.3, {"collision": "none"})
	Kit.light(self, Vector3(-14.0, 5.8, -SH + 1.0), WARM, 0.8, 6.0)
	watcher = _figure(Vector3(-14.0, 5.07, -SH + 0.45), 180.0)
	LookAway.create(self, Vector3(-14.0, 6.1, -SH + 0.45), _on_watcher_unseen, {"name": "WatcherWatch", "radius": 16.0, "delay": 3.0, "require_seen_first": true, "once": true, "dot_threshold": 0.92})
	# the tower door
	Door.create(self, Vector3(28.0, 0, -SH), 180.0, "clocktower", "from_city", {"kind": "iron", "label": "The tower door", "name": "TowerDoor",
		"requires_item": "tower_key", "locked_text": "A keyhole shaped like a clock hand.", "fade_color": Color(0.08, 0.06, 0.02), "sound": "key_turn"})
	_torch(Vector3(26.4, 2.8, -SH + 0.1), 180.0)
	_torch(Vector3(29.6, 2.8, -SH + 0.1), 180.0)
	_plate(Vector3(30.6, 1.6, -SH + 0.05), 180.0, "THE HOUR", 1.4)
	Readable.create(self, Vector3(30.6, 1.6, -SH + 0.2), 180.0, "Read the plate by the tower door", [
		"THE TOWER KEEPS THE HOUR. THE HOUR KEEPS THE KEY.",
		"Somebody has added, with a nail: the palace keeps the other thing. ask the knights. they will not answer.",
	], {"name": "TowerPlate", "size": Vector3(1.4, 0.6, 0.4), "offset": Vector3.ZERO, "note_key": "city_tower_plate", "note_title": "The tower door", "note_text": "The clocktower's door on the long street has a keyhole shaped like a clock hand. The plate beside it says the palace keeps the other thing."})
	add_spawn("from_tower", Vector3(28.0, 0.1, -2.6), 180.0)
	# litter
	Props.place(self, "cart_broken", Vector3(8.0, 0, 3.0), 15.0, 1.0)
	Props.place(self, "rubble_pile", Vector3(-1.0, 0, -3.5), 0.0, 0.9)
	Props.place(self, "rubble_pile", Vector3(23.0, 0, 3.4), 110.0, 0.7)
	Props.place(self, "barrel", Vector3(-30.5, 0, 3.3), 0.0, 1.0)
	Props.place(self, "crate", Vector3(-29.4, 0, 3.5), 25.0, 0.8)
	Kit.sign(self, "signs/graffiti_wake", Vector3(-4.05, 1.4, 7.0), 90.0, Vector2(1.5, 0.45))


# --- the gate street and the city gate ---------------------------------------------

func _gate_street() -> void:
	Kit.floor(self, Vector3(0, 0, 13.85), Vector2(8.0, 18.7), "stone/cobble_city", {"tile": 2.0})
	_building(-10.0, -4.0, 12.9, 22.0, 11.0, "stone/blocks_city", "e")
	_building(4.0, 10.0, 12.5, 22.0, 9.0, "brick/dark", "we")
	var g := Vector3(0, 0, 23.0)
	for sx in [-1.0, 1.0]:
		Kit.box(self, g + Vector3(sx * 6.0, 7.0, 0), Vector3(4.0, 14.0, 6.0), "stone/blocks_city", {"tile": 2.0})
		for k in 3:
			Kit.box(self, g + Vector3(sx * 6.0 - 1.4 + k * 1.4, 14.6, -2.5), Vector3(0.8, 1.2, 0.8), "stone/blocks_city", {"tile": 1.0})
		_torch(g + Vector3(sx * 3.9, 2.6, -2.0), -90.0 if sx < 0 else 90.0)
	Kit.arch(self, g, 0.0, 8.0, 6.5, "stone/blocks_city", {"depth": 2.0, "post": 0.6, "top": 0.8, "tile": 1.0})
	Kit.box(self, g + Vector3(0, 10.9, 0), Vector3(8.0, 7.2, 2.0), "stone/blocks_city", {"tile": 2.0})
	for k in 5:
		Kit.box(self, g + Vector3(-3.2 + k * 1.6, 15.1, -0.6), Vector3(0.8, 1.2, 0.8), "stone/blocks_city", {"tile": 1.0})
	# the gate: a wall under the arch with an iron door in it, the portcullis half raised above
	var wz := 0.14
	Kit.box(self, g + Vector3(-2.3, 3.25, wz), Vector3(3.5, 6.5, 0.2), DARK, {"tile": 1.0})
	Kit.box(self, g + Vector3(2.3, 3.25, wz), Vector3(3.5, 6.5, 0.2), DARK, {"tile": 1.0})
	Kit.box(self, g + Vector3(0, 4.6, wz), Vector3(1.2, 3.8, 0.2), DARK, {"tile": 1.0})
	Door.create(self, g, 0.0, "nexus", "from_city", {"kind": "iron", "label": "The city gate", "name": "CityGate", "fade_color": Color(0.05, 0.05, 0.1), "sound": "door_heavy"})
	Props.place(self, "portcullis", g + Vector3(0, 4.3, -0.8), 0.0, 2.7, {"collision": "none"})
	Kit.box(self, g + Vector3(0, 3.25, 0.85), Vector3(8.0, 6.5, 1.2), DARK, {"tile": 2.0})
	Kit.light(self, g + Vector3(0, 5.6, -2.5), COOL, 1.2, 10.0)
	Kit.light(self, g + Vector3(0, 2.2, -1.6), Color(0.85, 0.8, 0.7), 0.9, 6.0)
	Kit.particles(self, g + Vector3(0, 5.0, -1.2), "motes", Vector3(3.0, 2.0, 1.0), 20)
	_plate(g + Vector3(-3.95, 1.7, -1.4), -90.0, "ULLE", 1.5)
	Readable.create(self, g + Vector3(-3.8, 1.7, -1.4), -90.0, "Read the plaque", [
		"THE FREE CITY OF ULLE WELCOMES THE WAKING.",
		"The letters of the name are deeper than the others, as if they had been cut twice. Or cut out, and put back by someone who was guessing.",
	], {"name": "GatePlaque", "size": Vector3(0.3, 0.6, 1.5), "offset": Vector3.ZERO, "note_key": "city_plaque_1", "note_title": "The plaque at the gate", "note_text": "The plaque at the city gate says the city is called Ulle. The letters look put back. Nothing else in the city agrees."})
	Props.place(self, "rubble_pile", g + Vector3(3.0, 0, -4.2), 40.0, 0.8)
	Props.place(self, "signpost", Vector3(-3.2, 0, 6.2), 30.0, 1.0, {"collision": "cylinder"})
	Readable.create(self, Vector3(-3.2, 0, 6.2), 0.0, "Read the signpost", [
		"THE GATE. THE OTHER GATE. THE WATER.",
		"A fourth board has been taken off. Its nail holes point straight down.",
	], {"name": "GateSignpost", "size": Vector3(0.9, 2.5, 0.9)})
	add_spawn("from_nexus", g + Vector3(0, 0.1, -3.5), 0.0)
	add_spawn("default", g + Vector3(0, 0.1, -3.5), 0.0)
	Dog.maybe_spawn(self, Vector3(2.0, 0.1, 15.0))


# --- the west gate: the road to the Hollow Wood -----------------------------------

func _west_gate() -> void:
	Kit.floor(self, Vector3(-24.0, 0, -13.6), Vector2(6.0, 18.2), "stone/cobble_city", {"tile": 2.0})
	_building(-33.0, -27.0, -22.5, -12.5, 10.0, "wood/planks_dark", "e")
	_building(-21.0, -15.0, -22.5, -12.5, 12.0, "stone/blocks_city", "w")
	var g := Vector3(-24.0, 0, -22.5)
	Kit.arch(self, g, 0.0, 6.0, 5.5, "stone/blocks_city", {"depth": 1.6, "post": 0.8, "top": 0.9, "tile": 1.0})
	Kit.box(self, g + Vector3(0, 8.4, 0), Vector3(7.6, 4.0, 1.6), "stone/blocks_city", {"tile": 2.0})
	Door.create(self, g, 0.0, "forest", "road", {"kind": "none", "label": "The road out, into the wood", "name": "WestGate", "fade_color": Color(0.05, 0.1, 0.09), "fade_duration": 1.0, "sound": "wind_gust"})
	Kit.label(self, "THE HOLLOW WOOD", g + Vector3(0, 6.9, 0.85), 180.0, 34, Color(0.7, 0.85, 0.8), "display", {"pixel_size": 0.014})
	Kit.floor(self, Vector3(-24.0, 0, -27.5), Vector2(7.0, 9.0), "ground/dirt", {"tile": 3.0, "surface": "grass"})
	Kit.floor(self, Vector3(-24.0, -0.02, -34.0), Vector2(30.0, 12.0), "nature/grass_dark", {"tile": 3.0})
	Props.place(self, "tree_dead_1", Vector3(-28.6, 0, -29.5), 30.0, 1.1, {"collision": "cylinder", "collision_scale": 0.3})
	Props.place(self, "tree_dead_2", Vector3(-19.4, 0, -30.5), 200.0, 1.0, {"collision": "cylinder", "collision_scale": 0.3})
	Props.place(self, "tree_pine_1", Vector3(-31.5, -0.2, -32.0), 80.0, 1.0, {"collision": "none"})
	Kit.box(self, Vector3(-24.0, 3.5, -33.2), Vector3(16.0, 7.0, 1.4), "nature/roots", {"tile": 1.5})
	Kit.blocker(self, Vector3(-24.0, 3.0, -31.6), Vector3(16.0, 6.0, 0.4))
	Kit.particles(self, Vector3(-24.0, 2.0, -28.0), "motes", Vector3(4.0, 1.5, 4.0), 30)
	_lantern(Vector3(-26.6, 0, -20.0), -90.0)
	_lantern(Vector3(-21.4, 0, -9.0), 90.0)
	Kit.light(self, g + Vector3(0, 4.5, 1.5), Color(0.6, 0.9, 0.8), 1.2, 9.0)
	Kit.sign(self, "signs/graffiti_wake", Vector3(-20.95, 2.0, -16.0), 90.0, Vector2(1.4, 0.42))
	Readable.create(self, Vector3(-20.85, 2.0, -16.0), 90.0, "Read the graffiti", [
		"WAKE UP, in paint that ran before it dried.",
		"Under it, in chalk, neater: we did. it was this.",
	], {"name": "GraffitiWest", "size": Vector3(0.3, 0.6, 1.5), "offset": Vector3.ZERO})
	Props.place(self, "cart_broken", Vector3(-26.3, 0, -11.0), 200.0, 0.9)
	add_spawn("west_gate", g + Vector3(0, 0.1, 3.5), 180.0)


# --- the square, the churchyard, the fountain that runs upward --------------------

func _square() -> void:
	for i in 5:
		Kit.floor(self, Vector3(14.0, 0, -6.5 - i * 4.0), Vector2(20.0, 4.0), "stone/cobble_city", {"tile": 2.0})
	_building(-2.0, 4.0, -24.5, -12.5, 10.0, "brick/dark", "e")
	_building(24.0, 30.0, -24.5, -12.5, 11.0, "stone/blocks_city", "w")
	Kit.box(self, Vector3(23.0, 2.5, -24.7), Vector3(2.0, 5.0, 0.4), "stone/blocks_city", {"tile": 1.0})
	# the churchyard, west of the nave
	Kit.floor(self, Vector3(6.0, 0.01, -27.25), Vector2(4.0, 5.5), "nature/grass_dark", {"tile": 2.0, "surface": "grass"})
	Kit.box(self, Vector3(3.8, 2.0, -27.25), Vector3(0.4, 4.0, 5.5), "stone/blocks_city", {"tile": 1.0})
	Kit.box(self, Vector3(6.0, 2.0, -30.2), Vector3(4.8, 4.0, 0.4), "stone/blocks_city", {"tile": 1.0})
	Props.place(self, "gravestone_you", Vector3(5.0, 0, -28.6), 180.0, 1.0)
	Readable.create(self, Vector3(5.0, 0, -28.6), 180.0, "Read the stone", [
		"The stone has your name on it. Under the name, where the dates go, somebody has carved a small bell.",
		"The grass in front of it has not been walked on. You are walking on it.",
	], {"name": "YourStoneCity", "size": Vector3(1.0, 1.2, 0.8), "note_key": "city_your_stone", "note_title": "A stone in the churchyard", "note_text": "In the churchyard beside the cathedral there is a stone with your name on it and a small bell carved where the dates should be."})
	Props.place(self, "gravestone_blank", Vector3(7.0, 0, -28.9), 172.0, 1.0)
	Readable.create(self, Vector3(7.0, 0, -28.9), 180.0, "Read the blank stone", [
		"No name. The stone is smooth where a name would go, as if it had been polished off by hands.",
		"Somebody has left a coin on top. The coin has a wave on both sides. It is not yours to take. It is stuck.",
	], {"name": "BlankStoneCity", "size": Vector3(1.0, 1.2, 0.8)})
	Props.place(self, "gravestone_blank", Vector3(6.3, 0, -26.5), 190.0, 0.9)
	Props.place(self, "tree_dead_2", Vector3(4.9, 0, -25.4), 70.0, 0.7, {"collision": "cylinder", "collision_scale": 0.3})
	Kit.light(self, Vector3(6.0, 2.4, -27.5), Color(0.6, 0.7, 0.75), 0.7, 6.0)
	# the fountain
	var f := Vector3(14.0, 0, -14.0)
	Props.place(self, "fountain", f, 0.0, 1.0, {"collision": "cylinder"})
	Readable.create(self, f + Vector3(0, 0.3, 2.6), 0.0, "Look at the fountain", [
		"The fountain runs upward. The water climbs out of the basin, up the figure, and goes back into the spout, quietly, without splashing.",
		"The figure on top has no face. It is holding its hand out, palm up, the way you hold a hand out for rain.",
	], {"name": "FountainLook", "size": Vector3(2.4, 1.0, 0.6), "sound": "drip", "note_key": "city_fountain", "note_title": "The fountain in the square", "note_text": "The fountain in the square runs upward. The faceless figure on top holds a hand out for rain."})
	Kit.light(self, f + Vector3(0, 2.4, 0), Color(0.6, 0.75, 1.0), 1.2, 11.0)
	Kit.particles(self, f + Vector3(0, 2.6, 0), "motes", Vector3(1.5, 1.5, 1.5), 30)
	# the stall that sells nothing
	Props.place(self, "market_stall", Vector3(8.0, 0, -9.5), -90.0, 1.0)
	Readable.create(self, Vector3(9.25, 0.95, -9.5), -90.0, "Read the menu", [
		"Chalked on a board: TODAY — NOTHING. FISH (drowned). CANDLES (wet). THE NAME OF THE CITY (out of stock).",
		"The prices have been rubbed out and replaced with the word LATER.",
	], {"name": "StallMenu", "sign": "signs/menu", "sign_size": Vector2(0.75, 0.55), "size": Vector3(0.8, 0.6, 0.1), "offset": Vector3.ZERO, "note_key": "city_menu", "note_title": "The stall in the square", "note_text": "Today: nothing. Fish, drowned. Candles, wet. The name of the city, out of stock."})
	if visit_count < 2:
		Props.place(self, "stool", Vector3(8.4, 0, -12.2), -90.0, 1.0, {"collision": "none"})
		NPC.create(self, Vector3(8.4, 0, -12.2), -90.0, "the Stallholder", {"model": "patron_seated", "face_player": false, "name": "Stallholder", "on_talk": _stall_talk,
			"lines": [
				"\"What do I sell? Nothing,\" says the stallholder. \"It's all gone under. I sell the standing here.\"",
				"\"You can have some. It's free. Everyone who comes through takes some without noticing.\"",
				"\"The city had a name, you know. It went under first. Names are heavy.\"",
			],
			"reactions": {
				"crown": ["\"Majesty.\" The stallholder does not get up. \"You'll be wanting the good nothing. It's the same nothing. I put it on a cloth.\""],
				"bell": ["\"Don't ring that near the water,\" the stallholder says, quickly. \"The water remembers bells. It came up for one once.\""],
				"lantern": ["\"Careful with that. Half this street only exists in the dark, and the other half only exists in the light, and nobody's told them.\""],
				"umbrella": ["\"Oh, don't. It's not the rain. It's the tide. An umbrella just makes it feel unwelcome.\""],
			}})
	else:
		Readable.create(self, Vector3(8.4, 0, -12.2), -90.0, "An empty stool", ["The stallholder is not here. The stool is still warm, which it should not be, in this rain."], {"model": "stool", "collision": "none", "size": Vector3(0.6, 0.6, 0.6), "name": "EmptyStool"})
	Props.place(self, "signpost", Vector3(21.5, 0, -8.0), 20.0, 1.0, {"collision": "cylinder"})
	Readable.create(self, Vector3(21.5, 0, -8.0), 0.0, "Read the signpost", [
		"THE GATE. THE OTHER GATE. THE SEA (drowned).",
		"The arms point in three directions. None of them is where those things are. The arm for the sea points down.",
	], {"name": "SquareSignpost", "size": Vector3(0.9, 2.5, 0.9)})
	_lantern(Vector3(5.2, 0, -6.6), -90.0)
	_lantern(Vector3(22.8, 0, -6.6), 90.0)
	_lantern(Vector3(5.6, 0, -22.4), -90.0)
	_lantern(Vector3(22.6, 0, -22.4), 90.0)
	# the cathedral's face
	_torch(Vector3(13.0, 3.0, -24.35), 180.0)
	_torch(Vector3(17.0, 3.0, -24.35), 180.0)
	Props.place(self, "banner_eye", Vector3(10.5, 7.8, -24.3), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "banner_eye", Vector3(19.5, 7.8, -24.3), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "gargoyle", Vector3(8.8, 9.4, -24.2), 180.0, 1.0, {"collision": "none"})
	Props.place(self, "gargoyle", Vector3(21.2, 9.4, -24.2), 180.0, 1.0, {"collision": "none"})
	Kit.sign(self, "props/rune_ring", Vector3(15.0, 6.8, -24.44), 180.0, Vector2(2.6, 2.6))
	Kit.light(self, Vector3(15.0, 5.0, -22.5), WARM, 1.2, 10.0)
	_plate(Vector3(19.3, 1.7, -24.45), 180.0, "THE CITY OF", 2.4)
	Readable.create(self, Vector3(19.3, 1.7, -24.3), 180.0, "Read the plaque", [
		"THE CITY OF — and then nothing. The name has been chiselled out, carefully, by someone who took their time.",
		"The chisel marks are older than the letters around them. The city forgot its name before the plaque was made, and had it cut anyway, out of habit.",
	], {"name": "ForgotPlaque", "size": Vector3(2.4, 0.6, 0.4), "offset": Vector3.ZERO, "note_key": "city_plaque_2", "note_title": "The plaque that forgot", "note_text": "The plaque on the cathedral says THE CITY OF and then nothing. The gate says Ulle. The chisel marks are older than the letters."})
	Props.place(self, "rubble_pile", Vector3(4.9, 0, -18.5), 0.0, 1.0)
	Props.place(self, "cart_broken", Vector3(23.0, 0, -16.5), -70.0, 1.0)
	Usher.spawn(self, Vector3(21.0, 0, -20.0), {"appear_delay": 3.0, "radius": 30.0})
	rains.append(Kit.particles(self, Vector3(14.0, 9.0, -14.5), "rain", Vector3(10.0, 2.0, 10.0), 220))


# --- the cathedral: one map, nine metres tall ---------------------------------------

func _cathedral() -> void:
	var rects := [[1, 1, 13, 25, "n"]]
	var doors := [[6, 25, "D"], [7, 25, "D"], [0, 12, "D"], [0, 13, "D"]]
	var rows := MapBuilder.rasterize(14, 26, rects, doors)
	MapBuilder.build(self, rows, {"cell": 1.0, "height": 9.0, "origin": Vector3(8, 0, -50.5), "door_h": 4.0, "tile": 2.0,
		"floor": "stone/flagstone", "wall": "stone/blocks_city", "ceiling": "wood/planks_dark",
		"rooms": {"n": {"floor": "stone/flagstone", "wall": "stone/blocks_city", "ceiling": "wood/planks_dark"}},
		"outer_faces": true, "wall_tops": true, "name": "Cathedral"})
	for zz in [-46.0, -42.0, -38.0, -34.0, -30.0]:
		for xx in [11.2, 18.8]:
			Props.place(self, "pillar_city", Vector3(xx, 0, zz), 0.0, 1.6, {"collision": "cylinder"})
	for i in 6:
		var zz := -27.5 - i * 1.6
		Props.place(self, "bench", Vector3(13.3, 0, zz), 0.0, 1.0)
		Props.place(self, "bench", Vector3(16.7, 0, zz), 0.0, 1.0)
	var altar := Vector3(15.0, 0, -47.6)
	Props.place(self, "altar", altar, 0.0, 1.0)
	Readable.create(self, altar + Vector3(0, 0.6, 0.6), 0.0, "Look at the carving over the altar", [
		"Over the altar a clock face is carved into the wall. It has no hands. Around the rim, worn but readable:",
		"THE HOURS ARE STRUCK IN THEIR ORDER. TWELVE. THREE. SIX. NINE.",
		"Below it, smaller: the bells beneath keep the hours the tower forgot.",
	], {"name": "ClockCarving", "size": Vector3(2.0, 1.2, 0.7), "note_key": "city_clock_carving", "note_title": "The carving over the altar", "note_text": "The hours are struck in their order: twelve, three, six, nine. The bells beneath the cathedral keep the hours the tower forgot."})
	Kit.sign(self, "metal/clock_face", Vector3(15.0, 4.6, -49.44), 180.0, Vector2(2.8, 2.8))
	Props.place(self, "candle_tall", altar + Vector3(-1.5, 0, 0.3), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "candle_tall", altar + Vector3(1.5, 0, 0.3), 0.0, 1.0, {"collision": "none"})
	Kit.light(self, altar + Vector3(0, 1.6, 0.6), CANDLE, 1.5, 9.0)
	Props.place(self, "lectern", Vector3(12.4, 0, -45.4), -35.0, 1.0)
	Readable.create(self, Vector3(12.4, 0.9, -45.4), -35.0, "Read the register", [
		"The register of the drowned. Every line is the same name, in the same hand, and the name is the word WATER.",
		"The last entry is not dry yet.",
	], {"name": "Register", "size": Vector3(0.8, 0.7, 0.8), "note_key": "city_register", "note_title": "The register of the drowned", "note_text": "In the cathedral there is a register of the drowned. Every entry is the same name and the name is water. The last one is still wet."})
	Props.place(self, "candle_cluster", Vector3(18.4, 0, -45.6), 0.0, 1.2, {"collision": "none"})
	Kit.light(self, Vector3(18.4, 0.9, -45.6), CANDLE, 0.9, 6.0)
	for zz in [-44.0, -36.0, -28.0]:
		Props.place(self, "lantern_hanging_long", Vector3(15.0, 8.9, zz), 0.0, 1.0, {"collision": "none"})
		Kit.light(self, Vector3(15.0, 5.6, zz), WARM, 1.2, 11.0)
	for zz in [-45.0, -39.0, -33.0]:
		Props.place(self, "window_night", Vector3(9.06, 5.5, zz), -90.0, 1.4, {"collision": "none"})
		Props.place(self, "window_night", Vector3(20.94, 5.5, zz), 90.0, 1.4, {"collision": "none"})
		Kit.light(self, Vector3(9.9, 5.5, zz), COOL, 0.6, 6.0)
		Kit.light(self, Vector3(20.1, 5.5, zz), COOL, 0.6, 6.0)
	Props.place(self, "banner_eye", Vector3(12.1, 6.6, -42.0), -90.0, 1.0, {"collision": "none"})
	Props.place(self, "banner_eye", Vector3(17.9, 6.6, -34.0), 90.0, 1.0, {"collision": "none"})
	Props.place(self, "chain_hanging", Vector3(10.3, 9.0, -31.0), 0.0, 0.7, {"collision": "none"})
	Kit.particles(self, Vector3(15.0, 4.0, -38.0), "motes", Vector3(5.0, 3.0, 11.0), 70)
	Kit.label(self, "the crypt", Vector3(9.06, 4.4, -37.5), -90.0, 26, Color(0.7, 0.68, 0.6), "body", {"pixel_size": 0.012})
	Readable.create(self, Vector3(20.9, 1.4, -27.0), 90.0, "Read the wall", [
		"Scratched into the east wall, at the height of someone kneeling:",
		"they took the name off the gate. they took it off the plaque. they could not get it off the bells.",
	], {"name": "NaveScratch", "size": Vector3(0.3, 1.2, 1.4), "offset": Vector3.ZERO, "note_key": "city_nave_scratch", "note_title": "Scratched in the nave", "note_text": "They took the name off the gate and the plaque. They could not get it off the bells."})
	bells_puzzle = Puzzle.declare(self, "city_bells", "city_bells_rung", [], "ring the four bells in clock order", {"keepsake": "bell"})


# --- the crypt: a stair down from the nave's west door, a round room, four bells --

func _crypt() -> void:
	Kit.floor(self, Vector3(6.25, 0, -37.5), Vector2(3.5, 3.0), "stone/flagstone", {"tile": 1.0})
	Kit.ceiling(self, Vector3(6.25, 3.2, -37.5), Vector2(3.5, 3.0), DARK, {"thick": 0.8, "all_faces": true, "tile": 1.0})
	for zz in [-39.15, -35.85]:
		Kit.box(self, Vector3(1.25, -1.2, zz), Vector3(13.5, 8.8, 0.3), DARK, {"tile": 2.0})
	Kit.stairs(self, Vector3(4.5, 0, -37.5), 90.0, 3.0, 15, -0.35, 0.5, "stone/flagstone", {"name": "CryptStairs", "tile": 1.0})
	for i in range(0, 15, 2):
		Kit.ceiling(self, Vector3(4.5 - (i + 1) * 0.5, 3.2 - 0.35 * (i + 1), -37.5), Vector2(1.0, 3.0), DARK, {"thick": 0.8, "all_faces": true, "tile": 1.0})
	Kit.floor(self, Vector3(-4.25, CRYPT_Y - 0.01, -37.5), Vector2(2.5, 3.0), "stone/flagstone", {"tile": 1.0})
	Kit.ceiling(self, Vector3(-4.25, CRYPT_Y + 3.2, -37.5), Vector2(2.6, 3.0), DARK, {"thick": 0.8, "all_faces": true, "tile": 1.0})
	Kit.box(self, Vector3(-5.3, CRYPT_Y + 3.85, -37.5), Vector3(0.5, 1.5, 4.8), DARK, {"tile": 1.0})
	var e0 := CRYPT_C + Kit.polar(CRYPT_R, -22.5)
	var e1 := CRYPT_C + Kit.polar(CRYPT_R, 22.5)
	Kit.wall(self, e0, Vector3(e0.x, CRYPT_Y, -39.0), 4.5, DARK)
	Kit.wall(self, Vector3(e1.x, CRYPT_Y, -36.0), e1, 4.5, DARK)
	Kit.light(self, Vector3(6.2, 2.6, -37.5), CANDLE, 0.8, 5.0)
	_torch(Vector3(0.5, -1.9, -38.98), 180.0)
	Props.place(self, "candle_cluster", Vector3(7.4, 0, -38.6), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "rubble_pile", Vector3(-4.6, CRYPT_Y, -36.5), 30.0, 0.5, {"collision": "none"})
	Readable.create(self, Vector3(6.2, 1.4, -36.05), 0.0, "Read the lintel", [
		"Cut over the stair, in a hand that had run out of patience:",
		"FOUR ABOVE. ONE BELOW. THEY WILL NOT GIVE IT UP FOR ANY OTHER ORDER.",
	], {"name": "CryptLintel", "size": Vector3(2.0, 1.0, 0.3), "offset": Vector3.ZERO})
	# the round room
	Kit.ring(self, CRYPT_C, 0.0, CRYPT_R + 0.35, 16, "stone/flagstone", {"tile": 2.0})
	Kit.round_wall(self, CRYPT_C, CRYPT_R, 4.5, 16, DARK, {"gaps": [[0.0, 30.0]], "tile": 2.0})
	Kit.ring(self, CRYPT_C + Vector3(0, 4.5, 0), 0.0, CRYPT_R + 0.35, 16, DARK, {"down": true, "tile": 2.0})
	Kit.sign(self, "metal/clock_face", CRYPT_C + Vector3(0, 0.02, 0), 0.0, Vector2(7.0, 7.0), {"rotation": Vector3(-90, 0, 0)})
	for i in 4:
		var a: float = BELL_ANGLES[i]
		var p := CRYPT_C + Kit.polar(3.6, a)
		Kit.box(self, p + Vector3(0, 4.0, 0), Vector3(0.24, 1.0, 0.24), "wood/planks_dark", {"solid": false, "tile": 1.0})
		var pivot := Node3D.new()
		pivot.name = "BellPivot%d" % i
		pivot.position = p + Vector3(0, 3.5, 0)
		add_child(pivot)
		Props.place(pivot, "bell_large", Vector3(0, -1.5, 0), 0.0, 1.0, {"collision": "none"})
		bell_pivots.append(pivot)
		Interactable.make(self, p + Vector3(0, 1.75, 0), Vector3(1.3, 1.7, 1.3), "Ring the bell", _on_ring.bind(i), {"name": "Bell%d" % i})
		Kit.label(self, BELL_NAMES[i], CRYPT_C + Kit.polar(CRYPT_R - 0.45, a, 2.7), Kit.yaw_to_center(a), 44, Color(0.8, 0.74, 0.6), "display", {"pixel_size": 0.012})
		Kit.light(self, p + Vector3(0, 2.3, 0), Color(0.95, 0.8, 0.55), 0.9, 6.5)
		Props.place(self, "candle_cluster", CRYPT_C + Kit.polar(4.9, a + 12.0), 0.0, 1.0, {"collision": "none"})
	Kit.cylinder(self, CRYPT_C, 0.6, 0.9, "stone/smooth_grey", {"segments": 8, "tile": 1.0})
	var top := CRYPT_C + Vector3(0, 0.9, 0)
	bell_pickup = Pickup.create(self, top, {"keepsake": "bell", "requires_flag": "city_bells_rung", "name": "SmallBell"})
	bell_cage = Props.place(self, "cage", top, 0.0, 0.55, {"collision": "none", "name": "BellCage"})
	var solved := Game.has_flag("city_bells_rung")
	bell_cage.visible = not solved
	if not solved:
		bell_pickup.visible = false
		bell_pickup.enabled = false
	Readable.create(self, CRYPT_C + Vector3(0, 0, 0.95), 0.0, "Read the plinth", [
		"Carved round the plinth: STRIKE THE HOURS AS THE CLOCK WOULD. THE SMALL ONE LISTENS.",
		"Inside the cage something small and green-grey hangs from a hook. It has no clapper. It is very still, the way things are still when they are listening." if not solved else "The cage is open. Whatever was inside has been claimed, or is about to be.",
	], {"name": "PlinthRead", "size": Vector3(1.3, 0.9, 0.5), "note_key": "city_plinth", "note_title": "The plinth in the crypt", "note_text": "Under the cathedral, four bells at the quarters of a round room and a caged bell on a plinth in the middle. Strike the hours as the clock would."})
	Kit.light(self, CRYPT_C + Vector3(0, 2.6, 0), Color(0.6, 0.85, 0.8), 1.0, 8.0)
	Props.place(self, "coffin", CRYPT_C + Kit.polar(4.7, 225.0), 45.0, 1.0)
	Props.place(self, "coffin", CRYPT_C + Kit.polar(4.7, 135.0), -45.0, 1.0)
	Props.place(self, "urn", CRYPT_C + Kit.polar(5.2, 45.0), 0.0, 1.0)
	Props.place(self, "urn", CRYPT_C + Kit.polar(5.3, 315.0), 0.0, 0.9)
	Props.place(self, "skull", CRYPT_C + Kit.polar(5.4, 60.0), 200.0, 1.0, {"collision": "none"})
	Kit.particles(self, CRYPT_C + Vector3(0, 2.2, 0), "motes", Vector3(5.0, 2.0, 5.0), 40)


# --- the palace: one map, a throne room, stone knights -----------------------------

func _palace() -> void:
	var rects := [[1, 1, 13, 21, "t"]]
	var doors := [[6, 0, "D"], [7, 0, "D"]]
	var markers := []
	for r in range(1, 21):
		markers.append([6, r, "c"])
		markers.append([7, r, "c"])
	var rows := MapBuilder.rasterize(14, 22, rects, doors, markers)
	MapBuilder.build(self, rows, {"cell": 1.0, "height": 7.0, "origin": Vector3(-25, 0, 4.5), "door_h": 4.0, "tile": 2.0,
		"floor": "stone/flagstone_castle", "wall": "stone/blocks_city", "ceiling": "wood/planks_dark",
		"floors": {"c": "wall/carpet_red"}, "rooms": {"t": {"floor": "stone/flagstone_castle", "wall": "stone/blocks_city", "ceiling": "wood/planks_dark"}},
		"marker_rooms": {"c": "t"}, "outer_faces": true, "wall_tops": true, "name": "Palace"})
	var cx := -18.0
	Kit.box(self, Vector3(cx, 0.3, 23.75), Vector3(12.0, 0.6, 3.5), "stone/marble_black", {"tile": 1.5})
	Kit.stairs(self, Vector3(cx, 0, 20.5), 180.0, 4.0, 3, 0.2, 0.5, "stone/marble_black", {"name": "DaisSteps", "tile": 1.0})
	var throne := Vector3(cx, 0.6, 24.6)
	Props.place(self, "throne", throne, 0.0, 1.0)
	Pickup.create(self, throne + Vector3(0, 0.5, -0.1), {"item": "tower_key", "requires_keepsake": "crown", "name": "TowerKey"})
	if not Game.has_keepsake("crown"):
		Kit.blocker(self, Vector3(cx, 1.6, 20.2), Vector3(12.0, 3.2, 0.4))
	Readable.create(self, Vector3(cx, 0.4, 20.75), 0.0, "Read the step", [
		"Carved into the bottom step: THE CROWNED MAY PASS. THE REST MAY LOOK.",
		"Under it, in chalk, much later: they cannot tell paper from gold. nobody here can. that is the whole trouble.",
	], {"name": "DaisStep", "size": Vector3(3.0, 0.8, 0.5), "note_key": "city_knights_step", "note_title": "The step before the throne", "note_text": "The crowned may pass, the rest may look. The knights cannot tell paper from gold."})
	for sx in [-1.0, 1.0]:
		Props.place(self, "statue_knight_big", Vector3(cx + sx * 4.6, 0.6, 23.6), 0.0, 1.0, {"collision": "box"})
		for zz in [9.0, 13.0, 17.0]:
			Props.place(self, "statue_knight", Vector3(cx + sx * 3.8, 0, zz), -90.0 if sx < 0 else 90.0, 1.0, {"collision": "box"})
		for zz in [7.5, 11.5, 15.5, 19.5]:
			Props.place(self, "pillar_city", Vector3(cx + sx * 5.2, 0, zz), 0.0, 1.3, {"collision": "cylinder"})
		for pz in [Vector3(cx + sx * 3.0, 0, 7.0), Vector3(cx + sx * 3.0, 0, 15.0), Vector3(cx + sx * 2.4, 0.6, 22.8)]:
			Kit.cylinder(self, pz, 0.18, 1.0, "metal/brass", {"segments": 6, "tile": 1.0})
			Props.place(self, "candelabra", pz + Vector3(0, 1.0, 0), 0.0, 1.0, {"collision": "none"})
			Kit.light(self, pz + Vector3(0, 1.8, 0), CANDLE, 1.1, 7.0)
		var wx: float = cx + float(sx) * 5.7
		for zz in [9.5, 15.5, 21.5]:
			Props.place(self, "banner_eye", Vector3(wx, 5.6, zz), -90.0 if sx < 0 else 90.0, 1.0, {"collision": "none"})
		for zz in [12.5, 18.5]:
			Props.place(self, "window_night", Vector3(wx - sx * 0.24, 4.6, zz), -90.0 if sx < 0 else 90.0, 1.0, {"collision": "none"})
			Kit.light(self, Vector3(wx - sx * 0.9, 4.6, zz), COOL, 0.5, 6.0)
	NPC.create(self, Vector3(cx - 2.6, 0, 19.2), 0.0, "the Stone Knight", {"model": "statue_knight", "face_player": false, "turn_to_bell": false, "name": "StoneKnight", "on_talk": _knight_talk,
		"lines": [
			"The knight does not move. The words come from behind the visor, slowly, as if they were being read off a wall.",
			"\"THE CROWNED MAY PASS. THE REST MAY LOOK.\"",
			"\"We were told to wait for the king. We were not told which.\"",
		],
		"reactions": {
			"bell": ["The visor turns toward the bell before you have rung it.", "\"That one we know,\" the knight says. \"It is not the one we are waiting for. Ring it anyway. It has been a long time.\""],
			"knife": ["\"Stone,\" says the knight, with what might be patience."],
			"lantern": ["In the lantern's light the knight has a face under the visor. It is not a good face. It is not looking at you."],
		}})
	Props.place(self, "chain_hanging", Vector3(cx, 7.0, 10.5), 0.0, 0.5, {"collision": "none"})
	Props.place(self, "chain_hanging", Vector3(cx, 7.0, 17.5), 0.0, 0.5, {"collision": "none"})
	Props.place(self, "banner_eye", Vector3(cx - 5.7, 3.2, 12.5), -90.0, 1.0, {"collision": "none"})
	Readable.create(self, Vector3(cx - 5.5, 2.0, 12.5), -90.0, "Look at the banner", [
		"The eye on the banner is closed. You are fairly sure it was open when you came in.",
		"Every banner in the room has the same eye. They are all closed now. They are all being polite about it.",
	], {"name": "PalaceBanner", "size": Vector3(0.5, 2.4, 1.2), "offset": Vector3.ZERO})
	Kit.particles(self, Vector3(cx, 3.5, 15.0), "motes", Vector3(5.0, 2.5, 9.0), 60)
	Puzzle.declare(self, "palace_knights", "", ["keepsake:crown"], "the stone knights admit the crowned", {"item": "tower_key"})


## The palace's street face above the map's walls, and what stands in front of it.
func _palace_front() -> void:
	Kit.box(self, Vector3(-18.0, 9.5, 8.5), Vector3(14.0, 5.0, 8.0), "stone/blocks_city", {"tile": 2.0})
	Kit.box(self, Vector3(-18.0, 12.2, 8.5), Vector3(14.5, 0.4, 8.5), DARK, {"solid": false, "tile": 1.0})
	for k in 7:
		Kit.box(self, Vector3(-24.6 + k * 2.2, 12.9, 4.95), Vector3(0.9, 1.2, 0.9), "stone/blocks_city", {"tile": 1.0})
	for xx in [-23.0, -20.5, -15.5, -13.0]:
		Props.place(self, "window_night", Vector3(xx, 9.3, SH - 0.07), 0.0, 1.0, {"collision": "none"})
	Props.place(self, "window_lit", Vector3(-18.0, 9.6, SH - 0.07), 0.0, 1.3, {"collision": "none"})
	Kit.light(self, Vector3(-18.0, 9.6, 3.6), WARM, 0.6, 5.0)
	for sx in [-1.0, 1.0]:
		Props.place(self, "banner_eye", Vector3(-18.0 + sx * 2.6, 6.6, SH - 0.15), 0.0, 1.0, {"collision": "none"})
		_torch(Vector3(-18.0 + sx * 1.9, 2.8, SH - 0.12), 0.0)
		Props.place(self, "statue_knight", Vector3(-18.0 + sx * 4.2, 0, 3.5), 0.0, 0.9, {"collision": "box"})
	Props.place(self, "portcullis", Vector3(-18.0, 3.3, 4.95), 0.0, 0.8, {"collision": "none"})
	Kit.label(self, "THE PALACE", Vector3(-18.0, 5.4, SH - 0.08), 0.0, 30, Color(0.8, 0.75, 0.6), "display", {"pixel_size": 0.012})


# --- the alley (the tavern's back door lands here) --------------------------------

func _alley() -> void:
	var cx := -7.75
	Kit.floor(self, Vector3(cx, 0, 8.6), Vector2(2.5, 8.2), "stone/cobble_mossy", {"tile": 1.5})
	Kit.box(self, Vector3(-6.6, 5.0, 12.9), Vector3(5.2, 10.0, 0.4), "brick/dark", {"tile": 2.0})
	Kit.sign(self, "wood/door_dark", Vector3(cx, 1.05, 12.68), 0.0, Vector2(1.0, 2.1), {"tint": Color(0.7, 0.62, 0.6)})
	Readable.create(self, Vector3(cx, 0, 12.5), 0.0, "A door with no handle", [
		"A door with no handle on this side. Through it, very faintly, a song that has no end, and the smell of somewhere warm.",
		"It only opens from the other side, and only onto here sometimes.",
	], {"name": "BackDoorRead", "size": Vector3(1.2, 2.1, 0.5), "offset": Vector3(0, 1.05, 0), "note_key": "city_alley_door", "note_title": "The alley", "note_text": "The tavern's back door opens onto an alley off the long street, sometimes. From this side it has no handle. You can hear the song through it."})
	Kit.sign(self, "signs/graffiti_wake", Vector3(-6.53, 1.5, 8.2), 90.0, Vector2(1.7, 0.5))
	Readable.create(self, Vector3(-6.6, 1.5, 8.2), 90.0, "Read the graffiti", [
		"WAKE UP, in dripping paint. Under it, smaller, in a different hand: we tried. the water came anyway.",
		"Under that, smallest of all: it is nicer than it sounds.",
	], {"name": "GraffitiAlley", "size": Vector3(0.3, 0.8, 1.9), "offset": Vector3.ZERO, "note_key": "city_graffiti", "note_title": "Graffiti in the alley", "note_text": "WAKE UP. We tried. The water came anyway. It is nicer than it sounds."})
	Props.place(self, "cart_broken", Vector3(cx, 0, 11.5), 90.0, 0.85)
	Props.place(self, "rubble_pile", Vector3(-8.3, 0, 5.4), 0.0, 0.6)
	Props.place(self, "barrel", Vector3(-6.95, 0, 11.3), 0.0, 0.8)
	Kit.water(self, Vector3(cx, 0.01, 8.0), Vector2(1.6, 2.4), "nature/water_dark", {"tint": Color(0.5, 0.55, 0.6, 0.7), "subdiv": 2, "swell": 0.0})
	Kit.box(self, Vector3(-8.6, 4.0, 8.5), Vector3(0.8, 0.14, 1.8), DARK, {"solid": false, "tile": 1.0})
	Props.place(self, "window_lit", Vector3(-8.93, 4.85, 8.5), -90.0, 1.0, {"collision": "none"})
	_figure(Vector3(-8.55, 4.07, 8.5), -90.0)
	Kit.light(self, Vector3(-8.2, 4.7, 8.5), WARM, 0.7, 5.0)
	Kit.light(self, Vector3(cx, 3.0, 11.5), COOL, 0.6, 5.0)
	Kit.particles(self, Vector3(cx, 6.0, 8.6), "rain", Vector3(1.2, 1.0, 4.0), 60)
	add_spawn("alley", Vector3(cx, 0.1, 9.3), 0.0)


# --- the lower town, under the water ------------------------------------------------

func _lower_town() -> void:
	var second := visit_count >= 2
	Kit.floor(self, Vector3(20.0, 0, 6.25), Vector2(8.0, 3.5), "stone/cobble_city", {"tile": 2.0})
	Kit.stairs(self, Vector3(20.0, 0, 8.0), 180.0, 8.0, 2, -0.275, 0.6, "stone/cobble_city", {"name": "LaneSteps", "tile": 2.0})
	var wet := {"tile": 2.0, "surface": "water"}
	Kit.floor(self, Vector3(20.0, LOW_Y, 10.85), Vector2(8.0, 3.3), "stone/cobble_mossy", wet)
	Kit.floor(self, Vector3(22.0, LOW_Y, 16.75), Vector2(24.0, 8.5), "stone/cobble_mossy", wet)
	Kit.floor(self, Vector3(22.0, LOW_Y, 27.25), Vector2(24.0, 5.5), "stone/cobble_mossy", wet)
	Kit.floor(self, Vector3(22.0, CHANNEL_Y, 22.75), Vector2(24.0, 3.5), "ground/mud", wet)
	Kit.box(self, Vector3(22.0, (LOW_Y + CHANNEL_Y) * 0.5, 20.85), Vector3(24.0, LOW_Y - CHANNEL_Y, 0.3), DARK, {"tile": 1.0})
	Kit.box(self, Vector3(22.0, (LOW_Y + CHANNEL_Y) * 0.5, 24.65), Vector3(24.0, LOW_Y - CHANNEL_Y, 0.3), DARK, {"tile": 1.0})
	var lb := {"base": LOW_Y - 0.2}
	_building(4.0, 10.0, 22.0, 30.0, 10.0, "brick/dark", "e", lb)
	_building(32.0, 40.0, 12.5, 30.0, 11.0, "stone/blocks_city", "w", lb)
	_building(10.0, 34.0, 30.0, 38.0, 9.0, "wood/planks_dark", "n", lb)
	# the channel is deeper than the city; nobody wades it
	var spans := [[10.0, 18.5], [21.5, 34.0]] if not second else [[10.0, 34.0]]
	for s in spans:
		var sp: Array = s
		var bx := (float(sp[0]) + float(sp[1])) * 0.5
		var bw := float(sp[1]) - float(sp[0])
		Kit.blocker(self, Vector3(bx, 1.2, 20.55), Vector3(bw, 3.6, 0.3))
		Kit.blocker(self, Vector3(bx, 1.2, 24.95), Vector3(bw, 3.6, 0.3))
	if not second:
		Kit.box(self, Vector3(20.0, LOW_Y - 0.1, 22.75), Vector3(3.0, 0.2, 4.3), "wood/planks_grey", {"tile": 1.0})
		for sx in [-1.0, 1.0]:
			Kit.box(self, Vector3(20.0 + sx * 1.42, LOW_Y + 0.45, 22.75), Vector3(0.1, 0.9, 4.3), "wood/planks_dark", {"tile": 1.0})
			Kit.blocker(self, Vector3(20.0 + sx * 1.42, 1.2, 22.75), Vector3(0.2, 3.6, 4.3))
	else:
		Kit.box(self, Vector3(20.0, LOW_Y - 0.1, 21.1), Vector3(3.0, 0.2, 0.8), "wood/planks_grey", {"tile": 1.0})
		Kit.box(self, Vector3(20.0, LOW_Y - 0.1, 24.4), Vector3(3.0, 0.2, 0.8), "wood/planks_grey", {"tile": 1.0})
		Readable.create(self, Vector3(20.0, LOW_Y + 0.2, 20.2), 180.0, "Where the bridge was", [
			"Two stumps of planking, one on each bank. The bridge was here. The water has taken the middle of it and left the ends, the way it leaves the ends of things.",
			"Across the channel the market is still standing, up to its counters. Nobody is going to sell you anything from there now.",
		], {"name": "BridgeGone", "size": Vector3(2.4, 0.8, 0.6), "note_key": "city_bridge_gone", "note_title": "The bridge is gone", "note_text": "Second time in the Drowned City the water was higher and the bridge over the channel was gone. The far side of the lower town is the water's now."})
	Kit.water(self, Vector3(22.0, water_y, 19.6), Vector2(24.0, 20.8), "nature/water_dark", {"tint": Color(0.72, 0.84, 0.92, 0.82), "speed": 0.012, "swell": 0.035, "glow": 0.25, "subdiv": 6})
	if second:
		Kit.water(self, Vector3(20.0, 0.03, 6.25), Vector2(8.0, 3.5), "nature/water_dark", {"tint": Color(0.55, 0.66, 0.76, 0.7), "subdiv": 2, "swell": 0.0})
	# the sewer grate on its stone, and the way down
	var isl := Vector3(31.1, 0, 17.5)
	Kit.box(self, isl + Vector3(0, -0.425, 0), Vector3(2.6, 0.85, 3.0), DARK, {"tile": 1.0})
	Kit.stairs(self, Vector3(28.8, LOW_Y, 17.5), -90.0, 2.4, 2, 0.275, 0.5, DARK, {"name": "IslandSteps", "tile": 1.0})
	var grate := Vector3(30.9, 0, 17.5)
	Props.place(self, "drain_grate", grate, 0.0, 1.3, {"collision": "none"})
	Door.create(self, grate, 0.0, "catacombs", "from_sewer", {"kind": "none", "label": "Climb down through the grate", "name": "SewerGrate",
		"requires_keepsake": "lantern", "locked_text": "It is too dark down there to find the rungs.", "fade_color": Color(0.02, 0.02, 0.03), "fade_duration": 1.2, "sound": "door_heavy"})
	Readable.create(self, Vector3(31.95, 1.3, 18.8), 90.0, "Read the chalk on the wall", [
		"Chalked on the wall above the grate: RUNGS. COUNT THEM DOWN. DO NOT COUNT THEM UP.",
		"Below the grate the water is going somewhere, slowly, the way water goes when it has an appointment.",
	], {"name": "GrateChalk", "size": Vector3(0.3, 1.0, 1.6), "offset": Vector3.ZERO, "note_key": "city_sewer", "note_title": "The sewer grate", "note_text": "In the lower town a drain grate sits on a stone above the water. Rungs go down. It is too dark to find them without a light."})
	_lantern(Vector3(32.0, 0, 16.3), 90.0)
	add_spawn("sewer_top", Vector3(30.6, 0.1, 18.4), 90.0)
	# the drowned market, and what the lantern finds under the water
	Props.place(self, "market_stall", Vector3(13.0, LOW_Y, 27.2), 0.0, 1.0)
	Readable.create(self, Vector3(13.0, LOW_Y + 0.9, 26.2), 0.0, "Read the drowned menu", [
		"The chalkboard has run. What is left says: EVERYTHING, WET.",
	], {"name": "WetMenu", "size": Vector3(1.6, 0.8, 0.5)})
	Props.place(self, "market_stall", Vector3(27.5, LOW_Y, 27.6), 180.0, 1.0)
	Props.place(self, "cart_broken", Vector3(19.5, LOW_Y, 28.3), 40.0, 1.0)
	Props.place(self, "rubble_pile", Vector3(11.6, LOW_Y, 15.2), 0.0, 1.0)
	Props.place(self, "rubble_pile", Vector3(30.5, LOW_Y, 27.5), 60.0, 1.1)
	Props.place(self, "statue_knight", Vector3(24.5, LOW_Y, 15.0), 200.0, 1.0)
	Props.place(self, "barrel", Vector3(11.2, LOW_Y, 19.5), 0.0, 1.0)
	Props.place(self, "gargoyle", Vector3(15.0, LOW_Y, 19.0), 160.0, 1.0)
	var ring := Node3D.new()
	ring.name = "DrownedRing"
	add_child(ring)
	Kit.sign(ring, "props/rune_ring_floor", Vector3(14.0, LOW_Y + 0.02, 17.0), 0.0, Vector2(5.0, 5.0), {"rotation": Vector3(-90, 0, 0)})
	Kit.lantern_only(ring)
	Readable.create(self, Vector3(14.0, LOW_Y, 17.0), 0.0, "Look down into the water", [], {"name": "DrownedBell", "size": Vector3(2.0, 1.0, 2.0), "on_read": _on_water_read, "sound": "drip"})
	Readable.create(self, Vector3(14.0, LOW_Y + 0.2, 20.4), 180.0, "Look into the channel", [
		"The water in the channel is black and goes down further than the city does.",
		"Something at the bottom is ringing, very slowly, once every few years.",
	], {"name": "ChannelLook", "size": Vector3(2.0, 0.8, 0.6), "sound": "drip"})
	# somebody in a drowned window
	Props.place(self, "window_lit", Vector3(26.0, 1.3, 29.93), 0.0, 1.0, {"collision": "none"})
	_figure(Vector3(26.0, LOW_Y, 29.4), 0.0)
	Kit.light(self, Vector3(26.0, 1.4, 28.8), WARM, 0.7, 5.0)
	_lantern(Vector3(11.3, LOW_Y, 13.8), -90.0)
	_lantern(Vector3(25.5, LOW_Y, 19.6), 90.0)
	_lantern(Vector3(12.5, LOW_Y, 29.0), 0.0)
	_lantern(Vector3(31.0, LOW_Y, 25.0), 90.0)
	Props.place(self, "chain_hanging", Vector3(31.7, 8.0, 22.0), 0.0, 0.8, {"collision": "none"})
	Props.place(self, "chain_hanging", Vector3(10.3, 7.0, 25.0), 0.0, 0.7, {"collision": "none"})
	_plate(Vector3(24.05, 3.0, 6.8), 90.0, "DRY LANE", 2.0)
	Readable.create(self, Vector3(24.2, 3.0, 6.8), 90.0, "Read the street sign", [
		"DRY LANE. Somebody has scratched a line through DRY and written nothing to replace it.",
		"The steps go down into the water. The water has been coming up the steps to meet them.",
	], {"name": "SignDryLane", "size": Vector3(0.4, 0.6, 2.0), "offset": Vector3.ZERO})
	Kit.particles(self, Vector3(22.0, 1.5, 21.0), "motes", Vector3(11.0, 1.0, 8.0), 50)
	Kit.light(self, Vector3(20.0, 1.6, 11.0), COOL, 0.9, 8.0)
	Kit.light(self, Vector3(22.0, 2.6, 17.0), Color(0.7, 0.8, 0.95), 1.1, 13.0)
	Kit.light(self, Vector3(22.0, 7.0, 21.0), Color(0.62, 0.7, 0.88), 1.3, 26.0)
	Kit.light(self, Vector3(20.0, 1.8, 27.0), COOL, 0.9, 10.0)
	Kit.light(self, Vector3(30.0, 1.5, 17.5), Color(0.6, 0.85, 0.75), 0.8, 6.0)
	rains.append(Kit.particles(self, Vector3(22.0, 8.0, 21.0), "rain", Vector3(12.0, 2.0, 9.0), 260))


# --- the bells ------------------------------------------------------------------------

func _on_ring(_player: Node, it: Node, i: int) -> void:
	var pos: Vector3 = (it as Node3D).global_position
	Audio.sfx("bell_big", pos, -2.0)
	_swing(i)
	Game.bump("city_bells_struck")
	if bells_puzzle == null or bells_puzzle.is_solved():
		return
	var expected: int = BELL_ORDER[rung.size()]
	if i == expected:
		rung.append(i)
		if rung.size() == BELL_ORDER.size():
			_solve_bells()
		elif rung.size() == 1:
			Game.toast.emit("The bell rings. Under the floor, something starts counting.")
	else:
		rung.clear()
		Audio.sfx("riddle_wrong", pos, -4.0)
		get_tree().create_timer(0.3).timeout.connect(func() -> void: Audio.sfx("bell_big", pos, -9.0, 0.7))
		Game.toast.emit("The bells clash. Whatever was counting starts again from nothing.")


func _swing(i: int) -> void:
	if i < 0 or i >= bell_pivots.size():
		return
	var pv: Node3D = bell_pivots[i]
	if not is_instance_valid(pv):
		return
	var tw := create_tween()
	tw.tween_property(pv, "rotation:x", 0.32, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(pv, "rotation:x", -0.26, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pv, "rotation:x", 0.12, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pv, "rotation:x", 0.0, 0.45).set_trans(Tween.TRANS_SINE)


func _solve_bells() -> void:
	bells_puzzle.solve("The four bells agree. In the middle, a fifth answers.")
	Audio.sfx("bell_small", CRYPT_C + Vector3(0, 1.2, 0), -2.0)
	if bell_cage != null and is_instance_valid(bell_cage):
		var tw := create_tween()
		tw.tween_property(bell_cage, "position:y", bell_cage.position.y + 3.0, 1.2).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			if is_instance_valid(bell_cage):
				bell_cage.visible = false)
	if bell_pickup != null and is_instance_valid(bell_pickup):
		bell_pickup.visible = true
		bell_pickup.enabled = true
	Game.note("city_bells", "The four bells", "Twelve, three, six, nine: the bells under the cathedral struck in the clock's order, and the cage on the plinth lifted off the Small Bell like a hand off a shoulder.")


# --- the palace ------------------------------------------------------------------------

func _knight_talk(_player: Node, npc: Node) -> bool:
	var n := npc as NPC
	Game.note("stone_knights", "The stone knights", "The throne room of the Drowned City's palace is guarded by stone knights who let only the crowned through. They cannot tell paper from gold. Nobody here can.")
	if n != null and Game.has_keepsake("crown"):
		Game.set_flag("city_knights_bowed", true)
		await n.say([
			"The visor turns. Stone grinds on stone, a long way down.",
			"\"Majesty.\" The word takes a while. It is the first one in years.",
			"\"The throne is yours. It was always going to be somebody's. What is on it is yours too. We were only told to keep it, not from whom.\"",
		])
		return true
	return false


func _stall_talk(_player: Node, _npc: Node) -> bool:
	Game.note("stallholder", "The stallholder", "A stallholder in the cathedral square of the Drowned City who sells nothing, and gives it away. The city had a name, they say. It went under first. Names are heavy.")
	return false


# --- secrets -----------------------------------------------------------------------------

func _no_number_target() -> Array:
	var n := Game.bump("city_no_number")
	Game.note("no_number_door", "Through the house with no number", "The door of the house with no number opens onto the Drowned City again, somewhere else in it. The house is not between the door and the place. Nothing is.")
	Audio.sfx("door_creak_long", Vector3(-14.0, 1.0, -SH), -4.0)
	return NO_NUMBER_TARGETS[(n - 1) % NO_NUMBER_TARGETS.size()]


func _on_wrap(_p: Node) -> void:
	var n := Game.count("city_wraps")
	if n == 1:
		Game.toast.emit("The street goes on. The plate on the corner has changed its mind about the name.")
	elif n == 3:
		Game.note("city_wrap", "The street that goes round", "Walk to the east end of the long street and you are at the west end of it. The city is a ring, or a very short city that has learned to look long.")
		Game.toast.emit("You have been here. This is the same corner. It is not pretending otherwise.")


func _on_watcher_unseen(_l: Node) -> void:
	if watcher != null and is_instance_valid(watcher):
		watcher.visible = false
	Audio.sfx("whisper", Vector3(-14.0, 5.6, -SH), -6.0)
	Game.bump("figure_sightings")
	Game.toast.emit("The balcony of the house with no number is empty. The window is still lit.")
	Game.note("city_watchers", "The watchers in the windows", "Somebody stands in the lit windows of the Drowned City, on the balconies, in the doorways under the water. They do not move while you look. They are not there when you look back.")


func _on_water_read(_r: Node) -> void:
	if World.hud == null:
		return
	if Game.lantern_lit:
		Game.note("drowned_bell", "Where the great bell fell", "Under the water of the lower town, only in the lantern's light, a ring of letters on the cobbles: HERE THE GREAT BELL FELL. IT IS STILL FALLING. The small one in the crypt is listening for it.")
		await World.hud.say("", [
			"In the lantern's light there are letters on the cobbles under the water, in a ring, the way they go round a bell:",
			"HERE THE GREAT BELL FELL. IT IS STILL FALLING.",
			"The water over the ring is very slightly warmer than the rest.",
		])
	else:
		await World.hud.say("", [
			"Under the water something is set into the cobbles in a ring. It might be letters. The water is too dark to read by.",
			"Whatever it says, it says it all the way round.",
		])


# --- hooks ---------------------------------------------------------------------------------

func on_enter(spawn_id: String, n: int) -> void:
	super.on_enter(spawn_id, n)
	if n == 1:
		Game.note("drowned_city", "The Drowned City", "A city of tall dark houses in the rain, with somebody standing in the lit windows. It forgot its name before you arrived. The lower town is under black water to the knee. The long street goes round.")
	elif n == 2:
		Game.note("city_higher", "The water is higher", "The second time in the Drowned City the water in the lower town had come up the steps, the bridge over the channel was gone, and the stallholder was not at the stall. The stool was still warm.")
		Game.toast.emit("The water has come up. It did not wait for you.")
	if spawn_id == "sewer_top":
		Game.toast.emit("You come up through the grate into the rain.")
	if spawn_id == "alley":
		Game.toast.emit("The door shuts behind you. There is no handle on this side.")
	# TODO: the third visit should put the water on the long street itself.


func on_bell(_origin: Vector3) -> void:
	if not is_inside_tree():
		return
	for i in 4:
		get_tree().create_timer(0.5 + i * 0.4).timeout.connect(_answer_bell.bind(i))
	if not Game.has_note("city_bells_answer"):
		Game.note("city_bells_answer", "The bells answer", "Ring the Small Bell anywhere in the Drowned City and four larger bells answer from under the cathedral, one after another, in their order.")
		Game.toast.emit("Under the cathedral, four bells answer, in their order.")


func _answer_bell(i: int) -> void:
	if not is_inside_tree() or i >= bell_pivots.size():
		return
	var pv: Node3D = bell_pivots[i]
	if is_instance_valid(pv):
		Audio.sfx("bell_big", pv.global_position, -10.0)
		_swing(i)


func on_lantern(lit: bool) -> void:
	if lit and not Game.has_flag("city_lantern_lit"):
		Game.set_flag("city_lantern_lit", true)
		Game.toast.emit("The water shows what it took, now that there is light to show it by.")


func on_umbrella(open: bool) -> void:
	for r in rains:
		var p := r as CPUParticles3D
		if p != null and is_instance_valid(p):
			p.speed_scale = 1.8 if open else 1.0
	if open:
		Game.toast.emit("The rain leans in to see the umbrella. It has not seen one in a while.")
	# TODO: with the umbrella open the fountain should run the right way for once.
