class_name WeaponFactory
extends RefCounted
## Builds retro-futurist weapon models. Forward is -Z, the origin sits at the grip.

static func _gun_metal() -> Material: return Mats.gun(Color(0.3, 0.31, 0.33), 0.46, 0.55)
static func _brass() -> Material: return Mats.flat(Color(0.62, 0.47, 0.22), 0.36, 0.9)
static func _steel() -> Material: return Mats.gun(Color(0.42, 0.44, 0.47), 0.34, 0.9)
static func _bakelite() -> Material: return Mats.gun(Color(0.34, 0.19, 0.11), 0.55, 0.0)
static func _dark() -> Material: return Mats.flat(Color(0.06, 0.06, 0.07), 0.7, 0.3)


static func _core(team: int) -> Material:
	return Mats.glow(C.TEAM_COLORS[team], 1.5)


## Beyond this nobody can see a receiver's small details, so they cost nothing at range.
const DETAIL_RANGE := 16.0

static var _third_person := {}
const ASSETS := {C.W.PISTOL: "pistol", C.W.CARBINE: "carbine", C.W.SNIPER: "sniper", C.W.HEAVY: "heavy", C.W.MINIGUN: "minigun", C.W.SMG: "smg", C.W.ASSAULT: "assault", C.W.SCATTER: "scatter", C.W.SILENT: "silent", C.W.REVOLVER: "revolver", C.W.MPISTOL: "mpistol", C.W.SMG2: "smg2", C.W.RIFLE: "rifle", C.W.RAIL: "rail", C.W.AT_ROCKET: "at_launcher"}

## Height of the sight line per weapon, so any optic centres where the aim pose expects.
const SIGHT_Y := {C.W.HEAVY: 0.205, C.W.MINIGUN: 0.205}
const SIGHT_Z := {C.W.HEAVY: -0.12, C.W.MINIGUN: -0.12}
## Where a foregrip bolts on: the height of the underside, and how far along the gun.
const GRIP_AT := {
	C.W.CARBINE: Vector2(0.022, -0.37), C.W.ASSAULT: Vector2(0.024, -0.33), C.W.RIFLE: Vector2(0.02, -0.42),
	C.W.HEAVY: Vector2(0.03, -0.42), C.W.MINIGUN: Vector2(-0.02, -0.3), C.W.SMG: Vector2(0.012, -0.215), C.W.SMG2: Vector2(0.012, -0.225),
	C.W.SCATTER: Vector2(0.008, -0.32), C.W.SNIPER: Vector2(0.02, -0.3), C.W.SILENT: Vector2(0.02, -0.32),
	C.W.RAIL: Vector2(0.024, -0.24),
}


