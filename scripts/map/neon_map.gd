class_name NeonMap
extends CombatArena
## Neonowa Dzielnica: a rainy night downtown, 520 x 700 m, laid out on an American street grid.
## A 64 m boulevard runs north to south under an elevated maglev, two 48 m avenues run beside it
## and four 44 m cross streets tie them together, so tanks and mechs can drive anywhere the
## infantry can. Skyscrapers fill the blocks, with a park, a car park and a building site to
## break the grid. The map is point symmetric: whatever stands at (x, z) also stands at (-x, -z).

const HALF := Vector2(260, 350)
const BOULEVARD := 32.0
const AVENUE_X := 170.0
const AVENUE := 24.0
const CROSS_Z := [-240.0, -80.0, 80.0, 240.0]
const CROSS := 22.0
const SIDEWALK := 6.0
const ALLEY := 14.0
const BASE_Z := 315.0
## Modes for a few players start here, nearer each other. The whole city stays open.
const CLOSE_Z := 145.0
const DECK_Y := 14.0

const CYAN := Color(0.1, 0.9, 1.0)
const PINK := Color(1.0, 0.2, 0.6)
const AMBER := Color(1.0, 0.68, 0.22)
const WALL := Color(0.5, 0.54, 0.72)
const GREY := Color(0.42, 0.44, 0.5)
const PAINT := Color(1.5, 1.5, 1.4)
const LOBBY_Y := 6.0
const PAINTS := [Color(0.04, 0.05, 0.07), Color(0.78, 0.8, 0.84), Color(0.34, 0.37, 0.42), Color(0.5, 0.05, 0.08), Color(0.05, 0.14, 0.42), Color(0.9, 0.62, 0.06), Color(0.04, 0.3, 0.32), Color(0.34, 0.06, 0.36)]
const LEAVES := [Color(0.5, 0.95, 0.62), Color(0.42, 0.85, 0.8), Color(0.72, 1.0, 0.5), Color(0.86, 0.5, 0.9)]
## The four walk-through buildings round the central square.
const LOBBIES := [
	[Rect2(-74, 18, 30, 34), "HOTEL AURORA", PINK],
	[Rect2(44, 18, 30, 34), "ARKADA 24", CYAN],
	[Rect2(-74, -52, 30, 34), "SERWIS NEURO", CYAN],
	[Rect2(44, -52, 30, 34), "KLUB SYNAPSA", PINK],
]
const SHOPS := ["RAMEN", "NOODLE BAR", "BANK ORION", "KINO NOVA", "24H", "DINER", "NAPRAWY", "BATERIE", "NEON MOTEL", "TARG NOCNY", "ZENITH", "PULSAR", "CHROM", "METRO", "LUNA", "KASYNO"]

## Street cover for one half of the map; `_mirrored` builds the other half.
## Each entry is [kind, x, z, yaw]. A hard rule: no line across a street is ever more than
## half closed, and neon_test.gd measures that.
const STREET_COVER := [
	# The boulevard, either side of the median.
	["barrier", -20.0, 100.0, 0.0], ["barrier", 12.0, 122.0, 0.0], ["bus", 21.0, 134.0, 1.66], ["wreck", -9.0, 132.0, 0.7],
	["barrier", -13.0, 150.0, 0.0], ["bus", -15.0, 170.0, 1.42], ["container", 14.0, 164.0, 0.0], ["barrier", 21.0, 182.0, 0.0],
	["wreck", 7.0, 196.0, 2.1], ["barrier", -22.0, 204.0, 0.0], ["container", -9.0, 216.0, 0.0], ["barrier", 13.0, 220.0, 0.0],
	["barrier", -14.0, 268.0, 0.0], ["barrier", 15.0, 276.0, 0.0],
	# The near cross street.
	["barrier", 62.0, 72.0, 1.57], ["barrier", 92.0, 92.0, 1.57], ["bus", 112.0, 70.0, 0.06], ["wreck", 134.0, 86.0, 1.1],
	["barrier", -62.0, 90.0, 1.57], ["barrier", -92.0, 68.0, 1.57], ["container", -116.0, 86.0, 1.57], ["wreck", -46.0, 74.0, 2.6],
	# The far cross street.
	["barrier", 70.0, 232.0, 1.57], ["bus", 104.0, 250.0, 3.08], ["barrier", 138.0, 244.0, 1.57],
	["barrier", -74.0, 248.0, 1.57], ["container", -108.0, 232.0, 1.57], ["barrier", -136.0, 238.0, 1.57],
	# The avenues.
	["barrier", 160.0, 24.0, 0.0], ["bus", 183.0, 44.0, 1.5], ["barrier", 158.0, 124.0, 0.0], ["wreck", 180.0, 116.0, 0.4],
	["container", 165.0, 158.0, 0.0], ["barrier", 183.0, 186.0, 0.0], ["barrier", 160.0, 212.0, 0.0],
	["barrier", -182.0, 20.0, 0.0], ["container", -160.0, 42.0, 0.0], ["wreck", -176.0, 124.0, 2.0], ["barrier", -158.0, 136.0, 0.0],
	["bus", -181.0, 168.0, 1.63], ["barrier", -160.0, 198.0, 0.0], ["barrier", -178.0, 214.0, 0.0],
	["barrier", 160.0, 288.0, 0.0], ["barrier", 180.0, 306.0, 0.0], ["barrier", -160.0, 300.0, 0.0], ["barrier", -182.0, 284.0, 0.0],
]

var close_start := false
var tank_war := false
var _signs: Array[Array] = []
## Street edges waiting for trees and lamps, and the spots already taken along them.
var _kerbs: Array[Rect2] = []
var _taken: Array[Vector2] = []


var _solids: Array[Array] = []
## Everyone for themselves: kept round the square, or twelve people never find each other here.
var brawl := false


func _init(mode_id := "") -> void:
	brawl = mode_id == "deathmatch"
	close_start = mode_id in ["pvp", "deathmatch"]
	tank_war = mode_id == "czolgi"


func bound() -> Vector2:
	return HALF


func climate_of() -> Dictionary:
	return {"wet": 0.85, "grime": 0.4}


func weather() -> Dictionary:
	return {"lightning": [9.0, 26.0], "ships": true, "flash_ambient": 1.6, "flash_sun": 1.6}


func view_range() -> float:
	return 380.0


func coin_area() -> Vector2:
	return Vector2(200, 260)


func bases() -> Array:
	var z := CLOSE_Z if close_start else BASE_Z
	return [Vector3(14, 0, z), Vector3(-14, 0, -z)]


func team_spawns(team: int) -> Array[Vector3]:
	var s := 1.0 if team == 0 else -1.0
	var z := CLOSE_Z if close_start else BASE_Z + 6.0
	var out: Array[Vector3] = []
	for x: float in ([-24.0, -12.0, 12.0, 24.0] if close_start else [-52.0, -30.0, -12.0, 12.0, 30.0, 52.0]):
		out.append(Vector3(x, 0, s * z))
	return out


