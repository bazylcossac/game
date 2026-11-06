class_name Fortification
extends StaticBody3D
## One destructible obstacle. Meshes are shared across instances; server builds only physics.

static var _meshes := {}
var visual := Node3D.new()
var health_label: Label3D
var kind := 0
var max_hp := 1.0

func setup(id: int, type: int, team: int, size: Vector3, hp: float, view: bool) -> void:
	kind = type
	max_hp = hp
	set_meta("fort_id", id)
	collision_layer = C.LAYER_FORT | (0 if type == 1 else C.LAYER_WORLD)
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	add_child(visual)
	if not view:
		return
	if type == Fortifications.BEACON:
		WeaponFactory.fit(visual, "Beacon", team)
	else:
		for mesh: Mesh in meshes(type):
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			visual.add_child(mi)
	health_label = Label3D.new()
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.font_size = 32
	health_label.pixel_size = 0.008
	health_label.modulate = C.TEAM_COLORS[team]
	health_label.position.y = size.y + 0.4
	health_label.visibility_range_end = 24
	add_child(health_label)
	set_health(hp)

func set_health(hp: float) -> void:
	if health_label:
		health_label.text = "%d%%" % int(hp / max_hp * 100)
		health_label.visible = hp < max_hp

static func meshes(type: int) -> Array:
	if _meshes.has(type):
		return _meshes[type]
	var kit := MapKit.new()
	kit.rng.seed = 1943 + type
	match type:
		0: kit._sandbags(Vector3(-1.65, 0, 0), Vector3(1.65, 0, 0), 4)
		1: kit._wire(Vector3(-1.65, 0, 0), Vector3(1.65, 0, 0))
		2: kit._hedgehog(Vector3.ZERO)
		3:
			kit.b.box(Vector3(0, .2, 0), Vector3(1.2, .4, 1.2), "metal", Color(.3, .35, .4), false)
			kit.b.box(Vector3(0, 1.0, 0), Vector3(.35, 1.6, .35), "metal", Color(.4, .45, .5), false)
			kit.b.box(Vector3(0, 1.75, 0), Vector3(.8, .5, .7), "metal", Color(.3, .35, .4), false)
			kit.b.box(Vector3(0, 1.8, -.7), Vector3(.18, .18, 1.4), "metal", Color(.2, .25, .3), false)
			kit.b.box(Vector3(0, 1.9, -.7), Vector3(.08, .06, 1.1), "neon_cyan", Color.WHITE, false)
	var stage := Node3D.new()
	kit.b.finish(stage)
	var out: Array = []
	for child in stage.get_children():
		if child is MeshInstance3D:
			out.append(child.mesh)
	stage.free()
	_meshes[type] = out
	return out
