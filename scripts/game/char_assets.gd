class_name CharAssets
extends RefCounted
## The skinned soldiers from tools/blender_korpo.py and tools/blender_rebels.py.
##
## A file holds one skeleton and the meshes that hang on it: bodies, heads and each class's gear,
## every one built at three levels of detail and each a single surface. `character.gdshader` reads
## the paint and the kind of material from the vertex colours, so a soldier costs three draw calls
## however much it wears.

const DIR := "res://assets/models/chars/"
## Metres at which each level of detail takes over. The finest carries parts a few millimetres
## across, which shimmer once they are smaller than a pixel, so it gives way early.
const LOD_FROM := [0.0, 5.5, 26.0]

## What each class wears: the file, then the body, head and gear meshes in it.
const LOOKS := {
	"grenadier": ["korpo", "Body_Reg", "Head_Reg", ""],
	"hunter": ["korpo", "Body_Reg", "Head_Auditor", "Gear_hunter"],
	"heavy": ["korpo_big", "Body_Big", "Head_Big", ""],
	"servicer": ["korpo", "Body_Reg", "Head_Reg", "Gear_servicer"],
	"marshal": ["korpo", "Body_Reg", "Head_Director", "Gear_marshal"],
	"droid_engineer": ["korpo", "Body_Reg", "Head_Reg", "Gear_tech"],
	"phantom": ["korpo", "Body_Cmd", "Head_Hat", ""],
	"fighter": ["rebel", "Body_Reb", "Head_fighter", "Gear_fighter"],
	"medic": ["rebel", "Body_Reb", "Head_medic", "Gear_medic"],
	"sniper": ["rebel", "Body_Reb", "Head_sniper", "Gear_sniper"],
	"engineer": ["rebel", "Body_Reb", "Head_engineer", "Gear_engineer"],
	"commander": ["rebel", "Body_Reb", "Head_leader", "Gear_leader"],
	"gunner": ["rebel", "Body_Reb", "Head_gunner", "Gear_gunner"],
	"maccabee": ["rebel", "Body_Reb", "Head_jumper", "Gear_jumper"],
}
## Before a class is chosen, and for classes not listed.
const DEFAULT_LOOK := [["rebel", "Body_Reb", "Head_fighter", "Gear_fighter"], ["korpo", "Body_Reg", "Head_Reg", ""]]

## How each class is built, as multiples of the body the meshes were modelled on:
## [height, width of shoulders and chest, depth of chest, girth of arms, girth of legs, width of hips].
## The skeleton stretches the one mesh, so a slight scout and a hulking gunner cost nothing extra.
const BUILDS := {
	"grenadier": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	"hunter": [1.03, 0.9, 0.9, 0.86, 0.88, 0.92],
	"heavy": [1.16, 1.12, 1.1, 1.1, 1.12, 1.1],
	"servicer": [0.97, 0.95, 0.96, 0.94, 0.95, 0.97],
	"marshal": [1.05, 1.06, 1.03, 1.0, 1.0, 1.02],
	"droid_engineer": [0.98, 1.08, 1.08, 1.1, 1.08, 1.08],
	"phantom": [1.06, 0.94, 0.94, 0.9, 0.92, 0.95],
	"fighter": [0.95, 0.9, 0.9, 0.88, 0.9, 0.92],
	"medic": [0.97, 0.96, 0.97, 0.94, 0.96, 0.98],
	"sniper": [1.03, 0.88, 0.88, 0.84, 0.86, 0.9],
	"engineer": [0.98, 1.1, 1.12, 1.12, 1.1, 1.1],
	"commander": [1.04, 1.05, 1.03, 1.02, 1.02, 1.03],
	"gunner": [1.14, 1.3, 1.28, 1.34, 1.26, 1.24],
	"maccabee": [1.0, 0.97, 0.96, 0.96, 0.98, 0.97],
}
const DEFAULT_BUILD := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
## The Rebellion is people, and no two are alike: the skin each class's meshes are painted with.
const SKINS := {
	"fighter": Color(0.8, 0.6, 0.48), "medic": Color(0.55, 0.36, 0.25), "sniper": Color(0.86, 0.68, 0.56), "engineer": Color(0.72, 0.5, 0.38),
	"commander": Color(0.64, 0.44, 0.32), "gunner": Color(0.78, 0.58, 0.46), "maccabee": Color(0.46, 0.3, 0.21),
}
const DEFAULT_SKIN := Color(0.76, 0.56, 0.44)


## One file, read once: the skeleton's joints and every mesh by name.
class Rig:
	var bones := PackedStringArray()
	var parents := PackedInt32Array()
	var rests: Array[Transform3D] = []
	var skin: Skin
	var meshes := {}

	func rest_of(bone: String) -> Vector3:
		return rests[bones.find(bone)].origin


static var _rigs := {}
static var _materials := {}
## Scales every level's distance: a scope brings far soldiers close, so they need the near mesh.
static var zoom := 1.0


