class_name LanguageSwitch
extends HBoxContainer
## The PL / EN toggle. Every copy follows the language chosen on any of them.

var _buttons: Array[Button] = []


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 6)
	for code: String in T.LANGUAGES:
		var b := UiKit.toggle(code.to_upper())
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(72, 44)
		b.add_theme_stylebox_override("normal", UiKit.dark_box())
		b.pressed.connect(_pick.bind(code))
		add_child(b)
		_buttons.append(b)
	Settings.language_changed.connect(_sync)
	_sync()


func _pick(code: String) -> void:
	Sfx.play("ui_click", -6.0)
	Settings.set_language(code)
	_sync()


func _sync() -> void:
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(T.LANGUAGES[i] == Settings.language)
