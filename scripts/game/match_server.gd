class_name MatchServer
extends Node
## Authoritative game rules: spawning, damage, bots and snapshots. Runs on the host, the
## dedicated server, and in offline play. Clients never execute this. What differs between
## game modes lives in `rules`.

const SNAPSHOT_RATE := 1.0 / 20.0
const FLAG_TICK := 0.1
const MAX_REWIND := 0.3
const MAX_CLIENT_SPEED := 17.0
const ROUND_RESTART_DELAY := 22.0
const PING_RATE := 2.0

var world: World
var rules: ModeRules
var rng := RandomNumberGenerator.new()
var pending_names := {}
var pending_tokens := {}
var progress := ProgressStore.new()
var bots: Array[BotBrain] = []
var round_over := false

var _next_sid := 1
var _snap_t := 0.0
var _flag_t := 0.0
var _roster_t := 0.0
var _roster_dirty := false
var _ping_t := 0.0
## sid -> {"at": when it happens, "from": where the soldier stood} for getting in or out.
var _using := {}
var _restart_t := 0.0
var _regen_t := 0.0
var _grenade_id := 1
var _coin_id := 0
var _coin_t := C.COIN_FIRST_DELAY
var _coin_expire := {}
var _heal_bank := {}
var _save_t := 0.0

var stat_coins_spawned := 0
var stat_coins_taken := 0
var stat_supers := {}


func setup(w: World) -> void:
	world = w
	rng.randomize()
	world.map.b.nav.label_regions()
	rules = ModeRules.create(self)
	rules.start()
	_reset_vehicles(false)
	_balance_bots()


# ---------------------------------------------------------------- roster

func _alloc_sid() -> int:
	_next_sid += 1
	return _next_sid


func add_human(peer: int, player_name: String, token: String, side := 0) -> void:
	if world.soldier_for_peer(peer) != null:
		return
	var sid := _alloc_sid()
	var nice := player_name if player_name != "" else T.t("Gracz %d") % sid
	# A free-for-all has no sides: everyone wears the same colours there.
	var human := world.add_soldier(sid, peer, C.Team.RESISTANCE if world.ffa else clampi(side, 0, 1), nice)
	human.token = token
	human.level = Gear.level_of(progress.xp(token))
	_balance_bots()
	_send_roster()
	if peer != multiplayer.get_unique_id():
		# Bring the newcomer up to date on what is already in the world.
		Net.send_to_owner(world.soldiers[sid], &"joined", [sid])
	else:
		world.handle_event(&"joined", [sid])
	var list := []
	for id: int in world.coins:
		list.append([id, world.coins[id]["pos"]])
	Net.send_to_owner(world.soldiers[sid], &"coin_sync", [list])
	var tanks := []
	for id: int in world.vehicles:
		tanks.append(_vehicle_args(id))
	Net.send_to_owner(world.soldiers[sid], &"vehicle_sync", [tanks])
	Net.send_to_owner(world.soldiers[sid], &"fort_sync", [world.forts.snapshot()])
	Net.send_to_owner(world.soldiers[sid], &"squads", [world.squads.snapshot()])
	Net.send_to_owner(world.soldiers[sid], &"area_sync", [world.areas.snapshot()])
	_send_profile(world.soldiers[sid])
	print("[server] %s dołączył (peer %d)" % [nice, peer])


func remove_human(peer: int) -> void:
	pending_names.erase(peer)
	pending_tokens.erase(peer)
	var s := world.soldier_for_peer(peer)
	if s == null:
		return
	print("[server] %s wyszedł" % s.pname)
	if s.vehicle_id >= 0:
		exit_vehicle(s, true)
	rules.on_removed(s)
	world.squads.leave(s)
	world.remove_soldier(s.sid)
	_balance_bots()
	_send_roster()
	# Whoever comes to an empty server starts a fresh match, not the end of the last one.
	if _idle() and not round_over:
		_start_new_round()


## True when a new player would not fit: the small modes have a fixed number of places.
func is_full() -> bool:
	var counts := team_counts()
	return int(counts[0]) + int(counts[1]) >= player_limit()


func player_limit() -> int:
	return mini(int(world.mode["team_max"]), C.MAX_PLAYERS)


## Players on each side, bots left out.
func team_counts() -> Array:
	var counts := [0, 0]
	for s: Soldier in world.soldiers.values():
		if s.peer != 0:
			counts[s.team] += 1
	return counts


## A players-only server with nobody on it: there is no match to run until someone comes.
func _idle() -> bool:
	return world.cfg.get("no_bots", false) and world.soldiers.is_empty()


## Bots fill both sides up to the target, or up to the larger side's number of players.
func _balance_bots() -> void:
	if world.cfg.get("no_bots", false):
		return
	var target: int = world.cfg.get("bots_per_team", 12)
	if world.ffa:
		_balance_free_for_all(target)
		return
	var counts := [0, 0]
	var humans := [0, 0]
	for s: Soldier in world.soldiers.values():
		counts[s.team] += 1
		if s.peer != 0:
			humans[s.team] += 1
	var want := maxi(target, maxi(humans[0], humans[1]))
	while counts[0] < want:
		_add_bot(C.Team.RESISTANCE)
		counts[0] += 1
	while counts[1] < want:
		_add_bot(C.Team.EMPIRE)
		counts[1] += 1
	for i in range(bots.size() - 1, -1, -1):
		var brain := bots[i]
		if counts[brain.s.team] > want:
			counts[brain.s.team] -= 1
			rules.on_removed(brain.s)
			world.remove_soldier(brain.s.sid)
			bots.remove_at(i)


## Nobody has a side here, so everyone wears the Resistance's colours and `target` is a total.
func _balance_free_for_all(target: int) -> void:
	var count := world.soldiers.size()
	while count < target:
		_add_bot(C.Team.RESISTANCE)
		count += 1
	for i in range(bots.size() - 1, -1, -1):
		if count <= target:
			return
		count -= 1
		rules.on_removed(bots[i].s)
		world.remove_soldier(bots[i].s.sid)
		bots.remove_at(i)


func _add_bot(team: int) -> void:
	var names: Array = C.BOT_NAMES_RESISTANCE if team == 0 else C.BOT_NAMES_EMPIRE
	var used := 0
	for s: Soldier in world.soldiers.values():
		if s.team == team and s.peer == 0:
			used += 1
	var nice: String = names[used % names.size()]
	if used >= names.size():
		nice += " %d" % (used / names.size() + 1)
	var sid := _alloc_sid()
	var s := world.add_soldier(sid, 0, team, nice)
	var brain := BotBrain.new()
	brain.setup(s, self, C.DIFFICULTIES[world.cfg.get("difficulty", 1)])
	bots.append(brain)


func _send_roster() -> void:
	_roster_dirty = false
	Net.broadcast_remote(&"roster", [world.build_roster()])


# ---------------------------------------------------------------- main loop

func _exit_tree() -> void:
	progress.save()


func _physics_process(delta: float) -> void:
	_save_t += delta
	if _save_t >= 30.0:
		_save_t = 0.0
		progress.save()
	if round_over:
		_restart_t -= delta
		if _restart_t <= 0.0:
			_start_new_round()
		return
	if _idle():
		return
	for brain in bots:
		if world.bots_frozen:
			break
		var u0 := Time.get_ticks_usec()
		brain.tick(delta)
		if Time.get_ticks_usec() - u0 > 4000:
			print("[spike] brain ", brain.s.sid, " ", (Time.get_ticks_usec() - u0) / 1000.0, " cls=", brain.s.class_id, " slot=", brain.s.slot, " alive=", brain.s.alive, " tgt=", brain.target != null)
	_tick_regen(delta)
	world.squads.tick(delta)
	world.areas.tick(delta)
	_flag_t += delta
	if _flag_t >= FLAG_TICK:
		rules.tick_slow(_flag_t)
		if world.mode.get("coins", false):
			_tick_coins(_flag_t)
		_tick_supers()
		_tick_vehicles()
		_tick_use()
		_flag_t = 0.0
	rules.tick(delta)
	_snap_t += delta
	if _snap_t >= SNAPSHOT_RATE:
		_snap_t -= SNAPSHOT_RATE
		if Net.is_networked():
			Net.send_snapshot(world.build_snapshot())
	_roster_t += delta
	if _roster_t >= 1.0:
		_roster_t = 0.0
		if _roster_dirty:
			_send_roster()
	_ping_t += delta
	if _ping_t >= PING_RATE:
		_ping_t = 0.0
		if Net.is_networked():
			_send_pings()


