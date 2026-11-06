class_name MechModel
extends MachineModel
## Third-person walker for the Golem and the Goliat. It shares the SoldierModel interface,
## so Soldier can swap one for the other without knowing which it holds.
##
## The Golem is fired clay and brass, round and top-heavy, with a kiln glowing in its chest
## plate, a narrow slit, skirts and twin guns.
##
## Feet are placed by inverse kinematics, so they stay planted through the stance instead of
## swinging like pendulums. One arm is the gun, the other the fist.

const THIGH_LEN := 0.78
const SHIN_LEN := 0.78
const HIP_Y := 1.8
const HIP_DROP := 0.14
const HIP_X := 0.4
const FOOT_X := 0.47
const ANKLE_H := 0.25
const UPPER_ARM_LEN := 0.74
## Half a stride, and the share of a cycle a foot spends on the ground.
const STRIDE := 0.62
const STANCE := 0.56
const STEP_LIFT := 0.36
const GUN_SHOULDER := 0.5
const GUN_ELBOW := 1.0

var cannon_arm: Node3D
var cannon_elbow: Node3D
var fist_arm: Node3D
var fist_elbow: Node3D
var muzzle: Marker3D
var _recoil := 0.0
var _punch := 0.0
var _fall := -1.0
var _cycle := 0.0
var _amp := 0.0
var _dir := Vector2.UP
var _idle := 0.0

var plate: Forge.Tone
var plate2: Forge.Tone
var dark: Forge.Tone
var steel: Forge.Tone
var trim: Forge.Tone
var glass: Forge.Tone
var light: Forge.Tone
var light_soft: Forge.Tone
var _launcher_muzzle: Marker3D
var _launcher_up := false
var _raise := 0.0


func setup(new_team: int) -> void:
	team = new_team
	var golem := team == C.Team.RESISTANCE
	var glow_color: Color = C.TEAM_COLORS[team]
	plate = Forge.tone(Color(0.38, 0.41, 0.27) if golem else Color(0.35, 0.37, 0.38))
	plate2 = Forge.tone(Color(0.28, 0.31, 0.21) if golem else Color(0.25, 0.27, 0.28))
	dark = Forge.tone(Color(0.13, 0.11, 0.1) if golem else Color(0.06, 0.06, 0.07), Forge.RUBBER)
	steel = Forge.tone(Color(0.42, 0.41, 0.4), Forge.METAL)
	trim = Forge.tone(Color(0.66, 0.66, 0.6), Forge.METAL) if golem else Forge.tone(Color(0.48, 0.07, 0.05))
	glass = Forge.tone(Color(0.05, 0.1, 0.15) if golem else Color(0.14, 0.03, 0.02), Forge.GLASS)
	light = Forge.lamp(glow_color, 6.0)
	light_soft = Forge.lamp(glow_color, 2.4)

	pelvis = Node3D.new()
	pelvis.position.y = HIP_Y
	add_child(pelvis)
	part(pelvis, "pelvis", _golem_pelvis if golem else _goliat_pelvis)

	torso = Node3D.new()
	torso.position.y = 0.26
	pelvis.add_child(torso)
	part(torso, "torso", _golem_torso if golem else _goliat_torso)

	head = Node3D.new()
	head.position = Vector3(0, 1.2, -0.12) if golem else Vector3(0, 1.26, -0.16)
	torso.add_child(head)
	part(head, "head", _golem_head if golem else _goliat_head)
	if golem:
		Forge.decal(torso, "icon_usa", Vector2(0.42, 0.42), Vector3(0, 1.04, -0.625), Vector3(-0.42, PI, 0))
	else:
		Forge.decal(torso, "icon_empire", Vector2(0.56, 0.56), Vector3(0, 0.62, -0.665), Vector3(0.15, PI, 0))

	cannon_arm = _shoulder(-1.0, "arm_gun", golem)
	cannon_elbow = _elbow(cannon_arm, "gun", _golem_cannon if golem else _goliat_cannon)
	fist_arm = _shoulder(1.0, "arm_fist", golem)
	fist_elbow = _elbow(fist_arm, "fist", _golem_fist if golem else _goliat_fist)
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0, -1.62, 0)
	cannon_elbow.add_child(muzzle)
	_launcher_muzzle = Marker3D.new()
	_launcher_muzzle.position = Vector3(0, -1.88, 0)
	fist_elbow.add_child(_launcher_muzzle)

	var lr: Array = _leg(1.0, golem)
	hip_r = lr[0]
	knee_r = lr[1]
	ankle_r = lr[2]
	var ll: Array = _leg(-1.0, golem)
	hip_l = ll[0]
	knee_l = ll[1]
	ankle_l = ll[2]
	_refresh_paint()


func _shoulder(side: float, key: String, golem: bool) -> Node3D:
	var sh := Node3D.new()
	sh.position = Vector3(1.1 * side, 0.98, 0)
	torso.add_child(sh)
	part(sh, key, (_golem_upper if golem else _goliat_upper).bind(side))
	if side > 0.0:
		var icon := "icon_usa" if golem else "icon_empire"
		Forge.decal(sh, icon, Vector2(0.44, 0.44), Vector3(0.53, 0.0, 0.0) if golem else Vector3(0.545, 0.05, 0), Vector3(0, PI * 0.5, 0))
	return sh


