"""Street props for the maps: hover cars, a bus, trees, lamps, street furniture and battle wrecks.

Run: blender --background --factory-startup --python tools/blender_city.py
Writes assets/models/city/props.glb and art_source/city.blend. Every prop is one mesh named after
it, standing on the ground at its origin, and cars point along -Z. The game places them with
MultiMesh, tints the "Paint" and "Leaf" materials per copy and supplies all other materials itself.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

sys.path.insert(0, str(Path(__file__).parent))
from blender_kit import B, PALETTE, PARTS, ROOT, SOURCE, add, at, bake_wear, body, chamfer, join, outward, shade, sculpt, mirrored_rings, mirror_sharp, rings_to_faces, section, turned, upright

OUT = ROOT / "assets" / "models" / "city"
PAINT, GLASS, DARK, CHROME, RUBBER = "Paint", "Glass", "Dark", "Chrome", "Rubber"
LED, TAIL, GLOW_C, GLOW_P, AMBER, SCREEN = "Led", "Tail", "GlowCyan", "GlowPink", "GlowAmber", "Screen"
BARK, LEAF, FRUIT, CONCRETE, STEEL, BURNT, RUST, DEADWOOD, IRON = "Bark", "Leaf", "Fruit", "Concrete", "Steel", "Burnt", "Rust", "DeadWood", "Iron"
FROND, WOOD, MUDDY, BAG, WIRE, CANVAS = "Frond", "Wood", "Muddy", "Bag", "Wire", "Canvas"
PALETTE.update({
    PAINT: ((0.8, 0.8, 0.8), 0.6, 0.3, 0), GLASS: ((0.03, 0.05, 0.08), 0.4, 0.08, 0), DARK: ((0.03, 0.03, 0.035), 0.3, 0.6, 0),
    CHROME: ((0.75, 0.76, 0.8), 1.0, 0.2, 0), RUBBER: ((0.02, 0.02, 0.02), 0.0, 0.85, 0),
    LED: ((1.0, 0.96, 0.86), 0, 0.3, 5), TAIL: ((1.0, 0.05, 0.08), 0, 0.3, 4), GLOW_C: ((0.05, 0.8, 1.0), 0, 0.3, 4), GLOW_P: ((1.0, 0.06, 0.45), 0, 0.3, 4),
    AMBER: ((1.0, 0.55, 0.1), 0, 0.3, 4), SCREEN: ((0.2, 0.42, 0.7), 0, 0.2, 2),
    BARK: ((0.09, 0.07, 0.06), 0, 0.9, 0), LEAF: ((0.8, 0.8, 0.8), 0, 0.75, 0), FRUIT: ((1.0, 0.75, 0.4), 0, 0.3, 4), CONCRETE: ((0.5, 0.5, 0.5), 0, 0.9, 0),
    STEEL: ((0.3, 0.32, 0.36), 0.8, 0.45, 0), BURNT: ((0.08, 0.07, 0.06), 0.2, 0.85, 0), RUST: ((0.2, 0.09, 0.05), 0.3, 0.8, 0),
    DEADWOOD: ((0.1, 0.085, 0.075), 0, 0.95, 0), IRON: ((0.05, 0.055, 0.06), 0.7, 0.5, 0),
    FROND: ((0.8, 0.8, 0.8), 0, 0.7, 0), WOOD: ((0.2, 0.14, 0.09), 0, 0.9, 0), MUDDY: ((0.09, 0.07, 0.05), 0, 0.95, 0),
    BAG: ((0.3, 0.25, 0.17), 0, 0.95, 0), WIRE: ((0.1, 0.08, 0.07), 0.8, 0.6, 0), CANVAS: ((0.2, 0.2, 0.14), 0, 0.9, 0),
})
PROPS = []


def begin(name):
    PROPS.append(name)
    return name


def mesh(part, name, verts, faces, mat):
    obj = add(part, name, [B(v) for v in verts], faces, mat)
    outward(obj)
    return obj


def box(part, name, centre, size, mat, turn=(0, 0, 0), bevel=0.0):
    """A box in Godot metres; `turn` is pitch, yaw, roll in radians."""
    rot = Matrix.Rotation(turn[1], 3, "Y") @ Matrix.Rotation(turn[0], 3, "X") @ Matrix.Rotation(turn[2], 3, "Z")
    c = Vector(centre)
    h = Vector(size) / 2
    corners = [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]
    verts = [c + rot @ Vector((x * h.x, y * h.y, z * h.z)) for x, y, z in corners]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3)]
    obj = mesh(part, name, verts, faces, mat)
    if bevel:
        chamfer(obj, bevel, 30.0)
    return obj


def limb(part, name, points, radii, mat, sides=6):
    """A tapering tube along points, for trunks, branches and curved poles."""
    pts = [Vector(p) for p in points]
    rings = []
    side = Vector((1, 0, 0))
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = (side - d * side.dot(d))
        if side.length < 0.01:
            side = d.orthogonal()
        side.normalize()
        up = side.cross(d)
        r = radii[i]
        rings.append([p + (side * math.cos(math.tau * k / sides) + up * math.sin(math.tau * k / sides)) * r for k in range(sides)])
    return mesh(part, name, [v for ring in rings for v in ring], rings_to_faces(len(rings), sides), mat)


def blob(part, name, centre, radius, mat, seed, squash=(1, 0.82, 1), rough=0.34, level=2):
    """A lumpy ball of leaves."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=level, radius=1.0)
    verts, faces = [], []
    for v in bm.verts:
        n = noise.noise(v.co * 1.9 + Vector((seed, seed * 0.7, seed * 1.3)))
        p = v.co * (1 + n * rough * 2.0)
        verts.append(Vector(centre) + Vector((p.x * squash[0], p.y * squash[1], p.z * squash[2])) * radius)
    for f in bm.faces:
        faces.append(tuple(v.index for v in f.verts))
    bm.free()
    return mesh(part, name, verts, faces, mat)


def disc(part, name, centre, radius, height, mat, sides=12):
    c = Vector(centre)
    return upright(part, name, [(c.y, radius, radius), (c.y + height, radius, radius)], mat, sides, c.x, c.z)


# ---------------------------------------------------------------- cars

def _section(w, y0, y1, crown=0.05):
    h = y1 - y0
    return [(0, y0), (w * 0.74, y0), (w, y0 + h * 0.2), (w, y0 + h * 0.62), (w * 0.94, y1 - 0.01), (w * 0.5, y1 + crown * 0.8), (0, y1 + crown)]


def _hover_pods(part, half_w, front, rear, y):
    for x in (-half_w, half_w):
        for z in (front, rear):
            with at(x, 0, z):
                disc(part, "pod", (0, y - 0.12, 0), 0.34, 0.16, DARK, 12)
                disc(part, "pod glow", (0, y - 0.16, 0), 0.26, 0.05, GLOW_C, 12)


def _lights(part, half_w, nose, tail, y_front, y_tail):
    box(part, "headlight", (0, y_front, nose + 0.03), (half_w * 1.5, 0.05, 0.05), LED)
    for s in (-1, 1):
        box(part, "lamp", (s * half_w * 0.62, y_front + 0.02, nose + 0.05), (half_w * 0.5, 0.09, 0.08), LED)
    box(part, "tail light", (0, y_tail, tail - 0.03), (half_w * 1.72, 0.06, 0.05), TAIL)