func free_spawns() -> Array[Vector3]:
	var out: Array[Vector3] = team_spawns(0)
	out.append_array(team_spawns(1))
	if brawl:
		out.append_array([Vector3(14, 0, 80), Vector3(-14, 0, -80), Vector3(-14, 0, 80), Vector3(14, 0, -80)])
		return out
	for spot: Vector3 in [Vector3(-170, 0, 80), Vector3(170, 0, -80), Vector3(170, 0, 80), Vector3(-170, 0, -80), Vector3(-90, 0, 80), Vector3(90, 0, -80), Vector3(20, 0, 240), Vector3(-20, 0, -240), Vector3(-170, 0, 0), Vector3(170, 0, 0)]:
		out.append(spot)
	return out


func flag_defs() -> Array:
	if tank_war:
		return [
			{"name": "Targ", "letter": "A", "pos": Vector3(-170, 0, 80), "owner": -1},
			{"name": "Plac", "letter": "B", "pos": Vector3(0, 0, 24), "owner": -1},
			{"name": "Rampa", "letter": "C", "pos": Vector3(170, 0, -80), "owner": -1},
		]
	return [
		{"name": "Targ", "letter": "A", "pos": Vector3(-170, 0, 80), "owner": 0},
		{"name": "Arkada", "letter": "B", "pos": Vector3(170, 0, 80), "owner": -1},
		{"name": "Plac", "letter": "C", "pos": Vector3(0, 0, 24), "owner": -1},
		{"name": "Serwis", "letter": "D", "pos": Vector3(-170, 0, -80), "owner": -1},
		{"name": "Rampa", "letter": "E", "pos": Vector3(170, 0, -80), "owner": 1},
	]


func tank_depots() -> Array:
	var out := [[], []]
	var columns := [-55.0, -33.0, -11.0, 11.0, 33.0, 55.0] if tank_war else [-33.0, -11.0, 11.0, 33.0]
	for x: float in columns:
		out[0].append([Vector3(x, 0, 292), 0.0])
		out[1].append([Vector3(x, 0, -292), PI])
	return out


func hotspots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if brawl:
		out.append_array([Vector3.ZERO, Vector3(14, 0, 80), Vector3(-14, 0, -80), Vector3(-14, 0, 80), Vector3(14, 0, -80)])
		return out
	for f: Dictionary in flag_defs():
		out.append(f["pos"])
	out.append_array([Vector3(14, 0, 80), Vector3(-14, 0, -80), Vector3(170, 0, 0), Vector3(-170, 0, 0), Vector3(14, 0, 160), Vector3(-14, 0, -160), Vector3(90, 0, 80), Vector3(-90, 0, -80)])
	return out


func street_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(-BOULEVARD, -HALF.y, BOULEVARD * 2.0, HALF.y * 2.0)]
	for x: float in [-AVENUE_X, AVENUE_X]:
		out.append(Rect2(x - AVENUE, -HALF.y, AVENUE * 2.0, HALF.y * 2.0))
	for z: float in CROSS_Z:
		out.append(Rect2(-HALF.x, z - CROSS, HALF.x * 2.0, CROSS * 2.0))
	out.append(Rect2(-80, -58, 160, 116))
	return out


func _build_ground(_parent: Node3D, _headless: bool) -> void:
	b.box(Vector3(0, -0.3, 0), Vector3(HALF.x * 2.0 + 240.0, 0.6, HALF.y * 2.0 + 240.0), "asphalt", Color(1.0, 1.0, 1.0))


func build(parent: Node3D, map_seed: int, headless: bool) -> void:
	# Two metre cells reach 480 m from the centre, which covers the whole grid.
	b.nav = NavGrid.new(2.0)
	b.nav_wide = NavGrid.new(2.0)
	b.nav_tank = NavGrid.new(2.0)
	# A city block is cheap to draw and expensive to ask for: batches twice the size of the usual
	# ones nearly halve the draw calls, and the towers' occluders still hide most of them.
	b.batch_chunk = 128.0
	props.chunk = 256.0
	super.build(parent, map_seed, headless)
	if headless:
		return
	life = MapLife.new()
	parent.add_child(life)
	for spec: Array in _signs:
		_sign(parent, spec[0], spec[1], spec[2], spec[3], spec[4])
	for spec: Array in LOBBIES:
		_lobby_dressing(parent, spec[0], spec[1], spec[2])
	_square_dressing(parent)
	_street_lights(parent)
	_rain(parent)
	_traffic()
	_build_occluders(parent)
	_fade_lights(parent)


func _build_scenery() -> void:
	_edge()
	_blocks()
	_square()
	_median()
	_street_furniture()
	_mirrored_cover()
	_flag_markets()
	_plant_kerbs()
	_traffic_lights()
	_terminal(1.0)
	_terminal(-1.0)
	_road_paint()
	_gantries()
	_distant_city()


## The same random number on the server and on every client, whatever each of them skips.
func _roll(x: float, z: float, salt := 0.0) -> float:
	var v := sin(x * 12.9898 + z * 78.233 + salt * 37.719) * 43758.5453
	return v - floor(v)


func _point(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, -p.z)


# ---------------------------------------------------------------- city blocks

func _edge() -> void:
	# Beyond the last street the view runs into more city, not into a wall.
	b.batch_tag = "far"
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(s * (HALF.x + 18.0), 30, 0), Vector3(34, 60, HALF.y * 2.0 + 72.0), "facade_night", Color(0.7, 0.76, 0.9), false)
		b.box(Vector3(0, 30, s * (HALF.y + 18.0)), Vector3(HALF.x * 2.0 + 72.0, 60, 34), "facade_night", Color(0.7, 0.76, 0.9), false)
	b.batch_tag = ""


func _blocks() -> void:
	var inner := [Vector2(-146, -32), Vector2(32, 146)]
	var outer := [Vector2(-260, -194), Vector2(194, 260)]
	var rows := [Vector2(-218, -102), Vector2(102, 218)]
	var ends := [Vector2(-350, -262), Vector2(262, 350)]
	# Beside the boulevard, the park and the car park take the place of two pairs of towers.
	_towers(_span(inner[0], rows[1]))
	_park(_span(inner[1], rows[1]))
	_towers(_span(inner[1], rows[0]))
	_park(_span(inner[0], rows[0]))
	for row: Vector2 in rows:
		for x: Vector2 in outer:
			_towers(_span(x, row))
	# The middle row: towers behind the buildings of the square.
	for x: Vector2 in [Vector2(-146, -84), Vector2(84, 146)]:
		_towers(_span(x, Vector2(-58, 58)))
	for x: Vector2 in outer:
		_towers(_span(x, Vector2(-58, 58)))
	# The end rows, behind each base.
	_building_site(_span(Vector2(66, 146), ends[1]))
	_towers(_span(Vector2(-146, -66), ends[1]))
	_building_site(_span(Vector2(-146, -66), ends[0]))
	_towers(_span(Vector2(66, 146), ends[0]))
	for row: Vector2 in ends:
		for x: Vector2 in outer:
			_towers(_span(x, row))


func _span(x: Vector2, z: Vector2) -> Rect2:
	return Rect2(x.x, z.x, x.y - x.x, z.y - z.x)


