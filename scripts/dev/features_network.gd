extends Node
## Actual ENet regression for construction, late join, independent gunner and seat transfer.
var passed := 0
var failed := 0

func _ready() -> void:
	if Settings.arg("feature-role") == "server":
		_server()
	else:
		_client()

func _server() -> void:
	Net.start_dedicated({"mode": "podboj", "map": "neonowa_dzielnica", "bots_per_team": 0}, 17857)
	while Net.world == null:
		await get_tree().process_frame
	var w := Net.world
	var pos := Vector3(-178, 0, 88)
	w.on_vehicle(900, 0, pos, 0, 800, 0)
	w.vehicles[900]["home"] = [pos, 0.0]
	w.vehicles[900]["free_since"] = Net.server_time()
	w.vehicles[900]["respawn_at"] = INF
	var driver := w.add_soldier(9001, 0, 0, "NetworkDriver")
	driver.respawn(pos, 0, 0)
	driver.set_physics_process(false)
	w.server.enter_vehicle(driver, 900)
	w.on_fort({"id": 77, "kind": 0, "team": 0, "owner": driver.sid, "flag": 0, "pos": Vector3(-185, 0, 84), "yaw": 0.0, "hp": 300.0})
	var placed := false
	var occupied := 0.0
	var deadline := Net.server_time() + 60
	while Net.server_time() < deadline:
		await get_tree().create_timer(.05).timeout
		for s: Soldier in w.soldiers.values():
			if s.peer != 0 and s.alive and not placed:
				placed = true
				Net.broadcast(&"place", [s.sid, Vector3(-174, .1, 88), 0.0])
		if w.vehicles[900]["gunner"] != 0:
			if occupied == 0:
				occupied = Net.server_time()
			if driver.is_vehicle() and Net.server_time() - occupied > 2.5:
				w.server.exit_vehicle(driver)
	get_tree().quit(0)

func _client() -> void:
	Net.start_client("127.0.0.1", 17857, "NetworkEngineer")
	if not await _until(func() -> bool: return Net.world != null and Net.world.local != null, 15):
		print("[features-net] FAIL joining server")
		get_tree().quit(1)
		return
	var w := Net.world
	var s := w.local
	await _until(func() -> bool: return w.forts.items.has(77) and w.vehicles.has(900), 5)
	_check("late join receives existing construction", w.forts.items.has(77))
	_check("late join restores driven tank", w.soldiers.has(9001) and w.soldiers[9001].is_vehicle())
	Net.send_deploy(3, -1, {})
	await _until(func() -> bool: return s.alive and s.position.distance_to(Vector3(-174, .1, 88)) < 1.0, 7)
	_check("engineer deploys with shotgun", s.alive and s.weapon_id() == C.W.SCATTER)
	Net.send_build(0, Vector3(-173, 0, 83), 0)
	await _until(func() -> bool: return w.forts.items.size() == 2, 9)
	_check("construction crosses server-client connection", w.forts.items.size() == 2)
	await _until(func() -> bool: return w.forts.local_materials < 90, 1)
	_check("server replicates material cost", w.forts.local_materials < 90)
	_check("client obstacle navigation updates", not w.map.b.nav.is_free(w.map.b.nav.cell_of(Vector3(-173, 0, 83))))
	Net.send_use()
	await _until(func() -> bool: return s.is_gunner(), 5)
	_check("second human enters roof gun over network", s.is_gunner() and s.weapon_id() == C.W.TANK_MG)
	if not s.is_gunner():
		get_tree().quit(1)
		return
	s.yaw = 1.0
	Net.send_state(Vector3(999, 999, 999), 1.0, 0.2, s.state_flags(), 0, 2.5)
	await get_tree().create_timer(.4).timeout
	_check("gunner aim stays independent of hull", absf(w.soldiers[9001].hull_yaw) < .05 and s.position.distance_to(w.soldiers[9001].position) < 1)
	var ammo: int = s.mags[0]
	s.consume_shot()
	Net.send_fire(0, s.eye_position(), s.aim_direction(), Net.server_time() - Net.INTERP_DELAY)
	await get_tree().create_timer(.3).timeout
	_check("roof gun fires with independent ammunition", s.mags[0] == ammo - 1)
	await _until(func() -> bool: return w.vehicles[900]["driver"] == 0, 7)
	Net.send_switch_seat()
	await _until(func() -> bool: return s.is_vehicle() and not s.is_gunner(), 5)
	_check("network seat transfer makes gunner driver", s.is_vehicle() and not s.is_gunner() and w.vehicles[900]["driver"] == s.sid)
	var start := s.position
	Input.action_press("move_forward")
	await get_tree().create_timer(1.5).timeout
	Input.action_release("move_forward")
	_check("transferred driver can move tank", s.position.distance_to(start) > 3)
	Net.send_use()
	await _until(func() -> bool: return not s.is_vehicle(), 5)
	_check("network exit restores infantry", not s.is_vehicle() and s.class_data().get("builder", false) and s.hp <= 110)
	print("[features-net] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _until(test: Callable, seconds: float) -> bool:
	var deadline := Net.server_time() + seconds
	while not test.call() and Net.server_time() < deadline:
		await get_tree().create_timer(.05).timeout
	return test.call()

func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[features-net] %s %s" % ["PASS" if ok else "FAIL", label])
