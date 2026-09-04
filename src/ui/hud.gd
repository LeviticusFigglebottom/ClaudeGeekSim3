class_name HUD
extends CanvasLayer
## Everything drawn over the world: fades, prompts, keepsake panel, toasts, the
## area-name card, the dialogue box, the journal, the title screen and the
## pause menu. Built in code so it needs no scene editing to extend.

signal dialogue_finished
signal choice_made(index: int)

const TYPE_SPEED := 42.0

var fade: ColorRect
var prompt: Label
var crosshair: ColorRect
var toast_label: Label
var title_card: VBoxContainer
var area_title: Label
var area_sub: Label
var keepsake_box: HBoxContainer
var keepsake_icon: TextureRect
var keepsake_swatch: ColorRect
var keepsake_name: Label
var keepsake_verb: Label
var wake_bar: ProgressBar
var dialogue: PanelContainer
var speaker_label: Label
var dialogue_text: RichTextLabel
var choices_box: VBoxContainer
var journal_panel: PanelContainer
var journal_text: RichTextLabel
var journal_tabs: HBoxContainer
var title_screen: Control
var pause_menu: PanelContainer
var pause_buttons: VBoxContainer
var help_label: Label

var dialogue_active := false
var journal_open := false
var paused := false
var title_open := false
var settings_panel: PanelContainer
var settings_open := false
var _settings_back: Callable
var _toasts: Array[String] = []
var _toast_busy := false
var _lines: Array = []
var _line_index := 0
var _typing := false
var _choice_index := 0
var _choice_labels: Array[Label] = []
var _journal_tab := 0
var _title_tween: Tween


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var theme := UITheme.build()
	var root := Control.new()
	root.name = "Root"
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# crosshair
	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.55)
	crosshair.size = Vector2(4, 4)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-2, -2)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	# prompt
	prompt = _label(root, "", 26, "body", Color(0.95, 0.9, 0.78))
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.anchor_top = 1.0
	prompt.offset_top = -150
	prompt.offset_bottom = -110
	prompt.offset_left = -400
	prompt.offset_right = 400
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# wake bar
	wake_bar = ProgressBar.new()
	wake_bar.show_percentage = false
	wake_bar.min_value = 0.0
	wake_bar.max_value = 1.0
	wake_bar.set_anchors_preset(Control.PRESET_CENTER)
	wake_bar.offset_left = -80
	wake_bar.offset_right = 80
	wake_bar.offset_top = 40
	wake_bar.offset_bottom = 46
	wake_bar.visible = false
	wake_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wake_bar)

	# toast
	toast_label = _label(root, "", 24, "body", Color(0.9, 0.86, 0.7))
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_top = 40
	toast_label.offset_bottom = 80
	toast_label.offset_left = -500
	toast_label.offset_right = 500
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0

	# area title card
	title_card = VBoxContainer.new()
	title_card.set_anchors_preset(Control.PRESET_CENTER)
	title_card.offset_left = -500
	title_card.offset_right = 500
	title_card.offset_top = -160
	title_card.offset_bottom = -40
	title_card.alignment = BoxContainer.ALIGNMENT_CENTER
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_card.modulate.a = 0.0
	root.add_child(title_card)
	area_title = _label(title_card, "", 84, "title", Color(0.93, 0.88, 0.72))
	area_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area_sub = _label(title_card, "", 22, "display", Color(0.7, 0.65, 0.55))
	area_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# keepsake panel (bottom-left)
	keepsake_box = HBoxContainer.new()
	keepsake_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	keepsake_box.offset_left = 24
	keepsake_box.offset_top = -84
	keepsake_box.offset_bottom = -24
	keepsake_box.offset_right = 420
	keepsake_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(keepsake_box)
	keepsake_icon = TextureRect.new()
	keepsake_icon.custom_minimum_size = Vector2(56, 56)
	keepsake_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	keepsake_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	keepsake_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	keepsake_box.add_child(keepsake_icon)
	keepsake_swatch = ColorRect.new()
	keepsake_swatch.custom_minimum_size = Vector2(8, 56)
	keepsake_box.add_child(keepsake_swatch)
	var kv := VBoxContainer.new()
	kv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keepsake_box.add_child(kv)
	keepsake_name = _label(kv, "", 26, "display", Color(0.92, 0.88, 0.75))
	keepsake_verb = _label(kv, "", 20, "body", Color(0.6, 0.58, 0.5))
	keepsake_box.visible = false

	# help (top-right, fades after a while)
	help_label = _label(root, "", 20, "body", Color(0.55, 0.52, 0.45))
	help_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	help_label.offset_left = -520
	help_label.offset_right = -20
	help_label.offset_top = 16
	help_label.offset_bottom = 120
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help_label.text = "WASD move · mouse look · E interact · F use keepsake\nTab / Q cycle keepsakes · C crouch · J journal · hold R to wake"

	# dialogue box
	dialogue = PanelContainer.new()
	dialogue.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue.offset_left = 140
	dialogue.offset_right = -140
	dialogue.offset_top = -260
	dialogue.offset_bottom = -40
	dialogue.visible = false
	root.add_child(dialogue)
	var dv := VBoxContainer.new()
	dialogue.add_child(dv)
	speaker_label = _label(dv, "", 26, "display", Color(0.95, 0.8, 0.5))
	dialogue_text = RichTextLabel.new()
	dialogue_text.bbcode_enabled = true
	dialogue_text.fit_content = false
	dialogue_text.scroll_active = false
	dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_text.add_theme_font_size_override("normal_font_size", 26)
	dv.add_child(dialogue_text)
	choices_box = VBoxContainer.new()
	dv.add_child(choices_box)

	# journal
	journal_panel = PanelContainer.new()
	journal_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	journal_panel.offset_left = 120
	journal_panel.offset_right = -120
	journal_panel.offset_top = 60
	journal_panel.offset_bottom = -60
	journal_panel.visible = false
	root.add_child(journal_panel)
	var jv := VBoxContainer.new()
	journal_panel.add_child(jv)
	var jt := _label(jv, "Dream Journal", 64, "title", Color(0.93, 0.88, 0.72))
	jt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	journal_tabs = HBoxContainer.new()
	journal_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	jv.add_child(journal_tabs)
	for tab_name in ["Entries", "Keepsakes", "Pockets", "Wanderings"]:
		var l := _label(journal_tabs, "  " + tab_name + "  ", 24, "display", Color(0.6, 0.56, 0.48))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	journal_text = RichTextLabel.new()
	journal_text.bbcode_enabled = true
	journal_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal_text.scroll_active = true
	jv.add_child(journal_text)
	var jh := _label(jv, "A / D or Q / Tab: change page · J or Esc: close", 20, "body", Color(0.5, 0.48, 0.42))
	jh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# pause menu
	pause_menu = PanelContainer.new()
	pause_menu.set_anchors_preset(Control.PRESET_CENTER)
	pause_menu.offset_left = -220
	pause_menu.offset_right = 220
	pause_menu.offset_top = -220
	pause_menu.offset_bottom = 220
	pause_menu.visible = false
	root.add_child(pause_menu)
	pause_buttons = VBoxContainer.new()
	pause_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_menu.add_child(pause_buttons)
	var pt := _label(pause_buttons, "paused", 56, "title", Color(0.93, 0.88, 0.72))
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(pause_buttons, "resume", toggle_pause)
	_button(pause_buttons, "save", func() -> void:
		Game.save()
		show_toast("Saved to slot %d." % Game.slot))
	_button(pause_buttons, "settings", func() -> void:
		open_settings(func() -> void: pause_menu.visible = true))
	_button(pause_buttons, "wake up", func() -> void:
		toggle_pause()
		World.wake())
	_button(pause_buttons, "return to title", func() -> void:
		Game.save()
		toggle_pause()
		show_title()
		var main := get_parent()
		if main and main.has_method("tour_start"):
			main.tour_start())
	_button(pause_buttons, "quit", func() -> void:
		Game.save()
		get_tree().quit())

	# title screen
	title_screen = Control.new()
	title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_screen.visible = false
	root.add_child(title_screen)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.03, 0.42)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(bg)
	var tv := VBoxContainer.new()
	tv.set_anchors_preset(Control.PRESET_CENTER)
	tv.offset_left = -300
	tv.offset_right = 300
	tv.offset_top = -240
	tv.offset_bottom = 240
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	title_screen.add_child(tv)
	var tt := _label(tv, "ANTEROOM", 150, "title", Color(0.93, 0.88, 0.72))
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ts := _label(tv, "a dream of doors", 26, "display", Color(0.55, 0.5, 0.42))
	ts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	tv.add_child(spacer)
	var title_buttons := VBoxContainer.new()
	title_buttons.name = "Buttons"
	tv.add_child(title_buttons)
	var tf := _label(tv, "the flat has a door it did not have yesterday", 20, "body", Color(0.35, 0.33, 0.3))
	tf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_build_settings(root)

	# fade (topmost)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	Game.toast.connect(show_toast)
	Game.keepsake_equipped.connect(func(_id: String) -> void: _refresh_keepsake())
	Game.keepsake_gained.connect(func(_id: String) -> void: _refresh_keepsake())
	_refresh_keepsake()
	set_process(true)


