class_name ModelAssets
extends RefCounted
## Shared imported surfaces, adapted to the existing material batching and viewmodel path.
## Material name in the model: colour, roughness, metallic, grain scale.
const GUN_FINISH := {
	"ParkerizedSteel": [Color(0.4, 0.42, 0.45), 0.46, 0.62, 5.0],
	"MachinedSteel": [Color(0.74, 0.75, 0.78), 0.3, 0.86, 7.0],
	"TexturedPolymer": [Color(0.2, 0.21, 0.2), 0.62, 0.0, 11.0],
	"OliveHousing": [Color(0.42, 0.43, 0.27), 0.56, 0.12, 8.0],
	"LaminatedWood": [Color(0.5, 0.27, 0.14), 0.46, 0.0, 6.0],
	"RecessBlack": [Color(0.06, 0.06, 0.065), 0.66, 0.1, 5.0],
	"Glass": [Color(0.08, 0.14, 0.2), 0.08, 0.5, 5.0],
	"ImperialBone": [Color(0.84, 0.81, 0.72), 0.46, 0.3, 7.0],
	"ImperialDark": [Color(0.3, 0.3, 0.33), 0.42, 0.72, 6.0],
	"SmokeGrey": [Color(0.86, 0.86, 0.88), 0.6, 0.1, 6.0],
	"WarningRed": [Color(0.85, 0.14, 0.08), 0.5, 0.1, 6.0],
}
## Korpo's machines in droid_parts.glb. Material name: colour, roughness, metallic, and whether it
## takes the cloth weave instead of the machined grain.
const DROID_FINISH := {
	"Suit": [Color(0.075, 0.075, 0.085), 0.66, 0.0, true], "SuitSatin": [Color(0.04, 0.04, 0.046), 0.32, 0.15, false],
	"Shirt": [Color(0.86, 0.86, 0.85), 0.62, 0.0, true], "DroidShell": [Color(0.05, 0.05, 0.058), 0.2, 0.8, false],
	"DroidFace": [Color(0.8, 0.78, 0.74), 0.3, 0.05, false], "Shoe": [Color(0.035, 0.032, 0.032), 0.2, 0.1, false],
	"DroidMetal": [Color(0.72, 0.73, 0.76), 0.18, 0.95, false], "DroidGun": [Color(0.26, 0.27, 0.3), 0.3, 0.8, false],
	"Gold": [Color(0.86, 0.62, 0.22), 0.26, 0.95, false], "Tie": [Color(0.7, 0.7, 0.7), 0.4, 0.0, false],
}
static var _surfaces := {}
static var _loaded := {}
static var _finishes := {}

static func load_model(path: String, team: int, body := false) -> Node3D:
	if not _loaded.has(path):
		_loaded[path] = load(path)
	var root: Node3D = (_loaded[path] as PackedScene).instantiate()
	_clear_owners(root)
	_prepare(root, team, body)
	return root