func _pavement(r: Rect2, tint := Color(0.5, 0.52, 0.6)) -> void:
	var c := r.get_center()
	b.box(Vector3(c.x, 0.06, c.y), Vector3(r.size.x, 0.12, r.size.y), "tiles", tint, false)
	if b.headless:
		return
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(c.x, 0.08, c.y + s * r.size.y * 0.5), Vector3(r.size.x, 0.16, 0.3), "concrete", Color(0.66, 0.66, 0.68), false)
		b.box(Vector3(c.x + s * r.size.x * 0.5, 0.08, c.y), Vector3(0.3, 0.16, r.size.y), "concrete", Color(0.66, 0.66, 0.68), false)


## Fills a block with towers, with service alleys wide enough for a tank between them.
func _towers(r: Rect2) -> void:
	_pavement(r)
	_kerbs.append(r)
	var lot := r.grow(-SIDEWALK)
	var columns := 2 if lot.size.x >= 80.0 else 1
	var rows := 2 if lot.size.y >= 70.0 else 1
	var w := (lot.size.x - ALLEY * (columns - 1)) / columns
	var d := (lot.size.y - ALLEY * (rows - 1)) / rows
	if columns == 2 and rows == 2:
		var mid := lot.get_center()
		_dumpster(Vector3(mid.x + 4.0, 0, mid.y - d * 0.4), 0.0)
		_dumpster(Vector3(mid.x - 4.0, 0, mid.y + d * 0.4), PI)
	for i in columns:
		for j in rows:
			var at := lot.position + Vector2(i * (w + ALLEY), j * (d + ALLEY))
			_tower_lot(Rect2(at, Vector2(w, d)), r)


func _tower_lot(lot: Rect2, block: Rect2) -> void:
	var c := lot.get_center()
	var height: float = lerpf(70.0, 215.0, pow(_roll(c.x, c.y, 1.0), 1.5))
	# The square gets the tallest skyline, so it can be found from anywhere.
	height *= lerpf(1.25, 0.85, clampf(c.length() / 330.0, 0.0, 1.0))
	var podium := 12.0
	var tint := Color(0.7, 0.74, 0.88).lerp(Color(0.86, 0.72, 0.8), _roll(c.x, c.y, 2.0))
	b.box(Vector3(c.x, podium * 0.5, c.y), Vector3(lot.size.x, podium, lot.size.y), "panel", Color(0.3, 0.32, 0.4))
	b.add_footprint(c, lot.size, 0.0)
	_solid(Vector3(c.x, podium * 0.5, c.y), Vector3(lot.size.x, podium, lot.size.y))
	var strip: String = ["neon_cyan", "neon_pink", "neon_amber"][int(_roll(c.x, c.y, 3.0) * 3.0)]
	match int(_roll(c.x, c.y, 4.0) * 4.0):
		0:
			_shaft(c, lot.size - Vector2(6, 6), podium, height, tint, strip)
		1:
			# Setbacks, the way the old towers of an American downtown step in.
			_shaft(c, lot.size - Vector2(4, 4), podium, height * 0.5, tint, strip)
			_shaft(c, lot.size * 0.72, height * 0.5, height * 0.8, tint.darkened(0.08), strip)
			_shaft(c, lot.size * 0.46, height * 0.8, height, tint.darkened(0.14), strip)
		2:
			# Twin slabs with a slot of sky between them.
			var along := lot.size.x >= lot.size.y
			var offset := Vector2(lot.size.x * 0.27, 0) if along else Vector2(0, lot.size.y * 0.27)
			var slab := Vector2(lot.size.x * 0.38, lot.size.y - 6.0) if along else Vector2(lot.size.x - 6.0, lot.size.y * 0.38)
			_shaft(c - offset, slab, podium, height, tint, strip)
			_shaft(c + offset, slab, podium, height * 0.84, tint.darkened(0.1), strip)
		3:
			var radius := minf(lot.size.x, lot.size.y) * 0.46
			b.add_prism(Vector3(c.x, podium, c.y), radius, height - podium, 12, "facade_night", tint, radius * 0.86)
			_solid(Vector3(c.x, (podium + height) * 0.5, c.y), Vector3(radius * 1.3, height - podium, radius * 1.3))
			if not b.headless:
				for y: float in [podium + 24.0, height * 0.6, height - 8.0]:
					b.add_prism(Vector3(c.x, y, c.y), radius * 1.02, 0.5, 12, strip, Color.WHITE, -1.0, false)
	if b.headless:
		return
	_shopfront(lot, block, strip)
	b.box(Vector3(c.x, height + 9.0, c.y), Vector3(0.5, 18.0, 0.5), "metal", Color(0.3, 0.32, 0.38), false)
	b.box(Vector3(c.x, height + 18.2, c.y), Vector3(0.9, 0.9, 0.9), "neon_pink", Color.WHITE, false)


func _shaft(c: Vector2, size: Vector2, y0: float, y1: float, tint: Color, strip: String) -> void:
	b.box(Vector3(c.x, (y0 + y1) * 0.5, c.y), Vector3(size.x, y1 - y0, size.y), "facade_night", tint)
	if b.headless:
		return
	_solid(Vector3(c.x, (y0 + y1) * 0.5, c.y), Vector3(size.x, y1 - y0, size.y))
	var h := size * 0.5
	for corner: Vector2 in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
		b.box(Vector3(c.x + corner.x, (y0 + y1) * 0.5, c.y + corner.y), Vector3(0.4, y1 - y0, 0.4), strip, Color.WHITE, false)
	b.box(Vector3(c.x, y1 + 0.5, c.y), Vector3(size.x + 1.0, 1.0, size.y + 1.0), "metal", Color(0.2, 0.22, 0.28), false)
	b.box(Vector3(c.x, y1 - 1.5, c.y), Vector3(size.x + 0.3, 0.5, size.y + 0.3), strip, Color.WHITE, false)


## Remembers a solid block, for the renderer to skip whatever stands behind it.
func _solid(at: Vector3, size: Vector3) -> void:
	_solids.append([at, size * 0.97])


## Nothing behind a tower is drawn. A player cannot see the difference, the graphics card can.
func _build_occluders(parent: Node3D) -> void:
	for spec: Array in _solids:
		var shape := BoxOccluder3D.new()
		shape.size = spec[1]
		var node := OccluderInstance3D.new()
		node.occluder = shape
		parent.add_child(node)
		node.position = spec[0]


## Lamps too far off to light anything the fog has left visible.
func _fade_lights(parent: Node3D) -> void:
	for light: Light3D in parent.find_children("*", "Light3D", true, false):
		if light is DirectionalLight3D:
			continue
		light.distance_fade_enabled = true
		light.distance_fade_begin = 130.0
		light.distance_fade_length = 40.0