static func build(weapon_id: int, team: int, parts: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon"
	if ASSETS.has(weapon_id):
		# Each side has its own arsenal: the same weapon, built by a different hand.
		var imported := ModelAssets.load_model("res://assets/models/armory/%s%s.glb" % ["e_" if team == C.Team.EMPIRE and weapon_id != C.W.MINIGUN else "", ASSETS[weapon_id]], team)
		for label: String in ["Body", "Cell", "IronSight", "ThirdPersonOnly", "Muzzle", "Spin"]:
			var part := imported.find_child(label + "*", true, false) as Node3D
			if part:
				part.reparent(root, false)
				part.name = label
				if label != "Muzzle":
					ModelAssets.flatten(part)
		imported.free()
		for id: Variant in parts:
			_add_part(root, weapon_id, team, str(id))
		return root
	if C.WEAPONS[weapon_id].get("arm", false):
		_arms(root, weapon_id, team)
		for id: Variant in parts:
			_add_part(root, weapon_id, team, str(id))
		return root
	match weapon_id:
		C.W.PISTOL: _pistol(root, team)
		C.W.CARBINE: _carbine(root, team)
		C.W.SNIPER: _sniper(root, team)
		C.W.HEAVY: _heavy(root, team)
		C.W.SWORD: _sword(root, team)
		C.W.LIGHTSABER: _lightsaber(root, team)
		C.W.TANK_CANNON, C.W.TANK_MG: pass
		C.W.SMG: _smg(root, team)
		C.W.ASSAULT: _assault(root, team)
		C.W.SCATTER: _scatter(root, team)
		C.W.SILENT: _silent(root, team)
		C.W.MECH_GOLEM, C.W.MECH_GOLIAT, C.W.MECH_LAUNCHER: _mech_cannon(root, team)
		C.W.REVOLVER: _revolver(root, team)
		C.W.MPISTOL: _mpistol(root, team)
		C.W.SMG2: _smg2(root, team)
		C.W.RIFLE: _rifle(root, team)
		C.W.RAIL: _rail(root, team)
		C.W.GREATSWORD: _greatsword(root, team)
		C.W.AT_ROCKET:
			P.cyl(root, .075, .075, 1.05, Vector3(0, .09, -.15), _gun_metal(), Vector3(PI * .5, 0, 0), Vector3.ONE, 20)
			P.box(root, Vector3(.055, .16, .09), Vector3(0, -.03, .02), _dark())
			_muzzle(root, Vector3(0, .09, -.72))
	if Gear.WEAPON_SLOTS.has(weapon_id):
		_details(root)
	for id: Variant in parts:
		_add_part(root, weapon_id, team, str(id))
	return root


## The weapon as others see it on a body: every part folded into a few shared instances.
## Only the muzzle stays a node of its own, so a change of weapon in a firefight costs nothing.
static func third_person(weapon_id: int, team: int, parts: Array = []) -> Node3D:
	var key := "%d/%d/%s" % [weapon_id, team, parts]
	if not _third_person.has(key):
		var full := build(weapon_id, team, parts)
		var muzzle := full.get_node_or_null("Muzzle") as Node3D
		_third_person[key] = {"specs": P.folded(full), "muzzle": muzzle.position if muzzle else null}
		full.free()
	var entry: Dictionary = _third_person[key]
	var root := Node3D.new()
	root.name = "Weapon"
	for spec: Dictionary in entry["specs"]:
		P.place(root, spec)
	if entry["muzzle"] != null:
		_muzzle(root, entry["muzzle"])
	return root


static func _fine(mi: MeshInstance3D) -> void:
	mi.visibility_range_end = DETAIL_RANGE
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## What makes a block read as a gun up close: trigger and guard, side plates, an ejection port.
## The receiver is always the first piece a weapon adds.
static func _details(r: Node3D) -> void:
	var n := Node3D.new()
	n.name = "Details"
	r.add_child(n)
	P.box(n, Vector3(0.008, 0.008, 0.078), Vector3(0, -0.044, -0.046), _steel())
	P.box(n, Vector3(0.008, 0.04, 0.008), Vector3(0, -0.024, -0.086), _steel())
	P.box(n, Vector3(0.007, 0.034, 0.01), Vector3(0, -0.018, -0.052), _brass(), Vector3(0.28, 0, 0))
	var body := r.get_child(0) as MeshInstance3D
	var box := body.get_aabb()
	var at := body.position
	var x := box.size.x * 0.5 + 0.0012
	var long := box.size.z
	var tall := box.size.y
	for side: float in [-1.0, 1.0]:
		P.box(n, Vector3(0.0024, tall * 0.56, long * 0.46), at + Vector3(side * x, -tall * 0.1, long * 0.14), _dark())
		P.box(n, Vector3(0.0034, tall * 0.1, long * 0.5), at + Vector3(side * x, tall * 0.3, long * 0.1), _brass())
		for dz: float in [-0.08, 0.32]:
			P.cyl(n, 0.005, 0.005, 0.004, at + Vector3(side * (x + 0.001), -tall * 0.1, long * dz), _steel(), Vector3(0, 0, PI * 0.5), Vector3.ONE, 6)
	# Ejection port on the right, where the shooter's eye falls on it.
	P.box(n, Vector3(0.004, tall * 0.34, long * 0.2), at + Vector3(x + 0.0014, tall * 0.08, -long * 0.2), _steel())
	P.box(n, Vector3(0.0044, tall * 0.2, long * 0.14), at + Vector3(x + 0.0016, tall * 0.08, -long * 0.2), _dark())
	for c in n.get_children():
		_fine(c as MeshInstance3D)


## The stock ring sight. Any fitted optic removes it.
static func _iron(r: Node3D, y: float, z: float, team: int) -> void:
	var n := Node3D.new()
	n.name = "IronSight"
	r.add_child(n)
	P.box(n, Vector3(0.008, y - 0.1, 0.008), Vector3(0, (y + 0.08) * 0.5, z), _steel())
	P.ring(n, 0.024, 0.0022, Vector3(0, y, z), _steel())
	P.box(n, Vector3(0.0016, 0.0016, 0.002), Vector3(0, y, z), _core(team))


## Korpo's liquidator: the weapon in use straight ahead, the other arm beside it. Both come from
## the droid model, so first person shows the same arms everyone else sees.
const ARM_SPLIT := 0.42
const ARM_TIPS := {C.W.ARM_CANNON: Vector3(0.0, 0.0, -0.4), C.W.ARM_ROCKETS: Vector3(0.0, 0.07, -0.33)}


static func _arms(root: Node3D, weapon: int, team: int) -> void:
	var imported := ModelAssets.load_model(SoldierModel.DROID_MODEL, team, true)
	var rockets := weapon == C.W.ARM_ROCKETS
	var place := func(label: String, name: String, at: Vector3) -> void:
		var part := imported.find_child(label, true, false) as Node3D
		part.reparent(root, false)
		part.name = name
		part.transform = Transform3D(Basis.IDENTITY, at)
		ModelAssets.flatten(part)
	var other := Vector3(ARM_SPLIT if rockets else -ARM_SPLIT, -0.02, 0.06)
	place.call("FP_ArmCannon", "Body" if not rockets else "OtherArm", Vector3.ZERO if not rockets else other)
	place.call("FP_ArmPod", "Body" if rockets else "OtherArm", Vector3.ZERO if rockets else other)
	# The warheads are the "cell" of the pod: they drop out and come back on a reload.
	place.call("FP_ArmPod_Cell", "Cell" if rockets else "OtherCell", Vector3.ZERO if rockets else other)
	imported.free()
	_muzzle(root, ARM_TIPS[weapon])


## New parts for the heavy weapons, built here rather than modelled: sleeves, coils and pods.
static func _heavy_part(r: Node3D, weapon: int, team: int, id: String) -> void:
	var lit := _core(team)
	match id:
		"mg_cool", "mg_heavy":
			var n := _part(r, "barrel", Vector3(0, 0.07, -0.42))
			for i in 4:
				var z := -0.04 - i * 0.07
				if id == "mg_cool":
					P.cyl(n, 0.074, 0.074, 0.03, Vector3(0, 0, z), _gun_metal(), Vector3(PI * 0.5, 0, 0), Vector3.ONE, 16)
					P.cyl(n, 0.076, 0.076, 0.006, Vector3(0, 0, z + 0.02), lit, Vector3(PI * 0.5, 0, 0), Vector3.ONE, 16)
				else:
					P.cyl(n, 0.082, 0.082, 0.05, Vector3(0, 0, z), _dark(), Vector3(PI * 0.5, 0, 0), Vector3.ONE, 12)
		"mg_spin", "mg_brace":
			var n := _part(r, "motor", Vector3(0.0, 0.0, -0.08))
			P.box(n, Vector3(0.09, 0.08, 0.12), Vector3(0.07, 0.0, 0.0), _gun_metal())
			P.cyl(n, 0.03, 0.03, 0.1, Vector3(0.07, 0.05, 0.0), _steel() if id == "mg_spin" else _brass(), Vector3(PI * 0.5, 0, 0), Vector3.ONE, 10)
			P.box(n, Vector3(0.012, 0.02, 0.06), Vector3(0.118, 0.0, 0.0), lit)
		"core_cool", "core_focus", "core_cap":
			var n := _part(r, "core", Vector3(0.0, 0.0, -0.1))
			match id:
				"core_cool":
					for i in 3:
						P.box(n, Vector3(0.2, 0.012, 0.03), Vector3(0, 0.085, -i * 0.05), _steel())
				"core_focus":
					P.cyl(n, 0.05, 0.04, 0.08, Vector3(0, 0, -0.32), _steel(), Vector3(PI * 0.5, 0, 0), Vector3.ONE, 14)
					P.cyl(n, 0.03, 0.03, 0.01, Vector3(0, 0, -0.36), lit, Vector3(PI * 0.5, 0, 0), Vector3.ONE, 12)
				"core_cap":
					P.cyl(n, 0.035, 0.035, 0.16, Vector3(-0.08, 0.04, 0.0), _gun_metal(), Vector3(PI * 0.5, 0, 0), Vector3.ONE, 12)
					P.cyl(n, 0.037, 0.037, 0.02, Vector3(-0.08, 0.04, -0.04), lit, Vector3(PI * 0.5, 0, 0), Vector3.ONE, 12)
		"pod_third", "pod_rack":
			var n := _part(r, "pod", Vector3(0.0, 0.0, 0.0))
			if id == "pod_third":
				P.cyl(n, 0.04, 0.04, 0.4, Vector3(0, 0.15, -0.12), _gun_metal(), Vector3(PI * 0.5, 0, 0), Vector3.ONE, 14)
				P.cyl(n, 0.028, 0.0, 0.05, Vector3(0, 0.15, -0.34), Mats.flat(Color(0.7, 0.06, 0.04), 0.45, 0.1), Vector3(-PI * 0.5, 0, 0), Vector3.ONE, 12)
			else:
				P.box(n, Vector3(0.16, 0.12, 0.2), Vector3(0, 0.0, 0.3), _gun_metal())
				P.box(n, Vector3(0.12, 0.014, 0.16), Vector3(0, 0.067, 0.3), lit)
		"load_auto", "load_salvo":
			var n := _part(r, "loader", Vector3(0.0, -0.06, 0.1))
			P.box(n, Vector3(0.1, 0.06, 0.14), Vector3.ZERO, _dark())
			P.cyl(n, 0.02, 0.02, 0.12, Vector3(0.0, -0.03, 0.0), lit if id == "load_salvo" else _steel(), Vector3(PI * 0.5, 0, 0), Vector3.ONE, 10)


static func _add_part(r: Node3D, weapon: int, team: int, id: String) -> void:
	if id.begins_with("mg_") or id.begins_with("core_") or id.begins_with("pod_") or id.begins_with("load_"):
		_heavy_part(r, weapon, team, id)
		return
	match id:
		"reddot", "holo", "scope": _optic(r, weapon, team, id)
		"comp", "suppressor", "stabilizer": _muzzle_device(r, team, id)
		"vgrip", "agrip", "laser": _foregrip(r, weapon, team, id)
		"bigcell", "fastcell", "overcell": _power_cell(r, weapon, id)


## Every fitted part hangs off its own node, so the gunsmith's bench can animate it into place.
static func _part(parent: Node3D, slot: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Part_" + slot
	n.position = pos
	parent.add_child(n)
	return n


## Puts a modelled attachment from attachments.glb on its mount.
static func fit(parent: Node3D, label: String, team: int) -> void:
	var imported := ModelAssets.load_model("res://assets/models/armory/attachments.glb", team)
	var part := imported.find_child(label, true, false) as Node3D
	part.reparent(parent, false)
	part.transform = Transform3D.IDENTITY
	ModelAssets.flatten(part)
	imported.free()


static func _optic(r: Node3D, weapon: int, team: int, id: String) -> void:
	var y: float = SIGHT_Y.get(weapon, 0.145)
	var z: float = SIGHT_Z.get(weapon, -0.05)
	var iron := r.get_node_or_null("IronSight")
	if iron:
		iron.free()
	var n := _part(r, "optic", Vector3(0, y, z))
	fit(n, "Optic_" + id, team)
	match id:
		"reddot":
			P.box(n, Vector3(0.003, 0.003, 0.002), Vector3(0, 0, -0.024), Mats.glow(Color(1.0, 0.2, 0.15), 3.0))
		"holo":
			P.ring(n, 0.012, 0.0012, Vector3(0, 0, -0.02), _core(team))


## Fitted to the end of the barrel. The muzzle point moves forward with it, so shots leave
## from the front of the device.
static func _muzzle_device(r: Node3D, team: int, id: String) -> void:
	var tip := r.get_node_or_null("Muzzle") as Node3D
	if tip == null:
		return
	var at := tip.position
	var n := _part(r, "muzzle", at)
	fit(n, "Muzzle_" + id, team)
	tip.position = at + Vector3(0, 0, {"comp": -0.09, "suppressor": -0.26, "stabilizer": -0.17}[id])


static func _foregrip(r: Node3D, weapon: int, team: int, id: String) -> void:
	var g: Vector2 = GRIP_AT.get(weapon, Vector2(0.0, -0.28))
	var n := _part(r, "grip", Vector3(0, g.x, g.y))
	fit(n, "Grip_" + id, team)
	if id == "laser":
		var lens: Material = Mats.glow(Color(1.0, 0.25, 0.2), 3.0)
		P.cyl(n, 0.0098, 0.0098, 0.002, Vector3(0, -0.026, -0.0665), lens, _along_z(), Vector3.ONE, 10)
		# The dot is for the player's own eye: others see the beam.
		var beam := Node3D.new()
		beam.name = "LaserLine"
		n.add_child(beam)
		P.box(beam, Vector3(0.002, 0.002, 1.6), Vector3(0, -0.026, -0.87), lens)


## Which way the cell hangs out of the gun, read from its largest piece.
static func _cell_mount(r: Node3D, weapon: int) -> Dictionary:
	var cell := r.get_node_or_null("Cell") as Node3D
	if cell == null:
		return {}
	var best: MeshInstance3D
	var volume := 0.0
	for c in cell.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).get_aabb().get_volume() > volume:
			best = c
			volume = best.get_aabb().get_volume()
	if best == null:
		return {}
	var box := best.get_aabb()
	var side := weapon == C.W.HEAVY
	var out: Vector3 = best.basis.y if side else -best.basis.y
	var half := box.size.y * 0.5
	var centre := best.transform * box.get_center()
	var mount := {
		"top": centre - out * half, "bottom": centre + out * half, "out": out,
		"w": box.size.x, "d": box.size.z, "h": box.size.y, "round": best.mesh is CylinderMesh,
		"rot": Vector3(0, 0, -PI * 0.5) if side else best.rotation,
	}
	if not side and best.mesh is ArrayMesh:
		_follow_curve(mount, best)
	return mount


## A curved magazine's box is far deeper than its end: fittings belong on the end itself, tilted
## along the line down the magazine, or they hang in the air beside it.
static func _follow_curve(mount: Dictionary, part: MeshInstance3D) -> void:
	var points: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var box := part.get_aabb()
	var slice := box.size.y * 0.08
	var lo := Vector2(INF, -INF)
	var top_sum := 0.0
	var top_count := 0
	for p in points:
		if p.y < box.position.y + slice:
			lo = Vector2(minf(lo.x, p.z), maxf(lo.y, p.z))
		elif p.y > box.end.y - slice:
			top_sum += p.z
			top_count += 1
	if top_count == 0 or lo.x == INF:
		return
	var bottom := Vector3(box.get_center().x, box.position.y, (lo.x + lo.y) * 0.5)
	var top := Vector3(bottom.x, box.end.y, top_sum / top_count)
	var along := part.transform * top - part.transform * bottom
	mount["top"] = part.transform * top
	mount["bottom"] = part.transform * bottom
	mount["d"] = lo.y - lo.x
	mount["h"] = along.length()
	mount["rot"] = Vector3(atan2(along.z, along.y), 0, 0)


## Resizes the cell from the end that sits in the gun, so it still seats properly.
static func _stretch(cell: Node3D, top: Vector3, out: Vector3, long: float, wide: float) -> void:
	var s := Vector3.ONE * wide + out.abs() * (long - wide)
	cell.scale = s
	cell.position = top - top * s


## A ring around the cell at `y`, following its shape. `grow` is added to the outline.
static func _band(n: Node3D, m: Dictionary, y: float, thick: float, grow: float, mat: Material) -> void:
	var w: float = m["w"]
	if m["round"]:
		var radius := w * 0.5 + grow * 0.5
		P.cyl(n, radius, radius, thick, Vector3(0, y, 0), mat, Vector3.ZERO, Vector3.ONE, 16)
	else:
		var d: float = m["d"]
		P.box(n, Vector3(w + grow, thick, d + grow), Vector3(0, y, 0), mat)


static func _power_cell(r: Node3D, weapon: int, id: String) -> void:
	var m := _cell_mount(r, weapon)
	if m.is_empty():
		return
	var cell := r.get_node("Cell") as Node3D
	var n := _part(cell, "cell", m["bottom"])
	n.rotation = m["rot"]
	var w: float = m["w"]
	var d: float = m["d"]
	var h: float = m["h"]
	match id:
		"bigcell":
			_stretch(cell, m["top"], m["out"], 1.4, 1.1)
			_band(n, m, -0.004, 0.01, 0.01, _brass())
			_band(n, m, -0.03, 0.04, -w * 0.14, _gun_metal())
			_band(n, m, h * 0.34, 0.012, 0.006, _brass())
			P.box(n, Vector3(w * 0.9, 0.03, d * 0.4), Vector3(0, -0.03, 0), Mats.glow(Color(0.35, 0.8, 1.0), 2.2))
			_band(n, m, -0.052, 0.008, 0.012, _brass())
		"fastcell":
			_stretch(cell, m["top"], m["out"], 0.76, 0.94)
			_band(n, m, 0.0, 0.012, 0.012, _steel())
			var tab: Material = Mats.flat(Color(0.86, 0.42, 0.1), 0.5, 0.1)
			P.box(n, Vector3(minf(w * 0.5, 0.03), 0.042, 0.012), Vector3(0, -0.026, 0), tab)
			P.ring(n, 0.015, 0.0028, Vector3(0, -0.058, 0), _brass())
			for i in 2:
				_band(n, m, 0.016 + i * 0.016, 0.005, 0.008, _dark())
		"overcell":
			var hot: Material = Mats.glow(Color(1.0, 0.42, 0.12), 2.6)
			for i in 4:
				_band(n, m, 0.012 + i * h * 0.21, 0.008, 0.01, hot)
			_band(n, m, -0.004, 0.014, 0.014, _dark())
			for sx: float in [-1.0, 1.0]:
				P.box(n, Vector3(0.008, h * 0.86, 0.008), Vector3(sx * (w * 0.5 + 0.007), h * 0.42, 0), _steel())
			for i in 3:
				_band(n, m, -0.016 - i * 0.009, 0.006, -w * 0.1, _steel() if i % 2 == 0 else hot)


## Where a slot's part sits on a built weapon, in the weapon's own space.
static func anchor(r: Node3D, weapon: int, slot: String) -> Vector3:
	match slot:
		"optic":
			return Vector3(0, SIGHT_Y.get(weapon, 0.145), SIGHT_Z.get(weapon, -0.05))
		"muzzle":
			var tip := r.get_node_or_null("Muzzle") as Node3D
			return tip.position if tip else Vector3.ZERO
		"grip":
			var g: Vector2 = GRIP_AT.get(weapon, Vector2(0.0, -0.28))
			return Vector3(0, g.x - 0.04, g.y)
		"cell":
			if C.WEAPONS[weapon].get("arm", false):
				return Vector3(0.0, -0.07, 0.1)
			var m := _cell_mount(r, weapon)
			if not m.is_empty():
				return (r.get_node("Cell") as Node3D).transform * (m["bottom"] as Vector3)
		"barrel":
			return Vector3(0, 0.07, -0.5)
		"motor":
			return Vector3(0.07, 0.0, -0.08)
		"core":
			return Vector3(0.0, 0.08, -0.1)
		"pod":
			return Vector3(0.0, 0.12, -0.1)
		"loader":
			return Vector3(0.0, -0.06, 0.1)
	return Vector3.ZERO


## Size of everything in a built weapon, in its own space.
static func bounds(r: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[r, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var e: Array = stack.pop_back()
		var node: Node3D = e[0]
		var xf: Transform3D = e[1]
		if node is MeshInstance3D:
			var box: AABB = xf * (node as MeshInstance3D).get_aabb()
			out = box if first else out.merge(box)
			first = false
		for c in node.get_children():
			if c is Node3D:
				stack.append([c, xf * (c as Node3D).transform])
	return out


## Parts added here slide out of the weapon during a reload.
static func _cell(root: Node3D) -> Node3D:
	var existing := root.get_node_or_null("Cell") as Node3D
	if existing:
		return existing
	var n := Node3D.new()
	n.name = "Cell"
	root.add_child(n)
	return n


static func _muzzle(root: Node3D, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = "Muzzle"
	m.position = pos
	root.add_child(m)


static func _along_z() -> Vector3:
	return Vector3(PI * 0.5, 0, 0)


static func _smg(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.042, 0.07, 0.24), Vector3(0, 0.05, -0.07), _gun_metal())
	P.box(r, Vector3(0.03, 0.012, 0.24), Vector3(0, 0.09, -0.07), _steel())
	P.box(r, Vector3(0.036, 0.12, 0.05), Vector3(0, -0.05, 0.02), _bakelite(), Vector3(-0.3, 0, 0))
	P.cyl(r, 0.024, 0.024, 0.22, Vector3(0, 0.06, -0.3), _steel(), _along_z(), Vector3.ONE, 8)
	for i in 3:
		P.box(r, Vector3(0.01, 0.008, 0.024), Vector3(0, 0.086, -0.24 - i * 0.05), _core(team))
	P.cyl(_cell(r), 0.02, 0.02, 0.17, Vector3(0, -0.07, -0.13), _gun_metal(), Vector3(0.12, 0, 0))
	_iron(r, 0.145, -0.05, team)
	_muzzle(r, Vector3(0, 0.06, -0.42))


static func _assault(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.05, 0.09, 0.38), Vector3(0, 0.05, -0.1), _gun_metal())
	P.box(r, Vector3(0.04, 0.13, 0.05), Vector3(0, -0.05, 0.03), _bakelite(), Vector3(-0.3, 0, 0))
	P.box(_cell(r), Vector3(0.036, 0.2, 0.05), Vector3(0, -0.08, -0.18), _gun_metal(), Vector3(0.25, 0, 0))
	_skeleton_stock(r)
	P.cyl(r, 0.02, 0.028, 0.34, Vector3(0, 0.06, -0.46), _steel(), _along_z(), Vector3.ONE, 8)
	P.box(r, Vector3(0.012, 0.01, 0.2), Vector3(0, 0.098, -0.12), _core(team))
	_iron(r, 0.145, -0.05, team)
	_muzzle(r, Vector3(0, 0.06, -0.64))


static func _scatter(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.07, 0.1, 0.32), Vector3(0, 0.05, -0.1), _gun_metal())
	P.box(r, Vector3(0.04, 0.13, 0.05), Vector3(0, -0.05, 0.03), _bakelite(), Vector3(-0.3, 0, 0))
	_skeleton_stock(r)
	P.cyl(r, 0.1, 0.035, 0.26, Vector3(0, 0.06, -0.38), _steel(), _along_z(), Vector3.ONE, 10)
	P.cyl(r, 0.08, 0.08, 0.02, Vector3(0, 0.06, -0.5), _core(team), _along_z(), Vector3.ONE, 10)
	P.box(_cell(r), Vector3(0.05, 0.08, 0.1), Vector3(0, -0.03, -0.14), _gun_metal())
	_iron(r, 0.145, -0.05, team)
	_muzzle(r, Vector3(0, 0.06, -0.53))


static func _silent(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.04, 0.07, 0.36), Vector3(0, 0.05, -0.1), _gun_metal())
	P.box(r, Vector3(0.036, 0.12, 0.05), Vector3(0, -0.05, 0.03), _bakelite(), Vector3(-0.3, 0, 0))
	_skeleton_stock(r)
	P.cyl(r, 0.036, 0.036, 0.46, Vector3(0, 0.05, -0.5), _gun_metal(), _along_z(), Vector3.ONE, 10)
	P.cyl(r, 0.024, 0.024, 0.2, Vector3(0, 0.12, -0.08), _steel(), _along_z())
	P.box(r, Vector3(0.008, 0.008, 0.2), Vector3(0, 0.09, -0.15), _core(team))
	P.box(_cell(r), Vector3(0.034, 0.09, 0.07), Vector3(0, -0.03, -0.16), _gun_metal())
	_iron(r, 0.145, -0.05, team)
	_muzzle(r, Vector3(0, 0.05, -0.74))


