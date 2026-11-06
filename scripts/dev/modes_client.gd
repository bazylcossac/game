extends Node
## Headless client for a mode's network test: `--test=client --modes-check --want-mode=<id>
## --want-map=<id> --seconds=<n>`. Plays through the real controller and reports what the
## server told it.

var w: World
var s: Soldier
var _ok := true
var _route := PackedVector3Array()
var _route_i := 0
var _route_t := 0.0
var _best_score := [0, 0]
var _kills_seen := 0


func _ready() -> void:
	w = Net.world
	s = w.local
	_run()


func _say(label: String, good: bool) -> void:
	_ok = _ok and good
	print("[client] %s %s" % ["PASS" if good else "FAIL", label])


func _run() -> void:
	var want_mode := Settings.arg("want-mode")
	var want_map := Settings.arg("want-map")
	_say("tryb od serwera: %s" % w.cfg["mode"], w.cfg["mode"] == want_mode)
	_say("mapa od serwera: %s (%s)" % [w.cfg["map"], w.map.get_script().get_global_name()], w.cfg["map"] == want_map)
	_say("gracz w ruchu oporu", s.team == C.Team.RESISTANCE)
	if w.ffa:
		var all_same := true
		for o: Soldier in w.soldiers.values():
			all_same = all_same and o.team == C.Team.RESISTANCE
		_say("deathmatch: nikt nie gra Imperium (%d żołnierzy)" % w.soldiers.size(), all_same)
	var seconds := float(Settings.arg("seconds", "40"))
	var t := 0.0
	var moved := 0.0
	var last_pos := s.global_position
	var deploys := 0
	while t < seconds and not w.round_winner >= 0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		_watch()
		if not s.alive:
			if w.can_deploy_now() and w.controller.state != PlayerController.State.ALIVE and Net.server_time() - s.death_time > C.RESPAWN_DELAY:
				Net.send_deploy(0, -1, {})
				deploys += 1
			Input.action_release("use")
			Input.action_release("move_forward")
			continue
		moved += s.global_position.distance_to(last_pos) if s.global_position.distance_to(last_pos) < 8.0 else 0.0
		last_pos = s.global_position
		_act(0.1)
	Input.action_release("move_forward")
	Input.action_release("use")
	_say("przeszedł po mapie %.0f m" % moved, moved > 5.0)
	_say("wyniki doszły: %s, zabici widziani %d, maks. wyniki %s" % [str(w.tickets), _kills_seen, str(_best_score)], _scores_moved())
	if w.mode.get("tanks_only", false):
		print("[client] wejść do walki: %d" % deploys)
	print("[client] koniec: %s" % ("PASS" if _ok else "FAIL"))
	get_tree().quit(0 if _ok else 1)


func _scores_moved() -> bool:
	if w.mode["rules"] == "conquest":
		return _best_score[0] < w.score_limit or _best_score[1] < w.score_limit or w.tickets.min() < w.score_limit
	return w.tickets.max() > 0 or _best_score.max() > 0


func _watch() -> void:
	_best_score[0] = maxi(_best_score[0], w.tickets[0])
	_best_score[1] = maxi(_best_score[1], w.tickets[1])
	var kills := 0
	for o: Soldier in w.soldiers.values():
		kills += o.kills
	_kills_seen = maxi(_kills_seen, kills)
	if w.mode.get("tanks_only", false) and s.alive and not s.is_vehicle() and w.controller.state == PlayerController.State.ALIVE:
		_ok = false
		print("[client] FAIL gracz bez czołgu")


func _act(delta: float) -> void:
	var flag_goal := Vector3.ZERO
	if not w.flags.is_empty():
		flag_goal = w.flags[1]["pos"]
	_walk(flag_goal, delta)


## Steers the real controller along a nav route: faces the next way point and holds forward.
func _walk(goal: Vector3, delta: float) -> void:
	_route_t -= delta
	if _route_t <= 0.0 or _route_i >= _route.size():
		_route_t = 2.0
		_route = (w.map.b.nav_tank if s.is_vehicle() else w.map.b.nav).find_path(s.global_position, goal)
		_route_i = 0
	if _route_i >= _route.size():
		Input.action_release("move_forward")
		return
	var to := _route[_route_i] - s.global_position
	to.y = 0.0
	if to.length() < 1.2:
		_route_i += 1
		return
	s.yaw = atan2(-to.x, -to.z)
	Input.action_press("move_forward")
	if s.is_vehicle():
		s.hull_yaw = s.yaw
