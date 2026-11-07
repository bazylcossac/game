class_name World
extends Node3D
## One running match. Holds shared state; on a client this mirrors the server through
## the `on_*` event handlers, which also run on the server itself.

signal leave_requested

var cfg := {}
## The row of `Modes.LIST` this match plays by.
var mode := {}
## Free-for-all: nobody is on anyone's side, whatever `team` says.
var ffa := false
var score_limit := C.START_TICKETS
var map: MapKit
var soldiers := {}
var flags: Array[Dictionary] = []
## Each side's score. What it counts depends on the mode, see the rules classes.
var tickets := [C.START_TICKETS, C.START_TICKETS]
var server: MatchServer = null
var forts: Fortifications
var squads: Squads
var areas: GrenadeAreas
var fx: Fx = null
var hud: Hud = null
var controller: PlayerController = null
var local: Soldier = null
var sun: DirectionalLight3D
var spotted := {}
var round_winner := -1
var flag_views: Array[Dictionary] = []
var hits_confirmed := 0
var _lights: Array[SpotLight3D] = []
var _sweep := 0.0
var level := 1
var xp := 0
## Shots drawn here, per shooter. Used by the network test.
var shots_seen := {}
## id -> {"pos": Vector3, "node": CoinPickup or null}
var coins := {}
## id -> {"team", "pos", "yaw", "hp", "driver", "node"}; server keeps extra fields here too.
var vehicles := {}

var thermal_on := false
var _thermal_wait := 0.0
var _hot: ShaderMaterial
var _grenades := {}
var rockets := {}


func setup(new_cfg: Dictionary) -> void:
	cfg = Modes.normalize(new_cfg)
	mode = Modes.mode_of(cfg)
	ffa = mode.get("ffa", false)
	score_limit = Modes.score_limit(cfg)


func _ready() -> void:
	# Update remote/parked hulls before characters run their movement step.
	process_physics_priority = -20
	var view := Net.has_view()
	map = Modes.create_map(cfg)
	map.build(self, int(cfg.get("seed", 1943)), not view)
	if mode.get("flags", false):
		for def: Dictionary in map.flag_defs():
			var pos: Vector3 = def["pos"]
			flags.append({
				"name": def["name"], "letter": def["letter"], "start_owner": def["owner"], "owner": def["owner"],
				"value": 0.0, "pos": Vector3(pos.x, map.ground_height(pos.x, pos.z), pos.z),
			})
	forts = Fortifications.new()
	forts.world = self
	add_child(forts)
	squads = Squads.new()
	squads.world = self
	add_child(squads)
	areas = GrenadeAreas.new()
	areas.world = self
	add_child(areas)
	if view:
		sun = Atmos.setup(self, cfg["map"])
		MachineModel.warm()
		SoldierModel.warm_bodies()
		Sfx.preload_all()
		fx = Fx.new()
		add_child(fx)
		for p: Vector3 in map.fires:
			fx.add_fire(p)
		for p: Vector3 in map.smokes:
			fx.add_smoke(p)
		_build_lamps()
		var sky := map.weather()
		if not sky.is_empty():
			var weather := Weather.new()
			add_child(weather)
			weather.setup(self, sky)
		_build_empire_dressing()
		_build_flag_views()
		controller = PlayerController.new()
		controller.world = self
		add_child(controller)
		fx.add_ash(controller.camera)
		hud = Hud.new()
		hud.world = self
		add_child(hud)
		var ambience := {"neonowa_dzielnica": "ambient_neon", "stacja_rdzen": "ambient_station", "ziemia_niczyja": "ambient_storm"}
		Sfx.play_ambient(ambience.get(cfg["map"], "ambient_battle"), -17.0 if cfg["map"] == "neonowa_dzielnica" else (-11.0 if cfg["map"] == "ziemia_niczyja" else -8.0))
	if Net.is_server():
		server = MatchServer.new()
		add_child(server)
		server.setup(self)
	Net.world = self
	if view:
		Net.send_ready()


func _exit_tree() -> void:
	Sfx.stop_ambient()


func _physics_process(_delta: float) -> void:
	for id: int in vehicles:
		_sync_vehicle_collider(vehicles[id])
		var gunner: Soldier = soldiers.get(vehicles[id].get("gunner", 0))
		if gunner and gunner.alive:
			sync_gunner(gunner)
			# A gunner climbing in takes the roof gun out of a lone driver's hands.
			var driver: Soldier = soldiers.get(vehicles[id]["driver"])
			if driver and driver.slot == C.TANK_ROOF_SLOT:
				driver.switch_to(0)


## Room for one more: a carrier takes a driver and passengers, a tank a driver, a gunner and passengers.
func has_room(v: Dictionary) -> bool:
	var riders := (v["riders"] as Array).size()
	if v.get("kind", 0) == 1:
		return v["driver"] == 0 or riders < C.APC_SEATS
	return v["driver"] == 0 or v.get("gunner", 0) == 0 or riders < C.TANK_RIDERS


