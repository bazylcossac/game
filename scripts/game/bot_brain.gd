class_name BotBrain
extends RefCounted
## Server-side soldier AI: picks objectives, walks the nav grid, and fights.

const SIGHT_RANGE := 115.0
const HEARING_RANGE := 12.0
const SIGHT_COS := 0.15

var s: Soldier
var m: MatchServer
var diff: Dictionary
var rng := RandomNumberGenerator.new()

var path := PackedVector3Array()
var path_i := 0
var objective := -1
var goal := Vector3.ZERO

var target: Soldier = null
var react_t := 0.0
var lost_t := 0.0
var think_t := 0.0
var repath_t := 0.0
var wander_t := 0.0
var stuck_t := 0.0
var stuck_count := 0
var check_pos := Vector3.ZERO
var strafe := 1.0
var strafe_t := 0.0
var burst_left := 0
var pause_t := 0.0
var grenade_t := 0.0
var respawn_at := 0.0
var preferred_class := 0
var aim_offset := Vector2.ZERO
var aim_offset_t := 0.0
var coin_id := -1
var tank_id := -1
## Where the mode's rules have sent this bot, in modes without flags.
var has_point := false
var point := Vector3.ZERO
var point_radius := 0.0
var roam_until := 0.0
## The objective cannot wait: keep moving and fire on the way, instead of stopping to fight.
var rush := false


func setup(soldier: Soldier, server: MatchServer, difficulty: Dictionary) -> void:
	s = soldier
	m = server
	diff = difficulty
	rng.seed = soldier.sid * 7919 + 17
	var roll := rng.randf()
	if roll < 0.5:
		preferred_class = 0
	elif roll < 0.68:
		preferred_class = 1
	elif roll < 0.84:
		preferred_class = 2
	else:
		preferred_class = 3
	respawn_at = Net.server_time() + rng.randf_range(0.2, 2.5)


func reset() -> void:
	target = null
	path = PackedVector3Array()
	objective = -1
	coin_id = -1
	tank_id = -1
	has_point = false
	roam_until = 0.0
	rush = false
	respawn_at = Net.server_time() + rng.randf_range(0.5, 3.0)


func on_damaged(attacker: Soldier) -> void:
	if attacker == null or not attacker.alive:
		return
	if target == null or not target.alive:
		target = attacker
		react_t = float(diff["reaction"]) * 0.6
		lost_t = 0.0


func tick(delta: float) -> void:
	if not s.alive:
		_tick_dead()
		return
	if not m.rules.can_act():
		s.wish = Vector3.ZERO
		s.aiming = false
		s.blocking = false
		return
	if s.world.forts and s.world.forts.pending.has(s.sid):
		s.wish = Vector3.ZERO
		s.aiming = false
		return
	think_t -= delta
	if think_t <= 0.0:
		think_t = rng.randf_range(0.22, 0.38)
		_scan()
		_review_objective()
		_review_coin()
		_maybe_go_super()
		_review_tank()
		if s.is_gunner() and s.world.vehicle_for(s.sid).get("driver", 0) == 0:
			m.switch_seat(s)
	if target != null:
		_fight(delta)
	else:
		s.aiming = false
		s.blocking = false
		s.want_crouch = false
		s.want_fly = false
		_face_movement(delta)
		if s.slot != 0 and s.mags[0] > 0:
			s.switch_to(0)
		if s.can_reload() and s.mags[s.slot] < int(s.weapon()["mag"]) / 2:
			s.start_reload()
	_navigate(delta)


func _tick_dead() -> void:
	s.wish = Vector3.ZERO
	target = null
	if m.round_over or not m.rules.may_deploy(s) or Net.server_time() < respawn_at or Net.server_time() - s.death_time < C.RESPAWN_DELAY:
		return
	if rng.randf() < 0.3:
		var roll := rng.randf()
		preferred_class = 0 if roll < 0.5 else (1 if roll < 0.68 else (2 if roll < 0.84 else 3))
	var tank := _unclaimed_tank()
	m.spawn(s, preferred_class, -1 if tank >= 0 else _best_spawn())
	respawn_at = 0.0
	objective = -1
	path = PackedVector3Array()
	if tank >= 0:
		tank_id = tank
		s.world.vehicles[tank]["claimed_by"] = s.sid
		_set_goal()


