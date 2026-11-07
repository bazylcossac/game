extends Node
## `--test=lang`, headless: Polish stays Polish, every name in the data has an English version, the
## English text keeps its format codes, and nothing on the menu or deploy screen is left in Polish.

const POLISH_LETTERS := "ąćęłńóśźżĄĆĘŁŃÓŚŹŻ"

var passed := 0
var failed := 0


func _ready() -> void:
	await get_tree().process_frame
	_basics()
	_formats()
	_data()
	await _screens()
	T.apply("pl")
	print("[lang] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("[lang] FAIL ", label)


func _basics() -> void:
	T.apply("pl")
	_check("Polish text is untouched", T.t("Mapa") == "Mapa" and T.t("MAPA") == "MAPA")
	var packed := T.pack("Artyleria gotowa za %d s.", [12])
	_check("packed text reads in Polish", T.t(packed) == "Artyleria gotowa za 12 s.")
	T.apply("en")
	_check("English text is found", T.t("Mapa") == "Map")
	_check("capitals are found", T.t("SZTURMOWIEC") == "ASSAULT")
	_check("packed text reads in English", T.t(packed) == "Artillery ready in 12 s.")
	var perk := T.pack("Perk: %s", ["Twardziel"])
	_check("packed names are translated too", T.t(perk) == "Perk: Tough")
	var unknown := "Bojownik 7"
	_check("unknown text passes through", T.t(unknown) == unknown)


func _formats() -> void:
	var codes := RegEx.create_from_string("%(\\.\\d)?[ds%]")
	for key: String in LangEn.TEXT:
		var a := PackedStringArray()
		var b := PackedStringArray()
		for m in codes.search_all(key):
			a.append(m.get_string())
		for m in codes.search_all(String(LangEn.TEXT[key])):
			b.append(m.get_string())
		_check("format codes of: " + key, a == b)
		_check("no Polish letters in: " + String(LangEn.TEXT[key]), not _polish(String(LangEn.TEXT[key])))


func _data() -> void:
	var names: Array = C.TEAM_NAMES.duplicate() + C.NADE_NAMES.duplicate() + Settings.QUALITY_NAMES.duplicate()
	for w: Dictionary in C.WEAPONS.values():
		names.append_array([w["name"], w["short"]])
	for team: Array in C.CLASSES:
		for cd: Dictionary in team:
			names.append_array([cd["name"], cd["desc"]])
	for table: Dictionary in [Modes.LIST, Modes.MAPS, Gear.ATTACHMENTS, Gear.PERKS]:
		for entry: Dictionary in table.values():
			names.append_array([entry["name"], entry["desc"]])
	for d: Dictionary in C.DIFFICULTIES:
		names.append(d["name"])
	for f: Dictionary in Fortifications.DEFS:
		names.append(f["name"])
	for text: String in names:
		_check("no English for: " + text, not _polish(T.t(text)))


func _screens() -> void:
	var main := get_tree().current_scene
	main.call("_open_menu", "")
	await get_tree().process_frame
	var menu: Control = main.get("_menu")
	menu.call("_show", "battle")
	for id: String in Modes.LIST:
		Settings.match_mode = id
		Settings.match_map = ""
		menu.call("_refresh_options")
		await get_tree().process_frame
		_walk(menu)
	await _cards(menu)
	Settings.match_mode = Modes.DEFAULT_MODE
	menu.call("_show", "multi")
	await get_tree().process_frame
	_walk(menu)
	menu.call("show_side_pick", {"mode": "podboj", "map": "rynek"}, [1, 2])
	await get_tree().process_frame
	_walk(menu)
	menu.queue_free()
	main.set("_menu", null)
	await get_tree().process_frame
	Net.start_offline(Modes.normalize({"mode": "podboj", "map": "stare_miasto", "difficulty": 0, "bots_per_team": 0}))
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	await get_tree().create_timer(0.3).timeout
	for tab in 5:
		w.hud.deploy.call("_show_tab", tab)
		await get_tree().process_frame
		_walk(w.hud)
	w.hud.pause_menu.open()
	await get_tree().process_frame
	_walk(w.hud)
	w.hud.pause_menu.close()
	w.hud.admin.open()
	await get_tree().process_frame
	_walk(w.hud)
	w.hud.admin.close()
	main.call("_close_world")
	await get_tree().process_frame
	Net.leave()
	await get_tree().process_frame


## Pressing the cards has to change the choice that the start button sends.
func _cards(menu: Control) -> void:
	Settings.match_mode = "pvp"
	Settings.match_map = ""
	Settings.side = 0
	menu.call("_refresh_options")
	await get_tree().process_frame
	var cards := menu.find_children("*", "UiCard", true, false)
	var pressed_side := false
	for card: UiCard in cards:
		if card.is_visible_in_tree() and card.get_parent().get_child_count() == 2 and card.get_index() == 1:
			card.pressed.emit()
			pressed_side = true
			break
	await get_tree().process_frame
	await get_tree().process_frame
	_check("a side card sets the side", pressed_side and Settings.side == 1)
	Settings.side = 0
	var sent := []
	var keep := func(cfg: Dictionary) -> void: sent.append(cfg)
	menu.connect("play_offline", keep)
	menu.call("_pick_mode", "czolgi")
	await get_tree().process_frame
	await get_tree().process_frame
	var modes: Array = (menu.get("_option_boxes")[0] as VBoxContainer).get_child(1).get_children()
	(modes[0] as UiCard).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("a mode card sets the mode", Settings.match_mode == Modes.LIST.keys()[0])
	var maps := menu.find_children("*", "UiCard", true, false).filter(func(c: UiCard) -> bool: return c.custom_minimum_size == MainMenu.MAP_CARD and c.is_visible_in_tree())
	(maps[1] as UiCard).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var chosen: String = Modes.LIST[Settings.match_mode]["maps"][1]
	_check("a map card sets the map", Settings.match_map == chosen)
	menu.emit_signal("play_offline", menu.call("_cfg"))
	_check("the start sends the choice", not sent.is_empty() and sent[0]["map"] == chosen)
	menu.disconnect("play_offline", keep)


func _walk(node: Node) -> void:
	if node is Label or node is Button:
		var text: String = node.get("text")
		_check("left in Polish on %s: %s" % [node.get_parent().name, text], not _polish(T.t(text)))
	for child in node.get_children():
		_walk(child)


func _polish(text: String) -> bool:
	var plain := text.replace("Calabró", "")
	for letter in POLISH_LETTERS:
		if plain.contains(letter):
			return true
	return false
