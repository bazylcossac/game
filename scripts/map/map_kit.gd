class_name MapKit
extends RefCounted
## What every map is built from: terrain, walls, buildings and props. A map is a subclass
## that says where things go, see `CityMap`. The same seed yields identical geometry on
## server and clients.

const FLOOR_H := 3.3
const GROUND_EXTENT := 260
const GROUND_STEP := 2.0
## Cells per side of a ground tile. One mesh for the lot would be drawn whole in every pass,
## shadow cascades included, however little of it is in view.
const GROUND_TILE := 26
const FAR_TILE := 25

var b := MapBuilder.new()
var rng := RandomNumberGenerator.new()
var fires: Array[Vector3] = []
var smokes: Array[Vector3] = []
var lamps: Array[Vector3] = []
## Empire dressing, placed by the view only: [position, yaw, height] and light positions.
var banners: Array = []
var searchlights: Array[Vector3] = []
## Moving parts that only the view needs.
var life: MapLife
## Modelled street props, see CityProps. Only the view has them.
var props := CityProps.new()
var heights := PackedFloat32Array()
var _grid_n := 0
## x, z, radius
var _craters: Array[Vector3] = []


func build(parent: Node3D, map_seed: int, headless: bool) -> void:
	b.headless = headless
	props.enabled = not headless
	if not headless:
		_apply_climate()
	rng.seed = map_seed
	_plan_terrain()
	_build_ground(parent, headless)
	_build_scenery()
	_build_bounds()
	if not headless:
		_build_skyline()
	b.finish(parent)
	props.finish(parent)


# ---------------------------------------------------------------- map definition
# Overridden by each map. Everything else in the game reads the map through these.

func _plan_terrain() -> void:
	pass


func _build_scenery() -> void:
	pass


## Called once the crater pass has shaped the height grid, for trenches and the like.
func _carve_ground(_scorch: PackedFloat32Array) -> void:
	pass


## Blend weights for the ground shader: cobble, grass, scorch.
func _ground_tint(_x: float, _z: float, scorch: float) -> Color:
	return Color(0.0, 0.0, scorch, 1.0)


func base_height(_x: float, _z: float) -> float:
	return 0.0


## Capture points as {"name", "letter", "pos", "owner"}.
func flag_defs() -> Array:
	return []


## Each team's home, indexed by team.
func bases() -> Array:
	return [Vector3.ZERO, Vector3.ZERO]


## Tank parking, indexed by team, as [position, hull yaw].
func tank_depots() -> Array:
	return [[], []]


## Where each side's troop carriers wait, as for tanks: a little behind the first two tanks.
func apc_depots() -> Array:
	var out := [[], []]
	var tanks := tank_depots()
	for team in 2:
		var list: Array = tanks[team]
		for i in mini(list.size(), 2):
			var spot: Array = list[i]
			out[team].append([spot[0] + Vector3(0, 0, 11.0 if team == 0 else -11.0), spot[1]])
	return out


## The terrain grid: half its size, cell size, and cells per mesh tile.
func ground_extent() -> float:
	return GROUND_EXTENT


func ground_step() -> float:
	return GROUND_STEP


func ground_tile() -> int:
	return GROUND_TILE


## What the sky does on this map, see Weather. Empty for a quiet one.
func weather() -> Dictionary:
	return {}


## Half size of the playable area.
func bound() -> Vector2:
	return Vector2(200.0, 200.0)


## How far from the centre the full tactical map reaches.
func view_range() -> float:
	var half := bound()
	return maxf(half.x, half.y) + 17.0


## What spawning soldiers face.
func focus() -> Vector3:
	return Vector3.ZERO


## Half size of the area coins may fall in.
func coin_area() -> Vector2:
	return bound() * 0.9


## Paved routes for the tactical map.
func street_rects() -> Array[Rect2]:
	return []


## Places worth fighting over, for bots in modes without flags.
func hotspots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f: Dictionary in flag_defs():
		out.append(f["pos"])
	return out


## Where a team comes back into the fight when it has no flags to spawn at.
func team_spawns(team: int) -> Array[Vector3]:
	return [bases()[team]]


## Spawns for a free-for-all, spread over the whole map.
func free_spawns() -> Array[Vector3]:
	return hotspots()


# ---------------------------------------------------------------- terrain

## Height of the coarse terrain beyond the playable map.
func far_height(x: float, z: float) -> float:
	return base_height(x, z) + sin(x * 0.0047) * cos(z * 0.0053) * 22.0 * smoothstep(240.0, 700.0, Vector2(x, z).length()) - 0.6


