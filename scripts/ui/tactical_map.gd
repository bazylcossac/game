class_name TacticalMap
extends Control
## Vector map of the city, used as the rotating minimap and the deploy-screen map.

signal flag_clicked(idx: int)

const MINI_RANGE := 74.0
const STREET_COLOR := Color(1, 1, 1, 0.06)
const BUILDING_COLOR := Color(0.62, 0.66, 0.7, 0.3)
const LANDMARK_COLOR := Color(0.78, 0.74, 0.62, 0.42)
const COVER_COLOR := Color(0.62, 0.66, 0.7, 0.18)

var world: World
var mini := true
var selected_flag := -1

var _streets: Array[Rect2] = []
var _full_range := 232.0
var _polys: Array[PackedVector2Array] = []
var _colors: Array[Color] = []
var _redraw_t := 0.0
## Everything that never moves, as a single mesh: the rotating minimap redraws it every frame.
var _static := ArrayMesh.new()
const NOTHING := -99
var _hot := NOTHING


func setup(w: World, is_mini: bool) -> void:
	world = w
	mini = is_mini
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE if mini else Control.MOUSE_FILTER_STOP
	_streets = world.map.street_rects()
	_full_range = world.map.view_range()
	for f: Dictionary in world.map.b.footprints:
		var c: Vector2 = f["center"]
		var size: Vector2 = f["size"]
		var yaw: float = f["yaw"]
		var h := size * 0.5
		var poly := PackedVector2Array()
		for corner: Vector2 in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
			poly.append(c + Vector2(corner.x * cos(yaw) + corner.y * sin(yaw), -corner.x * sin(yaw) + corner.y * cos(yaw)))
		_polys.append(poly)
		match f["kind"]:
			"landmark": _colors.append(LANDMARK_COLOR)
			"cover", "wire": _colors.append(COVER_COLOR)
			"canopy": _colors.append(Color(0.62, 0.66, 0.7, 0.14))
			_: _colors.append(BUILDING_COLOR)
	_bake_static()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_redraw_t += delta
	if mini or _redraw_t >= 1.0 / 20.0:
		_redraw_t = 0.0
		queue_redraw()


func _bake_static() -> void:
	var verts := PackedVector2Array()
	var tints := PackedColorArray()
	var quad := func(p: PackedVector2Array, tint: Color) -> void:
		for i: int in [0, 1, 2, 0, 2, 3]:
			verts.append(p[i])
			tints.append(tint)
	for r: Rect2 in _streets:
		quad.call(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]), STREET_COLOR)
	for i in _polys.size():
		quad.call(_polys[i], _colors[i])
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = tints
	_static.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)


func _map_transform() -> Transform2D:
	var c := size * 0.5
	if mini and world.local != null:
		var s := minf(size.x, size.y) * 0.5 / MINI_RANGE
		# Between physics steps, the way the camera moves, or the map would judder against the view.
		var me := world.local
		var p := me._prev_pos.lerp(me._cur_pos, Engine.get_physics_interpolation_fraction())
		return Transform2D(0.0, c) * Transform2D(world.local.yaw, Vector2.ZERO) * Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2(-p.x, -p.z))
	var fs := minf(size.x, size.y) * 0.5 / _full_range
	return Transform2D(0.0, c) * Transform2D(0.0, Vector2(fs, fs), 0.0, Vector2.ZERO)


func _draw() -> void:
	if world == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.05, 0.82))
	var t := _map_transform()
	draw_set_transform_matrix(t)
	if _static.get_surface_count() > 0:
		draw_mesh(_static, null)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_bases(t)
	_draw_flags(t)
	_draw_beacon(t)
	_draw_soldiers(t)
	if mini:
		var c := size * 0.5
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(6.5, 7), c + Vector2(-6.5, 7)]), UiKit.INK)
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.LINE, false, 1.0)


func _my_team() -> int:
	return world.local.team if world.local else C.Team.RESISTANCE


