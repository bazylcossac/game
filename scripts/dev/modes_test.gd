extends Node
## `--test=modes`, headless: walks every map for reachability, plays every mode and map to a
## win with bots at a short limit, then checks friend and foe, and how a match ends.
## `--only=<word>` runs just the parts whose name contains that word.

const SPEED := 3.0
const PLAY_TIMEOUT := 170.0
## Steepest slope a soldier or tank can drive up is 52 degrees: rise over one 2 m grid step.
const MAX_STEP := 2.2

## Every mode on every map it offers, with a limit short enough to finish.
const MATCHES := [
	["podboj", "stare_miasto", 40],
	["pvp", "rynek", 25],
	["pvp", "pole_bitwy", 12],
	["deathmatch", "rynek", 8],
	["czolgi", "dolina_pancerna", 14],
	["pvp", "neonowa_dzielnica", 12],
	["deathmatch", "neonowa_dzielnica", 8],
	["podboj", "neonowa_dzielnica", 30],
	["pvp", "stacja_rdzen", 12],
	["deathmatch", "stacja_rdzen", 8],
	["podboj", "stacja_rdzen", 30],
	["podboj", "ziemia_niczyja", 30],
	["pvp", "ziemia_niczyja", 12],
	["czolgi", "ziemia_niczyja", 14],
]

var _passed := 0
var _failed := 0
var _port := int(Settings.arg("port", "7830"))


func _ready() -> void:
	Engine.time_scale = SPEED
	for part: Array in [["mapy", _maps], ["mecze", _matches], ["strony", _sides], ["czolgi", _tanks], ["tablica", _table]]:
		if String(part[0]).contains(Settings.arg("only", String(part[0]))):
			print("[modes] --- %s" % part[0])
			await part[1].call()
	Engine.time_scale = 1.0
	print("[modes] PASS %d, FAIL %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[modes] %s %s" % ["PASS" if ok else "FAIL", label])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Waits in game time until `done` says so, and tells whether it did before `limit` ran out.
