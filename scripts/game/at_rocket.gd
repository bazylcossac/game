class_name ATRocket
extends Node3D
## A swept projectile. All peers draw its flight; only the server decides impact and damage.
const SPEED := 82.0
const LOB_SPEED := 58.0
const LOB_DROP := 16.0
const LIFE := 8.0
var world: World
var id := 0
var owner_sid := 0
var direction := Vector3.FORWARD
var age := 0.0
## A mech's grenade: slower, and it drops as it flies.
var lobbed := false
var _speed := SPEED

func setup(w: World, new_id: int, owner: int, from: Vector3, dir: Vector3, lob := false) -> void:
	lobbed = lob
	_speed = LOB_SPEED if lob else SPEED
	world = w
	id = new_id
	owner_sid = owner
	position = from
	direction = dir.normalized()
	if not Net.has_view():
		return
	if ResourceLoader.exists("res://assets/models/armory/rocket_round.glb"):
		var model := (load("res://assets/models/armory/rocket_round.glb") as PackedScene).instantiate()
		add_child(model)
	else:
		P.cyl(self, .045, .025, .55, Vector3.ZERO, Mats.flat(Color(.27, .3, .23), .55, .6), Vector3(PI * .5, 0, 0), Vector3.ONE, 12)
	var trail := CPUParticles3D.new()
	trail.amount = 32
	trail.lifetime = .7
	trail.local_coords = false
	trail.gravity = Vector3(0, .15, 0)
	trail.initial_velocity_min = .1
	trail.initial_velocity_max = .6
	trail.scale_amount_min = .25
	trail.scale_amount_max = .65
	var ramp := Gradient.new()
	ramp.set_color(0, Color(.65, .65, .62, .38))
	ramp.set_color(1, Color(.5, .5, .48, 0))
	trail.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(.65, .65)
	quad.material = Mats.particle("smoke", false)
	trail.mesh = quad
	add_child(trail)
	P.ball(self, .035, Vector3(0, 0, .32), Mats.glow(Color(1, .45, .12), 2), Vector3(1, 1, 2.5))

func _ready() -> void:
	look_at(global_position + direction, Vector3.UP if absf(direction.y) < .99 else Vector3.RIGHT)

func _physics_process(delta: float) -> void:
	age += delta
	if lobbed:
		var velocity := direction * _speed + Vector3.DOWN * LOB_DROP * delta
		_speed = velocity.length()
		direction = velocity / _speed
		look_at(global_position + direction, Vector3.UP if absf(direction.y) < .99 else Vector3.RIGHT)
	var motion := direction * _speed * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + motion, C.LAYER_WORLD | C.LAYER_VEHICLE | C.LAYER_FORT)
	var wall := get_world_3d().direct_space_state.intersect_ray(q)
	var distance := motion.length() if wall.is_empty() else global_position.distance_to(wall["position"])
	var hit := world.server._trace_soldiers(global_position, direction, distance, world.soldiers.get(owner_sid), Net.server_time()) if Net.is_server() and world.server and world.soldiers.has(owner_sid) else {}
	if not hit.is_empty():
		global_position += direction * float(hit["dist"])
		set_physics_process(false)
		world.server.rocket_impact(id, owner_sid, global_position, hit["soldier"], -1)
	elif not wall.is_empty() or age > LIFE:
		if not wall.is_empty():
			global_position = wall["position"]
		set_physics_process(false)
		if Net.is_server() and world.server:
			world.server.rocket_impact(id, owner_sid, global_position, null, int(wall["collider"].get_meta("vehicle_id", -1)) if not wall.is_empty() else -1)
	else:
		global_position += motion
