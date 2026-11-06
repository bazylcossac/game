class_name SquareMap
extends MapKit
## Rynek: a tight square with two rings of tenements around it. Close quarters everywhere:
## alleys cut through the rows, every house has a way through, and the middle has no shelter
## but stalls and barricades.

const BOUND_X := 84.0
const BOUND_Z := 66.0
const SQUARE_X := 26.0
const SQUARE_Z := 19.0
const DEPTH := 9.0

const BASES := [Vector3(0, 0, 58), Vector3(0, 0, -58)]
const CLOCK := Vector3(0, 0, -41.5)


func climate_of() -> Dictionary:
	return {"wet": 0.5, "grime": 0.55}


func weather() -> Dictionary:
	return {"guns": true}


func bases() -> Array:
	return BASES


func bound() -> Vector2:
	return Vector2(BOUND_X, BOUND_Z)


func street_rects() -> Array[Rect2]:
	return [
		Rect2(-SQUARE_X, -SQUARE_Z, SQUARE_X * 2.0, SQUARE_Z * 2.0),
		Rect2(-58.0, 29.0, 116.0, 7.0), Rect2(-58.0, -36.0, 116.0, 7.0),
		Rect2(-48.0, -36.0, 7.0, 72.0), Rect2(41.0, -36.0, 7.0, 72.0),
		Rect2(-BOUND_X, 50.0, BOUND_X * 2.0, 16.0), Rect2(-BOUND_X, -66.0, BOUND_X * 2.0, 16.0),
	]


func hotspots() -> Array[Vector3]:
	return [
		Vector3(0, 0, 7.5), Vector3(-16, 0, 11), Vector3(16, 0, -11), Vector3(-16, 0, -12), Vector3(17, 0, 12),
		Vector3(0, 0, 32), Vector3(0, 0, -32), Vector3(-44, 0, 0), Vector3(44, 0, 0),
		Vector3(-44, 0, 32), Vector3(44, 0, 32), Vector3(-44, 0, -32), Vector3(44, 0, -32),
	]


func team_spawns(team: int) -> Array[Vector3]:
	var z := 57.0 if team == 0 else -57.0
	return [Vector3(-60, 0, z), Vector3(-30, 0, z), Vector3(0, 0, z), Vector3(30, 0, z), Vector3(60, 0, z)]


func free_spawns() -> Array[Vector3]:
	return [
		Vector3(-70, 0, 56), Vector3(-30, 0, 57), Vector3(30, 0, 57), Vector3(70, 0, 56),
		Vector3(-70, 0, -56), Vector3(-30, 0, -57), Vector3(30, 0, -57), Vector3(70, 0, -56),
		Vector3(-72, 0, 20), Vector3(-72, 0, -20), Vector3(72, 0, 20), Vector3(72, 0, -20),
		Vector3(-44, 0, 32), Vector3(44, 0, -32), Vector3(-44, 0, -32), Vector3(44, 0, 32),
	]


func coin_area() -> Vector2:
	return Vector2(76.0, 58.0)


func base_height(x: float, z: float) -> float:
	return _rim(x, z, Vector2(BOUND_X + 70.0, BOUND_Z + 70.0))


func _ground_tint(x: float, z: float, scorch: float) -> Color:
	var inside := 1.0 - smoothstep(0.98, 1.1, maxf(absf(x) / BOUND_X, absf(z) / BOUND_Z))
	var worn := sin(x * 0.21 + 0.4) * cos(z * 0.17) * 0.16
	return Color(clampf(inside * 0.84 + worn, 0.0, 1.0), 1.0 - inside, scorch, 1.0)


func _plan_terrain() -> void:
	for i in 26:
		_add_crater(Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-17.0, 17.0)), rng.randf_range(1.2, 2.4))
	for i in 18:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		_add_crater(Vector2(rng.randf_range(-76.0, 76.0), side * rng.randf_range(30.0, 62.0)), rng.randf_range(1.2, 2.2))


func _build_scenery() -> void:
	# Inner ring, facing the square.
	_row_x(-40.0, 40.0, SQUARE_Z + 1.0 + DEPTH * 0.5, 0.0)
	_row_x(-40.0, 40.0, -SQUARE_Z - 1.0 - DEPTH * 0.5, PI)
	_row_z(-16.0, 16.0, SQUARE_X + 1.0 + DEPTH * 0.5, PI * 0.5)
	_row_z(-16.0, 16.0, -SQUARE_X - 1.0 - DEPTH * 0.5, -PI * 0.5)
	# Outer ring, its back to the street that runs round the map.
	_row_x(-58.0, 58.0, 41.5, PI)
	_row_x(-58.0, 58.0, -41.5, 0.0)
	_row_z(-26.0, 26.0, 53.5, -PI * 0.5)
	_row_z(-26.0, 26.0, -53.5, PI * 0.5)
	_build_square()
	_build_alleys()
	_street_blocks()
	_clock_tower(CLOCK)
	_perimeter(Vector2(BOUND_X, BOUND_Z), 4, 24.0)
	_outer_ruins(Vector2(BOUND_X, BOUND_Z), 90)
	_fill_open(4, _rubbish)


