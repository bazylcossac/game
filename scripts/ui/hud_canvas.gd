class_name HudCanvas
extends Control
## Everything drawn directly over the game view, redrawn every frame.

const HIT_TIME := 0.32
const HIT_TIME_KILL := 0.55

var _shield_shown := 1.0
var _shield_flash := 0.0
var world: World
var killed_by: Soldier = null
var killed_with := -1
## Getting in or out of a vehicle: seconds left and the whole wait.
var _use_left := 0.0
var _use_total := 0.0
var death_t := 0.0
var flash_hurt := 0.0

var _feed: Array[Dictionary] = []
var _popups: Array[Dictionary] = []
var _hits: Array[Dictionary] = []
var _hit_t := 0.0
var _hit_kind := 0
var _banner := {}
var _big := {}
var _smooth_spread := 0.0
var _capture_tick := 0.0

var _f_bold: Font
var _f_semi: Font
var _f_med: Font
var _f_title: Font


var _odd_frame := false
static var _icons := {}


func _ready() -> void:
	_f_bold = UiKit.font("bold")
	_f_semi = UiKit.font("semibold")
	_f_med = UiKit.font("medium")
	_f_title = UiKit.font("title")


func add_kill(k: Soldier, v: Soldier, weapon_id: int, head: bool) -> void:
	var tag := T.t("OGIEŃ" if weapon_id == C.WEAPON_FIRE else ("GRANAT" if weapon_id < 0 else String(C.WEAPONS[weapon_id]["short"])))
	if weapon_id == C.WEAPON_RESPAWN:
		tag = T.t("ODRODZENIE")
	elif weapon_id == C.WEAPON_ADMIN:
		tag = "ADMIN"
	_feed.push_front({"k": k.pname if k else "", "kc": world.side_color(k) if k else UiKit.INK, "v": v.pname, "vc": world.side_color(v),
		"w": tag, "head": head, "t": 6.0,
		"mine": world.local != null and (k == world.local or v == world.local)})
	if _feed.size() > 6:
		_feed.pop_back()


func start_use(seconds: float) -> void:
	_use_left = seconds
	_use_total = seconds


func big_message(text: String, color: Color) -> void:
	_big = {"text": text, "color": color, "t": 2.2}


func banner(title: String, sub: String, color: Color) -> void:
	_banner = {"title": title, "sub": sub, "color": color, "t": 3.4}


func damage_from(pos: Vector3) -> void:
	_hits.append({"pos": pos, "t": 1.4})
	flash_hurt = 0.7


func hit_marker(kind: int) -> void:
	_hit_t = HIT_TIME_KILL if kind == 3 else HIT_TIME
	_hit_kind = kind
	match kind:
		1: Sfx.play("hitmarker", -6.0)
		2: Sfx.play("headshot", -5.0)
		3: Sfx.play("kill", -4.0)


func score_popup(points: int, reason: String) -> void:
	_popups.push_front({"text": "+%d  %s" % [points, T.t(reason)], "t": 2.6})
	if _popups.size() > 4:
		_popups.pop_back()


func _process(delta: float) -> void:
	if not visible:
		return
	for arr: Array in [_feed, _popups, _hits]:
		for i in range(arr.size() - 1, -1, -1):
			arr[i]["t"] -= delta
			if arr[i]["t"] <= 0.0:
				arr.remove_at(i)
	_hit_t = maxf(_hit_t - delta, 0.0)
	_use_left = maxf(_use_left - delta, 0.0)
	flash_hurt = maxf(flash_hurt - delta * 1.3, 0.0)
	death_t += delta
	if not _banner.is_empty():
		_banner["t"] -= delta
		if _banner["t"] <= 0.0:
			_banner = {}
	if not _big.is_empty():
		_big["t"] -= delta
		if _big["t"] <= 0.0:
			_big = {}
	# The HUD is hundreds of text and line calls. Above 100 fps every other frame is plenty.
	_odd_frame = not _odd_frame
	if _odd_frame and Engine.get_frames_per_second() >= 100.0:
		return
	queue_redraw()


func _draw() -> void:
	if Settings.show_fps:
		_text(_f_bold, Vector2(size.x - 130.0, 26.0), "%d FPS" % Engine.get_frames_per_second(), 22, UiKit.GREEN, HORIZONTAL_ALIGNMENT_RIGHT, 110.0)
	var c := world.controller
	var me := world.local
	var alive := me != null and me.alive
	if c.scoped:
		_draw_scope()
	if c.sighted:
		_draw_sight()
	if alive:
		_draw_world_markers()
	_draw_top_bar()
	_draw_killfeed()
	if alive and c.designating:
		_draw_designator(me)
	if alive:
		_draw_squad_panel(me)
		if not c.scoped and not c.designating:
			_draw_crosshair(c)
		_draw_hit_marker()
		_draw_damage_arcs()
		_draw_vitals(me)
		_draw_weapon_panel(me)
		_draw_capture_status(me)
		_draw_super_status(me)
		_draw_use_bar(me)
		_draw_test_modes(me)
		_draw_popups()
	elif me != null:
		_draw_death_card()
	_draw_banner()


