extends Node
## `--test=preview-flicker --out=<dir> [--variant=...] [--backdrop=1]`, windowed: the deploy
## screen's class preview for every class, turned slowly at a fixed time step, scored for flicker.
## The score is how far each frame strays from halfway between its neighbours, so steady motion
## cancels and only what blinks remains; it saves that change, amplified, as `<variant>_<class>_diff.png`.
## Variants switch things off to find a cause, and combine with "_": noshadow, noweave, noglow,
## thr (higher glow threshold), m8 (MSAA 8x), taa, matte (plain material), nogun, norim, l0only.

var out_dir := ""


func _ready() -> void:
	out_dir = Settings.arg("out", "user://pf")
	var variant := Settings.arg("variant", "plain")
	get_window().unfocusable = true
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.apply_display()
	get_window().size = Vector2i(900, 1000)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui)
	if Settings.arg("backdrop", "") != "":
		var back := ColorRect.new()
		back.color = Color(0.55, 0.2, 0.25)
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.add_child(back)
	for team in 2:
		var p := ClassPreview.new()
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.add_child(p)
		await get_tree().process_frame
		for class_id in C.CLASSES[team].size():
			var cd := C.cls(team, class_id)
			if cd.get("vehicle", false) or cd.get("mech", false):
				continue
			p.show_kit(team, class_id, {})
			p.set("_user_turned", true)
			p.set("_yaw", 1.9)
			if "noshadow" in variant:
				for l in p.find_children("*", "DirectionalLight3D", true, false):
					(l as DirectionalLight3D).shadow_enabled = false
			if "noweave" in variant:
				for mi: MeshInstance3D in p.find_children("*_L0", "MeshInstance3D", true, false):
					var m := mi.material_override as ShaderMaterial
					mi.material_override = CharAssets.material(team, m.get_shader_parameter("tint"), false)
			if "noglow" in variant:
				for we in p.find_children("*", "WorldEnvironment", true, false):
					(we as WorldEnvironment).environment.glow_enabled = false
			if "thr" in variant:
				for we in p.find_children("*", "WorldEnvironment", true, false):
					(we as WorldEnvironment).environment.glow_hdr_threshold = 1.8
			if "aa8" in variant:
				var vp := p.get_child(0) as SubViewport
				vp.msaa_3d = Viewport.MSAA_8X
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			if "m8" in variant:
				(p.get_child(0) as SubViewport).msaa_3d = Viewport.MSAA_8X
			if "taa" in variant:
				(p.get_child(0) as SubViewport).use_taa = true
			if "nogloss" in variant:
				for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
					if mi.material_override is ShaderMaterial:
						var m := (mi.material_override as ShaderMaterial).duplicate() as ShaderMaterial
						m.set_shader_parameter("steady_gloss", false)
						mi.material_override = m
			if "matte" in variant:
				var matte := StandardMaterial3D.new()
				matte.vertex_color_use_as_albedo = true
				matte.roughness = 1.0
				for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
					if mi.material_override is ShaderMaterial:
						mi.material_override = matte
			if "nogun" in variant:
				var model2: SoldierModel = p.get("_model")
				if model2.weapon_node:
					model2.weapon_node.visible = false
			if "norim" in variant:
				for l in p.find_children("*", "DirectionalLight3D", true, false):
					if (l as DirectionalLight3D).light_energy < 1.5:
						l.visible = false
			for dbg in [["xrim", "dbg_rim"], ["xemit", "dbg_emit"], ["xspec", "dbg_spec"], ["xmetal", "dbg_metal"], ["xrough", "dbg_rough"]]:
				if dbg[0] in variant:
					for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
						if mi.material_override is ShaderMaterial:
							var m := (mi.material_override as ShaderMaterial).duplicate() as ShaderMaterial
							m.set_shader_parameter(dbg[1], 0.0)
							mi.material_override = m
			if variant == "l0only":
				for mi: MeshInstance3D in p.find_children("*_L1", "MeshInstance3D", true, false) + p.find_children("*_L2", "MeshInstance3D", true, false):
					mi.visible = false
			p.set_process(false)
			var model: SoldierModel = p.get("_model")
			for i in 20:
				model.set_motion(Vector2.ZERO, true, false, false)
				model.update_pose(1.0 / 60.0, Vector3.ZERO, 1.9, 0.0, 0.0, false, false, false, true)
				await RenderingServer.frame_post_draw
			var frames: Array[Image] = []
			var worst := 0.0
			var total := 0.0
			var acc := Image.create(900, 1000, false, Image.FORMAT_RGB8)
			for f in 14:
				model.set_motion(Vector2.ZERO, true, false, false)
				model.update_pose(1.0 / 60.0, Vector3.ZERO, 1.9 + f * 0.004, 0.0, 0.0, false, false, false, true)
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				frames.append(img)
				if frames.size() >= 3:
					var d := _diff(frames[-3], frames[-2], frames[-1], acc)
					total += d
					worst = maxf(worst, d)
			var last: Image = frames[-1]
			var label := "%s_%s" % ["korpo" if team == 1 else "rebel", cd["id"]]
			print("[pf] %s %s mean %.2f worst %.2f" % [variant, label, total / 12.0, worst])
			acc.save_png("%s/%s_%s_diff.png" % [out_dir, variant, label])
			last.save_png("%s/%s_%s.png" % [out_dir, variant, label])
	get_tree().quit(0)


## Mean change of the pixels that changed at all, and the share of them, folded into one score:
## the sum of change over the frame, per thousand pixels.
## Flicker, not motion: how far the middle frame strays from halfway between its neighbours.
## Steady movement cancels out; a pixel that goes bright and back does not. Summed over the frame,
## per thousand pixels.
func _diff(a: Image, b: Image, c: Image, acc: Image) -> float:
	var da := a.get_data()
	var db := b.get_data()
	var dcc := c.get_data()
	var dc := acc.get_data()
	var sum := 0
	for i in da.size() / 3:
		var d := 0
		for k in 3:
			d = maxi(d, absi(da[i * 3 + k] + dcc[i * 3 + k] - 2 * db[i * 3 + k]) / 2)
		if d > 2:
			sum += d
		var shown := mini(d * 8, 255)
		if shown > dc[i * 3]:
			dc[i * 3] = shown
			dc[i * 3 + 1] = shown
			dc[i * 3 + 2] = shown
	acc.set_data(900, 1000, false, Image.FORMAT_RGB8, dc)
	return float(sum) / (da.size() / 3) * 1000.0
