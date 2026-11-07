extends Node
## `--test=fixes`, headless: getting in and out takes time, ammo survives a vehicle, empty vehicles
## break, the safe zones hold, sprint locks when stamina runs dry, F cuts once, and the admin panel.
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
	# The offline match keeps one bot to fight, which would only get in the way here.
	m.sv_admin(peer, "bots_clear", null)
	await _frames(2)
	_check("bots can be cleared", m.bots.is_empty() and w.soldiers.size() == 1)
	var mid: Vector3 = w.flags[2]["pos"]
	_check("the middle flag is outside both safe zones", not w.in_safe_zone(mid, 0) and not w.in_safe_zone(mid, 1))
	print("[fixes] safe zones: ", w.safe_zones)

	# ---- getting in takes two seconds
	m.spawn(me, 0, -1)
	await _frames(2)
	me.protected_t = 0.0
	me.global_position = mid + Vector3(30, 0.1, 0)
	me.last_valid_pos = me.global_position
	m._admin_vehicle(me, 0)
	var vid := 0
	for id: int in w.vehicles:
		vid = maxi(vid, id)
	var v: Dictionary = w.vehicles[vid]
	_check("the admin panel parks a tank ahead", float(v["hp"]) > 0.0 and (v["pos"] as Vector3).distance_to(me.global_position) < 16.0)
	me.global_position = (v["pos"] as Vector3) + Vector3(4.5, 0.1, 0)
	me.last_valid_pos = me.global_position
	var mags_before: Array = me.mags.duplicate()
	me.consume_shot()
	me.consume_shot()
	me.nades[0] -= 1
	var foot := me.ammo_state()
	m.sv_use(peer)
	await _seconds(1.0)
	_check("not in after one second", not me.is_vehicle())
	await _seconds(1.4)
	_check("in after two", me.is_vehicle() and int(v["driver"]) == me.sid)
	me.consume_shot()
	var tank_mags: Array = me.mags.duplicate()
	m.sv_use(peer)
	await _seconds(0.5)
	m.sv_use(peer)
	await _seconds(2.0)
	_check("a second E calls getting out off", me.is_vehicle())
	m.sv_use(peer)
	await _seconds(2.4)
	_check("out after two seconds", not me.is_vehicle())
	_check("the magazines come back as they were", me.mags == foot["mags"] and me.mags != mags_before)
	_check("so do the grenades", me.nades == foot["nades"])
	m.use_now(me)
	await _frames(2)
	_check("the tank keeps its own ammo", me.is_vehicle() and me.mags == tank_mags)
	m.use_now(me)
	await _frames(2)

	# ---- an empty tank can be wrecked, but not by friends and not at home
	var foe := _person(w, 601, C.Team.EMPIRE, (v["pos"] as Vector3) + Vector3(-18, 0.1, 0))
	foe.global_position = (v["pos"] as Vector3) + Vector3(-18, 0.1, 0)
	var hull := float(v["hp"])
	var target := (v["pos"] as Vector3) + Vector3.UP * 1.2
	# Somewhere with a clear view of the tank, and not behind the player standing next to it.
	for step in 16:
		var spot := (v["pos"] as Vector3) + Vector3(15, 0.1, 0).rotated(Vector3.UP, step * TAU / 16.0)
		foe.global_position = spot
		if m.world_ray(foe.eye_position(), target).is_empty() and me.global_position.distance_to(spot) > 12.0:
			break
	var aim := (target - foe.eye_position()).normalized()
	m.resolve_shot(foe, foe.eye_position(), aim, Net.server_time())
	_check("a shot hurts an empty tank", float(v["hp"]) < hull)
	var mate := _person(w, 602, me.team, (v["pos"] as Vector3) + Vector3(18, 0.1, 0))
	hull = float(v["hp"])
	m.resolve_shot(mate, mate.eye_position(), ((v["pos"] as Vector3) + Vector3.UP * 1.2 - mate.eye_position()).normalized(), Net.server_time())
	_check("a friend's shot does not", float(v["hp"]) == hull)
	m.explode(900, foe.sid, (v["pos"] as Vector3) + Vector3(-3, 0.3, 0))
	_check("a grenade does", float(v["hp"]) < hull)
	for i in 12:
		m.damage_parked(vid, 150.0, foe)
	_check("rockets wreck it", float(v["hp"]) <= 0.0 and float(v["respawn_at"]) > Net.server_time())
	var home: Dictionary = w.vehicles[1]
	hull = float(home["hp"])
	m.damage_parked(1, 150.0, foe)
	_check("a tank in its own base cannot be hurt", float(home["hp"]) == hull)

	# ---- the safe zone protects soldiers too
	me.global_position = w.home_of(me.team) + Vector3(2, 0.1, 2)
	var hp := me.hp
	m.apply_damage(me, 40.0, foe, C.W.CARBINE, false, foe.global_position)
	_check("nobody is hurt in their own base", me.hp == hp)
	foe.global_position = w.home_of(me.team) + Vector3(-2, 0.1, 2)
	hp = foe.hp
	m.apply_damage(foe, 40.0, me, C.W.CARBINE, false, me.global_position)
	_check("an enemy in that base is", foe.hp < hp)
	me.global_position = mid + Vector3(30, 0.1, 0)
	hp = me.hp
	m.apply_damage(me, 40.0, foe, C.W.CARBINE, false, foe.global_position)
	_check("outside it the player is hurt", me.hp < hp)

	# ---- stamina: run dry, then wait for a third before sprinting again
	me.refill()
	me.stamina = 0.0
	me.want_sprint = true
	me.wish = Vector3.FORWARD
	me.simulate_move(0.016)
	_check("no sprint at zero stamina", not me.sprinting and me.exhausted)
	me.stamina = me.stamina_max * 0.1
	me.simulate_move(0.016)
	_check("a scrap of stamina is not enough", not me.sprinting)
	me.stamina = me.stamina_max * 0.35
	me.simulate_move(0.016)
	_check("a third of it is", me.sprinting and not me.exhausted)
	me.want_sprint = false
	me.wish = Vector3.ZERO

	# ---- F cuts once and goes back to the gun
	var c := w.controller
	c.state = PlayerController.State.ALIVE
	me.switch_to(0)
	me.switch_t = 0.0
	me.fire_cd = 0.0
	Input.action_press("melee")
	await _frames(2)
	Input.action_release("melee")
	_check("F takes the sword out", me.is_melee())
	await _seconds(1.2)
	_check("and puts it back after one cut", me.slot == 0)

	# ---- admin panel
	m.sv_admin(peer, "god", null)
	hp = me.hp
	m.apply_damage(me, 60.0, foe, C.W.CARBINE, false, foe.global_position)
	_check("god mode takes no damage", me.god and me.hp == hp)
	m.sv_admin(peer, "god", null)
	m.sv_admin(peer, "ammo", null)
	var shots: int = me.mags[me.slot]
	me.consume_shot()
	_check("infinite ammo keeps the magazine", me.mags[me.slot] == shots)
	m.sv_admin(peer, "ammo", null)
	m.sv_admin(peer, "noclip", null)
	_check("noclip switches on", me.noclip)
	var before := me.global_position
	me.drive = Vector2(0, 1)
	me.pitch = 0.6
	me.simulate_move(0.5)
	me.drive = Vector2.ZERO
	_check("noclip flies where the eyes look", me.global_position.y > before.y + 2.0)
	m.sv_admin(peer, "noclip", null)
	m.sv_admin(peer, "tp", mid + Vector3(0, 0.5, 0))
	_check("teleport moves the player", me.global_position.distance_to(mid + Vector3(0, 0.5, 0)) < 0.1)
	var count := w.soldiers.size()
	m.sv_admin(peer, "dummy", null)
	await _frames(2)
	_check("a dummy stands in front", w.soldiers.size() == count + 1)
	# The dummy and the stand-ins count towards a side, so two presses are needed to see bots.
	m.sv_admin(peer, "bots_more", null)
	m.sv_admin(peer, "bots_more", null)
	await _frames(2)
	_check("+2 bots a side, twice", int(w.cfg["bots_per_team"]) == 4 and m.bots.size() >= 4)
	m.sv_admin(peer, "freeze", null)
	_check("bots freeze", w.bots_frozen)
	m.sv_admin(peer, "kill_bots", null)
	var alive_bots := 0
	for o: Soldier in w.soldiers.values():
		if o.peer == 0 and o.alive:
			alive_bots += 1
	_check("kill all bots", alive_bots == 0)
	m.sv_admin(peer, "flags", null)
	var mine := 0
	for f: Dictionary in w.flags:
		mine += 1 if f["owner"] == me.team else 0
	_check("all flags change hands", mine == w.flags.size())
	m.sv_admin(peer, "fix_vehicles", null)
	await _seconds(0.3)
	_check("vehicles come back", float(v["hp"]) > 0.0)
	m.sv_admin(peer, "win", null)
	_check("win the round", m.round_over)

	print("[fixes] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _person(w: World, sid: int, team: int, pos: Vector3) -> Soldier:
	var s := w.add_soldier(sid, 0, team, "Testowy %d" % sid)
	s.respawn(pos, 0.0, 0)
	s.protected_t = 0.0
	return s


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[fixes] %s %s" % ["PASS" if ok else "FAIL", label])
