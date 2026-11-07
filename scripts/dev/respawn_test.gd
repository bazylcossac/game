extends Node
## `--test=respawn`, headless: giving up a life from the pause menu, on foot and in vehicles.
var passed := 0
var failed := 0


func _ready() -> void:
	Net.start_offline({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	var m := w.server
	var me := w.local
	var peer := multiplayer.get_unique_id()
	var v: Dictionary = w.vehicles[1]
	var mate := _person(w, 501, me.team, v["pos"] + Vector3(4, 0.1, 0))

	m.spawn(me, 0, -1)
	await get_tree().physics_frame
	var tickets: int = w.tickets[me.team]
	var bystander_kills := mate.kills
	me.protected_t = 5.0
	Net.send_respawn()
	_check("spawn protection does not stop it", not me.alive and w.controller.state == PlayerController.State.DEAD)
	_check("one death, no kill for anyone", me.deaths == 1 and me.kills == 0 and mate.kills == bystander_kills)
	_check("a ticket is lost", w.tickets[me.team] == tickets - 1)
	Net.send_respawn()
	_check("a second press while dead changes nothing", me.deaths == 1 and w.tickets[me.team] == tickets - 1)
	m.sv_deploy(peer, 0, -1, {})
	_check("deploying straight away still has to wait", not me.alive)

	me.global_position = v["pos"] + Vector3(-4, 0.1, 0)
	m.spawn(me, 2, -1)
	me.global_position = v["pos"] + Vector3(-4, 0.1, 0)
	_check("driver gets in", m.enter_vehicle(mate, 1))
	_check("the player takes the gun", m.enter_vehicle(me, 1) and me.is_gunner())
	var hull := float(v["hp"])
	Net.send_respawn()
	_check("the gunner leaves the tank and dies", not me.alive and me.vehicle_id == -1 and v["gunner"] == 0)
	_check("the tank and its driver are fine", mate.alive and float(v["hp"]) == hull and v["driver"] == mate.sid)

	m.spawn(me, 0, -1)
	me.global_position = v["pos"] + Vector3(-4, 0.1, 0)
	m.exit_vehicle(mate)
	_check("the player takes the wheel", m.enter_vehicle(me, 1) and v["driver"] == me.sid)
	Net.send_respawn()
	_check("the driver leaves the tank whole", not me.alive and float(v["hp"]) > 0.0 and v["driver"] == 0)

	m.spawn(me, 0, -1)
	me.global_position = v["pos"] + Vector3(-4, 0.1, 0)
	_check("mate drives", m.enter_vehicle(mate, 1))
	var other := _person(w, 502, me.team, v["pos"] + Vector3(0, 0.1, 5))
	_check("other takes the gun", m.enter_vehicle(other, 1))
	_check("the player rides along", m.enter_vehicle(me, 1) and me.riding == 1)
	Net.send_respawn()
	_check("a passenger gets off and dies", not me.alive and me.riding == -1 and not (v["riders"] as Array).has(me.sid))
	_check("the crew stays", mate.alive and other.alive)

	m.spawn(me, 0, -1)
	m.end_match(0)
	var deaths := me.deaths
	Net.send_respawn()
	_check("no respawn once the match is over", me.alive and me.deaths == deaths)

	print("[respawn] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _person(w: World, sid: int, team: int, pos: Vector3) -> Soldier:
	var s := w.add_soldier(sid, 0, team, "Testowy %d" % sid)
	s.respawn(pos, 0.0, 0)
	s.protected_t = 0.0
	return s


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[respawn] %s %s" % ["PASS" if ok else "FAIL", label])
