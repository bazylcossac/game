class_name CityMap
extends MapKit
## Stare Miasto: the procedural war-torn city. The same seed yields identical geometry on
## server and clients.

const STREETS_X := [-231.0, -165.0, -99.0, -33.0, 33.0, 99.0, 165.0, 231.0]
const STREETS_Z := [-165.0, -99.0, -33.0, 33.0, 99.0, 165.0]
const BLOCKS_X := [-198.0, -132.0, -66.0, 0.0, 66.0, 132.0, 198.0]
const BLOCKS_Z := [-132.0, -66.0, 0.0, 66.0, 132.0]
const CITY_X := 244.0
const CITY_Z := 178.0
## 26 m between the houses: room for a tank to pass a wreck, and for two tanks to meet.
const STREET_HALF := 13.0
const BOUND_X := 274.0
const BOUND_Z := 227.0

const FLAG_DEFS := [
	{"name": "Ratusz", "letter": "A", "pos": Vector3(-132, 0, 72), "owner": 0},
	{"name": "Dworzec", "letter": "B", "pos": Vector3(132, 0, 68), "owner": 0},
	{"name": "Rynek", "letter": "C", "pos": Vector3(4, 0, 4), "owner": -1},
	{"name": "Fabryka", "letter": "D", "pos": Vector3(-132, 0, -66), "owner": 1},
	{"name": "Koszary", "letter": "E", "pos": Vector3(132, 0, -66), "owner": 1},
]
const BASES := [Vector3(0, 0, 196), Vector3(0, 0, -196)]
## Where each team's tanks stand at the start, as [position, hull yaw].
const TANK_DEPOTS := [
	[[Vector3(-9, 0, 183), 0.0], [Vector3(9, 0, 183), 0.0]],
	[[Vector3(-9, 0, -180), PI], [Vector3(9, 0, -180), PI]],
]


## It has just stopped raining: wet cobbles, and the front is still firing beyond the town.
func climate_of() -> Dictionary:
	return {"wet": 0.26, "grime": 0.6}


func weather() -> Dictionary:
	return {"guns": true}


func flag_defs() -> Array:
	return FLAG_DEFS


func bases() -> Array:
	return BASES


func tank_depots() -> Array:
	return TANK_DEPOTS


func bound() -> Vector2:
	return Vector2(BOUND_X, BOUND_Z)


func focus() -> Vector3:
	return FLAG_DEFS[2]["pos"]


func coin_area() -> Vector2:
	return Vector2(236.0, 170.0)


func street_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for s: float in STREETS_X:
		out.append(Rect2(s - STREET_HALF, -CITY_Z, STREET_HALF * 2.0, CITY_Z * 2.0))
	for s: float in STREETS_Z:
		out.append(Rect2(-CITY_X, s - STREET_HALF, CITY_X * 2.0, STREET_HALF * 2.0))
	return out


func _plan_terrain() -> void:
	_plan_craters()


func _build_scenery() -> void:
	for iz in BLOCKS_Z.size():
		for ix in BLOCKS_X.size():
			_build_block(ix, iz, BLOCKS_X[ix], BLOCKS_Z[iz])
	_build_street_props()
	_build_pavements()
	_camp_resistance(BASES[0])
	_camp_empire(BASES[1])


func _ground_tint(x: float, z: float, scorch: float) -> Color:
	var patch := sin(x * 0.11 + 0.7) * cos(z * 0.09) + sin(x * 0.031 - z * 0.04) * 0.9
	var open_land := smoothstep(CITY_Z - 7.0, CITY_Z + 7.0, maxf(absf(x) - 66.0, absf(z)))
	var in_park_column := absf(x) < 20.0 or absf(absf(x) - 198.0) < 20.0
	var park := 1.0 if in_park_column and absf(absf(z) - 66.0) < 20.0 else 0.0
	var grass := clampf(maxf(open_land, park) * (0.75 + patch * 0.3), 0.0, 1.0)
	return Color(_cobble_weight(x, z), grass, scorch, 1.0)


# ---------------------------------------------------------------- terrain

func base_height(x: float, z: float) -> float:
	var d := maxf(absf(x) / 281.0, absf(z) / 233.0)
	var rim := smoothstep(0.95, 1.7, d)
	var h := rim * (24.0 + 12.0 * sin(x * 0.013 + 1.0) * cos(z * 0.017))
	var field := smoothstep(0.86, 1.05, d)
	return h + field * sin(x * 0.05) * cos(z * 0.06) * 1.3


func _on_street(x: float, z: float) -> float:
	var best := 999.0
	if absf(z) < CITY_Z:
		for s: float in STREETS_X:
			best = minf(best, absf(x - s))
	if absf(x) < CITY_X:
		for s: float in STREETS_Z:
			best = minf(best, absf(z - s))
	return 1.0 - smoothstep(STREET_HALF - 0.8, STREET_HALF + 0.8, best)