func _text(font: Font, pos: Vector2, raw: String, size_px: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var s := T.t(raw)
	draw_string(font, pos + Vector2(1, 2), s, align, width, size_px, Color(0, 0, 0, color.a * 0.65))
	draw_string(font, pos, s, align, width, size_px, color)


func _draw_top_bar() -> void:
	if world.ffa:
		_draw_leader_bar()
		return
	var cx := size.x * 0.5
	var n := world.flags.size()
	var slot := 46.0
	var x0 := cx - (n - 1) * slot * 0.5
	var y := 46.0
	for i in n:
		var f: Dictionary = world.flags[i]
		var p := Vector2(x0 + i * slot, y)
		var col := C.team_color(f["owner"])
		var value: float = f["value"]
		var r := 18.0
		var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		draw_colored_polygon(pts, Color(0.04, 0.045, 0.06, 0.88))
		var lean := C.team_color(0 if value < 0.0 else 1)
		draw_colored_polygon(pts, Color(lean.r, lean.g, lean.b, 0.55 * absf(value)))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), col, 2.0, true)
		_text(_f_bold, p + Vector2(-18, 8), f["letter"], 22, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, 36)
	var bar_w := 210.0
	var gap := n * slot * 0.5 + 12.0
	for team in 2:
		var left := team == 0
		var x := cx - gap - bar_w if left else cx + gap
		var col: Color = C.TEAM_COLORS[team]
		var frac: float = float(world.tickets[team]) / world.score_limit
		draw_rect(Rect2(x, 36, bar_w, 8), Color(0, 0, 0, 0.5))
		var w := bar_w * clampf(frac, 0.0, 1.0)
		draw_rect(Rect2(x + (bar_w - w if left else 0.0), 36, w, 8), col)
		var num := str(world.tickets[team])
		_text(_f_title, Vector2(x, 30), num, 30, UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT, bar_w)
		_text(_f_semi, Vector2(x, 66), C.TEAM_SHORT[team], 20, col, HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT, bar_w)


## A free-for-all has no sides to show, so the bar shows the race to the kill limit.
func _draw_leader_bar() -> void:
	var cx := size.x * 0.5
	var leader: Soldier = null
	for s: Soldier in world.soldiers.values():
		if leader == null or s.kills > leader.kills:
			leader = s
	if leader == null:
		return
	var best := maxi(world.tickets[0], leader.kills)
	var bar_w := 320.0
	draw_rect(Rect2(cx - bar_w * 0.5, 36, bar_w, 8), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(cx - bar_w * 0.5, 36, bar_w * clampf(float(best) / world.score_limit, 0.0, 1.0), 8), UiKit.RED)
	_text(_f_semi, Vector2(cx - 300, 30), T.t("PROWADZI: %s") % leader.pname, 22, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, 600)
	_text(_f_title, Vector2(cx - 300, 72), "%d / %d" % [best, world.score_limit], 28, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, 600)
	if world.local != null:
		_text(_f_semi, Vector2(cx - 300, 98), T.t("TY: %d") % world.local.kills, 22, UiKit.BRASS, HORIZONTAL_ALIGNMENT_CENTER, 600)


