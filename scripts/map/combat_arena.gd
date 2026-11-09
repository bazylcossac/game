class_name CombatArena
extends MapKit
## Building blocks of the compact arenas: walls with real openings, rooms to walk through,
## decks and ramps for a second level, and cover. Bots walk the ground plane, so every
## objective stays down there and the upper level is a choice for human players.
## Geometry, collision and nav are built identically on clients and dedicated servers.

const DOOR_W := 3.2
const DOOR_H := 2.7
const SILL := 1.05
const HEAD := 2.45

## Lamps are specified by feel; this is how bright a feel of 1 has to be to read at night.
const LIGHT_GAIN := 3.0

## How walls are finished, so a slab reads as architecture: "skirt", "rib" and "tint" for the
## base and the pilasters, and "frame" for the lit edge of every door and window.
var style := {}


func coin_area() -> Vector2:
	return bound() - Vector2(8, 8)


## A compact arena has one flat floor rather than the 520 m battlefield terrain.
func ground_height(_x: float, _z: float) -> float:
	return 0.0


func _build_skyline() -> void:
	pass


## Solid wall from a to c. Each hole is [metres along the wall, width, bottom, top].
func _wall_run(a: Vector2, c: Vector2, h: float, mat: String, tint: Color, holes: Array = [], thick := 0.4, base := 0.0) -> void:
	var length := a.distance_to(c)
	var dir := (c - a) / length
	var yaw := atan2(-dir.y, dir.x)
	var piece := func(s0: float, s1: float, y0: float, y1: float) -> void:
		if s1 - s0 < 0.05 or y1 - y0 < 0.05:
			return
		var mid := a + dir * ((s0 + s1) * 0.5)
		b.box(Vector3(mid.x, base + (y0 + y1) * 0.5, mid.y), Vector3(s1 - s0, y1 - y0, thick), mat, tint, true, yaw)
	var sorted := holes.duplicate()
	sorted.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var at := 0.0
	for hole: Array in sorted:
		var s0: float = hole[0] - hole[1] * 0.5
		var s1: float = hole[0] + hole[1] * 0.5
		piece.call(at, s0, 0.0, h)
		piece.call(s0, s1, 0.0, hole[2])
		piece.call(s0, s1, hole[3], h)
		_finish(a, dir, yaw, at, s0, h, thick, base)
		_frame(a, dir, yaw, s0, s1, hole[2], hole[3], thick, base)
		at = s1
	piece.call(at, length, 0.0, h)
	_finish(a, dir, yaw, at, length, h, thick, base)


## Skirting and pilasters along a solid stretch of wall. Only the view needs them.
func _finish(a: Vector2, dir: Vector2, yaw: float, s0: float, s1: float, h: float, thick: float, base: float) -> void:
	if b.headless or style.is_empty() or s1 - s0 < 0.6 or h < 2.0:
		return
	var tint: Color = style["tint"]
	var mid := a + dir * ((s0 + s1) * 0.5)
	var skirt := minf(h * 0.22, 0.9)
	b.box(Vector3(mid.x, base + skirt * 0.5, mid.y), Vector3(s1 - s0, skirt, thick + 0.12), style["skirt"], tint.darkened(0.35), false, yaw)
	b.box(Vector3(mid.x, base + h - 0.2, mid.y), Vector3(s1 - s0, 0.4, thick + 0.14), style["skirt"], tint.darkened(0.2), false, yaw)
	var s := s0 + 2.0
	while s < s1 - 1.0:
		var p := a + dir * s
		b.box(Vector3(p.x, base + h * 0.5, p.y), Vector3(0.34, h, thick + 0.2), style["rib"], tint.darkened(0.12), false, yaw)
		s += 4.0


## A lit surround for an opening: posts, a head and, on a window, a sill.
func _frame(a: Vector2, dir: Vector2, yaw: float, s0: float, s1: float, y0: float, y1: float, thick: float, base: float) -> void:
	if b.headless or style.is_empty():
		return
	var lit: String = style["frame"]
	var depth := thick + 0.1
	for s: float in [s0, s1]:
		var p := a + dir * s
		b.box(Vector3(p.x, base + (y0 + y1) * 0.5, p.y), Vector3(0.09, y1 - y0, depth), lit, Color.WHITE, false, yaw)
	var c := a + dir * ((s0 + s1) * 0.5)
	b.box(Vector3(c.x, base + y1, c.y), Vector3(s1 - s0, 0.09, depth), lit, Color.WHITE, false, yaw)
	if y0 > 0.1:
		b.box(Vector3(c.x, base + y0, c.y), Vector3(s1 - s0, 0.09, depth), lit, Color.WHITE, false, yaw)


