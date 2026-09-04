extends Node
## Walks every brook of the King's Dream, headless, driven by injected input.
## Started by Main with `-- --area=kings_dream --spawn=from_king --brooks`.
##
## For each SeamlessTeleport in the area: put the player two metres short of it
## on its own side, facing the way it faces, hold forward for a moment, and
## check that they came out beside the seam's destination, that the area now
## counts that square as current, and that there is ground under their feet.
## Quits with 0 (pass) or 1 (fail).

var seams: Array = []
var i := -1
var step := 0
var t := 0.0
var failures: Array = []
var _done := false


func check(cond: bool, what: String) -> void:
	if cond:
		print("[brooks]   ok  " + what)
	else:
		print("[brooks] FAIL " + what)
		failures.append(what)


func _nearest_square(area: Node, pos: Vector3) -> int:
	var best := -1
	var best_d := 1e9
	for k in area.sq.size():
		var o: Vector3 = area.sq[k].origin
		var d := Vector2(pos.x - o.x, pos.z - o.z).length()
		if d < best_d:
			best_d = d
			best = k
	return best


func _process(delta: float) -> void:
	if _done:
		return
	t += delta
	var p := Game.player as Player
	var area := World.current_area
	match step:
		0:
			if World.current_area_id == "kings_dream" and not World.traveling and p != null and t > 1.0:
				for s in area.get_children():
					if s is SeamlessTeleport:
						seams.append(s)
				check(seams.size() >= 8, "the board has at least eight brooks (%d seams)" % seams.size())
				step = 1
				t = 0.0
		1:
			i += 1
			if i >= seams.size():
				step = 90
				return
			var s: SeamlessTeleport = seams[i]
			var fwd: Vector3 = -s.global_transform.basis.z
			var start: Vector3 = s.global_position - fwd * 2.5 + Vector3(0, 0.2, 0)
			p.teleport_to(Transform3D(Basis(Vector3.UP, atan2(-fwd.x, -fwd.z)), start))
			area._set_current(_nearest_square(area, start), false)
			Input.action_press("move_forward")
			step = 2
			t = 0.0
		2:
			if t > 1.6:
				Input.action_release("move_forward")
				var s: SeamlessTeleport = seams[i]
				var dest: Vector3 = s.dest.global_position
				var flat := Vector2(p.global_position.x - dest.x, p.global_position.z - dest.z).length()
				check(flat < 6.0 and absf(p.global_position.y - dest.y) < 2.0, "%s: came out beside its far bank (%.1f m off, dy %.1f)" % [s.name, flat, p.global_position.y - dest.y])
				var want := _nearest_square(area, dest)
				check(area.current == want, "%s: the area counts square %d as current (is %d)" % [s.name, want, area.current])
				check(p.is_on_floor(), "%s: there is ground under the player" % s.name)
				step = 1
				t = 0.0
		90:
			_done = true
			print("[brooks] %d failures" % failures.size())
			for f in failures:
				print("[brooks]   - " + f)
			get_tree().quit(1 if failures.size() > 0 else 0)
