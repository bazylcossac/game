class_name KillRules
extends ModeRules
## Klasyczne PvP and Deathmatch: respawn until a side reaches the kill limit. `tickets` holds
## the kills of each team; in a free-for-all the first entry is the leader's count.

const ROAM_MIN := 7.0
const ROAM_MAX := 16.0
## How often a bot heads for an enemy rather than a place on the map.
const HUNT_CHANCE := 0.6


func start() -> void:
	w.tickets = [0, 0]


func on_death(v: Soldier, attacker: Soldier) -> void:
	if attacker == null or attacker == v:
		return
	var limit := Modes.score_limit(w.cfg)
	if w.ffa:
		w.tickets[0] = maxi(w.tickets[0], attacker.kills)
		if attacker.kills >= limit and not m.round_over:
			m.end_match(attacker.sid)
		return
	w.tickets[attacker.team] += 1
	if w.tickets[attacker.team] >= limit and not m.round_over:
		m.end_match(attacker.team)


func on_removed(s: Soldier) -> void:
	if not w.ffa:
		return
	# The leader can walk out, and the board must not keep a score nobody holds.
	var best := 0
	for o: Soldier in w.soldiers.values():
		if o != s:
			best = maxi(best, o.kills)
	w.tickets[0] = best


func is_winner(s: Soldier, winner: int) -> bool:
	return s.sid == winner if w.ffa else s.team == winner


func winner_name(winner: int) -> String:
	if not w.ffa:
		return C.TEAM_NAMES[winner]
	var s: Soldier = w.soldiers.get(winner)
	return s.pname if s else "?"


func bot_think(brain: BotBrain) -> void:
	if Net.server_time() < brain.roam_until:
		return
	brain.roam_until = Net.server_time() + brain.rng.randf_range(ROAM_MIN, ROAM_MAX)
	var prey := _pick_prey(brain) if brain.rng.randf() < HUNT_CHANCE else null
	if prey != null:
		brain.go_to(prey.global_position, 6.0)
		return
	var spots := w.map.hotspots()
	brain.go_to(spots[brain.rng.randi_range(0, spots.size() - 1)], 7.0)


func _pick_prey(brain: BotBrain) -> Soldier:
	var foes: Array[Soldier] = []
	for o: Soldier in w.soldiers.values():
		if o.alive and w.are_foes(brain.s, o):
			foes.append(o)
	return null if foes.is_empty() else foes[brain.rng.randi_range(0, foes.size() - 1)]
