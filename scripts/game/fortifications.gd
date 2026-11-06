class_name Fortifications
extends Node
## Server-authoritative construction, resource budget, obstacle navigation and turrets.
const DEFS := [
	{"name": "Worki z piaskiem", "size": Vector3(3.4, 1.0, .65), "hp": 300.0, "cost": 25.0},
	{"name": "Zasieki", "size": Vector3(3.4, 1.0, 1.1), "hp": 180.0, "cost": 30.0},
	{"name": "Jeż przeciwczołgowy", "size": Vector3(2.5, 2.0, 2.5), "hp": 600.0, "cost": 45.0},
	{"name": "Wieżyczka laserowa", "size": Vector3(1.3, 2.0, 1.5), "hp": 220.0, "cost": 80.0},
	{"name": "Punkt odrodzenia", "size": Vector3(1.0, 1.9, 1.0), "hp": C.BEACON_HP, "cost": 0.0},
]
## Engineers pick from everything before this. It belongs to the squads, not to the build menu.
const BEACON := 4
const BUILD_SECONDS := 2.4
const MAX_PER_FLAG := 6
var world: World
var items := {}
var pending := {}
var banks := {}
var local_materials := 100.0
var local_progress := 0.0
var _next_id := 1
var _status_t := 0.0
var _bot_t := 0.0
var _turret_t := 0.0
var _ghost: MeshInstance3D
var _ghost_kind := -1
var _preview_good: StandardMaterial3D
var _preview_bad: StandardMaterial3D

func _physics_process(delta: float) -> void:
	if not Net.is_server() or world.server == null or not world.server.can_act():
		return
	for s: Soldier in world.soldiers.values():
		if s.alive and s.class_data().get("builder", false):
			banks[s.sid] = minf(100.0, float(banks.get(s.sid, 100.0)) + delta * 5.0)
	for sid: int in pending.keys():
		var build: Dictionary = pending[sid]
		var s: Soldier = world.soldiers.get(sid)
		if s == null or not valid(s, build["kind"], build["pos"], build["yaw"]).is_empty() or s.last_damage_time > build["started"] or s.fire_cd > 0:
			pending.erase(sid)
			continue
		if Net.server_time() - float(build["started"]) >= BUILD_SECONDS:
			if not _keeps_routes_open(sid, build["pos"], build["kind"], build["yaw"]):
				pending.erase(sid)
				continue
			banks[sid] -= float(DEFS[build["kind"]]["cost"])
			var data := {"id": _next_id, "kind": build["kind"], "team": s.team, "owner": sid, "flag": flag_at(s.team, build["pos"]), "pos": build["pos"], "yaw": build["yaw"], "hp": DEFS[build["kind"]]["hp"]}
			_next_id += 1
			pending.erase(sid)
			Net.broadcast(&"fort", [data])
	_status_t -= delta
	if _status_t <= 0:
		_status_t = .25
		for s: Soldier in world.soldiers.values():
			if s.peer != 0 and s.class_data().get("builder", false):
				var progress := clampf((Net.server_time() - float(pending[s.sid]["started"])) / BUILD_SECONDS, 0, 1) if pending.has(s.sid) else 0.0
				Net.send_to_owner(s, &"build_status", [float(banks.get(s.sid, 100.0)), progress, ""])
	_bot_t -= delta
	if _bot_t <= 0:
		_bot_t = 5.0
		_bot_builds()
	_turret_t -= delta
	if _turret_t <= 0:
		_turret_t = .35
		_fire_turrets()

func candidate(s: Soldier) -> Vector3:
	var p := s.global_position + Basis(Vector3.UP, s.yaw) * Vector3.FORWARD * 4.5
	p.y = world.map.ground_height(p.x, p.z)
	return p

func flag_at(team: int, pos: Vector3) -> int:
	for i in world.flags.size():
		if world.flags[i]["owner"] == team and (world.flags[i]["pos"] as Vector3).distance_to(pos) < C.FLAG_RADIUS * 1.35:
			return i
	return -1