func vehicle_for(sid: int) -> Dictionary:
	for id: int in vehicles:
		if vehicles[id]["driver"] == sid or vehicles[id].get("gunner", 0) == sid:
			return vehicles[id]
	return {}


## The tank on screen for a vehicle: the driver's own model, or the parked one when nobody drives.
func tank_view(v: Dictionary) -> TankModel:
	var driver: Soldier = soldiers.get(v["driver"])
	return driver.model as TankModel if driver and driver.model else v.get("node")


## True for a driver whose roof gun already has a gunner behind it.
func roof_taken(s: Soldier) -> bool:
	var v := vehicle_for(s.sid)
	return not v.is_empty() and int(v["driver"]) == s.sid and int(v.get("gunner", 0)) != 0


func gunner_tank(s: Soldier) -> TankModel:
	var v := vehicle_for(s.sid)
	return null if v.is_empty() else tank_view(v)


func sync_gunner(s: Soldier) -> void:
	var v := vehicle_for(s.sid)
	if v.is_empty():
		return
	var driver: Soldier = soldiers.get(v["driver"])
	s.global_position = driver.global_position if driver and driver.alive else v["pos"]
	s.hull_yaw = driver.hull_yaw if driver and driver.alive else float(v["yaw"])
	s.velocity = driver.velocity if driver and driver.alive else Vector3.ZERO
	s.hp = driver.hp if driver and driver.alive else float(v["hp"])


func shares_driver_armor(s: Soldier) -> bool:
	return s.riding >= 0 or (s.is_gunner() and vehicle_for(s.sid).get("driver", 0) != 0)


func collider_for_driver(sid: int) -> TankCollider:
	for id: int in vehicles:
		if vehicles[id]["driver"] == sid:
			return vehicles[id]["collider"]
	return null


func vehicle_spawn_clear(pos: Vector3) -> bool:
	for v: Dictionary in vehicles.values():
		if float(v["hp"]) <= 0:
			continue
		var p: Vector3 = v["pos"]
		if Vector2(pos.x - p.x, pos.z - p.z).length_squared() < 8.5 * 8.5:
			return false
	return true


func _sync_vehicle_collider(v: Dictionary) -> void:
	var driver: Soldier = soldiers.get(v["driver"])
	# A driver only speaks for the tank once they are in it: until the class swaps over, their
	# health and position are still the soldier's.
	var occupied := driver != null and driver.alive and driver.is_vehicle()
	var pos: Vector3 = driver.global_position if occupied else v["pos"]
	var yaw: float = driver.hull_yaw if occupied else v["yaw"]
	var intact := driver.hp > 0.0 if occupied else float(v["hp"]) > 0.0
	if occupied:
		v["pos"] = pos
		v["yaw"] = yaw
		v["hp"] = driver.hp
	(v["collider"] as TankCollider).update_hull(pos, yaw, intact, driver)


func _process(delta: float) -> void:
	if fx == null:
		return
	_sweep += delta
	# A crew can sit in thermal for minutes, while soldiers respawn and tanks change hands.
	if thermal_on:
		_thermal_wait -= delta
		if _thermal_wait <= 0.0:
			_thermal_wait = 1.0
			_paint_thermal(true)
	for i in _lights.size():
		_lights[i].rotation = Vector3(-0.32 + sin(_sweep * 0.3 + i) * 0.12, sin(_sweep * 0.22 + i * 1.7) * 1.3 + i * 1.6, 0.0)
	for i in flags.size():
		_update_flag_view(i, delta)
	for id: int in vehicles:
		var v: Dictionary = vehicles[id]
		var gunner: Soldier = soldiers.get(v.get("gunner", 0))
		var tank := tank_view(v)
		if tank:
			tank.set_gunner_aim(gunner.yaw if gunner else float(v["yaw"]), gunner.pitch if gunner else 0.0, gunner != null and gunner.alive)


func camera_position() -> Vector3:
	return controller.camera.global_position if controller else Vector3.ZERO


func handle_event(event: StringName, args: Array) -> void:
	var u0 := Time.get_ticks_usec()
	callv("on_" + event, args)
	var us := Time.get_ticks_usec() - u0
	if us > 3000:
		print("[spike] ", event, " ", us / 1000.0, " args0=", args[0] if args.size() > 0 else "-", " a3=", args[3] if args.size() > 3 else "-")


## Whether these two may hurt each other. Every check of friend and foe comes through here.
func are_foes(a: Soldier, b: Soldier) -> bool:
	return a != b if ffa else a.team != b.team


## How a soldier reads on the HUD. In a free-for-all everyone wears the same colours.
func side_color(s: Soldier) -> Color:
	if not ffa:
		return C.TEAM_COLORS[s.team]
	return UiKit.BRASS if s == local else UiKit.RED


## Where a team starts.
func home_of(team: int) -> Vector3:
	return map.bases()[team]


