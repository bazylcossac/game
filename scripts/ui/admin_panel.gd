class_name AdminPanel
extends Control
## F1: switches for testing the gameplay. Open to everyone for now; the server runs each order.

const WIDTH := 460.0

var world: World
var _built := false
var _toggles := {}
var _mouse_before := Input.MOUSE_MODE_VISIBLE


func _build() -> void:
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := UiKit.panel(18)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -WIDTH - 24.0
	panel.offset_right = -24.0
	panel.offset_top = 64.0
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(WIDTH - 36.0, 900.0)
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UiKit.label("PANEL ADMINA", 32, UiKit.INK, "title"))
	box.add_child(UiKit.wrapped("Do testów rozgrywki. F1 zamyka.", 19, UiKit.MUTED))

	_section(box, "GRACZ")
	_toggle(box, "god", "Nieśmiertelność")
	_toggle(box, "noclip", "Noclip (Spacja w górę, Ctrl w dół, Shift szybciej)")
	_toggle(box, "ammo", "Nieskończona amunicja i granaty")
	_grid(box, [
		["Zdrowie i amunicja", func() -> void: Net.send_admin("heal")],
		["Teleport w celownik", _teleport],
		["Moneta (superklasa)", func() -> void: Net.send_admin("coin")],
	])

	_section(box, "BOTY")
	_grid(box, [
		["+2 na stronę", func() -> void: Net.send_admin("bots_more")],
		["-2 na stronę", func() -> void: Net.send_admin("bots_less")],
		["Manekin wroga przed tobą", func() -> void: Net.send_admin("dummy")],
		["Zabij wszystkie boty", func() -> void: Net.send_admin("kill_bots")],
		["Usuń wszystkie boty", func() -> void: Net.send_admin("bots_clear")],
	])
	_toggle(box, "freeze", "Zamroź boty")

	_section(box, "POJAZDY")
	_grid(box, [
		["Czołg przed tobą", func() -> void: Net.send_admin("tank")],
		["Transporter przed tobą", func() -> void: Net.send_admin("apc")],
		["Odnów wszystkie pojazdy", func() -> void: Net.send_admin("fix_vehicles")],
	])

	_section(box, "MECZ")
	_grid(box, [
		["Zajmij wszystkie flagi", func() -> void: Net.send_admin("flags")],
		["Wygraj rundę", func() -> void: Net.send_admin("win")],
		["Nowa runda", func() -> void: Net.send_admin("round")],
	])


func _section(box: VBoxContainer, title: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	box.add_child(gap)
	box.add_child(UiKit.label(title, 22, UiKit.BRASS, "bold"))


func _grid(box: VBoxContainer, items: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for item: Array in items:
		var b := UiKit.button(item[0])
		b.custom_minimum_size = Vector2((WIDTH - 48.0) * 0.5, 40)
		b.add_theme_font_size_override("font_size", 19)
		b.clip_text = true
		b.pressed.connect(item[1])
		grid.add_child(b)
	box.add_child(grid)


func _toggle(box: VBoxContainer, cmd: String, title: String) -> void:
	var c := CheckBox.new()
	c.text = title
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 20)
	c.toggled.connect(func(_on: bool) -> void: Net.send_admin(cmd))
	_toggles[cmd] = c
	box.add_child(c)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if not _built:
		_build()
	visible = true
	_sync()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not visible:
		return
	visible = false
	# The deploy screen and the end screen need the pointer; the fight does not.
	if not world.hud.deploy_visible() and world.controller.state == PlayerController.State.ALIVE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = _mouse_before


func _process(_delta: float) -> void:
	if visible:
		_sync()


## The boxes show what the server says, not what was last clicked.
func _sync() -> void:
	var me := world.local
	var states := {"god": me != null and me.god, "noclip": me != null and me.noclip, "ammo": me != null and me.inf_ammo, "freeze": world.bots_frozen}
	for cmd: String in _toggles:
		(_toggles[cmd] as CheckBox).set_pressed_no_signal(states[cmd])


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


## Whatever solid thing sits under the crosshair, up to 800 m away.
func _teleport() -> void:
	var cam := world.controller.camera
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * 800.0, C.LAYER_WORLD)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		world.on_notice("NIC NIE MA W CELOWNIKU")
		return
	Net.send_admin("tp", (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.6)