func _until(done: Callable, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		if done.call():
			return true
		await _wait(0.1)
		t += 0.1
	return done.call()


## Offline means a local player exists, so the HUD and the events run too.
func _start(cfg: Dictionary, offline := false) -> World:
	_port += 1
	var full := Modes.normalize(cfg)
	if offline:
		Net.start_offline(full)
	else:
		Net.start_dedicated(full, _port)
	while Net.world == null or (offline and Net.world.local == null):
		await get_tree().process_frame
	# Physics space receives newly attached static bodies on the next physics tick.
	await get_tree().physics_frame
	await get_tree().process_frame
	return Net.world


func _stop() -> void:
	get_tree().current_scene.call("_close_world")
	await get_tree().process_frame
	Net.leave()
	await get_tree().process_frame
	await get_tree().process_frame


# ---------------------------------------------------------------- maps

func _maps() -> void:
	for pair: Array in [["pvp", "rynek"], ["czolgi", "dolina_pancerna"], ["pvp", "neonowa_dzielnica"], ["pvp", "stacja_rdzen"]]:
		var w: World = await _start({"mode": pair[0], "map": pair[1], "bots_per_team": 2})
		_check_reach(w, pair[1])
		await _stop()


func _check_reach(w: World, id: String) -> void:
	var map := w.map
	var nav := map.b.nav
	var from: Vector3 = map.bases()[0]
	var points: Array[Vector3] = []
	points.append(map.bases()[1])
	for list: Array in [map.team_spawns(0), map.team_spawns(1), map.free_spawns(), map.hotspots()]:
		points.append_array(list)
	for f: Dictionary in map.flag_defs():
		points.append(f["pos"])
	var bad := 0
	for p: Vector3 in points:
		if not nav.is_free(nav.cell_of(p)):
			bad += 1
			print("[modes] %s: %s stoi w ścianie" % [id, p])
		elif not nav.can_reach(from, p):
			bad += 1
			print("[modes] %s: nie da się dojść do %s" % [id, p])
	_check("%s: %d punktów osiągalnych pieszo" % [id, points.size()], bad == 0)
	var wide := 0
	for p: Vector3 in map.hotspots():
		if not map.b.nav_wide.can_reach(from, p) and map.b.nav.is_free(map.b.nav.cell_of(p)):
			wide += 1
	print("[modes] %s: miejsca poza zasięgiem mecha: %d z %d" % [id, wide, map.hotspots().size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var coin_bad := 0
	for i in 200:
		var p := map.random_coin_point(rng)
		if not nav.is_free(nav.cell_of(p)) or not nav.can_reach(from, p):
			coin_bad += 1
	_check("%s: monety spadają w osiągalnych miejscach" % id, coin_bad == 0)
	_check("%s: mieści się w siatce nawigacji" % id, map.bound().x < NavGrid.HALF * nav.cell_metres and map.bound().y < NavGrid.HALF * nav.cell_metres)
	var steep := 0
	var half := map.bound()
	var x := -half.x
	while x < half.x:
		var z := -half.y
		while z < half.y:
			if absf(map.ground_height(x + 2.0, z) - map.ground_height(x, z)) > MAX_STEP or absf(map.ground_height(x, z + 2.0) - map.ground_height(x, z)) > MAX_STEP:
				steep += 1
			z += 2.0
		x += 2.0
	_check("%s: nie ma zboczy nie do podjechania (%d)" % [id, steep], steep == 0)
	if id == "pole_bitwy":
		_check_tank_routes(w)


func _route_length(nav: NavGrid, a: Vector3, b: Vector3) -> float:
	var path := nav.find_path(a, b)
	if path.is_empty():
		return 0.0
	var total := Vector2(a.x, a.z).distance_to(Vector2(path[0].x, path[0].z))
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total


func _check_tank_routes(w: World) -> void:
	var nav := w.map.b.nav_tank
	var bad := 0
	for team in 2:
		for spot: Array in w.map.tank_depots()[team]:
			if not nav.is_free(nav.cell_of(spot[0])):
				bad += 1
				print("[modes] czołg stoi w przeszkodzie: %s" % spot[0])
			for f: Dictionary in w.flags:
				var path := nav.find_path(spot[0], f["pos"])
				var end: Vector3 = path[path.size() - 1] if path.size() > 0 else spot[0]
				if Vector2(end.x - f["pos"].x, end.z - f["pos"].z).length() > C.FLAG_RADIUS:
					bad += 1
					print("[modes] czołg nie dojeżdża do flagi %s" % f["name"])
	_check("pole_bitwy: czołgi dojeżdżają do wszystkich flag", bad == 0)


# ---------------------------------------------------------------- full matches

func _matches() -> void:
	for index in range(int(Settings.arg("from-match", "0")), MATCHES.size()):
		var spec: Array = MATCHES[index]
		if Settings.has_arg("match-mode") and spec[0] != Settings.arg("match-mode"):
			continue
		await _play(spec[0], spec[1], spec[2])


func _play(mode: String, map: String, limit: int) -> void:
	var w: World = await _start({"mode": mode, "map": map, "limit": limit, "prep_time": 2.0, "round_end_time": 1.0})
	var label := "%s na %s" % [mode, map]
	print("[modes] %s: %d żołnierzy" % [label, w.soldiers.size()])
	var t0 := Time.get_ticks_msec()
	var sunk := 0
	var stuck := 0
	while not w.server.round_over and (Time.get_ticks_msec() - t0) / 1000.0 * SPEED < PLAY_TIMEOUT * SPEED:
		await _wait(3.0)
		for s: Soldier in w.soldiers.values():
			if s.alive and s.global_position.y < w.map.ground_height(s.global_position.x, s.global_position.z) - 1.0:
				sunk += 1
				print("[modes] pod ziemią: %s, klasa %d, pozycja %s, grunt %.2f, w pojeździe %d" % [s.name, s.class_id, s.global_position, w.map.ground_height(s.global_position.x, s.global_position.z), s.vehicle_id])
	var kills := 0
	for s: Soldier in w.soldiers.values():
		kills += s.kills
	print("[modes] %s: %.0f s gry, wynik %s, eliminacje %d" % [label, (Time.get_ticks_msec() - t0) / 1000.0 * SPEED, str(w.tickets), kills])
	_check("%s: mecz dobiegł końca" % label, w.server.round_over)
	_check("%s: nikt nie wpadł pod ziemię (%d)" % [label, sunk], sunk == 0)
	match String(w.mode["rules"]):
		"kills":
			if w.ffa:
				var best := 0
				for s: Soldier in w.soldiers.values():
					best = maxi(best, s.kills)
				_check("%s: zwycięzca ma limit eliminacji" % label, best >= limit)
			else:
				_check("%s: drużyna ma limit eliminacji" % label, w.tickets.max() >= limit)
		_:
			_check("%s: jedna ze stron straciła tickety" % label, w.tickets.min() <= 0)
	await _stop()


# ---------------------------------------------------------------- sides

## Stands `b` right in front of `a` and has `a` fire at it.
func _shoot(w: World, a: Soldier, b: Soldier) -> float:
	a.teleport(Vector3(0, 0.1, 40))
	a.yaw = 0.0
	a.pitch = 0.0
	b.teleport(Vector3(0, 0.1, 37))
	b.protected_t = 0.0
	b.hp = b.max_hp
	await get_tree().physics_frame
	var before := b.hp
	var dir := (b.global_position + Vector3.UP - a.eye_position()).normalized()
	w.server.resolve_shot(a, a.eye_position(), dir, Net.server_time())
	return before - b.hp


func _bot_of(w: World, team: int, skip: Soldier = null) -> Soldier:
	for brain: BotBrain in w.server.bots:
		if brain.s.team == team and brain.s != skip:
			return brain.s
	return null


func _spawn_all(w: World) -> void:
	for brain: BotBrain in w.server.bots:
		if not brain.s.alive:
			w.server.spawn(brain.s, 0, -1)
	await get_tree().physics_frame


func _sides() -> void:
	# Free-for-all: one human among bots, and nobody is on anybody's side.
	var w: World = await _start({"mode": "deathmatch", "map": "rynek", "bots_per_team": 8, "difficulty": 0}, true)
	_check("deathmatch: osiem osób na mapie", w.soldiers.size() == 8)
	var everyone_blue := true
	for s: Soldier in w.soldiers.values():
		everyone_blue = everyone_blue and s.team == C.Team.RESISTANCE
	_check("deathmatch: nikt nie wygląda jak droid Imperium", everyone_blue)
	_check("deathmatch: gracz jest po stronie ruchu oporu", w.local.team == C.Team.RESISTANCE)
	Net.send_deploy(0, -1, {})
	await _spawn_all(w)
	_check("deathmatch: gracz wszedł do walki", w.local.alive)
	var a := _bot_of(w, 0)
	var b := _bot_of(w, 0, a)
	_check("deathmatch: bot jest wrogiem bota", w.are_foes(a, b))
	_check("deathmatch: nikt nie jest wrogiem samego siebie", not w.are_foes(a, a))
	_check("deathmatch: strzał rani każdego", await _shoot(w, a, b) > 0.0)
	_check("deathmatch: strzał rani gracza", await _shoot(w, a, w.local) > 0.0)
	b.teleport(Vector3(0, 0.1, 37))
	b.protected_t = 0.0
	b.hp = b.max_hp
	a.protected_t = 0.0
	a.hp = a.max_hp
	await get_tree().physics_frame
	w.server.explode(9001, a.sid, b.global_position + Vector3(0, 1, 0.5))
	_check("deathmatch: granat rani innych", b.hp < b.max_hp)
	# A medic must not patch up the people he is fighting.
	var medic := a
	medic.teleport(Vector3(0, 0.1, 40))
	w.server.spawn(medic, 1, -1)
	medic.teleport(Vector3(0, 0.1, 40))
	var patient := b
	patient.teleport(Vector3(1, 0.1, 40))
	patient.hp = 40.0
	patient.last_damage_time = Net.server_time()
	w.server.call("_heal_around", medic, 1.0)
	_check("deathmatch: sanitariusz nie leczy wrogów", patient.hp == 40.0)
	medic.hp = 40.0
	w.server.call("_heal_around", medic, 1.0)
	_check("deathmatch: sanitariusz leczy siebie", medic.hp > 40.0)
	var board := Overlays.ranking(w)
	_check("deathmatch: tablica wyników to jedna lista", board != null)
	board.free()
	_check("deathmatch: kolor wroga to nie kolor drużyny", w.side_color(a) == UiKit.RED and w.side_color(w.local) == UiKit.BRASS)
	await _stop()
	# Teams: a human against Empire bots, with friendly fire off.
	w = await _start({"mode": "pvp", "map": "rynek", "bots_per_team": 3, "difficulty": 0}, true)
	_check("pvp: gracz jest po stronie ruchu oporu", w.local.team == C.Team.RESISTANCE)
	var counts := [0, 0]
	for s: Soldier in w.soldiers.values():
		counts[s.team] += 1
	_check("pvp: drużyny po trzech %s" % str(counts), counts == [3, 3])
	var bots_of_empire := true
	for s: Soldier in w.soldiers.values():
		if s.team == C.Team.EMPIRE:
			bots_of_empire = bots_of_empire and s.peer == 0
	_check("pvp: domyślnie Imperium to boty", bots_of_empire)
	Net.send_deploy(0, -1, {})
	await _spawn_all(w)
	var mate := _bot_of(w, 0)
	var foe := _bot_of(w, 1)
	_check("pvp: strzał w swojego nie rani", await _shoot(w, w.local, mate) == 0.0)
	_check("pvp: strzał we wroga rani", await _shoot(w, w.local, foe) > 0.0)
	var score := w.tickets.duplicate()
	mate.protected_t = 0.0
	w.server.apply_damage(mate, 9999.0, mate, -1, false, mate.global_position)
	_check("pvp: samobójstwo nie daje punktu %s" % str(w.tickets), w.tickets == score)
	foe.protected_t = 0.0
	w.server.apply_damage(foe, 9999.0, w.local, C.W.CARBINE, false, w.local.global_position)
	_check("pvp: eliminacja daje punkt drużynie %s" % str(w.tickets), w.tickets[0] == score[0] + 1)
	await _stop()


# ---------------------------------------------------------------- tanks

func _tanks() -> void:
	var w: World = await _start({"mode": "czolgi", "map": "pole_bitwy", "bots_per_team": 6, "difficulty": 0}, true)
	_check("czołgi: trzy flagi", w.flags.size() == 3)
	Net.send_deploy(0, -1, {})
	await _wait(0.3)
	var s := w.local
	_check("czołgi: gracz zaczyna w czołgu", s.alive and s.is_vehicle())
	_check("czołgi: tickety z limitu trybu", w.tickets[0] == w.score_limit)
	Net.send_use()
	await _wait(0.2)
	_check("czołgi: nie da się wysiąść", s.is_vehicle())
	await _until(func() -> bool: return _crews(w) >= 12, 12.0)
	_check("czołgi: każdy bot też (%d załóg)" % _crews(w), _crews(w) == 12)
	_check("czołgi: najwyżej sześć na stronę", w.soldiers.size() == 12)
	var used: int = w.tickets[0]
	s.protected_t = 0.0
	w.server.apply_damage(s, 9999.0, null, -1, false, s.global_position)
	_check("czołgi: w strefie bezpiecznej bazy czołg jest nietykalny", s.alive and w.tickets[0] == used)
	s.global_position = w.flags[1]["pos"] + Vector3(0, 0.3, 0)
	w.server.apply_damage(s, 9999.0, null, -1, false, s.global_position)
	_check("czołgi: zniszczenie kosztuje ticket", w.tickets[0] <= used - 1)
	_check("czołgi: załoga ginie z czołgiem", not s.alive)
	await _until(func() -> bool: return Net.server_time() - s.death_time > C.RESPAWN_DELAY, 10.0)
	await get_tree().create_timer(C.RESPAWN_DELAY * SPEED + 0.5).timeout
	Net.send_deploy(0, -1, {})
	await _wait(0.3)
	_check("czołgi: gracz wraca w czołgu", s.alive and s.is_vehicle())
	# Holding two flags of three must drain the enemy, as the mode promises.
	w.flags[0]["owner"] = 0
	w.flags[1]["owner"] = 0
	w.flags[0]["value"] = -1.0
	w.flags[1]["value"] = -1.0
	var enemy_before: int = w.tickets[1]
	await _wait(8.0)
	_check("czołgi: dwie flagi z trzech zabierają tickety (%d -> %d)" % [enemy_before, w.tickets[1]], w.tickets[1] < enemy_before)
	await _stop()


func _crews(w: World) -> int:
	var n := 0
	for s: Soldier in w.soldiers.values():
		if s.alive and s.is_vehicle():
			n += 1
	return n



# ---------------------------------------------------------------- menus and arguments

func _table() -> void:
	_check("domyślnie Podbój na Neonowej Dzielnicy", Modes.normalize({})["mode"] == "podboj" and Modes.normalize({})["map"] == "neonowa_dzielnica")
	_check("zła mapa wraca do domyślnej", Modes.normalize({"mode": "czolgi", "map": "rynek"})["map"] == "dolina_pancerna")
	_check("zły tryb wraca do Podboju", Modes.normalize({"mode": "xyz"})["mode"] == "podboj")
	_check("czołgi najwyżej 6 na stronę", Modes.normalize({"mode": "czolgi", "bots_per_team": 12})["bots_per_team"] == 6)
	_check("podbój bez zmian: 12 botów, 350 ticketów", Modes.normalize({"bots_per_team": 12})["bots_per_team"] == 12 and Modes.score_limit({}) == C.START_TICKETS)
	_check("limity z zadania", Modes.LIST["pvp"]["limit"] == 75 and Modes.LIST["deathmatch"]["limit"] == 30)
	for id: String in Modes.LIST:
		var ok: bool = not Modes.LIST[id]["maps"].is_empty()
		for map: String in Modes.LIST[id]["maps"]:
			ok = ok and Modes.has_map(map)
		_check("tryb %s ma mapy z tabeli" % id, ok)