func _cobble_weight(x: float, z: float) -> float:
	var w := _on_street(x, z)
	for f: Dictionary in FLAG_DEFS:
		var p: Vector3 = f["pos"]
		if f["letter"] == "C":
			w = maxf(w, 1.0 - smoothstep(22.0, 27.0, maxf(absf(x), absf(z))))
		elif f["letter"] == "B":
			pass
		elif f["letter"] == "A":
			w = maxf(w, 1.0 - smoothstep(14.0, 18.0, Vector2(x - p.x, z - p.z).length()))
	return w


func _plan_craters() -> void:
	for i in 62:
		var off := rng.randf_range(-10.0, 10.0)
		var p := Vector2.ZERO
		if rng.randf() < 0.5:
			p = Vector2(float(STREETS_X[rng.randi_range(0, STREETS_X.size() - 1)]) + off, rng.randf_range(-170.0, 170.0))
		else:
			p = Vector2(rng.randf_range(-236.0, 236.0), float(STREETS_Z[rng.randi_range(0, STREETS_Z.size() - 1)]) + off)
		_add_crater(p, rng.randf_range(1.8, 3.6))
	# Open ground in the two park blocks and the no-man's land in front of the bases.
	for i in 44:
		var cz := 66.0 if rng.randf() < 0.5 else -66.0
		var cx: float = [0.0, -198.0, 198.0][rng.randi_range(0, 2)]
		_add_crater(Vector2(cx + rng.randf_range(-18, 18), cz + rng.randf_range(-18, 18)), rng.randf_range(2.0, 4.5))
	for i in 18:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		_add_crater(Vector2(rng.randf_range(-260, 260), side * rng.randf_range(CITY_Z - 2.0, CITY_Z + 7.0)), rng.randf_range(2.0, 4.5))


# ---------------------------------------------------------------- blocks

func _build_block(ix: int, iz: int, cx: float, cz: float) -> void:
	match [ix, iz]:
		[1, 3]: _site_town_hall(cx, cz)
		[5, 3]: _site_station(cx, cz)
		[3, 2]: _site_market(cx, cz)
		[1, 1]: _site_factory(cx, cz)
		[5, 1]: _site_barracks(cx, cz)
		[3, 1], [3, 3], [0, 1], [0, 3], [6, 1], [6, 3]: _site_park(cx, cz)
		_: _tenement_block(cx, cz)


func _tenement_block(cx: float, cz: float) -> void:
	var half := 20.0
	var depth := 9.0
	# South, north, east and west sides, each [offset along normal, yaw, span, axis].
	for side in 4:
		var yaw := 0.0
		var span := 40.0
		match side:
			1: yaw = PI
			2:
				yaw = PI * 0.5
				span = 40.0 - depth * 2.0 - 2.0
			3:
				yaw = -PI * 0.5
				span = 40.0 - depth * 2.0 - 2.0
		var s := -span * 0.5
		while s < span * 0.5 - 6.0:
			var w := minf(rng.randf_range(10.0, 15.0), span * 0.5 - s)
			var along := s + w * 0.5
			var offset := half - depth * 0.5
			var local := Vector3(along, 0, offset)
			var world := Basis(Vector3.UP, yaw) * local + Vector3(cx, 0, cz)
			if rng.randf() < 0.14:
				_rubble(world, rng.randf_range(2.5, 3.6), 22, "brick", Color(0.9, 0.84, 0.8))
			else:
				var ruin := 0.0 if rng.randf() < 0.3 else rng.randf_range(0.25, 0.9)
				_building(world, w, depth, rng.randi_range(2, 3), yaw, ruin)
			s += w + rng.randf_range(2.8, 4.6)
	# Courtyard clutter.
	for i in rng.randi_range(3, 5):
		var p := Vector3(cx + rng.randf_range(-7, 7), 0, cz + rng.randf_range(-7, 7))
		match rng.randi_range(0, 3):
			0: _crates(p)
			1: _dead_tree(p)
			2: _sandbags(p, p + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)).normalized() * 4.0)
			3: _rubble(p, 1.4, 8, "concrete", Color(0.8, 0.8, 0.78))