func soldier_for_peer(peer: int) -> Soldier:
	for s: Soldier in soldiers.values():
		if s.peer == peer:
			return s
	return null


func add_soldier(sid: int, peer: int, team: int, pname: String) -> Soldier:
	var s := Soldier.new()
	var mode: int = Soldier.Driver.BOT
	var mine := peer != 0 and peer == multiplayer.get_unique_id()
	if mine:
		mode = Soldier.Driver.LOCAL
	elif Net.is_server():
		mode = Soldier.Driver.PROXY_SERVER if peer != 0 else Soldier.Driver.BOT
	else:
		mode = Soldier.Driver.PROXY_VIEW
	s.setup(self, sid, peer, team, pname, mode)
	soldiers[sid] = s
	add_child(s)
	s.global_position = Vector3(0, -50, 0)
	return s


func remove_soldier(sid: int) -> void:
	var s: Soldier = soldiers.get(sid)
	if s == null:
		return
	soldiers.erase(sid)
	if s == local:
		local = null
	s.queue_free()


# ---------------------------------------------------------------- snapshots

func build_roster() -> Array:
	var out := []
	for s: Soldier in soldiers.values():
		out.append([s.sid, s.peer, s.team, s.pname, s.base_class if s.is_super() else s.class_id, s.alive, s.kills, s.deaths, s.score, s.global_position, s.yaw, s.kit, s.level, s.class_id, s.super_t, s.vehicle_id, s.vehicle_seat])
	return out


func on_roster(list: Array) -> void:
	var seen := {}
	for e: Array in list:
		var sid: int = e[0]
		seen[sid] = true
		var s: Soldier = soldiers.get(sid)
		if s == null:
			s = add_soldier(sid, e[1], e[2], e[3])
		s.kills = e[6]
		s.deaths = e[7]
		s.score = e[8]
		s.level = e[12]
		var alive: bool = e[5]
		if alive and not s.alive and s.control == Soldier.Driver.PROXY_VIEW:
			s.respawn(e[9], e[10], e[4], e[11])
		if e.size() > 16 and alive:
			var changed_seat := s.vehicle_seat != int(e[16])
			s.vehicle_id = e[15]
			s.vehicle_seat = e[16]
			if s.class_id != int(e[13]) or changed_seat:
				s.become(e[13], e[14], s.hp)
	for sid: int in soldiers.keys():
		if not seen.has(sid):
			remove_soldier(sid)


func build_snapshot() -> PackedByteArray:
	var count := soldiers.size()
	var buf := PackedByteArray()
	buf.resize(8 + 4 + 1 + flags.size() * 2 + 1 + count * 24)
	buf.encode_double(0, Net.server_time())
	buf.encode_u16(8, tickets[0])
	buf.encode_u16(10, tickets[1])
	buf.encode_u8(12, flags.size())
	var o := 13
	for f: Dictionary in flags:
		buf.encode_s8(o, f["owner"])
		buf.encode_s8(o + 1, int(float(f["value"]) * 127.0))
		o += 2
	buf.encode_u8(o, count)
	o += 1
	for s: Soldier in soldiers.values():
		var p := s.global_position
		buf.encode_u16(o, s.sid)
		buf.encode_float(o + 2, p.x)
		buf.encode_float(o + 6, p.y)
		buf.encode_float(o + 10, p.z)
		buf.encode_u16(o + 14, int(fposmod(s.yaw, TAU) / TAU * 65535.0))
		buf.encode_s16(o + 16, int(s.pitch * 10000.0))
		buf.encode_u16(o + 18, int(clampf(s.hp, 0.0, 65535.0)))
		var flags_now := s.state_flags()
		buf.encode_u8(o + 20, flags_now & 255)
		buf.encode_u8(o + 21, s.slot | (C.SLOT_PRONE if flags_now & C.F_PRONE != 0 else 0))
		buf.encode_u16(o + 22, int(fposmod(s.hull_yaw, TAU) / TAU * 65535.0))
		o += 24
	return buf


func apply_snapshot(buf: PackedByteArray) -> void:
	if buf.size() < 14:
		return
	var t := buf.decode_double(0)
	Net.sync_clock(t)
	tickets[0] = buf.decode_u16(8)
	tickets[1] = buf.decode_u16(10)
	var nf := buf.decode_u8(12)
	var o := 13
	for i in nf:
		if i < flags.size():
			flags[i]["owner"] = buf.decode_s8(o)
			flags[i]["value"] = buf.decode_s8(o + 1) / 127.0
		o += 2
	var count := buf.decode_u8(o)
	o += 1
	for i in count:
		var s: Soldier = soldiers.get(buf.decode_u16(o))
		if s != null:
			var hp := float(buf.decode_u16(o + 18))
			var state := buf.decode_u8(o + 20)
			var slot_byte := buf.decode_u8(o + 21)
			if slot_byte & C.SLOT_PRONE != 0:
				state |= C.F_PRONE
			if s.control == Soldier.Driver.LOCAL:
				s.hp = hp
				s.protected_t = 0.5 if state & C.F_PROTECTED != 0 else 0.0
			elif s.alive:
				var pos := Vector3(buf.decode_float(o + 2), buf.decode_float(o + 6), buf.decode_float(o + 10))
				s.hp = hp
				s.push_snapshot(t, pos, buf.decode_u16(o + 14) / 65535.0 * TAU, buf.decode_s16(o + 16) / 10000.0, buf.decode_u16(o + 22) / 65535.0 * TAU)
				s.apply_flags(state)
				s.protected_t = 0.5 if state & C.F_PROTECTED != 0 else 0.0
				var slot := slot_byte & ~C.SLOT_PRONE
				if slot != s.slot and slot < s.loadout.size():
					s.slot = slot
					if s.model:
						s.model.set_weapon(s.weapon_id(), s.weapon_parts())
		o += 24


