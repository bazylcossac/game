class_name StationMap
extends CombatArena
## Stacja Rdzeń: a sealed station round a reactor. Each wing has its own colour so nobody gets
## lost: blue cryo rooms in the west, amber cargo hold in the east, cyan reactor in the middle.
## A gallery runs above the reactor hall.
## Props are adapted from Godot's TPS demo (CC BY 3.0).

const HALF := Vector2(48, 62)
const CEILING := 7.0
const GALLERY_Y := 3.6
const WALL := Color(0.62, 0.66, 0.72)
const CYAN := Color(0.15, 0.85, 1.0)
const AMBER := Color(1.0, 0.62, 0.2)
const ICE := Color(0.5, 0.75, 1.0)
const RED := Color(1.0, 0.18, 0.14)

var _props: Array[Array] = []
var _spinner: Node3D


func climate_of() -> Dictionary:
	return {"wet": 0.22, "grime": 0.25}


func bound() -> Vector2:
	return HALF


func view_range() -> float:
	return 110.0


func bases() -> Array:
	return [Vector3(0, 0, 54), Vector3(0, 0, -54)]


func team_spawns(team: int) -> Array[Vector3]:
	var z := 55.0 if team == 0 else -55.0
	return [Vector3(-38, 0, z), Vector3(-18, 0, z), Vector3(0, 0, z), Vector3(18, 0, z), Vector3(38, 0, z)]


func free_spawns() -> Array[Vector3]:
	var out: Array[Vector3] = team_spawns(0)
	out.append_array(team_spawns(1))
	out.append_array([Vector3(-30, 0, 20), Vector3(29, 0, 15), Vector3(-30, 0, -20), Vector3(29, 0, -15), Vector3(0, 0, 30), Vector3(0, 0, -30)])
	return out


func flag_defs() -> Array:
	return [
		{"name": "Kriogenika", "letter": "A", "pos": Vector3(-31, 0, 31), "owner": 0},
		{"name": "Ładownia", "letter": "B", "pos": Vector3(31, 0, 6), "owner": -1},
		{"name": "Rdzeń", "letter": "C", "pos": Vector3(0, 0, 11), "owner": -1},
		{"name": "Serwerownia", "letter": "D", "pos": Vector3(-31, 0, -6), "owner": -1},
		{"name": "Dok", "letter": "E", "pos": Vector3(31, 0, -33), "owner": 1},
	]


func hotspots() -> Array[Vector3]:
	return [Vector3(-31, 0, 31), Vector3(31, 0, 6), Vector3(0, 0, 11), Vector3(-31, 0, -6), Vector3(31, 0, -33), Vector3(0, 0, 30), Vector3(0, 0, -30), Vector3(-12, 0, 0), Vector3(12, 0, 0)]


func street_rects() -> Array[Rect2]:
	return [Rect2(-46, -60, 92, 16), Rect2(-46, 44, 92, 16), Rect2(-6, -44, 12, 88), Rect2(-16, -16, 32, 32)]


func _build_ground(_parent: Node3D, _headless: bool) -> void:
	b.box(Vector3(0, -0.3, 0), Vector3(HALF.x * 2.0 + 6.0, 0.6, HALF.y * 2.0 + 6.0), "deck", Color(0.82, 0.86, 0.92))


func build(parent: Node3D, map_seed: int, headless: bool) -> void:
	super.build(parent, map_seed, headless)
	if headless:
		return
	for spec: Array in _props:
		var scene: PackedScene = load("res://assets/models/tps/%s.glb" % spec[0])
		var root := scene.instantiate() as Node3D
		parent.add_child(root)
		root.position = spec[1]
		root.scale = spec[2]
	life = MapLife.new()
	parent.add_child(life)
	_reactor_life(parent)
	_wing_lights(parent)
	_signs(parent)
	_sign(parent, "Modele: Juan Linietsky, Fernando Miguel Calabró / Godot TPS Demo / CC BY 3.0", Vector3(0, 3.1, 61.5), Color(0.55, 0.7, 0.8), PI, 24)


func _build_scenery() -> void:
	style = {"skirt": "metal", "rib": "metal", "tint": Color(0.7, 0.74, 0.8), "frame": "neon_cyan"}
	_shell()
	_reactor_hall()
	_service_corridors()
	style["frame"] = "station_light"
	_cryo_wing()
	style["frame"] = "amber_light"
	_cargo_hold()
	_docks()
	style = {}
	_floor_markings()


