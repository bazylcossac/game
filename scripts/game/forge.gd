class_name Forge
extends RefCounted
## Builds one rigid part of a machine into a single mesh: sloped hulls, chamfered plates and
## turned barrels that primitives cannot make, at one draw call per part.
##
## Every vertex carries what shaders/armor.gdshader needs:
##   COLOR  paint, darkened towards the bottom of each piece as cheap occlusion.
##   UV.x   edge wear, 1 on chamfers, where paint chips first.
##   UV.y   surface kind, see the constants below.
##
## Axes match the models: forward is -Z, up is +Y.

const PAINT := 0.0
const METAL := 1.0
const RUBBER := 2.0
const GLASS := 3.0
const LIGHT := 4.0

static var _cache := {}
static var _skins := {}
static var _decals := {}
static var _plume_mesh: Mesh
static var _plume_mat: ShaderMaterial

var _p := PackedVector3Array()
var _n := PackedVector3Array()
var _w := PackedFloat32Array()
var _c := PackedColorArray()
var _uv := PackedVector2Array()
var _xf := Transform3D.IDENTITY
var _nb := Basis.IDENTITY
var _stack: Array[Transform3D] = []


## A paint and the kind of surface under it.
class Tone:
	var color: Color
	var kind: float

	func _init(c: Color, new_kind := 0.0) -> void:
		color = c.srgb_to_linear()
		kind = new_kind


static func tone(color: Color, kind := PAINT) -> Tone:
	return Tone.new(color, kind)


## `energy` runs up to 10.
static func lamp(color: Color, energy: float) -> Tone:
	return Tone.new(color, LIGHT + energy * 0.1)


