class_name Hud
extends CanvasLayer
## In-game overlay. Owns the deploy screen, scoreboard, pause menu and end screen.

var world: World
var canvas: HudCanvas
var _thermal: ColorRect
var _root: Control
var minimap: TacticalMap
var big_map: TacticalMap
var deploy: DeployScreen
var scoreboard: Scoreboard
var pause_menu: PauseMenu
var end_screen: EndScreen
var vignette: ColorRect
var _vignette_mat: ShaderMaterial


func _ready() -> void:
	layer = 10
	var root := Control.new()
	_root = root
	UiKit.fill(root)
	root.theme = UiKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	vignette = ColorRect.new()
	UiKit.fill(vignette)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float hurt = 0.0;
uniform float base = 0.35;
void fragment() {
	vec2 d = UV - 0.5;
	float v = smoothstep(0.32, 0.86, length(d * vec2(1.0, 0.9)));
	vec3 col = mix(vec3(0.0), vec3(0.5, 0.02, 0.0), hurt);
	COLOR = vec4(col, v * (base + hurt * 0.75));
}
"""
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = sh
	vignette.material = _vignette_mat
	root.add_child(vignette)

	canvas = HudCanvas.new()
	canvas.world = world
	UiKit.fill(canvas)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(canvas)

	minimap = TacticalMap.new()
	minimap.setup(world, true)
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -288
	minimap.offset_right = -28
	minimap.offset_top = -476
	minimap.offset_bottom = -216
	root.add_child(minimap)

	scoreboard = Scoreboard.new()
	scoreboard.world = world
	UiKit.fill(scoreboard)
	scoreboard.visible = false
	root.add_child(scoreboard)

	deploy = DeployScreen.new()
	deploy.world = world
	UiKit.fill(deploy)
	deploy.visible = false
	root.add_child(deploy)

	end_screen = EndScreen.new()
	end_screen.world = world
	UiKit.fill(end_screen)
	end_screen.visible = false
	root.add_child(end_screen)

	pause_menu = PauseMenu.new()
	pause_menu.world = world
	UiKit.fill(pause_menu)
	pause_menu.visible = false
	root.add_child(pause_menu)
	_set_playing(false)


func set_thermal(on: bool) -> void:
	if on and _thermal == null:
		_thermal = ColorRect.new()
		_thermal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/thermal.gdshader")
		_thermal.material = mat
		UiKit.fill(_thermal)
		_root.add_child(_thermal)
		_root.move_child(_thermal, 0)
	if _thermal:
		_thermal.visible = on


## The whole battlefield on M, centred over the game.
func _build_big_map() -> void:
	big_map = TacticalMap.new()
	big_map.setup(world, false)
	big_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(big_map)
	big_map.offset_left = 180
	big_map.offset_right = -180
	big_map.offset_top = 70
	big_map.offset_bottom = -70
	big_map.visible = false
	_root.add_child(big_map)


func _set_playing(on: bool) -> void:
	canvas.visible = on
	minimap.visible = on
	vignette.visible = on


func _process(_delta: float) -> void:
	var c := world.controller
	var playing := c.state == PlayerController.State.ALIVE or c.state == PlayerController.State.DEAD
	if canvas.visible != playing:
		_set_playing(playing)
	var hurt := 0.0
	if world.local and world.local.alive:
		hurt = clampf(1.0 - world.local.hp / (world.local.max_hp * 0.55), 0.0, 1.0)
	_vignette_mat.set_shader_parameter("hurt", maxf(hurt * 0.75, canvas.flash_hurt))
	var overlay := deploy.visible or pause_menu.visible or end_screen.visible
	scoreboard.visible = (Input.is_action_pressed("scoreboard") and not overlay and playing)
	c.input_blocked = pause_menu.visible
	if big_map == null:
		_build_big_map()
	if Input.is_action_just_pressed("map") and playing and not overlay:
		big_map.visible = not big_map.visible
	if overlay or not playing:
		big_map.visible = false
	minimap.visible = playing and not c.scoped and not scoreboard.visible and not big_map.visible


func deploy_visible() -> bool:
	return deploy.visible


func show_deploy(wait: float) -> void:
	deploy.open(wait)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_deploy() -> void:
	deploy.visible = false


func toggle_pause() -> void:
	if end_screen.visible:
		return
	pause_menu.toggle()


func on_local_death(killer: Soldier, weapon_id: int) -> void:
	canvas.killed_by = killer
	canvas.killed_with = weapon_id
	canvas.death_t = 0.0


func add_kill(k: Soldier, v: Soldier, weapon_id: int, head: bool) -> void:
	canvas.add_kill(k, v, weapon_id, head)


func big_message(text: String, color: Color) -> void:
	canvas.big_message(text, color)


func banner(title: String, sub: String, color: Color) -> void:
	canvas.banner(title, sub, color)


func damage_from(pos: Vector3) -> void:
	canvas.damage_from(pos)


func hit_marker(kind: int) -> void:
	canvas.hit_marker(kind)


func score_popup(points: int, reason: String) -> void:
	canvas.score_popup(points, reason)


func show_end_screen(winner: int, restart_in: float) -> void:
	deploy.visible = false
	pause_menu.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	end_screen.open(winner, restart_in)


func hide_end_screen() -> void:
	end_screen.visible = false
