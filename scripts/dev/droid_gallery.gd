extends Node
## `--test=droid-gallery --out=<dir>`, windowed: every machine of the Iron Empire and every one of
## its guns, alone in a dark studio.

var out_dir := ""
var _camera: Camera3D
var _stage: Node3D


func _ready() -> void:
	out_dir = Settings.arg("out", "user://droids")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().unfocusable = true
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.apply_display()
	_build_studio()
	await _machines()
	await _guns()
	get_tree().quit(0)


func _build_studio() -> void:
	_stage = Node3D.new()
	add_child(_stage)
	var sun := Atmos.setup(_stage)
	sun.look_at_from_position(Vector3(-3, 5, 4), Vector3.ZERO)
	var environment := (_stage.get_child(0) as WorldEnvironment).environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.1, 0.115, 0.135)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.84, 0.9)
	environment.ambient_light_energy = 0.6
	environment.volumetric_fog_enabled = false
	environment.fog_enabled = false
	var rim := OmniLight3D.new()
	rim.position = Vector3(2.5, 3.2, -3)
	rim.light_color = Color(1.0, 0.72, 0.6)
	rim.light_energy = 1.6
	rim.omni_range = 12.0
	_stage.add_child(rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(3.2, 2.0, 1.2)
	fill.light_color = Color(0.86, 0.92, 1.0)
	fill.light_energy = 2.2
	fill.omni_range = 14.0
	_stage.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.16, 0.17, 0.19)
	ground.roughness = 0.8
	plane.material = ground
	floor_mesh.mesh = plane
	_stage.add_child(floor_mesh)
	_camera = Camera3D.new()
	_camera.fov = 26.0
	_stage.add_child(_camera)
	_camera.current = true


func _machines() -> void:
	for class_id in C.CLASSES[C.Team.EMPIRE].size():
		var cd := C.cls(C.Team.EMPIRE, class_id)
		if cd.get("vehicle", false):
			continue
		var mech: bool = cd.get("mech", false)
		var body: Node3D = MechModel.new() if mech else SoldierModel.new()
		body.call("setup", C.Team.EMPIRE)
		_stage.add_child(body)
		body.call("set_loadout", cd["weapons"][0], class_id)
		for frame in 30:
			body.call("update_pose", 0.016, Vector3.ZERO, PI, 0.0, 0.0, false, true, false, true)
			await get_tree().process_frame
		var height := 3.4 if mech else 1.9
		var label := String(cd["id"])
		for view: Array in [["przod", Vector3(0.7, 0.55, 3.0)], ["bok", Vector3(3.0, 0.55, 0.3)], ["tyl", Vector3(-0.9, 0.6, -3.0)]]:
			_camera.position = (view[1] as Vector3) * height + Vector3(0, 0, 0)
			_camera.look_at(Vector3(0, height * 0.5, 0))
			await _shot("droid_%d_%s_%s" % [class_id, label, view[0]])
		_camera.position = Vector3(0.45, 0.92, 1.25) * height
		_camera.look_at(Vector3(0, height * 0.8, 0))
		await _shot("droid_%d_%s_detal" % [class_id, label])
		body.free()
		await get_tree().process_frame


func _guns() -> void:
	for id: int in C.WEAPONS:
		if not WeaponFactory.ASSETS.has(id):
			continue
		var gun := WeaponFactory.build(id, C.Team.EMPIRE, [])
		_stage.add_child(gun)
		gun.position = Vector3(0, 0.75, 0)
		var label := String(C.WEAPONS[id]["name"]).to_lower().replace(" ", "_")
		await get_tree().process_frame
		var box := _bounds(gun)
		var centre := box.get_center()
		var far := maxf(maxf(box.size.z * 1.44, box.size.y * 2.6), 0.75)
		_camera.position = centre + Vector3(far, 0.02, 0)
		_camera.look_at(centre)
		await _shot("bron_%s_bok" % label)
		_camera.position = centre + Vector3(far * 0.74, far * 0.3, far * 0.5)
		_camera.look_at(centre)
		await _shot("bron_%s_skos" % label)
		gun.free()
		await get_tree().process_frame


func _bounds(node: Node3D) -> AABB:
	var box := AABB(node.global_position, Vector3.ZERO)
	for part in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		box = box.merge(mesh.global_transform * mesh.get_aabb())
	return box


func _shot(label: String) -> void:
	await get_tree().create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("[droid] ", path)
