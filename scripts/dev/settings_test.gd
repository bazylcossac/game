extends Node
## `--test=settings`: the way back out of the settings, from the main menu and the pause menu.
## The back button must sit on screen at every window shape, and Esc must lead back too.
## Windowed with --out=<dir> it also saves a screenshot of each settings view.
var passed := 0
var failed := 0
var out_dir := ""

const SHAPES := [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1280, 1024), Vector2i(2560, 1080)]


func _ready() -> void:
	out_dir = Settings.arg("out", "")
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	var main := get_tree().current_scene
	main.call("_open_menu", "")
	var menu: MainMenu = main.get("_menu")
	await _frames(3)

	var panel := _panel(menu)
	_check("the main menu has a settings page", panel != null)
	for shape: Vector2i in SHAPES:
		get_window().size = shape
		menu.call("_show", "settings")
		await _frames(3)
		_check("main menu %s: the back button is on screen" % shape, _on_screen(panel.back_button))
		_check("main menu %s: the controls list is on screen or scrolls" % shape, _content_reachable(panel))
	get_window().size = Vector2i(1600, 900)
	await _frames(3)
	await _shot("menu_settings")

	_click(panel.back_button)
	await _frames(2)
	_check("the back button leads to the main page", _page(menu, "main").visible and not panel.visible)

	menu.call("_show", "settings")
	await _frames(2)
	await _press_escape()
	_check("Esc in the settings leads to the main page", _page(menu, "main").visible and not panel.visible)
	await _press_escape()
	_check("Esc on the main page leaves it alone", _page(menu, "main").visible)

	Net.start_offline({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	w.hud.deploy.call("_deploy")
	await _frames(3)
	var pause := w.hud.pause_menu
	pause.open()
	await _frames(2)
	var main_box: Control = pause.get("_main")
	var in_game: SettingsPanel = pause.get("_settings")
	pause.call("_show_settings")
	for shape: Vector2i in SHAPES:
		get_window().size = shape
		await _frames(3)
		_check("pause menu %s: the back button is on screen" % shape, _on_screen(in_game.back_button))
		_check("pause menu %s: the controls list is on screen or scrolls" % shape, _content_reachable(in_game))
	get_window().size = Vector2i(1600, 900)
	await _frames(3)
	await _shot("pause_settings")

	_click(in_game.back_button)
	await _frames(2)
	_check("the back button leads to the pause list", pause.visible and main_box.visible and not in_game.visible)

	pause.call("_show_settings")
	await _frames(2)
	await _press_escape()
	_check("Esc in the settings leads to the pause list, not the fight", pause.visible and main_box.visible and not in_game.visible)
	await _press_escape()
	_check("a second Esc closes the pause menu", not pause.visible)

	print("[settings] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _panel(menu: MainMenu) -> SettingsPanel:
	return (menu.get("_pages") as Dictionary).get("settings") as SettingsPanel


func _page(menu: MainMenu, key: String) -> Control:
	return (menu.get("_pages") as Dictionary)[key]


## Fully inside the visible part of the screen, and not clipped away by a scroll box.
func _on_screen(c: Control) -> bool:
	if c == null or not c.is_visible_in_tree():
		return false
	var screen := c.get_viewport().get_visible_rect()
	var r := c.get_global_rect()
	return r.size.x > 0 and r.size.y > 0 and screen.encloses(r)


## Either the whole body fits, or it sits in a scroll box that can reach its end.
func _content_reachable(p: SettingsPanel) -> bool:
	var scroll := p.body_scroll
	if not _on_screen(scroll):
		return false
	var body := scroll.get_child(0) as Control
	if body.size.y <= scroll.size.y + 1.0:
		return true
	return scroll.get_v_scroll_bar().max_value >= body.size.y - 1.0


func _click(b: Button) -> void:
	b.pressed.emit()


func _press_escape() -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(label: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(label + ".png"))


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[settings] %s %s" % ["PASS" if ok else "FAIL", label])
