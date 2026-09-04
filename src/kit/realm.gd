class_name Realm
## Environment presets: one atmosphere per realm (fog, ambient, sun, sky dome).
##
## `Realm.apply(area, "forest")` adds a WorldEnvironment, an optional
## DirectionalLight3D and a sky dome that follows the camera. Returns the nodes
## so an area can tweak them (the Slow Sea shifts its sky colours over time).

const PRESETS := {
	"waking": {"bg": "#0d0c12", "ambient": "#6a6058", "ambient_energy": 0.74, "fog": "#141216", "fog_density": 0.022, "sun": [-35, 40, "#b8a888", 0.25], "sky": "sky/night"},
	"corridor": {"bg": "#0a0b0e", "ambient": "#6e7a6e", "ambient_energy": 0.68, "fog": "#0c0e10", "fog_density": 0.038, "sun": null, "sky": ""},
	"hallway": {"bg": "#000000", "ambient": "#8a8ea0", "ambient_energy": 1.4, "fog": "#020204", "fog_density": 0.022, "sun": null, "sky": ""},
	"nexus": {"bg": "#0b0a18", "ambient": "#4a4870", "ambient_energy": 0.94, "fog": "#100e24", "fog_density": 0.026, "sun": [-60, 20, "#8a86c0", 0.2], "sky": "sky/nexus"},
	"forest": {"bg": "#061a18", "ambient": "#3a6a5e", "ambient_energy": 0.94, "fog": "#0f2a25", "fog_density": 0.034, "sun": [-50, -30, "#8fd0bc", 0.35], "sky": "sky/forest"},
	"city": {"bg": "#2a2f3a", "ambient": "#7a8090", "ambient_energy": 1.01, "fog": "#4a5060", "fog_density": 0.022, "sun": [-30, 60, "#c9c2b0", 0.6], "sky": "sky/city"},
	"tavern": {"bg": "#0a0604", "ambient": "#6a4a30", "ambient_energy": 0.61, "fog": "#140c06", "fog_density": 0.030, "sun": null, "sky": ""},
	"house": {"bg": "#050812", "ambient": "#4a4a60", "ambient_energy": 0.61, "fog": "#0a0d1a", "fog_density": 0.030, "sun": [-70, 10, "#7a86b0", 0.15], "sky": "sky/house"},
	"castle": {"bg": "#0c0a18", "ambient": "#5a5070", "ambient_energy": 0.74, "fog": "#1a1428", "fog_density": 0.026, "sun": [-45, 30, "#9a8ab8", 0.3], "sky": "sky/castle"},
	"sea": {"bg": "#2b1a47", "ambient": "#b7a6f0", "ambient_energy": 1.22, "fog": "#b7a6f0", "fog_density": 0.009, "sun": [-40, -60, "#fff3dd", 0.7], "sky": "sky/sea"},
	"catacombs": {"bg": "#050403", "ambient": "#4a4434", "ambient_energy": 0.62, "fog": "#0a0806", "fog_density": 0.045, "sun": null, "sky": ""},
	"furnace": {"bg": "#0a0204", "ambient": "#6a1a1e", "ambient_energy": 0.81, "fog": "#2a0508", "fog_density": 0.030, "sun": [-80, 0, "#ff5a1f", 0.25], "sky": "sky/furnace"},
	"cistern": {"bg": "#0a2a2c", "ambient": "#8fc7c2", "ambient_energy": 1.08, "fog": "#2f8f95", "fog_density": 0.034, "sun": null, "sky": "sky/cistern"},
	"offices": {"bg": "#d8c26a", "ambient": "#e8dca0", "ambient_energy": 1.22, "fog": "#c4ad55", "fog_density": 0.038, "sun": null, "sky": ""},
	"clocktower": {"bg": "#0c0a18", "ambient": "#6a5a40", "ambient_energy": 0.74, "fog": "#1a1410", "fog_density": 0.022, "sun": [-40, 50, "#b58a3c", 0.35], "sky": "sky/castle"},
	"static": {"bg": "#5a5a5a", "ambient": "#9a9a9a", "ambient_energy": 1.35, "fog": "#7a7a7a", "fog_density": 0.015, "sun": null, "sky": "sky/static"},
	"kings_dream": {"bg": "#4a2a58", "ambient": "#f0cfc0", "ambient_energy": 1.34, "fog": "#f0cfc0", "fog_density": 0.010, "sun": [-38, -65, "#fff2cf", 0.8], "sky": "sky/kings_dream"},
	"promotion": {"bg": "#1a1424", "ambient": "#b8a8c8", "ambient_energy": 1.15, "fog": "#3a2c48", "fog_density": 0.012, "sun": [-45, -30, "#e8d8ff", 0.6], "sky": "sky/kings_mind"},
	"kings_mind": {"bg": "#1a1030", "ambient": "#d8b8d0", "ambient_energy": 1.2, "fog": "#c8a8c8", "fog_density": 0.007, "sun": [-30, -120, "#ffd8e8", 0.7], "sky": "sky/kings_mind"},
	"mirror": {"bg": "#0a1818", "ambient": "#4a7070", "ambient_energy": 0.94, "fog": "#0e2424", "fog_density": 0.026, "sun": [-60, 200, "#86c0c0", 0.2], "sky": "sky/nexus"},
}


static func apply(area: Node3D, preset: String, overrides: Dictionary = {}) -> Dictionary:
	var p: Dictionary = PRESETS.get(preset, PRESETS["waking"]).duplicate()
	for k in overrides:
		p[k] = overrides[k]
	var out := {}
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(p.bg)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(p.ambient)
	env.ambient_light_energy = float(p.ambient_energy)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if p.get("fog", "") != "":
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = Color(p.fog)
		env.fog_light_energy = 1.0
		env.fog_density = float(p.fog_density)
		env.fog_sky_affect = 0.0
		env.fog_aerial_perspective = 0.0
	var we := WorldEnvironment.new()
	we.name = "Env"
	we.environment = env
	area.add_child(we)
	out["env"] = env
	out["world_env"] = we
	if p.get("sun") != null:
		var s: Array = p.sun
		var sun := Kit.sun(area, float(s[0]), float(s[1]), Color(s[2]), float(s[3]), bool(p.get("shadows", true)))
		sun.name = "Sun"
		out["sun"] = sun
	if p.get("sky", "") != "":
		out["sky"] = sky_dome(area, String(p.sky), p.get("sky_opts", {}))
	return out


## A big inside-out sphere with the sky shader, kept centred on the camera.
static func sky_dome(area: Node3D, gradient_tex: String, opts: Dictionary = {}) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = float(opts.get("radius", 250.0))
	sm.height = sm.radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	var mi := MeshInstance3D.new()
	mi.name = "SkyDome"
	mi.mesh = sm
	var mat := ShaderMaterial.new()
	mat.shader = Kit.shader("sky")
	mat.set_shader_parameter("gradient_tex", Kit.tex(gradient_tex))
	mat.set_shader_parameter("detail_tex", Kit.tex(String(opts.get("detail", "common/stars"))))
	mat.set_shader_parameter("detail_strength", float(opts.get("detail_strength", 0.0)))
	mat.set_shader_parameter("band_strength", float(opts.get("band_strength", 0.0)))
	mat.set_shader_parameter("band_speed", float(opts.get("band_speed", 0.3)))
	mat.set_shader_parameter("tint", opts.get("tint", Color.WHITE))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	mi.set_script(load("res://src/kit/sky_follow.gd"))
	area.add_child(mi)
	return mi