func _site_market(cx: float, cz: float) -> void:
	# Monument: a plinth with a broken obelisk. Cover for the centre of the map.
	b.box(Vector3(cx, 0.35, cz), Vector3(9, 0.7, 9), "concrete", Color(0.8, 0.78, 0.72), true, 0.0, true)
	b.box(Vector3(cx, 1.1, cz), Vector3(6, 0.8, 6), "concrete", Color(0.72, 0.7, 0.66))
	b.box(Vector3(cx, 2.7, cz), Vector3(2.4, 2.4, 2.4), "concrete", Color(0.64, 0.62, 0.6))
	b.add_prism(Vector3(cx, 3.9, cz), 0.95, 3.8, 4, "concrete", Color(0.6, 0.58, 0.56), 0.4)
	b.add_footprint(Vector2(cx, cz), Vector2(9, 9), 0.0, "cover")
	for i in 7:
		var ang := TAU * i / 7.0 + 0.3
		var p := Vector3(cx + cos(ang) * 15.5, 0, cz + sin(ang) * 15.5)
		if i % 2 == 0:
			_market_stall(p, ang + PI * 0.5)
		else:
			_sandbags(p - Vector3(-sin(ang), 0, cos(ang)) * 3.0, p + Vector3(-sin(ang), 0, cos(ang)) * 3.0)
	_tram(Vector3(cx + 19, 0, cz - 6), 0.5)
	_truck(Vector3(cx - 17, 0, cz + 11), 2.0)
	_hedgehog(Vector3(cx - 10, 0, cz - 15))
	_hedgehog(Vector3(cx + 10, 0, cz + 16))
	fires.append(Vector3(cx + 19, 2.6, cz - 6))
	smokes.append(Vector3(cx - 17, 0.5, cz + 11))


func _site_town_hall(cx: float, cz: float) -> void:
	# Grand hall along the north side, with a clock tower. The flag stands on its forecourt.
	var hall := Vector3(cx, 0, cz - 11)
	var xf := Transform3D(Basis.IDENTITY, hall)
	var tint := Color(0.92, 0.84, 0.72)
	var w := 34.0
	var d := 15.0
	var opts := {"floors": 3, "fh": 3.9, "mat": "plaster", "tint": tint, "cornice": true, "bay": 3.4, "solid": 0.0, "lintel": 2.9, "sill": 1.1, "ruin": 0.0, "pier": 1.4}
	var front := opts.duplicate()
	front["doors"] = [4, 5]
	var ruined := opts.duplicate()
	ruined["ruin"] = 0.18
	_wall(xf, Vector2(-w / 2, d / 2), Vector2(w / 2, d / 2), front)
	var back := ruined.duplicate()
	back["doors"] = [2, 7]
	_wall(xf, Vector2(w / 2, -d / 2), Vector2(-w / 2, -d / 2), back)
	var side := ruined.duplicate()
	side["doors"] = [2]
	_wall(xf, Vector2(w / 2, d / 2), Vector2(w / 2, -d / 2), side)
	_wall(xf, Vector2(-w / 2, -d / 2), Vector2(-w / 2, d / 2), side)
	b.add_footprint(Vector2(hall.x, hall.z), Vector2(w, d), 0.0, "landmark")
	# Mezzanine reached by a long ramp, overlooking the square through the windows.
	b.box(hall + Vector3(0, 3.9, 3.5), Vector3(w - 1, 0.25, d - 8), "concrete", Color(0.7, 0.68, 0.64))
	var ramp_len := Vector2(7.0, 3.9).length()
	b.add_box(Transform3D(Basis(Vector3.BACK, atan2(3.9, 7.0)), hall + Vector3(-10, 1.92, -2.0)), Vector3(ramp_len, 0.18, 2.4), "wood", Color(0.7, 0.6, 0.5))
	b.box(hall + Vector3(-6.5 + 3.0, 3.9, -2.0), Vector3(7.0, 0.25, 3.2), "concrete", Color(0.7, 0.68, 0.64))
	# Clock tower.
	var tower := Vector3(cx + 13, 0, cz - 20)
	var tw := Transform3D(Basis.IDENTITY, tower)
	var t_opts := {"floors": 8, "fh": 3.9, "mat": "brick", "tint": Color(0.82, 0.74, 0.68), "bay": 3.0, "solid": 0.55, "sill": 1.4, "lintel": 3.0}
	for edge: Array in [[Vector2(-3.5, 3.5), Vector2(3.5, 3.5)], [Vector2(3.5, 3.5), Vector2(3.5, -3.5)], [Vector2(3.5, -3.5), Vector2(-3.5, -3.5)], [Vector2(-3.5, -3.5), Vector2(-3.5, 3.5)]]:
		_wall(tw, edge[0], edge[1], t_opts)
	b.add_prism(tower + Vector3(0, 31.2, 0), 5.0, 6.0, 4, "roof", Color(0.45, 0.5, 0.5), 0.1)
	b.add_footprint(Vector2(tower.x, tower.z), Vector2(7, 7), 0.0, "landmark")
	_sandbags(Vector3(cx - 9, 0, cz + 14), Vector3(cx - 2, 0, cz + 16))
	_sandbags(Vector3(cx + 3, 0, cz + 16), Vector3(cx + 10, 0, cz + 13))
	_crates(Vector3(cx - 13, 0, cz + 5))
	_crates(Vector3(cx + 14, 0, cz + 7))
	_tank_wreck(Vector3(cx + 16, 0, cz + 17), 0.6)
	smokes.append(Vector3(cx + 16, 1.5, cz + 17))
	_dead_tree(Vector3(cx - 16, 0, cz + 15))


