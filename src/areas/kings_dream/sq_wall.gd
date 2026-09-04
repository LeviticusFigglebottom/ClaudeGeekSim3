class_name KDWall
extends RefCounted
## Square: the Wall. Built by KDArea; makes no spawn and no door.


static func build(_area: AreaBase, root: Node3D, ctx: Dictionary) -> Dictionary:
	var d: Dictionary = ctx.def
	Kit.floor(root, Vector3.ZERO, Vector2(KD.SQ, KD.SQ), String(d.ground), {"tint": d.tint, "tile": 2.0, "thick": 0.2})
	Kit.light(root, Vector3(0, 6, 0), Color(1.0, 0.95, 0.85), 1.0, 30.0)
	Kit.light(root, Vector3(-20, 5, 20), Color(1.0, 0.9, 0.8), 0.8, 24.0)
	Kit.light(root, Vector3(20, 5, -20), Color(0.9, 0.95, 1.0), 0.8, 24.0)
	Kit.label(root, String(d.name), Vector3(0, 4.0, -10.0), 0.0, 48, Color(1, 1, 1), "title", {"pixel_size": 0.03})
	var out := {}
	# the brook on top of the wall (a stand-in on the ground until the wall is built)
	if ctx.fords.has("WALL"):
		var f: Dictionary = ctx.fords["WALL"]
		var other: Dictionary = (ctx.area as Node).DEFS[int(f.other)]
		out["WALL"] = KD.ford(root, "W", 0.0, d, other)
	return out