func _elbow(shoulder: Node3D, key: String, build: Callable) -> Node3D:
	var el := Node3D.new()
	el.position.y = -UPPER_ARM_LEN
	shoulder.add_child(el)
	part(el, key, build)
	return el


func _leg(side: float, golem: bool) -> Array:
	var tag := "r" if side > 0.0 else "l"
	var hip := Node3D.new()
	hip.position = Vector3(HIP_X * side, -HIP_DROP, 0)
	pelvis.add_child(hip)
	part(hip, "thigh_" + tag, (_golem_thigh if golem else _goliat_thigh).bind(side))
	var kn := Node3D.new()
	kn.position.y = -THIGH_LEN
	hip.add_child(kn)
	part(kn, "shin_" + tag, (_golem_shin if golem else _goliat_shin).bind(side))
	var an := Node3D.new()
	an.position.y = -SHIN_LEN
	kn.add_child(an)
	part(an, "foot_" + tag, (_golem_foot if golem else _goliat_foot).bind(side))
	return [hip, kn, an]


# ---------------------------------------------------------------- Golem

func _golem_pelvis(k: Forge) -> void:
	k.pod([[-0.36, 0.34, 0.26], [-0.22, 0.6, 0.38], [0.08, 0.7, 0.44], [0.28, 0.56, 0.36]], plate2, 16)
	k.pod([[0.1, 0.72, 0.46], [0.2, 0.72, 0.46], [0.24, 0.68, 0.43]], trim, 16)
	k.slab(Vector3(0.5, 0.5, 0.09), Vector3(0, -0.14, -0.45), plate, Vector3(0.14, 0, 0), 0.03, Vector2(1.2, 1))
	k.slab(Vector3(0.1, 0.42, 0.03), Vector3(0, -0.14, -0.51), trim, Vector3(0.14, 0, 0), 0.01)
	k.slab(Vector3(0.6, 0.42, 0.1), Vector3(0, -0.1, 0.44), plate, Vector3(-0.16, 0, 0), 0.03, Vector2(1.16, 1))
	for s: float in [-1.0, 1.0]:
		k.ball(0.24, Vector3(HIP_X * s, -HIP_DROP, 0), dark)
		k.slab(Vector3(0.1, 0.46, 0.5), Vector3(0.7 * s, -0.12, 0), plate, Vector3(0, 0, -0.2 * s), 0.03, Vector2(1, 1.1))


func _golem_torso(k: Forge) -> void:
	# Barrel chest, swollen high up so the whole figure leans over its feet.
	k.pod([
		[-0.04, 0.58, 0.4], [0.2, 0.68, 0.48, -0.02], [0.5, 0.86, 0.6, -0.04], [0.78, 1.0, 0.68, -0.05],
		[1.02, 1.02, 0.68, -0.03], [1.2, 0.86, 0.58, 0.0], [1.34, 0.56, 0.42, 0.02],
	], plate, 20)
	for y: float in [0.28, 0.56]:
		var rx := lerpf(0.72, 0.92, (y - 0.28) / 0.28)
		var rz := rx * 0.7
		k.pod([[y, rx - 0.02, rz - 0.02, -0.03], [y + 0.03, rx + 0.025, rz + 0.025, -0.03], [y + 0.09, rx + 0.03, rz + 0.03, -0.03], [y + 0.12, rx, rz, -0.03]], trim, 20)
	# The kiln: a brass ring around a bright core, with radiating grille bars.
	k.lathe([Vector2(0.3, -0.08), Vector2(0.34, -0.04), Vector2(0.34, 0.08), Vector2(0.27, 0.11), Vector2(0.22, 0.04)], Vector3(0, 0.74, -0.72), trim, Vector3(-PI * 0.5 - 0.1, 0, 0), 20)
	k.lathe([Vector2(0.24, 0.0), Vector2(0.0, 0.0)], Vector3(0, 0.74, -0.74), light, Vector3(-PI * 0.5 - 0.1, 0, 0), 18)
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		k.slab(Vector3(0.035, 0.24, 0.035), Vector3(cos(a) * 0.12, 0.74 + sin(a) * 0.12, -0.78), trim, Vector3(0, 0, a - PI * 0.5), 0.008)
	k.ball(0.06, Vector3(0, 0.74, -0.8), trim)
	# Breast plates over the kiln, and the slab that carries the star.
	k.slab(Vector3(0.74, 0.34, 0.08), Vector3(0, 1.06, -0.54), plate2, Vector3(0.42, 0, 0), 0.03, Vector2(0.8, 1))
	for s: float in [-1.0, 1.0]:
		k.slab(Vector3(0.6, 0.5, 0.1), Vector3(0.62 * s, 1.0, -0.42), plate2, Vector3(0.38, 0.5 * s, 0), 0.035, Vector2(0.8, 1))
		k.slab(Vector3(0.36, 0.12, 0.3), Vector3(0.52 * s, 1.27, 0.12), plate2, Vector3(0, 0, -0.24 * s), 0.03)
		k.ball(0.3, Vector3(1.04 * s, 0.98, 0), dark)
	# Neck ring.
	k.lathe([Vector2(0.4, 0), Vector2(0.44, 0.06), Vector2(0.42, 0.12), Vector2(0.34, 0.14)], Vector3(0, 1.12, -0.1), trim, Vector3.ZERO, 16)
	# Back: boiler, flues and vents.
	k.pod([[0.3, 0.46, 0.2, 0.68], [0.5, 0.56, 0.28, 0.7], [1.0, 0.56, 0.28, 0.7], [1.2, 0.42, 0.2, 0.64]], plate2, 14)
	k.vent(Vector2(0.62, 0.44), Vector3(0, 0.74, 0.97), dark, steel, Vector3(PI * 0.5, 0, 0), 5)
	for s: float in [-1.0, 1.0]:
		k.lathe([
			Vector2(0.15, 0), Vector2(0.15, 0.52), Vector2(0.2, 0.56), Vector2(0.2, 0.7), Vector2(0.14, 0.72), Vector2(0.1, 0.6),
		], Vector3(0.3 * s, 1.08, 0.74), plate, Vector3(-0.16, 0, 0.1 * s), 12)
		k.lathe([Vector2(0.135, 0.0), Vector2(0.0, 0.0)], Vector3(0.3 * s + 0.06 * s, 1.72, 0.84), light_soft, Vector3(-0.16, 0, 0.1 * s), 10)
		k.lathe([Vector2(0.17, 0), Vector2(0.19, 0.03), Vector2(0.17, 0.05)], Vector3(0.325 * s, 1.34, 0.78), trim, Vector3(-0.16, 0, 0.1 * s), 12)