func _site_station(cx: float, cz: float) -> void:
	# Long platform canopy with freight wagons parked along the rails.
	var length := 44.0
	for x: float in [-11.0, -1.0, 9.0]:
		for i in 5:
			var z := cz - 16.0 + i * 8.0
			b.box(Vector3(cx + x + 6, 2.6, z), Vector3(0.34, 5.2, 0.34), "metal", Color(0.5, 0.55, 0.52), true, 0.0, true)
	for strip in 3:
		var x: float = [-5.0, 5.0, 15.0][strip]
		b.box(Vector3(cx + x, 5.3, cz), Vector3(9.0, 0.2, 36.0), "metal", Color(0.46, 0.5, 0.5))
	b.add_footprint(Vector2(cx + 5, cz), Vector2(30, 36), 0.0, "canopy")
	for rail: float in [-14.0, -3.0, 7.0]:
		for off: float in [-0.72, 0.72]:
			b.box(Vector3(cx + rail + off, 0.05, cz), Vector3(0.12, 0.1, length), "metal", Color(0.45, 0.4, 0.38), false)
		var z := cz - 22.0
		while z < cz + 22.0:
			b.box(Vector3(cx + rail, 0.02, z), Vector3(2.4, 0.05, 0.3), "wood", Color(0.5, 0.42, 0.36), false)
			z += 1.2
	_wagon(Vector3(cx - 14, 0, cz - 13), 0.0)
	_wagon(Vector3(cx - 14, 0, cz + 11), 0.0)
	_wagon(Vector3(cx + 7, 0, cz - 15), 0.0)
	_wagon(Vector3(cx - 3, 0, cz + 15), 0.08)
	_building(Vector3(cx - 15, 0, cz + 22 - 4.5 - 18), 6.0, 0.1 + 8.0, 1, PI * 0.5, 0.6)
	_crates(Vector3(cx + 2, 0, cz + 7))
	_crates(Vector3(cx - 8, 0, cz - 3))
	_sandbags(Vector3(cx - 9, 0, cz + 6), Vector3(cx - 9, 0, cz - 1))
	smokes.append(Vector3(cx - 14, 3.0, cz + 11))


func _site_factory(cx: float, cz: float) -> void:
	var w := 34.0
	var d := 26.0
	var xf := Transform3D(Basis.IDENTITY, Vector3(cx, 0, cz))
	var opts := {"floors": 1, "fh": 8.5, "mat": "brick", "tint": Color(0.78, 0.72, 0.68), "bay": 4.6, "solid": 0.1, "sill": 3.4, "lintel": 6.8, "ruin": 0.12}
	var side := opts.duplicate()
	side["doors"] = [2]
	# Shells opened both long walls, wide enough to drive a tank through the hall.
	for z: float in [d / 2, -d / 2]:
		_wall(xf, Vector2(-w / 2, z), Vector2(-7.5, z), opts)
		_wall(xf, Vector2(7.5, z), Vector2(w / 2, z), opts)
		_rubble(Vector3(cx - 9.0, 0, cz + z), 2.2, 12, "brick", Color(0.78, 0.72, 0.68))
		_rubble(Vector3(cx + 9.0, 0, cz + z), 2.2, 12, "brick", Color(0.78, 0.72, 0.68))
	_wall(xf, Vector2(w / 2, d / 2), Vector2(w / 2, -d / 2), side)
	_wall(xf, Vector2(-w / 2, -d / 2), Vector2(-w / 2, d / 2), side)
	b.add_footprint(Vector2(cx, cz), Vector2(w, d), 0.0, "landmark")
	b.box(Vector3(cx, 0.02, cz), Vector3(w - 0.4, 0.04, d - 0.4), "concrete", Color(0.55, 0.54, 0.52), false)
	# Roof trusses with half the sheeting blown away.
	for i in 7:
		var x := cx - 15.0 + i * 5.0
		b.box(Vector3(x, 8.6, cz), Vector3(0.3, 0.45, d), "metal", Color(0.42, 0.42, 0.42), false)
		if i % 3 != 1 and i != 2 and i != 3:
			b.box(Vector3(x + 2.5, 8.85, cz + (6.5 if i % 2 == 0 else -6.5)), Vector3(5.0, 0.08, 13.0), "metal", Color(0.4, 0.4, 0.4), false)
	# Machines as cover, leaving a clear lane around the flag.
	for spec: Array in [[-10.0, -7.0, 0.0], [-10.0, 7.0, 0.0], [10.0, -7.0, 0.0], [10.0, 7.0, 0.0]]:
		_machine(Vector3(cx + spec[0], 0, cz + spec[1]))
	_crates(Vector3(cx - 3, 0, cz - 9))
	_crates(Vector3(cx + 4, 0, cz + 9))
	for s: Array in [[-13.0, -18.0, 22.0], [-6.0, -18.5, 19.0]]:
		b.add_prism(Vector3(cx + s[0], 0, cz + s[1]), 1.5, s[2], 10, "brick", Color(0.7, 0.62, 0.58), 0.95)
		smokes.append(Vector3(cx + s[0], s[2], cz + s[1]))
	_sandbags(Vector3(cx + 12, 0, cz + 16), Vector3(cx + 18, 0, cz + 16))
	_sandbags(Vector3(cx - 18, 0, cz + 16), Vector3(cx - 12, 0, cz + 16))
	_truck(Vector3(cx + 16, 0, cz - 17), 0.2)