# ---------------------------------------------------------------- events

func on_joined(sid: int) -> void:
	local = soldiers.get(sid)
	if controller and local:
		controller.attach(local)


func on_pings(list: Array) -> void:
	for e: Array in list:
		var s: Soldier = soldiers.get(e[0])
		if s:
			s.ping = e[1]


func on_profile(new_level: int, new_xp: int) -> void:
	level = new_level
	xp = new_xp


func on_level_up(new_level: int, unlocked: Array) -> void:
	level = new_level
	if hud:
		var first := PackedStringArray()
		for item: String in unlocked.slice(0, 3):
			first.append(T.t(item))
		var names := T.t("Odblokowano: %s") % ", ".join(first)
		if unlocked.is_empty():
			names = T.t("Kolejne odblokowania w zakładce Postępy")
		elif unlocked.size() > 3:
			names += T.t(" i %d więcej") % (unlocked.size() - 3)
		hud.banner(T.t("POZIOM %d") % new_level, names, UiKit.BRASS)
		Sfx.play("flag_captured", -2.0, 1.2)


func on_spawn(sid: int, pos: Vector3, yaw: float, class_id: int, kit: Dictionary) -> void:
	var s: Soldier = soldiers.get(sid)
	if s == null:
		return
	s.respawn(pos, yaw, class_id, kit)
	if s == local and controller:
		controller.on_spawned()


func on_kill(victim: int, killer: int, weapon_id: int, head: bool) -> void:
	var v: Soldier = soldiers.get(victim)
	if v == null:
		return
	var was_machine := v.is_mech() or (v.is_vehicle() and not v.is_gunner())
	var slayer: Soldier = soldiers.get(killer)
	if v.model and slayer:
		v.model.set_death_from(slayer.global_position)
	if v.alive:
		v.die()
	if was_machine and fx:
		fx.explosion(v.global_position + Vector3.UP * 1.2, true)
		fx.wreck_smoke(v.global_position + Vector3.UP * 0.9, MachineModel.WRECK_TIME - 3.0)
	elif fx and v != local:
		Sfx.play_at(_voice(v, "death"), v.global_position + Vector3.UP * 1.3, 1.0, randf_range(0.86, 0.98) if v.team == C.Team.EMPIRE else randf_range(0.96, 1.1))
	elif fx:
		Sfx.play(_voice(v, "death"), -3.0, randf_range(0.96, 1.08))
	var k: Soldier = soldiers.get(killer)
	if hud:
		hud.add_kill(k, v, weapon_id, head)
		if v != local and k == local:
			hud.big_message(T.t("WYELIMINOWANO: %s") % v.pname, side_color(v))
	if v == local and controller:
		controller.on_died(k, weapon_id)


func on_shot(sid: int, weapon_id: int, origin: Vector3, end: Vector3, kind: int, exclude_sid: int) -> void:
	if fx == null or (local != null and exclude_sid == local.sid):
		return
	var s: Soldier = soldiers.get(sid)
	if s == null:
		return
	var from := origin
	var mount := gunner_tank(s) if s.is_gunner() else null
	if mount:
		from = mount.gunner_muzzle()
		mount.play_gunner_fire()
	elif s.model and s.model.visible:
		from = s.model.muzzle_position()
		s.model.play_fire()
	var quiet: bool = s.weapon().get("suppressed", false) or C.WEAPONS[weapon_id]["sound"] == "laser_suppressed"
	fx.spawn_shot(weapon_id, s.team, from, end, kind, not quiet)
	shots_seen[sid] = int(shots_seen.get(sid, 0)) + 1
	if kind == 2:
		_flinch_near(end, from)
	var pitch := randf_range(0.94, 1.06) * (0.86 if s.team == C.Team.EMPIRE else 1.0)
	var sound: String = "laser_suppressed" if quiet else C.WEAPONS[weapon_id]["sound"]
	if s == local:
		Sfx.play_own(sound, 0.5 if quiet else 1.5 + float(C.SHOT_BOOST.get(sound, 0.0)), pitch)
	else:
		Sfx.play_at(sound, from, 1.5 if quiet else 4.0 + float(C.SHOT_BOOST.get(sound, 0.0)), pitch)
	if local != null and are_foes(s, local) and not quiet:
		spotted[sid] = Net.server_time() + (6.0 if local.has_perk("scout") else 2.5)


