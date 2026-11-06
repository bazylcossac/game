class_name Weather
extends Node3D
## What happens in the sky: lightning and thunder, a fleet fighting far overhead, flares and guns
## on the horizon. Each machine rolls its own, nothing here touches a player, and all of it can be
## switched on per map through MapKit.weather().

const SKY_HEIGHT := 420.0
const SOUND_SPEED := 340.0
const MAX_BEAMS := 28
const FLASH_FADE := 5.5

var _env: Environment
var _sun: DirectionalLight3D
var _base_ambient := 1.0
var _base_sun := 1.0
var _base_fog := 1.0
var _spec := {}
var _flash := 0.0
var _flicker_t := 0.0
var _next_bolt := 4.0
var _bolts: Array[Dictionary] = []
var _bolt_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _rain: GPUParticles3D
var _dust: GPUParticles3D
var _sky: ShaderMaterial

var _ships: Array[Dictionary] = []
var _beams: Array[Dictionary] = []
var _next_salvo := 1.0
var _booms: Array[Dictionary] = []
var _flares: Array[Dictionary] = []
var _next_flare := 6.0
var _next_gun := 2.0


func setup(world: Node, spec: Dictionary) -> void:
	_spec = spec
	_rng.randomize()
	for child in world.get_children():
		if child is WorldEnvironment:
			_env = (child as WorldEnvironment).environment
		elif child is DirectionalLight3D:
			_sun = child
	_base_ambient = _env.ambient_light_energy
	_base_sun = _sun.light_energy
	_base_fog = _env.fog_light_energy
	_bolt_mat = StandardMaterial3D.new()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.albedo_color = Color(2.4, 2.6, 3.4)
	_bolt_mat.disable_fog = true
	_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if spec.get("ships", false):
		_build_fleets()
	if spec.get("rain", false):
		_build_rain()
	if spec.get("dust", false):
		_build_dust()
	if _env.sky and _env.sky.sky_material is ShaderMaterial:
		_sky = _env.sky.sky_material


## Falls round the player, so it is heavy where anyone can see it and costs nothing elsewhere.
func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.amount = 5200
	_rain.lifetime = 1.1
	_rain.preprocess = 1.1
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-60, -46, -60), Vector3(120, 60, 120))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(48, 1, 48)
	process.direction = Vector3(0.3, -1, 0.1)
	process.spread = 3.0
	process.initial_velocity_min = 30.0
	process.initial_velocity_max = 38.0
	process.gravity = Vector3(0, -6, 0)
	_rain.process_material = process
	var drop := BoxMesh.new()
	# Temporal antialiasing on the higher settings wipes out anything this thin and this fast.
	var width := 0.02 if Settings.quality >= 2 else 0.011
	drop.size = Vector3(width, 0.9 if Settings.quality >= 2 else 0.7, width)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.7, 0.75, 0.84, 0.6 if Settings.quality >= 2 else 0.42)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# A drop right by the lens would be a white bar across the screen.
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 1.5
	m.distance_fade_max_distance = 9.0
	drop.material = m
	_rain.draw_pass_1 = drop
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)


## Veils of dust that drift past at knee height.
func _build_dust() -> void:
	_dust = GPUParticles3D.new()
	_dust.amount = 90
	_dust.lifetime = 9.0
	_dust.preprocess = 9.0
	_dust.local_coords = false
	_dust.visibility_aabb = AABB(Vector3(-90, -8, -90), Vector3(180, 24, 180))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(60, 1.5, 60)
	process.direction = Vector3(1, 0.03, 0.4)
	process.spread = 12.0
	process.initial_velocity_min = 2.5
	process.initial_velocity_max = 6.0
	process.gravity = Vector3.ZERO
	process.scale_min = 5.0
	process.scale_max = 12.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	_dust.process_material = process
	var puff := QuadMesh.new()
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	var round_tex := GradientTexture2D.new()
	round_tex.gradient = soft
	round_tex.fill = GradientTexture2D.FILL_RADIAL
	round_tex.fill_from = Vector2(0.5, 0.5)
	round_tex.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = round_tex
	m.albedo_color = Color(0.74, 0.64, 0.48, 0.1)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 2.0
	puff.material = m
	_dust.draw_pass_1 = puff
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust)


func _camera_at() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	return camera.global_position if camera else Vector3.ZERO


