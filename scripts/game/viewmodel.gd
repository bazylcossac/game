class_name ViewModel
extends Node3D
## First-person weapon and hands. Every movement here is procedural.

const SWING_TIME := 0.46
const THROW_TIME := 0.78
## The fraction of the throw at which the grenade leaves the hand.
const THROW_RELEASE := 0.56
## Where the throwing hand goes: [time, position, wrist]. Up into view, pin out, back over the
## shoulder, a fast whip forward, and the arm follows through out of sight.
const THROW_KEYS := [
	[0.0, Vector3(-0.34, -0.66, -0.42), Vector3(0.5, 0.0, 0.2)],
	[0.2, Vector3(-0.2, -0.17, -0.5), Vector3(0.05, 0.25, 0.3)],
	[0.32, Vector3(-0.2, -0.16, -0.5), Vector3(0.05, 0.25, 0.3)],
	[0.48, Vector3(-0.36, 0.14, -0.1), Vector3(-0.95, 0.0, 0.4)],
	[0.58, Vector3(-0.14, 0.12, -0.66), Vector3(0.8, 0.0, -0.1)],
	[0.7, Vector3(-0.02, -0.16, -0.86), Vector3(1.3, 0.0, -0.2)],
	[1.0, Vector3(0.06, -0.8, -0.6), Vector3(1.5, 0.0, 0.0)],
]
## Below the bottom of the screen, where the forearms come from.
const ELBOW_R := Vector3(0.42, -0.72, -0.12)
const ELBOW_L := Vector3(-0.42, -0.72, -0.12)

## Hip position, ADS position (centres the sights), per weapon.
const POSES := {
	C.W.AT_ROCKET: {"hip": Vector3(.24, -.22, -.45), "ads": Vector3(.055, -.17, -.3)},
	C.W.PISTOL: {"hip": Vector3(0.2, -0.22, -0.56), "ads": Vector3(0.0, -0.112, -0.46)},
	C.W.CARBINE: {"hip": Vector3(0.2, -0.21, -0.46), "ads": Vector3(0.0, -0.145, -0.3)},
	C.W.SNIPER: {"hip": Vector3(0.2, -0.22, -0.42), "ads": Vector3(0.0, -0.15, -0.2)},
	C.W.DMR: {"hip": Vector3(0.2, -0.215, -0.44), "ads": Vector3(0.0, -0.145, -0.26)},
	C.W.HEAVY: {"hip": Vector3(0.22, -0.27, -0.46), "ads": Vector3(0.0, -0.205, -0.32)},
	C.W.MINIGUN: {"hip": Vector3(0.26, -0.3, -0.46), "ads": Vector3(0.21, -0.31, -0.36)},
	# The arm in use sits in front, the other one off to its side: both stay in the picture.
	# Held low and to the left of centre, so the plate covers the body and the street shows through it.
	C.W.ENERGY_SHIELD: {"hip": Vector3(0.0, -0.4, -0.5), "ads": Vector3(0.0, -0.4, -0.5)},
	C.W.ARM_CANNON: {"hip": Vector3(0.22, -0.22, -0.36), "ads": Vector3(0.13, -0.19, -0.32)},
	C.W.ARM_ROCKETS: {"hip": Vector3(-0.2, -0.25, -0.36), "ads": Vector3(-0.12, -0.21, -0.32)},
	C.W.SMG: {"hip": Vector3(0.2, -0.21, -0.46), "ads": Vector3(0.0, -0.145, -0.3)},
	C.W.MECH_GOLEM: {"hip": Vector3(0.42, -0.36, -0.7), "ads": Vector3(0.3, -0.34, -0.7)},
	C.W.MECH_GOLIAT: {"hip": Vector3(0.42, -0.36, -0.7), "ads": Vector3(0.3, -0.34, -0.7)},
	C.W.MECH_LAUNCHER: {"hip": Vector3(0.42, -0.36, -0.7), "ads": Vector3(0.3, -0.34, -0.7)},
	C.W.REVOLVER: {"hip": Vector3(0.2, -0.22, -0.56), "ads": Vector3(0.0, -0.112, -0.46)},
	C.W.MPISTOL: {"hip": Vector3(0.2, -0.22, -0.56), "ads": Vector3(0.0, -0.112, -0.46)},
	C.W.RAIL: {"hip": Vector3(0.2, -0.22, -0.42), "ads": Vector3(0.0, -0.15, -0.2)},
	C.W.GREATSWORD: {"hip": Vector3(0.3, -0.3, -0.5), "ads": Vector3(0.0, -0.17, -0.5)},
	C.W.LIGHTSABER: {"hip": Vector3(0.3, -0.3, -0.5), "ads": Vector3(0.0, -0.17, -0.5)},
	C.W.SWORD: {"hip": Vector3(0.3, -0.3, -0.5), "ads": Vector3(0.0, -0.17, -0.5)},
}

