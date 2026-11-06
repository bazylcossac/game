class_name TankValleyMap
extends MapKit
## A 1020 x 900 m armored battlefield. Bases are below broad screened ridges.
## Three staggered passages force tanks out of their starting firing lines.
const EXTENT := 520.0
const STEP := 4.0
const BASES := [Vector3(-190, 0, 378), Vector3(190, 0, -378)]
const FLAGS := [
	{"name": "Kamieniołom", "letter": "A", "pos": Vector3(-300, 0, 64), "owner": -1},
	{"name": "Przeprawa", "letter": "B", "pos": Vector3(0, 0, 0), "owner": -1},
	{"name": "Stacja paliw", "letter": "C", "pos": Vector3(300, 0, -64), "owner": -1},
]

func bound() -> Vector2:
	return Vector2(510, 450)

func bases() -> Array:
	return BASES

func flag_defs() -> Array:
	return FLAGS

func hotspots() -> Array[Vector3]:
	return [Vector3(-300, 0, 64), Vector3(0, 0, 0), Vector3(300, 0, -64), Vector3(-140, 0, 180), Vector3(140, 0, -180)]

func team_spawns(team: int) -> Array[Vector3]:
	var home: Vector3 = BASES[team]
	return [home + Vector3(-30, 0, -8), home + Vector3(30, 0, -8), home + Vector3(-30, 0, 16), home + Vector3(30, 0, 16)]

func tank_depots() -> Array:
	var out := [[], []]
	for team in 2:
		for i in 6:
			out[team].append([BASES[team] + Vector3((i - 2.5) * 14, 0, -26 if team == 0 else 26), 0.0 if team == 0 else PI])
	return out

func free_spawns() -> Array[Vector3]:
	return hotspots()

func coin_area() -> Vector2:
	return Vector2(420, 330)

func street_rects() -> Array[Rect2]:
	return [Rect2(-325, -310, 30, 620), Rect2(-15, -300, 30, 600), Rect2(295, -310, 30, 620), Rect2(-420, -16, 840, 32)]

func base_height(x: float, z: float) -> float:
	var home := minf(Vector2(x - BASES[0].x, z - BASES[0].z).length(), Vector2(x - BASES[1].x, z - BASES[1].z).length())
	var terrain := (sin(x * .009) * cos(z * .011) * 4 + sin(z * .017 + x * .006) * 2) * smoothstep(55, 105, home)
	# A full-width rise blocks every direct base-to-base ray. Passages wind through
	# it at different X coordinates, never straight from a spawn towards its opposite.
	var north := exp(-pow((z + 242) / 48.0, 2)) * 27.0
	var south := exp(-pow((z - 242) / 48.0, 2)) * 27.0
	var gap_s := maxf(exp(-pow((x + 330) / 55.0, 2)), exp(-pow((x - 35) / 55.0, 2)))
	var gap_n := maxf(exp(-pow((x - 330) / 55.0, 2)), exp(-pow((x + 35) / 55.0, 2)))
	terrain += north * (1.0 - gap_n * .84) + south * (1.0 - gap_s * .84)
	terrain += 12 * exp(-pow((x + 145) / 65.0, 2) - pow(z / 160.0, 2))
	terrain += 12 * exp(-pow((x - 145) / 65.0, 2) - pow(z / 160.0, 2))
	return terrain + _rim(x, z, Vector2(530, 470))

func far_height(x: float, z: float) -> float:
	return base_height(x, z) - 25 + smoothstep(550, 1100, Vector2(x, z).length()) * 70

func ground_height(x: float, z: float) -> float:
	if heights.is_empty() or absf(x) >= EXTENT or absf(z) >= EXTENT:
		return base_height(x, z)
	var gx := (x + EXTENT) / STEP
	var gz := (z + EXTENT) / STEP
	var ix := int(gx)
	var iz := int(gz)
	return lerpf(lerpf(heights[iz * _grid_n + ix], heights[iz * _grid_n + ix + 1], gx - ix), lerpf(heights[(iz + 1) * _grid_n + ix], heights[(iz + 1) * _grid_n + ix + 1], gx - ix), gz - iz)

func build(parent: Node3D, map_seed: int, headless: bool) -> void:
	b.nav = NavGrid.new(2.5)
	b.nav_wide = NavGrid.new(2.5)
	b.nav_tank = NavGrid.new(2.5)
	super.build(parent, map_seed, headless)

