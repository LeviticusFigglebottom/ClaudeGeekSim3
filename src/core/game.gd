extends Node
## Game — global state for one dreamer: flags, keepsakes, items, visits, the
## journal, and save/load. Autoloaded as `Game`.
##
## Everything that persists between areas lives here. Areas read flags to decide
## how to build themselves (a house that has been visited three times is not the
## same house), and write flags when puzzles are solved.

signal flag_changed(flag: String, value: Variant)
signal keepsake_gained(id: String)
signal keepsake_equipped(id: String)
signal item_gained(id: String, count: int)
signal item_taken(id: String, count: int)
signal journal_updated(entry: Dictionary)
signal toast(text: String)
## Emitted by the Small Bell. Anything listening (stone knights, doors, the dog) reacts.
signal bell_rung(origin: Vector3)
signal time_frozen_changed(frozen: bool)
signal umbrella_changed(open: bool)
signal lantern_changed(lit: bool)
signal mirror_sight_changed(active: bool)
signal small_changed(small: bool)

const SAVE_PATH := "user://anteroom_save.json"
const SAVE_VERSION := 1

## Keepsakes are the things you were holding when you woke up. Each changes how
## the world treats you (Yume Nikki's "effects", by another name).
const KEEPSAKES := {
	"lantern": {
		"name": "The Lantern", "verb": "light / snuff", "color": Color("f2b134"),
		"desc": "A hooded lantern with no oil in it. It burns anyway. Some things only exist in its light.",
		"where": "The hermit's hut in the Hollow Wood, once the three braziers burn in the order of the stones.",
	},
	"wings": {
		"name": "Moth Wings", "verb": "glide (hold jump in the air)", "color": Color("d8c7ff"),
		"desc": "Grey, dusty, enormous. They do not flap so much as remember flapping.",
		"where": "The highest platform of the Slow Sea.",
	},
	"mouse": {
		"name": "The Tin Mouse", "verb": "shrink / grow", "color": Color("b6a48e"),
		"desc": "A tin mouse with a key in its back. Wind it and the world gets very large.",
		"where": "Behind the skirting board of the Nowhere House.",
	},
	"crown": {
		"name": "The Paper Crown", "verb": "(worn)", "color": Color("e8d36a"),
		"desc": "A crown of folded newspaper. The stone knights cannot tell the difference.",
		"where": "The rotating rooms of the Keep of Hours.",
	},
	"bell": {
		"name": "The Small Bell", "verb": "ring", "color": Color("9fd3c7"),
		"desc": "A bell with no clapper. When you ring it, everything that is listening turns to look.",
		"where": "The crypt beneath the cathedral of the Drowned City.",
	},
	"knife": {
		"name": "The Kitchen Knife", "verb": "cut", "color": Color("c9cdd6"),
		"desc": "Your kitchen knife. You do not remember bringing it. Tapestries, vines and certain conversations can be cut.",
		"where": "The Furnace, in the open hand of the chained giant.",
	},
	"umbrella": {
		"name": "The Umbrella", "verb": "open / close", "color": Color("6c8cd5"),
		"desc": "A black umbrella. Opening it indoors brings the weather in.",
		"where": "The barkeep of the Last Lamp trades it for a bottle of moonlight.",
	},
	"hourglass": {
		"name": "The Hourglass", "verb": "stop / start the clockwork", "color": Color("f0e6c8"),
		"desc": "The sand runs sideways. While it is turned, nothing that moves by clockwork moves.",
		"where": "The top of the Clocktower.",
	},
	"shard": {
		"name": "The Mirror Shard", "verb": "look through", "color": Color("a7f3f0"),
		"desc": "A piece of a mirror that shows the room as it would rather be.",
		"where": "The reflecting pool at the bottom of the Ossuary.",
	},
}

## Key items are ordinary objects with one job each.
const ITEMS := {
	"tape_measure": {"name": "Tape Measure", "desc": "Twenty-five feet of yellow steel. For measuring the things that should not be measured."},
	"coin": {"name": "Coin of the Sea", "desc": "A coin with a wave on both faces. The barkeep's riddle was worth exactly this much."},
	"moonlight": {"name": "Bottle of Moonlight", "desc": "Cold to hold. Lights nothing. The barkeep wants one very badly."},
	"tower_key": {"name": "Tower Key", "desc": "An iron key as long as your forearm, cut in the shape of a clock hand."},
	"photo": {"name": "Missing Photograph", "desc": "A family on a porch. One of them has been carefully scratched out."},
	"door_code": {"name": "The Difference", "desc": "The hallway is longer than the building. The difference is a number. You wrote it on your hand."},
	"dog_biscuit": {"name": "Dog Biscuit", "desc": "Shaped like a bone. Smells of nothing at all."},
	"page": {"name": "Torn Page", "desc": "A page from the house journal. The handwriting changes halfway down."},
	"candle_stub": {"name": "Candle Stub", "desc": "Black wax. It has been lit from both ends, and the middle."},
	"rose": {"name": "Paper Rose", "desc": "Folded from a page of the infinite library. It smells of dust and, faintly, of rain."},
}