## Only the server can measure every player, so it hands the numbers out for the score table.
func _send_pings() -> void:
	var list := []
	for s: Soldier in world.soldiers.values():
		if s.peer != 0:
			list.append([s.sid, Net.ping_of(s.peer)])
	Net.broadcast(&"pings", [list])


func _tick_regen(delta: float) -> void:
	_regen_t += delta
	if _regen_t < 0.25:
		return
	var step := _regen_t
	_regen_t = 0.0
	var now := Net.server_time()
	for s: Soldier in world.soldiers.values():
		# Super classes do not regenerate: their health is what limits them.
		var wait := C.REGEN_DELAY_PERK if s.has_perk("fieldmed") else C.REGEN_DELAY
		if s.alive and not s.is_super() and s.hp < s.max_hp and now - s.last_damage_time > wait:
			s.hp = minf(s.hp + C.REGEN_RATE * step, s.max_hp)
	for healer: Soldier in world.soldiers.values():
		if healer.alive and healer.class_data().get("healer", false):
			_heal_around(healer, step)


func _heal_around(healer: Soldier, step: float) -> void:
	var healed := 0.0
	for s: Soldier in world.soldiers.values():
		if not s.alive or world.are_foes(s, healer) or s.is_super() or s.hp >= s.max_hp:
			continue
		if s.global_position.distance_to(healer.global_position) > C.HEAL_RADIUS:
			continue
		var amount := minf(C.HEAL_RATE * step, s.max_hp - s.hp)
		s.hp += amount
		if s != healer:
			healed += amount
	var bank: float = float(_heal_bank.get(healer.sid, 0.0)) + healed
	if bank >= 50.0:
		bank -= 50.0
		add_score(healer, C.SCORE_HEAL_PER_50, "LECZENIE")
	_heal_bank[healer.sid] = bank


# ---------------------------------------------------------------- coins and super classes

func _tick_coins(dt: float) -> void:
	_coin_t -= dt
	if _coin_t <= 0.0:
		_coin_t = _next_coin_delay()
		if world.coins.size() < C.COIN_MAX_ON_MAP:
			spawn_coin(world.map.random_coin_point(rng), C.COIN_LIFETIME)
	var now := Net.server_time()
	for id: int in world.coins.keys():
		if now >= float(_coin_expire.get(id, 0.0)):
			_remove_coin(id)
			continue
		var pos: Vector3 = world.coins[id]["pos"]
		for s: Soldier in world.soldiers.values():
			if s.alive and s.coins == 0 and not s.is_super() and s.global_position.distance_to(pos) < C.COIN_PICKUP_RADIUS + 0.6:
				_coin_expire.erase(id)
				stat_coins_taken += 1
				Net.broadcast(&"coin_taken", [id, s.sid])
				break


func _next_coin_delay() -> float:
	var fixed := float(world.cfg.get("coin_interval", 0.0))
	return fixed if fixed > 0.0 else rng.randf_range(C.COIN_INTERVAL_MIN, C.COIN_INTERVAL_MAX)


func spawn_coin(pos: Vector3, lifetime: float) -> int:
	_coin_id += 1
	_coin_expire[_coin_id] = Net.server_time() + lifetime
	stat_coins_spawned += 1
	Net.broadcast(&"coin_spawn", [_coin_id, pos])
	return _coin_id


func _remove_coin(id: int) -> void:
	_coin_expire.erase(id)
	Net.broadcast(&"coin_gone", [id])


## Bots and the player's request both end up here. The reply goes out as an event.
func activate_super(s: Soldier, class_id: int) -> bool:
	if not s.alive or s.coins <= 0 or s.is_super() or not can_act():
		return false
	if class_id != C.SUPER_MECH and class_id != C.SUPER_SPECIAL:
		return false
	var cd := C.cls(s.team, class_id)
	if cd.get("mech", false) and not mech_fits(s.global_position):
		Net.send_to_owner(s, &"notice", ["ZA CIASNO NA MECHA: WYJDŹ NA OTWARTĄ PRZESTRZEŃ"])
		return false
	stat_supers[cd["id"]] = int(stat_supers.get(cd["id"], 0)) + 1
	Net.broadcast(&"transform", [s.sid, class_id, cd["duration"]])
	return true


func mech_fits(pos: Vector3) -> bool:
	var nav := world.map.b.nav_wide
	return nav.is_free(nav.cell_of(pos)) and pos.y - world.map.ground_height(pos.x, pos.z) < 1.2


func sv_transform(peer: int, class_id: int) -> void:
	var s := world.soldier_for_peer(peer)
	if s != null:
		activate_super(s, class_id)


func _tick_supers() -> void:
	for s: Soldier in world.soldiers.values():
		if s.alive and s.is_super() and not s.is_vehicle() and s.super_t <= 0.0:
			Net.broadcast(&"transform", [s.sid, s.base_class, 0.0])


# ---------------------------------------------------------------- vehicles

func _vehicle_args(id: int) -> Array:
	var v: Dictionary = world.vehicles[id]
	return [id, v["team"], v["pos"], v["yaw"], v["hp"], v["driver"], v.get("gunner", 0), v.get("kind", 0)]


func _push_vehicle(id: int) -> void:
	Net.broadcast(&"vehicle", _vehicle_args(id))


func _vehicle_class(v: Dictionary) -> int:
	return C.APC_CLASS if v.get("kind", 0) == 1 else C.VEHICLE_CLASS


func _seat_key(s: Soldier) -> String:
	return "ammo_gunner" if s.is_gunner() else "ammo_driver"


func _clear_ammo(v: Dictionary) -> void:
	v.erase("ammo_driver")
	v.erase("ammo_gunner")


func _reset_vehicles(announce: bool) -> void:
	if not world.mode.get("vehicles", false):
		return
	var tanks_only: bool = world.mode.get("tanks_only", false)
	var id := 0
	for team in 2:
		for spot: Array in world.map.tank_depots()[team]:
			id += 1
			var pos: Vector3 = spot[0]
			pos.y = world.map.ground_height(pos.x, pos.z)
			# When everyone spawns in a tank, one only exists while it has a crew.
			var hp := 0.0 if tanks_only else float(C.cls(team, C.VEHICLE_CLASS)["hp"])
			world.on_vehicle(id, team, pos, spot[1], hp, 0)
			var v: Dictionary = world.vehicles[id]
			_clear_ammo(v)
			v["home"] = [pos, spot[1]]
			v["free_since"] = Net.server_time()
			v["respawn_at"] = INF if tanks_only else 0.0
			if announce:
				Net.broadcast_remote(&"vehicle", _vehicle_args(id))
		if tanks_only:
			continue
		for spot: Array in world.map.apc_depots()[team]:
			id += 1
			var nav := world.map.b.nav_tank
			var pos: Vector3 = nav._center(nav.nearest_free(nav.cell_of(spot[0])))
			pos.y = world.map.ground_height(pos.x, pos.z)
			world.on_vehicle(id, team, pos, spot[1], float(C.cls(team, C.APC_CLASS)["hp"]), 0, 0, 1)
			var v: Dictionary = world.vehicles[id]
			_clear_ammo(v)
			v["home"] = [pos, spot[1]]
			v["free_since"] = Net.server_time()
			v["respawn_at"] = 0.0
			if announce:
				Net.broadcast_remote(&"vehicle", _vehicle_args(id))


