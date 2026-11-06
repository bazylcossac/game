class_name TrenchMap
extends MapKit
## Ziemia Niczyja: 720 x 600 m of mud under a storm. Each side holds a fire trench and a support
## trench joined by communication trenches, with belts of wire in front and a ruined village in the
## middle. Trenches are dug into the terrain itself, so soldiers walk down into them, and four gaps
## in every line let tanks through. The map is point symmetric: (x, z) mirrors (-x, -z).

const HALF := Vector2(360, 300)
const EXTENT := 405.0
const STEP := 1.5
const TILE := 30
## How deep a trench is, and how much the firing step raises its front edge.
const DEPTH := 1.8
const FIRE_STEP := 0.8
const FIRE_LINE := 114.0
const SUPPORT_LINE := 171.0
const BASE_Z := 246.0
const CLOSE_Z := 141.0
const WIRE_ROWS := [66.0, 88.0]
## Tanks cross the lines here. Each gap is left undug.
const CROSSINGS := [-204.0, -63.0, 63.0, 204.0]
const CROSSING_HALF := 10.5
const COMMS := [-282.0, -135.0, 0.0, 135.0, 282.0]
const BAY := 18.0

var close_start := false
var tank_war := false
## Every stretch of trench as [from, to, which way is the enemy along z, or 0 for a side trench].
var _runs: Array[Array] = []
var _dug := PackedFloat32Array()
var _lanterns: Array[Vector3] = []
var _pools: Array[Vector3] = []


func _init(mode_id := "") -> void:
	close_start = mode_id in ["pvp", "deathmatch"]
	tank_war = mode_id == "czolgi"


func ground_extent() -> float:
	return EXTENT


func ground_step() -> float:
	return STEP


func ground_tile() -> int:
	return TILE


func bound() -> Vector2:
	return HALF


func view_range() -> float:
	return 340.0


func coin_area() -> Vector2:
	return Vector2(320, 90)


func climate_of() -> Dictionary:
	return {"wet": 1.0, "grime": 0.85, "mud": true}


func weather() -> Dictionary:
	return {"lightning": [5.0, 15.0], "flares": true, "guns": true, "rain": true, "flash_ambient": 2.4, "flash_sun": 3.0}


func bases() -> Array:
	var z := CLOSE_Z if close_start else BASE_Z
	return [Vector3(9, 0, z), Vector3(-9, 0, -z)]


func team_spawns(team: int) -> Array[Vector3]:
	var s := 1.0 if team == 0 else -1.0
	var z := CLOSE_Z if close_start else BASE_Z + 8.0
	var out: Array[Vector3] = []
	for x: float in [-66.0, -50.0, 50.0, 66.0]:
		out.append(Vector3(x * s, 0, z * s))
	return out


func free_spawns() -> Array[Vector3]:
	var out: Array[Vector3] = team_spawns(0)
	out.append_array(team_spawns(1))
	out.append_array(hotspots())
	return out


func flag_defs() -> Array:
	if tank_war:
		return [
			{"name": "Las", "letter": "A", "pos": Vector3(228, 0, 30), "owner": -1},
			{"name": "Kościół", "letter": "B", "pos": Vector3(0, 0, 0), "owner": -1},
			{"name": "Bateria", "letter": "C", "pos": Vector3(-228, 0, -30), "owner": -1},
		]
	return [
		{"name": "Reduta", "letter": "A", "pos": Vector3(-252, 0, 96), "owner": 0},
		{"name": "Las", "letter": "B", "pos": Vector3(228, 0, 30), "owner": -1},
		{"name": "Kościół", "letter": "C", "pos": Vector3(0, 0, 0), "owner": -1},
		{"name": "Bateria", "letter": "D", "pos": Vector3(-228, 0, -30), "owner": -1},
		{"name": "Kopalnia", "letter": "E", "pos": Vector3(252, 0, -96), "owner": 1},
	]