const BARREL_AXIS := Vector3(0.0, 0.07, 0.0)
## Flipping the KP-20's magnifier: the gun rolls its left side up into view, the left hand comes
## off the handguard to the magnifier, flicks it over on its hinge and goes back.
const FLIP_TIME := 0.52
## Where the left hand pushes the magnifier, in the gun's frame, just outside the hinge.
const FLIP_HAND := Vector3(-0.058, 0.118, 0.05)
## While the hand is up there the elbow drops below the screen, held in view space: tied to the gun
## it would swing up into the picture as the gun rolls over.
const FLIP_ELBOW := Vector3(-0.34, -0.78, -0.26)
const RELOAD_ROCKET := "res://assets/models/armory/rocket_load.glb"
const TUBE_HEIGHT := 0.09
const ROCKET_TAIL := Vector3(0.0, 0.0, 0.3)
const LEFT_HAND_REST := Vector3(0.0, -0.03, -0.34)
const ROCKET_SWING_POS := Vector3(0.06, 0.0, -0.12)
const ROCKET_SWING_ROT := Vector3(-0.16, -0.95, 0.08)
const BLADE_REST_POS := Vector3(0.3, -0.3, -0.5)
const BLADE_REST_ROT := Vector3(-1.02, 0.1, -0.42)
## Blade poses in view space: [time, position, rotation]. The hilt travels; the blade
## points along +Y of the rotation, so negative Z rotation leans it to the right.
const SWINGS := [
	[
		[0.0, BLADE_REST_POS, BLADE_REST_ROT],
		[0.24, Vector3(0.42, -0.04, -0.42), Vector3(-0.35, 0.2, -1.05)],
		[0.48, Vector3(0.02, -0.17, -0.62), Vector3(-1.2, 0.0, 0.45)],
		[0.68, Vector3(-0.34, -0.34, -0.5), Vector3(-0.72, -0.2, 1.5)],
		[1.0, BLADE_REST_POS, BLADE_REST_ROT],
	],
	[
		[0.0, BLADE_REST_POS, BLADE_REST_ROT],
		[0.24, Vector3(-0.26, -0.04, -0.44), Vector3(-0.4, -0.2, 1.1)],
		[0.48, Vector3(0.04, -0.18, -0.62), Vector3(-1.2, 0.0, -0.3)],
		[0.68, Vector3(0.42, -0.36, -0.46), Vector3(-0.75, 0.2, -1.55)],
		[1.0, BLADE_REST_POS, BLADE_REST_ROT],
	],
	[
		[0.0, BLADE_REST_POS, BLADE_REST_ROT],
		[0.26, Vector3(0.16, 0.02, -0.34), Vector3(0.25, 0.0, -0.15)],
		[0.5, Vector3(0.05, -0.14, -0.62), Vector3(-1.3, 0.0, -0.05)],
		[0.7, Vector3(0.06, -0.46, -0.56), Vector3(-1.95, 0.0, 0.0)],
		[1.0, BLADE_REST_POS, BLADE_REST_ROT],
	],
]

var team := 0
## Set just before the shield is taken away because it broke, so it goes out the hard way.
var shield_broken_next := false
var weapon_id := -1
var weapon_parts: Array = []
## How fast the sights come up, set from the weapon's stats.
var ads_rate := 7.5
var gun: Node3D
var holder := Node3D.new()
var arm_r: Node3D
var arm_l: Node3D
var flash: OmniLight3D
var sword_light: OmniLight3D
var cockpit: Node3D
var _blade: Node3D
var _ignite := 1.0
var _cell: Node3D
var _cell_home := Vector3.ZERO
## A minigun's barrels, and how fast they are turning from 0 to 1.
var _barrels: Node3D
var _barrel_turn := 0.0
var barrel_speed := 0.0
## The flip magnifier, how far it is open (0 folded aside, 1 on the sight line), where it is
## going, and the flip in progress (-1 when none).
var _magnifier: Node3D
var _mag_open := 0.0
var _mag_from := 0.0
var _mag_target := 0.0
var _flip := -1.0
var _flip_clicked := false
## How far the left hand is off the handguard, and whether it still has to be put back.
var _reach := 0.0
var _reaching := false
## The rocket the left hand feeds into the back of the launcher.
var _round: Node3D
var _muzzle_sprite: MeshInstance3D
var _heat_mat: StandardMaterial3D
var _heat := 0.0
var _trail: BladeTrail
var _sword_forearm: MeshInstance3D
var _throw_rig: Node3D
var _throw_forearm: Node3D
var _throw_hand: Node3D
var _throw_items: Array[Node3D] = []
var _throw_pin: Node3D
var _throw_spoon: Node3D
var _throw_kind := C.NADE_FRAG

var ads := 0.0
var _kick := 0.0
var _kick_rot := 0.0
var _sway := Vector2.ZERO
var _bob_phase := 0.0
var _reload := 0.0
var _reload_len := 1.0
var _raise := 0.0
var _swing := -1.0
var _combo := 0
var _block := 0.0
var _sprint := 0.0
var _flash_t := 0.0
var _throw := -1.0
var _lag_y := 0.0
var _left_home := Vector3.ZERO


