extends Node
## `--test=modes-shots --out=<dir>`, windowed: every new map from fixed views, plus the HUD,
## deploy screen, scoreboard and menus of every mode. Prints what it saved.

## Map views as [label, feet position, yaw, pitch].
const VIEWS := {
	"neonowa_dzielnica": [
		["bulwar", Vector3(16, 0.2, 150), 0.0, 0.12], ["plac", Vector3(20, 0.2, 58), 0.3, 0.05],
		["aleja", Vector3(176, 0.2, 190), 0.0, 0.1], ["przecznica", Vector3(-40, 0.2, 80), PI * 0.5, 0.1],
		["park", Vector3(40, 0.2, 110), -2.4, 0.05], ["mapa", Vector3(0, 420, 0.5), 0.0, -1.5],
	],
	"stacja_rdzen": [
		["reaktor", Vector3(0, 0.2, 14), 0.0, 0.1], ["korytarz", Vector3(0, 0.2, 42), 0.0, 0.0],
		["kriogenika", Vector3(-31, 0.2, 36), 0.0, 0.0], ["ladownia", Vector3(31, 0.2, 14), 0.0, 0.0],
		["galeria", Vector3(-14, 3.9, 10), -0.6, -0.1], ["dok", Vector3(0, 0.2, 54), 0.5, 0.05],
		["mapa", Vector3(0, 40, 0.5), 0.0, -1.5],
	],
	"rynek": [
		["plac", Vector3(0, 0.2, 16), 0.0, -0.02], ["plac_z_gory", Vector3(-30, 22.0, 26), -0.8, -0.5],
		["zaulek", Vector3(-44, 0.2, 32), PI * 0.5 + 1.1, 0.0], ["brzeg", Vector3(-60, 0.2, 57), -1.5, 0.02],
		["mapa", Vector3(0, 150.0, 0.5), 0.0, -1.5],
	],
	"pole_bitwy": [
		["wzgorze", Vector3(-122, 0.2, 30), 0.0, 0.0], ["okop", Vector3(-40, 0.2, 30), -1.4, 0.03],
		["folwark", Vector3(4, 0.2, 40), 0.0, 0.02], ["mlyn", Vector3(100, 0.2, 10), -0.9, 0.05],
		["baza", Vector3(0, 0.2, 100), PI, 0.0], ["mapa", Vector3(0, 320.0, 0.5), 0.0, -1.5],
	],
}

var out_dir := ""
var _n := 0


func _ready() -> void:
	out_dir = Settings.arg("out", "user://shots")
	if Settings.has_arg("lang"):
		T.apply(Settings.arg("lang"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.apply_display()
	var only := Settings.arg("only", "")
	if only == "" or only == "menu":
		await _menu_pages()
	if only == "" or only == "mapy":
		await _map_views("pvp", "rynek")
		await _map_views("czolgi", "pole_bitwy")
	if only == "" or only == "nowe":
		await _map_views("pvp", "neonowa_dzielnica")
		await _map_views("pvp", "stacja_rdzen")
	if only == "" or only == "hud":
		await _hud("deathmatch", "rynek")
		await _hud("pvp", "neonowa_dzielnica")
		await _hud("czolgi", "pole_bitwy")
		await _hud("podboj", "stare_miasto")
	get_tree().quit(0)


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var path := "%s/%02d_%s.png" % [out_dir, _n, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("[shot] ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _start(mode: String, map: String, extra := {}) -> World:
	var cfg := {"mode": mode, "map": map, "difficulty": 0}
	cfg.merge(extra)
	Net.start_offline(Modes.normalize(cfg))
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	return Net.world


func _stop() -> void:
	get_tree().current_scene.call("_close_world")
	await get_tree().process_frame
	Net.leave()
	await get_tree().process_frame


func _enter(w: World) -> void:
	await _wait(0.4)
	w.hud.deploy.call("_deploy")
	while w.local == null or not w.local.alive:
		await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _wait(0.2)


func _hold(w: World, pos: Vector3, yaw: float, pitch: float, frames: int) -> void:
	var s := w.local
	s.protected_t = 99999.0
	for i in frames:
		var p := pos
		if pos.y < 1.0:
			p.y = w.map.ground_height(pos.x, pos.z) + 0.2
		s.teleport(p)
		s.velocity = Vector3.ZERO
		s.yaw = yaw
		s.pitch = pitch
		await get_tree().process_frame


func _map_views(mode: String, map: String) -> void:
	var w: World = await _start(mode, map, {"bots_per_team": 2})
	await _enter(w)
	w.hud.canvas.visible = false
	w.hud.minimap.visible = false
	for v: Array in VIEWS[map]:
		await _hold(w, v[1], v[2], v[3], 14)
		await _shot("%s_%s" % [map, v[0]])
	await _stop()


func _hud(mode: String, map: String) -> void:
	var w: World = await _start(mode, map)
	await _wait(1.2)
	await _shot("%s_rozmieszczenie" % mode)
	w.hud.deploy.call("_show_tab", 0)
	await _enter(w)
	await _wait(1.0)
	await _shot("%s_hud" % mode)
	await _wait(8.0)
	await _shot("%s_walka" % mode)
	Input.action_press("scoreboard")
	await _wait(0.3)
	await _shot("%s_wyniki" % mode)
	Input.action_release("scoreboard")
	w.server.end_match(w.local.sid if w.ffa else 0)
	await _wait(0.5)
	await _shot("%s_koniec" % mode)
	await _stop()


func _menu_pages() -> void:
	var main := get_tree().current_scene
	main.call("_open_menu", "")
	var menu: MainMenu = main.get("_menu")
	await _wait(2.5)
	await _shot("menu_glowne")
	menu.call("_show", "credits")
	await _wait(0.2)
	await _shot("autorzy")
	menu.call("_show", "settings")
	await _wait(0.2)
	await _shot("ustawienia")
	menu.call("_show", "battle")
	for id: String in Modes.LIST:
		Settings.match_mode = id
		Settings.match_map = ""
		menu.call("_refresh_options")
		await _wait(0.3)
		await _shot("menu_%s" % id)
	menu.call("_show", "multi")
	await _wait(0.2)
	await _shot("menu_siec")
	menu.call("_show", "host")
	await _wait(0.2)
	await _shot("menu_serwer")
	Settings.match_mode = Modes.DEFAULT_MODE
	menu.queue_free()
	main.set("_menu", null)
	await get_tree().process_frame
