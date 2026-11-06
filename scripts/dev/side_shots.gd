extends Node
## `--test=side-shots --out=<dir>`, windowed: the match as the Iron Empire sees it, its soldiers
## and its guns.
var out_dir := ""
var count := 0


func _ready() -> void:
	out_dir = Settings.arg("out", "user://sides")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	Settings.fullscreen = false
	Settings.apply_display()
	Settings.side = C.Team.EMPIRE
	Net.start_offline({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	w.server.bots.clear()
	await _wait(1.2)
	await _shot("rozmieszczenie_imperium")
	Net.send_deploy(2, -1, Gear.sanitize(2, {}, 30, C.Team.EMPIRE))
	await _wait(1.4)
	var me := w.local
	me.protected_t = 9999
	await _wait(0.5)
	await _shot("widok_droida_ciezkiego")
	me.nades[C.NADE_SMOKE] = 3
	me.nade_kind = C.NADE_SMOKE
	w.hud.visible = false
	var stage := Node3D.new()
	w.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 30
	var at := me.global_position
	var models: Array[SoldierModel] = []
	var line := [[0, C.W.ASSAULT], [2, C.W.HEAVY], [3, C.W.SCATTER], [1, C.W.SNIPER], [C.COMMAND_CLASS, C.W.ASSAULT]]
	for i in line.size():
		var m := SoldierModel.new()
		m.setup(C.Team.EMPIRE)
		stage.add_child(m)
		m.set_loadout(line[i][1], line[i][0])
		models.append(m)
	var base := at + Vector3(0, 0, -6)
	for frame in 30:
		for i in models.size():
			var p := base + Vector3((i - 2) * 1.5, 0, 0)
			p.y = w.map.ground_height(p.x, p.z)
			models[i].update_pose(.016, p, PI, 0.0, 0.0, false, true, false, true)
		await get_tree().process_frame
	base.y = w.map.ground_height(base.x, base.z)
	camera.global_position = base + Vector3(1.2, 1.6, 7.4)
	camera.look_at(base + Vector3(0, 1.0, 0))
	await _wait(0.2)
	await _shot("droidy_przod")
	camera.global_position = base + Vector3(-1.2, 1.7, -7.6)
	camera.look_at(base + Vector3(0, 1.1, 0))
	await _wait(0.2)
	await _shot("droidy_tyl")
	camera.fov = 22
	for i in 3:
		var p: Vector3 = models[i].global_position
		camera.global_position = p + Vector3(0.9, 1.6, 3.2)
		camera.look_at(p + Vector3(0, 1.2, 0))
		await _wait(0.15)
		await _shot("droid_%d" % i)
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	count += 1
	var path := "%s/%02d_%s.png" % [out_dir, count, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("[side-shots] ", path)
