extends Node
## `--test=browser-net --port=<port>`, headless client against a real `--server` on that port.
## Start the server with --name=Testowy. With `--ffa` the server is expected to run Deathmatch.
var passed := 0
var failed := 0
var port := 0


func _ready() -> void:
	port = int(Settings.arg("port", "17870"))
	await _until(func() -> bool: return true, 0.1)
	if Settings.has_arg("ffa"):
		await _free_for_all()
	else:
		await _list()
		await _join_and_play()
		await _fresh_after_empty()
	print("[browser] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _ask(at_port: int) -> Dictionary:
	var result := []
	var probe := ServerProbe.new()
	probe.answered.connect(func(info: Dictionary) -> void: result.append(info))
	add_child(probe)
	probe.ask("127.0.0.1", at_port)
	await _until(func() -> bool: return not result.is_empty(), 6)
	return result[0] if not result.is_empty() else {}


func _list() -> void:
	var info := await _ask(port)
	print("[browser] server says: ", info)
	_check("the server answers on the game port", info.get("reached", false))
	_check("it gives its name", info.get("name", "") == "Testowy")
	_check("it gives its version", info.get("version", "") == C.VERSION)
	_check("it gives mode and map", info.get("mode", "") == "podboj" and info.get("map", "") == "stare_miasto")
	_check("nobody is on it", int(info.get("players", -1)) == 0 and int(info.get("max", 0)) == 16)
	_check("the ping is measured", int(info.get("ping", -1)) >= 0 and int(info.get("ping", 999)) < 200)
	var again := await _ask(port)
	_check("asking leaves no player behind", int(again.get("players", -1)) == 0)
	var started := Time.get_ticks_msec()
	var dead := await _ask(port + 1)
	_check("a dead address reads as not reached", dead.has("reached") and not dead["reached"])
	_check("and gives up in time", Time.get_ticks_msec() - started < 4500)


func _join_and_play() -> void:
	var offered := []
	var keep := func(cfg: Dictionary, counts: Array) -> void: offered.append([cfg, counts])
	Net.side_requested.connect(keep)
	Net.start_client("127.0.0.1", port, "Wybierajacy", true)
	await _until(func() -> bool: return not offered.is_empty(), 5)
	_check("joining asks for a side", not offered.is_empty())
	_check("the side pick shows who is there", not offered.is_empty() and offered[0][1] == [0, 0])
	await get_tree().create_timer(0.5).timeout
	_check("no map loads before the pick", Net.world == null)
	Net.choose_side(C.Team.EMPIRE)
	if not await _until(func() -> bool: return Net.world != null and Net.world.local != null, 15):
		_check("joins after the pick", false)
		return
	Net.side_requested.disconnect(keep)
	var w := Net.world
	var me := w.local
	_check("the picked side is the side played", me.team == C.Team.EMPIRE)
	await get_tree().create_timer(1.5).timeout
	_check("no bots on a players-only server", w.soldiers.size() == 1)
	var info := await _ask(port)
	_check("the list counts the player", int(info.get("players", -1)) == 1)
	_check("the score table gets a ping", await _until(func() -> bool: return me.ping >= 0, 4))
	print("[browser] ping from the server: %d ms" % me.ping)

	Net.send_deploy(1, -1, {})
	await _until(func() -> bool: return me.alive, 4)
	_check("first deploy", me.alive and me.class_id == 1)
	await get_tree().create_timer(0.5).timeout
	var tickets := int(w.tickets[me.team])
	Net.send_respawn()
	await _until(func() -> bool: return not me.alive, 3)
	_check("respawn kills the player", not me.alive)
	_check("the controller shows the death", w.controller.state == PlayerController.State.DEAD)
	await get_tree().create_timer(1.3).timeout
	_check("it counts as a death", me.deaths == 1 and me.kills == 0)
	_check("it costs a ticket", int(w.tickets[me.team]) == tickets - 1)
	await get_tree().create_timer(C.RESPAWN_DELAY - 1.0).timeout
	_check("the deploy screen comes up", w.hud.deploy_visible())
	Net.send_deploy(3, -1, {})
	await _until(func() -> bool: return me.alive, 4)
	_check("back in with a new class", me.alive and me.class_id == 3)
	for i in 6:
		await get_tree().create_timer(2.0).timeout
		print("[browser] ping after %d s more: %d ms" % [(i + 1) * 2, me.ping])
	_check("the ping settles on the real delay", me.ping < 60)
	Net.leave()
	await get_tree().process_frame


func _fresh_after_empty() -> void:
	(get_tree().current_scene as Node).call("_close_world")
	await get_tree().create_timer(1.0).timeout
	var info := await _ask(port)
	_check("the player is gone from the list", int(info.get("players", -1)) == 0)
	Net.start_client("127.0.0.1", port, "Nastepny")
	if not await _until(func() -> bool: return Net.world != null and Net.world.local != null, 15):
		_check("joins again", false)
		return
	await get_tree().create_timer(0.6).timeout
	var w := Net.world
	_check("an emptied server starts over", int(w.tickets[1]) == C.START_TICKETS)
	await get_tree().create_timer(3.0).timeout
	_check("the match runs again with someone on it", int(w.tickets[0]) <= C.START_TICKETS)
	Net.leave()


func _free_for_all() -> void:
	var offered := []
	Net.side_requested.connect(func(cfg: Dictionary, counts: Array) -> void: offered.append([cfg, counts]))
	Net.start_client("127.0.0.1", port, "Solo", true)
	var joined := await _until(func() -> bool: return Net.world != null and Net.world.local != null, 15)
	_check("Deathmatch needs no side pick", joined and offered.is_empty())
	await get_tree().create_timer(1.0).timeout
	_check("no bots in Deathmatch either", Net.world != null and Net.world.soldiers.size() == 1)


func _until(test: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + seconds * 1000.0
	while not test.call() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.05).timeout
	return test.call()


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[browser] %s %s" % ["PASS" if ok else "FAIL", label])
