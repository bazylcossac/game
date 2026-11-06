class_name DeployScreen
extends Control
## Choose a class, its gear and a spawn point, then go. Shown before every life.

const TABS := ["MAPA", "UZBROJENIE", "PERKI", "POSTĘPY", "ODDZIAŁ"]
const SQUAD_TAB := 4
const BENCH_HINT := "Najedź na dodatek, aby przymierzyć go na broni. Przeciągnij broń, aby ją obrócić, a kółkiem myszy przybliż."

var world: World
var map_view: TacticalMap
var deploy_button: Button
var status: Label
var preview: ClassPreview
var gun_view: WeaponPreview
var class_id := 0
var spawn_flag := -1
var tab := 0
var _wait := 0.0
var _cards: Array[PanelContainer] = []
var _card_weapons: Array[Label] = []
var _built := false
var _detail_name: Label
var _detail_desc: Label
var _stats_box: VBoxContainer
var _tab_buttons: Array[Button] = []
var _tab_body: Control
var _map_panel: Control
var _beacon_button: Button
var _hint: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _left: Control
var _middle: Control
var _right: Control
var _gun_key := "primary"
var _scroll: ScrollContainer
var _scroll_keep := 0
var _slot_labels := {}
var _card_icons: Array[TextureRect] = []


func _team() -> int:
	return world.local.team if world.local else C.Team.RESISTANCE


func _kit() -> Dictionary:
	return Gear.sanitize(class_id, Settings.kit_for(class_id, _team()), world.level, _team())


func _store(kit: Dictionary) -> void:
	Settings.set_kit(class_id, kit, _team())
	_refresh_gear()


func _build() -> void:
	_built = true
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.035, 0.74)
	UiKit.fill(dim)
	add_child(dim)

	var margin := MarginContainer.new()
	UiKit.fill(margin)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	root.add_child(_header())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(350, 0)
	body.add_child(left)
	for i in C.NORMAL_CLASSES:
		left.add_child(_class_card(i))
	world.squads.changed.connect(_on_squads_changed)
	var desc := UiKit.panel(14, UiKit.PANEL)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var desc_box := VBoxContainer.new()
	desc_box.add_theme_constant_override("separation", 6)
	desc.add_child(desc_box)
	_detail_name = UiKit.label("", 28, UiKit.BRASS, "bold")
	desc_box.add_child(_detail_name)
	_detail_desc = UiKit.wrapped("", 22, UiKit.INK)
	desc_box.add_child(_detail_desc)
	if world.mode.get("coins", false):
		var supers := T.t("Superklasy za monetę: %s i %s") % [C.class_name_for(_team(), C.SUPER_MECH), C.class_name_for(_team(), C.SUPER_SPECIAL)]
		desc_box.add_child(UiKit.wrapped(supers, 20, UiKit.BRASS))
	left.add_child(desc)
	_left = left

	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 8)
	middle.custom_minimum_size = Vector2(420, 0)
	body.add_child(middle)
	var stage := UiKit.panel(4, UiKit.PANEL_SOFT)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(stage)
	preview = ClassPreview.new()
	stage.add_child(preview)
	gun_view = WeaponPreview.new()
	gun_view.visible = false
	gun_view.slot_clicked.connect(_focus_slot)
	stage.add_child(gun_view)
	_middle = middle
	var stats_panel := UiKit.panel(14, UiKit.PANEL)
	middle.add_child(stats_panel)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 3)
	stats_panel.add_child(_stats_box)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_right = right
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	right.add_child(tabs)
	for i in TABS.size():
		var b := UiKit.button(TABS[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 24)
		b.toggle_mode = true
		b.pressed.connect(_show_tab.bind(i))
		_tab_buttons.append(b)
		tabs.add_child(b)
	_map_panel = UiKit.panel(10)
	_map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_map_panel)
	map_view = TacticalMap.new()
	map_view.setup(world, false)
	map_view.flag_clicked.connect(_on_flag_clicked)
	_map_panel.add_child(map_view)
	_tab_body = UiKit.panel(16)
	_tab_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_tab_body)
	_hint = UiKit.wrapped("", 21, UiKit.MUTED)
	_hint.custom_minimum_size = Vector2(0, 56)
	right.add_child(_hint)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 18)
	root.add_child(foot)
	status = UiKit.label("", 24, UiKit.MUTED, "semibold")
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(status)
	_beacon_button = UiKit.button("PUNKT ODDZIAŁU")
	_beacon_button.custom_minimum_size = Vector2(240, 58)
	_beacon_button.visible = false
	_beacon_button.pressed.connect(func() -> void:
		spawn_flag = C.SPAWN_BEACON
		map_view.selected_flag = -1
		map_view.queue_redraw()
		Sfx.play("ui_click", -6.0))
	foot.add_child(_beacon_button)
	deploy_button = UiKit.button("DO BOJU", true)
	deploy_button.custom_minimum_size = Vector2(300, 58)
	deploy_button.add_theme_font_size_override("font_size", 32)
	deploy_button.pressed.connect(_deploy)
	foot.add_child(deploy_button)
	_select_class(class_id)
	_show_tab(tab)
	if world.mode.get("tanks_only", false):
		# Nobody leaves the tank here, so what they would carry on foot does not matter.
		_left.visible = false
		_middle.visible = false
		_tab_buttons[1].visible = false
		_tab_buttons[2].visible = false


