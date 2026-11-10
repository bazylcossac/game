class_name SoldierModel
extends Node3D
## Third-person body assembled from primitives and animated procedurally.
## The Rebellion hides behind hoods and respirators; Korpo's machines wear suits and a porcelain face.
##
## Axis conventions, since every pose depends on them. The body faces -Z.
##   hip.rotation.x    positive swings the thigh forward.
##   knee.rotation.x   negative bends the shin back, as a real knee does.
##   torso.rotation.x  positive leans back.
##   a gun's rotation.x positive raises the muzzle.
##   a blade's rotation.x negative tips the blade forward.

const PRONE_HIP := 0.2
const PRONE_REACH := 0.72
## How far the chest props up, and what head and gun turn back to look level.
const PRONE_CHEST := 0.5
const PRONE_LEVEL := PI * 0.5 - PRONE_CHEST
const UPPER_ARM := 0.29
const FOREARM := 0.28
const THIGH := 0.45
const SHIN := 0.45
const STAND_HIP := 0.95
const SWING_TIME := 0.5
const THROW_TIME := 0.62
const DETAIL_RANGE := 42.0
## Class id to its modelled kit in trooper_parts.glb.
const GEAR_MODELS := {
	"medic": "Gear_medic", "sniper": "Gear_sniper", "engineer": "Gear_engineer", "maccabee": "Gear_maccabee",
	"commander": "Gear_leader", "hunter": "Gear_hunter", "marshal": "Gear_marshal", "servicer": "Gear_servicer",
}
const TROOPER_MODEL := "res://assets/models/armory/trooper_parts.glb"
const DROID_MODEL := "res://assets/models/armory/droid_parts.glb"
## Where the liquidator's weapon arms end, below the elbow: the cannon's bore and the pod's tubes.
const ARM_MUZZLE := {C.W.ARM_CANNON: Vector3(0.0, -0.56, 0.0), C.W.ARM_ROCKETS: Vector3(0.0, -0.49, -0.07)}
## A heavy droid stands this much taller than the others, on the same skeleton.
const BIG_FRAME_SCALE := 1.13

## Blade poses in torso space: [time, hand, blade rotation, torso twist].
const SWINGS := [
	[
		[0.0, Vector3(0.24, 0.2, -0.26), Vector3(-0.6, 0.0, -0.2), 0.0],
		[0.24, Vector3(0.4, 0.52, -0.08), Vector3(0.3, 0.0, -1.1), -0.5],
		[0.5, Vector3(0.04, 0.4, -0.5), Vector3(-1.4, 0.0, 0.1), 0.2],
		[0.7, Vector3(-0.22, 0.1, -0.36), Vector3(-1.7, 0.3, 1.2), 0.6],
		[1.0, Vector3(0.24, 0.2, -0.26), Vector3(-0.6, 0.0, -0.2), 0.0],
	],
	[
		[0.0, Vector3(0.24, 0.2, -0.26), Vector3(-0.6, 0.0, -0.2), 0.0],
		[0.24, Vector3(-0.2, 0.5, -0.2), Vector3(0.2, 0.0, 1.1), 0.5],
		[0.5, Vector3(0.1, 0.38, -0.5), Vector3(-1.3, 0.0, -0.1), -0.1],
		[0.7, Vector3(0.44, 0.12, -0.26), Vector3(-1.6, -0.3, -1.3), -0.55],
		[1.0, Vector3(0.24, 0.2, -0.26), Vector3(-0.6, 0.0, -0.2), 0.0],
	],
	[
		[0.0, Vector3(0.24, 0.2, -0.26), Vector3(-0.6, 0.0, -0.2), 0.0],
		[0.26, Vector3(0.16, 0.74, -0.06), Vector3(0.7, 0.0, -0.1), -0.15],
		[0.52, Vector3(0.1, 0.34, -0.52), Vector3(-1.5, 0.0, 0.0), 0.05],
		[0.72, Vector3(0.08, 0.02, -0.42), Vector3(-2.1, 0.0, 0.0), 0.1],
		[1.0, Vector3(0.24, 0.2, -0.26), Vector3(-0.6, 0.0, -0.2), 0.0],
	],
]

var team := 0
## Set just before the shield is taken away because it broke, so it goes out the hard way.
var shield_broken_next := false
## How far the body leans round a corner, -1 left to 1 right, set by the soldier before each pose.
var lean := 0.0
var pelvis: Node3D
var torso: Node3D
var head: Node3D
var shoulder_r: Node3D
var elbow_r: Node3D
var shoulder_l: Node3D
var elbow_l: Node3D
var hip_r: Node3D
var knee_r: Node3D
var ankle_r: Node3D
var hip_l: Node3D
var knee_l: Node3D
var ankle_l: Node3D
var holder: Node3D
var weapon_node: Node3D
var weapon_id := -1
var weapon_parts: Array = []

## Seconds between limb updates, chosen by Soldier from the distance. 0 means every frame.
var pose_interval := 0.0

var phase := 0.0
var _pose_wait := 0.0
var _crouch := 0.0
var _prone := 0.0
## Lying flat, set by the soldier before each pose.
var prone := false
var _swing := -1.0
var _combo := 0
var _death := -1.0
var _fall_back := 1.0
var _corpse_t := 0.0
var _kick := 0.0
var _block := 0.0
var _ready_gun := 0.0
var _sprint := 0.0
var _air := 0.0
var _reload := 0.0
var _throw := -1.0
var _breath := 0.0
var _flinch := Vector2.ZERO
var _grip_r := Vector3.ZERO
var _grip_l := Vector3.ZERO
var _aim_pos := Vector3.ZERO
var _low_pos := Vector3.ZERO
var _local_vel := Vector2.ZERO
var _grounded := true
var _reloading := false
var _sprinting := false
var _gear: Node3D
var _head_gear: Node3D
var _frame := ""
var _frame_parts: Array[Node3D] = []
var _jet_flames: Node3D
var _cloak_shown := -1.0
var _flaps: Array[Node3D] = []
var _nade: Node3D
var _nade_items: Array[Node3D] = []
var _trail: BladeTrail


