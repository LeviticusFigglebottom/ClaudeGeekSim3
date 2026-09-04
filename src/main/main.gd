extends Node
## Main — wires the low-resolution 3D viewport, the persistent player, the HUD
## and the post-processing layer together, then either shows the title screen
## or (with `--area=<id>` after `--`) jumps straight into an area for testing.
##
##   godot --path . -- --area=forest --spawn=default --no-postfx

const PIXEL_SCALE := 3

@onready var container: SubViewportContainer = $ViewportContainer
@onready var viewport: SubViewport = $ViewportContainer/SubViewport
@onready var area_root: Node3D = $ViewportContainer/SubViewport/AreaRoot
@onready var player: Player = $ViewportContainer/SubViewport/Player
@onready var hud: HUD = $HUD

var postfx: CanvasLayer
var postfx_rect: ColorRect
var _shot_path := ""
var _shot_frames := 45
var _shot_look := Vector2.ZERO
var _has_look := false
var _shot_pos := Vector3.ZERO
var _has_pos := false
var _frame := 0
## The title screen looks out over the dream: a slow camera drifts through
## one realm after another behind the menu.
const TOUR := [["nexus", "default"], ["forest", "default"], ["city", "from_nexus"], ["tavern", "default"],
	["sea", "default"], ["cistern", "default"], ["castle", "from_nexus"], ["house", "porch"],
	["offices", "default"], ["clocktower", "from_city"], ["catacombs", "chapel"], ["furnace", "from_nexus"]]
const TOUR_SECONDS := 26.0
var title_cam: Camera3D = null
var touring := false
var _tour_i := 0
var _tour_target := Vector3.ZERO
var _tour_tween: Tween = null
## Web builds hold their HTML loading screen until the engine has drawn a few
## real frames; see web/shell.html.
var _web_frames := 0


func _ready() -> void:
	World.area_root = area_root
	World.hud = hud
	Game.player = player
	container.stretch_shrink = PIXEL_SCALE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_postfx()
	_apply_settings()
	Settings.changed.connect(func(_k: String, _v: Variant) -> void: _apply_settings())
	World.area_changed.connect(_on_area_changed)
	player.focus_changed.connect(_on_focus_changed)

	var start_area := ""
	var start_spawn := "default"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--area="):
			start_area = a.trim_prefix("--area=")
		elif a.begins_with("--spawn="):
			start_spawn = a.trim_prefix("--spawn=")
		elif a == "--no-postfx":
			postfx.visible = false
		elif a.begins_with("--pixel="):
			container.stretch_shrink = maxi(1, int(a.trim_prefix("--pixel=")))
		elif a.begins_with("--shot="):
			_shot_path = a.trim_prefix("--shot=")
		elif a.begins_with("--shot-frames="):
			_shot_frames = int(a.trim_prefix("--shot-frames="))
		elif a == "--playtest":
			var pt := Node.new()
			pt.name = "Playtest"
			pt.set_script(load("res://tools/playtest.gd"))
			add_child(pt)
		elif a.begins_with("--look="):
			var parts := a.trim_prefix("--look=").split(",")
			if parts.size() >= 2:
				_shot_look = Vector2(float(parts[0]), float(parts[1]))
				_has_look = true
		elif a.begins_with("--pos="):
			var parts := a.trim_prefix("--pos=").split(",")
			if parts.size() >= 3:
				_shot_pos = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
				_has_pos = true
	if start_area != "":
		Game.new_game()
		Game.set_flag("debug", true)
		_apply_debug_args()
		hud.hide_title()
		World.travel(start_area, start_spawn, {"duration": 0.2})
	else:
		hud.show_title()
		tour_start()


## Debug launch options (after `--`): --give=lantern,bell  --flag=hallway_measured
## --item=tape_measure  --visits=house:2  --lantern  --mirror  --small
## Screenshot placement: --pos=x,y,z (world) and --look=yaw,pitch (degrees)
func _apply_debug_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--give="):
			for k in a.trim_prefix("--give=").split(","):
				if k != "":
					Game.gain_keepsake(k)
		elif a.begins_with("--item="):
			for k in a.trim_prefix("--item=").split(","):
				if k != "":
					Game.gain_item(k)
		elif a.begins_with("--flag="):
			for k in a.trim_prefix("--flag=").split(","):
				if k != "":
					Game.set_flag(k, true)
		elif a.begins_with("--visits="):
			var parts := a.trim_prefix("--visits=").split(":")
			if parts.size() == 2:
				Game.visits[parts[0]] = int(parts[1])
		elif a == "--lantern":
			Game.equip("lantern")
			Game.lantern_lit = true
		elif a == "--mirror":
			Game.equip("shard")
			Game.mirror_sight = true
		elif a == "--small":
			Game.equip("mouse")
			Game.small = true