func ground_height(x: float, z: float) -> float:
	var half := ground_extent()
	if absf(x) >= half or absf(z) >= half:
		return base_height(x, z)
	var gx := (x + half) / ground_step()
	var gz := (z + half) / ground_step()
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var n := _grid_n
	var h00 := heights[iz * n + ix]
	var h10 := heights[iz * n + ix + 1]
	var h01 := heights[(iz + 1) * n + ix]
	var h11 := heights[(iz + 1) * n + ix + 1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


func _add_crater(p: Vector2, r: float) -> void:
	for f: Dictionary in flag_defs():
		var fp: Vector3 = f["pos"]
		if p.distance_to(Vector2(fp.x, fp.z)) < 10.0:
			return
	_craters.append(Vector3(p.x, p.y, r))


func _build_ground(parent: Node3D, headless: bool) -> void:
	var cells := int(ground_extent() * 2 / ground_step())
	var n := cells + 1
	_grid_n = n
	heights.resize(n * n)
	var scorch := PackedFloat32Array()
	scorch.resize(n * n)
	for iz in n:
		var z := -ground_extent() + iz * ground_step()
		for ix in n:
			heights[iz * n + ix] = base_height(-ground_extent() + ix * ground_step(), z)
	for c: Vector3 in _craters:
		var r := c.z
		var ix0 := int((c.x - r * 1.5 + ground_extent()) / ground_step())
		var iz0 := int((c.y - r * 1.5 + ground_extent()) / ground_step())
		var span := int(r * 3.0 / ground_step()) + 2
		for iz in range(iz0, iz0 + span):
			for ix in range(ix0, ix0 + span):
				if ix < 0 or iz < 0 or ix >= n or iz >= n:
					continue
				var wx := -ground_extent() + ix * ground_step()
				var wz := -ground_extent() + iz * ground_step()
				var t := Vector2(wx - c.x, wz - c.y).length() / r
				if t < 1.0:
					heights[iz * n + ix] -= (1.0 - t * t) * r * 0.32
				elif t < 1.45:
					heights[iz * n + ix] += sin((t - 1.0) / 0.45 * PI) * r * 0.07
				scorch[iz * n + ix] = maxf(scorch[iz * n + ix], 1.0 - smoothstep(0.7, 1.5, t))
	_carve_ground(scorch)

	var faces := PackedVector3Array()
	faces.resize(cells * cells * 6)
	var fi := 0
	for iz in cells:
		for ix in cells:
			var x0 := -ground_extent() + ix * ground_step()
			var z0 := -ground_extent() + iz * ground_step()
			var p00 := Vector3(x0, heights[iz * n + ix], z0)
			var p10 := Vector3(x0 + ground_step(), heights[iz * n + ix + 1], z0)
			var p11 := Vector3(x0 + ground_step(), heights[(iz + 1) * n + ix + 1], z0 + ground_step())
			var p01 := Vector3(x0, heights[(iz + 1) * n + ix], z0 + ground_step())
			faces[fi] = p00
			faces[fi + 1] = p10
			faces[fi + 2] = p11
			faces[fi + 3] = p00
			faces[fi + 4] = p11
			faces[fi + 5] = p01
			fi += 6
	b.add_collision_faces(faces)
	if headless:
		return

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	for iz in n:
		var z := -ground_extent() + iz * ground_step()
		for ix in n:
			var x := -ground_extent() + ix * ground_step()
			var i := iz * n + ix
			var h := heights[i]
			verts[i] = Vector3(x, h, z)
			var hl := heights[iz * n + maxi(ix - 1, 0)]
			var hr := heights[iz * n + mini(ix + 1, n - 1)]
			var hu := heights[maxi(iz - 1, 0) * n + ix]
			var hd := heights[mini(iz + 1, n - 1) * n + ix]
			normals[i] = Vector3(hl - hr, ground_step() * 2.0, hu - hd).normalized()
			colors[i] = _ground_tint(x, z, scorch[i])
	_add_tiles(parent, verts, normals, colors, cells, ground_tile(), func(_ix: int, _iz: int) -> bool: return true)
	_build_far_terrain(parent)


## Cuts a grid of `cells` per side into tiles. `keep` says which cells have any ground.
func _add_tiles(parent: Node3D, verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, cells: int, tile: int, keep: Callable) -> void:
	var n := cells + 1
	var side := tile + 1
	for tz in range(0, cells, tile):
		for tx in range(0, cells, tile):
			var t_verts := PackedVector3Array()
			var t_normals := PackedVector3Array()
			var t_colors := PackedColorArray()
			for iz in side:
				var row := (tz + iz) * n + tx
				t_verts.append_array(verts.slice(row, row + side))
				t_normals.append_array(normals.slice(row, row + side))
				t_colors.append_array(colors.slice(row, row + side))
			var indices := PackedInt32Array()
			for iz in tile:
				for ix in tile:
					if keep.call(tx + ix, tz + iz):
						var a := iz * side + ix
						indices.append_array(PackedInt32Array([a, a + 1, a + side + 1, a, a + side + 1, a + side]))
			if not indices.is_empty():
				parent.add_child(_mesh_from(t_verts, t_normals, t_colors, indices))


func _mesh_from(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _ground_material())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


static var _ground_mat: ShaderMaterial


static func _ground_material() -> ShaderMaterial:
	if _ground_mat == null:
		_ground_mat = ShaderMaterial.new()
		_ground_mat.shader = load("res://shaders/ground.gdshader")
		for pair: Array in [["dirt_a", "dirt_albedo"], ["dirt_n", "dirt_normal"], ["cobble_a", "cobble_albedo"],
				["cobble_n", "cobble_normal"], ["grass_a", "grass_albedo"], ["grass_n", "grass_normal"]]:
			_ground_mat.set_shader_parameter(pair[0], Mats.tex(pair[1]))
		_ground_mat.set_shader_parameter("macro_tex", Mats.tex("macro_noise"))
	return _ground_mat


## Sets the weather on the shared materials before the map is shown. Every map calls this,
## so nothing is left over from the map played before it.
func _apply_climate() -> void:
	var climate := climate_of()
	Mats.set_climate(climate["wet"], climate["grime"])
	var ground := _ground_material()
	ground.set_shader_parameter("wet", climate["wet"])
	var mud: bool = climate.get("mud", false)
	ground.set_shader_parameter("dirt_a", Mats.tex("mud_albedo" if mud else "dirt_albedo"))
	ground.set_shader_parameter("dirt_n", Mats.tex("mud_normal" if mud else "dirt_normal"))
	ground.set_shader_parameter("dirt_tile", 9.0 if mud else 6.0)
	ground.set_shader_parameter("water_in_dirt", 1.0 if mud else 0.0)
	ground.set_shader_parameter("scorch_dark", 0.5 if mud else 0.12)
	ground.set_shader_parameter("puddles", 0.3 if mud else 1.0)
	ground.set_shader_parameter("gain", 1.8 if mud else 1.0)


## How wet and how dirty this map is, see Mats.set_climate. "mud" swaps the ground to mud.
func climate_of() -> Dictionary:
	return {"wet": 0.0, "grime": 0.55}


func _build_far_terrain(parent: Node3D) -> void:
	var step := 30.0
	var extent := 1500.0
	var cells := int(extent * 2 / step)
	var n := cells + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for iz in n:
		for ix in n:
			var x := -extent + ix * step
			var z := -extent + iz * step
			verts.append(Vector3(x, far_height(x, z), z))
			normals.append(Vector3.UP)
			colors.append(Color(0, 0.8, 0, 1))
	_add_tiles(parent, verts, normals, colors, cells, FAR_TILE, func(ix: int, iz: int) -> bool:
		var x := -extent + ix * step
		var z := -extent + iz * step
		return absf(x + step * 0.5) >= ground_extent() - step or absf(z + step * 0.5) >= ground_extent() - step)


# ---------------------------------------------------------------- walls and buildings

## Builds one wall run between two local points. Options: floors, fh, mat, tint, ruin,
## thick, bay, doors (bay indices), cornice, sill, lintel.
func _wall(xf: Transform3D, a: Vector2, c: Vector2, o: Dictionary) -> void:
	var total_len := a.distance_to(c)
	var dir := (c - a) / total_len
	var yaw := atan2(-dir.y, dir.x)
	var floors: int = o.get("floors", 2)
	var fh: float = o.get("fh", FLOOR_H)
	var mat: String = o.get("mat", "brick")
	var tint: Color = o.get("tint", Color.WHITE)
	var ruin: float = o.get("ruin", 0.0)
	var thick: float = o.get("thick", 0.32)
	var bay_w: float = o.get("bay", 3.1)
	var doors: Array = o.get("doors", [])
	var sill_h: float = o.get("sill", 0.95)
	var lintel_h: float = o.get("lintel", 2.4)
	var solid_chance: float = o.get("solid", 0.08)
	var pier: float = o.get("pier", 1.05)
	var base_y: float = o.get("y", 0.0)
	var bays := maxi(1, int(round(total_len / bay_w)))
	var bay := total_len / bays
	var total_h := floors * fh
	var phase := rng.randf() * TAU

	var piece := func(s0: float, s1: float, y0: float, y1: float) -> void:
		if y1 - y0 < 0.05 or s1 - s0 < 0.05:
			return
		var mid := a + dir * ((s0 + s1) * 0.5)
		var t := xf * Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, base_y + (y0 + y1) * 0.5, mid.y))
		var k := rng.randf_range(0.93, 1.05)
		b.add_box(t, Vector3(s1 - s0, y1 - y0, thick), mat, Color(tint.r * k, tint.g * k, tint.b * k))

	for i in bays + 1:
		var s := i * bay
		var top := total_h
		if ruin > 0.0:
			var level := lerpf(total_h, total_h * 0.28, ruin)
			top = clampf(level + sin(i * 1.27 + phase) * fh * 0.7 + rng.randf_range(-1.0, 1.0) * fh * 0.55, 1.1, total_h)
		var p0 := maxf(s - pier * 0.5, 0.0)
		var p1 := minf(s + pier * 0.5, total_len)
		piece.call(p0, p1, 0.0, top)
		if i == bays:
			break
		var o0 := p1
		var o1 := minf(s + bay - pier * 0.5, total_len)
		if rng.randf() < solid_chance and not doors.has(i):
			piece.call(o0, o1, 0.0, top * rng.randf_range(0.85, 1.0))
			continue
		for f in floors:
			var y0 := f * fh
			if y0 >= top:
				break
			var is_door: bool = f == 0 and doors.has(i)
			if not is_door:
				piece.call(o0, o1, y0, minf(y0 + sill_h, top))
			var l0 := y0 + (lintel_h + 0.2 if is_door else lintel_h)
			if l0 < top:
				piece.call(o0, o1, l0, minf(y0 + fh, top))

	if o.get("cornice", false) and ruin <= 0.01:
		for f in range(1, floors + 1):
			var mid := (a + c) * 0.5
			var t := xf * Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, base_y + f * fh - 0.1, mid.y))
			b.add_box(t, Vector3(total_len + 0.3, 0.24, thick + 0.28), "concrete", tint.darkened(0.08), false)