## Bakes every body, class kit and standard weapon during loading, so that the first
## soldier to spawn with each of them does not stall the match.
static func warm_bodies() -> void:
	for team in 2:
		var m := SoldierModel.new()
		m.setup(team)
		for class_id in C.CLASSES[team].size():
			var cd := C.cls(team, class_id)
			if cd.get("mech", false) or cd.get("vehicle", false):
				continue
			if cd.has("frame"):
				m._apply_frame(cd["frame"])
			m._build_gear(cd)
			for weapon: int in cd["weapons"]:
				if not C.WEAPONS[weapon].get("arm", false):
					WeaponFactory.third_person(weapon, team).free()
		m.free()


func _cloth(color: Color) -> Material:
	return Mats.cloth(color)


## Small parts are skipped beyond detail range and cast no shadow: nobody can see them there.
static func _fine(mi: MeshInstance3D) -> MeshInstance3D:
	mi.visibility_range_end = DETAIL_RANGE
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func setup(new_team: int) -> void:
	team = new_team
	var empire := team == C.Team.EMPIRE
	# The cheap far body, in the same colours as the modelled one: black suits, or patched cloth.
	var coat: Material = _cloth(Color(0.07, 0.07, 0.08)) if empire else _cloth(Color(0.3, 0.28, 0.22))
	var coat_dark: Material = _cloth(Color(0.04, 0.04, 0.05)) if empire else _cloth(Color(0.2, 0.19, 0.16))
	var trousers: Material = _cloth(Color(0.07, 0.07, 0.08)) if empire else _cloth(Color(0.2, 0.23, 0.28))
	var leather: Material = Mats.flat(Color(0.03, 0.03, 0.03) if empire else Color(0.27, 0.18, 0.11), 0.3 if empire else 0.46)
	var strap: Material = Mats.flat(Color(0.05, 0.05, 0.06) if empire else Color(0.34, 0.29, 0.2), 0.7)
	var helmet: Material = Mats.flat(Color(0.78, 0.76, 0.72), 0.3, 0.05) if empire else _cloth(Color(0.2, 0.19, 0.16))
	var mask: Material = _cloth(Color(0.08, 0.08, 0.085))
	var metal: Material = Mats.flat(Color(0.42, 0.44, 0.47), 0.36, 0.85)
	var glow: Material = Mats.glow(C.TEAM_COLORS[team], 2.4 if empire else 1.8)
	var scarf: Material = _cloth(Color(0.86, 0.86, 0.85) if empire else Color(0.62, 0.07, 0.05))
	var accent: Material = _cloth(Color(0.04, 0.04, 0.05) if empire else Color(0.62, 0.07, 0.05))

	pelvis = Node3D.new()
	pelvis.position.y = STAND_HIP
	add_child(pelvis)
	P.cyl(pelvis, 0.19, 0.17, 0.2, Vector3(0, -0.02, 0), trousers, Vector3.ZERO, Vector3(1, 1, 0.72), 10)
	P.cyl(pelvis, 0.2, 0.2, 0.055, Vector3(0, 0.09, 0), leather, Vector3.ZERO, Vector3(1, 1, 0.74), 10)
	_fine(P.box(pelvis, Vector3(0.06, 0.05, 0.012), Vector3(0, 0.09, -0.15), metal))
	_fine(P.box(pelvis, Vector3(0.1, 0.13, 0.07), Vector3(0.2, -0.02, -0.02), leather))
	_fine(P.cyl(pelvis, 0.05, 0.05, 0.15, Vector3(-0.2, -0.03, 0.05), strap, Vector3.ZERO, Vector3.ONE, 8))
	# Coat skirts hang from the belt and swing as separate flaps.
	for side: float in [-1.0, 1.0]:
		var flap := Node3D.new()
		flap.position = Vector3(0.095 * side, 0.06, 0.02)
		pelvis.add_child(flap)
		var length := 0.12 if empire else 0.24
		P.box(flap, Vector3(0.2, length, 0.26), Vector3(0, -length * 0.5, 0), coat)
		_flaps.append(flap)

	torso = Node3D.new()
	torso.position.y = 0.08
	pelvis.add_child(torso)
	P.cyl(torso, 0.21, 0.185, 0.28, Vector3(0, 0.14, 0), coat, Vector3.ZERO, Vector3(1, 1, 0.74), 12)
	P.ball(torso, 0.25, Vector3(0, 0.36, 0), coat, Vector3(1.04, 0.86, 0.72))
	P.cyl(torso, 0.1, 0.26, 0.09, Vector3(0, 0.55, 0), coat_dark, Vector3.ZERO, Vector3(1, 1, 0.7), 12)
	P.cyl(torso, 0.092, 0.11, 0.09, Vector3(0, 0.62, 0), scarf, Vector3.ZERO, Vector3.ONE, 10)
	# Chest rig: crossed straps and energy cell pouches with lit tips.
	P.box(torso, Vector3(0.05, 0.56, 0.02), Vector3(0.08, 0.3, -0.18), strap, Vector3(-0.08, 0, 0.3))
	P.box(torso, Vector3(0.05, 0.56, 0.02), Vector3(-0.08, 0.3, -0.18), strap, Vector3(-0.08, 0, -0.3))
	P.box(torso, Vector3(0.3, 0.13, 0.05), Vector3(0, 0.14, -0.175), strap)
	for x: float in [-0.1, 0.0, 0.1]:
		_fine(P.box(torso, Vector3(0.082, 0.12, 0.05), Vector3(x, 0.16, -0.2), leather))
		P.box(torso, Vector3(0.05, 0.014, 0.01), Vector3(x, 0.2, -0.228), glow)
	P.box(torso, Vector3(0.2, 0.018, 0.01), Vector3(0, 0.41, -0.2), glow, Vector3(-0.1, 0, 0))
	if empire:
		for y: float in [0.08, 0.2, 0.32, 0.44]:
			_fine(P.ball(torso, 0.011, Vector3(0.1, y, -0.172), metal))
		for side: float in [-1.0, 1.0]:
			_fine(P.box(torso, Vector3(0.11, 0.018, 0.07), Vector3(0.21 * side, 0.525, 0), accent, Vector3(0, 0, -0.26 * side)))
	else:
		_fine(P.box(torso, Vector3(0.1, 0.1, 0.02), Vector3(0.13, 0.36, -0.2), coat_dark, Vector3(-0.08, 0, 0)))
	# Pack with a rolled blanket on top.
	P.box(torso, Vector3(0.32, 0.38, 0.14), Vector3(0, 0.29, 0.2), coat_dark)
	P.cyl(torso, 0.06, 0.06, 0.38, Vector3(0, 0.51, 0.2), trousers, Vector3(0, 0, PI * 0.5), Vector3.ONE, 8)
	_fine(P.box(torso, Vector3(0.05, 0.06, 0.02), Vector3(0.1, 0.32, 0.28), leather))
	_fine(P.box(torso, Vector3(0.05, 0.06, 0.02), Vector3(-0.1, 0.32, 0.28), leather))
	P.cyl(torso, 0.012, 0.012, 0.3, Vector3(0, 0.42, 0.28), glow, Vector3(0, 0, PI * 0.5), Vector3.ONE, 6)
	if not empire:
		# A scarf end that trails behind the shoulder.
		var tail := Node3D.new()
		tail.position = Vector3(0.05, 0.6, 0.1)
		torso.add_child(tail)
		P.box(tail, Vector3(0.09, 0.3, 0.02), Vector3(0, -0.15, 0.02), scarf)
		_flaps.append(tail)

	head = Node3D.new()
	head.position.y = 0.53
	torso.add_child(head)
	P.ball(head, 0.112, Vector3(0, 0.08, 0), mask, Vector3(0.95, 1.08, 1.0))
	if empire:
		P.ball(head, 0.135, Vector3(0, 0.125, 0), helmet, Vector3(1.03, 0.9, 1.1))
		P.box(head, Vector3(0.17, 0.042, 0.04), Vector3(0, 0.075, -0.105), glow)
		P.cyl(head, 0.05, 0.042, 0.1, Vector3(0, -0.005, -0.1), mask, Vector3(PI * 0.5, 0, 0), Vector3.ONE, 10)
		_fine(P.cyl(head, 0.03, 0.03, 0.05, Vector3(0.07, -0.02, -0.08), metal, Vector3(PI * 0.5, 0, 0.5), Vector3.ONE, 8))
	else:
		P.ball(head, 0.134, Vector3(0, 0.12, 0), helmet, Vector3(1.05, 0.82, 1.1))
		P.cyl(head, 0.19, 0.2, 0.016, Vector3(0, 0.1, 0.0), helmet, Vector3.ZERO, Vector3(1, 1, 1.05), 14)
		for side: float in [-1.0, 1.0]:
			P.box(head, Vector3(0.086, 0.052, 0.03), Vector3(0.052 * side, 0.07, -0.105), glow)
			_fine(P.cyl(head, 0.034, 0.034, 0.016, Vector3(0.052 * side, 0.07, -0.122), metal, Vector3(PI * 0.5, 0, 0), Vector3.ONE, 10))
		P.box(head, Vector3(0.215, 0.012, 0.02), Vector3(0, 0.07, -0.098), leather)
		_fine(P.cyl(head, 0.044, 0.05, 0.05, Vector3(0, -0.01, -0.1), scarf, Vector3(PI * 0.5, 0, 0), Vector3.ONE, 10))
	_fine(P.box(head, Vector3(0.012, 0.13, 0.012), Vector3(0.115, 0.0, -0.02), strap))
	_fine(P.box(head, Vector3(0.012, 0.13, 0.012), Vector3(-0.115, 0.0, -0.02), strap))

	var arm := func(side: float) -> Array:
		var sh := Node3D.new()
		sh.position = Vector3(0.28 * side, 0.47, 0)
		torso.add_child(sh)
		P.ball(sh, 0.086, Vector3.ZERO, coat, Vector3(1.05, 1.0, 1.0))
		P.cyl(sh, 0.074, 0.056, UPPER_ARM, Vector3(0, -UPPER_ARM * 0.5, 0), coat, Vector3.ZERO, Vector3.ONE, 10)
		if side < 0.0:
			P.cyl(sh, 0.073, 0.069, 0.075, Vector3(0, -0.13, 0), accent, Vector3.ZERO, Vector3.ONE, 10)
		var el := Node3D.new()
		el.position.y = -UPPER_ARM
		sh.add_child(el)
		P.ball(el, 0.058, Vector3.ZERO, coat_dark)
		P.cyl(el, 0.056, 0.042, FOREARM - 0.03, Vector3(0, -FOREARM * 0.46, 0), coat, Vector3.ZERO, Vector3.ONE, 10)
		P.cyl(el, 0.048, 0.05, 0.06, Vector3(0, -FOREARM + 0.05, 0), leather, Vector3.ZERO, Vector3.ONE, 10)
		P.box(el, Vector3(0.075, 0.09, 0.05), Vector3(0, -FOREARM - 0.02, 0), leather)
		_fine(P.box(el, Vector3(0.07, 0.05, 0.03), Vector3(0, -FOREARM - 0.08, -0.018), leather))
		_fine(P.capsule(el, 0.013, 0.06, Vector3(0.042 * side, -FOREARM - 0.02, -0.018), leather))
		return [sh, el]
	var ar: Array = arm.call(1.0)
	shoulder_r = ar[0]
	if not empire:
		_fine(Forge.decal(shoulder_r, "flag_usa", Vector2(0.1, 0.0625), Vector3(0.082, -0.1, 0.0), Vector3(0, PI * 0.5, 0)))
	elbow_r = ar[1]
	var al: Array = arm.call(-1.0)
	shoulder_l = al[0]
	elbow_l = al[1]

	var leg := func(side: float) -> Array:
		var hip := Node3D.new()
		hip.position = Vector3(0.1 * side, -0.05, 0)
		pelvis.add_child(hip)
		P.cyl(hip, 0.096, 0.07, THIGH, Vector3(0, -THIGH * 0.5, 0), trousers, Vector3.ZERO, Vector3.ONE, 10)
		if not empire:
			_fine(P.box(hip, Vector3(0.05, 0.13, 0.13), Vector3(0.09 * side, -0.2, 0), strap))
		var kn := Node3D.new()
		kn.position.y = -THIGH
		hip.add_child(kn)
		P.ball(kn, 0.07, Vector3.ZERO, trousers)
		_fine(P.ball(kn, 0.064, Vector3(0, 0, -0.026), leather, Vector3(0.9, 1.0, 0.6)))
		P.cyl(kn, 0.07, 0.054, SHIN - 0.17, Vector3(0, -(SHIN - 0.17) * 0.5, 0), trousers, Vector3.ZERO, Vector3.ONE, 10)
		P.cyl(kn, 0.07, 0.062, 0.22, Vector3(0, -SHIN + 0.11, 0), leather, Vector3.ZERO, Vector3.ONE, 10)
		var ank := Node3D.new()
		ank.position.y = -SHIN
		kn.add_child(ank)
		P.box(ank, Vector3(0.105, 0.075, 0.27), Vector3(0, -0.012, -0.06), leather)
		P.ball(ank, 0.056, Vector3(0, -0.005, -0.18), leather, Vector3(0.95, 0.7, 1.2))
		_fine(P.box(ank, Vector3(0.114, 0.018, 0.29), Vector3(0, -0.05, -0.06), strap))
		return [hip, kn, ank]
	var lr: Array = leg.call(1.0)
	hip_r = lr[0]
	knee_r = lr[1]
	ankle_r = lr[2]
	var ll: Array = leg.call(-1.0)
	hip_l = ll[0]
	knee_l = ll[1]
	ankle_l = ll[2]

	holder = Node3D.new()
	torso.add_child(holder)
	P.merge(self)
	_add_imported_body()
	_nade = Node3D.new()
	_nade.position = Vector3(0, -FOREARM - 0.09, -0.04)
	_nade.visible = false
	elbow_r.add_child(_nade)
	for kind in C.NADE_NAMES.size():
		var item := Node3D.new()
		_nade.add_child(item)
		WeaponFactory.fit(item, "Nade_%d" % kind, team)
		_nade_items.append(item)