func setup(new_team: int) -> void:
	team = new_team
	add_child(holder)
	flash = OmniLight3D.new()
	flash.light_color = C.TEAM_COLORS[team]
	flash.omni_range = 7.0
	flash.light_energy = 0.0
	flash.shadow_enabled = false
	flash.position = Vector3(0.1, -0.1, -0.9)
	add_child(flash)
	sword_light = OmniLight3D.new()
	sword_light.light_color = C.TEAM_COLORS[team]
	sword_light.omni_range = 4.0
	sword_light.light_energy = 0.0
	sword_light.position = Vector3(0.2, 0.1, -0.7)
	add_child(sword_light)
	_trail = BladeTrail.new()
	_trail.setup(C.TEAM_COLORS[team], true)
	add_child(_trail)
	_build_muzzle_sprite()
	_build_throw_rig()


func _build_muzzle_sprite() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.34)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = Mats.tex("flare")
	m.albedo_color = Color(C.TEAM_COLORS[team].r * 2.4, C.TEAM_COLORS[team].g * 2.4, C.TEAM_COLORS[team].b * 2.4)
	m.use_fov_override = true
	m.fov_override = 62.0
	m.use_z_clip_scale = true
	m.z_clip_scale = 0.12
	_muzzle_sprite = MeshInstance3D.new()
	_muzzle_sprite.mesh = quad
	_muzzle_sprite.material_override = m
	_muzzle_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle_sprite.visible = false
	add_child(_muzzle_sprite)


func _build_throw_rig() -> void:
	_throw_rig = Node3D.new()
	add_child(_throw_rig)
	_throw_forearm = _trooper_part("FP_Arm")
	_throw_rig.add_child(_throw_forearm)
	_throw_hand = Node3D.new()
	_throw_rig.add_child(_throw_hand)
	for kind in C.NADE_NAMES.size():
		var item := Node3D.new()
		item.position = Vector3(0.016, 0.02, -0.03)
		item.scale = Vector3.ONE * 1.25
		_throw_hand.add_child(item)
		WeaponFactory.fit(item, "Nade_%d" % kind, team)
		_throw_items.append(item)
	_throw_pin = Node3D.new()
	_throw_hand.add_child(_throw_pin)
	WeaponFactory.fit(_throw_pin, "Nade_pin", team)
	_throw_spoon = Node3D.new()
	_throw_hand.add_child(_throw_spoon)
	WeaponFactory.fit(_throw_spoon, "Nade_spoon", team)
	_glove(_throw_hand, Vector3.ZERO, Vector3.ZERO)
	P.to_viewmodel(_throw_rig)
	_throw_rig.visible = false


func _sleeve() -> Material:
	return Mats.cloth(Color(0.13, 0.17, 0.25))


func _forearm_mesh(parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.052
	m.bottom_radius = 0.036
	m.height = 1.0
	m.radial_segments = 12
	m.rings = 1
	mi.mesh = m
	mi.material_override = _sleeve()
	parent.add_child(mi)
	return mi


## Stretches a forearm from a hand position out to a fixed elbow.
func _place_forearm(mi: MeshInstance3D, hand: Vector3, elbow: Vector3) -> void:
	var length := hand.distance_to(elbow)
	var dir := (elbow - hand) / maxf(length, 0.01)
	var b := Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(1.0, length, 1.0))
	mi.transform = Transform3D(b, (hand + elbow) * 0.5)


func set_weapon(id: int, parts: Array = []) -> void:
	if id == weapon_id and parts == weapon_parts:
		return
	var was_shield := weapon_id == C.W.ENERGY_SHIELD
	weapon_id = id
	weapon_parts = parts
	_raise = 1.0
	_swing = -1.0
	if gun and was_shield and gun.get_node_or_null("Plate"):
		var old_plate := gun.get_node("Plate") as Node3D
		old_plate.reparent(self)
		WeaponFactory.collapse_shield(self, old_plate, shield_broken_next)
		if not shield_broken_next:
			Sfx.play("shield_off", -6.0)
	shield_broken_next = false
	if gun:
		gun.queue_free()
	if arm_r:
		arm_r.queue_free()
	if arm_l:
		arm_l.queue_free()
	if _sword_forearm:
		_sword_forearm.queue_free()
		_sword_forearm = null
	gun = WeaponFactory.build(id, team, parts)
	holder.add_child(gun)
	_round = null
	if id == C.W.AT_ROCKET:
		_round = (load(RELOAD_ROCKET) as PackedScene).instantiate()
		_round.visible = false
		gun.add_child(_round)
		_viewmodel_surfaces(_round)
	_build_arms()
	P.to_viewmodel(holder)
	if id == C.W.ENERGY_SHIELD and gun.get_node_or_null("Plate"):
		WeaponFactory.deploy_shield(self, gun.get_node("Plate"))
		Sfx.play("shield_on", -4.0)
	_set_cockpit(false)
	sword_light.light_energy = 0.0
	if C.is_blade(id):
		sword_light.light_energy = 1.1 if id == C.W.LIGHTSABER else 0.3
		_sword_forearm = _forearm_mesh(self)
		_sword_forearm.material_override = Mats.viewmodel(_sleeve())
		_sword_forearm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade = gun.get_node_or_null("Blade") as Node3D
	_ignite = 0.0
	_cell = gun.get_node_or_null("Cell") as Node3D
	_magnifier = gun.get_node_or_null("Magnifier") as Node3D
	_flip = -1.0
	_mag_open = _mag_target
	if _magnifier:
		_magnifier.transform = WeaponFactory.magnifier_pose(_mag_open)
	_barrels = gun.get_node_or_null("Spin") as Node3D
	_barrel_turn = 0.0
	if _cell:
		_cell_home = _cell.position
	_heat_mat = Mats.viewmodel(Mats.glow(C.TEAM_COLORS[team], 1.5))
	_heat = 0.0