## Seen only from inside the cockpit; the walker carries its own model in third person.
static func _mech_cannon(r: Node3D, team: int) -> void:
	var plate := Mats.flat(Color(0.56, 0.35, 0.23) if team == C.Team.RESISTANCE else Color(0.3, 0.32, 0.33), 0.55, 0.4)
	P.box(r, Vector3(0.24, 0.24, 0.5), Vector3(0, 0, 0.0), plate)
	P.cyl(r, 0.075, 0.095, 0.8, Vector3(0, 0.02, -0.62), _gun_metal(), _along_z(), Vector3.ONE, 12)
	for i in 3:
		P.cyl(r, 0.11, 0.11, 0.03, Vector3(0, 0.02, -0.36 - i * 0.2), _brass(), _along_z(), Vector3.ONE, 12)
	P.box(r, Vector3(0.02, 0.02, 0.5), Vector3(0, 0.12, -0.3), _core(team))
	_muzzle(r, Vector3(0, 0.02, -1.04))


static func _revolver(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.042, 0.05, 0.1), Vector3(0, 0.075, -0.01), _gun_metal())
	P.box(r, Vector3(0.036, 0.13, 0.055), Vector3(0, -0.015, 0.024), _bakelite(), Vector3(-0.3, 0, 0))
	P.cyl(r, 0.04, 0.04, 0.07, Vector3(0, 0.074, -0.08), _steel(), _along_z(), Vector3.ONE, 8)
	for a: float in [0.0, 1.05, 2.1, 3.14, 4.19, 5.24]:
		P.cyl(r, 0.008, 0.008, 0.072, Vector3(cos(a) * 0.028, 0.074 + sin(a) * 0.028, -0.08), _core(team), _along_z(), Vector3.ONE, 6)
	P.cyl(r, 0.016, 0.02, 0.2, Vector3(0, 0.086, -0.21), _gun_metal(), _along_z(), Vector3.ONE, 10)
	P.box(r, Vector3(0.01, 0.012, 0.2), Vector3(0, 0.104, -0.21), _brass())
	P.box(r, Vector3(0.006, 0.016, 0.012), Vector3(0, 0.117, -0.29), _steel())
	P.box(_cell(r), Vector3(0.028, 0.03, 0.04), Vector3(0, -0.09, 0.044), _gun_metal(), Vector3(-0.3, 0, 0))
	_muzzle(r, Vector3(0, 0.086, -0.32))