func _golem_head(k: Forge) -> void:
	# Sunk between the shoulders, heavy-browed and faceless.
	k.pod([[-0.1, 0.27, 0.27], [0.06, 0.34, 0.36], [0.24, 0.35, 0.37], [0.38, 0.27, 0.3], [0.45, 0.1, 0.12]], plate, 16)
	k.slab(Vector3(0.5, 0.15, 0.14), Vector3(0, 0.25, -0.32), plate2, Vector3(-0.26, 0, 0), 0.03, Vector2(0.86, 0.9))
	k.slab(Vector3(0.58, 0.075, 0.1), Vector3(0, 0.12, -0.33), glass, Vector3.ZERO, 0.012)
	k.slab(Vector3(0.48, 0.03, 0.04), Vector3(0, 0.12, -0.38), light, Vector3.ZERO, 0.008)
	k.slab(Vector3(0.44, 0.15, 0.2), Vector3(0, -0.03, -0.27), plate2, Vector3(-0.08, 0, 0), 0.03, Vector2(1.14, 1))
	k.slab(Vector3(0.09, 0.2, 0.5), Vector3(0, 0.41, 0.02), trim, Vector3(0.14, 0, 0), 0.02, Vector2(0.6, 1))
	for s: float in [-1.0, 1.0]:
		k.lathe([Vector2(0.13, 0), Vector2(0.13, 0.06), Vector2(0.09, 0.08), Vector2(0, 0.08)], Vector3(0.33 * s, 0.15, 0.02), trim, Vector3(0, 0, -PI * 0.5 * s), 10)


func _golem_upper(k: Forge, s: float) -> void:
	# Pauldron: a great clay dome with a brass rim.
	k.lathe([
		Vector2(0.0, -0.3), Vector2(0.38, -0.3), Vector2(0.54, -0.18), Vector2(0.56, 0.02), Vector2(0.48, 0.24), Vector2(0.28, 0.38), Vector2(0.0, 0.42),
	], Vector3.ZERO, plate, Vector3.ZERO, 18, Vector3(1, 1, 1.08), true)
	k.lathe([Vector2(0.53, -0.21), Vector2(0.58, -0.2), Vector2(0.59, -0.13), Vector2(0.55, -0.1)], Vector3.ZERO, trim, Vector3.ZERO, 18, Vector3(1, 1, 1.08))
	k.lathe([Vector2(0.4, 0.21), Vector2(0.45, 0.22), Vector2(0.43, 0.27), Vector2(0.36, 0.28)], Vector3.ZERO, trim, Vector3.ZERO, 18, Vector3(1, 1, 1.08))
	k.pod([[-0.72, 0.21, 0.23], [-0.45, 0.25, 0.27], [-0.2, 0.3, 0.32]], plate2, 12)
	k.pod([[-0.56, 0.255, 0.275], [-0.52, 0.275, 0.295], [-0.46, 0.275, 0.295], [-0.42, 0.26, 0.28]], trim, 12)
	k.ball(0.22, Vector3(0, -UPPER_ARM_LEN, 0), dark)
	k.ram(Vector3(-0.18 * s, -0.18, 0.28), Vector3(-0.14 * s, -0.7, 0.22), 0.05, dark, steel)


func _golem_cannon(k: Forge) -> void:
	k.pod([[-0.02, 0.26, 0.26], [-0.2, 0.33, 0.34], [-0.62, 0.37, 0.39], [-0.9, 0.32, 0.34], [-1.0, 0.24, 0.26]], plate, 14)
	for y: float in [-0.3, -0.56, -0.82]:
		k.pod([[y, 0.36, 0.38], [y - 0.03, 0.4, 0.42], [y - 0.08, 0.4, 0.42], [y - 0.11, 0.36, 0.38]], trim, 14)
	# Stepped bore, cooling sleeve, flared mouth.
	k.lathe([
		Vector2(0.2, 0.9), Vector2(0.2, 1.1), Vector2(0.16, 1.12), Vector2(0.16, 1.42), Vector2(0.23, 1.46), Vector2(0.27, 1.54),
		Vector2(0.27, 1.62), Vector2(0.18, 1.64), Vector2(0.12, 1.5),
	], Vector3.ZERO, dark, Vector3(PI, 0, 0), 14)
	k.lathe([Vector2(0.12, 1.5), Vector2(0.0, 1.5)], Vector3.ZERO, light, Vector3(PI, 0, 0), 12)
	k.lathe([Vector2(0.235, 0), Vector2(0.25, 0.02), Vector2(0.25, 0.07), Vector2(0.235, 0.09)], Vector3(0, -1.2, 0), trim, Vector3(PI, 0, 0), 14)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var off := Vector3(cos(a) * 0.3, 0, sin(a) * 0.32)
		k.slab(Vector3(0.05, 0.62, 0.05), off + Vector3(0, -0.62, 0), light_soft, Vector3(0, -a, 0), 0.012)
	k.slab(Vector3(0.2, 0.34, 0.14), Vector3(0, -0.6, 0.42), plate2, Vector3.ZERO, 0.03)