func _label(parent: Node, text: String, size: int, kind: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UITheme.font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _process(delta: float) -> void:
	var p := Game.player as Player
	if p != null and not title_open:
		var wp: float = p.wake_progress()
		wake_bar.visible = wp > 0.05
		wake_bar.value = wp
	if help_label.visible and Game.stats.playtime > 90.0:
		help_label.modulate.a = maxf(0.0, help_label.modulate.a - delta * 0.3)
		if help_label.modulate.a <= 0.0:
			help_label.visible = false
	if _typing and dialogue_text.visible_characters < dialogue_text.get_total_character_count():
		dialogue_text.visible_characters = mini(dialogue_text.get_total_character_count(),
			dialogue_text.visible_characters + int(ceil(TYPE_SPEED * delta)))
		if dialogue_text.visible_characters >= dialogue_text.get_total_character_count():
			_typing = false


func _input(event: InputEvent) -> void:
	# Mouse look is forwarded from here (the root viewport) so it never depends
	# on events propagating into the SubViewport. Clicking while the cursor is
	# free re-captures it.
	if event is InputEventMouseMotion and not title_open and not paused and Game.player:
		# screen_relative is unaffected by the window stretch, so sensitivity is stable
		Game.player.on_mouse_motion(event.screen_relative)
	elif event is InputEventMouseButton and event.pressed and not title_open and not paused and not journal_open:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		Settings.toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if settings_open:
		if event.is_action_pressed("pause"):
			close_settings()
			get_viewport().set_input_as_handled()
		return
	if title_open:
		return
	if dialogue_active:
		if _choice_labels.size() > 0:
			if event.is_action_pressed("move_forward") or event.is_action_pressed("keepsake_prev"):
				_move_choice(-1)
			elif event.is_action_pressed("move_back") or event.is_action_pressed("keepsake_next"):
				_move_choice(1)
			elif event.is_action_pressed("dialogue_advance") or event.is_action_pressed("interact"):
				_confirm_choice()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("dialogue_advance") or event.is_action_pressed("interact"):
			_advance_dialogue()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if journal_open:
			toggle_journal()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	if event.is_action_pressed("journal"):
		toggle_journal()
		get_viewport().set_input_as_handled()
		return
	if journal_open:
		if event.is_action_pressed("move_right") or event.is_action_pressed("keepsake_next"):
			_journal_tab = wrapi(_journal_tab + 1, 0, 4)
			_refresh_journal()
		elif event.is_action_pressed("move_left") or event.is_action_pressed("keepsake_prev"):
			_journal_tab = wrapi(_journal_tab - 1, 0, 4)
			_refresh_journal()
		get_viewport().set_input_as_handled()


# --- fades ---------------------------------------------------------------

func fade_out(color: Color = Color.BLACK, duration: float = 0.7) -> void:
	fade.color = Color(color.r, color.g, color.b, fade.color.a)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, duration)
	await tw.finished


