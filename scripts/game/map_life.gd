class_name MapLife
extends Node3D
## What keeps a map from feeling like a photograph: trains, drones, cranes, flickering signs
## and steam. Only the view has it, none of it touches a player, and all of it runs on the
## clock alone, so it needs no network traffic.

var _movers: Array[Dictionary] = []
var _lights: Array[Dictionary] = []
var _labels: Array[Dictionary] = []
var _orbits: Array[Dictionary] = []
var _followers: Array[Dictionary] = []
var _clock := 0.0


## Sends a node along a line from `a` to `c` every `period` seconds, taking `travel` of them.
func add_shuttle(node: Node3D, a: Vector3, c: Vector3, period: float, travel: float, sound := "") -> void:
	add_child(node)
	node.visible = false
	_movers.append({"node": node, "a": a, "c": c, "period": period, "travel": travel, "sound": sound, "last": -1})


## Rocks a node between two points, with the slow ease of something heavy.
func add_sway(node: Node3D, a: Vector3, c: Vector3, period: float) -> void:
	add_child(node)
	_orbits.append({"node": node, "a": a, "c": c, "period": period, "mode": "sway"})


## Flies a node round `centre` on a slow figure of eight.
func add_orbit(node: Node3D, centre: Vector3, radius: Vector2, period: float) -> void:
	add_child(node)
	_orbits.append({"node": node, "centre": centre, "radius": radius, "period": period, "mode": "orbit", "phase": _orbits.size() * 1.7})


## Keeps a node over the camera, for weather that only has to fall where someone is looking.
func add_follower(node: Node3D, offset: Vector3) -> void:
	_followers.append({"node": node, "offset": offset})


func add_spin(node: Node3D, speed: float) -> void:
	_orbits.append({"node": node, "speed": speed, "mode": "spin"})


## Light that breathes between `low` and `high` energy.
func add_pulse(light: Light3D, low: float, high: float, period: float) -> void:
	_lights.append({"light": light, "low": low, "high": high, "period": period})


## A sign with a failing tube: steady, then a few fast blinks.
func add_flicker(label: Label3D, seed_value: float) -> void:
	_labels.append({"label": label, "seed": seed_value, "color": label.modulate})


func add_steam(at: Vector3, color: Color, height := 3.0) -> void:
	var p := GPUParticles3D.new()
	p.amount = 12
	p.lifetime = 2.4
	p.preprocess = 2.4
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, height + 6.0, 8))
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 9.0
	m.initial_velocity_min = height * 0.4
	m.initial_velocity_max = height * 0.7
	m.gravity = Vector3.ZERO
	m.scale_min = 0.8
	m.scale_max = 1.5
	m.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.5))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var fade := GradientTexture1D.new()
	fade.gradient = ramp
	m.color_ramp = fade
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	quad.material = Mats.particle("smoke", false, true)
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.position = at


func _process(delta: float) -> void:
	_clock += delta
	var camera := get_viewport().get_camera_3d()
	if camera:
		for f: Dictionary in _followers:
			(f["node"] as Node3D).global_position = camera.global_position + (f["offset"] as Vector3)
	for m: Dictionary in _movers:
		var period: float = m["period"]
		var round_no := int(_clock / period)
		var t := fmod(_clock, period) / float(m["travel"])
		var node: Node3D = m["node"]
		node.visible = t < 1.0
		if t < 1.0:
			node.position = (m["a"] as Vector3).lerp(m["c"], t)
			if round_no != m["last"] and m["sound"] != "":
				m["last"] = round_no
				Sfx.play_at(m["sound"], (m["a"] as Vector3).lerp(m["c"], 0.5), 2.0)
	for o: Dictionary in _orbits:
		var node: Node3D = o["node"]
		match o["mode"]:
			"spin":
				node.rotation.y += float(o["speed"]) * delta
			"sway":
				var k := 0.5 - 0.5 * cos(TAU * _clock / float(o["period"]))
				node.position = (o["a"] as Vector3).lerp(o["c"], k)
			"orbit":
				var a := TAU * _clock / float(o["period"]) + float(o["phase"])
				var r: Vector2 = o["radius"]
				node.position = (o["centre"] as Vector3) + Vector3(sin(a) * r.x, sin(a * 2.0) * 1.2, sin(a * 2.0) * r.y)
				node.rotation.y = -a
	for l: Dictionary in _lights:
		var wave := 0.5 + 0.5 * sin(TAU * _clock / float(l["period"]))
		(l["light"] as Light3D).light_energy = lerpf(l["low"], l["high"], wave)
	for s: Dictionary in _labels:
		var beat := fmod(_clock + float(s["seed"]) * 3.1, 7.0)
		var blink := beat < 0.5 and sin(beat * 70.0) > 0.0
		(s["label"] as Label3D).modulate = (s["color"] as Color).darkened(0.7) if blink else s["color"]
