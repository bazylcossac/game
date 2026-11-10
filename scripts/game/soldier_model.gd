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
const TROOPER_MODEL := "res://assets/models/armory/trooper_parts.glb"
const DROID_MODEL := "res://assets/models/armory/droid_parts.glb"
## Where the liquidator's weapon arms end, below the elbow: the cannon's bore and the pod's tubes.
const ARM_MUZZLE := {C.W.ARM_CANNON: Vector3(0.0, -0.56, 0.0), C.W.ARM_ROCKETS: Vector3(0.0, -0.49, -0.07)}

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
## A model looked at on its own, such as the class preview, always wears its finest meshes.
var always_fine := false
## The joints the poses turn. The skinned body copies them onto its bones after every pose.
var pelvis: Node3D
var torso: Node3D
var head: Node3D
var shoulder_r: Node3D
var elbow_r: Node3D
var hand_r: Node3D
var shoulder_l: Node3D
var elbow_l: Node3D
var hand_l: Node3D
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
var _rig: CharAssets.Rig
var _rig_key := ""
var _skeleton: Skeleton3D
## The joint that drives each bone of the skeleton, in the skeleton's order.
var _bone_joints: Array[Node3D] = []
## Each bone's place in the body, worked out from its joint and its parent's, and how much
## thicker than the modelled body this class makes it.
var _bone_placed: Array[Transform3D] = []
var _bone_girth: Array[Vector3] = []
var _build: Array = CharAssets.DEFAULT_BUILD
## How much further forward a deep chest pushes whatever the hands hold.
var _chest_reach := 0.0
var _look: Array = []
var _tint := Color.BLACK
var _worn: Array[MeshInstance3D] = []
var _jet_flames: Node3D
var _cloak_shown := -1.0
var _nade: Node3D
var _nade_items: Array[Node3D] = []
var _trail: BladeTrail


## Loads every body and standard weapon during loading, so that the first soldier to spawn with
## each of them does not stall the match.
static func warm_bodies() -> void:
	CharAssets.warm()
	for team in 2:
		for class_id in C.CLASSES[team].size():
			var cd := C.cls(team, class_id)
			if cd.get("mech", false) or cd.get("vehicle", false):
				continue
			for weapon: int in cd["weapons"]:
				if not C.WEAPONS[weapon].get("arm", false):
					WeaponFactory.third_person(weapon, team).free()


func _joint(parent: Node3D) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	return n


func setup(new_team: int) -> void:
	team = new_team
	pelvis = _joint(self)
	torso = _joint(pelvis)
	head = _joint(torso)
	shoulder_r = _joint(torso)
	elbow_r = _joint(shoulder_r)
	hand_r = _joint(elbow_r)
	shoulder_l = _joint(torso)
	elbow_l = _joint(shoulder_l)
	hand_l = _joint(elbow_l)
	hip_r = _joint(pelvis)
	knee_r = _joint(hip_r)
	ankle_r = _joint(knee_r)
	hip_l = _joint(pelvis)
	knee_l = _joint(hip_l)
	ankle_l = _joint(knee_l)
	holder = _joint(torso)
	_dress(CharAssets.DEFAULT_LOOK[team], CharAssets.DEFAULT_SKIN if team == C.Team.RESISTANCE else Color.BLACK)
	_nade = Node3D.new()
	_nade.position = Vector3(0, -0.09, -0.04)
	_nade.visible = false
	hand_r.add_child(_nade)
	for kind in C.NADE_NAMES.size():
		var item := Node3D.new()
		_nade.add_child(item)
		WeaponFactory.fit(item, "Nade_%d" % kind, team)
		_nade_items.append(item)


func set_loadout(new_weapon: int, class_id: int, parts: Array = []) -> void:
	var cd := C.cls(team, class_id)
	_dress(CharAssets.look(team, String(cd["id"])), CharAssets.tint(team, cd), CharAssets.build(String(cd["id"])))
	_fit_extras(cd)
	set_weapon(new_weapon, parts)
	_cloak_shown = -1.0