func build(parent: Node3D, map_seed: int, headless: bool) -> void:
	super.build(parent, map_seed, headless)
	if headless:
		return
	life = MapLife.new()
	parent.add_child(life)
	# Bombers pass high over the square every minute, on their way to somewhere else.
	for i in 3:
		var bomber := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = Forge.mesh("bomber", _bomber)
		body.material_override = Forge.skin(C.Team.EMPIRE)
		bomber.add_child(body)
		var off := Vector3(i * 22.0 - 22.0, 0, absf(i - 1.0) * 26.0)
		life.add_shuttle(bomber, Vector3(0, 95, 420) + off, Vector3(0, 95, -420) + off, 60.0, 15.0, "jet" if i == 1 else "")
	var pulse := OmniLight3D.new()
	pulse.light_color = Color(1.0, 0.82, 0.5)
	pulse.omni_range = 11.0
	parent.add_child(pulse)
	pulse.position = CLOCK + Vector3(0, 19.5, 3.4)
	life.add_pulse(pulse, 1.0, 2.2, 6.0)


## Long streets must not be firing ranges: wrecks and barricades close most of each one.
func _street_blocks() -> void:
	for z: float in [-32.5, 32.5]:
		for spec: Array in [[-30.0, 0.5], [0.0, -0.5], [30.0, 0.4]]:
			_barricade(Vector3(spec[0] + 1.8, 0, z + spec[1]), PI * 0.5, 3.6)
		_truck(Vector3(-16, 0, z - 1.0), PI * 0.5 + 0.35)
		_truck(Vector3(16, 0, z + 1.0), PI * 0.5 - 0.35)
	for x: float in [-44.5, 44.5]:
		for z: float in [-14.0, 14.0]:
			_barricade(Vector3(x + 1.4, 0, z), 0.0, 3.6)
	# Wagons in pairs, staggered: the way through bends, so no line runs round the outer road.
	for s: float in [-1.0, 1.0]:
		for x: float in [-46.0, -14.0, 22.0, 54.0]:
			_wagon(Vector3(x, 0, s * 54.0), PI * 0.5)
			_wagon(Vector3(x + 10.0, 0, s * 62.0), PI * 0.5)
		for z: float in [-36.0, 4.0]:
			_wagon(Vector3(s * 71.0, 0, z), 0.0)
			_wagon(Vector3(s * 79.0, 0, z + 10.0), 0.0)


## The town clock: a landmark that shows which way is north from anywhere on the map.
func _clock_tower(p: Vector3) -> void:
	var stone := Color(0.7, 0.66, 0.6)
	b.box(p + Vector3.UP * 11.0, Vector3(6.0, 22.0, 6.0), "plaster", stone, false)
	b.box(p + Vector3.UP * 22.3, Vector3(7.0, 0.6, 7.0), "concrete", stone.darkened(0.15), false)
	b.add_prism(p + Vector3.UP * 22.6, 3.2, 7.0, 4, "roof", Color(0.7, 0.6, 0.55), 0.2)
	if b.headless:
		return
	for s: float in [-1.0, 1.0]:
		b.box(p + Vector3(0, 19.5, s * 3.06), Vector3(3.4, 3.4, 0.08), "amber_light", Color.WHITE, false)
		b.box(p + Vector3(0, 20.2, s * 3.12), Vector3(0.14, 1.5, 0.05), "metal", Color(0.1, 0.1, 0.1), false)
		b.box(p + Vector3(0.5, 19.5, s * 3.12), Vector3(1.1, 0.14, 0.05), "metal", Color(0.1, 0.1, 0.1), false)


func _rubbish(p: Vector3) -> void:
	match rng.randi_range(0, 4):
		0: _crates(p)
		1: _drums(p)
		2: _rubble(p, rng.randf_range(0.9, 1.4), 8, "brick", Color(0.86, 0.78, 0.72))
		3: _barricade(p, rng.randf() * TAU, 3.0)
		4: _sandbags(p, p + Vector3(rng.randf_range(-3.0, 3.0), 0, rng.randf_range(-3.0, 3.0)), 3)


func _bomber(k: Forge) -> void:
	var skin := Forge.tone(Color(0.16, 0.18, 0.2))
	k.slab(Vector3(1.6, 1.4, 14), Vector3.ZERO, skin, Vector3.ZERO, 0.2)
	k.slab(Vector3(22, 0.24, 3.2), Vector3(0, 0.1, -1.0), skin, Vector3.ZERO, 0.08)
	k.slab(Vector3(7, 0.2, 1.6), Vector3(0, 0.4, 6.0), skin, Vector3.ZERO, 0.08)
	for x: float in [-5.0, 5.0]:
		k.slab(Vector3(1.1, 1.0, 3.0), Vector3(x, 0, -1.8), skin, Vector3.ZERO, 0.1)


