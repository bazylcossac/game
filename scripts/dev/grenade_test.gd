extends Node
## `--test=grenades`, headless: the reload rule, class counts, smoke and fire on the real server.
var passed := 0
var failed := 0
var w: World
var m: MatchServer


func _ready() -> void:
	Net.start_dedicated({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 0}, 17865)
	while Net.world == null:
		await get_tree().process_frame
	w = Net.world
	m = w.server
	await get_tree().physics_frame
	await get_tree().process_frame
	var spot: Vector3 = w.flags[0]["pos"] + Vector3(0, 0.1, 0)
	_counts()
	_reload_rule(spot)
	await _smoke(spot)
	await _fire(spot)
	await _impact(spot)
	print("[grenades] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _counts() -> void:
	var table := {
		0: [[3, 1, 0], [1, 2, 0], [1, 1, 0], [1, 0, 2], [1, 2, 0]],
		1: [[2, 1, 1], [1, 1, 0], [1, 0, 1], [1, 2, 0], [1, 2, 0]],
	}
	for team: int in table:
		for class_id in table[team].size():
			var s := _person(800 + team * 10 + class_id, team, Vector3(0, 40, 0), class_id)
			var want: Array = table[team][class_id]
			_check("%s carries %s" % [C.cls(team, class_id)["id"], str(want)], s.nades == want)
			w.remove_soldier(s.sid)
	var rockets := _person(830, 0, Vector3(0, 40, 0), 0, Gear.sanitize(0, {"ordnance": "rockets"}, 1))
	_check("rocket assault keeps the smoke but no frags", rockets.nades == [0, 1, 0])
	w.remove_soldier(rockets.sid)


func _reload_rule(spot: Vector3) -> void:
	var s := _person(840, 0, spot, 0)
	_check("a ready soldier can throw", s.can_throw())
	s.mags[0] = 0
	s.start_reload()
	_check("no throw while reloading", s.reload_t > 0.0 and not s.can_throw())
	s.peer = 840
	s.control = Soldier.Driver.PROXY_SERVER
	var before: Array = s.nades.duplicate()
	m.sv_grenade(840, s.eye_position(), Vector3.FORWARD, C.NADE_FRAG)
	_check("the server refuses a throw during a reload", s.nades == before and w._grenades.is_empty())
	s.reload_t = 0.0
	m.sv_grenade(840, s.eye_position(), Vector3.FORWARD, C.NADE_FIRE)
	_check("the server refuses a kind the soldier does not carry", s.nades == before)
	s.grenade_cd = 0.0
	m.sv_grenade(840, s.eye_position(), Vector3.FORWARD, C.NADE_SMOKE)
	_check("a carried kind is spent once", s.nades[C.NADE_SMOKE] == before[C.NADE_SMOKE] - 1)
	s.pick_next_nade()
	_check("H skips kinds with none left", s.nades[s.nade_kind] > 0)
	s.control = Soldier.Driver.BOT
	s.peer = 0
	w.remove_soldier(s.sid)


func _smoke(spot: Vector3) -> void:
	var q := w.areas
	var a := spot + Vector3(-10, 1.5, 0)
	var b := spot + Vector3(10, 1.5, 0)
	_check("clear air blocks nothing", not q.blocks_sight(a, b))
	q.start(C.NADE_SMOKE, spot, null, 0)
	_check("a cloud blocks the line through it", q.blocks_sight(a, b))
	_check("a cloud leaves other lines alone", not q.blocks_sight(a + Vector3(0, 0, 30), b + Vector3(0, 0, 30)))
	var watcher := _person(850, 0, a - Vector3(0, 1.5, 0), 0)
	var target := _person(851, 1, b - Vector3(0, 1.5, 0), 0)
	var brain := BotBrain.new()
	brain.setup(watcher, m, C.DIFFICULTIES[1])
	_check("a bot cannot see through smoke", not brain._can_see(target))
	q.items.clear()
	w.remove_soldier(watcher.sid)
	w.remove_soldier(target.sid)


func _fire(spot: Vector3) -> void:
	var q := w.areas
	var owner := _person(860, 0, spot + Vector3(30, 0, 0), 0)
	var foe := _person(861, 1, spot + Vector3(1.5, 0, 0), 0)
	var friend := _person(862, 0, spot + Vector3(-1.5, 0, 0), 0)
	var outside := _person(863, 1, spot + Vector3(0, 0, C.FIRE_RADIUS + 3.0), 0)
	var score := owner.score
	q.start(C.NADE_FIRE, spot, owner, 0)
	await get_tree().create_timer(1.3).timeout
	var after_second := foe.hp
	_check("fire burns an enemy standing in it (%d hp)" % foe.hp, foe.hp < foe.max_hp)
	_check("fire does not kill instantly", foe.alive and foe.hp > foe.max_hp * 0.4)
	_check("fire spares friends", friend.hp == friend.max_hp)
	_check("fire stays in its area", outside.hp == outside.max_hp)
	foe.teleport(spot + Vector3(0, 0.1, 20))
	await get_tree().create_timer(0.8).timeout
	_check("leaving the fire stops the burn", foe.hp == after_second)
	foe.teleport(spot + Vector3(1.5, 0.1, 0))
	await get_tree().create_timer(C.FIRE_SECONDS).timeout
	_check("staying in it is deadly", not foe.alive and owner.score > score)
	var burning := 0
	for item: Dictionary in q.items.values():
		burning += 1 if item["kind"] == C.NADE_FIRE else 0
	_check("fire burns out", burning == 0)
	for s: Soldier in [owner, friend, outside]:
		w.remove_soldier(s.sid)
	w.remove_soldier(foe.sid)


func _impact(spot: Vector3) -> void:
	var s := _person(870, 0, spot + Vector3(0, 6, 0), 0)
	m.throw_grenade(s, spot + Vector3(0, 3, 0), Vector3.DOWN, C.NADE_FIRE)
	await get_tree().create_timer(0.9).timeout
	var fires: Array = w.areas.items.values().filter(func(i: Dictionary) -> bool: return i["kind"] == C.NADE_FIRE)
	_check("an incendiary goes off on impact, before any fuse", w._grenades.is_empty() and not fires.is_empty())
	var area: Dictionary = fires[0]
	_check("its fire starts on the ground", absf((area["pos"] as Vector3).y - spot.y) < 1.0)
	w.areas.items.clear()


func _person(sid: int, team: int, pos: Vector3, class_id: int, kit: Dictionary = {}) -> Soldier:
	var s := w.add_soldier(sid, 0, team, "Tester%d" % sid)
	s.respawn(pos, 0, class_id, kit)
	s.protected_t = 0
	s.set_physics_process(false)
	return s


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[grenades] %s %s" % ["PASS" if ok else "FAIL", label])
