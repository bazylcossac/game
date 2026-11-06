class_name TankAssets
extends RefCounted
## The tank made in Blender (tools/blender_tank.py), repainted for armor.gdshader. The file holds
## one shape; each material name there is a tone here, so a side's colours cost no extra model.
## Blender bakes occlusion into red and edge wear into green of each vertex.

const MODEL := "res://assets/models/tank/tank.glb"
const CARRIER_MODEL := "res://assets/models/tank/apc.glb"
const PARTS: Array[String] = ["Hull", "Turret", "Mantlet", "Barrel", "Station", "StationGun"]

static var _meshes := {}
static var _layout := {}


static func _tones(team: int) -> Dictionary:
	var usa := team == C.Team.RESISTANCE
	var glow: Color = C.TEAM_COLORS[team]
	return {
		"Plate": Forge.tone(Color(0.36, 0.39, 0.25) if usa else Color(0.33, 0.35, 0.36)),
		"Plate2": Forge.tone(Color(0.27, 0.3, 0.2) if usa else Color(0.24, 0.26, 0.27)),
		"Dark": Forge.tone(Color(0.13, 0.12, 0.11) if usa else Color(0.06, 0.06, 0.07), Forge.RUBBER),
		"Steel": Forge.tone(Color(0.42, 0.41, 0.4), Forge.METAL),
		"Trim": Forge.tone(Color(0.62, 0.62, 0.56), Forge.METAL) if usa else Forge.tone(Color(0.48, 0.07, 0.05)),
		"Glass": Forge.tone(Color(0.06, 0.12, 0.17) if usa else Color(0.16, 0.04, 0.03), Forge.GLASS),
		"Light": Forge.lamp(glow, 5.0),
		"LightSoft": Forge.lamp(glow, 2.0),
	}


## Where a part or marker sits relative to its parent in the model.
static func placed(node_name: String) -> Transform3D:
	_load_layout()
	return _layout[node_name]


## One rigid part in a side's paint, as a single surface.
static func mesh(team: int, part_name: String) -> ArrayMesh:
	var key := "%d/%s" % [team, part_name]
	if not _meshes.has(key):
		var scene: Node = (load(CARRIER_MODEL if part_name.begins_with("Apc") else MODEL) as PackedScene).instantiate()
		var source := scene.find_child(part_name, true, false) as MeshInstance3D
		_meshes[key] = _painted(source.mesh, _tones(team))
		scene.free()
	return _meshes[key]


static func _load_layout() -> void:
	if not _layout.is_empty():
		return
	for path: String in [MODEL, CARRIER_MODEL]:
		var scene: Node = (load(path) as PackedScene).instantiate()
		_collect(scene)
		scene.free()


static func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is Node3D:
			_layout[String(child.name)] = (child as Node3D).transform
		_collect(child)


static func _painted(source: Mesh, tones: Dictionary) -> ArrayMesh:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var tone: Forge.Tone = tones[source.surface_get_material(surface).resource_name]
		var base := points.size()
		var baked: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var lit := tone.kind >= Forge.GLASS
		points.append_array(arrays[Mesh.ARRAY_VERTEX])
		normals.append_array(arrays[Mesh.ARRAY_NORMAL])
		for c in baked:
			var shade := 1.0 if lit else c.r
			colors.append(Color(tone.color.r * shade, tone.color.g * shade, tone.color.b * shade))
			uvs.append(Vector2(c.g, tone.kind))
		for i: int in arrays[Mesh.ARRAY_INDEX]:
			indices.append(base + i)
	var merged := []
	merged.resize(Mesh.ARRAY_MAX)
	merged[Mesh.ARRAY_VERTEX] = points
	merged[Mesh.ARRAY_NORMAL] = normals
	merged[Mesh.ARRAY_COLOR] = colors
	merged[Mesh.ARRAY_TEX_UV] = uvs
	merged[Mesh.ARRAY_INDEX] = indices
	# Tanks are seen from a long way off on the big maps, so the far ones must cost little.
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, merged)
	importer.generate_lods(25.0, 60.0, [])
	return importer.get_mesh()
