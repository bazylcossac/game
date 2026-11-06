class_name BladeTrail
extends MeshInstance3D
## Short ribbon left behind a swung blade. Points are in this node's own space: world
## space for third-person bodies, view space for the first-person sword.

const LIFE := 0.15

static var _mats := {}

var _points: Array = []
var _im := ImmediateMesh.new()
var _color := Color.WHITE
var _strength := 0.42
var _first_person := false


func setup(color: Color, first_person: bool) -> void:
	_color = color
	_strength = 0.24 if first_person else 0.42
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 6.0
	_first_person = first_person


## Vertices carry the colour, so every ribbon shares one material. Call this while loading,
## or the first swing of a match stalls on compiling it.
static func material(first_person: bool) -> StandardMaterial3D:
	if _mats.has(first_person):
		return _mats[first_person]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	if first_person:
		m.use_fov_override = true
		m.fov_override = 62.0
		m.use_z_clip_scale = true
		m.z_clip_scale = 0.12
	_mats[first_person] = m
	return m


func push(base: Vector3, tip: Vector3) -> void:
	_points.append([base, tip, 0.0])


func tick(delta: float) -> void:
	for i in range(_points.size() - 1, -1, -1):
		_points[i][2] += delta
		if _points[i][2] >= LIFE:
			_points.remove_at(i)
	_im.clear_surfaces()
	if _points.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material(_first_person))
	for p: Array in _points:
		var a: float = 1.0 - float(p[2]) / LIFE
		var c := Color(_color.r * a, _color.g * a, _color.b * a, a * a * _strength)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p[0])
		_im.surface_set_color(c)
		_im.surface_add_vertex(p[1])
	_im.surface_end()