func _pick_facade() -> Dictionary:
	if rng.randf() < 0.5:
		var v := rng.randf_range(0.82, 1.1)
		return {"mat": "brick", "tint": Color(v, v * rng.randf_range(0.92, 1.0), v * rng.randf_range(0.88, 1.0))}
	var palettes := [Color(1.0, 0.93, 0.8), Color(0.86, 0.84, 0.76), Color(0.96, 0.8, 0.66), Color(0.74, 0.78, 0.76), Color(0.9, 0.74, 0.62)]
	return {"mat": "plaster", "tint": palettes[rng.randi_range(0, palettes.size() - 1)]}


func _building(center: Vector3, w: float, d: float, floors: int, yaw: float, ruin: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), center)
	var facade := _pick_facade()
	var hw := w * 0.5
	var hd := d * 0.5
	var t := 0.16
	var bays_w := maxi(1, int(round(w / 3.1)))
	var opts := {"floors": floors, "mat": facade["mat"], "tint": facade["tint"], "ruin": ruin, "cornice": true}
	var front := opts.duplicate()
	front["doors"] = [bays_w / 2]
	var back := opts.duplicate()
	back["doors"] = [maxi(bays_w / 2 - 1, 0)]
	_wall(xf, Vector2(-hw, hd - t), Vector2(hw, hd - t), front)
	_wall(xf, Vector2(hw, -hd + t), Vector2(-hw, -hd + t), back)
	_wall(xf, Vector2(hw - t, hd), Vector2(hw - t, -hd), opts)
	_wall(xf, Vector2(-hw + t, -hd), Vector2(-hw + t, hd), opts)
	b.add_footprint(Vector2(center.x, center.z), Vector2(w, d), yaw)

	# Interior floor, so rooms do not show raw dirt.
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), Vector3(w - 0.3, 0.04, d - 0.3), "wood", Color(0.5, 0.46, 0.42), false)

	if floors >= 2:
		var stair_len := 5.4
		var stair_w := 1.7
		var has_stairs := ruin < 0.55 and w > stair_len + 3.0
		var hole_x0 := -hw + 0.4
		var hole_z1 := -hd + 0.4 + stair_w
		for f in range(1, floors):
			var y := f * FLOOR_H - 0.12
			if ruin > 0.0 and y > lerpf(floors * FLOOR_H, floors * FLOOR_H * 0.28, ruin):
				continue
			var keep_half := ruin > 0.35
			var slab_d := (d - 0.4) * (0.6 if keep_half else 1.0)
			var slab_z := hd - 0.2 - slab_d * 0.5
			if f == 1 and has_stairs:
				var front_d := hd - 0.2 - hole_z1
				b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, y, hole_z1 + front_d * 0.5)), Vector3(w - 0.4, 0.24, front_d), "concrete", Color(0.7, 0.68, 0.64))
				var rest := hw - 0.2 - (hole_x0 + stair_len)
				b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(hw - 0.2 - rest * 0.5, y, (hole_z1 - hd + 0.2) * 0.5)), Vector3(rest, 0.24, hole_z1 + hd - 0.2), "concrete", Color(0.7, 0.68, 0.64))
			else:
				b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, y, slab_z)), Vector3(w - 0.4, 0.24, slab_d), "concrete", Color(0.7, 0.68, 0.64))
		if has_stairs:
			var angle := atan2(FLOOR_H, stair_len)
			var ramp_len := Vector2(stair_len, FLOOR_H).length()
			var ramp := Transform3D(Basis(Vector3.BACK, angle), Vector3(hole_x0 + stair_len * 0.5, FLOOR_H * 0.5 - 0.1, -hd + 0.4 + stair_w * 0.5))
			b.add_box(xf * ramp, Vector3(ramp_len, 0.16, stair_w), "wood", Color(0.7, 0.62, 0.54))

	if ruin <= 0.01:
		_roof(xf, w, d, floors * FLOOR_H)
	else:
		for i in rng.randi_range(1, 2):
			var lp := Vector3(rng.randf_range(-hw + 2, hw - 2), 0, rng.randf_range(-hd + 2, hd - 2))
			_rubble(xf * lp, rng.randf_range(1.2, 2.2), rng.randi_range(8, 14), facade["mat"], facade["tint"])
		if ruin > 0.5 and rng.randf() < 0.14:
			fires.append(xf * Vector3(0, 0.3, 0))