func tank_depots() -> Array:
	var out := [[], []]
	var columns := [-48.0, -30.0, -12.0, 12.0, 30.0, 48.0] if tank_war else [-30.0, -12.0, 12.0, 30.0]
	for x: float in columns:
		out[0].append([Vector3(x, 0, 224), 0.0])
		out[1].append([Vector3(-x, 0, -224), PI])
	return out


func hotspots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f: Dictionary in flag_defs():
		out.append(f["pos"])
	out.append_array([Vector3(-110, 0, 40), Vector3(110, 0, -40), Vector3(120, 0, 62), Vector3(-120, 0, -62), Vector3(63, 0, 20), Vector3(-63, 0, -20)])
	return out


func street_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for x: float in CROSSINGS:
		out.append(Rect2(x - CROSSING_HALF, -240, CROSSING_HALF * 2.0, 480))
	return out


func base_height(x: float, z: float) -> float:
	var land := sin(x * 0.013 + 0.6) * cos(z * 0.017 - 0.4) * 1.5 + sin(x * 0.037 - z * 0.029) * 0.5
	# Two long swells across no man's land give a little dead ground to crawl in.
	land += exp(-pow((z - 40.0) / 24.0, 2.0)) * 1.3 + exp(-pow((z + 40.0) / 24.0, 2.0)) * 1.3
	var home := minf(Vector2(x, z - BASE_Z).length(), Vector2(x, z + BASE_Z).length())
	land *= smoothstep(30.0, 80.0, home)
	return land + _rim(x, z, HALF + Vector2(14, 14))


func far_height(x: float, z: float) -> float:
	return base_height(x, z) + sin(x * 0.0047) * cos(z * 0.0053) * 12.0 * smoothstep(420.0, 900.0, Vector2(x, z).length())


func _plan_terrain() -> void:
	_plan_runs()
	# A long bombardment: the ground between the lines is more shell hole than field.
	for i in 340:
		var p := Vector2(_grid(rng.randf_range(-340, 340)), rng.randf_range(-100, 100))
		var r := rng.randf_range(1.8, 5.8)
		_shell_hole(p, r)
		_shell_hole(-p, r)
	for i in 90:
		var p := Vector2(rng.randf_range(-340, 340), rng.randf_range(100, 230))
		var r := rng.randf_range(1.6, 3.6)
		_shell_hole(p, r)
		_shell_hole(-p, r)


func _shell_hole(p: Vector2, r: float) -> void:
	if not _on_trench(p, r + 4.0):
		_add_crater(p, r)
		if r > 3.4:
			_pools.append(Vector3(p.x, p.y, r))


func _grid(v: float) -> float:
	return round(v / STEP) * STEP


func _plan_runs() -> void:
	for line: float in [FIRE_LINE, SUPPORT_LINE]:
		_crenellated(line)
	for x: float in COMMS:
		var a := Vector2(_grid(x), FIRE_LINE)
		var turn := 15.0
		var mid1 := FIRE_LINE + 19.5
		var mid2 := FIRE_LINE + 37.5
		_add_run(a, Vector2(a.x, mid1), 0.0)
		_add_run(Vector2(a.x, mid1), Vector2(a.x + turn, mid1), 0.0)
		_add_run(Vector2(a.x + turn, mid1), Vector2(a.x + turn, mid2), 0.0)
		_add_run(Vector2(a.x + turn, mid2), Vector2(a.x, mid2), 0.0)
		_add_run(Vector2(a.x, mid2), Vector2(a.x, SUPPORT_LINE), 0.0)


## Bays with a traverse between them, so a shell or a bullet cannot run the length of the line.
func _crenellated(z0: float) -> void:
	var x := -333.0
	var back := false
	while x < 333.0:
		var to := x + BAY
		var blocked := false
		for crossing: float in CROSSINGS:
			if x < crossing + CROSSING_HALF and to > crossing - CROSSING_HALF:
				blocked = true
		if blocked:
			x = to
			continue
		var z := z0 + (6.0 if back else 0.0)
		_add_run(Vector2(x, z), Vector2(to, z), -1.0)
		var turn := z0 + (0.0 if back else 6.0)
		var next_blocked := false
		for crossing: float in CROSSINGS:
			if to < crossing + CROSSING_HALF and to + BAY > crossing - CROSSING_HALF:
				next_blocked = true
		if not next_blocked and to + BAY < 340.0:
			_add_run(Vector2(to, z), Vector2(to, turn), 0.0)
		back = not back
		x = to