func _draw_bases(t: Transform2D) -> void:
	if world.ffa:
		return
	# The safe zones, on every map: a soft ring round each home.
	for team in world.safe_zones.size():
		var zone: Array = world.safe_zones[team]
		var center: Vector3 = zone[0]
		var col: Color = C.TEAM_COLORS[team]
		var radius := float(zone[1]) * t.get_scale().x
		var p := t * Vector2(center.x, center.z)
		draw_circle(p, radius, Color(col.r, col.g, col.b, 0.07))
		draw_arc(p, radius, 0, TAU, 48, Color(col.r, col.g, col.b, 0.45), 1.5, true)
	if mini:
		return
	var f := UiKit.font("bold")
	for team in 2:
		var b := world.home_of(team)
		var p := t * Vector2(b.x, b.z)
		var col: Color = C.TEAM_COLORS[team]
		var r := Rect2(p - Vector2(46, 15), Vector2(92, 30))
		var hot := _hot == -1 and team == _my_team()
		var chosen := selected_flag == -1 and team == _my_team()
		draw_rect(r, Color(col.r, col.g, col.b, 0.34 if (hot or chosen) else 0.14))
		draw_rect(r, col, false, 2.0 if chosen else 1.0)
		draw_string(f, r.position + Vector2(0, 22), T.t("BAZA"), HORIZONTAL_ALIGNMENT_CENTER, 92, 20, col)


func _draw_flags(t: Transform2D) -> void:
	var f := UiKit.font("bold")
	var r := 12.0 if mini else 19.0
	for i in world.flags.size():
		var fl: Dictionary = world.flags[i]
		var pos: Vector3 = fl["pos"]
		var p := t * Vector2(pos.x, pos.z)
		if mini:
			var half := size * 0.5
			var off := p - half
			var lim := minf(half.x, half.y) - 14.0
			if off.length() > lim:
				p = half + off.normalized() * lim
		var col := C.team_color(fl["owner"])
		var value: float = fl["value"]
		draw_circle(p, r, Color(0.03, 0.035, 0.05, 0.9))
		draw_arc(p, r, 0, TAU, 32, Color(col.r, col.g, col.b, 0.5), 2.0, true)
		var lean := C.team_color(0 if value < 0.0 else 1)
		draw_arc(p, r, -PI * 0.5, -PI * 0.5 + TAU * absf(value), 32, lean, 3.0, true)
		if not mini and i == selected_flag:
			draw_arc(p, r + 7.0, 0, TAU, 32, UiKit.BRASS, 2.0, true)
		elif not mini and i == _hot:
			draw_arc(p, r + 6.0, 0, TAU, 32, Color(1, 1, 1, 0.5), 1.5, true)
		var fs := 18 if mini else 26
		draw_string(f, p + Vector2(-r, fs * 0.36), fl["letter"], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, col)
		if not mini:
			draw_string(UiKit.font("semibold"), p + Vector2(-70, r + 21), T.t(String(fl["name"])).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 140, 18, UiKit.MUTED)


## Pins a point to the edge of the round minimap when it lies out of range.
func _pin(p: Vector2, margin: float) -> Vector2:
	if not mini:
		return p
	var half := size * 0.5
	var off := p - half
	var lim := minf(half.x, half.y) - margin
	return half + off.normalized() * lim if off.length() > lim else p


## The player's own squad beacon: a place to come in, and only for that squad.
func _beacon_at() -> Variant:
	if world.local == null or world.ffa:
		return null
	return world.squads.beacon_pos(world.squads.squad_of(world.local.sid))


func _draw_beacon(t: Transform2D) -> void:
	var pos: Variant = _beacon_at()
	if pos == null:
		return
	var at := pos as Vector3
	var p := _pin(t * Vector2(at.x, at.z), 14.0)
	var r := 11.0 if mini else 17.0
	var chosen := selected_flag == C.SPAWN_BEACON
	var col := UiKit.BRASS if chosen or _hot == C.SPAWN_BEACON else UiKit.GREEN
	var diamond := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r)])
	draw_colored_polygon(diamond, Color(0.03, 0.035, 0.05, 0.9))
	draw_polyline(diamond, col, 3.0 if chosen else 2.0, true)
	draw_circle(p, r * 0.3, col)