static func _mpistol(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.04, 0.06, 0.24), Vector3(0, 0.072, -0.08), _gun_metal())
	P.box(r, Vector3(0.034, 0.12, 0.05), Vector3(0, -0.015, 0.02), _bakelite(), Vector3(-0.22, 0, 0))
	P.cyl(r, 0.016, 0.022, 0.1, Vector3(0, 0.08, -0.24), _steel(), _along_z(), Vector3.ONE, 8)
	for i in 3:
		P.box(r, Vector3(0.042, 0.008, 0.016), Vector3(0, 0.098, -0.14 - i * 0.03), _core(team))
	P.box(_cell(r), Vector3(0.028, 0.15, 0.04), Vector3(0, -0.1, 0.03), _gun_metal(), Vector3(-0.22, 0, 0))
	P.box(r, Vector3(0.006, 0.014, 0.01), Vector3(0, 0.11, -0.18), _steel())
	_muzzle(r, Vector3(0, 0.08, -0.3))


static func _smg2(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.05, 0.08, 0.28), Vector3(0, 0.05, -0.08), _gun_metal())
	P.box(r, Vector3(0.03, 0.012, 0.28), Vector3(0, 0.094, -0.08), _steel())
	P.box(r, Vector3(0.038, 0.12, 0.05), Vector3(0, -0.05, 0.03), _bakelite(), Vector3(-0.3, 0, 0))
	_skeleton_stock(r)
	P.box(r, Vector3(0.056, 0.05, 0.2), Vector3(0, 0.05, -0.31), _bakelite())
	for i in 4:
		P.box(r, Vector3(0.058, 0.008, 0.02), Vector3(0, 0.05, -0.24 - i * 0.045), _core(team))
	P.cyl(r, 0.02, 0.026, 0.12, Vector3(0, 0.055, -0.46), _steel(), _along_z(), Vector3.ONE, 8)
	P.box(_cell(r), Vector3(0.034, 0.17, 0.05), Vector3(0, -0.08, -0.13), _gun_metal(), Vector3(0.1, 0, 0))
	_iron(r, 0.145, -0.05, team)
	_muzzle(r, Vector3(0, 0.055, -0.53))


