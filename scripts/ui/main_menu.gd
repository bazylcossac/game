class_name MainMenu
extends Control
## Title screen over a live 3D flyover of the battlefield, with picture cards for the choices.

signal play_offline(cfg: Dictionary)
signal host_game(cfg: Dictionary, port: int)
signal join_game(address: String, port: int)

const FULL_PAGES := ["battle", "host", "team"]
const SIDE_ART := ["side_usa", "side_imperium"]
const SIDE_ICONS := ["res://assets/textures/icon_usa.png", "res://assets/textures/icon_empire.png"]
const SIDE_NOTES := ["Ostatni ludzie. Złom, laser i wściekłość.", "Sztuczna inteligencja w garniturze. Wydajność, posłuszeństwo, likwidacja."]
const MAP_CARD := Vector2(212, 240)

var _pages := {}
var _status: Label
var _version: Label
var _header: Control
var _dim: ColorRect
var _backdrop: MenuBackdrop
var _option_boxes: Array[VBoxContainer] = []
var _summaries: Array[Label] = []
var _side_rows: Array[HBoxContainer] = []
var _host_port := C.DEFAULT_PORT
var _browser: ServerBrowser
var _team_note: Label
var _team_row: HBoxContainer
var _eye: TextureRect
var _scan: ColorRect
var _clock := 0.0


func _ready() -> void:
	theme = UiKit.theme()
	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)
	add_child(_left_shade())
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.03, 0.78)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(_dim))
	# A surveillance feed: scan lines, a dark vignette and a red cast, over the whole screen.
	_scan = ColorRect.new()
	_scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var feed := ShaderMaterial.new()
	feed.shader = load("res://shaders/menu_feed.gdshader")
	_scan.material = feed
	add_child(UiKit.fill(_scan))

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 72)
	m.add_theme_constant_override("margin_right", 72)
	m.add_theme_constant_override("margin_top", 44)
	m.add_theme_constant_override("margin_bottom", 32)
	add_child(UiKit.fill(m))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	m.add_child(col)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 22)
	title_row.add_child(UiKit.label(C.GAME_TITLE, 118, UiKit.INK, "title"))
	# Korpo's eye watches the title screen, and opens and closes its light slowly.
	_eye = TextureRect.new()
	_eye.texture = load(SIDE_ICONS[C.Team.EMPIRE])
	_eye.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_eye.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_eye.custom_minimum_size = Vector2(96, 96)
	_eye.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_eye)
	header.add_child(title_row)
	var bar := ColorRect.new()
	bar.color = UiKit.RED
	bar.custom_minimum_size = Vector2(420, 4)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(bar)
	var gap_small := Control.new()
	gap_small.custom_minimum_size = Vector2(0, 8)
	header.add_child(gap_small)
	header.add_child(UiKit.label(C.GAME_SUBTITLE, 34, UiKit.RED, "semibold"))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 28)
	header.add_child(gap)
	col.add_child(header)
	_header = header

	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(pages)
	_pages["main"] = _page_main()
	_pages["battle"] = _setup_page("SZYBKA BITWA", "ROZPOCZNIJ", _start_battle, "main")
	_pages["multi"] = _page_multi()
	_pages["host"] = _setup_page("ZAŁÓŻ SERWER", "URUCHOM SERWER", _start_server, "multi")
	_pages["team"] = _page_team()
	_pages["settings"] = _page_settings()
	_pages["credits"] = _page_credits()
	for key: String in _pages:
		var p: Control = _pages[key]
		pages.add_child(p)
		if key == "main" or key in FULL_PAGES:
			UiKit.fill(p)
		else:
			p.set_anchors_preset(Control.PRESET_TOP_LEFT)

	var foot := HBoxContainer.new()
	col.add_child(foot)
	_status = UiKit.label("", 24, UiKit.BRASS, "semibold")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_status)
	_version = UiKit.label("", 20, UiKit.MUTED)
	foot.add_child(_version)

	var language := LanguageSwitch.new()
	language.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	language.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	language.offset_left = -260
	language.offset_right = -72
	language.offset_top = 40
	language.offset_bottom = 84
	add_child(language)

	Settings.language_changed.connect(_on_language)
	_on_language()
	_show("main")
	Sfx.play_music("menu_music")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	_clock += delta
	if _eye:
		_eye.modulate = Color(1, 1, 1, 0.75 + 0.25 * sin(_clock * 1.3))


func set_status(text: String) -> void:
	_status.text = T.t(text)