func _golem_fist(k: Forge) -> void:
	k.pod([[-0.02, 0.24, 0.24], [-0.24, 0.32, 0.33], [-0.6, 0.36, 0.38], [-0.82, 0.32, 0.34]], plate, 14)
	k.pod([[-0.72, 0.35, 0.37], [-0.75, 0.39, 0.41], [-0.8, 0.39, 0.41], [-0.84, 0.33, 0.35]], trim, 14)
	k.slab(Vector3(0.14, 0.46, 0.1), Vector3(0, -0.42, -0.38), plate2, Vector3(0.1, 0, 0), 0.03)
	_launcher(k)


func _golem_thigh(k: Forge, s: float) -> void:
	k.pod([[-0.02, 0.24, 0.26], [-0.2, 0.31, 0.35], [-0.52, 0.29, 0.33], [-0.74, 0.21, 0.24]], plate, 14)
	k.pod([[-0.3, 0.31, 0.35], [-0.33, 0.335, 0.375], [-0.38, 0.335, 0.375], [-0.41, 0.31, 0.35]], trim, 14)
	k.slab(Vector3(0.36, 0.44, 0.08), Vector3(0, -0.5, -0.31), plate2, Vector3(-0.12, 0, 0), 0.03, Vector2(1.18, 1))
	k.ram(Vector3(0.0, -0.1, 0.34), Vector3(0.0, -0.62, 0.3), 0.055, dark, steel)
	k.slab(Vector3(0.09, 0.5, 0.42), Vector3(0.33 * s, -0.2, 0), plate2, Vector3(0, 0, -0.06 * s), 0.025)


func _golem_shin(k: Forge, _s: float) -> void:
	k.ball(0.25, Vector3.ZERO, dark)
	k.lathe([Vector2(0, -0.2), Vector2(0.2, -0.17), Vector2(0.27, -0.02), Vector2(0.22, 0.12), Vector2(0, 0.17)], Vector3(0, 0.02, -0.14), trim, Vector3(-0.2, 0, 0), 14, Vector3(1.1, 1, 0.7), true)
	k.pod([[-0.08, 0.25, 0.28], [-0.3, 0.33, 0.37, 0.02], [-0.54, 0.31, 0.34, 0.02], [-0.76, 0.3, 0.32]], plate, 14)
	k.pod([[-0.58, 0.31, 0.34, 0.02], [-0.61, 0.345, 0.375, 0.02], [-0.66, 0.345, 0.375, 0.02], [-0.69, 0.31, 0.33, 0.02]], trim, 14)
	k.slab(Vector3(0.3, 0.46, 0.09), Vector3(0, -0.34, -0.36), plate2, Vector3(0.04, 0, 0), 0.03, Vector2(1.18, 1))
	k.ball(0.17, Vector3(0, -SHIN_LEN, 0), dark)


func _golem_foot(k: Forge, _s: float) -> void:
	var g := -ANKLE_H
	k.hull([
		[-0.34, g, g + 0.14, g + 0.3, 0.36, 0.34, 0.24],
		[0.22, g, g + 0.14, g + 0.3, 0.32, 0.3, 0.22],
		[0.46, g, g + 0.08, g + 0.17, 0.24, 0.22, 0.16],
	], plate2, 0.04)
	k.slab(Vector3(0.5, 0.04, 0.34), Vector3(0, g + 0.33, -0.12), trim, Vector3(0.12, 0, 0), 0.012, Vector2(0.86, 0.9))
	for x: float in [-0.26, 0.0, 0.26]:
		k.at(Vector3(x, 0, 0))
		k.hull([
			[-0.82, g, g + 0.05, g + 0.1, 0.04, 0.09, 0.06],
			[-0.52, g, g + 0.1, g + 0.2, 0.11, 0.13, 0.09],
			[-0.28, g, g + 0.12, g + 0.24, 0.11, 0.13, 0.09],
		], plate, 0.03)
		k.back()
		k.slab(Vector3(0.14, 0.05, 0.14), Vector3(x, g + 0.07, -0.78), trim, Vector3(0.3, 0, 0), 0.015, Vector2(0.7, 0.7))


# ---------------------------------------------------------------- Goliat