func _roof(xf: Transform3D, w: float, d: float, y: float) -> void:
	var hw := w * 0.5 + 0.3
	var hd := d * 0.5 + 0.3
	var rh := minf(d * 0.36, 3.4)
	var tint := Color(rng.randf_range(0.7, 1.0), rng.randf_range(0.66, 0.9), rng.randf_range(0.62, 0.86))
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, y + 0.06, 0)), Vector3(w, 0.12, d), "concrete", Color(0.5, 0.5, 0.48))
	var p := func(x: float, py: float, z: float) -> Vector3: return xf * Vector3(x, py, z)
	var fl: Vector3 = p.call(-hw, y, hd)
	var fr: Vector3 = p.call(hw, y, hd)
	var bl: Vector3 = p.call(-hw, y, -hd)
	var br: Vector3 = p.call(hw, y, -hd)
	var rl: Vector3 = p.call(-hw, y + rh, 0.0)
	var rr: Vector3 = p.call(hw, y + rh, 0.0)
	b.add_tri(rl, rr, fr, "roof", tint)
	b.add_tri(rl, fr, fl, "roof", tint)
	b.add_tri(rr, rl, bl, "roof", tint)
	b.add_tri(rr, bl, br, "roof", tint)
	b.add_tri(rl, fl, bl, "brick", tint)
	b.add_tri(rr, br, fr, "brick", tint)


# ---------------------------------------------------------------- props

func _market_stall(p: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var tint := [Color(0.8, 0.4, 0.3), Color(0.5, 0.6, 0.72), Color(0.76, 0.7, 0.5)][rng.randi_range(0, 2)] as Color
	for sx: float in [-1.8, 1.8]:
		for sz: float in [-1.0, 1.0]:
			b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(sx, 1.15, sz)), Vector3(0.12, 2.3, 0.12), "wood", Color(0.7, 0.6, 0.5), true, false)
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), Vector3(3.6, 1.0, 1.7), "wood", Color(0.66, 0.56, 0.46))
	b.add_box(xf * Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 2.42, 0)), Vector3(4.2, 0.06, 2.8), "fabric", tint, false)


func _wagon(p: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var tint := [Color(0.6, 0.36, 0.28), Color(0.46, 0.44, 0.4), Color(0.4, 0.46, 0.42)][rng.randi_range(0, 2)] as Color
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), Vector3(2.4, 0.5, 11.6), "metal", Color(0.4, 0.38, 0.36))
	# Sides have a door gap in the middle, so soldiers can run through the wagon.
	for sx: float in [-1.3, 1.3]:
		b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(sx, 1.9, 3.4)), Vector3(0.12, 2.6, 4.8), "wood", tint)
		b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(sx, 1.9, -3.4)), Vector3(0.12, 2.6, 4.8), "wood", tint)
	for sz: float in [-5.8, 5.8]:
		b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 1.9, sz)), Vector3(2.6, 2.6, 0.12), "wood", tint)
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 3.26, 0)), Vector3(2.9, 0.14, 12.0), "metal", Color(0.4, 0.4, 0.4))
	for sz: float in [-4.0, 4.0]:
		b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.1, sz)), Vector3(1.9, 0.2, 1.4), "metal", Color(0.3, 0.3, 0.3))
	b.add_footprint(Vector2(p.x, p.z), Vector2(2.8, 12), yaw, "cover")


func _machine(p: Vector3) -> void:
	b.box(p + Vector3(0, 0.75, 0), Vector3(4.5, 1.5, 2.2), "metal", Color(0.5, 0.56, 0.52))
	b.box(p + Vector3(-1.0, 1.9, 0), Vector3(1.6, 0.9, 1.5), "metal", Color(0.46, 0.5, 0.48))
	b.box(p + Vector3(1.4, 2.2, 0), Vector3(0.3, 1.5, 0.3), "metal", Color(0.4, 0.42, 0.4), false)
	b.add_footprint(Vector2(p.x, p.z), Vector2(4.5, 2.2), 0.0, "cover")


func _bunker(p: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var g := Color(0.62, 0.62, 0.6)
	var o := {"floors": 1, "fh": 2.8, "mat": "concrete", "tint": g, "thick": 0.8, "bay": 3.0, "sill": 1.5, "lintel": 2.0, "solid": 0.2}
	var fr := o.duplicate()
	fr["doors"] = [1]
	_wall(xf, Vector2(-5, 3.5), Vector2(5, 3.5), fr)
	_wall(xf, Vector2(5, -3.5), Vector2(-5, -3.5), o)
	_wall(xf, Vector2(5, 3.5), Vector2(5, -3.5), o)
	_wall(xf, Vector2(-5, -3.5), Vector2(-5, 3.5), o)
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 3.0, 0)), Vector3(11.4, 0.6, 8.2), "concrete", g)
	for x: float in [-3.4, 3.4]:
		banners.append([xf * Vector3(x, 1.6, 3.96), yaw, 2.5])
	b.add_footprint(Vector2(p.x, p.z), Vector2(10, 7), yaw, "landmark")