## Screenshot mode (`--shot=path.png`): wait a few frames for the area to settle,
## save the window image and quit. Used by tools/screenshots.sh for visual QA.
func _process(_delta: float) -> void:
	_signal_web_ready()
	if touring and title_cam and title_cam.current and title_cam.global_position.distance_to(_tour_target) > 0.5:
		title_cam.look_at(_tour_target)
	if _shot_path == "":
		return
	_frame += 1
	if _has_pos and Game.player and _frame == 5:
		Game.player.global_position = _shot_pos
	if _has_look and Game.player and _frame == 5:
		Game.player.set_look(deg_to_rad(_shot_look.x), deg_to_rad(_shot_look.y))
	if _frame == _shot_frames:
		var img := get_viewport().get_texture().get_image()
		var err := img.save_png(_shot_path)
		var where := ""
		if Game.player:
			where = " at %s yaw %.0f" % [Game.player.global_position, rad_to_deg(Game.player.yaw)]
		print("[shot] %s -> %s (%s)%s" % [World.current_area_id, _shot_path, "ok" if err == OK else str(err), where])
		get_tree().quit()


## The browser shows our loading screen until this fires: the first frames of a
## web build draw placeholder materials while the shaders compile, and nobody
## needs to watch that happen.
func _signal_web_ready() -> void:
	if _web_frames > 8 or not OS.has_feature("web"):
		return
	_web_frames += 1
	if _web_frames == 8:
		JavaScriptBridge.eval("window.anteroomReady && window.anteroomReady();", true)


func _build_postfx() -> void:
	postfx = CanvasLayer.new()
	postfx.name = "PostFX"
	postfx.layer = 1
	add_child(postfx)
	postfx_rect = ColorRect.new()
	postfx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	postfx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/shaders/postfx.gdshader")
	mat.set_shader_parameter("pixel_size", float(container.stretch_shrink))
	postfx_rect.material = mat
	postfx.add_child(postfx_rect)


func _exit_tree() -> void:
	Kit.clear_caches()
	Props.clear_caches()


func _on_area_changed(_area_id: String, _spawn_id: String) -> void:
	# the title tour travels too; that is not the player's dream to save
	if Game.started and not Game.has_flag("debug") and not hud.title_open:
		Game.save()


## Picture settings: how coarse the pixels are and how strong the dither is.
func _apply_settings() -> void:
	var px: int = clampi(int(Settings.get_value("pixel")), 1, 4)
	container.stretch_shrink = px
	if postfx_rect and postfx_rect.material is ShaderMaterial:
		var m := postfx_rect.material as ShaderMaterial
		m.set_shader_parameter("pixel_size", float(px))
		m.set_shader_parameter("dither_strength", 0.55 * clampf(float(Settings.get_value("dither")), 0.0, 1.5))


# --- the title tour ----------------------------------------------------------

func tour_start() -> void:
	if touring:
		return
	touring = true
	if title_cam == null:
		title_cam = Camera3D.new()
		title_cam.name = "TitleCamera"
		title_cam.fov = 68.0
		title_cam.near = 0.05
		viewport.add_child(title_cam)
	_tour_i = 0
	_tour_show()


func _tour_show() -> void:
	if not touring:
		return
	var entry: Array = TOUR[_tour_i % TOUR.size()]
	await World.travel(entry[0], entry[1], {"duration": 0.0, "silent": true})
	if not touring:
		return
	player.set_frozen(true)
	player.collider.disabled = true
	player.camera.current = false
	var sp: Transform3D = World.current_area.spawns.get(entry[1], Transform3D()) if World.current_area else Transform3D()
	var fwd := -sp.basis.z
	var right := sp.basis.x
	var from := sp.origin + Vector3(0, 1.6, 0) + right * 0.8 - fwd * 0.4
	var to := from + fwd * 4.0 - right * 2.2 + Vector3(0, 0.25, 0)
	_tour_target = sp.origin + Vector3(0, 1.3, 0) + fwd * 12.0
	title_cam.global_position = from
	title_cam.current = true
	title_cam.look_at(_tour_target)
	hud.fade_in(1.8)
	_tour_tween = create_tween()
	_tour_tween.tween_property(title_cam, "global_position", to, TOUR_SECONDS)
	_tour_tween.parallel().tween_property(self, "_tour_target", _tour_target + right * 5.0, TOUR_SECONDS)
	_tour_tween.tween_callback(_tour_advance)


func _tour_advance() -> void:
	if not touring:
		return
	_tour_i += 1
	await hud.fade_out(Color.BLACK, 1.2)
	_tour_show()


## Hand the world back to the player (called before a game starts).
func tour_stop() -> void:
	if not touring:
		return
	touring = false
	if _tour_tween:
		_tour_tween.kill()
	while World.traveling:
		await get_tree().process_frame
	if title_cam:
		title_cam.current = false
	player.collider.disabled = false
	player.camera.current = true


func _on_focus_changed(target: Node) -> void:
	if target == null:
		hud.set_prompt("")
	else:
		hud.set_prompt(String(target.prompt_text()))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("screenshot"):
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
		var path := "user://screenshots/%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
		img.save_png(path)
		hud.show_toast("Screenshot saved to " + ProjectSettings.globalize_path(path))