func _site_barracks(cx: float, cz: float) -> void:
	var g := Color(0.72, 0.72, 0.7)
	# Perimeter wall with gaps on each side. The south side was breached, wide enough for a tank.
	for seg: Array in [
		[Vector3(cx - 15, 1.4, cz + 18), Vector3(8, 2.8, 0.6)], [Vector3(cx + 15, 1.4, cz + 18), Vector3(8, 2.8, 0.6)],
		[Vector3(cx - 11, 1.4, cz - 18), Vector3(16, 2.8, 0.6)], [Vector3(cx + 11, 1.4, cz - 18), Vector3(16, 2.8, 0.6)],
		[Vector3(cx + 18, 1.4, cz - 11), Vector3(0.6, 2.8, 14)], [Vector3(cx + 18, 1.4, cz + 11), Vector3(0.6, 2.8, 14)],
		[Vector3(cx - 18, 1.4, cz - 11), Vector3(0.6, 2.8, 14)], [Vector3(cx - 18, 1.4, cz + 11), Vector3(0.6, 2.8, 14)],
	]:
		b.box(seg[0], seg[1], "concrete", g)
		b.add_footprint(Vector2(seg[0].x, seg[0].z), Vector2(seg[1].x, seg[1].z), 0.0, "cover")
	_bunker(Vector3(cx - 9.5, 0, cz - 9.5), 0.0)
	_bunker(Vector3(cx + 9.5, 0, cz + 9.5), PI)
	_watch_tower(Vector3(cx + 15, 0, cz - 15))
	_watch_tower(Vector3(cx - 15, 0, cz + 15))
	_crates(Vector3(cx + 11, 0, cz - 9))
	_crates(Vector3(cx - 10, 0, cz + 9))
	_sandbags(Vector3(cx - 8, 0, cz + 2), Vector3(cx - 2, 0, cz + 2))
	_sandbags(Vector3(cx - 3, 0, cz - 6), Vector3(cx + 4, 0, cz - 6))
	_hedgehog(Vector3(cx - 22, 0, cz))
	_wire(Vector3(cx - 19, 0, cz + 20), Vector3(cx - 12, 0, cz + 21))
	_wire(Vector3(cx + 12, 0, cz + 21), Vector3(cx + 19, 0, cz + 20))
	_rubble(Vector3(cx - 10, 0, cz + 19), 1.6, 9, "concrete", g)
	_rubble(Vector3(cx + 10, 0, cz + 19), 1.4, 8, "concrete", g)
	_tank_wreck(Vector3(cx + 22, 0, cz + 3), 1.4)
	fires.append(Vector3(cx + 22, 1.5, cz + 3))


func _site_park(cx: float, cz: float) -> void:
	# Shell-torn gardens: open ground crossed by trenches of sandbags.
	for i in 9:
		_dead_tree(Vector3(cx + rng.randf_range(-18, 18), 0, cz + rng.randf_range(-18, 18)))
	for i in 5:
		var p := Vector3(cx + rng.randf_range(-15, 15), 0, cz + rng.randf_range(-15, 15))
		_sandbags(p, p + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-0.3, 0.3)).normalized() * rng.randf_range(4.0, 8.0))
	_hedgehog(Vector3(cx - 8, 0, cz + 4))
	_hedgehog(Vector3(cx + 10, 0, cz - 6))
	_wire(Vector3(cx - 20, 0, cz - 15), Vector3(cx - 10, 0, cz - 16))
	_wire(Vector3(cx + 11, 0, cz + 15), Vector3(cx + 20, 0, cz + 14))
	_tank_wreck(Vector3(cx + 3, 0, cz + 2), rng.randf_range(0, TAU))
	smokes.append(Vector3(cx + 3, 1.5, cz + 2))