func _watch_tower(p: Vector3) -> void:
	for sx: float in [-1.4, 1.4]:
		for sz: float in [-1.4, 1.4]:
			b.box(p + Vector3(sx, 2.6, sz), Vector3(0.22, 5.2, 0.22), "wood", Color(0.6, 0.5, 0.42), true, 0.0, true)
	b.box(p + Vector3(0, 5.2, 0), Vector3(3.6, 0.16, 3.6), "wood", Color(0.6, 0.5, 0.42))
	b.box(p + Vector3(0, 5.75, 1.75), Vector3(3.6, 1.0, 0.1), "wood", Color(0.56, 0.46, 0.4))
	b.box(p + Vector3(0, 5.75, -1.75), Vector3(3.6, 1.0, 0.1), "wood", Color(0.56, 0.46, 0.4))
	b.box(p + Vector3(0, 7.4, 0), Vector3(4.0, 0.12, 4.0), "metal", Color(0.4, 0.4, 0.38), false)
	searchlights.append(p + Vector3(0, 6.9, 0))
	b.add_footprint(Vector2(p.x, p.z), Vector2(3.4, 3.4), 0.0, "cover")


func _sandbags(a: Vector3, c: Vector3, layers := 4) -> void:
	var flat_a := a
	var flat_c := Vector3(c.x, a.y, c.z)
	var length := flat_a.distance_to(flat_c)
	if length < 0.5:
		return
	var dir := (flat_c - flat_a) / length
	var yaw := atan2(-dir.z, dir.x)
	var bag := 0.86
	var count := int(length / bag)
	for layer in layers:
		var y := 0.13 + layer * 0.24
		var off := 0.5 * (layer % 2)
		for i in count:
			var p := flat_a + dir * (i + off) * bag
			var k := rng.randf_range(0.86, 1.05)
			_bag(Transform3D(Basis(Vector3.UP, yaw + rng.randf_range(-0.05, 0.05)), p + Vector3(0, y, 0)), bag * 1.02, 0.5, 0.27, Color(k * 0.62, k * 0.55, k * 0.4))
	var mid := (flat_a + flat_c) * 0.5
	b.box(mid + Vector3(0, layers * 0.12, 0), Vector3(length, layers * 0.24 + 0.02, 0.5), "", Color.WHITE, true, yaw)
	b.add_footprint(Vector2(mid.x, mid.z), Vector2(length, 0.6), yaw, "cover")


## One filled sack, fat in the middle and tied off at both ends. Purely visual: the wall of
## bags has a single collider of its own.
func _bag(xf: Transform3D, length: float, width: float, height: float, tint: Color) -> void:
	var stations: Array = [[-0.5, 0.42], [-0.34, 0.86], [0.0, 1.0], [0.34, 0.86], [0.5, 0.42]]
	var sides := 8
	var rings: Array = []
	for st: Array in stations:
		var ring := PackedVector3Array()
		for i in sides:
			var a := TAU * i / sides + 0.39
			# A bag settles flat, so its section is squashed at the bottom.
			var drop := 0.72 if sin(a) < 0.0 else 1.0
			ring.append(xf * Vector3(st[0] * length, sin(a) * height * 0.5 * st[1] * drop, cos(a) * width * 0.5 * st[1]))
		rings.append(ring)
	for r in rings.size() - 1:
		var lo: PackedVector3Array = rings[r]
		var hi: PackedVector3Array = rings[r + 1]
		for i in sides:
			var j := (i + 1) % sides
			b.add_tri(lo[i], lo[j], hi[j], "fabric", tint, false)
			b.add_tri(lo[i], hi[j], hi[i], "fabric", tint, false)
	for end: PackedVector3Array in [rings[0], rings[rings.size() - 1]]:
		for i in range(1, sides - 1):
			b.add_tri(end[0], end[i], end[i + 1], "fabric", tint.darkened(0.15), false)


## Concertina wire on wooden trestles: a low obstacle that soldiers and bots have to go around.
func _wire(a: Vector3, c: Vector3) -> void:
	var flat_a := a
	var flat_c := Vector3(c.x, a.y, c.z)
	var length := flat_a.distance_to(flat_c)
	var dir := (flat_c - flat_a) / length
	var side := Vector3(-dir.z, 0, dir.x)
	var yaw := atan2(-dir.z, dir.x)
	var wood := Color(0.62, 0.5, 0.38)
	var steel := Color(0.46, 0.42, 0.4)
	var posts := int(length / 2.2) + 1
	for i in posts:
		var p := flat_a + dir * (length * i / maxf(posts - 1, 1))
		for tilt: float in [-0.42, 0.42]:
			var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
			b.add_box(Transform3D(basis, p + Vector3(0, 0.56, 0)), Vector3(0.09, 1.25, 0.09), "wood", wood, false, false)
		b.add_box(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.66, 0)), Vector3(0.08, 0.08, 0.64), "wood", wood.darkened(0.15), false, false)
	# A coil is a helix drawn in straight pieces, stretched a little along the line.
	var turns := int(length / 0.2)
	var segments := turns * 10
	var last := flat_a + Vector3(0, 0.56, 0) + side * 0.46
	for i in range(1, segments + 1):
		var t := float(i) / segments
		var ang := t * turns * TAU
		var wobble := 0.07 * sin(float(i) * 1.7) + 0.05 * sin(t * turns * 2.3)
		var at := flat_a + dir * (length * t) + side * cos(ang) * (0.46 + wobble) + Vector3(0, 0.56 + sin(ang) * (0.46 + wobble), 0)
		var run := at - last
		b.add_box(Transform3D(Basis(Quaternion(Vector3.UP, run.normalized())), (at + last) * 0.5), Vector3(0.011, run.length() * 1.05, 0.011), "metal", steel, false, false)
		last = at
	var mid := (flat_a + flat_c) * 0.5
	b.box(mid + Vector3(0, 0.5, 0), Vector3(length, 1.0, 1.0), "", Color.WHITE, true, yaw)
	b.add_footprint(Vector2(mid.x, mid.z), Vector2(length, 1.0), yaw, "wire")


func _rubble(p: Vector3, radius: float, count: int, mat: String, tint: Color) -> void:
	var h := radius * 0.42
	b.add_prism(p, radius, h, 7, mat, tint.darkened(0.2), radius * 0.2)
	for i in count:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius * 1.05
		var off := Vector3(cos(ang) * r, 0, sin(ang) * r)
		var y := p.y + h * (1.0 - r / (radius * 1.2)) + 0.1
		var s := rng.randf_range(0.18, 0.62)
		var basis := Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU)
		b.add_box(Transform3D(basis, Vector3(p.x, y, p.z) + off), Vector3(s * rng.randf_range(1.0, 1.8), s * 0.6, s), mat, tint, false)