func _tick_vehicles() -> void:
	var now := Net.server_time()
	for id: int in world.vehicles:
		var v: Dictionary = world.vehicles[id]
		if float(v["hp"]) <= 0.0 and now >= float(v["respawn_at"]):
			v["pos"] = v["home"][0]
			v["yaw"] = v["home"][1]
			v["hp"] = float(C.cls(v["team"], _vehicle_class(v))["hp"])
			v["driver"] = 0
			v["free_since"] = now
			_clear_ammo(v)
			_push_vehicle(id)


func free_vehicle_near(s: Soldier, reach: float) -> int:
	var best := -1
	var best_d := reach
	for id: int in world.vehicles:
		var v: Dictionary = world.vehicles[id]
		if v["team"] != s.team or not world.has_room(v) or float(v["hp"]) <= 0.0:
			continue
		var driver: Soldier = world.soldiers.get(v["driver"])
		var d := s.global_position.distance_to(driver.global_position if driver else v["pos"])
		if d < best_d:
			best_d = d
			best = id
	return best


## E starts getting in or out, which takes C.USE_TIME. A second E calls it off.
func sv_use(peer: int) -> void:
	var s := world.soldier_for_peer(peer)
	if s == null or not s.alive or not can_act():
		return
	if _using.has(s.sid):
		_using.erase(s.sid)
		Net.send_to_owner(s, &"use_wait", [0.0])
		return
	var possible := s.riding >= 0 or (s.vehicle_id >= 0 and rules.can_leave_vehicle()) or (s.vehicle_id < 0 and free_vehicle_near(s, C.TANK_ENTER_RANGE) >= 0)
	if not possible:
		return
	_using[s.sid] = {"at": Net.server_time() + C.USE_TIME, "from": s.global_position}
	Net.send_to_owner(s, &"use_wait", [C.USE_TIME])


func _tick_use() -> void:
	var now := Net.server_time()
	for sid: int in _using.keys():
		var s: Soldier = world.soldiers.get(sid)
		var job: Dictionary = _using[sid]
		if s == null or not s.alive or not can_act():
			_using.erase(sid)
			continue
		# Walking off on foot calls it off; a moving vehicle carries its crew along anyway.
		if s.vehicle_id < 0 and s.riding < 0 and s.global_position.distance_to(job["from"]) > 2.0:
			_using.erase(sid)
			Net.send_to_owner(s, &"use_wait", [0.0])
			continue
		if now >= float(job["at"]):
			_using.erase(sid)
			Net.send_to_owner(s, &"use_wait", [0.0])
			use_now(s)


## Gets in or out on the spot. Bots and tests come here directly.
func use_now(s: Soldier) -> void:
	if s == null or not s.alive or not can_act():
		return
	if s.riding >= 0:
		dismount(s)
		return
	if s.vehicle_id >= 0:
		if rules.can_leave_vehicle():
			exit_vehicle(s)
		return
	var id := free_vehicle_near(s, C.TANK_ENTER_RANGE)
	if id >= 0:
		enter_vehicle(s, id)


func sv_build(peer: int, kind: int, pos: Vector3, yaw: float) -> void:
	var s := world.soldier_for_peer(peer)
	if s and can_act():
		world.forts.request(s, kind, pos, yaw)


func enter_vehicle(s: Soldier, id: int) -> bool:
	var v: Dictionary = world.vehicles.get(id, {})
	if v.is_empty() or not s.alive or s.is_super() or v["team"] != s.team or not world.has_room(v) or float(v["hp"]) <= 0.0:
		return false
	var crew_full: bool = v["driver"] != 0 and (v.get("kind", 0) == 1 or v.get("gunner", 0) != 0)
	if crew_full:
		Net.broadcast(&"ride", [s.sid, id])
		return true
	s.infantry_hp = s.hp
	var seat := 0 if v["driver"] == 0 else 1
	var driver: Soldier = world.soldiers.get(v["driver"])
	if driver:
		v["pos"] = driver.global_position
		v["yaw"] = driver.hull_yaw
		v["hp"] = driver.hp
	v["driver" if seat == 0 else "gunner"] = s.sid
	_using.erase(s.sid)
	Net.broadcast(&"crew", [s.sid, id, seat])
	_push_vehicle(id)
	Net.broadcast(&"place", [s.sid, v["pos"], v["yaw"]])
	Net.broadcast(&"transform", [s.sid, _vehicle_class(v), 0.0, v["hp"], v.get("ammo_gunner" if seat == 1 else "ammo_driver", {})])
	return true


## Lets a passenger out beside the carrier.
func dismount(s: Soldier) -> void:
	var spot := _vehicle_exit_spot(s)
	if not spot.is_finite():
		spot = s.global_position + Vector3.UP * 3.2
	Net.broadcast(&"ride", [s.sid, -1])
	Net.broadcast(&"place", [s.sid, spot, s.yaw])


func sv_switch_seat(peer: int) -> void:
	var s := world.soldier_for_peer(peer)
	if s and can_act():
		switch_seat(s)


func switch_seat(s: Soldier) -> bool:
	if s.riding >= 0:
		return _rider_takes_seat(s)
	var v: Dictionary = world.vehicles.get(s.vehicle_id, {})
	if not s.alive or v.is_empty() or v.get("kind", 0) == 1:
		return false
	var target := "driver" if s.is_gunner() else "gunner"
	if v.get(target, 0) != 0:
		return false
	v[_seat_key(s)] = s.ammo_state()
	v["pos"] = s.global_position
	v["yaw"] = s.hull_yaw
	v["hp"] = s.hp
	v["gunner" if s.is_gunner() else "driver"] = 0
	v[target] = s.sid
	Net.broadcast(&"crew", [s.sid, s.vehicle_id, 0 if target == "driver" else 1])
	_push_vehicle(s.vehicle_id)
	Net.broadcast(&"transform", [s.sid, _vehicle_class(v), 0.0, v["hp"], v.get("ammo_" + target, {})])
	return true


## A passenger moves up to a free driver's or gunner's seat without getting out.
func _rider_takes_seat(s: Soldier) -> bool:
	var id := s.riding
	var v: Dictionary = world.vehicles.get(id, {})
	if v.is_empty() or not s.alive:
		return false
	if v["driver"] != 0 and (v.get("kind", 0) == 1 or v.get("gunner", 0) != 0):
		return false
	Net.broadcast(&"ride", [s.sid, -1])
	return enter_vehicle(s, id)


## Puts a soldier who has just spawned into a tank of their own, on the spot.
func crew_tank(s: Soldier) -> void:
	for id: int in world.vehicles:
		var v: Dictionary = world.vehicles[id]
		if v["team"] == s.team and v["driver"] == 0:
			v["pos"] = s.global_position
			v["yaw"] = s.yaw
			v["hp"] = float(C.cls(s.team, C.VEHICLE_CLASS)["hp"])
			_clear_ammo(v)
			enter_vehicle(s, id)
			return


func exit_vehicle(s: Soldier, disconnecting := false) -> void:
	var id := s.vehicle_id
	var v: Dictionary = world.vehicles.get(id, {})
	if v.is_empty():
		return
	var spot := _vehicle_exit_spot(s)
	if not spot.is_finite():
		if not disconnecting:
			return
		# The soldier is removed right after parking, so no infantry is placed here.
		spot = s.global_position
	v[_seat_key(s)] = s.ammo_state()
	s.vehicle_id = -1
	v["pos"] = s.global_position
	v["yaw"] = s.hull_yaw
	v["hp"] = s.hp
	v["gunner" if s.is_gunner() else "driver"] = 0
	v["free_since"] = Net.server_time()
	_push_vehicle(id)
	Net.broadcast(&"crew", [s.sid, -1, -1])
	Net.broadcast(&"transform", [s.sid, s.base_class, 0.0, s.infantry_hp])
	Net.broadcast(&"place", [s.sid, spot, s.yaw])


