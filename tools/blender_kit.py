"""Shared modelling tools for the Blender scripts in this folder.

Coordinates are Godot metres: +Y up, -Z forward. Bodies are lofted from cross-sections with
creases, then dressed with parts projected onto them, so nothing is a plain box or cylinder.
"""
import math
import random
import sys
from contextlib import contextmanager
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, geometry
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_source"

PLATE, PLATE2, DARK, STEEL, TRIM, GLASS, LIGHT, SOFT = "Plate", "Plate2", "Dark", "Steel", "Trim", "Glass", "Light", "LightSoft"
## Name -> (linear colour, metallic, roughness, emission). Each model script fills this in.
PALETTE = {}
OFFSET = [Vector((0, 0, 0))]
PARTS = {}
BVH = {}


def B(p):
    """Godot metres, relative to the current `at()` block, to Blender space."""
    q = Vector(p) + OFFSET[-1]
    return Vector((q.x, -q.z, q.y))


def dirB(p):
    return Vector((p[0], -p[2], p[1]))


@contextmanager
def at(*pos):
    OFFSET.append(OFFSET[-1] + Vector(pos))
    yield
    OFFSET.pop()


def material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    rgb, metal, rough, glow = PALETTE[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if glow:
        p.inputs["Emission Color"].default_value = (*rgb, 1)
        p.inputs["Emission Strength"].default_value = glow
    return m


def add(part, name, verts, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.update()
    mesh.materials.append(material(mat))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    PARTS.setdefault(part, []).append(obj)
    return obj


def bake_modifiers(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    obj.modifiers.clear()
    old = obj.data
    obj.data = mesh
    bpy.data.meshes.remove(old)


def outward(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


def chamfer(obj, width, angle=26.0, segments=1):
    if width > 0:
        mod = obj.modifiers.new("edge", "BEVEL")
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(angle)
        mod.width = width
        mod.segments = segments
        mod.miter_outer = "MITER_ARC"
        bake_modifiers(obj)


def rings_to_faces(count, n, cap=True):
    faces = []
    for i in range(count - 1):
        for j in range(n):
            faces.append((i * n + j, i * n + (j + 1) % n, (i + 1) * n + (j + 1) % n, (i + 1) * n + j))
    if cap:
        faces.append(tuple(range(n - 1, -1, -1)))
        faces.append(tuple((count - 1) * n + j for j in range(n)))
    return faces


def sculpt(part, name, rings, mat, sharp=(), level=2, bevel=0.012, soft=1.0):
    """Lofts closed rings into a smooth body. Indices in `sharp` stay as crisp creases along it."""
    n = len(rings[0])
    verts = [B(p) for ring in rings for p in ring]
    obj = add(part, name, verts, rings_to_faces(len(rings), n), mat)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    crease = bm.edges.layers.float.get("crease_edge") or bm.edges.layers.float.new("crease_edge")
    for i in range(len(rings) - 1):
        for j in sharp:
            edge = bm.edges.get((bm.verts[i * n + j], bm.verts[(i + 1) * n + j]))
            if edge:
                edge[crease] = soft
    for i in (0, len(rings) - 1):
        for j in range(n):
            edge = bm.edges.get((bm.verts[i * n + j], bm.verts[i * n + (j + 1) % n]))
            if edge:
                edge[crease] = 1.0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    if level:
        mod = obj.modifiers.new("smooth", "SUBSURF")
        mod.levels = level
        mod.render_levels = level
        bake_modifiers(obj)
    chamfer(obj, bevel)
    return obj


def mirrored_rings(stations):
    """Half profiles, keel first and spine last, into rings: [(z, [(x, y), ...]), ...]."""
    rings = []
    for z, pts in stations:
        right = [(x, y, z) for x, y in pts]
        rings.append(right + [(-x, y, z) for x, y in pts[-2:0:-1]])
    return rings


def mirror_sharp(indices, count):
    ring = 2 * count - 2
    return sorted({i for i in indices} | {(ring - i) % ring for i in indices})


def body(part, name, stations, mat, sharp, **kw):
    return sculpt(part, name, mirrored_rings(stations), mat, mirror_sharp(sharp, len(stations[0][1])), **kw)


def box_ring(cx, cy, z, w, h, cut):
    """A chamfered, eight-sided section. `cut` is how much each corner loses."""
    return [(cx + w - cut, cy - h, z), (cx + w, cy - h + cut, z), (cx + w, cy + h - cut, z), (cx + w - cut, cy + h, z),
            (cx - w + cut, cy + h, z), (cx - w, cy + h - cut, z), (cx - w, cy - h + cut, z), (cx - w + cut, cy - h, z)]


def section(part, name, stations, mat, bevel=0.006, cx=0.0, cy=0.0):
    """A straight-edged run along Z, for guns and fittings: [(z, half_w, half_h, cut), ...]."""
    rings = [box_ring(cx, cy, z, w, h, cut) for z, w, h, cut in stations]
    obj = add(part, name, [B(p) for ring in rings for p in ring], rings_to_faces(len(rings), 8), mat)
    outward(obj)
    chamfer(obj, bevel, 20.0)
    return obj


def round_ring(cx, cy, z, rx, ry, sides, squash=2.6):
    """A superellipse: rounded, but squarer than a circle, as cast and machined parts are."""
    ring = []
    for i in range(sides):
        a = math.tau * i / sides
        c, s = math.cos(a), math.sin(a)
        ring.append((cx + rx * math.copysign(abs(c) ** (2 / squash), c), cy + ry * math.copysign(abs(s) ** (2 / squash), s), z))
    return ring


def turned(part, name, stations, mat, sides=14, cx=0.0, cy=0.0, squash=2.0, bevel=0.0):
    """Stations along Z: [(z, radius), ...] or [(z, rx, ry), ...]."""
    rings = []
    for st in stations:
        rx = st[1]
        ry = st[2] if len(st) > 2 else rx
        rings.append(round_ring(cx, cy, st[0], rx, ry, sides, squash))
    obj = add(part, name, [B(p) for ring in rings for p in ring], rings_to_faces(len(rings), sides), mat)
    outward(obj)
    chamfer(obj, bevel, 40.0)
    return obj


def upright(part, name, stations, mat, sides=14, cx=0.0, cz=0.0, squash=2.0, bevel=0.0):
    """As `turned`, standing along Y: [(y, rx, rz), ...]."""
    rings = []
    for y, rx, rz in stations:
        ring = round_ring(cx, cz, 0, rx, rz, sides, squash)
        rings.append([(p[0], y, p[1]) for p in ring])
    obj = add(part, name, [B(p) for ring in rings for p in ring], rings_to_faces(len(rings), sides), mat)
    outward(obj)
    chamfer(obj, bevel, 40.0)
    return obj


def slab(part, name, outline, x0, x1, mat, bevel=0.01):
    """An outline drawn from the side as (z, y), given thickness across X. For brackets and fins."""
    n = len(outline)
    verts = [B((x0, y, z)) for z, y in outline] + [B((x1, y, z)) for z, y in outline]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    faces += [(j, (j + 1) % n, n + (j + 1) % n, n + j) for j in range(n)]
    obj = add(part, name, verts, faces, mat)
    outward(obj)
    chamfer(obj, bevel, 20.0)
    return obj


def tube(part, name, points, radius, mat, sides=6):
    pts = [Vector(p) for p in points]
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = d.cross(Vector((0, 1, 0)))
        if side.length < 0.01:
            side = d.cross(Vector((1, 0, 0)))
        side.normalize()
        up = side.cross(d)
        rings.append([p + (side * math.cos(math.tau * k / sides) + up * math.sin(math.tau * k / sides)) * radius for k in range(sides)])
    obj = add(part, name, [B(p) for ring in rings for p in ring], rings_to_faces(len(rings), sides), mat)
    outward(obj)
    return obj


# ---------------------------------------------------------------- plates projected onto a body

AXES = {
    "top": (lambda a, b: (a, 9, b), (0, -1, 0)),
    "bottom": (lambda a, b: (a, -9, b), (0, 1, 0)),
    "right": (lambda a, b: (9, b, a), (-1, 0, 0)),
    "left": (lambda a, b: (-9, b, a), (1, 0, 0)),
    "front": (lambda a, b: (a, b, -9), (0, 0, 1)),
    "rear": (lambda a, b: (a, b, 9), (0, 0, -1)),
}


def tree(target):
    key = target.name
    if key not in BVH:
        mesh = target.data
        BVH[key] = BVHTree.FromPolygons([v.co.copy() for v in mesh.vertices], [tuple(p.vertices) for p in mesh.polygons])
    return BVH[key]


def forget(target):
    BVH.pop(target.name, None)


def signed_area(poly):
    return sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly))) * 0.5


def inset(poly, d):
    """Moves a counter-clockwise outline inwards by `d`, keeping corners mitred."""
    out = []
    n = len(poly)
    for i in range(n):
        p = Vector(poly[i])
        a = (p - Vector(poly[i - 1])).normalized()
        b = (Vector(poly[(i + 1) % n]) - p).normalized()
        na = Vector((-a.y, a.x))
        nb = Vector((-b.y, b.x))
        bis = (na + nb).normalized()
        out.append(tuple(p + bis * min(d / max(bis.dot(na), 0.3), d * 2.5)))
    return out


def inside(p, poly):
    hit = False
    x, y = p
    for i in range(len(poly)):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % len(poly)]
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            hit = not hit
    return hit