## Adds a stretch and its mirror image on the other side of the map.
func _add_run(a: Vector2, c: Vector2, front: float) -> void:
	_runs.append([a, c, front])
	_runs.append([-a, -c, -front])


func _on_trench(p: Vector2, margin: float) -> bool:
	for run: Array in _runs:
		var a: Vector2 = run[0]
		var c: Vector2 = run[1]
		var lo := Vector2(minf(a.x, c.x), minf(a.y, c.y)) - Vector2(margin, margin)
		var hi := Vector2(maxf(a.x, c.x), maxf(a.y, c.y)) + Vector2(margin, margin)
		if p.x > lo.x and p.x < hi.x and p.y > lo.y and p.y < hi.y:
			return true
	return false


## The cut is square in plan: flat floor, then a bank up to the surface one grid cell away.
func _carve_ground(scorch: PackedFloat32Array) -> void:
	var n := _grid_n
	_dug.resize(n * n)
	for run: Array in _runs:
		_dig(run[0], run[1], run[2])
	for i in n * n:
		heights[i] -= _dug[i]
		scorch[i] = maxf(scorch[i], _dug[i] / DEPTH * 0.32)


func _dig(a: Vector2, c: Vector2, front: float) -> void:
	var n := _grid_n
	var reach := STEP * 2.0
	var ix0 := int((minf(a.x, c.x) - reach + EXTENT) / STEP)
	var ix1 := int((maxf(a.x, c.x) + reach + EXTENT) / STEP)
	var iz0 := int((minf(a.y, c.y) - reach + EXTENT) / STEP)
	var iz1 := int((maxf(a.y, c.y) + reach + EXTENT) / STEP)
	var across_z := absf(a.x - c.x) > absf(a.y - c.y)
	for iz in range(iz0, iz1 + 1):
		for ix in range(ix0, ix1 + 1):
			var p := Vector2(-EXTENT + ix * STEP, -EXTENT + iz * STEP)
			var dx := maxf(maxf(minf(a.x, c.x) - p.x, p.x - maxf(a.x, c.x)), 0.0)
			var dz := maxf(maxf(minf(a.y, c.y) - p.y, p.y - maxf(a.y, c.y)), 0.0)
			var d := maxf(dx, dz)
			if d >= reach - 0.01:
				continue
			var cut := DEPTH if d <= STEP + 0.01 else 0.0
			# The side facing the enemy has a raised step to stand on and shoot from.
			if front != 0.0 and across_z and (p.y - a.y) * _enemy_side(a.y) > 0.5 and d <= STEP + 0.01:
				cut = DEPTH - FIRE_STEP
			_dug[iz * n + ix] = maxf(_dug[iz * n + ix], cut)


func _enemy_side(z: float) -> float:
	return -signf(z)


func _ground_tint(x: float, z: float, scorch: float) -> Color:
	var patch := sin(x * 0.11 + 0.7) * cos(z * 0.09) + sin(x * 0.031 - z * 0.04) * 0.9
	var rear := smoothstep(120.0, 200.0, absf(z))
	var i := int(round((z + EXTENT) / STEP)) * _grid_n + int(round((x + EXTENT) / STEP))
	var dug := _dug[i] / DEPTH if i >= 0 and i < _dug.size() else 0.0
	var grass := clampf((0.2 + rear * 0.55 + patch * 0.22) - dug * 2.0 - scorch * 1.2, 0.0, 1.0)
	return Color(0.0, grass, scorch * 0.55, 1.0)


func _build_scenery() -> void:
	for run: Array in _runs:
		_furnish_run(run[0], run[1], run[2])
	_wire_belts()
	_village()
	_redoubts()
	_wood_and_battery()
	_camp(1.0)
	_camp(-1.0)
	_no_mans_land()