func _shell() -> void:
	var w := HALF.x
	var d := HALF.y
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(s * (w + 0.5), CEILING * 0.5, 0), Vector3(1, CEILING, d * 2.0 + 2.0), "panel", WALL)
		b.box(Vector3(0, CEILING * 0.5, s * (d + 0.5)), Vector3(w * 2.0 + 2.0, CEILING, 1), "panel", WALL)
	b.box(Vector3(0, CEILING + 0.2, 0), Vector3(w * 2.0 + 2.0, 0.4, d * 2.0 + 2.0), "metal", Color(0.5, 0.52, 0.56))
	# Ceiling ribs with light strips, in the colour of the wing below.
	for z in range(-56, 57, 8):
		for spec: Array in [[-31.0, "station_light"], [0.0, "neon_cyan"], [31.0, "amber_light"]]:
			b.box(Vector3(spec[0], CEILING - 0.3, z), Vector3(22, 0.1, 0.5), spec[1], Color.WHITE, false)
		b.box(Vector3(0, CEILING - 0.15, z), Vector3(w * 2.0, 0.3, 0.9), "metal", Color(0.4, 0.44, 0.5), false)


func _reactor_hall() -> void:
	# The hall walls: four doorways, and windows onto both wings.
	_wall_run(Vector2(-16, -16), Vector2(16, -16), CEILING, "panel", WALL, [door(16, 5.0)])
	_wall_run(Vector2(-16, 16), Vector2(16, 16), CEILING, "panel", WALL, [door(16, 5.0)])
	_wall_run(Vector2(-16, -16), Vector2(-16, 16), CEILING, "panel", WALL, [window(5), door(10), door(22), window(27)])
	_wall_run(Vector2(16, -16), Vector2(16, 16), CEILING, "panel", WALL, [window(5), door(10), door(22), window(27)])
	# The reactor itself, with a safety ring that gives waist-high cover all the way round.
	b.add_prism(Vector3.ZERO, 5.2, 1.0, 14, "metal", Color(0.42, 0.48, 0.56), 4.8)
	b.add_prism(Vector3.UP, 3.2, CEILING - 1.0, 14, "reactor_glass", Color.WHITE, 3.2)
	b.add_footprint(Vector2.ZERO, Vector2(10.4, 10.4), 0.0, "landmark")
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		var p := Vector3(cos(a) * 9.5, 0, sin(a) * 9.5)
		_low(p, Vector3(4.0, 1.15, 0.9), "panel", Color(0.46, 0.52, 0.6), -a + PI * 0.5)
	for p: Vector3 in [Vector3(-13, 0, -13), Vector3(13, 0, -13), Vector3(-13, 0, 13), Vector3(13, 0, 13)]:
		_low(p, Vector3(2.0, CEILING, 2.0), "panel", WALL.darkened(0.2))
	# Gallery along both long sides, reached by ramps at opposite corners.
	for s: float in [-1.0, 1.0]:
		var x0 := -15.8 if s < 0.0 else 12.0
		_deck(Rect2(x0, -15.8, 3.8, 31.6), GALLERY_Y, "deck", Color(0.6, 0.64, 0.7))
		var edge := s * 12.0
		_rail(Vector2(edge, -15.8), Vector2(edge, -6.0), GALLERY_Y, "panel", WALL)
		_rail(Vector2(edge, 6.0), Vector2(edge, 15.8), GALLERY_Y, "panel", WALL)
	_ramp(Vector3(-10.2, 0, -12.0), Vector2(0, 1), GALLERY_Y, 2.4, "deck", Color(0.5, 0.54, 0.6))
	_ramp(Vector3(10.2, 0, 12.0), Vector2(0, -1), GALLERY_Y, 2.4, "deck", Color(0.5, 0.54, 0.6))
	_deck(Rect2(-12.0, -6.0 + 0.3, 3.0, 3.0), GALLERY_Y, "deck", Color(0.6, 0.64, 0.7))
	_deck(Rect2(9.0, 2.7, 3.0, 3.0), GALLERY_Y, "deck", Color(0.6, 0.64, 0.7))
	_prop("gas_tank", Vector3(-9, 0, 14.2), Vector3(1.6, 3.0, 1.6))
	_prop("gas_tank", Vector3(9, 0, -14.2), Vector3(1.6, 3.0, 1.6))


func _service_corridors() -> void:
	# Two straight corridors link the docks to the hall, each with a side bay half way.
	for s: float in [-1.0, 1.0]:
		var z0 := s * 16.0
		var z1 := s * 44.0
		for x: float in [-6.0, 6.0]:
			_wall_run(Vector2(x, z0), Vector2(x, z1), CEILING, "panel", WALL, [door(14.0, 4.0)])
		_low(Vector3(-2.2, 0, s * 25.0), Vector3(3.2, 1.15, 0.9), "panel", Color(0.46, 0.5, 0.58))
		_low(Vector3(2.4, 0, s * 33.0), Vector3(3.0, 1.15, 0.9), "panel", Color(0.46, 0.5, 0.58))
		_low(Vector3(-2.8, 0, s * 40.0), Vector3(2.2, 1.15, 0.9), "panel", Color(0.46, 0.5, 0.58))


