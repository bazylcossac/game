extends Node
## `--test=tank-shots --out=<dir>`, windowed: the tank in a real match, from the driver's seat, the
## gunner's seat and outside, with the roof gun aimed away from the main gun.
var out_dir := ""
var count := 0


func _ready() -> void:
	out_dir = Settings.arg("out", "user://tank")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	Settings.fullscreen = false
	Settings.apply_display()
	Net.start_offline({"mode": "czolgi", "map": "dolina_pancerna", "bots_per_team": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	w.server.bots.clear()
	Net.send_deploy(0, -1, Gear.sanitize(0, {}, 30))
	await _wait(1.0)
	var me := w.local
	me.protected_t = 9999
	print("[tank-shots] seat %d, vehicle %d" % [me.vehicle_seat, me.vehicle_id])
	await _wait(0.6)
	await _shot("kierowca")

	# Hand the driving seat to a teammate, so the local player sits at the roof gun.
	var vehicle := me.vehicle_id
	w.server.switch_seat(me)
	var mate := w.add_soldier(900, 0, 0, "Kierowca")
	mate.respawn(me.global_position + Vector3(4, 0.1, 0), 0, 0)
	mate.set_physics_process(false)
	w.server.enter_vehicle(mate, vehicle)
	await _wait(0.5)
	print("[tank-shots] gunner %s, driver model %s" % [str(me.is_gunner()), str(mate.model)])
	var ahead := me.hull_yaw
	me.yaw = ahead
	me.pitch = 0.04
	await _wait(0.5)
	await _shot("strzelec_przod")
	me.yaw = ahead - 1.5
	me.pitch = 0.16
	await _wait(0.4)
	await _shot("strzelec_bok")
	var tank: TankModel = w.gunner_tank(me)
	print("[tank-shots] station turned %.2f rad, muzzle %s" % [tank.roof_mount.rotation.y, str(tank.gunner_muzzle().round())])
	w.controller.call("_shoot")
	await _wait(0.03)
	await _shot("strzelec_ogien")

	var at := me.global_position
	var forward := Basis(Vector3.UP, ahead) * Vector3.FORWARD
	var side := forward.cross(Vector3.UP)
	var foe := TankModel.new()
	foe.setup(1)
	w.add_child(foe)
	var foe_at := at + side * 9.0 + forward * 2.0
	foe_at.y = w.map.ground_height(foe_at.x, foe_at.z)
	foe.park(foe_at, ahead + 0.3)
	foe.turret.rotation.y = -0.5
	foe.set_gunner_aim(ahead + 1.2, 0.2, true)
	w.hud.visible = false
	var camera := Camera3D.new()
	w.add_child(camera)
	camera.current = true
	camera.fov = 38
	var centre := (at + foe_at) * 0.5 + Vector3.UP * 1.4
	for spec: Array in [["oba_przod", forward * 19.0 + side * 3.0 + Vector3.UP * 3.4], ["oba_tyl", -forward * 19.0 - side * 4.0 + Vector3.UP * 4.5]]:
		camera.global_position = centre + spec[1]
		camera.look_at(centre)
		await _wait(0.3)
		await _shot(spec[0])
	camera.fov = 30
	camera.global_position = at + side * -9.0 + forward * 7.0 + Vector3.UP * 5.0
	camera.look_at(at + Vector3.UP * 2.0)
	await _wait(0.2)
	await _shot("zblizenie")
	camera.global_position = foe_at + side * 9.0 + forward * 7.0 + Vector3.UP * 3.0
	camera.look_at(foe_at + Vector3.UP * 1.6)
	foe.set_health(0.15)
	await _wait(0.2)
	await _shot("uszkodzony")
	foe.play_death()
	foe.update_pose(0.016, foe_at, 0.0, 0.0, 0.0, false, false, false, false)
	await _wait(0.2)
	await _shot("wrak")
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	count += 1
	var path := "%s/%02d_%s.png" % [out_dir, count, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("[tank-shots] ", path)