func _roll(x: float, z: float, salt := 0.0) -> float:
	var v := sin(x * 12.9898 + z * 78.233 + salt * 37.719) * 43758.5453
	return v - floor(v)


func _floor_at(p: Vector2) -> Vector3:
	return Vector3(p.x, ground_height(p.x, p.y), p.y)


## Boards underfoot, timber against the banks and sandbags along the top.
func _furnish_run(a: Vector2, c: Vector2, front: float) -> void:
	var run := c - a
	var length := run.length()
	if length < 0.5:
		return
	var dir := run / length
	var yaw := atan2(-dir.y, dir.x)
	var side := Vector2(-dir.y, dir.x)
	var mid := (a + c) * 0.5
	var along := Basis(Vector3.UP, yaw)
	var xf := Transform3D(along, Vector3(mid.x, 0, mid.y))
	b.nav_tank.block_obb(xf, length * 0.5 + 3.0, 3.0, 1.9)
	b.nav_wide.block_obb(xf, length * 0.5 + 3.0, 3.0, 1.0)
	b.add_footprint(mid, Vector2(length + 3.0, 3.0), yaw, "wire")
	var t := 1.0
	while t < length:
		var p := a + dir * t
		if _roll(p.x, p.y, 1.0) > 0.16:
			props.stand("duckboard", _floor_at(p) + Vector3.UP * 0.03, yaw + PI * 0.5 + (_roll(p.y, p.x, 2.0) - 0.5) * 0.12)
		t += 2.0
	t = 1.5
	var bay := absf(dir.x) > 0.5
	while t < length:
		var p := a + dir * t
		for s: float in [-1.0, 1.0]:
			if _roll(p.x + s, p.y, 3.0) < 0.14:
				continue
			_bank(p + side * s * STEP, yaw, s, bay and signf(side.y * s) == _enemy_side(a.y))
		t += 3.0
	if front == 0.0 or not bay:
		return
	# The parapet runs along the enemy side, in lengths with gaps to climb out through.
	var enemy := _enemy_side(a.y)
	t = 1.5
	while t < length:
		var p := a + dir * t + Vector2(0, enemy * (STEP * 2.0 + 0.7))
		if _roll(p.x, p.y, 4.0) > 0.28:
			var at := _floor_at(p)
			# Sunk halfway, so a man on the firing step can see and shoot over the top.
			props.stand("sandbag_wall", at - Vector3.UP * 0.34, yaw)
			b.floor_y = at.y
			b.box(at + Vector3.UP * 0.19, Vector3(3.0, 0.38, 0.8), "", Color.WHITE, true, yaw)
			b.floor_y = 0.0
		t += 3.0
	if _roll(a.x, a.y, 5.0) < 0.22:
		_lanterns.append(_floor_at(mid - Vector2(0, enemy * 1.2)))


## A panel of planks laid against the slope. `step` banks rise from the firing step, so are lower.
func _bank(foot: Vector2, yaw: float, s: float, step: bool) -> void:
	var rise := DEPTH - FIRE_STEP if step else DEPTH
	var lean := atan2(STEP, rise)
	# The model's posts stand on its +Z face, which has to look into the trench.
	var basis := Basis(Vector3.UP, yaw + (PI if s > 0.0 else 0.0)) * Basis(Vector3.RIGHT, -lean)
	basis = basis.scaled_local(Vector3(1.0, sqrt(rise * rise + STEP * STEP) / 2.1, 1.0))
	props.place("revetment", Transform3D(basis, _floor_at(foot) + Vector3.UP * 0.03))


func _wire_belts() -> void:
	for row: float in WIRE_ROWS:
		var x := -344.0
		while x < 344.0:
			var open := false
			for crossing: float in CROSSINGS:
				open = open or absf(x - crossing) < CROSSING_HALF + 3.0
			# Patrols cut lanes through the belt, so infantry can get across too.
			open = open or fposmod(x + row, 44.0) < 8.0
			if not open:
				var zig := sin(x * 0.11) * 3.0
				_coil(Vector2(x, row + zig))
				_coil(Vector2(-x, -row - zig))
			x += 4.0