## Finds who was hit, from where the shot ended, and jolts their body.
func _flinch_near(end: Vector3, from: Vector3) -> void:
	for o: Soldier in soldiers.values():
		if o.alive and o.model and o.global_position.distance_squared_to(end) < 6.0:
			o.model.play_hit((from - end).normalized())
			if randf() < 0.4 and not o.is_mech() and not o.is_vehicle():
				Sfx.play_at(_voice(o, "hurt"), o.global_position + Vector3.UP * 1.4, -3.0, randf_range(0.88, 1.08))
			return


func on_swing(sid: int, exclude_sid: int) -> void:
	if fx == null or (local != null and exclude_sid == local.sid):
		return
	var s: Soldier = soldiers.get(sid)
	if s and s.model:
		s.model.play_swing()
		Sfx.play_at("sword_swing", s.global_position + Vector3.UP, -2.0, randf_range(0.9, 1.1))


func on_clash(pos: Vector3) -> void:
	if fx:
		fx.sparks(pos, Vector3.UP, Color(1, 1, 1), 22)
		fx.flash(pos, Color(0.85, 0.92, 1.0), 4.0, 5.0, 0.1)
		Sfx.play_at("sword_clash", pos, 2.0, randf_range(0.92, 1.08))


func on_sword_hit(pos: Vector3) -> void:
	if fx:
		fx.sparks(pos, Vector3.UP, Color(1.0, 0.6, 0.3), 16)
		Sfx.play_at("sword_hit", pos, 0.0, randf_range(0.92, 1.08))


func on_hurt(hp: float, from: Vector3) -> void:
	if local == null:
		return
	local.hp = hp
	if hud:
		hud.damage_from(from)
	Sfx.play(_voice(local, "hurt"), -5.0, randf_range(0.92, 1.08))


func on_hit_confirm(kind: int) -> void:
	hits_confirmed += 1
	if hud:
		hud.hit_marker(kind)


func on_score(points: int, reason: String) -> void:
	if hud:
		hud.score_popup(points, reason)


func on_flag_changed(idx: int, new_owner: int, old_owner: int) -> void:
	flags[idx]["owner"] = new_owner
	if hud == null or local == null:
		return
	var f: Dictionary = flags[idx]
	var label := "%s — %s" % [f["letter"], T.t(String(f["name"])).to_upper()]
	if new_owner == local.team:
		hud.banner("FLAGA ZDOBYTA", label, C.team_color(new_owner))
		Sfx.play("flag_captured", -3.0)
	elif old_owner == local.team:
		hud.banner("FLAGA UTRACONA", label, C.team_color(1 - local.team))
		Sfx.play("flag_lost", -3.0)
	elif new_owner >= 0:
		hud.banner("WRÓG ZAJĄŁ FLAGĘ", label, C.team_color(new_owner))


func on_round_end(winner: int, restart_in: float, final_score: Array) -> void:
	round_winner = winner
	tickets = final_score.duplicate()
	if controller:
		controller.on_round_end()
	if hud:
		hud.show_end_screen(winner, restart_in)


func on_round_start() -> void:
	round_winner = -1
	for s: Soldier in soldiers.values():
		s.alive = false
		s.death_time = -100.0
		s.coins = 0
		s.super_t = 0.0
		if s.model:
			s.model.visible = false
	if controller:
		controller.on_round_start()
	if hud:
		hud.hide_end_screen()


func on_notice(text: String) -> void:
	if hud:
		hud.big_message(text, UiKit.BRASS)
		Sfx.play("empty_click", -4.0)


func on_coin_spawn(id: int, pos: Vector3) -> void:
	var node: CoinPickup = null
	if Net.has_view():
		node = CoinPickup.new()
		node.position = pos
		add_child(node)
		Sfx.play("coin_spawn", -6.0)
		if hud:
			hud.banner("MONETA NA MAPIE", "Złoty słup światła: pierwszy bierze superklasę", UiKit.BRASS)
	coins[id] = {"pos": pos, "node": node}


func on_coin_sync(list: Array) -> void:
	for e: Array in list:
		if not coins.has(e[0]):
			on_coin_spawn(e[0], e[1])


func on_coin_gone(id: int) -> void:
	var c: Dictionary = coins.get(id, {})
	if c.is_empty():
		return
	coins.erase(id)
	if c["node"] != null:
		(c["node"] as Node).queue_free()


func on_coin_taken(id: int, sid: int) -> void:
	var c: Dictionary = coins.get(id, {})
	on_coin_gone(id)
	var s: Soldier = soldiers.get(sid)
	if s == null:
		return
	s.coins = 1
	if fx and not c.is_empty():
		Sfx.play_at("coin_pickup", c["pos"], 0.0)
	if s == local and hud:
		hud.banner("MONETA", "Wciśnij B, aby wybrać superklasę", UiKit.BRASS)
		Sfx.play("coin_pickup", -2.0)


