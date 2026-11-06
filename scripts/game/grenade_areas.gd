class_name GrenadeAreas
extends Node
## What smoke and incendiary grenades leave behind. The server owns where they are and how long
## they last. Clients only draw them. Smoke hides people from bots as well as from players.

var world: World
## Id to {"id", "kind", "pos", "team", "owner", "until"}, on the server.
var items := {}
var _next_id := 1
var _burn_t := 0.0


func start(kind: int, pos: Vector3, owner: Soldier, team: int) -> void:
	var seconds: float = C.SMOKE_SECONDS if kind == C.NADE_SMOKE else C.FIRE_SECONDS
	var hit := world.server.world_ray(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 12.0)
	var ground: Vector3 = pos if hit.is_empty() else hit["position"]
	var id := _next_id
	_next_id += 1
	items[id] = {"id": id, "kind": kind, "pos": ground, "team": team, "owner": owner.sid if owner else 0, "until": Net.server_time() + seconds}
	Net.broadcast(&"area", [kind, ground, seconds])


func tick(delta: float) -> void:
	for id: int in items.keys():
		if Net.server_time() >= float(items[id]["until"]):
			items.erase(id)
	_burn_t -= delta
	if _burn_t <= 0.0:
		_burn_t = C.FIRE_TICK
		for item: Dictionary in items.values():
			if item["kind"] == C.NADE_FIRE:
				_burn(item)


func _burn(item: Dictionary) -> void:
	var pos: Vector3 = item["pos"]
	var owner: Soldier = world.soldiers.get(item["owner"])
	var damage := C.FIRE_DPS * C.FIRE_TICK
	for s: Soldier in world.soldiers.values():
		if not s.alive or world.shares_driver_armor(s) or s == owner:
			continue
		if not (world.are_foes(s, owner) if owner else s.team != int(item["team"])):
			continue
		var to := s.global_position - pos
		if Vector2(to.x, to.z).length() > C.FIRE_RADIUS + s.body_radius() or absf(to.y) > 2.4:
			continue
		var taken := damage * (C.FIRE_VS_ARMOR if s.is_vehicle() else 1.0) * (0.6 if s.has_perk("flak") else 1.0)
		world.server.apply_damage(s, taken, owner, C.WEAPON_FIRE, false, pos)
	for id: int in world.forts.items.keys():
		if pos.distance_to(world.forts.items[id]["pos"]) < C.FIRE_RADIUS:
			world.forts.damage(id, damage, owner, false)


## Whether a cloud stands between two points. Bots ask this before they can see someone.
func blocks_sight(from: Vector3, to: Vector3) -> bool:
	for item: Dictionary in items.values():
		if item["kind"] != C.NADE_SMOKE:
			continue
		var centre: Vector3 = item["pos"] + Vector3.UP * 1.4
		if not Geometry3D.segment_intersects_sphere(from, to, centre, C.SMOKE_RADIUS).is_empty():
			return true
	return false


## What a player joining now has to draw, with the time each area has left.
func snapshot() -> Array:
	var out := []
	for item: Dictionary in items.values():
		out.append([item["kind"], item["pos"], float(item["until"]) - Net.server_time()])
	return out


func reset() -> void:
	items.clear()