## Shop windows, a lit band and a canopy on every side, and billboards on those facing a street.
func _shopfront(lot: Rect2, block: Rect2, strip: String) -> void:
	var c := lot.get_center()
	var h := lot.size * 0.5
	for side: Array in [[Vector2(0, -1), PI], [Vector2(0, 1), 0.0], [Vector2(1, 0), PI * 0.5], [Vector2(-1, 0), -PI * 0.5]]:
		var n: Vector2 = side[0]
		var along_x := absf(n.y) > 0.5
		var length := lot.size.x if along_x else lot.size.y
		var reach := absf(n.x) * h.x + absf(n.y) * h.y
		var face := c + n * (reach + 0.1)
		var size := func(w: float, height: float, depth: float) -> Vector3:
			return Vector3(w, height, depth) if along_x else Vector3(depth, height, w)
		b.box(Vector3(face.x, 2.4, face.y), size.call(length - 1.0, 3.6, 0.1), "window_blue", Color.WHITE, false)
		b.box(Vector3(face.x, 4.5, face.y), size.call(length, 0.3, 0.15), strip, Color.WHITE, false)
		var shade := c + n * (reach + 0.9)
		b.box(Vector3(shade.x, 5.1, shade.y), size.call(length, 0.18, 1.8), "metal", Color(0.24, 0.26, 0.32), false)
		var pier := -length * 0.5 + 6.0
		while pier < length * 0.5 - 2.0:
			var at := face + (Vector2(pier, 0) if along_x else Vector2(0, pier))
			b.box(Vector3(at.x, 2.4, at.y), size.call(0.7, 4.8, 0.4), "metal", Color(0.3, 0.32, 0.38), false)
			pier += 10.0
		var edge := face + n * 7.0
		if not block.has_point(edge):
			_billboard(c + n * (reach + 0.4), along_x, side[1], length, c.x + n.x * 3.0, c.y + n.y * 7.0)


func _billboard(at: Vector2, along_x: bool, yaw: float, length: float, seed_x: float, seed_z: float) -> void:
	var roll := _roll(seed_x, seed_z, 5.0)
	var color: Color = [PINK, CYAN, AMBER][int(_roll(seed_x, seed_z, 6.0) * 3.0)]
	var title: String = SHOPS[int(_roll(seed_x, seed_z, 7.0) * SHOPS.size())]
	var y := 8.4
	_signs.append([title, Vector3(at.x, y, at.y) + _outward(yaw) * 0.4, color, yaw, 170])
	if roll < 0.45:
		return
	# A big screen on the shoulder of the podium, lit from behind.
	var w := minf(length * 0.7, 26.0)
	var size := Vector3(w, 9.0, 0.5) if along_x else Vector3(0.5, 9.0, w)
	b.box(Vector3(at.x, 18.0, at.y), size, "metal", Color(0.05, 0.06, 0.1), false)
	var lit := Vector3(w + 0.6, 0.22, 0.6) if along_x else Vector3(0.6, 0.22, w + 0.6)
	var strip := "neon_pink" if color == PINK else ("neon_cyan" if color == CYAN else "neon_amber")
	for dy: float in [-4.6, 4.6]:
		b.box(Vector3(at.x, 18.0 + dy, at.y), lit, strip, Color.WHITE, false)
	var big: String = SHOPS[int(_roll(seed_x, seed_z, 8.0) * SHOPS.size())]
	_signs.append([big, Vector3(at.x, 18.0, at.y) + _outward(yaw) * 0.5, color, yaw, 300])


func _outward(yaw: float) -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)


## Open ground in the grid: paths wide enough to drive, hedges and glowing trees to hide behind.
func _park(r: Rect2) -> void:
	_pavement(r, Color(0.24, 0.3, 0.3))
	_kerbs.append(r)
	b.add_footprint(r.get_center(), r.size, 0.0, "canopy")
	var c := r.get_center()
	for i in 5:
		for j in 5:
			var p := Vector3(r.position.x + 14.0 + i * (r.size.x - 28.0) / 4.0, 0, r.position.y + 14.0 + j * (r.size.y - 28.0) / 4.0)
			if (i + j) % 2 == 0:
				_glow_tree(p)
			elif i % 2 == 1:
				_hedge(p)
	b.add_prism(Vector3(c.x, 0, c.y), 7.0, 0.9, 16, "concrete", Color(0.4, 0.42, 0.5), 6.4)
	b.add_footprint(Vector2(c.x, c.y), Vector2(14, 14), 0.0, "cover")
	if not b.headless:
		b.add_prism(Vector3(c.x, 0.86, c.y), 6.0, 0.1, 16, "neon_cyan", Color.WHITE, -1.0, false)


func _glow_tree(p: Vector3) -> void:
	_trunk(p, 0.7)
	var k := 1.0 + _roll(p.x, p.z, 21.0) * 0.5
	props.stand("tree_oak", p, _roll(p.z, p.x, 22.0) * TAU, _leaf(p), Vector3(k, k, k))


func _hedge(p: Vector3) -> void:
	b.box(p + Vector3.UP * 0.58, Vector3(14, 1.15, 1.4), "", Color.WHITE)
	b.add_footprint(Vector2(p.x, p.z), Vector2(14, 1.4), 0.0, "cover")
	for dx: float in [-4.7, 0.0, 4.7]:
		props.stand("planter_bush", p + Vector3(dx, 0, 0), PI * 0.5, _leaf(p + Vector3(dx, 0, 0)))


func _leaf(p: Vector3) -> Color:
	return LEAVES[int(_roll(p.x, p.z, 23.0) * LEAVES.size())]


## Only the bottom of a tree is in anyone's way.
func _trunk(p: Vector3, width: float) -> void:
	b.box(p + Vector3.UP * 1.8, Vector3(width, 3.6, width), "", Color.WHITE)


## A tower going up: bare columns far enough apart to drive between, and a crane over them.
func _building_site(r: Rect2) -> void:
	_pavement(r, Color(0.34, 0.32, 0.3))
	var lot := r.grow(-SIDEWALK)
	var c := lot.get_center()
	b.add_footprint(c, lot.size, 0.0, "canopy")
	for i in range(-1, 2):
		for j in range(-1, 2):
			_low(Vector3(c.x + i * 24.0, 0, c.y + j * 26.0), Vector3(1.2, 40.0, 1.2), "concrete", Color(0.46, 0.46, 0.48))
	for y: float in [10.0, 20.0, 30.0, 40.0]:
		b.box(Vector3(c.x, y, c.y), Vector3(lot.size.x, 0.5, lot.size.y), "concrete", Color(0.42, 0.42, 0.46))
	for spec: Array in [[c.x - 16.0, c.y - 8.0], [c.x + 12.0, c.y + 14.0]]:
		_container(Vector3(spec[0], 0, spec[1]))
		_stack(Vector3(spec[0] + 8.0, 0, spec[1] + 2.0), 0.3, "wood", Color(0.46, 0.4, 0.34))
	b.box(Vector3(c.x, 65.0, c.y), Vector3(2.2, 90.0, 2.2), "metal", Color(0.76, 0.56, 0.2), false)
	b.box(Vector3(c.x + 24.0, 108.0, c.y), Vector3(72.0, 1.8, 1.8), "metal", Color(0.76, 0.56, 0.2), false)
	if not b.headless:
		b.box(Vector3(c.x + 58.0, 109.2, c.y), Vector3(1, 1, 1), "neon_pink", Color.WHITE, false)


# ---------------------------------------------------------------- the central square