func _build_ground(parent: Node3D, headless: bool) -> void:
	var cells := int(EXTENT * 2 / STEP)
	_grid_n = cells + 1
	heights.resize(_grid_n * _grid_n)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for iz in _grid_n:
		for ix in _grid_n:
			var x := -EXTENT + ix * STEP
			var z := -EXTENT + iz * STEP
			var y := base_height(x, z)
			heights[iz * _grid_n + ix] = y
			verts.append(Vector3(x, y, z))
			if not headless:
				normals.append(Vector3(base_height(x - 1, z) - base_height(x + 1, z), 2, base_height(x, z - 1) - base_height(x, z + 1)).normalized())
				var road := 1.0 - smoothstep(6, 16, minf(absf(z), minf(absf(x - 310), absf(x + 310))))
				colors.append(Color(0, (1.0 - road) * .78, 0, 1))
	var faces := PackedVector3Array()
	for z in cells:
		for x in cells:
			var i := z * _grid_n + x
			faces.append_array(PackedVector3Array([verts[i], verts[i + 1], verts[i + _grid_n + 1], verts[i], verts[i + _grid_n + 1], verts[i + _grid_n]]))
	b.add_collision_faces(faces)
	if not headless:
		_add_tiles(parent, verts, normals, colors, cells, 26, func(_x: int, _z: int) -> bool: return true)
		_build_far_terrain(parent)

func _build_scenery() -> void:
	for team in 2:
		var h: Vector3 = BASES[team]
		# Base side shelters protect respawning tanks while leaving broad exits.
		for side: float in [-1.0, 1.0]:
			b.box(h + Vector3(side * 68, 3, 0), Vector3(6, 6, 100), "concrete", Color(.55, .56, .52))
			b.add_footprint(Vector2(h.x + side * 68, h.z), Vector2(6, 100), 0, "cover")
		for i in 3:
			_crates(_ground(h.x + (i - 1) * 22, h.z + (34 if team == 0 else -34)))
	for f: Dictionary in FLAGS:
		var p: Vector3 = f["pos"]
		for side: float in [-1.0, 1.0]:
			var c := _ground(p.x + side * 28, p.z + side * 18)
			b.box(c + Vector3.UP * 2.2, Vector3(16, 4.4, 9), "concrete", Color(.46, .44, .4))
			b.add_footprint(Vector2(c.x, c.z), Vector2(16, 9), 0, "cover")
		_tank_wreck(_ground(p.x + 24, p.z - 22), .6)
	# Broad rocks and ruined embankments supply stopping places along each approach.
	for z: float in [-160, -95, 95, 160]:
		for x: float in [-385, -220, -70, 70, 220, 385]:
			var p := _ground(x, z)
			_outcrop(p, rng.randf_range(7, 11))
	_landmarks()
	# Sparse burned tree lines make the scale readable without sealing tank routes.
	for side: float in [-1.0, 1.0]:
		for z in range(-360, 361, 45):
			_dead_tree(_ground(side * rng.randf_range(430, 470), z + rng.randf_range(-8, 8)))
	_countryside()
	b.floor_y = 0

## A heap of rock, big enough to hide a tank.
func _outcrop(p: Vector3, radius: float) -> void:
	var yaw := rng.randf() * TAU
	var k := radius * 0.72
	props.stand("boulder_a", p - Vector3.UP * 0.5, yaw, Color(.62, .58, .5), Vector3(k, k * 0.7, k))
	props.stand("boulder_b", p + Vector3(cos(yaw), -0.3, sin(yaw)) * radius * 0.7, yaw + 2.0, Color(.56, .52, .46), Vector3(k * 0.6, k * 0.5, k * 0.6))
	b.box(p + Vector3.UP * radius * 0.26, Vector3(radius * 1.5, radius * 0.52, radius * 1.5), "", Color.WHITE, true, yaw)
	b.add_footprint(Vector2(p.x, p.z), Vector2(radius * 1.5, radius * 1.5), yaw, "cover")