var flags: Dictionary = {}
var keepsakes: Array = []
var active_keepsake: String = ""
var items: Dictionary = {}
var visits: Dictionary = {}
var journal: Array = []
var stats: Dictionary = {"doors": 0, "wakes": 0, "falls": 0, "distance": 0.0, "playtime": 0.0}
var run_seed: int = 0
var rng := RandomNumberGenerator.new()
var player: Node3D = null
var started := false

var time_frozen := false: set = set_time_frozen
var umbrella_open := false: set = set_umbrella_open
var lantern_lit := false: set = set_lantern_lit
var mirror_sight := false: set = set_mirror_sight
var small := false: set = set_small


func _ready() -> void:
	migrate_legacy_save()
	InputSetup.ensure()
	rng.randomize()
	run_seed = rng.randi()


func _process(delta: float) -> void:
	if started:
		stats.playtime += delta


# --- flags ---------------------------------------------------------------

func flag(flag_name: String) -> Variant:
	return flags.get(flag_name, false)

func has_flag(flag_name: String) -> bool:
	var v = flags.get(flag_name, false)
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	return v != null and v != ""

func set_flag(flag_name: String, value: Variant = true) -> void:
	if flags.has(flag_name) and flags[flag_name] == value:
		return
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)

func count(flag_name: String) -> int:
	return int(flags.get(flag_name, 0))

func bump(flag_name: String, by: int = 1) -> int:
	var v := count(flag_name) + by
	flags[flag_name] = v
	flag_changed.emit(flag_name, v)
	return v

## True with probability p, from the run's RNG (rare events: the face on the TV...).
func chance(p: float) -> bool:
	return rng.randf() < p


# --- keepsakes -----------------------------------------------------------

func has_keepsake(id: String) -> bool:
	return id in keepsakes

func gain_keepsake(id: String) -> void:
	if not KEEPSAKES.has(id):
		push_error("Unknown keepsake: %s" % id)
		return
	if has_keepsake(id):
		return
	keepsakes.append(id)
	keepsake_gained.emit(id)
	var k: Dictionary = KEEPSAKES[id]
	note("keepsake_" + id, k.name, k.desc)
	toast.emit("You are holding %s." % k.name)
	if active_keepsake == "":
		equip(id)

func equip(id: String) -> void:
	if id != "" and not has_keepsake(id):
		return
	if id == active_keepsake:
		return
	active_keepsake = id
	keepsake_equipped.emit(id)

func cycle_keepsake(dir: int) -> void:
	if keepsakes.is_empty():
		return
	var options: Array = [""] + keepsakes
	var i := options.find(active_keepsake)
	i = wrapi(i + dir, 0, options.size())
	equip(options[i])

func active_is(id: String) -> bool:
	return active_keepsake == id

func keepsake_name(id: String) -> String:
	return KEEPSAKES.get(id, {}).get("name", id)


# --- items ---------------------------------------------------------------

func has_item(id: String) -> bool:
	return int(items.get(id, 0)) > 0

func item_count(id: String) -> int:
	return int(items.get(id, 0))

func gain_item(id: String, n: int = 1) -> void:
	if not ITEMS.has(id):
		push_error("Unknown item: %s" % id)
		return
	items[id] = item_count(id) + n
	item_gained.emit(id, n)
	var it: Dictionary = ITEMS[id]
	note("item_" + id, it.name, it.desc)
	toast.emit("Found: %s" % it.name)

func take_item(id: String, n: int = 1) -> bool:
	if item_count(id) < n:
		return false
	items[id] = item_count(id) - n
	item_taken.emit(id, n)
	return true

func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


# --- visits --------------------------------------------------------------

## Record a visit to an area and return how many times it has now been entered.
func visit(area_id: String) -> int:
	visits[area_id] = int(visits.get(area_id, 0)) + 1
	return visits[area_id]

func visits_to(area_id: String) -> int:
	return int(visits.get(area_id, 0))


# --- journal -------------------------------------------------------------

## Add a journal entry once. The journal is the game's memory of itself: it
## quietly records what you found and hints at what you have not.
func note(key: String, title: String, text: String) -> void:
	for e in journal:
		if e.key == key:
			return
	var entry := {"key": key, "title": title, "text": text, "area": World.current_area_id, "t": stats.playtime}
	journal.append(entry)
	journal_updated.emit(entry)

func has_note(key: String) -> bool:
	for e in journal:
		if e.key == key:
			return true
	return false


# --- toggles (keepsake states) --------------------------------------------

func set_time_frozen(v: bool) -> void:
	if time_frozen == v:
		return
	time_frozen = v
	time_frozen_changed.emit(v)

func set_umbrella_open(v: bool) -> void:
	if umbrella_open == v:
		return
	umbrella_open = v
	umbrella_changed.emit(v)

