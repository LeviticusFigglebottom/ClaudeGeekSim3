extends AreaBase
## TEMPORARY kit-test build of the Static (replaced by the real area later).

func build() -> void:
	Realm.apply(self, "castle")
	var rows := [
		"##########",
		"#........#",
		"#..A.....#",
		"#........D....",
		"#....@...#   #",
		"#........#####",
		"##########",
	]
	var m := MapBuilder.build(self, rows, {"floor": "stone/flagstone_castle", "wall": "stone/blocks_castle", "ceiling": "", "origin": Vector3(-10, 0, -8), "no_ceiling": "", "height": 4.0})
	var spawn: Vector3 = m.first.call("@")
	add_spawn("default", spawn, 0.0)
	var a: Vector3 = m.first.call("A")
	Kit.light(self, a + Vector3(0, 2.5, 0), Color(1, 0.7, 0.4), 2.0, 10.0)
	Kit.box(self, a + Vector3(0, 0.5, 0), Vector3(1, 1, 1), "wood/crate")
	Kit.cylinder(self, a + Vector3(2, 0, 0), 0.4, 3.0, "stone/blocks_castle")
	Kit.sign(self, "props/painting_landscape", Vector3(-9.85, 1.8, -5), 90.0, Vector2(1.2, 1.2))
	Kit.label(self, "The Static", Vector3(-4, 3.2, -7.8), 0.0, 64)
	Kit.water(self, Vector3(-4, 0.05, -1), Vector2(4, 4))
	Kit.stairs(self, Vector3(-2, 0, 2), 0.0, 2.0, 4, 0.3, 0.5, "stone/blocks_castle")
	Kit.arch(self, Vector3(2, 0, -2), 0.0, 1.6, 2.4, "stone/blocks_nexus")
	Kit.particles(self, Vector3(-4, 2, -2), "motes", Vector3(6, 2, 6), 60)