func _add_imported_body() -> void:
	# The existing inexpensive body becomes a distant LOD. Both use the same joint pivots.
	_set_legacy_range(self)
	if team == C.Team.EMPIRE:
		_apply_frame("Reg")
		return
	var imported := ModelAssets.load_model(TROOPER_MODEL, team, true)
	var bones := {"Pelvis": pelvis, "Torso": torso, "Head": head, "UpperArm_R": shoulder_r, "UpperArm_L": shoulder_l, "Forearm_R": elbow_r, "Forearm_L": elbow_l, "Thigh_R": hip_r, "Thigh_L": hip_l, "Shin_R": knee_r, "Shin_L": knee_l, "Boot_R": ankle_r, "Boot_L": ankle_l}
	for label: String in bones:
		var part := imported.find_child(label, true, false) as Node3D
		if part:
			part.reparent(bones[label], false)
			ModelAssets.flatten(part)
			for mesh: MeshInstance3D in part.get_children():
				mesh.visibility_range_end = 53
	imported.free()


func _set_legacy_range(node: Node3D) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.visibility_range_begin = 53
			child.visibility_range_end = 0
		elif child is Node3D:
			_set_legacy_range(child)


func set_loadout(new_weapon: int, class_id: int, parts: Array = []) -> void:
	set_weapon(new_weapon, parts)
	var cd := C.cls(team, class_id)
	if cd.has("frame"):
		_apply_frame(cd["frame"])
	_build_gear(cd)
	_cloak_shown = -1.0