## The server let the player in: the match is waiting for them to pick a side.
func show_side_pick(cfg: Dictionary, counts: Array) -> void:
	var full := Modes.normalize(cfg)
	_team_note.text = "%s  ·  %s" % [T.t(Modes.mode_of(full)["name"]), T.t(Modes.MAPS[full["map"]]["name"])]
	for c in _team_row.get_children():
		_team_row.remove_child(c)
		c.queue_free()
	for team in C.TEAM_NAMES.size():
		var note := "%s\n%s" % [T.t(SIDE_NOTES[team]), T.t("Graczy w drużynie: %d") % int(counts[team])]
		var card := UiCard.new().setup(_art(SIDE_ART[team]), T.t(C.TEAM_NAMES[team]).to_upper(), note, C.TEAM_COLORS[team], load(SIDE_ICONS[team]))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_choose_team.bind(team))
		_team_row.add_child(card)
	set_status("")
	_show("team")


## Back to the server list when the connection ends before a side was picked.
func close_side_pick() -> void:
	if (_pages["team"] as Control).visible:
		_show("multi")


func _choose_team(team: int) -> void:
	set_status("Wczytywanie mapy...")
	Net.choose_side(team)


func _show(page: String) -> void:
	for key: String in _pages:
		(_pages[key] as Control).visible = key == page
	_header.visible = page not in FULL_PAGES
	_dim.visible = page != "main"


func _on_language() -> void:
	_version.text = T.t("wersja %s") % C.VERSION
	_refresh_options()


func _left_shade() -> TextureRect:
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.025, 0.035, 0.97))
	grad.set_color(1, Color(0.02, 0.025, 0.035, 0.0))
	grad.add_point(0.42, Color(0.02, 0.025, 0.035, 0.82))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 512
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return UiKit.fill(shade)


func _art(name_id: String) -> Texture2D:
	return load("res://assets/textures/menu/%s.jpg" % name_id)


func _caption(text: String) -> Label:
	return UiKit.label(text, 24, UiKit.BRASS, "bold")


func _menu_button(text: String, primary := false) -> Button:
	var b := UiKit.button(text, primary)
	b.custom_minimum_size = Vector2(280, 60)
	b.add_theme_font_size_override("font_size", 28)
	return b


## One entry of the main list: a name and a line saying what is behind it.
func _nav_item(title: String, note: String, primary := false) -> Button:
	var b := UiKit.button("", primary)
	b.custom_minimum_size = Vector2(560, 84)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(UiKit.fill(margin))
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", -4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(text)
	var dark := Color(0.08, 0.07, 0.05)
	text.add_child(UiKit.label(title, 34, dark if primary else UiKit.INK, "bold"))
	text.add_child(UiKit.label(note, 21, Color(dark, 0.78) if primary else UiKit.MUTED))
	return b


func _page_main() -> Control:
	var page := HBoxContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	page.add_child(box)
	var battle := _nav_item("SZYBKA BITWA", "Walka z botami, gotowa w minutę", true)
	battle.pressed.connect(_show.bind("battle"))
	box.add_child(battle)
	var multi := _nav_item("GRA SIECIOWA", "Dołącz do serwera albo załóż własny")
	multi.pressed.connect(_show.bind("multi"))
	box.add_child(multi)
	var opts := _nav_item("USTAWIENIA", "Grafika, dźwięk, sterowanie i język")
	opts.pressed.connect(_show.bind("settings"))
	box.add_child(opts)
	var credits := _nav_item("AUTORZY I LICENCJE", "Kto stworzył grę i jej zasoby")
	credits.pressed.connect(_show.bind("credits"))
	box.add_child(credits)
	var quit := _nav_item("WYJŚCIE", "Wróć na pulpit")
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)

	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(space)
	var story := UiKit.panel(24, UiKit.PANEL_SOFT)
	story.size_flags_vertical = Control.SIZE_SHRINK_END
	story.custom_minimum_size = Vector2(600, 0)
	page.add_child(story)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 14)
	story.add_child(inside)
	var marks := HBoxContainer.new()
	marks.add_theme_constant_override("separation", 18)
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	marks.add_child(_emblem(0))
	marks.add_child(UiKit.label("VS", 40, UiKit.BRASS, "title"))
	marks.add_child(_emblem(1))
	inside.add_child(marks)
	inside.add_child(UiKit.wrapped("Rok 2087. Sztuczna inteligencja przejęła korporacje, a korporacje przejęły świat. Ludzie nie są już potrzebni do żadnej pracy. Korpo, armia robotów w czarnych garniturach, zarządza miastami i wygasza resztę ludzkości. Rebelia, ostatni ludzie, chwyta za broń ze złomu. Stań po jednej ze stron.", 23, UiKit.MUTED))
	return page


func _emblem(team: int) -> TextureRect:
	var mark := TextureRect.new()
	mark.texture = load(SIDE_ICONS[team])
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(84, 84)
	return mark