func on_vehicle(id: int, team: int, pos: Vector3, yaw: float, hp: float, driver: int, gunner := 0, kind := 0) -> void:
	var v: Dictionary = vehicles.get(id, {})
	if v.is_empty():
		var collider := TankCollider.new()
		collider.name = "TankCollider%d" % id
		collider.set_meta("vehicle_id", id)
		collider.setup(team, C.APC_CLASS if kind == 1 else C.VEHICLE_CLASS)
		# Enter the physics space at the spawn pose, rather than sweeping out from origin.
		collider.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
		add_child(collider)
		v = {"id": id, "team": team, "node": null, "collider": collider, "kind": kind, "riders": []}
		vehicles[id] = v
		if Net.has_view():
			var node: TankModel = ApcModel.new() if kind == 1 else TankModel.new()
			node.setup(team)
			add_child(node)
			v["node"] = node
	v["pos"] = pos
	v["yaw"] = yaw
	v["hp"] = hp
	v["driver"] = driver
	v["gunner"] = gunner
	_sync_vehicle_collider(v)
	var model: TankModel = v["node"]
	if model:
		model.visible = driver == 0 and hp > 0.0
		model.park(pos, yaw)


func on_vehicle_sync(list: Array) -> void:
	for e: Array in list:
		callv("on_vehicle", e)


## A soldier climbs into a carrier, or out of one when `vehicle` is -1.
func on_ride(sid: int, vehicle: int) -> void:
	var s: Soldier = soldiers.get(sid)
	if s == null:
		return
	if s.riding >= 0 and vehicles.has(s.riding):
		(vehicles[s.riding]["riders"] as Array).erase(sid)
	s.set_riding(vehicle)
	if vehicle >= 0 and vehicles.has(vehicle):
		(vehicles[vehicle]["riders"] as Array).append(sid)
	if s == local and controller:
		controller.on_transformed(true)


## Where the carrier is that this soldier rides in.
func ride_position(s: Soldier) -> Vector3:
	var v: Dictionary = vehicles.get(s.riding, {})
	if v.is_empty():
		return s.global_position
	var driver: Soldier = soldiers.get(v["driver"])
	return driver.global_position if driver and driver.alive else v["pos"]


func on_crew(sid: int, vehicle: int, seat: int) -> void:
	var s: Soldier = soldiers.get(sid)
	if s:
		s.vehicle_id = vehicle
		s.vehicle_seat = seat


func on_fort(data: Dictionary) -> void:
	forts.receive(data)
	if fx and int(data["kind"]) == Fortifications.BEACON:
		Sfx.play_at("beacon_place", data["pos"], 0.0)


func on_squads(list: Array) -> void:
	squads.receive(list)


func on_squad_notice(message: String) -> void:
	if hud:
		hud.banner("ODDZIAŁ", message, UiKit.BRASS)


## Everyone sees where shells are about to fall, which is what makes running away possible.
func on_strike(team: int, pos: Vector3, seconds: float, squad_name: String) -> void:
	if fx == null:
		return
	fx.strike_marker(pos, seconds + C.STRIKE_SHELLS * C.STRIKE_INTERVAL)
	Sfx.play_at("artillery_whistle", pos + Vector3.UP * 24.0, 8.0)
	if local == null or hud == null:
		return
	if local.team == team:
		Sfx.play("radio_call", -2.0)
		hud.banner("ARTYLERIA", T.t("Oddział %s: pociski w drodze") % T.t(squad_name), UiKit.BRASS)
	elif local.global_position.distance_to(pos) < C.STRIKE_SCATTER + C.SHELL_RADIUS + 26.0:
		hud.banner("OSTRZAŁ ARTYLERYJSKI", "Uciekaj z zaznaczonej strefy", UiKit.RED)


func on_fort_sync(list: Array) -> void:
	for data: Dictionary in list:
		forts.receive(data)


func on_fort_health(id: int, hp: float) -> void:
	if forts.items.has(id):
		forts.items[id]["hp"] = hp
		(forts.items[id]["node"] as Fortification).set_health(hp)


func on_fort_removed(id: int) -> void:
	forts.remove(id)


func on_build_status(materials: float, progress: float, message: String) -> void:
	forts.local_materials = materials
	forts.local_progress = progress
	if hud and not message.is_empty():
		hud.banner("BUDOWA", message, UiKit.BRASS)


func on_fort_fire(id: int, end: Vector3) -> void:
	if not fx or not forts.items.has(id):
		return
	var item: Dictionary = forts.items[id]
	var from: Vector3 = item["pos"] + Vector3.UP * 2.15
	var direction := end - from
	var node: Fortification = item["node"]
	node.visual.rotation.y = atan2(-direction.x, -direction.z) - node.rotation.y
	fx.spawn_shot(C.W.TANK_MG, item["team"], from, end, 2, true, false)
	Sfx.play_at("laser_rifle", from, -9)