## Copses, scrub and wrecks. Trees keep off the roads, so they screen tanks without closing a route.
func _countryside() -> void:
	var autumn := [Color(.56, .58, .3), Color(.46, .54, .3), Color(.66, .5, .26), Color(.4, .48, .3)]
	for i in 34:
		var c := Vector2(rng.randf_range(-470, 470), rng.randf_range(-420, 420))
		if _on_way(c, 30.0):
			continue
		for j in rng.randi_range(5, 11):
			var p := c + Vector2(rng.randf_range(-22, 22), rng.randf_range(-22, 22))
			var at := _ground(p.x, p.y)
			var k := rng.randf_range(.9, 1.5)
			var tint: Color = autumn[rng.randi() % autumn.size()]
			props.stand("tree_oak" if rng.randf() < .6 else "tree_slim", at - Vector3.UP * .2, rng.randf() * TAU, tint, Vector3(k, k, k))
			b.box(at + Vector3.UP * 2.0, Vector3(1.0, 4.0, 1.0), "", Color.WHITE, true)
			b.add_footprint(p, Vector2(1, 1), 0, "cover")
	for i in 420:
		var p := Vector2(rng.randf_range(-490, 490), rng.randf_range(-430, 430))
		if _on_way(p, 8.0):
			continue
		var k := rng.randf_range(.8, 1.7)
		props.stand("shrub", _ground(p.x, p.y), rng.randf() * TAU, Color(.5, .52, .3), Vector3(k, k * rng.randf_range(.7, 1.1), k))
	for i in 150:
		var p := Vector2(rng.randf_range(-490, 490), rng.randf_range(-430, 430))
		var k := rng.randf_range(.3, 1.0)
		props.stand("boulder_b" if i % 2 == 0 else "boulder_a", _ground(p.x, p.y) - Vector3.UP * .1, rng.randf() * TAU, Color(.6, .57, .5), Vector3(k, k, k))
	# An earlier battle: burnt out tanks lying where they stopped.
	for spec: Array in [[-240, 150, .4], [-120, 60, 1.9], [90, 120, 2.6], [240, -150, 3.5], [120, -60, 5.0], [-90, -120, .1], [-30, 210, 1.2], [30, -210, 4.3]]:
		_tank_wreck(_ground(spec[0], spec[1]), spec[2])
		if rng.randf() < .5:
			smokes.append(_ground(spec[0], spec[1]) + Vector3.UP * 1.5)


## On a road or by a flag or a base, where nothing should stand in the way of a tank.
func _on_way(p: Vector2, margin: float) -> bool:
	for r: Rect2 in street_rects():
		if r.grow(margin).has_point(p):
			return true
	for f: Dictionary in FLAGS:
		if p.distance_to(Vector2(f["pos"].x, f["pos"].z)) < 44.0 + margin:
			return true
	for h: Vector3 in BASES:
		if p.distance_to(Vector2(h.x, h.z)) < 110.0 + margin:
			return true
	return false


func _landmarks() -> void:
	# Western quarry: terraces, excavated stone, a service office and a conveyor.
	for i in 3:
		var p := _ground(-350 + i * 18, 110)
		b.box(p + Vector3.UP * (3 + i), Vector3(14, 6 + i * 2, 56), "concrete", Color(.52, .50, .45))
		b.add_footprint(Vector2(p.x, p.z), Vector2(14, 56), 0, "landmark")
	_building(_ground(-350, 35), 18, 14, 1, .12, .18)
	var conveyor := _ground(-350, 70)
	b.box(conveyor + Vector3(0, 7, 0), Vector3(4, 1, 36), "metal", Color(.25, .28, .25))
	for z: float in [-14, 14]:
		for side: float in [-1, 1]:
			b.box(conveyor + Vector3(side * 1.5, 3.5, z), Vector3(.3, 7, .3), "metal", Color(.35, .37, .34))
	# Central checkpoint has broken parapets and an open, wide through route.
	for side: float in [-1, 1]:
		for z: float in [-25, 25]:
			var p := _ground(side * 17, z)
			b.box(p + Vector3.UP * .7, Vector3(1.4, 1.4, 14), "concrete", Color(.58, .58, .54))
			b.add_footprint(Vector2(p.x, p.z), Vector2(1.4, 14), 0, "cover")
	_truck(_ground(38, -40), .4)
	# Eastern fuel depot: cylindrical tanks, flange bands, canopy and maintenance shed.
	for x: float in [340, 362]:
		var p := _ground(x, -100)
		b.add_prism(p, 5, 12, 20, "metal", Color(.62, .62, .55))
		for y: float in [.4, 5.5, 11.6]:
			b.add_prism(p + Vector3.UP * y, 5.25, .3, 20, "metal", Color(.23, .26, .24))
		b.add_footprint(Vector2(x, -100), Vector2(11, 11), 0, "landmark")
	_building(_ground(348, -25), 20, 14, 1, -.15, .1)
	var canopy := _ground(302, -28)
	b.box(canopy + Vector3.UP * 6, Vector3(26, .5, 15), "metal", Color(.5, .48, .38))
	for x: float in [-11, 11]:
		for z: float in [-5, 5]:
			b.box(canopy + Vector3(x, 3, z), Vector3(.4, 6, .4), "metal", Color(.3, .33, .3))
	_drums(_ground(325, -35))

func _build_skyline() -> void:
	pass