func fade_in(duration: float = 0.7) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, duration)


func fade_to(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, duration)
	await tw.finished


# --- prompts / toasts / cards --------------------------------------------

func set_prompt(text: String) -> void:
	if text == "":
		prompt.text = ""
	else:
		prompt.text = "[%s]  %s" % [InputSetup.key_hint("interact"), text]


func show_toast(text: String) -> void:
	_toasts.append(text)
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toasts.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	toast_label.text = _toasts.pop_front()
	var tw := create_tween()
	tw.tween_property(toast_label, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.2 + toast_label.text.length() * 0.03)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_next_toast)


func show_area_name(area_name: String, subtitle: String = "") -> void:
	area_title.text = area_name
	area_sub.text = subtitle
	if _title_tween:
		_title_tween.kill()
	title_card.modulate.a = 0.0
	_title_tween = create_tween()
	_title_tween.tween_interval(0.3)
	_title_tween.tween_property(title_card, "modulate:a", 1.0, 1.2)
	_title_tween.tween_interval(2.6)
	_title_tween.tween_property(title_card, "modulate:a", 0.0, 1.6)


func _refresh_keepsake() -> void:
	var id := Game.active_keepsake
	if id == "" or not Game.KEEPSAKES.has(id):
		keepsake_box.visible = Game.keepsakes.size() > 0
		keepsake_name.text = "empty hands"
		keepsake_verb.text = "Tab to hold something" if Game.keepsakes.size() > 0 else ""
		keepsake_swatch.color = Color(0.3, 0.3, 0.3)
		keepsake_icon.texture = null
		return
	var k: Dictionary = Game.KEEPSAKES[id]
	keepsake_box.visible = true
	keepsake_name.text = k.name
	keepsake_verb.text = "%s: %s" % [InputSetup.key_hint("use_keepsake"), k.verb]
	keepsake_swatch.color = k.color
	var icon_path := "res://assets/textures/ui/keepsake_%s.png" % id
	keepsake_icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null