## A tank nobody has used for a while. Bots respawn at base to crew it, so a human gets
## the first chance and a team never leaves its armour parked for the whole round.
func _unclaimed_tank() -> int:
	if preferred_class == 2 and s.team == C.Team.RESISTANCE:
		return -1  # Snipers stay on foot.
	var now := Net.server_time()
	for id: int in s.world.vehicles:
		var v: Dictionary = s.world.vehicles[id]
		if v["team"] != s.team or v.get("kind", 0) == 1 or (v["driver"] != 0 and v.get("gunner", 0) != 0) or float(v["hp"]) <= 0.0:
			continue
		if now - float(v["free_since"]) <= C.BOT_TANK_WAIT:
			continue
		var owner: Soldier = s.world.soldiers.get(int(v.get("claimed_by", 0)))
		if owner == null or not owner.alive or owner.is_vehicle():
			return id
	return -1


func _best_spawn() -> int:
	# Prefer the owned flag nearest the front line: any flag the team does not hold.
	var best := -1
	var best_d := INF
	for i in s.world.flags.size():
		var f: Dictionary = s.world.flags[i]
		if f["owner"] != s.team:
			continue
		var fp: Vector3 = f["pos"]
		for j in s.world.flags.size():
			if s.world.flags[j]["owner"] == s.team:
				continue
			var d: float = fp.distance_to(s.world.flags[j]["pos"]) + rng.randf_range(0.0, 40.0)
			if d < best_d:
				best_d = d
				best = i
	return best


# ---------------------------------------------------------------- perception

func _scan() -> void:
	if target != null:
		if not target.alive:
			target = null
		else:
			var visible := _can_see(target)
			lost_t = 0.0 if visible else lost_t + 0.3
			if lost_t > 2.2:
				target = null
	if target != null:
		return
	var eye := s.eye_position()
	var facing := s.aim_direction()
	facing.y = 0.0
	facing = facing.normalized()
	var candidates: Array = []
	for o: Soldier in s.world.soldiers.values():
		if not o.alive or not s.world.are_foes(s, o) or o.protected_t > 0.0:
			continue
		if o.riding >= 0:
			continue
		var to := o.global_position - s.global_position
		var d := to.length()
		var sight := 300.0 if s.is_vehicle() else SIGHT_RANGE
		if d > (C.CLOAK_SIGHT_RANGE if o.is_cloaked() else sight):
			continue
		if d > (HEARING_RANGE * 0.4 if o.has_perk("quiet") else HEARING_RANGE):
			var flat := Vector3(to.x, 0.0, to.z).normalized()
			if flat.dot(facing) < SIGHT_COS:
				continue
		candidates.append([d, o])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in mini(candidates.size(), 3):
		var o: Soldier = candidates[i][1]
		if _can_see(o):
			target = o
			var d: float = candidates[i][0]
			react_t = float(diff["reaction"]) * rng.randf_range(0.8, 1.3) * (1.0 + d / 90.0)
			lost_t = 0.0
			burst_left = 0
			return


func _can_see(o: Soldier) -> bool:
	var from := s.eye_position()
	var to := o.global_position + Vector3.UP * (o.stance_height() * 0.8)
	return m.world_ray(from, to).is_empty() and not s.world.areas.blocks_sight(from, to)


# ---------------------------------------------------------------- objectives

func _review_objective() -> void:
	var flags: Array = s.world.flags
	if flags.is_empty():
		m.rules.bot_think(self)
		return
	if objective >= 0:
		var f: Dictionary = flags[objective]
		var inside: bool = s.global_position.distance_to(f["pos"]) < C.FLAG_RADIUS
		var done: bool = f["owner"] == s.team and absf(float(f["value"])) >= 0.999
		if done and (inside or rng.randf() < 0.05):
			objective = -1
	if objective < 0:
		_pick_objective()


func _pick_objective() -> void:
	var flags: Array = s.world.flags
	var best := -1
	var best_score := INF
	for i in flags.size():
		var f: Dictionary = flags[i]
		var d: float = s.global_position.distance_to(f["pos"])
		var score := d + rng.randf_range(0.0, 90.0)
		var mine: bool = f["owner"] == s.team
		if mine:
			var contested := absf(float(f["value"])) < 0.98
			# A kilometre-wide battlefield must not make a captured nearby flag
			# permanently preferable to every neutral objective across the valley.
			score += -30.0 if contested else (2000.0 if s.is_vehicle() else 180.0)
		if s.is_vehicle():
			for ally: BotBrain in m.bots:
				if ally != self and ally.s.alive and ally.s.team == s.team and ally.objective == i:
					score += 110.0
		if score < best_score:
			best_score = score
			best = i
	objective = best
	_set_goal()