static func _clear_owners(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owners(child)

static func _prepare(node: Node3D, team: int, body: bool) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		if not child is MeshInstance3D:
			_prepare(child, team, body)
			continue
		var mi := child as MeshInstance3D
		var group := Node3D.new()
		group.transform = mi.transform
		var label := mi.name
		node.remove_child(mi)
		group.name = label
		node.add_child(group)
		for surface in mi.mesh.get_surface_count():
			var key := "%d/%d" % [mi.mesh.get_instance_id(), surface]
			if not _surfaces.has(key):
				_surfaces[key] = _surface_mesh(mi.mesh.surface_get_arrays(surface), body)
			var part := MeshInstance3D.new()
			part.mesh = _surfaces[key]
			var mat := mi.get_active_material(surface) as StandardMaterial3D
			part.material_override = _material(mat, team, body)
			group.add_child(part)
		mi.free()

## Bodies get reduced versions for the distance. A big battle is mostly far-away soldiers.
static func _surface_mesh(arrays: Array, reduce: bool) -> ArrayMesh:
	if not reduce:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(25.0, 60.0, [])
	return importer.get_mesh()


static func _material(mat: StandardMaterial3D, team: int, body: bool) -> Material:
	if mat == null:
		return Mats.flat(Color(.25, .28, .3))
	var key := mat.resource_name
	if key.begins_with("EnergyIndicator"):
		return Mats.glow(C.TEAM_COLORS[team], 2.4 if body and team == C.Team.EMPIRE else 1.2)
	# Night-sight beads: bright enough to find the sight on a dark street.
	if key.begins_with("SightDot"):
		return Mats.glow(Color(0.42, 1.0, 0.5), 2.2)
	if not body:
		return _gun_finish(mat)
	return _body_finish(key.get_slice(".", 0), team, mat)


## The Rebellion's patched cloth, or plain cloth for Korpo. Baked vertex colours shade the folds.
static func _uniform(dark: bool, plain: Color) -> StandardMaterial3D:
	if dark:
		return Mats.cloth(plain)
	var m := Mats.cloth(Color.WHITE).duplicate() as StandardMaterial3D
	m.albedo_texture = Mats.tex("camo_usa")
	m.uv1_scale = Vector3.ONE * 1.5
	return m


## The trooper's colours per side, as [Rebellion, Korpo].
static func _body_finish(key: String, team: int, source: StandardMaterial3D) -> Material:
	var cache := "%d/%s" % [team, key]
	if not _finishes.has(cache):
		var dark := team == C.Team.EMPIRE
		var m: StandardMaterial3D
		if DROID_FINISH.has(key):
			var finish: Array = DROID_FINISH[key]
			m = (Mats.cloth(finish[0]) if finish[3] else Mats.gun(finish[0], finish[1], finish[2])).duplicate() as StandardMaterial3D
			m.roughness = finish[1]
			m.metallic = finish[2]
			if key == "Suit":
				# A cold sheen along the shoulders, so a black suit still reads at night.
				m.rim = 0.3
				m.rim_tint = 0.2
			m.vertex_color_use_as_albedo = true
			_finishes[cache] = m
			return m
		match key:
			"Cloth_Main": m = _uniform(dark, Color(0.3, 0.33, 0.28))
			"Cloth_Dark": m = Mats.cloth(Color(0.19, 0.21, 0.18) if dark else Color(0.2, 0.18, 0.15))
			"Trouser": m = Mats.cloth(Color(0.25, 0.27, 0.23) if dark else Color(0.2, 0.18, 0.15))
			"Hood": m = Mats.cloth(Color(0.2, 0.19, 0.16))
			"Armband": m = Mats.cloth(Color(0.62, 0.07, 0.05))
			"Webbing": m = Mats.cloth(Color(0.17, 0.18, 0.16) if dark else Color(0.24, 0.22, 0.16))
			"ArmorPlate": m = Mats.gun(Color(0.27, 0.28, 0.27), 0.5, 0.2) if dark else Mats.gun(Color(0.3, 0.27, 0.23), 0.62, 0.35)
			"HelmetShell": m = Mats.gun(Color(0.25, 0.27, 0.26), 0.48, 0.25) if dark else _uniform(false, Color.WHITE)
			"Rubber": m = Mats.gun(Color(0.08, 0.08, 0.085), 0.8, 0.0)
			"Leather": m = Mats.gun(Color(0.13, 0.12, 0.11) if dark else Color(0.4, 0.33, 0.23), 0.6, 0.0)
			"Fitting": m = Mats.gun(Color(0.5, 0.51, 0.54), 0.4, 0.8)
			"Glass": m = Mats.gun(Color(0.05, 0.09, 0.13), 0.08, 0.6)
			"MedicCloth": m = Mats.cloth(Color(0.8, 0.81, 0.84))
			"Camouflage": m = Mats.cloth(Color(0.26, 0.29, 0.2))
			"CommandMark": m = Mats.cloth(Color(0.62, 0.1, 0.08) if dark else Color(0.92, 0.92, 0.86))
			"Canister": m = Mats.gun(Color(0.34, 0.32, 0.22) if dark else Color(0.4, 0.38, 0.26), 0.5, 0.4)
			_: return source
		m = m.duplicate() as StandardMaterial3D
		m.vertex_color_use_as_albedo = true
		_finishes[cache] = m
	return _finishes[cache]


## Guns have no UVs, so their grain is projected, and baked vertex colours darken recesses and
## lift worn edges. Those colours only multiply, so paint here is set brighter than it ends up.
static func _gun_finish(source: StandardMaterial3D) -> Material:
	var key := source.resource_name
	if not _finishes.has(key):
		var finish: Array = GUN_FINISH.get(key.get_slice(".", 0), [source.albedo_color, source.roughness, source.metallic, 5.0])
		var m := Mats.gun(finish[0], finish[1], finish[2]).duplicate() as StandardMaterial3D
		m.vertex_color_use_as_albedo = true
		m.normal_scale = 0.7
		m.uv1_scale = Vector3.ONE * finish[3]
		_finishes[key] = m
	return _finishes[key]


static func flatten(root: Node3D) -> void:
	var found: Array = []
	_collect(root, Transform3D.IDENTITY, found)
	for e: Array in found:
		var mi: MeshInstance3D = e[0]
		mi.reparent(root, false)
		mi.transform = e[1]
	for child in root.get_children():
		if not child is MeshInstance3D:
			child.free()

static func _collect(node: Node3D, xf: Transform3D, out: Array) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append([child, xf * child.transform])
		elif child is Node3D:
			_collect(child, xf * child.transform, out)
