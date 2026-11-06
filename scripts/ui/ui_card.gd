class_name UiCard
extends Button
## A picture that works as a choice. The menu uses it for modes, maps and sides.

static var _shade: GradientTexture2D

var selected := false:
	set(value):
		selected = value
		_paint()

var _accent := UiKit.BRASS
var _hovered := false
var _picture: TextureRect
var _frame: Panel
var _title: Label


func setup(picture: Texture2D, title: String, note := "", accent := UiKit.BRASS, emblem: Texture2D = null) -> UiCard:
	_accent = accent
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

	_picture = TextureRect.new()
	_picture.texture = picture
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(UiKit.fill(_picture))
	var shade := TextureRect.new()
	shade.texture = _shade_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(UiKit.fill(shade))

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(UiKit.fill(margin))
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_END
	text.add_theme_constant_override("separation", 0)
	margin.add_child(text)
	_title = UiKit.label(title, 30, UiKit.INK, "title")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_title)
	if note != "":
		text.add_child(UiKit.wrapped(note, 21, UiKit.INK))
	if emblem:
		var mark := TextureRect.new()
		mark.texture = emblem
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.position = Vector2(14, 12)
		mark.size = Vector2(64, 64)
		add_child(mark)

	_frame = Panel.new()
	add_child(UiKit.fill(_frame))
	_ignore_mouse(self)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	pressed.connect(func() -> void: Sfx.play("ui_click", -6.0))
	_paint()
	return self


func _set_hover(on: bool) -> void:
	_hovered = on
	if on:
		Sfx.play("ui_hover", -10.0)
	_paint()


func _paint() -> void:
	if _frame == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.set_border_width_all(3 if selected else (2 if _hovered else 1))
	box.border_color = _accent if selected else (Color(_accent, 0.7) if _hovered else UiKit.LINE)
	_frame.add_theme_stylebox_override("panel", box)
	var light := 1.0 if selected else (0.86 if _hovered else 0.6)
	_picture.modulate = Color(light, light, light)
	_title.add_theme_color_override("font_color", _accent if selected else UiKit.INK)


func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)


static func _shade_texture() -> GradientTexture2D:
	if _shade == null:
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.02, 0.025, 0.035, 0.0))
		ramp.set_color(1, Color(0.02, 0.025, 0.035, 0.94))
		ramp.set_offset(0, 0.38)
		_shade = GradientTexture2D.new()
		_shade.gradient = ramp
		_shade.fill_from = Vector2(0, 0)
		_shade.fill_to = Vector2(0, 1)
		_shade.width = 4
		_shade.height = 128
	return _shade