func _fit_gear(label: String, onto: Node3D = null) -> void:
	var imported := ModelAssets.load_model(DROID_MODEL if team == C.Team.EMPIRE else TROOPER_MODEL, team, true)
	var part := imported.find_child(label, true, false) as Node3D
	part.reparent(onto if onto else _gear, false)
	part.transform = Transform3D.IDENTITY
	ModelAssets.flatten(part)
	imported.free()


## The Empire's machines differ per class, so the body is put on when the class is known.
func _apply_frame(frame: String) -> void:
	if frame == _frame:
		return
	_frame = frame
	for part: Node3D in _frame_parts:
		part.free()
	_frame_parts.clear()
	scale = Vector3.ONE * (BIG_FRAME_SCALE if frame == "Big" else 1.0)
	var imported := ModelAssets.load_model(DROID_MODEL, team, true)
	var bones := {"Pelvis": pelvis, "Torso": torso, "Head": head, "UpperArm_R": shoulder_r, "UpperArm_L": shoulder_l, "Forearm_R": elbow_r, "Forearm_L": elbow_l, "Thigh_R": hip_r, "Thigh_L": hip_l, "Shin_R": knee_r, "Shin_L": knee_l, "Boot_R": ankle_r, "Boot_L": ankle_l}
	for label: String in bones:
		var part := imported.find_child("%s_%s" % [frame, label], true, false) as Node3D
		if part:
			part.reparent(bones[label], false)
			ModelAssets.flatten(part)
			for mesh: MeshInstance3D in part.get_children():
				mesh.visibility_range_end = 53
			_frame_parts.append(part)
	imported.free()