def _seams(part, half_w, xs, y0, y1):
    for z in xs:
        for s in (-1, 1):
            box(part, "door seam", (s * (half_w + 0.003), (y0 + y1) / 2, z), (0.012, y1 - y0, 0.014), DARK)


def sedan():
    p = begin("car_sedan")
    stations = [
        (-2.32, _section(0.58, 0.47, 0.6, 0.0)), (-2.2, _section(0.8, 0.38, 0.68, 0.02)), (-1.65, _section(0.93, 0.31, 0.8, 0.05)),
        (-0.8, _section(0.97, 0.29, 0.9, 0.05)), (0.2, _section(0.98, 0.29, 0.92, 0.05)), (1.2, _section(0.97, 0.3, 0.94, 0.05)),
        (1.9, _section(0.92, 0.33, 0.96, 0.03)), (2.28, _section(0.68, 0.45, 0.9, 0.0)),
    ]
    body(p, "shell", stations, PAINT, [2, 4], level=1, bevel=0.0)
    cabin = [
        (-1.05, [(0, 0.86), (0.78, 0.86), (0.7, 0.93), (0, 0.96)]), (-0.55, [(0, 0.86), (0.84, 0.86), (0.66, 1.3), (0, 1.36)]),
        (0.35, [(0, 0.86), (0.85, 0.86), (0.67, 1.36), (0, 1.42)]), (1.05, [(0, 0.88), (0.84, 0.88), (0.66, 1.3), (0, 1.36)]), (1.72, [(0, 0.92), (0.78, 0.92), (0.6, 0.98), (0, 1.0)]),
    ]
    body(p, "cabin", cabin, GLASS, [1, 2], level=1, bevel=0.0)
    roof = [(-0.42, [(0, 1.34), (0.6, 1.34), (0.58, 1.36), (0, 1.41)]), (0.4, [(0, 1.38), (0.62, 1.38), (0.6, 1.4), (0, 1.455)]), (0.98, [(0, 1.32), (0.6, 1.32), (0.58, 1.34), (0, 1.39)])]
    body(p, "roof", roof, PAINT, [1], level=1, bevel=0.0)
    for s in (-1, 1):
        limb(p, "pillar", [(s * 0.84, 0.9, -1.0), (s * 0.66, 1.34, -0.42)], [0.04, 0.03], PAINT, 5)
        limb(p, "pillar", [(s * 0.86, 0.9, 0.3), (s * 0.67, 1.38, 0.3)], [0.05, 0.04], PAINT, 5)
        limb(p, "pillar", [(s * 0.82, 0.92, 1.56), (s * 0.63, 1.34, 0.98)], [0.06, 0.04], PAINT, 5)
        box(p, "mirror", (s * 1.0, 0.98, -0.75), (0.18, 0.1, 0.09), PAINT)
        box(p, "skirt", (s * 0.98, 0.33, 0.0), (0.04, 0.06, 3.3), DARK)
        box(p, "side glow", (s * 0.985, 0.36, 0.0), (0.03, 0.025, 3.0), GLOW_C)
    _seams(p, 0.975, (-0.75, 0.28, 1.25), 0.36, 0.86)
    _lights(p, 0.78, -2.32, 2.28, 0.6, 0.76)
    box(p, "grille", (0, 0.47, -2.33), (0.9, 0.1, 0.05), DARK)
    _hover_pods(p, 0.68, -1.5, 1.45, 0.3)


def sport():
    p = begin("car_sport")
    stations = [
        (-2.4, _section(0.66, 0.3, 0.38, 0.0)), (-2.2, _section(0.86, 0.26, 0.46, 0.03)), (-1.5, _section(0.98, 0.24, 0.6, 0.06)),
        (-0.5, _section(1.02, 0.24, 0.7, 0.04)), (0.5, _section(1.04, 0.24, 0.76, 0.04)), (1.4, _section(1.03, 0.26, 0.84, 0.03)), (2.2, _section(0.84, 0.32, 0.86, 0.0)),
    ]
    body(p, "shell", stations, PAINT, [2, 4], level=1, bevel=0.0)
    bubble = [(-1.15, [(0, 0.6), (0.7, 0.6), (0.6, 0.66), (0, 0.7)]), (-0.3, [(0, 0.68), (0.8, 0.68), (0.58, 1.04), (0, 1.13)]), (0.5, [(0, 0.72), (0.8, 0.72), (0.56, 1.08), (0, 1.16)]), (1.4, [(0, 0.82), (0.66, 0.82), (0.5, 0.88), (0, 0.9)])]
    body(p, "canopy", bubble, GLASS, [1], level=1, bevel=0.0)
    for s in (-1, 1):
        box(p, "air intake", (s * 1.03, 0.5, 0.75), (0.04, 0.22, 0.7), DARK, (0, 0, s * 0.1))
        box(p, "stripe", (s * 1.045, 0.34, 0), (0.02, 0.03, 3.4), GLOW_P)
    for s in (-1, 1):
        box(p, "wing post", (s * 0.7, 0.98, 2.0), (0.06, 0.22, 0.2), PAINT)
    box(p, "wing", (0, 1.1, 2.05), (1.9, 0.05, 0.42), PAINT, (0.1, 0, 0), 0.01)
    _lights(p, 0.8, -2.42, 2.2, 0.36, 0.72)
    _hover_pods(p, 0.76, -1.5, 1.5, 0.24)


def van():
    p = begin("car_van")
    def ring(w, y0, y1):
        return [(0, y0), (w * 0.86, y0), (w, y0 + 0.18), (w, y1 - 0.16), (w * 0.84, y1), (0, y1 + 0.02)]
    stations = [(-2.5, ring(0.74, 0.46, 0.92)), (-2.36, ring(0.9, 0.34, 1.16)), (-1.7, ring(0.98, 0.3, 1.86)), (-1.2, ring(1.0, 0.3, 2.02)), (0.4, ring(1.0, 0.3, 2.06)), (2.3, ring(1.0, 0.32, 2.04)), (2.46, ring(0.9, 0.42, 1.92))]
    body(p, "shell", stations, PAINT, [2, 3], level=1, bevel=0.0)
    box(p, "windscreen", (0, 1.55, -1.92), (1.7, 0.66, 0.05), GLASS, (0.5, 0, 0))
    for s in (-1, 1):
        box(p, "cab window", (s * 1.0, 1.52, -1.25), (0.03, 0.6, 0.86), GLASS)
        box(p, "cargo rib", (s * 1.005, 0.95, 0.9), (0.02, 0.05, 2.7), DARK)
        box(p, "cargo glow", (s * 1.006, 1.6, 0.9), (0.02, 0.06, 2.7), AMBER)
        box(p, "skirt", (s * 0.99, 0.36, 0), (0.04, 0.06, 3.6), DARK)
    _seams(p, 1.0, (-0.72,), 0.4, 1.8)
    box(p, "rear door", (0, 1.2, 2.47), (0.02, 1.4, 0.04), DARK)
    _lights(p, 0.82, -2.5, 2.46, 0.74, 0.9)
    _hover_pods(p, 0.72, -1.7, 1.7, 0.32)