func _draw_killfeed() -> void:
	var y := 40.0
	var right := size.x - 30.0
	for e: Dictionary in _feed:
		var a := clampf(float(e["t"]), 0.0, 1.0)
		var kn: String = e["k"]
		var vn: String = e["v"]
		var w: String = "  [" + String(e["w"]) + ("  ★" if e["head"] else "") + "]  "
		var fs := 22
		var vw := _f_semi.get_string_size(vn, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ww := _f_med.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var kw := _f_semi.get_string_size(kn, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var total := vw + ww + kw
		var x := right - total
		if e["mine"]:
			draw_rect(Rect2(x - 10, y - 21, total + 20, 28), Color(0.95, 0.71, 0.3, 0.16 * a))
		var kc: Color = e["kc"]
		var vc: Color = e["vc"]
		_text(_f_semi, Vector2(x, y), kn, fs, Color(kc.r, kc.g, kc.b, a))
		_text(_f_med, Vector2(x + kw, y), w, fs, Color(0.8, 0.8, 0.8, a))
		_text(_f_semi, Vector2(x + kw + ww, y), vn, fs, Color(vc.r, vc.g, vc.b, a))
		y += 31.0


func _draw_crosshair(c: PlayerController) -> void:
	var s: Soldier = world.local
	var center := size * 0.5
	var col := Color(0.95, 0.96, 0.92, 0.9)
	if s.weapon().get("shield", false):
		_draw_shield_gauge(s, center)
		return
	if s.is_melee():
		draw_arc(center, 9.0, 0, TAU, 28, col, 1.6, true)
		draw_circle(center, 1.4, col)
		if s.blocking:
			draw_arc(center, 24.0, -2.4, -0.74, 24, UiKit.BLUE, 3.0, true)
		return
	if c.vm.ads > 0.8 and not s.weapon().get("no_sights", false):
		draw_circle(center, 2.6, Color(0, 0, 0, 0.55))
		draw_circle(center, 1.7, col)
		return
	# Four arms round an open middle, so the target stays visible, with a dot on the exact point.
	var target_gap := 9.0 + c.current_spread() * tan(deg_to_rad(1.0)) * size.y / (2.0 * tan(deg_to_rad(c.camera.fov * 0.5)))
	_smooth_spread = lerpf(_smooth_spread, target_gap, 0.3)
	var g := _smooth_spread
	var l := 10.0
	var shade := Color(0, 0, 0, 0.55)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(center + d * (g - 1.0), center + d * (g + l + 1.0), shade, 4.0)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(center + d * g, center + d * (g + l), col, 2.0)
	draw_circle(center, 2.4, shade)
	draw_circle(center, 1.5, col)


## The shield's health right under the crosshair, where the eyes already are: an arc that drains
## and a number, blue while it holds, red when it is about to go, and a flash on every hit.
func _draw_shield_gauge(s: Soldier, center: Vector2) -> void:
	var frac := clampf(s.shield / C.SHIELD_HP, 0.0, 1.0)
	if frac < _shield_shown - 0.001:
		_shield_flash = 1.0
	_shield_shown = frac
	_shield_flash = maxf(_shield_flash - get_process_delta_time() * 4.0, 0.0)
	var col: Color = UiKit.BLUE if frac > 0.3 else UiKit.RED
	var lit := col.lerp(Color.WHITE, _shield_flash * 0.7)
	var r := 52.0 + _shield_flash * 4.0
	var from := PI * 0.5 + 1.1
	var to := PI * 0.5 - 1.1
	draw_arc(center, r, from, to, 48, Color(0, 0, 0, 0.6), 12.0, true)
	draw_arc(center, r, from, from + (to - from) * frac, 48, lit, 8.0, true)
	draw_circle(center, 2.4, Color(0, 0, 0, 0.55))
	draw_circle(center, 1.5, Color(0.95, 0.96, 0.92, 0.9))


## A cross that snaps open and settles: white for a hit, gold for the head, red for a kill.
func _draw_hit_marker() -> void:
	if _hit_t <= 0.0:
		return
	var c := size * 0.5
	var kill := _hit_kind == 3
	var total := HIT_TIME_KILL if kill else HIT_TIME
	var left := _hit_t / total
	var pop := pow(left, 3.0)
	var col := Color(1, 1, 1) if _hit_kind == 1 else (Color(1.0, 0.8, 0.25) if _hit_kind == 2 else Color(1.0, 0.22, 0.14))
	col.a = minf(left * 2.4, 1.0)
	var gap := (15.0 if kill else 12.0) + pop * 9.0
	var arm := 17.0 if kill else 13.0
	var width := 4.0 if kill else 3.0
	var shade := Color(0, 0, 0, col.a * 0.6)
	for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n := d.normalized()
		draw_line(c + n * (gap - 1.0), c + n * (gap + arm + 1.0), shade, width + 2.0, true)
		draw_line(c + n * gap, c + n * (gap + arm), col, width, true)
	if kill:
		draw_arc(c, gap + arm + 7.0 - pop * 8.0, 0.0, TAU, 40, Color(col, col.a * 0.7), 2.0, true)


func _draw_damage_arcs() -> void:
	var c := size * 0.5
	var cam := world.controller.camera
	for h: Dictionary in _hits:
		var to: Vector3 = h["pos"] - cam.global_position
		var fwd := -cam.global_transform.basis.z
		var right := cam.global_transform.basis.x
		var ang := atan2(to.dot(right), to.dot(Vector3(fwd.x, 0, fwd.z).normalized()))
		var a := clampf(float(h["t"]), 0.0, 1.0)
		var mid := ang - PI * 0.5
		draw_arc(c, 150.0, mid - 0.42, mid + 0.42, 22, Color(1.0, 0.16, 0.1, a * 0.85), 11.0, true)


func _draw_vitals(s: Soldier) -> void:
	var x := 28.0
	var y := size.y - 74.0
	var w := 260.0
	var frac := clampf(s.hp / s.max_hp, 0.0, 1.0)
	var col := UiKit.INK if frac > 0.35 else UiKit.RED
	draw_rect(Rect2(x, y, w, 46), UiKit.PANEL_SOFT)
	_text(_f_title, Vector2(x + 12, y + 37), str(int(ceil(s.hp))), 34, col)
	var bar_x := x + 76
	var bar_w := w - 90
	draw_rect(Rect2(bar_x, y + 12, bar_w, 9), Color(1, 1, 1, 0.1))
	draw_rect(Rect2(bar_x, y + 12, bar_w * frac, 9), col)
	draw_rect(Rect2(bar_x, y + 28, bar_w, 4), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(bar_x, y + 28, bar_w * (s.stamina / s.stamina_max), 4), UiKit.RED if s.exhausted else UiKit.BRASS)
	if s.has_shield():
		draw_rect(Rect2(bar_x, y + 36, bar_w, 4), Color(1, 1, 1, 0.08))
		draw_rect(Rect2(bar_x, y + 36, bar_w * s.shield / C.SHIELD_HP, 4), UiKit.BLUE if s.shield_ready else UiKit.RED)
		if not s.shield_ready:
			_text(_f_semi, Vector2(x, y - 10), "TARCZA SIĘ ŁADUJE", 18, UiKit.RED)
	if s.protected_t > 0.0:
		_text(_f_semi, Vector2(x, y - 276), "OCHRONA PO ODRODZENIU", 20, UiKit.BLUE)
	if world.in_safe_zone(s.global_position, s.team):
		_text(_f_semi, Vector2(x, y - 300), "STREFA BEZPIECZNA: NIKT CIĘ TU NIE ZRANI", 20, UiKit.GREEN)


## A bar under the crosshair while getting in or out of a vehicle.
func _draw_use_bar(s: Soldier) -> void:
	if _use_left <= 0.0 or _use_total <= 0.0:
		return
	var w := 260.0
	var at := Vector2(size.x * 0.5 - w * 0.5, size.y * 0.5 + 110.0)
	var leaving: bool = s.vehicle_id >= 0 or s.riding >= 0
	var label := "WYSIADANIE" if leaving else "WSIADANIE"
	_text(_f_semi, at + Vector2(0, -8), label, 20, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, w)
	draw_rect(Rect2(at, Vector2(w, 8)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(at, Vector2(w * (1.0 - _use_left / _use_total), 8)), UiKit.BRASS)
	_text(_f_med, at + Vector2(0, 30), "E: przerwij" if leaving else "X: przerwij", 18, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)


## What the admin panel has switched on, so nobody forgets they cannot die.
func _draw_test_modes(s: Soldier) -> void:
	var on := PackedStringArray()
	if s.god:
		on.append(T.t("NIEŚMIERTELNOŚĆ"))
	if s.noclip:
		on.append("NOCLIP")
	if s.inf_ammo:
		on.append(T.t("NIESKOŃCZONA AMUNICJA"))
	if world.bots_frozen:
		on.append(T.t("BOTY ZAMROŻONE"))
	if on.is_empty():
		return
	_text(_f_semi, Vector2(28, size.y - 112), T.t("TRYB TESTOWY: %s") % "  ·  ".join(on), 20, UiKit.BRASS)


## The white outline of a gun, from tools run through --test=weapon-icons. Null for vehicle guns.
static func weapon_icon(id: int, team: int) -> Texture2D:
	var path := "res://assets/textures/weapons/%s_%d.png" % [String(C.W.find_key(id)).to_lower(), team]
	# Held here, because a canvas keeps only a texture's id and draws white once the texture is freed.
	if not _icons.has(path):
		_icons[path] = load(path) if ResourceLoader.exists(path) else null
	return _icons[path]


func _draw_weapon_panel(s: Soldier) -> void:
	var w := s.weapon()
	var right := size.x - 30.0
	var y := size.y - 34.0
	var name_text: String = T.t(String(w["name"])).to_upper()
	if w.get("shield", false):
		var charge := int(round(s.shield / C.SHIELD_HP * 100.0))
		_text(_f_title, Vector2(right - 300, y - 12), "%d%%" % charge, 52, UiKit.BLUE if charge > 25 else UiKit.RED, HORIZONTAL_ALIGNMENT_RIGHT, 300)
		_text(_f_semi, Vector2(right - 460, y + 14), "TARCZA ZATRZYMUJE STRZAŁY Z PRZODU", 20, UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 460)
	elif w["melee"]:
		_text(_f_title, Vector2(right - 300, y - 12), w["short"], 44, UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT, 300)
		var hint := "PPM — BLOK, ODBIJA LASERY" if C.is_blade(s.weapon_id()) else name_text
		_text(_f_semi, Vector2(right - 400, y + 14), hint, 20, UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 400)
	else:
		var mag: int = s.mags[s.slot]
		var low: bool = mag <= int(w["mag"]) / 4
		var mag_text := str(mag)
		var res_text := str(s.reserves[s.slot])
		var res_w := _f_semi.get_string_size(res_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		_text(_f_semi, Vector2(right - res_w, y - 12), res_text, 30, UiKit.MUTED)
		_text(_f_title, Vector2(right - res_w - 220, y - 12), mag_text, 58, UiKit.RED if low else UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT, 208)
		_text(_f_semi, Vector2(right - 400, y + 14), name_text, 20, UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 400)
		if s.reload_t > 0.0:
			var c := size * 0.5
			var p: float = 1.0 - s.reload_t / float(w["reload"])
			draw_arc(c, 30.0, -PI * 0.5, -PI * 0.5 + TAU * p, 40, UiKit.BRASS, 3.0, true)
			_text(_f_semi, c + Vector2(-100, 60), "PRZEŁADOWANIE", 20, UiKit.BRASS, HORIZONTAL_ALIGNMENT_CENTER, 200)
		elif mag == 0:
			_text(_f_semi, size * 0.5 + Vector2(-100, 60), "BRAK ENERGII", 22, UiKit.RED, HORIZONTAL_ALIGNMENT_CENTER, 200)
	# Slots with a picture of each weapon, then grenades.
	var slot_w := 112.0
	var sx := right - slot_w * s.loadout.size()
	var sy := y - 86.0
	for i in s.loadout.size():
		var active := i == s.slot
		var col := UiKit.BRASS if active else Color(0.86, 0.88, 0.9, 0.42)
		var at := Vector2(sx + i * slot_w, sy - 30.0)
		var icon := weapon_icon(s.loadout[i], s.team)
		if icon:
			draw_texture_rect(icon, Rect2(at + Vector2(12, 0), Vector2(94, 32)), false, col)
		else:
			_text(_f_bold, at + Vector2(16, 24), String(C.WEAPONS[s.loadout[i]]["short"]), 18, col)
		_text(_f_bold, at + Vector2(0, 16), str(i + 1), 17, col)
		if s.loadout[i] == C.W.ENERGY_SHIELD:
			# Its charge under the picture: blue when it can be taken out, red while it recovers.
			draw_rect(Rect2(at + Vector2(12, 39), Vector2(94, 4)), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(at + Vector2(12, 39), Vector2(94 * s.shield / C.SHIELD_HP, 4)), UiKit.BLUE if s.shield_ready else UiKit.RED)
		if active:
			draw_rect(Rect2(at + Vector2(0, 35), Vector2(slot_w - 6.0, 2)), UiKit.BRASS)
	sy -= 44.0
	if not s.is_vehicle() and not s.is_mech():
		var kinds: int = s.nades.reduce(func(sum: int, n: int) -> int: return sum + (1 if n > 0 else 0), 0)
		var held: int = s.nades[s.nade_kind]
		var line := "[G] %s  %d" % [T.t(C.NADE_NAMES[s.nade_kind]), held]
		_text(_f_semi, Vector2(right - 300, sy), line, 20, UiKit.BRASS if held > 0 else UiKit.FAINT, HORIZONTAL_ALIGNMENT_RIGHT, 300)
		if kinds > 1:
			var rest: Array[String] = []
			for kind in s.nades.size():
				if kind != s.nade_kind and s.nades[kind] > 0:
					rest.append("%s %d" % [T.t(C.NADE_NAMES[kind]), s.nades[kind]])
			_text(_f_semi, Vector2(right - 300, sy - 22), "[H] " + "  ·  ".join(rest), 17, UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 300)


## Coin prompt, the super class picker, its timer, and class ability readouts.
func _draw_super_status(s: Soldier) -> void:
	var cx := size.x * 0.5
	var cd := s.class_data()
	if cd.get("builder", false):
		var kind := world.controller.build_kind
		var selected := "[V] WYBIERZ FORTYFIKACJĘ" if kind < 0 else T.t("[V] %s (%d)  ·  [T] BUDUJ") % [T.t(Fortifications.DEFS[kind]["name"]).to_upper(), Fortifications.DEFS[kind]["cost"]]
		_text(_f_bold, Vector2(0, size.y - 146), T.t("%s  ·  MATERIAŁY %d/100") % [T.t(selected), world.forts.local_materials], 22, UiKit.BRASS, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		if world.forts.local_progress > 0:
			draw_rect(Rect2(cx - 150, size.y - 130, 300 * world.forts.local_progress, 5), UiKit.BRASS)
	if cd.get("command", false) and world.squads.leads(s):
		var squad := world.squads.squad_of(s.sid)
		var wait := float(squad["next_strike"]) - Net.server_time()
		var ready := wait <= 0.0 and float(squad["charge"]) >= 100.0
		var strike := "[Y] ARTYLERIA GOTOWA" if ready else (T.t("[Y] ARTYLERIA %d%%") % int(squad["charge"]) if wait <= 0.0 else T.t("[Y] ARTYLERIA ZA %d s") % int(ceil(wait)))
		var beacon := "[T] PUNKT ODRODZENIA" if world.squads.beacon_pos(squad) == null else "[T] PRZENIEŚ PUNKT"
		_text(_f_bold, Vector2(0, size.y - 146), "%s  ·  %s" % [strike, beacon], 22, UiKit.BRASS, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		draw_rect(Rect2(cx - 150, size.y - 130, 300, 5), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(cx - 150, size.y - 130, 300 * float(squad["charge"]) / 100.0, 5), UiKit.BRASS if not ready else UiKit.GREEN)
	if s.riding >= 0:
		_text(_f_bold, Vector2(0, size.y - 146.0), "PASAŻER · [X] ZMIANA MIEJSCA · [E] WYSIADKA", 22, UiKit.BRASS, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if s.is_vehicle():
		var way_out := "" if world.mode.get("tanks_only", false) else T.t("  ·  E WYSIADKA")
		var role := "STRZELEC / DZIAŁKO WIEŻOWE" if s.is_gunner() else "KIEROWCA / DZIAŁO · [2] DZIAŁKO · W/S NAPĘD · A/D SKRĘT"
		if s.on_roof_gun() and not s.is_gunner():
			role = "DZIAŁKO · DZIAŁO ZABLOKOWANE · [1] POWRÓT · W/S NAPĘD · A/D SKRĘT"
		elif world.roof_taken(s):
			role = "KIEROWCA / DZIAŁO · W/S NAPĘD · A/D SKRĘT"
		if not s.class_data().get("apc", false):
			_draw_hull_gauge(s)
			role = "%s · %s" % [T.t(role), T.t("[N] TERMOWIZJA")]
		if s.class_data().get("apc", false):
			_text(_f_bold, Vector2(0, size.y - 146.0), T.t("KIEROWCA · W/S NAPĘD · A/D SKRĘT") + way_out, 22, UiKit.BRASS, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		else:
			_text(_f_bold, Vector2(0, size.y - 146.0), T.t("%s · [X] ZMIANA MIEJSCA%s") % [T.t(role), way_out], 22, UiKit.BRASS, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		return
	if not s.is_super() and s.riding < 0:
		var server := world.vehicles
		for id: int in server:
			var v: Dictionary = server[id]
			var carrier: bool = v.get("kind", 0) == 1
			var room: bool = world.has_room(v)
			if v["team"] == s.team and room and float(v["hp"]) > 0.0 and s.global_position.distance_to(v["pos"]) < C.TANK_ENTER_RANGE:
				_text(_f_bold, Vector2(0, size.y - 182.0), T.t("[X] WSIADAJ: ") + T.t("KIEROWCA" if v["driver"] == 0 else ("STRZELEC DACHOWY" if not carrier and v.get("gunner", 0) == 0 else "PASAŻER")), 26, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, size.x)
				break
	if s.is_super():
		var w := 300.0
		var x := cx - w * 0.5
		var y := size.y - 150.0
		var frac: float = clampf(s.super_t / float(cd["duration"]), 0.0, 1.0)
		_text(_f_bold, Vector2(x, y - 8), "%s  %d s" % [T.t(String(cd["name"])).to_upper(), int(ceil(s.super_t))], 24, UiKit.BRASS if s.super_t > 10.0 else UiKit.RED, HORIZONTAL_ALIGNMENT_CENTER, w)
		draw_rect(Rect2(x, y, w, 7), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(x, y, w * frac, 7), UiKit.BRASS if s.super_t > 10.0 else UiKit.RED)
		if cd.get("jetpack", false):
			draw_rect(Rect2(x, y + 12, w, 5), Color(0, 0, 0, 0.55))
			draw_rect(Rect2(x, y + 12, w * (s.jet_fuel / C.JET_FUEL), 5), UiKit.BLUE)
			_text(_f_semi, Vector2(x, y + 40), "SPACJA — LOT", 19, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)
	elif s.coins > 0:
		if world.controller.picker_open:
			_draw_picker(s)
		else:
			_text(_f_bold, Vector2(0, size.y - 146.0), "MONETA  ·  [B] SUPERKLASA", 26, UiKit.BRASS, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if s.hp < s.max_hp and not s.is_super():
		for o: Soldier in world.soldiers.values():
			if o.alive and not world.are_foes(o, s) and o.class_data().get("healer", false) and o.global_position.distance_to(s.global_position) < C.HEAL_RADIUS:
				_text(_f_semi, Vector2(28, size.y - 82.0), "LECZENIE", 20, Color(0.45, 1.0, 0.6))
				break


## Binoculars: a range scale, the blast area on screen, and why the leader may not fire yet.
func _draw_designator(s: Soldier) -> void:
	var c := world.controller
	var centre := size * 0.5
	var point: Vector3 = c.strike_point()
	var problem := "Brak celu." if not point.is_finite() else world.squads.strike_problem(s, point)
	var col := UiKit.GREEN if problem == "" else UiKit.RED
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.18))
	draw_arc(centre, 44, 0, TAU, 48, col, 2.0, true)
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(centre + dir * 52, centre + dir * 120, col, 2.0)
	var reach := "---" if not point.is_finite() else "%d m" % int(s.global_position.distance_to(point))
	_text(_f_bold, Vector2(0, centre.y + 140), reach, 30, col, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_text(_f_semi, Vector2(0, centre.y + 176), "LPM: WEZWIJ OSTRZAŁ  ·  PPM: ANULUJ" if problem == "" else problem, 22, col, HORIZONTAL_ALIGNMENT_CENTER, size.x)


## Who is in the squad, under the score bar, and the state of its beacon.
func _draw_squad_panel(s: Soldier) -> void:
	var squad := world.squads.squad_of(s.sid)
	if squad.is_empty():
		return
	var x := 24.0
	var y := 120.0
	_text(_f_bold, Vector2(x, y), T.t("ODDZIAŁ %s") % T.t(String(squad["name"])).to_upper(), 22, UiKit.BRASS)
	for sid: int in squad["members"]:
		y += 24.0
		var m: Soldier = world.soldiers.get(sid)
		if m:
			var mark := "★ " if int(squad["leader"]) == sid else "   "
			_text(_f_semi, Vector2(x, y), mark + m.pname, 20, UiKit.INK if m.alive else UiKit.MUTED)
	var pos: Variant = world.squads.beacon_pos(squad)
	if pos != null:
		_text(_f_semi, Vector2(x, y + 26.0), T.t("PUNKT ODRODZENIA: %d m") % int(s.global_position.distance_to(pos)), 19, UiKit.BRASS)


func _draw_picker(s: Soldier) -> void:
	var cw := 340.0
	var ch := 138.0
	var gap := 18.0
	var y := size.y - 330.0
	for i in 2:
		var x := size.x * 0.5 - cw - gap * 0.5 + i * (cw + gap)
		var cd := C.cls(s.team, C.SUPER_MECH + i)
		draw_rect(Rect2(x, y, cw, ch), Color(0.03, 0.035, 0.05, 0.9))
		draw_rect(Rect2(x, y, cw, ch), UiKit.BRASS, false, 1.5)
		_text(_f_title, Vector2(x + 14, y + 40), str(i + 1), 32, UiKit.BRASS)
		_text(_f_bold, Vector2(x + 46, y + 36), T.t(String(cd["name"])).to_upper(), 30, UiKit.INK)
		var line := T.t("%d s  ·  %d zdrowia") % [int(cd["duration"]), int(cd["hp"])]
		_text(_f_semi, Vector2(x + 14, y + 62), line, 20, UiKit.BRASS)
		draw_multiline_string(_f_med, Vector2(x + 14, y + 84), T.t(cd["desc"]), HORIZONTAL_ALIGNMENT_LEFT, cw - 26, 18, 3, UiKit.MUTED)
	_text(_f_semi, Vector2(0, y - 12), "WYBIERZ SUPERKLASĘ: 1 LUB 2  ·  B ANULUJE", 22, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_capture_status(s: Soldier) -> void:
	for i in world.flags.size():
		var f: Dictionary = world.flags[i]
		var p: Vector3 = f["pos"]
		if Vector2(s.global_position.x - p.x, s.global_position.z - p.z).length() >= C.FLAG_RADIUS:
			continue
		var value: float = f["value"]
		var mine := -value if s.team == 0 else value  # 1.0 means fully ours
		if mine >= 0.999:
			return
		var cx := size.x * 0.5
		var y := 100.0
		var w := 340.0
		var title := T.t("ZDOBYWANIE: %s") % T.t(String(f["name"])).to_upper() if mine > -0.999 else T.t("PRZEJMOWANIE: %s") % T.t(String(f["name"])).to_upper()
		_text(_f_bold, Vector2(cx - w * 0.5, y), title, 26, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, w)
		draw_rect(Rect2(cx - w * 0.5, y + 10, w, 10), Color(0, 0, 0, 0.55))
		var progress := (mine + 1.0) * 0.5
		draw_rect(Rect2(cx - w * 0.5, y + 10, w * progress, 10), C.TEAM_COLORS[s.team])
		draw_rect(Rect2(cx - 1, y + 7, 2, 16), UiKit.INK)
		return


func _marker(pos: Vector3, letter: String, col: Color) -> void:
	var cam := world.controller.camera
	if cam.is_position_behind(pos):
		return
	var p := cam.unproject_position(pos) * (size / get_viewport_rect().size)
	p = p.clamp(Vector2(40, 110), size - Vector2(40, 120))
	var r := 15.0
	var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r)])
	draw_colored_polygon(pts.slice(0, 4), Color(0.04, 0.045, 0.06, 0.62))
	draw_polyline(pts, col, 2.0, true)
	_text(_f_bold, p + Vector2(-15, 7), letter, 19, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, 30)
	_text(_f_semi, p + Vector2(-30, r + 16), "%d m" % int(cam.global_position.distance_to(pos)), 17, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 60)


func _draw_world_markers() -> void:
	var cam := world.controller.camera
	var me := world.local
	var f := _f_bold
	for i in world.flags.size():
		var fl: Dictionary = world.flags[i]
		var pos: Vector3 = fl["pos"] + Vector3.UP * 4.0
		if cam.is_position_behind(pos):
			continue
		var p := cam.unproject_position(pos)
		p = p * (size / get_viewport_rect().size)
		p = p.clamp(Vector2(40, 110), size - Vector2(40, 120))
		var col := C.team_color(fl["owner"])
		var r := 15.0
		var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r)])
		draw_colored_polygon(pts.slice(0, 4), Color(0.04, 0.045, 0.06, 0.62))
		draw_polyline(pts, col, 2.0, true)
		_text(f, p + Vector2(-15, 7), fl["letter"], 19, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, 30)
		var d := int(cam.global_position.distance_to(pos))
		_text(_f_semi, p + Vector2(-30, r + 16), "%d m" % d, 17, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 60)
	for id: int in world.coins:
		var pos: Vector3 = world.coins[id]["pos"] + Vector3.UP * 2.0
		if cam.is_position_behind(pos):
			continue
		var p := cam.unproject_position(pos) * (size / get_viewport_rect().size)
		p = p.clamp(Vector2(40, 110), size - Vector2(40, 120))
		draw_circle(p, 12.0, Color(0.04, 0.045, 0.06, 0.7))
		draw_arc(p, 12.0, 0, TAU, 24, UiKit.BRASS, 2.0, true)
		draw_circle(p, 5.0, UiKit.BRASS)
		_text(_f_semi, p + Vector2(-30, 28), "%d m" % int(cam.global_position.distance_to(pos)), 17, UiKit.BRASS, HORIZONTAL_ALIGNMENT_CENTER, 60)
	var my_squad := world.squads.squad_of(me.sid)
	var beacon: Variant = world.squads.beacon_pos(my_squad)
	if beacon != null:
		_marker((beacon as Vector3) + Vector3.UP * 2.6, "+", UiKit.GREEN)
	for s: Soldier in world.soldiers.values():
		if not s.alive or s == me or world.are_foes(s, me):
			continue
		var pos := s.global_position + Vector3.UP * (s.stance_height() + 0.3)
		var dist := cam.global_position.distance_to(pos)
		var mate := world.squads.same_squad(me, s)
		if (dist > 45.0 and not mate) or cam.is_position_behind(pos):
			continue
		var p := cam.unproject_position(pos) * (size / get_viewport_rect().size)
		if not Rect2(Vector2.ZERO, size).has_point(p):
			continue
		var a := clampf(1.3 - dist / 45.0, 0.25, 1.0)
		var col: Color = UiKit.GREEN if mate else C.TEAM_COLORS[s.team]
		if mate:
			a = maxf(a, 0.85)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -6), p + Vector2(6, -6), p + Vector2(0, 3)]), Color(col.r, col.g, col.b, a))
		if dist < 22.0 or mate:
			_text(_f_semi, p + Vector2(-80, -12), s.pname, 18, Color(col.r, col.g, col.b, a), HORIZONTAL_ALIGNMENT_CENTER, 160)


