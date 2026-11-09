class_name Mats
extends RefCounted
## Shared material cache. World materials use world-space triplanar mapping, so
## procedural geometry needs no UVs and textures line up across box seams.

static var _world := {}
static var _flat := {}
static var _wet := 0.0
static var _grime := 0.5

## name: [texture, metres per tile, roughness, metallic, normal strength]
const WORLD := {
	"brick": ["brick", 3.2, 0.92, 0.0, 1.0],
	"plaster": ["plaster", 4.0, 0.95, 0.0, 0.7],
	"concrete": ["concrete", 5.0, 0.9, 0.0, 0.8],
	"wood": ["wood", 2.4, 0.85, 0.0, 0.9],
	"metal": ["metal", 3.0, 0.55, 0.65, 0.8],
	"roof": ["roof", 3.0, 0.8, 0.0, 1.0],
	"fabric": ["fabric", 1.2, 0.95, 0.0, 0.6],
	"dirt": ["dirt", 4.0, 0.98, 0.0, 1.0],
	"asphalt": ["asphalt", 6.0, 0.62, 0.05, 0.8],
	"panel": ["panel", 6.0, 0.48, 0.35, 0.9],
	"deck": ["deck", 2.6, 0.5, 0.7, 1.0],
	"tiles": ["tiles", 5.0, 0.42, 0.25, 0.8],
	"mud": ["mud", 7.0, 0.82, 0.0, 1.0],
	"planks": ["planks", 2.4, 0.86, 0.0, 1.0],
	"burlap": ["burlap", 1.0, 0.95, 0.0, 0.8],
	"corrugated": ["corrugated", 2.0, 0.55, 0.5, 0.9],
	"facade_night": ["facade_night", 26.0, 0.3, 0.2, 0.3],
	"carpet": ["carpet", 2.0, 0.96, 0.0, 0.7],
	"office_wall": ["office_wall", 2.4, 0.62, 0.0, 0.6],
	"ceiling_tiles": ["ceiling_tiles", 2.4, 0.9, 0.0, 0.6],
}
## Indoors: the rain and the street's dirt never reach these.
const INDOOR := ["carpet", "office_wall", "ceiling_tiles"]


static func tex(name: String) -> Texture2D:
	return load("res://assets/textures/%s.png" % name)


