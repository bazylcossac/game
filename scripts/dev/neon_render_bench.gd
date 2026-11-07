extends Node
## `--test=scratch --file=res://scripts/dev/neon_render_bench.gd [--map=<id>] [--quality=3] [--out=<dir>] [--bots=0]`,
## windowed: what the map alone costs to draw from fixed camera spots, at street level and high
## up, with a screenshot of each so a change can be judged by eye as well as by the numbers.
##   --spot=<name>   only that spot
##   --scale=2       render at twice the resolution, to load the graphics card like a slower one
##   --nosun=1       without the sun's shadow
##   --parts=1       at one spot, hide each kind of scenery in turn; --parts=props splits the props
##                   by model, --parts=quick only hides everything at once, --cast=1 turns off
##                   shadows instead of hiding, --parts=env turns off each screen effect instead

const SAMPLE := 3.0
## [name, camera position, point looked at]
const SPOTS := [
	["plac", Vector3(0, 1.7, 62), Vector3(0, 4, 0)],
	["bulwar", Vector3(20, 1.7, 300), Vector3(0, 8, 0)],
	["aleja", Vector3(176, 1.7, 220), Vector3(170, 8, -200)],
	["przecznica", Vector3(110, 1.7, 84), Vector3(-200, 6, 80)],
	["dach", Vector3(-120, 40, 170), Vector3(60, 18, -100)],
	["wysoko", Vector3(0, 95, 340), Vector3(0, 0, 40)],
]

var out_dir := ""


func _ready() -> void:
	get_window().unfocusable = true
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.quality = int(Settings.arg("quality", "3"))
	Settings.apply_display()
	Engine.max_fps = 0
	out_dir = Settings.arg("out", "user://neon_bench")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var map_id := Settings.arg("map", "neonowa_dzielnica")
	var bots := int(Settings.arg("bots", "0"))
	Net.start_offline(Modes.normalize({"mode": "podboj", "map": map_id, "difficulty": 1, "bots_per_team": bots}))
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	if bots == 0:
		w.server.bots.clear()
	await _wait(1.0)
	w.hud.visible = false
	var camera := Camera3D.new()
	camera.fov = 75.0
	camera.far = 900.0
	w.add_child(camera)
	camera.current = true
	# --scale=2 renders four times the pixels: a stand-in for a slower graphics card, where the
	# fill rate runs out first. This card idles at a low clock on the map alone.
	get_viewport().scaling_3d_scale = float(Settings.arg("scale", "1"))
	if Settings.arg("nosun", "") != "":
		for sun in w.get_children():
			if sun is DirectionalLight3D:
				sun.shadow_enabled = false
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await _wait(3.0)
	print("[bench] %s, quality %d, %s, 3d scale %.1f" % [map_id, Settings.quality, str(get_viewport().get_visible_rect().size), get_viewport().scaling_3d_scale])
	var only := Settings.arg("spot", "")
	if Settings.arg("parts", "") != "":
		var spot: Array = SPOTS[0]
		for s: Array in SPOTS:
			if s[0] == only:
				spot = s
		camera.global_position = spot[1]
		camera.look_at(spot[2])
		await _wait(1.0)
		if Settings.arg("parts") == "env":
			await _env_parts(w)
		else:
			await _parts(w)
		get_tree().quit(0)
		return
	for spot: Array in SPOTS:
		if only != "" and spot[0] != only:
			continue
		camera.global_position = spot[1]
		camera.look_at(spot[2])
		camera.current = true
		await _wait(1.0)
		await _measure(spot[0])
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, spot[0]])
	get_tree().quit(0)


## Turns off one screen effect at a time.
func _env_parts(w: Node) -> void:
	var env: Environment
	for child in w.get_children():
		if child is WorldEnvironment:
			env = (child as WorldEnvironment).environment
	await _measure("all")
	for prop: String in ["ssr_enabled", "ssao_enabled", "ssil_enabled", "volumetric_fog_enabled", "glow_enabled", "fog_enabled"]:
		if not env.get(prop):
			print("[bench] %s already off" % prop)
			continue
		env.set(prop, false)
		await _wait(0.4)
		await _measure("-" + prop.trim_suffix("_enabled"))
		env.set(prop, true)
	for sun in w.get_children():
		if sun is DirectionalLight3D and (sun as DirectionalLight3D).shadow_enabled:
			sun.shadow_enabled = false
			await _wait(0.4)
			await _measure("-sun shadow")
			sun.shadow_enabled = true
	var vp := get_viewport()
	vp.use_taa = false
	await _wait(0.4)
	await _measure("-taa")
	vp.use_taa = true