## A model from a file keeps its materials on the mesh, where to_viewmodel does not look. Left as
## they are it would be drawn in the world, behind the gun and in a different perspective.
func _viewmodel_surfaces(root: Node) -> void:
	for part in root.find_children("*", "MeshInstance3D", true, false):
		var mi := part as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				mi.set_surface_override_material(i, Mats.viewmodel(m))


## Mech pilots sit behind a frame instead of seeing their own hands.
func _set_cockpit(on: bool) -> void:
	if cockpit == null and on:
		cockpit = Node3D.new()
		add_child(cockpit)
		var shell := MeshInstance3D.new()
		shell.mesh = Forge.mesh("cockpit/%d" % team, _cockpit_shell)
		var skin := StandardMaterial3D.new()
		skin.vertex_color_use_as_albedo = true
		skin.roughness = 0.7
		skin.metallic = 0.1
		shell.material_override = skin
		cockpit.add_child(shell)
		var lamp: Material = Mats.glow(C.TEAM_COLORS[team], 1.2)
		var warn: Material = Mats.glow(Color(1.0, 0.62, 0.2), 1.4)
		for x: float in [-0.3, -0.24, -0.18, 0.18, 0.24]:
			P.box(cockpit, Vector3(0.04, 0.012, 0.01), Vector3(x, -0.335, -0.6), lamp if x < 0.0 else warn)
		for side: float in [-1.0, 1.0]:
			P.box(cockpit, Vector3(0.006, 0.26, 0.006), Vector3(side * 0.7, 0.04, -0.68), lamp, Vector3(0, 0, side * 0.2))
		P.to_viewmodel(cockpit)
	if cockpit:
		cockpit.visible = on


## Canopy frame: raked pillars, a heavy brow and a dash with dials, all in the walker's paint.
## The view ends about 0.4 up and down at this depth, so the frame sits just inside that.
func _cockpit_shell(k: Forge) -> void:
	var golem := team == C.Team.RESISTANCE
	var frame := Forge.tone(Color(0.62, 0.4, 0.28) if golem else Color(0.4, 0.42, 0.44))
	var inner := Forge.tone(Color(0.24, 0.19, 0.17) if golem else Color(0.16, 0.17, 0.18))
	var trim := Forge.tone(Color(0.9, 0.7, 0.32) if golem else Color(0.62, 0.12, 0.08))
	for side: float in [-1.0, 1.0]:
		k.slab(Vector3(0.16, 1.2, 0.14), Vector3(side * 0.8, 0.0, -0.74), frame, Vector3(0, 0, side * 0.2), 0.03, Vector2(0.72, 0.9))
		k.slab(Vector3(0.05, 1.0, 0.1), Vector3(side * 0.71, 0.0, -0.71), inner, Vector3(0, 0, side * 0.2), 0.012)
		k.slab(Vector3(0.44, 0.24, 0.3), Vector3(side * 0.62, -0.41, -0.64), frame, Vector3(0.2, 0, side * 0.1), 0.03, Vector2(0.86, 0.8))
		k.lathe([Vector2(0.05, 0), Vector2(0.058, 0.008), Vector2(0.058, 0.024), Vector2(0.04, 0.024)], Vector3(side * 0.44, -0.355, -0.6), trim, Vector3(1.3, 0, 0), 14)
		k.lathe([Vector2(0.0, 0.0), Vector2(0.042, 0.0)], Vector3(side * 0.44, -0.34, -0.604), inner, Vector3(PI + 1.3, 0, 0), 14)
	k.slab(Vector3(1.9, 0.12, 0.2), Vector3(0, 0.46, -0.76), frame, Vector3(0.14, 0, 0), 0.03, Vector2(0.94, 0.9))
	k.slab(Vector3(1.6, 0.02, 0.05), Vector3(0, 0.392, -0.68), trim, Vector3.ZERO, 0.006)
	k.slab(Vector3(1.9, 0.2, 0.4), Vector3(0, -0.46, -0.68), frame, Vector3(0.22, 0, 0), 0.04, Vector2(0.96, 0.84))
	k.slab(Vector3(1.5, 0.02, 0.05), Vector3(0, -0.358, -0.61), trim, Vector3(0.22, 0, 0), 0.006)
	k.slab(Vector3(0.74, 0.05, 0.14), Vector3(0, -0.35, -0.64), inner, Vector3(0.3, 0, 0), 0.012)


