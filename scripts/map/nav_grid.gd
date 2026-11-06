class_name NavGrid
extends RefCounted
## Ground-level pathfinding for bots. Map geometry stamps blocked cells as it is built,
## which keeps pathing deterministic and working on a headless server with no nav baking.

const HALF := 240
const SIZE := HALF * 2
## Path cells tried at a time when straightening. Most lines are clear, so it pays to look ahead.
const PULL_STRIDE := 6

var grid := AStarGrid2D.new()
## Coarser cells let large tank maps keep the same bounded memory footprint.
var cell_metres := 1.0
## The same blocked cells, row by row. Straightening a path asks about tens of thousands of
## cells, which has to stay cheaper than a round trip into the engine each.
var _solid := PackedByteArray()
## Which connected area each free cell belongs to, see `label_regions`.
var _regions := PackedInt32Array()
var _dynamic := {}
var _dynamic_counts := {}
var _dynamic_base := {}


func add_obstacle(id: int, xf: Transform3D, half: Vector2, inflate: float) -> void:
	remove_obstacle(id)
	var cells := PackedInt32Array()
	var ex := half.x + inflate
	var ez := half.y + inflate
	var bx := xf.basis.x.normalized()
	var bz := xf.basis.z.normalized()
	var reach_x := absf(bx.x) * ex + absf(bz.x) * ez
	var reach_z := absf(bx.z) * ex + absf(bz.z) * ez
	for x in range(int(floor((xf.origin.x - reach_x) / cell_metres)), int(ceil((xf.origin.x + reach_x) / cell_metres)) + 1):
		for z in range(int(floor((xf.origin.z - reach_z) / cell_metres)), int(ceil((xf.origin.z + reach_z) / cell_metres)) + 1):
			var c := Vector2i(x, z)
			if not grid.is_in_boundsv(c):
				continue
			var delta := Vector3((x + 0.5) * cell_metres - xf.origin.x, 0, (z + 0.5) * cell_metres - xf.origin.z)
			if absf(delta.dot(bx)) > ex or absf(delta.dot(bz)) > ez:
				continue
			var index := (z + HALF) * SIZE + x + HALF
			if not _dynamic_counts.has(index):
				_dynamic_base[index] = _solid[index]
			_dynamic_counts[index] = int(_dynamic_counts.get(index, 0)) + 1
			_solid[index] = 1
			grid.set_point_solid(c, true)
			cells.append(index)
	_dynamic[id] = cells
	_regions.clear()


func remove_obstacle(id: int) -> void:
	if not _dynamic.has(id):
		return
	for index: int in _dynamic[id]:
		_dynamic_counts[index] -= 1
		if _dynamic_counts[index] == 0:
			_solid[index] = _dynamic_base[index]
			grid.set_point_solid(Vector2i(index % SIZE - HALF, index / SIZE - HALF), _solid[index] != 0)
			_dynamic_counts.erase(index)
			_dynamic_base.erase(index)
	_dynamic.erase(id)
	_regions.clear()


func _init(metres := 1.0) -> void:
	cell_metres = metres
	_solid.resize(SIZE * SIZE)
	grid.region = Rect2i(-HALF, -HALF, HALF * 2, HALF * 2)
	grid.cell_size = Vector2.ONE * cell_metres
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(
		clampi(int(floor(p.x / cell_metres)), -HALF, HALF - 1),
		clampi(int(floor(p.z / cell_metres)), -HALF, HALF - 1))


func is_free(c: Vector2i) -> bool:
	return _free_at(c.x, c.y)


func _free_at(x: int, y: int) -> bool:
	return x >= -HALF and y >= -HALF and x < HALF and y < HALF and _solid[(y + HALF) * SIZE + x + HALF] == 0


