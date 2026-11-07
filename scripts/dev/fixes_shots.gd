extends Node
## `--test=fixes-shots --out=<dir>`, windowed: the deploy cards with health, the crosshair, the big
## map with the player's facing, the safe zone note, the use bar and the admin panel.


func _ready() -> void:
	var out := Settings.arg("out", "user://shots")
	DirAccess.make_dir_recursive_absolute(out)
	Net.start_offline({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 2, "difficulty": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	var m := w.server
	var me := w.local
	await _wait(1.5)
	await _shot(out, "klasy_zdrowie")
	Net.send_deploy(0, -1, {})
	while not me.alive:
		await get_tree().process_frame
	m.sv_admin(multiplayer.get_unique_id(), "freeze", null)
	await _wait(1.2)
	await _shot(out, "strefa_bezpieczna")
	me.global_position = w.flags[2]["pos"] + Vector3(70, 0.2, 60)
	me.last_valid_pos = me.global_position
	me.yaw = 0.8
	await _wait(0.8)
	await _shot(out, "celownik")
	w.hud.big_map.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(0.4)
	await _shot(out, "mapa_kierunek")
	w.hud.big_map.visible = false
	m._admin_vehicle(me, 0)
	await _wait(0.5)
	var vid := 0
	for id: int in w.vehicles:
		vid = maxi(vid, id)
	me.global_position = (w.vehicles[vid]["pos"] as Vector3) + Vector3(4.5, 0.2, 0)
	me.last_valid_pos = me.global_position
	await _wait(0.3)
	m.sv_use(multiplayer.get_unique_id())
	await _wait(0.9)
	await _shot(out, "wsiadanie")
	await _wait(1.5)
	w.hud.admin.open()
	await _wait(0.4)
	await _shot(out, "panel_admina")
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(out: String, name_id: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name_id])
	print("[shots] ", name_id)