func _square() -> void:
	_pavement(Rect2(-84, -58, 52, 116), Color(0.44, 0.46, 0.56))
	_pavement(Rect2(32, -58, 52, 116), Color(0.44, 0.46, 0.56))
	style = {"skirt": "metal", "rib": "panel", "tint": Color(0.62, 0.66, 0.82), "frame": "neon_pink"}
	for spec: Array in LOBBIES:
		style["frame"] = "neon_pink" if spec[2] == PINK else "neon_cyan"
		var doors := [door(7, 5.0), window(15), door(23, 5.0)]
		var sides := [door(9, 5.0), window(17), door(25, 5.0)]
		_room(spec[0], LOBBY_Y, "panel", WALL, {"n": doors, "s": doors, "w": sides, "e": sides}, "metal")
		_interior(spec[0])
	style = {}
	# The holo fountain breaks every line across the middle of the map.
	b.add_prism(Vector3(0, 0, 0), 9.0, 1.1, 14, "concrete", Color(0.5, 0.52, 0.6), 8.4)
	b.add_prism(Vector3(0, 1.1, 0), 3.2, 4.4, 10, "panel", Color(0.46, 0.5, 0.6), 2.2)
	b.add_footprint(Vector2.ZERO, Vector2(18, 18), 0.0, "landmark")
	for spec: Array in [[-38.0, 8.0, 5.0], [38.0, -8.0, 5.0], [-14.0, 40.0, 7.0], [14.0, -40.0, 7.0], [20.0, 12.0, 4.0], [-20.0, -12.0, 4.0]]:
		_planter(Vector3(spec[0], 0, spec[1]), spec[2])
	for spec: Array in [[-24.0, 26.0, 0.3], [24.0, -26.0, 0.3], [26.0, 34.0, 1.2], [-26.0, -34.0, 1.2]]:
		_car(Vector3(spec[0], 0, spec[1]), spec[2])
	for p: Vector3 in [Vector3(-44, 0, 6), Vector3(44, 0, -6), Vector3(-60, 0, -8), Vector3(60, 0, 8)]:
		_low(p, Vector3(2.4, 7.0, 2.4), "concrete", WALL.darkened(0.2))


## Half walls split a floor into shops, and counters give cover in each one.
func _interior(r: Rect2) -> void:
	var c := r.get_center()
	_wall_run(Vector2(r.position.x + 0.2, c.y), Vector2(r.end.x - 0.2, c.y), LOBBY_Y, "panel", WALL.darkened(0.12), [door(6, 5.0), door(15, 5.0), door(24, 5.0)], 0.3)
	b.box(Vector3(c.x, 0.14, c.y), Vector3(r.size.x - 0.5, 0.04, r.size.y - 0.5), "tiles", Color(0.7, 0.72, 0.8), false)
	for s: float in [-1.0, 1.0]:
		var z := c.y + s * 8.5
		_low(Vector3(c.x - 8.5, 0, z), Vector3(5, 1.1, 1.0), "panel", Color(0.5, 0.56, 0.66))
		_low(Vector3(c.x + 8.5, 0, z), Vector3(1.0, 1.1, 5), "panel", Color(0.5, 0.56, 0.66))
		_low(Vector3(c.x, 0, z + s * 2.5), Vector3(1.4, 2.2, 1.4), "concrete", WALL.darkened(0.2))


# ---------------------------------------------------------------- streets

## The elevated line runs the length of the boulevard. Its piers and flower beds split the road
## into two carriageways, each about 26 m wide.
func _median() -> void:
	b.box(Vector3(0, DECK_Y, 0), Vector3(9.0, 0.9, HALF.y * 2.0 + 120.0), "metal", Color(0.34, 0.36, 0.44))
	var z := -320.0
	while z <= 320.0:
		var clear := absf(z) < 66.0
		for cross: float in CROSS_Z:
			clear = clear or absf(z - cross) < CROSS + 3.0
		if not clear:
			_low(Vector3(0, 0, z), Vector3(2.6, DECK_Y, 2.6), "concrete", Color(0.42, 0.42, 0.5))
			_median_bed(Vector3(0, 0, z + 16.0))
		z += 32.0
	if b.headless:
		return
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(s * 4.6, DECK_Y - 0.6, 0), Vector3(0.14, 0.14, HALF.y * 2.0 + 120.0), "neon_cyan", Color.WHITE, false)
		b.box(Vector3(s * 4.2, DECK_Y + 1.1, 0), Vector3(0.24, 1.3, HALF.y * 2.0 + 120.0), "metal", Color(0.4, 0.42, 0.48), false)


func _median_bed(p: Vector3) -> void:
	b.box(p + Vector3.UP * 0.52, Vector3(2.2, 1.05, 12.0), "", Color.WHITE)
	b.add_footprint(Vector2(p.x, p.z), Vector2(2.2, 12.0), 0.0, "cover")
	for dz: float in [-3.6, 3.6]:
		var q := p + Vector3(0, 0, dz)
		props.stand("planter_bush", q, 0.0, _leaf(q), Vector3(1.9, 1.0, 0.96))
	props.stand("tree_slim", p, _roll(p.x, p.z, 24.0) * TAU, _leaf(p))


func _mirrored_cover() -> void:
	for spec: Array in STREET_COVER:
		var p := Vector3(spec[1], 0, spec[2])
		var yaw: float = spec[3]
		_cover(spec[0], p, yaw)
		_cover(spec[0], _point(p), yaw + PI)


func _cover(kind: String, p: Vector3, yaw: float) -> void:
	match kind:
		"barrier": _barrier(p, yaw)
		"bus": _bus(p, yaw)
		"wreck": _car(p, yaw)
		"container": _container(p, yaw)


func _barrier(p: Vector3, yaw: float) -> void:
	_low(p, Vector3(7.0, 1.15, 0.8), "", Color.WHITE, yaw)
	props.stand("barrier", p, yaw + PI * 0.5)


func _bus(p: Vector3, yaw: float) -> void:
	_low(p, Vector3(12.0, 3.0, 2.8), "", Color.WHITE, yaw)
	var paint := Color(0.08, 0.2, 0.42) if _roll(p.x, p.z, 10.0) < 0.5 else Color(0.42, 0.07, 0.12)
	props.stand("bus", p, yaw + PI * 0.5, paint)