func _goliat_pelvis(k: Forge) -> void:
	k.hull([
		[-0.42, -0.3, -0.04, 0.3, 0.38, 0.6, 0.52],
		[0.42, -0.3, -0.04, 0.3, 0.38, 0.6, 0.52],
	], plate2, 0.035)
	k.slab(Vector3(1.28, 0.1, 0.92), Vector3(0, 0.26, 0), trim, Vector3.ZERO, 0.02)
	k.slab(Vector3(0.56, 0.54, 0.07), Vector3(0, -0.2, -0.46), plate, Vector3(0.1, 0, 0), 0.02, Vector2(1.3, 1))
	for s: float in [-1.0, 1.0]:
		k.ball(0.23, Vector3(HIP_X * s, -HIP_DROP, 0), dark)
		# Armoured skirts hung from the waist.
		k.slab(Vector3(0.07, 0.62, 0.72), Vector3(0.74 * s, -0.16, 0), plate, Vector3(0, 0, -0.12 * s), 0.02)
		k.bolts(Vector3(0.79 * s, 0.08, -0.26), Vector3(0.79 * s, 0.08, 0.26), 3, 0.026, steel, Vector3(0, 0, -PI * 0.5 * s))


func _goliat_torso(k: Forge) -> void:
	# An inverted wedge: narrow waist, broad flat shoulders.
	k.limb([
		[-0.05, 0.56, 0.42, 0.38],
		[0.34, 0.72, 0.52, 0.44],
		[0.86, 1.02, 0.68, 0.56],
		[1.12, 1.02, 0.6, 0.54],
		[1.24, 0.82, 0.44, 0.46],
	], plate, 0.04)
	# Glacis over the chest, with a riveted frame around the cross.
	k.slab(Vector3(1.3, 0.68, 0.08), Vector3(0, 0.62, -0.61), plate2, Vector3(-0.15, 0, 0), 0.025, Vector2(1.3, 1))
	k.bolts(Vector3(-0.48, 0.32, -0.57), Vector3(0.48, 0.32, -0.57), 6, 0.03, steel, Vector3(-PI * 0.5 - 0.14, 0, 0))
	k.bolts(Vector3(-0.68, 0.94, -0.665), Vector3(0.68, 0.94, -0.665), 8, 0.03, steel, Vector3(-PI * 0.5 - 0.14, 0, 0))
	k.slab(Vector3(1.8, 0.08, 0.1), Vector3(0, 1.06, -0.64), trim, Vector3(-0.2, 0, 0), 0.012)
	for s: float in [-1.0, 1.0]:
		k.slab(Vector3(0.1, 0.42, 0.72), Vector3(0.78 * s, 0.34, 0), plate2, Vector3(0, 0, 0.26 * s), 0.025)
		k.ball(0.28, Vector3(1.04 * s, 0.98, 0), dark)
		k.vent(Vector2(0.3, 0.34), Vector3(0.74 * s, 0.84, -0.66), dark, steel, Vector3(-PI * 0.5 - 0.1, 0, 0), 4)
	# Shoulder yoke and neck.
	k.slab(Vector3(1.54, 0.12, 0.92), Vector3(0, 1.24, 0), plate2, Vector3.ZERO, 0.03, Vector2(0.84, 0.9))
	k.lathe([Vector2(0.34, 0), Vector2(0.34, 0.1), Vector2(0.28, 0.12)], Vector3(0, 1.26, -0.14), dark, Vector3.ZERO, 12)
	# Back: engine block with twin exhausts and an ammunition drum.
	k.slab(Vector3(1.24, 0.82, 0.42), Vector3(0, 0.76, 0.72), plate2, Vector3.ZERO, 0.03, Vector2(0.9, 0.9))
	k.vent(Vector2(0.86, 0.5), Vector3(0, 0.78, 0.95), dark, steel, Vector3(PI * 0.5, 0, 0), 6)
	k.slab(Vector3(1.26, 0.06, 0.44), Vector3(0, 1.14, 0.72), trim, Vector3.ZERO, 0.012)
	for s: float in [-1.0, 1.0]:
		k.lathe([
			Vector2(0.11, 0), Vector2(0.11, 0.62), Vector2(0.15, 0.66), Vector2(0.15, 0.78), Vector2(0.1, 0.8), Vector2(0.07, 0.7),
		], Vector3(0.5 * s, 1.0, 0.82), steel, Vector3(-0.1, 0, 0), 10)
		k.lathe([Vector2(0.09, 0.0), Vector2(0.0, 0.0)], Vector3(0.5 * s, 1.7, 0.89), light_soft, Vector3(-0.1, 0, 0), 8)


func _goliat_head(k: Forge) -> void:
	# A low armoured cupola with one long slit, more gun turret than face.
	k.limb([
		[-0.1, 0.27, 0.3, 0.26],
		[0.1, 0.34, 0.4, 0.32],
		[0.26, 0.33, 0.38, 0.32],
		[0.36, 0.22, 0.24, 0.24],
	], plate, 0.03)
	k.slab(Vector3(0.6, 0.06, 0.08), Vector3(0, 0.15, -0.37), glass, Vector3.ZERO, 0.01)
	k.slab(Vector3(0.5, 0.024, 0.03), Vector3(0, 0.15, -0.41), light, Vector3.ZERO, 0.006)
	k.slab(Vector3(0.72, 0.05, 0.3), Vector3(0, 0.215, -0.32), plate2, Vector3(0.22, 0, 0), 0.015)
	k.slab(Vector3(0.1, 0.05, 0.6), Vector3(0, 0.38, 0), trim, Vector3.ZERO, 0.012)
	k.rod(Vector3(0.22, 0.3, 0.2), Vector3(0.28, 1.1, 0.34), 0.012, dark, 5)
	k.lathe([Vector2(0.08, 0), Vector2(0.08, 0.14), Vector2(0, 0.14)], Vector3(-0.28, 0.2, -0.12), steel, Vector3(0, 0, PI * 0.5), 8)


