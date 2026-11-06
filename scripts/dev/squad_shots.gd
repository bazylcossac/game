extends Node
## `--test=squad-shots --out=<dir>`, windowed: the squad screens and the commander's tools in a
## real match, for judging how they look.
var out_dir := ""
var count := 0


func _ready() -> void:
	out_dir = Settings.arg("out", "user://squads")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	Settings.fullscreen = false
	Settings.apply_display()
	Net.start_offline({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	w.server.bots.clear()
	await _wait(1.2)
	var deploy: Node = w.hud.get_parent().find_child("DeployScreen", true, false) if w.hud else null
	if deploy == null:
		deploy = _find_deploy(get_tree().root)
	Net.send_squad(0, 0)
	if deploy:
		deploy.call("_show_tab", 4)
	await _wait(0.5)
	await _shot("ekran_oddzialu")
	if deploy:
		deploy.call("_show_tab", 1)
		await _wait(0.5)
		await _shot("ekran_uzbrojenie_dowodcy")
		deploy.call("_show_tab", 0)
	await _wait(0.2)
	Net.send_deploy(C.COMMAND_CLASS, -1, Gear.sanitize(C.COMMAND_CLASS, {}, 30))
	await _wait(1.2)
	var me := w.local
	me.protected_t = 9999
	var spot: Vector3 = _open_spot(w)
	me.teleport(spot + Vector3.UP * 0.1)
	me.yaw = 0.0
	me.pitch = -0.04
	await _wait(0.6)
	var squad := w.squads.squad_of(me.sid)
	squad["charge"] = 100.0
	squad["next_strike"] = 0.0
	squad["beacon_ready"] = 0.0
	w.squads.place_beacon(me)
	await _wait(0.8)
	await _shot("dowodca_hud_i_punkt")
	var beacon: Variant = w.squads.beacon_pos(squad)
	w.hud.visible = false
	var camera := Camera3D.new()
	w.add_child(camera)
	camera.current = true
	camera.fov = 30
	# The local player has no outside body, so the commanders pose as models beside them.
	var body := me.global_position + Vector3(-6, 0, 2)
	var models: Array[SoldierModel] = []
	for team in 2:
		var m := SoldierModel.new()
		m.setup(team)
		w.add_child(m)
		m.set_loadout(C.W.CARBINE if team == 0 else C.W.ASSAULT, C.COMMAND_CLASS)
		models.append(m)
	for frame in 30:
		for team in 2:
			var at := body + Vector3(team * 1.5, 0, 0)
			at.y = w.map.ground_height(at.x, at.z)
			models[team].update_pose(.016, at, 0.0, 0.0, 0.0, false, true, false, true)
		await get_tree().process_frame
	var mid := body + Vector3(0.75, w.map.ground_height(body.x, body.z) - body.y, 0)
	camera.global_position = mid + Vector3(1.6, 1.7, -5.4)
	camera.look_at(mid + Vector3(0, 1.0, 0))
	await _wait(0.2)
	await _shot("dowodcy_z_przodu")
	camera.global_position = mid + Vector3(-1.6, 1.8, 5.6)
	camera.look_at(mid + Vector3(0, 1.1, 0))
	await _wait(0.2)
	await _shot("dowodcy_z_tylu")
	if beacon != null:
		camera.global_position = (beacon as Vector3) + Vector3(2.8, 1.5, 3.0)
		camera.look_at((beacon as Vector3) + Vector3(0, 0.95, 0))
		await _wait(0.2)
		await _shot("punkt_odrodzenia")
	for m in models:
		m.queue_free()
	w.controller.camera.current = true
	camera.queue_free()
	w.hud.visible = true
	# Turn away from the beacon and look for a point worth shelling.
	var best := me.yaw
	var far := 0.0
	for i in 16:
		var a := TAU * i / 16.0
		var from := me.eye_position()
		var hit := w.server.world_ray(from, from + Basis(Vector3.UP, a) * Vector3(0, -0.04, -1).normalized() * 120.0)
		var reach := 120.0 if hit.is_empty() else from.distance_to(hit["position"])
		if reach > far and reach < 110.0 and w.squads._sky_above(hit.get("position", from)):
			far = reach
			best = a
	me.yaw = best
	me.pitch = -0.04
	w.controller.designating = true
	await _wait(0.9)
	await _shot("celownik_artylerii")
	var target: Vector3 = w.controller.strike_point()
	w.controller.designating = false
	var called := target.is_finite() and w.squads.request_strike(me, target)
	print("[squad-shots] strike called: ", called, " at ", target)
	await _wait(1.2)
	await _shot("ostrzezenie_hud")
	var above := Camera3D.new()
	w.add_child(above)
	above.current = true
	above.fov = 46
	above.global_position = target + Vector3(-26, 24, 26)
	above.look_at(target)
	w.hud.visible = false
	await _wait(0.3)
	await _shot("strefa_ostrzalu")
	await _wait(C.STRIKE_WARNING - 1.2)
	await _shot("ostrzal")
	await _wait(0.75)
	await _shot("ostrzal_2")
	get_tree().quit(0)


func _find_deploy(node: Node) -> Node:
	if node.get_script() != null and node.has_method("_fill_squads"):
		return node
	for child in node.get_children():
		var found := _find_deploy(child)
		if found:
			return found
	return null


func _open_spot(w: World) -> Vector3:
	var flag: Dictionary = w.flags[w.flags.size() / 2]
	for r: float in [50.0, 70.0, 90.0, 40.0]:
		for i in 16:
			var a := TAU * i / 16.0
			var p: Vector3 = flag["pos"] + Vector3(cos(a), 0, sin(a)) * r
			p.y = w.map.ground_height(p.x, p.z)
			var far: Vector3 = p + Vector3(0, 0, -45)
			far.y = w.map.ground_height(far.x, far.z)
			if w.server.world_ray(p + Vector3.UP * 1.6, far + Vector3.UP * 0.4).is_empty():
				return p
	return flag["pos"]


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	count += 1
	var path := "%s/%02d_%s.png" % [out_dir, count, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("[squad-shots] ", path)