def edge_distance(p, poly):
    best = 1e9
    q = Vector(p)
    for i in range(len(poly)):
        a, b = Vector(poly[i]), Vector(poly[(i + 1) % len(poly)])
        t = max(0.0, min(1.0, (q - a).dot(b - a) / max((b - a).length_squared, 1e-9)))
        best = min(best, (q - (a + (b - a) * t)).length)
    return best


def project(target, axis, a, b):
    origin_of, direction = AXES[axis]
    origin = B(origin_of(a, b))
    d = dirB(direction)
    hit = tree(target).ray_cast(origin, d, 30.0)
    if hit[0] is not None:
        return hit[0], hit[1]
    near = tree(target).find_nearest(origin + d * 8.0)
    return near[0], near[1]


def plate(part, name, outline, axis, target, mat, thick=0.03, rim=0.016, cell=0.14, mirror=False, lift=0.0):
    """Lays a bevelled plate on `target`, seen along `axis`, following its curvature."""
    if mirror:
        twin = "left" if axis == "right" else "right" if axis == "left" else axis
        flip = axis in ("top", "bottom", "front", "rear")
        plate(part, name + " R", outline, axis, target, mat, thick, rim, cell, False, lift)
        plate(part, name + " L", [(-a, b) for a, b in outline] if flip else list(outline), twin, target, mat, thick, rim, cell, False, lift)
        return
    poly = [tuple(p) for p in outline]
    if signed_area(poly) < 0:
        poly.reverse()
    ring = inset(poly, rim)
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    interior = []
    a = min(xs)
    while a < max(xs):
        b = min(ys)
        while b < max(ys):
            if inside((a, b), ring) and edge_distance((a, b), ring) > cell * 0.35:
                interior.append((a, b))
            b += cell
        a += cell
    coords = [Vector(p) for p in poly + ring + interior]
    n, m = len(poly), len(ring)
    edges = [(n + i, n + (i + 1) % m) for i in range(m)]
    out = geometry.delaunay_2d_cdt(coords, edges, [list(range(n))], 1, 1e-6)
    verts2, faces2 = out[0], out[2]
    verts = []
    roots = []
    for v in verts2:
        point, normal = project(target, axis, v.x, v.y)
        edge = edge_distance((v.x, v.y), poly) < 1e-4
        verts.append(point + normal * (lift + (0.0 if edge else thick)))
        roots.append(point - normal * 0.02)
    obj = add(part, name, verts, [tuple(f) for f in faces2], mat)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    # A skirt below the rim, so no light leaks between the plate and the surface it sits on.
    border = [e for e in bm.edges if len(e.link_faces) == 1]
    lower = {}
    for e in border:
        for v in e.verts:
            if v.index not in lower:
                lower[v.index] = bm.verts.new(roots[v.index])
    for e in border:
        a2, b2 = e.verts
        bm.faces.new((a2, b2, lower[b2.index], lower[a2.index]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    # The hit normal can only tell the plate which way is out, so make sure it faces that way.
    centre = sum((Vector(v) for v in verts), Vector()) / len(verts)
    probe = project(target, axis, sum(xs) / len(xs), sum(ys) / len(ys))[1]
    poly0 = max(obj.data.polygons, key=lambda p: p.area)
    if poly0.normal.dot(probe) < 0:
        obj.data.flip_normals() if hasattr(obj.data, "flip_normals") else _flip(obj)
    return obj


def _flip(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


def grille(part, name, outline, axis, target, slats, frame=PLATE2, slat=STEEL, cut=0.075, mirror=False):
    """A raised frame around a dark floor crossed by angled slats. `slats` lie across the outline."""
    if mirror:
        grille(part, name + " R", outline, axis, target, slats, frame, slat, cut)
        flip = axis in ("top", "bottom", "front", "rear")
        twin = "left" if axis == "right" else "right" if axis == "left" else axis
        grille(part, name + " L", [(-a, b) for a, b in outline] if flip else list(outline), twin, target, slats, frame, slat, cut)
        return
    plate(part, name + " frame", outline, axis, target, frame, 0.022, 0.012, 0.2)
    poly = [tuple(p) for p in outline]
    if signed_area(poly) < 0:
        poly.reverse()
    floor = inset(poly, cut)
    plate(part, name + " floor", floor, axis, target, DARK, 0.03, 0.002, 0.25)
    a0, a1 = min(p[0] for p in floor), max(p[0] for p in floor)
    b0, b1 = min(p[1] for p in floor), max(p[1] for p in floor)
    for i in range(slats):
        b = b0 + (b1 - b0) * (i + 0.5) / slats
        hits = []
        for k in range(len(floor)):
            (x0, y0), (x1, y1) = floor[k], floor[(k + 1) % len(floor)]
            if (y0 > b) != (y1 > b):
                hits.append(x0 + (b - y0) * (x1 - x0) / (y1 - y0))
        if len(hits) >= 2:
            lo, hi = min(hits) + 0.01, max(hits) - 0.01
            h = (b1 - b0) / slats * 0.32
            plate(part, f"{name} slat {i}", [(lo, b - h), (hi, b - h), (hi, b + h), (lo, b + h)], axis, target, slat, 0.05, 0.008, 0.5)


def stripe(part, name, line, width, axis, target, mat, thick=0.012, mirror=False):
    """A narrow strip following a line on the surface, for trim and lamps."""
    left, right = [], []
    for i, p in enumerate(line):
        a = Vector(line[max(i - 1, 0)])
        b = Vector(line[min(i + 1, len(line) - 1)])
        d = (b - a).normalized()
        nrm = Vector((-d.y, d.x)) * width * 0.5
        left.append(tuple(Vector(p) + nrm))
        right.append(tuple(Vector(p) - nrm))
    return plate(part, name, left + right[::-1], axis, target, mat, thick, min(0.006, width * 0.25), 0.3, mirror)


def seam(part, line, axis, target, mirror=False):
    """A dark joint between panels. Lines this thin are what make the plates read as real size."""
    stripe(part, "Seam", line, 0.014, axis, target, DARK, 0.0035, mirror)


def studs(part, name, start, end, count, axis, target, radius=0.02, mat=STEEL):
    """A row of fasteners between two points, seen along `axis`."""
    verts, faces = [], []
    for i in range(count):
        t = i / max(count - 1, 1)
        point, normal = project(target, axis, start[0] + (end[0] - start[0]) * t, start[1] + (end[1] - start[1]) * t)
        u = normal.orthogonal().normalized()
        v = normal.cross(u)
        base = len(verts)
        for ring_radius, height in ((radius, -0.004), (radius, 0.012), (radius * 0.62, 0.02)):
            for k in range(6):
                a = math.tau * k / 6
                verts.append(point + (u * math.cos(a) + v * math.sin(a)) * ring_radius + normal * height)
        for r in range(2):
            for k in range(6):
                faces.append((base + r * 6 + k, base + r * 6 + (k + 1) % 6, base + (r + 1) * 6 + (k + 1) % 6, base + (r + 1) * 6 + k))
        faces.append(tuple(base + 12 + k for k in range(6)))
    obj = add(part, name, verts, faces, mat)
    outward(obj)
    return obj


def canister(part, name, x, y, z, length, radius):
    """A strapped coolant bottle lying along the blade."""
    turned(part, name, [(z - length / 2, radius * 0.5), (z - length / 2 + 0.05, radius * 0.92), (z - length / 2 + 0.1, radius), (z + length / 2 - 0.1, radius),
                        (z + length / 2 - 0.05, radius * 0.92), (z + length / 2, radius * 0.5)], STEEL, 12, x, y)
    for f in (-0.28, 0.28):
        turned(part, name + " strap", [(z + length * f - 0.03, radius * 1.05), (z + length * f + 0.03, radius * 1.05)], DARK, 12, x, y)


def join(name):
    objs = PARTS[name]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def shade(obj, angle=26.0):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    limit = math.radians(angle)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = len(e.link_faces) == 2 and e.calc_face_angle(9.0) < limit
    bm.to_mesh(obj.data)
    bm.free()


# ---------------------------------------------------------------- machined parts

def fillet(points, seg=3):
    """Rounds an outline. A point given as (a, b, r) becomes an arc of radius r."""
    out = []
    n = len(points)
    for i, p in enumerate(points):
        r = p[2] if len(p) > 2 else 0.0
        here = Vector(p[:2])
        if r <= 0:
            out.append(tuple(here))
            continue
        a = (Vector(points[i - 1][:2]) - here)
        b = (Vector(points[(i + 1) % n][:2]) - here)
        la, lb = a.length, b.length
        a.normalize()
        b.normalize()
        angle = a.angle(b, math.pi)
        reach = min(r / max(math.tan(angle / 2), 0.05), la * 0.48, lb * 0.48)
        start = here + a * reach
        end = here + b * reach
        for k in range(seg + 1):
            t = k / seg
            # A quadratic curve through the corner is close enough to an arc at this scale.
            out.append(tuple(start * (1 - t) ** 2 + here * (2 * t * (1 - t)) + end * t ** 2))
    return out


def worn_chamfer(obj, width, angle=24.0, segments=1):
    """As `chamfer`, but remembers which faces are the new edges: paint wears off those first."""
    if width <= 0:
        return
    slot = len(obj.data.materials)
    obj.data.materials.append(material("_Worn"))
    mod = obj.modifiers.new("edge", "BEVEL")
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.width = width
    mod.segments = segments
    mod.material = slot
    mod.miter_outer = "MITER_ARC"
    bake_modifiers(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    worn = bm.faces.layers.int.get("worn") or bm.faces.layers.int.new("worn")
    for f in bm.faces:
        if f.material_index == slot:
            f[worn] = 1
            f.material_index = 0
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.pop(index=slot)


def profile(part, name, outline, half, mat, bevel=0.0016, holes=(), segments=1, x=0.0, seg=3):
    """A side outline as (z, y[, radius]) given thickness across X, with real holes through it."""
    ring = fillet(outline, seg)
    if signed_area(ring) < 0:
        ring.reverse()
    loops = [ring]
    for hole in holes:
        h = fillet(hole, 2)
        if signed_area(h) < 0:
            h.reverse()
        loops.append(h)
    coords, faces_in = [], []
    for loop in loops:
        faces_in.append(list(range(len(coords), len(coords) + len(loop))))
        coords += [Vector(p) for p in loop]
    out = geometry.delaunay_2d_cdt(coords, [], faces_in, 2, 1e-7)
    flat, tris = out[0], out[2]
    count = len(flat)
    verts = [B((x + half, v.y, v.x)) for v in flat] + [B((x - half, v.y, v.x)) for v in flat]
    faces = [tuple(t) for t in tris] + [tuple(i + count for i in reversed(t)) for t in tris]
    key = {(round(v.x, 6), round(v.y, 6)): i for i, v in enumerate(flat)}
    for loop in loops:
        ids = [key.get((round(p[0], 6), round(p[1], 6))) for p in loop]
        ids = [i for i in ids if i is not None]
        for j in range(len(ids)):
            a, b = ids[j], ids[(j + 1) % len(ids)]
            faces.append((a, b, b + count, a + count))
    obj = add(part, name, verts, faces, mat)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    worn_chamfer(obj, bevel, 24.0, segments)
    return obj


def lathe(part, name, stations, mat, sides=14, cy=0.0, cx=0.0, bevel=0.0):
    """Turned along Z: [(z, radius), ...]. Edges above the shading angle stay crisp."""
    obj = turned(part, name, stations, mat, sides, cx, cy)
    worn_chamfer(obj, bevel, 35.0)
    return obj


def fluted(part, name, z0, z1, radius, cy, mat, flutes=6, depth=0.14, cx=0.0):
    """A barrel with long grooves cut along it."""
    sides = flutes * 4
    rings = []
    for z in (z0, z1):
        ring = []
        for i in range(sides):
            a = math.tau * i / sides
            r = radius * (1 - depth if i % 4 in (1, 2) else 1)
            ring.append((cx + r * math.cos(a), cy + r * math.sin(a), z))
        rings.append(ring)
    obj = add(part, name, [B(p) for ring in rings for p in ring], rings_to_faces(2, sides), mat)
    outward(obj)
    return obj


def bake_wear(obj, reach=0.05, rays=8, base=0.66):
    """Vertex colour multiplies the paint: darker in recesses, full brightness on worn edges."""
    mesh = obj.data
    if not mesh.vertices:
        return
    whole = BVHTree.FromPolygons([v.co.copy() for v in mesh.vertices], [tuple(p.vertices) for p in mesh.polygons])
    rnd = random.Random(11)
    dirs = []
    for _ in range(rays):
        u, a = rnd.random(), rnd.random() * math.tau
        r = math.sqrt(u)
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(1 - u))))
    shade_of = []
    for v in mesh.vertices:
        n = v.normal
        t = n.orthogonal().normalized()
        b = n.cross(t)
        start = v.co + n * 0.0006
        free = sum(1 for d in dirs if whole.ray_cast(start, t * d.x + b * d.y + n * d.z, reach)[0] is None)
        shade_of.append(0.6 + 0.4 * free / rays)
    worn = mesh.attributes.get("worn")
    attr = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for poly in mesh.polygons:
        edge = worn is not None and worn.data[poly.index].value == 1
        for li in poly.loop_indices:
            s = shade_of[mesh.loops[li].vertex_index]
            value = (1.0 if edge else base) * s
            attr.data[li].color = (value, value, value, 1)
    mesh.color_attributes.active_color_index = 0