func _goliat_upper(k: Forge, s: float) -> void:
	# Stepped slabs of shoulder armour, raised above the yoke.
	k.limb([[-0.34, 0.48, 0.42, 0.4], [0.06, 0.54, 0.5, 0.48], [0.34, 0.46, 0.42, 0.42], [0.42, 0.32, 0.3, 0.3]], plate, 0.035)
	k.slab(Vector3(0.1, 0.16, 0.92), Vector3(0.53 * s, -0.22, 0), trim, Vector3.ZERO, 0.014)
	k.slab(Vector3(0.74, 0.07, 0.66), Vector3(0, 0.44, 0), plate2, Vector3.ZERO, 0.02, Vector2(0.84, 0.84))
	k.bolts(Vector3(-0.3, 0.47, -0.26), Vector3(0.3, 0.47, -0.26), 4, 0.026, steel)
	k.bolts(Vector3(-0.3, 0.47, 0.26), Vector3(0.3, 0.47, 0.26), 4, 0.026, steel)
	k.limb([[-0.72, 0.2, 0.2, 0.22], [-0.3, 0.26, 0.26, 0.28]], plate2, 0.03)
	k.ball(0.21, Vector3(0, -UPPER_ARM_LEN, 0), dark)
	k.ram(Vector3(-0.2 * s, -0.2, 0.28), Vector3(-0.16 * s, -0.7, 0.24), 0.05, dark, steel)


func _goliat_cannon(k: Forge) -> void:
	k.limb([[-0.02, 0.22, 0.24, 0.26], [-0.2, 0.34, 0.36, 0.34], [-0.86, 0.36, 0.38, 0.36], [-1.04, 0.28, 0.3, 0.28]], plate, 0.035)
	k.slab(Vector3(0.74, 0.1, 0.8), Vector3(0, -0.92, 0), trim, Vector3.ZERO, 0.014)
	# Belt drum on the outside of the forearm.
	k.lathe([Vector2(0, 0), Vector2(0.28, 0), Vector2(0.28, 0.2), Vector2(0.24, 0.24), Vector2(0, 0.24)], Vector3(-0.34, -0.52, 0), plate2, Vector3(0, 0, PI * 0.5), 14)
	k.bolts(Vector3(-0.585, -0.34, 0), Vector3(-0.585, -0.7, 0), 3, 0.03, steel, Vector3(0, 0, PI * 0.5))
	for x: float in [-0.14, 0.14]:
		k.lathe([
			Vector2(0.13, 0.96), Vector2(0.13, 1.1), Vector2(0.09, 1.14), Vector2(0.085, 1.46), Vector2(0.15, 1.48), Vector2(0.15, 1.56), Vector2(0.1, 1.58),
			Vector2(0.1, 1.6), Vector2(0.15, 1.62), Vector2(0.15, 1.7), Vector2(0.07, 1.71), Vector2(0.05, 1.6),
		], Vector3(x, 0, 0), steel, Vector3(PI, 0, 0), 10)
		k.lathe([Vector2(0.055, 1.6), Vector2(0.0, 1.6)], Vector3(x, 0, 0), light, Vector3(PI, 0, 0), 8)
		k.slab(Vector3(0.025, 0.5, 0.025), Vector3(x, -1.24, 0.12), light_soft, Vector3.ZERO, 0.006)
	k.slab(Vector3(0.5, 0.12, 0.22), Vector3(0, -1.22, 0), plate2, Vector3.ZERO, 0.02)


func _goliat_fist(k: Forge) -> void:
	k.limb([[-0.02, 0.22, 0.24, 0.26], [-0.2, 0.32, 0.34, 0.32], [-0.8, 0.34, 0.36, 0.34]], plate, 0.035)
	k.slab(Vector3(0.78, 0.09, 0.8), Vector3(0, -0.82, 0), trim, Vector3.ZERO, 0.014)
	k.bolts(Vector3(-0.2, -0.3, -0.35), Vector3(-0.2, -0.7, -0.35), 3, 0.026, steel, Vector3(-PI * 0.5, 0, 0))
	k.bolts(Vector3(0.2, -0.3, -0.35), Vector3(0.2, -0.7, -0.35), 3, 0.026, steel, Vector3(-PI * 0.5, 0, 0))
	_launcher(k)


## A drum launcher built onto the forearm, muzzle pointing down the arm.
func _launcher(k: Forge) -> void:
	k.slab(Vector3(0.5, 0.3, 0.46), Vector3(0, -0.98, 0), plate2, Vector3.ZERO, 0.04)
	k.pod([[-0.84, 0.3, 0.3], [-1.02, 0.34, 0.34], [-1.28, 0.34, 0.34], [-1.4, 0.3, 0.3]], steel, 12)
	for i in 6:
		var a := TAU * i / 6.0
		k.slab(Vector3(0.1, 0.4, 0.1), Vector3(cos(a) * 0.3, -1.14, sin(a) * 0.3), dark, Vector3.ZERO, 0.012)
	k.pod([[-1.36, 0.16, 0.16], [-1.72, 0.14, 0.14], [-1.78, 0.17, 0.17], [-1.84, 0.17, 0.17]], plate, 12)
	k.pod([[-1.84, 0.12, 0.12], [-1.86, 0.1, 0.1]], dark, 12)
	k.slab(Vector3(0.06, 0.34, 0.04), Vector3(0.2, -1.5, 0), light_soft, Vector3.ZERO, 0.01)