# --- dialogue ------------------------------------------------------------

## Show lines of dialogue one by one. `await hud.say("The Barkeep", ["...", "..."])`.
func say(speaker: String, lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines.duplicate()
	_line_index = 0
	dialogue_active = true
	_lock_player(true)
	dialogue.visible = true
	speaker_label.text = speaker
	speaker_label.visible = speaker != ""
	_clear_choices()
	_show_line()
	await dialogue_finished


func _show_line() -> void:
	dialogue_text.text = String(_lines[_line_index])
	dialogue_text.visible_characters = 0
	_typing = true
	Audio.sfx("ui_blip", null, -18.0)


func _advance_dialogue() -> void:
	if _typing:
		dialogue_text.visible_characters = -1
		_typing = false
		return
	_line_index += 1
	if _line_index < _lines.size():
		_show_line()
	else:
		_end_dialogue()


func _end_dialogue() -> void:
	dialogue.visible = false
	dialogue_active = false
	_clear_choices()
	_lock_player(false)
	dialogue_finished.emit()


## Ask a question with options; returns the chosen index.
## `var i: int = await hud.ask("The Barkeep", "What'll it be?", ["Ale", "Answers"])`.
func ask(speaker: String, text: String, options: Array) -> int:
	dialogue_active = true
	_lock_player(true)
	dialogue.visible = true
	speaker_label.text = speaker
	speaker_label.visible = speaker != ""
	dialogue_text.text = text
	dialogue_text.visible_characters = -1
	_typing = false
	_clear_choices()
	_choice_index = 0
	for i in options.size():
		var l := _label(choices_box, "", 24, "body", Color(0.8, 0.76, 0.66))
		l.text = "   " + String(options[i])
		_choice_labels.append(l)
	_highlight_choice()
	var idx: int = await choice_made
	return idx


func _clear_choices() -> void:
	for c in choices_box.get_children():
		c.queue_free()
	_choice_labels.clear()


func _move_choice(dir: int) -> void:
	_choice_index = wrapi(_choice_index + dir, 0, _choice_labels.size())
	_highlight_choice()
	Audio.sfx("ui_blip", null, -20.0)


func _highlight_choice() -> void:
	for i in _choice_labels.size():
		var l := _choice_labels[i]
		var base := String(l.text).strip_edges()
		if base.begins_with("> "):
			base = base.substr(2)
		if i == _choice_index:
			l.text = " > " + base
			l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
		else:
			l.text = "   " + base
			l.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))


