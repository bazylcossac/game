extends Node
## `--test=props-gallery --out=<dir>`, windowed: every street prop alone, at night, as it is in game.

var out_dir := ""


func _ready() -> void:
	out_dir = Settings.arg("out", "user://props")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().unfocusable = true
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.apply_display()
	var stage := Node3D.new()
	add_child(stage)
	var sun := Atmos.setup(stage)
	sun.look_at_from_position(Vector3(-3, 5, 4), Vector3.ZERO)
	sun.light_energy = 1.4
	var environment := (stage.get_child(0) as WorldEnvironment).environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.05, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.62, 0.8)
	environment.ambient_light_energy = 1.1
	environment.volumetric_fog_enabled = false
	environment.fog_enabled = false
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	plane.material = Mats.world("asphalt")
	floor_mesh.mesh = plane
	stage.add_child(floor_mesh)
	var rim := OmniLight3D.new()
	rim.position = Vector3(5, 5, -5)
	rim.light_color = Color(1.0, 0.4, 0.7)
	rim.light_energy = 3.0
	rim.omni_range = 18.0
	stage.add_child(rim)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.far = 200.0
	stage.add_child(camera)
	camera.current = true
	var tints := {"car_sedan": Color(0.5, 0.05, 0.08), "car_sport": Color(0.9, 0.62, 0.06), "car_van": Color(0.78, 0.8, 0.84), "bus": Color(0.08, 0.2, 0.42), "tree_oak": Color(0.5, 0.95, 0.62), "tree_slim": Color(0.86, 0.5, 0.9), "tree_palm": Color(0.72, 1.0, 0.5), "planter_bush": Color(0.42, 0.85, 0.8), "container": Color(0.56, 0.2, 0.08), "kiosk": Color(0.05, 0.14, 0.42)}
	var root: Node = (load(CityProps.PATH) as PackedScene).instantiate()
	var names := []
	for child in root.find_children("*", "MeshInstance3D", true, false):
		names.append(String(child.name))
	root.free()
	for prop: String in names:
		var shown := MeshInstance3D.new()
		var mesh := CityProps.mesh_for(prop)
		shown.mesh = mesh
		stage.add_child(shown)
		var tint: Color = tints.get(prop, Color.WHITE)
		# A single mesh has no copy colour, so the paint is shown through a tinted duplicate.
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface) as StandardMaterial3D
			if mat and mat.vertex_color_use_as_albedo and mat.metallic_specular >= 0.0 and (mat == CityProps.finish_for(_named("Paint")) or mat == CityProps.finish_for(_named("Leaf"))):
				var copy := mat.duplicate() as StandardMaterial3D
				copy.albedo_color = tint
				shown.set_surface_override_material(surface, copy)
		var box := shown.get_aabb()
		var c := box.get_center()
		var far := maxf(box.size.length() * 2.0, 4.0)
		camera.position = c + Vector3(far * 0.62, far * 0.24, far * 0.72)
		camera.look_at(c)
		await get_tree().create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, prop])
		print("[props] ", prop)
		shown.free()
	get_tree().quit(0)


func _named(key: String) -> Material:
	var m := StandardMaterial3D.new()
	m.resource_name = key
	return m