func _goliat_thigh(k: Forge, s: float) -> void:
	k.limb([[-0.02, 0.22, 0.26, 0.24], [-0.2, 0.31, 0.36, 0.3], [-0.74, 0.22, 0.26, 0.24]], plate, 0.035)
	k.slab(Vector3(0.07, 0.56, 0.62), Vector3(0.34 * s, -0.36, -0.02), plate2, Vector3(0, 0, 0.04 * s), 0.02)
	k.bolts(Vector3(0.38 * s, -0.14, -0.24), Vector3(0.38 * s, -0.14, 0.2), 3, 0.024, steel, Vector3(0, 0, -PI * 0.5 * s))
	k.slab(Vector3(0.1, 0.06, 0.62), Vector3(0.355 * s, -0.56, -0.02), trim, Vector3.ZERO, 0.012)
	k.ram(Vector3(-0.05, -0.08, 0.3), Vector3(-0.05, -0.64, 0.26), 0.05, dark, steel)


func _goliat_shin(k: Forge, s: float) -> void:
	k.ball(0.23, Vector3.ZERO, dark)
	# Knee guard: a sharp wedge that juts forward.
	k.limb([[-0.2, 0.22, 0.2, -0.02, -0.14], [0.0, 0.26, 0.34, -0.06, -0.14], [0.2, 0.18, 0.2, -0.04, -0.12]], plate2, 0.03)
	k.limb([[-0.08, 0.24, 0.3, 0.28], [-0.34, 0.33, 0.42, 0.34], [-0.76, 0.3, 0.36, 0.32]], plate, 0.035)
	k.slab(Vector3(0.4, 0.5, 0.06), Vector3(0, -0.42, -0.42), plate2, Vector3(0.05, 0, 0), 0.02, Vector2(1.16, 1))
	k.bolts(Vector3(-0.13, -0.24, -0.44), Vector3(0.13, -0.24, -0.44), 3, 0.024, steel, Vector3(-PI * 0.5, 0, 0))
	k.slab(Vector3(0.08, 0.1, 0.72), Vector3(0.335 * s, -0.56, 0.02), trim, Vector3.ZERO, 0.012)
	k.ball(0.16, Vector3(0, -SHIN_LEN, 0), dark)


func _goliat_foot(k: Forge, _s: float) -> void:
	var g := -ANKLE_H
	# One long armoured wedge, like a sledge.
	k.hull([
		[-0.84, g, g + 0.04, g + 0.1, 0.3, 0.34, 0.26],
		[-0.42, g, g + 0.14, g + 0.3, 0.38, 0.4, 0.28],
		[0.28, g, g + 0.14, g + 0.34, 0.36, 0.38, 0.26],
		[0.52, g, g + 0.08, g + 0.2, 0.28, 0.3, 0.2],
	], plate, 0.03)
	k.slab(Vector3(0.84, 0.06, 0.12), Vector3(0, g + 0.04, -0.78), steel, Vector3(0.14, 0, 0), 0.016)
	k.slab(Vector3(0.1, 0.05, 0.84), Vector3(0, g + 0.3, -0.34), trim, Vector3(0.28, 0, 0), 0.012)
	k.slab(Vector3(0.82, 0.08, 1.3), Vector3(0, g + 0.02, -0.16), dark, Vector3.ZERO, 0.02)


# ---------------------------------------------------------------- behaviour

func set_loadout(new_weapon: int, _class_id: int, parts: Array = []) -> void:
	set_weapon(new_weapon, parts)


func set_weapon(id: int, _parts: Array = []) -> void:
	_launcher_up = id == C.W.MECH_LAUNCHER


func reset_pose() -> void:
	_fall = -1.0
	rotation = Vector3.ZERO
	pelvis.position.y = HIP_Y
	pelvis.rotation = Vector3.ZERO
	cannon_arm.rotation = Vector3(GUN_SHOULDER, 0, 0)
	cannon_elbow.rotation = Vector3(GUN_ELBOW, 0, 0)
	fist_arm.rotation = Vector3(0.2, 0, 0)
	fist_elbow.rotation = Vector3(0.5, 0, 0)
	_end_wreck()


func play_swing() -> void:
	_punch = 1.0


func play_fire() -> void:
	_recoil = 1.0


func play_death() -> void:
	_fall = 0.0
	_corpse_t = WRECK_TIME
	_start_wreck()


func muzzle_position() -> Vector3:
	return _launcher_muzzle.global_position if _launcher_up else muzzle.global_position


## Places one ankle at `foot`, given in model space, and keeps the sole level.
func _solve_leg(hip: Node3D, knee: Node3D, ankle: Node3D, foot: Vector3, sole_tilt: float) -> void:
	var root := pelvis.position + hip.position
	var to := foot - root
	var reach := clampf(Vector2(to.y, to.z).length(), 0.3, THIGH_LEN + SHIN_LEN - 0.005)
	var cos_inner := (THIGH_LEN * THIGH_LEN + SHIN_LEN * SHIN_LEN - reach * reach) / (2.0 * THIGH_LEN * SHIN_LEN)
	var bend := PI - acos(clampf(cos_inner, -1.0, 1.0))
	var open := asin(clampf(SHIN_LEN * sin(bend) / reach, -1.0, 1.0))
	hip.rotation.x = atan2(-to.z, -to.y) + open
	hip.rotation.z = atan2(to.x, -to.y)
	knee.rotation.x = -bend
	ankle.rotation.x = -(hip.rotation.x + knee.rotation.x) + sole_tilt
	ankle.rotation.z = -hip.rotation.z


