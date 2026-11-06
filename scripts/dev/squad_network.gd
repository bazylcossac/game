extends Node
## `--test=squad-net`, run as `--squad-role=server` and `--squad-role=client`: squads over a real
## ENet connection, including what a client sees and the orders it sends.
var passed := 0
var failed := 0


func _ready() -> void:
	if Settings.arg("squad-role") == "server":
		Net.start_dedicated({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 0}, 17864)
		await get_tree().create_timer(40).timeout
		get_tree().quit(0)
	else:
		await _client()


func _client() -> void:
	Net.start_client("127.0.0.1", 17864, "NetworkLeader")
	if not await _until(func() -> bool: return Net.world != null and Net.world.local != null, 15):
		_check("joins the server", false)
		get_tree().quit(1)
		return
	var w := Net.world
	var me := w.local
	Net.send_squad(0, 0)
	await _until(func() -> bool: return w.squads.leads(me), 3)
	_check("client's squad comes back from the server", w.squads.leads(me))
	var squad := w.squads.squad_of(me.sid)
	_check("the first squad is Alfa", squad.get("name", "") == "Alfa")
	await get_tree().create_timer(C.RESPAWN_DELAY).timeout
	Net.send_deploy(0, -1, {})
	await _until(func() -> bool: return me.alive, 4)
	_check("leader asking for a rifleman is sent in as commander", me.alive and me.class_id == C.COMMAND_CLASS)
	_check("commander kit reaches the client", me.class_data().get("command", false) and me.loadout[0] == C.W.CARBINE)
	var charge := float(w.squads.squad_of(me.sid)["charge"])
	await get_tree().create_timer(2.2).timeout
	_check("charge updates reach the client", float(w.squads.squad_of(me.sid)["charge"]) > charge)
	Net.send_strike(me.global_position + Vector3(0, 0, -40))
	await get_tree().create_timer(0.6).timeout
	_check("an uncharged strike changes nothing", float(w.squads.squad_of(me.sid)["next_strike"]) > 0.0)
	Net.send_squad(2, 0)
	await _until(func() -> bool: return w.squads.squad_of(me.sid).is_empty(), 3)
	_check("leaving closes the empty squad for the client too", w.squads.list.is_empty())
	print("[squad-net] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _until(test: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + seconds * 1000.0
	while not test.call() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.05).timeout
	return test.call()


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[squad-net] %s %s" % ["PASS" if ok else "FAIL", label])
