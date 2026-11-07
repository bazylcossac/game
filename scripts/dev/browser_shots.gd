extends Node
## `--test=browser-shots --port=<port> --out=<dir>`, windowed, against a real `--server`: the server
## list, the side pick, the score table with ping, the pause menu and the respawn card.


func _ready() -> void:
	var port := int(Settings.arg("port", "17870"))
	var out := Settings.arg("out", "user://shots")
	DirAccess.make_dir_recursive_absolute(out)
	var main := get_tree().current_scene
	main.call("_open_menu", "")
	await _wait(0.5)
	var menu: Control = main.get("_menu")
	menu.call("_show", "multi")
	await _wait(0.4)
	await _shot(out, "lista_sprawdzanie")
	var browser: ServerBrowser = menu.get("_browser")
	var row: Dictionary = browser.get("_rows")[0]
	# Nothing listens one port up, and the real server stays out of this.
	ServerBrowser.asking = true
	row["address"] = "127.0.0.1"
	row["port"] = port + 1
	browser.refresh()
	await _wait(3.4)
	await _shot(out, "lista_nie_odpowiada")
	row["port"] = port
	browser.refresh()
	await _wait(0.8)
	await _shot(out, "lista_online")
	(row["join"] as Button).pressed.emit()
	await _wait(1.2)
	await _shot(out, "wybor_druzyny")
	Net.choose_side(C.Team.EMPIRE)
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	await _wait(2.5)
	await _shot(out, "rozmieszczenie")
	Net.send_deploy(1, -1, {})
	await _wait(1.5)
	Input.action_press("scoreboard")
	await _wait(0.7)
	await _shot(out, "tab_ping")
	Input.action_release("scoreboard")
	w.hud.pause_menu.open()
	await _wait(0.4)
	await _shot(out, "esc_odrodz")
	w.hud.pause_menu.call("_respawn")
	await _wait(1.0)
	await _shot(out, "odrodzenie")
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(out: String, name_id: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name_id])
	print("[shots] ", name_id)