## Exiting must not put infantry inside the hull, another tank or a wall.
func _vehicle_exit_spot(s: Soldier) -> Vector3:
	var capsule := CapsuleShape3D.new()
	capsule.radius = C.BODY_RADIUS
	capsule.height = C.STAND_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = capsule
	q.collision_mask = C.LAYER_WORLD | C.LAYER_VEHICLE | C.LAYER_FORT
	var basis := Basis(Vector3.UP, s.hull_yaw)
	for distance: float in [3.8, 5.0, 7.0, 10.0]:
		for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			var center := s.global_position + basis * side * distance
			var spot := world.map.spawn_point_near(center, 0.8, rng)
			q.transform = Transform3D(Basis.IDENTITY, spot + Vector3.UP * C.STAND_HEIGHT * 0.5)
			if world.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
				return spot
	return Vector3.INF


func _vehicle_destroyed(s: Soldier) -> Array[Soldier]:
	var v: Dictionary = world.vehicles.get(s.vehicle_id, {})
	var crew: Array[Soldier] = []
	if v.is_empty():
		return crew
	v["pos"] = s.global_position
	v["yaw"] = s.hull_yaw
	for sid: int in [v["driver"], v.get("gunner", 0)]:
		var member: Soldier = world.soldiers.get(sid)
		if member:
			member.vehicle_id = -1
			if member != s and member.alive:
				crew.append(member)
	for sid: int in (v["riders"] as Array).duplicate():
		var rider: Soldier = world.soldiers.get(sid)
		Net.broadcast(&"ride", [sid, -1])
		if rider and rider.alive:
			crew.append(rider)
	v["hp"] = 0.0
	v["driver"] = 0
	v["gunner"] = 0
	v["respawn_at"] = Net.server_time() + rules.tank_respawn_delay()
	_clear_ammo(v)
	Net.broadcast(&"vehicle", [v["id"], v["team"], v["pos"], v["yaw"], 0.0, 0, 0])
	return crew


## `winner` is a team, or a soldier id in a free-for-all, see `ModeRules.is_winner`.
func end_match(winner: int) -> void:
	round_over = true
	_restart_t = ROUND_RESTART_DELAY
	print("[server] koniec rundy, wygrywa: %s, wynik %s" % [rules.winner_name(winner), str(world.tickets)])
	for s: Soldier in world.soldiers.values():
		if s.peer != 0:
			var won := rules.is_winner(s, winner)
			var bonus := C.WIN_XP if won else C.LOSS_XP
			Net.send_to_owner(s, &"score", [bonus, "ZWYCIĘSTWO" if won else "UDZIAŁ W BITWIE"])
			_grant_xp(s, bonus)
	progress.save()
	Net.broadcast_remote(&"roster", [world.build_roster()])
	# Snapshots stop here, so the final score has to travel with the event.
	Net.broadcast(&"round_end", [winner, ROUND_RESTART_DELAY, world.tickets])


func _start_new_round() -> void:
	round_over = false
	rules.start()
	for id: int in world.coins.keys():
		_remove_coin(id)
	_coin_t = C.COIN_FIRST_DELAY
	for s: Soldier in world.soldiers.values():
		s.vehicle_id = -1
	_reset_vehicles(true)
	world.forts.reset()
	world.squads.reset()
	world.areas.reset()
	_using.clear()
	for s: Soldier in world.soldiers.values():
		s.kills = 0
		s.deaths = 0
		s.score = 0
		s.death_time = -100.0
		if s.alive:
			s.alive = false
	for brain in bots:
		brain.reset()
	Net.broadcast(&"round_start", [])
	_send_roster()


# ---------------------------------------------------------------- spawning

func can_spawn_at(team: int, flag_idx: int) -> bool:
	if flag_idx < 0 or flag_idx >= world.flags.size():
		return false
	return world.flags[flag_idx]["owner"] == team


func spawn(s: Soldier, class_id: int, flag_idx: int, kit: Dictionary = {}) -> void:
	if s.peer == 0 and class_id == 0 and kit.is_empty():
		kit = Gear.sanitize(0, {"ordnance": "rockets" if rng.randf() < .4 else "grenades"}, 1, s.team)
	var pos := world.squads.take_beacon_spot(s) if flag_idx == C.SPAWN_BEACON else rules.spawn_point(s, flag_idx)
	# Never below the terrain, which on an uneven map rises above a spot picked at sea level.
	pos.y = maxf(pos.y, world.map.ground_height(pos.x, pos.z) + 0.1)
	var toward: Vector3 = world.map.focus() - pos
	var yaw := atan2(-toward.x, -toward.z)
	Net.broadcast(&"spawn", [s.sid, pos, yaw, class_id, kit])
	rules.on_spawned(s)


func sv_deploy(peer: int, class_id: int, flag_idx: int, kit: Dictionary) -> void:
	var s := world.soldier_for_peer(peer)
	if s == null or s.alive or round_over or not rules.may_deploy(s):
		return
	if class_id < 0 or class_id >= C.NORMAL_CLASSES:
		return
	if Net.server_time() - s.death_time < C.RESPAWN_DELAY - 0.25:
		return
	# The class goes with the rank: a leader cannot swap it, and nobody else can pick it.
	if world.squads.leads(s):
		class_id = C.COMMAND_CLASS
	elif class_id == C.COMMAND_CLASS:
		class_id = 0
	if flag_idx == C.SPAWN_BEACON and world.squads.spawn_problem(s) != "":
		flag_idx = -1
	spawn(s, class_id, flag_idx, Gear.sanitize(class_id, kit, s.level, s.team))


## The pause menu's respawn. It costs what a death costs, and nobody is credited with a kill.
func sv_respawn(peer: int) -> void:
	var s := world.soldier_for_peer(peer)
	if s == null or not s.alive or not can_act():
		return
	# Out of the vehicle first: the player's own choice must not wreck it under the crew.
	if s.riding >= 0:
		dismount(s)
	elif s.vehicle_id >= 0 and rules.can_leave_vehicle():
		exit_vehicle(s)
		if s.vehicle_id >= 0:
			Net.send_to_owner(s, &"notice", ["NIE MA GDZIE WYSIĄŚĆ Z POJAZDU"])
			return
	apply_damage(s, 99999.0, null, C.WEAPON_RESPAWN, false, s.global_position, true)


# ---------------------------------------------------------------- admin panel

