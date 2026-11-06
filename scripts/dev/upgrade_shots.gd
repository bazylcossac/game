extends Node
var out_dir := ""
var count := 0

func _ready() -> void:
	out_dir = Settings.arg("out", "user://upgrades")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	Settings.fullscreen = false
	Settings.apply_display()
	await _studio()
	await _arsenal()
	await _lineup()
	await _fps()
	await _valley()
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	count += 1
	var path := "%s/%02d_%s.png" % [out_dir, count, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("[upgrade-shot] ", path)

func _studio() -> void:
	var stage := Node3D.new()
	add_child(stage)
	var sun := Atmos.setup(stage)
	sun.look_at_from_position(Vector3(-3, 5, -4), Vector3.ZERO)
	var environment := (stage.get_child(0) as WorldEnvironment).environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.09, .11, .13)
	environment.volumetric_fog_enabled = false
	environment.fog_enabled = false
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2, 3, -3)
	fill.light_color = Color(.84, .91, 1)
	fill.light_energy = .6
	fill.omni_range = 12
	stage.add_child(fill)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	plane.material = Mats.world("concrete")
	floor.mesh = plane
	floor.position.y = -.25
	stage.add_child(floor)
	var camera := Camera3D.new()
	camera.fov = 32
	stage.add_child(camera)
	camera.current = true
	for spec: Array in [["karabinek", C.W.CARBINE, []], ["dodatki", C.W.CARBINE, ["holo", "suppressor", "vgrip", "bigcell"]], ["wyrzutnia", C.W.AT_ROCKET, []], ["pistolet", C.W.PISTOL, []]]:
		var gun := WeaponFactory.build(spec[1], 0, spec[2])
		stage.add_child(gun)
		camera.position = Vector3(.95, .5, .65)
		camera.look_at(Vector3(0, .01, -.2))
		await get_tree().create_timer(.3).timeout
		await _shot(spec[0])
		gun.free()
	var soldiers: Array[SoldierModel] = []
	for team in 2:
		var soldier := SoldierModel.new()
		soldier.setup(team)
		stage.add_child(soldier)
		soldier.set_loadout(C.W.CARBINE if team == 0 else C.W.ASSAULT, 0)
		soldiers.append(soldier)
	for frame in 40:
		for team in 2:
			soldiers[team].update_pose(.016, Vector3(-.6 if team == 0 else .6, 0, 0), 0, 0, 0, false, false, false, true)
		await get_tree().process_frame
	camera.position = Vector3(2.8, 1.6, -4.5)
	camera.look_at(Vector3(0, .95, 0))
	await _shot("postacie")
	camera.position = Vector3(-.95, 1.65, -1.1)
	camera.look_at(Vector3(-.6, 1.45, 0))
	await _shot("postac_detale")
	stage.queue_free()
	await get_tree().process_frame

## One lit stage, used for the gallery shots below.
func _stage() -> Dictionary:
	var stage := Node3D.new()
	add_child(stage)
	var sun := Atmos.setup(stage)
	sun.look_at_from_position(Vector3(-3, 6, -5), Vector3.ZERO)
	var environment := (stage.get_child(0) as WorldEnvironment).environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.42, .46, .5)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.8, .84, .9)
	environment.ambient_light_energy = .75
	environment.volumetric_fog_enabled = false
	environment.fog_enabled = false
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	plane.material = Mats.world("concrete")
	floor.mesh = plane
	stage.add_child(floor)
	var camera := Camera3D.new()
	camera.fov = 30
	stage.add_child(camera)
	camera.current = true
	return {"stage": stage, "camera": camera, "floor": floor}


## Every weapon and side worth showing: the Empire's guns are separate models, its blades are not.
func _gallery() -> Array:
	var out := []
	for id: int in C.WEAPONS:
		if id in [C.W.TANK_CANNON, C.W.TANK_MG, C.W.MECH_GOLEM, C.W.MECH_GOLIAT, C.W.MECH_LAUNCHER]:
			continue
		out.append([id, 0])
		if WeaponFactory.ASSETS.has(id):
			out.append([id, 1])
	return out


