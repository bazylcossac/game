class_name Fx
extends Node3D
## Pooled visual effects: laser bolts, sparks, explosions, scorch marks, fires.

const BOLT_SPEED := 170.0
const MAX_BOLTS := 72
const MAX_SPARKS := 36
const MAX_DUST := 22
const MAX_CHIPS := 22
const MAX_SPRITES := 28
const MAX_FLASHES := 8
const MAX_DECALS := 70
## Dust and chips are only worth simulating this close to the camera.
const NEAR_EFFECTS := 75.0

## How wide the player's own shots are, against 1.9 for what others see of them.
const OWN_BEAM_WIDTH := 0.7

class Bolt:
	var mesh: MeshInstance3D
	var streak: MeshInstance3D
	var glow: MeshInstance3D
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var dist := 0.0
	var t := 0.0
	var length := 8.0
	var radius := 0.03
	var instant := false
	var life := 0.0
	var age := 0.0
	var impact_kind := 0
	var team := 0
	var done := true
	var own := false

class Sprite:
	var mesh: MeshInstance3D
	var life := 0.0
	var age := 0.0
	var size := 1.0

## Count of bolts drawn on this machine. Used by the network test.
var shots_spawned := 0

var _bolts: Array[Bolt] = []
var _bolt_i := 0
var _sparks: Array[CPUParticles3D] = []
var _spark_i := 0
var _dust: Array[CPUParticles3D] = []
var _dust_i := 0
var _chips: Array[CPUParticles3D] = []
var _chip_i := 0
var _sprites: Array[Sprite] = []
var _sprite_i := 0
var _flashes: Array[OmniLight3D] = []
var _flash_t: Array[float] = []
var _flash_i := 0
var _decals: Array[Decal] = []
var _decal_i := 0
var _beam_mat: ShaderMaterial
var _glow_mats: Array[StandardMaterial3D] = []
var _flames: Array[OmniLight3D] = []
var _ring_mat: StandardMaterial3D
var _ring_mesh: TorusMesh
var _chunk_mesh: BoxMesh
var _burst_ramp: Gradient
var _burst_curve: Curve
var _burst_quads := {}
var _smoke_puff: StandardMaterial3D