func _header() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	var title := UiKit.label("ROZMIESZCZENIE", 46, UiKit.INK, "title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var progress := VBoxContainer.new()
	progress.add_theme_constant_override("separation", 2)
	progress.custom_minimum_size = Vector2(420, 0)
	head.add_child(progress)
	var row := HBoxContainer.new()
	_level_label = UiKit.label("", 28, UiKit.BRASS, "bold")
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_level_label)
	_xp_label = UiKit.label("", 21, UiKit.MUTED, "semibold")
	row.add_child(_xp_label)
	progress.add_child(row)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 8)
	_style_bar(_xp_bar, UiKit.BRASS)
	progress.add_child(_xp_bar)
	var emblem := TextureRect.new()
	emblem.texture = Mats.tex("icon_empire" if _team() == C.Team.EMPIRE else "icon_usa")
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.custom_minimum_size = Vector2(56, 56)
	head.add_child(emblem)
	return head


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)


func _class_card(i: int) -> Control:
	var card := UiKit.panel(10, UiKit.PANEL_SOFT)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var key := UiKit.label(str(i + 1), 32, UiKit.BRASS, "title")
	key.custom_minimum_size = Vector2(26, 0)
	row.add_child(key)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UiKit.label(C.class_name_for(_team(), i).to_upper(), 26, UiKit.INK, "bold"))
	var weapon := UiKit.label("", 20, UiKit.MUTED)
	text.add_child(weapon)
	_card_weapons.append(weapon)
	row.add_child(text)
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(112, 38)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.modulate = UiKit.MUTED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	_card_icons.append(picture)
	for c: Control in [row, key, text, text.get_child(0), weapon]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("ui_click", -6.0)
			_select_class(i))
	card.mouse_entered.connect(func() -> void: Sfx.play("ui_hover", -12.0))
	_cards.append(card)
	return card


func _leader() -> bool:
	return world.local != null and world.squads.leads(world.local)


## A leader has exactly one class. It appears when they take command and goes when they stop.
func _on_squads_changed() -> void:
	if not visible or not _built:
		return
	var leading := _leader()
	_cards[C.COMMAND_CLASS].visible = leading
	if leading != (class_id == C.COMMAND_CLASS):
		_select_class(C.COMMAND_CLASS if leading else 0)
	if tab == SQUAD_TAB:
		_rebuild_tab()