## Every weapon, one at a time, from the same side.
func _arsenal() -> void:
	var s := await _stage()
	var camera: Camera3D = s["camera"]
	(s["floor"] as Node3D).position.y = -.4
	for pick: Array in _gallery():
		var id: int = pick[0]
		var gun := WeaponFactory.build(id, pick[1], [])
		(s["stage"] as Node3D).add_child(gun)
		var blade := C.is_blade(id)
		var centre := Vector3(0, .5, 0) if blade else Vector3(0, .03, -float(C.WEAPONS[id].get("range", 0)) * 0 - .2)
		var far := 2.3 if blade else 2.0
		camera.position = centre + Vector3(far, .5, -far * .55)
		camera.look_at(centre)
		await get_tree().create_timer(.12).timeout
		await _shot("%s_%s" % ["bron" if pick[1] == 0 else "imperium", str(C.WEAPONS[id]["name"]).to_lower().replace(" ", "_")])
		gun.free()
	(s["stage"] as Node3D).queue_free()
	await get_tree().process_frame


## Each class of each side in a row, armed, front and back, to see how the kit sits on the body.
func _lineup() -> void:
	var s := await _stage()
	var camera: Camera3D = s["camera"]
	var stage: Node3D = s["stage"]
	for team in 2:
		var models: Array[SoldierModel] = []
		for class_id in C.CLASSES[team].size():
			var cd := C.cls(team, class_id)
			if cd.get("mech", false) or cd.get("vehicle", false):
				continue
			var m := SoldierModel.new()
			m.setup(team)
			stage.add_child(m)
			m.set_loadout(cd["weapons"][0], class_id)
			models.append(m)
		var gap := 1.2
		for frame in 30:
			for i in models.size():
				models[i].update_pose(.016, Vector3((i - (models.size() - 1) * .5) * gap, 0, 0), 0, 0, 0, false, true, false, true)
			await get_tree().process_frame
		var width := models.size() * gap
		for spec: Array in [["przod", -1.0], ["tyl", 1.0]]:
			camera.position = Vector3(width * .2, 1.4, float(spec[1]) * (width * 1.15 + 1.0))
			camera.look_at(Vector3(0, .95, 0))
			await get_tree().create_timer(.1).timeout
			await _shot("klasy_%d_%s" % [team, spec[0]])
		for m in models:
			m.free()
	stage.queue_free()
	await get_tree().process_frame


func _start(mode: String, map: String) -> World:
	Net.start_offline({"mode": mode, "map": map, "bots_per_team": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	return Net.world

func _stop() -> void:
	get_tree().current_scene.call("_close_world")
	await get_tree().process_frame
	Net.leave()
	await get_tree().process_frame

func _fps() -> void:
	var w := await _start("pvp", "neonowa_dzielnica")
	w.server.bots.clear()
	w.local.level = 30
	var kit := Gear.sanitize(0, {"primary": C.W.CARBINE, "parts_p": ["holo", "suppressor", "vgrip", "bigcell"], "ordnance": "rockets"}, 30)
	Net.send_deploy(0, -1, kit)
	await get_tree().create_timer(.5).timeout
	w.local.teleport(Vector3(0, .1, 60))
	w.local.yaw = 0
	w.local.pitch = -.02
	w.local.protected_t = 9999
	await get_tree().create_timer(1).timeout
	await _shot("widok_broni")
	w.controller.call("_switch", 3)
	await get_tree().create_timer(1).timeout
	await _shot("widok_wyrzutni")
	await _stop()

func _valley() -> void:
	var w := await _start("czolgi", "dolina_pancerna")
	w.hud.visible = false
	var camera := Camera3D.new()
	w.add_child(camera)
	camera.current = true
	camera.fov = 52
	camera.position = Vector3(-600, 480, 650)
	camera.look_at(Vector3.ZERO)
	await get_tree().create_timer(.4).timeout
	await _shot("dolina_z_gory")
	var home: Vector3 = w.map.bases()[0]
	camera.position = home + Vector3(0, 8, 45)
	camera.look_at(home + Vector3(0, 12, -180))
	await get_tree().create_timer(.3).timeout
	await _shot("oslona_bazy")
	await _stop()