def bus():
    p = begin("bus")
    def ring(w, y0, y1):
        return [(0, y0), (w * 0.9, y0), (w, y0 + 0.2), (w, y1 - 0.26), (w * 0.86, y1), (0, y1 + 0.03)]
    stations = [(-6.0, ring(1.1, 0.5, 2.1)), (-5.86, ring(1.28, 0.34, 2.72)), (-4.8, ring(1.38, 0.3, 2.96)), (0, ring(1.4, 0.3, 3.0)), (4.8, ring(1.38, 0.3, 2.96)), (5.9, ring(1.26, 0.36, 2.8)), (6.0, ring(1.1, 0.5, 2.3))]
    body(p, "shell", stations, PAINT, [2, 3], level=1, bevel=0.0)
    box(p, "windscreen", (0, 1.9, -5.86), (2.3, 1.5, 0.08), GLASS, (0.1, 0, 0))
    box(p, "rear window", (0, 2.1, 5.98), (2.0, 0.9, 0.05), GLASS)
    for s in (-1, 1):
        for i in range(6):
            z = -3.9 + i * 1.82
            if s > 0 and i in (1, 4):
                box(p, "door", (s * 1.405, 1.52, z), (0.04, 2.3, 1.36), GLASS)
                box(p, "door line", (s * 1.42, 1.52, z), (0.02, 2.3, 0.03), DARK)
            else:
                box(p, "window", (s * 1.405, 2.0, z), (0.04, 1.14, 1.6), GLASS)
        box(p, "belt", (s * 1.41, 1.34, 0), (0.03, 0.06, 11.0), GLOW_C)
        box(p, "skirt", (s * 1.39, 0.36, 0), (0.05, 0.08, 10.6), DARK)
    for z in (-3.4, 0.2, 3.6):
        box(p, "roof unit", (0, 3.1, z), (1.7, 0.24, 2.0), DARK, (0, 0, 0), 0.03)
    box(p, "route sign", (0, 2.86, -5.9), (1.5, 0.22, 0.05), AMBER)
    _lights(p, 1.06, -6.0, 6.0, 0.82, 1.1)
    for z in (-4.2, 0.0, 4.2):
        _hover_pods(p, 0.95, z, z, 0.36)


# ---------------------------------------------------------------- trees

def _grow(part, rnd, start, direction, length, radius, depth, tips, droop=0.0):
    points, radii = [Vector(start)], [radius]
    d = Vector(direction).normalized()
    segments = 4
    for i in range(segments):
        d = (d + Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.1, 0.22) - droop, rnd.uniform(-0.3, 0.3)))).normalized()
        points.append(points[-1] + d * length / segments)
        radii.append(radius * (1 - 0.72 * (i + 1) / segments))
    limb(part, "branch", points, radii, BARK if droop == 0.0 else DEADWOOD, 6 if depth > 1 else 4)
    if depth <= 0:
        tips.append(points[-1])
        return
    for i in range(3 if depth > 1 else 2):
        base = points[rnd.randint(2, segments)]
        spin = rnd.uniform(0, math.tau)
        out = (d * 0.7 + Vector((math.cos(spin), rnd.uniform(0.1, 0.6), math.sin(spin))) * 0.8).normalized()
        _grow(part, rnd, base, out, length * rnd.uniform(0.55, 0.72), radii[-2] * 0.9, depth - 1, tips, droop)


def cards(part, centre, radii, count, seed, size):
    """Crossed cards of leaves over a crown. Each card carries a full square of the leaf texture."""
    rnd = random.Random(seed)
    c = Vector(centre)
    verts, faces, uvs = [], [], []
    for i in range(count):
        # Even spread over a shell, thinned towards the middle where nobody sees.
        y = 1 - 2 * (i + 0.5) / count
        r = math.sqrt(max(0.0, 1 - y * y))
        a = i * 2.39996
        # A lumpy outline, not a ball: the radius swells and dips round the crown.
        depth = rnd.uniform(0.62, 1.0) * (0.8 + 0.24 * math.sin(a * 3.0 + y * 4.0) + 0.1 * math.sin(a * 7.0 - y * 3.0))
        at = c + Vector((math.cos(a) * r * radii[0], y * radii[1], math.sin(a) * r * radii[2])) * depth
        out = (at - c).normalized()
        side = out.cross(Vector((rnd.uniform(-0.3, 0.3), 1, rnd.uniform(-0.3, 0.3)))).normalized()
        up = side.cross(out).normalized()
        turn = rnd.uniform(0, math.tau)
        u = side * math.cos(turn) + up * math.sin(turn)
        v = up * math.cos(turn) - side * math.sin(turn)
        h = size * rnd.uniform(0.75, 1.25)
        base = len(verts)
        verts += [at - u * h - v * h, at + u * h - v * h, at + u * h + v * h, at - u * h + v * h]
        faces.append((base, base + 1, base + 2, base + 3))
        uvs += [(0, 0), (1, 0), (1, 1), (0, 1)]
    obj = add(part, "leaves", [B(v) for v in verts], faces, LEAF)
    layer = obj.data.uv_layers.new(name="UVMap")
    for poly in obj.data.polygons:
        for li in poly.loop_indices:
            layer.data[li].uv = uvs[obj.data.loops[li].vertex_index]
    return obj


def street_tree(name, seed, height, spread):
    p = begin(name)
    rnd = random.Random(seed)
    tips = []
    _grow(p, rnd, (0, 0, 0), (0.05, 1, 0.03), height * 0.42, 0.27, 2, tips)
    centre = (0, height * 0.7, 0)
    # A dark core stops the sky showing through, and cards of leaves give the outline.
    blob(p, "crown core", centre, spread * 0.62, FROND, seed, (1, 0.76, 1), 0.16, 2)
    cards(p, centre, (spread, spread * 0.8, spread), 150, seed, spread * 0.36)
    for tip in tips[::3]:
        cards(p, tip, (spread * 0.34, spread * 0.3, spread * 0.34), 12, seed + 1, spread * 0.26)
    for i in range(12):
        a = i * 1.9
        q = Vector(centre) + Vector((math.cos(a) * spread * 0.92, rnd.uniform(-0.55, 0.2) * spread, math.sin(a) * spread * 0.92))
        box(p, "fairy lamp", q, (0.1, 0.1, 0.1), FRUIT)


def palm():
    p = begin("tree_palm")
    rnd = random.Random(7)
    points, radii = [], []
    for i in range(10):
        t = i / 9
        points.append((0.5 * t * t, t * 8.4, 0.2 * t * t))
        radii.append(0.27 - 0.1 * t + (0.012 if i % 2 else 0))
    limb(p, "trunk", points, radii, BARK, 8)
    top = Vector(points[-1])
    for i in range(10):
        a = math.tau * i / 10 + rnd.uniform(-0.15, 0.15)
        reach = rnd.uniform(3.2, 3.9)
        arch = rnd.uniform(1.0, 1.5)
        out = Vector((math.cos(a), 0, math.sin(a)))
        side = out.cross(Vector((0, 1, 0)))
        rows = []
        for k in range(8):
            t = k / 7
            spine = top + out * reach * t + Vector((0, arch * math.sin(t * math.pi * 0.62) - 2.4 * t * t, 0))
            w = 0.5 * math.sin(math.pi * min(t * 1.06 + 0.04, 1.0))
            rows.append((spine + side * w + Vector((0, -0.14, 0)), spine, spine - side * w + Vector((0, -0.14, 0))))
        verts = [v for row in rows for v in row]
        faces = []
        for k in range(7):
            b0 = k * 3
            faces += [(b0, b0 + 3, b0 + 4, b0 + 1), (b0 + 1, b0 + 4, b0 + 5, b0 + 2)]
        mesh(p, "frond", verts, faces, FROND)
    for i in range(5):
        a = math.tau * i / 5
        box(p, "coconut lamp", top + Vector((math.cos(a) * 0.3, -0.25, math.sin(a) * 0.3)), (0.14, 0.14, 0.14), FRUIT)