func _select_class(i: int) -> void:
	if _leader() != (i == C.COMMAND_CLASS):
		Sfx.play("empty_click", -4.0)
		return
	class_id = i
	for j in _cards.size():
		var s := StyleBoxFlat.new()
		var on := j == i
		s.bg_color = Color(0.95, 0.71, 0.3, 0.16) if on else UiKit.PANEL_SOFT
		s.border_color = UiKit.BRASS if on else UiKit.LINE
		s.set_border_width_all(1)
		s.border_width_left = 4 if on else 1
		s.set_content_margin_all(10)
		_cards[j].add_theme_stylebox_override("panel", s)
	_detail_name.text = C.class_name_for(_team(), i).to_upper()
	var cd := C.cls(_team(), i)
	_detail_desc.text = T.t("%s\nGranaty: %d odłamkowe, %d dymne, %d zapalające.") % [T.t(cd["desc"]), int(cd["grenades"]), int(cd.get("smoke", 0)), int(cd.get("fire", 0))]
	_refresh_gear()


## Redraws everything that depends on the current kit.
func _refresh_gear() -> void:
	var kit := _kit()
	preview.show_kit(_team(), class_id, kit)
	_show_gun(kit)
	for i in _card_weapons.size():
		var k := Gear.sanitize(i, Settings.kit_for(i, _team()), world.level, _team())
		_card_weapons[i].text = String(C.WEAPONS[k["primary"]]["name"])
		_card_icons[i].texture = HudCanvas.weapon_icon(k["primary"], _team())
	_rebuild_stats(kit)
	if tab > 0:
		_rebuild_tab()


func _rebuild_stats(kit: Dictionary) -> void:
	for c in _stats_box.get_children():
		c.free()
	var keys := _gun_keys()
	var id: int = kit[keys[0]]
	var now := Gear.stats(id, kit[keys[1]], kit["perks"])
	var base := Gear.stats(id)
	_stats_box.add_child(UiKit.label(T.t(String(now["name"])).to_upper(), 24, UiKit.INK, "bold"))
	var rows: Array = [["Obrażenia", _dmg(now), _dmg(base), 120.0, true]]
	if now["melee"]:
		rows.append(["Zasięg", float(now["range"]), float(base["range"]), 5.0, true])
		rows.append(["Szybkość", 60.0 / float(now["rate"]), 60.0 / float(base["rate"]), 130.0, true])
	else:
		rows.append(["Szybkostrzelność", 60.0 / float(now["rate"]), 60.0 / float(base["rate"]), 850.0, true])
		rows.append(["Odrzut", float(now["recoil"]) * 10.0, float(base["recoil"]) * 10.0, 45.0, false])
		rows.append(["Zasięg", float(now["range"]), float(base["range"]), 360.0, true])
		rows.append(["Ogniwo", float(now["mag"]), float(base["mag"]), 126.0, true])
		rows.append(["Przeładowanie", float(now["reload"]), float(base["reload"]), 4.5, false])
	for r: Array in rows:
		_stats_box.add_child(_stat_row(r[0], r[1], r[2], r[3], r[4]))


func _dmg(w: Dictionary) -> float:
	return float(w["damage"]) * float(w.get("pellets", 1))


