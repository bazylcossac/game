class_name Squads
extends Node
## Player squads, artillery and spawn beacons. The server owns every decision. Clients keep the
## same `list` from the "squads" event, so the HUD and the deploy screen read it directly.
##
## Artillery is balanced by four things: the charge has to be earned, a strike is announced to
## everyone before it lands, the leader needs eyes on an open-sky target, and enemy bases are
## off limits. A beacon is a single destructible object that an enemy nearby shuts down.

signal changed

const NAMES := ["Alfa", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel"]
const MAX_MEMBERS := 4
## A squad's id is never reused in a match, so a late event cannot reach the wrong squad.
var world: World
var list := {}
## Shells still in the air, on the server: {"at": time, "pos": target, "owner": sid}.
var shells: Array[Dictionary] = []
var _next_id := 1
var _sync_t := 0.0
var _bot_t := 0.0
var _rng := RandomNumberGenerator.new()


func enabled() -> bool:
	return world.mode.get("squads", false)


func squad_of(sid: int) -> Dictionary:
	for squad: Dictionary in list.values():
		if (squad["members"] as Array).has(sid):
			return squad
	return {}


func leads(s: Soldier) -> bool:
	var squad := squad_of(s.sid)
	return not squad.is_empty() and int(squad["leader"]) == s.sid


func same_squad(a: Soldier, b: Soldier) -> bool:
	var squad := squad_of(a.sid)
	return not squad.is_empty() and (squad["members"] as Array).has(b.sid)


# ---------------------------------------------------------------- membership

func create(s: Soldier) -> bool:
	if not enabled():
		return false
	var name_for := _free_name(s.team)
	if name_for == "":
		return false
	leave(s)
	var id := _next_id
	_next_id += 1
	list[id] = {
		"id": id, "team": s.team, "name": name_for, "leader": s.sid, "members": [s.sid], "charge": 0.0,
		"next_strike": Net.server_time() + C.STRIKE_FIRST_DELAY, "beacon": 0, "beacon_ready": 0.0, "beacon_lock": 0.0,
	}
	_sync()
	return true


func join(s: Soldier, id: int) -> bool:
	var squad: Dictionary = list.get(id, {})
	if squad.is_empty() or int(squad["team"]) != s.team or (squad["members"] as Array).size() >= MAX_MEMBERS or (squad["members"] as Array).has(s.sid):
		return false
	leave(s)
	if not list.has(id):
		return false
	(squad["members"] as Array).append(s.sid)
	_sync()
	return true


## Leaving hands the squad to its longest-serving member. The last one out closes it.
func leave(s: Soldier) -> void:
	var squad := squad_of(s.sid)
	if squad.is_empty():
		return
	var members: Array = squad["members"]
	members.erase(s.sid)
	if members.is_empty():
		_remove_beacon(squad)
		list.erase(squad["id"])
	elif int(squad["leader"]) == s.sid:
		squad["leader"] = members[0]
	_sync()


func _free_name(team: int) -> String:
	for candidate: String in NAMES:
		var taken := false
		for squad: Dictionary in list.values():
			taken = taken or (int(squad["team"]) == team and squad["name"] == candidate)
		if not taken:
			return candidate
	return ""


# ---------------------------------------------------------------- server tick

func tick(delta: float) -> void:
	if not enabled():
		return
	for squad: Dictionary in list.values():
		var size := (squad["members"] as Array).size()
		# A fuller squad calls in fire sooner, which is what makes squads worth joining.
		var rate := 100.0 / C.STRIKE_CHARGE_SECONDS * (1.0 + C.STRIKE_MEMBER_BONUS * (size - 1))
		squad["charge"] = minf(float(squad["charge"]) + delta * rate, 100.0)
	for i in range(shells.size() - 1, -1, -1):
		if Net.server_time() >= float(shells[i]["at"]):
			_land(shells[i])
			shells.remove_at(i)
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 1.0
		if not list.is_empty():
			_sync()
	_bot_t -= delta
	if _bot_t <= 0.0:
		_bot_t = 1.0
		_bots_attack_beacons()


func on_kill(attacker: Soldier) -> void:
	_add_charge(squad_of(attacker.sid), C.STRIKE_KILL_CHARGE)


func on_capture(pos: Vector3, team: int) -> void:
	for squad: Dictionary in list.values():
		if int(squad["team"]) != team:
			continue
		for sid: int in squad["members"]:
			var s: Soldier = world.soldiers.get(sid)
			if s and s.alive and s.global_position.distance_to(pos) < C.FLAG_RADIUS * 1.5:
				_add_charge(squad, C.STRIKE_CAPTURE_CHARGE)
				break


func _add_charge(squad: Dictionary, amount: float) -> void:
	if not squad.is_empty():
		squad["charge"] = minf(float(squad["charge"]) + amount, 100.0)


## Every round starts even: no stored charge, no beacons left over.
func reset() -> void:
	shells.clear()
	for squad: Dictionary in list.values():
		squad["charge"] = 0.0
		squad["next_strike"] = Net.server_time() + C.STRIKE_FIRST_DELAY
		squad["beacon"] = 0
		squad["beacon_ready"] = 0.0
		squad["beacon_lock"] = 0.0
	_sync()


# ---------------------------------------------------------------- artillery

## Why a strike cannot land at `target` right now, or "" if it can. Used by both sides, so the
## designator can warn the leader before the server refuses.
func strike_problem(s: Soldier, target: Vector3) -> String:
	var squad := squad_of(s.sid)
	if squad.is_empty() or int(squad["leader"]) != s.sid or not s.class_data().get("command", false):
		return "Artylerię wzywa dowódca oddziału."
	if not s.alive or s.is_vehicle():
		return "Musisz stać na ziemi."
	var wait := float(squad["next_strike"]) - Net.server_time()
	if wait > 0.0:
		return T.pack("Artyleria gotowa za %d s.", [int(ceil(wait))])
	if float(squad["charge"]) < 100.0:
		return T.pack("Artyleria naładowana w %d%%.", [int(squad["charge"])])
	if not target.is_finite():
		return "Nieprawidłowy cel."
	var reach := s.global_position.distance_to(target)
	if reach > C.STRIKE_RANGE:
		return T.pack("Cel poza zasięgiem (%d m).", [int(C.STRIKE_RANGE)])
	if reach < C.STRIKE_MIN_RANGE:
		return "Cel zbyt blisko ciebie."
	var bases: Array = world.map.bases()
	for team in bases.size():
		if team != s.team and (bases[team] as Vector3).distance_to(target) < C.STRIKE_BASE_SAFE:
			return "Strefa odrodzenia wroga jest chroniona."
	if not _sky_above(target):
		return "Pociski nie dolecą: nad celem nie ma otwartego nieba."
	return ""


func request_strike(s: Soldier, target: Vector3) -> bool:
	var problem := strike_problem(s, target)
	if problem == "" and not _sees(s, target):
		problem = "Nie widzisz tego miejsca."
	if problem != "":
		Net.send_to_owner(s, &"squad_notice", [problem])
		return false
	var squad := squad_of(s.sid)
	squad["charge"] = 0.0
	squad["next_strike"] = Net.server_time() + C.STRIKE_COOLDOWN
	var impact := Net.server_time() + C.STRIKE_WARNING
	for i in C.STRIKE_SHELLS:
		var angle := _rng.randf() * TAU
		var offset := Vector3(cos(angle), 0, sin(angle)) * sqrt(_rng.randf()) * C.STRIKE_SCATTER
		shells.append({"at": impact + i * C.STRIKE_INTERVAL, "pos": target + offset, "owner": s.sid})
	Net.broadcast(&"strike", [s.team, target, C.STRIKE_WARNING, squad["name"]])
	_sync()
	return true


func _sky_above(target: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 0.6, target + Vector3.UP * 90.0, C.LAYER_WORLD)
	return world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## A designator works by sight. A clear line, or a wall right at the target, both count.
func _sees(s: Soldier, target: Vector3) -> bool:
	var hit := world.server.world_ray(s.eye_position(), target + Vector3.UP * 0.4)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(target) < 4.0


func _land(shell: Dictionary) -> void:
	var owner: Soldier = world.soldiers.get(shell["owner"])
	if owner == null or not world.server.can_act():
		return
	var pos: Vector3 = shell["pos"]
	var hit := world.server.world_ray(pos + Vector3.UP * 90.0, pos + Vector3.DOWN * 30.0)
	if not hit.is_empty():
		pos = hit["position"]
	world.server.shell_blast(owner, pos)


# ---------------------------------------------------------------- beacon

func beacon_spot(s: Soldier) -> Vector3:
	var p := s.global_position + Basis(Vector3.UP, s.yaw) * Vector3.FORWARD * 2.4
	p.y = world.map.ground_height(p.x, p.z)
	return p


func beacon_problem(s: Soldier, pos: Vector3) -> String:
	var squad := squad_of(s.sid)
	if squad.is_empty() or int(squad["leader"]) != s.sid or not s.class_data().get("command", false):
		return "Punkt odrodzenia stawia dowódca oddziału."
	# Height, not is_on_floor: the server only hears a player's position, not their contacts.
	var feet := s.global_position
	if not s.alive or s.is_vehicle() or absf(feet.y - world.map.ground_height(feet.x, feet.z)) > 0.6:
		return "Musisz stać na ziemi."
	var wait := float(squad["beacon_ready"]) - Net.server_time()
	if wait > 0.0:
		return T.pack("Nowy punkt odrodzenia za %d s.", [int(ceil(wait))])
	var bases: Array = world.map.bases()
	for team in bases.size():
		if team != s.team and (bases[team] as Vector3).distance_to(pos) < C.BEACON_BASE_SAFE:
			return "Za blisko bazy wroga."
	for f: Dictionary in world.flags:
		if int(f["owner"]) != s.team and (f["pos"] as Vector3).distance_to(pos) < C.BEACON_FLAG_SAFE:
			return "Za blisko flagi, której nie trzymacie."
	if _foe_near(s.team, pos, C.BEACON_CONTEST):
		return "Wróg jest zbyt blisko."
	return world.forts.site_problem(Fortifications.BEACON, pos, s.yaw, s)


func place_beacon(s: Soldier) -> bool:
	var pos := beacon_spot(s)
	var problem := beacon_problem(s, pos)
	if problem != "":
		Net.send_to_owner(s, &"squad_notice", [problem])
		return false
	var squad := squad_of(s.sid)
	# A leader moves the squad's one beacon: the old one is taken down, not left standing.
	_remove_beacon(squad)
	squad["beacon"] = world.forts.place_beacon(s, pos, int(squad["id"]))
	squad["beacon_ready"] = Net.server_time() + C.BEACON_REPLACE_DELAY
	_sync()
	return true


func _remove_beacon(squad: Dictionary) -> void:
	var id := int(squad["beacon"])
	if id > 0 and world.forts.items.has(id):
		Net.broadcast(&"fort_removed", [id])
	squad["beacon"] = 0


## Called by the fortifications when enemy fire brings a beacon down.
func on_beacon_destroyed(fort_id: int, attacker: Soldier) -> void:
	for squad: Dictionary in list.values():
		if int(squad["beacon"]) == fort_id:
			squad["beacon"] = 0
			squad["beacon_ready"] = Net.server_time() + C.BEACON_LOST_DELAY
			if attacker:
				world.server.add_score(attacker, C.SCORE_BEACON, "PUNKT ODRODZENIA")
			_sync()
			return


func beacon_pos(squad: Dictionary) -> Variant:
	var id := int(squad.get("beacon", 0))
	return world.forts.items[id]["pos"] if id > 0 and world.forts.items.has(id) else null


## Why this soldier cannot come in at the squad's beacon, or "" if they can.
func spawn_problem(s: Soldier) -> String:
	var squad := squad_of(s.sid)
	var pos: Variant = beacon_pos(squad)
	if pos == null:
		return "Oddział nie ma punktu odrodzenia."
	if _foe_near(s.team, pos, C.BEACON_CONTEST):
		return "Punkt odrodzenia jest pod ostrzałem wroga."
	var wait := float(squad["beacon_lock"]) - Net.server_time()
	if wait > 0.0:
		return T.pack("Punkt odrodzenia gotowy za %d s.", [int(ceil(wait))])
	return ""


## Spreads a squad out in time, so a beacon cannot pour a whole squad onto a flag at once.
func take_beacon_spot(s: Soldier) -> Vector3:
	var squad := squad_of(s.sid)
	squad["beacon_lock"] = Net.server_time() + C.BEACON_SPAWN_GAP
	_sync()
	var pos: Vector3 = beacon_pos(squad)
	var angle := _rng.randf() * TAU
	var spot := pos + Vector3(cos(angle), 0, sin(angle)) * 2.4
	spot.y = world.map.ground_height(spot.x, spot.z) + 0.1
	return spot


func _foe_near(team: int, pos: Vector3, reach: float) -> bool:
	for o: Soldier in world.soldiers.values():
		if o.alive and o.team != team and o.global_position.distance_to(pos) < reach:
			return true
	return false


## Bots have no target list for objects, so one that can see a beacon simply shoots it.
func _bots_attack_beacons() -> void:
	for squad: Dictionary in list.values():
		var pos: Variant = beacon_pos(squad)
		if pos == null:
			continue
		var at: Vector3 = (pos as Vector3) + Vector3.UP
		for o: Soldier in world.soldiers.values():
			if o.peer != 0 or not o.alive or o.team == int(squad["team"]) or o.is_melee():
				continue
			if o.global_position.distance_to(at) > C.BEACON_BOT_RANGE:
				continue
			if not world.server.world_ray(o.eye_position(), at + (o.eye_position() - at).normalized() * 1.2).is_empty():
				continue
			Net.broadcast(&"shot", [o.sid, o.weapon_id(), o.eye_position(), at, 1, -1], false)
			world.forts.damage(int(squad["beacon"]), float(o.weapon()["damage"]), o, false)
			break


# ---------------------------------------------------------------- state

func snapshot() -> Array:
	return list.values()


func _sync() -> void:
	Net.broadcast(&"squads", [snapshot()])


func receive(data: Array) -> void:
	if not Net.is_server():
		list.clear()
		for squad: Dictionary in data:
			list[int(squad["id"])] = squad
	changed.emit()
