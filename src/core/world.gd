extends Node
## World — the machinery of travel between areas. Autoloaded as `World`.
##
## An area is a scene whose root extends `AreaBase`. Travel unloads the current
## area, instantiates the next one under `area_root`, drops the player on the
## requested spawn point and fades back in. The registry lives in
## `src/data/areas.gd` (`AreaRegistry`).

signal travel_started(area_id: String, spawn_id: String)
signal area_changed(area_id: String, spawn_id: String)
signal area_built(area: Node3D)

var current_area: Node3D = null
var current_area_id := ""
var current_spawn_id := ""
var previous_area_id := ""
var traveling := false
## Set by Main: the Node3D inside the low-res SubViewport that areas are parented to.
var area_root: Node3D = null
## Set by Main: the HUD (fades, area name toasts).
var hud: Node = null
## When true (headless tours, tests) travel skips fades and waits.
var quiet := false


func info(area_id: String) -> Dictionary:
	return AreaRegistry.info(area_id)

func has_area(area_id: String) -> bool:
	return AreaRegistry.has(area_id)

func area_name(area_id: String) -> String:
	return String(info(area_id).get("name", area_id))


## Travel to `area_id`, arriving at `spawn_id`.
## opts: color (fade colour), duration, silent (no area name toast), keep_velocity
func travel(area_id: String, spawn_id: String = "default", opts: Dictionary = {}) -> void:
	if traveling:
		return
	if not has_area(area_id):
		push_error("World.travel: unknown area '%s'" % area_id)
		return
	if area_root == null:
		push_error("World.travel: no area_root set (is Main running?)")
		return
	traveling = true
	travel_started.emit(area_id, spawn_id)
	var color: Color = opts.get("color", Color.BLACK)
	var dur: float = float(opts.get("duration", 0.7))
	if Game.player and Game.player.has_method("set_frozen"):
		Game.player.set_frozen(true)
	if hud and not quiet:
		await hud.fade_out(color, dur)
	_unload_current()
	var scene_path: String = info(area_id).scene
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("World.travel: could not load %s" % scene_path)
		traveling = false
		return
	var area := scene.instantiate()
	previous_area_id = current_area_id
	current_area_id = area_id
	current_spawn_id = spawn_id
	area_root.add_child(area)
	current_area = area
	var n := Game.visit(area_id)
	Game.set_flag("visited_" + area_id, true)
	_place_player(area, spawn_id)
	if area.has_method("on_enter"):
		area.on_enter(spawn_id, n)
	area_built.emit(area)
	Audio.set_ambience(String(info(area_id).get("ambience", "")))
	if not quiet:
		await get_tree().process_frame
		await get_tree().process_frame
	if Game.player and Game.player.has_method("set_frozen"):
		Game.player.set_frozen(false)
	if hud and not quiet:
		hud.fade_in(dur)
		if not opts.get("silent", false):
			hud.show_area_name(area_name(area_id), String(info(area_id).get("subtitle", "")))
	traveling = false
	area_changed.emit(area_id, spawn_id)


## Return to the flat. Keepsakes come with you; the toggles do not.
func wake() -> void:
	Game.stats.wakes += 1
	Game.reset_toggles()
	Game.set_flag("has_woken", true)
	travel("apartment", "bed", {"color": Color.WHITE, "duration": 1.4})


## Falling out of the world lands you between channels.
func fall_out() -> void:
	Game.stats.falls += 1
	Game.reset_toggles()
	travel("static", "default", {"color": Color.WHITE, "duration": 0.15})


## Re-enter the current area at a spawn (used by loops that need a rebuild).
func reload_here(spawn_id: String = "default", opts: Dictionary = {}) -> void:
	if current_area_id != "":
		travel(current_area_id, spawn_id, opts)


func spawn_transform(area: Node, spawn_id: String) -> Transform3D:
	if "spawns" in area:
		var spawns: Dictionary = area.spawns
		if spawns.has(spawn_id):
			return spawns[spawn_id]
	var m := area.find_child("Spawn_" + spawn_id, true, false)
	if m is Node3D:
		return (m as Node3D).global_transform
	if "spawns" in area and area.spawns.has("default"):
		push_warning("World: area '%s' has no spawn '%s'; using default" % [current_area_id, spawn_id])
		return area.spawns["default"]
	push_warning("World: area '%s' has no spawn '%s' and no default" % [current_area_id, spawn_id])
	return Transform3D(Basis(), Vector3(0, 1, 0))


func _place_player(area: Node, spawn_id: String) -> void:
	if Game.player == null:
		return
	var t := spawn_transform(area, spawn_id)
	if Game.player.has_method("teleport_to"):
		Game.player.teleport_to(t)
	else:
		Game.player.global_transform = t


func _unload_current() -> void:
	if current_area == null:
		return
	if current_area.has_method("on_exit"):
		current_area.on_exit()
	area_root.remove_child(current_area)
	current_area.queue_free()
	current_area = null
