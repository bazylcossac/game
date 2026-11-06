class_name Grenade
extends Node3D
## A thrown grenade of any kind. Every machine simulates the flight; only the server sets it off.

const TRAILS := {
	C.NADE_SMOKE: {"amount": 18, "life": 0.7, "tex": "smoke", "size": 0.3, "additive": false},
	C.NADE_FIRE: {"amount": 30, "life": 0.35, "tex": "fire", "size": 0.22, "additive": true},
}

var world: World
var id := 0
var owner_sid := 0
var velocity := Vector3.ZERO
var fuse := C.GRENADE_FUSE
var team := 0
var kind := C.NADE_FRAG
var _light: OmniLight3D
var _bounce_cd := 0.0
var _body: Node3D
var _spin := Vector3.ZERO


func setup(w: World, new_id: int, sid: int, pos: Vector3, vel: Vector3, new_team: int, new_kind := C.NADE_FRAG) -> void:
	world = w
	id = new_id
	owner_sid = sid
	velocity = vel
	team = new_team
	kind = new_kind
	position = pos
	fuse = [C.GRENADE_FUSE, C.SMOKE_FUSE, C.FIRE_FUSE][kind]
	if Net.has_view():
		_body = Node3D.new()
		add_child(_body)
		WeaponFactory.fit(_body, "Nade_%d" % kind, team)
		_spin = Vector3(randf_range(6.0, 11.0), randf_range(-5.0, 5.0), randf_range(-8.0, 8.0))
		_body.scale = Vector3.ONE * 1.35
		add_child(_trail())
		var colors: Array = [C.TEAM_COLORS[team], Color(0.8, 0.82, 0.86), Color(1.0, 0.5, 0.15)]
		_light = OmniLight3D.new()
		_light.light_color = colors[kind]
		_light.omni_range = 3.5
		_light.light_energy = 1.2
		add_child(_light)


func _trail() -> CPUParticles3D:
	var spec: Dictionary = TRAILS.get(kind, {"amount": 26, "life": 0.4, "tex": "soft_dot", "size": 0.16, "additive": true})
	var trail := CPUParticles3D.new()
	trail.amount = spec["amount"]
	trail.lifetime = spec["life"]
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0))
	trail.color_ramp = ramp
	var c: Color = C.TEAM_COLORS[team]
	trail.color = [Color(c.r * 2.4, c.g * 2.4, c.b * 2.4), Color(0.75, 0.76, 0.78, 0.6), Color(3.0, 1.5, 0.5)][kind]
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(spec["size"])
	quad.material = Mats.particle(spec["tex"], spec["additive"])
	trail.mesh = quad
	return trail


func _physics_process(delta: float) -> void:
	fuse -= delta
	_bounce_cd = maxf(_bounce_cd - delta, 0.0)
	if _body:
		_body.rotation += _spin * delta
	if _light:
		_light.light_energy = 2.2 if int(fuse * (10.0 if fuse < 1.0 else 4.0)) % 2 == 0 else 0.3
	if fuse <= 0.0:
		set_physics_process(false)
		if Net.is_server() and world.server:
			world.server.grenade_landed(id, owner_sid, global_position, kind, team)
		return
	velocity.y -= C.GRAVITY * 0.8 * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, C.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	var normal: Vector3 = hit["normal"]
	if kind == C.NADE_FIRE:
		# The casing breaks on contact: it does not bounce away from where it was aimed.
		global_position = hit["position"] + normal * 0.08
		fuse = 0.0
		return
	velocity = velocity.bounce(normal) * (0.42 if kind == C.NADE_FRAG else 0.3)
	_spin *= 0.6
	if world.fx and velocity.length() > 2.0:
		world.fx.sparks(hit["position"], normal, Color(1.0, 0.8, 0.5), 6)
	global_position = hit["position"] + normal * 0.08
	if _bounce_cd <= 0.0 and velocity.length() > 2.0:
		_bounce_cd = 0.12
		Sfx.play_at("grenade_bounce", global_position, -6.0)