func _sprite_material(tex: String, color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = Mats.tex(tex)
	m.albedo_color = color
	m.no_depth_test = false
	return m


func _ready() -> void:
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = load("res://shaders/beam.gdshader")
	_build_blast_parts()
	for team in 2:
		var c: Color = C.TEAM_COLORS[team]
		_glow_mats.append(_sprite_material("soft_dot", Color(c.r * 1.5, c.g * 1.5, c.b * 1.5)))
	var dot := QuadMesh.new()
	dot.size = Vector2.ONE
	for i in MAX_BOLTS:
		var b := Bolt.new()
		b.mesh = _beam_mesh(dot)
		b.streak = _beam_mesh(dot)
		b.glow = MeshInstance3D.new()
		b.glow.mesh = dot
		b.glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.glow.visible = false
		b.glow.top_level = true
		add_child(b.glow)
		_bolts.append(b)
	for i in MAX_SPARKS:
		_sparks.append(_add_pool(_make_sparks()))
	for i in MAX_DUST:
		_dust.append(_add_pool(_make_dust()))
	for i in MAX_CHIPS:
		_chips.append(_add_pool(_make_chips()))
	for i in MAX_SPRITES:
		var sp := Sprite.new()
		sp.mesh = MeshInstance3D.new()
		sp.mesh.mesh = dot
		sp.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.mesh.visible = false
		sp.mesh.top_level = true
		add_child(sp.mesh)
		_sprites.append(sp)
	for i in MAX_FLASHES:
		var l := OmniLight3D.new()
		l.light_energy = 0.0
		l.omni_range = 7.0
		l.shadow_enabled = false
		l.top_level = true
		add_child(l)
		_flashes.append(l)
		_flash_t.append(0.0)
	var scorch := Mats.tex("scorch")
	for i in MAX_DECALS:
		var d := Decal.new()
		d.texture_albedo = scorch
		d.size = Vector3(0.5, 0.6, 0.5)
		d.visible = false
		d.top_level = true
		d.cull_mask = 1
		d.upper_fade = 0.1
		d.lower_fade = 0.1
		add_child(d)
		_decals.append(d)
	_warm_shaders()


## What every explosion shares, made once. Each blast only needs its own particle nodes.
func _build_blast_parts() -> void:
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.92
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 40
	_ring_mesh.ring_segments = 5
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_color = Color(2.4, 1.6, 1.0, 0.8)
	_chunk_mesh = BoxMesh.new()
	_chunk_mesh.size = Vector3(0.17, 0.11, 0.15)
	_chunk_mesh.material = Mats.flat(Color(0.2, 0.18, 0.16), 0.9)
	_burst_ramp = Gradient.new()
	_burst_ramp.set_color(0, Color(1, 1, 1, 1))
	_burst_ramp.set_color(1, Color(1, 1, 1, 0))
	_burst_curve = Curve.new()
	_burst_curve.add_point(Vector2(0, 0.45))
	_burst_curve.add_point(Vector2(1, 1))


## A material compiles its shader the first time the renderer is given it. Doing that while
## loading keeps 20 ms each out of the first shot, grenade and explosion of the match.
func _warm_shaders() -> void:
	for m: Material in [_glow_mats[0], _ring_mat, BladeTrail.material(false), BladeTrail.material(true),
			Mats.particle("soft_dot", true, true), Mats.particle("fire", true, true), Mats.particle("smoke", false, true),
			Mats.particle("soft_dot", false, true), Mats.particle("soft_dot", true)]:
		m.get_rid()


func _beam_mesh(quad: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.extra_cull_margin = 4.0
	mi.material_override = _beam_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	mi.top_level = true
	add_child(mi)
	return mi


func _add_pool(p: CPUParticles3D) -> CPUParticles3D:
	add_child(p)
	return p


func _base_particles(amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.top_level = true
	p.direction = Vector3.UP
	return p


## Thin hot streaks that point along their flight.
func _make_sparks() -> CPUParticles3D:
	var p := _base_particles(14, 0.5)
	p.spread = 62.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 12.0
	p.gravity = Vector3(0, -15, 0)
	p.damping_min = 2.0
	p.damping_max = 5.0
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var streak := CylinderMesh.new()
	streak.top_radius = 0.012
	streak.bottom_radius = 0.0
	streak.height = 0.3
	streak.radial_segments = 4
	streak.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	streak.material = m
	p.mesh = streak
	return p


func _make_dust() -> CPUParticles3D:
	var p := _base_particles(7, 0.9)
	p.spread = 48.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, 0.4, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.55))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, 1))
	p.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2(0.75, 0.75)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Mats.tex("smoke")
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	p.color = Color(0.62, 0.56, 0.5)
	return p


## Bits of the wall knocked loose by the hit.
func _make_chips() -> CPUParticles3D:
	var p := _base_particles(8, 0.8)
	p.spread = 55.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -18, 0)
	p.angular_velocity_min = -600.0
	p.angular_velocity_max = 600.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.2
	var box := BoxMesh.new()
	box.size = Vector3(0.045, 0.03, 0.04)
	box.material = Mats.flat(Color(0.34, 0.3, 0.27), 0.9)
	p.mesh = box
	return p


## `own` is the player's own first-person shot: it runs straight into the crosshair, so it
## has to stay thin there or it hides the target and the hit marker.
func _area_emitter(amount: int, life: float, tex: String, size: float, color: Color, additive: bool) -> CPUParticles3D:
	var p := _burst(life, amount, 1.0, size, tex, color, additive)
	p.one_shot = false
	p.explosiveness = 0.0
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	return p


