extends Node
## Scripted end-to-end smoke test, driven by injected input. Started by Main when
## the game is launched with `-- --playtest` (works headless):
##
##   godot --headless --path . -- --area=apartment --spawn=bed --playtest
##
## Walks, looks, interacts with the bed, checks that the dream started, rings
## through the HUD dialogue, then quits with 0 (pass) or 1 (fail).

var step := 0
var t := 0.0
var failures: Array = []
var start_pos := Vector3.ZERO
var start_yaw := 0.0
var _done := false
var _presses := 0


func _ready() -> void:
	print("[playtest] starting")


func _press(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	get_viewport().push_input(ev)
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _aim_at_bed(p: Player) -> void:
	var beds := World.current_area.find_children("*", "Bed", true, false)
	if beds.is_empty():
		return
	var b: Node3D = beds[0]
	var target := b.global_position + Vector3(0, 0.6, 0)
	var d := target - p.eye_position()
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	p.set_look(yaw, clampf(pitch, -1.2, 1.2))


func check(cond: bool, what: String) -> void:
	if cond:
		print("[playtest]   ok  " + what)
	else:
		print("[playtest] FAIL " + what)
		failures.append(what)


func _process(delta: float) -> void:
	if _done:
		return
	t += delta
	var p := Game.player as Player
	match step:
		0:
			if World.current_area_id != "" and not World.traveling and p != null and t > 1.0:
				start_pos = p.global_position
				start_yaw = p.yaw
				Input.action_press("move_forward")
				step = 1
				t = 0.0
		1:
			if t > 0.8:
				Input.action_release("move_forward")
				check(p.global_position.distance_to(start_pos) > 0.5, "walking forward moves the player (%.2f m)" % p.global_position.distance_to(start_pos))
				var ev := InputEventMouseMotion.new()
				ev.relative = Vector2(40, 0)
				ev.screen_relative = Vector2(40, 0)
				ev.position = Vector2(640, 360)
				get_viewport().push_input(ev)
				step = 2
				t = 0.0
		2:
			if t > 0.2:
				check(absf(wrapf(p.yaw - start_yaw, -PI, PI)) > 0.02, "mouse motion turns the view (%.3f rad)" % absf(wrapf(p.yaw - start_yaw, -PI, PI)))
				_aim_at_bed(p)
				step = 3
				t = 0.0
		3:
			if t > 0.3:
				var f := p.focus
				check(f != null, "something is in focus after turning (%s)" % (f.name if f else "nothing"))
				if f != null and f is Bed:
					Input.action_press("interact")
					step = 4
				else:
					# nudge toward the bed and retry a few times
					Input.action_press("move_forward")
					step = 30
				t = 0.0
		30:
			if t > 0.4:
				Input.action_release("move_forward")
				_aim_at_bed(p)
				step = 3
				t = 0.0
				if Game.stats.playtime > 20.0:
					check(false, "could not focus the bed")
					step = 90
		4:
			if t > 0.1:
				Input.action_release("interact")
				step = 5
				t = 0.0
		5:
			if World.current_area_id == "nexus" and not World.traveling:
				check(true, "sleeping in the bed travels to the Anteroom")
				check(Game.visits_to("nexus") == 1, "visit count recorded")
				step = 6
				t = 0.0
			elif t > 8.0:
				check(false, "bed did not travel to the nexus (area=%s)" % World.current_area_id)
				step = 90
		6:
			if t > 0.5:
				# interact with the plaque via a direct call to test dialogue + save
				var plaque := World.current_area.get_node_or_null("Plaque")
				check(plaque != null, "the Anteroom has its plaque")
				if plaque:
					plaque.interact(p)
				step = 7
				t = 0.0
		7:
			if t > 0.3:
				check(World.hud.dialogue_active, "dialogue opened")
				_presses = 0
				step = 8
				t = 0.0
		8:
			# press advance until the dialogue closes (skip typing, next line, ...)
			if t > 0.15:
				t = 0.0
				if World.hud.dialogue_active and _presses < 12:
					_press("dialogue_advance", true)
					_presses += 1
					step = 9
				else:
					step = 11
		9:
			if t > 0.1:
				_press("dialogue_advance", false)
				step = 8
				t = 0.0
		11:
			if t > 0.5:
				check(not World.hud.dialogue_active, "dialogue closed after %d presses" % _presses)
				check(Game.has_note("plaque"), "reading the plaque wrote a journal note")
				Game.gain_keepsake("bell")
				check(Game.active_keepsake == "bell", "gaining a keepsake equips it")
				Input.action_press("use_keepsake")
				step = 12
				t = 0.0
		12:
			if t > 0.1:
				Input.action_release("use_keepsake")
				step = 13
				t = 0.0
		13:
			if t > 0.5:
				check(Game.has_flag("nexus_bell_rung"), "ringing the bell in the Anteroom sets nexus_bell_rung")
				check(Game.save(), "save() writes a file")
				Input.action_press("wake")
				step = 14
				t = 0.0
		14:
			if World.current_area_id == "apartment" and not World.traveling:
				Input.action_release("wake")
				check(true, "holding R wakes up in the flat")
				check(Game.has_flag("has_woken"), "waking sets has_woken")
				step = 90
			elif t > 6.0:
				Input.action_release("wake")
				check(false, "wake did not return to the flat")
				step = 90
		90:
			_done = true
			print("[playtest] %d failures" % failures.size())
			for f in failures:
				print("[playtest]   - " + f)
			get_tree().quit(1 if failures.size() > 0 else 0)
