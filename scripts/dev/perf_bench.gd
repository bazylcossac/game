extends Node
## `--test=perf-fx --map=<id> --bots=<per team> [--quality=3] [--spot=x,z,yaw]`, windowed: what a frame
## costs in a real match, and what each screen effect adds to it. Time is in milliseconds.

const SAMPLE := 5.0

var _env: Environment
var _base := {}


func _ready() -> void:
	get_window().unfocusable = true
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.quality = int(Settings.arg("quality", "3"))
	Settings.apply_display()
	Engine.max_fps = 0
	var map_id := Settings.arg("map", "neonowa_dzielnica")
	var bots := int(Settings.arg("bots", "15"))
	Net.start_offline(Modes.normalize({"mode": "podboj", "map": map_id, "difficulty": 1, "bots_per_team": bots}))
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	await _wait(0.6)
	Net.send_deploy(0, -1, {})
	while not w.local.alive:
		await get_tree().process_frame
	w.local.protected_t = 9999.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var spot := Settings.arg("spot", "0,60,0").split(",")
	w.local.global_position = Vector3(float(spot[0]), 1.0, float(spot[1]))
	w.local.yaw = float(spot[2])
	w.local.pitch = -0.02
	for child in w.get_children():
		if child is WorldEnvironment:
			_env = (child as WorldEnvironment).environment
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await _wait(6.0)
	print("[perf] %s, %d bots a side, quality %d, %s, %d soldiers" % [map_id, bots, Settings.quality, str(get_viewport().get_visible_rect().size), w.soldiers.size()])
	var counts := {}
	var faded := 0
	var shadowed := 0
	var tris := {}
	for node in w.find_children("*", "Node3D", true, false):
		var kind := node.get_class()
		counts[kind] = int(counts.get(kind, 0)) + 1
		if node is Light3D:
			faded += 1 if (node as Light3D).distance_fade_enabled else 0
			shadowed += 1 if (node as Light3D).shadow_enabled else 0
	print("[perf] nodes %s, lights faded %d, lights with shadows %d" % [counts, faded, shadowed])
	await _measure("all on")
	if Settings.arg("parts", "") != "":
		await _parts(w)
		get_tree().quit(0)
		return
	await _switch("ssr_enabled", "no reflections")
	await _switch("ssao_enabled", "no ambient occlusion")
	await _switch("ssil_enabled", "no indirect light")
	await _switch("volumetric_fog_enabled", "no volumetric fog")
	await _switch("glow_enabled", "no glow")
	var vp := get_viewport()
	var taa := vp.use_taa
	vp.use_taa = false
	await _wait(0.5)
	await _measure("no TAA")
	vp.use_taa = taa
	for sun: Node in w.get_children():
		if sun is DirectionalLight3D:
			(sun as DirectionalLight3D).shadow_enabled = false
			await _wait(0.5)
			await _measure("no sun shadow")
			(sun as DirectionalLight3D).shadow_enabled = true
	get_tree().quit(0)


## Takes the game apart a piece at a time, to see where the main thread goes.
func _parts(w: World) -> void:
	var hud: Node = w.hud
	var canvas: CanvasItem = hud.get("canvas")
	var minimap: CanvasItem = hud.get("minimap")
	canvas.set_process(false)
	canvas.visible = false
	hud.set_process(false)
	minimap.visible = false
	minimap.set_process(false)
	await _wait(0.5)
	await _measure("no HUD, no minimap")
	canvas.set_process(true)
	canvas.visible = true
	hud.set_process(true)
	minimap.set_process(true)
	await _wait(0.5)
	await _measure("all on again")
	for s: Soldier in w.soldiers.values():
		if s != w.local:
			s.set_process(false)
	await _wait(0.5)
	await _measure("no soldier animation")
	for s: Soldier in w.soldiers.values():
		s.set_process(true)
	for node in w.find_children("*", "Node", true, false):
		if node is MapLife or node is Weather:
			node.set_process(false)
	await _wait(0.5)
	await _measure("no map life, no sky")
	for node in w.find_children("*", "Node", true, false):
		if node is MapLife or node is Weather:
			node.set_process(true)
	w.server.bots.clear()
	await _wait(0.5)
	await _measure("bots stop thinking")


func _switch(prop: String, label: String) -> void:
	var was: bool = _env.get(prop)
	if not was:
		print("[perf] %-22s already off" % label)
		return
	_env.set(prop, false)
	await _wait(0.5)
	await _measure(label)
	_env.set(prop, true)
	await _wait(0.3)


func _measure(label: String) -> void:
	var rid := get_viewport().get_viewport_rid()
	var frames := 0
	var gpu := 0.0
	var cpu := 0.0
	var script := 0.0
	var physics := 0.0
	var t := 0.0
	while t < SAMPLE:
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		frames += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		script += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	print("[perf] %-22s fps %5.0f | frame %5.2f | gpu %5.2f | render cpu %5.2f | process %5.2f | physics %5.2f | objects %5d | draws %5d | tris %7.0fk" % [
		label, frames / t, t / frames * 1000.0, gpu / frames, cpu / frames, script / frames, physics / frames,
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
