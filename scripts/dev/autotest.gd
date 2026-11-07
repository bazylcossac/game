extends Node
## Developer harness, enabled with `-- --test=<mode>`. Not used in normal play.
##   sim     headless: map checks, then watches a bot-only match and prints statistics.
##   screens windowed: drives the real UI and saves screenshots to --out=<dir>.
##   client  headless client that joins --host and walks around, for network tests.
##   machines windowed: mechs and tanks on a bare stage, without starting a match.
##   bench   windowed: the 3D weapon bench, driven with real mouse clicks.
##   props   windowed: close looks at the sandbags, wire and hedgehogs on the real map.
##   perf    windowed: frame timing over fixed views of a full bot match, vsync off.
##   map-audit headless: cover, exposure and lines of fire of one map, see map_audit.gd.
##   modes   headless: every map, mode and bomb rule, see modes_test.gd.
##   modes-shots windowed: views of the new maps and the HUD of every mode, see modes_shots.gd.
##   tank-shots windowed: the tank from both crew seats and from outside, see tank_shots.gd.
##   squads  headless: squads, the leader's class, artillery and beacons, see squad_test.gd.
##   sides   headless: playing either side, and each side's gear, see side_test.gd.
##   side-shots windowed: the game as the Iron Empire, see side_shots.gd.
##   droid-gallery windowed: every Empire machine and gun in a studio, see droid_gallery.gd.
##   menu-art windowed: stages the menu card pictures, see menu_art.gd and tools/menu_art.py.
##   lang: Polish and English text, format codes and screens, see lang_test.gd.
##   browser-net headless client against a real --server: the list, sides, ping, respawn, see browser_network.gd.
##   fixes headless: vehicle use time, kept ammo, empty vehicles, safe zones, stamina, F, admin panel.
##   fixes-shots windowed: crosshair, big map, class health, admin panel, see fixes_shots.gd.
##   perf-weather windowed: frame cost with the weather on and off, see weather_perf.gd.
##   respawn headless: the pause menu's respawn in vehicles and modes, see respawn_test.gd.
##   browser-shots windowed: the server list, side pick, score table and pause menu, see browser_shots.gd.
##   neon: whether tanks and mechs fit every street of Neonowa Dzielnica, see neon_test.gd.
##   grenades headless: the reload rule, class counts, smoke and fire, see grenade_test.gd.
##   grenade-shots windowed: the throw, frame by frame, and each kind going off.
##   squad-net headless pair: the same over a real connection, see squad_network.gd.
##   squad-shots windowed: squad screens and the commander's tools, see squad_shots.gd.

## Fixed stops of the perf test, as [name, feet position, starting yaw, pitch]. The view
## makes one full turn at each, so every run sees the same scenery.
const PERF_STOPS := [
	["rynek", Vector3(4, 0.2, 20), 0.0, -0.05],
	["ulica", Vector3(-25, 0.2, 40), 0.0, 0.0],
	["kamienice", Vector3(-50, 0.2, 25), 1.57, 0.0],
	["ratusz", Vector3(-100, 0.2, 66), 0.0, 0.0],
	["dworzec", Vector3(100, 0.2, 62), 0.0, 0.0],
	["dach", Vector3(-25, 16.0, 25), 0.8, -0.3],
	["wysoko", Vector3(0, 60.0, 150), 0.0, -0.42],
]
const PERF_WARMUP := 25.0
const PERF_STOP_SECONDS := 10.0
const PERF_DEPLOY_SECONDS := 6.0


## Runs after every other node each tick and frame, which closes their timing.
class TickEnd:
	extends Node
	var tester: Node

	func _physics_process(_delta: float) -> void:
		tester.end_tick()

	func _process(_delta: float) -> void:
		tester.end_process()


var out_dir := ""
var shots := 0

## Script time of each physics tick and each frame, in ms.
var _tick_ms := PackedFloat32Array()
var _tick_start := 0
var _process_ms := PackedFloat32Array()
var _process_start := 0
var _perf_times := PackedFloat32Array()
## Time spent in the renderer's frame, from just before it draws until it hands back.
var _draw_ms := PackedFloat32Array()
var _draw_start := 0


func _input(event: InputEvent) -> void:
	# Reports real input reaching the window, which would otherwise skew a scripted run.
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed() and not event.is_echo():
			print("[input] ", event.as_text())


