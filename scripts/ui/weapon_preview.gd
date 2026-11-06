class_name WeaponPreview
extends Control
## The gunsmith's bench: the weapon in 3D with its real parts, labelled slot by slot.
## Drag to turn it, scroll to zoom. A part that changes slides into place.

signal slot_clicked(slot: String)

const BASE_YAW := PI * 0.5 + 0.3
const BASE_TILT := 0.14
const SLIDE_TIME := 0.26
## Which way each part arrives from.
const SLIDE_FROM := {
	"optic": Vector3(0, 0.14, 0), "muzzle": Vector3(0, 0, -0.2), "grip": Vector3(0, -0.14, 0), "cell": Vector3(0, -0.14, 0),
}
const CHIP_H := 54.0
const MUZZLE_ROOM := 0.34

## Slot to highlight, as when a part is being tried on.
var focus_slot := ""

var _box := SubViewportContainer.new()
var _viewport := SubViewport.new()
var _overlay := Control.new()
var _tilt := Node3D.new()
var _turn := Node3D.new()
var _cam := Camera3D.new()
var _gun: Node3D
var _weapon := -1
var _team := 0
var _parts: Array = []
var _size := Vector3.ONE
var _centre := Vector3.ZERO
var _yaw := BASE_YAW
var _pitch := BASE_TILT
var _zoom := 1.0
var _dist := 2.0
var _idle := 0.0
var _dragging := false
var _moved := 0.0
var _user_turned := false
var _hits := {}
var _pulse := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_box.stretch = true
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(_box)
	add_child(_box)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.handle_input_locally = false
	_box.add_child(_viewport)
	_build_stage()

	UiKit.fill(_overlay)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_overlay.draw.connect(_paint)
	_overlay.gui_input.connect(_on_input)
	add_child(_overlay)


func _build_stage() -> void:
	var stage := Node3D.new()
	_viewport.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.66)
	env.ambient_light_energy = 0.7
	# Metal has nothing to reflect on an empty stage without a sky, and would come out black.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.5, 0.56, 0.68)
	sky_mat.sky_horizon_color = Color(0.86, 0.74, 0.58)
	sky_mat.ground_bottom_color = Color(0.1, 0.09, 0.09)
	sky_mat.ground_horizon_color = Color(0.4, 0.34, 0.28)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 2.0
	key.rotation_degrees = Vector3(-48, 24, 0)
	key.shadow_enabled = true
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.5, 0.68, 1.0)
	rim.light_energy = 1.4
	rim.rotation_degrees = Vector3(-8, 196, 0)
	stage.add_child(rim)
	stage.add_child(_tilt)
	_tilt.add_child(_turn)
	_cam.fov = 22.0
	_cam.near = 0.02
	stage.add_child(_cam)
	_cam.current = true


func show_weapon(id: int, parts: Array, team: int) -> void:
	if id == _weapon and parts == _parts and team == _team:
		return
	var same_gun := id == _weapon and team == _team
	var was: Array = _parts
	_weapon = id
	_team = team
	_parts = parts.duplicate()
	if _gun:
		_turn.remove_child(_gun)
		_gun.queue_free()
	_gun = WeaponFactory.build(id, team, _parts)
	_turn.add_child(_gun)
	if not same_gun:
		_frame_weapon()
		return
	_place_gun()
	for part: Variant in _parts:
		if not was.has(part):
			_slide_in(String(Gear.ATTACHMENTS[str(part)]["slot"]))


func _is_blade() -> bool:
	return bool(C.WEAPONS[_weapon].get("melee", false))


## The framing comes from the bare weapon, so fitting a part never makes the camera jump.
func _frame_weapon() -> void:
	var bare := WeaponFactory.build(_weapon, _team, [])
	var box := WeaponFactory.bounds(bare)
	bare.free()
	_centre = box.get_center()
	_size = box.size
	if _is_blade():
		_size = Vector3(box.size.x, box.size.z, box.size.y)
	else:
		# Room in front of the barrel, so a long suppressor stays in frame.
		_centre.z -= MUZZLE_ROOM * 0.5
		_size.z += MUZZLE_ROOM
	_place_gun()
	_zoom = 1.0
	_user_turned = false
	_pitch = BASE_TILT
	_fit()


## Blades are built standing up, so they are laid along the bench like a gun.
func _place_gun() -> void:
	var lay := Basis.from_euler(Vector3(-PI * 0.5, 0, 0)) if _is_blade() else Basis.IDENTITY
	_gun.basis = lay
	_gun.position = -(lay * _centre)


func _fit() -> void:
	var aspect := size.x / maxf(size.y, 1.0)
	var half_h := tan(deg_to_rad(_cam.fov * 0.5))
	# The gun fills most of the width, leaving the top and bottom rows to the labels.
	_dist = maxf(_size.z * 0.5 / (0.8 * half_h * maxf(aspect, 0.1)), maxf(_size.y, _size.x) * 0.5 / (0.5 * half_h))