func on_place(sid: int, pos: Vector3, yaw: float) -> void:
	var s: Soldier = soldiers.get(sid)
	if s == null:
		return
	s.teleport(pos)
	s.velocity = Vector3.ZERO
	s.tank_speed = 0.0
	s.hull_yaw = yaw
	s.yaw = yaw
	s._snaps.clear()


func on_transform(sid: int, class_id: int, duration: float, new_hp := -1.0) -> void:
	var s: Soldier = soldiers.get(sid)
	if s == null:
		return
	var was_vehicle := s.is_vehicle()
	s.become(class_id, duration, new_hp)
	if class_id == C.VEHICLE_CLASS or class_id == C.APC_CLASS or was_vehicle:
		if s == local and controller:
			controller.on_transformed(true)
		return
	if fx:
		var color := UiKit.BRASS if class_id >= C.NORMAL_CLASSES else C.team_color(s.team)
		fx.flash(s.global_position + Vector3.UP * 1.5, color, 7.0, 12.0, 0.2)
		fx.sparks(s.global_position + Vector3.UP * 1.2, Vector3.UP, color, 22)
		Sfx.play_at("transform", s.global_position, 0.0)
	if hud and class_id >= C.NORMAL_CLASSES and local != null and are_foes(s, local):
		hud.big_message(T.t("WRÓG: %s") % T.t(String(s.class_data()["name"])).to_upper(), side_color(s))
	if s == local and controller:
		controller.on_transformed(false)


func on_correct_position(pos: Vector3) -> void:
	if local:
		local.teleport(pos)
		local.velocity = Vector3.ZERO


func on_rocket(id: int, sid: int, pos: Vector3, direction: Vector3, lobbed := false) -> void:
	var rocket := ATRocket.new()
	rocket.setup(self, id, sid, pos, direction, lobbed)
	rockets[id] = rocket
	add_child(rocket)
	if fx and (local == null or local.sid != sid):
		Sfx.play_at("mech_launcher" if lobbed else "tank_fire", pos, 2.0 if lobbed else -5.0, 1.0 if lobbed else 1.25)


func on_rocket_explosion(id: int, pos: Vector3) -> void:
	if rockets.has(id):
		(rockets[id] as Node).queue_free()
		rockets.erase(id)
	if fx:
		fx.explosion(pos)


func on_grenade(id: int, sid: int, pos: Vector3, vel: Vector3, kind: int) -> void:
	var g := Grenade.new()
	var s: Soldier = soldiers.get(sid)
	g.setup(self, id, sid, pos, vel, s.team if s else 0, kind)
	_grenades[id] = g
	add_child(g)
	Sfx.play_at("grenade_throw", pos, -2.0)
	if s and s.model and s != local:
		s.model.play_throw(kind)


## Machines break rather than cry out.
func _voice(s: Soldier, sound: String) -> String:
	return "droid_" + sound if s != null and s.team == C.Team.EMPIRE else sound


func on_grenade_gone(id: int) -> void:
	var g: Grenade = _grenades.get(id)
	if g:
		_grenades.erase(id)
		g.queue_free()


func on_area(kind: int, pos: Vector3, seconds: float) -> void:
	if fx == null:
		return
	if kind == C.NADE_SMOKE:
		fx.smoke_cloud(pos, seconds)
	else:
		fx.fire_patch(pos, seconds)


func on_area_sync(list: Array) -> void:
	for e: Array in list:
		on_area(e[0], e[1], e[2])


## Paints every machine and soldier in the marker colour that thermal.gdshader turns white hot.
func set_thermal(on: bool) -> void:
	thermal_on = on
	if hud:
		hud.set_thermal(on)
	_paint_thermal(on)


func _paint_thermal(on: bool) -> void:
	var bodies: Array[Node] = []
	for s: Soldier in soldiers.values():
		if s != local and s.model:
			bodies.append(s.model)
	for id: int in vehicles:
		if vehicles[id].get("node"):
			bodies.append(vehicles[id]["node"])
	for body in bodies:
		for part in body.find_children("*", "GeometryInstance3D", true, false):
			(part as GeometryInstance3D).material_overlay = _thermal_paint() if on else null


func _thermal_paint() -> Material:
	if _hot == null:
		_hot = ShaderMaterial.new()
		_hot.shader = load("res://shaders/thermal_body.gdshader")
	return _hot


## A tank shell: the bolt takes time to get there, so the blast has to wait for it.
func on_shell_blast(from: Vector3, pos: Vector3) -> void:
	if fx == null:
		return
	get_tree().create_timer(from.distance_to(pos) / Fx.BOLT_SPEED).timeout.connect(on_explosion.bind(-1, pos))