## A wall of smoke: puffs swell for two seconds, hold, then thin out over the last few seconds.
func smoke_cloud(pos: Vector3, seconds: float) -> void:
	if _smoke_puff == null:
		_smoke_puff = StandardMaterial3D.new()
		_smoke_puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_puff.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_smoke_puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_puff.albedo_texture = Mats.tex("smoke")
		_smoke_puff.albedo_color = Color(0.78, 0.79, 0.8, 1.0)
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	for i in 34:
		var puff := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * randf_range(4.6, 7.0)
		puff.mesh = quad
		puff.material_override = _smoke_puff
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := randf() * TAU
		var reach := sqrt(randf()) * C.SMOKE_RADIUS * 0.82
		puff.position = Vector3(cos(angle) * reach, randf_range(0.5, 3.4), sin(angle) * reach)
		puff.scale = Vector3.ONE * 0.2
		puff.transparency = 1.0
		root.add_child(puff)
		var grow := puff.create_tween().set_parallel(true)
		grow.tween_property(puff, "scale", Vector3.ONE, randf_range(1.4, 2.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		grow.tween_property(puff, "transparency", 0.05, 1.0)
		grow.tween_property(puff, "position:y", puff.position.y + 0.5, seconds)
		var fade := puff.create_tween()
		fade.tween_interval(maxf(seconds - randf_range(2.0, 4.0), 0.1))
		fade.tween_property(puff, "transparency", 1.0, 2.2)
	Sfx.play_at("smoke_hiss", pos, 0.0)
	get_tree().create_timer(seconds + 1.0, false).timeout.connect(root.queue_free)


## Burning fuel on the ground, drawn to the size of the area that actually hurts.
func fire_patch(pos: Vector3, seconds: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	flash(pos + Vector3.UP * 0.5, Color(1.0, 0.6, 0.25), 9.0, 12.0, 0.2)
	scorch(pos, Vector3.UP, C.FIRE_RADIUS * 0.9)
	var flames := _area_emitter(96, 0.9, "fire", 1.7, Color(3.4, 1.7, 0.6), true)
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flames.emission_box_extents = Vector3(C.FIRE_RADIUS * 0.8, 0.1, C.FIRE_RADIUS * 0.8)
	flames.gravity = Vector3(0, 3.2, 0)
	flames.spread = 12.0
	flames.initial_velocity_min = 0.6
	flames.initial_velocity_max = 2.4
	root.add_child(flames)
	var smoke := _area_emitter(16, 2.4, "smoke", 2.6, Color(0.1, 0.09, 0.08, 0.55), false)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(C.FIRE_RADIUS * 0.7, 0.2, C.FIRE_RADIUS * 0.7)
	smoke.position.y = 1.2
	smoke.gravity = Vector3(0, 1.4, 0)
	root.add_child(smoke)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.2)
	glow.light_energy = 2.6
	glow.omni_range = C.FIRE_RADIUS * 2.4
	glow.position.y = 1.0
	root.add_child(glow)
	var flicker := glow.create_tween().set_loops(int(ceil(seconds / 0.22)))
	flicker.tween_property(glow, "light_energy", 1.6, 0.11)
	flicker.tween_property(glow, "light_energy", 2.8, 0.11)
	Sfx.play_at("fire_ignite", pos, 3.0)
	for i in int(seconds / 2.0):
		get_tree().create_timer(i * 2.0, false).timeout.connect(func() -> void: Sfx.play_at("fire_burn", pos, -1.0))
	get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		if is_instance_valid(root):
			flames.emitting = false
			smoke.emitting = false
			glow.visible = false)
	get_tree().create_timer(seconds + 2.6, false).timeout.connect(root.queue_free)


## A ring on the ground where a barrage will land, pulsing until the last shell.
func strike_marker(pos: Vector3, seconds: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	var radius := C.STRIKE_SCATTER + C.SHELL_RADIUS * 0.5
	torus.inner_radius = radius - 0.18
	torus.outer_radius = radius + 0.18
	torus.rings = 48
	ring.mesh = torus
	ring.material_override = Mats.glow(Color(1.0, 0.16, 0.08), 3.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = pos + Vector3.UP * 0.4
	add_child(ring)
	var pulse := ring.create_tween().set_loops(int(ceil(seconds / 0.8)))
	pulse.tween_property(ring, "scale", Vector3(1.04, 1.0, 1.04), 0.4)
	pulse.tween_property(ring, "scale", Vector3(0.97, 1.0, 0.97), 0.4)
	get_tree().create_timer(seconds).timeout.connect(ring.queue_free)


func spawn_shot(weapon_id: int, team: int, from: Vector3, to: Vector3, kind: int, muzzle_flash := true, own := false) -> void:
	var w: Dictionary = C.WEAPONS[weapon_id]
	var b := _bolts[_bolt_i]
	_bolt_i = (_bolt_i + 1) % MAX_BOLTS
	shots_spawned += 1
	b.from = from
	b.to = to
	b.dist = from.distance_to(to)
	b.t = 0.0
	b.age = 0.0
	b.team = team
	b.impact_kind = kind
	b.radius = float(w["beam"]) * (OWN_BEAM_WIDTH * .65 if own else .95)
	b.own = own
	b.instant = weapon_id == C.W.SNIPER
	b.life = 0.09 if b.instant else 0.12
	b.length = minf(b.dist, 3.8 if weapon_id in [C.W.TANK_CANNON, C.W.MECH_GOLEM, C.W.MECH_GOLIAT, C.W.HEAVY, C.W.MINIGUN, C.W.ARM_CANNON] else 1.8)
	b.done = false
	b.mesh.visible = true
	var col: Color = C.TEAM_BEAM[team]
	var tint := Vector3(col.r, col.g, col.b)
	b.mesh.set_instance_shader_parameter("beam_color", tint)
	b.mesh.set_instance_shader_parameter("fade", 1.0)
	b.streak.set_instance_shader_parameter("beam_color", tint)
	b.streak.set_instance_shader_parameter("fade", 0.3)
	b.glow.material_override = _glow_mats[team]
	var c: Color = C.TEAM_COLORS[team]
	flash(from, c, 0.8, 4.5, 0.05)
	if muzzle_flash:
		sprite("flare", from, Color(1.5, 1.15, .72), .16 + b.radius * 2.0, 0.035)
	if own:
		b.streak.visible = false
	else:
		b.streak.visible = false
	if b.instant:
		_place(b.mesh, from, to, b.radius, not own)
		_impact(b)
		b.impact_kind = -1


func _process(delta: float) -> void:
	for b in _bolts:
		if b.done:
			continue
		b.age += delta
		# A faint line from muzzle to impact, which is what the shooter reads best.
		var streak_fade := 1.0 - b.age / b.life
		if streak_fade > 0.0 and not b.own:
			b.streak.set_instance_shader_parameter("fade", streak_fade * 0.85)
		else:
			b.streak.visible = false
		if b.instant:
			var k := 1.0 - b.age / b.life
			b.mesh.set_instance_shader_parameter("fade", maxf(k, 0.0))
			if k <= 0.0:
				b.done = true
				b.mesh.visible = false
				b.streak.visible = false
			continue
		b.t += delta * BOLT_SPEED
		var head := minf(b.t, b.dist)
		var tail := maxf(b.t - b.length, 0.0)
		if tail >= b.dist:
			b.done = true
			b.mesh.visible = false
			b.glow.visible = false
			b.streak.visible = false
			continue
		var dir := (b.to - b.from) / maxf(b.dist, 0.001)
		var head_pos := b.from + dir * head
		_place(b.mesh, b.from + dir * tail, head_pos, b.radius, not b.own)
		# The bright head stays readable from straight behind, where the beam has no width.
		# Seen from behind, the player's own head is a ball of light right on the crosshair.
		b.glow.visible = b.t < b.dist and not b.own
		var size := .035 + b.radius * 1.7
		b.glow.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * size * minf(_distance_scale(head_pos), 1.8)), head_pos)
		if head >= b.dist and b.impact_kind >= 0:
			_impact(b)
			b.impact_kind = -1
	for sp in _sprites:
		if sp.age >= sp.life:
			continue
		sp.age += delta
		var k := clampf(sp.age / sp.life, 0.0, 1.0)
		if k >= 1.0:
			sp.mesh.visible = false
		else:
			var grow := sp.size * lerpf(0.75, 1.3, k) * (1.0 - k * k)
			sp.mesh.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * maxf(grow, 0.001)), sp.mesh.global_position)
	for i in _flashes.size():
		if _flash_t[i] > 0.0:
			_flash_t[i] -= delta
			if _flash_t[i] <= 0.0:
				_flashes[i].light_energy = 0.0
				_flashes[i].visible = false