## Where a foot is at `c` in its cycle: x and y along the motion and up, z the sole's tilt.
func _foot_path(c: float) -> Vector3:
	if c < STANCE:
		return Vector3(lerpf(STRIDE, -STRIDE, c / STANCE), 0.0, 0.0)
	var u := (c - STANCE) / (1.0 - STANCE)
	var eased := u * u * (3.0 - 2.0 * u)
	# The toe stays down as it leaves and rises to meet the ground as it arrives.
	return Vector3(lerpf(-STRIDE, STRIDE, eased), sin(u * PI) * STEP_LIFT, lerpf(-0.5, 0.3, u) * sin(u * PI))


func _place_foot(hip: Node3D, knee: Node3D, ankle: Node3D, side: float, c: float) -> void:
	var f := _foot_path(c)
	var along := f.x * _amp
	var foot := Vector3(FOOT_X * side + _dir.x * along, ANKLE_H + f.y * _amp, -_dir.y * along)
	_solve_leg(hip, knee, ankle, foot, f.z * _amp)


func update_pose(delta: float, pos: Vector3, yaw: float, pitch: float, speed: float, _crouching: bool, _aiming: bool, _blocking: bool, alive: bool) -> void:
	global_position = pos
	if _fall >= 0.0:
		_collapse(delta)
		return
	rotation = Vector3(0, yaw, 0)
	if not alive:
		return
	_recoil = move_toward(_recoil, 0.0, delta * 6.0)
	_punch = move_toward(_punch, 0.0, delta * 2.4)
	_idle += delta
	_amp = move_toward(_amp, clampf(speed / 1.5, 0.0, 1.0), delta * 3.0)
	if _local_vel.length_squared() > 0.25:
		_dir = _dir.lerp(_local_vel.normalized(), 1.0 - exp(-delta * 8.0)).normalized()
	# Paced so a planted foot travels back exactly as fast as the body moves forward.
	_cycle = fposmod(_cycle + delta * speed * STANCE / (2.0 * STRIDE), 1.0)
	var c_l := fposmod(_cycle + 0.5, 1.0)
	var settle := sin(_cycle * TAU * 2.0 - 0.6)
	var sway := sin(_cycle * TAU)
	pelvis.position.y = HIP_Y - 0.03 - (0.06 + (settle * 0.5 + 0.5) * 0.085) * _amp + sin(_idle * 1.3) * 0.008
	pelvis.position.x = sway * 0.07 * _amp
	pelvis.rotation = Vector3(0.05 * _amp * _dir.y, sway * 0.09 * _amp, -sway * 0.035 * _amp)
	_place_foot(hip_r, knee_r, ankle_r, 1.0, _cycle)
	_place_foot(hip_l, knee_l, ankle_l, -1.0, c_l)

	# The shoulders counter the hips, and the mass lags a little behind each footfall.
	torso.rotation = Vector3(pitch * 0.3 + settle * 0.012 * _amp - _recoil * 0.03, -sway * 0.14 * _amp, sway * 0.03 * _amp)
	head.rotation = Vector3(pitch * 0.5, sway * 0.1 * _amp, 0)
	cannon_arm.rotation.x = GUN_SHOULDER + pitch * 0.7 + _recoil * 0.07 + sway * 0.03 * _amp
	cannon_elbow.rotation.x = GUN_ELBOW + _recoil * 0.1
	# The launcher arm comes up when that weapon is chosen, and hangs at the side otherwise.
	_raise = move_toward(_raise, 1.0 if _launcher_up else 0.0, delta * 4.0)
	var kick := _recoil * (0.12 if _launcher_up else 0.0)
	fist_arm.rotation.x = lerpf(0.2 - sway * 0.28 * _amp, GUN_SHOULDER + pitch * 0.7, _raise) + kick
	fist_elbow.rotation.x = lerpf(0.5 + maxf(sway, 0.0) * 0.18 * _amp, GUN_ELBOW, _raise) + kick


func _collapse(delta: float) -> void:
	_corpse_t -= delta
	_cool(delta)
	if _corpse_t <= 0.0:
		visible = false
		return
	_fall = minf(_fall + delta * 0.9, 1.0)
	var t := _fall * _fall
	pelvis.position.y = lerpf(HIP_Y, 0.62, t)
	pelvis.rotation.x = -0.32 * t
	hip_l.rotation.x = 1.3 * t
	hip_r.rotation.x = 1.05 * t
	knee_l.rotation.x = -2.1 * t
	knee_r.rotation.x = -1.85 * t
	ankle_l.rotation.x = 0.7 * t
	ankle_r.rotation.x = 0.7 * t
	torso.rotation.x = -0.5 * t
	head.rotation.x = -0.4 * t
	cannon_arm.rotation.x = lerpf(GUN_SHOULDER, 0.1, t)
	cannon_elbow.rotation.x = lerpf(GUN_ELBOW, 0.2, t)
	fist_arm.rotation.x = lerpf(0.2, -0.1, t)
	fist_elbow.rotation.x = lerpf(0.5, 0.15, t)