## Hides one kind of scenery at a time, to see what each costs to draw.
func _parts(w: Node) -> void:
	var groups := {}
	var names := {}
	for key: String in Mats._world:
		names[Mats._world[key]] = key
	var map_root: Node = w.map_root if "map_root" in w else w
	var mesh_count := {}
	for node in map_root.find_children("*", "GeometryInstance3D", true, false):
		var key := node.get_class()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is ArrayMesh:
			var m: Material = (node as MeshInstance3D).mesh.surface_get_material(0)
			if names.has(m):
				key = "batch:" + names[m]
		if node is MultiMeshInstance3D:
			var mm := (node as MultiMeshInstance3D).multimesh
			var prop_name := "?"
			for p: String in CityProps._meshes:
				if CityProps._meshes[p] == mm.mesh:
					prop_name = p
			key = "mm:%s(%d surf)" % [prop_name, mm.mesh.get_surface_count()] if Settings.arg("parts") == "props" else "multimesh"
		if not groups.has(key):
			groups[key] = []
		groups[key].append(node)
	for key: String in groups:
		mesh_count[key] = groups[key].size()
	print("[bench] groups ", mesh_count)
	# Where the loose meshes live, by the first node under the world that holds them.
	var owners := {}
	for n: Node in groups.get("MeshInstance3D", []):
		var top := n
		while top.get_parent() != map_root:
			top = top.get_parent()
		var label := "%s(%s)" % [top.get_class(), String(top.name).left(14)]
		var mesh: Mesh = (n as MeshInstance3D).mesh
		var tri := 0
		if mesh:
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				tri += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] else arr[Mesh.ARRAY_VERTEX].size()) / 3
		if not owners.has(label):
			owners[label] = [0, 0]
		owners[label][0] += 1
		owners[label][1] += tri
	print("[bench] loose meshes by owner ", owners)
	var lights: Array = map_root.find_children("*", "Light3D", true, false)
	await _measure("all")
	# --cast=1 turns off only each group's shadow instead of hiding it.
	var cast := Settings.arg("cast", "") != ""
	for key: String in groups:
		if groups[key].size() < 4 or Settings.arg("parts") == "quick":
			continue
		var was := {}
		for n in groups[key]:
			if not is_instance_valid(n):
				continue
			was[n] = n.cast_shadow
			if cast:
				n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				n.visible = false
		await _wait(0.3)
		await _measure(("-shadow " if cast else "-") + key)
		for n: GeometryInstance3D in was:
			if is_instance_valid(n):
				n.cast_shadow = was[n]
				n.visible = true
	var everything := []
	for key: String in groups:
		for n in groups[key]:
			if is_instance_valid(n) and n.visible:
				n.visible = false
				everything.append(n)
	await _wait(0.3)
	await _measure("-all geometry")
	for n in everything:
		if is_instance_valid(n):
			n.visible = true
	for l: Light3D in lights:
		if not l is DirectionalLight3D:
			l.visible = false
	await _wait(0.3)
	await _measure("-omni/spot")
	for l: Light3D in lights:
		l.visible = true
	for l: Light3D in lights:
		if l is DirectionalLight3D:
			l.shadow_enabled = false
	await _wait(0.3)
	await _measure("-sun shadow")


func _measure(label: String) -> void:
	var rid := get_viewport().get_viewport_rid()
	var frame_ms := PackedFloat32Array()
	var gpu := PackedFloat32Array()
	var cpu := PackedFloat32Array()
	var t := 0.0
	var objects := 0.0
	var draws := 0.0
	var tris := 0.0
	while t < SAMPLE:
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		frame_ms.append(d * 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		tris += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var frames := frame_ms.size()
	# Medians: another program on the machine now and then stretches a few frames.
	print("[bench] %-11s fps %5.0f | frame %5.2f | gpu %5.2f | render cpu %5.2f | objects %5.0f | draws %5.0f | tris %6.0fk" % [
		label, frames / t, _median(frame_ms), _median(gpu), _median(cpu), objects / frames, draws / frames, tris / frames / 1000.0])


static func _median(values: PackedFloat32Array) -> float:
	values.sort()
	return values[values.size() / 2]


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
