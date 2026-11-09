extends Node
## `--test=menu-art --out=<dir>`, windowed: stages the pictures on the menu cards inside the real
## maps. tools/menu_art.py then crops them into assets/textures/menu.

const SCENES := [
	# name, mode, map, camera, look at, figures, tanks, shots
	{"name": "map_stare_miasto", "mode": "podboj", "map": "stare_miasto", "cam": Vector3(-14, 7, 46), "look": Vector3(30, 7, -40)},
	{"name": "map_rynek", "mode": "pvp", "map": "rynek", "cam": Vector3(0, 3.0, 20), "look": Vector3(0, 6, -30)},
	{"name": "map_pole_bitwy", "mode": "pvp", "map": "pole_bitwy", "cam": Vector3(4, 2.4, 40), "look": Vector3(4, 3.2, 0)},
	{"name": "map_neonowa_dzielnica", "mode": "podboj", "map": "neonowa_dzielnica", "cam": Vector3(22, 3.2, 196), "look": Vector3(4, 22, 40)},
	{"name": "map_stacja_rdzen", "mode": "pvp", "map": "stacja_rdzen", "cam": Vector3(0, 2.0, 15), "look": Vector3(0, 2.6, -6)},
	{"name": "map_dolina_pancerna", "mode": "czolgi", "map": "dolina_pancerna", "cam": Vector3(-260, 26, 250), "look": Vector3(0, 6, 0)},
	{"name": "mode_podboj", "mode": "podboj", "map": "stare_miasto", "cam": Vector3(9, 1.5, 24), "look": Vector3(-2, 2.4, 8),
		"men": [[0, 0, 6.4, 21.3, -3, 5, false], [0, 0, 9.8, 18.6, -1, 3, true], [1, 0, -5, 5, 8, 20, false], [1, 2, -1, 3, 8, 20, false], [1, 0, 3, 3.5, 8, 20, false]],
		"bolts": [[0, 6.4, 21.3, -1, 3], [1, -1, 3, 6.4, 21.3], [1, -5, 5, 9, 22], [0, 9.8, 18.6, 3, 3.5], [1, 3, 3.5, 8, 23]]},
	{"name": "mode_pvp", "mode": "pvp", "map": "rynek", "cam": Vector3(-12, 1.4, 9), "look": Vector3(6, 1.8, 9),
		"men": [[0, 2, -9.5, 7.2, 7, 9, false], [1, 3, 7, 9, -9, 7, false], [1, 0, 9.5, 12, -9, 7, false]],
		"bolts": [[0, -9.5, 7.2, 7, 9], [1, 7, 9, -9.5, 7.2], [1, 9.5, 12, -10, 6]]},
	{"name": "mode_deathmatch", "mode": "pvp", "map": "neonowa_dzielnica", "cam": Vector3(13, 1.4, 116), "look": Vector3(12, 3.2, 96),
		"men": [[1, 3, 8.5, 108, 15, 106, false], [0, 0, 15.5, 106, 9, 108, false], [1, 1, 12, 100, 15, 106, true]],
		"bolts": [[1, 8.5, 108, 15.5, 106], [0, 15.5, 106, 8.5, 108], [1, 12, 100, 15.5, 106]]},
	{"name": "mode_czolgi", "mode": "czolgi", "map": "dolina_pancerna", "cam": Vector3(-242, 2.2, 242), "look": Vector3(-222, 3.0, 228), "bolt_height": 1.6,
		"tanks": [[0, -232, 238, -2.2], [1, -228, 226, 0.95]],
		"bolts": [[0, -232, 238, -228, 226], [1, -228, 226, -232, 238]]},
	{"name": "neon_bulwar", "mode": "podboj", "map": "neonowa_dzielnica", "cam": Vector3(16, 2.2, 158), "look": Vector3(2, 12, 40), "tanks": [[0, 12, 128, 0.15]]},
	{"name": "neon_plac", "mode": "podboj", "map": "neonowa_dzielnica", "cam": Vector3(26, 3, 62), "look": Vector3(-4, 8, 0)},
	{"name": "neon_aleja", "mode": "podboj", "map": "neonowa_dzielnica", "cam": Vector3(176, 2.2, 196), "look": Vector3(170, 16, 60)},
	{"name": "neon_przecznica", "mode": "podboj", "map": "neonowa_dzielnica", "cam": Vector3(-34, 3, 76), "look": Vector3(-150, 12, 82)},
	{"name": "neon_park", "mode": "podboj", "map": "neonowa_dzielnica", "cam": Vector3(36, 3.5, 108), "look": Vector3(120, 8, 200)},
	{"name": "neon_z_gory", "mode": "podboj", "map": "neonowa_dzielnica", "cam": Vector3(-300, 260, 420), "look": Vector3(0, 10, 0)},
	{"name": "neon_baza", "mode": "podboj", "map": "neonowa_dzielnica", "cam": Vector3(-6, 3, 334), "look": Vector3(10, 10, 240), "tanks": [[0, -11, 292, 0.0], [0, 11, 292, 0.0], [0, 33, 292, 0.0]]},
	{"name": "neon_czolg_i_mech", "mode": "podboj", "map": "neonowa_dzielnica", "cam": Vector3(6, 2.0, 128), "look": Vector3(16, 6.5, 84), "bolt_height": 2.2,
		"tanks": [[0, 12, 108, 0.1], [1, 18, 72, 3.0]], "men": [[1, 5, 22, 100, 12, 108, false]], "bolts": [[1, 22, 100, 12, 108], [0, 12, 108, 18, 72]]},
	{"name": "stare_ulica", "mode": "podboj", "map": "stare_miasto", "cam": Vector3(-132, 2.0, 33), "look": Vector3(-60, 3.2, 34)},
	{"name": "stare_rynek", "mode": "podboj", "map": "stare_miasto", "cam": Vector3(30, 2.6, 30), "look": Vector3(0, 4, 0)},
	{"name": "stare_ratusz", "mode": "podboj", "map": "stare_miasto", "cam": Vector3(-100, 2.2, 99), "look": Vector3(-132, 8, 62)},
	{"name": "stare_czolg", "mode": "podboj", "map": "stare_miasto", "cam": Vector3(40, 2.2, 104), "look": Vector3(32, 2.6, 60), "tanks": [[0, 30, 76, 0.1], [0, 38, 52, 0.0]]},
	{"name": "stare_z_gory", "mode": "podboj", "map": "stare_miasto", "cam": Vector3(-200, 170, 220), "look": Vector3(0, 0, 0)},
	{"name": "neon_niebo", "mode": "podboj", "map": "neonowa_dzielnica", "cam": Vector3(14, 2, 120), "look": Vector3(60, 300, -300), "hold": 9.0},
	{"name": "map_ziemia_niczyja", "mode": "podboj", "map": "ziemia_niczyja", "cam": Vector3(-96, 2.2, 126), "look": Vector3(-60, 3, 60), "hold": 2.0},
	{"name": "ziemia_okop", "mode": "podboj", "map": "ziemia_niczyja", "cam": Vector3(-151, 1.65, 114), "look": Vector3(-136, 1.2, 114), "hold": 1.0},
	{"name": "ziemia_stopien", "mode": "podboj", "map": "ziemia_niczyja", "cam": Vector3(-144, 1.65, 112.5), "look": Vector3(-130, 1.5, 60), "hold": 1.0},
	{"name": "ziemia_przedpole", "mode": "podboj", "map": "ziemia_niczyja", "cam": Vector3(-44, 3.2, 100), "look": Vector3(-20, 3.5, 20), "hold": 2.0},
	{"name": "ziemia_kosciol", "mode": "podboj", "map": "ziemia_niczyja", "cam": Vector3(40, 2.4, 40), "look": Vector3(0, 8, -24), "hold": 2.0},
	{"name": "ziemia_bateria", "mode": "podboj", "map": "ziemia_niczyja", "cam": Vector3(-212, 2, -6), "look": Vector3(-232, 2, -30), "hold": 2.0},
	{"name": "ziemia_z_gory", "mode": "podboj", "map": "ziemia_niczyja", "cam": Vector3(-210, 130, 300), "look": Vector3(-40, 0, 90), "hold": 1.0},
	{"name": "czolganie_bok", "mode": "pvp", "map": "rynek", "cam": Vector3(3.6, 0.7, 12), "look": Vector3(0, 0.3, 12), "prone": true, "men": [[0, 0, 0, 12, 0, 2, false]]},
	{"name": "czolganie_przod", "mode": "pvp", "map": "rynek", "cam": Vector3(1.2, 0.7, 8.8), "look": Vector3(0, 0.3, 12), "prone": true, "men": [[1, 0, 0, 12, 0, 2, false]]},
	{"name": "side_usa", "mode": "pvp", "map": "rynek", "cam": Vector3(0.2, 0.8, 12.4), "look": Vector3(0, 1.5, 8), "relaxed": true,
		"men": [[0, 4, 0, 8.5, 0.2, 13, false], [0, 0, -1.7, 9.3, 0.6, 13, false], [0, 2, 1.7, 9.2, -0.6, 13, false]]},
	{"name": "side_imperium", "mode": "pvp", "map": "neonowa_dzielnica", "cam": Vector3(14.2, 0.8, 104.4), "look": Vector3(14, 1.6, 100), "relaxed": true,
		"men": [[1, 2, 14, 100.8, 14.2, 105, false], [1, 0, 12.7, 101.4, 14.6, 105, false], [1, 3, 15.3, 101.3, 13.4, 105, false]]},
	# Checks for Corp Wars, written to their own folder: never run menu_art.py over these.
	{"name": "check_korpo", "mode": "pvp", "map": "neonowa_dzielnica", "cam": Vector3(14, 1.5, 107), "look": Vector3(14, 1.2, 100), "relaxed": true,
		"men": [[1, 0, 10, 100, 10, 107, false], [1, 1, 12, 100, 12, 107, false], [1, 2, 14, 100, 14, 107, false], [1, 3, 16, 100, 16, 107, false], [1, 4, 18, 100, 18, 107, false], [1, 5, 8, 100, 8, 107, false], [1, 7, 20, 100, 20, 107, false]]},
	{"name": "check_rebels", "mode": "pvp", "map": "neonowa_dzielnica", "cam": Vector3(14, 1.5, 107), "look": Vector3(14, 1.2, 100), "relaxed": true,
		"men": [[0, 0, 10, 100, 10, 107, false], [0, 1, 12, 100, 12, 107, false], [0, 2, 14, 100, 14, 107, false], [0, 3, 16, 100, 16, 107, false], [0, 4, 18, 100, 18, 107, false], [0, 5, 8, 100, 8, 107, false], [0, 7, 20, 100, 20, 107, false]]},
	{"name": "check_fight", "mode": "pvp", "map": "neonowa_dzielnica", "cam": Vector3(4, 1.7, 110), "look": Vector3(14, 1.4, 96),
		"men": [[1, 2, 16, 92, 6, 104, false], [1, 0, 19, 95, 6, 104, false], [0, 5, 6, 104, 16, 92, false], [0, 0, 9, 107, 16, 92, true]],
		"bolts": [[1, 16, 92, 6, 104], [0, 6, 104, 16, 92], [1, 19, 95, 9, 107]]},
	{"name": "check_shield", "mode": "pvp", "map": "neonowa_dzielnica", "cam": Vector3(14, 1.5, 106), "look": Vector3(14, 1.3, 100),
		"men": [[0, 5, 12.5, 100, 12.5, 107, false, C.W.ENERGY_SHIELD], [0, 0, 15.5, 100, 15.5, 107, false, C.W.CARBINE, 1.0], [1, 0, 18, 100, 18, 107, false, C.W.ASSAULT, -1.0]]},
	{"name": "check_office", "mode": "pvp", "map": "neonowa_dzielnica", "cam": Vector3(-102, 1.7, 147), "look": Vector3(-130, 1.2, 116)},
	{"name": "check_office_wall", "mode": "pvp", "map": "neonowa_dzielnica", "cam": Vector3(-130, 1.7, 128), "look": Vector3(-138.5, 2.0, 140)},
	{"name": "check_office_desk", "mode": "pvp", "map": "neonowa_dzielnica", "cam": Vector3(-108, 1.2, 120), "look": Vector3(-120, 0.8, 132)},
	{"name": "check_office_door", "mode": "pvp", "map": "neonowa_dzielnica", "cam": Vector3(-118, 1.7, 100), "look": Vector3(-118, 2.0, 130)},
	{"name": "check_ads", "mode": "pvp", "map": "neonowa_dzielnica", "cam": Vector3(0, 2.0, 150), "look": Vector3(-40, 18, 110)},
	{"name": "check_street", "mode": "pvp", "map": "neonowa_dzielnica", "cam": Vector3(10, 1.8, 180), "look": Vector3(0, 8, 60)},
]