# ---------------------------------------------------------------- streets and bases

## Infantry cover. Between two crossings a street gets three strongpoints, against alternate kerbs,
## so a soldier can run from one to the next while a tank keeps its lane past them.
func _street_cover() -> void:
	for x: float in STREETS_X:
		for z: float in BLOCKS_Z:
			var side := 1.0 if int(x / 33.0 + z / 66.0) % 2 == 0 else -1.0
			for i in 3:
				var kerb := side * (1.0 if i != 1 else -1.0)
				_strongpoint(Vector3(x + kerb * 9.0, 0, z + (i - 1) * 13.0), 0.0, kerb)
				_kerb_cover(Vector3(x - kerb * 11.2, 0, z + (i - 1) * 13.0), 0.0)
	for z: float in STREETS_Z:
		for x: float in BLOCKS_X:
			var side := 1.0 if int(z / 33.0 + x / 66.0) % 2 == 0 else -1.0
			for i in 3:
				var kerb := side * (1.0 if i != 1 else -1.0)
				_strongpoint(Vector3(x + (i - 1) * 13.0, 0, z + kerb * 9.0), PI * 0.5, kerb)
				_kerb_cover(Vector3(x + (i - 1) * 13.0, 0, z - kerb * 11.2), PI * 0.5)
	# On a crossing the corners give cover in both directions. The middle stays open.
	for x: float in STREETS_X:
		for z: float in STREETS_Z:
			if _near_flag(Vector3(x, 0, z), 15.0):
				continue
			# Two opposite corners, alternating from one crossing to the next.
			var turn := 1.0 if (int(x / 66.0) + int(z / 66.0)) % 2 == 0 else -1.0
			for flip: Vector2 in [Vector2(1, turn), Vector2(-1, -turn)]:
				var c := Vector3(x + flip.x * 11.0, 0, z + flip.y * 11.0)
				_sandbags(c - Vector3(flip.x * 3.0, 0, 0), c)
				_sandbags(c, c - Vector3(0, 0, flip.y * 3.0))
				b.add_footprint(Vector2(c.x - flip.x * 1.5, c.z), Vector2(3, 1), 0.0, "cover")
				b.add_footprint(Vector2(c.x, c.z - flip.y * 1.5), Vector2(1, 3), 0.0, "cover")


## One strongpoint. `yaw` turns it to its street: its walls face along the street, where the shooting
## comes from, and `side` is the kerb it backs on to.
func _strongpoint(c: Vector3, yaw: float, side: float) -> void:
	if _near_flag(c, 15.0) or _at_gate(c):
		return
	var across := Vector3(cos(yaw), 0, -sin(yaw))
	var along := Vector3(sin(yaw), 0, cos(yaw))
	var turn := yaw + rng.randf_range(-0.12, 0.12)
	match rng.randi_range(0, 6):
		6:
			_tank_wreck(c, yaw + rng.randf_range(-0.14, 0.14))
		0:
			# Sandbags in a U, open towards the kerb.
			_sandbags(c - across * side * 3.0 - along * 2.2, c + across * side * 3.0 - along * 2.2)
			_sandbags(c - across * side * 3.0 + along * 2.2, c + across * side * 3.0 + along * 2.2)
			_sandbags(c - across * side * 3.0 - along * 2.2, c - across * side * 3.0 + along * 2.2)
			_bag_cover(c - along * 2.2, 6.0, yaw)
			_bag_cover(c + along * 2.2, 6.0, yaw)
			_bag_cover(c - across * side * 3.0, 4.4, yaw + PI * 0.5)
		1:
			# A wall the shells left standing, with its own bricks heaped at the foot.
			_broken_wall(c - along * 1.4, 6.5, yaw)
			_rubble(c + along * 1.0 + across * side * 1.5, 1.7, 9, "brick", Color(0.8, 0.72, 0.66))
		2:
			_burnt_car(c - along * 2.0, yaw + PI * 0.5 + rng.randf_range(-0.2, 0.2))
			_burnt_car(c + along * 3.0 + across * side * 1.0, yaw + PI * 0.5 + rng.randf_range(-0.3, 0.3))
		3:
			# A container dragged across the road, tall enough to stand behind.
			props.stand("container", c, turn, Color(0.5, 0.34, 0.26))
			b.add_box(Transform3D(Basis(Vector3.UP, turn), c + Vector3.UP * 1.3), Vector3(6.1, 2.6, 2.5), "", Color.WHITE)
			b.add_footprint(Vector2(c.x, c.z), Vector2(6.1, 2.5), turn, "cover")
			_sandbags(c + along * 2.4 - across * 2.5, c + along * 2.4 + across * 1.5, 3)
		4:
			# The tram that stopped here. Long side to the street, stopped dead.
			props.stand("wreck_truck", c, turn + PI * 0.5)
			_truck_cover(c, turn)
			_broken_wall(c + along * 4.0 + across * side * 1.0, 4.0, yaw)
		5:
			_street_barricade(c, yaw)