static func _rifle(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.044, 0.07, 0.38), Vector3(0, 0.05, -0.12), _gun_metal())
	P.box(r, Vector3(0.03, 0.012, 0.36), Vector3(0, 0.092, -0.12), _steel())
	P.box(r, Vector3(0.04, 0.13, 0.05), Vector3(0, -0.05, 0.03), _bakelite(), Vector3(-0.3, 0, 0))
	_skeleton_stock(r)
	P.box(r, Vector3(0.05, 0.05, 0.3), Vector3(0, 0.04, -0.42), _bakelite())
	P.cyl(r, 0.018, 0.024, 0.46, Vector3(0, 0.07, -0.6), _steel(), _along_z(), Vector3.ONE, 8)
	P.box(r, Vector3(0.01, 0.01, 0.34), Vector3(0.026, 0.05, -0.34), _core(team))
	P.box(_cell(r), Vector3(0.032, 0.1, 0.07), Vector3(0, -0.03, -0.16), _gun_metal())
	_iron(r, 0.145, -0.05, team)
	_muzzle(r, Vector3(0, 0.07, -0.84))


static func _rail(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.06, 0.09, 0.46), Vector3(0, 0.05, -0.12), _gun_metal())
	P.box(r, Vector3(0.04, 0.12, 0.05), Vector3(0, -0.05, 0.03), _bakelite(), Vector3(-0.3, 0, 0))
	_skeleton_stock(r)
	for y: float in [0.095, 0.025]:
		P.box(r, Vector3(0.05, 0.016, 0.82), Vector3(0, y, -0.74), _steel())
	for i in 9:
		P.box(r, Vector3(0.02, 0.06, 0.012), Vector3(0, 0.06, -0.4 - i * 0.085), _core(team))
	P.box(r, Vector3(0.064, 0.014, 0.1), Vector3(0, 0.06, -1.1), _brass())
	P.cyl(r, 0.03, 0.03, 0.3, Vector3(0, 0.15, -0.08), _gun_metal(), _along_z())
	P.cyl(r, 0.038, 0.032, 0.07, Vector3(0, 0.15, -0.25), _brass(), _along_z())
	P.box(r, Vector3(0.02, 0.05, 0.03), Vector3(0, 0.11, -0.12), _gun_metal())
	P.box(_cell(r), Vector3(0.05, 0.12, 0.1), Vector3(0, -0.05, -0.16), _gun_metal())
	_muzzle(r, Vector3(0, 0.06, -1.16))