## The gloved fist from the trooper model. `rot` turns it to wrap a grip.
func _glove(parent: Node3D, pos: Vector3, rot: Vector3) -> void:
	var g := _trooper_part("FP_Glove")
	g.position = pos
	g.rotation = rot
	parent.add_child(g)


## The same hand and forearm in either side's model: a glove and sleeve, or bare machinery.
func _trooper_part(label: String) -> Node3D:
	var droid := team == C.Team.EMPIRE
	var imported := ModelAssets.load_model(SoldierModel.DROID_MODEL if droid else SoldierModel.TROOPER_MODEL, team, true)
	var part := imported.find_child(label + "_D" if droid else label, true, false) as Node3D
	part.get_parent().remove_child(part)
	part.transform = Transform3D.IDENTITY
	ModelAssets.flatten(part)
	imported.free()
	return part


func _build_arms() -> void:
	var build := func(hand: Vector3, elbow: Vector3, with_band: bool, grip: Vector3) -> Node3D:
		var n := Node3D.new()
		holder.add_child(n)
		var dir := (elbow - hand).normalized()
		# The modelled forearm runs one metre up from the wrist.
		var arm := _trooper_part("FP_Arm")
		arm.basis = Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(1, hand.distance_to(elbow), 1))
		arm.position = hand
		n.add_child(arm)
		_glove(n, hand, grip)
		# Kept so a hand can reach somewhere else while its elbow stays put.
		n.set_meta("hand", hand)
		n.set_meta("elbow", elbow)
		return n
	var right_grip := Vector3(0.28, 0, 0)
	var left_grip := Vector3(0, 0, PI)
	match weapon_id:
		C.W.MECH_GOLEM, C.W.MECH_GOLIAT, C.W.MECH_LAUNCHER, C.W.ARM_CANNON, C.W.ARM_ROCKETS:
			arm_r = Node3D.new()
			holder.add_child(arm_r)
			arm_l = Node3D.new()
			holder.add_child(arm_l)
		C.W.ENERGY_SHIELD:
			arm_r = build.call(Vector3(0, -0.02, 0.03), Vector3(0.18, -0.3, 0.42), false, right_grip)
			arm_l = Node3D.new()
			holder.add_child(arm_l)
		C.W.PISTOL, C.W.REVOLVER, C.W.MPISTOL:
			arm_r = build.call(Vector3(0, -0.02, 0.03), Vector3(0.08, -0.3, 0.42), false, right_grip)
			arm_l = build.call(Vector3(-0.03, -0.05, 0.05), Vector3(-0.3, -0.34, 0.36), true, Vector3(0.2, 0, 0.4))
		C.W.SWORD, C.W.LIGHTSABER, C.W.GREATSWORD:
			arm_r = Node3D.new()
			holder.add_child(arm_r)
			_glove(arm_r, Vector3(0, 0.0, 0), Vector3(0, 0, 0))
			arm_l = Node3D.new()
			holder.add_child(arm_l)
		C.W.HEAVY:
			arm_r = build.call(Vector3(0, -0.08, 0.06), Vector3(0.12, -0.34, 0.4), false, right_grip)
			arm_l = build.call(Vector3(0, -0.06, -0.42), Vector3(-0.3, -0.34, 0.1), true, left_grip)
		C.W.MINIGUN:
			# The left hand holds the upright handle under the collar.
			arm_r = build.call(Vector3(0, -0.08, 0.06), Vector3(0.12, -0.34, 0.4), false, right_grip)
			arm_l = build.call(Vector3(0, -0.06, -0.376), Vector3(-0.3, -0.36, 0.12), true, Vector3(0.28, 0, 0))
		_:
			arm_r = build.call(Vector3(0, -0.07, 0.05), Vector3(0.1, -0.32, 0.42), false, right_grip)
			arm_l = build.call(Vector3(0, -0.03, -0.34), Vector3(-0.3, -0.32, 0.12), true, left_grip)
	_left_home = arm_l.position


func kick(strength: float) -> void:
	_kick = minf(_kick + strength, 1.6)
	_kick_rot = minf(_kick_rot + strength * 0.6, 1.2)
	_flash_t = 0.05
	_heat = minf(_heat + 0.3, 1.0)
	if not C.is_blade(weapon_id) and gun:
		var m := gun.get_node_or_null("Muzzle") as Node3D
		if m:
			_muzzle_sprite.position = to_local(m.global_position)
			_muzzle_sprite.rotation.z = randf() * TAU
			_muzzle_sprite.scale = Vector3.ONE * randf_range(0.8, 1.3)
			_muzzle_sprite.visible = true


