extends Node
var passed := 0
var failed := 0

func _ready() -> void:
	Net.start_dedicated({"mode": "czolgi", "map": "dolina_pancerna", "bots_per_team": 0}, 17861)
	while Net.world == null:
		await get_tree().process_frame
	var w := Net.world
	await get_tree().physics_frame
	await get_tree().process_frame
	_check("tank war defaults to large valley", Modes.normalize({"mode": "czolgi"})["map"] == "dolina_pancerna" and w.map.bound() == Vector2(510, 450))
	var starts := [w.map.team_spawns(0), w.map.team_spawns(1)]
	for team in 2:
		for depot: Array in w.map.tank_depots()[team]:
			starts[team].append(depot[0])
	var exposed := 0
	var min_distance := INF
	for a: Vector3 in starts[0]:
		for b: Vector3 in starts[1]:
			a.y = w.map.ground_height(a.x, a.z) + 3.4
			b.y = w.map.ground_height(b.x, b.z) + 3.4
			min_distance = minf(min_distance, a.distance_to(b))
			if w.server.world_ray(a, b).is_empty():
				exposed += 1
	_check("all 100 starting firing lines are screened (%d exposed)" % exposed, exposed == 0)
	_check("opposing starts beyond cannon range plus 10 seconds of closing (%d m)" % min_distance, min_distance > float(C.WEAPONS[C.W.TANK_CANNON]["range"]) + C.TANK_SPEED * 20)
	var routes := true
	for team in 2:
		for f: Dictionary in w.flags:
			routes = routes and w.map.b.nav_tank.can_reach(w.map.bases()[team], f["pos"])
	_check("both bases reach all objectives", routes)
	var coordinate := Vector3(430, 0, -390)
	_check("large map navigation preserves world coordinates", w.map.b.nav._center(w.map.b.nav.cell_of(coordinate)).distance_to(coordinate) < 4)
	_check_shot_sounds()
	var grenades := Gear.sanitize(0, {"ordnance": "grenades"}, 1)
	var rockets := Gear.sanitize(0, {"ordnance": "rockets"}, 1)
	_check("other classes cannot obtain launcher through kit", Gear.sanitize(1, {"ordnance": "rockets"}, 30)["ordnance"] == "grenades")
	var from := Vector3(-190, 0, 378)
	from.y = w.map.ground_height(from.x, from.z) + .1
	var s := w.add_soldier(801, 0, 0, "OrdnanceTester")
	s.respawn(from, 0, 0, grenades)
	s.set_physics_process(false)
	_check("grenade choice gives exactly three grenades", s.grenades == 3 and not s.loadout.has(C.W.AT_ROCKET))
	s.respawn(from, 0, 0, rockets)
	_check("AT choice replaces grenades with three rockets", s.grenades == 0 and s.loadout[3] == C.W.AT_ROCKET and s.mags[3] + s.reserves[3] == 3)
	s.respawn(from, 0, 0, Gear.sanitize(0, {"ordnance": "rockets", "perks": ["tough", "scavenger"]}, 30))
	_check("ammunition perk does not add a fourth AT rocket", s.mags[3] + s.reserves[3] == 3)
	var foe_pos := from + Vector3(0, 0, -50)
	foe_pos.y = w.map.ground_height(foe_pos.x, foe_pos.z)
	w.on_vehicle(99, 1, foe_pos, PI, 800, 0)
	w.vehicles[99]["home"] = [foe_pos, PI]
	w.vehicles[99]["respawn_at"] = 0.0
	w.vehicles[99]["free_since"] = Net.server_time()
	var foe := w.add_soldier(802, 0, 1, "ArmorTarget")
	foe.respawn(foe_pos, 0, 0)
	foe.set_physics_process(false)
	w.server.enter_vehicle(foe, 99)
	foe.protected_t = 0
	var gunner := w.add_soldier(803, 0, 1, "ArmorGunner")
	gunner.respawn(foe_pos, 0, 0)
	gunner.set_physics_process(false)
	w.server.enter_vehicle(gunner, 99)
	gunner.protected_t = 0
	s.switch_to(3)
	s.switch_t = 0
	await get_tree().physics_frame
	await get_tree().process_frame
	var dir := (foe.global_position + Vector3.UP * 1.3 - s.eye_position()).normalized()
	s.consume_shot()
	w.server.resolve_shot(s, s.eye_position(), dir, Net.server_time())
	_check("rocket damage is not instantaneous", foe.hp == 800 and not w.rockets.is_empty())
	await _until(func() -> bool: return foe.hp < 800, 3)
	_check("swept rocket hits armor after flight", foe.hp == 650)
	_check("rocket removes shared crew armor once", gunner.is_gunner() and gunner.hp == 650)
	var tank_hp: float = C.cls(1, C.VEHICLE_CLASS)["hp"]
	var rocket: float = C.WEAPONS[C.W.AT_ROCKET]["damage"]
	_check("five rockets leave a tank alive, six destroy it", rocket * 5.0 < tank_hp and rocket * 6.0 >= tank_hp)
	var frag := C.GRENADE_DAMAGE * C.GRENADE_VS_ARMOR
	_check("a grenade on the hull hurts, about a third of a rocket", frag >= rocket * 0.25 and frag <= rocket * 0.4)
	var magazine: float = C.WEAPONS[C.W.CARBINE]["damage"] * C.ARMOR_DEFAULT * float(C.WEAPONS[C.W.CARBINE]["mag"])
	_check("a whole rifle magazine barely marks a tank", magazine > 0.0 and magazine < tank_hp * 0.02)
	foe.hp = rocket * 0.5
	gunner.hp = foe.hp
	w.vehicles[99]["hp"] = foe.hp
	s.start_reload()
	s.finish_reload()
	s.fire_cd = 0
	s.consume_shot()
	w.server.resolve_shot(s, s.eye_position(), dir, Net.server_time())
	await _until(func() -> bool: return not foe.alive, 3)
	_check("a last direct AT hit destroys a worn tank", not foe.alive and w.vehicles[99]["hp"] == 0)
	_check("AT destruction eliminates both crew", not gunner.alive and w.vehicles[99]["gunner"] == 0)
	_check("the kit holds one rocket back after two shots", s.mags[3] == 0 and s.reserves[3] == 1)
	for id: int in WeaponFactory.ASSETS:
		var model := WeaponFactory.build(id, 0)
		var muzzle := model.get_node_or_null("Muzzle") as Node3D
		_check("imported %s retains muzzle and geometry" % WeaponFactory.ASSETS[id], muzzle != null and WeaponFactory.bounds(model).get_volume() > .000001)
		model.free()
	var gun := WeaponFactory.build(C.W.CARBINE, 0, ["reddot", "suppressor", "vgrip", "bigcell"])
	_check("imported weapon keeps all four customization anchors", gun.find_child("Part_optic", true, false) != null and gun.find_child("Part_muzzle", true, false) != null and gun.find_child("Part_grip", true, false) != null and gun.find_child("Part_cell", true, false) != null)
	gun.free()
	for id: int in WeaponFactory.ASSETS:
		var theirs := WeaponFactory.build(id, C.Team.EMPIRE, [])
		var ours := WeaponFactory.build(id, C.Team.RESISTANCE, [])
		var muzzle := theirs.get_node_or_null("Muzzle") as Node3D
		_check("Empire %s has a muzzle at the same point" % WeaponFactory.ASSETS[id], muzzle != null and muzzle.position.distance_to((ours.get_node("Muzzle") as Node3D).position) < 0.02)
		_check("Empire %s has its own cell" % WeaponFactory.ASSETS[id], theirs.get_node_or_null("Cell") != null)
		theirs.free()
		ours.free()
	var fitted := WeaponFactory.build(C.W.CARBINE, C.Team.EMPIRE, ["reddot", "suppressor", "vgrip", "bigcell"])
	_check("Empire weapon keeps all four customization anchors", fitted.find_child("Part_optic", true, false) != null and fitted.find_child("Part_muzzle", true, false) != null and fitted.find_child("Part_grip", true, false) != null and fitted.find_child("Part_cell", true, false) != null)
	fitted.free()
	print("[combat-upgrade] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _until(test: Callable, seconds: float) -> void:
	var deadline := Net.server_time() + seconds
	while not test.call() and Net.server_time() < deadline:
		await get_tree().create_timer(.05).timeout

## Every gun needs a stereo take for its shooter and a muffled mono take for everyone else.
func _check_shot_sounds() -> void:
	var missing: Array[String] = []
	var sounds := {"laser_suppressed": true}
	for id: int in C.WEAPONS:
		if not C.WEAPONS[id]["melee"]:
			sounds[C.WEAPONS[id]["sound"]] = true
	for sound: String in sounds:
		for take in range(1, int(Sfx.VARIANTS.get(sound, 0)) + 1):
			var own := load("res://assets/audio/%s%s_%d.wav" % [Sfx.OWN_PREFIX, sound, take]) as AudioStreamWAV
			var far := load("res://assets/audio/%s_%d.wav" % [sound, take]) as AudioStreamWAV
			if own == null or far == null or not own.stereo or far.stereo:
				missing.append("%s_%d" % [sound, take])
	_check("every gun has a close stereo shot and a muffled mono shot %s" % str(missing), missing.is_empty())


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[combat-upgrade] %s %s" % ["PASS" if ok else "FAIL", label])