func door(at: float, width := DOOR_W) -> Array:
	return [at, width, 0.0, DOOR_H]


func window(at: float, width := 2.4) -> Array:
	return [at, width, SILL, HEAD]


## A hollow building. `holes` holds the openings of each side, under "n", "s", "e" and "w".
func _room(r: Rect2, h: float, mat: String, tint: Color, holes: Dictionary, roof := "") -> void:
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	_wall_run(Vector2(x0, z0), Vector2(x1, z0), h, mat, tint, holes.get("n", []))
	_wall_run(Vector2(x0, z1), Vector2(x1, z1), h, mat, tint, holes.get("s", []))
	_wall_run(Vector2(x0, z0), Vector2(x0, z1), h, mat, tint, holes.get("w", []))
	_wall_run(Vector2(x1, z0), Vector2(x1, z1), h, mat, tint, holes.get("e", []))
	b.add_footprint(r.get_center(), r.size, 0.0)
	if roof != "":
		_deck(r.grow(0.2), h, roof, tint)


## Flat platform. It is overhead, so nothing on the ground has to walk round it.
func _deck(r: Rect2, y: float, mat: String, tint: Color, thick := 0.3) -> void:
	var c := r.get_center()
	b.box(Vector3(c.x, y - thick * 0.5, c.y), Vector3(r.size.x, thick, r.size.y), mat, tint)


## Straight ramp rising along `dir` (a unit axis) from `foot` to the height `rise`.
func _ramp(foot: Vector3, dir: Vector2, rise: float, width: float, mat: String, tint: Color) -> void:
	var run := rise * 1.75
	var length := Vector2(run, rise).length()
	var angle := atan2(rise, run)
	var yaw := atan2(-dir.y, dir.x)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, angle)
	var mid := foot + Vector3(dir.x, 0, dir.y) * run * 0.5 + Vector3.UP * rise * 0.5
	b.add_box(Transform3D(basis, mid), Vector3(length, 0.18, width), mat, tint)
	# The solid under it, so nobody walks in below the slope.
	b.add_box(Transform3D(Basis(Vector3.UP, yaw), foot + Vector3(dir.x, 0, dir.y) * run * 0.62 + Vector3.UP * 0.5), Vector3(run * 0.72, 1.0, width), mat, tint.darkened(0.3))
	b.add_footprint(Vector2(mid.x, mid.z), Vector2(absf(dir.x) * run + absf(dir.y) * width, absf(dir.y) * run + absf(dir.x) * width), 0.0, "cover")


## Cover a soldier can crouch behind and shoot over.
func _low(p: Vector3, size: Vector3, mat: String, tint: Color, yaw := 0.0) -> void:
	b.box(p + Vector3.UP * size.y * 0.5, size, mat, tint, true, yaw)
	b.add_footprint(Vector2(p.x, p.z), Vector2(size.x, size.z), yaw, "cover")


## Three crates, the tallest a shoulder high.
func _stack(p: Vector3, yaw: float, mat: String, tint: Color) -> void:
	var axis := Basis(Vector3.UP, yaw)
	_low(p, Vector3(1.5, 1.5, 1.5), mat, tint, yaw)
	b.box(p + axis * Vector3(0.1, 2.0, 0.05), Vector3(1.0, 1.0, 1.0), mat, tint.lightened(0.08), true, yaw + 0.25)
	_low(p + axis * Vector3(1.55, 0, 0.2), Vector3(1.2, 1.0, 1.2), mat, tint.darkened(0.12), yaw + 0.1)


## A rail along a deck edge: low enough to shoot over, high enough to hide a crouching body.
func _rail(a: Vector2, c: Vector2, y: float, mat: String, tint: Color) -> void:
	_wall_run(a, c, 1.05, mat, tint, [], 0.14, y)


func _sign(parent: Node3D, text: String, at: Vector3, color: Color, yaw := 0.0, size := 70) -> Label3D:
	var label := Label3D.new()
	label.text = T.t(text)
	label.font = load("res://assets/fonts/BarlowCondensed-Bold.ttf")
	label.font_size = size
	label.pixel_size = 0.022
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color(0.01, 0.02, 0.04)
	label.double_sided = false
	# Blended text sorts against its own outline, and at a distance the two swap places every
	# frame. Cut out and mipmapped, a sign holds still.
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.alpha_scissor_threshold = 0.4
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	parent.add_child(label)
	label.position = at
	label.rotation.y = yaw
	return label


func _fill_light(parent: Node3D, at: Vector3, color: Color, reach: float, energy := 1.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy * LIGHT_GAIN
	light.omni_range = reach
	light.shadow_enabled = false
	parent.add_child(light)
	light.position = at
	return light
