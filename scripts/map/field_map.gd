class_name FieldMap
extends MapKit
## Pole Bitwy: open fields for tanks. Rolling hills hide whole columns, two broken trench
## lines cross the front, and three flags stand far enough apart that a side must split up.

const BOUND_X := 205.0
const BOUND_Z := 165.0
const TRENCH_HALF := 2.6
const TRENCH_DEPTH := 1.9

const FLAG_DEFS := [
	{"name": "Wzgórze", "letter": "A", "pos": Vector3(-122, 0, -8), "owner": -1},
	{"name": "Folwark", "letter": "B", "pos": Vector3(4, 0, 6), "owner": -1},
	{"name": "Młyn", "letter": "C", "pos": Vector3(126, 0, -16), "owner": -1},
]
const BASES := [Vector3(0, 0, 138), Vector3(0, 0, -138)]
## Hills as x, z, radius, height.
const HILLS := [
	Vector4(-122, -8, 44, 8.5), Vector4(-48, 74, 34, 7.0), Vector4(62, 66, 40, 6.5), Vector4(-52, -70, 38, 7.5),
	Vector4(70, -74, 30, 6.0), Vector4(-168, 70, 36, 6.0), Vector4(164, 62, 34, 5.5), Vector4(166, -84, 36, 7.0),
	Vector4(-160, -92, 32, 6.0), Vector4(58, 8, 20, 3.5), Vector4(-58, 2, 22, 4.0),
]
## Each line is one length of trench. The gaps between them are the tank crossings.
const TRENCHES := [
	[Vector2(-186, 40), Vector2(-160, 28), Vector2(-136, 40), Vector2(-110, 30), Vector2(-92, 42)],
	[Vector2(-66, 38), Vector2(-40, 30), Vector2(-16, 40), Vector2(8, 32)],
	[Vector2(36, 42), Vector2(62, 34), Vector2(88, 44), Vector2(116, 34)],
	[Vector2(142, 40), Vector2(168, 30), Vector2(190, 42)],
	[Vector2(-190, -38), Vector2(-164, -48), Vector2(-140, -36), Vector2(-112, -46)],
	[Vector2(-86, -44), Vector2(-62, -34), Vector2(-36, -44), Vector2(-12, -34)],
	[Vector2(16, -44), Vector2(42, -36), Vector2(66, -46), Vector2(92, -36)],
	[Vector2(118, -44), Vector2(144, -34), Vector2(170, -46), Vector2(192, -36)],
]

var _dug := PackedFloat32Array()


func climate_of() -> Dictionary:
	return {"wet": 0.0, "grime": 0.7}


func weather() -> Dictionary:
	return {"guns": true, "dust": true}


func flag_defs() -> Array:
	return FLAG_DEFS


func bases() -> Array:
	return BASES


## Six parking places per side, one for each tank a side may field.
func tank_depots() -> Array:
	var out := [[], []]
	for x: float in [-35.0, -21.0, -7.0, 7.0, 21.0, 35.0]:
		out[0].append([Vector3(x, 0, 112), 0.0])
		out[1].append([Vector3(x, 0, -112), PI])
	return out


func bound() -> Vector2:
	return Vector2(BOUND_X, BOUND_Z)


func focus() -> Vector3:
	return FLAG_DEFS[1]["pos"]


func coin_area() -> Vector2:
	return Vector2(190.0, 120.0)


func street_rects() -> Array[Rect2]:
	return [Rect2(-4.0, -BOUND_Z, 8.0, BOUND_Z * 2.0), Rect2(-BOUND_X, 2.0, BOUND_X * 2.0, 8.0)]


func hotspots() -> Array[Vector3]:
	return [Vector3(-122, 0, -8), Vector3(4, 0, 6), Vector3(126, 0, -16), Vector3(-60, 0, 24), Vector3(64, 0, -22), Vector3(-30, 0, -24), Vector3(40, 0, 26)]


func team_spawns(team: int) -> Array[Vector3]:
	var side := 1.0 if team == 0 else -1.0
	return [Vector3(-34, 0, 118 * side), Vector3(-12, 0, 116 * side), Vector3(12, 0, 116 * side), Vector3(34, 0, 118 * side)]


func free_spawns() -> Array[Vector3]:
	return hotspots()