## Class gear hung on the shared body, so a class reads at a glance from a distance.
func _build_gear(cd: Dictionary) -> void:
	var id := String(cd["id"])
	if _gear:
		_gear.free()
	if _head_gear:
		_head_gear.free()
		_head_gear = null
	_jet_flames = null
	_gear = Node3D.new()
	torso.add_child(_gear)
	var model: String = GEAR_MODELS.get(id, "")
	if model != "":
		_fit_gear(model)
	if model == "Gear_leader" or model == "Gear_marshal":
		_head_gear = Node3D.new()
		head.add_child(_head_gear)
		_fit_gear(model + "_head", _head_gear)
	if cd.has("tie"):
		# Korpo's rank and trade: one tie per class, the only colour on a black suit.
		var tie := Node3D.new()
		_gear.add_child(tie)
		_fit_gear("Tie_Big" if cd.get("frame", "") == "Big" else "Tie", tie)
		var silk: Material = Mats.flat(C.TIE_COLORS[cd["tie"]], 0.38, 0.05)
		for mi: MeshInstance3D in tie.find_children("*", "MeshInstance3D", true, false):
			var current := mi.material_override as StandardMaterial3D
			# Everything but the chrome clip takes the class colour.
			if current and current.metallic < 0.5:
				mi.material_override = silk
	var glow: Material = Mats.glow(C.TEAM_COLORS[team], 1.8)
	match id:
		"medic", "servicer":
			var green: Material = Mats.glow(Color(0.3, 1.0, 0.5), 2.0)
			P.box(_gear, Vector3(0.16, 0.042, 0.006), Vector3(0, 0.3, 0.348), green)
			P.box(_gear, Vector3(0.042, 0.16, 0.006), Vector3(0, 0.3, 0.348), green)
		"maccabee":
			P.box(_gear, Vector3(0.06, 0.2, 0.01), Vector3(0, 0.32, 0.332), glow)
			_jet_flames = Node3D.new()
			_gear.add_child(_jet_flames)
			for side: float in [-1.0, 1.0]:
				P.cyl(_jet_flames, 0.07, 0.0, 0.6, Vector3(0.155 * side, -0.36, 0.3), Mats.glow(Color(0.5, 0.8, 1.0), 3.0))
			_jet_flames.visible = false
	P.merge(_gear)


## Only tanks have a hull that turns separately.
## Machines show their damage on the armour. People do not.
func set_health(_fraction: float) -> void:
	pass


func set_hull(_yaw: float) -> void:
	pass


func set_jet(on: bool) -> void:
	if _jet_flames:
		_jet_flames.visible = on


## Fades the whole body. `level` 0 is solid. Moving fast makes the camouflage shimmer.
func set_cloak(level: float, speed: float) -> void:
	var value := 0.0
	if level > 0.0:
		value = 0.965 if speed < 3.0 else 0.9
	if is_equal_approx(value, _cloak_shown):
		return
	_cloak_shown = value
	_apply_transparency(self, value)


func _apply_transparency(node: Node, value: float) -> void:
	for child in node.get_children():
		_apply_transparency(child, value)
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).transparency = value


func set_weapon(id: int, parts: Array = []) -> void:
	if id == weapon_id and parts == weapon_parts:
		return
	var was_shield := weapon_id == C.W.ENERGY_SHIELD
	weapon_id = id
	weapon_parts = parts
	if weapon_node and was_shield and weapon_node.get_node_or_null("Plate"):
		var old_plate := weapon_node.get_node("Plate") as Node3D
		old_plate.reparent(self)
		WeaponFactory.collapse_shield(self, old_plate, shield_broken_next)
		if is_visible_in_tree() and not shield_broken_next:
			Sfx.play_at("shield_off", old_plate.global_position, -4.0)
	shield_broken_next = false
	if weapon_node:
		weapon_node.queue_free()
	if C.WEAPONS[id].get("arm", false):
		# The weapon is the forearm itself: only the point the shots leave from is added.
		weapon_node = Node3D.new()
		weapon_node.name = "Weapon"
		var muzzle := Marker3D.new()
		muzzle.name = "Muzzle"
		muzzle.position = ARM_MUZZLE[id]
		weapon_node.add_child(muzzle)
		(elbow_l if id == C.W.ARM_ROCKETS else elbow_r).add_child(weapon_node)
	elif id == C.W.ENERGY_SHIELD:
		# Built whole rather than folded, so the plate can be animated on its own.
		weapon_node = WeaponFactory.build(id, team, parts)
		holder.add_child(weapon_node)
		WeaponFactory.deploy_shield(self, weapon_node.get_node("Plate"))
		if is_visible_in_tree():
			Sfx.play_at("shield_on", global_position + Vector3.UP * 1.2, -2.0)
	else:
		weapon_node = WeaponFactory.third_person(id, team, parts)
		holder.add_child(weapon_node)
	_pose_for_weapon()


func _pose_for_weapon() -> void:
	_swing = -1.0
	match weapon_id:
		C.W.PISTOL, C.W.REVOLVER, C.W.MPISTOL:
			_aim_pos = Vector3(0.05, 0.42, -0.4)
			_low_pos = Vector3(0.12, 0.2, -0.3)
			_grip_r = Vector3(0, -0.01, 0.02)
			_grip_l = Vector3(-0.02, -0.05, 0.05)
		C.W.ENERGY_SHIELD:
			# Held out in front at chest height, the plate covering the body.
			_aim_pos = Vector3(0.0, 0.3, -0.38)
			_low_pos = Vector3(0.0, 0.3, -0.36)
			_grip_r = Vector3(0, -0.02, 0.03)
			_grip_l = Vector3(-0.1, -0.06, 0.06)
		C.W.ARM_CANNON, C.W.ARM_ROCKETS:
			# Both weapon arms come up and point at the target, the way a war machine aims.
			_aim_pos = Vector3(0.0, 0.42, -0.26)
			_low_pos = Vector3(0.0, 0.3, -0.24)
			_grip_r = Vector3(0.24, 0.0, -0.16)
			_grip_l = Vector3(-0.24, 0.0, -0.16)
		C.W.HEAVY, C.W.MINIGUN:
			_aim_pos = Vector3(0.1, 0.27, -0.2)
			_low_pos = Vector3(0.1, 0.2, -0.18)
			_grip_r = Vector3(0, -0.07, 0.05)
			_grip_l = Vector3(0, -0.06, -0.376) if weapon_id == C.W.MINIGUN else Vector3(0, -0.04, -0.22)
		_:
			_aim_pos = Vector3(0.06, 0.35, -0.17)
			_low_pos = Vector3(0.05, 0.21, -0.18)
			_grip_r = Vector3(0, -0.06, 0.04)
			_grip_l = Vector3(0, -0.02, -0.22)
	if C.is_blade(weapon_id):
		_place_blade(SWINGS[0][0][1], SWINGS[0][0][2])
		_solve_arm(shoulder_l, elbow_l, Vector3(-0.38, 0.05, -0.1), Vector3(-0.6, -1.0, 0.2))
	elif weapon_node:
		holder.transform = Transform3D(Basis.IDENTITY, _aim_pos)
		_pose_arms(holder.transform * _grip_l)


