class_name SettingsPanel
extends VBoxContainer
## Settings content, reused by the main menu and the pause menu.

signal closed

const CONTROLS := [
	["WSAD", "Ruch"], ["Mysz", "Rozglądanie"], ["LPM", "Strzał / cięcie"], ["PPM", "Celowanie / blok mieczem"],
	["Shift", "Sprint"], ["Spacja", "Skok"], ["Ctrl / C", "Kucanie"], ["R", "Przeładowanie"],
	["1 2 3 4", "Broń (4: tarcza ciężkiego Rebelii)"], ["Q / E", "Wychylenie w lewo / w prawo"], ["F", "Szybkie cięcie"], ["G", "Granat"], ["B", "Superklasa (moneta)"], ["X", "Wsiadanie do pojazdu (2 s)"], ["E", "Wysiadanie z pojazdu"], ["Tab", "Wyniki"], ["Esc", "Menu"], ["F1", "Panel admina"],
]


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	add_child(UiKit.label("USTAWIENIA", 42, UiKit.INK, "title"))
	add_child(UiKit.accent_bar())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.custom_minimum_size = Vector2(430, 0)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.custom_minimum_size = Vector2(430, 0)
	cols.add_child(right)

	left.add_child(UiKit.slider_row("Czułość myszy", 0.05, 1.0, 0.01, Settings.sensitivity, "%.2f", func(v: float) -> void: Settings.sensitivity = v))
	left.add_child(UiKit.slider_row("Czułość przy celowaniu", 0.3, 1.5, 0.05, Settings.ads_sensitivity, "%.2f", func(v: float) -> void: Settings.ads_sensitivity = v))
	left.add_child(UiKit.slider_row("Pole widzenia", 65, 110, 1, Settings.fov, "%.0f°", func(v: float) -> void: Settings.fov = v))
	left.add_child(UiKit.slider_row("Głośność główna", 0, 1, 0.01, Settings.master_volume, "%.2f", func(v: float) -> void:
		Settings.master_volume = v
		Settings.apply_audio()))
	left.add_child(UiKit.slider_row("Efekty", 0, 1, 0.01, Settings.sfx_volume, "%.2f", func(v: float) -> void:
		Settings.sfx_volume = v
		Settings.apply_audio()))
	left.add_child(UiKit.slider_row("Muzyka", 0, 1, 0.01, Settings.music_volume, "%.2f", func(v: float) -> void:
		Settings.music_volume = v
		Settings.apply_audio()))

	var language := HBoxContainer.new()
	var language_title := UiKit.label("Język", 22, UiKit.MUTED)
	language_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language.add_child(language_title)
	language.add_child(LanguageSwitch.new())
	right.add_child(language)
	right.add_child(UiKit.choice_row("Jakość grafiki", Settings.QUALITY_NAMES, Settings.quality, func(i: int) -> void:
		Settings.quality = i
		_apply_quality()))
	right.add_child(_check("Pełny ekran", Settings.fullscreen, func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply_display()))
	right.add_child(_check("Synchronizacja pionowa", Settings.vsync, func(on: bool) -> void:
		Settings.vsync = on
		Settings.apply_display()))
	right.add_child(_check("Odwróć oś Y", Settings.invert_y, func(on: bool) -> void: Settings.invert_y = on))
	right.add_child(_check("Licznik FPS", Settings.show_fps, func(on: bool) -> void: Settings.show_fps = on))
	right.add_child(_check("Deszcz i efekty pogody", Settings.weather_fx, func(on: bool) -> void:
		Settings.weather_fx = on
		for weather in get_tree().root.find_children("*", "Weather", true, false):
			(weather as Weather).set_effects(on)))
	right.add_child(UiKit.label("Sterowanie", 22, UiKit.MUTED))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 0)
	for pair: Array in CONTROLS:
		grid.add_child(UiKit.label(pair[0], 20, UiKit.BRASS, "semibold"))
		grid.add_child(UiKit.label(pair[1], 20, UiKit.MUTED))
	right.add_child(grid)

	var back := UiKit.button("ZAPISZ I WRÓĆ")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Vector2(280, 54)
	back.pressed.connect(func() -> void:
		Settings.save_settings()
		closed.emit())
	add_child(back)


func _check(title: String, value: bool, on_change: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = title
	c.button_pressed = value
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool) -> void: on_change.call(on))
	return c


func _apply_quality() -> void:
	var env_node := get_tree().root.find_child("WorldEnvironment", true, false)
	for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		env_node = n
	var sun := get_tree().root.find_child("Sun", true, false) as DirectionalLight3D
	if env_node:
		Settings.apply_quality((env_node as WorldEnvironment).environment, sun)