## Parts are identical across vehicles of a side, so each is built once and shared.
static func mesh(key: String, build: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var k := Forge.new()
	build.call(k)
	var m := k.commit()
	_cache[key] = m
	return m


static func skin(team: int) -> ShaderMaterial:
	if _skins.has(team):
		return _skins[team]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/armor.gdshader")
	var tex: Texture2D = load("res://assets/textures/armor_detail.png")
	m.set_shader_parameter("detail", tex)
	if team == C.Team.RESISTANCE:
		m.set_shader_parameter("patch_color", Color(0.62, 0.52, 0.44))
		m.set_shader_parameter("patch_amount", 0.5)
		m.set_shader_parameter("paint_metal", 0.12)
		m.set_shader_parameter("paint_rough", 0.62)
		m.set_shader_parameter("bare_color", Color(0.66, 0.5, 0.26))
	else:
		m.set_shader_parameter("patch_color", Color(0.42, 0.42, 0.4))
		m.set_shader_parameter("patch_amount", 0.55)
		m.set_shader_parameter("paint_metal", 0.42)
		m.set_shader_parameter("paint_rough", 0.5)
		m.set_shader_parameter("bare_color", Color(0.5, 0.5, 0.52))
	_skins[team] = m
	return m


## A flat marking laid on the armour. `pos` should stand slightly off the surface.
static func decal(parent: Node3D, tex_name: String, size: Vector2, pos: Vector3, rot: Vector3, tint := Color.WHITE, energy := 0.0) -> MeshInstance3D:
	var key := "%s|%s|%.1f" % [tex_name, tint.to_html(), energy]
	if not _decals.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = Mats.tex(tex_name)
		m.albedo_color = tint
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.7
		if energy > 0.0:
			m.emission_enabled = true
			m.emission = tint
			m.emission_energy_multiplier = energy
			m.emission_texture = m.albedo_texture
		_decals[key] = m
	var quad := QuadMesh.new()
	quad.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = _decals[key]
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Open cone along +Z: the wide end at the origin, tapering away behind the engine.
static func plume(parent: Node3D, pos: Vector3, radius: float, length: float, color: Color) -> MeshInstance3D:
	if _plume_mesh == null:
		var cone := CylinderMesh.new()
		cone.top_radius = 1.0
		cone.bottom_radius = 0.05
		cone.height = 1.0
		cone.radial_segments = 14
		cone.rings = 1
		cone.cap_top = false
		cone.cap_bottom = false
		_plume_mesh = cone
		_plume_mat = ShaderMaterial.new()
		_plume_mat.shader = load("res://shaders/plume.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = _plume_mesh
	mi.material_override = _plume_mat
	mi.position = pos + Vector3(0, 0, length * 0.5)
	mi.rotation.x = -PI * 0.5
	mi.scale = Vector3(radius, length, radius)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("plume_color", Vector3(color.r, color.g, color.b))
	parent.add_child(mi)
	return mi


func commit() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _p
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# ---------------------------------------------------------------- placement

## Everything until the matching back() is placed relative to this.
func at(pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> void:
	_stack.append(_xf)
	_set_xf(_xf * Transform3D(Basis.from_euler(rot) * Basis.from_scale(scale), pos))


func at_xf(xf: Transform3D) -> void:
	_stack.append(_xf)
	_set_xf(_xf * xf)


func back() -> void:
	_set_xf(_stack.pop_back())


func _set_xf(xf: Transform3D) -> void:
	_xf = xf
	_nb = xf.basis.inverse().transposed()


# ---------------------------------------------------------------- emission

func _tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, wear: float) -> void:
	var pa := _xf * a
	var pb := _xf * b
	var pc := _xf * c
	var ma := (_nb * na).normalized()
	var mb := (_nb * nb).normalized()
	var mc := (_nb * nc).normalized()
	# Godot's front faces wind clockwise, so the cross product must point into the surface.
	if (pb - pa).cross(pc - pa).dot(ma + mb + mc) > 0.0:
		var tp := pb
		pb = pc
		pc = tp
		var tn := mb
		mb = mc
		mc = tn
	_p.append(pa)
	_p.append(pb)
	_p.append(pc)
	_n.append(ma)
	_n.append(mb)
	_n.append(mc)
	_w.append(wear)
	_w.append(wear)
	_w.append(wear)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, wear: float) -> void:
	_tri(a, b, c, na, nb, nc, wear)
	_tri(a, c, d, na, nc, nd, wear)


## Paints what was emitted since `start`: lit from above, darker towards its own underside.
func _close(start: int, t: Tone, ao := 0.6) -> void:
	var lo := INF
	var hi := -INF
	for i in range(start, _p.size()):
		lo = minf(lo, _p[i].y)
		hi = maxf(hi, _p[i].y)
	var span := maxf(hi - lo, 0.001)
	var shade := 1.0 if t.kind >= GLASS else ao
	for i in range(start, _p.size()):
		var f := lerpf(shade, 1.0, (_p[i].y - lo) / span)
		_c.append(Color(t.color.r * f, t.color.g * f, t.color.b * f))
		_uv.append(Vector2(_w[i], t.kind))


static func _centre(ring: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in ring:
		c += p
	return c / float(ring.size())


# ---------------------------------------------------------------- surfaces

## Skins a stack of rings that share a point count.
##   chamfered  rings came from _bevel_ring, so their even edges are worn chamfers.
##   end_bevel  also chamfers the two ends by that distance.
##   smooth     shades round each ring, for rounded bodies.
func loft(rings: Array, t: Tone, chamfered := false, end_bevel := 0.0, smooth := false) -> void:
	var start := _p.size()
	var all := rings
	if end_bevel > 0.0:
		all = _bevel_ends(rings, end_bevel)
	var n: int = (all[0] as PackedVector3Array).size()
	var worn_from := 1 if end_bevel > 0.0 else 0
	for r in all.size() - 1:
		var a: PackedVector3Array = all[r]
		var b: PackedVector3Array = all[r + 1]
		var mid := (_centre(a) + _centre(b)) * 0.5
		var faces := PackedVector3Array()
		faces.resize(n)
		for i in n:
			var j := (i + 1) % n
			var fn := (a[j] - a[i]).cross(b[i] - a[i])
			if fn.length_squared() < 1e-10:
				fn = (b[j] - a[j]).cross(b[i] - a[j])
			if fn.length_squared() < 1e-10:
				fn = (a[i] + a[j] + b[i] + b[j]) * 0.25 - mid
			if fn.dot((a[i] + a[j] + b[i] + b[j]) * 0.25 - mid) < 0.0:
				fn = -fn
			faces[i] = fn.normalized()
		var edge_band := end_bevel > 0.0 and (r < worn_from or r >= all.size() - 1 - worn_from)
		for i in n:
			var j := (i + 1) % n
			var wear := 1.0 if edge_band or (chamfered and i % 2 == 0) else 0.0
			if smooth:
				var ni := (faces[(i + n - 1) % n] + faces[i]).normalized()
				var nj := (faces[i] + faces[j]).normalized()
				_quad(a[i], a[j], b[j], b[i], ni, nj, nj, ni, wear)
			else:
				_quad(a[i], a[j], b[j], b[i], faces[i], faces[i], faces[i], faces[i], wear)
	_cap(all[0], _centre(all[0]) - _centre(all[1]))
	_cap(all[all.size() - 1], _centre(all[all.size() - 1]) - _centre(all[all.size() - 2]))
	_close(start, t)


func _cap(ring: PackedVector3Array, out: Vector3) -> void:
	var c := _centre(ring)
	var n := out.normalized()
	for i in ring.size():
		_tri(c, ring[i], ring[(i + 1) % ring.size()], n, n, n, 0.0)


func _bevel_ends(rings: Array, c: float) -> Array:
	var out: Array = []
	var last := rings.size() - 1
	out.append(_shrunk(rings[0], c))
	for r in rings.size():
		var ring: PackedVector3Array = rings[r]
		if r == 0 or r == last:
			var other: PackedVector3Array = rings[1 if r == 0 else last - 1]
			var moved := PackedVector3Array()
			for i in ring.size():
				moved.append(ring[i] + (other[i] - ring[i]).normalized() * c)
			out.append(moved)
		else:
			out.append(ring)
	out.append(_shrunk(rings[last], c))
	return out


func _shrunk(ring: PackedVector3Array, c: float) -> PackedVector3Array:
	var mid := _centre(ring)
	var out := PackedVector3Array()
	for p in ring:
		out.append(p + (mid - p).normalized() * minf(c, p.distance_to(mid) * 0.8))
	return out


## Replaces each corner of a closed outline with a small chamfer.
func _bevel_ring(pts: Array, c: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var prev: Vector3 = pts[(i + n - 1) % n]
		var next: Vector3 = pts[(i + 1) % n]
		out.append(p + (prev - p).normalized() * minf(c, p.distance_to(prev) * 0.45))
		out.append(p + (next - p).normalized() * minf(c, p.distance_to(next) * 0.45))
	return out


## Chamfered plate. `top` scales its upper face and `shift` slides it, which makes wedges
## and raked plates. Stands along local Y.
func slab(size: Vector3, pos: Vector3, t: Tone, rot := Vector3.ZERO, bevel := 0.035, top := Vector2.ONE, shift := Vector2.ZERO) -> void:
	at(pos, rot)
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.8)
	var low := [Vector3(h.x, 0, h.z), Vector3(h.x, 0, -h.z), Vector3(-h.x, 0, -h.z), Vector3(-h.x, 0, h.z)]
	var a: Array = []
	var c: Array = []
	for p: Vector3 in low:
		a.append(p + Vector3(0, -h.y, 0))
		c.append(Vector3(p.x * top.x + shift.x, h.y, p.z * top.y + shift.y))
	loft([_bevel_ring(a, b), _bevel_ring(c, b)], t, true, b)
	back()


## Long hull of hexagonal sections along Z. Each station is
## [z, y_low, y_mid, y_high, half_width_low, half_width_mid, half_width_high].
func hull(stations: Array, t: Tone, bevel := 0.05) -> void:
	var rings: Array = []
	for s: Array in stations:
		var z: float = s[0]
		var pts := [
			Vector3(s[4], s[1], z), Vector3(s[5], s[2], z), Vector3(s[6], s[3], z),
			Vector3(-s[6], s[3], z), Vector3(-s[5], s[2], z), Vector3(-s[4], s[1], z),
		]
		rings.append(_bevel_ring(pts, bevel))
	loft(rings, t, true, bevel)


## Limb armour of sections along Y, faceted at the front. Each station is
## [y, half_width, front_depth, back_depth] or, with a fifth value, an offset in Z.
func limb(stations: Array, t: Tone, bevel := 0.04) -> void:
	var rings: Array = []
	for s: Array in stations:
		var y: float = s[0]
		var w: float = s[1]
		var f: float = s[2]
		var b: float = s[3]
		var oz: float = s[4] if s.size() > 4 else 0.0
		var pts := [
			Vector3(w, y, oz + b), Vector3(w, y, oz - f * 0.45), Vector3(w * 0.55, y, oz - f),
			Vector3(-w * 0.55, y, oz - f), Vector3(-w, y, oz - f * 0.45), Vector3(-w, y, oz + b),
		]
		rings.append(_bevel_ring(pts, bevel))
	loft(rings, t, true, bevel)


## Rounded body of elliptical sections along Y. Each station is [y, radius_x, radius_z] or,
## with a fourth value, an offset in Z.
func pod(stations: Array, t: Tone, sides := 16) -> void:
	var rings: Array = []
	for s: Array in stations:
		var ring := PackedVector3Array()
		var oz: float = s[3] if s.size() > 3 else 0.0
		for i in sides:
			var a := TAU * i / sides
			ring.append(Vector3(cos(a) * s[1], s[0], sin(a) * s[2] + oz))
		rings.append(ring)
	loft(rings, t, false, 0.0, true)


## Turned part: `profile` is a list of Vector2(radius, height). Going up the outside and back
## in at the top keeps the normals outward; going back down walks the inside of a bore.
##   soft  blends bands together, for domes.
func lathe(profile: Array, pos: Vector3, t: Tone, rot := Vector3.ZERO, sides := 14, scale := Vector3.ONE, soft := false) -> void:
	at(pos, rot, scale)
	var start := _p.size()
	var cs := PackedFloat32Array()
	var sn := PackedFloat32Array()
	for i in sides + 1:
		cs.append(cos(TAU * i / sides))
		sn.append(sin(TAU * i / sides))
	var slopes: Array[Vector2] = []
	for s in profile.size() - 1:
		var d: Vector2 = profile[s + 1] - profile[s]
		slopes.append(Vector2(d.y, -d.x).normalized())
	for s in profile.size() - 1:
		var a: Vector2 = profile[s]
		var b: Vector2 = profile[s + 1]
		if a.distance_squared_to(b) < 1e-8:
			continue
		var na := slopes[s]
		var nb := slopes[s]
		if soft:
			if s > 0:
				na = (slopes[s - 1] + slopes[s]).normalized()
			if s < profile.size() - 2:
				nb = (slopes[s] + slopes[s + 1]).normalized()
		var wear := 1.0 if a.distance_to(b) < 0.07 else 0.0
		for i in sides:
			var j := i + 1
			var p0 := Vector3(cs[i] * a.x, a.y, sn[i] * a.x)
			var p1 := Vector3(cs[j] * a.x, a.y, sn[j] * a.x)
			var p2 := Vector3(cs[j] * b.x, b.y, sn[j] * b.x)
			var p3 := Vector3(cs[i] * b.x, b.y, sn[i] * b.x)
			var n0 := Vector3(cs[i] * na.x, na.y, sn[i] * na.x)
			var n1 := Vector3(cs[j] * na.x, na.y, sn[j] * na.x)
			var n2 := Vector3(cs[j] * nb.x, nb.y, sn[j] * nb.x)
			var n3 := Vector3(cs[i] * nb.x, nb.y, sn[i] * nb.x)
			_quad(p0, p1, p2, p3, n0, n1, n2, n3, wear)
	_close(start, t, 0.72)
	back()


## A lathe laid along -Z, from breech to muzzle.
func barrel(profile: Array, pos: Vector3, t: Tone, sides := 12) -> void:
	lathe(profile, pos, t, Vector3(-PI * 0.5, 0, 0), sides)


func ball(r: float, pos: Vector3, t: Tone, scale := Vector3.ONE, sides := 12, bands := 6) -> void:
	var profile: Array = []
	for i in bands + 1:
		var a := -PI * 0.5 + PI * i / bands
		profile.append(Vector2(cos(a) * r, sin(a) * r))
	lathe(profile, pos, t, Vector3.ZERO, sides, scale, true)


## Upper half of a ball, closed underneath.
func dome(r: float, pos: Vector3, t: Tone, scale := Vector3.ONE, sides := 14, bands := 4) -> void:
	var profile: Array = [Vector2(0.0, 0.0), Vector2(r, 0.0)]
	for i in bands + 1:
		var a := PI * 0.5 * i / bands
		profile.append(Vector2(cos(a) * r, sin(a) * r))
	lathe(profile, pos, t, Vector3.ZERO, sides, scale, true)


## Round bar between two points.
func rod(a: Vector3, b: Vector3, r: float, t: Tone, sides := 8) -> void:
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	at_xf(Transform3D(Basis(Quaternion(Vector3.UP, dir)), a))
	lathe([Vector2(0, 0), Vector2(r, 0), Vector2(r, length), Vector2(0, length)], Vector3.ZERO, t, Vector3.ZERO, sides)
	back()


## Hydraulic ram: a fat cylinder with a bright rod running out of it.
func ram(a: Vector3, b: Vector3, r: float, body: Tone, shaft: Tone) -> void:
	var mid := a.lerp(b, 0.55)
	rod(a, mid, r, body)
	rod(mid, b, r * 0.55, shaft)


func bolts(a: Vector3, b: Vector3, count: int, r: float, t: Tone, rot := Vector3.ZERO) -> void:
	for i in count:
		var f := float(i) / maxf(count - 1, 1)
		lathe([Vector2(r, 0), Vector2(r, r * 0.6), Vector2(r * 0.5, r), Vector2(0, r)], a.lerp(b, f), t, rot, 6)


## Louvred grille lying on a surface whose outward side is local +Y.
func vent(size: Vector2, pos: Vector3, frame: Tone, slat: Tone, rot := Vector3.ZERO, slats := 6) -> void:
	at(pos, rot)
	slab(Vector3(size.x, 0.05, size.y), Vector3.ZERO, frame, Vector3.ZERO, 0.02)
	var w := size.y / float(slats) * 0.72
	for i in slats:
		var z := -size.y * 0.5 + size.y * (i + 0.5) / slats
		slab(Vector3(size.x - 0.07, 0.022, w), Vector3(0, 0.038, z), slat, Vector3(0.5, 0, 0), 0.006)
	back()
