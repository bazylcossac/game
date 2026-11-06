class_name TankModel
extends MachineModel
## Hover tank, modelled in Blender, used both for a driven tank, through Soldier, and for a parked
## one placed directly in the world. Hull, turret and the crew's roof station all turn separately.
## The station stands on the turret's own axis, so the gunner keeps a steady view when it swings.

const HOVER := 0.62
const IDLE_POWER := 0.6
const RECOIL := 0.5
const ROOF_RECOIL := 0.07
const SIGHT_OFFSET := Vector3(0.0, 2.6, 1.0)
## How fast an unmanned station drifts back over the main gun.
const ROOF_RETURN := 2.2
## How fast the turret swings back onto the aim after the main gun has been locked, in rad/s.
const TURRET_CATCH_UP := 6.0

var hull: Node3D
var turret: Node3D
var gun: Node3D
var muzzle: Node3D
var hull_yaw := 0.0
var _barrel: Node3D
var _recoil := 0.0
var _bob := 0.0
var _wrecked := false
var _glow_light: OmniLight3D
var _plumes: Array[MeshInstance3D] = []
var _last_pos := Vector3.ZERO
var _last_yaw := 0.0
var _last_speed := 0.0
var _thrust := 0.0
var _pitch_tilt := 0.0
var _roll_tilt := 0.0
var _jolt := 0.0
var roof_mount: Node3D
var roof_gun: Node3D
var roof_muzzle: Node3D
var _roof_home := Vector3.ZERO
var _roof_yaw := 0.0
var _roof_pitch := 0.0
var _roof_manned := false
var _roof_recoil := 0.0
## A lone driver on the roof gun: the main gun stays locked and the station takes the aim.
var _on_roof := false
var _catching_up := false
var _driver_yaw := 0.0
var _driver_pitch := 0.0


func setup(new_team: int) -> void:
	team = new_team
	var usa := team == C.Team.RESISTANCE
	var glow_color: Color = C.TEAM_COLORS[team]

	hull = _piece(self, "Hull")
	hull.position.y = HOVER

	_glow_light = OmniLight3D.new()
	_glow_light.light_color = glow_color
	_glow_light.light_energy = 1.4
	_glow_light.omni_range = 6.5
	_glow_light.position.y = -0.3
	hull.add_child(_glow_light)

	turret = _piece(hull, "Turret")
	for marker: String in ["Emblem_R", "Emblem_L"]:
		var emblem := Forge.decal(turret, "icon_usa" if usa else "icon_empire", Vector2(0.52, 0.52), Vector3.ZERO, Vector3.ZERO)
		emblem.transform = TankAssets.placed(marker)
	gun = _piece(turret, "Mantlet")
	_barrel = _piece(gun, "Barrel")
	muzzle = _marker(_barrel, "Muzzle")
	roof_mount = _piece(turret, "Station")
	roof_gun = _piece(roof_mount, "StationGun")
	_roof_home = roof_gun.position
	roof_muzzle = _marker(roof_gun, "StationMuzzle")

	for marker: String in ["Exhaust_R", "Exhaust_L"]:
		_plumes.append(Forge.plume(hull, TankAssets.placed(marker).origin, 0.25, 2.4, glow_color))
	_power = IDLE_POWER
	_refresh_paint()


func _piece(parent: Node3D, part_name: String) -> Node3D:
	var node := Node3D.new()
	node.transform = TankAssets.placed(part_name)
	parent.add_child(node)
	var mi := MeshInstance3D.new()
	mi.mesh = TankAssets.mesh(team, part_name)
	mi.material_override = Forge.skin(team)
	node.add_child(mi)
	_skin.append(mi)
	return node


func _marker(parent: Node3D, marker_name: String) -> Node3D:
	var node := Node3D.new()
	node.transform = TankAssets.placed(marker_name)
	parent.add_child(node)
	return node


## `yaw` is where the gunner looks in the world. The station takes off what the hull and turret
## have already turned, so the driver swinging the main gun does not drag the gunner's aim.
func set_gunner_aim(yaw: float, pitch: float, manned: bool) -> void:
	_roof_manned = manned
	_roof_yaw = yaw
	_roof_pitch = pitch


func gunner_muzzle() -> Vector3:
	return roof_muzzle.global_position


## The commander's view: up on the turret, high enough to see the barrel and the front of the hull.
func sight_position() -> Vector3:
	return turret.global_position + turret.global_basis * SIGHT_OFFSET


func gunner_pivot() -> Vector3:
	return roof_gun.global_position


func play_gunner_fire() -> void:
	_roof_recoil = 1.0


func _aim_roof(delta: float) -> void:
	if _wrecked:
		return
	if _roof_manned or _on_roof:
		var aim_yaw := _driver_yaw if _on_roof else _roof_yaw
		var aim_pitch := _driver_pitch if _on_roof else _roof_pitch
		roof_mount.rotation.y = wrapf(aim_yaw - rotation.y - turret.rotation.y, -PI, PI)
		roof_gun.rotation.x = clampf(aim_pitch, C.TANK_GUNNER_PITCH_MIN, C.TANK_GUNNER_PITCH_MAX)
	else:
		var settle := 1.0 - exp(-delta * ROOF_RETURN)
		roof_mount.rotation.y = lerp_angle(roof_mount.rotation.y, 0.0, settle)
		roof_gun.rotation.x = lerpf(roof_gun.rotation.x, 0.0, settle)
	_roof_recoil = move_toward(_roof_recoil, 0.0, delta * 9.0)
	roof_gun.position = _roof_home + roof_gun.basis * Vector3(0, 0, _roof_recoil * ROOF_RECOIL)