## Puts the magnifier on the sight line or folds it aside; with `animate` the hands do it.
func set_sight(open: bool, animate := false) -> void:
	_mag_target = 1.0 if open else 0.0
	if not animate or _magnifier == null or gun == null:
		_flip = -1.0
		_mag_open = _mag_target
		if _magnifier:
			_magnifier.transform = WeaponFactory.magnifier_pose(_mag_open)
		return
	_mag_from = _mag_open
	_flip = 0.0
	_flip_clicked = false
	Sfx.play("reload_out", -12.0, 1.6)


func switching_sight() -> bool:
	return _flip >= 0.0


func start_reload(duration: float) -> void:
	_reload = duration
	_reload_len = duration


func cancel_reload() -> void:
	_reload = 0.0
	_reset_reload_parts()


func _reset_reload_parts() -> void:
	if _round:
		_round.visible = false
	if _cell:
		_cell.position = _cell_home
		_cell.visible = true
	if arm_l:
		arm_l.position = _left_home


func play_swing() -> void:
	_swing = 0.0
	_combo = (_combo + 1) % SWINGS.size()


func play_throw(kind := C.NADE_FRAG) -> void:
	_throw = 0.0
	_throw_kind = kind
	for i in _throw_items.size():
		_throw_items[i].visible = i == kind
	Sfx.play("grenade_pin", -6.0)


func add_sway(mouse: Vector2) -> void:
	_sway += mouse * 0.00035


func animate(delta: float, aiming: bool, blocking: bool, sprinting: bool, speed: float, on_floor: bool, vertical_speed := 0.0) -> void:
	if gun == null:
		return
	ads = move_toward(ads, 1.0 if aiming else 0.0, delta * ads_rate)
	_block = move_toward(_block, 1.0 if blocking else 0.0, delta * 9.0)
	_sprint = move_toward(_sprint, 1.0 if sprinting else 0.0, delta * 6.0)
	_raise = move_toward(_raise, 0.0, delta * 3.6)
	_kick = lerpf(_kick, 0.0, minf(delta * 14.0, 1.0))
	_kick_rot = lerpf(_kick_rot, 0.0, minf(delta * 11.0, 1.0))
	_sway = _sway.lerp(Vector2.ZERO, minf(delta * 9.0, 1.0))
	_sway = _sway.clamp(Vector2(-0.06, -0.06), Vector2(0.06, 0.06))
	_lag_y = lerpf(_lag_y, clampf(-vertical_speed * 0.006, -0.05, 0.05), minf(delta * 8.0, 1.0))
	_flash_t = maxf(_flash_t - delta, 0.0)
	flash.light_energy = 3.0 if _flash_t > 0.0 else 0.0
	_muzzle_sprite.visible = _flash_t > 0.0
	_heat = move_toward(_heat, 0.0, delta * 0.8)
	if _heat_mat:
		_heat_mat.emission_energy_multiplier = 1.5 + _heat * 4.0

	var pose: Dictionary = POSES.get(weapon_id, POSES[C.W.CARBINE])
	# Held out far enough that the stock is in the picture, not behind the player's ear.
	var hip: Vector3 = pose["hip"] + Vector3(-0.05, -0.015, -0.05)
	var sight: Vector3 = pose["ads"] + Vector3(0, 0, -0.1)
	var pos := hip.lerp(sight, _ease(ads))
	var stock := gun.get_node_or_null("ThirdPersonOnly") as Node3D
	if stock:
		stock.visible = ads < 0.45
	var rot := Vector3.ZERO

	var moving := clampf(speed / 6.0, 0.0, 1.0) if on_floor else 0.0
	_bob_phase = fmod(_bob_phase + delta * (speed * 1.55 + 0.9), TAU * 2.0)
	var calm := 1.0 - ads * 0.82
	pos.x += sin(_bob_phase * 0.5) * 0.009 * moving * calm + _sway.x * calm
	pos.y += (absf(sin(_bob_phase * 0.5)) - 0.5) * 0.012 * moving * calm - _sway.y * calm + sin(Time.get_ticks_msec() * 0.0014) * 0.0016 * calm + _lag_y * calm
	rot.y = -_sway.x * 1.4 * calm
	rot.x = _sway.y * 1.0 * calm
	rot.z = -_sway.x * 1.2 * calm

	pos.z += _kick * 0.05
	rot.x += _kick_rot * 0.06

	if _sprint > 0.0 and not C.is_blade(weapon_id):
		pos += Vector3(0.02, -0.06, 0.08) * _sprint
		rot += Vector3(-0.2, 0.75, 0.32) * _sprint
		pos.x += sin(_bob_phase) * 0.016 * _sprint

	if _flip >= 0.0:
		var flipped := _flip_pose(pos, rot, delta)
		pos = flipped[0]
		rot = flipped[1]

	if _reload > 0.0:
		_reload -= delta
		var parts := _reload_pose(pos, rot)
		pos = parts[0]
		rot = parts[1]
		if _reload <= 0.0:
			_reset_reload_parts()

	if _throw >= 0.0:
		_throw += delta / THROW_TIME
		if _throw >= 1.0:
			_throw = -1.0
			_throw_rig.visible = false
		else:
			_animate_throw()
			# The gun drops and swings aside so the throwing arm has the room.
			var clear := sin(minf(_throw * 1.3, 1.0) * PI)
			pos.y -= clear * 0.14
			pos.x += clear * 0.08
			rot.z -= clear * 0.22
			rot.x -= clear * 0.12

	pos.y -= _raise * 0.32
	rot.x -= _raise * 0.7

	if _barrels:
		_barrel_turn = fmod(_barrel_turn + barrel_speed * delta * 34.0, TAU)
		var turn := Basis(Vector3.BACK, _barrel_turn)
		_barrels.transform = Transform3D(turn, BARREL_AXIS - turn * BARREL_AXIS)
	if _blade:
		# The beam shoots out of the hilt when the weapon is drawn.
		_ignite = move_toward(_ignite, 1.0, delta * 6.0)
		_blade.scale.y = maxf(_ignite, 0.01)
	if C.is_blade(weapon_id):
		var s := _sword_pose(pos, rot, delta)
		pos = s[0]
		rot = s[1]

	holder.position = pos
	holder.rotation = rot
	# After the gun is placed, so the elbow can be held still in view space.
	if _reaching:
		_reach_left(_reach)
		_reaching = _flip >= 0.0
	if _sword_forearm:
		_place_forearm(_sword_forearm, pos, ELBOW_R + Vector3(pos.x * 0.4, 0.0, 0.0))
		_update_trail(delta)


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## The magnifier flip, in three beats: the gun rolls over and lifts to show its left side, the left
## hand comes back to the magnifier and throws it over with a little overshoot as the latch catches,
## then the gun settles back and the hand returns to the handguard.
func _flip_pose(pos: Vector3, rot: Vector3, delta: float) -> Array:
	_flip += delta / FLIP_TIME
	var t := minf(_flip, 1.0)
	var tilt := smoothstep(0.0, 0.24, t) * (1.0 - smoothstep(0.68, 1.0, t))
	pos += Vector3(-0.03, 0.035, 0.045) * tilt
	rot += Vector3(0.1, -0.2, -0.46) * tilt
	_reach = smoothstep(0.1, 0.3, t) * (1.0 - smoothstep(0.62, 0.86, t))
	_reaching = true
	# Thrown over between 0.3 and 0.56 with an overshoot that springs back into the latch.
	var k := clampf((t - 0.3) / 0.26, 0.0, 1.0)
	var back := 1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0)
	_mag_open = lerpf(_mag_from, _mag_target, back)
	if _magnifier:
		_magnifier.transform = WeaponFactory.magnifier_pose(_mag_open)
	if t >= 0.56 and not _flip_clicked:
		_flip_clicked = true
		Sfx.play("reload_in", -9.0, 1.8)
	var latch := smoothstep(0.55, 0.58, t) * (1.0 - smoothstep(0.58, 0.72, t))
	pos.x -= latch * 0.012
	rot.z += latch * 0.07
	if _flip >= 1.0:
		_flip = -1.0
		_mag_open = _mag_target
		if _magnifier:
			_magnifier.transform = WeaponFactory.magnifier_pose(_mag_open)
		_reach = 0.0
	return [pos, rot]