## A row of houses along X. Gaps between them are the alleys people fight through.
func _row_x(from: float, to: float, z: float, yaw: float) -> void:
	var x := from
	while x < to - 6.0:
		var w := minf(rng.randf_range(10.0, 14.0), to - x)
		_house(Vector3(x + w * 0.5, 0, z), w, yaw)
		x += w + rng.randf_range(3.2, 4.6)


func _row_z(from: float, to: float, x: float, yaw: float) -> void:
	var z := from
	while z < to - 6.0:
		var w := minf(rng.randf_range(10.0, 14.0), to - z)
		_house(Vector3(x, 0, z + w * 0.5), w, yaw)
		z += w + rng.randf_range(3.2, 4.6)


func _house(p: Vector3, w: float, yaw: float) -> void:
	if rng.randf() < 0.1:
		_rubble(p, rng.randf_range(2.6, 3.6), 20, "brick", Color(0.88, 0.8, 0.74))
		return
	var ruin := 0.0 if rng.randf() < 0.45 else rng.randf_range(0.2, 0.7)
	_building(p, w, DEPTH, rng.randi_range(2, 3), yaw, ruin)


func _build_square() -> void:
	_fountain(Vector3(0, 0, 0))
	for spec: Array in [[-18.0, -10.0, 0.0], [-11.0, -13.5, 0.0], [12.0, -11.0, PI], [19.0, 7.0, PI * 0.5], [-20.0, 8.0, PI * 0.5], [-9.0, 13.0, 0.0], [10.0, 14.0, 0.0]]:
		_market_stall(Vector3(spec[0], 0, spec[1]), spec[2])
	_tram(Vector3(13, 0, 2.5), 0.28)
	_truck(Vector3(-15, 0, 1), PI * 0.5 + 0.3)
	_sandbags(Vector3(-7, 0, -8), Vector3(-1, 0, -9.5))
	_sandbags(Vector3(4, 0, 8.5), Vector3(10, 0, 7.5))
	_sandbags(Vector3(-24, 0, -3), Vector3(-24, 0, 3))
	_sandbags(Vector3(24, 0, -7), Vector3(24, 0, -1))
	_hedgehog(Vector3(-6, 0, 16))
	_hedgehog(Vector3(6, 0, -16))
	_crates(Vector3(-22, 0, 15))
	_crates(Vector3(22, 0, -15))
	fires.append(Vector3(13, 2.6, 2.5))
	smokes.append(Vector3(-15, 0.5, 1))
	for p: Vector3 in [Vector3(-25, 0, -18), Vector3(25, 0, -18), Vector3(-25, 0, 18), Vector3(25, 0, 18)]:
		_lamp(p)


## A dry fountain with a stone basin and the stump of its column.
func _fountain(p: Vector3) -> void:
	b.add_prism(p, 5.4, 0.9, 12, "concrete", Color(0.74, 0.72, 0.66), 5.2)
	b.add_prism(p + Vector3.UP * 0.9, 1.2, 1.5, 8, "concrete", Color(0.68, 0.66, 0.62), 0.9)
	b.add_prism(p + Vector3.UP * 2.4, 0.6, 1.8, 8, "concrete", Color(0.62, 0.6, 0.58), 0.34)
	b.add_footprint(Vector2(p.x, p.z), Vector2(10.8, 10.8), 0.0, "landmark")


func _build_alleys() -> void:
	for i in 24:
		var p := hotspots()[rng.randi_range(5, 12)] + Vector3(rng.randf_range(-14.0, 14.0), 0, rng.randf_range(-2.6, 2.6))
		if not _clear_of_spots(p):
			continue
		match rng.randi_range(0, 3):
			0: _crates(p)
			1: _rubble(p, rng.randf_range(0.9, 1.5), 8, "brick", Color(0.86, 0.78, 0.72))
			2: _sandbags(p, p + Vector3(rng.randf_range(-3.0, 3.0), 0, rng.randf_range(0.6, 1.4)), 3)
			3: _hedgehog(p)
	for spec: Array in [[-77.0, 44.0, 0.0], [77.0, -44.0, PI], [-44.0, -62.0, PI * 0.5], [44.0, 62.0, PI * 0.5]]:
		_truck(Vector3(spec[0], 0, spec[1]), spec[2])
	_tank_wreck(Vector3(-72, 0, 0), 0.1)
	_tank_wreck(Vector3(72, 0, 4), PI + 0.2)
	smokes.append(Vector3(-72, 1.5, 0))
	fires.append(Vector3(72, 1.4, 4))
	for x: float in [-64.0, -16.0, 16.0, 64.0]:
		_lamp(Vector3(x, 0, 62))
		_lamp(Vector3(x, 0, -62))
	for z: float in [-30.0, 30.0]:
		_dead_tree(Vector3(-78, 0, z))
		_dead_tree(Vector3(78, 0, z))