func _cryo_wing() -> void:
	# Rows of cryo pods make aisles; the far ends are server rooms.
	for s: float in [-1.0, 1.0]:
		_wall_run(Vector2(-46, s * 16.0), Vector2(-16, s * 16.0), CEILING, "panel", WALL, [door(8), window(15), door(23)])
		_wall_run(Vector2(-46, s * 44.0), Vector2(-6, s * 44.0), CEILING, "panel", WALL, [door(8), door(23), door(34)])
		for x: float in [-42.0, -36.0, -26.0, -20.0]:
			for z: float in [22.0, 31.0, 39.0]:
				_pod(Vector3(x, 0, s * z))
		_low(Vector3(-31, 0, s * 26.0), Vector3(1.0, 1.15, 4.0), "panel", Color(0.46, 0.5, 0.58))
	for x: float in [-41.0, -33.0, -21.0]:
		_rack(Vector3(x, 0, 5.0), 4.0)
		_rack(Vector3(x, 0, -5.0), 4.0)
	_low(Vector3(-27, 0, 0), Vector3(3.0, 1.15, 1.0), "panel", Color(0.46, 0.5, 0.58))
	_low(Vector3(-37, 0, 0), Vector3(1.0, 1.15, 3.0), "panel", Color(0.46, 0.5, 0.58))


func _cargo_hold() -> void:
	for s: float in [-1.0, 1.0]:
		_wall_run(Vector2(6, s * 44.0), Vector2(46, s * 44.0), CEILING, "panel", WALL, [door(12), door(27), door(36)])
	# A maze of containers, staggered so no aisle runs the length of the hold.
	for spec: Array in [[22.0, 36.0, 0.0], [34.0, 39.0, 1.57], [41.0, 30.0, 0.0], [24.0, 24.0, 1.57], [33.0, 21.0, 0.0], [42.0, 15.0, 1.57],
			[22.0, 9.0, 0.0], [38.0, 0.0, 0.0], [22.0, -9.0, 0.0], [42.0, -15.0, 1.57], [33.0, -21.0, 0.0], [24.0, -24.0, 1.57], [41.0, -30.0, 0.0], [34.0, -39.0, 1.57], [22.0, -36.0, 0.0]]:
		_box_container(Vector3(spec[0], 0, spec[1]), spec[2])
	for p: Vector3 in [Vector3(28, 0, 30), Vector3(38, 0, 8), Vector3(28, 0, -3), Vector3(38, 0, -8), Vector3(28, 0, -30), Vector3(20, 0, 16)]:
		_stack(p, 0.3, "metal", Color(0.56, 0.44, 0.28))
	_prop("cargo", Vector3(44, 0, 42), Vector3(3.2, 2.2, 2.6))
	_prop("cargo", Vector3(44, 0, -42), Vector3(3.2, 2.2, 2.6))


func _docks() -> void:
	for s: float in [-1.0, 1.0]:
		var z := s * 49.0
		for x: float in [-37.0, -23.0, -10.0, 10.0, 23.0, 37.0]:
			_low(Vector3(x, 0, z), Vector3(4.0, 1.2, 1.0), "panel", Color(0.46, 0.5, 0.58))
		_prop("machine", Vector3(-44, 0, s * 57.0), Vector3(5, 3.6, 3))
		_prop("machine", Vector3(44, 0, s * 57.0), Vector3(5, 3.6, 3))


## Painted guide lines in each wing's colour: a player always knows which way the core is.
func _floor_markings() -> void:
	if b.headless:
		return
	for z in range(-56, 57, 4):
		for spec: Array in [[-31.0, Color(0.5, 0.75, 1.0)], [31.0, Color(1.0, 0.68, 0.24)]]:
			b.box(Vector3(spec[0], 0.02, z), Vector3(0.3, 0.03, 2.4), "arena_paint", spec[1], false)
	for s: float in [-1.0, 1.0]:
		for x in range(-44, 45, 2):
			b.box(Vector3(x, 0.02, s * 44.8), Vector3(1.0, 0.03, 0.5), "arena_paint", Color(0.9, 0.7, 0.14), false)
			b.box(Vector3(x + 1.0, 0.02, s * 44.8), Vector3(1.0, 0.03, 0.5), "arena_paint", Color(0.1, 0.1, 0.1), false)


func _pod(p: Vector3) -> void:
	_low(p, Vector3(2.4, 2.3, 1.6), "panel", Color(0.54, 0.6, 0.68))
	if not b.headless:
		for s: float in [-1.0, 1.0]:
			b.box(p + Vector3(0, 1.45, s * 0.81), Vector3(1.3, 1.0, 0.05), "window_blue", Color.WHITE, false)
			b.box(p + Vector3(0, 2.05, s * 0.82), Vector3(1.6, 0.14, 0.08), "metal", Color(0.6, 0.64, 0.7), false)
			b.box(p + Vector3(0, 0.85, s * 0.82), Vector3(1.6, 0.14, 0.08), "metal", Color(0.6, 0.64, 0.7), false)
			b.box(p + Vector3(0, 0.45, s * 0.82), Vector3(0.7, 0.05, 0.05), "neon_cyan", Color.WHITE, false)