static func world(key: String) -> Material:
	if _world.has(key):
		return _world[key]
	var lights := {"neon_cyan": Color(0.04, 0.8, 1), "neon_pink": Color(1, 0.06, 0.38), "neon_amber": Color(1, 0.55, 0.1), "leaf_cyan": Color(0.06, 0.5, 0.56), "leaf_pink": Color(0.6, 0.1, 0.36), "window_blue": Color(0.18, 0.38, 0.6), "station_light": Color(0.6, 0.8, 1), "amber_light": Color(1, 0.62, 0.22), "reactor_glass": Color(0.02, 0.5, 0.75), "office_light": Color(0.8, 0.88, 1.0)}
	if lights.has(key):
		var light_mat := glow(lights[key], 0.7 if key in ["window_blue", "reactor_glass", "leaf_cyan", "leaf_pink"] else 2.2)
		_world[key] = light_mat
		return light_mat
	if key in ["arena_floor", "arena_wall", "wet_ground", "arena_paint"]:
		var arena := StandardMaterial3D.new()
		arena.vertex_color_use_as_albedo = true
		arena.albedo_texture = tex("metal_albedo" if key == "arena_wall" else "concrete_albedo")
		arena.uv1_triplanar = true
		arena.uv1_world_triplanar = true
		arena.uv1_scale = Vector3.ONE * 0.2
		arena.roughness = 0.12 if key == "wet_ground" else (0.38 if key == "arena_floor" else 0.65)
		arena.metallic = 0.5 if key == "arena_wall" else 0.25
		_world[key] = arena
		return arena
	var spec: Array = WORLD[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/world.gdshader")
	m.set_shader_parameter("albedo_tex", tex(spec[0] + "_albedo"))
	m.set_shader_parameter("normal_tex", tex(spec[0] + "_normal"))
	m.set_shader_parameter("macro_tex", tex("macro_noise"))
	m.set_shader_parameter("tile", float(spec[1]))
	m.set_shader_parameter("base_roughness", float(spec[2]))
	m.set_shader_parameter("base_metallic", float(spec[3]))
	m.set_shader_parameter("normal_strength", float(spec[4]))
	# The lit windows in the photo stay lit after dark.
	m.set_shader_parameter("emission_energy", 0.55 if key == "facade_night" else 0.0)
	m.set_shader_parameter("wet", 0.0 if key in INDOOR else _wet)
	m.set_shader_parameter("grime", 0.12 if key in INDOOR else _grime)
	_world[key] = m
	return m


## How soaked this map is, 0 to 1, and how dirty its walls are.
static func set_climate(wet: float, grime: float) -> void:
	_wet = wet
	_grime = grime
	for key: String in _world:
		var m: Material = _world[key]
		if m is ShaderMaterial and not key in INDOOR:
			(m as ShaderMaterial).set_shader_parameter("wet", wet)
			(m as ShaderMaterial).set_shader_parameter("grime", grime)


## The old standard material of a surface, for props that carry their own tint per copy.
static func plain(key: String) -> StandardMaterial3D:
	var spec: Array = WORLD[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(spec[0] + "_albedo")
	m.normal_enabled = true
	m.normal_texture = tex(spec[0] + "_normal")
	m.normal_scale = spec[4]
	m.roughness = spec[2]
	m.metallic = spec[3]
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_scale = Vector3.ONE / float(spec[1])
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func flat(color: Color, roughness := 0.7, metallic := 0.0) -> StandardMaterial3D:
	var key := "f%s|%.2f|%.2f" % [color.to_html(), roughness, metallic]
	if _flat.has(key):
		return _flat[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_flat[key] = m
	return m


## Weapon parts: a fine machined grain in the normal map. The factory uses these on small
## pieces with no UVs, so the grain is projected in the part's own space.
static func gun(color: Color, roughness := 0.5, metallic := 0.5) -> StandardMaterial3D:
	var key := "w%s|%.2f|%.2f" % [color.to_html(), roughness, metallic]
	if _flat.has(key):
		return _flat[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.normal_enabled = true
	m.normal_texture = tex("metal_normal")
	m.normal_scale = 0.5
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_scale = Vector3.ONE * 3.5
	_flat[key] = m
	return m


## Uniform cloth: a weave in the normal map, and a soft rim so bodies stay readable in shade.
static func cloth(color: Color) -> StandardMaterial3D:
	var key := "c%s" % color.to_html()
	if _flat.has(key):
		return _flat[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.normal_enabled = true
	m.normal_texture = tex("fabric_normal")
	m.normal_scale = 0.4
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 6.0
	m.uv1_scale = Vector3.ONE * 2.0
	m.rim_enabled = true
	m.rim = 0.16
	m.rim_tint = 0.6
	_flat[key] = m
	return m


static func glow(color: Color, energy := 3.0) -> StandardMaterial3D:
	var key := "g%s|%.2f" % [color.to_html(), energy]
	if _flat.has(key):
		return _flat[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b)
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	_flat[key] = m
	return m


## Billboards for particles. These stay cached for good: when the last material of a kind
## goes, Godot drops its shader, and compiling it again stalled every explosion by 20 ms.
static func particle(tex_name: String, additive: bool, two_sided := false) -> StandardMaterial3D:
	var key := "p%s|%s|%s" % [tex_name, additive, two_sided]
	if _flat.has(key):
		return _flat[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex(tex_name)
	m.vertex_color_use_as_albedo = true
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flat[key] = m
	return m


## Copy of a material for first-person use: its own FOV, and clipped so it never
## pokes through nearby walls.
static func viewmodel(src: StandardMaterial3D) -> StandardMaterial3D:
	var key := "vm%d" % src.get_instance_id()
	if _flat.has(key):
		return _flat[key]
	var m := src.duplicate() as StandardMaterial3D
	m.use_fov_override = true
	m.fov_override = 62.0
	m.use_z_clip_scale = true
	m.z_clip_scale = 0.12
	_flat[key] = m
	return m
