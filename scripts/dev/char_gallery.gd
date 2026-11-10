extends Node
## `--test=char-gallery --out=<dir> [--only=rebel|korpo] [--shots=lineup,detail,poses,far]`, windowed:
## every foot soldier of both sides in a plain studio. Line-ups from the front and back, a close
## look at each class, the poses that strain a body most, and the same body far away.

const POSES := [
	# name, speed, pitch, crouching, prone, sprinting, seconds to settle
	["stoi", 0.0, 0.0, false, false, false, 0.5],
	["bieg", 7.5, 0.0, false, false, true, 0.62],
	["kuca", 0.0, 0.0, true, false, false, 0.6],
	["lezy", 0.0, 0.0, false, true, false, 0.9],
	["gora", 0.0, 0.7, false, false, false, 0.5],
	["dol", 0.0, -0.7, false, false, false, 0.5],
]

var out_dir := ""
var _camera: Camera3D
var _stage: Node3D
var _wanted: PackedStringArray


func _ready() -> void:
	out_dir = Settings.arg("out", "user://chars")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_wanted = Settings.arg("shots", "lineup,detail,poses,far").split(",")
	get_window().unfocusable = true
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.apply_display()
	get_window().size = Vector2i(1920, 1080)
	_build_studio()
	var only := Settings.arg("only", "")
	for team in 2:
		var label := "korpo" if team == C.Team.EMPIRE else "rebel"
		if only != "" and only != label:
			continue
		if "lineup" in _wanted:
			await _lineup(team, label)
		if "detail" in _wanted:
			await _details(team, label)
		if "poses" in _wanted:
			await _poses(team, label)
		if "far" in _wanted:
			await _far(team, label)
	get_tree().quit(0)


func _build_studio() -> void:
	_stage = Node3D.new()
	add_child(_stage)
	var sun := Atmos.setup(_stage)
	sun.look_at_from_position(Vector3(-3, 5, 4), Vector3.ZERO)
	var environment := (_stage.get_child(0) as WorldEnvironment).environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.3, 0.33, 0.37)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.84, 0.9)
	environment.ambient_light_energy = 0.7
	environment.volumetric_fog_enabled = false
	environment.fog_enabled = false
	var fill := OmniLight3D.new()
	fill.position = Vector3(4.0, 2.4, 5.0)
	fill.light_color = Color(0.9, 0.94, 1.0)
	fill.light_energy = 1.6
	fill.omni_range = 30.0
	_stage.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.3, 0.32, 0.35)
	ground.roughness = 0.9
	plane.material = ground
	floor_mesh.mesh = plane
	_stage.add_child(floor_mesh)
	_camera = Camera3D.new()
	_camera.fov = 24.0
	_stage.add_child(_camera)
	_camera.current = true


func _classes(team: int) -> Array[int]:
	var out: Array[int] = []
	for class_id in C.CLASSES[team].size():
		var cd := C.cls(team, class_id)
		if not cd.get("vehicle", false) and not cd.get("mech", false):
			out.append(class_id)
	return out


func _spawn(team: int, class_id: int, at: Vector3, weapon_slot := 0) -> SoldierModel:
	var cd := C.cls(team, class_id)
	var body := SoldierModel.new()
	body.setup(team)
	_stage.add_child(body)
	body.set_loadout(cd["weapons"][mini(weapon_slot, (cd["weapons"] as Array).size() - 1)], class_id)
	body.position = at
	return body


func _settle(bodies: Array, pose: Array, yaw := PI) -> void:
	var frames := int(float(pose[6]) / 0.016)
	for frame in frames:
		for body: SoldierModel in bodies:
			body.prone = pose[4]
			body.set_motion(Vector2(0.0, pose[1]), true, false, pose[5])
			body.update_pose(0.016, body.position, yaw, pose[2], pose[1], pose[3], true, false, true)
	await get_tree().process_frame


func _lineup(team: int, label: String) -> void:
	var bodies: Array = []
	var ids := _classes(team)
	for i in ids.size():
		bodies.append(_spawn(team, ids[i], Vector3((i - (ids.size() - 1) * 0.5) * 1.05, 0, 0)))
	await _settle(bodies, POSES[0])
	_camera.fov = 24.0
	for view: Array in [["przod", Vector3(0.0, 1.25, 12.5)], ["tyl", Vector3(0.0, 1.4, -12.5)], ["skos", Vector3(7.5, 1.6, 10.5)]]:
		_camera.position = view[1]
		_camera.look_at(Vector3(0, 0.95, 0))
		await _shot("%s_szereg_%s" % [label, view[0]])
	for body: SoldierModel in bodies:
		body.free()
	await get_tree().process_frame


func _details(team: int, label: String) -> void:
	for class_id in _classes(team):
		var body := _spawn(team, class_id, Vector3.ZERO)
		await _settle([body], POSES[0])
		var id := String(C.cls(team, class_id)["id"])
		_camera.fov = 24.0
		_camera.position = Vector3(1.2, 1.5, 4.6)
		_camera.look_at(Vector3(0, 1.0, 0))
		await _shot("%s_%s_cala" % [label, id])
		_camera.position = Vector3(0.55, 1.62, 1.75)
		_camera.look_at(Vector3(0, 1.5, 0))
		await _shot("%s_%s_popiersie" % [label, id])
		_camera.position = Vector3(-1.4, 1.6, -4.4)
		_camera.look_at(Vector3(0, 1.0, 0))
		await _shot("%s_%s_tyl" % [label, id])
		body.free()
		await get_tree().process_frame


func _poses(team: int, label: String) -> void:
	var ids := _classes(team)
	var bodies: Array = []
	for i in POSES.size():
		bodies.append(_spawn(team, ids[i % ids.size()], Vector3((i - (POSES.size() - 1) * 0.5) * 1.5, 0, 0)))
	for i in POSES.size():
		await _settle([bodies[i]], POSES[i])
	_camera.fov = 24.0
	for view: Array in [["przod", Vector3(3.0, 1.3, 13.0)], ["bok", Vector3(13.5, 1.2, 0.6)], ["tyl", Vector3(-3.0, 1.6, -13.0)]]:
		_camera.position = view[1]
		_camera.look_at(Vector3(0, 0.8, 0))
		await _shot("%s_pozy_%s" % [label, view[0]])
	for body: SoldierModel in bodies:
		body.free()
	await get_tree().process_frame


## The same soldiers from where most of a battle sees them, through a long lens.
func _far(team: int, label: String) -> void:
	var ids := _classes(team)
	var bodies: Array = []
	for i in ids.size():
		bodies.append(_spawn(team, ids[i], Vector3((i - (ids.size() - 1) * 0.5) * 1.05, 0, 0)))
	await _settle(bodies, POSES[0])
	for distance: float in [20.0, 40.0, 70.0]:
		_camera.fov = rad_to_deg(2.0 * atan(2.6 / distance))
		_camera.position = Vector3(distance * 0.3, 1.5, distance * 0.954)
		_camera.look_at(Vector3(0, 0.95, 0))
		await _shot("%s_daleko_%d" % [label, int(distance)])
	for body: SoldierModel in bodies:
		body.free()
	await get_tree().process_frame


func _shot(label: String) -> void:
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("[char] ", path)