func _coil(p: Vector2) -> void:
	var at := _floor_at(p)
	var yaw := (_roll(p.x, p.y, 6.0) - 0.5) * 0.16
	props.stand("wire_coil", at, yaw)
	b.floor_y = at.y
	b.box(at + Vector3.UP * 0.6, Vector3(4.0, 1.2, 1.2), "", Color.WHITE, true, yaw)
	b.floor_y = 0.0
	b.add_footprint(p, Vector2(4.0, 1.2), yaw, "wire")


## The church and the houses round it, more rubble than walls by now.
func _village() -> void:
	for s: float in [1.0, -1.0]:
		_building(_ground(s * 4.0, s * -30.0), 30.0, 13.0, 2, 0.0, 0.72)
		_building(_ground(s * 34.0, s * 18.0), 14.0, 9.0, 2, 0.3, 0.8)
		_building(_ground(s * 40.0, s * -16.0), 12.0, 9.0, 1, -0.2, 0.74)
		_building(_ground(s * -30.0, s * 34.0), 13.0, 9.0, 2, 0.1, 0.84)
		_rubble(_ground(s * 18.0, s * 8.0), 3.0, 18, "brick", Color(0.6, 0.54, 0.5))
		_rubble(_ground(s * -18.0, s * 16.0), 2.6, 14, "concrete", Color(0.6, 0.6, 0.58))
		props.stand("sandbag_wall", _ground(s * 10.0, s * 16.0), 0.1)
		_low_wall(_ground(s * 10.0, s * 16.0), 3.0, 0.1)
		props.stand("sandbag_wall", _ground(s * -12.0, s * 14.0), -0.3)
		_low_wall(_ground(s * -12.0, s * 14.0), 3.0, -0.3)
		_tank_wreck(_ground(s * 58.0, s * 8.0), 0.8)
	b.floor_y = 0.0
	# What is left of the tower: four stumps of wall and a heap at the foot.
	var tower := _ground(0, -34)
	b.box(tower + Vector3(0, 9, 0), Vector3(6.5, 18, 6.5), "brick", Color(0.56, 0.5, 0.46))
	b.add_footprint(Vector2(tower.x, tower.z), Vector2(6.5, 6.5), 0.0, "landmark")
	b.add_prism(tower + Vector3.UP * 18.0, 4.0, 3.5, 4, "brick", Color(0.5, 0.46, 0.42), 1.2)


## Soot and rain have taken the colour out of every wall here.
func _pick_facade() -> Dictionary:
	var dark := [Color(0.34, 0.3, 0.29), Color(0.28, 0.26, 0.26), Color(0.4, 0.34, 0.31)]
	return {"mat": "brick", "tint": dark[rng.randi() % dark.size()]}


func _low_wall(at: Vector3, length: float, yaw: float) -> void:
	b.box(at + Vector3.UP * 0.36, Vector3(length, 0.72, 0.8), "", Color.WHITE, true, yaw)
	b.add_footprint(Vector2(at.x, at.z), Vector2(length, 0.8), yaw, "cover")


## Strongpoints by the end flags: a ring of bags and a shelter dug into the bank.
func _redoubts() -> void:
	for s: float in [1.0, -1.0]:
		var c := Vector2(-252.0 * s, 96.0 * s)
		for i in 8:
			var a := TAU * i / 8.0 + 0.3
			if i % 4 == 2:
				continue
			var p := c + Vector2(cos(a), sin(a)) * 14.0
			var at := _floor_at(p)
			props.stand("sandbag_wall", at, -a + PI * 0.5)
			b.floor_y = at.y
			_low_wall(at, 3.0, -a + PI * 0.5)
			b.floor_y = 0.0
		props.stand("field_gun", _floor_at(c + Vector2(4, -3) * s), 0.0 if s > 0.0 else PI)
		for i in 3:
			props.stand("ammo_crate", _floor_at(c + Vector2(-5 + i * 1.3, 3) * s), 0.4 * i)