## A two-handed blade: long, wide, with a heavy cross-guard.
static func _greatsword(r: Node3D, team: int) -> void:
	fit(r, "Hilt_great", team)
	var length := 1.25
	var blade := Node3D.new()
	blade.name = "Blade"
	blade.position.y = 0.14
	r.add_child(blade)
	P.box(blade, Vector3(0.05, length, 0.012), Vector3(0, length * 0.5, 0), Mats.glow(Color(0.92, 0.96, 1.0), 1.4))
	P.box(blade, Vector3(0.082, length + 0.02, 0.02), Vector3(0, length * 0.5, 0), Mats.glow(C.TEAM_COLORS[team], 1.9))
	_muzzle(r, Vector3(0, 1.38, 0))


## An open frame stock, which stays out of the first-person view.
static func _skeleton_stock(r: Node3D) -> void:
	var stock := Node3D.new()
	stock.name = "ThirdPersonOnly"
	r.add_child(stock)
	P.box(stock, Vector3(0.014, 0.014, 0.24), Vector3(0, 0.07, 0.16), _steel())
	P.box(stock, Vector3(0.014, 0.014, 0.24), Vector3(0, -0.01, 0.16), _steel())
	P.box(stock, Vector3(0.03, 0.13, 0.02), Vector3(0, 0.03, 0.28), _bakelite())


