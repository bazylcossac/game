class_name ConquestRules
extends ModeRules
## Podbój and Wojna czołgów: flags and tickets. In the tank war every soldier lives and
## dies in a tank, which is the only other difference.

var _bleed_t := [0.0, 0.0]


func start() -> void:
	var tickets := Modes.score_limit(w.cfg)
	w.tickets = [tickets, tickets]
	for f: Dictionary in w.flags:
		var start_owner: int = f["start_owner"]
		f["owner"] = start_owner
		f["value"] = 0.0 if start_owner < 0 else (-1.0 if start_owner == 0 else 1.0)


func tick(delta: float) -> void:
	_tick_bleed(delta)


func tick_slow(dt: float) -> void:
	_tick_flags(dt)


func can_leave_vehicle() -> bool:
	return not mode.get("tanks_only", false)


func tank_respawn_delay() -> float:
	# The tank war hands out a fresh tank at every spawn, so wrecks never come back.
	return INF if mode.get("tanks_only", false) else C.TANK_RESPAWN


func spawn_point(s: Soldier, flag_idx: int) -> Vector3:
	var center: Vector3 = w.map.bases()[s.team]
	var spread := 22.0
	if m.can_spawn_at(s.team, flag_idx):
		center = w.flags[flag_idx]["pos"]
		spread = C.FLAG_RADIUS * 0.9
	if mode.get("tanks_only", false):
		for attempt in 48:
			var candidate := w.map.spawn_point_near(center, spread * (1.0 if attempt < 32 else 1.7), m.rng, w.map.b.nav_tank)
			if w.vehicle_spawn_clear(candidate):
				return candidate
	return w.map.spawn_point_near(center, spread, m.rng, w.map.b.nav_tank if mode.get("tanks_only", false) else w.map.b.nav)


func on_spawned(s: Soldier) -> void:
	if mode.get("tanks_only", false):
		m.crew_tank(s)


func on_death(v: Soldier, _attacker: Soldier) -> void:
	_lose_ticket(v.team)


func _tick_flags(dt: float) -> void:
	for i in w.flags.size():
		var f: Dictionary = w.flags[i]
		var pos: Vector3 = f["pos"]
		var n := [0, 0]
		for s: Soldier in w.soldiers.values():
			if s.alive and Vector2(s.global_position.x - pos.x, s.global_position.z - pos.z).length() < C.FLAG_RADIUS and absf(s.global_position.y - pos.y) < 12.0:
				n[s.team] += 1
		var diff: int = n[1] - n[0]
		var value: float = f["value"]
		var old_owner: int = f["owner"]
		if diff != 0:
			var rate := (1.0 + 0.35 * (mini(absi(diff), 4) - 1)) / C.CAPTURE_TIME
			value = clampf(value + signf(diff) * rate * dt, -1.0, 1.0)
		elif n[0] == 0 and n[1] == 0:
			# Unattended flags drift back to whoever holds them.
			var rest := 0.0 if old_owner < 0 else (-1.0 if old_owner == 0 else 1.0)
			value = move_toward(value, rest, dt / (C.CAPTURE_TIME * 2.0))
		f["value"] = value
		var new_owner := old_owner
		if value <= -1.0:
			new_owner = C.Team.RESISTANCE
		elif value >= 1.0:
			new_owner = C.Team.EMPIRE
		elif old_owner == C.Team.RESISTANCE and value >= 0.0:
			new_owner = C.NEUTRAL
		elif old_owner == C.Team.EMPIRE and value <= 0.0:
			new_owner = C.NEUTRAL
		if new_owner != old_owner:
			f["owner"] = new_owner
			Net.broadcast(&"flag_changed", [i, new_owner, old_owner])
			if new_owner >= 0:
				_reward_capture(pos, new_owner)
				w.squads.on_capture(pos, new_owner)
	# Offline and host games read the flag dictionaries directly; clients use snapshots.


func _reward_capture(pos: Vector3, team: int) -> void:
	for s: Soldier in w.soldiers.values():
		if s.alive and s.team == team and s.global_position.distance_to(pos) < C.FLAG_RADIUS + 3.0:
			m.add_score(s, C.SCORE_CAPTURE, "ZDOBYCIE FLAGI")


func _tick_bleed(delta: float) -> void:
	var owned := [0, 0]
	for f: Dictionary in w.flags:
		if f["owner"] >= 0:
			owned[f["owner"]] += 1
	var table: Dictionary = mode["bleed"]
	for team in 2:
		var enemy := 1 - team
		var period := 0.0
		for need: int in table:
			if owned[team] >= need:
				period = table[need]
		if period <= 0.0 or owned[team] <= owned[enemy]:
			_bleed_t[enemy] = 0.0
			continue
		_bleed_t[enemy] += delta
		if _bleed_t[enemy] >= period:
			_bleed_t[enemy] = 0.0
			_lose_ticket(enemy)


func _lose_ticket(team: int) -> void:
	w.tickets[team] = maxi(w.tickets[team] - 1, 0)
	if w.tickets[team] <= 0 and not m.round_over:
		m.end_match(1 - team)
