class_name ModeRules
extends RefCounted
## What makes one game mode different. MatchServer runs the match and asks these hooks at
## each decision, so offline, hosted and dedicated games all play by the same code.

var m: MatchServer
var w: World
var mode: Dictionary


static func create(server: MatchServer) -> ModeRules:
	var rules: ModeRules
	match String(server.world.mode["rules"]):
		"kills": rules = KillRules.new()
		_: rules = ConquestRules.new()
	rules.m = server
	rules.w = server.world
	rules.mode = server.world.mode
	return rules


## Resets the score for a new match.
func start() -> void:
	pass


## Every physics tick of a running match.
func tick(_delta: float) -> void:
	pass


## At the flag rate, for checks that need not run every tick.
func tick_slow(_dt: float) -> void:
	pass


## False while a round is being set up or wound down: nobody moves, fires or takes damage.
func can_act() -> bool:
	return true


func may_deploy(_s: Soldier) -> bool:
	return true


func can_leave_vehicle() -> bool:
	return true


func tank_respawn_delay() -> float:
	return C.TANK_RESPAWN


func spawn_point(s: Soldier, _flag_idx: int) -> Vector3:
	return _safe_spot(s, w.map.free_spawns() if w.ffa else w.map.team_spawns(s.team))


func on_spawned(_s: Soldier) -> void:
	pass


## A soldier has just died. Called last, because this can end the match.
func on_death(_v: Soldier, _attacker: Soldier) -> void:
	pass


## A soldier is about to leave the match for good.
func on_removed(_s: Soldier) -> void:
	pass


## `winner` is what MatchServer.end_match was given: a team, or a soldier id in a free-for-all.
func is_winner(s: Soldier, winner: int) -> bool:
	return s.team == winner


func winner_name(winner: int) -> String:
	return C.TEAM_NAMES[winner]


## Gives a bot something to do in modes without flags. Runs on the bot's think timer.
func bot_think(_brain: BotBrain) -> void:
	pass


## Of a few random spots, the one furthest from any enemy, so nobody spawns under a gun.
func _safe_spot(s: Soldier, spots: Array[Vector3]) -> Vector3:
	var best := spots[0]
	var best_d := -1.0
	for i in mini(spots.size(), 4):
		var p: Vector3 = spots[m.rng.randi_range(0, spots.size() - 1)]
		var nearest := INF
		for o: Soldier in w.soldiers.values():
			if o.alive and w.are_foes(s, o):
				nearest = minf(nearest, o.global_position.distance_squared_to(p))
		if nearest > best_d:
			best_d = nearest
			best = p
	return w.map.spawn_point_near(best, 4.0, m.rng)