## Two-bone IK in torso space. `pole` is the direction the elbow bends toward.
func _solve_arm(shoulder: Node3D, elbow: Node3D, target: Vector3, pole: Vector3) -> void:
	var s := shoulder.position
	var to := target - s
	var d := clampf(to.length(), 0.05, UPPER_ARM + FOREARM - 0.002)
	var dir := to.normalized()
	var cos_a := clampf((UPPER_ARM * UPPER_ARM + d * d - FOREARM * FOREARM) / (2.0 * UPPER_ARM * d), -1.0, 1.0)
	var axis := dir.cross(pole.normalized())
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	var upper_dir := dir.rotated(axis.normalized(), acos(cos_a))
	var elbow_pos := s + upper_dir * UPPER_ARM
	var fore_dir := (s + dir * d - elbow_pos).normalized()
	var upper_basis := Basis(Quaternion(Vector3.DOWN, upper_dir))
	shoulder.basis = upper_basis
	elbow.basis = upper_basis.inverse() * Basis(Quaternion(Vector3.DOWN, fore_dir))


func _pose_arms(hand_l: Vector3) -> void:
	_solve_arm(shoulder_r, elbow_r, holder.transform * _grip_r, Vector3(0.5, -1.0, 0.4))
	_solve_arm(shoulder_l, elbow_l, hand_l, Vector3(-0.6, -1.0, 0.2))


func reset_pose() -> void:
	_death = -1.0
	_swing = -1.0
	_throw = -1.0
	_reload = 0.0
	_flinch = Vector2.ZERO
	rotation = Vector3.ZERO
	pelvis.rotation = Vector3.ZERO
	torso.rotation = Vector3.ZERO
	if _nade:
		_nade.visible = false
	_pose_for_weapon()


func play_swing() -> void:
	_swing = 0.0
	_combo = (_combo + 1) % SWINGS.size()


func play_fire() -> void:
	_kick = 1.0
	_ready_gun = 1.0


func play_throw(kind := C.NADE_FRAG) -> void:
	_throw = 0.0
	for i in _nade_items.size():
		_nade_items[i].visible = i == kind


## `dir` is where the hit came from, in world space.
func play_hit(dir: Vector3) -> void:
	var local := Basis(Vector3.UP, -rotation.y) * dir
	_flinch = Vector2(clampf(local.x, -1.0, 1.0), clampf(local.z, -1.0, 1.0)) * 0.3


func play_death() -> void:
	_death = 0.0
	_corpse_t = 9.0


## The body falls away from whatever killed it.
func set_death_from(pos: Vector3) -> void:
	var to := pos - global_position
	var forward := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	_fall_back = 1.0 if to.dot(forward) >= 0.0 else -1.0


func muzzle_position() -> Vector3:
	if weapon_node:
		var m := weapon_node.get_node_or_null("Muzzle") as Node3D
		if m:
			return m.global_position
	return global_position + Vector3.UP * 1.4


## Fed each frame by Soldier. `velocity` is sideways and forward speed, relative to the body.
func set_motion(velocity: Vector2, grounded: bool, reloading: bool, sprinting: bool) -> void:
	_local_vel = velocity
	_grounded = grounded
	_reloading = reloading
	_sprinting = sprinting


func update_pose(delta: float, pos: Vector3, yaw: float, pitch: float, speed: float, crouching: bool, aiming: bool, blocking: bool, alive: bool) -> void:
	global_position = pos
	if _trail:
		_trail.tick(delta)
	if _death >= 0.0:
		_update_death(delta)
		return
	rotation = Vector3(0, yaw, 0)
	if not alive:
		return
	# The body keeps gliding every frame. Only its limbs catch up in larger steps.
	_pose_wait += delta
	if _pose_wait < pose_interval:
		return
	delta = _pose_wait
	_pose_wait = 0.0
	_crouch = move_toward(_crouch, 1.0 if crouching else 0.0, delta * 6.0)
	_prone = move_toward(_prone, 1.0 if prone else 0.0, delta * 3.5)
	_block = move_toward(_block, 1.0 if blocking else 0.0, delta * 8.0)
	_kick = move_toward(_kick, 0.0, delta * 9.0)
	_sprint = move_toward(_sprint, 1.0 if _sprinting else 0.0, delta * 6.0)
	_air = move_toward(_air, 0.0 if _grounded else 1.0, delta * 7.0)
	_ready_gun = move_toward(_ready_gun, 1.0 if aiming or prone else 0.0, delta * (7.0 if aiming or prone else 0.9))
	_reload = move_toward(_reload, 1.0 if _reloading else 0.0, delta * 5.0)
	_breath += delta
	_flinch = _flinch.lerp(Vector2.ZERO, minf(delta * 9.0, 1.0))
	if _throw >= 0.0:
		_throw += delta / THROW_TIME
		if _throw >= 1.0:
			_throw = -1.0

	_animate_legs(delta, speed)
	var sway := sin(phase)
	var moving := clampf(speed / 5.0, 0.0, 1.0)
	var twist := 0.0
	if C.is_blade(weapon_id):
		twist = _animate_blade(delta, pitch)
	else:
		_animate_gun(pitch, sway, moving)
	if _throw >= 0.0:
		# The whole body turns into a throw: back on the wind-up, through on the release.
		twist += sin(_throw * TAU) * -0.42
	var lean := clampf(speed / C.SPRINT_SPEED, 0.0, 1.0) * clampf(_local_vel.y / 4.0, -0.4, 1.0)
	var breathe := sin(_breath * 1.7) * 0.012
	torso.rotation = Vector3(
		pitch * 0.55 - lean * 0.26 - _sprint * 0.1 - _crouch * 0.22 + _prone * PRONE_CHEST + breathe + _flinch.y * 0.8,
		-pelvis.rotation.y - sway * 0.1 * moving + twist,
		-clampf(_local_vel.x / 8.0, -1.0, 1.0) * 0.1 + sway * 0.03 * moving - _flinch.x * 0.7 - lean * 0.42)
	head.rotation = Vector3(pitch * 0.45 + _prone * PRONE_LEVEL, -torso.rotation.y * 0.5, -torso.rotation.z * 0.6)
	# The hips shift a little the same way, so the head ends up near where the camera and hitbox put it.
	pelvis.position.x += lean * 0.06
	_animate_flaps(speed)