func base_height(x: float, z: float) -> float:
	var land := sin(x * 0.018 + 0.6) * cos(z * 0.021 - 0.4) * 1.9 + sin(x * 0.047 - z * 0.036) * 0.7
	for h: Vector4 in HILLS:
		var d := (Vector2(x - h.x, z - h.y)).length_squared() / (h.z * h.z)
		if d < 7.0:
			land += h.w * exp(-d * 1.3)
	# The bases sit on levelled ground, because their camps are built flat.
	var home := minf(Vector2(x, z - BASES[0].z).length(), Vector2(x, z - BASES[1].z).length())
	land *= smoothstep(52.0, 84.0, home)
	return land + _rim(x, z, Vector2(BOUND_X + 8.0, BOUND_Z + 8.0))


func _plan_terrain() -> void:
	for i in 120:
		var p := Vector2(rng.randf_range(-196.0, 196.0), rng.randf_range(-104.0, 104.0))
		_add_crater(p, rng.randf_range(2.2, 6.5))
	# A barrage walked along the road through the farm.
	for i in 16:
		_add_crater(Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-100.0, 100.0)), rng.randf_range(2.0, 3.6))


func _carve_ground(scorch: PackedFloat32Array) -> void:
	var n := _grid_n
	_dug.resize(n * n)
	for line: Array in TRENCHES:
		for i in line.size() - 1:
			_dig(line[i], line[i + 1])
	for i in n * n:
		heights[i] -= _dug[i]
		scorch[i] = maxf(scorch[i], _dug[i] / TRENCH_DEPTH * 0.28)


## Stamps a trench into the grid. Keeps the deepest cut where two lengths meet at a corner.
func _dig(a: Vector2, c: Vector2) -> void:
	var n := _grid_n
	var reach := TRENCH_HALF + 2.0
	var ix0 := int((minf(a.x, c.x) - reach + GROUND_EXTENT) / GROUND_STEP)
	var ix1 := int((maxf(a.x, c.x) + reach + GROUND_EXTENT) / GROUND_STEP) + 1
	var iz0 := int((minf(a.y, c.y) - reach + GROUND_EXTENT) / GROUND_STEP)
	var iz1 := int((maxf(a.y, c.y) + reach + GROUND_EXTENT) / GROUND_STEP) + 1
	var run := c - a
	for iz in range(iz0, iz1 + 1):
		for ix in range(ix0, ix1 + 1):
			var p := Vector2(-GROUND_EXTENT + ix * GROUND_STEP, -GROUND_EXTENT + iz * GROUND_STEP)
			var t := clampf((p - a).dot(run) / run.length_squared(), 0.0, 1.0)
			var d := p.distance_to(a + run * t)
			var cut := (1.0 - smoothstep(TRENCH_HALF - 1.2, TRENCH_HALF + 1.0, d)) * TRENCH_DEPTH
			_dug[iz * n + ix] = maxf(_dug[iz * n + ix], cut)


func _ground_tint(x: float, z: float, scorch: float) -> Color:
	var patch := sin(x * 0.11 + 0.7) * cos(z * 0.09) + sin(x * 0.031 - z * 0.04) * 0.9
	var track := 1.0 - smoothstep(3.0, 7.0, minf(absf(x), absf(z - 6.0)))
	var i := int((z + GROUND_EXTENT) / GROUND_STEP) * _grid_n + int((x + GROUND_EXTENT) / GROUND_STEP)
	var bare := _dug[i] / TRENCH_DEPTH if i >= 0 and i < _dug.size() else 0.0
	var grass := clampf(0.82 + patch * 0.32 - track * 0.8 - bare, 0.0, 1.0)
	var farm := 1.0 - smoothstep(20.0, 26.0, Vector2(x - 4.0, z - 6.0).length())
	return Color(farm * 0.55, grass, scorch, 1.0)


func _build_scenery() -> void:
	_build_trenches()
	_site_hill()
	_site_farm()
	_site_mill()
	_build_no_mans_land()
	b.floor_y = 0.0
	_camp_resistance(BASES[0])
	_camp_empire(BASES[1])


func _build_trenches() -> void:
	for line: Array in TRENCHES:
		for i in line.size() - 1:
			_trench_run(line[i], line[i + 1], i % 2 == 0)