func _crates(p: Vector3) -> void:
	var yaw := rng.randf() * TAU
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var tint := Color(0.72, 0.6, 0.46)
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)), Vector3(1.2, 1.2, 1.2), "wood", tint)
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(1.3, 0.45, 0.1)), Vector3(0.9, 0.9, 0.9), "wood", tint.darkened(0.1))
	if rng.randf() < 0.6:
		b.add_box(xf * Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.1, 1.6, 0)), Vector3(0.8, 0.8, 0.8), "wood", tint.lightened(0.08))
	b.add_footprint(Vector2(p.x, p.z), Vector2(2.2, 1.3), yaw, "cover")


## Three lengths of angle iron riveted through a gusset, set at right angles to one another.
## Oil drums, in a huddle a soldier can crouch behind.
func _drums(p: Vector3) -> void:
	var tint := Color(0.5, 0.42, 0.34)
	for off: Vector3 in [Vector3(-0.5, 0, -0.1), Vector3(0.45, 0, -0.3), Vector3(0.05, 0, 0.5)]:
		b.add_prism(p + off, 0.46, 1.15, 8, "metal", tint.darkened(rng.randf_range(0.0, 0.25)))
	b.add_footprint(Vector2(p.x, p.z), Vector2(1.9, 1.9), 0.0, "cover")


## Concrete pipes on their side, as left on a building site.
func _pipes(p: Vector3) -> void:
	var yaw := rng.randf() * TAU
	var axis := Basis(Vector3.UP, yaw)
	for off: Vector3 in [Vector3(0, 0.55, -0.62), Vector3(0, 0.55, 0.62)]:
		b.add_box(Transform3D(axis, p + axis * off), Vector3(4.6, 1.1, 1.15), "concrete", Color(0.72, 0.7, 0.66))
	b.add_footprint(Vector2(p.x, p.z), Vector2(4.6, 2.4), yaw, "cover")


## A barricade of doors and beams, thrown across a street by its defenders.
func _barricade(p: Vector3, yaw: float, length := 4.0) -> void:
	var axis := Basis(Vector3.UP, yaw)
	var tint := Color(0.62, 0.5, 0.4)
	b.add_box(Transform3D(axis, p + Vector3.UP * 0.65), Vector3(length, 1.3, 0.4), "wood", tint)
	for x: float in [-length * 0.4, 0.0, length * 0.4]:
		var lean := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.5)
		b.add_box(Transform3D(lean, p + axis * Vector3(x, 0.8, 0.55)), Vector3(0.22, 1.9, 0.22), "wood", tint.darkened(0.2), false)
	b.add_footprint(Vector2(p.x, p.z), Vector2(length, 0.8), yaw, "cover")


## Is any cell within `reach` metres of `p` solid? Walls and props stamp the grid as they
## are placed, so this sees whatever has been built so far.
func _has_cover_near(p: Vector3, reach: int) -> bool:
	var nav := b.nav
	var c := nav.cell_of(p)
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			if dx * dx + dz * dz <= reach * reach and not nav.is_free(c + Vector2i(dx, dz)):
				return true
	return false


## Clutter must not land on a place people spawn or bots gather.
func _clear_of_spots(p: Vector3) -> bool:
	var spots: Array[Vector3] = hotspots() + free_spawns() + team_spawns(0) + team_spawns(1)
	for spot: Vector3 in spots:
		if Vector2(spot.x, spot.z).distance_to(Vector2(p.x, p.z)) < 4.5:
			return false
	return true


## Leaves nowhere more than `reach` metres from something to hide behind. Runs after the
## hand-placed scenery, so it only ever fills what the layout left bare.
func _fill_open(reach: int, piece: Callable) -> void:
	var half := bound() - Vector2(3, 3)
	var x := -half.x
	while x < half.x:
		var z := -half.y
		while z < half.y:
			var at := _ground(x + rng.randf_range(-1.5, 1.5), z + rng.randf_range(-1.5, 1.5))
			z += 4.0
			if b.nav.is_free(b.nav.cell_of(at)) and not _has_cover_near(at, reach) and _clear_of_spots(at):
				piece.call(at)
		x += 4.0


func _hedgehog(p: Vector3) -> void:
	var yaw := rng.randf() * TAU
	props.stand("hedgehog", p, yaw)
	b.box(p + Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.2), "", Color.WHITE, true)


func _dead_tree(p: Vector3) -> void:
	var h := rng.randf_range(3.5, 6.5)
	var k := h / 5.5
	props.stand("dead_tree_a" if rng.randf() < 0.5 else "dead_tree_b", p, rng.randf() * TAU, Color.WHITE, Vector3(k, k, k))
	b.add_box(Transform3D(Basis.IDENTITY, p + Vector3.UP * h * 0.5), Vector3(0.4, h, 0.4), "", Color.WHITE, true)


func _tank_wreck(p: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var dark := Color(0.34, 0.33, 0.31)
	var at := func(pos: Vector3, size: Vector3, tint: Color, collide := true) -> void:
		b.add_box(xf * Transform3D(Basis.IDENTITY, pos), size, "", tint, collide)
	# The wreck faces away from its local -Z, so the gun droops over the front of the hull.
	props.stand("wreck_tank", p, yaw + PI)
	at.call(Vector3(0, 1.0, 0), Vector3(3.0, 1.2, 6.2), dark)
	at.call(Vector3(-1.75, 0.6, 0), Vector3(0.6, 1.2, 6.8), Color(0.2, 0.2, 0.2))
	at.call(Vector3(1.75, 0.6, 0), Vector3(0.6, 1.2, 6.8), Color(0.2, 0.2, 0.2))
	b.add_box(xf * Transform3D(Basis(Vector3.UP, 0.35), Vector3(0, 2.05, -0.3)), Vector3(2.3, 0.9, 2.8), "", dark.darkened(0.1))
	b.add_box(xf * Transform3D(Basis(Vector3.UP, 0.35) * Basis(Vector3.RIGHT, -0.12), Vector3(0.75, 2.15, 1.9)), Vector3(0.18, 0.18, 3.6), "metal", dark.darkened(0.3), false)
	b.add_footprint(Vector2(p.x, p.z), Vector2(3.8, 6.8), yaw, "cover")


func _truck(p: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var body := Color(0.4, 0.42, 0.34)
	props.stand("wreck_truck", p, yaw)
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0.5)), Vector3(2.0, 0.3, 6.0), "", Color(0.3, 0.3, 0.3))
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 2.5)), Vector3(2.0, 1.4, 1.8), "", body)
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -0.8)), Vector3(2.1, 1.1, 3.5), "", Color(0.5, 0.42, 0.34))
	b.add_footprint(Vector2(p.x, p.z), Vector2(2.1, 6), yaw, "cover")


