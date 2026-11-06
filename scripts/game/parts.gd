class_name P
extends RefCounted
## Tiny construction kit for models made of primitives. Meshes are cached by size.

static var _meshes := {}
static var _merged := {}


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var key := "b%s" % size
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _add(parent, _meshes[key], pos, mat, rot)


## Cylinder along local Y unless rotated.
static func cyl(parent: Node3D, r_top: float, r_bottom: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, scale := Vector3.ONE, sides := 12) -> MeshInstance3D:
	var key := "c%.3f|%.3f|%.3f|%d" % [r_top, r_bottom, h, sides]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = r_top
		m.bottom_radius = r_bottom
		m.height = h
		m.radial_segments = sides
		m.rings = 1
		_meshes[key] = m
	return _add(parent, _meshes[key], pos, mat, rot, scale)


static func ball(parent: Node3D, r: float, pos: Vector3, mat: Material, scale := Vector3.ONE) -> MeshInstance3D:
	var key := "s%.3f" % r
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 14
		m.rings = 8
		_meshes[key] = m
	return _add(parent, _meshes[key], pos, mat, Vector3.ZERO, scale)


## Thin ring facing along local Z, for sights.
static func ring(parent: Node3D, r: float, thickness: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var key := "t%.3f|%.3f" % [r, thickness]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = r - thickness
		m.outer_radius = r + thickness
		m.rings = 28
		m.ring_segments = 6
		_meshes[key] = m
	return _add(parent, _meshes[key], pos, mat, Vector3(PI * 0.5, 0, 0))


static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var key := "p%.3f|%.3f" % [r, h]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = 10
		m.rings = 3
		_meshes[key] = m
	return _add(parent, _meshes[key], pos, mat, rot)


## Folds the rigid parts on each node under `root` into one instance per node. Moving a body
## then touches a dozen instances instead of a hundred, and bodies alike share their meshes.
static func merge(root: Node3D) -> void:
	for child in root.get_children():
		if child is Node3D and not child is MeshInstance3D:
			merge(child)
	var parts := _collect(root, Transform3D.IDENTITY, false)
	for group: Array in _grouped(parts).values():
		if group.size() < 2:
			continue
		place(root, _fold(group))
		for part: Dictionary in group:
			(part["node"] as Node).free()


## Everything under `root` as ready-made instances, for models that never move their parts.
## Pass them to `place`; the source is left as it was.
static func folded(root: Node3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for group: Array in _grouped(_collect(root, Transform3D.IDENTITY, true)).values():
		out.append(_fold(group))
	return out


static func place(parent: Node3D, spec: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = spec["mesh"]
	mi.cast_shadow = spec["shadow"]
	mi.visibility_range_end = spec["range"]
	mi.transparency = spec["fade"]
	parent.add_child(mi)


## Hidden parts stay out of it: something means to switch them on later.
static func _collect(node: Node3D, xf: Transform3D, deep: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child in node.get_children():
		if not child is Node3D:
			continue
		var c := child as Node3D
		var at := xf * c.transform
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.visible and mi.material_override != null and mi.mesh.get_surface_count() == 1:
				out.append({"node": mi, "xf": at})
		if deep:
			out.append_array(_collect(c, at, true))
	return out


## Parts can only share an instance if they are drawn under the same rules.
static func _grouped(parts: Array[Dictionary]) -> Dictionary:
	var groups := {}
	for part: Dictionary in parts:
		var mi: MeshInstance3D = part["node"]
		var key := "%d|%.2f|%.2f" % [mi.cast_shadow, mi.visibility_range_end, mi.transparency]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(part)
	return groups


static func _fold(group: Array) -> Dictionary:
	var first: MeshInstance3D = group[0]["node"]
	var key := ""
	for part: Dictionary in group:
		var mi: MeshInstance3D = part["node"]
		key += "%d/%d/%s;" % [mi.mesh.get_instance_id(), mi.material_override.get_instance_id(), part["xf"]]
	if not _merged.has(key):
		_merged[key] = _bake(group)
	return {"mesh": _merged[key], "shadow": first.cast_shadow, "range": first.visibility_range_end, "fade": first.transparency}


## One surface per material. Materials here project their maps, so only positions and
## normals have to move with the part. Baked vertex colours come along where a model has them.
static func _bake(group: Array) -> ArrayMesh:
	var by_material := {}
	for part: Dictionary in group:
		var mat: Material = (part["node"] as MeshInstance3D).material_override
		if not by_material.has(mat):
			by_material[mat] = []
		by_material[mat].append(part)
	var out := ArrayMesh.new()
	for mat: Material in by_material:
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		for part: Dictionary in by_material[mat]:
			var xf: Transform3D = part["xf"]
			var src: Array = (part["node"] as MeshInstance3D).mesh.surface_get_arrays(0)
			var base := verts.size()
			verts.append_array(xf * (src[Mesh.ARRAY_VERTEX] as PackedVector3Array))
			if src[Mesh.ARRAY_TEX_UV] != null:
				uvs.append_array(src[Mesh.ARRAY_TEX_UV])
			if src[Mesh.ARRAY_COLOR] != null:
				colors.append_array(src[Mesh.ARRAY_COLOR])
			var turned: PackedVector3Array = Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * (src[Mesh.ARRAY_NORMAL] as PackedVector3Array)
			for n: Vector3 in turned:
				normals.append(n.normalized())
			for i: int in src[Mesh.ARRAY_INDEX]:
				indices.append(base + i)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		if uvs.size() == verts.size():
			arrays[Mesh.ARRAY_TEX_UV] = uvs
		if colors.size() == verts.size():
			arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


## Swaps every material under `root` for its first-person variant.
static func to_viewmodel(root: Node) -> void:
	for child in root.get_children():
		if child.name == &"LaserLine":
			child.free()
		else:
			to_viewmodel(child)
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.material_override is StandardMaterial3D:
			mi.material_override = Mats.viewmodel(mi.material_override)
