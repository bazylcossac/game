extends Node
var passed := 0
var failed := 0

func _ready() -> void:
	Net.start_dedicated({"mode": "podboj", "map": "neonowa_dzielnica", "bots_per_team": 0}, 17856)
	while Net.world == null:
		await get_tree().process_frame
	var w := Net.world
	w.forts._bot_t = 9999
	var s := w.add_soldier(601, 0, 0, "EngineerTester")
	s.respawn(Vector3(-178, .1, 88), 0, 3)
	s.set_physics_process(false)
	var foe := w.add_soldier(602, 0, 1, "Attacker")
	foe.respawn(Vector3(-178, .1, 70), 0, 0)
	foe.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check("engineer starts with shotgun at level 1", s.weapon_id() == C.W.SCATTER and Gear.sanitize(3, {}, 1)["primary"] == C.W.SCATTER)
	_check("ordinary soldier cannot build", not w.forts.request(foe, 0, Vector3(-177, 0, 85), 0))
	_check("nonfinite position rejected", not w.forts.request(s, 0, Vector3.INF, 0))
	_check("unknown construction rejected", not w.forts.request(s, 99, Vector3(-177, 0, 85), 0))
	_check("distant position rejected", not w.forts.request(s, 0, Vector3(0, 0, 0), 0))
	# Some ground near a flag was already closed to tanks: destroying cover must not change that.
	var tank_free: bool = w.map.b.nav_tank.is_free(w.map.b.nav_tank.cell_of(Vector3(-177, 0, 85)))
	_check("owned flag accepts construction", w.forts.request(s, 0, Vector3(-177, 0, 85), 0))
	_check("duplicate pending construction rejected", not w.forts.request(s, 1, Vector3(-177, 0, 84), 0))
	_check("building is not instantaneous", w.forts.items.is_empty())
	var deadline := Net.server_time() + Fortifications.BUILD_SECONDS + 2.0
	while w.forts.pending.has(s.sid) and Net.server_time() < deadline:
		await get_tree().create_timer(.1).timeout
	_check("construction completes", w.forts.items.size() == 1)
	_check("materials charged once", w.forts.banks[s.sid] >= 75 and w.forts.banks[s.sid] < 79)
	if w.forts.items.is_empty():
		get_tree().quit(1)
		return
	var id: int = w.forts.items.keys()[0]
	var at := Vector3(-177, 0, 85)
	_check("bots avoid built cover", not w.map.b.nav.is_free(w.map.b.nav.cell_of(at)) and not w.map.b.nav_tank.is_free(w.map.b.nav_tank.cell_of(at)))
	_check("navigation still reaches enemy base", w.map.b.nav.can_reach(w.map.bases()[0], w.map.bases()[1]))
	_check("overlapping placement rejected", not w.forts.request(s, 0, at, 0))
	var data := w.forts.snapshot()
	var decoded: Array = bytes_to_var(var_to_bytes(data))
	_check("late join snapshot contains serializable construction", decoded.size() == 1 and decoded[0]["pos"] == at and not decoded[0].has("node"))
	var hp: float = w.forts.items[id]["hp"]
	w.forts.damage(id, 100, foe, false)
	_check("sandbags resist small arms", w.forts.items[id]["hp"] == hp)
	w.forts.damage(id, 100, s, true, true)
	_check("friendly fire does not remove fortifications", w.forts.items[id]["hp"] == hp)
	w.forts.damage(id, 100, foe, true, true)
	_check("explosion damages cover", w.forts.items[id]["hp"] == hp - 100)
	w.forts.damage(id, 9999, foe, true, true)
	_check("destroyed cover disappears", not w.forts.items.has(id))
	_check("destroyed cover restores bot path", w.map.b.nav.is_free(w.map.b.nav.cell_of(at)) and w.map.b.nav_tank.is_free(w.map.b.nav_tank.cell_of(at)) == tank_free)
	await get_tree().physics_frame
	await get_tree().process_frame
	w.flags[0]["owner"] = 1
	_check("enemy flag rejects construction", not w.forts.request(s, 0, at, 0))
	w.flags[0]["owner"] = 0
	w.forts.banks[s.sid] = 0
	_check("insufficient materials rejected", not w.forts.request(s, 0, at, 0))
	w.forts.banks[s.sid] = 100
	_check("second build starts", w.forts.request(s, 0, at, 0))
	s.last_damage_time = Net.server_time() + .01
	await get_tree().create_timer(.2).timeout
	_check("damage interrupts construction without spending materials", not w.forts.pending.has(s.sid) and w.forts.banks[s.sid] == 100)
	# A turret really fires, while a hedgehog needs explosive damage.
	var turret := {"id": 100, "kind": 3, "team": 0, "owner": s.sid, "flag": 0, "pos": at, "yaw": 0.0, "hp": 220.0}
	w.on_fort(turret)
	foe.protected_t = 0
	await get_tree().create_timer(.8).timeout
	_check("turret fires at enemies", foe.hp < foe.max_hp)
	w.on_fort_removed(100)
	turret["id"] = 101
	turret["kind"] = 2
	turret["hp"] = 600.0
	w.on_fort(turret)
	w.forts.damage(101, 9999, foe, true, false)
	_check("hedgehog resists nonexplosive heavy fire", w.forts.items.has(101))
	w.forts.damage(101, 9999, foe, true, true)
	_check("explosive destroys hedgehog", not w.forts.items.has(101))
	_check_overlap_nav(w.map.b.nav)
	print("[engineer] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _check_overlap_nav(nav: NavGrid) -> void:
	var pos := Vector3(-177, 0, 85)
	var xf := Transform3D(Basis.IDENTITY, pos)
	nav.add_obstacle(200, xf, Vector2.ONE, .45)
	nav.add_obstacle(201, xf, Vector2.ONE, .45)
	nav.remove_obstacle(200)
	_check("overlapping obstacles retain navigation block", not nav.is_free(nav.cell_of(pos)))
	nav.remove_obstacle(201)
	_check("last obstacle restores original navigation", nav.is_free(nav.cell_of(pos)))

func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[engineer] %s %s" % ["PASS" if ok else "FAIL", label])