## The whole choice of a match on one screen, for a battle and for a hosted server.
func _setup_page(title: String, start_text: String, on_start: Callable, back_to: String) -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.add_child(UiKit.label(title, 56, UiKit.INK, "title"))
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 10)
	options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(options)
	_option_boxes.append(options)
	_fill_options(options)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 20)
	var back := _menu_button("WSTECZ")
	back.pressed.connect(_show.bind(back_to))
	foot.add_child(back)
	var summary := UiKit.label("", 26, UiKit.MUTED, "semibold")
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(summary)
	_summaries.append(summary)
	var go := _menu_button(start_text, true)
	go.custom_minimum_size = Vector2(420, 68)
	go.add_theme_font_size_override("font_size", 34)
	go.pressed.connect(on_start)
	foot.add_child(go)
	page.add_child(foot)
	return page


func _start_battle() -> void:
	Settings.save_settings()
	play_offline.emit(_cfg())


func _start_server() -> void:
	Settings.save_settings()
	host_game.emit(_cfg(), _host_port)


func _fill_options(box: VBoxContainer) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var cfg := _cfg()
	var mode := Modes.mode_of(cfg)
	box.add_child(_caption("WYBIERZ TRYB"))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 12)
	for id: String in Modes.LIST:
		var card := UiCard.new().setup(_art("mode_" + id), T.t(Modes.LIST[id]["name"]).to_upper())
		card.selected = id == cfg["mode"]
		card.custom_minimum_size = Vector2(0, 250)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_pick_mode.bind(id))
		modes.add_child(card)
	box.add_child(modes)
	box.add_child(UiKit.wrapped(mode["desc"], 25, UiKit.INK))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(_caption("WYBIERZ MAPĘ"))
	var maps := HBoxContainer.new()
	maps.add_theme_constant_override("separation", 10)
	for id: String in mode["maps"]:
		var card := UiCard.new().setup(_art("map_" + id), T.t(Modes.MAPS[id]["name"]).to_upper())
		card.selected = id == cfg["map"]
		card.custom_minimum_size = MAP_CARD
		card.pressed.connect(_pick_map.bind(id))
		maps.add_child(card)
	left.add_child(maps)
	left.add_child(UiKit.wrapped(Modes.MAPS[cfg["map"]]["desc"], 24, UiKit.MUTED))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(620, 0)
	row.add_child(right)
	right.add_child(_caption("WYBIERZ STRONĘ"))
	if mode.get("ffa", false):
		right.add_child(UiKit.wrapped("W tym trybie nie ma stron.", 24, UiKit.MUTED))
	else:
		right.add_child(_side_cards(210))
	var low: int = mode["team_min"]
	var high: int = mode["team_max"]
	if low < high:
		var title := "Walczących na mapie" if mode.get("ffa", false) else "Żołnierzy na drużynę"
		right.add_child(UiKit.slider_row(title, low, high, 1, clampi(Settings.bots_per_team, low, high), "%.0f", func(v: float) -> void: Settings.bots_per_team = int(v)))
	var names: Array = []
	for d: Dictionary in C.DIFFICULTIES:
		names.append(d["name"])
	right.add_child(UiKit.choice_row("Poziom przeciwnika", names, Settings.difficulty, func(i: int) -> void: Settings.difficulty = i))


## Two cards, one per side. Picking one repaints every set of cards on the menu.
func _side_cards(height: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for team in C.TEAM_NAMES.size():
		var card := UiCard.new().setup(_art(SIDE_ART[team]), T.t(C.TEAM_NAMES[team]).to_upper(), T.t(SIDE_NOTES[team]), C.TEAM_COLORS[team], load(SIDE_ICONS[team]))
		card.selected = Settings.side == team
		card.custom_minimum_size = Vector2(0, height)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_pick_side.bind(team))
		row.add_child(card)
	_side_rows.append(row)
	return row


func _pick_mode(id: String) -> void:
	Settings.match_mode = id
	Settings.match_map = ""
	_refresh_options.call_deferred()


func _pick_map(id: String) -> void:
	Settings.match_map = id
	_refresh_options.call_deferred()


func _pick_side(team: int) -> void:
	Settings.side = team
	_refresh_options.call_deferred()


## Waits for the end of the press, because this replaces the card that was pressed.
func _refresh_options() -> void:
	for box in _option_boxes:
		_fill_options(box)
	# Untyped: a row freed meanwhile is no longer an HBoxContainer, and a typed lambda would fail on it.
	_side_rows.assign(_side_rows.filter(func(row: Variant) -> bool: return is_instance_valid(row) and not (row as Node).is_queued_for_deletion()))
	for row in _side_rows:
		for team in row.get_child_count():
			var card := row.get_child(team) as UiCard
			card.selected = Settings.side == team
	var cfg := _cfg()
	var mode := Modes.mode_of(cfg)
	var parts := PackedStringArray([T.t(mode["name"]), T.t(Modes.MAPS[cfg["map"]]["name"])])
	if not mode.get("ffa", false):
		parts.append(T.t(C.TEAM_NAMES[Settings.side]))
	for label in _summaries:
		label.text = "  ·  ".join(parts)