## Test orders from the F1 panel. Anyone may send them for now; each one is logged.
func sv_admin(peer: int, cmd: String, arg: Variant) -> void:
	var s := world.soldier_for_peer(peer)
	if s == null:
		return
	print("[admin] %s: %s" % [s.pname, cmd])
	match cmd:
		"god":
			s.god = not s.god
			_send_admin_state(s)
		"noclip":
			s.noclip = not s.noclip and s.alive and not s.is_vehicle() and s.riding < 0
			_send_admin_state(s)
		"ammo":
			s.inf_ammo = not s.inf_ammo
			_send_admin_state(s)
		"heal":
			if s.alive:
				Net.broadcast(&"refill", [s.sid])
		"tp":
			if s.alive and arg is Vector3 and (arg as Vector3).is_finite() and s.vehicle_id < 0 and s.riding < 0:
				Net.broadcast(&"place", [s.sid, arg, s.yaw])
		"coin":
			if s.alive and s.coins == 0 and not s.is_super():
				spawn_coin(s.global_position, C.COIN_LIFETIME)
		"bots_more", "bots_less":
			var target := int(world.cfg.get("bots_per_team", 0)) + (2 if cmd == "bots_more" else -2)
			world.cfg["bots_per_team"] = clampi(target, 0, int(world.mode["team_max"]))
			world.cfg["no_bots"] = world.cfg["bots_per_team"] == 0
			if world.cfg["no_bots"]:
				_remove_bots(false)
			_balance_bots()
			_send_roster()
			Net.send_to_owner(s, &"notice", [T.pack("BOTÓW NA STRONĘ: %d", [world.cfg["bots_per_team"]])])
		"bots_clear":
			world.cfg["bots_per_team"] = 0
			world.cfg["no_bots"] = true
			_remove_bots(true)
			_send_roster()
		"kill_bots":
			for o: Soldier in world.soldiers.values():
				if o.peer == 0 and o.alive:
					apply_damage(o, 99999.0, null, C.WEAPON_ADMIN, false, o.global_position, true)
		"freeze":
			world.bots_frozen = not world.bots_frozen
			for brain in bots:
				brain.s.wish = Vector3.ZERO
				brain.s.want_sprint = false
				brain.s.drive = Vector2.ZERO
			Net.broadcast(&"admin_world", [world.bots_frozen])
		"dummy":
			if s.alive:
				_add_dummy(s)
		"tank", "apc":
			if s.alive and world.mode.get("vehicles", false):
				_admin_vehicle(s, 1 if cmd == "apc" else 0)
		"fix_vehicles":
			for id: int in world.vehicles:
				var v: Dictionary = world.vehicles[id]
				if float(v["hp"]) <= 0.0:
					v["respawn_at"] = 0.0
				elif _is_parked(v):
					v["hp"] = float(C.cls(v["team"], _vehicle_class(v))["hp"])
					_push_vehicle(id)
		"flags":
			for i in world.flags.size():
				var f: Dictionary = world.flags[i]
				var before: int = f["owner"]
				f["owner"] = s.team
				f["value"] = -1.0 if s.team == C.Team.RESISTANCE else 1.0
				if before != s.team:
					Net.broadcast(&"flag_changed", [i, s.team, before])
		"win":
			if not round_over:
				end_match(s.sid if world.ffa else s.team)
		"round":
			_start_new_round()


func _send_admin_state(s: Soldier) -> void:
	Net.broadcast(&"admin_state", [s.sid, s.god, s.noclip, s.inf_ammo])


## Every bot goes; with `dummies` the standing targets go too.
func _remove_bots(dummies: bool) -> void:
	for brain in bots:
		rules.on_removed(brain.s)
		world.remove_soldier(brain.s.sid)
	bots.clear()
	if dummies:
		for o: Soldier in world.soldiers.values():
			if o.peer == 0:
				rules.on_removed(o)
				world.remove_soldier(o.sid)


## An enemy that stands still and never fights back: something to shoot at.
func _add_dummy(s: Soldier) -> void:
	var team := C.Team.EMPIRE if s.team == C.Team.RESISTANCE else C.Team.RESISTANCE
	var sid := _alloc_sid()
	var dummy := world.add_soldier(sid, 0, team, T.t("Manekin %d") % sid)
	var ahead := Vector3(-sin(s.yaw), 0.0, -cos(s.yaw))
	var pos := world.map.spawn_point_near(s.global_position + ahead * 7.0, 1.0, rng)
	pos.y = maxf(pos.y, world.map.ground_height(pos.x, pos.z) + 0.1)
	Net.broadcast(&"spawn", [sid, pos, s.yaw + PI, 0, {}])
	dummy.protected_t = 0.0
	_send_roster()


func _admin_vehicle(s: Soldier, kind: int) -> void:
	var id := 1
	for key: int in world.vehicles:
		id = maxi(id, key + 1)
	var ahead := Vector3(-sin(s.yaw), 0.0, -cos(s.yaw))
	var nav := world.map.b.nav_tank
	var pos: Vector3 = nav._center(nav.nearest_free(nav.cell_of(s.global_position + ahead * 10.0)))
	pos.y = world.map.ground_height(pos.x, pos.z)
	var hp := float(C.cls(s.team, C.APC_CLASS if kind == 1 else C.VEHICLE_CLASS)["hp"])
	Net.broadcast(&"vehicle", [id, s.team, pos, s.yaw, hp, 0, 0, kind])
	var v: Dictionary = world.vehicles[id]
	v["home"] = [pos, s.yaw]
	v["free_since"] = Net.server_time()
	v["respawn_at"] = 0.0


func sv_squad(peer: int, action: int, id: int) -> void:
	var s := world.soldier_for_peer(peer)
	if s == null:
		return
	match action:
		0: world.squads.create(s)
		1: world.squads.join(s, id)
		2: world.squads.leave(s)


func sv_strike(peer: int, target: Vector3) -> void:
	var s := world.soldier_for_peer(peer)
	if s:
		world.squads.request_strike(s, target)


func sv_beacon(peer: int) -> void:
	var s := world.soldier_for_peer(peer)
	if s:
		world.squads.place_beacon(s)


# ---------------------------------------------------------------- client input validation

func sv_state(peer: int, pos: Vector3, new_yaw: float, new_pitch: float, flags: int, new_slot: int, hull: float) -> void:
	var s := world.soldier_for_peer(peer)
	if s == null or not s.alive or not pos.is_finite() or is_nan(new_yaw) or is_nan(new_pitch):
		return
	if s.riding >= 0:
		s.yaw = new_yaw
		s.pitch = new_pitch
		return
	var now := Net.server_time()
	if s.is_gunner():
		world.sync_gunner(s)
		s.yaw = new_yaw
		s.pitch = clampf(new_pitch, C.TANK_GUNNER_PITCH_MIN, C.TANK_GUNNER_PITCH_MAX)
		s.apply_flags(flags)
		return
	var dt := clampf(now - s.last_state_time, 0.01, 0.5)
	s.last_state_time = now
	var moved := Vector2(pos.x - s.last_valid_pos.x, pos.z - s.last_valid_pos.z).length()
	if moved > MAX_CLIENT_SPEED * dt + 1.5 and not s.noclip:
		# Too fast to be legitimate: hold the soldier where it was and resync the client.
		Net.send_to_owner(s, &"correct_position", [s.last_valid_pos])
		return
	s.last_valid_pos = pos
	s.global_position = pos
	s.yaw = new_yaw
	if not is_nan(hull):
		s.hull_yaw = hull
	s.pitch = clampf(new_pitch, -1.55, 1.55)
	s.apply_flags(flags)
	if new_slot != s.slot and new_slot >= 0 and new_slot < s.loadout.size() and not (s.is_vehicle() and new_slot == C.TANK_ROOF_SLOT and world.roof_taken(s)):
		s.slot = new_slot
		s.reload_t = 0.0
		if s.model:
			s.model.set_weapon(s.weapon_id(), s.weapon_parts())


## False once the match is over, and between the rounds of modes that have them.
func can_act() -> bool:
	return not round_over and rules.can_act()


func _rewind_time(view_time: float) -> float:
	var now := Net.server_time()
	return clampf(view_time, now - MAX_REWIND, now)


func sv_fire(peer: int, slot: int, origin: Vector3, dir: Vector3, view_time: float) -> void:
	var s := world.soldier_for_peer(peer)
	if s == null or not s.alive or not can_act() or not origin.is_finite() or not dir.is_finite():
		return
	if dir.length_squared() < 0.5:
		return
	if s.control == Soldier.Driver.PROXY_SERVER:
		# The owner's client predicted this shot, so check it against server-side state.
		if slot != s.slot or s.mags[slot] <= 0 or s.reload_t > 0.0 or s.is_melee():
			return
		if s.fire_cd > float(s.weapon()["rate"]) * 0.3:
			return
		if origin.distance_to(s.eye_position()) > (6.0 if s.is_vehicle() else 3.0):
			return
		s.consume_shot()
	var pellets := int(s.weapon().get("pellets", 1))
	if pellets <= 1:
		resolve_shot(s, origin, dir.normalized(), _rewind_time(view_time), true)
		return
	# Spread is decided here, so a client cannot focus every pellet on one spot.
	var cone := deg_to_rad(float(s.weapon()["spread_hip"]))
	for i in pellets:
		var aim := dir.normalized().rotated(Vector3.UP, rng.randf_range(-cone, cone))
		aim = aim.rotated(aim.cross(Vector3.UP).normalized(), rng.randf_range(-cone, cone))
		resolve_shot(s, origin, aim.normalized(), _rewind_time(view_time), true)