## Timber walls and duckboards down the length of a trench, in pieces short enough to follow
## the ground. Tanks are kept out of it, or a bot's route would end nose-down in the mud.
func _trench_run(a: Vector2, c: Vector2, parapet: bool) -> void:
	var run := c - a
	var length := run.length()
	var dir := run / length
	var yaw := atan2(-dir.y, dir.x)
	var side := Vector2(-dir.y, dir.x)
	var mid := (a + c) * 0.5
	b.nav_tank.block_obb(Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, 0, mid.y)), length * 0.5 + 1.0, TRENCH_HALF, 1.6)
	b.add_footprint(mid, Vector2(length, TRENCH_HALF * 1.6), yaw, "wire")
	var pieces := int(length / 5.0)
	var wood := Color(0.56, 0.46, 0.36)
	for i in pieces:
		var at := a + dir * (length * (i + 0.5) / pieces)
		var y := ground_height(at.x, at.y)
		var piece := length / pieces
		b.box(Vector3(at.x, y + 0.05, at.y), Vector3(piece * 0.95, 0.08, 1.3), "wood", wood.darkened(0.2), false, yaw)
		for s: float in [-1.0, 1.0]:
			var w := at + side * s * 1.55
			b.box(Vector3(w.x, y + 0.75, w.y), Vector3(piece, 1.5, 0.14), "wood", wood, false, yaw)
			b.box(Vector3(w.x, y + 0.75, w.y) + Vector3(dir.x, 0, dir.y) * piece * 0.5, Vector3(0.18, 1.8, 0.18), "wood", wood.darkened(0.3), false)
		if parapet and i % 2 == 1:
			var lip := at + side * (TRENCH_HALF + 1.4) * (1.0 if a.y > 0.0 else -1.0)
			var from := _ground(lip.x - dir.x * 2.2, lip.y - dir.y * 2.2)
			_sandbags(from, from + Vector3(dir.x, 0, dir.y) * 4.4, 3)


func _site_hill() -> void:
	var c: Vector3 = FLAG_DEFS[0]["pos"]
	_bunker(_ground(c.x - 20, c.z - 15), 0.5)
	_bunker(_ground(c.x + 21, c.z + 13), PI + 0.4)
	for spec: Array in [[-13.0, 18.0, 3.0, 22.0], [8.0, -22.0, 20.0, -16.0], [-30.0, 2.0, -26.0, 14.0]]:
		_sandbags(_ground(c.x + spec[0], c.z + spec[1]), Vector3(c.x + spec[2], 0, c.z + spec[3]))
	_tank_wreck(_ground(c.x + 2, c.z - 30), 1.1)
	smokes.append(_ground(c.x + 2, c.z - 30) + Vector3.UP * 1.5)
	_tank_wreck(_ground(c.x + 34, c.z - 8), 2.4)
	for i in 6:
		var ang := TAU * i / 6.0 + 0.4
		_dead_tree(_ground(c.x + cos(ang) * 34.0, c.z + sin(ang) * 30.0))


func _site_farm() -> void:
	var c: Vector3 = FLAG_DEFS[1]["pos"]
	_building(_ground(c.x - 25, c.z - 18), 15.0, 9.0, 2, 0.2, 0.55)
	_building(_ground(c.x + 26, c.z - 15), 12.0, 8.0, 2, -0.15, 0.7)
	_building(_ground(c.x + 24, c.z + 20), 16.0, 9.0, 1, 0.1, 0.45)
	_building(_ground(c.x - 27, c.z + 18), 11.0, 8.0, 2, -0.3, 0.8)
	for spec: Array in [[-30.0, -2.0, -30.0, 8.0], [30.0, 0.0, 30.0, 8.0], [-8.0, -25.0, 8.0, -26.0], [-6.0, 26.0, 10.0, 25.0]]:
		_farm_wall(_ground(c.x + spec[0], c.z + spec[1]), Vector3(c.x + spec[2], 0, c.z + spec[3]))
	_truck(_ground(c.x + 11, c.z - 9), 0.7)
	_crates(_ground(c.x - 12, c.z + 8))
	_crates(_ground(c.x + 7, c.z + 12))
	_rubble(_ground(c.x - 14, c.z - 8), 2.6, 16, "brick", Color(0.84, 0.76, 0.7))
	_tank_wreck(_ground(c.x - 40, c.z - 4), 1.5)
	fires.append(_ground(c.x - 40, c.z - 4) + Vector3.UP * 1.4)
	for spec: Array in [[14.0, 32.0], [-16.0, -34.0], [38.0, -30.0], [-38.0, 30.0]]:
		_dead_tree(_ground(c.x + spec[0], c.z + spec[1]))


## A dry-stone field wall: low enough to shoot over, and a tank has to go round it.
func _farm_wall(a: Vector3, c: Vector3) -> void:
	var mid := Vector3((a.x + c.x) * 0.5, a.y + 0.55, (a.z + c.z) * 0.5)
	var run := Vector2(c.x - a.x, c.z - a.z)
	b.box(mid, Vector3(run.length(), 1.1, 0.7), "concrete", Color(0.66, 0.63, 0.58), true, atan2(-run.y, run.x))
	b.add_footprint(Vector2(mid.x, mid.z), Vector2(run.length(), 0.7), atan2(-run.y, run.x), "cover")