func set_lantern_lit(v: bool) -> void:
	if lantern_lit == v:
		return
	lantern_lit = v
	lantern_changed.emit(v)

func set_mirror_sight(v: bool) -> void:
	if mirror_sight == v:
		return
	mirror_sight = v
	mirror_sight_changed.emit(v)

func set_small(v: bool) -> void:
	if small == v:
		return
	small = v
	small_changed.emit(v)

func reset_toggles() -> void:
	time_frozen = false
	umbrella_open = false
	lantern_lit = false
	mirror_sight = false
	small = false

func ring_bell(origin: Vector3) -> void:
	bump("bells_rung")
	bell_rung.emit(origin)


# --- real time -----------------------------------------------------------

## Some things only happen at night. The game checks the real clock.
func is_night() -> bool:
	var h: int = Time.get_datetime_dict_from_system().hour
	return h >= 22 or h < 5

func is_witching_hour() -> bool:
	var d := Time.get_datetime_dict_from_system()
	return d.hour == 3

func weekday() -> int:
	return int(Time.get_datetime_dict_from_system().weekday)


# --- save / load ---------------------------------------------------------

func new_game(i: int = 0) -> void:
	if i >= 1:
		slot = i
	flags = {}
	keepsakes = []
	active_keepsake = ""
	items = {}
	visits = {}
	journal = []
	stats = {"doors": 0, "wakes": 0, "falls": 0, "distance": 0.0, "playtime": 0.0}
	reset_toggles()
	rng.randomize()
	run_seed = rng.randi()
	started = true

func serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"flags": flags.duplicate(true),
		"keepsakes": keepsakes.duplicate(),
		"active_keepsake": active_keepsake,
		"items": items.duplicate(true),
		"visits": visits.duplicate(true),
		"journal": journal.duplicate(true),
		"stats": stats.duplicate(true),
		"run_seed": run_seed,
		"area": World.current_area_id,
		"spawn": World.current_spawn_id,
		"saved_at": Time.get_datetime_string_from_system(),
	}

func deserialize(d: Dictionary) -> void:
	flags = d.get("flags", {})
	keepsakes = []
	for k in d.get("keepsakes", []):
		keepsakes.append(String(k))
	active_keepsake = String(d.get("active_keepsake", ""))
	items = d.get("items", {})
	visits = d.get("visits", {})
	journal = d.get("journal", [])
	stats = d.get("stats", stats)
	run_seed = int(d.get("run_seed", 0))
	rng.seed = run_seed
	reset_toggles()
	started = true

## Three dreams can be kept at once. `slot` is the one being played; a new
## game picks a slot instead of overwriting whatever was there.
const SLOTS := 3
var slot := 1


static func slot_path(i: int) -> String:
	return "user://anteroom_save_%d.json" % i


func save() -> bool:
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("Could not open save slot %d for writing: %s" % [slot, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(serialize(), "\t"))
	f.close()
	return true


## Any slot (i < 1) or one slot in particular.
func has_save(i: int = 0) -> bool:
	if i >= 1:
		return FileAccess.file_exists(slot_path(i))
	for k in range(1, SLOTS + 1):
		if FileAccess.file_exists(slot_path(k)):
			return true
	return false


func _read_slot(i: int) -> Dictionary:
	if not FileAccess.file_exists(slot_path(i)):
		return {}
	var f := FileAccess.open(slot_path(i), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


## What the title screen shows for a slot: where, how far, when.
func slot_summary(i: int) -> Dictionary:
	var d := _read_slot(i)
	if d.is_empty():
		return {}
	var st: Dictionary = d.get("stats", {})
	return {
		"area": String(d.get("area", "")),
		"keepsakes": (d.get("keepsakes", []) as Array).size(),
		"playtime": float(st.get("playtime", 0.0)),
		"saved_at": String(d.get("saved_at", "")),
		"wakes": int(st.get("wakes", 0)),
	}


## The slot saved most recently, or 0 when there is none.
func latest_slot() -> int:
	var best := 0
	var best_at := ""
	for k in range(1, SLOTS + 1):
		var at := String(_read_slot(k).get("saved_at", ""))
		if at != "" and at > best_at:
			best_at = at
			best = k
	return best


func first_free_slot() -> int:
	for k in range(1, SLOTS + 1):
		if not has_save(k):
			return k
	return 0


func load_save(i: int = 0) -> Dictionary:
	if i >= 1:
		slot = i
	var d := _read_slot(slot)
	if d.is_empty():
		push_error("Save slot %d is empty or unreadable" % slot)
		return {}
	deserialize(d)
	return d


func delete_save(i: int = 0) -> void:
	var k := i if i >= 1 else slot
	if has_save(k):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(k)))


## Saves from before there were slots become slot 1.
func migrate_legacy_save() -> void:
	if FileAccess.file_exists(SAVE_PATH) and not has_save(1):
		var d := DirAccess.open("user://")
		if d:
			d.rename(SAVE_PATH.get_file(), slot_path(1).get_file())