func sv_swing(peer: int, dir: Vector3, view_time: float) -> void:
	var s := world.soldier_for_peer(peer)
	if s == null or not s.alive or not can_act() or not dir.is_finite() or dir.length_squared() < 0.5:
		return
	# Arms built into weapons have nothing to swing.
	if s.melee_slot() < 0:
		return
	if s.control == Soldier.Driver.PROXY_SERVER:
		if s.fire_cd > float(s.melee_weapon()["rate"]) * 0.3:
			return
		s.fire_cd = s.melee_weapon()["rate"]
	resolve_swing(s, dir.normalized(), _rewind_time(view_time), true)


func sv_reload(peer: int) -> void:
	var s := world.soldier_for_peer(peer)
	if s != null and s.control == Soldier.Driver.PROXY_SERVER and s.can_reload():
		s.start_reload()


func sv_grenade(peer: int, origin: Vector3, dir: Vector3, kind: int) -> void:
	var s := world.soldier_for_peer(peer)
	if s == null or not s.alive or not can_act() or not origin.is_finite() or not dir.is_finite():
		return
	if kind < 0 or kind >= s.nades.size():
		return
	if s.control == Soldier.Driver.PROXY_SERVER:
		if s.nades[kind] <= 0 or s.grenade_cd > 0.0 or s.reload_t > C.RELOAD_THROW_SLACK or origin.distance_to(s.eye_position()) > 3.0:
			return
		if not s.inf_ammo:
			s.nades[kind] -= 1
		s.grenade_cd = 1.0
	throw_grenade(s, origin, dir.normalized(), kind)


# ---------------------------------------------------------------- combat

## Returns {soldier, dist, head} for the first enemy on the ray, or an empty dictionary.
func _trace_soldiers(origin: Vector3, dir: Vector3, max_dist: float, shooter: Soldier, time: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for s: Soldier in world.soldiers.values():
		if not s.alive or not world.are_foes(s, shooter):
			continue
		if world.shares_driver_armor(s):
			continue
		var p := s.position_at(time)
		var h := s.stance_height()
		var to := p + Vector3.UP * (h * 0.5) - origin
		var along := to.dot(dir)
		if along < -4.0 or along > best_d + 4.0:
			continue
		if s.is_vehicle():
			var box: Vector3 = s.class_data()["hit_box"]
			var box_d := _ray_obb(origin, dir, p + Vector3.UP * 1.3, s.hull_yaw, box)
			if box_d >= 0.0 and box_d < best_d:
				best_d = box_d
				best = {"soldier": s, "dist": box_d, "head": false}
			continue
		var r := s.body_radius()
		var reach := h * 0.5 + r + 0.3
		if (to - dir * along).length_squared() > reach * reach:
			continue
		if not s.class_data().get("no_headshot", false):
			var head_d := _ray_sphere(origin, dir, p + Vector3.UP * (h - 0.15), C.HEAD_RADIUS)
			if head_d >= 0.0 and head_d < best_d:
				best_d = head_d
				best = {"soldier": s, "dist": head_d, "head": true}
				continue
		var body_d := _ray_capsule(origin, dir, p + Vector3.UP * 0.3, p + Vector3.UP * (h - 0.42), r)
		if body_d >= 0.0 and body_d < best_d:
			best_d = body_d
			best = {"soldier": s, "dist": body_d, "head": false}
	return best


## Ray against a box turned around Y, in local slabs. Returns -1.0 on a miss.
static func _ray_obb(o: Vector3, d: Vector3, center: Vector3, yaw: float, half: Vector3) -> float:
	var inv := Basis(Vector3.UP, -yaw)
	var lo := inv * (o - center)
	var ld := inv * d
	var t_min := 0.0
	var t_max := INF
	for i in 3:
		if absf(ld[i]) < 0.000001:
			if absf(lo[i]) > half[i]:
				return -1.0
			continue
		var t1 := (-half[i] - lo[i]) / ld[i]
		var t2 := (half[i] - lo[i]) / ld[i]
		t_min = maxf(t_min, minf(t1, t2))
		t_max = minf(t_max, maxf(t1, t2))
		if t_min > t_max:
			return -1.0
	return t_min


static func _ray_sphere(o: Vector3, d: Vector3, c: Vector3, r: float) -> float:
	var oc := o - c
	var b := oc.dot(d)
	var disc := b * b - (oc.length_squared() - r * r)
	if disc < 0.0:
		return -1.0
	var t := -b - sqrt(disc)
	return t if t >= 0.0 else -1.0


static func _ray_capsule(o: Vector3, d: Vector3, a: Vector3, c: Vector3, r: float) -> float:
	# Closest approach between the ray and the capsule's core segment.
	var seg := c - a
	var seg_len_sq := seg.length_squared()
	var w := o - a
	var dd := d.dot(seg)
	var denom := seg_len_sq - dd * dd
	var s := 0.0
	if denom > 0.00001:
		s = clampf((seg.dot(w) - dd * d.dot(w)) / denom, 0.0, 1.0)
	var point := a + seg * s
	var t := maxf((point - o).dot(d), 0.0)
	var gap := (o + d * t).distance_to(point)
	if gap > r:
		return -1.0
	return maxf(t - sqrt(r * r - gap * gap), 0.0)


func world_ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, C.LAYER_WORLD)
	return world.get_world_3d().direct_space_state.intersect_ray(q)


func resolve_shot(s: Soldier, origin: Vector3, dir: Vector3, time: float, from_owner := false) -> void:
	if s.weapon().get("rocket", false):
		_grenade_id += 1
		Net.broadcast(&"rocket", [_grenade_id, s.sid, origin + dir * .65, dir])
		return
	if s.weapon_id() == C.W.MECH_LAUNCHER:
		_grenade_id += 1
		Net.broadcast(&"rocket", [_grenade_id, s.sid, origin + dir * 1.6, (dir + Vector3.UP * 0.07).normalized(), true])
		return
	var w := s.weapon()
	var max_d: float = w["range"]
	var end := origin + dir * max_d
	var wall := world_ray(origin, end)
	var kind := 0
	if not wall.is_empty():
		max_d = origin.distance_to(wall["position"])
		end = wall["position"]
		kind = 1
	var hit := _trace_soldiers(origin, dir, max_d, s, time)
	if hit.is_empty():
		var hull := _parked_on_ray(origin, end)
		if not hull.is_empty():
			end = hull["position"]
			kind = 1
			damage_parked(int(hull["id"]), float(w["damage"]) * float(w.get("vs_armor", C.ARMOR_DEFAULT)), s)
		elif not wall.is_empty():
			var fort_id := int(wall["collider"].get_meta("fort_id", 0))
			if fort_id > 0:
				world.forts.damage(fort_id, float(w["damage"]), s, float(w["damage"]) >= 50.0, false)
	if not hit.is_empty():
		var target: Soldier = hit["soldier"]
		end = origin + dir * float(hit["dist"])
		kind = 2
		var dist: float = hit["dist"]
		var falloff := 1.0
		var start: float = w["falloff_start"]
		if dist > start:
			falloff = lerpf(1.0, w["falloff_min"], clampf((dist - start) / maxf(float(w["range"]) - start, 1.0), 0.0, 1.0))
		var dmg: float = float(w["damage"]) * falloff
		var head: bool = hit["head"]
		if head:
			dmg *= float(w["head_mult"])
		if target.is_vehicle():
			dmg *= float(w.get("vs_armor", C.ARMOR_DEFAULT))
		if _deflected(target, origin):
			kind = 3
			dmg *= C.BLOCK_DAMAGE_MULT
			target.stamina = maxf(target.stamina - C.BLOCK_DRAIN_PER_HIT, 0.0)
			head = false
		apply_damage(target, dmg, s, s.weapon_id(), head, origin)
	var exclude_sid := s.sid if from_owner and s.peer != 0 else -1
	Net.broadcast(&"shot", [s.sid, s.weapon_id(), origin, end, kind, exclude_sid], false)
	if kind > 0 and w.has("splash"):
		_blast(s, end, w["splash"], w["splash_damage"], hit.get("soldier"), -2, origin)