func _draw_soldiers(t: Transform2D) -> void:
	var me := world.local
	if me == null:
		return
	var now := Net.server_time()
	for id: int in world.coins:
		var c: Vector3 = world.coins[id]["pos"]
		var cp := t * Vector2(c.x, c.z)
		if mini:
			var half := size * 0.5
			var off := cp - half
			var lim := minf(half.x, half.y) - 8.0
			if off.length() > lim:
				cp = half + off.normalized() * lim
		draw_circle(cp, 6.0, Color(0.03, 0.035, 0.05, 0.9))
		draw_circle(cp, 4.0, UiKit.BRASS)
	for id: int in world.vehicles:
		var v: Dictionary = world.vehicles[id]
		if v["team"] == me.team and v["driver"] == 0 and float(v["hp"]) > 0.0:
			var vp: Vector3 = v["pos"]
			var q := t * Vector2(vp.x, vp.z)
			draw_rect(Rect2(q - Vector2(5, 5), Vector2(10, 10)), Color(0.03, 0.035, 0.05, 0.9))
			draw_rect(Rect2(q - Vector2(5, 5), Vector2(10, 10)), C.TEAM_COLORS[me.team], false, 2.0)
	for s: Soldier in world.soldiers.values():
		if not s.alive or s == me:
			continue
		var p := t * Vector2(s.global_position.x, s.global_position.z)
		var col := world.side_color(s)
		if s.is_vehicle() and (s.team == me.team or p.distance_to(t * Vector2(me.global_position.x, me.global_position.z)) < 9999.0):
			draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), col)
		elif not world.are_foes(s, me):
			draw_circle(p, 3.5 if mini else 4.0, col)
		elif float(world.spotted.get(s.sid, 0.0)) > now or s.is_mech():
			draw_circle(p, 7.0 if s.is_mech() else 4.0, col)
	if not mini and me.alive:
		_draw_me(t * Vector2(me.global_position.x, me.global_position.z), me.yaw)


## The player on the big map: a cone where they look and an arrow along it.
func _draw_me(p: Vector2, yaw: float) -> void:
	var ahead := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(-ahead.y, ahead.x)
	var reach := 70.0
	var cone := PackedVector2Array([p])
	for i in 11:
		var a := lerpf(-0.55, 0.55, i / 10.0)
		cone.append(p + ahead.rotated(a) * reach)
	draw_colored_polygon(cone, Color(UiKit.BRASS, 0.22))
	draw_polyline(PackedVector2Array([cone[1], p, cone[cone.size() - 1]]), Color(UiKit.BRASS, 0.7), 1.5, true)
	var arrow := PackedVector2Array([p + ahead * 19.0, p - ahead * 10.0 + side * 11.0, p - ahead * 4.0, p - ahead * 10.0 - side * 11.0])
	draw_colored_polygon(arrow, Color(0.03, 0.035, 0.05, 0.95))
	var inner := PackedVector2Array()
	for q: Vector2 in arrow:
		inner.append(p + (q - p) * 0.72)
	draw_colored_polygon(inner, UiKit.BRASS)


func _gui_input(event: InputEvent) -> void:
	if mini:
		return
	if event is InputEventMouseMotion:
		_hot = _pick((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var idx := _pick(mb.position)
			if idx != NOTHING:
				flag_clicked.emit(idx)


## Returns a flag index, -1 for the home base, C.SPAWN_BEACON, or NOTHING.
func _pick(pos: Vector2) -> int:
	var t := _map_transform()
	var beacon: Variant = _beacon_at()
	if beacon != null:
		var at := beacon as Vector3
		if (t * Vector2(at.x, at.z)).distance_to(pos) < 26.0:
			return C.SPAWN_BEACON
	for i in world.flags.size():
		var fp: Vector3 = world.flags[i]["pos"]
		if (t * Vector2(fp.x, fp.z)).distance_to(pos) < 28.0:
			return i
	var b := world.home_of(_my_team())
	if (t * Vector2(b.x, b.z)).distance_to(pos) < 50.0:
		return -1
	return NOTHING
