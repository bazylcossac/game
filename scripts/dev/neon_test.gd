extends Node
## `--test=neon`, headless: is the city wide enough? A tank and a mech must reach every flag from
## both bases, and every metre of every street must leave them a wide road through the cover.

## The narrowest free width allowed across a street, in metres of road a tank can use.
const TANK_ROAD := 12.0
const MECH_ROAD := 14.0

var passed := 0
var failed := 0


func _ready() -> void:
	for mode: String in ["podboj", "czolgi", "pvp"]:
		var map := NeonMap.new(mode)
		var holder := Node3D.new()
		add_child(holder)
		map.build(holder, Modes.DEFAULT_SEED, true)
		map.b.nav.label_regions()
		map.b.nav_tank.label_regions()
		map.b.nav_wide.label_regions()
		_reach(map, mode)
		if mode == "podboj":
			_roads(map)
			_symmetry(map)
		holder.queue_free()
		await get_tree().process_frame
	await _old_town()
	await _trenches()
	print("[neon] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


## Ziemia Niczyja: soldiers walk anywhere, tanks only through the gaps in the lines.
func _trenches() -> void:
	for mode: String in ["podboj", "czolgi", "pvp"]:
		var map := TrenchMap.new(mode)
		var holder := Node3D.new()
		add_child(holder)
		var started := Time.get_ticks_msec()
		map.build(holder, Modes.DEFAULT_SEED, true)
		print("[neon] trench build %d ms" % (Time.get_ticks_msec() - started))
		map.b.nav.label_regions()
		map.b.nav_tank.label_regions()
		map.b.nav_wide.label_regions()
		for f: Dictionary in map.flag_defs():
			for home: Vector3 in map.bases():
				_check("%s trenches: soldier reaches %s" % [mode, f["name"]], map.b.nav.can_reach(home, f["pos"]))
				_check("%s trenches: tank in range of %s" % [mode, f["name"]], _in_range(map, home, f["pos"]))
		for team in 2:
			for spawn: Vector3 in map.team_spawns(team):
				_check("%s trenches: spawn %s is free" % [mode, spawn], map.b.nav.is_free(map.b.nav.cell_of(spawn)))
			for spot: Array in map.tank_depots()[team]:
				_check("%s trenches: pad reaches the front" % mode, map.b.nav_tank.can_reach(spot[0], Vector3(63, 0, 20)))
		var floor_y := map.ground_height(-171.0, 114.0)
		var edge := map.ground_height(-171.0, 120.0 + 6.0)
		_check("trench is deep enough to hide in (%.1f m)" % (edge - floor_y), edge - floor_y > 1.4)
		holder.queue_free()
		await get_tree().process_frame


## Stare Miasto has tanks too. Same questions, on its narrower streets.
func _old_town() -> void:
	var map := CityMap.new()
	var holder := Node3D.new()
	add_child(holder)
	map.build(holder, Modes.DEFAULT_SEED, true)
	map.b.nav.label_regions()
	map.b.nav_tank.label_regions()
	map.b.nav_wide.label_regions()
	for f: Dictionary in map.flag_defs():
		for home: Vector3 in map.bases():
			_check("old town: mech reaches %s" % f["name"], map.b.nav_wide.can_reach(home, f["pos"]))
			_check("old town: tank gets in range of %s" % f["name"], _in_range(map, home, f["pos"]))
	var worst := 999.0
	var worst_mech := 999.0
	var where := Vector3.ZERO
	for x: float in CityMap.STREETS_X.slice(1, CityMap.STREETS_X.size() - 1):
		var s := -CityMap.CITY_Z + 12.0
		while s <= CityMap.CITY_Z - 12.0:
			var tank := _widest(map.b.nav_tank, x, CityMap.STREET_HALF, s, true)
			if tank < worst:
				worst = tank
				where = Vector3(x, 0, s)
			worst_mech = minf(worst_mech, _widest(map.b.nav_wide, x, CityMap.STREET_HALF, s, true))
			s += 4.0
	for z: float in CityMap.STREETS_Z.slice(1, CityMap.STREETS_Z.size() - 1):
		var s := -CityMap.CITY_X + 12.0
		while s <= CityMap.CITY_X - 12.0:
			var tank := _widest(map.b.nav_tank, z, CityMap.STREET_HALF, s, false)
			if tank < worst:
				worst = tank
				where = Vector3(s, 0, z)
			worst_mech = minf(worst_mech, _widest(map.b.nav_wide, z, CityMap.STREET_HALF, s, false))
			s += 4.0
	print("[neon] old town narrowest road: tank %.0f m at %s, mech %.0f m" % [worst, where, worst_mech])
	_check("old town leaves a tank at least 8 m", worst >= 8.0)
	_check("old town leaves a mech at least 10 m", worst_mech >= 10.0)
	holder.queue_free()
	await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("[neon] FAIL ", label)


func _reach(map: NeonMap, mode: String) -> void:
	var homes: Array = map.bases()
	var points: Array[Vector3] = []
	for f: Dictionary in map.flag_defs():
		points.append(f["pos"])
	points.append_array(map.hotspots())
	for p: Vector3 in points:
		for home: Vector3 in homes:
			_check("%s: soldier reaches %s" % [mode, p], map.b.nav.can_reach(home, p))
			_check("%s: mech reaches %s" % [mode, p], map.b.nav_wide.can_reach(home, p))
			_check("%s: tank reaches %s" % [mode, p], map.b.nav_tank.can_reach(home, p))
	for team in 2:
		for spawn: Vector3 in map.team_spawns(team):
			_check("%s: spawn %s is free" % [mode, spawn], map.b.nav.is_free(map.b.nav.cell_of(spawn)))
		for spot: Array in map.tank_depots()[team]:
			_check("%s: tank pad %s is free" % [mode, spot[0]], map.b.nav_tank.is_free(map.b.nav_tank.cell_of(spot[0])))
			_check("%s: tank pad reaches the square" % mode, map.b.nav_tank.can_reach(spot[0], Vector3(14, 0, 40)))


## Cuts every street crosswise every four metres and measures the widest free run.
func _roads(map: NeonMap) -> void:
	var worst_tank := 999.0
	var worst_mech := 999.0
	var where := Vector3.ZERO
	var streets: Array = [[0.0, NeonMap.BOULEVARD, true], [NeonMap.AVENUE_X, NeonMap.AVENUE, true], [-NeonMap.AVENUE_X, NeonMap.AVENUE, true]]
	for z: float in NeonMap.CROSS_Z:
		streets.append([z, NeonMap.CROSS, false])
	for street: Array in streets:
		var along_z: bool = street[2]
		var reach: float = (NeonMap.HALF.y if along_z else NeonMap.HALF.x) - 40.0
		var s := -reach
		while s <= reach:
			var tank := _widest(map.b.nav_tank, street[0], street[1], s, along_z)
			var mech := _widest(map.b.nav_wide, street[0], street[1], s, along_z)
			if tank < worst_tank:
				worst_tank = tank
				where = Vector3(street[0], 0, s) if along_z else Vector3(s, 0, street[0])
			worst_mech = minf(worst_mech, mech)
			s += 4.0
	print("[neon] narrowest road: tank %.0f m at %s, mech %.0f m" % [worst_tank, where, worst_mech])
	_check("every street leaves a tank at least %d m" % int(TANK_ROAD), worst_tank >= TANK_ROAD)
	_check("every street leaves a mech at least %d m" % int(MECH_ROAD), worst_mech >= MECH_ROAD)


## Some flags stand inside halls. A tank only has to come close enough to capture one.
func _in_range(map: MapKit, home: Vector3, flag: Vector3) -> bool:
	for i in 16:
		var a := TAU * i / 16.0
		var p := flag + Vector3(cos(a), 0, sin(a)) * (C.FLAG_RADIUS - 1.0)
		if map.b.nav_tank.is_free(map.b.nav_tank.cell_of(p)) and map.b.nav_tank.can_reach(home, p):
			return true
	return false


func _widest(nav: NavGrid, centre: float, half: float, s: float, along_z: bool) -> float:
	var best := 0.0
	var run := 0.0
	var at := -half
	while at <= half:
		var p := Vector3(centre + at, 0, s) if along_z else Vector3(s, 0, centre + at)
		run = run + nav.cell_metres if nav.is_free(nav.cell_of(p)) else 0.0
		best = maxf(best, run)
		at += nav.cell_metres
	return best


func _symmetry(map: NeonMap) -> void:
	var home: Array = map.bases()
	_check("bases mirror each other", (home[0] as Vector3).is_equal_approx(-(home[1] as Vector3)))
	var mismatch := 0
	var cells := 0
	for x in range(-240, 241, 8):
		for z in range(-330, 331, 8):
			# The middle of a cell, so a point and its mirror fall on matching cells.
			var p := Vector3(x + 1, 0, z + 1)
			cells += 1
			if map.b.nav_tank.is_free(map.b.nav_tank.cell_of(p)) != map.b.nav_tank.is_free(map.b.nav_tank.cell_of(-p)):
				mismatch += 1
	print("[neon] mirror: %d of %d cells differ" % [mismatch, cells])
	_check("the two halves match within 4%", float(mismatch) / cells < 0.04)