func _animate_legs(delta: float, speed: float) -> void:
	var moving := clampf(speed / 3.5, 0.0, 1.0)
	var forward := 1.0
	var side := 0.0
	if speed > 0.2:
		forward = _local_vel.y / speed
		side = _local_vel.x / speed
	# Stride length grows with speed, so feet do not slide over the ground.
	var stride := lerpf(1.5, 2.6, clampf(speed / C.SPRINT_SPEED, 0.0, 1.0))
	var direction := -1.0 if forward < -0.3 else 1.0
	phase = fmod(phase + direction * delta * TAU * speed / stride, TAU)
	var amp := lerpf(0.5, 0.7, _sprint) * moving
	var crouch_hip := _crouch * 1.25
	var crouch_knee := _crouch * 2.0

	var legs := [[hip_r, knee_r, ankle_r, phase, 1.0], [hip_l, knee_l, ankle_l, phase + PI, -1.0]]
	for l: Array in legs:
		var hip: Node3D = l[0]
		var knee: Node3D = l[1]
		var ankle: Node3D = l[2]
		var p: float = l[3]
		var s: float = l[4]
		var swing_leg := sin(p) * amp
		var bend := pow(maxf(0.0, cos(p + 0.45)), 1.3) * lerpf(0.9, 1.5, _sprint) * moving
		var air_hip := (0.95 if s > 0.0 else 0.25) * _air
		var air_knee := (1.3 if s > 0.0 else 0.75) * _air
		hip.rotation.x = swing_leg * absf(forward) * (1.0 - _air) + crouch_hip * (1.0 if s > 0.0 else 0.8) + air_hip + 0.03
		hip.rotation.z = -sin(p) * amp * side * 0.5 + _crouch * 0.08 * s
		knee.rotation.x = -(bend + crouch_knee * (1.0 if s > 0.0 else 0.85) + air_knee + 0.06)
		ankle.rotation.x = clampf(-(hip.rotation.x + knee.rotation.x), -0.9, 0.9)
		if _prone > 0.0:
			# Crawling: legs out behind, one knee drawn up at a time.
			var draw := maxf(sin(p), 0.0) * moving
			hip.rotation.x = lerpf(hip.rotation.x, draw * 0.6 - 0.03, _prone)
			hip.rotation.z = lerpf(hip.rotation.z, 0.12 * s + draw * 0.3 * s, _prone)
			knee.rotation.x = lerpf(knee.rotation.x, -(0.1 + draw * 0.9), _prone)
			ankle.rotation.x = lerpf(ankle.rotation.x, 0.75, _prone)

	var sway := sin(phase)
	var drop := absf(cos(phase)) * 0.05 * moving
	pelvis.position.y = STAND_HIP - _crouch * 0.38 - drop - _air * 0.12 + sin(_breath * 1.7) * 0.003
	pelvis.position.x = sway * 0.02 * moving
	# Legs turn toward where the body is really going while the shoulders stay on the aim.
	var turn := clampf(side * forward * 1.1, -0.55, 0.55) * moving
	pelvis.rotation = Vector3(0.0, -turn + sway * 0.1 * moving, cos(phase) * 0.03 * moving)
	if _prone > 0.0:
		pelvis.rotation = pelvis.rotation.lerp(Vector3(-PI * 0.5, 0.0, sway * 0.06 * moving), _prone)
		pelvis.position.y = lerpf(pelvis.position.y, PRONE_HIP, _prone)
	# Lying flat the body stretches out behind the head, which stays where the soldier's eyes are.
	pelvis.position.z = _prone * PRONE_REACH


func _animate_gun(pitch: float, sway: float, moving: float) -> void:
	var pos := _low_pos.lerp(_aim_pos, _ready_gun)
	var rot := Vector3(-0.36, 0.34, 0.0).lerp(Vector3.ZERO, _ready_gun)
	# Sprinting: the gun rides across the chest and pumps with the stride.
	pos = pos.lerp(Vector3(0.05, 0.28 + absf(sway) * 0.03, -0.17), _sprint)
	rot = rot.lerp(Vector3(-0.15 + sway * 0.1, 1.0, 0.38), _sprint)
	if _reload > 0.0:
		pos = pos.lerp(Vector3(0.09, 0.32, -0.22), _reload)
		rot = rot.lerp(Vector3(0.55, 0.3, 0.4), _reload)
	pos.y += sin(_breath * 1.7) * 0.004 + sway * 0.006 * moving
	pos.z += _kick * 0.035
	rot.x += _kick * 0.09 + pitch * 0.45
	if _prone > 0.0:
		pos += Vector3(0.0, 0.2, 0.05) * _prone
		rot.x += PRONE_LEVEL * _prone
	holder.transform = Transform3D(Basis.from_euler(rot), pos)
	if weapon_node == null:
		return

	var hand_l := holder.transform * _grip_l
	if _reload > 0.0:
		# The left hand drops to the belt and back, as if swapping the energy cell.
		var t := fmod(_breath * 1.1, 1.0)
		var belt := Vector3(-0.14, 0.08, -0.2)
		var cell := holder.transform * Vector3(0.0, -0.13, -0.14)
		hand_l = hand_l.lerp(cell.lerp(belt, sin(t * PI)), _reload)
	_pose_arms(hand_l)
	if _throw >= 0.0:
		_pose_throw()


