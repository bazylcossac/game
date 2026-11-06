extends Node
## Real server rules with deterministic crew actions; also reconstructs a late-joining client.
class MirrorWorld:
	extends World
	func _ready() -> void:
		pass
	func add_soldier(id: int, peer: int, team: int, pname: String) -> Soldier:
		var s := super.add_soldier(id, peer, team, pname)
		s.control = Soldier.Driver.PROXY_VIEW
		return s

var passed := 0
var failed := 0

func _ready() -> void:
	Net.start_dedicated({"mode": "podboj", "map": "stare_miasto", "bots_per_team": 0}, 17855)
	while Net.world == null:
		await get_tree().process_frame
	var w := Net.world
	var m := w.server
	var v: Dictionary = w.vehicles[1]
	var a := _person(w, 501, 0, v["pos"] + Vector3(4, 0.1, 0))
	var b := _person(w, 502, 0, v["pos"] + Vector3(-4, 0.1, 0))
	var c := _person(w, 503, 0, v["pos"] + Vector3(0, 0.1, 5))
	var foe := _person(w, 504, 1, v["pos"] + Vector3(12, 0.1, 0))
	_check("first passenger drives", m.enter_vehicle(a, 1) and v["driver"] == a.sid and not a.is_gunner())
	_check("second passenger uses roof MG", m.enter_vehicle(b, 1) and v["gunner"] == b.sid and b.is_gunner() and b.loadout == [C.W.TANK_MG])
	var d := _person(w, 505, 0, v["pos"] + Vector3(0, 0.1, -5))
	d.want_prone = true
	d._update_crouch()
	_check("soldier lies down", d.prone and d.stance_height() == C.PRONE_HEIGHT and d.eye_height() == C.PRONE_EYE)
	_check("lying down is reported to others", d.state_flags() & C.F_PRONE != 0)
	d.want_prone = false
	d._update_crouch()
	_check("and gets up again", not d.prone and d.stance_height() == C.STAND_HEIGHT)
	var e := _person(w, 506, 0, v["pos"] + Vector3(5, 0.1, 5))
	_check("third climbs in as a passenger", m.enter_vehicle(c, 1) and c.riding == 1 and not c.is_vehicle())
	_check("fourth climbs in as a passenger", m.enter_vehicle(d, 1) and d.riding == 1)
	_check("a fifth does not fit", not m.enter_vehicle(e, 1) and e.riding == -1)
	_check("no free seat for a passenger to move to", not m.switch_seat(c) and c.riding == 1)
	m.exit_vehicle(b)
	_check("a passenger takes the free gun", m.switch_seat(c) and c.riding == -1 and c.is_gunner() and v["gunner"] == c.sid)
	m.exit_vehicle(c)
	m.dismount(d)
	_check("passengers are gone", (v["riders"] as Array).is_empty())
	_check("gunner returns to the gun", m.enter_vehicle(b, 1) and b.is_gunner())
	_check("enemy entry refused", not m.enter_vehicle(foe, 1))
	_check("with a gunner aboard the driver cannot take the roof gun", w.roof_taken(a))
	a.switch_to(C.TANK_ROOF_SLOT)
	_check("the switch is refused", a.slot == 0)
	var ammo := a.mags.duplicate()
	b.consume_shot()
	_check("gunner has independent ammunition", a.mags == ammo and b.mags[0] == int(b.weapon()["mag"]) - 1)
	b.peer = 42
	m.sv_state(42, Vector3(999, 999, 999), 1.2, 0.2, C.F_ALIVE, 0, 2.5)
	b.peer = 0
	_check("remote gunner cannot steer or teleport tank", b.position.distance_to(a.position) < 0.1 and a.hull_yaw != 2.5 and is_equal_approx(b.yaw, 1.2))
	_check("occupied seat change refused", not m.switch_seat(b))
	a.protected_t = 0
	b.protected_t = 0
	var hp := a.hp
	m.apply_damage(b, 50, foe, C.W.TANK_MG, false, foe.position)
	w.sync_gunner(b)
	_check("crew shares armor without double damage", a.hp == hp - 50 and b.hp == a.hp)
	_check_roof_gun()
	var mirror := MirrorWorld.new()
	add_child(mirror)
	mirror.on_roster(w.build_roster())
	mirror.on_vehicle_sync([m.call("_vehicle_args", 1)])
	_check("late join restores driver and gunner", mirror.soldiers[a.sid].is_vehicle() and mirror.soldiers[b.sid].is_gunner() and mirror.vehicles[1]["gunner"] == b.sid)
	mirror.queue_free()
	m.exit_vehicle(a)
	_check("no roof gun conflict once the gunner is the only one left", not w.roof_taken(b))
	_check("driver exits while gunner stays", not a.is_vehicle() and b.is_gunner() and v["driver"] == 0 and v["gunner"] == b.sid)
	_check("gunner can take driving seat", m.switch_seat(b) and not b.is_gunner() and v["driver"] == b.sid)
	_check("former driver can take roof seat", m.enter_vehicle(a, 1) and a.is_gunner())
	b.protected_t = 0
	a.protected_t = 0
	m.apply_damage(b, 99999, foe, C.W.TANK_CANNON, false, foe.position)
	_check("destruction kills both crew", not a.alive and not b.alive and a.deaths == 1 and b.deaths == 1)
	_check("both eliminations credited", foe.kills == 2)
	_check("destroyed tank clears both seats", v["driver"] == 0 and v["gunner"] == 0 and v["hp"] == 0)
	print("[crew] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

## The second seat's gun: real parts in the model, turning on its own, on top of the turret.
func _check_roof_gun() -> void:
	var tank := TankModel.new()
	tank.setup(0)
	add_child(tank)
	var mesh: Mesh = (tank.hull.get_child(0) as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(0)
	var kinds := {}
	for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
		kinds[floori(uv.y)] = true
	_check("model keeps paint, metal, rubber and light surfaces", kinds.has(0) and kinds.has(1) and kinds.has(2) and kinds.has(4))
	var shades := {}
	for c: Color in arrays[Mesh.ARRAY_COLOR]:
		shades[snappedf(c.r, 0.02)] = true
	_check("baked occlusion reaches the paint (%d shades)" % shades.size(), shades.size() > 8)
	tank.rotation.y = 0.4
	tank.turret.rotation.y = -0.9
	tank.set_gunner_aim(1.3, 0.3, true)
	tank._aim_roof(0.016)
	var forward := -tank.roof_gun.global_basis.z
	_check("roof gun aims where the gunner looks, whatever the turret does", forward.distance_to(Basis.from_euler(Vector3(0.3, 1.3, 0.0), EULER_ORDER_YXZ) * Vector3.FORWARD) < 0.01)
	var length := tank.gunner_muzzle().distance_to(tank.gunner_pivot())
	_check("long barrel reaches out from the mount (%.2f m)" % length, length > 3.0)
	var before := tank.gunner_muzzle()
	tank.turret.rotation.y = 1.4
	tank._aim_roof(0.016)
	_check("driver's turret swing leaves the gunner's aim alone", tank.gunner_muzzle().distance_to(before) < 0.01)
	tank.play_gunner_fire()
	tank._aim_roof(0.016)
	_check("firing kicks the gun back along its barrel", tank.gunner_muzzle().distance_to(before) > 0.03)
	tank.set_gunner_aim(0.0, 0.0, false)
	for i in 300:
		tank._aim_roof(0.016)
	_check("empty station settles over the main gun", absf(tank.roof_mount.rotation.y) < 0.01 and absf(tank.roof_gun.rotation.x) < 0.01)
	_check_solo_driver(tank)
	tank.queue_free()


## A driver alone: switching to the roof gun locks the main gun, and it swings back afterwards.
func _check_solo_driver(tank: TankModel) -> void:
	tank.turret.rotation.y = 0.0
	tank.hull_yaw = 0.2
	tank.update_pose(0.016, Vector3.ZERO, 0.9, 0.1, 0, false, false, false, true)
	var main_aim := tank.turret.rotation.y
	_check("on the cannon the turret follows the aim", is_equal_approx(main_aim, 0.7))
	var cannon_tip := tank.muzzle_position()
	tank.set_weapon(C.W.TANK_MG)
	tank.update_pose(0.016, Vector3.ZERO, -1.4, 0.3, 0, false, false, false, true)
	tank._aim_roof(0.016)
	_check("the roof gun locks the turret where it stood", is_equal_approx(tank.turret.rotation.y, main_aim))
	_check("the locked gun keeps its elevation", is_equal_approx(tank.gun.rotation.x, 0.1))
	var forward := -tank.roof_gun.global_basis.z
	_check("the roof gun takes the driver's aim", forward.distance_to(Basis.from_euler(Vector3(0.3, -1.4, 0.0), EULER_ORDER_YXZ) * Vector3.FORWARD) < 0.01)
	_check("shots leave from the roof gun", tank.muzzle_position().distance_to(tank.gunner_muzzle()) < 0.001 and tank.muzzle_position().distance_to(cannon_tip) > 0.5)
	tank.set_weapon(C.W.TANK_CANNON)
	tank.update_pose(0.016, Vector3.ZERO, -1.4, 0.0, 0, false, false, false, true)
	var moved := absf(angle_difference(tank.turret.rotation.y, main_aim))
	_check("back on the cannon the turret swings, not snaps (%.2f rad)" % moved, moved > 0.01 and moved < 0.2)
	for i in 80:
		tank.update_pose(0.016, Vector3.ZERO, -1.4, 0.0, 0, false, false, false, true)
	_check("and it reaches the aim", absf(angle_difference(tank.turret.rotation.y, wrapf(-1.4 - 0.2, -PI, PI))) < 0.02)


func _person(w: World, sid: int, team: int, pos: Vector3) -> Soldier:
	var s := w.add_soldier(sid, 0, team, "CrewTester")
	s.respawn(pos, 0, 0)
	s.set_physics_process(false)
	return s

func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[crew] %s %s" % ["PASS" if ok else "FAIL", label])