static func _pistol(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.042, 0.06, 0.2), Vector3(0, 0.07, -0.06), _gun_metal())
	P.box(r, Vector3(0.036, 0.13, 0.055), Vector3(0, -0.015, 0.018), _bakelite(), Vector3(-0.28, 0, 0))
	P.cyl(r, 0.018, 0.026, 0.17, Vector3(0, 0.08, -0.24), _gun_metal(), _along_z())
	for i in 3:
		P.cyl(r, 0.03, 0.03, 0.012, Vector3(0, 0.08, -0.18 - i * 0.045), _brass(), _along_z())
	P.cyl(r, 0.012, 0.012, 0.14, Vector3(0, 0.08, -0.25), _core(team), _along_z())
	P.ball(r, 0.016, Vector3(0, 0.104, 0.0), _core(team))
	P.box(r, Vector3(0.008, 0.016, 0.012), Vector3(0, 0.108, -0.14), _steel())
	P.box(_cell(r), Vector3(0.03, 0.05, 0.05), Vector3(0, -0.095, 0.04), _gun_metal(), Vector3(-0.28, 0, 0))
	P.box(_cell(r), Vector3(0.012, 0.022, 0.016), Vector3(0, -0.1, 0.012), _core(team), Vector3(-0.28, 0, 0))
	_muzzle(r, Vector3(0, 0.08, -0.33))


static func _carbine(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.044, 0.078, 0.3), Vector3(0, 0.05, -0.1), _gun_metal())
	P.box(r, Vector3(0.03, 0.012, 0.32), Vector3(0, 0.094, -0.1), _steel())
	P.box(r, Vector3(0.047, 0.01, 0.22), Vector3(0, 0.06, -0.12), _brass())
	P.box(r, Vector3(0.04, 0.13, 0.05), Vector3(0, -0.05, 0.03), _bakelite(), Vector3(-0.3, 0, 0))
	_skeleton_stock(r)
	P.cyl(r, 0.03, 0.03, 0.36, Vector3(0, 0.06, -0.44), _steel(), _along_z(), Vector3.ONE, 8)
	for i in 5:
		P.box(r, Vector3(0.012, 0.008, 0.03), Vector3(0, 0.092, -0.33 - i * 0.055), _core(team))
		P.cyl(r, 0.036, 0.036, 0.01, Vector3(0, 0.06, -0.3 - i * 0.055), _brass(), _along_z())
	P.cyl(r, 0.018, 0.03, 0.05, Vector3(0, 0.06, -0.64), _brass(), _along_z())
	# Energy cell in place of a magazine.
	P.cyl(_cell(r), 0.034, 0.034, 0.15, Vector3(0, -0.06, -0.15), _gun_metal(), Vector3(0.28, 0, 0))
	P.cyl(_cell(r), 0.012, 0.012, 0.1, Vector3(0, -0.08, -0.17), _core(team), Vector3(0.28, 0, 0))
	# Ring sight on a slim post: the shooter looks through the circle, not over a block.
	_iron(r, 0.145, -0.05, team)
	_muzzle(r, Vector3(0, 0.06, -0.68))