## The first vehicle hull on the line, as {"id", "position"}, or empty.
func _parked_on_ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, C.LAYER_VEHICLE)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit["collider"].has_meta("vehicle_id"):
		return {}
	return {"id": hit["collider"].get_meta("vehicle_id"), "position": hit["position"]}


func _is_parked(v: Dictionary) -> bool:
	return int(v["driver"]) == 0 and int(v.get("gunner", 0)) == 0 and float(v["hp"]) > 0.0


## A vehicle with nobody at the controls is still armour: enemies can wreck it where it stands.
## Crewed vehicles take their damage through the driver instead, see apply_damage.
func damage_parked(id: int, amount: float, attacker: Soldier) -> void:
	var v: Dictionary = world.vehicles.get(id, {})
	if v.is_empty() or not _is_parked(v) or amount <= 0.0 or not can_act():
		return
	if attacker != null and attacker.team == int(v["team"]) and not world.ffa:
		return
	if world.in_safe_zone(v["pos"], int(v["team"])):
		return
	v["hp"] = maxf(float(v["hp"]) - amount, 0.0)
	if float(v["hp"]) > 0.0:
		if attacker:
			Net.send_to_owner(attacker, &"hit_confirm", [1])
		return
	v["respawn_at"] = Net.server_time() + rules.tank_respawn_delay()
	_clear_ammo(v)
	for sid: int in (v["riders"] as Array).duplicate():
		var rider: Soldier = world.soldiers.get(sid)
		Net.broadcast(&"ride", [sid, -1])
		if rider and rider.alive:
			apply_damage(rider, 99999.0, attacker, C.W.TANK_CANNON, false, v["pos"], true)
	_push_vehicle(id)
	Net.broadcast(&"vehicle_wrecked", [id])
	if attacker:
		Net.send_to_owner(attacker, &"hit_confirm", [3])
		add_score(attacker, C.SCORE_ASSIST, "ZNISZCZONY POJAZD")


## Splash on every empty vehicle around a blast, falling off with distance like it does on people.
func _blast_parked(pos: Vector3, radius: float, damage: float, attacker: Soldier, skip_id := -1) -> void:
	for id: int in world.vehicles:
		var v: Dictionary = world.vehicles[id]
		if id == skip_id or not _is_parked(v):
			continue
		var d := maxf((v["pos"] as Vector3).distance_to(pos) - 2.6, 0.0)
		if d < radius:
			damage_parked(id, damage * (1.0 - d / radius), attacker)


## Area damage from a tank shell. `skip` already took the direct hit.
## One artillery shell. Friends are safe, as from every other explosion in the game.
func shell_blast(s: Soldier, pos: Vector3) -> void:
	_blast(s, pos, C.SHELL_RADIUS, C.SHELL_DAMAGE, null, -1)


func _blast(s: Soldier, pos: Vector3, radius: float, damage: float, skip: Variant, weapon := -2, from := Vector3.INF) -> void:
	if from.is_finite():
		Net.broadcast(&"shell_blast", [from, pos])
	else:
		Net.broadcast(&"explosion", [-1, pos])
	_damage_forts(pos, radius, damage, s)
	_blast_parked(pos, radius, damage * 0.5, s)
	for t: Soldier in world.soldiers.values():
		if not t.alive or not world.are_foes(t, s) or t == skip:
			continue
		if world.shares_driver_armor(t):
			continue
		var chest := t.global_position + Vector3.UP * 1.0
		var d := maxf(chest.distance_to(pos) - t.body_radius(), 0.0)
		if d > radius or not world_ray(pos + Vector3.UP * 0.3, chest).is_empty():
			continue
		var dmg := damage * (1.0 - d / radius)
		apply_damage(t, dmg * (0.5 if t.is_vehicle() else 1.0), s, s.weapon_id() if weapon == -2 else weapon, false, pos)


func _deflected(target: Soldier, from: Vector3) -> bool:
	if not target.blocking or target.stamina <= 0.0:
		return false
	var to_shooter := from - target.global_position
	to_shooter.y = 0.0
	var facing := target.aim_direction()
	facing.y = 0.0
	return facing.normalized().dot(to_shooter.normalized()) > 0.25


func resolve_swing(s: Soldier, dir: Vector3, time: float, from_owner := false) -> void:
	var origin := s.eye_position()
	var melee := s.melee_weapon()
	var reach: float = melee["range"]
	var best: Soldier = null
	var best_score := -1.0
	for t: Soldier in world.soldiers.values():
		if not t.alive or not world.are_foes(t, s):
			continue
		var p := t.position_at(time) + Vector3.UP * (t.stance_height() * 0.55)
		var to := p - origin
		var dist := to.length()
		if dist > reach + 0.5 + (t.body_radius() * 1.6 if t.is_vehicle() else 0.0):
			continue
		var cosine := dir.dot(to / maxf(dist, 0.01))
		if cosine < 0.45:
			continue
		if not world_ray(origin, p).is_empty():
			continue
		if cosine - dist * 0.05 > best_score:
			best_score = cosine - dist * 0.05
			best = t
	var exclude_sid := s.sid if from_owner and s.peer != 0 else -1
	Net.broadcast(&"swing", [s.sid, exclude_sid], false)
	if best == null:
		return
	if _deflected(best, origin):
		best.stamina = maxf(best.stamina - 2.0, 0.0)
		Net.broadcast(&"clash", [(origin + best.eye_position()) * 0.5])
		return
	var dmg: float = float(melee["damage"]) * float(s.class_data()["sword_mult"]) * float(best.class_data().get("melee_vuln", 1.0))
	if best.is_vehicle():
		dmg *= C.MELEE_VS_ARMOR
	apply_damage(best, dmg, s, s.loadout[s.melee_slot()], false, origin)
	Net.broadcast(&"sword_hit", [best.eye_position() - Vector3.UP * 0.4])


