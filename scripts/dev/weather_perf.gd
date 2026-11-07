extends Node
## `--test=perf-weather --map=<id> [--bots=<per team>] [--quality=3]`, windowed: what a frame costs
## with the weather on, with rain and dust off (the settings switch), and with the whole sky show off,
## from a few fixed spots. Prints one table, times in milliseconds. Vsync off, so fps is the real cost.

const SAMPLE := 4.0
const SETTLE := 1.0
## Spots as [name, x, z, yaw, height above the ground]. Ground level and a high look over the city.
const SPOTS := {
	"neonowa_dzielnica": [["aleja", 0.0, 60.0, 0.0, 1.7], ["skrzyżowanie", 60.0, -40.0, 1.6, 1.7], ["dach", 0.0, 120.0, 0.0, 45.0]],
	"ziemia_niczyja": [["okop", 0.0, 150.0, 3.14, 1.7], ["ziemia niczyja", 0.0, 0.0, 1.57, 1.7], ["wysoko", 0.0, 220.0, 3.14, 50.0]],
}


func _ready() -> void:
	get_window().unfocusable = true
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.weather_fx = true
	Settings.quality = int(Settings.arg("quality", "3"))
	Settings.apply_display()
	Engine.max_fps = 0
	var map_id := Settings.arg("map", "neonowa_dzielnica")
	var bots := int(Settings.arg("bots", "8"))
	Net.start_offline(Modes.normalize({"mode": "podboj", "map": map_id, "difficulty": 1, "bots_per_team": bots}))
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	await _wait(0.6)
	Net.send_deploy(0, -1, {})
	while not w.local.alive:
		await get_tree().process_frame
	w.local.god = true
	w.hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var weather: Weather = null
	for node in w.find_children("*", "Weather", true, false):
		weather = node
	print("[weather] %s, quality %d, %s, weather: %s" % [map_id, Settings.quality, str(get_viewport().get_visible_rect().size), "yes" if weather else "none on this map"])
	await _wait(4.0)
	var rows := []
	for spot: Array in SPOTS.get(map_id, [["start", w.local.global_position.x, w.local.global_position.z, w.local.yaw, 1.7]]):
		var ground := w.map.ground_height(spot[1], spot[2])
		w.local.noclip = true
		w.local.global_position = Vector3(spot[1], ground + float(spot[4]) - C.STAND_EYE, spot[2])
		w.local.yaw = spot[3]
		w.local.pitch = -0.25 if float(spot[4]) > 10.0 else -0.02
		await _wait(1.5)
		var on := await _measure()
		if weather:
			weather.set_effects(false)
		await _wait(SETTLE)
		var dry := await _measure()
		if weather:
			weather.set_process(false)
			weather.visible = false
		await _wait(SETTLE)
		var bare := await _measure()
		if weather:
			weather.set_process(true)
			weather.visible = true
			weather.set_effects(true)
		await _wait(SETTLE)
		rows.append([spot[0], on, dry, bare])
	print("[weather] %-14s | %-24s | %-24s | %-24s" % ["miejsce", "pogoda wlaczona", "bez deszczu i pylu", "bez calej pogody"])
	for r: Array in rows:
		print("[weather] %-14s | %s | %s | %s" % [r[0], _cell(r[1]), _cell(r[2]), _cell(r[3])])
	get_tree().quit(0)


func _cell(m: Dictionary) -> String:
	return "%4.0f fps %5.2f ms gpu %5.2f" % [m["fps"], m["frame"], m["gpu"]]


func _measure() -> Dictionary:
	var rid := get_viewport().get_viewport_rid()
	var frames := 0
	var gpu := 0.0
	var t := 0.0
	while t < SAMPLE:
		await get_tree().process_frame
		t += get_process_delta_time()
		frames += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	return {"fps": frames / t, "frame": t / frames * 1000.0, "gpu": gpu / frames}


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