func _confirm_choice() -> void:
	var idx := _choice_index
	dialogue.visible = false
	dialogue_active = false
	_clear_choices()
	_lock_player(false)
	choice_made.emit(idx)


func _lock_player(locked: bool) -> void:
	if Game.player:
		Game.player.input_locked = locked


# --- journal ---------------------------------------------------------------

func toggle_journal() -> void:
	journal_open = not journal_open
	journal_panel.visible = journal_open
	_lock_player(journal_open)
	if journal_open:
		Audio.sfx("page", null, -10.0)
		_refresh_journal()


func _refresh_journal() -> void:
	for i in journal_tabs.get_child_count():
		var l: Label = journal_tabs.get_child(i)
		l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7) if i == _journal_tab else Color(0.5, 0.47, 0.4))
	var s := ""
	match _journal_tab:
		0:
			if Game.journal.is_empty():
				s = "[i]The pages are blank. They fill themselves in as you go.[/i]"
			for e in Game.journal:
				s += "[b][color=#efd9a0]%s[/color][/b]\n%s\n\n" % [e.title, e.text]
		1:
			for id in Game.KEEPSAKES:
				var k: Dictionary = Game.KEEPSAKES[id]
				if Game.has_keepsake(id):
					var held := "  [color=#9fd3c7](holding)[/color]" if Game.active_keepsake == id else ""
					s += "[b][color=#efd9a0]%s[/color][/b]%s\n%s\n\n" % [k.name, held, k.desc]
				else:
					s += "[b][color=#6a6458]? ? ?[/color][/b]\n[color=#6a6458][i]%s[/i][/color]\n\n" % _obscure(String(k.where))
		2:
			var any := false
			for id in Game.ITEMS:
				if Game.has_item(id):
					any = true
					var it: Dictionary = Game.ITEMS[id]
					var n := Game.item_count(id)
					s += "[b][color=#efd9a0]%s[/color][/b]%s\n%s\n\n" % [it.name, (" ×%d" % n) if n > 1 else "", it.desc]
			if not any:
				s = "[i]Your pockets are empty. Your pockets are always empty here.[/i]"
		3:
			s += "[b]Places[/b]\n"
			for id in AreaRegistry.AREAS:
				var n := Game.visits_to(id)
				if n > 0:
					s += "  %s — %d %s\n" % [World.area_name(id), n, "visit" if n == 1 else "visits"]
				else:
					s += "  [color=#6a6458]? ? ?[/color]\n"
			s += "\n[b]Numbers[/b]\n  doors: %d\n  times woken: %d\n  times fallen out of the world: %d\n  walked: %d m\n  dreamt for: %s\n" % [
				Game.stats.doors, Game.stats.wakes, Game.stats.falls, int(Game.stats.distance), _fmt_time(Game.stats.playtime)]
			if Game.count("bells_rung") > 0:
				s += "  bells rung: %d\n" % Game.count("bells_rung")
	journal_text.text = s