func valid(s: Soldier, kind: int, pos: Vector3, yaw: float) -> String:
	if not s.alive or not s.class_data().get("builder", false):
		return "Budować może tylko żywy Inżynier."
	if Net.is_server() and world.server and not world.server.can_act():
		return "Runda zakończona."
	if kind < 0 or kind >= BEACON or not pos.is_finite() or not is_finite(yaw):
		return "Nieprawidłowa budowla."
	if s.global_position.distance_to(pos) > 7.0:
		return "Podejdź bliżej."
	var half := world.map.bound()
	if absf(pos.x) > half.x - 3 or absf(pos.z) > half.y - 3 or absf(pos.y - world.map.ground_height(pos.x, pos.z)) > .15:
		return "Buduj na ziemi wewnątrz mapy."
	var flag := flag_at(s.team, pos)
	if flag < 0:
		return "Buduj przy fladze swojej drużyny."
	var count := 0
	for data: Dictionary in items.values():
		if data["flag"] == flag:
			count += 1
			if kind == 3 and data["kind"] == 3:
				return "Na fladze może stać jedna wieżyczka."
	if count >= MAX_PER_FLAG:
		return "Limit sześciu fortyfikacji na fladze."
	var materials := float(banks.get(s.sid, 100.0)) if Net.is_server() else local_materials
	if materials < float(DEFS[kind]["cost"]):
		return "Za mało materiałów."
	return site_problem(kind, pos, yaw, s)


## Whether the ground at `pos` can take this structure, whoever is putting it there.
func site_problem(kind: int, pos: Vector3, yaw: float, s: Soldier) -> String:
	var size: Vector3 = DEFS[kind]["size"]
	var basis := Basis(Vector3.UP, yaw)
	for x: float in [-size.x * .5, size.x * .5]:
		for z: float in [-size.z * .5, size.z * .5]:
			var corner := pos + basis * Vector3(x, 0, z)
			if absf(world.map.ground_height(corner.x, corner.z) - pos.y) > .45:
				return "Wybierz równiejszy teren."
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = size
	q.shape = box
	q.transform = Transform3D(basis, pos + Vector3.UP * (size.y * .5 + .06))
	q.collision_mask = C.LAYER_WORLD | C.LAYER_VEHICLE | C.LAYER_FORT
	if not world.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
		return "Miejsce jest zajęte."
	for other: Soldier in world.soldiers.values():
		if other.alive and other.global_position.distance_to(pos) < size.length() * .5 + other.body_radius():
			return "Odsuń budowlę od żołnierzy."
	var ray := PhysicsRayQueryParameters3D.create(s.eye_position(), pos + Vector3.UP * .5, C.LAYER_WORLD)
	if not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return "Nie możesz budować przez ścianę."
	return ""


func place_beacon(s: Soldier, pos: Vector3, squad_id: int) -> int:
	var id := _next_id
	_next_id += 1
	Net.broadcast(&"fort", [{"id": id, "kind": BEACON, "team": s.team, "owner": s.sid, "flag": -1, "squad": squad_id, "pos": pos, "yaw": s.yaw, "hp": DEFS[BEACON]["hp"]}])
	return id


func request(s: Soldier, kind: int, pos: Vector3, yaw: float) -> bool:
	if pending.has(s.sid):
		return false
	var reason := valid(s, kind, pos, yaw)
	if not reason.is_empty():
		Net.send_to_owner(s, &"build_status", [float(banks.get(s.sid, 100)), 0.0, reason])
		return false
	if not _keeps_routes_open(s.sid, pos, kind, yaw):
		Net.send_to_owner(s, &"build_status", [float(banks.get(s.sid, 100)), 0.0, "Zostaw przejście między flagami."])
		return false
	pending[s.sid] = {"kind": kind, "pos": pos, "yaw": yaw, "started": Net.server_time()}
	return true


func _keeps_routes_open(sid: int, pos: Vector3, kind: int, yaw: float) -> bool:
	var size: Vector3 = DEFS[kind]["size"]
	var nav := world.map.b.nav
	nav.add_obstacle(-sid, Transform3D(Basis(Vector3.UP, yaw), pos), Vector2(size.x, size.z) * .5, .45)
	var ok := nav.can_reach(world.map.bases()[0], world.map.bases()[1])
	for f: Dictionary in world.flags:
		ok = ok and nav.can_reach(world.map.bases()[0], f["pos"])
	nav.remove_obstacle(-sid)
	return ok

func receive(data: Dictionary) -> void:
	var id: int = data["id"]
	if items.has(id):
		return
	var item := data.duplicate()
	var def: Dictionary = DEFS[int(data["kind"])]
	var node := Fortification.new()
	node.setup(id, data["kind"], data["team"], def["size"], def["hp"], Net.has_view())
	node.transform = Transform3D(Basis(Vector3.UP, data["yaw"]), data["pos"])
	world.add_child(node)
	item["node"] = node
	items[id] = item
	var size: Vector3 = def["size"]
	for pair: Array in [[world.map.b.nav, .45], [world.map.b.nav_wide, 1.0], [world.map.b.nav_tank, 1.9]]:
		(pair[0] as NavGrid).add_obstacle(id, node.transform, Vector2(size.x, size.z) * .5, pair[1])
	_repath()