func apply_damage(v: Soldier, amount: float, attacker: Soldier, weapon_id: int, head: bool, from: Vector3, crew_loss := false) -> void:
	if v.is_gunner() and not crew_loss:
		var vehicle := world.vehicle_for(v.sid)
		var driver: Soldier = world.soldiers.get(vehicle.get("driver", 0))
		if driver and driver.alive:
			apply_damage(driver, amount, attacker, weapon_id, head, from)
			return
	if not v.alive or (not crew_loss and (v.protected_t > 0.0 or not can_act())):
		return
	if not crew_loss and (v.god or world.in_safe_zone(v.global_position, v.team)):
		return
	v.hp -= amount
	if v.is_gunner() and not crew_loss:
		var vehicle := world.vehicle_for(v.sid)
		if not vehicle.is_empty():
			vehicle["hp"] = maxf(v.hp, 0.0)
	v.cloak_block_t = C.CLOAK_BREAK_TIME
	v.last_damage_time = Net.server_time()
	if attacker != null and attacker != v:
		v.damagers[attacker.sid] = float(v.damagers.get(attacker.sid, 0.0)) + amount
	if v.hp > 0.0:
		Net.send_to_owner(v, &"hurt", [v.hp, from])
		if attacker != null and attacker != v:
			Net.send_to_owner(attacker, &"hit_confirm", [2 if head else 1])
		if v.control == Soldier.Driver.BOT:
			_notify_bot(v, attacker)
		return
	v.hp = 0.0
	v.deaths += 1
	var crew: Array[Soldier] = []
	if v.vehicle_id >= 0:
		crew = _vehicle_destroyed(v)
	if v.coins > 0:
		# A held coin falls where its carrier died, so hunting them is worthwhile.
		spawn_coin(v.global_position, C.COIN_DROP_LIFETIME)
	v.death_time = Net.server_time()
	_roster_dirty = true
	var killer_sid := 0
	if attacker != null and attacker != v:
		killer_sid = attacker.sid
		attacker.kills += 1
		world.squads.on_kill(attacker)
		add_score(attacker, C.SCORE_KILL, "ELIMINACJA")
		if head:
			add_score(attacker, C.SCORE_HEADSHOT, "STRZAŁ W GŁOWĘ")
		Net.send_to_owner(attacker, &"hit_confirm", [3])
		for sid: int in v.damagers:
			if sid != attacker.sid and world.soldiers.has(sid) and float(v.damagers[sid]) >= 25.0:
				add_score(world.soldiers[sid], C.SCORE_ASSIST, "ASYSTA")
	Net.broadcast(&"kill", [v.sid, killer_sid, weapon_id, head])
	for member: Soldier in crew:
		apply_damage(member, 99999.0, attacker, weapon_id, false, from, true)
	# Last, because this can end the round: the summary must include the kill above.
	rules.on_death(v, attacker)


func _notify_bot(v: Soldier, attacker: Soldier) -> void:
	if attacker == null:
		return
	for brain in bots:
		if brain.s == v:
			brain.on_damaged(attacker)
			return


func add_score(s: Soldier, points: int, reason: String) -> void:
	s.score += points
	_roster_dirty = true
	Net.send_to_owner(s, &"score", [points, reason])
	_grant_xp(s, points)


func _grant_xp(s: Soldier, amount: int) -> void:
	if s.peer == 0 or s.token == "":
		return
	var before := s.level
	s.level = Gear.level_of(progress.add(s.token, amount))
	_send_profile(s)
	if s.level > before:
		var unlocked: Array = []
		for l in range(before + 1, s.level + 1):
			unlocked.append_array(Gear.unlocks_at(l))
		Net.send_to_owner(s, &"level_up", [s.level, unlocked])
		_roster_dirty = true
		progress.save()


func _send_profile(s: Soldier) -> void:
	Net.send_to_owner(s, &"profile", [s.level, progress.xp(s.token)])


func throw_grenade(s: Soldier, origin: Vector3, dir: Vector3, kind := C.NADE_FRAG) -> void:
	_grenade_id += 1
	var vel := dir * 17.0 + Vector3.UP * 4.0 + s.velocity * 0.4
	Net.broadcast(&"grenade", [_grenade_id, s.sid, origin, vel, kind])


## A thrown grenade has gone off. Only frags explode; the other two leave an area behind.
func grenade_landed(id: int, owner_sid: int, pos: Vector3, kind: int, team: int) -> void:
	if kind == C.NADE_FRAG:
		explode(id, owner_sid, pos)
		return
	Net.broadcast(&"grenade_gone", [id])
	if can_act():
		world.areas.start(kind, pos, world.soldiers.get(owner_sid), team)


func rocket_impact(id: int, owner_sid: int, pos: Vector3, direct: Soldier, vehicle_id: int) -> void:
	var flying: ATRocket = world.rockets.get(id)
	var lobbed: bool = flying != null and flying.lobbed
	Net.broadcast(&"rocket_explosion", [id, pos])
	if not can_act():
		return
	var owner: Soldier = world.soldiers.get(owner_sid)
	if owner == null:
		return
	var parked_hit := -1
	if direct == null and world.vehicles.has(vehicle_id):
		var vehicle: Dictionary = world.vehicles[vehicle_id]
		if vehicle["team"] != owner.team:
			direct = world.soldiers.get(vehicle["driver"] if vehicle["driver"] != 0 else vehicle.get("gunner", 0))
			if direct == null:
				parked_hit = vehicle_id
				damage_parked(vehicle_id, float(C.WEAPONS[C.W.MECH_LAUNCHER if lobbed else C.W.AT_ROCKET]["damage"]), owner)
	_blast_parked(pos, 6.5 if lobbed else 4.5, 85.0 * 0.4 if lobbed else 75.0, owner, parked_hit)
	if direct and world.are_foes(direct, owner):
		var weapon := C.W.MECH_LAUNCHER if lobbed else _rocket_of(owner)
		apply_damage(direct, float(C.WEAPONS[weapon]["damage"]) if direct.is_vehicle() else (95.0 if lobbed else 110.0), owner, weapon, false, pos)
	_damage_forts(pos, 6.5 if lobbed else 5.0, 220.0 if lobbed else 450.0, owner)
	var reach := 6.5 if lobbed else 4.5
	for s: Soldier in world.soldiers.values():
		if not s.alive or s == direct or world.shares_driver_armor(s) or not world.are_foes(s, owner):
			continue
		var distance := s.global_position.distance_to(pos)
		if distance < reach and world_ray(pos + Vector3.UP * .2, s.global_position + Vector3.UP).is_empty():
			var blast := (85.0 * (0.4 if s.is_vehicle() else 1.0)) if lobbed else 75.0
			apply_damage(s, blast * (1.0 - distance / reach), owner, C.W.MECH_LAUNCHER if lobbed else _rocket_of(owner), false, pos)


## Which launcher a rocket came from, for the kill feed.
func _rocket_of(owner: Soldier) -> int:
	return C.W.ARM_ROCKETS if owner.loadout.has(C.W.ARM_ROCKETS) else C.W.AT_ROCKET


func explode(grenade_id: int, owner_sid: int, pos: Vector3) -> void:
	Net.broadcast(&"explosion", [grenade_id, pos])
	if not can_act():
		return
	var owner: Soldier = world.soldiers.get(owner_sid)
	_damage_forts(pos, C.GRENADE_RADIUS, C.GRENADE_DAMAGE, owner)
	_blast_parked(pos, C.GRENADE_RADIUS, C.GRENADE_DAMAGE * C.GRENADE_VS_ARMOR, owner)
	for s: Soldier in world.soldiers.values():
		if not s.alive or (owner != null and s != owner and not world.are_foes(s, owner)):
			continue
		if world.shares_driver_armor(s):
			continue
		var chest := s.global_position + Vector3.UP * 1.0
		var d := maxf(chest.distance_to(pos) - (s.body_radius() if s.is_vehicle() else 0.0), 0.0)
		if d > C.GRENADE_RADIUS:
			continue
		if not world_ray(pos + Vector3.UP * 0.3, chest).is_empty():
			continue
		var k := 1.0 - d / C.GRENADE_RADIUS
		var dmg := C.GRENADE_DAMAGE * k * (0.5 if s == owner else 1.0)
		if s.is_vehicle():
			dmg *= C.GRENADE_VS_ARMOR
		if s.has_perk("flak"):
			dmg *= 0.6
		apply_damage(s, dmg, owner, -1, false, pos)


func _damage_forts(pos: Vector3, radius: float, amount: float, attacker: Soldier) -> void:
	for id: int in world.forts.items.keys():
		var distance := pos.distance_to(world.forts.items[id]["pos"])
		if distance < radius:
			world.forts.damage(id, amount * (1.0 - distance / radius), attacker, true, true)
