class_name PauseMenu
extends Control
## In-game menu. Pauses the simulation only in offline play.

var world: World
var _main: Control
var _settings: Control
var _built := false
var _mouse_before := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## The controller stops receiving input while the tree is paused, so Esc closes from here.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_built = true
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.035, 0.74)
	UiKit.fill(dim)
	add_child(dim)
	var center := CenterContainer.new()
	UiKit.fill(center)
	add_child(center)
	var panel := UiKit.panel(34)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(420, 0)
	_main = box
	stack.add_child(box)
	box.add_child(UiKit.label("PAUZA" if Net.mode == Net.Mode.OFFLINE else "MENU", 46, UiKit.INK, "title"))
	box.add_child(UiKit.accent_bar())
	for pair: Array in [["WRÓĆ DO WALKI", close], ["USTAWIENIA", _show_settings], ["WYJDŹ DO MENU GŁÓWNEGO", _leave]]:
		var b := UiKit.button(pair[0], pair[0] == "WRÓĆ DO WALKI")
		b.custom_minimum_size = Vector2(0, 54)
		b.pressed.connect(pair[1])
		box.add_child(b)

	var s := SettingsPanel.new()
	s.closed.connect(_hide_settings)
	s.visible = false
	_settings = s
	stack.add_child(s)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if not _built:
		_build()
	visible = true
	_hide_settings()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Net.mode == Net.Mode.OFFLINE:
		get_tree().paused = true


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Input.mouse_mode = _mouse_before
	world.controller.camera.fov = Settings.fov


func _show_settings() -> void:
	_main.visible = false
	_settings.visible = true


func _hide_settings() -> void:
	if _built:
		_main.visible = true
		_settings.visible = false


func _leave() -> void:
	get_tree().paused = false
	world.leave_requested.emit()