## Something small against the far kerb, so nobody is more than a few steps from cover.
func _kerb_cover(c: Vector3, yaw: float) -> void:
	if _near_flag(c, 14.0):
		return
	var along := Vector3(sin(yaw), 0, cos(yaw))
	match rng.randi_range(0, 2):
		0:
			_sandbags(c - along * 1.8, c + along * 1.8)
			_bag_cover(c, 3.6, yaw + PI * 0.5)
		1:
			_crates(c)
		2:
			_broken_wall(c, 3.4, yaw + PI * 0.5)


func _bag_cover(at: Vector3, length: float, yaw: float) -> void:
	b.add_footprint(Vector2(at.x, at.z), Vector2(length, 0.9), yaw, "cover")


func _truck_cover(c: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), c)
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 0)), Vector3(6.4, 2.2, 2.1), "", Color.WHITE)
	b.add_footprint(Vector2(c.x, c.z), Vector2(6.4, 2.1), yaw, "cover")


## A chest-high wall with a broken top.
func _broken_wall(c: Vector3, length: float, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), c)
	var tint := Color(0.74, 0.62, 0.54)
	var x := -length * 0.5
	while x < length * 0.5 - 0.1:
		var w := minf(rng.randf_range(0.9, 1.7), length * 0.5 - x)
		var h := rng.randf_range(1.15, 1.9)
		b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(x + w * 0.5, h * 0.5, 0)), Vector3(w + 0.02, h, 0.46), "brick", tint)
		x += w
	b.add_footprint(Vector2(c.x, c.z), Vector2(length, 0.5), yaw, "cover")


## Beams, doors and a cart thrown across the road by the people who lived here.
func _street_barricade(c: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), c)
	var wood := Color(0.56, 0.44, 0.32)
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.62, 0)), Vector3(6.4, 1.24, 0.9), "", Color.WHITE)
	b.add_footprint(Vector2(c.x, c.z), Vector2(6.4, 0.9), yaw, "cover")
	for i in 9:
		var at := Vector3(rng.randf_range(-2.9, 2.9), rng.randf_range(0.2, 1.05), rng.randf_range(-0.4, 0.4))
		var lean := Basis(Vector3.BACK, rng.randf_range(-0.5, 0.5)) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4))
		b.add_box(xf * Transform3D(lean, at), Vector3(rng.randf_range(1.6, 3.0), 0.16, rng.randf_range(0.2, 0.46)), "wood", wood * rng.randf_range(0.7, 1.05), false)
	_crates(c + Basis(Vector3.UP, yaw) * Vector3(-1.2, 0, 1.3))


func _build_street_props() -> void:
	_street_cover()
	# Wrecks and barricades keep to the kerbs, so the middle of every street stays a road.
	for i in 60:
		var side := rng.randf_range(STREET_HALF - 2.6, STREET_HALF - 1.4) * (1.0 if rng.randf() < 0.5 else -1.0)
		var horizontal := rng.randf() < 0.5
		var p := Vector3.ZERO
		if horizontal:
			p = Vector3(rng.randf_range(-226.0, 226.0), 0, float(STREETS_Z[rng.randi_range(1, STREETS_Z.size() - 2)]) + side)
		else:
			p = Vector3(float(STREETS_X[rng.randi_range(1, STREETS_X.size() - 2)]) + side, 0, rng.randf_range(-160.0, 160.0))
		var yaw := (PI * 0.5 if horizontal else 0.0) + rng.randf_range(-0.3, 0.3)
		if _near_flag(p, 18.0) or _on_crossing(p):
			continue
		match rng.randi_range(0, 2):
			0: _hedgehog(p)
			1: _crates(p)
			2: _rubble(p, rng.randf_range(1.0, 1.6), 10, "brick", Color(0.86, 0.78, 0.72))
	# Street lamps, some still burning.
	for s: float in [-165.0, -99.0, -33.0, 33.0, 99.0, 165.0]:
		var z := -160.0
		while z < 165.0:
			_lamp(Vector3(s + STREET_HALF - 0.4, 0, z))
			z += 66.0
	for s: float in [-99.0, -33.0, 33.0, 99.0]:
		var x := -226.0
		while x < 230.0:
			_lamp(Vector3(x, 0, s + STREET_HALF - 0.4))
			x += 66.0
	for i in 30:
		var p := Vector3(rng.randf_range(-226, 226), 0.2, rng.randf_range(-160, 160))
		if _on_street(p.x, p.z) > 0.5:
			smokes.append(p)


