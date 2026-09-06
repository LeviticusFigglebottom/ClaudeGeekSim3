class_name Ending
## An ending: the flag, the note, the last words at the place of choosing,
## and then the scene. The scenes live in the `ending` area, one for each
## kind, chosen by Game.ending_kind:
##
##   await Ending.play("limbo", "The last rank", ["..."], Color.BLACK)
##
## whole      lying down in room 5½: the two of you agreeing, and waking up
## limbo      the last square: the king in the corner, staying
## unplugged  the plug: the last channel going off, and what that is
## m          the chair: the visitor's afternoon


static func play(kind: String, title: String, lines: Array, color: Color = Color.BLACK) -> void:
	Game.set_flag("ending_" + kind, true)
	Game.bump("endings")
	Game.ending_kind = kind
	if World.hud:
		await World.hud.say("", lines)
	Game.note("ending_" + kind, title, "An ending: %s." % title.to_lower())
	World.travel("ending", kind, {"color": color, "duration": 2.4, "in_duration": 3.5, "silent": true})
