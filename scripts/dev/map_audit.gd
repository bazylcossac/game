extends Node
## `--test=map-audit --map=<id> [--mode=<id>]`, headless: measures how a map plays, with rays
## through the real collision. A map that looks fine can still leave a player nowhere to hide.
##   cover     share of walkable ground with something to duck behind within COVER_REACH.
##   exposed   share of walkable ground seen from far away in most directions.
##   sight     lengths of the lines of fire: median, 95th percentile and longest.
##   route     walking distance between the two bases.

const STEP := 3.0
const RAYS := 16
const COVER_REACH := 5.0
const FAR_SIGHT := 35.0
const MAX_SIGHT := 150.0
const EYE := 1.55
const WAIST := 1.0


func _ready() -> void:
	var map_id := Settings.arg("map", "rynek")
	var mode := Settings.arg("mode", "pvp")
	Net.start_dedicated(Modes.normalize({"mode": mode, "map": map_id, "bots_per_team": 0, "seed": 1943}), int(Settings.arg("port", "7795")))
	while Net.world == null:
		await get_tree().process_frame
	for i in 6:
		await get_tree().physics_frame
	var w: World = Net.world
	var space := w.get_world_3d().direct_space_state
	var nav: NavGrid = w.map.b.nav
	var bound: Vector2 = w.map.bound()
	var walkable := 0
	var covered := 0
	var exposed := 0
	var lengths := PackedFloat32Array()
	var x := -bound.x
	while x <= bound.x:
		var z := -bound.y
		while z <= bound.y:
			var p := Vector3(x, 0, z)
			z += STEP
			if not nav.is_free(nav.cell_of(p)):
				continue
			var ground: float = w.map.ground_height(p.x, p.z)
			walkable += 1
			var far := 0
			var near := false
			for i in RAYS:
				var a := TAU * i / RAYS
				var d := Vector3(cos(a), 0, sin(a))
				var sight := _ray(space, p + Vector3(0, ground + EYE, 0), d, MAX_SIGHT)
				lengths.append(sight)
				if sight > FAR_SIGHT:
					far += 1
				if _ray(space, p + Vector3(0, ground + WAIST, 0), d, COVER_REACH) < COVER_REACH:
					near = true
			if near:
				covered += 1
			if far >= RAYS / 2:
				exposed += 1
		x += STEP
	lengths.sort()
	var bases: Array = w.map.bases()
	var route := nav.find_path(bases[0], bases[1])
	var walked := 0.0
	for i in route.size() - 1:
		walked += route[i].distance_to(route[i + 1])
	print("[audit] %-18s walkable=%4d cover=%5.1f%% exposed=%4.1f%% sight p50=%3.0f p95=%3.0f max=%3.0f route=%3.0fm" % [
		map_id, walkable, 100.0 * covered / maxi(walkable, 1), 100.0 * exposed / maxi(walkable, 1),
		lengths[lengths.size() / 2], lengths[int(lengths.size() * 0.95)], lengths[lengths.size() - 1], walked,
	])
	get_tree().quit(0)


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, reach: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, C.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	return from.distance_to(hit["position"]) if hit.has("position") else reach
