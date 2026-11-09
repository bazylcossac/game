extends Node
## `--test=weapon-icons`, windowed: renders every gun side-on as a white silhouette for the HUD and
## the deploy screen. Writes assets/textures/weapons/<weapon>_<team>.png. Run --import afterwards.

const SIZE := Vector2i(512, 176)
const OUT := "res://assets/textures/weapons"


func _ready() -> void:
	get_window().unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var view := SubViewport.new()
	view.size = SIZE
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_4X
	add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.add_child(camera)
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	for team in 2:
		for key: String in C.W.keys():
			var id: int = C.W[key]
			if not C.WEAPONS.has(id) or key.begins_with("TANK") or key.begins_with("MECH") or key == "APC_NONE":
				continue
			if id == C.W.MINIGUN and team == C.Team.EMPIRE:
				continue
			if C.WEAPONS[id].get("arm", false) and team == C.Team.RESISTANCE:
				continue
			var gun := WeaponFactory.build(id, team)
			# A weapon arm is drawn alone, without the other arm beside it.
			for spare: String in ["OtherArm", "OtherCell"]:
				if gun.get_node_or_null(spare):
					gun.get_node(spare).free()
			view.add_child(gun)
			# Blades stand upright on their models. Laid down, they read like every other icon.
			if C.WEAPONS[id]["melee"]:
				gun.rotation.x = -PI * 0.5
			var box := AABB()
			var first := true
			for part in gun.find_children("*", "GeometryInstance3D", true, false):
				var mesh := part as GeometryInstance3D
				if mesh is GPUParticles3D or mesh is CPUParticles3D or part.name == &"LaserLine":
					mesh.visible = false
					continue
				mesh.material_override = white
				mesh.visibility_range_end = 0.0
				if not mesh.is_visible_in_tree():
					continue
				var bounds := mesh.global_transform * mesh.get_aabb()
				box = bounds if first else box.merge(bounds)
				first = false
			if first:
				gun.queue_free()
				continue
			var centre := box.get_center()
			# Side on, muzzle to the right. The camera size is the view's height in metres.
			camera.size = maxf(box.size.y * 1.12, box.size.z * 1.06 * float(SIZE.y) / float(SIZE.x))
			camera.look_at_from_position(centre + Vector3(4, 0, 0), centre, Vector3.UP)
			for i in 3:
				await RenderingServer.frame_post_draw
			var image := view.get_texture().get_image()
			var path := "%s/%s_%d.png" % [ProjectSettings.globalize_path(OUT), key.to_lower(), team]
			image.save_png(path)
			print("[icons] ", path.get_file())
			gun.queue_free()
			await get_tree().process_frame
	get_tree().quit(0)