## Moves the left hand `amount` of the way from the handguard to the magnifier's tab. Only the hand
## travels: the forearm turns and stretches to keep its elbow where it was, below the screen.
func _reach_left(amount: float) -> void:
	if arm_l == null or not arm_l.has_meta("hand") or arm_l.get_child_count() < 2:
		return
	var home: Vector3 = arm_l.get_meta("hand")
	var hand := home.lerp(FLIP_HAND, amount)
	var elbow: Vector3 = (arm_l.get_meta("elbow") as Vector3).lerp(holder.transform.affine_inverse() * FLIP_ELBOW, amount)
	var forearm := arm_l.get_child(0) as Node3D
	forearm.basis = Basis(Quaternion(Vector3.UP, (elbow - hand).normalized())) * Basis.from_scale(Vector3(1, hand.distance_to(elbow), 1))
	forearm.position = hand
	(arm_l.get_child(1) as Node3D).position = hand


## Loading from the back: the tube swings across the body until its rear end is in view, and the
## left hand brings up a fresh rocket and pushes it in until it is gone.
func _reload_rocket(pos: Vector3, rot: Vector3, t: float) -> Array:
	var swing := smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.84, 1.0, t))
	pos += ROCKET_SWING_POS * swing
	rot += ROCKET_SWING_ROT * swing
	# Pushed away mid-swing, or the wide rear end would pass right in front of the eyes.
	var clear := sin(swing * PI)
	pos += Vector3(0.14, -0.08, -0.24) * clear
	var lift := -0.34 * (1.0 - smoothstep(0.24, 0.4, t))
	var along := lerpf(1.02, 0.02, _ease(clampf((t - 0.38) / 0.36, 0.0, 1.0)))
	var at := Vector3(0.0, TUBE_HEIGHT + lift, along)
	_round.position = at
	_round.visible = t > 0.2 and t < 0.76
	if arm_l:
		var hold := smoothstep(0.1, 0.3, t) * (1.0 - smoothstep(0.76, 0.92, t))
		arm_l.position = _left_home + (at + ROCKET_TAIL - LEFT_HAND_REST) * hold
	# Seating the rocket knocks the tube.
	var slap := smoothstep(0.73, 0.76, t) * (1.0 - smoothstep(0.76, 0.86, t))
	pos.x -= slap * 0.022
	rot.y += slap * 0.05
	return [pos, rot]