static func _obscure(text: String) -> String:
	# Hide most of a hint; a few words leak through.
	var words := text.split(" ")
	var out := PackedStringArray()
	for i in words.size():
		var w := words[i]
		if i % 3 == 1 and w.length() > 3:
			out.append(w)
		else:
			out.append("—".repeat(mini(w.length(), 6)))
	return " ".join(out)


static func _fmt_time(t: float) -> String:
	var m := int(t / 60.0)
	var s := int(t) % 60
	return "%d:%02d" % [m, s]


# --- pause ----------------------------------------------------------------

func toggle_pause() -> void:
	paused = not paused
	pause_menu.visible = paused
	get_tree().paused = paused
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED)
	if paused:
		var first := pause_buttons.get_child(1) as Button
		if first:
			first.grab_focus()


# --- title -------------------------------------------------------------------

func show_title() -> void:
	title_open = true
	title_screen.visible = true
	keepsake_box.visible = false
	prompt.text = ""
	crosshair.visible = false
	help_label.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	fade.color.a = 0.0
	_title_menu()


func _title_buttons() -> VBoxContainer:
	var buttons := title_screen.find_child("Buttons", true, false) as VBoxContainer
	for c in buttons.get_children():
		buttons.remove_child(c)
		c.queue_free()
	return buttons


func _title_menu() -> void:
	var buttons := _title_buttons()
	var first: Button = null
	var latest := Game.latest_slot()
	if latest > 0:
		first = _button(buttons, "continue", func() -> void: _continue_game(latest))
	var b := _button(buttons, "new dream", func() -> void: _slot_picker("new"))
	if first == null:
		first = b
	if latest > 0:
		_button(buttons, "load a dream", func() -> void: _slot_picker("load"))
	_button(buttons, "settings", func() -> void: open_settings(_title_menu))
	if not OS.has_feature("web"):
		_button(buttons, "quit", func() -> void: get_tree().quit())
	first.call_deferred("grab_focus")


## Three slots. A new dream goes into an empty one, or asks before it takes a
## used one; loading lists the ones that are used.
func _slot_picker(mode: String) -> void:
	var buttons := _title_buttons()
	var first: Button = null
	for i in range(1, Game.SLOTS + 1):
		var summary := Game.slot_summary(i)
		var used := not summary.is_empty()
		if mode == "load" and not used:
			continue
		var text := "slot %d — %s" % [i, _slot_text(summary)]
		var slot_i := i
		var cb: Callable
		if mode == "load":
			cb = func() -> void: _continue_game(slot_i)
		elif used:
			cb = func() -> void: _confirm_overwrite(slot_i)
		else:
			cb = func() -> void: _new_game(slot_i)
		var b := _button(buttons, text, cb)
		if first == null:
			first = b
	var back := _button(buttons, "back", _title_menu)
	if first == null:
		first = back
	first.call_deferred("grab_focus")


func _confirm_overwrite(slot_i: int) -> void:
	var buttons := _title_buttons()
	var l := _label(buttons, "slot %d holds a dream. forget it?" % slot_i, 22, "body", Color(0.75, 0.6, 0.5))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(buttons, "keep it", func() -> void: _slot_picker("new"))
	var yes := _button(buttons, "forget it and dream again", func() -> void: _new_game(slot_i))
	yes.call_deferred("grab_focus")


static func _slot_text(summary: Dictionary) -> String:
	if summary.is_empty():
		return "empty"
	var area := String(summary.get("area", ""))
	var where := String(AreaRegistry.info(area).get("name", area)) if AreaRegistry.has(area) else "asleep"
	return "%s · %d keepsake%s · %s" % [where, int(summary.keepsakes), "" if int(summary.keepsakes) == 1 else "s", _fmt_time(float(summary.playtime))]


func hide_title() -> void:
	title_open = false
	title_screen.visible = false
	crosshair.visible = true
	help_label.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_refresh_keepsake()