func _street_furniture() -> void:
	# Parked cars along the kerbs, gaps where the rolls say so. Only half of them are ever there.
	var z := 96.0
	while z < 340.0:
		if absf(z - 240.0) > CROSS + 4.0:
			for x: float in [BOULEVARD - 2.6, -(BOULEVARD - 2.6), AVENUE_X + AVENUE - 2.6, AVENUE_X - AVENUE + 2.6, -(AVENUE_X + AVENUE - 2.6), -(AVENUE_X - AVENUE + 2.6)]:
				if absf(x) > 60.0 or z < 250.0:
					if _roll(x, z, 11.0) < 0.42:
						_car(Vector3(x, 0, z), PI * 0.5)
						_car(Vector3(-x, 0, -z), -PI * 0.5)
		z += 11.0
	for row: float in [80.0, 240.0]:
		var x := 40.0
		while x < 250.0:
			if absf(x - AVENUE_X) > AVENUE + 4.0:
				for side: float in [CROSS - 2.6, -(CROSS - 2.6)]:
					if _roll(x, row + side, 12.0) < 0.36:
						_car(Vector3(x, 0, row + side), 0.0)
						_car(Vector3(-x, 0, -row - side), PI)
			x += 11.0
	# Cover and life on the pavements of the boulevard and the avenues.
	for spec: Array in [[36.0, 110.0], [36.0, 150.0], [-36.0, 124.0], [-36.0, 190.0], [36.0, 204.0], [142.0, 110.0], [142.0, 40.0], [198.0, 130.0], [198.0, 30.0], [-142.0, 130.0], [-142.0, 30.0], [-198.0, 110.0], [-198.0, 200.0], [142.0, 196.0]]:
		var p := Vector3(spec[0], 0, spec[1])
		var pick := int(_roll(p.x, p.z, 13.0) * 3.0)
		for q: Vector3 in [p, _point(p)]:
			match pick:
				0: _kiosk(q)
				1: _planter(q, 5.0)
				2: _bus_stop(q, absf(q.x) < 150.0)


func _bus_stop(p: Vector3, along_z: bool) -> void:
	var size := Vector3(1.0, 2.6, 7.0) if along_z else Vector3(7.0, 2.6, 1.0)
	_low(p, size, "", Color.WHITE)
	_taken.append(Vector2(p.x, p.z))
	# The shelter opens towards the road it serves.
	var road: float = [0.0, AVENUE_X, -AVENUE_X].reduce(func(best: float, c: float) -> float: return c if absf(p.x - c) < absf(p.x - best) else best)
	var yaw := 0.0 if road > p.x else PI
	props.stand("bus_stop", p, yaw if along_z else yaw + PI * 0.5)


## Night stalls on the pavement round the two end flags, one more reason to fight for them.
func _flag_markets() -> void:
	for z: float in [40.0, 54.0, 110.0, 124.0]:
		for at: Vector3 in [Vector3(-143, 0, z), Vector3(-197, 0, z + 7.0)]:
			_stall(at, PI * 0.5 if at.x > -170.0 else -PI * 0.5)
			_stall(_point(at), -PI * 0.5 if at.x > -170.0 else PI * 0.5)


## Each side's terminal at the end of the boulevard: pads for the tanks and a line of barriers
## with gaps a tank can take without turning.
func _terminal(s: float) -> void:
	var tint := Color(0.36, 0.42, 0.56) if s > 0.0 else Color(0.5, 0.34, 0.38)
	_pavement(Rect2(-66, 262.0 if s > 0.0 else -350.0, 132, 88), tint)
	for x: float in [-58.0, -32.0, 32.0, 58.0]:
		_low(Vector3(x, 0, s * 266.0), Vector3(10.0, 1.3, 1.0), "concrete", Color(0.5, 0.5, 0.54))
	for x: float in [-64.0, 64.0]:
		for z: float in [280.0, 306.0, 332.0]:
			_container(Vector3(x, 0, s * z), PI * 0.5)
	if b.headless:
		return
	var strip := "neon_cyan" if s > 0.0 else "neon_pink"
	for x: float in [-55.0, -33.0, -11.0, 11.0, 33.0, 55.0]:
		for q: float in [-1.0, 1.0]:
			b.box(Vector3(x + q * 6.0, 0.14, s * 292.0), Vector3(0.2, 0.05, 15.0), strip, Color.WHITE, false)
	for x: float in [-66.0, 66.0]:
		b.box(Vector3(x, 13.0, s * 268.0), Vector3(1.4, 26.0, 1.4), "metal", tint, false)
		b.box(Vector3(x, 26.4, s * 268.0), Vector3(2.4, 0.8, 2.4), strip, Color.WHITE, false)


## Lane lines and zebra crossings. They carry no collision and exist only for the eye.
func _road_paint() -> void:
	if b.headless:
		return
	var dash := func(at: Vector3, along_z: bool) -> void:
		b.box(at + Vector3.UP * 0.02, Vector3(0.42, 0.04, 5.0) if along_z else Vector3(5.0, 0.04, 0.42), "concrete", PAINT, false)
	var z := -340.0
	while z < 340.0:
		var open := true
		for cross: float in CROSS_Z:
			open = open and absf(z - cross) > CROSS + 8.0
		if open:
			for x: float in [-22.0, -12.0, 12.0, 22.0, AVENUE_X - 8.0, AVENUE_X + 8.0, -AVENUE_X - 8.0, -AVENUE_X + 8.0]:
				dash.call(Vector3(x, 0, z), true)
		z += 13.0
	for row: float in CROSS_Z:
		var x := -250.0
		while x < 250.0:
			if absf(x) > BOULEVARD + 8.0 and absf(absf(x) - AVENUE_X) > AVENUE + 8.0:
				for side: float in [-7.0, 7.0]:
					dash.call(Vector3(x, 0, row + side), false)
			x += 13.0
		for cx: float in [0.0, -AVENUE_X, AVENUE_X]:
			var half := BOULEVARD if cx == 0.0 else AVENUE
			for s: float in [-1.0, 1.0]:
				_zebra(Vector3(cx, 0, row + s * (CROSS + 3.0)), half, true)
				_zebra(Vector3(cx + s * (half + 3.0), 0, row), CROSS, false)


func _zebra(at: Vector3, half: float, across_x: bool) -> void:
	var s := -half + 1.5
	while s < half - 1.0:
		var p := at + (Vector3(s, 0.02, 0) if across_x else Vector3(0, 0.02, s))
		b.box(p, Vector3(1.4, 0.04, 4.0) if across_x else Vector3(4.0, 0.04, 1.4), "concrete", PAINT, false)
		s += 3.0


## Lit arches high over the road at the big crossings. Everything clears a mech by a long way.
func _gantries() -> void:
	if b.headless:
		return
	for row: float in [-80.0, 80.0]:
		for cx: float in [-AVENUE_X, AVENUE_X]:
			var z := row - signf(row) * (CROSS + 8.0)
			var strip := "neon_pink" if cx * row > 0.0 else "neon_cyan"
			for s: float in [-1.0, 1.0]:
				b.box(Vector3(cx + s * (AVENUE + 2.0), 6.0, z), Vector3(0.7, 12.0, 0.7), "metal", GREY, false)
			b.box(Vector3(cx, 11.6, z), Vector3(AVENUE * 2.0 + 5.0, 0.9, 0.9), "metal", GREY, false)
			b.box(Vector3(cx, 11.0, z), Vector3(AVENUE * 2.0 + 4.0, 0.14, 0.14), strip, Color.WHITE, false)


## The skyline beyond the map and the wall of city at its edge. Nobody comes near either, so they
## are drawn as one batch per material, like a backdrop, instead of in thirty pieces.
func _distant_city() -> void:
	b.batch_tag = "far"
	for i in 44:
		var a := TAU * i / 44.0
		var p := Vector3(sin(a) * 440.0, 0, cos(a) * 540.0)
		_far_tower(p, Vector3(46 + _roll(p.x, p.z, 14.0) * 30.0, 90 + _roll(p.x, p.z, 15.0) * 190.0, 46 + _roll(p.x, p.z, 16.0) * 30.0))
	b.batch_tag = ""


