class_name ApcModel
extends TankModel
## The troop carrier: the tank's hover hull and everything that moves it, with no turret or guns.
## The empty nodes stand in for the parts TankModel would aim.


func setup(new_team: int) -> void:
	team = new_team
	var usa := team == C.Team.RESISTANCE
	var glow_color: Color = C.TEAM_COLORS[team]
	hull = _piece(self, "ApcHull")
	hull.position.y = HOVER
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = glow_color
	_glow_light.light_energy = 1.4
	_glow_light.omni_range = 6.0
	_glow_light.position.y = -0.3
	hull.add_child(_glow_light)
	turret = _stub(hull)
	gun = _stub(turret)
	_barrel = _stub(gun)
	muzzle = _stub(_barrel)
	roof_mount = _stub(turret)
	roof_gun = _stub(roof_mount)
	roof_muzzle = _stub(roof_gun)
	for side: Array in [["ApcEmblem_R", PI * 0.5], ["ApcEmblem_L", -PI * 0.5]]:
		var at := TankAssets.placed(side[0]).origin
		Forge.decal(hull, "icon_usa" if usa else "icon_empire", Vector2(0.5, 0.5), at + Vector3(signf(at.x) * 0.03, 0, 0), Vector3(0, side[1], 0))
	for marker: String in ["ApcExhaust_R", "ApcExhaust_L"]:
		_plumes.append(Forge.plume(hull, TankAssets.placed(marker).origin, 0.22, 2.0, glow_color))
	_power = IDLE_POWER
	_refresh_paint()


func _stub(parent: Node3D) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	return node


func play_fire() -> void:
	pass
