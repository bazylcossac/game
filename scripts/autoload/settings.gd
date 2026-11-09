extends Node
## Persistent player settings, input map and command-line options.

signal language_changed

const PATH := "user://settings.cfg"

var player_name := "Bojownik"
## Which side this player joins, unless the mode has none.
var side := 0
var language := "pl"
var show_fps := false
## Rain, dust and the weather show. Off is cheaper on weak graphics cards.
var weather_fx := true
var sensitivity := 0.22
var ads_sensitivity := 0.8
var fov := 85.0
var master_volume := 0.85
var sfx_volume := 1.0
var music_volume := 0.55
var quality := 2  ## 0 low, 1 medium, 2 high, 3 ultra
var fullscreen := true
var vsync := true
var invert_y := false
var last_server := "127.0.0.1"
var bots_per_team := 12
var difficulty := 1
var match_mode := Modes.DEFAULT_MODE
var match_map := ""
## Identifies this player to the server that stores their progress.
var token := ""
var kits := {}

## Parsed from the command line, see main.gd.
var args := {}

const QUALITY_NAMES := ["Niska", "Średnia", "Wysoka", "Ultra"]

## Physical keycodes so WASD stays WASD on any keyboard layout.
const KEYS := {
	"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
	"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C], "reload": [KEY_R],
	"grenade": [KEY_G], "grenade_next": [KEY_H], "slot1": [KEY_1], "slot2": [KEY_2], "slot3": [KEY_3], "slot4": [KEY_4],
	"melee": [KEY_F], "super": [KEY_B], "use": [KEY_E], "seat": [KEY_X], "lean_left": [KEY_Q], "lean_right": [KEY_E], "build_menu": [KEY_V], "build": [KEY_T], "artillery": [KEY_Y], "prone": [KEY_Z], "thermal": [KEY_N], "map": [KEY_M], "scoreboard": [KEY_TAB], "pause": [KEY_ESCAPE], "admin": [KEY_F1],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	_build_input_map()
	_carry_over_saves()
	load_settings()
	T.setup(language)
	if has_arg("token"):
		token = arg("token")
	elif token == "":
		token = Crypto.new().generate_random_bytes(16).hex_encode()
		save_settings()
	if DisplayServer.get_name() != "headless":
		apply_display()
	apply_audio()


## Each side keeps its own kits: the same class number means a different soldier.
func kit_for(class_id: int, team := 0) -> Dictionary:
	return kits.get(class_id + team * 100, Gear.default_kit(class_id, team))


func set_kit(class_id: int, kit: Dictionary, team := 0) -> void:
	kits[class_id + team * 100] = kit


func _parse_args() -> void:
	for raw: String in OS.get_cmdline_user_args():
		var clean := raw.trim_prefix("--")
		var eq := clean.find("=")
		if eq >= 0:
			args[clean.substr(0, eq)] = clean.substr(eq + 1)
		else:
			args[clean] = "true"


func set_language(code: String) -> void:
	language = code
	T.apply(code)
	save_settings()
	language_changed.emit()


func arg(key: String, fallback: String = "") -> String:
	return String(args.get(key, fallback))


func has_arg(key: String) -> bool:
	return args.has(key)


func _build_input_map() -> void:
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for pair: Array in [["fire", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT]]:
		InputMap.add_action(pair[0])
		var ev := InputEventMouseButton.new()
		ev.button_index = pair[1]
		InputMap.action_add_event(pair[0], ev)


## The game was called Miecz Dawida until 0.13.0, and Godot keeps its files in a folder named after
## the game. The first start under the new name copies the settings and the progress across.
func _carry_over_saves() -> void:
	var here := OS.get_user_data_dir()
	var old := here.get_base_dir().path_join("Miecz Dawida")
	if here.ends_with("Miecz Dawida") or not DirAccess.dir_exists_absolute(old):
		return
	for file: String in ["settings.cfg", "progress.cfg"]:
		var from := old.path_join(file)
		var to := here.path_join(file)
		if FileAccess.file_exists(from) and not FileAccess.file_exists(to):
			DirAccess.copy_absolute(from, to)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	player_name = cfg.get_value("player", "name", player_name)
	side = cfg.get_value("player", "side", side)
	language = cfg.get_value("player", "language", language)
	show_fps = cfg.get_value("video", "show_fps", show_fps)
	weather_fx = cfg.get_value("video", "weather", weather_fx)
	last_server = cfg.get_value("player", "last_server", last_server)
	sensitivity = cfg.get_value("input", "sensitivity", sensitivity)
	ads_sensitivity = cfg.get_value("input", "ads_sensitivity", ads_sensitivity)
	invert_y = cfg.get_value("input", "invert_y", invert_y)
	fov = cfg.get_value("video", "fov", fov)
	quality = cfg.get_value("video", "quality", quality)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	vsync = cfg.get_value("video", "vsync", vsync)
	master_volume = cfg.get_value("audio", "master", master_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	bots_per_team = cfg.get_value("match", "bots_per_team", bots_per_team)
	difficulty = cfg.get_value("match", "difficulty", difficulty)
	match_mode = cfg.get_value("match", "mode", match_mode)
	match_map = cfg.get_value("match", "map", match_map)
	token = cfg.get_value("player", "token", token)
	kits = cfg.get_value("player", "kits", kits)


func save_settings() -> void:
	if has_arg("test"):
		return  # Test runs must never touch the player's real settings.
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "last_server", last_server)
	cfg.set_value("input", "sensitivity", sensitivity)
	cfg.set_value("input", "ads_sensitivity", ads_sensitivity)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("match", "bots_per_team", bots_per_team)
	cfg.set_value("match", "difficulty", difficulty)
	cfg.set_value("match", "mode", match_mode)
	cfg.set_value("match", "map", match_map)
	cfg.set_value("player", "token", token)
	cfg.set_value("player", "kits", kits)
	cfg.set_value("player", "side", side)
	cfg.set_value("player", "language", language)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("video", "weather", weather_fx)
	cfg.save(PATH)


func apply_display() -> void:
	var win := get_window()
	if has_arg("windowed"):
		win.mode = Window.MODE_WINDOWED
	else:
		win.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	for pair: Array in [["SFX", sfx_volume], ["Music", music_volume]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(pair[1], 0.0001)))


## Applies the current quality preset to an environment and the root viewport.
func apply_quality(env: Environment, sun: DirectionalLight3D) -> void:
	var vp := get_viewport()
	env.ssao_enabled = quality >= 1
	env.ssil_enabled = quality >= 3
	env.sdfgi_enabled = quality >= 3
	env.volumetric_fog_enabled = quality >= 2
	env.glow_enabled = true
	env.ssr_enabled = false
	# Half-size passes: on wet ground and in shadowed corners nobody can tell them from full ones.
	RenderingServer.environment_set_ssr_half_size(true)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality <= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = quality >= 2
	vp.msaa_3d = Viewport.MSAA_DISABLED
	if sun:
		sun.shadow_enabled = not sun.has_meta("no_shadow")
		sun.directional_shadow_max_distance = [90.0, 140.0, 220.0, 320.0][quality]
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if quality == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
