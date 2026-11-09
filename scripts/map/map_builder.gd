class_name MapBuilder
extends RefCounted
## Accumulates world geometry into a few batched meshes and collision shapes.
## In headless mode only collision and nav data are produced.

const CHUNK := 64.0

class Batch:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

var headless := false
var nav := NavGrid.new()
## Same map for mechs: wider clearance, and anything under 3.4 m (doorways, rooms) is closed.
var nav_wide := NavGrid.new()
## And for tanks, which hover over anything low but need the most room.
var nav_tank := NavGrid.new()
## Height of the ground under what is being placed: nav grids care about height above it.
var floor_y := 0.0
## Rects for the tactical map: {"center": Vector2, "size": Vector2, "yaw": float, "kind": String}
var footprints: Array[Dictionary] = []

## Side of the square each drawn batch covers. Collision keeps CHUNK whatever this is.
var batch_chunk := CHUNK
## While set, whatever is drawn goes into one batch per material under this name, wherever it
## stands: for scenery so far off that it is always seen whole, like a skyline.
var batch_tag := ""

var _batches := {}
var _collision := {}

## Local face frames as [normal, u, v] with u x v = normal, giving clockwise winding.
const FACES := [
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
]


func _batch(mat: String, origin: Vector3) -> Batch:
	var key := "%s|%s" % [mat, batch_tag] if batch_tag != "" else "%s|%d|%d" % [mat, int(floor(origin.x / batch_chunk)), int(floor(origin.z / batch_chunk))]
	if not _batches.has(key):
		_batches[key] = Batch.new()
	return _batches[key]


func _collision_faces(origin: Vector3) -> Array:
	var key := Vector2i(int(floor(origin.x / CHUNK)), int(floor(origin.z / CHUNK)))
	if not _collision.has(key):
		_collision[key] = [PackedVector3Array()]
	return _collision[key]


## Darkens geometry near the ground: a cheap stand-in for grime and contact occlusion.
static func _shade(tint: Color, y: float) -> Color:
	var k := lerpf(0.58, 1.0, clampf(y / 2.6, 0.0, 1.0))
	return Color(tint.r * k, tint.g * k, tint.b * k, tint.a)


func add_box(xf: Transform3D, size: Vector3, mat: String, tint := Color.WHITE, collide := true, block_nav := true) -> void:
	var h := size * 0.5
	if not headless and mat != "":
		var b := _batch(mat, xf.origin)
		for f: Array in FACES:
			var n: Vector3 = f[0]
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			var c := n * h
			var du := u * h
			var dv := v * h
			var base := b.verts.size()
			var wn := (xf.basis * n).normalized()
			for corner: Vector3 in [c - du + dv, c + du + dv, c + du - dv, c - du - dv]:
				var w := xf * corner
				b.verts.append(w)
				b.normals.append(wn)
				b.colors.append(_shade(tint, w.y))
			b.indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	if collide:
		var arr: Array = _collision_faces(xf.origin)
		var faces: PackedVector3Array = arr[0]
		for f: Array in FACES:
			var n: Vector3 = f[0]
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			var c := n * h
			var du := u * h
			var dv := v * h
			var p0 := xf * (c - du + dv)
			var p1 := xf * (c + du + dv)
			var p2 := xf * (c + du - dv)
			var p3 := xf * (c - du - dv)
			faces.append_array(PackedVector3Array([p0, p1, p2, p0, p2, p3]))
		arr[0] = faces
		if block_nav:
			_stamp_nav(xf, size)


func _stamp_nav(xf: Transform3D, size: Vector3) -> void:
	var h := size * 0.5
	var reach := absf(xf.basis.x.y) * h.x + absf(xf.basis.y.y) * h.y + absf(xf.basis.z.y) * h.z
	var bottom := xf.origin.y - reach - floor_y
	var top := xf.origin.y + reach - floor_y
	if top >= 0.4 and bottom <= 3.4:
		nav_wide.block_obb(xf, h.x, h.z, 1.0)
	if top >= 0.7 and bottom <= 3.4:
		nav_tank.block_obb(xf, h.x, h.z, 1.9)
	# Only things at body height stop a soldier; overhead slabs and kerbs do not.
	if top < 0.4 or bottom > 1.9:
		return
	nav.block_obb(xf, h.x, h.z, 0.45)