static func look(team: int, class_id: String) -> Array:
	return LOOKS.get(class_id, DEFAULT_LOOK[team])


static func build(class_id: String) -> Array:
	return BUILDS.get(class_id, DEFAULT_BUILD)


## The colour the shader paints a class's own marks with: Korpo's tie, or the Rebellion's skin.
static func tint(team: int, cd: Dictionary) -> Color:
	if cd.has("tie"):
		return C.TIE_COLORS[cd["tie"]]
	return SKINS.get(String(cd["id"]), DEFAULT_SKIN) if team == C.Team.RESISTANCE else Color.BLACK


static func rig(key: String) -> Rig:
	if _rigs.has(key):
		return _rigs[key]
	var r := Rig.new()
	var root: Node = (load(DIR + key + ".glb") as PackedScene).instantiate()
	var skeleton := root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for i in skeleton.get_bone_count():
		r.bones.append(skeleton.get_bone_name(i))
		r.parents.append(skeleton.get_bone_parent(i))
		r.rests.append(skeleton.get_bone_rest(i))
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		r.meshes[String(mi.name)] = mi.mesh
		if mi.skin:
			r.skin = mi.skin
	root.free()
	_rigs[key] = r
	return r


## The skeleton is flat: every bone hangs straight off the root and SoldierModel hands each its
## place in the body. That lets a bone be made thicker or thinner without its children inheriting
## the stretch, which is how one mesh serves every build.
static func skeleton(r: Rig) -> Skeleton3D:
	var s := Skeleton3D.new()
	var placed: Array[Transform3D] = []
	for i in r.bones.size():
		s.add_bone(r.bones[i])
		var rest := r.rests[i]
		if r.parents[i] >= 0:
			rest = placed[r.parents[i]] * rest
		placed.append(rest)
		s.set_bone_rest(i, rest)
		s.set_bone_pose(i, rest)
	return s


## The lowest level of detail this machine draws: browsers and the low preset skip the finest.
static func first_level() -> int:
	return 1 if OS.has_feature("web") or Settings.quality == 0 else 0


## Every level of one mesh, each showing over its own range of distances.
## `always_fine` is for a model looked at on its own, such as the class preview.
static func fit(parent: Skeleton3D, r: Rig, label: String, team: int, tint := Color.BLACK, always_fine := false) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var first := 0 if always_fine else first_level()
	for level in range(first, 3):
		var key := "%s_L%d" % [label, level]
		if not r.meshes.has(key):
			continue
		var mi := MeshInstance3D.new()
		mi.name = key
		mi.mesh = r.meshes[key]
		mi.skin = r.skin
		mi.material_override = material(team, tint, level == 0)
		mi.set_meta("level", level)
		mi.set_meta("first", level == first)
		parent.add_child(mi)
		mi.skeleton = NodePath("..")
		mi.add_to_group(&"char_lod")
		_range(mi)
		out.append(mi)
	return out


## The levels hand over at one exact distance, with no margin either side. A margin makes each
## mesh wait before it changes, and two meshes waiting on each other leave a band of distances
## where neither is drawn: the soldier blinks out as it crosses.
static func _range(mi: MeshInstance3D) -> void:
	var level: int = mi.get_meta("level")
	mi.visibility_range_begin = 0.0 if mi.get_meta("first") else LOD_FROM[level] * zoom
	mi.visibility_range_end = 0.0 if level == 2 else LOD_FROM[level + 1] * zoom
	mi.visibility_range_begin_margin = 0.0
	mi.visibility_range_end_margin = 0.0


## Called when the player's view zooms in or out: `factor` is how much closer things look.
static func set_zoom(factor: float, tree: SceneTree) -> void:
	factor = clampf(snappedf(factor, 0.5), 1.0, 8.0)
	if is_equal_approx(factor, zoom):
		return
	zoom = factor
	for mi: MeshInstance3D in tree.get_nodes_in_group("char_lod"):
		_range(mi)


static func material(team: int, tint: Color, fine: bool) -> ShaderMaterial:
	var key := "%d/%s/%s" % [team, tint.to_html(false), fine]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/character.gdshader" if fine else "res://shaders/character_far.gdshader")
		if fine:
			m.set_shader_parameter("weave_normal", Mats.tex("fabric_normal"))
		m.set_shader_parameter("glow", C.TEAM_COLORS[team])
		m.set_shader_parameter("glow_energy", 2.6 if team == C.Team.EMPIRE else 1.6)
		m.set_shader_parameter("tint", tint)
		_materials[key] = m
	return _materials[key]


## Loads the files and compiles the shaders during loading rather than at the first spawn.
static func warm() -> void:
	for look_of: Array in LOOKS.values() + DEFAULT_LOOK:
		rig(look_of[0])
	for team in 2:
		material(team, Color.BLACK, true)
		material(team, Color.BLACK, false)