func _process(delta: float) -> void:
	if _rain:
		_rain.global_position = _camera_at() + Vector3(-10, 30, -4)
	if _dust:
		_dust.global_position = _camera_at() * Vector3(1, 0, 1) + Vector3(-18, 2.2, -6)
	_tick_lightning(delta)
	_tick_light(delta)
	if not _ships.is_empty():
		_tick_fleets(delta)
	if _spec.get("flares", false):
		_tick_flares(delta)
	if _spec.get("guns", false):
		_tick_guns(delta)


# ---------------------------------------------------------------- lightning

func _tick_lightning(delta: float) -> void:
	var gap: Array = _spec.get("lightning", [])
	if gap.is_empty():
		return
	_next_bolt -= delta
	if _next_bolt <= 0.0:
		_next_bolt = _rng.randf_range(gap[0], gap[1])
		_strike()
	for i in range(_bolts.size() - 1, -1, -1):
		var b: Dictionary = _bolts[i]
		b["t"] -= delta
		var node: MeshInstance3D = b["node"]
		node.visible = fmod(b["t"], 0.09) > 0.03
		if b["t"] <= 0.0:
			node.queue_free()
			_bolts.remove_at(i)


## One bolt somewhere around the player. The light comes at once, the sound when it arrives.
func _strike() -> void:
	var eye := _camera_at()
	var distance := _rng.randf_range(260.0, 1100.0)
	var angle := _rng.randf() * TAU
	var foot := eye + Vector3(cos(angle), 0, sin(angle)) * distance
	foot.y = 0.0
	var node := MeshInstance3D.new()
	node.mesh = _bolt_mesh(foot, eye)
	node.material_override = _bolt_mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_bolts.append({"node": node, "t": _rng.randf_range(0.22, 0.36)})
	_flash = maxf(_flash, clampf(1.25 - distance / 1000.0, 0.3, 1.0))
	_flicker_t = 0.3
	var near := distance < 560.0
	var volume := lerpf(-4.0, -13.0, clampf(distance / 1100.0, 0.0, 1.0))
	get_tree().create_timer(distance / SOUND_SPEED).timeout.connect(func() -> void:
		Sfx.play("thunder_near" if near else "thunder_far", volume, _rng.randf_range(0.9, 1.08)))


## A jagged ribbon from the cloud base to the ground, with a couple of forks, facing the player.
func _bolt_mesh(foot: Vector3, eye: Vector3) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := (foot - eye).cross(Vector3.UP).normalized()
	var spine := _jag(foot + Vector3.UP * SKY_HEIGHT + side * _rng.randf_range(-70, 70), foot, 16, 34.0)
	_ribbon(surface, spine, side, 2.4)
	for i in 3:
		var from: Vector3 = spine[_rng.randi_range(2, spine.size() - 5)]
		var to := from + Vector3(_rng.randf_range(-110, 110), -_rng.randf_range(60, 150), 0) + side * _rng.randf_range(-70, 70)
		_ribbon(surface, _jag(from, to, 7, 18.0), side, 1.1)
	return surface.commit()