func on_explosion(id: int, pos: Vector3) -> void:
	var g: Grenade = _grenades.get(id)
	if g:
		_grenades.erase(id)
		g.queue_free()
	if fx:
		fx.explosion(pos)
		if controller:
			controller.shake(clampf(1.4 - camera_position().distance_to(pos) / 34.0, 0.0, 1.2))


# ---------------------------------------------------------------- scenery

func _build_lamps() -> void:
	var bulb := Mats.glow(Color(1.0, 0.72, 0.42), 6.0)
	for p: Vector3 in map.lamps:
		P.ball(self, 0.13, p, bulb)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.68, 0.4)
		l.light_energy = 1.6
		l.omni_range = 13.0
		l.position = p
		add_child(l)


func _build_empire_dressing() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = Mats.tex("banner_empire")
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.backlight_enabled = true
	mat.backlight = Color(0.25, 0.25, 0.25)
	for e: Array in map.banners:
		var height: float = e[2]
		var quad := QuadMesh.new()
		quad.size = Vector2(height * 0.4, height)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.position = e[0]
		mi.rotation.y = e[1]
		add_child(mi)
	var lens := Mats.glow(Color(1.0, 0.95, 0.8), 3.0)
	for p: Vector3 in map.searchlights:
		P.cyl(self, 0.28, 0.2, 0.4, p, Mats.flat(Color(0.2, 0.2, 0.2), 0.5, 0.7), Vector3(PI * 0.5, 0, 0))
		P.ball(self, 0.2, p + Vector3(0, 0, -0.14), lens)
		var l := SpotLight3D.new()
		l.position = p
		l.light_color = Color(1.0, 0.96, 0.84)
		l.light_energy = 8.0
		l.spot_range = 80.0
		l.spot_angle = 9.0
		l.light_volumetric_fog_energy = 4.0
		add_child(l)
		_lights.append(l)


func _build_flag_views() -> void:
	var ring_shader: Shader = load("res://shaders/zone_ring.gdshader")
	var cloth_shader: Shader = load("res://shaders/flag_cloth.gdshader")
	var pole_mat := Mats.flat(Color(0.3, 0.3, 0.32), 0.4, 0.8)
	for f: Dictionary in flags:
		var root := Node3D.new()
		root.position = f["pos"]
		add_child(root)
		P.cyl(root, 0.05, 0.07, 11.0, Vector3(0, 5.5, 0), pole_mat)
		P.cyl(root, 0.42, 0.56, 0.3, Vector3(0, 0.15, 0), Mats.flat(Color(0.25, 0.25, 0.26), 0.7, 0.3))
		P.ball(root, 0.1, Vector3(0, 11.05, 0), Mats.flat(Color(0.6, 0.47, 0.22), 0.4, 0.9))

		var plane := PlaneMesh.new()
		plane.orientation = PlaneMesh.FACE_Z
		plane.size = Vector2(2.8, 1.75)
		plane.subdivide_width = 18
		plane.subdivide_depth = 8
		var cloth_mat := ShaderMaterial.new()
		cloth_mat.shader = cloth_shader
		var cloth := MeshInstance3D.new()
		cloth.mesh = plane
		cloth.material_override = cloth_mat
		cloth.position = Vector3(1.45, 9.8, 0)
		cloth.extra_cull_margin = 2.0
		root.add_child(cloth)

		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = C.FLAG_RADIUS
		ring_mesh.bottom_radius = C.FLAG_RADIUS
		ring_mesh.height = 2.6
		ring_mesh.radial_segments = 64
		ring_mesh.rings = 1
		ring_mesh.cap_top = false
		ring_mesh.cap_bottom = false
		var ring_mat := ShaderMaterial.new()
		ring_mat.shader = ring_shader
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = ring_mat
		ring.position.y = 1.3
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)

		flag_views.append({"cloth": cloth, "cloth_mat": cloth_mat, "ring_mat": ring_mat, "shown": -99})


func _update_flag_view(i: int, delta: float) -> void:
	var f: Dictionary = flags[i]
	var v: Dictionary = flag_views[i]
	var owner: int = f["owner"]
	var value: float = f["value"]
	# Which side's colours fly: the side the value currently leans toward.
	var lean := owner
	if lean < 0 and absf(value) > 0.02:
		lean = 0 if value < 0.0 else 1
	if v["shown"] != lean:
		v["shown"] = lean
		var tex_name := "flag_neutral" if lean < 0 else ("flag_usa" if lean == 0 else "flag_empire")
		(v["cloth_mat"] as ShaderMaterial).set_shader_parameter("flag_tex", Mats.tex(tex_name))
		var c := C.team_color(owner)
		(v["ring_mat"] as ShaderMaterial).set_shader_parameter("ring_color", Vector3(c.r, c.g, c.b))
	var target := lerpf(2.2, 9.8, absf(value)) if lean >= 0 else 2.2
	var cloth: MeshInstance3D = v["cloth"]
	cloth.position.y = move_toward(cloth.position.y, target, delta * 3.0)
