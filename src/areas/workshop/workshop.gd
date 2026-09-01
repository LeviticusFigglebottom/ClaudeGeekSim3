extends AreaBase
## The Workshop — a hidden room where every prop in the game stands on a plinth
## with its name. Reached by ringing the Small Bell thirteen times in the
## Anteroom. Doubles as the visual QA gallery for tools/screenshots.sh.

const PER_ROW := 8
const SPACING := 2.6
const ROW_GAP := 7.0

func build() -> void:
	can_wake = true
	Realm.apply(self, "city", {"fog_density": 0.006, "ambient_energy": 1.1, "ambient": "#b0b0c0"})
	var models := _list_models()
	var rows := int(ceil(float(models.size()) / PER_ROW))
	var width := PER_ROW * SPACING + 6.0
	var depth := rows * ROW_GAP + 24.0
	Kit.floor(self, Vector3(width * 0.5 - 3.0, 0, -(depth * 0.5) + 14.0), Vector2(width, depth), "stone/flagstone", {"tile": 2.0})
	for i in models.size():
		var r := i / PER_ROW
		var c := i % PER_ROW
		var pos := Vector3(c * SPACING + SPACING * 0.5, 0, -(r * ROW_GAP) - 4.0)
		Props.place(self, models[i], pos, 0.0, 1.0, {"collision": "none"})
		Kit.label(self, models[i], pos + Vector3(0, -0.3, 1.2), 0.0, 24, Color(0.95, 0.9, 0.7), "body", {"pixel_size": 0.008, "outline": 6})
	for r in rows:
		var z := -(r * ROW_GAP) - 4.0
		add_spawn("row%d" % r, Vector3(PER_ROW * SPACING * 0.5, 0.1, z + 9.5), 0.0)
		Kit.light(self, Vector3(PER_ROW * SPACING * 0.5, 5.0, z), Color(1, 0.95, 0.85), 1.5, 22.0)
	add_spawn("default", Vector3(PER_ROW * SPACING * 0.5, 0.1, 6.0), 0.0)
	Kit.label(self, "THE WORKSHOP", Vector3(PER_ROW * SPACING * 0.5, 3.5, -1.0), 0.0, 96, Color(0.9, 0.85, 0.7), "title")


static func _list_models() -> Array:
	var out: Array = []
	var d := DirAccess.open("res://assets/models")
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.ends_with(".glb"):
			out.append(f.get_basename())
		elif f.ends_with(".glb.import"):
			pass
		f = d.get_next()
	d.list_dir_end()
	out.sort()
	return out
