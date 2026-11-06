class_name CoinPickup
extends Node3D
## The visible coin. Pickup itself is decided by the server, see MatchServer._tick_coins.

var _spin: Node3D
var _t := 0.0


func _ready() -> void:
	_spin = Node3D.new()
	_spin.position.y = 1.1
	add_child(_spin)
	var gold: Material = Mats.glow(Color(1.0, 0.72, 0.22), 1.4)
	var face: Material = Mats.flat(Color(0.92, 0.68, 0.26), 0.3, 0.95)
	P.cyl(_spin, 0.36, 0.36, 0.07, Vector3.ZERO, face, Vector3(PI * 0.5, 0, 0), Vector3.ONE, 24)
	P.ring(_spin, 0.36, 0.022, Vector3.ZERO, gold)
	for sign: float in [-1.0, 1.0]:
		P.ball(_spin, 0.09, Vector3(0, 0, 0.03 * sign), gold, Vector3(1, 1, 0.3))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.76, 0.34)
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position.y = 1.2
	add_child(light)

	# A tall column, so the coin can be found from across the map.
	var column := CylinderMesh.new()
	column.top_radius = 0.34
	column.bottom_radius = 0.34
	column.height = 26.0
	column.radial_segments = 12
	column.rings = 1
	column.cap_top = false
	column.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/zone_ring.gdshader")
	mat.set_shader_parameter("ring_color", Vector3(1.0, 0.72, 0.28))
	mat.set_shader_parameter("strength", 5.0)
	mat.set_shader_parameter("falloff", 0.8)
	var mi := MeshInstance3D.new()
	mi.mesh = column
	mi.material_override = mat
	mi.position.y = 13.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	_spin.rotation.y = _t * 2.2
	_spin.position.y = 1.1 + sin(_t * 2.0) * 0.1