# ---------------------------------------------------------------- props

func _far_tower(p: Vector3, size: Vector3) -> void:
	b.box(p + Vector3.UP * size.y * 0.5, size, "facade_night", Color(0.85, 0.9, 1.0), false)
	if b.headless:
		return
	var strip := "neon_cyan" if int(absf(p.x + p.z)) % 2 == 0 else "neon_pink"
	for s: float in [-1.0, 1.0]:
		b.box(p + Vector3(s * (size.x * 0.5 + 0.1), size.y * 0.5, size.z * 0.5), Vector3(0.25, size.y, 0.25), strip, Color.WHITE, false)
	b.box(p + Vector3(0, size.y + 0.4, 0), Vector3(size.x + 1.0, 0.8, size.z + 1.0), "metal", Color(0.2, 0.24, 0.3), false)


## A grounded hover car: chest-high at the body, a little more at the roof.
func _car(p: Vector3, yaw: float) -> void:
	var axis := Basis(Vector3.UP, yaw)
	var roll := _roll(p.x, p.z, 17.0)
	var paint: Color = PAINTS[int(_roll(p.x, p.z, 25.0) * PAINTS.size())]
	if roll < 0.24:
		_low(p, Vector3(4.9, 2.05, 2.0), "", Color.WHITE, yaw)
		props.stand("car_van", p, yaw + PI * 0.5, paint)
		return
	_low(p, Vector3(4.6, 0.95, 2.0), "", Color.WHITE, yaw)
	b.box(p + axis * Vector3(-0.2, 1.2, 0), Vector3(2.0, 0.5, 1.6), "", Color.WHITE, true, yaw)
	props.stand("car_sport" if roll < 0.42 else "car_sedan", p, yaw + PI * 0.5, paint)


func _planter(p: Vector3, length: float) -> void:
	_low(p, Vector3(length, 1.05, 1.1), "", Color.WHITE)
	_taken.append(Vector2(p.x, p.z))
	props.stand("planter_bush", p, PI * 0.5, _leaf(p), Vector3(1.0, 1.0, length / 5.0))


func _kiosk(p: Vector3) -> void:
	_low(p, Vector3(3.0, 2.5, 2.4), "", Color.WHITE)
	_taken.append(Vector2(p.x, p.z))
	props.stand("kiosk", p, 0.0 if p.z < 0.0 else PI, PAINTS[int(_roll(p.x, p.z, 26.0) * PAINTS.size())])


func _dumpster(p: Vector3, yaw: float) -> void:
	_low(p, Vector3(2.5, 1.4, 1.7), "", Color.WHITE, yaw)
	props.stand("dumpster", p, yaw, Color(0.1, 0.26, 0.18) if _roll(p.x, p.z, 27.0) < 0.5 else Color(0.34, 0.2, 0.08))


## Palms down the boulevard, street trees on the rest, with lamps between them.
func _plant_kerbs() -> void:
	for r: Rect2 in _kerbs:
		var near := r.grow(-SIDEWALK * 0.5)
		var far := r.grow(-0.9)
		for edge: Array in [[Vector2(near.position.x, near.position.y), Vector2(near.end.x, near.position.y), far.position.y, true, 0.0], [Vector2(near.position.x, near.end.y), Vector2(near.end.x, near.end.y), far.end.y, true, PI],
				[Vector2(near.position.x, near.position.y), Vector2(near.position.x, near.end.y), far.position.x, false, -PI * 0.5], [Vector2(near.end.x, near.position.y), Vector2(near.end.x, near.end.y), far.end.x, false, PI * 0.5]]:
			var a: Vector2 = edge[0]
			var c: Vector2 = edge[1]
			if absf(a.x) > HALF.x - SIDEWALK or absf(a.y) > HALF.y - SIDEWALK or (not edge[3] and absf(a.x) > HALF.x - 8.0):
				continue
			if edge[3] and absf(a.y) > HALF.y - 8.0:
				continue
			var length := a.distance_to(c)
			var count := int(length / 22.0)
			for i in count:
				var spot := a.lerp(c, (i + 0.5) / count)
				if i % 2 == 0:
					_kerb_tree(spot)
				else:
					var lamp := Vector3(spot.x, 0, edge[2]) if edge[3] else Vector3(edge[2], 0, spot.y)
					_kerb_lamp(lamp, edge[4])


func _kerb_tree(spot: Vector2) -> void:
	for other: Vector2 in _taken:
		if other.distance_to(spot) < 7.0:
			return
	var p := Vector3(spot.x, 0, spot.y)
	_trunk(p, 0.5)
	var roll := _roll(spot.x, spot.y, 28.0)
	var prop := "tree_palm" if absf(spot.x) < 60.0 else ("tree_slim" if roll < 0.6 else "tree_oak")
	var k := 0.85 + _roll(spot.y, spot.x, 29.0) * 0.3
	props.stand(prop, p, roll * TAU, _leaf(p), Vector3(k, k, k))
	if not b.headless:
		b.box(p + Vector3.UP * 0.13, Vector3(1.8, 0.04, 1.8), "metal", Color(0.12, 0.13, 0.15), false)


## `over_road` is the yaw that swings the lamp's arm out over the carriageway.
func _kerb_lamp(p: Vector3, over_road: float) -> void:
	props.stand("lamp_city", p, over_road - PI * 0.5)


## At every crossing the signals hang out over the road from two opposite corners.
func _traffic_lights() -> void:
	for z: float in CROSS_Z:
		for cx: float in [-AVENUE_X, 0.0, AVENUE_X]:
			var half := BOULEVARD if cx == 0.0 else AVENUE
			props.stand("traffic_light", Vector3(cx + half + 1.4, 0, z + CROSS + 1.4), 0.0)
			props.stand("traffic_light", Vector3(cx - half - 1.4, 0, z - CROSS - 1.4), PI)
			props.stand("traffic_light", Vector3(cx + half + 1.4, 0, z - CROSS - 1.4), -PI * 0.5)
			props.stand("traffic_light", Vector3(cx - half - 1.4, 0, z + CROSS + 1.4), PI * 0.5)


func _stall(p: Vector3, yaw: float) -> void:
	var axis := Basis(Vector3.UP, yaw)
	_low(p, Vector3(5.0, 1.15, 1.6), "wood", Color(0.46, 0.38, 0.32), yaw)
	if b.headless:
		return
	var red := _roll(p.x, p.z, 18.0) < 0.5
	for s: float in [-1.0, 1.0]:
		b.box(p + axis * Vector3(s * 2.4, 1.4, 0.8), Vector3(0.14, 2.8, 0.14), "metal", Color(0.3, 0.32, 0.36), false, yaw)
	b.box(p + axis * Vector3(0, 2.85, 0.2), Vector3(5.5, 0.12, 2.8), "fabric", Color(0.34, 0.1, 0.22) if red else Color(0.08, 0.22, 0.3), false, yaw)
	b.box(p + axis * Vector3(0, 2.72, 1.55), Vector3(5.4, 0.1, 0.08), "neon_pink" if red else "neon_cyan", Color.WHITE, false, yaw)


