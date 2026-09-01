class_name UITheme
## Builds the game's Theme in code from the bundled OFL fonts.
##
## Fonts (assets/fonts): Jacquard 12 (blackletter pixel — titles), VT323
## (terminal — prompts and body), Metamorphous (dark-fantasy display — subtitles).

static var _theme: Theme = null
static var _fonts: Dictionary = {}

static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path := ""
	match kind:
		"title":
			path = "res://assets/fonts/Jacquard12-Regular.ttf"
		"display":
			path = "res://assets/fonts/Metamorphous-Regular.ttf"
		_:
			path = "res://assets/fonts/VT323-Regular.ttf"
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path)
		if f is FontFile:
			var ff: FontFile = f
			ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			ff.hinting = TextServer.HINTING_LIGHT
			ff.generate_mipmaps = false
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[kind] = f
	return f


static func build() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 22
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.04, 0.035, 0.05, 0.92)
	panel.border_color = Color(0.55, 0.48, 0.34, 1.0)
	panel.set_border_width_all(2)
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.08, 0.07, 0.09, 0.9)
	btn.border_color = Color(0.4, 0.35, 0.25)
	btn.set_border_width_all(1)
	btn.set_content_margin_all(8)
	var btn_hover := btn.duplicate()
	btn_hover.bg_color = Color(0.2, 0.16, 0.1, 0.95)
	btn_hover.border_color = Color(0.95, 0.8, 0.45)
	var btn_pressed := btn_hover.duplicate()
	btn_pressed.bg_color = Color(0.3, 0.22, 0.12, 1.0)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("focus", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_color("font_color", "Button", Color(0.85, 0.8, 0.7))
	t.set_color("font_hover_color", "Button", Color(1, 0.93, 0.75))
	t.set_color("font_focus_color", "Button", Color(1, 0.93, 0.75))
	t.set_font_size("font_size", "Button", 26)
	t.set_color("font_color", "Label", Color(0.88, 0.84, 0.76))
	t.set_color("default_color", "RichTextLabel", Color(0.88, 0.84, 0.76))
	t.set_font_size("normal_font_size", "RichTextLabel", 22)
	_theme = t
	return t