func remove(id: int) -> void:
	if not items.has(id):
		return
	var node: Fortification = items[id]["node"]
	node.collision_layer = 0
	node.queue_free()
	items.erase(id)
	for nav: NavGrid in [world.map.b.nav, world.map.b.nav_wide, world.map.b.nav_tank]:
		nav.remove_obstacle(id)
	_repath()

func damage(id: int, amount: float, attacker: Soldier, heavy: bool, explosive := false) -> void:
	if not Net.is_server() or not items.has(id) or amount <= 0:
		return
	var item: Dictionary = items[id]
	if attacker and attacker.team == item["team"]:
		return
	if item["kind"] == 2 and not explosive:
		return
	if item["kind"] < 2 and not (heavy or explosive):
		return
	item["hp"] = maxf(float(item["hp"]) - amount, 0)
	if item["hp"] <= 0:
		if item["kind"] == BEACON:
			world.squads.on_beacon_destroyed(id, attacker)
		Net.broadcast(&"fort_removed", [id])
	else:
		Net.broadcast(&"fort_health", [id, item["hp"]])

func snapshot() -> Array:
	var out: Array = []
	for item: Dictionary in items.values():
		var data := item.duplicate()
		data.erase("node")
		out.append(data)
	return out


func reset() -> void:
	for id: int in items.keys():
		Net.broadcast(&"fort_removed", [id])
	pending.clear()
	banks.clear()

func _repath() -> void:
	if world.server:
		for brain: BotBrain in world.server.bots:
			brain.repath_t = 0

func _bot_builds() -> void:
	for s: Soldier in world.soldiers.values():
		if s.peer != 0 or not s.alive or not s.class_data().get("builder", false) or pending.has(s.sid):
			continue
		for f: Dictionary in world.flags:
			if f["owner"] != s.team or s.global_position.distance_to(f["pos"]) > C.FLAG_RADIUS:
				continue
			var kind := world.server.rng.randi_range(0, BEACON - 1)
			for attempt in 4:
				var angle := world.server.rng.randf() * TAU
				var pos: Vector3 = f["pos"] + Vector3(cos(angle), 0, sin(angle)) * 6
				pos.y = world.map.ground_height(pos.x, pos.z)
				if request(s, kind, pos, angle):
					break

func _fire_turrets() -> void:
	for item: Dictionary in items.values():
		if item["kind"] != 3:
			continue
		var from: Vector3 = item["pos"] + Vector3.UP * 2.15
		var target: Soldier
		var closest := 40.0
		for s: Soldier in world.soldiers.values():
			if not s.alive or s.team == item["team"] or world.shares_driver_armor(s):
				continue
			var distance := s.global_position.distance_to(from)
			if distance > closest:
				continue
			var q := PhysicsRayQueryParameters3D.create(from, s.global_position + Vector3.UP, C.LAYER_WORLD)
			q.exclude = [(item["node"] as Fortification).get_rid()]
			if world.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				target = s
				closest = distance
		if target:
			var owner: Soldier = world.soldiers.get(item["owner"])
			world.server.apply_damage(target, 6.0 * (C.ARMOR_DEFAULT if target.is_vehicle() else 1.0), owner, C.W.TANK_MG, false, from)
			Net.broadcast(&"fort_fire", [item["id"], target.global_position + Vector3.UP])

func update_preview(s: Soldier, kind: int) -> void:
	if kind < 0 or not s.alive or not s.class_data().get("builder", false):
		if _ghost:
			_ghost.visible = false
		return
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(_ghost)
		_preview_good = _preview_material(Color(.15, 1, .45, .3))
		_preview_bad = _preview_material(Color(1, .15, .1, .3))
	var size: Vector3 = DEFS[kind]["size"]
	if kind != _ghost_kind:
		var box := BoxMesh.new()
		box.size = size
		_ghost.mesh = box
		_ghost_kind = kind
	var pos := candidate(s)
	_ghost.material_override = _preview_good if valid(s, kind, pos, s.yaw).is_empty() else _preview_bad
	_ghost.visible = true
	_ghost.global_transform = Transform3D(Basis(Vector3.UP, s.yaw), pos + Vector3.UP * size.y * .5)


func _preview_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