## The wood is stumps now, and a battery that never left its pits.
func _wood_and_battery() -> void:
	for s: float in [1.0, -1.0]:
		var c := Vector2(228.0 * s, 30.0 * s)
		for i in 46:
			var a := i * 2.39996
			var r := sqrt((i + 0.5) / 46.0) * 44.0
			var p := c + Vector2(cos(a), sin(a)) * r
			if Vector2(p - c).length() < 7.0 or _on_trench(p, 3.0):
				continue
			var kind := int(_roll(p.x, p.y, 7.0) * 3.0)
			var at := _floor_at(p)
			props.stand(["stump_a", "stump_b", "dead_tree_a"][kind], at, _roll(p.y, p.x, 8.0) * TAU)
			b.floor_y = at.y
			b.box(at + Vector3.UP * 1.2, Vector3(0.9, 2.4, 0.9), "", Color.WHITE)
			b.floor_y = 0.0
			b.add_footprint(p, Vector2(0.9, 0.9), 0.0, "cover")
		for i in 3:
			var gun := c + Vector2(-16.0 + i * 16.0, 14.0 * (1.0 if i % 2 == 0 else -1.0)) * s
			if _on_trench(gun, 4.0):
				continue
			var at := _floor_at(gun)
			props.stand("field_gun", at, (0.3 * i) + (PI if s > 0.0 else 0.0))
			b.floor_y = at.y
			b.box(at + Vector3.UP * 0.9, Vector3(2.2, 1.8, 3.6), "", Color.WHITE)
			b.floor_y = 0.0
			b.add_footprint(gun, Vector2(2.2, 3.6), 0.0, "cover")
			for j in 3:
				props.stand("sandbag_wall", _floor_at(gun + Vector2(cos(j * 2.1), sin(j * 2.1)) * 5.0), j * 2.1)


func _camp(s: float) -> void:
	var c := Vector3(0, 0, s * BASE_Z)
	if s > 0.0:
		_camp_resistance(c)
	else:
		_camp_empire(c)
	for x: float in [-132.0, -96.0, 96.0, 132.0]:
		var at := _floor_at(Vector2(x, s * (SUPPORT_LINE + 9.0)))
		props.stand("dugout", at, 0.0 if s > 0.0 else PI)
		for i in 3:
			props.stand("ammo_crate", at + Vector3(2.4 + i * 0.3, 0, i * 0.7), i * 0.6)


func _no_mans_land() -> void:
	var picks := [[-150.0, 18.0, 0.6], [150.0, -30.0, 2.2], [-76.0, 52.0, 1.4], [92.0, 44.0, 3.0], [-300.0, 34.0, 0.2], [290.0, -12.0, 1.0]]
	for spec: Array in picks:
		var at := _ground(spec[0], spec[1])
		_tank_wreck(at, spec[2])
		_tank_wreck(_ground(-spec[0], -spec[1]), spec[2] + PI)
		smokes.append(at + Vector3.UP * 1.5)
	for i in 70:
		var p := Vector2(rng.randf_range(-340, 340), rng.randf_range(-96, 96))
		if _on_trench(p, 2.0) or absf(p.x) < 60.0 and absf(p.y) < 44.0:
			continue
		var at := _floor_at(p)
		var kind := int(_roll(p.x, p.y, 9.0) * 4.0)
		if kind == 0:
			props.stand("ammo_crate", at, _roll(p.y, p.x, 10.0) * TAU)
		elif kind == 1:
			props.stand("stump_b", at, _roll(p.y, p.x, 11.0) * TAU)
			b.floor_y = at.y
			b.box(at + Vector3.UP * 0.7, Vector3(0.9, 1.4, 0.9), "", Color.WHITE)
			b.floor_y = 0.0
		elif kind == 2:
			props.stand("sandbag_wall", at, _roll(p.y, p.x, 12.0) * TAU)
			b.floor_y = at.y
			_low_wall(at, 3.0, _roll(p.y, p.x, 12.0) * TAU)
			b.floor_y = 0.0
	# Listening posts: a horseshoe of bags thrown up at night, every forty metres or so.
	var x := -324.0
	while x <= 324.0:
		for row: float in [14.0, 44.0, 74.0]:
			var p := Vector2(x + (_roll(x, row, 13.0) - 0.5) * 22.0, row + (_roll(row, x, 14.0) - 0.5) * 18.0)
			var open := absf(p.x) < 52.0 and absf(p.y) < 40.0
			for crossing: float in CROSSINGS:
				open = open or absf(absf(p.x) - absf(crossing)) < CROSSING_HALF + 3.0
			if not open and not _on_trench(p, 5.0):
				_listening_post(p, 1.0)
				_listening_post(-p, -1.0)
		x += 40.5
	for z: float in [-220.0, -200.0, 200.0, 220.0]:
		for x2: float in [-160.0, 160.0]:
			props.stand("dead_tree_b", _floor_at(Vector2(x2, z)), z)


