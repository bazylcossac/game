extends Node
## `--test=squads`, headless: real server rules for squads, the leader's class, artillery and
## the spawn beacon. Bots are switched off, so every number below comes from these actions.
var passed := 0
var failed := 0
var w: World
var m: MatchServer


func _ready() -> void:
	Net.start_dedicated({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 0}, 17863)
	while Net.world == null:
		await get_tree().process_frame
	w = Net.world
	m = w.server
	await get_tree().physics_frame
	await get_tree().process_frame
	var spot := _open_ground()
	var lead := _person(701, 0, spot)
	var mate := _person(702, 0, spot + Vector3(3, 0, 0))
	var third := _person(703, 0, spot + Vector3(-3, 0, 0))
	var foe := _person(704, 1, spot + Vector3(0, 0, 40))
	_membership(lead, mate, third, foe)
	_leader_class(lead, mate)
	_artillery(lead, mate, foe, spot)
	await _barrage(lead, mate, foe, spot)
	await _beacon(lead, mate, foe, spot)
	_promotion(lead, mate, third)
	print("[squads] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _membership(lead: Soldier, mate: Soldier, third: Soldier, foe: Soldier) -> void:
	var q := w.squads
	_check("creator leads the new squad", q.create(lead) and q.leads(lead))
	var id: int = q.squad_of(lead.sid)["id"]
	_check("teammate joins", q.join(mate, id) and q.same_squad(lead, mate) and not q.leads(mate))
	_check("enemy cannot join", not q.join(foe, id))
	q.join(third, id)
	var a := _person(711, 0, lead.global_position + Vector3(6, 0, 0))
	q.join(a, id)
	var b := _person(712, 0, lead.global_position + Vector3(-6, 0, 0))
	_check("squad holds four at most", not q.join(b, id) and (q.squad_of(lead.sid)["members"] as Array).size() == Squads.MAX_MEMBERS)
	q.leave(a)
	q.leave(third)


func _leader_class(lead: Soldier, mate: Soldier) -> void:
	var at := lead.global_position
	for s: Soldier in [lead, mate]:
		s.alive = false
		s.death_time = -100.0
		s.peer = s.sid
	m.sv_deploy(lead.sid, 0, -1, {})
	_check("leader asking for a rifleman still deploys as commander", lead.class_id == C.COMMAND_CLASS and lead.class_data().get("command", false))
	m.sv_deploy(mate.sid, C.COMMAND_CLASS, -1, {})
	_check("member cannot take the commander class", mate.class_id == 0)
	_check("commander keeps a normal kit, not a super class", not lead.is_super() and lead.loadout[0] == C.W.CARBINE)
	_check("commander carries one grenade", lead.grenades == 1)
	lead.teleport(at)
	mate.teleport(at + Vector3(3, 0, 0))
	lead.peer = 0
	mate.peer = 0
	lead.protected_t = 0
	mate.protected_t = 0
	lead.set_physics_process(false)
	mate.set_physics_process(false)


func _artillery(lead: Soldier, mate: Soldier, foe: Soldier, spot: Vector3) -> void:
	var q := w.squads
	var squad: Dictionary = q.squad_of(lead.sid)
	var target := spot + Vector3(0, 0, 40)
	_check("no strike during the opening delay", q.strike_problem(lead, target).begins_with("Artyleria gotowa za"))
	squad["next_strike"] = 0.0
	_check("no strike without a full charge", q.strike_problem(lead, target).begins_with("Artyleria naładowana"))
	var before := float(squad["charge"])
	q.on_kill(mate)
	_check("a squad kill feeds the charge", is_equal_approx(float(squad["charge"]) - before, C.STRIKE_KILL_CHARGE))
	squad["charge"] = 0.0
	q.tick(1.0)
	var pair_rate := float(squad["charge"])
	_check("a bigger squad charges faster than a lone leader", pair_rate > 100.0 / C.STRIKE_CHARGE_SECONDS)
	squad["charge"] = 100.0
	_check("member cannot call it", q.strike_problem(mate, target) != "")
	_check("target too far is refused", q.strike_problem(lead, spot + Vector3(0, 0, C.STRIKE_RANGE + 40)) != "")
	_check("target at the leader's feet is refused", q.strike_problem(lead, spot + Vector3(2, 0, 0)) != "")
	var enemy_base: Vector3 = w.map.bases()[1]
	lead.teleport(enemy_base + Vector3(0, 0, 100))
	_check("enemy base is protected", q.strike_problem(lead, enemy_base).find("chroniona") >= 0)
	lead.teleport(spot)


func _barrage(lead: Soldier, mate: Soldier, foe: Soldier, spot: Vector3) -> void:
	var q := w.squads
	var squad: Dictionary = q.squad_of(lead.sid)
	var target := spot + Vector3(0, 0, 40)
	target.y = w.map.ground_height(target.x, target.z)
	foe.teleport(target + Vector3.UP * 0.1)
	foe.protected_t = 0
	foe.set_physics_process(false)
	mate.teleport(target + Vector3(2, 0.1, 0))
	var friend_hp := mate.hp
	# Scatter is random and can miss one soldier, so a fixed seed and a spread of targets test it.
	q._rng.seed = 12
	var targets: Array[Soldier] = [foe]
	for i in 6:
		var a := TAU * i / 6.0
		var t := _person(720 + i, 1, target + Vector3(cos(a), 0, sin(a)) * 7.0)
		targets.append(t)
	squad["charge"] = 100.0
	_check("target passes every rule (%s)" % q.strike_problem(lead, target), q.strike_problem(lead, target) == "")
	_check("leader has eyes on the target", q._sees(lead, target))
	_check("full charge calls the strike", q.request_strike(lead, target))
	_check("calling spends the charge and starts the cooldown", float(squad["charge"]) == 0.0 and float(squad["next_strike"]) > Net.server_time() + C.STRIKE_COOLDOWN - 2)
	_check("the barrage has six shells in the air", q.shells.size() == C.STRIKE_SHELLS)
	_check("nothing lands during the warning", foe.hp == foe.max_hp)
	var early := Net.server_time() + C.STRIKE_WARNING - 0.4
	while Net.server_time() < early:
		await get_tree().physics_frame
	_check("the warning runs its full time", foe.alive and foe.hp == foe.max_hp)
	var end := Net.server_time() + 0.4 + C.STRIKE_SHELLS * C.STRIKE_INTERVAL + 0.3
	while Net.server_time() < end:
		await get_tree().physics_frame
	_check("all shells landed", q.shells.is_empty())
	var hurt := 0
	for t: Soldier in targets:
		hurt += 1 if t.hp < t.max_hp or not t.alive else 0
	_check("shells hurt enemies in the zone (%d of %d)" % [hurt, targets.size()], hurt > 0)
	for t: Soldier in targets:
		if t != foe:
			w.remove_soldier(t.sid)
	_check("shells spare friends", mate.hp == friend_hp)


func _beacon(lead: Soldier, mate: Soldier, foe: Soldier, spot: Vector3) -> void:
	var q := w.squads
	var squad: Dictionary = q.squad_of(lead.sid)
	foe.alive = true
	foe.teleport(spot + Vector3(0, 0, 9))
	lead.teleport(spot + Vector3(0, 0.05, 0))
	lead.yaw = 0
	await get_tree().physics_frame
	var pos := q.beacon_spot(lead)
	_check("no beacon with an enemy nearby", q.beacon_problem(lead, pos).find("Wróg") >= 0)
	foe.teleport(spot + Vector3(0, 0, 60))
	var problem := q.beacon_problem(lead, pos)
	_check("beacon allowed on open ground (%s)" % problem, problem == "")
	_check("member cannot place it", q.beacon_problem(mate, pos) != "")
	_check("leader places it", q.place_beacon(lead) and q.beacon_pos(squad) != null)
	var first: int = squad["beacon"]
	_check("a new beacon must wait", not q.place_beacon(lead))
	squad["beacon_ready"] = 0.0
	lead.teleport(spot + Vector3(6, 0.05, 0))
	_check("placing again moves the one beacon", q.place_beacon(lead) and int(squad["beacon"]) != first and not w.forts.items.has(first))
	_check("beacon is open to the squad", q.spawn_problem(mate) == "")
	mate.alive = false
	mate.death_time = -100.0
	mate.peer = mate.sid
	var near: Vector3 = q.beacon_pos(squad)
	m.sv_deploy(mate.sid, 0, C.SPAWN_BEACON, {})
	mate.peer = 0
	_check("member comes in at the beacon", mate.alive and mate.global_position.distance_to(near) < 5.0)
	_check("spawns at a beacon are spaced out", q.spawn_problem(lead).find("gotowy") >= 0)
	squad["beacon_lock"] = 0.0
	foe.teleport(near + Vector3(5, 0, 0))
	_check("an enemy at the beacon shuts it down", q.spawn_problem(mate).find("ostrzałem") >= 0)
	var id: int = squad["beacon"]
	var score := foe.score
	w.forts.damage(id, C.BEACON_HP + 1.0, foe, false)
	_check("enemy fire destroys it and is rewarded", not w.forts.items.has(id) and int(squad["beacon"]) == 0 and foe.score > score)
	_check("a lost beacon takes a while to replace", q.beacon_problem(lead, pos).begins_with("Nowy punkt"))


func _promotion(lead: Soldier, mate: Soldier, third: Soldier) -> void:
	var q := w.squads
	var id: int = q.squad_of(lead.sid)["id"]
	q.leave(lead)
	_check("the next member takes command", q.leads(mate) and q.squad_of(lead.sid).is_empty())
	q.leave(mate)
	_check("the last one out closes the squad", not q.list.has(id))


func _open_ground() -> Vector3:
	var flag: Dictionary = w.flags[w.flags.size() / 2]
	for r: float in [50.0, 70.0, 90.0, 40.0]:
		for i in 16:
			var a := TAU * i / 16.0
			var p: Vector3 = flag["pos"] + Vector3(cos(a), 0, sin(a)) * r
			p.y = w.map.ground_height(p.x, p.z)
			var far: Vector3 = p + Vector3(0, 0, 40)
			far.y = w.map.ground_height(far.x, far.z)
			var clear: bool = w.server.world_ray(p + Vector3.UP * 1.6, far + Vector3.UP * 0.4).is_empty()
			var bases: Array = w.map.bases()
			if clear and w.server.world_ray(far + Vector3.UP * 0.6, far + Vector3.UP * 90).is_empty() and (bases[1] as Vector3).distance_to(p) > 120.0 and (bases[1] as Vector3).distance_to(far) > 120.0:
				return p
	return flag["pos"]


func _person(sid: int, team: int, pos: Vector3) -> Soldier:
	var s := w.add_soldier(sid, 0, team, "Tester%d" % sid)
	s.respawn(pos + Vector3.UP * 0.1, 0, 0)
	s.protected_t = 0
	s.set_physics_process(false)
	return s


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[squads] %s %s" % ["PASS" if ok else "FAIL", label])