func _slide_in(slot: String) -> void:
	var node := _gun.find_child("Part_" + slot, true, false) as Node3D
	_pulse[slot] = 1.0
	if node == null:
		return
	var home := node.position
	node.position = home + SLIDE_FROM.get(slot, Vector3.ZERO)
	var t := create_tween()
	t.tween_property(node, "position", home, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _gun == null:
		return
	_fit()
	_idle += delta
	if not _dragging and not _user_turned:
		_yaw = BASE_YAW + sin(_idle * 0.4) * 0.26
	_tilt.rotation.x = _pitch
	_turn.rotation.y = _yaw
	_cam.position.z = lerpf(_cam.position.z, _dist * _zoom, 1.0 - exp(-delta * 9.0))
	for slot: String in _pulse.keys():
		_pulse[slot] = maxf(float(_pulse[slot]) - delta * 2.2, 0.0)
		if _pulse[slot] <= 0.0:
			_pulse.erase(slot)
	_overlay.queue_redraw()


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		match b.button_index:
			MOUSE_BUTTON_LEFT:
				if b.pressed:
					for slot: String in _hits:
						if (_hits[slot] as Rect2).has_point(b.position):
							slot_clicked.emit(slot)
							return
					_dragging = true
					_moved = 0.0
				else:
					_dragging = false
			MOUSE_BUTTON_WHEEL_UP:
				_zoom = maxf(_zoom * 0.92, 0.34)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = minf(_zoom * 1.08, 1.3)
	elif event is InputEventMouseMotion and _dragging:
		var m := event as InputEventMouseMotion
		_user_turned = true
		_yaw += m.relative.x * 0.01
		_pitch = clampf(_pitch + m.relative.y * 0.008, -1.1, 1.1)


# ---------------------------------------------------------------- labels

func _slot_part(slot: String) -> String:
	for p: Variant in _parts:
		if Gear.ATTACHMENTS.has(str(p)) and Gear.ATTACHMENTS[str(p)]["slot"] == slot:
			return str(p)
	return ""


func _paint() -> void:
	_paint_bench()
	_hits.clear()
	if _gun == null:
		return
	var rows := {true: [], false: []}
	for slot: String in Gear.slots_for(_weapon):
		var at := _cam.unproject_position(_gun.to_global(WeaponFactory.anchor(_gun, _weapon, slot)))
		rows[slot == "optic" or slot == "muzzle"].append({"slot": slot, "at": at})
	for upper: bool in rows:
		var row: Array = rows[upper]
		row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"].x < b["at"].x)
		var next_x := 14.0
		for e: Dictionary in row:
			next_x = _paint_chip(e, upper, next_x)


## Faint drafting lines behind the weapon.
func _paint_bench() -> void:
	var line := Color(1, 1, 1, 0.035)
	var step := 64.0
	var x := fmod(_overlay.size.x * 0.5, step)
	while x < _overlay.size.x:
		_overlay.draw_line(Vector2(x, 0), Vector2(x, _overlay.size.y), line, 1.0)
		x += step
	var y := fmod(_overlay.size.y * 0.5, step)
	while y < _overlay.size.y:
		_overlay.draw_line(Vector2(0, y), Vector2(_overlay.size.x, y), line, 1.0)
		y += step


func _paint_chip(e: Dictionary, upper: bool, min_x: float) -> float:
	var slot: String = e["slot"]
	var at: Vector2 = e["at"]
	var part := _slot_part(slot)
	var title: String = String(Gear.SLOT_NAMES[slot]).to_upper()
	var text: String = Gear.ATTACHMENTS[part]["name"] if part != "" else "Brak"
	var small := UiKit.font("semibold")
	var bold := UiKit.font("bold")
	var width := maxf(small.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x) + 26.0
	var x := clampf(at.x - width * 0.5, min_x, maxf(_overlay.size.x - width - 14.0, min_x))
	var y := 14.0 if upper else _overlay.size.y - CHIP_H - 14.0
	var box := Rect2(x, y, width, CHIP_H)
	_hits[slot] = box
	var lit := slot == focus_slot
	var color := UiKit.BRASS if part != "" or lit else UiKit.FAINT
	var edge := Vector2(clampf(at.x, box.position.x + 8.0, box.end.x - 8.0), box.end.y if upper else box.position.y)
	_overlay.draw_line(at, edge, Color(color, 0.75), 1.5, true)
	_overlay.draw_circle(at, 4.0, color)
	if _pulse.has(slot):
		var p: float = _pulse[slot]
		_overlay.draw_arc(at, 6.0 + (1.0 - p) * 30.0, 0.0, TAU, 28, Color(UiKit.BRASS, p), 2.0, true)
	_overlay.draw_rect(box, Color(0.95, 0.71, 0.3, 0.24) if lit else Color(0.03, 0.035, 0.05, 0.82))
	_overlay.draw_rect(box, Color(color, 0.8), false, 1.0)
	_overlay.draw_string(small, Vector2(x + 13.0, y + 21.0), T.t(title), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.MUTED)
	_overlay.draw_string(bold, Vector2(x + 13.0, y + 45.0), T.t(text), HORIZONTAL_ALIGNMENT_LEFT, -1, 23, UiKit.INK if part != "" else UiKit.FAINT)
	return box.end.x + 10.0
