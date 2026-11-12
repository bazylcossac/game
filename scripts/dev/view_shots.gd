extends Node
## `--test=view-shots --out=<dir>`, windowed: guns as the player holds them, at the hip and aimed,
## for both sides, and sprinting (`--only=bieg`). `--only=word` keeps the shots whose name contains it, `--map=id` picks the map.

const GUNS := [
	[0, 0, "mech", {}], [0, 0, "karabinek", {}], [1, 2, "dzialko", {}], [0, 2, "karabin", {}], [1, 1, "promieniowy", {}], [0, 0, "wyrzutnia", {"ordnance": "rockets"}], [1, 0, "wyrzutnia_imperium", {"ordnance": "rockets"}], [1, 0, "szturmowy", {}], [0, 5, "minigun", {}], [1, 5, "droid_inzynier", {}],
	[1, 2, "likwidator_dzialo", {}], [1, 2, "likwidator_rakiety", {"slot": 1, "parts_s": ["pod_third"]}], [0, 5, "minigun_lufy", {"parts_p": ["mg_cool", "mg_spin"]}],
	[0, 5, "tarcza", {"slot": 3}], [0, 0, "wychylenie", {"lean": 1}],
	[0, 0, "kolimator", {"parts_p": ["reddot"]}], [0, 0, "holo", {"parts_p": ["holo"]}], [1, 0, "kolimator_imperium", {"parts_p": ["reddot"]}],
	[0, 0, "pistolet", {"slot": 1}], [1, 0, "pistolet_imperium", {"slot": 1}],
	[0, 0, "bieg_karabinek", {"run": 1}], [1, 5, "bieg_droid_inzynier", {"run": 1}], [0, 1, "bieg_katana", {"slot": 2, "run": 1}], [0, 0, "bieg_miecz_swietlny", {"slot": 2, "run": 1}],
]

var out_dir := ""
var _only := ""


func _ready() -> void:
	out_dir = Settings.arg("out", "user://view")
	_only = Settings.arg("only", "")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().unfocusable = true
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.apply_display()
	for spec: Array in GUNS:
		if _only != "" and not String(spec[2]).contains(_only):
			continue
		await _gun(spec[0], spec[1], spec[2], spec[3])
	if _only == "" or "czolg".contains(_only):
		await _tank()
	get_tree().quit(0)


func _gun(team: int, class_id: int, label: String, kit: Dictionary) -> void:
	Settings.side = team
	Net.start_offline(Modes.normalize({"mode": "pvp", "map": Settings.arg("map", "rynek"), "difficulty": 0, "bots_per_team": 0}))
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	w.server.bots.clear()
	await _wait(0.5)
	Net.send_deploy(class_id, -1, Gear.sanitize(class_id, kit, 30, team))
	while not w.local.alive:
		await get_tree().process_frame
	await _wait(0.8)
	var s := w.local
	s.protected_t = 999.0
	if label == "mech":
		var foe := w.add_soldier(950, 0, 1, "Cel")
		foe.respawn(s.global_position + Vector3(0, 0.1, -30), 0, 0)
		foe.set_physics_process(false)
		s.coins = 1
		w.server.activate_super(s, C.SUPER_MECH)
		await _wait(1.0)
		s.yaw = PI * 0.5
		await _wait(0.4)
	if kit.has("ordnance"):
		var at := s.global_position + Basis(Vector3.UP, s.yaw) * Vector3(1.5, 0, -13)
		w.on_vehicle(999, 1, at, 0.6, 800.0, 0)
		w.controller.call("_switch", 3)
		await _wait(0.9)
	if kit.has("slot"):
		w.controller.call("_switch", int(kit["slot"]))
		await _wait(0.9)
	if kit.has("lean"):
		Input.action_press("lean_right" if int(kit["lean"]) > 0 else "lean_left")
		await _wait(0.6)
		await _shot("%s_wychylony" % label)
		Input.action_release("lean_right")
		Input.action_release("lean_left")
		await _wait(0.5)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _shot("%s_biodro" % label)
	if kit.has("run"):
		# Sprinting forward: shots through one stride, so the swing shows from frame to frame.
		Input.action_press("move_forward")
		Input.action_press("sprint")
		await _wait(0.7)
		for i in 4:
			await _shot("%s_%d" % [label, i])
			await _wait(0.11)
		Input.action_release("sprint")
		Input.action_release("move_forward")
		await _wait(0.6)
	Input.action_press("aim")
	await _wait(0.7)
	await _shot("%s_cel" % label)
	Input.action_release("aim")
	await _wait(0.5)
	if kit.has("ordnance"):
		var view: Node = w.controller.get("vm")
		var length: float = C.WEAPONS[C.W.AT_ROCKET]["reload"]
		view.call("start_reload", length)
		var was := 0.0
		for at: float in [0.14, 0.32, 0.48, 0.62, 0.72, 0.9]:
			await _wait((at - was) * length)
			was = at
			await _shot("%s_ladowanie_%d" % [label, int(at * 100.0)])
	get_tree().current_scene.call("_close_world")
	await get_tree().process_frame
	Net.leave()
	await get_tree().process_frame


## What each seat of a tank sees, on a street with an enemy tank ahead.
func _tank() -> void:
	Settings.side = 0
	Net.start_offline(Modes.normalize({"mode": "podboj", "map": "stare_miasto", "difficulty": 0, "bots_per_team": 0}))
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w := Net.world
	w.server.bots.clear()
	await _wait(0.8)
	await _shot("czolg_wybor_klasy")
	Net.send_deploy(0, -1, {})
	while not w.local.alive:
		await get_tree().process_frame
	await _wait(0.6)
	var s := w.local
	s.protected_t = 999.0
	var pc := w.controller
	var own: Dictionary = w.vehicles[1]
	var ahead: Vector3 = own["pos"]
	var yaw: float = own["yaw"]
	s.yaw = yaw
	w.on_vehicle(999, 1, ahead + Basis(Vector3.UP, yaw) * Vector3(3, 0, -34), 0.7, 800.0, 0)
	w.server.enter_vehicle(s, 1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _wait(1.0)
	await _shot("czolg_dzialo")
	pc.tank_heat = true
	await _wait(0.6)
	await _shot("czolg_dzialo_termo")
	pc.tank_heat = false
	s.switch_to(C.TANK_ROOF_SLOT)
	await _wait(0.8)
	await _shot("czolg_dzialko")
	pc.tank_heat = true
	await _wait(0.6)
	await _shot("czolg_dzialko_termo")
	pc.tank_heat = false
	s.switch_to(0)
	await _wait(0.2)
	w.server.switch_seat(s)
	await _wait(0.8)
	await _shot("czolg_strzelec")
	w.server.exit_vehicle(s)
	await _wait(0.4)
	var mate := w.add_soldier(951, 0, 0, "Kierowca")
	mate.respawn(ahead + Vector3(3, 0.1, 0), 0, 0)
	mate.set_physics_process(false)
	var gunner := w.add_soldier(952, 0, 0, "Strzelec")
	gunner.respawn(ahead + Vector3(-3, 0.1, 0), 0, 0)
	gunner.set_physics_process(false)
	w.server.enter_vehicle(mate, 1)
	w.server.enter_vehicle(gunner, 1)
	w.server.enter_vehicle(s, 1)
	await _wait(1.0)
	await _shot("czolg_pasazer")
	get_tree().current_scene.call("_close_world")
	await get_tree().process_frame
	Net.leave()
	await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, label])
	print("[view] ", label)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
