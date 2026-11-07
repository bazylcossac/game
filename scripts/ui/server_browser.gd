class_name ServerBrowser
extends VBoxContainer
## The servers from `C.SERVERS`, each with what it is playing, its players and its ping. While on
## screen it keeps asking, so a server that comes up or fills up shows without a click.

signal join_requested(address: String, port: int)

const REFRESH := 6.0
const PLAYERS_WIDTH := 130.0
const PING_WIDTH := 130.0
const JOIN_WIDTH := 220.0

## Tests switch this off, so opening the page in one never knocks on a real server.
static var asking := true

## One entry per server: its address, labels, button and the probe now asking it.
var _rows: Array[Dictionary] = []
var _wait := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(_head())
	for server: Dictionary in C.SERVERS:
		_add_row(server)
	visibility_changed.connect(refresh)
	refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_wait -= delta
	if _wait <= 0.0:
		refresh()


func refresh() -> void:
	if not asking or not is_visible_in_tree():
		return
	_wait = REFRESH
	for row: Dictionary in _rows:
		if row["probe"] == null:
			var probe := ServerProbe.new()
			row["probe"] = probe
			probe.answered.connect(_on_answer.bind(row))
			add_child(probe)
			probe.ask(row["address"], row["port"])


func _head() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_child(head)
	var name_label := UiKit.label("SERWER", 20, UiKit.FAINT, "semibold")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(_cell("GRACZE", PLAYERS_WIDTH, 20, UiKit.FAINT))
	head.add_child(_cell("PING", PING_WIDTH, 20, UiKit.FAINT))
	var space := Control.new()
	space.custom_minimum_size = Vector2(JOIN_WIDTH, 0)
	head.add_child(space)
	return margin


func _cell(text: String, width: float, size_px: int, color: Color) -> Label:
	var l := UiKit.label(text, size_px, color, "semibold")
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


func _add_row(server: Dictionary) -> void:
	var panel := UiKit.panel(14, UiKit.PANEL_SOFT)
	add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	panel.add_child(line)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var title := UiKit.label(server["name"], 30, UiKit.INK, "bold")
	title.clip_text = true
	text.add_child(title)
	var detail := UiKit.label("Sprawdzanie...", 22, UiKit.MUTED)
	detail.clip_text = true
	text.add_child(detail)
	var players := _cell("–", PLAYERS_WIDTH, 28, UiKit.INK)
	line.add_child(players)
	var ping := _cell("–", PING_WIDTH, 28, UiKit.INK)
	line.add_child(ping)
	var join := UiKit.button("DOŁĄCZ", true)
	join.custom_minimum_size = Vector2(JOIN_WIDTH, 60)
	join.add_theme_font_size_override("font_size", 28)
	join.disabled = true
	line.add_child(join)
	var row := {"address": server["address"], "port": server["port"], "fallback": server["name"], "title": title, "detail": detail, "players": players, "ping": ping, "join": join, "probe": null}
	join.pressed.connect(func() -> void: join_requested.emit(row["address"], row["port"]))
	_rows.append(row)


func _on_answer(info: Dictionary, row: Dictionary) -> void:
	row["probe"] = null
	var version := String(info.get("version", ""))
	var said_name := String(info.get("name", "")).left(40)
	var title: Label = row["title"]
	var detail: Label = row["detail"]
	var players: Label = row["players"]
	var ping: Label = row["ping"]
	var join: Button = row["join"]
	title.text = said_name if said_name != "" else String(row["fallback"])
	players.text = "–"
	ping.text = "–"
	join.disabled = true
	join.text = "DOŁĄCZ"
	detail.add_theme_color_override("font_color", UiKit.RED)
	if not bool(info.get("reached", false)):
		detail.text = "Serwer nie odpowiada"
		return
	if version == "":
		detail.text = "Serwer ma starszą wersję gry"
		return
	ping.text = T.t("%d ms") % int(info["ping"])
	if version != C.VERSION:
		detail.text = T.t("Inna wersja gry: %s") % version
		return
	var count := int(info.get("players", 0))
	var limit := int(info.get("max", 0))
	players.text = "%d / %d" % [count, limit]
	detail.add_theme_color_override("font_color", UiKit.MUTED)
	detail.text = _playing(info)
	if count >= limit:
		join.text = "PEŁNY"
		return
	join.disabled = false


func _playing(info: Dictionary) -> String:
	var mode_id := String(info.get("mode", ""))
	var map_id := String(info.get("map", ""))
	var mode_name := T.t(Modes.LIST[mode_id]["name"]) if Modes.has_mode(mode_id) else mode_id
	var map_name := T.t(Modes.MAPS[map_id]["name"]) if Modes.has_map(map_id) else map_id
	return "%s  ·  %s" % [mode_name, map_name]
