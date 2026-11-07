extends Node
## `--test=carrier`, headless: the troop carrier's seats, armour and how its passengers live and die.

var passed := 0
var failed := 0


func _ready() -> void:
	Net.start_dedicated({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 0}, 17871)
	while Net.world == null:
		await get_tree().process_frame
	var w := Net.world
	# These tanks stand in the base, where the safe zone would stop the damage this test is about.
	w.safe_zones.clear()
	var m := w.server
	await get_tree().process_frame
	var carrier := -1
	for id: int in w.vehicles:
		if w.vehicles[id].get("kind", 0) == 1 and w.vehicles[id]["team"] == 0:
			carrier = id
	_check("each side gets a carrier", carrier >= 0)
	if carrier < 0:
		_finish()
		return
	var v: Dictionary = w.vehicles[carrier]
	var hp: float = C.cls(0, C.APC_CLASS)["hp"]
	_check("armoured, but less than a tank", hp > 500.0 and hp < float(C.cls(0, C.VEHICLE_CLASS)["hp"]))
	var men: Array[Soldier] = []
	for i in 2 + C.APC_SEATS:
		var s := w.add_soldier(700 + i, 0, 0, "Pasazer%d" % i)
		s.respawn(v["pos"] + Vector3(2, 0.1, 0), 0, 0)
		s.set_physics_process(false)
		s.protected_t = 0.0
		men.append(s)
	var foe := w.add_soldier(790, 0, 1, "Wrog")
	foe.respawn(v["pos"] + Vector3(0, 0.1, 30), 0, 0)
	foe.set_physics_process(false)
	await get_tree().physics_frame
	_check("the first one in drives", m.enter_vehicle(men[0], carrier) and men[0].vehicle_id == carrier and men[0].is_vehicle())
	_check("driver has no weapon to fire", not men[0].can_fire())
	_check("no second seat at a gun", not m.switch_seat(men[0]))
	for i in range(1, 1 + C.APC_SEATS):
		_check("passenger %d climbs in" % i, m.enter_vehicle(men[i], carrier) and men[i].riding == carrier)
	_check("six passengers fill it", v["riders"].size() == 6)
	_check("one more does not fit", not m.enter_vehicle(men[7], carrier) and men[7].riding == -1)
	var rider := men[1]
	var before := rider.hp
	_check("passengers cannot be shot", w.shares_driver_armor(rider))
	m.explode(1, foe.sid, rider.global_position)
	_check("a blast outside leaves them unhurt", rider.hp == before)
	await get_tree().physics_frame
	rider.set_physics_process(true)
	await get_tree().physics_frame
	var pos: Vector3 = w.ride_position(rider)
	_check("passenger travels with the carrier", rider.global_position.distance_to(pos) < 0.1)
	m.dismount(rider)
	_check("passenger can get out", rider.riding == -1 and rider.alive and not v["riders"].has(rider.sid))
	_check("and gets back in", m.enter_vehicle(rider, carrier) and rider.riding == carrier)
	men[0].protected_t = 0.0
	m.apply_damage(men[0], 99999.0, foe, C.W.AT_ROCKET, false, men[0].global_position)
	_check("destroying it kills the driver", not men[0].alive)
	var dead := 0
	for i in range(1, 1 + C.APC_SEATS):
		dead += 0 if men[i].alive else 1
	_check("and everyone inside", dead == C.APC_SEATS)
	_check("seats are empty afterwards", v["riders"].is_empty() and float(v["hp"]) == 0.0)
	_finish()


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[carrier] %s %s" % ["PASS" if ok else "FAIL", label])


func _finish() -> void:
	print("[carrier] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