func _draw_popups() -> void:
	var y := size.y * 0.5 + 118.0
	for p: Dictionary in _popups:
		var a := clampf(float(p["t"]) * 1.5, 0.0, 1.0)
		_text(_f_bold, Vector2(0, y), p["text"], 26, Color(1.0, 0.86, 0.5, a), HORIZONTAL_ALIGNMENT_CENTER, size.x)
		y += 30.0
	if not _big.is_empty():
		var a := clampf(float(_big["t"]) * 1.5, 0.0, 1.0)
		var col: Color = _big["color"]
		_text(_f_bold, Vector2(0, size.y * 0.5 + 92.0), _big["text"], 28, Color(col.r, col.g, col.b, a), HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_banner() -> void:
	if _banner.is_empty():
		return
	var t: float = _banner["t"]
	var a := clampf(minf(t, 3.4 - t) * 3.0, 0.0, 1.0)
	var col: Color = _banner["color"]
	var y := 170.0
	var w := 520.0
	var x := size.x * 0.5 - w * 0.5
	draw_rect(Rect2(x, y, w, 76), Color(0.03, 0.035, 0.05, 0.74 * a))
	draw_rect(Rect2(x, y, w, 3), Color(col.r, col.g, col.b, a))
	_text(_f_title, Vector2(x, y + 44), _banner["title"], 32, Color(col.r, col.g, col.b, a), HORIZONTAL_ALIGNMENT_CENTER, w)
	_text(_f_semi, Vector2(x, y + 68), _banner["sub"], 20, Color(1, 1, 1, 0.8 * a), HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_death_card() -> void:
	var cx := size.x * 0.5
	var y := size.y * 0.72
	var w := 520.0
	var a := clampf(death_t * 2.0, 0.0, 1.0)
	draw_rect(Rect2(cx - w * 0.5, y, w, 104), Color(0.03, 0.035, 0.05, 0.8 * a))
	draw_rect(Rect2(cx - w * 0.5, y, 4, 104), Color(1.0, 0.28, 0.2, a))
	if killed_with == C.WEAPON_RESPAWN:
		_text(_f_semi, Vector2(cx - w * 0.5, y + 30), "ODRODZENIE", 22, Color(1, 1, 1, 0.7 * a), HORIZONTAL_ALIGNMENT_CENTER, w)
		_text(_f_title, Vector2(cx - w * 0.5, y + 74), "ZARAZ WYBIERZESZ KLASĘ", 36, Color(UiKit.BRASS, a), HORIZONTAL_ALIGNMENT_CENTER, w)
		return
	_text(_f_semi, Vector2(cx - w * 0.5, y + 30), "ZOSTAŁEŚ WYELIMINOWANY", 22, Color(1, 1, 1, 0.7 * a), HORIZONTAL_ALIGNMENT_CENTER, w)
	var who := "Wybuch" if killed_by == null or not is_instance_valid(killed_by) else killed_by.pname
	var col := UiKit.RED if killed_by != null and is_instance_valid(killed_by) and world.are_foes(killed_by, world.local) else UiKit.INK
	_text(_f_title, Vector2(cx - w * 0.5, y + 72), who.to_upper(), 36, Color(col.r, col.g, col.b, a), HORIZONTAL_ALIGNMENT_CENTER, w)
	var wn: String = "Granat plazmowy" if killed_with < 0 else String(C.WEAPONS[killed_with]["name"])
	_text(_f_med, Vector2(cx - w * 0.5, y + 96), wn, 20, Color(1, 1, 1, 0.6 * a), HORIZONTAL_ALIGNMENT_CENTER, w)


## The rocket sight's reticle, with a bracket round every machine it can see.
## The sight of the rocket launcher and the main gun: a frame, a cross and what it is showing.
func _draw_sight() -> void:
	var c := size * 0.5
	var ink := Color(0.86, 0.95, 1.0, 0.85)
	var half := Vector2(size.y * 0.32, size.y * 0.22)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var at := c + half * corner
		draw_line(at, at - Vector2(corner.x * 60.0, 0), ink, 2.0)
		draw_line(at, at - Vector2(0, corner.y * 60.0), ink, 2.0)
	draw_line(c - Vector2(46, 0), c - Vector2(12, 0), ink, 1.5)
	draw_line(c + Vector2(12, 0), c + Vector2(46, 0), ink, 1.5)
	draw_line(c + Vector2(0, 12), c + Vector2(0, 46), ink, 1.5)
	var label := "[N] TERMOWIZJA" if world.controller.thermal else "[N] WIDOK NORMALNY"
	_text(_f_bold, Vector2(c.x - half.x, c.y - half.y - 16.0), label, 22, ink)


## Which way the hull points against the view, for anyone looking out of a tank.
func _draw_hull_gauge(s: Soldier) -> void:
	var c := Vector2(350.0, size.y - 60.0)
	var ink := Color(0.86, 0.95, 1.0, 0.9)
	draw_circle(c, 44.0, Color(0, 0, 0, 0.5))
	var turn := angle_difference(s.yaw, s.hull_yaw)
	var hull := PackedVector2Array()
	for p: Vector2 in [Vector2(-13, -22), Vector2(13, -22), Vector2(13, 22), Vector2(-13, 22), Vector2(-13, -22)]:
		hull.append(c + p.rotated(-turn))
	draw_polyline(hull, ink, 2.0, true)
	# The bright arrow is the front of the hull. The line straight up is where the gun looks.
	var front := PackedVector2Array([c + Vector2(-11, -24).rotated(-turn), c + Vector2(0, -38).rotated(-turn), c + Vector2(11, -24).rotated(-turn)])
	draw_colored_polygon(front, UiKit.BRASS)
	draw_circle(c, 6.0, ink)
	draw_line(c, c + Vector2(0, -30), ink, 2.0, true)


func _draw_scope() -> void:
	var c := size * 0.5
	var r := size.y * 0.46
	var black := Color(0, 0, 0, 0.97)
	draw_rect(Rect2(0, 0, c.x - r, size.y), black)
	draw_rect(Rect2(c.x + r, 0, c.x - r, size.y), black)
	var ring := PackedVector2Array()
	var inner := PackedVector2Array()
	var n := 64
	for i in n + 1:
		var a := TAU * i / n
		ring.append(c + Vector2(cos(a), sin(a)) * r)
		inner.append(c + Vector2(cos(a), sin(a)) * r * 1.5)
	draw_polyline(ring, Color(0, 0, 0, 1), 3.0, true)
	draw_arc(c, r * 1.25, 0, TAU, 72, black, r * 0.5, true)
	var line := Color(0, 0, 0, 0.85)
	draw_line(c + Vector2(-r, 0), c + Vector2(-16, 0), line, 2.0)
	draw_line(c + Vector2(16, 0), c + Vector2(r, 0), line, 2.0)
	draw_line(c + Vector2(0, -r), c + Vector2(0, -16), line, 2.0)
	draw_line(c + Vector2(0, 16), c + Vector2(0, r), line, 2.0)
	draw_circle(c, 1.8, Color(1.0, 0.3, 0.2))
	for i in range(1, 5):
		draw_line(c + Vector2(-8, 30.0 * i), c + Vector2(8, 30.0 * i), line, 1.5)