## Stamps an oriented box footprint. `half` is the local half-extent on X and Z.
func block_obb(xf: Transform3D, half_x: float, half_z: float, inflate: float) -> void:
	var ex := half_x + inflate
	var ez := half_z + inflate
	var bx := xf.basis.x.normalized()
	var bz := xf.basis.z.normalized()
	var reach := absf(bx.x) * ex + absf(bz.x) * ez
	var reach_z := absf(bx.z) * ex + absf(bz.z) * ez
	var o := xf.origin
	for cx in range(int(floor((o.x - reach) / cell_metres)), int(ceil((o.x + reach) / cell_metres)) + 1):
		for cz in range(int(floor((o.z - reach_z) / cell_metres)), int(ceil((o.z + reach_z) / cell_metres)) + 1):
			var c := Vector2i(cx, cz)
			if not grid.is_in_boundsv(c):
				continue
			var d := Vector3((cx + 0.5) * cell_metres - o.x, 0.0, (cz + 0.5) * cell_metres - o.z)
			if absf(d.dot(bx)) <= ex and absf(d.dot(bz)) <= ez:
				grid.set_point_solid(c, true)
				_solid[(cz + HALF) * SIZE + cx + HALF] = 1


func nearest_free(c: Vector2i, max_radius := 14) -> Vector2i:
	if is_free(c):
		return c
	for r in range(1, max_radius):
		for dx in range(-r, r + 1):
			for dz: int in [-r, r]:
				if is_free(c + Vector2i(dx, dz)):
					return c + Vector2i(dx, dz)
				if is_free(c + Vector2i(dz, dx)):
					return c + Vector2i(dz, dx)
	return c


## Returns ground-plane waypoints (y = 0). Empty if unreachable.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := nearest_free(cell_of(from))
	var b := nearest_free(cell_of(to))
	var cells := grid.get_id_path(a, b, true)
	var out := PackedVector3Array()
	if cells.is_empty():
		return out
	# String-pull: keep only the waypoints a straight line cannot skip.
	var last := cells.size() - 1
	var anchor := 0
	var i := 1
	var probed := 0
	while i <= last:
		if i > probed:
			probed = mini(i + PULL_STRIDE - 1, last)
			if _clear_line(cells[anchor], cells[probed]):
				i = probed + 1
				continue
		if not _clear_line(cells[anchor], cells[i]):
			out.append(_center(cells[i - 1]))
			anchor = i - 1
		i += 1
	out.append(_center(cells[last]))
	return out


func _center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * cell_metres, 0.0, (c.y + 0.5) * cell_metres)


func _clear_line(a: Vector2i, b: Vector2i) -> bool:
	var dx := float(b.x - a.x)
	var dy := float(b.y - a.y)
	var steps := int(ceil(maxf(absf(dx), absf(dy)) * 2.0))
	if steps <= 1:
		return true
	# Both ends are on the grid, so everything between them is too.
	var ox := float(a.x + HALF)
	var oy := float(a.y + HALF)
	var step_x := dx / steps
	var step_y := dy / steps
	for s in range(1, steps):
		var px := ox + step_x * s
		var py := oy + step_y * s
		# Sample the cell and its neighbours along the line so corners are not cut.
		if _solid[roundi(py) * SIZE + roundi(px)] != 0 or _solid[floori(py) * SIZE + floori(px)] != 0 or _solid[ceili(py) * SIZE + ceili(px)] != 0:
			return false
	return true


## Numbers the connected areas of free ground. A diagonal step needs both of its sides free,
## so moving along rows and columns reaches exactly what pathfinding can. Run this while
## loading: it makes `can_reach` a lookup, where a search across the map would stall a frame.
func label_regions() -> void:
	_regions.resize(SIZE * SIZE)
	_regions.fill(0)
	var stack := PackedInt32Array()
	stack.resize(SIZE * SIZE)
	var label := 0
	for start in SIZE * SIZE:
		if _solid[start] != 0 or _regions[start] != 0:
			continue
		label += 1
		_regions[start] = label
		stack[0] = start
		var top := 1
		while top > 0:
			top -= 1
			var i := stack[top]
			var col := i % SIZE
			for next: int in [i - 1 if col > 0 else -1, i + 1 if col < SIZE - 1 else -1, i - SIZE, i + SIZE]:
				if next >= 0 and next < SIZE * SIZE and _solid[next] == 0 and _regions[next] == 0:
					_regions[next] = label
					stack[top] = next
					top += 1


func can_reach(from: Vector3, to: Vector3) -> bool:
	if _regions.is_empty():
		label_regions()
	var a := nearest_free(cell_of(from))
	var b := nearest_free(cell_of(to))
	return is_free(a) and is_free(b) and _regions[(a.y + HALF) * SIZE + a.x + HALF] == _regions[(b.y + HALF) * SIZE + b.x + HALF]
