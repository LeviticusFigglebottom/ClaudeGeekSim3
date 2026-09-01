class_name InputSetup
## Guarantees the input actions exist at runtime.
##
## project.godot defines the same actions for the editor; this fallback keeps
## headless runs (and anyone who regenerates project settings) working, and it
## is the single place that documents the default controls.

const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_C, KEY_CTRL],
	"interact": [KEY_E],
	"use_keepsake": [KEY_F],
	"keepsake_next": [KEY_TAB],
	"keepsake_prev": [KEY_Q],
	"wake": [KEY_R],
	"journal": [KEY_J],
	"pause": [KEY_ESCAPE],
	"dialogue_advance": [KEY_SPACE, KEY_E, KEY_ENTER],
	"screenshot": [KEY_F12],
}

const MOUSE := {
	"interact": MOUSE_BUTTON_LEFT,
	"use_keepsake": MOUSE_BUTTON_RIGHT,
	"keepsake_next": MOUSE_BUTTON_WHEEL_DOWN,
	"keepsake_prev": MOUSE_BUTTON_WHEEL_UP,
	"dialogue_advance": MOUSE_BUTTON_LEFT,
}

static func ensure() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		if MOUSE.has(action):
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE[action]
			InputMap.action_add_event(action, mb)

## Human readable hint for the HUD ("E" for interact etc.).
static func key_hint(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k: InputEventKey = ev
			var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			if k.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(code)
			return OS.get_keycode_string(code)
	return "?"