# ---------------------------------------------------------------- behaviour

## Shows a tank standing empty in the world.
func park(pos: Vector3, yaw: float) -> void:
	global_position = pos
	hull_yaw = yaw
	rotation.y = yaw
	turret.rotation.y = 0.0
	gun.rotation.x = 0.0
	_last_pos = pos
	_last_yaw = yaw
	_set_thrust(0.0)


func _process(delta: float) -> void:
	_bob += delta
	if not _wrecked:
		hull.position.y = HOVER + sin(_bob * 1.7) * 0.05 - _jolt * 0.03
		if _thrust < 0.01:
			hull.rotation.z = sin(_bob * 0.9) * 0.008 + _roll_tilt
	_aim_roof(delta)


func set_loadout(new_weapon: int, _class_id: int, parts: Array = []) -> void:
	set_weapon(new_weapon, parts)


func set_weapon(id: int, _parts: Array = []) -> void:
	var roof := id == C.W.TANK_MG
	_catching_up = _on_roof and not roof
	_on_roof = roof


func set_hull(yaw: float) -> void:
	hull_yaw = yaw


func reset_pose() -> void:
	_wrecked = false
	rotation = Vector3.ZERO
	hull.rotation = Vector3.ZERO
	hull.position.y = HOVER
	turret.rotation.y = 0.0
	roof_mount.rotation.y = 0.0
	roof_gun.rotation.x = 0.0
	_glow_light.visible = true
	_end_wreck()
	_set_thrust(0.0)


func play_swing() -> void:
	pass


func play_fire() -> void:
	if _on_roof:
		play_gunner_fire()
		return
	_recoil = 1.0
	_jolt = 1.0


func play_death() -> void:
	_wrecked = true
	_corpse_t = WRECK_TIME
	_glow_light.visible = false
	_set_thrust(0.0)
	_start_wreck()
	hull.rotation = Vector3(0.06, 0, 0.09)
	hull.position.y = 0.1
	turret.rotation.y += 0.5
	gun.rotation.x = -0.14
	roof_mount.rotation.y += 1.1
	roof_gun.rotation.x = C.TANK_GUNNER_PITCH_MIN


func muzzle_position() -> Vector3:
	return roof_muzzle.global_position if _on_roof else muzzle.global_position


func _set_thrust(level: float) -> void:
	_thrust = level
	_power = 0.0 if _wrecked else lerpf(IDLE_POWER, 1.25, level)
	_refresh_paint()
	_glow_light.light_energy = 0.9 + level * 1.1
	for p in _plumes:
		p.visible = level > 0.02
		if p.visible:
			p.set_instance_shader_parameter("thrust", level)


## The turret follows the aim exactly, except that it swings across after being unlocked.
func _aim_main_gun(delta: float, yaw: float, pitch: float) -> void:
	if _catching_up:
		turret.rotation.y = rotate_toward(turret.rotation.y, yaw, delta * TURRET_CATCH_UP)
		gun.rotation.x = move_toward(gun.rotation.x, pitch, delta * TURRET_CATCH_UP)
		_catching_up = absf(angle_difference(turret.rotation.y, yaw)) > 0.01
	else:
		turret.rotation.y = yaw
		gun.rotation.x = pitch


func update_pose(delta: float, pos: Vector3, yaw: float, pitch: float, _speed: float, _crouching: bool, _aiming: bool, _blocking: bool, alive: bool) -> void:
	global_position = pos
	if _wrecked:
		_cool(delta)
		_corpse_t -= delta
		if _corpse_t <= 0.0:
			visible = false
		return
	rotation.y = hull_yaw
	if not alive:
		return
	_recoil = move_toward(_recoil, 0.0, delta * 3.2)
	_jolt = move_toward(_jolt, 0.0, delta * 4.5)
	_driver_yaw = yaw
	_driver_pitch = pitch
	if not _on_roof:
		_aim_main_gun(delta, wrapf(yaw - hull_yaw, -PI, PI), clampf(pitch, -0.2, 0.42))
	_barrel.position.z = _recoil * _recoil * RECOIL

	# Motion is read from the pose, so a remote tank tilts the same way as a local one.
	var step := maxf(delta, 0.001)
	var forward := Basis(Vector3.UP, hull_yaw) * Vector3.FORWARD
	var along := (pos - _last_pos).dot(forward) / step
	var turn := wrapf(hull_yaw - _last_yaw, -PI, PI) / step
	var accel := (along - _last_speed) / step
	_last_pos = pos
	_last_yaw = hull_yaw
	_last_speed = along
	var blend := 1.0 - exp(-delta * 5.0)
	_pitch_tilt = lerpf(_pitch_tilt, clampf(accel * 0.012, -0.075, 0.075), blend)
	_roll_tilt = lerpf(_roll_tilt, clampf(turn * 0.075, -0.1, 0.1), blend)
	hull.rotation.x = _pitch_tilt + _jolt * 0.028
	hull.rotation.z = _roll_tilt
	var want := clampf(absf(along) / C.TANK_SPEED, 0.0, 1.0)
	var thrust := lerpf(_thrust, want, 1.0 - exp(-delta * 4.0))
	if absf(thrust - _thrust) > 0.004 or (want == 0.0 and _thrust > 0.0):
		_set_thrust(thrust if thrust > 0.01 else 0.0)