## Bots grab coins that happen to be nearby, so players still have a fair race for them.
func _review_coin() -> void:
	var coins: Dictionary = s.world.coins
	if coin_id >= 0 and (not coins.has(coin_id) or s.coins > 0):
		coin_id = -1
		_set_goal()
	if coin_id >= 0 or target != null or s.coins > 0 or s.is_super():
		return
	for id: int in coins:
		var pos: Vector3 = coins[id]["pos"]
		if s.global_position.distance_to(pos) < 55.0:
			coin_id = id
			_set_goal()
			return


## Tanks left unused for a while are fair game, so a human always gets the first chance.
func _review_tank() -> void:
	if s.is_super():
		tank_id = -1
		return
	var tanks: Dictionary = s.world.vehicles
	if tank_id >= 0:
		var v: Dictionary = tanks.get(tank_id, {})
		if v.is_empty() or (v["driver"] != 0 and v.get("gunner", 0) != 0) or float(v["hp"]) <= 0.0:
			tank_id = -1
			_set_goal()
		elif s.global_position.distance_to(v["pos"]) < C.TANK_ENTER_RANGE:
			if m.enter_vehicle(s, tank_id):
				path = PackedVector3Array()
				repath_t = 0.0
			tank_id = -1
		return
	if target != null or coin_id >= 0:
		return
	var nearby := _unclaimed_tank()
	if nearby >= 0 and s.global_position.distance_to(tanks[nearby]["pos"]) < 35.0:
		tank_id = nearby
		tanks[nearby]["claimed_by"] = s.sid
		_set_goal()


func _maybe_go_super() -> void:
	if s.coins <= 0 or s.is_super():
		return
	var pick := C.SUPER_MECH if rng.randf() < 0.55 else C.SUPER_SPECIAL
	if pick == C.SUPER_MECH and not m.mech_fits(s.global_position):
		return
	m.activate_super(s, pick)
	path = PackedVector3Array()
	repath_t = 0.0


## Sends the bot to a spot of the rules' choosing, within `radius` of it.
func go_to(pos: Vector3, radius: float) -> void:
	has_point = true
	point = pos
	point_radius = radius
	_set_goal()


func _nav() -> NavGrid:
	if s.is_vehicle():
		return s.world.map.b.nav_tank
	return s.world.map.b.nav_wide if s.is_mech() else s.world.map.b.nav


func _set_goal() -> void:
	if coin_id >= 0 and s.world.coins.has(coin_id):
		goal = s.world.coins[coin_id]["pos"]
		repath_t = 0.0
		wander_t = 8.0
		return
	if tank_id >= 0 and s.world.vehicles.has(tank_id):
		goal = s.world.vehicles[tank_id]["pos"]
		repath_t = 0.0
		wander_t = 8.0
		return
	if has_point:
		var turn := rng.randf() * TAU
		var away := rng.randf_range(0.0, point_radius)
		goal = point + Vector3(cos(turn) * away, 0.0, sin(turn) * away)
		repath_t = 0.0
		wander_t = rng.randf_range(3.0, 7.0)
		return
	if objective < 0:
		return
	var center: Vector3 = s.world.flags[objective]["pos"]
	var ang := rng.randf() * TAU
	var r := rng.randf_range(2.0, C.FLAG_RADIUS * 0.7)
	goal = center + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
	repath_t = 0.0
	wander_t = rng.randf_range(4.0, 9.0)


# ---------------------------------------------------------------- movement

func _navigate(delta: float) -> void:
	repath_t -= delta
	if (objective >= 0 or has_point) and repath_t <= 0.0:
		var u0 := Time.get_ticks_usec()
		path = _nav().find_path(s.global_position, goal)
		if Time.get_ticks_usec() - u0 > 3000:
			print("[spike] path ", (Time.get_ticks_usec() - u0) / 1000.0, " ", s.global_position, " -> ", goal, " n=", path.size(), " tank=", s.is_vehicle(), " mech=", s.is_mech())
		path_i = 0
		repath_t = rng.randf_range(5.0, 8.0)
	var holding := target != null and _should_hold_position()
	var move := Vector3.ZERO
	if not holding and path_i < path.size():
		var wp := path[path_i]
		var to := Vector3(wp.x - s.global_position.x, 0.0, wp.z - s.global_position.z)
		if to.length() < (2.5 if s.is_vehicle() else 0.9):
			path_i += 1
		else:
			move = to.normalized()
	elif not holding:
		# Arrived: mill about inside the capture zone.
		wander_t -= delta
		if wander_t <= 0.0:
			_set_goal()

	if target != null:
		strafe_t -= delta
		if strafe_t <= 0.0:
			strafe_t = rng.randf_range(0.5, 1.5)
			strafe = -strafe if rng.randf() < 0.65 else strafe
		var to_t := target.global_position - s.global_position
		to_t.y = 0.0
		var side := Vector3(-to_t.z, 0.0, to_t.x).normalized() * strafe
		if s.is_melee():
			move = to_t.normalized()
		elif s.is_vehicle():
			if holding:
				move = Vector3.ZERO
		elif holding:
			move = side * 0.8
		else:
			move = (move * 0.6 + side * 0.6).normalized()
	s.wish = move
	s.want_sprint = target == null or s.is_melee()
	_check_stuck(delta, move)


