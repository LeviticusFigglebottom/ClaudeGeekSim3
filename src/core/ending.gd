class_name Ending
## An ending, for now: the words, a fade, a flag, and the flat. The scenes
## that belong here are not made yet; until they are, every ending sets
## `ending_<kind>`, writes a note, and puts the sleeper back in bed.
##
##   await Ending.play("limbo", "The last rank", ["..."], Color.BLACK)


static func play(kind: String, title: String, lines: Array, color: Color = Color.BLACK) -> void:
	Game.set_flag("ending_" + kind, true)
	Game.bump("endings")
	if World.hud:
		await World.hud.say("", lines)
		await World.hud.fade_out(color, 3.0)
	Game.note("ending_" + kind, title, "An ending: %s. Its scene is not made yet, so for now you wake in the flat." % title.to_lower())
	World.travel("apartment", "bed", {"color": color, "duration": 0.8})
	await Engine.get_main_loop().create_timer(1.6).timeout
	Game.toast.emit("%s. (The ending's scene is not made yet.)" % title)