## Overarm throw with the right arm while the left keeps hold of the gun.
func _pose_throw() -> void:
	var t := _throw
	var hand := Vector3.ZERO
	if t < 0.38:
		hand = Vector3(0.3, 0.3, -0.1).lerp(Vector3(0.36, 0.74, 0.22), smoothstep(0.0, 0.38, t))
	elif t < 0.6:
		hand = Vector3(0.36, 0.74, 0.22).lerp(Vector3(0.18, 0.62, -0.48), smoothstep(0.38, 0.6, t))
	else:
		hand = Vector3(0.18, 0.62, -0.48).lerp(Vector3(0.1, 0.1, -0.34), smoothstep(0.6, 1.0, t))
	_nade.visible = t < 0.52
	_solve_arm(shoulder_r, elbow_r, hand, Vector3(0.8, -0.4, 0.3))


## Places the hilt at `hand`, kept within reach of the shoulder.
func _place_blade(hand: Vector3, rot: Vector3) -> void:
	var s := shoulder_r.position
	var to := hand - s
	var reach := UPPER_ARM + FOREARM + 0.04
	if to.length() > reach:
		hand = s + to.normalized() * reach
	holder.transform = Transform3D(Basis.from_euler(rot), hand)
	_solve_arm(shoulder_r, elbow_r, hand, Vector3(0.6, -1.0, 0.4))


## Returns how far the swing twists the shoulders.
func _animate_blade(delta: float, pitch: float) -> float:
	var hand: Vector3 = SWINGS[0][0][1]
	var rot: Vector3 = SWINGS[0][0][2]
	var twist := 0.0
	# Sprinting with a blade: it trails low and behind.
	hand = hand.lerp(Vector3(0.34, 0.04, -0.02), _sprint)
	rot = rot.lerp(Vector3(1.1, 0.0, -0.3), _sprint)
	if _block > 0.01:
		hand = hand.lerp(Vector3(0.06, 0.46, -0.42), _block)
		rot = rot.lerp(Vector3(-0.25, 0.0, -1.3), _block)
	if _swing >= 0.0:
		_swing += delta / SWING_TIME
		if _swing >= 1.0:
			_swing = -1.0
		else:
			var keys: Array = SWINGS[_combo]
			for i in keys.size() - 1:
				var a: Array = keys[i]
				var b: Array = keys[i + 1]
				if _swing <= b[0]:
					var k := smoothstep(0.0, 1.0, (_swing - float(a[0])) / (float(b[0]) - float(a[0])))
					var from_hand: Vector3 = a[1]
					var from_rot: Vector3 = a[2]
					hand = from_hand.lerp(b[1], k)
					rot = from_rot.lerp(b[2], k)
					twist = lerpf(a[3], b[3], k)
					break
	rot.x += pitch * 0.3
	_place_blade(hand, rot)
	_solve_arm(shoulder_l, elbow_l, Vector3(-0.4 + twist * 0.2, 0.06 + _sprint * 0.1, -0.1 + twist * 0.3), Vector3(-0.6, -1.0, 0.2))
	_update_trail()
	return twist


func _update_trail() -> void:
	if _trail == null:
		_trail = BladeTrail.new()
		_trail.setup(C.TEAM_COLORS[team], false)
		add_child(_trail)
		_trail.top_level = true
		_trail.global_transform = Transform3D.IDENTITY
	if _swing >= 0.1 and _swing <= 0.8 and weapon_node:
		var tip := weapon_node.get_node_or_null("Muzzle") as Node3D
		if tip:
			var base := holder.global_transform.origin
			_trail.push(base.lerp(tip.global_position, 0.55), tip.global_position)


func _animate_flaps(speed: float) -> void:
	var kick := clampf(speed / C.SPRINT_SPEED, 0.0, 1.0)
	for i in _flaps.size():
		var flap := _flaps[i]
		var leg_swing := hip_r.rotation.x if i == 0 else hip_l.rotation.x
		flap.rotation.x = kick * 0.4 + sin(_breath * 6.0 + i) * 0.05 * kick + leg_swing * 0.35 * (1.0 if i < 2 else 0.0)


func _update_death(delta: float) -> void:
	_corpse_t -= delta
	if _corpse_t <= 0.0:
		visible = false
		return
	_death = minf(_death + delta * 1.5, 1.0)
	var buckle := smoothstep(0.0, 0.4, _death)
	var fall := smoothstep(0.2, 1.0, _death)
	fall = fall * fall
	# Knees give way first, then the whole body topples.
	hip_r.rotation = Vector3(lerpf(0.1, 0.5 if _fall_back > 0.0 else -0.1, buckle), 0.0, 0.1)
	hip_l.rotation = Vector3(lerpf(0.1, 0.9 if _fall_back > 0.0 else 0.15, buckle), 0.0, -0.14)
	knee_r.rotation.x = -buckle * 0.9
	knee_l.rotation.x = -buckle * 1.5
	ankle_r.rotation.x = buckle * 0.4
	ankle_l.rotation.x = buckle * 0.4
	pelvis.position.y = lerpf(STAND_HIP, 0.62, buckle)
	torso.rotation = Vector3(_fall_back * 0.3 * fall - 0.3 * buckle * (1.0 - fall), 0.2 * fall, 0.25 * fall)
	head.rotation = Vector3(_fall_back * 0.4 * fall, 0.5 * fall, 0.0)
	shoulder_r.rotation = shoulder_r.rotation.lerp(Vector3(-0.3, 0.0, 1.0), minf(delta * 6.0, 1.0))
	shoulder_l.rotation = shoulder_l.rotation.lerp(Vector3(0.5, 0.0, -1.2), minf(delta * 6.0, 1.0))
	elbow_r.rotation = elbow_r.rotation.lerp(Vector3(0.5, 0.0, 0.0), minf(delta * 6.0, 1.0))
	elbow_l.rotation = elbow_l.rotation.lerp(Vector3(0.9, 0.0, 0.0), minf(delta * 6.0, 1.0))
	rotation.x = _fall_back * fall * (PI * 0.49)
	position.y += fall * 0.16