func _stat_row(title: String, value: float, base: float, top: float, more_is_better: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UiKit.label(title, 20, UiKit.MUTED)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = clampf(value / top, 0.03, 1.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, 7)
	var color := UiKit.BRASS
	if not is_equal_approx(value, base):
		var better := (value > base) == more_is_better
		color = Color(0.4, 0.95, 0.55) if better else UiKit.RED
	_style_bar(bar, color)
	row.add_child(bar)
	var n := UiKit.label("%.1f" % value if value < 10.0 else "%d" % int(round(value)), 20, color if color != UiKit.BRASS else UiKit.INK, "semibold")
	n.custom_minimum_size = Vector2(46, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(n)
	return row


func _show_tab(i: int) -> void:
	tab = i
	for j in _tab_buttons.size():
		_tab_buttons[j].set_pressed_no_signal(j == i)
	_map_panel.visible = i == 0
	_tab_body.visible = i != 0
	# The workbench needs the room: a rifle lies across the stage instead of standing in it.
	var bench := i == 1
	preview.visible = not bench
	gun_view.visible = bench
	_middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL if bench else Control.SIZE_FILL
	_middle.size_flags_stretch_ratio = 1.5
	_right.size_flags_stretch_ratio = 1.0
	_hint.text = ""
	if i == 0:
		_hint.text = _map_hint()
	elif bench:
		_hint.text = BENCH_HINT
	_rebuild_stats(_kit())
	if i > 0:
		_rebuild_tab()


func _map_hint() -> String:
	if world.mode.get("tanks_only", false):
		return T.t("Wjeżdżasz czołgiem %s. Kliknij flagę na mapie, aby zacząć przy niej.") % C.class_name_for(_team(), C.VEHICLE_CLASS)
	if not world.flags.is_empty():
		return "Kliknij flagę na mapie albo punkt swojego oddziału, aby wejść do walki przy nim."
	return "Wchodzisz do walki w miejscu z dala od wrogów."


func _rebuild_tab() -> void:
	# This can run from inside a button's own press, so that button must outlive the call.
	if _scroll:
		_scroll_keep = _scroll.scroll_vertical
	for c in _tab_body.get_children():
		_tab_body.remove_child(c)
		c.queue_free()
	_slot_labels.clear()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_body.add_child(scroll)
	_scroll = scroll
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	match tab:
		1: _fill_arsenal(box)
		2: _fill_perks(box)
		3: _fill_progress(box)
		SQUAD_TAB: _fill_squads(box)
	_restore_scroll(scroll, _scroll_keep)


## The list has to be laid out before it can be scrolled.
func _restore_scroll(scroll: ScrollContainer, value: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = value


func _fill_arsenal(box: VBoxContainer) -> void:
	var kit := _kit()
	if class_id == 0:
		box.add_child(UiKit.label("SPRZĘT DODATKOWY", 24, UiKit.BRASS, "bold"))
		var equipment: Array = [
			{"id": "grenades", "name": "Granaty odłamkowe [G]", "level": 1, "desc": "Granaty do walki z piechotą i lekkimi osłonami. Dymny zostaje w obu zestawach."},
			{"id": "rockets", "name": "3 rakiety przeciwpancerne [4]", "level": 1, "desc": "Wyrzutnia AT-43 i trzy pociski. Czołg pada dopiero po sześciu trafieniach. Zastępują granaty."},
		]
		box.add_child(_options(equipment, kit.get("ordnance", "grenades"), func(id: Variant) -> void:
			kit["ordnance"] = id
			_store(kit)))
		box.add_child(UiKit.rule())
	var guns: Array = [
		{"id": "primary", "name": T.t("Główna: %s") % T.t(C.WEAPONS[kit["primary"]]["name"]), "level": 1, "desc": BENCH_HINT},
		{"id": "sidearm", "name": T.t("Boczna: %s") % T.t(C.WEAPONS[kit["sidearm"]]["name"]), "level": 1, "desc": BENCH_HINT},
	]
	box.add_child(_options(guns, _gun_key, func(id: Variant) -> void:
		_gun_key = id
		_rebuild_stats(kit)
		_refresh_gear()))
	box.add_child(UiKit.rule())
	var keys := _gun_keys()
	var picks: Array = []
	for w: int in (Gear.primaries(_team(), class_id) if _gun_key == "primary" else Gear.SIDEARMS):
		picks.append({"id": w, "name": C.WEAPONS[w]["name"], "level": Gear.weapon_level(w), "desc": _weapon_desc(w)})
	box.add_child(UiKit.label("MODEL", 24, UiKit.BRASS, "bold"))
	box.add_child(_options(picks, kit[keys[0]], func(id: Variant) -> void:
		kit[keys[0]] = id
		kit[keys[1]] = []
		_store(kit), func(id: Variant) -> void:
		var k := kit.duplicate(true)
		k[keys[0]] = id
		k[keys[1]] = []
		_try_kit(k, "")))
	if Gear.slots_for(kit[keys[0]]).is_empty():
		box.add_child(UiKit.wrapped("Tej broni nie da się modyfikować.", 22, UiKit.MUTED))
	_fill_parts(box, kit, keys[0], keys[1])


## Which kit entries belong to the gun on show: [weapon, its parts].
func _gun_keys() -> Array:
	if tab == 1 and _gun_key == "sidearm":
		return ["sidearm", "parts_s"]
	return ["primary", "parts_p"]


func _show_gun(kit: Dictionary) -> void:
	var keys := _gun_keys()
	gun_view.show_weapon(kit[keys[0]], kit[keys[1]], _team())


## Shows a kit on the bench and in the stats without keeping it.
func _try_kit(kit: Dictionary, slot: String) -> void:
	_show_gun(kit)
	gun_view.focus_slot = slot
	_rebuild_stats(kit)


func _end_try() -> void:
	var kit := _kit()
	_show_gun(kit)
	gun_view.focus_slot = ""
	_rebuild_stats(kit)


## Clicking a label on the bench brings that slot's choices into view.
func _focus_slot(slot: String) -> void:
	Sfx.play("ui_click", -6.0)
	gun_view.focus_slot = slot
	var row: Control = _slot_labels.get(slot)
	if row and _scroll:
		_scroll.ensure_control_visible(row)


func _weapon_desc(w: int) -> String:
	var s := Gear.stats(w)
	if s["melee"]:
		return T.t("Broń biała. Obrażenia %d, zasięg %.1f m.") % [int(s["damage"]), s["range"]]
	var mode := T.t("ogień ciągły" if s["auto"] else "pojedyncze strzały")
	return T.t("%s, %d obrażeń, %d strz./min, ogniwo %d.") % [mode.left(1).to_upper() + mode.substr(1), int(_dmg(s)), int(60.0 / float(s["rate"])), s["mag"]]


func _fill_parts(box: VBoxContainer, kit: Dictionary, weapon_key: String, parts_key: String) -> void:
	for slot: String in Gear.slots_for(kit[weapon_key]):
		var title := UiKit.label(String(Gear.SLOT_NAMES[slot]).to_upper(), 24, UiKit.BRASS, "bold")
		box.add_child(title)
		_slot_labels[slot] = title
		var items: Array = [{"id": "", "name": "Brak", "level": 1, "desc": "Bez dodatku w tym miejscu."}]
		var picked := ""
		for id: String in Gear.attachments_for(slot):
			var a: Dictionary = Gear.ATTACHMENTS[id]
			items.append({"id": id, "name": a["name"], "level": a["level"], "desc": a["desc"]})
			if kit[parts_key].has(id):
				picked = id
		var swapped := func(id: Variant) -> Array:
			var parts: Array = []
			for p: String in kit[parts_key]:
				if Gear.ATTACHMENTS[p]["slot"] != slot:
					parts.append(p)
			if String(id) != "":
				parts.append(id)
			return parts
		var row := _options(items, picked, func(id: Variant) -> void:
			kit[parts_key] = swapped.call(id)
			_store(kit), func(id: Variant) -> void:
			var k := kit.duplicate(true)
			k[parts_key] = swapped.call(id)
			_try_kit(k, slot))
		box.add_child(row)


func _fill_perks(box: VBoxContainer) -> void:
	var kit := _kit()
	box.add_child(UiKit.wrapped("Perki działają na tę klasę przez całe życie. Superklasy i czołgi ich nie używają.", 22, UiKit.MUTED))
	for slot: String in Gear.PERK_SLOTS:
		box.add_child(UiKit.label(Gear.PERK_SLOT_NAMES[slot].to_upper(), 26, UiKit.BRASS, "bold"))
		var items: Array = [{"id": "", "name": "Brak", "level": 1, "desc": "Bez perka w tym miejscu."}]
		var picked := ""
		for id: String in Gear.perks_for(slot):
			var p: Dictionary = Gear.PERKS[id]
			items.append({"id": id, "name": p["name"], "level": p["level"], "desc": p["desc"]})
			if kit["perks"].has(id):
				picked = id
		box.add_child(_options(items, picked, func(id: Variant) -> void:
			var perks: Array = []
			for p: String in kit["perks"]:
				if Gear.PERKS[p]["slot"] != slot:
					perks.append(p)
			if String(id) != "":
				perks.append(id)
			kit["perks"] = perks
			_store(kit)))


func _fill_progress(box: VBoxContainer) -> void:
	box.add_child(UiKit.wrapped("Punkty z walki to doświadczenie. Wygrana runda daje premię 500, przegrana 150.", 22, UiKit.MUTED))
	var shown := 0
	for level in range(world.level + 1, Gear.MAX_LEVEL + 1):
		var items := Gear.unlocks_at(level)
		if items.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var tag := UiKit.label(T.t("POZIOM %d") % level, 24, UiKit.BRASS, "bold")
		tag.custom_minimum_size = Vector2(130, 0)
		row.add_child(tag)
		var listed := PackedStringArray()
		for item: String in items:
			listed.append(T.t(item))
		var names := UiKit.wrapped(", ".join(listed), 22, UiKit.INK)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(names)
		box.add_child(row)
		shown += 1
	if shown == 0:
		box.add_child(UiKit.label("Wszystko odblokowane.", 24, UiKit.BRASS, "bold"))


## A wrapping row of choices. Locked ones show the level they need.
func _fill_squads(box: VBoxContainer) -> void:
	if not world.squads.enabled():
		box.add_child(UiKit.wrapped("W tym trybie nie ma oddziałów.", 24, UiKit.MUTED))
		return
	var me := world.local
	var mine := world.squads.squad_of(me.sid)
	box.add_child(UiKit.wrapped(T.t("Twórca oddziału zostaje jego dowódcą: dostaje stałą klasę, wzywa artylerię i stawia punkt odrodzenia dla oddziału. W oddziale jest do %d graczy.") % Squads.MAX_MEMBERS, 21, UiKit.MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	if mine.is_empty():
		var make := UiKit.button("UTWÓRZ ODDZIAŁ", true)
		make.custom_minimum_size = Vector2(0, 46)
		make.pressed.connect(func() -> void: Net.send_squad(0, 0))
		actions.add_child(make)
	else:
		var quit := UiKit.button(T.t("OPUŚĆ ODDZIAŁ %s") % T.t(String(mine["name"])).to_upper())
		quit.custom_minimum_size = Vector2(0, 46)
		quit.pressed.connect(func() -> void: Net.send_squad(2, 0))
		actions.add_child(quit)
	for squad: Dictionary in world.squads.list.values():
		if int(squad["team"]) != me.team:
			continue
		var panel := UiKit.panel(10, UiKit.PANEL_SOFT)
		box.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var members: Array = squad["members"]
		text.add_child(UiKit.label(T.t("ODDZIAŁ %s  (%d/%d)") % [T.t(String(squad["name"])).to_upper(), members.size(), Squads.MAX_MEMBERS], 24, UiKit.BRASS, "bold"))
		var names: Array[String] = []
		for sid: int in members:
			var m: Soldier = world.soldiers.get(sid)
			if m:
				names.append(("★ " if int(squad["leader"]) == sid else "") + m.pname)
		text.add_child(UiKit.label(", ".join(names), 20, UiKit.INK))
		if mine.get("id", -1) != squad["id"] and members.size() < Squads.MAX_MEMBERS:
			var id := int(squad["id"])
			var enter := UiKit.button("DOŁĄCZ")
			enter.pressed.connect(func() -> void: Net.send_squad(1, id))
			row.add_child(enter)


func _options(items: Array, selected: Variant, on_pick: Callable, on_try := Callable()) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for it: Dictionary in items:
		var locked: bool = int(it["level"]) > world.level
		var b := Button.new()
		b.text = String(it["name"]) if not locked else T.t("%s · poz. %d") % [T.t(it["name"]), it["level"]]
		b.toggle_mode = true
		b.button_pressed = it["id"] == selected
		b.disabled = locked
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 21)
		var on := UiKit._box(Color(0.95, 0.71, 0.3, 0.26), UiKit.BRASS, 1, 0.22)
		on.content_margin_left = 12
		on.content_margin_right = 12
		on.content_margin_top = 4
		on.content_margin_bottom = 4
		var off := UiKit._box(Color(1, 1, 1, 0.055), UiKit.LINE, 1, 0.22)
		off.content_margin_left = 12
		off.content_margin_right = 12
		off.content_margin_top = 4
		off.content_margin_bottom = 4
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("disabled", off)
		b.add_theme_stylebox_override("hover", on)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		var desc: String = it["desc"]
		var id: Variant = it["id"]
		b.mouse_entered.connect(func() -> void:
			_hint.text = desc
			if on_try.is_valid():
				on_try.call(id))
		if on_try.is_valid():
			b.mouse_exited.connect(_end_try)
		b.pressed.connect(func() -> void:
			Sfx.play("ui_click", -6.0)
			on_pick.call(id))
		flow.add_child(b)
	return flow


func _on_flag_clicked(idx: int) -> void:
	if idx >= 0 and world.flags[idx]["owner"] != world.local.team:
		Sfx.play("empty_click", -4.0)
		return
	if idx == C.SPAWN_BEACON and world.squads.spawn_problem(world.local) != "":
		Sfx.play("empty_click", -4.0)
		status.text = T.t(world.squads.spawn_problem(world.local))
		return
	spawn_flag = idx
	map_view.selected_flag = idx
	map_view.queue_redraw()
	Sfx.play("ui_click", -6.0)


func open(wait: float) -> void:
	if not _built:
		_build()
	_wait = wait
	visible = true
	_on_squads_changed()
	_refresh_gear()
	if spawn_flag >= 0 and world.flags[spawn_flag]["owner"] != world.local.team:
		spawn_flag = -1
		map_view.selected_flag = -1


func _process(delta: float) -> void:
	if not visible:
		return
	_wait = maxf(_wait - delta, 0.0)
	if spawn_flag >= 0 and world.flags[spawn_flag]["owner"] != world.local.team:
		spawn_flag = -1
		map_view.selected_flag = -1
	var beacon_problem := world.squads.spawn_problem(world.local) if world.local else "-"
	var squad := world.squads.squad_of(world.local.sid) if world.local else {}
	_beacon_button.visible = world.squads.beacon_pos(squad) != null
	_beacon_button.disabled = beacon_problem != ""
	_beacon_button.tooltip_text = beacon_problem
	if spawn_flag == C.SPAWN_BEACON and beacon_problem != "":
		spawn_flag = -1
	var where := "BAZA"
	if spawn_flag >= 0:
		where = T.t("FLAGA %s — %s") % [world.flags[spawn_flag]["letter"], T.t(String(world.flags[spawn_flag]["name"])).to_upper()]
	elif spawn_flag == C.SPAWN_BEACON:
		where = "PUNKT ODRODZENIA ODDZIAŁU"
	deploy_button.disabled = _wait > 0.0
	deploy_button.text = "DO BOJU" if _wait <= 0.0 else T.t("ODRODZENIE ZA %d") % int(ceil(_wait))
	status.text = T.t("Miejsce wejścia: %s") % T.t(where)
	if world.ffa:
		status.text = "Miejsce wejścia: z dala od wrogów"
	_level_label.text = T.t("POZIOM %d") % world.level
	if world.level >= Gear.MAX_LEVEL:
		_xp_label.text = "maksymalny"
		_xp_bar.value = _xp_bar.max_value
	else:
		var into := world.xp - Gear.xp_total(world.level)
		var step := Gear.xp_step(world.level)
		_xp_label.text = "%d / %d XP" % [into, step]
		_xp_bar.max_value = step
		_xp_bar.value = into


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).physical_keycode
	if key >= KEY_1 and key <= KEY_5:
		_select_class(key - KEY_1)
	elif (key == KEY_SPACE or key == KEY_ENTER) and _wait <= 0.0:
		_deploy()


func _deploy() -> void:
	if _wait > 0.0:
		return
	Sfx.play("ui_deploy", -4.0)
	Settings.save_settings()
	Net.send_deploy(class_id, spawn_flag, _kit())