func _container(p: Vector3, yaw := 0.0) -> void:
	_low(p, Vector3(6.0, 2.7, 3.2), "", Color.WHITE, yaw)
	var tint: Color = [Color(0.56, 0.2, 0.08), Color(0.08, 0.26, 0.4), Color(0.1, 0.3, 0.2), Color(0.5, 0.42, 0.1)][int(_roll(p.x, p.z, 19.0) * 4.0)]
	props.stand("container", p, yaw + PI * 0.5, tint)


# ---------------------------------------------------------------- view only

func _lobby_dressing(parent: Node3D, r: Rect2, title: String, color: Color) -> void:
	var c := r.get_center()
	var toward := -signf(c.y)
	var face := r.position.y if toward < 0.0 else r.end.y
	var strip := "neon_pink" if color == PINK else "neon_cyan"
	_sign(parent, title, Vector3(c.x, 4.2, face + toward * 0.3), color, PI if toward < 0.0 else 0.0, 110)
	_fill_light(parent, Vector3(c.x, 3.6, c.y), color, 22, 1.8)
	b.box(Vector3(c.x, 5.85, face + toward * 0.3), Vector3(r.size.x, 0.12, 0.12), strip, Color.WHITE, false)
	life.add_steam(Vector3(c.x - 8, LOBBY_Y + 0.4, c.y - 8), Color(0.7, 0.75, 0.9), 2.4)


func _square_dressing(parent: Node3D) -> void:
	var holo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 4.2
	ring.outer_radius = 4.5
	ring.ring_segments = 8
	ring.rings = 40
	holo.mesh = ring
	holo.material_override = Mats.glow(CYAN, 2.4)
	holo.position = Vector3(0, 8.5, 0)
	holo.rotation.x = 0.5
	holo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(holo)
	life.add_spin(holo, 0.6)
	_sign(parent, "SEKTOR 07", Vector3(0, 6.6, 3.4), CYAN, 0.0, 130)
	_sign(parent, "SEKTOR 07", Vector3(0, 6.6, -3.4), CYAN, PI, 130)
	life.add_pulse(_fill_light(parent, Vector3(0, 8, 0), CYAN, 44, 2.2), 5.0, 9.0, 4.0)


## A few strong lamps at the crossings carry the night; the neon does the rest.
func _street_lights(parent: Node3D) -> void:
	var colors := [PINK, CYAN, AMBER]
	var i := 0
	for z: float in CROSS_Z:
		for x: float in [-AVENUE_X, 0.0, AVENUE_X]:
			_fill_light(parent, Vector3(x + 10.0, 9.0, z), colors[i % 3], 62, 2.2)
			i += 1
	for z: float in [-160.0, 160.0, 0.0]:
		for x: float in [-AVENUE_X, AVENUE_X, 16.0, -16.0]:
			if z != 0.0 or absf(x) > 100.0:
				_fill_light(parent, Vector3(x, 8.0, z), colors[i % 3], 56, 1.8)
				i += 1
	for s: float in [-1.0, 1.0]:
		_fill_light(parent, Vector3(0, 12, s * 300.0), CYAN if s > 0.0 else PINK, 80, 2.4)


func _traffic() -> void:
	# The maglev runs the length of the boulevard above the fighting.
	var train := Node3D.new()
	var skin := Forge.mesh("maglev", _maglev)
	var body := MeshInstance3D.new()
	body.mesh = skin
	body.material_override = Forge.skin(C.Team.EMPIRE)
	body.rotation.y = PI * 0.5
	train.add_child(body)
	life.add_shuttle(train, Vector3(0, DECK_Y + 2.2, 460), Vector3(0, DECK_Y + 2.2, -460), 34.0, 14.0, "maglev")
	# Air traffic in lanes over the avenues, well above any building you can reach.
	for i in 6:
		var car := Node3D.new()
		var lit := CYAN if i % 2 == 0 else PINK
		P.box(car, Vector3(1.8, 0.6, 4.2), Vector3.ZERO, Mats.flat(Color(0.14, 0.15, 0.2), 0.4, 0.6))
		P.box(car, Vector3(1.7, 0.16, 0.16), Vector3(0, 0, 2.15), Mats.glow(Color(1, 0.95, 0.85), 5.0))
		P.box(car, Vector3(1.7, 0.16, 0.16), Vector3(0, 0, -2.15), Mats.glow(lit, 5.0))
		var x: float = [-AVENUE_X, AVENUE_X, 20.0][i % 3]
		var y := 34.0 + i * 7.0
		var way := 1.0 if i < 3 else -1.0
		life.add_shuttle(car, Vector3(x + way * 6.0, y, way * 460.0), Vector3(x + way * 6.0, y, -way * 460.0), 19.0 + i * 3.0, 15.0 + i)
	for i in 4:
		var drone := Node3D.new()
		var lamp := SpotLight3D.new()
		lamp.light_color = Color(0.7, 0.9, 1.0)
		lamp.light_energy = 8.0
		lamp.spot_range = 40.0
		lamp.spot_angle = 24.0
		lamp.rotation.x = -PI * 0.5
		drone.add_child(lamp)
		P.box(drone, Vector3(0.9, 0.22, 0.9), Vector3.ZERO, Mats.flat(Color(0.14, 0.15, 0.2), 0.4, 0.6))
		P.box(drone, Vector3(0.18, 0.1, 0.18), Vector3(0, -0.14, 0), Mats.glow(PINK if i == 1 else CYAN, 3.0))
		life.add_orbit(drone, Vector3([-AVENUE_X, 18.0, AVENUE_X, -18.0][i], 20.0, [80.0, 0.0, -80.0, 160.0][i]), Vector2(26, 30), 26.0 + i * 5.0)


func _maglev(k: Forge) -> void:
	var shell := Forge.tone(Color(0.36, 0.4, 0.48))
	var lit := Forge.lamp(CYAN, 4.0)
	for i in 3:
		var x := -22.0 + i * 22.0
		k.slab(Vector3(20, 3.0, 3.4), Vector3(x, 0, 0), shell, Vector3.ZERO, 0.2)
		k.slab(Vector3(18, 0.7, 3.5), Vector3(x, 0.45, 0), lit, Vector3.ZERO, 0.04)


## The rain falls round the player: a storm over the whole map would be far too many drops.
func _rain(parent: Node3D) -> void:
	var rain := GPUParticles3D.new()
	rain.name = "CityRain"
	rain.amount = 2600
	rain.lifetime = 1.4
	rain.preprocess = 1.4
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-70, -50, -70), Vector3(140, 60, 140))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(60, 1, 60)
	process.direction = Vector3(0.08, -1, 0.04)
	process.spread = 2.0
	process.initial_velocity_min = 22.0
	process.initial_velocity_max = 28.0
	process.gravity = Vector3(0, -6, 0)
	rain.process_material = process
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.014, 0.6, 0.014)
	mesh.material = Mats.glow(Color(0.5, 0.7, 1.0), 0.5)
	rain.draw_pass_1 = mesh
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rain)
	life.add_follower(rain, Vector3(0, 32, 0))
