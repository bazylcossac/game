class_name Overlays
extends RefCounted
## Shared table builder for the scoreboard and end screen.

static func team_column(world: World, team: int) -> Control:
	var panel := UiKit.panel(16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var col: Color = C.TEAM_COLORS[team]
	var head := HBoxContainer.new()
	var title := UiKit.label(String(C.TEAM_NAMES[team]).to_upper(), 30, col, "title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.label(str(world.tickets[team]), 30, UiKit.INK, "title"))
	box.add_child(head)
	var list: Array = []
	for s: Soldier in world.soldiers.values():
		if s.team == team:
			list.append(s)
	list.sort_custom(func(a: Soldier, b: Soldier) -> bool: return a.score > b.score)
	_add_rows(box, world, list)
	return panel


## The one table of a free-for-all, ranked by what decides the match.
static func ranking(world: World) -> Control:
	var panel := UiKit.panel(16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var head := HBoxContainer.new()
	var title := UiKit.label(T.t(String(world.mode["name"])).to_upper(), 30, UiKit.BRASS, "title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.label("do %d" % world.score_limit, 30, UiKit.INK, "title"))
	box.add_child(head)
	var list: Array = world.soldiers.values()
	list.sort_custom(func(a: Soldier, b: Soldier) -> bool: return a.kills > b.kills)
	_add_rows(box, world, list)
	return panel


static func _add_rows(box: VBoxContainer, world: World, list: Array) -> void:
	box.add_child(_row("ŻOŁNIERZ", "ELIM.", "ŚMIERCI", "PUNKTY", UiKit.FAINT, 19, false))
	box.add_child(UiKit.rule())
	for s: Soldier in list:
		var me: bool = s == world.local
		var nice := "%s  ·  bot" % s.pname if s.peer == 0 else "[%d]  %s" % [s.level, s.pname]
		box.add_child(_row(nice, str(s.kills), str(s.deaths), str(s.score), UiKit.BRASS if me else (UiKit.INK if s.alive else UiKit.MUTED), 22, me))


static func _row(a: String, b: String, c: String, d: String, color: Color, size: int, highlight: bool) -> Control:
	var row := HBoxContainer.new()
	var name_label := UiKit.label(a, size, color, "semibold" if highlight else "medium")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)
	for pair: Array in [[b, 70.0], [c, 80.0], [d, 90.0]]:
		var l := UiKit.label(pair[0], size, color, "semibold" if highlight else "medium")
		l.custom_minimum_size = Vector2(pair[1], 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(l)
	return row