## Puts on a look, [file, body, head, gear], on a body of the given build. Another file means
## another skeleton.
func _dress(look_of: Array, tint: Color, build: Array = CharAssets.DEFAULT_BUILD) -> void:
	if look_of == _look and tint == _tint and build == _build:
		return
	var rebuilt: bool = look_of[0] != _rig_key
	if rebuilt:
		_rig_key = look_of[0]
		_rig = CharAssets.rig(_rig_key)
		if _skeleton:
			_skeleton.free()
		_worn.clear()
		_skeleton = CharAssets.skeleton(_rig)
		add_child(_skeleton)
	if rebuilt or build != _build:
		_build = build
		_shape()
	if rebuilt or look_of != _look or tint != _tint:
		for mi in _worn:
			mi.free()
		_worn.clear()
		for label: String in look_of.slice(1):
			if label != "":
				_worn.append_array(CharAssets.fit(_skeleton, _rig, label, team, tint, always_fine))
	_look = look_of
	_tint = tint
	_sync()


## Sets the joints where this build has them, and how thick each bone makes its part of the mesh.
func _shape() -> void:
	var joints := {
		"Pelvis": pelvis, "Torso": torso, "Head": head, "UpperArm_R": shoulder_r, "Forearm_R": elbow_r, "Hand_R": hand_r,
		"UpperArm_L": shoulder_l, "Forearm_L": elbow_l, "Hand_L": hand_l, "Thigh_R": hip_r, "Shin_R": knee_r, "Boot_R": ankle_r,
		"Thigh_L": hip_l, "Shin_L": knee_l, "Boot_L": ankle_l,
	}
	var wide: float = _build[1]
	var deep: float = _build[2]
	var arm: float = _build[3]
	var leg: float = _build[4]
	var hips: float = _build[5]
	_bone_joints.clear()
	_bone_girth.clear()
	_bone_placed.resize(_rig.bones.size())
	for i in _rig.bones.size():
		var bone := _rig.bones[i]
		var joint: Node3D = joints[bone]
		var at := _rig.rests[i].origin
		var girth := Vector3.ONE
		if bone == "Pelvis":
			girth = Vector3(hips, 1.0, lerpf(1.0, deep, 0.7))
		elif bone == "Torso":
			girth = Vector3(wide, 1.0, deep)
		elif bone.begins_with("UpperArm"):
			at.x *= wide
			girth = Vector3(arm, 1.0, arm)
		elif bone.begins_with("Forearm"):
			girth = Vector3(arm, 1.0, arm)
		elif bone.begins_with("Hand"):
			girth = Vector3.ONE * lerpf(1.0, arm, 0.5)
		elif bone.begins_with("Thigh"):
			at.x *= hips
			girth = Vector3(leg, 1.0, leg)
		elif bone.begins_with("Shin"):
			girth = Vector3(leg, 1.0, leg)
		elif bone.begins_with("Boot"):
			girth = Vector3(leg, 1.0, lerpf(1.0, leg, 0.5))
		joint.position = at
		_bone_joints.append(joint)
		_bone_girth.append(girth)
	_chest_reach = (deep - 1.0) * 0.13
	scale = Vector3.ONE * float(_build[0])


## Hands the posed joints to the bones. A joint's transform is its bone's, since the skeleton
## rests with every bone unturned; the build's girth goes on last, in the bone's own space.
func _sync() -> void:
	for i in _bone_joints.size():
		var placed := _bone_joints[i].transform
		var parent := _rig.parents[i]
		if parent >= 0:
			placed = _bone_placed[parent] * placed
		_bone_placed[i] = placed
		_skeleton.set_bone_pose(i, placed.scaled_local(_bone_girth[i]))


## What a class has that is not part of its mesh: the jump pack's flames.
func _fit_extras(cd: Dictionary) -> void:
	if _jet_flames:
		_jet_flames.free()
		_jet_flames = null
	if cd.get("jetpack", false):
		_jet_flames = Node3D.new()
		torso.add_child(_jet_flames)
		for side: float in [-1.0, 1.0]:
			P.cyl(_jet_flames, 0.07, 0.0, 0.6, Vector3(0.155 * side, -0.36, 0.3), Mats.glow(Color(0.5, 0.8, 1.0), 3.0))
		_jet_flames.visible = false


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
	_sync()


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
	_sync()


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
	pos.z -= _chest_reach
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
	_sync()