## Invisible collision-only box, for map boundaries.
func add_blocker(center: Vector3, size: Vector3) -> void:
	add_box(Transform3D(Basis.IDENTITY, center), size, "", Color.WHITE, true, true)


## Convenience for axis-aligned, optionally yawed boxes.
func box(center: Vector3, size: Vector3, mat: String, tint := Color.WHITE, collide := true, yaw := 0.0, block_nav := true) -> void:
	add_box(Transform3D(Basis(Vector3.UP, yaw), center), size, mat, tint, collide, block_nav)


## Clockwise triangle, used for roofs and other non-box shapes.
func add_tri(a: Vector3, b2: Vector3, c: Vector3, mat: String, tint := Color.WHITE, collide := true) -> void:
	if not headless:
		var b := _batch(mat, a)
		var n := (c - a).cross(b2 - a).normalized()
		var base := b.verts.size()
		for p: Vector3 in [a, b2, c]:
			b.verts.append(p)
			b.normals.append(n)
			b.colors.append(tint)
		b.indices.append_array(PackedInt32Array([base, base + 1, base + 2]))
	if collide:
		var arr: Array = _collision_faces(a)
		var faces: PackedVector3Array = arr[0]
		faces.append_array(PackedVector3Array([a, b2, c]))
		arr[0] = faces


## Vertical prism with an n-gon cross-section, for chimneys, columns and monuments.
func add_prism(center: Vector3, radius: float, height: float, sides: int, mat: String, tint := Color.WHITE, top_radius := -1.0, solid := true) -> void:
	var rt := radius if top_radius < 0.0 else top_radius
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var b0 := center + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var b1 := center + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var t0 := center + Vector3(cos(a0) * rt, height, sin(a0) * rt)
		var t1 := center + Vector3(cos(a1) * rt, height, sin(a1) * rt)
		add_tri(t1, t0, b0, mat, tint, solid)
		add_tri(t1, b0, b1, mat, tint, solid)
		add_tri(center + Vector3.UP * height, t0, t1, mat, tint, solid)
	# A prism that starts overhead, like a tower on top of an office floor, blocks nobody's way.
	if solid and center.y - floor_y < 1.9:
		block_footprint(Transform3D(Basis.IDENTITY, center), radius, radius)


## Marks ground as blocked for both soldiers and mechs.
func block_footprint(xf: Transform3D, half_x: float, half_z: float) -> void:
	nav.block_obb(xf, half_x, half_z, 0.45)
	nav_wide.block_obb(xf, half_x, half_z, 1.0)
	nav_tank.block_obb(xf, half_x, half_z, 1.9)



func add_footprint(center: Vector2, size: Vector2, yaw: float, kind := "building") -> void:
	footprints.append({"center": center, "size": size, "yaw": yaw, "kind": kind})


## Adds pre-computed terrain triangles to the collision set.
func add_collision_faces(faces: PackedVector3Array) -> void:
	_collision[Vector2i(99999, _collision.size())] = [faces]


func finish(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "WorldCollision"
	body.collision_layer = C.LAYER_WORLD
	body.collision_mask = 0
	parent.add_child(body)
	for key: Vector2i in _collision:
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(_collision[key][0])
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
	_collision.clear()
	if headless:
		return
	for key: String in _batches:
		var b: Batch = _batches[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b.verts
		arrays[Mesh.ARRAY_NORMAL] = b.normals
		arrays[Mesh.ARRAY_COLOR] = b.colors
		arrays[Mesh.ARRAY_INDEX] = b.indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, Mats.world(key.get_slice("|", 0)))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		parent.add_child(mi)
	_batches.clear()