## Swapping the energy cell: tilt the gun, pull the spent cell, seat a fresh one.
func _reload_pose(pos: Vector3, rot: Vector3) -> Array:
	var t := 1.0 - _reload / _reload_len
	if _round:
		return _reload_rocket(pos, rot, t)
	var tilt := smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(0.84, 1.0, t))
	# Rolled over to show the underside, so the cell can be seen coming out.
	pos += Vector3(-0.05, 0.0, 0.02) * tilt
	rot += Vector3(0.38, 0.14, -0.95) * tilt
	if _cell:
		# Out between 0.2 and 0.4, gone until 0.58, back in by 0.78.
		var out := smoothstep(0.2, 0.4, t) * (1.0 - smoothstep(0.58, 0.78, t))
		_cell.position = _cell_home + Vector3(0.0, -0.28 * out, 0.02 * out)
		_cell.visible = out < 0.95
	if arm_l:
		# The left hand comes back to the cell, drops out of frame, and returns with a new one.
		var to_cell := smoothstep(0.1, 0.22, t) * (1.0 - smoothstep(0.78, 0.92, t))
		var low := smoothstep(0.26, 0.42, t) * (1.0 - smoothstep(0.54, 0.74, t))
		arm_l.position = _left_home + Vector3(0.0, -0.06, 0.2) * to_cell + Vector3(-0.03, -0.3, 0.05) * low
	# Seating the cell knocks the gun.
	var slap := smoothstep(0.76, 0.79, t) * (1.0 - smoothstep(0.79, 0.88, t))
	pos.y += slap * 0.018
	rot.x -= slap * 0.08
	return [pos, rot]


func _animate_throw() -> void:
	var t := _throw
	var key := 0
	while key < THROW_KEYS.size() - 2 and t >= float(THROW_KEYS[key + 1][0]):
		key += 1
	var from: Array = THROW_KEYS[key]
	var to: Array = THROW_KEYS[key + 1]
	var k := smoothstep(float(from[0]), float(to[0]), t)
	var hand: Vector3 = (from[1] as Vector3).lerp(to[1], k)
	_throw_rig.visible = true
	_throw_hand.position = hand
	_throw_hand.rotation = (from[2] as Vector3).lerp(to[2], k)
	var released := t >= THROW_RELEASE
	_throw_items[_throw_kind].visible = not released
	# The pin comes out while the grenade is held up, and the lever springs off as it leaves.
	var pulled := smoothstep(0.22, 0.32, t)
	_throw_pin.visible = t < 0.42
	_throw_pin.position = Vector3(-0.1, 0.16, 0.02) * pulled + Vector3(0.016, 0.02, -0.03)
	_throw_pin.rotation.z = pulled * 1.4
	var flown := maxf(t - THROW_RELEASE, 0.0) / 0.2
	_throw_spoon.visible = t < THROW_RELEASE + 0.2
	_throw_spoon.position = Vector3(0.016, 0.02, -0.03) + Vector3(0.05, 0.22, 0.1) * flown
	_throw_spoon.rotation.x = flown * 8.0
	var wrist := hand + Vector3(0, -0.03, 0.03)
	_throw_forearm.position = wrist
	_throw_forearm.basis = Basis(Quaternion(Vector3.UP, (ELBOW_L - wrist).normalized())) * Basis.from_scale(Vector3(1, wrist.distance_to(ELBOW_L), 1))


func _sword_pose(pos: Vector3, rot: Vector3, delta: float) -> Array:
	var extra_pos := pos - BLADE_REST_POS
	var p := pos
	var r := rot + BLADE_REST_ROT
	if _block > 0.0:
		r = r.lerp(Vector3(-0.75, 0.2, 0.82), _block)
		p = p.lerp(Vector3(0.22, -0.26, -0.52), _block)
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
					var k := _ease((_swing - float(a[0])) / (float(b[0]) - float(a[0])))
					var from_pos: Vector3 = a[1]
					var from_rot: Vector3 = a[2]
					p = from_pos.lerp(b[1], k) + extra_pos
					r = from_rot.lerp(b[2], k) + rot
					break
	return [p, r]


func _update_trail(delta: float) -> void:
	if _swing >= 0.14 and _swing <= 0.74 and gun:
		var tip := gun.get_node_or_null("Muzzle") as Node3D
		if tip:
			var t := to_local(tip.global_position)
			_trail.push(holder.position.lerp(t, 0.5), t)
	_trail.tick(delta)