static func _sniper(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.05, 0.09, 0.42), Vector3(0, 0.05, -0.12), _gun_metal())
	P.box(r, Vector3(0.04, 0.12, 0.05), Vector3(0, -0.05, 0.03), _bakelite(), Vector3(-0.3, 0, 0))
	_skeleton_stock(r)
	P.cyl(r, 0.022, 0.03, 0.72, Vector3(0, 0.06, -0.68), _steel(), _along_z())
	for i in 7:
		P.cyl(r, 0.034, 0.034, 0.012, Vector3(0, 0.06, -0.42 - i * 0.075), _core(team) if i % 2 == 0 else _brass(), _along_z())
	P.cyl(r, 0.038, 0.03, 0.09, Vector3(0, 0.06, -1.06), _brass(), _along_z())
	P.cyl(r, 0.03, 0.03, 0.3, Vector3(0, 0.15, -0.08), _gun_metal(), _along_z())
	P.cyl(r, 0.038, 0.032, 0.07, Vector3(0, 0.15, -0.25), _brass(), _along_z())
	P.cyl(r, 0.036, 0.03, 0.05, Vector3(0, 0.15, 0.09), _brass(), _along_z())
	P.box(r, Vector3(0.02, 0.05, 0.03), Vector3(0, 0.11, -0.12), _gun_metal())
	P.box(_cell(r), Vector3(0.036, 0.1, 0.09), Vector3(0, -0.04, -0.16), _gun_metal())
	P.box(_cell(r), Vector3(0.014, 0.05, 0.03), Vector3(0.016, -0.05, -0.16), _core(team))
	_muzzle(r, Vector3(0, 0.06, -1.12))


static func _heavy(r: Node3D, team: int) -> void:
	P.box(r, Vector3(0.1, 0.14, 0.5), Vector3(0, 0.05, -0.14), _gun_metal())
	P.box(r, Vector3(0.05, 0.14, 0.055), Vector3(0, -0.07, 0.04), _bakelite(), Vector3(-0.3, 0, 0))
	for a: float in [0.0, 2.094, 4.188]:
		var off := Vector3(cos(a) * 0.04, 0.06 + sin(a) * 0.04, -0.62)
		P.cyl(r, 0.018, 0.022, 0.5, off, _steel(), _along_z(), Vector3.ONE, 8)
	for i in 3:
		P.cyl(r, 0.078, 0.078, 0.022, Vector3(0, 0.06, -0.44 - i * 0.14), _brass(), _along_z())
	# Large plasma drum.
	P.cyl(_cell(r), 0.11, 0.11, 0.09, Vector3(-0.1, 0.0, -0.16), _gun_metal(), Vector3(0, 0, PI * 0.5))
	P.cyl(_cell(r), 0.085, 0.085, 0.095, Vector3(-0.1, 0.0, -0.16), _core(team), Vector3(0, 0, PI * 0.5))
	P.box(r, Vector3(0.03, 0.05, 0.3), Vector3(0, 0.14, -0.3), _gun_metal())
	P.box(r, Vector3(0.045, 0.1, 0.16), Vector3(0, -0.03, -0.42), _bakelite())
	_iron(r, 0.205, -0.12, team)
	_muzzle(r, Vector3(0, 0.06, -0.9))


## A straight beam of light from a machined hilt, in the team's colour.
static func _lightsaber(r: Node3D, team: int) -> void:
	fit(r, "Hilt_saber", team)
	P.box(r, Vector3(0.002, 0.012, 0.008), Vector3(0.0262, 0.059, 0), _core(team))
	var length := 1.02
	var blade := Node3D.new()
	blade.name = "Blade"
	blade.position.y = 0.135
	r.add_child(blade)
	P.cyl(blade, 0.016, 0.018, length, Vector3(0, length * 0.5, 0), Mats.glow(Color(0.95, 0.97, 1.0), 2.2), Vector3.ZERO, Vector3.ONE, 10)
	P.ball(blade, 0.016, Vector3(0, length, 0), Mats.glow(Color(0.95, 0.97, 1.0), 2.2))
	var halo := P.cyl(blade, 0.03, 0.033, length + 0.03, Vector3(0, length * 0.5, 0), Mats.glow(C.TEAM_COLORS[team], 3.2), Vector3.ZERO, Vector3.ONE, 10)
	halo.transparency = 0.42
	_muzzle(r, Vector3(0, 1.1, 0))


## A cavalry sabre with a charged edge. The hilt is at the origin, the blade runs up +Y.
static func _sword(r: Node3D, team: int) -> void:
	fit(r, "Hilt_sword", team)
	var blade_mat := Mats.glow(C.TEAM_COLORS[team], 1.7)
	var core_mat := Mats.glow(Color(0.92, 0.96, 1.0), 1.3)
	var segs := 6
	var length := 0.14
	var pos := Vector3(0, 0.1, 0)
	var curve := 0.0
	for i in segs:
		var mid := pos + Vector3(0, cos(curve), sin(curve)) * length * 0.5
		var t := 1.0 - float(i) / segs
		var w := 0.024 * (0.55 + t * 0.45)
		P.box(r, Vector3(0.01, length * 1.03, w), mid, core_mat, Vector3(curve, 0, 0))
		P.box(r, Vector3(0.016, length * 1.03, w + 0.01), mid + Vector3(0, 0, 0.002), blade_mat, Vector3(curve, 0, 0))
		pos += Vector3(0, cos(curve), sin(curve)) * length
		curve += 0.045
	P.box(r, Vector3(0.008, 0.09, 0.02), pos + Vector3(0, 0.03, 0.006), core_mat, Vector3(curve, 0, 0))
	_muzzle(r, pos)
