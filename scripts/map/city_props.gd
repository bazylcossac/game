class_name CityProps
extends RefCounted
## Street props from tools/blender_city.py, drawn in batches: one MultiMesh per kind of prop and
## per stretch of map. Maps keep their own invisible collision boxes, so a server never needs these
## and nothing here changes how a map plays.

const PATH := "res://assets/models/city/props.glb"
const CHUNK := 128.0
## Beyond this a small prop is lost in the fog anyway.
const SMALL_REACH := 340.0
const LARGE := ["tree_oak", "tree_slim", "tree_palm", "bus", "lamp_city", "stump_a", "field_gun", "wreck_tank", "revetment", "boulder_a", "boulder_b"]

static var _meshes := {}

var enabled := true
var _batches := {}


func place(prop: String, xf: Transform3D, color := Color.WHITE) -> void:
	if not enabled:
		return
	var key := "%s|%d|%d" % [prop, int(floor(xf.origin.x / CHUNK)), int(floor(xf.origin.z / CHUNK))]
	if not _batches.has(key):
		_batches[key] = {"prop": prop, "items": []}
	_batches[key]["items"].append([xf, color])


## Stands a prop on the spot, turned by `yaw`.
func stand(prop: String, at: Vector3, yaw := 0.0, color := Color.WHITE, size := Vector3.ONE) -> void:
	place(prop, Transform3D(Basis(Vector3.UP, yaw).scaled_local(size), at), color)


func finish(parent: Node3D) -> void:
	for batch: Dictionary in _batches.values():
		var items: Array = batch["items"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = mesh_for(batch["prop"])
		multi.instance_count = items.size()
		for i in items.size():
			multi.set_instance_transform(i, items[i][0])
			multi.set_instance_color(i, items[i][1])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.name = "Props_%s" % batch["prop"]
		if not batch["prop"] in LARGE:
			node.visibility_range_end = SMALL_REACH
		parent.add_child(node)
	_batches.clear()


static func mesh_for(prop: String) -> Mesh:
	if _meshes.is_empty():
		var root: Node = (load(PATH) as PackedScene).instantiate()
		for child in root.find_children("*", "MeshInstance3D", true, false):
			var source := child as MeshInstance3D
			var copy: Mesh = source.mesh.duplicate()
			for surface in copy.get_surface_count():
				var made := finish_for(copy.surface_get_material(surface))
				if made:
					copy.surface_set_material(surface, made)
			_meshes[String(source.name)] = copy
		root.free()
	return _meshes[prop]


## The model only names its materials. What they look like is decided here, with the game's own
## textures, because each copy of "Paint" and "Leaf" has its own colour.
static func finish_for(source: Material) -> Material:
	if source == null:
		return null
	var key := source.resource_name
	var cached := "prop_%s" % key
	if _materials.has(cached):
		return _materials[cached]
	var out: Material
	match key:
		"Paint":
			var paint := StandardMaterial3D.new()
			paint.vertex_color_use_as_albedo = true
			paint.metallic = 0.55
			paint.roughness = 0.26
			paint.clearcoat_enabled = true
			paint.clearcoat = 0.7
			paint.clearcoat_roughness = 0.12
			out = paint
		"Leaf":
			var leaf := ShaderMaterial.new()
			leaf.shader = load("res://shaders/leaf.gdshader")
			leaf.set_shader_parameter("leaf_tex", load("res://assets/textures/leaf_cards.png"))
			out = leaf
		"Frond":
			var frond := StandardMaterial3D.new()
			frond.vertex_color_use_as_albedo = true
			frond.albedo_texture = Mats.tex("grass_albedo")
			frond.uv1_triplanar = true
			frond.uv1_scale = Vector3.ONE * 0.8
			frond.roughness = 0.82
			frond.cull_mode = BaseMaterial3D.CULL_DISABLED
			out = frond
		"Glass": out = Mats.flat(Color(0.03, 0.05, 0.08), 0.05, 0.6)
		"Dark": out = Mats.flat(Color(0.035, 0.035, 0.04), 0.55, 0.3)
		"Chrome": out = Mats.flat(Color(0.76, 0.77, 0.8), 0.2, 1.0)
		"Rubber": out = Mats.flat(Color(0.03, 0.03, 0.03), 0.9, 0.0)
		"Led": out = Mats.glow(Color(1.0, 0.95, 0.85), 4.0)
		"Tail": out = Mats.glow(Color(1.0, 0.06, 0.08), 3.0)
		"GlowCyan": out = Mats.glow(Color(0.05, 0.8, 1.0), 2.4)
		"GlowPink": out = Mats.glow(Color(1.0, 0.06, 0.45), 2.4)
		"GlowAmber": out = Mats.glow(Color(1.0, 0.55, 0.1), 2.4)
		"Screen": out = Mats.glow(Color(0.2, 0.42, 0.7), 1.0)
		"Fruit": out = Mats.glow(Color(1.0, 0.76, 0.42), 3.0)
		"Bark": out = _textured("wood", Color(0.5, 0.4, 0.34))
		"DeadWood": out = _textured("wood", Color(0.46, 0.38, 0.32))
		"Concrete": out = _textured("concrete", Color(0.62, 0.62, 0.62))
		"Steel": out = _textured("metal", Color(0.42, 0.44, 0.48))
		"Iron": out = _textured("metal", Color(0.16, 0.17, 0.18))
		"Burnt": out = _textured("metal", Color(0.24, 0.22, 0.2))
		"Rust": out = _textured("metal", Color(0.42, 0.22, 0.13))
		"Wood": out = _textured("planks", Color(0.9, 0.82, 0.74))
		"Muddy": out = _textured("mud", Color(0.8, 0.74, 0.68))
		"Bag": out = _textured("burlap", Color(0.72, 0.66, 0.54))
		"Wire": out = Mats.flat(Color(0.12, 0.1, 0.09), 0.5, 0.7)
		"Canvas": out = _textured("fabric", Color(0.34, 0.33, 0.24))
	_materials[cached] = out
	return out


static var _materials := {}


static func _textured(world_key: String, tint: Color) -> Material:
	var out := Mats.plain(world_key)
	out.albedo_color = tint
	return out