func _tram(p: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var cream := Color(0.86, 0.76, 0.56)
	var red := Color(0.5, 0.22, 0.18)
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.75, 0)), Vector3(2.3, 1.1, 10.5), "metal", red)
	for z: float in [-4.6, -2.3, 0.0, 2.3, 4.6]:
		for sx: float in [-1.08, 1.08]:
			b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(sx, 1.8, z)), Vector3(0.1, 1.0, 0.3), "metal", cream)
	b.add_box(xf * Transform3D(Basis.IDENTITY, Vector3(0, 2.45, 0)), Vector3(2.3, 0.35, 10.5), "metal", cream)
	b.add_footprint(Vector2(p.x, p.z), Vector2(2.3, 10.5), yaw, "cover")


func _lamp(p: Vector3) -> void:
	var tint := Color(0.22, 0.24, 0.24)
	var y := ground_height(p.x, p.z)
	if rng.randf() < 0.25:
		return
	props.stand("lamp_old", Vector3(p.x, y, p.z))
	b.add_box(Transform3D(Basis.IDENTITY, Vector3(p.x, y + 2.6, p.z)), Vector3(0.14, 5.2, 0.14), "", tint, true, false)
	if rng.randf() < 0.45:
		lamps.append(Vector3(p.x - 0.9, y + 5.05, p.z))