## Grows with distance, so far-off shots do not shrink below a pixel.
func _distance_scale(pos: Vector3) -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 1.0
	return clampf(cam.global_position.distance_to(pos) / 22.0, 1.0, 3.5)


func _place(mesh: MeshInstance3D, from: Vector3, to: Vector3, radius: float, widen := true) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		mesh.visible = false
		return
	mesh.visible = true
	var dir := (to - from) / length
	var mid := (from + to) * 0.5
	var r := radius * (_distance_scale(mid) if widen else 1.0)
	var basis := Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(r, length, r))
	mesh.global_transform = Transform3D(basis, mid)


## A billboard that flares and fades on its own.
func sprite(tex: String, pos: Vector3, color: Color, size: float, life: float) -> void:
	var sp := _sprites[_sprite_i]
	_sprite_i = (_sprite_i + 1) % MAX_SPRITES
	sp.mesh.material_override = _sprite_cache(tex, color)
	sp.mesh.visible = true
	sp.mesh.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * size), pos)
	sp.size = size
	sp.life = life
	sp.age = 0.0


var _sprite_mats := {}


func _sprite_cache(tex: String, color: Color) -> Material:
	var key := tex + color.to_html()
	if not _sprite_mats.has(key):
		_sprite_mats[key] = _sprite_material(tex, color)
	return _sprite_mats[key]


