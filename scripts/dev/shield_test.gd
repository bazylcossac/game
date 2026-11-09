extends Node
## `--test=shield`, headless: the heavies' health, the rebel heavy's energy shield on the real
## server (front only, breaking, falling back to the gun, charging in 15 s) and leaning on Q and E.
var passed := 0
var failed := 0
var w: World
var m: MatchServer


func _ready() -> void:
	Net.start_dedicated({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 0}, 17867)
	while Net.world == null:
		await get_tree().process_frame
	w = Net.world
	m = w.server
	await get_tree().physics_frame
	await get_tree().process_frame
	var spot: Vector3 = w.flags[0]["pos"] + Vector3(0, 0.1, 0)
	var korpo := _person(820, C.Team.EMPIRE, spot + Vector3(40, 0, 0), 2)
	_check("the liquidator has 300 health", is_equal_approx(korpo.max_hp, 300.0))
	_check("and is a little slower than the line", float(korpo.class_data()["speed"]) < 0.88)
	var heavy := _person(810, C.Team.RESISTANCE, spot, 5, {}, 777)
	_check("the rebel heavy has 200 health", is_equal_approx(heavy.max_hp, 200.0))
	_check("the shield is the fourth weapon", heavy.loadout.size() == 4 and heavy.loadout[3] == C.W.ENERGY_SHIELD)
	_check("and it starts charged", is_equal_approx(heavy.shield, C.SHIELD_HP) and heavy.shield_ready)
	_check("its sword stays on key 3", heavy.melee_slot() == 2)
	heavy.yaw = 0.0
	var front := heavy.global_position + Vector3(0, 1, -10)
	var back := heavy.global_position + Vector3(0, 1, 10)
	m.apply_damage(heavy, 30.0, korpo, C.W.ASSAULT, false, front)
	_check("without the shield up, shots hurt (%d)" % heavy.hp, is_equal_approx(heavy.hp, 170.0))
	heavy.switch_to(3)
	_check("the shield comes out", heavy.shield_held())
	m.apply_damage(heavy, 60.0, korpo, C.W.ASSAULT, false, front)
	_check("a shot from the front is stopped (hp %d, shield %d)" % [heavy.hp, heavy.shield], is_equal_approx(heavy.hp, 170.0) and is_equal_approx(heavy.shield, 40.0))
	m.apply_damage(heavy, 20.0, korpo, C.W.ASSAULT, false, back)
	_check("a shot from behind is not (%d)" % heavy.hp, is_equal_approx(heavy.hp, 150.0) and is_equal_approx(heavy.shield, 40.0))
	m.apply_damage(heavy, 70.0, korpo, C.W.ASSAULT, false, front)
	_check("past its last 40 the shield breaks and the rest gets through (%d)" % heavy.hp, is_equal_approx(heavy.hp, 120.0) and heavy.shield <= 0.0)
	_check("the soldier is back on the main gun", heavy.slot == 0 and not heavy.shield_ready)
	heavy.switch_to(3)
	_check("a broken shield cannot be taken out", heavy.slot == 0)
	heavy.last_valid_pos = heavy.global_position
	m.sv_state(777, heavy.global_position, 0.0, 0.0, 0, 3, 0.0)
	_check("not even by a client claiming the slot", heavy.slot == 0)
	for i in 4 * 14:
		m.call("_tick_regen", 0.25)
	_check("after 14 s it is still charging", not heavy.shield_ready)
	for i in 4 * 2:
		m.call("_tick_regen", 0.25)
	_check("after 15 s it is full and ready again", heavy.shield_ready and is_equal_approx(heavy.shield, C.SHIELD_HP))
	heavy.switch_to(3)
	_check("and can be taken out", heavy.shield_held())
	heavy.switch_to(0)

	# Leaning: the eyes, the shots and the head all move out to the side.
	var eye := heavy.eye_position()
	heavy.lean = 1
	heavy.lean_amount = 1.0
	var leaned := heavy.eye_position()
	var right := Basis(Vector3.UP, heavy.yaw) * Vector3.RIGHT
	_check("leaning right moves the eyes %.2f m to the right" % (leaned - eye).dot(right), (leaned - eye).dot(right) > 0.3)
	heavy.lean = -1
	heavy.lean_amount = -1.0
	_check("and leaning left to the left", (heavy.eye_position() - eye).dot(right) < -0.3)
	var flags := heavy.state_flags()
	var copy := _person(811, C.Team.RESISTANCE, spot + Vector3(5, 0, 0), 0)
	copy.apply_flags(flags)
	_check("the lean travels with the soldier's state", copy.lean == -1)
	heavy.lean_amount = 1.0
	heavy.lean = 1
	var head := heavy.global_position + Vector3.UP * (heavy.stance_height() - 0.15) + heavy.lean_offset()
	var shooter_at := head + Vector3(0, 0, -20)
	var hit: Dictionary = m.call("_trace_soldiers", shooter_at, (head - shooter_at).normalized(), 40.0, korpo, Net.server_time())
	_check("a shot at the leaning head is a headshot", not hit.is_empty() and hit["head"])
	heavy.prone = true
	_check("nobody leans lying down", not heavy.can_lean())
	print("[shield] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _person(sid: int, team: int, pos: Vector3, class_id: int, kit: Dictionary = {}, peer := 0) -> Soldier:
	var s := w.add_soldier(sid, peer, team, "Tester%d" % sid)
	s.respawn(pos, 0, class_id, kit)
	s.protected_t = 0
	s.set_physics_process(false)
	return s


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[shield] %s %s" % ["PASS" if ok else "FAIL", label])