func _tent(p: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var tint := Color(0.62, 0.62, 0.48)
	var q := func(x: float, y: float, z: float) -> Vector3: return xf * Vector3(x, y, z)
	var fl: Vector3 = q.call(-2.2, 0.0, 3.2)
	var fr: Vector3 = q.call(2.2, 0.0, 3.2)
	var bl: Vector3 = q.call(-2.2, 0.0, -3.2)
	var br: Vector3 = q.call(2.2, 0.0, -3.2)
	var rf: Vector3 = q.call(0.0, 2.6, 3.2)
	var rb: Vector3 = q.call(0.0, 2.6, -3.2)
	b.add_tri(rf, fr, br, "fabric", tint)
	b.add_tri(rf, br, rb, "fabric", tint)
	b.add_tri(rb, bl, fl, "fabric", tint)
	b.add_tri(rb, fl, rf, "fabric", tint)
	b.add_tri(rb, br, bl, "fabric", tint)
	b.add_tri(rf, fl, fr, "fabric", tint.darkened(0.3))
	b.block_footprint(xf, 2.2, 3.2)
	b.add_footprint(Vector2(p.x, p.z), Vector2(4.4, 6.4), yaw, "cover")


func _build_bounds() -> void:
	var h := 60.0
	var half := bound()
	b.add_blocker(Vector3(0, h * 0.5, half.y + 1), Vector3(half.x * 2 + 4, h, 2))
	b.add_blocker(Vector3(0, h * 0.5, -half.y - 1), Vector3(half.x * 2 + 4, h, 2))
	b.add_blocker(Vector3(half.x + 1, h * 0.5, 0), Vector3(2, h, half.y * 2 + 4))
	b.add_blocker(Vector3(-half.x - 1, h * 0.5, 0), Vector3(2, h, half.y * 2 + 4))


## Unreachable, collision-free ruins that give the horizon a burnt-city skyline.
func _build_skyline() -> void:
	for i in 150:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(250.0, 560.0)
		var p := Vector3(cos(ang) * r * 1.1, 0, sin(ang) * r)
		var y := far_height(p.x, p.z)
		var w := rng.randf_range(10.0, 26.0)
		var depth := rng.randf_range(10.0, 22.0)
		var height := rng.randf_range(8.0, 26.0)
		var yaw := rng.randf_range(-0.4, 0.4)
		var k := rng.randf_range(0.26, 0.44)
		var tint := Color(k, k * 0.95, k * 0.92)
		# Sunk into the slope, and given a broken crown so it does not read as a plain box.
		b.box(Vector3(p.x, y + height * 0.5 - 8.0, p.z), Vector3(w, height + 8.0, depth), "concrete", tint, false, yaw)
		for j in rng.randi_range(2, 4):
			var off := Basis(Vector3.UP, yaw) * Vector3(rng.randf_range(-w, w) * 0.4, 0.0, 0.0)
			var crown := rng.randf_range(2.0, 7.0)
			b.box(Vector3(p.x, y + height - 4.0 + crown * 0.5, p.z) + off, Vector3(w * 0.22, crown, depth * 0.9), "concrete", tint, false, yaw)
		if rng.randf() < 0.14:
			smokes.append(Vector3(p.x, y + height, p.z))


func _camp_resistance(c: Vector3) -> void:
	# A rough field camp: sandbag ring, canvas tents, supply dumps.
	for seg: Array in [[-34.0, -14.0, -14.0, -18.0], [14.0, -18.0, 34.0, -14.0], [-38.0, -12.0, -40.0, 6.0], [38.0, -12.0, 40.0, 6.0]]:
		_sandbags(c + Vector3(seg[0], 0, seg[1]), c + Vector3(seg[2], 0, seg[3]))
	for spec: Array in [[-24.0, 4.0, 0.2], [-10.0, 12.0, -0.1], [11.0, 12.0, 0.1], [25.0, 4.0, -0.2], [-28.0, -6.0, 0.4], [28.0, -6.0, -0.4]]:
		_tent(c + Vector3(spec[0], 0, spec[1]), spec[2])
	_crates(c + Vector3(-5, 0, -8))
	_crates(c + Vector3(6, 0, -9))
	_truck(c + Vector3(-16, 0, -7), 0.3)
	_truck(c + Vector3(17, 0, -5), -0.4)
	smokes.append(c + Vector3(0, 0.2, 22))


func _camp_empire(c: Vector3) -> void:
	_bunker(c + Vector3(-22, 0, -10), 0.0)
	_bunker(c + Vector3(22, 0, -10), 0.0)
	_bunker(c + Vector3(0, 0, -20), 0.0)
	_watch_tower(c + Vector3(-34, 0, 12))
	_watch_tower(c + Vector3(34, 0, 12))
	for spec: Array in [[-30.0, 18.0, -12.0, 20.0], [12.0, 20.0, 30.0, 18.0]]:
		b.box(c + Vector3((spec[0] + spec[2]) * 0.5, 1.0, (spec[1] + spec[3]) * 0.5), Vector3(absf(spec[2] - spec[0]), 2.0, 1.0), "concrete", Color(0.66, 0.66, 0.64))
		b.add_footprint(Vector2(c.x + (spec[0] + spec[2]) * 0.5, c.z + (spec[1] + spec[3]) * 0.5), Vector2(absf(spec[2] - spec[0]), 1.0), 0.0, "cover")
	for x: float in [-40.0, -26.0, 26.0, 40.0]:
		_hedgehog(c + Vector3(x, 0, 24))
	_crates(c + Vector3(-8, 0, 6))
	_crates(c + Vector3(10, 0, 7))
	_tank_wreck(c + Vector3(-14, 0, 14), 0.1)
	# Masts flanking the gate.
	for x: float in [-15.0, 15.0, -22.0, 22.0]:
		var foot := c + Vector3(x, 0, 23)
		b.box(foot + Vector3(0, 4.5, 0), Vector3(0.16, 9.0, 0.16), "metal", Color(0.3, 0.3, 0.3), true, 0.0, false)
		b.box(foot + Vector3(0, 8.9, 0), Vector3(2.1, 0.1, 0.1), "metal", Color(0.3, 0.3, 0.3), false)
		banners.append([foot + Vector3(0, 6.3, 0.1), 0.0, 5.0])


## Stands a spot on the terrain, and tells the nav grids that this is the floor there.
func _ground(x: float, z: float) -> Vector3:
	var y := ground_height(x, z)
	b.floor_y = y
	return Vector3(x, y, z)


## Hills that close in around a map, flat out to `half`.
func _rim(x: float, z: float, half: Vector2) -> float:
	var d := maxf(absf(x) / half.x, absf(z) / half.y)
	return smoothstep(0.95, 1.7, d) * (24.0 + 12.0 * sin(x * 0.013 + 1.0) * cos(z * 0.017))


## A closed ring of tall facades around a compact map, with dark rooms behind the windows.
func _perimeter(half: Vector2, floors: int, stretch: float) -> void:
	var xf := Transform3D.IDENTITY
	var corners := [Vector2(-half.x, half.y), Vector2(half.x, half.y), Vector2(half.x, -half.y), Vector2(-half.x, -half.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var c: Vector2 = corners[(i + 1) % 4]
		var pieces := maxi(int(round(a.distance_to(c) / stretch)), 1)
		for j in pieces:
			var facade := _pick_facade()
			var from := a.lerp(c, float(j) / pieces)
			var to := a.lerp(c, float(j + 1) / pieces)
			_wall(xf, from, to, {"floors": floors + j % 2, "mat": facade["mat"], "tint": facade["tint"], "solid": 0.04, "cornice": true})
		var mid := (a + c) * 0.5 + (a + c).normalized() * 1.0
		var wide := absf(c.x - a.x) > 1.0
		b.box(Vector3(mid.x, 9.0, mid.y), Vector3(a.distance_to(c) + 4.0 if wide else 2.0, 18.0, 2.0 if wide else a.distance_to(c) + 4.0), "concrete", Color(0.08, 0.08, 0.09), true, 0.0, false)


## Burnt-out blocks beyond the edge of a compact map, so the view does not end at a wall.
func _outer_ruins(half: Vector2, count: int) -> void:
	var placed := 0
	while placed < count:
		var p := Vector3(rng.randf_range(-236.0, 236.0), 0.0, rng.randf_range(-236.0, 236.0))
		if absf(p.x) < half.x + 16.0 and absf(p.z) < half.y + 16.0:
			continue
		placed += 1
		var y := base_height(p.x, p.z)
		var w := rng.randf_range(12.0, 30.0)
		var depth := rng.randf_range(10.0, 24.0)
		var height := rng.randf_range(9.0, 24.0)
		var yaw := rng.randf_range(-0.3, 0.3)
		var v := rng.randf_range(0.34, 0.56)
		var tint := Color(v, v * 0.95, v * 0.9)
		b.box(Vector3(p.x, y + height * 0.5 - 5.0, p.z), Vector3(w, height + 5.0, depth), "brick" if rng.randf() < 0.5 else "concrete", tint, false, yaw)
		for j in rng.randi_range(2, 4):
			var off := Basis(Vector3.UP, yaw) * Vector3(rng.randf_range(-w, w) * 0.42, 0.0, 0.0)
			var crown := rng.randf_range(2.0, 6.0)
			b.box(Vector3(p.x, y + height + crown * 0.5, p.z) + off, Vector3(w * 0.2, crown, depth * 0.9), "concrete", tint, false, yaw)


# ---------------------------------------------------------------- placement

## A random spot a soldier can really walk to: open ground reachable from both bases.
func random_coin_point(r: RandomNumberGenerator) -> Vector3:
	var area := coin_area()
	var homes := bases()
	for attempt in 40:
		var p := Vector3(r.randf_range(-area.x, area.x), 0.0, r.randf_range(-area.y, area.y))
		if not b.nav.is_free(b.nav.cell_of(p)):
			continue
		if b.nav.can_reach(homes[0], p) and b.nav.can_reach(homes[1], p):
			p.y = ground_height(p.x, p.z)
			return p
	return focus()


## `grid` is whose room to check, as a tank needs more of it than a soldier.
func spawn_point_near(center: Vector3, spread: float, r: RandomNumberGenerator, grid: NavGrid = null) -> Vector3:
	var nav := grid if grid != null else b.nav
	for attempt in 12:
		var ang := r.randf() * TAU
		var dist := sqrt(r.randf()) * spread
		var p := center + Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		if nav.is_free(nav.cell_of(p)):
			p.y = ground_height(p.x, p.z) + 0.1
			return p
	var c := nav.nearest_free(nav.cell_of(center))
	var q := nav._center(c)
	q.y = ground_height(q.x, q.z) + 0.1
	return q
