extends Node
## Real ENet deployment, slot four, projectile replication and authoritative armor damage.
var passed := 0
var failed := 0
const START := Vector3(12, 30.1, 20)
const TARGET := Vector3(12, 30.1, -30)

func _ready() -> void:
	if Settings.arg("ordnance-role") == "server":
		Net.start_dedicated({"mode":"podboj", "map":"neonowa_dzielnica", "bots_per_team":0}, 17862)
		while Net.world == null:
			await get_tree().process_frame
		var w := Net.world
		_range(w)
		w.on_vehicle(99, 1, TARGET, PI, 800, 0)
		w.vehicles[99]["home"] = [TARGET, PI]
		w.vehicles[99]["free_since"] = Net.server_time()
		w.vehicles[99]["respawn_at"] = INF
		var foe := w.add_soldier(802, 0, 1, "NetworkArmorTarget")
		foe.respawn(TARGET, 0, 0)
		foe.set_physics_process(false)
		w.server.enter_vehicle(foe, 99)
		foe.protected_t = 0
		var placed := false
		var deadline := Net.server_time() + 35
		while Net.server_time() < deadline:
			await get_tree().create_timer(.05).timeout
			if foe.hp == 500.0:
				foe.hp = 100.0
			for s: Soldier in w.soldiers.values():
				if s.peer != 0 and s.alive and not placed:
					placed = true
					Net.broadcast(&"place", [s.sid, START, 0.0])
		get_tree().quit(0)
	else:
		await _client()

func _range(w: World) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = C.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(28, 1, 75)
	shape.shape = box
	body.add_child(shape)
	w.add_child(body)
	body.position = Vector3(12, 29.5, -5)

func _client() -> void:
	Net.start_client("127.0.0.1", 17862, "NetworkAssault")
	if not await _until(func() -> bool: return Net.world != null and Net.world.local != null, 15):
		_check("joins ENet server", false)
		get_tree().quit(1)
		return
	var w := Net.world
	_range(w)
	var s := w.local
	Net.send_deploy(0, -1, Gear.sanitize(0, {"ordnance":"rockets"}, 1))
	await _until(func() -> bool: return s.alive and s.position.distance_to(START) < 1, 5)
	_check("network deploy replaces grenades with exactly three rockets", s.alive and s.grenades == 0 and s.loadout.has(C.W.AT_ROCKET) and s.mags[3] + s.reserves[3] == 3)
	await _until(func() -> bool: return w.soldiers.has(802) and w.soldiers[802].is_vehicle(), 3)
	var foe: Soldier = w.soldiers.get(802)
	if foe == null or not s.loadout.has(C.W.AT_ROCKET):
		get_tree().quit(1)
		return
	w.controller.call("_switch", 3)
	await get_tree().create_timer(.6).timeout
	_check("fourth weapon slot selects launcher over network", s.weapon_id() == C.W.AT_ROCKET)
	_aim(s, foe)
	w.controller.call("_shoot")
	await _until(func() -> bool: return not w.rockets.is_empty(), .4)
	_check("client receives flying projectile before impact", not w.rockets.is_empty() and foe.hp == 800)
	await _until(func() -> bool: return foe.hp < 800, 3)
	_check("server replicates first armor hit", foe.hp == 650)
	await _until(func() -> bool: return s.reload_t <= 0 and s.mags[3] == 1, 4)
	_check("reload brings up the next rocket", s.mags[3] == 1 and s.reserves[3] == 1)
	_aim(s, foe)
	w.controller.call("_shoot")
	await _until(func() -> bool: return foe.hp < 650, 3)
	_check("second rocket hurts but does not destroy", foe.alive and foe.hp <= 500)
	await _until(func() -> bool: return s.reload_t <= 0 and s.mags[3] == 1, 4)
	_aim(s, foe)
	w.controller.call("_shoot")
	await _until(func() -> bool: return not foe.alive, 3)
	_check("a last network hit destroys worn armor", not foe.alive)
	_check("network kit grants no fourth rocket", s.mags[3] == 0 and s.reserves[3] == 0 and not s.can_fire())
	print("[ordnance-net] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _aim(s: Soldier, foe: Soldier) -> void:
	var to := foe.position + Vector3.UP * 1.3 - s.eye_position()
	s.yaw = atan2(-to.x, -to.z)
	s.pitch = atan2(to.y, Vector2(to.x, to.z).length())

func _until(test: Callable, seconds: float) -> bool:
	var deadline := Net.server_time() + seconds
	while not test.call() and Net.server_time() < deadline:
		await get_tree().create_timer(.025).timeout
	return test.call()

func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[ordnance-net] %s %s" % ["PASS" if ok else "FAIL", label])