func _site_mill() -> void:
	var c: Vector3 = FLAG_DEFS[2]["pos"]
	_windmill(_ground(c.x + 21, c.z - 15))
	_building(_ground(c.x - 21, c.z + 15), 13.0, 8.0, 2, 0.5, 0.6)
	for spec: Array in [[-16.0, -18.0, -4.0, -24.0], [12.0, 22.0, 26.0, 18.0]]:
		_sandbags(_ground(c.x + spec[0], c.z + spec[1]), Vector3(c.x + spec[2], 0, c.z + spec[3]))
	_tank_wreck(_ground(c.x - 8, c.z + 32), 0.5)
	smokes.append(_ground(c.x - 8, c.z + 32) + Vector3.UP * 1.5)
	_truck(_ground(c.x + 30, c.z + 8), 2.2)
	for i in 5:
		var ang := TAU * i / 5.0 + 1.1
		_hedgehog(_ground(c.x + cos(ang) * 30.0, c.z + sin(ang) * 26.0))


func _windmill(p: Vector3) -> void:
	var tint := Color(0.72, 0.68, 0.6)
	b.add_prism(p, 4.6, 13.0, 10, "brick", tint, 3.1)
	b.add_prism(p + Vector3.UP * 13.0, 3.4, 2.4, 10, "roof", Color(0.4, 0.38, 0.36), 1.0)
	var hub := p + Vector3(0, 12.6, 3.6)
	for ang: float in [0.5, 2.1, 3.7, 5.2]:
		var dir := Vector3(cos(ang), sin(ang), 0.0)
		var blade := Basis(Quaternion(Vector3.UP, dir))
		b.add_box(Transform3D(blade, hub + dir * 4.6), Vector3(0.16, 9.2, 0.16), "wood", Color(0.5, 0.42, 0.34), false)
		b.add_box(Transform3D(blade, hub + dir * 5.6 + Vector3(dir.y, -dir.x, 0) * 0.7), Vector3(1.3, 6.2, 0.05), "wood", Color(0.62, 0.54, 0.44), false)
	b.add_footprint(Vector2(p.x, p.z), Vector2(9.2, 9.2), 0.0, "landmark")


func _build_no_mans_land() -> void:
	for i in 12:
		var x := rng.randf_range(-190.0, 190.0)
		var z := rng.randf_range(-100.0, 100.0)
		if _clear_of_sites(x, z):
			_tank_wreck(_ground(x, z), rng.randf() * TAU)
			if i % 3 == 0:
				smokes.append(_ground(x, z) + Vector3.UP * 1.5)
	for i in 26:
		var x := rng.randf_range(-196.0, 196.0)
		var z := rng.randf_range(-120.0, 120.0)
		if _clear_of_sites(x, z):
			_dead_tree(_ground(x, z))
	# Dragon's teeth and wire narrow the crossings without closing them.
	for line: Array in TRENCHES:
		var end: Vector2 = line[line.size() - 1]
		for k in 3:
			_hedgehog(_ground(end.x + 7.0 + k * 3.5, end.y + (k - 1) * 4.0))
		var start: Vector2 = line[0]
		var wire_a := _ground(start.x, start.y + (9.0 if start.y > 0.0 else -9.0))
		_wire(wire_a, Vector3(start.x + 18.0, 0, wire_a.z + 2.0))
	for z: float in [-96.0, -80.0, -64.0, 64.0, 80.0, 96.0]:
		_telegraph_pole(_ground(9.0, z))


func _clear_of_sites(x: float, z: float) -> bool:
	for f: Dictionary in FLAG_DEFS:
		var p: Vector3 = f["pos"]
		if Vector2(x - p.x, z - p.z).length() < 34.0:
			return false
	return absf(x) > 12.0 and absf(z - 6.0) > 9.0


func _telegraph_pole(p: Vector3) -> void:
	var wood := Color(0.34, 0.28, 0.24)
	var lean := rng.randf_range(-0.12, 0.12)
	var basis := Basis(Vector3.BACK, lean)
	b.add_box(Transform3D(basis, p + Vector3(0, 3.6, 0)), Vector3(0.2, 7.2, 0.2), "wood", wood, true, false)
	b.add_box(Transform3D(basis, p + Vector3(-sin(lean) * 3.0, 6.6, 0)), Vector3(1.6, 0.12, 0.12), "wood", wood, false)