## The surface normal where a shot landed, falling back to facing the shooter.
func _surface_normal(b: Bolt) -> Vector3:
	var dir := (b.to - b.from).normalized()
	var q := PhysicsRayQueryParameters3D.create(b.to - dir * 0.4, b.to + dir * 0.4, C.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return -dir if hit.is_empty() else hit["normal"]


func _impact(b: Bolt) -> void:
	var c: Color = C.TEAM_COLORS[b.team]
	var hot := Color(c.r * 2.6, c.g * 2.6, c.b * 2.6)
	var near := _is_near(b.to)
	match b.impact_kind:
		1:
			var normal := _surface_normal(b)
			# Sparks fly out mostly along the reflected shot, which sells the angle of the hit.
			var bounce := (b.to - b.from).normalized().bounce(normal)
			sparks(b.to + normal * 0.03, (normal + bounce).normalized(), Color(1.0, 0.82, 0.55).lerp(c, 0.4), 14)
			sprite("soft_dot", b.to + normal * 0.08, hot, 0.9, 0.12)
			flash(b.to + normal * 0.2, c, 1.7, 4.5, 0.08)
			scorch(b.to, normal, 0.36)
			if near:
				_emit(_chips, b.to, normal, -1)
				_emit(_dust, b.to + normal * 0.05, normal, 0)
			Sfx.play_at("impact_wall", b.to, -8.0, randf_range(0.85, 1.2))
		2:
			var back := (b.from - b.to).normalized()
			sparks(b.to, back, c, 16)
			sprite("flare", b.to, hot, 0.8, 0.1)
			flash(b.to, c, 1.0, 3.0, 0.06)
			Sfx.play_at("impact_body", b.to, -4.0, randf_range(0.9, 1.15))
		3:
			var back := (b.from - b.to).normalized()
			sparks(b.to, back, Color(1, 1, 1), 22)
			sprite("flare", b.to, Color(3.0, 3.0, 3.2), 1.5, 0.14)
			flash(b.to, Color(0.9, 0.95, 1.0), 3.0, 5.0, 0.1)
			Sfx.play_at("deflect", b.to, -2.0, randf_range(0.9, 1.2))


func _is_near(pos: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.global_position.distance_to(pos) < NEAR_EFFECTS


func _emit(pool: Array[CPUParticles3D], pos: Vector3, normal: Vector3, which: int) -> void:
	var p: CPUParticles3D
	if which < 0:
		p = pool[_chip_i]
		_chip_i = (_chip_i + 1) % pool.size()
	else:
		p = pool[_dust_i]
		_dust_i = (_dust_i + 1) % pool.size()
	p.global_position = pos
	p.direction = normal
	p.restart()


func sparks(pos: Vector3, normal: Vector3, color: Color, amount: int) -> void:
	var p := _sparks[_spark_i]
	_spark_i = (_spark_i + 1) % MAX_SPARKS
	p.global_position = pos
	p.direction = normal
	p.color = Color(color.r * 3.2, color.g * 3.2, color.b * 3.2)
	p.amount = maxi(amount, 2)
	p.restart()


func flash(pos: Vector3, color: Color, energy: float, radius: float, duration: float) -> void:
	var i := _flash_i
	_flash_i = (_flash_i + 1) % MAX_FLASHES
	var l := _flashes[i]
	l.visible = true
	l.global_position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	_flash_t[i] = duration


func scorch(pos: Vector3, normal: Vector3, size: float) -> void:
	var d := _decals[_decal_i]
	_decal_i = (_decal_i + 1) % MAX_DECALS
	d.visible = true
	var up := normal.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	d.global_transform = Transform3D(Basis(side, up, side.cross(up)), pos)
	d.size = Vector3(size, 0.5, size)


func explosion(pos: Vector3, big := false) -> void:
	flash(pos + Vector3.UP * 0.5, Color(1.0, 0.72, 0.4), 16.0, 26.0, 0.14)
	scorch(pos, Vector3.UP, 4.2)
	Sfx.play_at("explosion_big" if big else "explosion", pos, 7.0 if big else 6.0, randf_range(0.92, 1.08))
	var root := Node3D.new()
	root.top_level = true
	add_child(root)
	root.global_position = pos
	var fireball := _burst(0.55, 34, 8.0, 3.4, "fire", Color(4.0, 2.0, 0.8), true)
	var smoke := _burst(2.2, 18, 4.5, 5.0, "smoke", Color(0.12, 0.11, 0.1, 0.85), false)
	var debris := _burst(0.9, 22, 13.0, 0.12, "soft_dot", Color(3.0, 1.6, 0.7), true)
	debris.gravity = Vector3(0, -16, 0)
	var dust := _burst(1.3, 16, 9.0, 3.6, "smoke", Color(0.42, 0.37, 0.32, 0.6), false)
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.flatness = 0.92
	dust.gravity = Vector3.ZERO
	var chunks := _burst(1.2, 14, 12.0, 0.1, "soft_dot", Color(1, 1, 1), false)
	chunks.mesh = _chunk_mesh
	chunks.color_ramp = null
	chunks.scale_amount_curve = null
	chunks.gravity = Vector3(0, -19, 0)
	chunks.damping_min = 0.0
	chunks.damping_max = 0.0
	chunks.angular_velocity_min = -500.0
	chunks.angular_velocity_max = 500.0
	root.add_child(fireball)
	root.add_child(smoke)
	root.add_child(debris)
	root.add_child(dust)
	root.add_child(chunks)
	_shockwave(root)
	sprite("flare", pos + Vector3.UP * 0.8, Color(4.0, 2.6, 1.4), 7.0, 0.16)
	get_tree().create_timer(2.6, false).timeout.connect(root.queue_free)


## A ring of hot air that races out along the ground.
func _shockwave(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	mi.material_override = _ring_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.25
	root.add_child(mi)
	var tw := create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(9.0, 1.0, 9.0), 0.36).from(Vector3(0.6, 1.0, 0.6)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mi, "transparency", 1.0, 0.36)


func _burst(life: float, amount: int, speed: float, size: float, tex: String, color: Color, additive: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 95.0
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, 0.6, 0)
	p.damping_min = speed * 0.5
	p.damping_max = speed * 0.9
	p.color = color
	p.color_ramp = _burst_ramp
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _burst_curve
	var key := "%s|%s|%.2f" % [tex, additive, size]
	if not _burst_quads.has(key):
		var quad := QuadMesh.new()
		quad.size = Vector2(size, size)
		quad.material = Mats.particle(tex, additive, true)
		_burst_quads[key] = quad
	p.mesh = _burst_quads[key]
	p.emitting = true
	return p


# ---------------------------------------------------------------- ambient fires and smoke

func add_fire(pos: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	var flame := _emitter(40, 1.1, "fire", Color(4.0, 1.5, 0.35, 1), true, 1.6, Vector3(0.9, 0.2, 0.9), Vector3(0, 3.2, 0))
	root.add_child(flame)
	var smoke := _emitter(26, 6.0, "smoke", Color(0.1, 0.09, 0.09, 0.6), false, 4.5, Vector3(1, 0.2, 1), Vector3(0.7, 3.0, 0.2))
	smoke.position.y = 1.5
	root.add_child(smoke)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 2.4
	light.omni_range = 13.0
	light.position.y = 1.4
	root.add_child(light)
	_flames.append(light)


## Oily smoke and a low fire that stay on a destroyed machine for a while.
func wreck_smoke(pos: Vector3, seconds: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	var smoke := _emitter(16, 3.4, "smoke", Color(0.07, 0.065, 0.065, 0.6), false, 3.2, Vector3(0.7, 0.3, 0.7), Vector3(0.5, 2.6, 0.2))
	var flame := _emitter(14, 0.7, "fire", Color(3.6, 1.4, 0.3, 1), true, 1.1, Vector3(0.6, 0.2, 0.6), Vector3(0, 2.2, 0))
	smoke.preprocess = 0.0
	flame.preprocess = 0.0
	root.add_child(smoke)
	root.add_child(flame)
	get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		smoke.emitting = false
		flame.emitting = false)
	get_tree().create_timer(seconds + 3.6, false).timeout.connect(root.queue_free)


func add_smoke(pos: Vector3) -> void:
	var smoke := _emitter(30, 13.0, "smoke", Color(0.08, 0.075, 0.075, 0.5), false, 9.0, Vector3(1.4, 0.3, 1.4), Vector3(1.1, 3.4, 0.3))
	add_child(smoke)
	smoke.global_position = pos


func _emitter(amount: int, life: float, tex: String, color: Color, additive: bool, size: float, box: Vector3, velocity: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.visibility_aabb = AABB(Vector3(-40, -4, -40), Vector3(80, 90, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = velocity.normalized()
	pm.spread = 12.0
	pm.initial_velocity_min = velocity.length() * 0.7
	pm.initial_velocity_max = velocity.length() * 1.2
	pm.gravity = Vector3.ZERO
	pm.color = color
	var alpha := Gradient.new()
	alpha.set_offset(0, 0.0)
	alpha.set_color(0, Color(1, 1, 1, 0))
	alpha.add_point(0.15, Color(1, 1, 1, 1))
	alpha.set_offset(alpha.get_point_count() - 1, 1.0)
	alpha.set_color(alpha.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = alpha
	pm.color_ramp = ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = Mats.tex(tex)
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func add_ash(follow: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 9, 18)
	pm.direction = Vector3(0.3, -1, 0.15)
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0.1, -0.12, 0.05)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 3.0
	pm.color = Color(0.86, 0.78, 0.7, 0.8)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Mats.tex("soft_dot")
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	follow.add_child(p)
