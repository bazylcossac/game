extends Node
## `--test=grenade-shots --out=<dir>`, windowed: the throw frame by frame, each kind going off,
## and the three models up close.
var out_dir := ""
var count := 0


func _ready() -> void:
	out_dir = Settings.arg("out", "user://grenades")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	Settings.fullscreen = false
	Settings.apply_display()
	Net.start_offline({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	w.server.bots.clear()
	await _wait(1.0)
	Net.send_deploy(1, -1, Gear.sanitize(1, {}, 30))
	await _wait(1.2)
	var me := w.local
	me.protected_t = 9999
	var spot: Vector3 = w.flags[w.flags.size() / 2]["pos"] + Vector3(14, 0.1, 14)
	spot.y = w.map.ground_height(spot.x, spot.z) + 0.1
	me.teleport(spot)
	me.yaw = 0.8
	me.pitch = 0.0
	await _wait(0.8)
	await _shot("hud_granaty")
	# A real throw, captured as it plays.
	me.nades[C.NADE_SMOKE] = 5
	me.nade_kind = C.NADE_SMOKE
	w.controller.call("_throw_grenade")
	for label: String in ["rzut_a", "rzut_b", "rzut_c", "rzut_d"]:
		await _wait(0.13)
		await _shot(label)
	await _wait(1.0)
	# Each kind going off in front of the camera.
	var ahead := spot + Basis(Vector3.UP, 0.8) * Vector3(0, 0, -11)
	ahead.y = w.map.ground_height(ahead.x, ahead.z)
	w.areas.start(C.NADE_SMOKE, ahead, me, 0)
	await _wait(3.2)
	await _shot("dym")
	me.yaw = 0.3
	await _wait(0.2)
	await _shot("dym_z_boku")
	w.areas.reset()
	me.yaw = 2.6
	await _wait(0.2)
	var side := spot + Basis(Vector3.UP, 2.6) * Vector3(0, 0, -9)
	side.y = w.map.ground_height(side.x, side.z)
	w.areas.start(C.NADE_FIRE, side, me, 0)
	await _wait(1.6)
	await _shot("ogien")
	# The models themselves, lit by a stage of their own.
	var stage := Node3D.new()
	w.add_child(stage)
	stage.position = Vector3(0, 80, 0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 22
	camera.current = true
	for kind in 3:
		var item := Node3D.new()
		stage.add_child(item)
		item.position = Vector3((kind - 1) * 0.14, 0, 0)
		WeaponFactory.fit(item, "Nade_%d" % kind, 0)
	var lever := Node3D.new()
	stage.add_child(lever)
	lever.position = Vector3(-0.14, 0, 0)
	WeaponFactory.fit(lever, "Nade_spoon", 0)
	WeaponFactory.fit(lever, "Nade_pin", 0)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.3, 0.3, 0.6)
	fill.light_energy = 2.0
	stage.add_child(fill)
	camera.position = Vector3(0.1, 0.08, 0.72)
	camera.look_at(stage.global_position)
	w.hud.visible = false
	await _wait(0.3)
	await _shot("modele")
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	count += 1
	var path := "%s/%02d_%s.png" % [out_dir, count, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("[grenade-shots] ", path)