func _rack(p: Vector3, length: float) -> void:
	_low(p, Vector3(1.0, 2.6, length), "metal", Color(0.3, 0.34, 0.4))
	if not b.headless:
		for y: float in [0.7, 1.3, 1.9]:
			for sx: float in [-0.52, 0.52]:
				b.box(p + Vector3(sx, y, 0), Vector3(0.04, 0.06, length - 0.4), "neon_cyan", Color.WHITE, false)


func _box_container(p: Vector3, yaw: float) -> void:
	var tint := Color(0.86, 0.52, 0.2) if rng.randf() < 0.5 else Color(0.4, 0.6, 0.72)
	_low(p, Vector3(6.4, 2.8, 3.0), "metal", tint, yaw)
	if not b.headless:
		var axis := Basis(Vector3.UP, yaw)
		for x: float in [-2.5, -1.25, 0.0, 1.25, 2.5]:
			b.box(p + axis * Vector3(x, 1.4, 0), Vector3(0.24, 2.6, 3.1), "metal", tint.darkened(0.2), false, yaw)


func _prop(id: String, foot: Vector3, size: Vector3) -> void:
	# Exported props have normalized bounds: bottom-centred with size (1,1,1).
	_props.append([id, foot, size])
	b.box(foot + Vector3.UP * size.y * 0.5, size, "", Color.WHITE)
	b.add_footprint(Vector2(foot.x, foot.z), Vector2(size.x, size.z), 0.0, "cover")


func _reactor_life(parent: Node3D) -> void:
	# Three rings turn round the core, and the alarm light breathes with it.
	for i in 3:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 3.45
		mesh.outer_radius = 3.7
		mesh.rings = 40
		mesh.ring_segments = 8
		ring.mesh = mesh
		ring.material_override = Mats.glow(CYAN, 1.8)
		ring.position = Vector3(0, 1.8 + i * 1.7, 0)
		ring.rotation.z = 0.12 * (i - 1)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ring)
		life.add_spin(ring, 0.5 * (1.0 if i % 2 == 0 else -1.0))
	life.add_pulse(_fill_light(parent, Vector3(0, 4, 0), CYAN, 24, 3.0), 6.0, 12.0, 5.0)
	life.add_steam(Vector3(-13, 0.2, 7), Color(0.7, 0.85, 1.0), 2.0)
	life.add_steam(Vector3(13, 0.2, -7), Color(0.7, 0.85, 1.0), 2.0)
	life.add_steam(Vector3(44, 0.2, 2), Color(1.0, 0.8, 0.6), 2.6)
	life.add_steam(Vector3(-44, 0.2, -2), Color(0.6, 0.8, 1.0), 2.6)


func _wing_lights(parent: Node3D) -> void:
	for z: float in [-52.0, -30.0, -6.0, 6.0, 30.0, 52.0]:
		_fill_light(parent, Vector3(-31, 5.4, z), ICE, 22, 1.5)
		_fill_light(parent, Vector3(31, 5.4, z), AMBER, 22, 1.7)
	for z: float in [-30.0, 30.0]:
		_fill_light(parent, Vector3(0, 5.4, z), Color(0.8, 0.9, 1.0), 18, 1.4)
	for x: float in [-30.0, 0.0, 30.0]:
		life.add_pulse(_fill_light(parent, Vector3(x, 5.2, -54), RED, 20, 1.2), 2.0, 5.0, 3.0)
		_fill_light(parent, Vector3(x, 5.2, 54), Color(0.3, 0.6, 1.0), 20, 1.2)


func _signs(parent: Node3D) -> void:
	_sign(parent, "RDZEŃ 03", Vector3(0, 5.4, 15.7), CYAN, 0.0, 110)
	_sign(parent, "RDZEŃ 03", Vector3(0, 5.4, -15.7), CYAN, PI, 110)
	_sign(parent, "KRIOGENIKA", Vector3(-31, 4.4, 43.7), ICE, 0.0, 90)
	_sign(parent, "SERWEROWNIA", Vector3(-31, 4.4, 15.7), ICE, 0.0, 90)
	_sign(parent, "ŁADOWNIA", Vector3(31, 4.4, 43.7), AMBER, 0.0, 90)
	_sign(parent, "SEKTOR A", Vector3(-31, 4.4, -43.7), RED, PI, 90)
	_sign(parent, "SEKTOR B", Vector3(31, 4.4, -43.7), RED, PI, 90)
