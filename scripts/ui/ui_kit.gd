class_name UiKit
extends RefCounted
## Shared look of the interface: palette, fonts, theme and small widget helpers.

const INK := Color(0.93, 0.92, 0.87)
const MUTED := Color(0.64, 0.65, 0.66)
const FAINT := Color(0.42, 0.44, 0.47)
const BRASS := Color(0.95, 0.71, 0.3)
const PANEL := Color(0.045, 0.05, 0.065, 0.86)
const PANEL_SOFT := Color(0.06, 0.066, 0.085, 0.66)
const LINE := Color(1, 1, 1, 0.09)
const BLUE := Color(0.3, 0.68, 1.0)
const RED := Color(1.0, 0.28, 0.2)
const GREEN := Color(0.42, 0.95, 0.5)

static var _fonts := {}
static var _theme: Theme


static func font(kind := "semibold") -> Font:
	if not _fonts.has(kind):
		var path: String = {
			"medium": "res://assets/fonts/BarlowCondensed-Medium.ttf",
			"semibold": "res://assets/fonts/BarlowCondensed-SemiBold.ttf",
			"bold": "res://assets/fonts/BarlowCondensed-Bold.ttf",
			"title": "res://assets/fonts/Anton-Regular.ttf",
		}[kind]
		_fonts[kind] = load(path)
	return _fonts[kind]


static func _box(bg: Color, border := Color(0, 0, 0, 0), bw := 0, skew := 0.0, radius := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.skew = Vector2(skew, 0)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.anti_aliasing = true
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("medium")
	t.default_font_size = 24
	t.set_color("font_color", "Label", INK)

	t.set_stylebox("normal", "Button", _box(Color(1, 1, 1, 0.055), LINE, 1, 0.22))
	t.set_stylebox("hover", "Button", _box(Color(0.95, 0.71, 0.3, 0.18), BRASS, 1, 0.22))
	t.set_stylebox("pressed", "Button", _box(Color(0.95, 0.71, 0.3, 0.34), BRASS, 1, 0.22))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", _box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.04), 1, 0.22))
	t.set_font("font", "Button", font("bold"))
	t.set_font_size("font_size", "Button", 26)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(1, 0.93, 0.76))
	t.set_color("font_pressed_color", "Button", Color(1, 0.93, 0.76))
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", FAINT)

	t.set_stylebox("panel", "PanelContainer", _box(PANEL, LINE, 1))
	t.set_stylebox("panel", "Panel", _box(PANEL, LINE, 1))

	var field := _box(Color(0, 0, 0, 0.4), LINE, 1)
	field.content_margin_left = 12
	t.set_stylebox("normal", "LineEdit", field)
	var field_focus := _box(Color(0, 0, 0, 0.5), BRASS, 1)
	field_focus.content_margin_left = 12
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_font("font", "LineEdit", font("semibold"))
	t.set_font_size("font_size", "LineEdit", 24)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", BRASS)
	t.set_color("selection_color", "LineEdit", Color(0.95, 0.71, 0.3, 0.35))

	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.1)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled := StyleBoxFlat.new()
	filled.bg_color = BRASS
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var grab := _grabber_icon()
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)

	t.set_font("font", "CheckBox", font("semibold"))
	t.set_font_size("font_size", "CheckBox", 24)
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", Color(1, 0.93, 0.76))
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_icon("checked", "CheckBox", _check_icon(true))
	t.set_icon("unchecked", "CheckBox", _check_icon(false))
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())

	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(1, 1, 1, 0.16)
	grabber.content_margin_left = 3
	grabber.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	_theme = t
	return t


static func _check_icon(on: bool) -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var edge := mini(mini(x, 23 - x), mini(y, 23 - y))
			if edge < 2:
				img.set_pixel(x, y, BRASS if on else MUTED)
			elif on and edge >= 5:
				img.set_pixel(x, y, BRASS)
	return ImageTexture.create_from_image(img)


static func _grabber_icon() -> ImageTexture:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	for y in 18:
		for x in 18:
			var d := Vector2(x - 8.5, y - 8.5).length()
			img.set_pixel(x, y, Color(0.98, 0.84, 0.55, clampf(8.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func label(text: String, size := 24, color := INK, kind := "medium") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func wrapped(text: String, size := 22, color := MUTED) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		b.add_theme_stylebox_override("normal", _box(BRASS, BRASS, 1, 0.22))
		b.add_theme_stylebox_override("hover", _box(Color(1.0, 0.82, 0.46), Color(1, 0.9, 0.7), 1, 0.22))
		b.add_theme_stylebox_override("pressed", _box(Color(0.82, 0.58, 0.22), BRASS, 1, 0.22))
		b.add_theme_stylebox_override("disabled", _box(Color(0.3, 0.27, 0.2, 0.7), Color(0, 0, 0, 0), 0, 0.22))
		for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color(0.08, 0.07, 0.05))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			Sfx.play("ui_hover", -10.0))
	b.pressed.connect(func() -> void: Sfx.play("ui_click", -6.0))
	return b


static func panel(margin := 24, bg := PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _box(bg, LINE, 1)
	s.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", s)
	return p


static func rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = LINE
	r.custom_minimum_size = Vector2(0, 1)
	return r


static func accent_bar(width := 56.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = BRASS
	r.custom_minimum_size = Vector2(width, 4)
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return r


## A labelled slider row. Calls `on_change` with the new value.
static func slider_row(title: String, min_v: float, max_v: float, step: float, value: float, fmt: String, on_change: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	var name_label := label(title, 22, MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := label(fmt % value, 22, INK, "semibold")
	head.add_child(name_label)
	head.add_child(val)
	box.add_child(head)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v: float) -> void:
		val.text = fmt % v
		on_change.call(v))
	box.add_child(s)
	return box


## Button background that stays readable over a bright sky.
static func dark_box() -> StyleBoxFlat:
	return _box(Color(0.03, 0.035, 0.05, 0.84), LINE, 1, 0.22)


## A button that stays lit while chosen.
static func toggle(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 22)
	var on := _box(Color(0.95, 0.71, 0.3, 0.26), BRASS, 1, 0.22)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	return b


## A row of mutually exclusive buttons. Returns the row; `on_pick` receives the index.
static func choice_row(title: String, options: Array, selected: int, on_pick: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(label(title, 22, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var buttons: Array[Button] = []
	for i in options.size():
		var b := toggle(options[i])
		b.button_pressed = i == selected
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.append(b)
		row.add_child(b)
	for i in buttons.size():
		buttons[i].pressed.connect(func() -> void:
			Sfx.play("ui_click", -6.0)
			for j in buttons.size():
				buttons[j].set_pressed_no_signal(j == i)
			on_pick.call(i))
	box.add_child(row)
	return box


static func fill(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c