func _cfg() -> Dictionary:
	var mode: Dictionary = Modes.LIST.get(Settings.match_mode, Modes.LIST[Modes.DEFAULT_MODE])
	var bots := clampi(Settings.bots_per_team, mode["team_min"], mode["team_max"])
	return Modes.normalize({"seed": Modes.DEFAULT_SEED, "bots_per_team": bots, "difficulty": Settings.difficulty, "mode": Settings.match_mode, "map": Settings.match_map})


func _page_team() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.add_child(UiKit.label("WYBIERZ DRUŻYNĘ", 56, UiKit.INK, "title"))
	_team_note = UiKit.label("", 28, UiKit.BRASS, "semibold")
	page.add_child(_team_note)
	_team_row = HBoxContainer.new()
	_team_row.add_theme_constant_override("separation", 14)
	_team_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_team_row)
	var back := _menu_button("WSTECZ")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void:
		Net.leave()
		_show("multi"))
	page.add_child(back)
	return page


func _join(address: String, port: int) -> void:
	Settings.save_settings()
	join_game.emit(address, port)


func _page_multi() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(1180, 0)
	box.add_child(UiKit.label("GRA SIECIOWA", 42, UiKit.INK, "title"))
	box.add_child(UiKit.accent_bar())
	box.add_child(_caption("SERWERY"))
	_browser = ServerBrowser.new()
	_browser.join_requested.connect(_join)
	box.add_child(_browser)
	box.add_child(UiKit.wrapped("Drużynę wybierasz po dołączeniu do serwera.", 24, UiKit.MUTED))

	var fields := HBoxContainer.new()
	fields.add_theme_constant_override("separation", 12)
	box.add_child(fields)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(UiKit.label("Twój pseudonim", 22, UiKit.MUTED))
	var nick := LineEdit.new()
	nick.text = Settings.player_name
	nick.max_length = 20
	nick.text_changed.connect(func(t: String) -> void: Settings.player_name = t)
	who.add_child(nick)
	fields.add_child(who)
	var where := VBoxContainer.new()
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	where.size_flags_stretch_ratio = 1.6
	where.add_child(UiKit.label("Inny serwer: adres i port", 22, UiKit.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var addr := LineEdit.new()
	addr.text = Settings.last_server
	addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(addr)
	var port := LineEdit.new()
	port.text = str(C.DEFAULT_PORT)
	port.custom_minimum_size = Vector2(120, 0)
	row.add_child(port)
	where.add_child(row)
	fields.add_child(where)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var refresh := _menu_button("ODŚWIEŻ", true)
	refresh.custom_minimum_size = Vector2(240, 64)
	refresh.pressed.connect(_browser.refresh)
	buttons.add_child(refresh)
	var join := _menu_button("DOŁĄCZ PO ADRESIE")
	join.custom_minimum_size = Vector2(340, 64)
	join.pressed.connect(func() -> void:
		Settings.last_server = addr.text.strip_edges()
		_join(Settings.last_server, int(port.text)))
	buttons.add_child(join)
	var host := _menu_button("ZAŁÓŻ SERWER")
	host.custom_minimum_size = Vector2(340, 64)
	host.pressed.connect(func() -> void:
		_host_port = int(port.text)
		_show("host"))
	buttons.add_child(host)
	buttons.add_child(_back_button())
	box.add_child(buttons)
	return box


func _page_settings() -> Control:
	var s := SettingsPanel.new()
	s.closed.connect(_show.bind("main"))
	return s


func _back_button() -> Button:
	var b := _menu_button("WSTECZ")
	b.custom_minimum_size = Vector2(240, 64)
	b.pressed.connect(_show.bind("main"))
	return b


func _page_credits() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(820, 0)
	box.add_theme_constant_override("separation", 14)
	box.add_child(UiKit.label("AUTORZY I LICENCJE", 42, UiKit.INK, "title"))
	box.add_child(UiKit.accent_bar())
	box.add_child(UiKit.wrapped("Modele skrzyń, zbiorników i maszyn w Stacji Rdzeń: Juan Linietsky i Fernando Miguel Calabró, Godot TPS Demo (2018). Licencja Creative Commons Attribution 3.0. Zmieniono materiały, skalę i rozmieszczenie modeli; układ mapy jest nowy.", 24, UiKit.MUTED))
	box.add_child(UiKit.wrapped("Źródło: github.com/godotengine/tps-demo\nLicencja: creativecommons.org/licenses/by/3.0/\nTekstury i niebo: ambientCG (CC0). Cząsteczki: Kenney (CC0). Fonty: Anton i Barlow Condensed (SIL OFL 1.1). Pełne źródła i licencje: assets/LICENSES.md.", 23, UiKit.MUTED))
	box.add_child(_back_button())
	return box