func _leave_title() -> void:
	var main := get_parent()
	if main and main.has_method("tour_stop"):
		await main.tour_stop()
	hide_title()


func _new_game(slot_i: int = 0) -> void:
	await _leave_title()
	Game.new_game(slot_i if slot_i >= 1 else maxi(1, Game.first_free_slot()))
	fade.color = Color(1, 1, 1, 1)
	World.travel(AreaRegistry.STARTING_AREA, AreaRegistry.STARTING_SPAWN, {"color": Color.WHITE, "duration": 2.2})


func _continue_game(slot_i: int = 0) -> void:
	await _leave_title()
	var d := Game.load_save(slot_i)
	fade.color = Color(0, 0, 0, 1)
	var area := String(d.get("area", AreaRegistry.STARTING_AREA))
	var spawn := String(d.get("spawn", AreaRegistry.STARTING_SPAWN))
	if not World.has_area(area):
		area = AreaRegistry.STARTING_AREA
		spawn = AreaRegistry.STARTING_SPAWN
	World.travel(area, spawn, {"duration": 1.2})


# --- settings ---------------------------------------------------------------

func _build_settings(root: Node) -> void:
	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -300
	settings_panel.offset_right = 300
	settings_panel.offset_top = -280
	settings_panel.offset_bottom = 280
	settings_panel.visible = false
	root.add_child(settings_panel)
	var v := VBoxContainer.new()
	v.name = "Rows"
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_panel.add_child(v)


func _settings_rows() -> VBoxContainer:
	var v := settings_panel.get_node("Rows") as VBoxContainer
	for c in v.get_children():
		v.remove_child(c)
		c.queue_free()
	return v


func _slider(parent: Node, text: String, key: String, lo: float, hi: float, step: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _label(row, text, 22, "body", Color(0.8, 0.76, 0.66))
	l.custom_minimum_size = Vector2(230, 0)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = float(Settings.get_value(key))
	sl.custom_minimum_size = Vector2(260, 24)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.focus_mode = Control.FOCUS_ALL
	sl.value_changed.connect(func(val: float) -> void:
		Settings.set_value(key, int(val) if step >= 1.0 else val))
	row.add_child(sl)
	return sl


func open_settings(back: Callable) -> void:
	_settings_back = back
	settings_open = true
	pause_menu.visible = false
	var v := _settings_rows()
	var t := _label(v, "settings", 56, "title", Color(0.93, 0.88, 0.72))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var h := _label(v, "how much of the dream is the picture", 20, "body", Color(0.5, 0.48, 0.42))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var first := _slider(v, "pixel dither", "dither", 0.0, 1.0, 0.05)
	_slider(v, "vertex wobble", "wobble", 0.0, 1.0, 0.05)
	_slider(v, "texture warp", "warp", 0.0, 1.0, 0.05)
	_slider(v, "pixel size", "pixel", 1.0, 4.0, 1.0)
	_slider(v, "mouse speed", "mouse", 0.3, 2.5, 0.1)
	_slider(v, "volume", "volume", 0.0, 1.0, 0.05)
	var fs := CheckButton.new()
	fs.text = "fullscreen  (F11)"
	fs.button_pressed = Settings.is_fullscreen() if DisplayServer.get_name() != "headless" else bool(Settings.get_value("fullscreen"))
	fs.toggled.connect(func(on: bool) -> void:
		Settings.values["fullscreen"] = on
		Settings.set_fullscreen(on, true)
		Settings.save())
	v.add_child(fs)
	_button(v, "as it was dreamt", func() -> void:
		Settings.reset()
		open_settings(_settings_back))
	_button(v, "back", close_settings)
	if title_open:
		_title_buttons()
	settings_panel.visible = true
	first.call_deferred("grab_focus")


func close_settings() -> void:
	settings_open = false
	settings_panel.visible = false
	if _settings_back.is_valid():
		_settings_back.call()
