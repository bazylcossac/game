class_name EndScreen
extends Control
## Round summary, shown until the server starts the next round.

var world: World
var _countdown := 0.0
var _title: Label
var _sub: Label
var _next: Label
var _table: HBoxContainer


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.035, 0.82)
	UiKit.fill(dim)
	add_child(dim)
	var m := MarginContainer.new()
	UiKit.fill(m)
	m.add_theme_constant_override("margin_left", 150)
	m.add_theme_constant_override("margin_right", 150)
	m.add_theme_constant_override("margin_top", 56)
	m.add_theme_constant_override("margin_bottom", 44)
	add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	m.add_child(box)
	_title = UiKit.label("", 84, UiKit.INK, "title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_sub = UiKit.label("", 28, UiKit.MUTED, "semibold")
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_sub)
	_table = HBoxContainer.new()
	_table.add_theme_constant_override("separation", 20)
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_table)
	var foot := HBoxContainer.new()
	box.add_child(foot)
	_next = UiKit.label("", 26, UiKit.MUTED, "semibold")
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_next)
	var leave := UiKit.button("WYJDŹ DO MENU")
	leave.custom_minimum_size = Vector2(260, 54)
	leave.pressed.connect(func() -> void: world.leave_requested.emit())
	foot.add_child(leave)


func open(winner: int, restart_in: float) -> void:
	_countdown = restart_in
	var mine := world.local != null and winner == (world.local.sid if world.ffa else world.local.team)
	_title.text = "ZWYCIĘSTWO" if mine else "PORAŻKA"
	_title.add_theme_color_override("font_color", _winner_color(winner, mine))
	_sub.text = T.t("%s  ·  Poziom %d") % [_summary(winner), world.level]
	for c in _table.get_children():
		c.queue_free()
	if world.ffa:
		_table.add_child(Overlays.ranking(world))
	else:
		_table.add_child(Overlays.team_column(world, 0))
		_table.add_child(Overlays.team_column(world, 1))
	visible = true
	Sfx.play("flag_captured" if mine else "flag_lost", 0.0)


func _winner_color(winner: int, mine: bool) -> Color:
	if world.ffa:
		return UiKit.BRASS if mine else UiKit.RED
	return C.TEAM_COLORS[winner]


func _summary(winner: int) -> String:
	if world.ffa:
		var s: Soldier = world.soldiers.get(winner)
		return T.t("%s wygrywa deathmatch") % (s.pname if s else T.t("Nikt"))
	if world.mode["rules"] == "conquest" and not world.mode.get("tanks_only", false):
		return T.t("%s wygrywa bitwę o miasto") % T.t(C.TEAM_NAMES[winner])
	return T.t("%s wygrywa: %s") % [T.t(C.TEAM_NAMES[winner]), T.t(world.mode["name"])]


func _process(delta: float) -> void:
	if not visible:
		return
	_countdown = maxf(_countdown - delta, 0.0)
	_next.text = T.t("Następna runda za %d s") % int(ceil(_countdown))
