extends Node
## `--test=dmr`, headless: the KP-20 two-sight marksman rifle and the testing rule that every player
## is at the top level. Checks the data and balance, both sides' models, then plays a local match:
## deploys a sniper with the KP-20, flips the magnifier in and out with the real key and aims
## through each sight.
var passed := 0
var failed := 0


func _ready() -> void:
	_data()
	_models()
	await _in_match()
	print("[dmr] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _data() -> void:
	var kp: Dictionary = C.WEAPONS[C.W.DMR]
	var sniper: Dictionary = C.WEAPONS[C.W.SNIPER]
	_check("the rebel marksman can pick it", Gear.primaries(C.Team.RESISTANCE, 2).has(C.W.DMR))
	_check("so can Korpo's auditor", Gear.primaries(C.Team.EMPIRE, 1).has(C.W.DMR))
	_check("and nobody else", Gear.PRIMARIES.filter(func(row: Array) -> bool: return row.has(C.W.DMR)).size() == 1 and Gear.PRIMARIES_EMPIRE.filter(func(row: Array) -> bool: return row.has(C.W.DMR)).size() == 1)
	_check("single shots, not automatic", not kp["auto"])
	_check("fires faster than the beam rifle (%.2f s against %.2f s)" % [kp["rate"], sniper["rate"]], float(kp["rate"]) < float(sniper["rate"]) * 0.5)
	_check("but hits for less (%d against %d)" % [kp["damage"], sniper["damage"]], float(kp["damage"]) < float(sniper["damage"]))
	_check("and still hard: two body shots for a 100 hp soldier", float(kp["damage"]) * 2.0 >= 100.0 and float(kp["damage"]) < 100.0)
	_check("a headshot fells a 100 hp soldier", float(kp["damage"]) * float(kp["head_mult"]) >= 100.0)
	_check("slower than a carbine", float(kp["rate"]) > float(C.WEAPONS[C.W.RIFLE]["rate"]))
	_check("both sights are built in: no optic slot", not Gear.slots_for(C.W.DMR).has("optic"))

	var dot := Gear.stats(C.W.DMR)
	var mag := Gear.magnified(dot)
	_check("the dot is a plain sight", not dot["scope"] and is_equal_approx(float(dot["ads_fov"]), 0.72))
	var zoom := 1.0 / float(mag["ads_fov"])
	_check("the magnifier zooms about 2.5x (%.2fx)" % zoom, zoom > 2.2 and zoom < 3.1 and mag["scope"])
	_check("and tightens the aimed shot like a sniper rifle (%.3f)" % mag["spread_ads"], float(mag["spread_ads"]) < float(dot["spread_ads"]) * 0.3 and float(mag["spread_ads"]) < 0.05)
	_check("at the cost of a slower sight", float(mag["ads_speed"]) < float(dot["ads_speed"]))
	_check("damage, rate and range do not change with the sight", mag["damage"] == dot["damage"] and mag["rate"] == dot["rate"] and mag["range"] == dot["range"])
	var gripped := Gear.magnified(Gear.stats(C.W.DMR, ["agrip"]))
	_check("parts still count through the magnifier", float(gripped["ads_speed"]) > float(mag["ads_speed"]))
	_check("guns with one sight have no second", Gear.magnified(Gear.stats(C.W.SNIPER)).is_empty())
	_check("it unlocks below the cap", Gear.weapon_level(C.W.DMR) <= Gear.MAX_LEVEL)

	_check("for now everyone is at the top level", Gear.everyone_max and Gear.level_for(0) == Gear.MAX_LEVEL)
	Gear.everyone_max = false
	_check("which can be turned off again", Gear.level_for(0) == 1 and Gear.level_for(500) == 2)
	Gear.everyone_max = true


func _models() -> void:
	for team in 2:
		var gun := WeaponFactory.build(C.W.DMR, team)
		var magnifier := gun.get_node_or_null("Magnifier") as Node3D
		_check("side %d: the model has its magnifier, cell, stock and muzzle" % team, magnifier != null and gun.get_node_or_null("Cell") != null and gun.get_node_or_null("ThirdPersonOnly") != null and gun.get_node_or_null("Muzzle") != null)
		var muzzle := gun.get_node("Muzzle") as Node3D
		_check("side %d: the muzzle is well out in front (%.2f)" % [team, muzzle.position.z], muzzle.position.z < -0.8)
		gun.free()
		var far := WeaponFactory.third_person(C.W.DMR, team)
		_check("side %d: it folds for other players' view" % team, far.get_child_count() > 0)
		far.free()
	# Open, the magnifier stays where it was modelled; folded, its eyepiece leaves the sight line.
	_check("open, the magnifier is where it was modelled", WeaponFactory.magnifier_pose(1.0).is_equal_approx(Transform3D.IDENTITY))
	var eye := Vector3(0.0, 0.145, 0.06)
	var folded := WeaponFactory.magnifier_pose(0.0) * eye
	_check("folded, it lies to the left of the dot (%.3f, %.3f)" % [folded.x, folded.y], folded.x < -0.035 and absf(folded.y - 0.145) < 0.03)


func _in_match() -> void:
	Net.start_offline({"seed": 1943, "bots_per_team": 0, "difficulty": 0})
	while Net.world == null or Net.world.local == null:
		await get_tree().process_frame
	var w: World = Net.world
	var s := w.local
	w.server.bots.clear()
	await _wait(0.5)
	_check("a new player starts at the top level (%d)" % w.level, w.level == Gear.MAX_LEVEL and s.level == Gear.MAX_LEVEL)
	var kit := {"primary": C.W.DMR, "sidearm": C.W.PISTOL, "parts_p": ["vgrip", "fastcell"], "parts_s": [], "perks": ["reflex"]}
	_check("the server keeps a KP-20 kit at once", Gear.sanitize(2, kit, s.level)["primary"] == C.W.DMR)
	_check("and the top-level parts with it", (Gear.sanitize(2, kit, s.level)["parts_p"] as Array).size() == 2)
	_check("Korpo's auditor too", Gear.sanitize(1, kit, s.level, C.Team.EMPIRE)["primary"] == C.W.DMR)
	Net.send_deploy(2, -1, kit)
	await _wait(0.4)
	var c: PlayerController = w.controller
	_check("deployed with the KP-20", s.alive and s.loadout[0] == C.W.DMR and s.has_two_sights())
	_check("starting on the red dot", s.sight == 0 and not c.vm.switching_sight())
	var magnifier := c.vm.gun.get_node_or_null("Magnifier") as Node3D
	_check("with the magnifier folded aside", magnifier != null and magnifier.transform.is_equal_approx(WeaponFactory.magnifier_pose(0.0)))

	await _press("sight_switch")
	_check("V flips the magnifier in", s.sight == 1 and c.vm.switching_sight())
	await _wait(0.12)
	Input.action_press("aim")
	await _wait(0.1)
	_check("the sight cannot come up while the hands are busy", not s.aiming)
	await _wait(ViewModel.FLIP_TIME)
	_check("the flip is over", not c.vm.switching_sight())
	_check("the magnifier sits on the sight line", magnifier.transform.is_equal_approx(WeaponFactory.magnifier_pose(1.0)))
	await _wait(0.7)
	_check("aiming now looks through the magnifier (fov %.1f)" % c.camera.fov, c.scoped and c.camera.fov < Settings.fov * 0.5)
	Input.action_release("aim")
	await _wait(0.4)

	await _press("sight_switch", true)
	await _wait(ViewModel.FLIP_TIME + 0.1)
	_check("the middle button flips it back to the dot", s.sight == 0 and magnifier.transform.is_equal_approx(WeaponFactory.magnifier_pose(0.0)))
	Input.action_press("aim")
	await _wait(0.7)
	_check("aiming through the dot keeps the gun in view (fov %.1f)" % c.camera.fov, not c.scoped and c.vm.visible and c.camera.fov > Settings.fov * 0.6)
	Input.action_release("aim")
	await _wait(0.3)

	# The choice is the player's, so it comes back after the next life.
	await _press("sight_switch")
	await _wait(ViewModel.FLIP_TIME + 0.1)
	s.protected_t = 0.0
	w.server.apply_damage(s, 9999.0, null, C.W.PISTOL, false, s.global_position)
	await _wait(C.RESPAWN_DELAY + 0.2)
	Net.send_deploy(2, -1, kit)
	await _wait(0.4)
	magnifier = c.vm.gun.get_node_or_null("Magnifier") as Node3D
	_check("the magnifier is still in after a respawn", s.alive and s.sight == 1 and magnifier.transform.is_equal_approx(WeaponFactory.magnifier_pose(1.0)))
	c._switch(1)
	await _wait(0.2)
	await _press("sight_switch")
	_check("a pistol has nothing to flip", s.sight == 1 and not c.vm.switching_sight())


## Presses an action for one physics tick, the way a real key press reaches the controller.
func _press(action: String, mouse := false) -> void:
	if mouse:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_MIDDLE
		ev.pressed = true
		_check("the middle button is bound to the sight switch", InputMap.event_is_action(ev, action))
	await get_tree().physics_frame
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[dmr] %s %s" % ["PASS" if ok else "FAIL", label])
