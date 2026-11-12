extends Node
## Root of the app. Swaps between the menu and a running world, and picks the launch
## mode from the command line. Pass arguments after `--`, for example:
##   Godot --headless -- --server --port=7777 --mode=pvp --map=rynek --name="Mój serwer"
## A dedicated server is for players only. --bots=12 --difficulty=1 fills it with bots after all.

var _menu: MainMenu = null
var _world: World = null
var _loading: CanvasLayer = null
var _tester: Node = null


func _ready() -> void:
	Net.world_requested.connect(_on_world_requested)
	Net.side_requested.connect(_on_side_requested)
	Net.connect_failed.connect(_on_connect_failed)
	Net.session_ended.connect(_on_session_ended)
	if Settings.has_arg("real-levels"):
		Gear.everyone_max = false
	if Settings.has_arg("server"):
		_start_dedicated()
		return
	if Settings.has_arg("test"):
		_tester = load("res://scripts/dev/autotest.gd").new()
		add_child(_tester)
		return
	_open_menu("")


func _start_dedicated() -> void:
	var port := int(Settings.arg("port", str(C.DEFAULT_PORT)))
	var bots := int(Settings.arg("bots", "0"))
	var cfg := Modes.normalize({
		"seed": int(Settings.arg("seed", "1943")),
		"bots_per_team": bots,
		"no_bots": bots <= 0,
		"difficulty": int(Settings.arg("difficulty", "1")),
		"mode": Settings.arg("mode"),
		"map": Settings.arg("map"),
		"limit": int(Settings.arg("limit", "0")),
	})
	if Settings.arg("mode") != "" and Settings.arg("mode") != cfg["mode"]:
		printerr("[server] nie ma trybu %s, dostępne: %s" % [Settings.arg("mode"), ", ".join(Modes.LIST.keys())])
	if Settings.arg("map") != "" and Settings.arg("map") != cfg["map"]:
		printerr("[server] tryb %s nie ma mapy %s, dostępne: %s" % [cfg["mode"], Settings.arg("map"), ", ".join(Modes.mode_of(cfg)["maps"])])
	Net.server_name = Settings.arg("name").strip_edges().left(40)
	var err := Net.start_dedicated(cfg, port)
	if err != OK:
		printerr("[server] nie można otworzyć portu %d: %s" % [port, error_string(err)])
		get_tree().quit(1)
		return
	print("[server] %s %s nasłuchuje na porcie %d, botów na drużynę: %d" % [C.GAME_TITLE, C.VERSION, port, cfg["bots_per_team"]])
	print("[server] tryb: %s, mapa: %s" % [Modes.mode_of(cfg)["name"], Modes.MAPS[cfg["map"]]["name"]])


func _open_menu(status: String) -> void:
	_close_world()
	if _menu == null:
		_menu = MainMenu.new()
		UiKit.fill(_menu)
		add_child(_menu)
		_menu.play_offline.connect(func(cfg: Dictionary) -> void: Net.start_offline(cfg))
		_menu.host_game.connect(_on_host)
		_menu.join_game.connect(_on_join)
	_menu.close_side_pick()
	_menu.set_status(status)


func _on_host(cfg: Dictionary, port: int) -> void:
	var err := Net.start_host(cfg, port)
	if err != OK and _menu:
		_menu.set_status(T.t("Nie można założyć serwera: %s") % error_string(err))


func _on_join(address: String, port: int) -> void:
	var nick := Settings.player_name.strip_edges()
	var err := Net.start_client(address, port, nick if nick != "" else "Bojownik", true)
	if _menu:
		_menu.set_status(T.t("Łączenie z %s:%d...") % [address, port] if err == OK else T.t("Błąd połączenia: %s") % error_string(err))


func _on_side_requested(cfg: Dictionary, counts: Array) -> void:
	if _menu:
		_menu.show_side_pick(cfg, counts)


func _on_connect_failed(reason: String) -> void:
	_open_menu(reason)


func _on_session_ended(reason: String) -> void:
	_open_menu(reason)


func _on_world_requested(cfg: Dictionary) -> void:
	if Net.mode == Net.Mode.DEDICATED:
		_spawn_world(cfg)
		return
	_show_loading(Modes.normalize(cfg))
	# Let the loading screen reach the display before the map build blocks the frame.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if _menu:
		_menu.queue_free()
		_menu = null
	Sfx.stop_music(0.6)
	_spawn_world(cfg)
	_hide_loading()


func _spawn_world(cfg: Dictionary) -> void:
	_world = World.new()
	_world.setup(cfg)
	_world.leave_requested.connect(_on_leave)
	add_child(_world)


func _close_world() -> void:
	if _world:
		_world.queue_free()
		_world = null
	get_tree().paused = false


func _on_leave() -> void:
	Net.leave()
	_open_menu("")


func _show_loading(cfg: Dictionary) -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 50
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.05)
	UiKit.fill(bg)
	_loading.add_child(bg)
	var c := CenterContainer.new()
	UiKit.fill(c)
	_loading.add_child(c)
	var box := VBoxContainer.new()
	c.add_child(box)
	var t := UiKit.label(C.GAME_TITLE, 72, UiKit.INK, "title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var s := UiKit.label("%s  ·  %s" % [Modes.mode_of(cfg)["name"], Modes.MAPS[cfg["map"]]["name"]], 28, UiKit.BRASS, "semibold")
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	add_child(_loading)


func _hide_loading() -> void:
	if _loading:
		_loading.queue_free()
		_loading = null