func _jag(from: Vector3, to: Vector3, steps: int, wander: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in steps + 1:
		var p := from.lerp(to, float(i) / steps)
		if i > 0 and i < steps:
			p += Vector3(_rng.randf_range(-wander, wander), _rng.randf_range(-6, 6), _rng.randf_range(-wander, wander))
		out.append(p)
	return out


func _ribbon(surface: SurfaceTool, line: PackedVector3Array, side: Vector3, width: float) -> void:
	for i in line.size() - 1:
		var a := line[i]
		var c := line[i + 1]
		var w := side * width * (1.0 - float(i) / line.size() * 0.6)
		surface.add_vertex(a - w)
		surface.add_vertex(a + w)
		surface.add_vertex(c + w)
		surface.add_vertex(a - w)
		surface.add_vertex(c + w)
		surface.add_vertex(c - w)


func _tick_light(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta * FLASH_FADE * 0.4)
	_flicker_t = maxf(_flicker_t - delta, 0.0)
	var level := _flash
	if _flicker_t > 0.0:
		level *= 0.55 + 0.45 * sin(_flicker_t * 90.0)
	_env.ambient_light_energy = _base_ambient + level * float(_spec.get("flash_ambient", 2.2))
	_env.fog_light_energy = _base_fog + level * 2.0
	_sun.light_energy = _base_sun + level * float(_spec.get("flash_sun", 2.4))
	if _sky:
		_sky.set_shader_parameter("flash", level)


# ---------------------------------------------------------------- the battle overhead

func _build_fleets() -> void:
	var skin := {}
	for side in 2:
		for i in 4:
			_add_ship("ship_cruiser", side, i, 6.0 + _rng.randf() * 2.0, skin)
		for i in 7:
			_add_ship("ship_fighter", side, i + 4, 3.0, skin)
	for i in MAX_BEAMS:
		var beam := MeshInstance3D.new()
		beam.mesh = BoxMesh.new()
		beam.visible = false
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
		_beams.append({"node": beam, "t": 0.0, "life": 0.0, "from": Vector3.ZERO, "to": Vector3.ZERO})


## Everything up there stays clear of the fog, or the rain would hide the whole battle.
func _add_ship(prop: String, side: int, index: int, size: float, skin: Dictionary) -> void:
	var node := MeshInstance3D.new()
	var mesh: Mesh = CityProps.mesh_for(prop)
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surface in mesh.get_surface_count():
		var source: Material = mesh.surface_get_material(surface)
		var key := "%d/%d" % [source.get_instance_id(), side]
		if not skin.has(key):
			var copy := source.duplicate() as StandardMaterial3D
			copy.metallic = minf(copy.metallic, 0.3)
			copy.disable_fog = true
			if copy.vertex_color_use_as_albedo:
				copy.vertex_color_use_as_albedo = false
				copy.albedo_color = Color(0.1, 0.12, 0.17) if side == 0 else Color(0.09, 0.07, 0.09)
			skin[key] = copy
		node.set_surface_override_material(surface, skin[key])
	add_child(node)
	var fighter := prop == "ship_fighter"
	var sign_x := -1.0 if side == 0 else 1.0
	_ships.append({
		"node": node, "side": side, "fighter": fighter, "size": size,
		"home": Vector3(sign_x * _rng.randf_range(350, 640), _rng.randf_range(430, 640) if not fighter else _rng.randf_range(300, 520), _rng.randf_range(-800, 800)),
		"phase": _rng.randf() * TAU, "rate": _rng.randf_range(0.12, 0.3) if fighter else _rng.randf_range(0.012, 0.03),
		"wide": _rng.randf_range(220, 520) if fighter else _rng.randf_range(60, 160),
	})
	node.scale = Vector3.ONE * size
	node.rotation.y = PI * 0.5 * (1.0 if side == 0 else -1.0)


func _tick_fleets(delta: float) -> void:
	for ship: Dictionary in _ships:
		ship["phase"] += delta * float(ship["rate"])
		var a: float = ship["phase"]
		var wide: float = ship["wide"]
		var home: Vector3 = ship["home"]
		var node: Node3D = ship["node"]
		var was := node.position
		node.position = home + Vector3(sin(a * 0.7) * wide * 0.7, sin(a * 1.3) * wide * 0.12, cos(a) * wide)
		if ship["fighter"]:
			var ahead := node.position - was
			if ahead.length_squared() > 0.0001:
				node.look_at(node.position + ahead, Vector3.UP)
	_next_salvo -= delta
	if _next_salvo <= 0.0:
		_next_salvo = _rng.randf_range(0.5, 2.4)
		_salvo()
	for b: Dictionary in _beams:
		var node: MeshInstance3D = b["node"]
		if not node.visible:
			continue
		b["t"] += delta / float(b["life"])
		var t: float = b["t"]
		if t >= 1.0:
			node.visible = false
			if b.get("hit", false):
				_boom(b["to"], b["color"])
			continue
		var from: Vector3 = b["from"]
		var to: Vector3 = b["to"]
		var head := from.lerp(to, t)
		var tail := from.lerp(to, maxf(t - 0.16, 0.0))
		node.global_position = (head + tail) * 0.5
		node.look_at(head, Vector3.UP if absf((head - tail).normalized().y) < 0.98 else Vector3.RIGHT)
		node.scale = Vector3(1.6, 1.6, head.distance_to(tail))
	for i in range(_booms.size() - 1, -1, -1):
		var e: Dictionary = _booms[i]
		e["t"] += delta / 0.5
		var mesh: MeshInstance3D = e["node"]
		var t: float = e["t"]
		mesh.scale = Vector3.ONE * (20.0 + t * 46.0)
		(mesh.material_override as StandardMaterial3D).albedo_color.a = 1.0 - t
		if t >= 1.0:
			mesh.queue_free()
			_booms.remove_at(i)


## A few bolts from one ship at a ship of the other side. Most of them miss.
func _salvo() -> void:
	var shooter: Dictionary = _ships[_rng.randi_range(0, _ships.size() - 1)]
	var targets := _ships.filter(func(o: Dictionary) -> bool: return o["side"] != shooter["side"])
	var target: Dictionary = targets[_rng.randi_range(0, targets.size() - 1)]
	var from: Vector3 = (shooter["node"] as Node3D).global_position
	var aim: Vector3 = (target["node"] as Node3D).global_position
	var color: Color = C.TEAM_BEAM[shooter["side"]]
	for i in (2 if shooter["fighter"] else 5):
		for b: Dictionary in _beams:
			var node: MeshInstance3D = b["node"]
			if node.visible:
				continue
			var hit := _rng.randf() < 0.3
			b["from"] = from + Vector3(_rng.randf_range(-12, 12), _rng.randf_range(-6, 6), _rng.randf_range(-12, 12))
			b["to"] = aim if hit else aim + Vector3(_rng.randf_range(-120, 120), _rng.randf_range(-70, 70), _rng.randf_range(-120, 120))
			b["t"] = -float(i) * 0.1
			b["life"] = maxf(from.distance_to(aim) / 1100.0, 0.25)
			b["hit"] = hit
			b["color"] = color
			node.material_override = _beam_mat(shooter["side"])
			node.visible = true
			break


var _beam_mats := {}


func _beam_mat(side: int) -> StandardMaterial3D:
	if not _beam_mats.has(side):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = C.TEAM_BEAM[side]
		m.disable_fog = true
		_beam_mats[side] = m
	return _beam_mats[side]


func _boom(at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	mesh.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = Mats.tex("flare")
	m.albedo_color = Color(color.r * 0.5 + 0.6, color.g * 0.5 + 0.5, color.b * 0.5 + 0.4, 1.0)
	m.disable_fog = true
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	mesh.global_position = at
	_booms.append({"node": mesh, "t": 0.0})
	_flash = maxf(_flash, 0.08)


# ---------------------------------------------------------------- the front line

## Star shells: they climb, hang under a parachute and light the mud as they fall.
func _tick_flares(delta: float) -> void:
	_next_flare -= delta
	if _next_flare <= 0.0:
		_next_flare = _rng.randf_range(7.0, 20.0)
		var eye := _camera_at()
		var at := eye + Vector3(_rng.randf_range(-260, 260), 0, _rng.randf_range(-260, 260))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.92, 0.7)
		light.omni_range = 120.0
		light.light_energy = 0.0
		light.shadow_enabled = true
		add_child(light)
		light.global_position = Vector3(at.x, 110.0, at.z)
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.8
		sphere.height = 1.6
		ball.mesh = sphere
		ball.material_override = Mats.glow(Color(1.0, 0.9, 0.7), 16.0)
		light.add_child(ball)
		_flares.append({"node": light, "t": 0.0, "life": _rng.randf_range(11.0, 16.0)})
	for i in range(_flares.size() - 1, -1, -1):
		var f: Dictionary = _flares[i]
		f["t"] += delta
		var light: OmniLight3D = f["node"]
		var k: float = float(f["t"]) / float(f["life"])
		light.position.y -= delta * 6.0
		light.position.x += sin(float(f["t"]) * 0.4) * delta * 1.5
		light.light_energy = (1.0 - absf(k * 2.0 - 1.0) ** 3.0) * 7.0 * (0.9 + 0.1 * sin(float(f["t"]) * 19.0))
		if k >= 1.0:
			light.queue_free()
			_flares.remove_at(i)


## The far guns: a flicker behind the horizon, and the rumble comes after it.
func _tick_guns(delta: float) -> void:
	_next_gun -= delta
	if _next_gun <= 0.0:
		_next_gun = _rng.randf_range(1.6, 7.0)
		_flash = maxf(_flash, _rng.randf_range(0.06, 0.16))
		var delay := _rng.randf_range(0.8, 3.0)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if _rng.randf() < 0.4:
				Sfx.play("thunder_far", -22.0, _rng.randf_range(1.2, 1.6)))