def bush():
    p = begin("planter_bush")
    section(p, "tub", [(-2.5, 0.55, 0.52, 0.06), (2.5, 0.55, 0.52, 0.06)], CONCRETE, 0.02, 0.0, 0.52)
    box(p, "soil", (0, 1.05, 0), (0.86, 0.04, 4.8), DARK)
    box(p, "edge light", (0, 0.3, 0), (1.14, 0.03, 4.9), GLOW_C)
    for i, z in enumerate((-1.8, -0.9, 0, 0.9, 1.8)):
        blob(p, "bush", (0, 1.28, z), 0.42, FROND, i * 1.7 + 2, (0.9, 0.8, 1.1), 0.16, 1)
        cards(p, (0, 1.36, z), (0.56, 0.42, 0.62), 30, i + 3, 0.3)


def shrub():
    """A wild bush, a metre and a half high, for open country."""
    p = begin("shrub")
    for i, (x, z) in enumerate(((0, 0), (0.6, 0.3), (-0.5, 0.4), (0.1, -0.6))):
        blob(p, "shrub", (x, 0.5, z), 0.5, FROND, i * 2.3 + 1, (1.0, 0.8, 1.0), 0.18, 1)
        cards(p, (x, 0.72, z), (0.72, 0.6, 0.72), 20, i + 9, 0.34)


def boulder(name, seed):
    """A weathered rock two metres across, sunk a little into the ground."""
    p = begin(name)
    blob(p, "rock", (0, 0.5, 0), 1.0, CONCRETE, seed, (1.0, 0.72, 0.84), 0.2, 3)
    blob(p, "rock", (0.6, 0.26, 0.4), 0.5, CONCRETE, seed + 2, (1.0, 0.7, 0.9), 0.2, 2)


def dead_tree(name, seed, height):
    p = begin(name)
    rnd = random.Random(seed)
    tips = []
    _grow(p, rnd, (0, 0, 0), (0.08, 1, -0.05), height * 0.5, 0.2, 2, tips, 0.03)


# ---------------------------------------------------------------- street furniture

def city_lamp():
    p = begin("lamp_city")
    upright(p, "base", [(0, 0.2, 0.2), (0.7, 0.13, 0.13)], STEEL, 8)
    pts, radii = [], []
    for i in range(10):
        t = i / 9
        arm = max(0.0, (t - 0.72) / 0.28)
        pts.append((-1.7 * arm * arm, 8.4 * min(t / 0.8, 1.0) + 0.5 * math.sin(arm * math.pi * 0.5), 0))
        radii.append(0.1 - 0.05 * t)
    limb(p, "pole", pts, radii, STEEL, 8)
    box(p, "head", (-1.9, 8.86, 0), (1.3, 0.1, 0.36), STEEL, (0, 0, 0), 0.02)
    box(p, "led", (-1.9, 8.8, 0), (1.14, 0.03, 0.26), LED)
    box(p, "banner", (0.3, 5.6, 0), (0.44, 1.5, 0.03), GLOW_P)
    box(p, "banner arm", (0.16, 6.32, 0), (0.34, 0.03, 0.03), STEEL)


def traffic_light():
    p = begin("traffic_light")
    upright(p, "base", [(0, 0.2, 0.2), (0.6, 0.12, 0.12)], STEEL, 8)
    limb(p, "pole", [(0, 0.5, 0), (0, 6.6, 0)], [0.1, 0.08], STEEL, 8)
    limb(p, "arm", [(0, 6.3, 0), (-3.0, 6.56, 0), (-6.6, 6.7, 0)], [0.07, 0.055, 0.035], STEEL, 6)
    for x in (-3.4, -6.2):
        box(p, "signal", (x, 6.05, 0), (0.34, 1.0, 0.24), DARK, (0, 0, 0), 0.02)
        for y, mat in ((6.36, TAIL), (6.05, AMBER), (5.74, GLOW_C)):
            turned(p, "lens", [(0.12, 0.11), (0.14, 0.11)], mat, 10, x, y)
            box(p, "visor", (x, y + 0.13, 0.2), (0.27, 0.02, 0.17), DARK)
    box(p, "street sign", (-1.4, 6.74, 0), (1.5, 0.3, 0.03), GLOW_C)


def kiosk():
    p = begin("kiosk")
    section(p, "stand", [(-1.2, 1.5, 0.75, 0.1), (1.2, 1.5, 0.75, 0.1)], PAINT, 0.02, 0, 0.75)
    box(p, "upper", (0, 2.0, 0), (2.7, 1.0, 2.0), DARK, (0, 0, 0), 0.02)
    box(p, "window", (0, 2.0, 1.01), (2.4, 0.76, 0.04), SCREEN)
    box(p, "window back", (0, 2.0, -1.01), (2.4, 0.76, 0.04), SCREEN)
    box(p, "roof", (0, 2.62, 0), (3.8, 0.14, 3.2), PAINT, (0, 0, 0), 0.03)
    box(p, "roof edge", (0, 2.54, 0), (3.84, 0.05, 3.24), GLOW_P)
    box(p, "counter", (0, 1.2, 1.3), (2.6, 0.08, 0.56), STEEL)
    for i in range(6):
        box(p, "magazine", (-1.0 + i * 0.4, 1.28, 1.34), (0.26, 0.05, 0.34), LED if i % 3 == 0 else AMBER)


def bus_stop():
    p = begin("bus_stop")
    for z in (-3.3, 0, 3.3):
        limb(p, "post", [(-0.4, 0, z), (-0.4, 2.7, z)], [0.05, 0.05], STEEL, 6)
    box(p, "roof", (0.22, 2.76, 0), (1.9, 0.1, 7.4), STEEL, (0, 0, 0.05), 0.02)
    box(p, "roof light", (0.22, 2.68, 0), (1.6, 0.03, 7.0), LED)
    box(p, "back glass", (-0.4, 1.4, 0), (0.04, 2.3, 6.6), GLASS)
    box(p, "advert", (-0.36, 1.4, 2.6), (0.1, 2.1, 1.3), SCREEN)
    box(p, "advert frame", (-0.36, 1.4, 2.6), (0.13, 2.2, 0.05), GLOW_C)
    box(p, "bench", (0.05, 0.5, -0.8), (0.42, 0.06, 3.2), STEEL)
    for z in (-2.1, 0.5):
        box(p, "bench leg", (0.05, 0.25, z), (0.3, 0.5, 0.06), DARK)


def barrier():
    p = begin("barrier")
    ring = [(0, 0), (0.4, 0), (0.4, 0.12), (0.2, 0.42), (0.13, 1.15), (0, 1.15)]
    stations = [(z, ring) for z in (-3.5, 3.5)]
    rings = mirrored_rings(stations)
    obj = mesh(p, "block", [q for r in rings for q in r], rings_to_faces(2, len(rings[0])), CONCRETE)
    for z in (-2.4, 0, 2.4):
        for s in (-1, 1):
            box(p, "reflector", (s * 0.19, 0.66, z), (0.04, 0.26, 1.1), AMBER, (0, 0, -s * 0.18))
    for z in (-3.4, 3.4):
        box(p, "joint", (0, 0.06, z), (0.82, 0.12, 0.08), STEEL)