func _should_hold_position() -> bool:
	if s.is_melee() or rush:
		return false
	var d := s.global_position.distance_to(target.global_position)
	if s.is_vehicle():
		if objective >= 0 and s.world.flags[objective]["owner"] != s.team and Vector2(s.position.x - goal.x, s.position.z - goal.z).length() > C.FLAG_RADIUS * .8:
			return false
		return d < 65.0
	var max_engage: float = 28.0 if s.weapon_id() == C.W.PISTOL else 55.0
	if s.weapon_id() == C.W.SNIPER:
		return true
	if s.weapon_id() == C.W.SCATTER:
		max_engage = 14.0
	return d < max_engage


func _check_stuck(delta: float, move: Vector3) -> void:
	stuck_t += delta
	if stuck_t < 1.0:
		return
	stuck_t = 0.0
	var moved := s.global_position.distance_to(check_pos)
	check_pos = s.global_position
	if move.length_squared() < 0.1 or moved > 0.6:
		stuck_count = 0
		return
	stuck_count += 1
	s.want_jump = true
	if s.is_vehicle():
		s.reverse_t = 1.2
	if stuck_count >= 2:
		# Likely wedged on a corner: try a fresh route to a different point.
		stuck_count = 0
		_set_goal()


func _face_movement(delta: float) -> void:
	var v := s.wish
	if v.length_squared() < 0.01:
		return
	var want := atan2(-v.x, -v.z)
	s.yaw = lerp_angle(s.yaw, want, minf(float(diff["turn"]) * delta, 1.0))
	s.pitch = lerpf(s.pitch, 0.0, minf(4.0 * delta, 1.0))


# ---------------------------------------------------------------- combat

func _fight(delta: float) -> void:
	if not target.alive:
		target = null
		return
	var aim_at := target.global_position + Vector3.UP * (target.stance_height() * 0.72)
	var eye := s.eye_position()
	var to := aim_at - eye
	var dist := to.length()
	_pick_weapon(dist)

	# Aim wanders a little, so bots miss in a human-looking way.
	aim_offset_t -= delta
	if aim_offset_t <= 0.0:
		aim_offset_t = rng.randf_range(0.15, 0.4)
		var err := deg_to_rad(float(diff["aim_error"]))
		aim_offset = Vector2(rng.randf_range(-err, err), rng.randf_range(-err, err) * 0.7)

	var want_yaw := atan2(-to.x, -to.z) + aim_offset.x
	var want_pitch := atan2(to.y, Vector2(to.x, to.z).length()) + aim_offset.y
	var turn := minf(float(diff["turn"]) * delta * 1.6, 1.0)
	s.yaw = lerp_angle(s.yaw, want_yaw, turn)
	s.pitch = lerpf(s.pitch, want_pitch, turn)

	react_t -= delta
	if react_t > 0.0:
		return

	if s.is_melee():
		if dist < float(s.weapon()["range"]) - 0.1 and s.can_swing():
			_swing()
		s.want_fly = dist > 5.0 and dist < 34.0 and s.jet_fuel > 0.6
		s.blocking = dist > 3.5 and dist < 22.0 and s.stamina > 2.0 and rng.randf() < 0.02 or s.blocking and dist > 3.5 and s.stamina > 1.0
		return

	if s.mags[s.slot] <= 0:
		if s.can_reload():
			s.start_reload()
		elif s.slot == 0:
			s.switch_to(1)
		else:
			s.switch_to(2)
		return

	s.want_crouch = s.weapon_id() == C.W.SNIPER and dist > 30.0
	s.aiming = dist > 18.0
	if pause_t > 0.0:
		pause_t -= delta
		return
	if absf(angle_difference(s.yaw, want_yaw)) > 0.25:
		return
	if lost_t > 0.0:
		return
	if s.can_fire():
		_fire(dist)
	_maybe_grenade(dist)