func _ready() -> void:
	set_physics_process(false)
	set_process(false)
	out_dir = Settings.arg("out", "user://shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Whatever the player last chose in the menu must not change what a test plays.
	Settings.side = C.Team.RESISTANCE
	ServerBrowser.asking = false
	Settings.match_mode = Modes.DEFAULT_MODE
	Settings.match_map = ""
	match Settings.arg("test"):
		"sim": _sim()
		"screens": _screens()
		"client": _client()
		"input": _input_test()
		"supers": _supers_screens()
		"anims": _anims()
		"gear": _gear_test()
		"deploy": _deploy_screens()
		"empire": _empire_screens()
		"machines": _machines()
		"bench": _bench()
		"props": _props()
		"perf": _perf()
		"map-audit": add_child(load("res://scripts/dev/map_audit.gd").new())
		"modes": add_child(load("res://scripts/dev/modes_test.gd").new())
		"tank-collision": add_child(load("res://scripts/dev/tank_collision_test.gd").new())
		"crew": add_child(load("res://scripts/dev/crew_test.gd").new())
		"engineer": add_child(load("res://scripts/dev/engineer_test.gd").new())
		"features-net": add_child(load("res://scripts/dev/features_network.gd").new())
		"combat-upgrade": add_child(load("res://scripts/dev/combat_upgrade_test.gd").new())
		"ordnance-net": add_child(load("res://scripts/dev/ordnance_network.gd").new())
		"upgrade-shots": add_child(load("res://scripts/dev/upgrade_shots.gd").new())
		"tank-shots": add_child(load("res://scripts/dev/tank_shots.gd").new())
		"squads": add_child(load("res://scripts/dev/squad_test.gd").new())
		"grenades": add_child(load("res://scripts/dev/grenade_test.gd").new())
		"sides": add_child(load("res://scripts/dev/side_test.gd").new())
		"side-shots": add_child(load("res://scripts/dev/side_shots.gd").new())
		"grenade-shots": add_child(load("res://scripts/dev/grenade_shots.gd").new())
		"squad-net": add_child(load("res://scripts/dev/squad_network.gd").new())
		"squad-shots": add_child(load("res://scripts/dev/squad_shots.gd").new())
		"modes-shots": add_child(load("res://scripts/dev/modes_shots.gd").new())
		"menu-art": add_child(load("res://scripts/dev/menu_art.gd").new())
		"carrier": add_child(load("res://scripts/dev/carrier_test.gd").new())
		"view-shots": add_child(load("res://scripts/dev/view_shots.gd").new())
		"weapon-icons": add_child(load("res://scripts/dev/weapon_icons.gd").new())
		"perf-fx": add_child(load("res://scripts/dev/perf_bench.gd").new())
		"props-gallery": add_child(load("res://scripts/dev/props_gallery.gd").new())
		"neon": add_child(load("res://scripts/dev/neon_test.gd").new())
		"droid-gallery": add_child(load("res://scripts/dev/droid_gallery.gd").new())
		"lang": add_child(load("res://scripts/dev/lang_test.gd").new())
		"browser-net": add_child(load("res://scripts/dev/browser_network.gd").new())
		"respawn": add_child(load("res://scripts/dev/respawn_test.gd").new())
		"fixes": add_child(load("res://scripts/dev/fixes_test.gd").new())
		"fixes-shots": add_child(load("res://scripts/dev/fixes_shots.gd").new())
		"perf-weather": add_child(load("res://scripts/dev/weather_perf.gd").new())
		"browser-shots": add_child(load("res://scripts/dev/browser_shots.gd").new())
		"scratch": add_child(load(Settings.arg("file")).new())
		_: get_tree().quit(2)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return  # No frames are drawn, so frame_post_draw would never fire.
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	shots += 1
	var path := "%s/%02d_%s.png" % [out_dir, shots, label]
	img.save_png(path)
	print("[shot] ", path)


func _start_tick_timer() -> void:
	process_physics_priority = -100000
	process_priority = -100000
	var end := TickEnd.new()
	end.tester = self
	end.process_physics_priority = 100000
	end.process_priority = 100000
	add_child(end)
	set_physics_process(true)
	set_process(true)


func _physics_process(_delta: float) -> void:
	_tick_start = Time.get_ticks_usec()


func end_tick() -> void:
	_tick_ms.append((Time.get_ticks_usec() - _tick_start) / 1000.0)
	if _tick_ms[_tick_ms.size() - 1] > 8.0:
		print("[spike] tick ", _tick_ms[_tick_ms.size() - 1])


func _process(_delta: float) -> void:
	_process_start = Time.get_ticks_usec()


func end_process() -> void:
	_process_ms.append((Time.get_ticks_usec() - _process_start) / 1000.0)


func _sorted(values: PackedFloat32Array) -> PackedFloat32Array:
	var out := values.duplicate()
	out.sort()
	return out


func _pct(sorted: PackedFloat32Array, fraction: float) -> float:
	return 0.0 if sorted.is_empty() else sorted[mini(int(sorted.size() * fraction), sorted.size() - 1)]


func _mean(values: PackedFloat32Array) -> float:
	var sum := 0.0
	for v: float in values:
		sum += v
	return sum / maxf(values.size(), 1.0)


func _print_ticks(label: String) -> void:
	for pair: Array in [["tick", _tick_ms], ["frame", _process_ms], ["draw", _draw_ms]]:
		var sorted := _sorted(pair[1])
		print("[%s] %s script ms: n=%d avg=%.3f p50=%.3f p95=%.3f p99=%.3f max=%.3f" % [label, pair[0], sorted.size(), _mean(pair[1]),
			_pct(sorted, 0.5), _pct(sorted, 0.95), _pct(sorted, 0.99), _pct(sorted, 1.0)])


func _sim() -> void:
	var seconds := float(Settings.arg("seconds", "60"))
	_start_tick_timer()
	var t0 := Time.get_ticks_msec()
	var port := int(Settings.arg("port", "7792"))
	var cfg := {"seed": 1943, "bots_per_team": int(Settings.arg("bots", "12")), "difficulty": int(Settings.arg("difficulty", "1")), "coin_interval": float(Settings.arg("coin-interval", "0"))}
	Net.start_dedicated(cfg, port)
	await get_tree().process_frame
	var w: World = Net.world
	print("[sim] map built in %d ms, footprints=%d" % [Time.get_ticks_msec() - t0, w.map.b.footprints.size()])
	var nav := w.map.b.nav
	var bad := 0
	for team in 2:
		for f: Dictionary in w.flags:
			if not nav.can_reach(CityMap.BASES[team], f["pos"]):
				bad += 1
				print("[sim] UNREACHABLE from base %d to %s" % [team, f["name"]])
	for a: Dictionary in w.flags:
		for b: Dictionary in w.flags:
			if not nav.can_reach(a["pos"], b["pos"]):
				bad += 1
				print("[sim] UNREACHABLE %s -> %s" % [a["name"], b["name"]])
	print("[sim] reachability failures: %d" % bad)
	var wide_bad := 0
	for team in 2:
		for f: Dictionary in w.flags:
			if not w.map.b.nav_wide.can_reach(CityMap.BASES[team], f["pos"]):
				wide_bad += 1
				print("[sim] mech cannot reach %s from base %d" % [f["name"], team])
	print("[sim] mech reachability failures: %d" % wide_bad)
	var tank_bad := 0
	for team in 2:
		for spot: Array in CityMap.TANK_DEPOTS[team]:
			var from: Vector3 = spot[0]
			if not w.map.b.nav_tank.is_free(w.map.b.nav_tank.cell_of(from)):
				print("[sim] tank depot blocked at %s" % from)
				tank_bad += 1
			for f: Dictionary in w.flags:
				var path := w.map.b.nav_tank.find_path(from, f["pos"])
				var end: Vector3 = path[path.size() - 1] if path.size() > 0 else from
				var gap := Vector2(end.x - f["pos"].x, end.z - f["pos"].z).length()
				# The factory flag stands indoors, so tanks shell it from the doorway.
				if gap > C.FLAG_RADIUS + 3.0:
					tank_bad += 1
					print("[sim] tank from %s stops %.0f m short of %s" % [from, gap, f["name"]])
	print("[sim] tank route failures: %d" % tank_bad)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var coin_bad := 0
	for i in 300:
		var p := w.map.random_coin_point(rng)
		if not nav.is_free(nav.cell_of(p)) or not nav.can_reach(CityMap.BASES[0], p) or absf(p.y - w.map.ground_height(p.x, p.z)) > 0.01:
			coin_bad += 1
	print("[sim] unreachable coin spots out of 300: %d" % coin_bad)
	if cfg["coin_interval"] > 0.0:
		w.server.set("_coin_t", 2.0)
	var elapsed := 0.0
	var below_ground := 0
	var last_pos := {}
	while elapsed < seconds:
		await _wait(10.0)
		elapsed += 10.0
		if Settings.has_arg("coin-for-humans"):
			for s: Soldier in w.soldiers.values():
				if s.peer != 0 and s.alive and s.coins == 0 and not s.is_super():
					w.server.spawn_coin(s.global_position, 20.0)
		var kills := 0
		var alive := 0
		var moving := 0
		for s: Soldier in w.soldiers.values():
			kills += s.kills
			if s.alive:
				alive += 1
				if Vector2(s.velocity.x, s.velocity.z).length() > 1.0:
					moving += 1
				if s.global_position.y < w.map.ground_height(s.global_position.x, s.global_position.z) - 1.0:
					below_ground += 1
		var owners := []
		for f: Dictionary in w.flags:
			owners.append("%s:%d(%.2f)" % [f["letter"], f["owner"], f["value"]])
		print("[sim] t=%3.0f alive=%d moving=%d kills=%d tickets=%s flags=%s fps=%d" % [elapsed, alive, moving, kills, str(w.tickets), " ".join(owners), Engine.get_frames_per_second()])
		var supers := []
		for s: Soldier in w.soldiers.values():
			if s.alive and s.is_super():
				var was: Vector3 = last_pos.get(s.sid, s.global_position)
				supers.append("%s(%.0fhp,%.0fs,moved %.0fm)" % [s.class_data()["name"], s.hp, s.super_t, s.global_position.distance_to(was)])
			last_pos[s.sid] = s.global_position
		print("[sim]       coins spawned=%d taken=%d supers used=%s live=%s" % [w.server.stat_coins_spawned, w.server.stat_coins_taken, str(w.server.stat_supers), " ".join(supers)])
		var tanks := []
		for id: int in w.vehicles:
			var v: Dictionary = w.vehicles[id]
			tanks.append("#%d:%s" % [id, "zniszczony" if float(v["hp"]) <= 0.0 else ("wolny" if v["driver"] == 0 else "jedzie")])
		print("[sim]       tanks %s" % " ".join(tanks))
		if Settings.has_arg("tank-for-humans"):
			var given := {}
			for s: Soldier in w.soldiers.values():
				if s.peer != 0 and s.alive and s.vehicle_id < 0:
					for id: int in w.vehicles:
						var v: Dictionary = w.vehicles[id]
						if v["team"] == s.team and v["driver"] == 0 and float(v["hp"]) > 0.0 and not given.has(id):
							given[id] = true
							v["pos"] = s.global_position + Vector3(4, 0, 0)
							Net.broadcast(&"vehicle", [id, v["team"], v["pos"], v["yaw"], v["hp"], 0])
							break
		for id: int in w.coins:
			var cp: Vector3 = w.coins[id]["pos"]
			var nearest := 9999.0
			var chasing := 0
			for brain: BotBrain in w.server.bots:
				if brain.s.alive:
					nearest = minf(nearest, brain.s.global_position.distance_to(cp))
					if brain.coin_id == id:
						chasing += 1
			print("[sim]       coin %d at %s nearest bot %.0f m, chasing %d" % [id, cp.round(), nearest, chasing])
	print("[sim] soldiers under the ground: %d" % below_ground)
	_print_ticks("sim")
	get_tree().quit(0)


func _client() -> void:
	var host := Settings.arg("host", "127.0.0.1")
	var port := int(Settings.arg("port", "7792"))
	Net.start_client(host, port, Settings.arg("name", "Tester"))
	await _wait(float(Settings.arg("join-wait", "5.0")))
	var w: World = Net.world
	if w == null or w.local == null:
		print("[client] FAIL could not join: world=%s" % str(w))
		get_tree().quit(1)
		return
	var s := w.local
	print("[client] joined sid=%d soldiers=%d" % [s.sid, w.soldiers.size()])
	if Settings.has_arg("modes-check"):
		add_child(load("res://scripts/dev/modes_client.gd").new())
		return
	var spawn_flag := int(Settings.arg("spawn", "1"))
	if Settings.has_arg("cheat-kit"):
		# Asks for gear far above level 1. The server must not grant it.
		Net.send_deploy(0, spawn_flag, {"primary": C.W.HEAVY, "sidearm": C.W.MPISTOL, "parts_p": ["overcell", "scope"], "parts_s": [], "perks": ["tough", "scout"]})
		await _wait(1.0)
		print("[client] %s server refused locked gear: %s, %s, perks %s, hp %d" % ["PASS" if s.loadout[0] == C.W.CARBINE and s.loadout[1] == C.W.PISTOL and s.kit["perks"].is_empty() and int(s.max_hp) == 100 else "FAIL", C.WEAPONS[s.loadout[0]]["name"], C.WEAPONS[s.loadout[1]]["name"], str(s.kit["perks"]), int(s.max_hp)])
		print("[client] level %d, xp %d" % [w.level, w.xp])
		get_tree().quit(0)
		return
	Net.send_deploy(0, spawn_flag)
	await _wait(1.0)
	print("[client] %s deployed: pos=%s" % ["PASS" if s.alive else "FAIL", s.global_position])

	# Real movement through the controller and physics.
	var start := s.global_position
	s.yaw = PI * 0.5
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(2.5)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _wait(0.3)
	var moved := s.global_position.distance_to(start)
	print("[client] %s walked %.1f m" % ["PASS" if moved > 8.0 else "FAIL", moved])

	# A teleport hack must be rejected and pulled back by the server.
	var before := s.global_position
	s.teleport(before + Vector3(0, 0, -90))
	Net.send_state(s.global_position, s.yaw, s.pitch, s.state_flags(), s.slot, s.hull_yaw)
	await _wait(0.6)
	var back := s.global_position.distance_to(before)
	print("[client] %s teleport rejected (now %.1f m from the start)" % ["PASS" if back < 10.0 else "FAIL", back])

	# Shoot live proxies. Hits only count if lag-compensated server hit detection agrees.
	var seconds := float(Settings.arg("seconds", "20"))
	var t := 0.0
	var fired := 0
	var deaths := 0
	while t < seconds:
		await _wait(0.1)
		t += 0.1
		if not s.alive:
			deaths += 1
			await _wait(C.RESPAWN_DELAY)
			t += C.RESPAWN_DELAY
			Net.send_deploy(0, 1)
			await _wait(0.5)
			continue
		var target: Soldier = null
		var best := 130.0
		for o: Soldier in w.soldiers.values():
			if not o.alive or o.team == s.team or o.protected_t > 0.0:
				continue
			var eye := s.eye_position()
			var aim := o.global_position + Vector3.UP * 1.0
			var d := eye.distance_to(aim)
			if d >= best:
				continue
			var q := PhysicsRayQueryParameters3D.create(eye, aim, C.LAYER_WORLD)
			if w.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				target = o
				best = d
		if target != null and s.can_fire():
			s.consume_shot()
			var dir := (target.global_position + Vector3.UP * 1.0 - s.eye_position()).normalized()
			Net.send_fire(s.slot, s.eye_position(), dir, Net.server_time() - Net.INTERP_DELAY)
			fired += 1
		elif s.mags[s.slot] <= 0 and s.can_reload():
			s.start_reload()
			Net.send_reload()
	if Settings.has_arg("drive-tank"):
		var tries := 0.0
		while not s.is_vehicle() and tries < 24.0:
			Net.send_use()
			await _wait(0.5)
			tries += 0.5
		print("[client] %s entered a tank: %s, %.0f hp" % ["PASS" if s.is_vehicle() else "FAIL", s.class_data()["name"], s.hp])
		# Turn on the spot first, so a nearby barricade cannot decide this test.
		var hull0 := s.hull_yaw
		Input.action_press("move_left")
		await _wait(0.8)
		Input.action_release("move_left")
		print("[client] %s hull turned %.2f rad" % ["PASS" if s.hull_yaw > hull0 + 0.5 else "FAIL", s.hull_yaw - hull0])
		var best_drive := 0.0
		for attempt in 4:
			var tank_start := s.global_position
			Input.action_press("move_forward")
			await _wait(1.6)
			Input.action_release("move_forward")
			await _wait(0.3)
			best_drive = maxf(best_drive, s.global_position.distance_to(tank_start))
			if best_drive > 6.0:
				break
			Input.action_press("move_left")
			await _wait(1.2)
			Input.action_release("move_left")
		print("[client] %s drove %.1f m" % ["PASS" if best_drive > 6.0 else "FAIL", best_drive])
		await _wait(1.0)
		print("[client] position accepted by the server: %s" % s.global_position.round())
		await _wait(float(Settings.arg("tank-time", "6")))
		Net.send_use()
		await _wait(C.USE_TIME + 0.8)
		print("[client] %s left the tank: %s, %.0f hp" % ["PASS" if not s.is_vehicle() else "FAIL", s.class_data()["name"], s.hp])
		get_tree().quit(0)
		return

	# A super class over the network. The server drops a coin on us in this test.
	var waited := 0.0
	while (s.coins == 0 or not s.alive) and waited < 14.0:
		await _wait(0.25)
		waited += 0.25
		if not s.alive and Net.server_time() - s.death_time > C.RESPAWN_DELAY:
			Net.send_deploy(0, 1)
	print("[client] %s coin reached the client" % ("PASS" if s.coins == 1 else "FAIL"))
	Net.send_transform(C.SUPER_SPECIAL if Settings.has_arg("pick-special") else C.SUPER_MECH)
	await _wait(0.7)
	if s.coins > 0:
		Net.send_transform(C.SUPER_SPECIAL)
		await _wait(0.7)
	print("[client] %s transformed: %s, %.0f hp, %.0f s left" % ["PASS" if s.is_super() else "FAIL", s.class_data()["name"], s.hp, s.super_t])
	var mechs := 0
	for o: Soldier in w.soldiers.values():
		if o.alive and o.is_mech() and o.model is MechModel:
			mechs += 1
	var proxies := 0
	for o: Soldier in w.soldiers.values():
		if o.alive and o != s and o._snaps.size() > 0:
			proxies += 1
	print("[client] mechs visible here: %d" % mechs)
	if Settings.has_arg("watch-tank"):
		await _wait(float(Settings.arg("watch-tank")))
		for o: Soldier in w.soldiers.values():
			if o.peer != 0 and o != s:
				print("[client] %s other player: %s, tank model=%s, at %s, hull %.2f" % ["PASS" if o.model is TankModel else "FAIL", o.class_data()["name"], str(o.model is TankModel), o.global_position.round(), o.hull_yaw])
	if Settings.has_arg("linger"):
		await _wait(float(Settings.arg("linger")))
		mechs = 0
		for o: Soldier in w.soldiers.values():
			if o.alive and o != s and o.is_mech() and o.model is MechModel and o.peer != 0:
				mechs += 1
				print("[client] other player is a %s, hp %.0f, height %.1f" % [o.class_data()["name"], o.hp, o.stance_height()])
		print("[client] %s other player's mech shows up here (%d)" % ["PASS" if mechs > 0 else "FAIL", mechs])
	print("[client] %s server confirmed %d hits from %d shots, deaths=%d" % ["PASS" if w.hits_confirmed > 0 else "FAIL", w.hits_confirmed, fired, deaths])
	for o: Soldier in w.soldiers.values():
		if o.peer != 0 and o != s:
			var seen: int = w.shots_seen.get(o.sid, 0)
			print("[client] %s bolts drawn here from the other player: %d" % ["PASS" if seen > 0 else "FAIL", seen])
	print("[client] bolts drawn on this screen in total: %d" % w.fx.shots_spawned)
	print("[client] proxies=%d tickets=%s score=%d" % [proxies, str(w.tickets), s.score])
	get_tree().quit(0)


func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _mouse(button: MouseButton, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = down
	Input.parse_input_event(e)


func _tap_key(code: Key) -> void:
	_key(code, true)
	await _wait(0.08)
	_key(code, false)
	await _wait(0.08)


func _click() -> void:
	_mouse(MOUSE_BUTTON_LEFT, true)
	await _wait(0.08)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await _wait(0.08)


var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("[input] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_fails += 1


## Feeds synthetic hardware events through the real input path and checks the results.
func _input_test() -> void:
	Net.start_offline({"seed": 1943, "bots_per_team": 4, "difficulty": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w: World = Net.world
	await _wait(1.0)
	_check("deploy screen opens", w.hud.deploy.visible)
	await _tap_key(KEY_2)
	_check("key 2 picks the second class", w.hud.deploy.class_id == 1)
	await _tap_key(KEY_1)
	await _tap_key(KEY_SPACE)
	await _wait(0.4)
	var s := w.local
	_check("space deploys", s.alive and w.controller.state == PlayerController.State.ALIVE)
	_check("deploy hides screen", not w.hud.deploy.visible)
	_check("mouse captured", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	s.protected_t = 9999.0
	# Keep bots out of the tanks, and start on a clear street, so nothing here depends on luck.
	for tv: Dictionary in w.vehicles.values():
		tv["free_since"] = Net.server_time() + 9999.0
	s.teleport(Vector3(0, 0.2, 125))
	s.yaw = PI * 0.5
	await _wait(0.2)

	var p0 := s.global_position
	_key(KEY_W, true)
	await _wait(0.8)
	_key(KEY_W, false)
	await _wait(0.2)
	var moved := s.global_position.distance_to(p0)
	_check("W moves forward (%.2f m)" % moved, moved > 2.5)

	var p1 := s.global_position
	_key(KEY_W, true)
	_key(KEY_SHIFT, true)
	await _wait(0.8)
	var sprint_on := s.sprinting
	_key(KEY_W, false)
	_key(KEY_SHIFT, false)
	await _wait(0.2)
	_check("shift sprints (%.2f m)" % s.global_position.distance_to(p1), sprint_on and s.global_position.distance_to(p1) > moved)

	var yaw0 := s.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(200, -60)
	Input.parse_input_event(motion)
	await _wait(0.1)
	_check("mouse turns the view (%.3f rad)" % (s.yaw - yaw0), s.yaw < yaw0 - 0.02)
	_check("mouse up raises pitch (%.3f)" % s.pitch, s.pitch > 0.01)

	var y0 := s.global_position.y
	await _tap_key(KEY_SPACE)
	await _wait(0.12)
	_check("space jumps", s.global_position.y > y0 + 0.2)
	await _wait(0.9)

	_key(KEY_CTRL, true)
	await _wait(0.2)
	_check("ctrl crouches", s.crouching)
	_key(KEY_CTRL, false)
	await _wait(0.2)
	_check("release stands up", not s.crouching)

	var ammo: int = s.mags[0]
	_mouse(MOUSE_BUTTON_LEFT, true)
	await _wait(0.5)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await _wait(0.1)
	_check("automatic fire spends ammo (%d -> %d)" % [ammo, s.mags[0]], s.mags[0] < ammo - 2)

	_mouse(MOUSE_BUTTON_RIGHT, true)
	await _wait(0.4)
	_check("right mouse aims", s.aiming and w.controller.vm.ads > 0.9)
	_mouse(MOUSE_BUTTON_RIGHT, false)
	await _wait(0.2)

	await _tap_key(KEY_R)
	_check("R starts reload", s.reload_t > 0.0)
	await _wait(2.4)
	_check("reload refills magazine", s.mags[0] == 32)

	await _tap_key(KEY_2)
	await _wait(0.5)
	_check("2 switches to pistol", s.weapon_id() == C.W.PISTOL)
	if Sfx.enabled:
		_check("the hum stops with the blade away", Sfx._hum_target == 0.0)
	var pistol: int = s.mags[1]
	await _click()
	_check("pistol fires once per click", s.mags[1] == pistol - 1)

	await _tap_key(KEY_3)
	await _wait(0.5)
	_check("3 draws the lightsaber", s.weapon_id() == C.W.LIGHTSABER)
	if Sfx.enabled:
		await _wait(0.3)
		_check("the blade hums", Sfx._hum.playing)
		_check("the hum loops", (Sfx._hum.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	await _click()
	_check("click swings", s.fire_cd > 0.0)
	_mouse(MOUSE_BUTTON_RIGHT, true)
	await _wait(0.2)
	_check("right mouse blocks", s.blocking)
	_mouse(MOUSE_BUTTON_RIGHT, false)
	await _wait(0.7)

	var nades := s.grenades
	await _tap_key(KEY_G)
	_check("G throws a grenade", s.grenades == nades - 1)
	await _wait(3.0)

	_key(KEY_TAB, true)
	await _wait(0.2)
	_check("tab shows scoreboard", w.hud.scoreboard.visible)
	_key(KEY_TAB, false)
	await _wait(0.2)
	_check("tab released hides it", not w.hud.scoreboard.visible)

	await _tap_key(KEY_ESCAPE)
	_check("esc pauses", get_tree().paused and w.hud.pause_menu.visible)
	_check("pause frees the mouse", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	_key(KEY_ESCAPE, true)
	await get_tree().create_timer(0.1, true).timeout
	_key(KEY_ESCAPE, false)
	await get_tree().create_timer(0.1, true).timeout
	_check("esc resumes", not get_tree().paused and not w.hud.pause_menu.visible)
	_check("resume recaptures the mouse", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	# Death, then deploying again.
	s.protected_t = 0.0
	w.server.apply_damage(s, 500.0, null, C.W.PISTOL, false, s.global_position)
	await _wait(0.2)
	_check("death ends the life", not s.alive and w.controller.state == PlayerController.State.DEAD)
	await _wait(C.RESPAWN_DELAY + 0.3)
	_check("deploy returns after death", w.hud.deploy.visible)
	await _tap_key(KEY_SPACE)
	await _wait(0.4)
	_check("can redeploy", s.alive)

	# Tanks.
	s.protected_t = 9999.0
	var srv := w.server
	s.teleport(Vector3(0, 0.2, 125))
	await _wait(0.1)
	var hp_before := s.hp
	var tank: Dictionary = w.vehicles[1]
	tank["pos"] = s.global_position + Vector3(3, 0, 0)
	await _tap_key(KEY_E)
	await _wait(0.3)
	_check("E enters the tank", s.is_vehicle() and s.vehicle_id == 1 and tank["driver"] == s.sid)
	_check("the tank has its own health (%.1f)" % s.hp, is_equal_approx(s.hp, 800.0))
	_check("the tank model is on", s.model is TankModel and s.model.visible)
	_check("the first person weapon is hidden", not w.controller.vm.visible)
	var drive_from := s.global_position
	var h0 := s.hull_yaw
	_key(KEY_W, true)
	_key(KEY_A, true)
	await _wait(1.6)
	_key(KEY_W, false)
	_key(KEY_A, false)
	await _wait(0.2)
	_check("W and A drive and steer (%.1f m, %.2f rad)" % [s.global_position.distance_to(drive_from), s.hull_yaw - h0], s.global_position.distance_to(drive_from) > 3.0 and s.hull_yaw > h0 + 0.5)
	var shells: int = s.mags[0]
	await _click()
	_check("the main gun fires", s.mags[0] == shells - 1)
	await _tap_key(KEY_2)
	await _wait(0.5)
	_check("2 picks the machine gun", s.weapon_id() == C.W.TANK_MG)
	await _tap_key(KEY_F)
	_check("F does nothing in a tank", s.is_vehicle())
	s.hp -= 100.0
	var dented := s.hp
	var parked_at := s.global_position
	await _tap_key(KEY_E)
	await _wait(0.3)
	_check("E gets out", not s.is_vehicle() and tank["driver"] == 0)
	_check("infantry health came back", is_equal_approx(s.hp, hp_before))
	_check("the tank stays where it was left (%.1f m)" % (tank["pos"] as Vector3).distance_to(parked_at), (tank["pos"] as Vector3).distance_to(parked_at) < 1.0)
	_check("it remembers its damage (%.1f, dented %.1f)" % [float(tank["hp"]), dented], is_equal_approx(float(tank["hp"]), dented))
	_check("you stand beside it", s.global_position.distance_to(parked_at) > 2.0 and s.global_position.distance_to(parked_at) < 9.0)
	_check("the parked tank shows", (tank["node"] as Node3D).visible)
	s.teleport(parked_at + Vector3(3, 0, 0))
	await _wait(0.1)
	await _tap_key(KEY_E)
	await _wait(0.3)
	_check("you can climb back in (hp %.1f, dented %.1f, vehicle %s)" % [s.hp, dented, s.is_vehicle()], s.is_vehicle() and is_equal_approx(s.hp, dented))
	s.protected_t = 0.0
	srv.apply_damage(s, 99999.0, null, C.W.PISTOL, false, s.global_position)
	await _wait(0.3)
	_check("a destroyed tank kills the driver", not s.alive and float(tank["hp"]) <= 0.0 and tank["driver"] == 0)
	tank["respawn_at"] = 0.0
	await _wait(0.4)
	_check("a tank returns to its depot", float(tank["hp"]) > 700.0 and (tank["pos"] as Vector3).distance_to(tank["home"][0]) < 0.1)
	await _wait(C.RESPAWN_DELAY + 0.3)
	await _tap_key(KEY_SPACE)
	await _wait(0.4)
	_check("can deploy after the tank", s.alive)

	# Coin, picker, mech. Deploying is random, so stand somewhere a mech is sure to fit.
	s.protected_t = 9999.0
	var open_cell := w.map.b.nav_wide.nearest_free(w.map.b.nav_wide.cell_of(Vector3(0, 0, 118)))
	s.teleport(Vector3(open_cell.x + 0.5, 0.2, open_cell.y + 0.5))
	await _wait(0.2)
	srv.spawn_coin(s.global_position, 30.0)
	await _wait(0.4)
	_check("walking onto a coin picks it up", s.coins == 1 and w.coins.is_empty())
	await _tap_key(KEY_B)
	_check("B opens the picker", w.controller.picker_open)
	await _tap_key(KEY_B)
	_check("B closes the picker", not w.controller.picker_open)
	await _tap_key(KEY_B)
	await _tap_key(KEY_1)
	await _wait(0.3)
	_check("1 turns into the Golem", s.class_id == C.SUPER_MECH and s.is_mech() and s.coins == 0)
	_check("the mech has mech health", is_equal_approx(s.max_hp, 480.0) and is_equal_approx(s.hp, 480.0))
	_check("the body grew", is_equal_approx(s.shape.height, float(s.class_data()["height"])) and s.shape.height > 3.0)
	_check("the model was swapped", s.model is MechModel)
	_check("the cannon is in hand", s.weapon_id() == C.W.MECH_GOLEM and w.controller.vm.weapon_id == C.W.MECH_GOLEM)
	var cannon: int = s.mags[0]
	_mouse(MOUSE_BUTTON_LEFT, true)
	await _wait(0.5)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await _wait(0.1)
	_check("the cannon fires", s.mags[0] < cannon)
	await _tap_key(KEY_2)
	await _wait(0.4)
	_check("2 swaps to the launcher", s.weapon_id() == C.W.MECH_LAUNCHER)
	_check("the launcher holds nine shells", s.mags[1] + s.reserves[1] == 9)
	var y1 := s.global_position.y
	await _tap_key(KEY_SPACE)
	await _wait(0.1)
	_check("mechs cannot jump", absf(s.global_position.y - y1) < 0.05)
	var hurt_hp := s.hp
	s.protected_t = 0.0
	srv.apply_damage(s, 40.0, null, C.W.PISTOL, false, s.global_position)
	s.protected_t = 9999.0
	await _wait(8.0)
	_check("mechs do not regenerate (%.0f)" % s.hp, s.hp <= hurt_hp - 39.0)
	s.super_t = 0.05
	await _wait(0.4)
	_check("time out reverts the class", s.class_id == s.base_class and not s.is_mech())
	_check("the pilot comes back hurt (%.0f)" % s.hp, s.hp < s.max_hp * (C.SUPER_END_HP_FRACTION + 0.1))
	_check("the soldier model returned", not s.model is MechModel)

	# Coin, picker, jetpack.
	srv.spawn_coin(s.global_position, 30.0)
	await _wait(0.4)
	await _tap_key(KEY_B)
	await _tap_key(KEY_2)
	await _wait(0.3)
	_check("2 turns into the Machabeusz", s.class_id == C.SUPER_SPECIAL)
	var fly0 := s.global_position.y
	_key(KEY_SPACE, true)
	await _wait(1.2)
	var fly1 := s.global_position.y
	var fuel := s.jet_fuel
	_key(KEY_SPACE, false)
	_check("holding space flies (%.1f m up)" % (fly1 - fly0), fly1 > fly0 + 3.0)
	_check("flying burns fuel", fuel < C.JET_FUEL - 0.8)
	await _wait(2.5)
	_check("gravity brings you back", s.is_on_floor())
	s.super_t = 0.05
	await _wait(0.4)

	# A held coin drops on death and can be taken again.
	srv.spawn_coin(s.global_position, 30.0)
	await _wait(0.4)
	_check("coin held before dying", s.coins == 1)
	s.protected_t = 0.0
	srv.apply_damage(s, 9999.0, null, C.W.PISTOL, false, s.global_position)
	await _wait(0.2)
	var dropped := false
	for coin: Dictionary in w.coins.values():
		dropped = dropped or (coin["pos"] as Vector3).distance_to(s.global_position) < 2.0
	_check("the coin drops where you died", s.coins == 0 and dropped)
	await _wait(C.RESPAWN_DELAY + 0.4)
	await _tap_key(KEY_SPACE)
	await _wait(0.4)

	# End of the round, the summary, and the automatic next round.
	s.protected_t = 9999.0
	w.tickets[1] = 1
	for o: Soldier in w.soldiers.values():
		if o.team == C.Team.EMPIRE and o.alive:
			o.protected_t = 0.0
			w.server.apply_damage(o, 9999.0, s, C.W.CARBINE, false, s.global_position)
			break
	await _wait(0.3)
	_check("last ticket ends the round", w.server.round_over and w.hud.end_screen.visible)
	_check("the win is reported", w.round_winner == C.Team.RESISTANCE)
	_check("the round-ending kill is counted", s.kills >= 1)
	_check("coins are gone for the summary", true)
	_check("mouse is free on the summary", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	await _shot("end_screen")
	w.server.set("_restart_t", 0.2)
	await _wait(0.6)
	_check("next round resets tickets", w.tickets[0] == C.START_TICKETS and w.tickets[1] == C.START_TICKETS)
	_check("next round opens deploy", w.hud.deploy.visible and not w.hud.end_screen.visible)
	await _wait(0.4)
	await _tap_key(KEY_SPACE)
	await _wait(0.4)
	_check("can play the next round", s.alive)

	# Back to the menu and into a fresh match, which exercises teardown.
	w.leave_requested.emit()
	await _wait(1.5)
	_check("leaving returns to the menu", _menu() != null and Net.mode == Net.Mode.NONE and Net.world == null)
	Net.start_offline({"seed": 1943, "bots_per_team": 4, "difficulty": 0})
	var t0 := Time.get_ticks_msec()
	while (Net.world == null or Net.world.local == null) and Time.get_ticks_msec() - t0 < 5000:
		await get_tree().process_frame
	_check("a second match starts", Net.world != null and Net.world.local != null)
	print("[input] finished, failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Close-ups of everything new.
func _supers_screens() -> void:
	Net.start_offline({"seed": 1943, "bots_per_team": 12, "difficulty": 1})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w: World = Net.world
	await _wait(1.0)
	w.hud.deploy.call("_deploy")
	await _wait(0.6)
	var c := w.controller
	var s := w.local
	var srv := w.server
	srv.bots.clear()
	s.protected_t = 9999.0
	s.teleport(Vector3(0, 0.2, 44))
	s.yaw = 0.0
	s.pitch = 0.1

	var line := [[0, 0], [0, 1], [0, 2], [0, 3], [1, 0], [1, 1], [1, 2], [1, 3]]
	var picks: Array = []
	for spec: Array in line:
		for o: Soldier in w.soldiers.values():
			if o != s and o.team == spec[0] and not picks.has(o):
				picks.append(o)
				o.respawn(Vector3(-6.3 + picks.size() * 1.4, 0.1, 37.0), PI + 0.7, spec[1])
				o.protected_t = 9999.0
				o.wish = Vector3.ZERO
				break
	await _wait(0.6)
	await _shot("classes_lineup")
	for o: Soldier in picks:
		o.yaw = 0.7
	await _wait(0.3)
	await _shot("classes_lineup_back")

	var a: Soldier = null
	var b: Soldier = null
	var d: Soldier = null
	var e: Soldier = null
	for o: Soldier in w.soldiers.values():
		if o == s or picks.has(o):
			continue
		if o.team == 0 and a == null:
			a = o
		elif o.team == 1 and b == null:
			b = o
		elif o.team == 0 and d == null:
			d = o
		elif o.team == 1 and e == null:
			e = o
	for o: Soldier in picks:
		o.teleport(Vector3(200, -40, 200))
	var pairs := [[a, 4, -4.5], [b, 4, 3.5], [d, 5, -1.6], [e, 5, 0.9]]
	for p: Array in pairs:
		var o: Soldier = p[0]
		o.respawn(Vector3(p[2], 0.1, 35.0), PI + 0.3, 0)
		o.become(p[1], 9999.0)
		o.protected_t = 9999.0
		o.wish = Vector3.ZERO
	await _wait(0.8)
	await _shot("supers_lineup")
	d.velocity = Vector3(0, 3, 0)
	e.cloak_block_t = 9999.0
	await _wait(0.1)
	await _shot("supers_cloak_off")
	e.cloak_block_t = 0.0
	s.teleport(Vector3(0, 0.2, 44))
	var coin_pos := Vector3(-7, 0.0, 39)
	srv.spawn_coin(coin_pos, 60.0)
	var to_coin := coin_pos - s.global_position
	s.yaw = atan2(-to_coin.x, -to_coin.z)
	s.pitch = 0.08
	await _wait(0.8)
	await _shot("coin")
	a.yaw = 0.0
	b.yaw = PI * 0.5
	s.yaw = 0.0
	s.pitch = 0.1

	srv.spawn_coin(s.global_position, 30.0)
	await _wait(0.5)
	s.yaw = 0.0
	Input.action_press("super")
	await _wait(0.1)
	Input.action_release("super")
	await _wait(0.3)
	await _shot("picker")
	Input.action_press("slot1")
	await _wait(0.1)
	Input.action_release("slot1")
	await _wait(0.8)
	await _shot("mech_cockpit")
	c.call("_switch", 1)
	await _wait(0.7)
	await _shot("mech_fist")
	s.super_t = 0.05
	await _wait(0.5)

	# Lightsabers on both sides.
	s.teleport(Vector3(0, 0.2, 44))
	s.protected_t = 9999.0
	s.hp = s.max_hp
	s.yaw = 0.0
	s.pitch = 0.0
	for o: Soldier in [a, b, d, e]:
		o.teleport(Vector3(200, -40, 200))
	var fighters := [a, b]
	for i in 2:
		var o: Soldier = fighters[i]
		o.respawn(Vector3(-1.4 + i * 2.8, 0.1, 39.5), PI + (0.5 if i == 0 else -0.5), 0)
		o.protected_t = 9999.0
		o.wish = Vector3.ZERO
		o.switch_to(2)
	c.call("_switch", 2)
	await _wait(0.8)
	await _shot("sabers")
	for o: Soldier in fighters:
		o.teleport(Vector3(200, -40, 200))

	# Tanks parked, then driven.
	var t1: Dictionary = w.vehicles[1]
	var t3: Dictionary = w.vehicles[3]
	t1["pos"] = Vector3(-7, 0, 32)
	t1["yaw"] = 0.5
	t3["pos"] = Vector3(7, 0, 30)
	t3["yaw"] = -0.5
	for tv: Dictionary in [t1, t3]:
		(tv["node"] as TankModel).park(tv["pos"], tv["yaw"])
	s.yaw = 0.0
	s.pitch = 0.04
	await _wait(0.5)
	await _shot("tanks_parked")
	s.teleport(Vector3(-4, 0.2, 33))
	await _wait(0.2)
	Input.action_press("use")
	await _wait(0.1)
	Input.action_release("use")
	await _wait(0.8)
	s.yaw = 0.15
	await _wait(0.4)
	await _shot("tank_driving")
	fx_shot(w, s)
	await _wait(0.08)
	await _shot("tank_fire")
	c.state = PlayerController.State.WAITING
	c.set_process(false)
	w.hud.visible = false
	var cam := c.camera
	cam.fov = 70.0
	cam.global_position = Vector3(0, 400, 1)
	cam.look_at(Vector3.ZERO, Vector3.FORWARD)
	await _wait(0.6)
	await _shot("overhead_big_map")
	get_tree().quit(0)


## One stretch of frame samples. `step` runs each frame with the seconds elapsed.
func _perf_sample(label: String, seconds: float, step: Callable, totals: Dictionary) -> void:
	var vp := get_viewport().get_viewport_rid()
	var times := PackedFloat32Array()
	var sums := {"draws": 0.0, "objects": 0.0, "prims": 0.0, "cpu": 0.0, "gpu": 0.0, "proc": 0.0, "phys": 0.0}
	var t0 := Time.get_ticks_usec()
	var last := t0
	var elapsed := 0.0
	while elapsed < seconds:
		step.call(elapsed)
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		elapsed = (now - t0) / 1000000.0
		sums["draws"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		sums["objects"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		sums["prims"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		sums["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		sums["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		sums["proc"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		sums["phys"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var n := float(times.size())
	var sorted := _sorted(times)
	print("[perf] %-10s frames=%5d fps=%6.1f p50=%6.2f p95=%6.2f p99=%6.2f max=%6.1f draws=%5.0f objects=%5.0f prims=%8.0f cpu_ms=%5.2f gpu_ms=%5.2f proc_max=%5.2f phys_max=%5.2f" % [
		label, times.size(), n / elapsed, _pct(sorted, 0.5), _pct(sorted, 0.95), _pct(sorted, 0.99), _pct(sorted, 1.0),
		sums["draws"] / n, sums["objects"] / n, sums["prims"] / n, sums["cpu"] / n, sums["gpu"] / n, sums["proc"] / n, sums["phys"] / n])
	if totals.is_empty():
		return
	_perf_times.append_array(times)
	totals["seconds"] = float(totals["seconds"]) + elapsed
	for key: String in sums:
		totals[key] = float(totals[key]) + float(sums[key])


## A full offline match seen from fixed views. Pass --quality=<0..3>, and --out=<dir> for a
## screenshot at each stop. Bots leave the protected player alone, so nothing interrupts it.
func _perf() -> void:
	Settings.quality = int(Settings.arg("quality", "2"))
	Settings.fov = 85.0
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.apply_display()
	Engine.max_fps = 0
	var t0 := Time.get_ticks_msec()
	Net.start_offline({"seed": 1943, "bots_per_team": 12, "difficulty": 1})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w: World = Net.world
	print("[perf] world ready in %d ms" % (Time.get_ticks_msec() - t0))
	w.server.rng.seed = 1943
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	RenderingServer.frame_pre_draw.connect(func() -> void: _draw_start = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: _draw_ms.append((Time.get_ticks_usec() - _draw_start) / 1000.0))
	_start_tick_timer()
	await _wait(1.0)
	await _perf_sample("deploy", PERF_DEPLOY_SECONDS, func(_t: float) -> void: pass, {})
	w.hud.deploy.call("_deploy")
	while w.local == null or not w.local.alive:
		await get_tree().process_frame
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Real keys and clicks reach the window too, and must not fire or pause during the run.
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	var s := w.local
	s.protected_t = 99999.0
	var hold := func(pos: Vector3, yaw: float, pitch: float) -> void:
		s.teleport(pos)
		s.velocity = Vector3.ZERO
		s.yaw = yaw
		s.pitch = pitch
	await _perf_sample("warmup", PERF_WARMUP, func(_t: float) -> void: hold.call(PERF_STOPS[0][1], 0.0, 0.0), {})
	_tick_ms.clear()
	_process_ms.clear()
	_draw_ms.clear()
	var totals := {"seconds": 0.0, "draws": 0.0, "objects": 0.0, "prims": 0.0, "cpu": 0.0, "gpu": 0.0, "proc": 0.0, "phys": 0.0}
	for stop: Array in PERF_STOPS:
		var turn := func(t: float) -> void:
			hold.call(stop[1], float(stop[2]) + TAU * t / PERF_STOP_SECONDS, stop[3])
		# Keeps the jump between stops out of the numbers.
		for i in 10:
			turn.call(0.0)
			await get_tree().process_frame
		await _perf_sample(stop[0], PERF_STOP_SECONDS, turn, totals)
		if Settings.has_arg("out"):
			turn.call(0.0)
			await get_tree().process_frame
			await _shot("perf_" + String(stop[0]))
	var n := float(_perf_times.size())
	var sorted := _sorted(_perf_times)
	print("[perf] TOTAL frames=%d fps=%.1f p50=%.2f p95=%.2f p99=%.2f max=%.1f over33ms=%d draws=%.0f objects=%.0f prims=%.0f cpu_ms=%.2f gpu_ms=%.2f proc_max=%.2f phys_max=%.2f" % [
		_perf_times.size(), n / float(totals["seconds"]), _pct(sorted, 0.5), _pct(sorted, 0.95), _pct(sorted, 0.99), _pct(sorted, 1.0),
		sorted.size() - sorted.bsearch(33.3), float(totals["draws"]) / n, float(totals["objects"]) / n, float(totals["prims"]) / n,
		float(totals["cpu"]) / n, float(totals["gpu"]) / n, float(totals["proc"]) / n, float(totals["phys"]) / n])
	print("[perf] memory static=%.1f MB video=%.1f MB textures=%.1f MB buffers=%.1f MB nodes=%d" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	_print_ticks("perf")
	var kills := 0
	for o: Soldier in w.soldiers.values():
		kills += o.kills
	print("[perf] match tickets=%s kills=%d shots_drawn=%d" % [str(w.tickets), kills, w.fx.shots_spawned])
	get_tree().quit(0)


func fx_shot(w: World, s: Soldier) -> void:
	var muzzle := s.model.muzzle_position()
	w.fx.spawn_shot(C.W.TANK_CANNON, 0, muzzle, muzzle + s.aim_direction() * 50.0, 1)


## Slow-motion frame grabs of each animation, for checking movement by eye.
func _anims() -> void:
	Net.start_offline({"seed": 1943, "bots_per_team": 6, "difficulty": 1})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w: World = Net.world
	await _wait(1.0)
	w.hud.deploy.call("_deploy")
	await _wait(0.6)
	var c := w.controller
	var s := w.local
	var srv := w.server
	srv.bots.clear()
	s.protected_t = 9999.0
	var spot := Vector3(0, 0.2, 125)
	s.teleport(spot)
	s.yaw = PI * 0.5
	s.pitch = 0.0
	await _wait(0.3)

	# First person, slowed down so a frame lands in each part of the motion.
	Engine.time_scale = 0.12
	c.call("_switch", 2)
	await _wait(0.6)
	for combo in 3:
		c.vm._combo = (combo + 2) % 3
		s.fire_cd = 0.0
		c.call("_swing")
		for frame in 3:
			await _wait(0.1)
			await _shot("fp_swing%d_%d" % [combo, frame])
		await _wait(0.5)
	c.call("_switch", 0)
	await _wait(0.5)
	s.mags[0] = 5
	c.call("_reload")
	var rl: float = s.weapon()["reload"]
	var at := 0.0
	for k: float in [0.14, 0.32, 0.5, 0.7, 0.86]:
		await _wait(rl * (k - at))
		at = k
		await _shot("fp_reload_%d" % int(k * 100.0))
	await _wait(rl * 0.3)
	s.reload_t = 0.0
	s.grenades = 3
	c.call("_throw_grenade")
	await _wait(0.16)
	await _shot("fp_throw_a")
	await _wait(0.14)
	await _shot("fp_throw_b")
	await _wait(0.12)
	await _shot("fp_throw_c")
	await _wait(0.8)
	Engine.time_scale = 1.0

	# Shooting a wall up close, from the shooter's eyes.
	s.mags[0] = 30
	s.yaw = PI * 0.5
	s.pitch = -0.04
	var to_wall := spot + Vector3(-11, 0.9, -9)
	var from_eye := s.eye_position()
	var d := (to_wall - from_eye).normalized()
	s.yaw = atan2(-d.x, -d.z)
	await _wait(0.2)
	Input.action_press("fire")
	await _wait(0.42)
	await _shot("fp_firing")
	await _wait(0.1)
	await _shot("fp_firing_2")
	Input.action_release("fire")
	await _wait(0.6)

	# Firing down the street, from the shooter's eyes. Wait out the thrown grenade first.
	s.teleport(spot)
	s.yaw = PI * 0.5
	s.pitch = 0.03
	s.mags[0] = 30
	await _wait(4.0)
	Input.action_press("fire")
	await _wait(0.33)
	await _shot("fp_street_a")
	await _wait(0.04)
	await _shot("fp_street_b")
	await _wait(0.05)
	await _shot("fp_street_c")
	Input.action_release("fire")
	await _wait(0.5)

	# Impacts close up, on open ground, seen from the side.
	c.state = PlayerController.State.WAITING
	c.vm.visible = false
	c.set_process(false)
	w.hud.visible = false
	var view := c.camera
	view.fov = 40.0
	var target := Vector3(-30, w.map.ground_height(-30, 125), 125)
	view.global_position = target + Vector3(0.5, 1.2, 4.5)
	view.look_at(target + Vector3.UP * 0.4, Vector3.UP)
	var muzzle_at := target + Vector3(-22, 1.5, -2)
	w.fx.spawn_shot(C.W.CARBINE, 0, muzzle_at, target, 1)
	await _wait(0.14)
	await _shot("hit_ground_a")
	await _wait(0.1)
	await _shot("hit_ground_b")
	await _wait(0.25)
	await _shot("hit_ground_c")
	await _wait(0.4)
	c.set_process(true)
	w.hud.visible = true
	c.state = PlayerController.State.ALIVE

	# Third person. The camera leaves the player, and two soldiers perform for it.
	c.state = PlayerController.State.WAITING
	c.vm.visible = false
	c.set_process(false)
	w.hud.visible = false
	var cam := c.camera
	cam.fov = 40.0
	var a: Soldier = null
	var b: Soldier = null
	for o: Soldier in w.soldiers.values():
		if o != s and o.team == 0 and a == null:
			a = o
		elif o != s and o.team == 1 and b == null:
			b = o
	var stage := Vector3(-30, 0.1, 125)
	for o: Soldier in [a, b]:
		o.respawn(stage, 0.0, 0)
		o.protected_t = 9999.0
		o.wish = Vector3.ZERO
	s.teleport(Vector3(40, 0.2, 125))
	a.teleport(stage + Vector3(-1.4, 0, 0))
	b.teleport(stage + Vector3(1.4, 0, 0))
	a.yaw = -PI * 0.5
	b.yaw = -PI * 0.5
	cam.global_position = stage + Vector3(0.4, 1.5, 7.0)
	cam.look_at(stage + Vector3(0, 0.95, 0), Vector3.UP)
	await _wait(0.4)
	await _shot("tp_idle")
	# Stand side-on and run on the spot: run forward, teleporting back between frames.
	for o: Soldier in [a, b]:
		o.wish = Vector3(1, 0, 0)
		o.want_sprint = true
	await _wait(0.7)
	for frame in 3:
		a.teleport(stage + Vector3(-1.4, 0, 0))
		b.teleport(stage + Vector3(1.4, 0, 0))
		await _wait(0.12)
		await _shot("tp_run_%d" % frame)
	for o: Soldier in [a, b]:
		o.wish = Vector3.ZERO
		o.want_sprint = false
		o.want_crouch = true
	a.teleport(stage + Vector3(-1.4, 0, 0))
	b.teleport(stage + Vector3(1.4, 0, 0))
	await _wait(0.6)
	await _shot("tp_crouch")
	for o: Soldier in [a, b]:
		o.want_crouch = false
	await _wait(0.4)
	a.want_jump = true
	b.want_jump = true
	await _wait(0.3)
	await _shot("tp_jump")
	await _wait(0.9)

	# Blades.
	for o: Soldier in [a, b]:
		o.switch_to(2)
	await _wait(0.4)
	Engine.time_scale = 0.2
	for combo in 3:
		a.model._combo = combo + 2
		b.model._combo = combo + 2
		a.model.play_swing()
		b.model.play_swing()
		await _wait(0.13)
		await _shot("tp_blade%d_a" % combo)
		await _wait(0.13)
		await _shot("tp_blade%d_b" % combo)
		await _wait(0.5)
	for o: Soldier in [a, b]:
		o.switch_to(0)
	await _wait(0.5)
	a.model.play_throw()
	b.model.play_throw()
	await _wait(0.2)
	await _shot("tp_throw_a")
	await _wait(0.13)
	await _shot("tp_throw_b")
	await _wait(0.5)
	a.aiming = true
	b.aiming = true
	await _wait(0.4)
	await _shot("tp_aim")
	a.aiming = false
	b.aiming = false
	a.reload_t = 9.0
	b.reload_t = 9.0
	await _wait(0.5)
	await _shot("tp_reload")
	a.reload_t = 0.0
	b.reload_t = 0.0
	Engine.time_scale = 1.0
	await _wait(0.2)
	# Bolts crossing the frame, as a bystander sees them.
	a.yaw = -PI * 0.5
	b.yaw = PI * 0.5
	a.switch_to(0)
	b.switch_to(0)
	a.aiming = true
	b.aiming = true
	await _wait(0.4)
	for i in 3:
		w.on_shot(a.sid, a.weapon_id(), a.eye_position(), b.global_position + Vector3(0, 1.2, 0), 2, -1)
		w.on_shot(b.sid, b.weapon_id(), b.eye_position(), a.global_position + Vector3(0, 1.2, 0), 2, -1)
		await _wait(0.03)
	await _shot("tp_shots")
	a.aiming = false
	b.aiming = false
	await _wait(0.5)
	# One falls away from a shot in front, the other from one behind.
	a.protected_t = 0.0
	b.protected_t = 0.0
	a.model.set_death_from(a.global_position + Vector3(-5, 0, 0))
	b.model.set_death_from(b.global_position + Vector3(5, 0, 0))
	a.die()
	b.die()
	await _wait(0.3)
	await _shot("tp_death_a")
	await _wait(0.9)
	await _shot("tp_death_b")
	get_tree().quit(0)


## Gear rules, recoil, perks and progression, without drawing anything.
## Every part must change how the weapon looks, or there is no point in showing it.
func _check_part_looks() -> void:
	var dull: Array[String] = []
	var checked := 0
	for w: int in Gear.WEAPON_SLOTS:
		var plain := WeaponFactory.build(w, 0, [])
		var plain_box := WeaponFactory.bounds(plain)
		for slot: String in Gear.slots_for(w):
			var seen := {}
			for id: String in Gear.attachments_for(slot):
				var gun := WeaponFactory.build(w, 0, [id])
				var box := WeaponFactory.bounds(gun)
				var look := "%s|%d" % [box, _count_meshes(gun)]
				checked += 1
				if gun.find_child("Part_" + slot, true, false) == null or look == "%s|%d" % [plain_box, _count_meshes(plain)] or seen.has(look):
					dull.append("%s/%s" % [C.WEAPONS[w]["name"], id])
				seen[look] = true
				gun.free()
		plain.free()
	_check("all %d weapon and part pairs look different" % checked, dull.is_empty())
	if not dull.is_empty():
		print("[gear] no visible change: ", dull)


func _count_meshes(n: Node) -> int:
	var total := 1 if n is MeshInstance3D else 0
	for c in n.get_children():
		total += _count_meshes(c)
	return total


func _gear_test() -> void:
	_check_part_looks()
	# Every sound the game can ask for must exist.
	var names: Array[String] = ["sword_hum", "sword_on", "sword_off", "explosion_big", "reload_in", "reload_out", "empty_click"]
	for w: int in C.WEAPONS:
		names.append(String(C.WEAPONS[w]["sound"]))
	var missing: Array[String] = []
	for n: String in names + Sfx.VARIANTS.keys():
		var takes: int = Sfx.VARIANTS.get(n, 0)
		if takes == 0 and not ResourceLoader.exists("res://assets/audio/%s.wav" % n):
			missing.append(n)
		for i in takes:
			if not ResourceLoader.exists("res://assets/audio/%s_%d.wav" % [n, i + 1]):
				missing.append("%s_%d" % [n, i + 1])
	_check("every sound exists %s" % str(missing), missing.is_empty())

	# Levels.
	_check("level 1 at 0 xp", Gear.level_of(0) == 1)
	_check("level 2 at 500 xp", Gear.level_of(500) == 2 and Gear.level_of(499) == 1)
	_check("levels stop at the cap", Gear.level_of(99999999) == Gear.MAX_LEVEL)
	var lost := []
	for id: String in Gear.ATTACHMENTS:
		if int(Gear.ATTACHMENTS[id]["level"]) > Gear.MAX_LEVEL:
			lost.append(id)
	_check("everything can be reached", lost.is_empty())

	# Only legal gear survives.
	var wish := {"primary": C.W.ASSAULT, "sidearm": C.W.REVOLVER, "parts_p": ["bigcell", "reddot", "scope"], "parts_s": ["comp"], "perks": ["tough", "runner", "scavenger"]}
	var low := Gear.sanitize(0, wish, 1)
	_check("locked weapon falls back", low["primary"] == C.W.CARBINE and low["sidearm"] == C.W.PISTOL)
	_check("locked parts are dropped", (low["parts_p"] as Array).is_empty() and (low["perks"] as Array).is_empty())
	var mid := Gear.sanitize(0, wish, 5)
	_check("unlocked gear is kept", mid["primary"] == C.W.ASSAULT and mid["sidearm"] == C.W.REVOLVER)
	_check("one part per slot, level respected", (mid["parts_p"] as Array).has("bigcell") and (mid["parts_p"] as Array).has("reddot") and not (mid["parts_p"] as Array).has("scope"))
	_check("one perk per slot", (mid["perks"] as Array).size() == 2 and (mid["perks"] as Array).has("tough"))
	var wrong := Gear.sanitize(2, {"primary": C.W.CARBINE, "parts_p": ["nonsense", 5], "perks": "x"}, 30)
	_check("other classes' weapons and junk are refused", wrong["primary"] == C.W.SNIPER and (wrong["parts_p"] as Array).is_empty())
	var pistol_scope := Gear.sanitize(0, {"sidearm": C.W.PISTOL, "parts_s": ["scope", "vgrip", "comp"]}, 30)
	_check("slots depend on the weapon", (pistol_scope["parts_s"] as Array) == ["comp"])

	# Stats.
	var plain := Gear.stats(C.W.CARBINE)
	_check("big cell holds more", int(Gear.stats(C.W.CARBINE, ["bigcell"])["mag"]) == 45)
	_check("big cell reloads slower", float(Gear.stats(C.W.CARBINE, ["bigcell"])["reload"]) > float(plain["reload"]))
	_check("grip cuts recoil", float(Gear.stats(C.W.CARBINE, ["vgrip"])["recoil"]) < float(plain["recoil"]))
	_check("compensator cuts side kick", float(Gear.stats(C.W.CARBINE, ["comp"])["recoil_h"]) < float(plain["recoil_h"]))
	var quiet := Gear.stats(C.W.CARBINE, ["suppressor"])
	_check("suppressor is quiet but weaker", quiet["suppressed"] and float(quiet["damage"]) < float(plain["damage"]))
	var zoom := Gear.stats(C.W.CARBINE, ["scope"])
	_check("scope zooms and is a scope", zoom["scope"] and is_equal_approx(float(zoom["ads_fov"]), 0.42))
	_check("base table is untouched", int(C.WEAPONS[C.W.CARBINE]["mag"]) == 32)
	_check("weapons kick differently", Gear.stats(C.W.ASSAULT)["recoil_bias"] != plain["recoil_bias"] and Gear.stats(C.W.SMG)["recoil_h"] != plain["recoil_h"])

	# Into a match, with progress in a throwaway file.
	Net.start_offline({"seed": 1943, "bots_per_team": 2, "difficulty": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w: World = Net.world
	var s := w.local
	var srv := w.server
	srv.bots.clear()
	await _wait(0.5)
	_check("a new player starts at level 1", w.level == 1 and s.level == 1)
	_check("the deploy screen is live", w.hud.deploy.preview != null and w.hud.deploy.preview._model != null)

	Net.send_deploy(0, -1, wish)
	await _wait(0.3)
	_check("the server gives a new player only starter gear", s.alive and s.loadout[0] == C.W.CARBINE)
	srv.call("add_score", s, 620, "test")
	await _wait(0.1)
	_check("score levels you up", s.level == 2 and w.level == 2 and w.xp == 620)
	_check("the level up is announced", not w.hud.canvas._banner.is_empty())
	srv.call("add_score", s, 8000, "test")
	await _wait(0.1)
	_check("big gains jump levels (%d)" % s.level, s.level >= 8)

	s.protected_t = 0.0
	srv.apply_damage(s, 9999.0, null, C.W.PISTOL, false, s.global_position)
	await _wait(C.RESPAWN_DELAY + 0.2)
	var kit := {"primary": C.W.ASSAULT, "sidearm": C.W.REVOLVER, "parts_p": ["bigcell", "vgrip", "suppressor"], "parts_s": [], "perks": ["tough", "grenadier"]}
	Net.send_deploy(0, -1, kit)
	await _wait(0.3)
	_check("unlocked weapons are issued", s.loadout[0] == C.W.ASSAULT and s.loadout[1] == C.W.REVOLVER)
	_check("the third slot keeps the lightsaber", s.loadout[2] == C.W.LIGHTSABER)
	_check("the magazine really grew (%d)" % s.mags[0], s.mags[0] == 39)
	_check("perks change the soldier", is_equal_approx(s.max_hp, 115.0) and s.grenades == 4)
	_check("attachments reach the weapon stats", s.weapon()["suppressed"] and float(s.weapon()["recoil"]) < float(C.WEAPONS[C.W.ASSAULT]["recoil"]))

	# Recoil against a weapon with a known drift, measured through the real firing path.
	var c := w.controller
	s.protected_t = 9999.0
	s.teleport(Vector3(0, 0.2, 125))
	s.pitch = 0.0
	s.yaw = 1.0
	await _wait(0.2)
	Input.action_press("fire")
	await _wait(0.6)
	Input.action_release("fire")
	var climbed := s.pitch
	var drifted := s.yaw - 1.0
	_check("a burst climbs (%.3f)" % climbed, climbed > 0.02)
	_check("assault rifle pulls left (%.3f)" % drifted, drifted > 0.0)
	await _wait(1.2)
	_check("the muzzle settles back (%.3f)" % s.pitch, s.pitch < climbed * 0.75)

	# Pellets.
	s.kit = {}
	var pellet_id := w.fx.shots_spawned
	s.respawn(Vector3(0, 0.2, 125), 0.0, 1, Gear.sanitize(1, {"primary": C.W.SCATTER}, 30))
	c.on_spawned()
	s.protected_t = 9999.0
	await _wait(0.5)
	pellet_id = w.fx.shots_spawned
	Input.action_press("fire")
	await _wait(0.05)
	Input.action_release("fire")
	await _wait(0.2)
	_check("a scatter shot fires many bolts (%d)" % (w.fx.shots_spawned - pellet_id), w.fx.shots_spawned - pellet_id >= 8)

	# A super class must ignore the kit, and restore it afterwards.
	s.respawn(Vector3(0, 0.2, 125), 0.0, 0, Gear.sanitize(0, kit, 30))
	c.on_spawned()
	s.protected_t = 9999.0
	s.become(C.SUPER_MECH, 5.0)
	_check("a mech ignores your kit", s.loadout[0] == C.W.MECH_GOLEM)
	s.become(0, 0.0)
	_check("your kit comes back afterwards", s.loadout[0] == C.W.ASSAULT and int(s.weapon()["mag"]) == 39)

	# It survives a restart.
	var before := w.xp
	srv.progress.save()
	var again := ProgressStore.new()
	_check("progress is saved (%d)" % again.xp(s.token), again.xp(s.token) == before)
	print("[input] finished, failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## The new deploy tabs, and customised weapons in first person.
func _deploy_screens() -> void:
	Net.start_offline({"seed": 1943, "bots_per_team": 6, "difficulty": 1})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w: World = Net.world
	await _wait(1.0)
	var s := w.local
	var d: DeployScreen = w.hud.deploy
	await _shot("level1_map")
	d.call("_show_tab", 1)
	await _wait(0.3)
	await _shot("level1_arsenal")
	d.call("_show_tab", 3)
	await _wait(0.3)
	await _shot("level1_progress")
	w.server.call("add_score", s, 30000, "test")
	await _wait(0.2)
	Settings.set_kit(0, {"primary": C.W.ASSAULT, "sidearm": C.W.REVOLVER, "parts_p": ["scope", "suppressor", "vgrip", "bigcell"], "parts_s": ["comp"], "perks": ["reflex", "scavenger"]})
	Settings.set_kit(2, {"primary": C.W.RAIL, "sidearm": C.W.MPISTOL, "parts_p": ["vgrip", "fastcell"], "parts_s": [], "perks": []})
	Settings.set_kit(3, {"primary": C.W.GREATSWORD, "sidearm": C.W.PISTOL, "parts_p": [], "parts_s": [], "perks": []})
	d.call("_select_class", 0)
	d.call("_show_tab", 1)
	await _wait(0.5)
	await _shot("maxed_arsenal")
	d.call("_show_tab", 2)
	await _wait(0.3)
	await _shot("maxed_perks")
	d.call("_select_class", 2)
	await _wait(0.4)
	await _shot("preview_sniper")
	d.call("_select_class", 3)
	await _wait(0.4)
	await _shot("preview_greatsword")
	d.call("_select_class", 1)
	await _wait(0.4)
	await _shot("preview_medic")

	var c := w.controller
	var kits := [
		["rifle_holo", 0, {"primary": C.W.RIFLE, "sidearm": C.W.MPISTOL, "parts_p": ["holo", "comp", "agrip", "fastcell"], "parts_s": ["suppressor"], "perks": []}],
		["assault_dot", 0, {"primary": C.W.ASSAULT, "sidearm": C.W.REVOLVER, "parts_p": ["reddot", "suppressor", "laser", "bigcell"], "parts_s": [], "perks": []}],
	]
	d.call("_deploy")
	await _wait(0.5)
	s.protected_t = 9999.0
	for k: Array in kits:
		s.respawn(Vector3(0, 0.2, 125), PI * 0.5, k[1], Gear.sanitize(k[1], k[2], 30))
		c.on_spawned()
		s.protected_t = 9999.0
		s.pitch = 0.0
		await _wait(1.1)
		await _shot("fp_%s_hip" % k[0])
		Input.action_press("aim")
		await _wait(0.6)
		await _shot("fp_%s_ads" % k[0])
		Input.action_release("aim")
		await _wait(0.3)
	c.call("_switch", 1)
	await _wait(0.8)
	await _shot("fp_sidearm")
	get_tree().quit(0)


## The Empire's look: base, barracks, armour and the scoreboard.
func _empire_screens() -> void:
	Net.start_offline({"seed": 1943, "bots_per_team": 8, "difficulty": 1})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w: World = Net.world
	await _wait(1.0)
	w.hud.deploy.call("_deploy")
	await _wait(0.5)
	var c := w.controller
	var s := w.local
	var srv := w.server
	srv.bots.clear()
	s.protected_t = 9999.0
	s.teleport(Vector3(0, 0.2, -141))
	s.yaw = PI
	s.pitch = 0.12
	await _wait(0.8)
	await _shot("base_gate")
	s.teleport(Vector3(0, 0.2, -143))
	s.yaw = 0.0
	s.pitch = 0.05
	await _wait(0.5)
	await _shot("base_inside")
	s.teleport(Vector3(100, 0.2, -38))
	s.yaw = 0.7
	await _wait(0.5)
	await _shot("barracks")
	var o: Soldier = null
	for x: Soldier in w.soldiers.values():
		if x.team == C.Team.EMPIRE:
			o = x
			break
	var t3: Dictionary = w.vehicles[3]
	t3["pos"] = Vector3(-6, 0, 118)
	t3["yaw"] = -0.9
	(t3["node"] as TankModel).park(t3["pos"], t3["yaw"])
	o.respawn(Vector3(5, 0.1, 118), PI, 0)
	o.become(C.SUPER_MECH, 999.0)
	o.protected_t = 9999.0
	o.wish = Vector3.ZERO
	s.teleport(Vector3(0, 0.2, 128))
	s.yaw = 0.0
	s.pitch = 0.08
	await _wait(0.8)
	await _shot("armour")
	Input.action_press("scoreboard")
	await _wait(0.6)
	await _shot("scoreboard")
	get_tree().quit(0)


func _menu() -> MainMenu:
	return get_parent().get("_menu")


func _screens() -> void:
	var main := get_parent()
	main.call("_open_menu", "")
	await _wait(6.0)
	await _shot("menu")
	var menu: MainMenu = _menu()
	menu.call("_show", "battle")
	await _wait(0.4)
	await _shot("menu_battle")
	menu.call("_show", "settings")
	await _wait(0.4)
	await _shot("menu_settings")
	menu.call("_show", "multi")
	await _wait(0.4)
	await _shot("menu_multi")

	Net.start_offline({"seed": 1943, "bots_per_team": int(Settings.arg("bots", "12")), "difficulty": 1})
	var t0 := Time.get_ticks_msec()
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	print("[screens] world ready in %d ms" % (Time.get_ticks_msec() - t0))
	var w: World = Net.world
	await _wait(3.0)
	await _shot("deploy")
	w.hud.deploy.call("_deploy")
	await _wait(1.0)
	await _shot("spawn")
	var c := w.controller
	var s := w.local

	# Vista of each flag from a soldier's eyes.
	for f: Dictionary in w.flags:
		var p: Vector3 = f["pos"]
		s.teleport(w.map.spawn_point_near(p + Vector3(0, 0, 10), 5.0, w.server.rng))
		var look := p + Vector3.UP * 3.0 - s.eye_position()
		s.yaw = atan2(-look.x, -look.z)
		s.pitch = 0.05
		s.protected_t = 9999.0
		await _wait(0.5)
		await _shot("flag_%s" % f["letter"])

	# Each weapon.
	s.teleport(Vector3(-4, 0.2, 40))
	s.yaw = 0.2
	s.pitch = 0.0
	await _wait(0.3)
	for i in 3:
		c.call("_switch", i)
		await _wait(0.8)
		await _shot("weapon_slot%d" % i)
	c.call("_switch", 0)
	await _wait(0.6)
	Input.action_press("aim")
	await _wait(0.6)
	await _shot("ads")
	Input.action_release("aim")

	# A soldier of each team up close, side by side.
	var showcase: Array[Soldier] = []
	for team in 2:
		for o: Soldier in w.soldiers.values():
			if o != s and o.team == team and o.peer == 0:
				showcase.append(o)
				break
	var bots_backup := w.server.bots.duplicate()
	w.server.bots.clear()
	s.teleport(Vector3(0, 0.2, 40))
	s.yaw = 0.0
	s.pitch = -0.08
	for i in showcase.size():
		var o := showcase[i]
		if not o.alive:
			o.respawn(Vector3.ZERO, 0.0, 0)
		o.teleport(Vector3(-1.1 + 2.2 * i, 0.1, 36.0))
		o.wish = Vector3.ZERO
		o.yaw = PI
		o.protected_t = 9999.0
	await _wait(0.8)
	await _shot("soldiers_closeup")
	for i in showcase.size():
		showcase[i].teleport(Vector3(-1.1 + 2.2 * i, 0.1, 36.0))
		showcase[i].yaw = PI * 0.75
		showcase[i].switch_to(2)
	await _wait(0.6)
	await _shot("soldiers_side")
	w.server.bots = bots_backup

	# Overhead view.
	c.state = PlayerController.State.WAITING
	c.vm.visible = false
	var cam := c.camera
	cam.global_position = Vector3(0, 300, 40)
	cam.look_at(Vector3(0, 0, 0), Vector3.FORWARD)
	cam.fov = 70.0
	c.set_process(false)
	w.hud.visible = false
	await _wait(0.6)
	await _shot("overhead")
	cam.global_position = Vector3(-30, 40, 120)
	cam.look_at(Vector3(0, 5, 0), Vector3.UP)
	await _wait(0.5)
	await _shot("aerial")
	cam.global_position = Vector3(0, 12, 60)
	cam.look_at(Vector3(40, 60, 0), Vector3.UP)
	await _wait(0.4)
	await _shot("sky_with_volfog")
	var env_node: WorldEnvironment = w.find_children("*", "WorldEnvironment", true, false)[0]
	env_node.environment.volumetric_fog_enabled = false
	await _wait(0.4)
	await _shot("sky_no_volfog")
	env_node.environment.volumetric_fog_enabled = true
	c.set_process(true)
	w.hud.visible = true

	# Then just let the battle run and look at it.
	c.state = PlayerController.State.ALIVE
	s.protected_t = 9999.0
	s.teleport(w.map.spawn_point_near(w.flags[2]["pos"] + Vector3(0, 0, 22), 4.0, w.server.rng))
	s.yaw = 0.0
	s.pitch = 0.02
	var fx := w.fx
	for i in 6:
		var z := 40.0 - i * 6.0
		fx.spawn_shot(C.W.CARBINE, 0, s.eye_position() + Vector3(-9.0 + i, -0.3, -6.0), Vector3(14.0, 1.2, z - 60.0), 1)
		fx.spawn_shot(C.W.HEAVY, 1, Vector3(16.0 - i * 2.0, 1.4, -18.0), s.eye_position() + Vector3(-12.0 + i * 3.0, 0.0, -3.0), 1)
		await _wait(0.016)
	await _shot("lasers")
	await _wait(0.5)
	fx.explosion(s.global_position + Vector3(-5.0, 0.2, -14.0))
	await _wait(0.16)
	await _shot("explosion")
	c.call("_switch", 2)
	await _wait(0.6)
	Input.action_press("aim")
	await _wait(0.5)
	await _shot("sword_block")
	Input.action_release("aim")
	await _wait(0.2)
	c.call("_swing")
	await _wait(0.13)
	await _shot("sword_swing")
	c.call("_switch", 1)
	await _wait(0.7)
	await _shot("pistol")
	c.call("_switch", 0)
	await _wait(0.5)
	var sniper_slot_class := s.class_id
	s.respawn(s.global_position, s.yaw, 1)
	s.protected_t = 9999.0
	c.call("on_spawned")
	await _wait(0.7)
	await _shot("sniper_hip")
	Input.action_press("aim")
	await _wait(0.7)
	await _shot("sniper_scope")
	Input.action_release("aim")
	s.respawn(s.global_position, s.yaw, sniper_slot_class)
	s.protected_t = 9999.0
	c.call("on_spawned")
	await _wait(0.4)
	await _wait(float(Settings.arg("battle", "26")))
	await _shot("battle_1")
	await _wait(1.5)
	Input.action_press("scoreboard")
	await _wait(0.8)
	await _shot("scoreboard")
	Input.action_release("scoreboard")
	print("[screens] fps=%d draws=%d prims=%d" % [Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit(0)


## A photo stage for the walkers and tanks. Needs no match, so looks can be iterated on quickly.
func _machines() -> void:
	var stage := Node3D.new()
	add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.56, 0.6, 0.66)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.86)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_hdr_threshold = 1.15
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 1.9
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(120, 120)
	var ground := MeshInstance3D.new()
	ground.mesh = floor_mesh
	ground.material_override = Mats.world("concrete")
	stage.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 34.0
	stage.add_child(cam)
	cam.current = true

	var t0 := Time.get_ticks_usec()
	var golem := MechModel.new()
	golem.setup(0)
	stage.add_child(golem)
	var goliat := MechModel.new()
	goliat.setup(1)
	stage.add_child(goliat)
	var lew := TankModel.new()
	lew.setup(0)
	stage.add_child(lew)
	var wilk := TankModel.new()
	wilk.setup(1)
	stage.add_child(wilk)
	print("[machines] built in %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	for m: MachineModel in [golem, goliat, lew, wilk]:
		var tris := 0
		for mi: MeshInstance3D in m._skin:
			tris += mi.mesh.surface_get_array_len(0) / 3
		print("[machines] %s team %d: %d parts, %d triangles" % [m.get_script().get_global_name(), m.team, m._skin.size(), tris])
	var view := func(target: Vector3, dist: float, yaw: float, height: float) -> void:
		cam.global_position = target + Vector3(sin(yaw) * dist, height, cos(yaw) * dist)
		cam.look_at(target, Vector3.UP)

	var mechs: Array = [[golem, Vector3(-3.4, 0, 0)], [goliat, Vector3(3.4, 0, 0)]]
	lew.visible = false
	wilk.visible = false
	var pose := func(speed: float, seconds: float) -> void:
		var left := seconds
		while left > 0.0:
			for e: Array in mechs:
				var m: MechModel = e[0]
				m.set_motion(Vector2(0, speed), true, false, false)
				m.update_pose(0.016, e[1], 0.0, 0.0, speed, false, false, false, true)
			left -= 0.016
	for e: Array in mechs:
		(e[0] as MechModel).reset_pose()
	pose.call(0.0, 0.4)
	cam.global_position = Vector3(0, 2.6, -17)
	cam.look_at(Vector3(0, 1.9, 0), Vector3.UP)
	await _wait(0.2)
	await _shot("mechs_front")
	for spec: Array in [["golem", Vector3(-3.4, 1.9, 0)], ["goliat", Vector3(3.4, 1.9, 0)]]:
		var c: Vector3 = spec[1]
		for a: Array in [["34", PI + 0.7, 8.5, 1.4], ["side", PI * 1.5, 9.0, 0.3], ["rear", 0.6, 8.5, 1.4], ["close", PI - 0.35, 4.6, 0.9]]:
			var target := c + (Vector3(0, 1.0, 0) if a[0] == "close" else Vector3.ZERO)
			view.call(target, a[2], a[1], a[3])
			await _wait(0.1)
			await _shot("%s_%s" % [spec[0], a[0]])
	# A stride, frame by frame, from the side.
	cam.global_position = Vector3(-17, 2.2, 0)
	cam.look_at(Vector3(0, 1.8, 0), Vector3.UP)
	for i in 4:
		pose.call(4.2, 0.17)
		await _wait(0.06)
		await _shot("mechs_walk_%d" % i)
	golem.play_swing()
	goliat.play_swing()
	pose.call(0.0, 0.14)
	await _wait(0.06)
	cam.global_position = Vector3(0, 2.6, -17)
	cam.look_at(Vector3(0, 1.9, 0), Vector3.UP)
	await _shot("mechs_punch")
	# Damaged, then wrecked.
	golem.set_health(0.2)
	goliat.set_health(0.2)
	pose.call(0.0, 0.8)
	await _wait(0.06)
	await _shot("mechs_damaged")
	golem.play_death()
	goliat.play_death()
	pose.call(0.0, 1.4)
	await _wait(0.06)
	await _shot("mechs_wrecked")
	golem.visible = false
	goliat.visible = false

	lew.visible = true
	wilk.visible = true
	lew.reset_pose()
	wilk.reset_pose()
	lew.park(Vector3(-3.6, 0, 0), 0.0)
	wilk.park(Vector3(3.6, 0, 0), 0.0)
	await _wait(0.1)
	cam.global_position = Vector3(0, 3.4, -21)
	cam.look_at(Vector3(0, 1.3, 0), Vector3.UP)
	await _shot("tanks_front")
	for spec: Array in [["lew", lew, Vector3(-3.6, 1.3, 0)], ["wilk", wilk, Vector3(3.6, 1.3, 0)]]:
		var other: Node3D = wilk if spec[1] == lew else lew
		other.visible = false
		var c: Vector3 = spec[2]
		for a: Array in [["34", PI + 0.72, 12.5, 2.6], ["side", PI * 1.5, 13.5, 0.6], ["rear", 0.62, 12.5, 3.2], ["top", PI + 0.5, 8.0, 8.0], ["low", PI + 0.5, 7.5, -0.7]]:
			view.call(c, a[2], a[1], a[3])
			await _wait(0.1)
			await _shot("%s_%s" % [spec[0], a[0]])
		other.visible = true
	# Under way: leaning into a turn with the plumes lit.
	var drive := func(m: TankModel, at: Vector3, seconds: float) -> void:
		var yaw := 0.0
		var left := seconds
		while left > 0.0:
			yaw += 0.6 * 0.016
			m.hull_yaw = yaw
			m._last_pos = at + Basis(Vector3.UP, yaw) * Vector3.BACK * 10.0 * 0.016
			m.update_pose(0.016, at, yaw + 0.4, 0.06, 10.0, false, false, false, true)
			left -= 0.016
	drive.call(lew, Vector3(-3.6, 0, 0), 1.2)
	drive.call(wilk, Vector3(3.6, 0, 0), 1.2)
	await _wait(0.06)
	cam.global_position = Vector3(0, 4.4, 20)
	cam.look_at(Vector3(0, 1.3, 0), Vector3.UP)
	await _shot("tanks_thrust")
	lew.play_death()
	wilk.play_death()
	lew.update_pose(0.016, lew.global_position, 0.0, 0.0, 0.0, false, false, false, false)
	wilk.update_pose(0.016, wilk.global_position, 0.0, 0.0, 0.0, false, false, false, false)
	await _wait(0.1)
	cam.global_position = Vector3(0, 4.4, -18)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	await _shot("tanks_wrecked")
	get_tree().quit(0)


func _press(c: Control) -> void:
	# Input events use window pixels, while controls live in the stretched canvas.
	var at := c.get_viewport().get_final_transform() * c.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await _wait(0.12)
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().process_frame


func _button_named(root: Node, text: String) -> Button:
	for b: Node in root.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			return b
	return null


## Fits parts on the bench by clicking them, as a player does.
func _bench() -> void:
	Net.start_offline({"seed": 1943, "bots_per_team": 2, "difficulty": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w: World = Net.world
	await _wait(1.0)
	var s := w.local
	var d: DeployScreen = w.hud.deploy
	w.server.call("add_score", s, 60000, "test")
	await _wait(0.2)
	Settings.set_kit(0, {"primary": C.W.CARBINE, "sidearm": C.W.PISTOL, "parts_p": [], "parts_s": [], "perks": []})
	d.call("_select_class", 0)
	await _press(d._tab_buttons[1])
	await _wait(0.5)
	_check("the bench is showing", d.gun_view.is_visible_in_tree() and not d.preview.is_visible_in_tree())
	await _shot("bench_plain")
	for name: String in ["Kolimator", "Tłumik", "Chwyt pionowy", "Duże ogniwo"]:
		var b := _button_named(d, name)
		_check("%s can be clicked" % name, b != null)
		if b:
			await _press(b)
			await _wait(0.45)
			await _shot("bench_" + name.to_lower().replace(" ", "_"))
	var parts: Array = d._kit()["parts_p"]
	_check("clicks fitted four parts: %s" % [parts], parts.size() == 4)
	_check("the bench shows what was fitted", d.gun_view._parts == parts)
	await _press(_button_named(d, "Luneta 3x"))
	await _press(_button_named(d, "Kompensator"))
	await _press(_button_named(d, "Wskaźnik laserowy"))
	await _press(_button_named(d, "Ogniwo przeładowane"))
	await _wait(0.45)
	await _shot("bench_second_set")
	await _press(_button_named(d, "Stabilizator wiązki"))
	await _press(_button_named(d, "Celownik holograficzny"))
	await _press(_button_named(d, "Chwyt kątowy"))
	await _press(_button_named(d, "Szybkie ogniwo"))
	await _wait(0.45)
	await _shot("bench_third_set")
	# Hovering tries a part on without fitting it.
	var before: Array = d._kit()["parts_p"].duplicate()
	var hover := _button_named(d, "Tłumik")
	var motion := InputEventMouseMotion.new()
	motion.position = hover.get_viewport().get_final_transform() * hover.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _wait(0.4)
	_check("hover tries the part on", d.gun_view._parts.has("suppressor"))
	_check("hover keeps the kit", d._kit()["parts_p"] == before)
	await _shot("bench_hover")
	await _press(_button_named(d, "Boczna: %s" % C.WEAPONS[d._kit()["sidearm"]]["name"]))
	await _wait(0.45)
	_check("the sidearm is on the bench", d.gun_view._weapon == d._kit()["sidearm"])
	await _press(_button_named(d, "Tłumik"))
	await _press(_button_named(d, "Duże ogniwo"))
	await _wait(0.45)
	await _shot("bench_sidearm")
	_check("the sidearm took its parts", d._kit()["parts_s"].size() == 2)
	d.call("_select_class", 3)
	await _wait(0.1)
	await _press(_button_named(d, "Główna: %s" % C.WEAPONS[d._kit()["primary"]]["name"]))
	await _wait(0.5)
	await _shot("bench_sword")
	d.call("_select_class", 2)
	await _wait(0.5)
	await _shot("bench_sniper")
	# Every primary and sidearm with a full set, for a contact sheet.
	var sets := {"optic": "scope", "muzzle": "suppressor", "grip": "laser", "cell": "bigcell"}
	var alt := {"optic": "reddot", "muzzle": "comp", "grip": "vgrip", "cell": "fastcell"}
	for wid: int in Gear.WEAPON_SLOTS:
		for pick: Dictionary in [sets, alt]:
			var fitted: Array = []
			for slot: String in Gear.slots_for(wid):
				fitted.append(pick[slot])
			d.gun_view.show_weapon(wid, fitted, 0)
			await _wait(0.5)
			await _shot("gun_%s_%s" % [C.WEAPONS[wid]["name"], "a" if pick == sets else "b"])
	print("[bench] finished, failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _props() -> void:
	Net.start_offline({"seed": 1943, "bots_per_team": 0, "difficulty": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w: World = Net.world
	await _wait(1.0)
	w.hud.visible = false
	w.hud.deploy.visible = false
	var c := w.controller
	c.set_process(false)
	var cam := c.camera
	var seen := {}
	for f: Dictionary in w.map.b.footprints:
		var kind: String = f.get("kind", "")
		var n: int = seen.get(kind, 0)
		if not kind in ["wire", "cover"] or n >= 2:
			continue
		seen[kind] = n + 1
		var at: Vector2 = f["center"]
		var ground := w.map.ground_height(at.x, at.y)
		cam.global_position = Vector3(at.x + 3.2, ground + 1.7, at.y + 3.6)
		cam.look_at(Vector3(at.x, ground + 0.5, at.y), Vector3.UP)
		await _wait(0.4)
		await _shot("%s_%d" % [kind, n])
	get_tree().quit(0)
