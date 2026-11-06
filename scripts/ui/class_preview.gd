class_name ClassPreview
extends SubViewportContainer
## Live 3D look at the chosen class and gear, on its own small stage. Drag to turn it.

var _viewport := SubViewport.new()
var _stage := Node3D.new()
var _model: SoldierModel
var _yaw := 1.9
var _dragging := false
var _idle_t := 0.0
var _user_turned := false


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.handle_input_locally = false
	add_child(_viewport)
	_viewport.add_child(_stage)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.54, 0.62)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.72)
	key.light_energy = 1.7
	key.rotation_degrees = Vector3(-34, 34, 0)
	key.shadow_enabled = true
	_stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.45, 0.65, 1.0)
	rim.light_energy = 1.3
	rim.rotation_degrees = Vector3(-12, 205, 0)
	_stage.add_child(rim)

	var floor_disc := P.cyl(_stage, 1.1, 1.14, 0.05, Vector3(0, -0.03, 0), Mats.flat(Color(0.1, 0.11, 0.13), 0.5, 0.5), Vector3.ZERO, Vector3.ONE, 40)
	floor_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	P.ring(_stage, 1.1, 0.012, Vector3(0, 0.0, 0), Mats.glow(UiKit.BRASS, 1.4)).rotation = Vector3.ZERO

	var cam := Camera3D.new()
	cam.fov = 26.0
	_stage.add_child(cam)
	cam.position = Vector3(0, 1.42, 5.1)
	cam.look_at_from_position(cam.position, Vector3(0, 0.98, 0), Vector3.UP)
	cam.current = true


func show_kit(team: int, class_id: int, kit: Dictionary) -> void:
	if _model == null:
		_model = SoldierModel.new()
		_model.setup(team)
		_stage.add_child(_model)
	var weapon: int = kit.get("primary", C.cls(team, class_id)["weapons"][0])
	_model.set_loadout(weapon, class_id, kit.get("parts_p", []))
	_model.reset_pose()


func _process(delta: float) -> void:
	if _model == null or not is_visible_in_tree():
		return
	# Sways side-on, so the weapon stays in view, until the player takes over by dragging.
	_idle_t += delta
	if not _dragging and not _user_turned:
		_yaw = 1.9 + sin(_idle_t * 0.45) * 0.45
	_model.set_motion(Vector2.ZERO, true, false, false)
	_model.update_pose(delta, Vector3.ZERO, _yaw, 0.0, 0.0, false, false, false, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _dragging:
		_user_turned = true
		_yaw += (event as InputEventMouseMotion).relative.x * 0.012