## Pavements, kerbs and tram rails, so a wide street still reads as a street. None of it collides.
func _build_pavements() -> void:
	for cz: float in BLOCKS_Z:
		for cx: float in BLOCKS_X:
			for side: Array in [[Vector2(0, 21.6), true], [Vector2(0, -21.6), true], [Vector2(21.6, 0), false], [Vector2(-21.6, 0), false]]:
				var offset: Vector2 = side[0]
				_pavement_side(cx + offset.x, cz + offset.y, side[1])
	for z: float in [-33.0, 33.0]:
		_rails(Vector2(-226, z), Vector2(226, z))
	for x: float in [-33.0, 33.0]:
		_rails(Vector2(x, -160), Vector2(x, 160))
	# Bare trees along the pavements of the two main streets, and burnt cars at the kerbs.
	for z: float in [-58.0, 58.0, -8.0, 8.0]:
		var x := -222.0
		while x < 224.0:
			if not _near_flag(Vector3(x, 0, z), 18.0) and absf(fposmod(x, 66.0) - 33.0) > 9.0 and absf(z) > 50.0:
				_dead_tree(Vector3(x, 0, z))
			x += 21.0
	for spec: Array in [[-62.0, 21.0, 0.3], [-20.0, 45.0, 1.9], [20.0, -45.0, 1.5], [62.0, -21.0, 3.0], [-120.0, 44.0, 0.1], [120.0, -44.0, 2.9], [-44.0, 112.0, 1.4], [44.0, -112.0, 1.7], [-176.0, 22.0, 0.2], [176.0, -22.0, 3.3]]:
		_burnt_car(Vector3(spec[0], 0, spec[1]), spec[2])


func _pavement_side(x: float, z: float, along_x: bool) -> void:
	if b.headless:
		return
	var y := ground_height(x, z)
	var size := Vector3(46.0, 0.14, 3.2) if along_x else Vector3(3.2, 0.14, 40.0)
	b.box(Vector3(x, y + 0.07, z), size, "concrete", Color(0.72, 0.7, 0.66), false)
	var kerb := Vector3(46.0, 0.18, 0.3) if along_x else Vector3(0.3, 0.18, 40.0)
	var outward := Vector3(0, 0, signf(z - round(z / 66.0) * 66.0) * 1.6) if along_x else Vector3(signf(x - round(x / 66.0) * 66.0) * 1.6, 0, 0)
	b.box(Vector3(x, y + 0.09, z) + outward, kerb, "concrete", Color(0.86, 0.84, 0.8), false)


func _rails(a: Vector2, c: Vector2) -> void:
	if b.headless:
		return
	var length := a.distance_to(c)
	var along_x := absf(c.x - a.x) > 1.0
	var pieces := int(length / 14.0)
	for i in pieces:
		var m := a.lerp(c, (i + 0.5) / pieces)
		if _near_flag(Vector3(m.x, 0, m.y), 26.0):
			continue
		for s: float in [-0.72, 0.72]:
			var p := Vector3(m.x, ground_height(m.x, m.y) + 0.03, m.y) + (Vector3(0, 0, s) if along_x else Vector3(s, 0, 0))
			b.box(p, Vector3(length / pieces, 0.07, 0.1) if along_x else Vector3(0.1, 0.07, length / pieces), "metal", Color(0.46, 0.42, 0.4), false)


func _burnt_car(p: Vector3, yaw: float) -> void:
	props.stand("wreck_car", p, yaw)
	b.add_box(Transform3D(Basis(Vector3.UP, yaw), p + Vector3.UP * 0.6), Vector3(1.9, 1.2, 4.4), "", Color.WHITE)
	b.add_footprint(Vector2(p.x, p.z), Vector2(1.9, 4.4), yaw, "cover")


func _on_crossing(p: Vector3) -> bool:
	var on_x := false
	for x: float in STREETS_X:
		on_x = on_x or absf(p.x - x) < STREET_HALF + 1.0
	var on_z := false
	for z: float in STREETS_Z:
		on_z = on_z or absf(p.z - z) < STREET_HALF + 1.0
	return on_x and on_z


## In front of the way into a flag's block, which a tank has to be able to drive through.
func _at_gate(p: Vector3) -> bool:
	for f: Dictionary in FLAG_DEFS:
		var d := Vector2(absf(p.x - f["pos"].x), absf(p.z - f["pos"].z))
		if minf(d.x, d.y) < 9.0 and maxf(d.x, d.y) < 46.0:
			return true
	return false


func _near_flag(p: Vector3, radius: float) -> bool:
	for f: Dictionary in FLAG_DEFS:
		var fp: Vector3 = f["pos"]
		if Vector2(p.x - fp.x, p.z - fp.z).length() < radius:
			return true
	return false
