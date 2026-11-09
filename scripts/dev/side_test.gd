extends Node
## `--test=sides`, headless: a human on either side, bots filling both, and each side's own gear.
var passed := 0
var failed := 0


func _ready() -> void:
	Net.start_dedicated({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 3}, 17866)
	while Net.world == null:
		await get_tree().process_frame
	var w := Net.world
	var m := w.server
	await get_tree().physics_frame
	m.add_human(901, "Maszyna", "tok-a", C.Team.EMPIRE)
	var human := w.soldier_for_peer(901)
	_check("a player can join the Empire", human.team == C.Team.EMPIRE)
	var counts := [0, 0]
	for s: Soldier in w.soldiers.values():
		counts[s.team] += 1
	_check("bots keep the two sides even (%d, %d)" % [counts[0], counts[1]], counts[0] == counts[1] and counts[0] >= 3)
	m.add_human(902, "Oporny", "tok-b", C.Team.RESISTANCE)
	_check("a second player can take the other side", w.soldier_for_peer(902).team == C.Team.RESISTANCE)
	m.add_human(903, "Haker", "tok-c", 7)
	_check("a nonsense side falls back to a real one", w.soldier_for_peer(903).team in [0, 1])
	var heavy := Gear.sanitize(2, {"primary": C.W.HEAVY, "sidearm": C.W.PISTOL, "parts_s": ["pod_third", "load_auto"]}, 30, C.Team.EMPIRE)
	_check("Korpo's liquidator keeps its arm cannon and rocket pod", heavy["primary"] == C.W.ARM_CANNON and heavy["sidearm"] == C.W.ARM_ROCKETS)
	_check("the pod takes its own upgrades", heavy["parts_s"] == ["pod_third", "load_auto"])
	var sniper := Gear.sanitize(2, {"primary": C.W.HEAVY}, 30, C.Team.RESISTANCE)
	_check("the same class number on the Resistance may not", sniper["primary"] == C.W.SNIPER)
	human.death_time = -100.0
	m.sv_deploy(901, 2, -1, {"primary": C.W.HEAVY, "parts_s": ["pod_third"]})
	_check("the human deploys as a liquidator", human.alive and C.cls(human.team, human.class_id)["id"] == "heavy" and human.loadout == [C.W.ARM_CANNON, C.W.ARM_ROCKETS])
	_check("two rockets in the pod", human.mags[1] == 2)
	_check("three once the pod is upgraded", Gear.stats(C.W.ARM_ROCKETS, ["pod_third"])["mag"] == 3)
	_check("and no blade to swing", human.melee_slot() < 0)
	_check("every Empire class has a machine frame", _frames())
	var squad_ok: bool = w.squads.create(human) and w.squads.leads(human)
	_check("the Empire can form squads too", squad_ok)
	human.alive = false
	human.death_time = -100.0
	m.sv_deploy(901, 0, -1, {})
	_check("its leader deploys as the droid commander", C.cls(human.team, human.class_id)["id"] == "marshal")
	print("[sides] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _frames() -> bool:
	for cd: Dictionary in C.CLASSES[C.Team.EMPIRE]:
		if not cd.get("mech", false) and not cd.get("vehicle", false) and not cd.has("frame"):
			return false
	return true


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[sides] %s %s" % ["PASS" if ok else "FAIL", label])
