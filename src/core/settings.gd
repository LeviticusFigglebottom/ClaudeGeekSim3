extends Node
## Player preferences: how much PS1 the picture has, fullscreen, mouse speed,
## volume. Kept in user://settings.json, apart from the dream itself, so they
## survive new games and follow the player between save slots.
##
## The look settings scale what the areas authored: 1.0 is the picture as
## built, 0.0 is clean. The defaults sit a little under 1.0 on purpose.

const PATH := "user://settings.json"
const DEFAULTS := {
	"dither": 0.42,      # ordered dither strength in the post-process (authored 0.55)
	"wobble": 0.8,       # vertex snapping (0 = no wobble)
	"warp": 0.7,         # affine texture warp (0 = perspective-correct)
	"pixel": 3,          # render at 1/pixel of the window
	"levels": 32,        # colour steps per channel in the post-process (256 = none)
	"aura": 0.6,         # how visible the glow on things you can use is
	"fullscreen": true,
	"mouse": 1.0,
	"volume": 1.0,
}

signal changed(key: String, value: Variant)

var values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	load_settings()
	for k in values:
		apply(k)


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	values[key] = value
	apply(key)
	save()
	changed.emit(key, value)


func reset() -> void:
	for k in DEFAULTS:
		set_value(k, DEFAULTS[k])


func apply(key: String) -> void:
	var v: Variant = values.get(key)
	match key:
		"wobble":
			RenderingServer.global_shader_parameter_set("ps1_wobble", clampf(float(v), 0.0, 1.0))
		"warp":
			RenderingServer.global_shader_parameter_set("ps1_warp", clampf(float(v), 0.0, 1.0))
		"aura":
			RenderingServer.global_shader_parameter_set("aura_opacity", clampf(float(v), 0.0, 1.0))
		"fullscreen":
			set_fullscreen(bool(v), false)
		"volume":
			var bus := AudioServer.get_bus_index("Master")
			AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(float(v), 0.0, 1.0)))
			AudioServer.set_bus_mute(bus, float(v) <= 0.001)
		_:
			pass   # dither, pixel and mouse are read by Main and the Player


func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## In a browser fullscreen only works from a click or key press, so the
## startup application is skipped there; the F11 toggle still works.
func set_fullscreen(on: bool, from_gesture: bool = true) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if OS.has_feature("web") and not from_gesture:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if not on and not OS.has_feature("web"):
		DisplayServer.window_set_size(Vector2i(1280, 720))
		var screen := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen - Vector2i(1280, 720)) / 2)


func toggle_fullscreen() -> void:
	var on := not is_fullscreen()
	values["fullscreen"] = on
	set_fullscreen(on, true)
	save()
	changed.emit("fullscreen", on)


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(values, "\t"))
		f.close()


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		for k in DEFAULTS:
			if parsed.has(k):
				values[k] = parsed[k]