func _pick_weapon(dist: float) -> void:
	if s.is_gunner():
		return
	if s.loadout.has(C.W.AT_ROCKET):
		if target.is_vehicle() and dist > 12 and (s.mags[3] > 0 or s.reserves[3] > 0):
			s.switch_to(3)
			return
		if s.slot == 3:
			s.switch_to(0)
	if s.loadout.has(C.W.ARM_ROCKETS):
		# The liquidator: rockets for armour, mechs and close packs, the cannon for the rest.
		var armour: bool = target.is_vehicle() or target.is_mech()
		var has_rockets: bool = s.mags[1] > 0 or s.reserves[1] > 0
		var want_arm := 1 if has_rockets and dist > 8.0 and (armour or (s.mags[0] <= 0 and s.reserves[0] <= 0)) else 0
		if s.slot != want_arm:
			s.switch_to(want_arm)
		return
	var melee := s.melee_slot()
	if melee < 0:
		# Tanks: the machine gun for infantry up close, the main gun for the rest.
		var close_infantry := dist < 22.0 and not target.is_vehicle() and not target.is_mech()
		var want_slot := 1 if close_infantry or (s.mags[0] <= 0 and s.reserves[0] <= 0) else 0
		if s.is_mech():
			# The launcher is for armour and for groups at range, while it has shells.
			var has_shells: bool = s.mags[1] > 0 or s.reserves[1] > 0
			want_slot = 1 if has_shells and dist > 18.0 and (target.is_vehicle() or target.is_mech() or rng.randf() < 0.02) else 0
		if s.slot != want_slot:
			s.switch_to(want_slot)
		return
	if s.class_data().get("melee_first", false):
		var want := 1 if dist > 26.0 and s.mags[1] > 0 else 0
		if s.slot != want:
			s.switch_to(want)
	elif dist < float(s.melee_weapon()["range"]) + 0.2 and s.slot != melee:
		s.switch_to(melee)
	elif dist > 6.0 and s.slot == melee:
		s.switch_to(0 if s.mags[0] > 0 or s.reserves[0] > 0 else 1)


func _fire(dist: float) -> void:
	var w := s.weapon()
	s.consume_shot()
	var spread := deg_to_rad(float(w["spread_ads"] if s.aiming else w["spread_hip"]) * 0.6)
	for i in int(w.get("pellets", 1)):
		var dir := s.aim_direction()
		dir = dir.rotated(Vector3.UP, rng.randf_range(-spread, spread))
		dir = dir.rotated(dir.cross(Vector3.UP).normalized(), rng.randf_range(-spread, spread))
		m.resolve_shot(s, s.eye_position(), dir.normalized(), Net.server_time())
	if w["auto"]:
		if burst_left <= 0:
			burst_left = rng.randi_range(4, 9)
		burst_left -= 1
		if burst_left <= 0:
			pause_t = float(diff["burst_pause"]) * rng.randf_range(0.7, 1.4) * (1.0 + dist / 60.0)
	else:
		pause_t = float(diff["burst_pause"]) * rng.randf_range(0.5, 1.2)


func _swing() -> void:
	s.fire_cd = s.weapon()["rate"]
	s.blocking = false
	if not s.is_mech() and not s.is_vehicle():
		s.lunge_t = 0.12
		s.lunge_dir = Vector3(s.aim_direction().x, 0.0, s.aim_direction().z).normalized()
	m.resolve_swing(s, s.aim_direction(), Net.server_time())


func _maybe_grenade(dist: float) -> void:
	grenade_t -= 0.016
	if dist < 11.0 or dist > 30.0 or s.grenade_cd > 0.0 or s.reload_t > 0.0 or grenade_t > 0.0:
		return
	if rng.randf() > 0.004:
		return
	# Hurt and under fire, a bot covers itself. Otherwise it reaches for whatever hurts most.
	var hurt: bool = s.hp < s.max_hp * 0.5 and s.nades[C.NADE_SMOKE] > 0
	var kind: int = C.NADE_SMOKE if hurt else (C.NADE_FRAG if s.nades[C.NADE_FRAG] > 0 else C.NADE_FIRE)
	if s.nades[kind] <= 0:
		return
	s.nades[kind] -= 1
	s.grenade_cd = 1.0
	grenade_t = 12.0
	var dir := s.aim_direction() + Vector3.UP * 0.22
	m.throw_grenade(s, s.eye_position(), dir.normalized(), kind)