var out_dir := ""


func _ready() -> void:
	out_dir = Settings.arg("out", "user://menu_art")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().unfocusable = true
	get_window().size = Vector2i(1600, 900)
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.quality = int(Settings.arg("quality", "3"))
	Settings.apply_display()
	var only := Settings.arg("only", "")
	for scene: Dictionary in SCENES:
		if only == "" or only.contains(String(scene["name"])):
			await _stage(scene)
	get_tree().quit(0)


func _stage(scene: Dictionary) -> void:
	var bots := int(Settings.arg("bots", "0"))
	Net.start_offline(Modes.normalize({"mode": scene["mode"], "map": scene["map"], "difficulty": 0, "bots_per_team": bots}))
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	if bots == 0:
		w.server.bots.clear()
	w.hud.visible = false
	await _wait(0.6)
	var stage := Node3D.new()
	w.add_child(stage)
	var camera := Camera3D.new()
	camera.fov = 52.0
	camera.far = 2600.0
	stage.add_child(camera)
	camera.position = _ground(w, scene["cam"])
	camera.look_at(_ground(w, scene["look"]), Vector3.UP)
	camera.current = true

	var men: Array = []
	for spec: Array in scene.get("men", []):
		var team: int = spec[0]
		var cd := C.cls(team, spec[1])
		var m: Node3D = MechModel.new() if cd.get("mech", false) else SoldierModel.new()
		m.call("setup", team)
		stage.add_child(m)
		# Optional: a weapon to hold instead of the first, and a lean.
		m.call("set_loadout", spec[7] if spec.size() > 7 else cd["weapons"][0], spec[1])
		if spec.size() > 8:
			m.set("lean", spec[8])
		men.append([m, spec])
	for spec: Array in scene.get("tanks", []):
		var tank := TankModel.new()
		tank.setup(spec[0])
		stage.add_child(tank)
		var at := Vector3(spec[1], 0, spec[2])
		at.y = w.map.ground_height(at.x, at.z) - 1.1
		tank.park(at, spec[3])
	for frame in 40:
		for pair: Array in men:
			var spec: Array = pair[1]
			var at := Vector3(spec[2], 0, spec[3])
			at.y = w.map.ground_height(at.x, at.z)
			var to := Vector3(spec[4], 0, spec[5]) - Vector3(at.x, 0, at.z)
			if scene.get("prone", false):
				(pair[0] as Node3D).set("prone", true)
			(pair[0] as Node3D).call("update_pose", 0.016, at, atan2(-to.x, -to.z), 0.0, 0.0, spec[6], not scene.get("relaxed", false), false, true)
		await get_tree().process_frame
	for round_no in 3:
		for spec: Array in scene.get("bolts", []):
			var from := Vector3(spec[1], 0, spec[2])
			var to := Vector3(spec[3], 0, spec[4])
			var height: float = scene.get("bolt_height", 1.3)
			from.y = w.map.ground_height(from.x, from.z) + height
			to.y = w.map.ground_height(to.x, to.z) + height
			w.fx.spawn_shot(C.W.CARBINE, spec[0], from, to, 0, round_no == 2)
		await get_tree().create_timer(0.05).timeout
	await _wait(float(scene.get("hold", 0.0)))
	if Settings.has_arg("fps"):
		await _wait(float(Settings.arg("settle", "0")))
		var start := Time.get_ticks_msec()
		var frames := 0
		while Time.get_ticks_msec() - start < 5000:
			await get_tree().process_frame
			frames += 1
		print("[art] fps %s: %.0f" % [scene["name"], frames / 5.0])
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, scene["name"]]
	get_viewport().get_texture().get_image().save_png(path)
	print("[art] ", path)
	stage.queue_free()
	get_tree().current_scene.call("_close_world")
	await get_tree().process_frame
	Net.leave()
	await get_tree().process_frame


## A camera height is measured from the ground under it, because maps are not flat.
func _ground(w: World, p: Vector3) -> Vector3:
	return Vector3(p.x, w.map.ground_height(p.x, p.z) + p.y, p.z)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