## Two courses of bags, chest high, with the open end towards home.
func _listening_post(p: Vector2, s: float) -> void:
	for i in 3:
		var a := PI * (0.5 + (i - 1) * 0.42) * -s
		var at := _floor_at(p + Vector2(cos(a), sin(a)) * 3.2)
		var yaw := -a + PI * 0.5
		props.stand("sandbag_wall", at - Vector3.UP * 0.04, yaw)
		props.stand("sandbag_wall", at + Vector3.UP * 0.5, yaw + 0.03)
		b.floor_y = at.y
		b.box(at + Vector3.UP * 0.6, Vector3(3.0, 1.2, 0.8), "", Color.WHITE, true, yaw)
		b.floor_y = 0.0
		b.add_footprint(Vector2(at.x, at.z), Vector2(3.0, 0.8), yaw, "cover")


func build(parent: Node3D, map_seed: int, headless: bool) -> void:
	# Two metre cells reach 480 m, more than this map's 360.
	b.nav = NavGrid.new(2.0)
	b.nav_wide = NavGrid.new(2.0)
	b.nav_tank = NavGrid.new(2.0)
	super.build(parent, map_seed, headless)
	if headless:
		return
	_build_pools(parent)
	for at: Vector3 in _lanterns.slice(0, 26):
		props_lantern(parent, at)


## Water standing in the bigger shell holes. Rain rings run across it.
func _build_pools(parent: Node3D) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/puddle.gdshader")
	mat.set_shader_parameter("macro_tex", Mats.tex("macro_noise"))
	mesh.material = mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = _pools.size()
	for i in _pools.size():
		var p := _pools[i]
		var r := p.z * 0.74
		var y := ground_height(p.x, p.y) + p.z * 0.11
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r, 1, r)), Vector3(p.x, y, p.y)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


func props_lantern(parent: Node3D, at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.34)
	light.light_energy = 1.6
	light.omni_range = 8.0
	parent.add_child(light)
	light.position = at + Vector3(0.28, 1.5, 0)
	var post := MeshInstance3D.new()
	post.mesh = CityProps.mesh_for("lantern")
	parent.add_child(post)
	post.position = at


## Far off there is only what the shelling left: broken gables, chimneys and burning villages.
func _build_skyline() -> void:
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf_range(-0.14, 0.14)
		var r := rng.randf_range(540.0, 840.0)
		var c := Vector2(cos(a) * r, sin(a) * r)
		for j in rng.randi_range(4, 8):
			var p := c + Vector2(rng.randf_range(-46, 46), rng.randf_range(-30, 30))
			var w := rng.randf_range(2.0, 9.0)
			var h := rng.randf_range(4.0, 17.0)
			b.box(Vector3(p.x, far_height(p.x, p.y) + h * 0.5 - 1.0, p.y), Vector3(w, h, w * 0.3), "brick", Color(0.2, 0.19, 0.2), false, rng.randf() * TAU)
		if i % 3 == 0:
			smokes.append(Vector3(c.x, far_height(c.x, c.y) + 3.0, c.y))