def container():
    p = begin("container")
    # Corrugated walls: a folded strip along each long side.
    length, width, height = 6.0, 3.2, 2.7
    for s in (-1, 1):
        verts, faces = [], []
        n = 40
        for i in range(n + 1):
            z = -length / 2 + length * i / n
            x = s * (width / 2 - (0.0 if (i // 2) % 2 == 0 else 0.07))
            verts += [(x, 0.1, z), (x, height - 0.1, z)]
        for i in range(n):
            faces.append((i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2))
        mesh(p, "side", verts, faces, PAINT)
    box(p, "core", (0, height / 2, 0), (width - 0.16, height - 0.2, length - 0.1), PAINT)
    for s in (-1, 1):
        for y in (0.05, height - 0.05):
            box(p, "rail", (s * (width / 2 - 0.05), y, 0), (0.12, 0.12, length), STEEL)
        for z in (-length / 2, length / 2):
            box(p, "corner", (s * (width / 2 - 0.05), height / 2, z), (0.14, height, 0.14), STEEL)
    for s in (-1, 1):
        box(p, "end rail", (0, 0.05 if s < 0 else height - 0.05, length / 2), (width, 0.12, 0.12), STEEL)
    for x in (-0.5, 0.5):
        limb(p, "door bar", [(x, 0.2, length / 2 + 0.04), (x, height - 0.2, length / 2 + 0.04)], [0.03, 0.03], STEEL, 5)


def dumpster():
    p = begin("dumpster")
    section(p, "bin", [(-0.8, 1.05, 0.5, 0.08), (0.8, 1.2, 0.62, 0.08)], PAINT, 0.02, 0, 0.65)
    box(p, "lid", (0, 1.34, 0), (2.5, 0.08, 1.72), DARK, (0.06, 0, 0), 0.02)
    for x in (-0.8, 0.8):
        box(p, "skid", (x, 0.08, 0), (0.12, 0.16, 1.5), STEEL)


def vending():
    p = begin("vending")
    box(p, "cabinet", (0, 1.0, 0), (1.1, 2.0, 0.8), PAINT, (0, 0, 0), 0.02)
    box(p, "front", (0, 1.15, 0.41), (0.86, 1.3, 0.03), SCREEN)
    box(p, "top sign", (0, 1.9, 0.41), (0.96, 0.2, 0.03), GLOW_P)
    box(p, "slot", (0, 0.32, 0.41), (0.7, 0.2, 0.03), DARK)


# ---------------------------------------------------------------- Korpo offices

def _chair(p, x, z, facing):
    """An office chair on a five-spoke base, turned to face `facing` along Z."""
    limb(p, "chair post", [(x, 0.08, z), (x, 0.44, z)], [0.03, 0.03], CHROME, 6)
    for i in range(5):
        a = math.tau * i / 5
        limb(p, "chair spoke", [(x, 0.06, z), (x + math.cos(a) * 0.3, 0.04, z + math.sin(a) * 0.3)], [0.022, 0.018], DARK, 4)
    box(p, "chair seat", (x, 0.48, z), (0.5, 0.08, 0.48), DARK, (0, 0, 0), 0.02)
    box(p, "chair back", (x, 0.84, z + facing * 0.24), (0.46, 0.62, 0.07), DARK, (facing * 0.12, 0, 0), 0.02)


def _workstation(p, x, z, facing):
    """One desk: top, panel legs, a monitor and a keyboard. The chair sits on the `facing` side."""
    box(p, "desk top", (x, 0.74, z), (1.5, 0.04, 0.75), PAINT, (0, 0, 0), 0.008)
    for s in (-1, 1):
        box(p, "desk leg", (x + s * 0.71, 0.36, z), (0.04, 0.72, 0.7), STEEL)
    box(p, "monitor", (x, 1.06, z - facing * 0.18), (0.62, 0.38, 0.03), DARK, (0, 0, 0), 0.006)
    box(p, "screen", (x, 1.07, z - facing * 0.18 + facing * 0.017), (0.56, 0.32, 0.005), SCREEN)
    limb(p, "monitor stand", [(x, 0.76, z - facing * 0.2), (x, 0.9, z - facing * 0.2)], [0.02, 0.02], CHROME, 5)
    box(p, "keyboard", (x, 0.77, z + facing * 0.08), (0.44, 0.02, 0.14), DARK)
    _chair(p, x, z + facing * 0.62, facing)


def office_desks():
    """Four desks pushed together under a low screen: the open-plan floor where people once worked."""
    p = begin("office_desks")
    for x in (-0.76, 0.76):
        for facing in (-1, 1):
            _workstation(p, x, facing * 0.4, facing)
    box(p, "divider", (0, 1.0, 0), (3.1, 0.5, 0.05), PAINT, (0, 0, 0), 0.01)
    box(p, "divider glow", (0, 1.25, 0), (3.1, 0.02, 0.06), GLOW_P)


def office_shelf():
    """Two metres of steel shelving full of binders and archive boxes."""
    p = begin("office_shelf")
    for x in (-0.98, 0.98):
        for z in (-0.2, 0.2):
            box(p, "upright", (x, 1.05, z), (0.04, 2.1, 0.04), STEEL)
    for y in (0.08, 0.6, 1.12, 1.64, 2.08):
        box(p, "shelf", (0, y, 0), (2.0, 0.03, 0.44), STEEL)
    rnd = random.Random(31)
    for y in (0.1, 0.62, 1.14, 1.66):
        x = -0.92
        while x < 0.88:
            w = rnd.uniform(0.05, 0.09)
            if rnd.random() < 0.18:
                box(p, "archive box", (x + 0.16, y + 0.15, 0), (0.32, 0.28, 0.36), CANVAS)
                x += 0.36
                continue
            h = rnd.uniform(0.3, 0.42)
            box(p, "binder", (x + w / 2, y + h / 2 + 0.01, 0.02), (w, h, 0.32), PAINT if rnd.random() < 0.7 else DARK, (0, 0, rnd.uniform(-0.05, 0.05)))
            x += w + 0.004
            if rnd.random() < 0.08:
                x += 0.12


def server_rack():
    """A rack of the machine's own minds, humming with status lights."""
    p = begin("server_rack")
    box(p, "cabinet", (0, 1.1, 0), (0.7, 2.2, 1.0), DARK, (0, 0, 0), 0.01)
    box(p, "door", (0, 1.1, -0.505), (0.64, 2.1, 0.02), GLASS)
    rnd = random.Random(7)
    for i in range(16):
        y = 0.2 + i * 0.12
        box(p, "unit", (0, y, -0.46), (0.6, 0.09, 0.06), IRON)
        for k in range(3):
            if rnd.random() < 0.7:
                box(p, "status", (-0.24 + k * 0.05, y, -0.495), (0.02, 0.02, 0.01), TAIL if rnd.random() < 0.45 else GLOW_C)
    box(p, "top light", (0, 2.21, -0.3), (0.6, 0.02, 0.3), TAIL)


def filing_cabinet():
    p = begin("filing_cabinet")
    box(p, "cabinet", (0, 0.66, 0), (0.48, 1.32, 0.62), PAINT, (0, 0, 0), 0.01)
    for i in range(4):
        y = 0.2 + i * 0.31
        box(p, "drawer", (0, y, -0.315), (0.42, 0.27, 0.01), STEEL)
        box(p, "handle", (0, y + 0.06, -0.325), (0.14, 0.02, 0.02), CHROME)


def reception():
    """The front desk, four metres of black stone under a lit band, where a machine greets nobody."""
    p = begin("reception")
    box(p, "counter", (0, 0.55, 0), (4.0, 1.1, 0.8), DARK, (0, 0, 0), 0.02)
    box(p, "counter top", (0, 1.13, -0.08), (4.1, 0.06, 0.96), CHROME, (0, 0, 0), 0.01)
    box(p, "front glow", (0, 0.86, -0.41), (3.8, 0.04, 0.02), GLOW_P)
    box(p, "logo", (0, 0.55, -0.41), (0.5, 0.36, 0.02), LED)
    for x in (-1.2, 1.2):
        box(p, "screen", (x, 1.36, 0.1), (0.5, 0.32, 0.03), SCREEN, (0.3, 0, 0))


def duckboard():
    """Two metres of trench boards: slats nailed across a pair of runners."""
    p = begin("duckboard")
    rnd = random.Random(4)
    for x in (-0.28, 0.28):
        box(p, "runner", (x, 0.05, 0), (0.09, 0.09, 2.0), MUDDY)
    for i in range(11):
        z = -0.92 + i * 0.184
        box(p, "slat", (rnd.uniform(-0.03, 0.03), 0.12, z), (0.8 + rnd.uniform(-0.06, 0.06), 0.035, 0.12), WOOD, (rnd.uniform(-0.03, 0.03), rnd.uniform(-0.05, 0.05), 0))


def revetment():
    """Three metres of planks and posts, built to lie against a trench wall."""
    p = begin("revetment")
    rnd = random.Random(8)
    for i in range(8):
        y = 0.12 + i * 0.25
        box(p, "plank", (rnd.uniform(-0.05, 0.05), y, 0), (3.0 + rnd.uniform(-0.12, 0.12), 0.22, 0.05), WOOD, (rnd.uniform(-0.02, 0.02), 0, rnd.uniform(-0.012, 0.012)))
    for x in (-1.42, 0.0, 1.42):
        box(p, "post", (x, 1.05, 0.05), (0.14, 2.3, 0.12), MUDDY, (0, 0, rnd.uniform(-0.03, 0.03)))
    tube_wire = [(-1.42, 2.1, 0.13), (0.0, 2.05, 0.15), (1.42, 2.12, 0.13)]
    limb(p, "binding wire", tube_wire, [0.012] * 3, WIRE, 4)


def sandbag_wall():
    """Three metres of bags, laid like bricks, slumped and wet."""
    p = begin("sandbag_wall")
    rnd = random.Random(3)
    for row in range(3):
        for i in range(5 - (row % 2)):
            x = -1.2 + i * 0.6 + (0.3 if row % 2 else 0)
            y = 0.16 + row * 0.25
            blob(p, "bag", (x + rnd.uniform(-0.03, 0.03), y, rnd.uniform(-0.04, 0.04)), 0.3, BAG, row * 7 + i, (1.05, 0.44, 0.74), 0.09, 2)


def wire_coil():
    """Four metres of coiled barbed wire on two pickets."""
    p = begin("wire_coil")
    rnd = random.Random(5)
    pts, rad = [], []
    turns = 22
    for i in range(turns * 9):
        t = i / (turns * 9)
        a = t * turns * math.tau
        r = 0.52 + 0.06 * math.sin(i * 0.9)
        pts.append((-2 + 4 * t, 0.56 + math.sin(a) * r, math.cos(a) * r))
        rad.append(0.012)
    limb(p, "coil", pts, rad, WIRE, 3)
    for k in range(60):
        i = rnd.randint(0, len(pts) - 1)
        q = Vector(pts[i])
        limb(p, "barb", [q - Vector((0.03, 0.03, 0)), q + Vector((0.03, 0.03, 0))], [0.008, 0.008], WIRE, 3)
    for x in (-1.9, 1.9):
        for tilt in (-0.42, 0.42):
            limb(p, "picket", [(x, 0, tilt * -0.9), (x + 0.03, 1.28, tilt * 0.9)], [0.04, 0.03], RUST, 5)
        limb(p, "brace", [(x, 0.72, -0.5), (x, 0.72, 0.5)], [0.02, 0.02], RUST, 4)


def stump(name, seed, height):
    """A shell-torn trunk with splintered ends."""
    p = begin(name)
    rnd = random.Random(seed)
    limb(p, "trunk", [(0, 0, 0), (0.05, height * 0.5, 0.03), (rnd.uniform(-0.1, 0.1), height, rnd.uniform(-0.1, 0.1))], [0.42, 0.3, 0.16], DEADWOOD, 8)
    for i in range(7):
        a = rnd.uniform(0, math.tau)
        top = Vector((math.cos(a) * 0.14, height + rnd.uniform(0.2, 0.9), math.sin(a) * 0.14))
        limb(p, "splinter", [(math.cos(a) * 0.14, height - 0.1, math.sin(a) * 0.14), top], [0.07, 0.008], DEADWOOD, 4)
    for i in range(3):
        a = rnd.uniform(0, math.tau)
        out = Vector((math.cos(a), rnd.uniform(0.1, 0.5), math.sin(a)))
        base = Vector((0, height * rnd.uniform(0.4, 0.8), 0))
        limb(p, "stub", [base, base + out * rnd.uniform(0.5, 1.2)], [0.1, 0.02], DEADWOOD, 5)


def ammo_crate():
    p = begin("ammo_crate")
    box(p, "crate", (0, 0.2, 0), (1.0, 0.4, 0.5), WOOD, (0, 0, 0), 0.01)
    for x in (-0.42, 0.42):
        box(p, "band", (x, 0.2, 0), (0.05, 0.42, 0.52), RUST)
    box(p, "lid", (0.02, 0.41, 0.01), (1.0, 0.03, 0.5), MUDDY, (0, 0.04, 0))


def field_gun():
    """An abandoned field gun: wheels, trail and a long barrel at a tired angle."""
    p = begin("field_gun")
    for s_ in (-1, 1):
        rim = []
        for i in range(25):
            a = i / 24 * math.tau
            rim.append((s_ * 0.8, 0.75 + math.sin(a) * 0.72, math.cos(a) * 0.72))
        limb(p, "rim", rim, [0.05] * 25, MUDDY, 5)
        for i in range(10):
            a = i / 10 * math.tau
            limb(p, "spoke", [(s_ * 0.8, 0.75, 0), (s_ * 0.8, 0.75 + math.sin(a) * 0.7, math.cos(a) * 0.7)], [0.03, 0.03], WOOD, 4)
        limb(p, "trail", [(s_ * 0.3, 0.6, 0.2), (s_ * 0.1, 0.25, 1.6), (0, 0.08, 3.0)], [0.08, 0.07, 0.06], IRON, 6)
    limb(p, "axle", [(-0.8, 0.75, 0), (0.8, 0.75, 0)], [0.05, 0.05], IRON, 6)
    box(p, "shield", (0, 1.15, -0.2), (1.5, 1.1, 0.05), IRON, (-0.1, 0, 0.03))
    box(p, "cradle", (0, 1.04, 0.1), (0.3, 0.28, 1.6), IRON, (0.12, 0, 0))
    limb(p, "barrel", [(0, 1.05, 0.5), (0, 1.2, -1.0), (0, 1.34, -2.4)], [0.1, 0.075, 0.06], IRON, 10)
    limb(p, "muzzle", [(0, 1.335, -2.36), (0, 1.35, -2.46)], [0.078, 0.078], IRON, 10)


def lantern():
    p = begin("lantern")
    limb(p, "post", [(0, 0, 0), (0, 1.5, 0), (0.28, 1.72, 0)], [0.05, 0.04, 0.02], WOOD, 5)
    box(p, "cage", (0.28, 1.5, 0), (0.15, 0.24, 0.15), IRON)
    box(p, "flame", (0.28, 1.5, 0), (0.1, 0.17, 0.1), AMBER)


def dugout():
    """A low roof of corrugated iron and sandbags over the door of a shelter."""
    p = begin("dugout")
    for x in (-1.2, 1.2):
        box(p, "post", (x, 0.95, 0.9), (0.2, 1.9, 0.2), MUDDY)
    box(p, "lintel", (0, 1.92, 0.9), (2.8, 0.22, 0.22), MUDDY)
    box(p, "roof", (0, 2.08, 0), (3.0, 0.12, 2.2), RUST, (0.08, 0, 0))
    for i in range(2):
        blob(p, "roof bag", (-0.6 + i * 1.2, 2.3, 0.2), 0.42, BAG, i + 9, (1.1, 0.45, 0.8), 0.1, 1)
    box(p, "dark", (0, 0.95, 0.8), (2.2, 1.9, 0.04), DARK)


# ---------------------------------------------------------------- wrecks of the old town

def _dent(obj, amount, seed):
    for v in obj.data.vertices:
        n = noise.noise(v.co * 1.4 + Vector((seed, 0, seed)))
        v.co += v.normal * n * amount


def wreck_car():
    p = begin("wreck_car")
    stations = [
        (-2.2, _section(0.74, 0.3, 0.72, 0.0)), (-1.5, _section(0.88, 0.26, 0.86, 0.04)), (-0.8, _section(0.9, 0.26, 0.92, 0.04)),
        (0.4, _section(0.9, 0.26, 0.94, 0.03)), (1.5, _section(0.88, 0.28, 0.9, 0.03)), (2.1, _section(0.68, 0.36, 0.82, 0.0)),
    ]
    shell = body(p, "shell", stations, BURNT, [2, 4], level=1, bevel=0.0)
    _dent(shell, 0.1, 3.0)
    roof = [(-0.7, [(0, 0.9), (0.76, 0.9), (0.56, 1.26), (0, 1.3)]), (0.3, [(0, 0.92), (0.76, 0.92), (0.58, 1.22), (0, 1.26)]), (1.1, [(0, 0.92), (0.72, 0.92), (0.58, 1.12), (0, 1.14)])]
    cab = body(p, "roof", roof, RUST, [1], level=1, bevel=0.0)
    _dent(cab, 0.09, 6.0)
    for z in (-1.4, 1.35):
        for s in (-1, 1):
            turned(p, "wheel", [(0, 0.34), (0.2, 0.34)], RUBBER, 12, 0, 0.34)
            PARTS[p][-1].location = B((s * 0.95, 0, z))
            bpy.context.view_layer.update()
            obj = PARTS[p][-1]
            obj.rotation_euler = (0, 0, math.pi / 2)
    box(p, "bonnet", (0.15, 0.98, -1.5), (1.4, 0.05, 1.1), RUST, (-0.35, 0.2, 0.1))


def wreck_truck():
    p = begin("wreck_truck")
    box(p, "chassis", (0, 0.8, 0.5), (2.0, 0.3, 6.0), BURNT)
    cab = [(1.7, [(0, 0.95), (0.98, 0.95), (1.0, 1.7), (0.86, 2.3), (0, 2.34)]), (3.3, [(0, 0.95), (0.98, 0.95), (1.0, 1.56), (0.8, 1.86), (0, 1.9)])]
    c = body(p, "cab", cab, RUST, [1, 2, 3], level=0, bevel=0.0)
    _dent(c, 0.08, 2.0)
    for z in (-2.2, -1.2, -0.2, 0.8):
        for s in (-1, 1):
            limb(p, "bow", [(s * 1.04, 0.95, z), (s * 1.04, 2.1, z), (s * 0.5, 2.5, z), (0, 2.6, z)], [0.03] * 4, IRON, 5)
    for i in range(10):
        box(p, "bed plank", (0, 1.04, -2.3 + i * 0.36), (2.1, 0.06, 0.3), BURNT, (0, 0, 0.04 * (i % 3 - 1)))
    box(p, "side board", (1.04, 1.3, -0.8), (0.06, 0.6, 3.4), RUST, (0.04, 0, 0.1))
    box(p, "side board", (-1.04, 1.24, -1.2), (0.06, 0.5, 2.6), BURNT, (0, 0, -0.16))


def wreck_tank():
    p = begin("wreck_tank")
    hull = [
        (-3.4, [(0, 0.4), (1.2, 0.4), (1.5, 0.8), (1.0, 1.0), (0, 1.02)]), (-2.4, [(0, 0.1), (1.5, 0.1), (1.9, 0.72), (1.34, 1.44), (0, 1.5)]),
        (0.0, [(0, 0.05), (1.6, 0.05), (2.0, 0.72), (1.45, 1.56), (0, 1.62)]), (2.4, [(0, 0.1), (1.5, 0.1), (1.9, 0.78), (1.34, 1.5), (0, 1.56)]), (3.3, [(0, 0.46), (1.2, 0.46), (1.42, 0.86), (1.1, 1.26), (0, 1.3)]),
    ]
    h = body(p, "hull", hull, BURNT, [1, 2, 3], level=1, bevel=0.0)
    _dent(h, 0.12, 5.0)
    turret = [(-1.7, [(0, 1.56), (0.7, 1.56), (0.72, 1.9), (0, 2.0)]), (-0.6, [(0, 1.5), (1.2, 1.5), (1.26, 2.06), (0.7, 2.34), (0, 2.38)][:4]), (0.9, [(0, 1.5), (1.2, 1.5), (1.14, 2.16), (0, 2.3)]), (1.8, [(0, 1.58), (0.8, 1.58), (0.7, 2.0), (0, 2.1)])]
    t = body(p, "turret", turret, RUST, [1, 2], level=1, bevel=0.0)
    t.rotation_euler = (math.radians(4), math.radians(5), math.radians(24))
    _dent(t, 0.07, 8.0)
    limb(p, "barrel", [(0.3, 2.0, -1.6), (0.9, 1.64, -3.6), (1.5, 0.9, -5.2)], [0.13, 0.11, 0.09], IRON, 8)
    box(p, "torn plate", (1.6, 1.3, 1.2), (0.06, 0.9, 2.0), RUST, (0.2, 0.3, 0.7))
    box(p, "torn plate", (-1.7, 1.0, -0.8), (0.06, 1.1, 1.5), RUST, (-0.15, -0.2, -0.5))
    for x, z in ((-0.7, 1.9), (0.6, 2.4), (0.0, -2.2)):
        box(p, "hatch debris", (x, 1.6, z), (0.5, 0.05, 0.4), IRON, (0.2, x, 0.3))


def hedgehog():
    p = begin("hedgehog")
    for i, (a, tilt) in enumerate(((0.0, 0.75), (2.09, 0.75), (4.19, 0.75))):
        d = Vector((math.cos(a) * math.sin(tilt), math.cos(tilt), math.sin(a) * math.sin(tilt)))
        c = Vector((0, 0.74, 0))
        q = d.to_track_quat("Y", "Z").to_matrix()
        for name, size, off in (("web", (0.05, 2.7, 0.24), (0, 0, 0)), ("flange", (0.24, 2.7, 0.04), (0, 0, 0.12)), ("flange", (0.24, 2.7, 0.04), (0, 0, -0.12))):
            h = Vector(size) / 2
            corners = [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]
            verts = [c + q @ (Vector(off) + Vector((x * h.x, y * h.y, z * h.z))) for x, y, z in corners]
            mesh(p, name, verts, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3)], RUST if i % 2 else IRON)


def old_lamp():
    p = begin("lamp_old")
    upright(p, "foot", [(0, 0.22, 0.22), (0.3, 0.2, 0.2), (0.42, 0.12, 0.12), (1.0, 0.09, 0.09)], IRON, 10)
    limb(p, "pole", [(0, 1.0, 0), (0, 4.6, 0)], [0.07, 0.05], IRON, 8)
    limb(p, "arm", [(0, 4.5, 0), (-0.35, 5.1, 0), (-0.9, 5.3, 0), (-1.1, 5.16, 0)], [0.04, 0.035, 0.03, 0.025], IRON, 6)
    upright(p, "lantern", [(4.72, 0.12, 0.12), (5.0, 0.2, 0.2), (5.06, 0.08, 0.08)], IRON, 8, -1.1, 0)
    box(p, "glass", (-1.1, 4.86, 0), (0.2, 0.22, 0.2), AMBER)
    limb(p, "ring", [(-0.22, 3.9, 0), (0.22, 3.9, 0)], [0.03, 0.03], IRON, 6)


def cruiser():
    p = begin("ship_cruiser")
    def ring(w, h, y=0.0):
        return [(0, y - h), (w * 0.9, y - h * 0.8), (w, y), (w * 0.72, y + h * 0.7), (0, y + h)]
    stations = [(-15, ring(0.3, 0.2)), (-11, ring(1.7, 0.7)), (-4, ring(3.4, 1.3)), (4, ring(4.4, 1.7)), (10, ring(4.2, 1.9)), (14, ring(3.0, 1.6))]
    body(p, "hull", stations, PAINT, [1, 2, 3], level=1, bevel=0.0)
    for z, w, h, y in ((6.5, 1.5, 1.4, 2.6), (9.5, 1.0, 1.6, 3.9), (3.0, 1.9, 0.6, 1.9)):
        box(p, "tower", (0, y, z), (w * 2, h, 3.2), PAINT, (0, 0, 0), 0.1)
    box(p, "bridge", (0, 4.7, 9.0), (1.5, 0.3, 0.5), LED)
    for s_ in (-1, 1):
        for i in range(26):
            box(p, "window", (s_ * (2.4 + i * 0.05), 0.75, -9.0 + i * 0.86), (0.08, 0.08, 0.34), LED)
    for s in (-1, 1):
        box(p, "wing", (s * 5.6, -0.3, 8.0), (3.4, 0.5, 6.0), PAINT, (0, 0, s * 0.18), 0.05)
        box(p, "hull light", (s * 3.1, 0.25, 2.0), (0.1, 0.1, 14.0), GLOW_C)
        for z in (-4.0, 0.0, 4.0):
            box(p, "turret", (s * 2.5, 1.4, z), (1.1, 0.5, 1.1), DARK)
            box(p, "barrel", (s * 2.5, 1.5, z - 1.1), (0.16, 0.16, 1.6), DARK)
    for x in (-2.6, 0.0, 2.6):
        turned(p, "engine", [(13.6, 1.2), (15.0, 1.0)], DARK, 14, x, 0.0)
        turned(p, "engine glow", [(14.95, 0.9), (15.0, 0.0)], GLOW_C, 14, x, 0.0)


def fighter():
    p = begin("ship_fighter")
    stations = [(-3.0, _section(0.1, -0.1, 0.1, 0.0)), (-1.4, _section(0.42, -0.26, 0.26, 0.04)), (0.8, _section(0.62, -0.32, 0.36, 0.04)), (2.0, _section(0.5, -0.28, 0.3, 0.0))]
    body(p, "hull", stations, PAINT, [2, 4], level=1, bevel=0.0)
    for s in (-1, 1):
        box(p, "wing", (s * 1.7, 0.0, 0.7), (2.6, 0.08, 1.8), PAINT, (0, s * 0.3, s * 0.1))
        box(p, "gun", (s * 2.6, 0.0, -0.4), (0.1, 0.1, 1.8), DARK)
        turned(p, "engine glow", [(2.0, 0.22), (2.06, 0.0)], GLOW_C, 10, s * 0.32, 0.0)
    box(p, "canopy", (0, 0.36, -0.4), (0.4, 0.2, 1.0), GLASS)


# ---------------------------------------------------------------- output

def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    OUT.mkdir(parents=True, exist_ok=True)
    sedan()
    sport()
    van()
    bus()
    street_tree("tree_oak", 3, 9.5, 3.6)
    street_tree("tree_slim", 11, 7.5, 2.5)
    palm()
    bush()
    shrub()
    boulder("boulder_a", 3)
    boulder("boulder_b", 8)
    dead_tree("dead_tree_a", 5, 6.0)
    dead_tree("dead_tree_b", 9, 5.0)
    city_lamp()
    traffic_light()
    kiosk()
    bus_stop()
    barrier()
    container()
    dumpster()
    vending()
    office_desks()
    office_shelf()
    server_rack()
    filing_cabinet()
    reception()
    wreck_car()
    wreck_truck()
    wreck_tank()
    hedgehog()
    old_lamp()
    duckboard()
    revetment()
    sandbag_wall()
    wire_coil()
    stump("stump_a", 2, 2.6)
    stump("stump_b", 6, 1.4)
    ammo_crate()
    field_gun()
    lantern()
    dugout()
    cruiser()
    fighter()
    root = bpy.data.objects.new("CityProps", None)
    bpy.context.collection.objects.link(root)
    objs = []
    for name in PROPS:
        for o in PARTS[name]:
            o.select_set(False)
        # Parts placed by transform have to keep it through the join.
        for o in PARTS[name]:
            mat = o.matrix_world.copy()
            o.data.transform(mat)
            o.matrix_world = Matrix.Identity(4)
        obj = join(name)
        shade(obj, 88.0 if name.startswith(("tree", "planter")) else 38.0)
        if not name.startswith(("tree", "planter", "dead", "wire", "stump")):
            bake_wear(obj, 0.35, 6, 1.0)
        obj.parent = root
        objs.append(obj)
        print("[city]", name, sum(len(p.vertices) - 2 for p in obj.data.polygons), flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "city.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in objs:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / "props.glb"), export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_normals=True, export_materials="EXPORT", export_vertex_color="ACTIVE", export_all_vertex_colors=False,
        export_animations=False, export_cameras=False, export_lights=False,
    )
    print("[city] done", flush=True)


main()
