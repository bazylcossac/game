"""Shared tools for the character scripts: bodies that bend at the joints.

A character is a few meshes skinned to one skeleton, the same joints SoldierModel poses in the
game. Coordinates are Godot metres: +Y up, -Z forward, +X the character's right.

Three things keep a soldier cheap to draw:
  * every mesh is a single surface. Colour, shading and the kind of material ride on the vertex
    colours (rgb is the paint with its shadows baked in, alpha is the kind), so a whole body is one
    draw call whatever it wears;
  * each mesh is built three times, at three levels of detail, by the same code with fewer sides
    and without the small parts. Nothing is decimated, so the far body keeps the near one's shape;
  * only the nearest level carries UVs for the cloth weave.
"""
import math
import random
import sys
from bisect import bisect_right
from contextlib import contextmanager
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector, geometry
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_kit import B, ROOT, SOURCE, at, edge_distance, inset, inside, rings_to_faces, signed_area  # noqa: E402,F401

OUT = ROOT / "assets/models/chars"
FRONT, BACK, OUTER, INNER = 270.0, 90.0, 0.0, 180.0

## The kinds of surface the game's character shader knows, in the order it lists them.
KINDS = ["cloth", "suit", "leather", "rubber", "paint", "metal", "ceramic", "glass", "skin", "glow", "tint", "lamp", "satin"]
## Roughness and metallic of each kind, for the previews. The game keeps its own copy.
KIND_LOOK = {"cloth": (0.92, 0.0), "suit": (0.7, 0.0), "leather": (0.5, 0.0), "rubber": (0.8, 0.0), "paint": (0.45, 0.5), "metal": (0.24, 1.0),
             "ceramic": (0.22, 0.0), "glass": (0.08, 0.6), "skin": (0.6, 0.0), "glow": (0.4, 0.0), "tint": (0.4, 0.0), "lamp": (0.4, 0.0), "satin": (0.34, 0.1)}
## Name -> (linear colour, kind). Each character script fills this in.
PALETTE = {}
PIECES = {}
## What the previews paint the parts the game colours per class: ties, or skin.
PREVIEW_TINT = [(0.5, 0.5, 0.5)]
_BIND = ["Torso"]
_LOD = [0]
_UNSHADED = [False]
_SHADE = {}

UPPER_ARM, FOREARM, THIGH, SHIN = 0.29, 0.28, 0.45, 0.45
BONES = ["Pelvis", "Torso", "Head", "UpperArm_R", "Forearm_R", "Hand_R", "UpperArm_L", "Forearm_L", "Hand_L",
         "Thigh_R", "Shin_R", "Boot_R", "Thigh_L", "Shin_L", "Boot_L"]
PARENT = {"Torso": "Pelvis", "Head": "Torso", "UpperArm_R": "Torso", "Forearm_R": "UpperArm_R", "Hand_R": "Forearm_R",
          "UpperArm_L": "Torso", "Forearm_L": "UpperArm_L", "Hand_L": "Forearm_L", "Thigh_R": "Pelvis", "Shin_R": "Thigh_R",
          "Boot_R": "Shin_R", "Thigh_L": "Pelvis", "Shin_L": "Thigh_L", "Boot_L": "Shin_L"}
JOINT = {}


def set_joints(shoulder=0.2, hip=0.1):
    """Where each joint rests. Only the width of the shoulders differs between bodies."""
    JOINT.clear()
    JOINT.update({"Pelvis": Vector((0, 0.95, 0)), "Torso": Vector((0, 1.03, 0)), "Head": Vector((0, 1.56, 0))})
    for tag, s in (("R", 1.0), ("L", -1.0)):
        JOINT[f"UpperArm_{tag}"] = Vector((s * shoulder, 1.5, 0))
        JOINT[f"Forearm_{tag}"] = Vector((s * shoulder, 1.5 - UPPER_ARM, 0))
        JOINT[f"Hand_{tag}"] = Vector((s * shoulder, 1.5 - UPPER_ARM - FOREARM, 0))
        JOINT[f"Thigh_{tag}"] = Vector((s * hip, 0.9, 0))
        JOINT[f"Shin_{tag}"] = Vector((s * hip, 0.9 - THIGH, 0))
        JOINT[f"Boot_{tag}"] = Vector((s * hip, 0.0, 0))


# ---------------------------------------------------------------- levels of detail

def lod():
    return _LOD[0]


def set_lod(level):
    _LOD[0] = level


def fine(level=0):
    """True while building a level at least this detailed. Small parts exist only up close."""
    return _LOD[0] <= level


def sides(n):
    return (n, max(6, int(round(n * 0.6 / 2.0)) * 2), max(4, int(round(n * 0.36))))[_LOD[0]]


def stride(step):
    return step * (1.0, 2.2, 5.0)[_LOD[0]]


def pick(near, mid=None, far=None):
    return (near, near if mid is None else mid, (near if mid is None else mid) if far is None else far)[_LOD[0]]


# ---------------------------------------------------------------- pieces

def swatch(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.diffuse_color = (*PALETTE[name][0], 1)
    return m


@contextmanager
def bound(rule):
    """Everything built inside follows `rule`: a bone's name, or a region that blends at its joints."""
    _BIND.append(rule)
    yield
    _BIND.pop()


@contextmanager
def unshaded():
    """Pieces built inside take no baked shadow. Thin layers laid on a body, such as a shirt front
    under its lapels, would only pick up a saw-toothed stain from their neighbours."""
    _UNSHADED.append(True)
    yield
    _UNSHADED.pop()


def add(part, name, verts, faces, mat, bind=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.update()
    mesh.materials.append(swatch(mat))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj["bind"] = bind or _BIND[-1]
    obj["unshaded"] = _UNSHADED[-1]
    PIECES.setdefault(part, []).append(obj)
    return obj


def outward(obj, inside_point=None):
    """Makes the faces agree, then makes them face away from `inside_point` if the piece is open."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if inside_point is not None:
        ref = B(inside_point)
        total = sum(f.normal.dot(f.calc_center_median() - ref) * f.calc_area() for f in bm.faces)
        if total < 0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def bake_modifiers(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    obj.modifiers.clear()
    old = obj.data
    obj.data = mesh
    bpy.data.meshes.remove(old)


def bevel(obj, width, angle=30.0, segments=1):
    if width > 0 and fine(0):
        mod = obj.modifiers.new("edge", "BEVEL")
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(angle)
        mod.width = width
        mod.segments = segments
        bake_modifiers(obj)
    return obj


def catmull(a, b, c, d, t):
    return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t ** 3)


def smooth(lo, hi, x):
    """0 at `lo`, 1 at `hi`, eased. `lo` may be the larger of the two."""
    if lo == hi:
        return 1.0 if x >= hi else 0.0
    t = min(1.0, max(0.0, (x - lo) / (hi - lo)))
    return t * t * (3 - 2 * t)


def bump(x, centre, width):
    return math.exp(-((x - centre) / width) ** 2)


def wrap_angle(a, centre):
    """`a` brought within half a turn of `centre`, in degrees."""
    return (a - centre + 180.0) % 360.0 - 180.0


# ---------------------------------------------------------------- forms

class Form:
    """A limb or a trunk as cross-sections along an axis, smooth between them.

    Stations are (t, rx, rz[, cx, cz]): a superellipse of half-widths rx across and rz deep,
    centred at (cx, cz), at height t. Angles run round the axis in degrees: 0 is the outer side
    (+X on the right of the body), 90 the back, 180 the inner side, 270 the front.
    `side` -1 mirrors the form for the left of the body, and keeps 0 as its outer side.
    `relief(a, t)` adds metres to the radius: folds, muscles, the features of a face.
    With axis "z" the form runs front to back instead: rx is across, rz is up, and 90 is the top.
    """

    def __init__(self, stations, squash=2.3, axis="y", side=1.0, origin=(0, 0, 0), relief=None, folds=0.0, seed=1.0, bunch=()):
        self.st = sorted((tuple(float(v) for v in s) + (0.0,) * (5 - len(s)) for s in stations), key=lambda s: s[0])
        self.keys = [s[0] for s in self.st]
        self.squash = squash
        self.axis = axis
        self.side = side
        self.origin = Vector(origin)
        self.relief = relief
        self.folds = folds
        self.seed = seed
        self.bunch = bunch

    def eval(self, t):
        st = self.st
        t = min(max(t, self.keys[0]), self.keys[-1])
        i = max(0, min(len(st) - 2, bisect_right(self.keys, t) - 1))
        a, b = st[i], st[i + 1]
        u = (t - a[0]) / (b[0] - a[0]) if b[0] > a[0] else 0.0
        p0, p3 = st[max(i - 1, 0)], st[min(i + 2, len(st) - 1)]
        out = [catmull(p0[k], a[k], b[k], p3[k], u) for k in range(1, 5)]
        # The curve must not swing past the stations it runs between, or a taper turns inside out.
        for k in (0, 1):
            out[k] = max(min(out[k], max(a[k + 1], b[k + 1]) * 1.04), min(a[k + 1], b[k + 1]) * 0.96, 0.0)
        return out

    def _squash(self, s):
        if isinstance(self.squash, tuple):
            return self.squash[0] if s < 0 else self.squash[1]
        return self.squash

    def _grow(self, a, t):
        g = self.relief(a % 360.0, t) if self.relief else 0.0
        if self.folds:
            rad = math.radians(a)
            gather = sum(k * math.exp(-((t - c) / w) ** 2) for c, w, k in self.bunch)
            wave = math.sin(t * 62 + rad * 2 + self.seed) * 0.55 + math.sin(t * 113 - rad * 3 + self.seed * 2.3) * 0.3 + math.sin(t * 31 + rad + self.seed * 0.7) * 0.5
            g += self.folds * (1 + gather * 2.4) * wave
        return g

    def _place(self, u, v, t):
        if self.axis == "y":
            return Vector((self.side * u, t, v)) + self.origin
        return Vector((self.side * u, v, t)) + self.origin

    def centre(self, t):
        _, _, cx, cz = self.eval(t)
        return self._place(cx, cz, t)

    def surface(self, a, t):
        rx, rz, cx, cz = self.eval(t)
        rad = math.radians(a)
        c, s = math.cos(rad), math.sin(rad)
        sq = self._squash(s)
        ex = math.copysign(abs(c) ** (2 / sq), c)
        ez = math.copysign(abs(s) ** (2 / sq), s)
        g = self._grow(a, t)
        return self._place(cx + (rx + g) * ex, cz + (rz + g) * ez, t)

    def normal(self, a, t):
        lo, hi = self.keys[0], self.keys[-1]
        dt = 0.004
        ta, tb = max(lo, t - dt), min(hi, t + dt)
        da = self.surface(a + 2.0, t) - self.surface(a - 2.0, t)
        dv = self.surface(a, tb) - self.surface(a, ta)
        n = da.cross(dv)
        out = self.surface(a, t) - self.centre(t)
        if n.length < 1e-9:
            return out.normalized() if out.length > 1e-9 else Vector((0, 1, 0))
        n.normalize()
        return n if n.dot(out) >= 0 else -n

    def at(self, a, t, lift=0.0):
        p = self.surface(a, t)
        return p + self.normal(a, t) * lift if lift else p

    def span(self, a, t, width):
        """The angles either side of `a` that are `width` metres apart on the surface."""
        per_degree = max((self.surface(a + 1.0, t) - self.surface(a - 1.0, t)).length / 2.0, 1e-5)
        half = width / per_degree / 2.0
        return a - half, a + half

    def stations(self, step, t0=None, t1=None):
        lo = self.keys[0] if t0 is None else t0
        hi = self.keys[-1] if t1 is None else t1
        keys = [lo] + [t for t in self.keys if lo < t < hi] + [hi]
        # Far away, stations that crowd together fold into one ring.
        gap = (0.0, 0.014, 0.04)[lod()]
        kept = [keys[0]]
        for t in keys[1:-1]:
            if t - kept[-1] >= gap and hi - t >= gap:
                kept.append(t)
        kept.append(keys[-1])
        out = []
        for a, b in zip(kept, kept[1:]):
            count = max(int(round((b - a) / stride(step))), 1)
            out += [a + (b - a) * k / count for k in range(count)]
        return out + [hi]

    def mesh(self, part, name, mat, n=16, step=0.03, t0=None, t1=None, caps=True, lift=0.0, turn=0.0):
        n = sides(n)
        ts = self.stations(step, t0, t1)
        rings = [[self.at(360.0 * k / n + turn, t, lift) for k in range(n)] for t in ts]
        obj = add(part, name, [B(p) for r in rings for p in r], rings_to_faces(len(rings), n, caps), mat)
        return outward(obj, None if caps else self.centre((ts[0] + ts[-1]) / 2))

    def cap(self, part, name, mat, t, n=16, lift=0.0, up=True):
        """A flat lid across the form at `t`: the dark inside of a sleeve or a trouser leg.
        `up` is the way it faces along the axis."""
        n = sides(n)
        ring = [self.at(360.0 * k / n, t, lift) for k in range(n)]
        obj = add(part, name, [B(p) for p in ring], [tuple(range(n))], mat)
        along = Vector((0, 1, 0)) if self.axis == "y" else Vector((0, 0, 1))
        return outward(obj, self.centre(t) - along * (0.1 if up else -0.1))

    def shell(self, part, name, mat, a0, a1, t0, t1, thick=0.006, lift=0.0, na=8, nt=6, warp=None, sink=0.006, exact=False):
        """A layer lying on the form between two angles and two heights: a plate, a cuff, a band.
        `thick` may be a function of (u, v), each 0 to 1 across the shell. `warp(u, v)` returns the
        (angle, height) of a point, for shells that are not rectangles."""
        scale = 1.0 if exact else (1.0, 0.6, 0.34)[lod()]
        closed = abs(a1 - a0) >= 359.9
        na = max(4 if closed else 1, int(round(na * scale)))
        nt = max(1, int(round(nt * scale)))
        cols = na if closed else na + 1
        # A coarse shell cuts corners, so far away it stands higher to stay clear of what it covers.
        clear = (0.0, 0.0015, 0.007)[lod()]

        def point(i, j, top):
            u, v = i / na, j / nt
            a, t = warp(u, v) if warp else (a0 + (a1 - a0) * u, t0 + (t1 - t0) * v)
            h = (thick(u, v) if callable(thick) else thick) + clear
            return self.at(a, t, lift + h if top else lift - sink)

        def idx(i, j):
            return j * cols + (i % cols)

        verts = [point(i, j, True) for j in range(nt + 1) for i in range(cols)]
        faces = [(idx(i, j), idx(i + 1, j), idx(i + 1, j + 1), idx(i, j + 1)) for j in range(nt) for i in range(na)]
        edges = [((i, j), (i + 1, j)) for j in (0, nt) for i in range(na)]
        if not closed:
            edges += [((i, j), (i, j + 1)) for i in (0, na) for j in range(nt)]
        low = {}
        for e in edges:
            for i, j in e:
                key = (i % cols, j)
                if key not in low:
                    low[key] = len(verts)
                    verts.append(point(i, j, False))
        for (ia, ja), (ib, jb) in edges:
            faces.append((idx(ia, ja), idx(ib, jb), low[(ib % cols, jb)], low[(ia % cols, ja)]))
        a_mid, t_mid = warp(0.5, 0.5) if warp else ((a0 + a1) / 2, (t0 + t1) / 2)
        obj = add(part, name, [B(p) for p in verts], faces, mat)
        return outward(obj, self.centre(t_mid))

    def band(self, part, name, mat, t0, t1, thick=0.006, lift=0.0, n=16, nt=1, sink=0.006, warp=None):
        """A shell all the way round: a belt, a cuff, an armband."""
        return self.shell(part, name, mat, 0.0, 360.0, t0, t1, thick, lift, sides(n), nt, warp, sink, True)

    def project(self, face, u, v, lift=0.0):
        """A point of the surface seen from one side, in the form's own coordinates: (x, height)
        from the front or back, (depth, height) from the outer or inner side."""
        rx, rz, cx, cz = self.eval(v)
        if face in ("front", "back"):
            sq = self._squash(-1.0 if face == "front" else 1.0)
            q = max(-1.0, min(1.0, (u * self.side - cx) / max(rx, 1e-6)))
            ang = math.degrees(math.acos(math.copysign(abs(q) ** (sq / 2), q)))
            a = 360.0 - ang if face == "front" else ang
        else:
            q = max(-1.0, min(1.0, (u - cz) / max(rz, 1e-6)))
            sq = self._squash(q)
            ang = math.degrees(math.asin(math.copysign(abs(q) ** (sq / 2), q)))
            a = ang if face == "outer" else 180.0 - ang
        return self.at(a, v, lift), a

    def patch(self, part, name, mat, outline, face="front", thick=0.006, lift=0.0, cell=0.03, rim=0.005, sink=0.006):
        """A shaped layer drawn from one side and laid on the form: a lapel, a pocket flap, a
        plate. The outline is (x, height) from the front or back, (depth, height) from a side."""
        poly = [tuple(p) for p in outline]
        if signed_area(poly) < 0:
            poly.reverse()
        cell = cell * (1.0, 1.9, 3.6)[lod()]
        dense = []
        for i, p in enumerate(poly):
            q = poly[(i + 1) % len(poly)]
            count = max(1, int(math.ceil((Vector(q) - Vector(p)).length / cell)))
            dense += [tuple(Vector(p).lerp(Vector(q), k / count)) for k in range(count)]
        poly = dense
        ring = inset(poly, rim) if rim > 0 and fine(1) else []
        bounds = ring or poly
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]
        interior = []
        a = min(xs) + cell * 0.5
        while a < max(xs):
            b = min(ys) + cell * 0.5
            while b < max(ys):
                if inside((a, b), bounds) and edge_distance((a, b), bounds) > cell * 0.4:
                    interior.append((a, b))
                b += cell
            a += cell
        coords = [Vector(p) for p in poly + ring + interior]
        n, m = len(poly), len(ring)
        edges = [(n + i, n + (i + 1) % m) for i in range(m)]
        out = geometry.delaunay_2d_cdt(coords, edges, [list(range(n))], 1, 1e-6)
        flat, tris = out[0], out[2]
        verts, roots = [], []
        for v in flat:
            on_edge = bool(ring) and edge_distance((v.x, v.y), poly) < 1e-5
            verts.append(self.project(face, v.x, v.y, lift + (thick * 0.25 if on_edge else thick))[0])
            roots.append(self.project(face, v.x, v.y, lift - sink)[0])
        faces = [tuple(f) for f in tris]
        count = {}
        for f in faces:
            for k in range(len(f)):
                e = (min(f[k], f[(k + 1) % len(f)]), max(f[k], f[(k + 1) % len(f)]))
                count[e] = count.get(e, 0) + 1
        low = {}
        for (i, j), c in count.items():
            if c == 1:
                for k in (i, j):
                    if k not in low:
                        low[k] = len(verts)
                        verts.append(roots[k])
                faces.append((i, j, low[j], low[i]))
        obj = add(part, name, [B(p) for p in verts], faces, mat)
        return outward(obj, self.centre(sum(ys) / len(ys)))

    def strap(self, part, name, mat, path, width=0.03, thick=0.004, lift=0.0, step=0.03, closed=False, sink=0.004):
        """A ribbon running over the surface through (angle, height) points: webbing, a seam."""
        pts = [(float(a), float(t)) for a, t in path]
        samples = []
        n = len(pts)
        last = n if closed else n - 1
        for i in range(last):
            p0, p1 = pts[(i - 1) % n] if closed else pts[max(i - 1, 0)], pts[i]
            p2, p3 = pts[(i + 1) % n], pts[(i + 2) % n] if closed else pts[min(i + 2, n - 1)]
            # Angles may run past a full turn, so the neighbours are unwrapped onto this span.
            a1 = p1[0]
            a0, a2 = a1 + wrap_angle(p0[0], a1), a1 + wrap_angle(p2[0], a1)
            a3 = a2 + wrap_angle(p3[0], a2)
            length = (self.surface(a1, p1[1]) - self.surface(a2, p2[1])).length
            count = max(1, int(round(length / stride(step))))
            for k in range(count):
                u = k / count
                samples.append((catmull(a0, a1, a2, a3, u), catmull(p0[1], p1[1], p2[1], p3[1], u)))
        if not closed:
            samples.append(pts[-1])
        m = len(samples)
        verts = []
        for i, (a, t) in enumerate(samples):
            nrm = self.normal(a, t)
            before = samples[(i - 1) % m] if closed else samples[max(i - 1, 0)]
            after = samples[(i + 1) % m] if closed else samples[min(i + 1, m - 1)]
            tangent = self.surface(*after) - self.surface(*before)
            across = nrm.cross(tangent)
            across = across.normalized() if across.length > 1e-9 else Vector((1, 0, 0))
            top = self.at(a, t, lift + thick)
            down = nrm * (thick + sink)
            verts += [top + across * width / 2, top - across * width / 2, top - across * width / 2 - down, top + across * width / 2 - down]
        faces = []
        for i in range(m if closed else m - 1):
            j = (i + 1) % m
            for k in range(3):
                faces.append((i * 4 + k, i * 4 + k + 1, j * 4 + k + 1, j * 4 + k))
        if not closed:
            faces += [(0, 1, 2, 3), ((m - 1) * 4 + 3, (m - 1) * 4 + 2, (m - 1) * 4 + 1, (m - 1) * 4)]
        obj = add(part, name, [B(p) for p in verts], faces, mat)
        return outward(obj, self.centre(samples[m // 2][1]))

    def pad(self, part, name, mat, a, t, w, h, depth, lift=0.0, soft=0.3, na=5, nt=5):
        """A soft pouch hugging the form, `w` wide and `h` tall, centred on (a, t)."""
        a0, a1 = self.span(a, t, w)

        def puff(u, v):
            edge = min(u, 1 - u, v, 1 - v) * 2
            return depth * (0.45 + 0.55 * min(1.0, edge / soft) ** 0.6)

        return self.shell(part, name, mat, a0, a1, t - h / 2, t + h / 2, puff, lift, na, nt)

    def stud(self, part, name, mat, a, t, radius=0.008, height=0.004, lift=0.0, n=8):
        """A button or a rivet standing on the surface."""
        p = self.at(a, t, lift)
        nrm = self.normal(a, t)
        return disc(part, name, mat, p, nrm, radius, height, sides(n))


# ---------------------------------------------------------------- free pieces

def disc(part, name, mat, pos, nrm, radius, height, n=8, taper=0.7):
    pos, nrm = Vector(pos), Vector(nrm).normalized()
    u = nrm.orthogonal().normalized()
    v = nrm.cross(u)
    verts = []
    for r, h in ((radius, -0.003), (radius, height * 0.6), (radius * taper, height)):
        verts += [pos + (u * math.cos(math.tau * k / n) + v * math.sin(math.tau * k / n)) * r + nrm * h for k in range(n)]
    faces = [(r * n + k, r * n + (k + 1) % n, (r + 1) * n + (k + 1) % n, (r + 1) * n + k) for r in range(2) for k in range(n)]
    faces.append(tuple(2 * n + k for k in range(n)))
    obj = add(part, name, [B(p) for p in verts], faces, mat)
    return outward(obj, pos - nrm * 0.05)


def tube(part, name, points, radius, mat, n=6, caps=True, up=(0, 1, 0)):
    """A round run through points: a cable, a finger. `radius` may be one value or one per point."""
    pts = [Vector(p) for p in points]
    n = max(3, sides(n) if n > 4 else n)
    rings = []
    side = None
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = side if side is not None else Vector(up).cross(d)
        if ref.length < 0.01:
            ref = d.orthogonal()
        # Carried from ring to ring, so the tube does not twist where it turns.
        side = (ref - d * ref.dot(d)).normalized()
        across = d.cross(side)
        r = radius[i] if isinstance(radius, (list, tuple)) else radius
        rings.append([p + (side * math.cos(math.tau * k / n) + across * math.sin(math.tau * k / n)) * r for k in range(n)])
    obj = add(part, name, [B(p) for ring in rings for p in ring], rings_to_faces(len(rings), n, caps), mat)
    return outward(obj)


def loft(part, name, rings, mat, caps=True, level=0, sharp=(), crease_ends=True, edge=0.0):
    """Explicit rings into a body, optionally rounded by subdivision. Columns in `sharp` stay crisp."""
    n = len(rings[0])
    obj = add(part, name, [B(p) for ring in rings for p in ring], rings_to_faces(len(rings), n, caps), mat)
    outward(obj)
    level = max(0, level - lod())
    if level:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.verts.ensure_lookup_table()
        crease = bm.edges.layers.float.get("crease_edge") or bm.edges.layers.float.new("crease_edge")
        for i in range(len(rings) - 1):
            for j in sharp:
                e = bm.edges.get((bm.verts[i * n + j], bm.verts[(i + 1) * n + j]))
                if e:
                    e[crease] = 1.0
        if crease_ends:
            for i in (0, len(rings) - 1):
                for j in range(n):
                    e = bm.edges.get((bm.verts[i * n + j], bm.verts[i * n + (j + 1) % n]))
                    if e:
                        e[crease] = 1.0
        bm.to_mesh(obj.data)
        bm.free()
        mod = obj.modifiers.new("smooth", "SUBSURF")
        mod.levels = level
        mod.render_levels = level
        bake_modifiers(obj)
    return bevel(obj, edge)


def slab(part, name, outline, x0, x1, mat, edge=0.0, plane="zy"):
    """An outline given thickness. Plane "zy" is drawn from the side as (z, y) and runs across X;
    "xy" is drawn from the front and runs along Z; "xz" is drawn from above and runs up Y."""
    poly = [tuple(p) for p in outline]
    if signed_area(poly) < 0:
        poly.reverse()
    out = geometry.delaunay_2d_cdt([Vector(p) for p in poly], [], [list(range(len(poly)))], 1, 1e-7)
    flat, tris = out[0], out[2]

    def place(p, d):
        return {"zy": (d, p[1], p[0]), "xy": (p[0], p[1], d), "xz": (p[0], d, p[1])}[plane]

    n = len(flat)
    verts = [B(place(v, x0)) for v in flat] + [B(place(v, x1)) for v in flat]
    faces = [tuple(t) for t in tris] + [tuple(i + n for i in reversed(t)) for t in tris]
    key = {(round(v.x, 6), round(v.y, 6)): i for i, v in enumerate(flat)}
    ids = [key[(round(p[0], 6), round(p[1], 6))] for p in poly if (round(p[0], 6), round(p[1], 6)) in key]
    faces += [(ids[j], ids[(j + 1) % len(ids)], ids[(j + 1) % len(ids)] + n, ids[j] + n) for j in range(len(ids))]
    obj = add(part, name, verts, faces, mat)
    outward(obj)
    return bevel(obj, edge)


def block(part, name, mat, centre, size, edge=0.004, turn=None):
    """A chamfered box, for the few things that really are boxes: a radio, a magazine."""
    c, (w, h, d) = Vector(centre), size
    corners = [Vector((sx * w / 2, sy * h / 2, sz * d / 2)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    if turn is not None:
        corners = [turn @ p for p in corners]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    obj = add(part, name, [B(c + p) for p in corners], faces, mat)
    outward(obj)
    return bevel(obj, edge)


def remap(part, fn, flip=False):
    """Moves every point of a part that is still in pieces. `fn` takes and returns Godot metres;
    `flip` is for a mapping that mirrors, which turns the faces inside out."""
    for obj in PIECES[part]:
        for v in obj.data.vertices:
            q = fn(Vector((v.co.x, v.co.z, -v.co.y)))
            v.co = (q.x, -q.z, q.y)
        if flip:
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
            bm.to_mesh(obj.data)
            bm.free()
        obj.data.update()


# ---------------------------------------------------------------- binding to the skeleton

GROUPS = {"torso": "trunk", "Torso": "trunk", "Pelvis": "trunk", "Head": "head"}
for _tag in ("R", "L"):
    for _bone in ("arm", "UpperArm", "Forearm", "Hand"):
        GROUPS[f"{_bone}_{_tag}" if _bone != "arm" else f"arm_{_tag.lower()}"] = f"arm_{_tag}"
    for _bone in ("leg", "Thigh", "Shin", "Boot"):
        GROUPS[f"{_bone}_{_tag}" if _bone != "leg" else f"leg_{_tag.lower()}"] = f"leg_{_tag}"


def weights(rule, p):
    """How much each bone moves a point at rest position `p`."""
    if rule in JOINT:
        return {rule: 1.0}
    if rule in ("arm_r", "arm_l"):
        tag = "R" if rule == "arm_r" else "L"
        y = p.y - JOINT[f"UpperArm_{tag}"].y
        fore = smooth(-(UPPER_ARM - 0.055), -(UPPER_ARM + 0.055), y)
        hand = smooth(-(UPPER_ARM + FOREARM - 0.012), -(UPPER_ARM + FOREARM + 0.012), y)
        # The head of the sleeve sits inside the shoulder and gives a little with the trunk.
        trunk = 0.4 * smooth(-0.015, 0.06, y)
        return {"Torso": trunk, f"UpperArm_{tag}": (1 - fore) * (1 - trunk), f"Forearm_{tag}": fore * (1 - hand), f"Hand_{tag}": fore * hand}
    if rule in ("leg_r", "leg_l"):
        tag = "R" if rule == "leg_r" else "L"
        y = p.y - JOINT[f"Thigh_{tag}"].y
        shin = smooth(-(THIGH - 0.07), -(THIGH + 0.07), y)
        boot = smooth(0.17, 0.07, p.y)
        hips = 0.55 * smooth(-0.1, 0.04, y)
        return {"Pelvis": hips, f"Thigh_{tag}": (1 - shin) * (1 - hips), f"Shin_{tag}": shin * (1 - boot), f"Boot_{tag}": shin * boot}
    if rule in ("torso", "skirt"):
        out = {}
        head = smooth(1.575, 1.635, p.y)
        chest = smooth(0.93, 1.13, p.y)
        # The seat and the hem of a jacket go with the legs, less so toward the middle.
        tag = "R" if p.x >= 0 else "L"
        # A hem rides up on the thigh in front and hangs behind it.
        reach = (0.3 + 0.5 * smooth(0.06, -0.06, p.z)) * smooth(0.965, 0.84, p.y) * smooth(0.0, 0.075, abs(p.x))
        # The point of the shoulder lifts a little with the arm.
        sh = JOINT[f"UpperArm_{tag}"]
        d = math.hypot((abs(p.x) - abs(sh.x)), p.y - sh.y)
        arm = 0.42 * smooth(0.13, 0.035, d) * smooth(abs(sh.x) - 0.1, abs(sh.x) - 0.02, abs(p.x))
        out[f"Thigh_{tag}"] = reach
        out[f"UpperArm_{tag}"] = arm * (1 - head)
        rest = 1 - reach - out[f"UpperArm_{tag}"]
        out["Head"] = rest * head
        out["Torso"] = rest * (1 - head) * chest
        out["Pelvis"] = rest * (1 - head) * (1 - chest)
        return out
    raise KeyError(rule)


def bind_piece(obj):
    rule = obj["bind"]
    groups = {}
    for v in obj.data.vertices:
        p = Vector((v.co.x, v.co.z, -v.co.y))
        for bone, w in weights(rule, p).items():
            if w > 0.004:
                if bone not in groups:
                    groups[bone] = obj.vertex_groups.new(name=bone)
                groups[bone].add([v.index], w, "REPLACE")


def bake_shade(objs, reach=0.08, rays=10, floor=0.55):
    """Shadows where cloth folds and parts meet, kept on each vertex. Pieces of one limb shade each
    other but not the rest of the body, since the limbs will not stay where they were built."""
    verts, polys = [], []
    for obj in objs:
        base = len(verts)
        verts += [v.co.copy() for v in obj.data.vertices]
        polys += [tuple(base + i for i in p.vertices) for p in obj.data.polygons]
    if not polys:
        return
    whole = BVHTree.FromPolygons(verts, polys)
    rnd = random.Random(11)
    dirs = []
    for _ in range(rays):
        u, a = rnd.random(), rnd.random() * math.tau
        r = math.sqrt(u)
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(1 - u))))
    for obj in objs:
        mesh = obj.data
        attr = mesh.attributes.get("shade") or mesh.attributes.new("shade", "FLOAT", "POINT")
        if obj.get("unshaded"):
            for v in mesh.vertices:
                attr.data[v.index].value = 1.0
            continue
        for v in mesh.vertices:
            n = v.normal
            t = n.orthogonal().normalized()
            b = n.cross(t)
            start = v.co + n * 0.005
            free = sum(1 for d in dirs if whole.ray_cast(start, t * d.x + b * d.y + n * d.z, reach)[0] is None)
            attr.data[v.index].value = floor + (1 - floor) * free / rays


def join(part):
    objs = PIECES.pop(part)
    by_group = {}
    for obj in objs:
        by_group.setdefault(GROUPS.get(obj["bind"], obj["bind"]), []).append(obj)
    for group in by_group.values():
        bake_shade(group)
    for obj in objs:
        bind_piece(obj)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = part
    obj.data.name = part
    return obj


def paint(obj, tone=None):
    """Writes the vertex colours the game reads: paint times shadow, gamma-encoded so that dark
    cloth keeps its shading in eight bits, and the kind of surface in alpha."""
    mesh = obj.data
    names = [m.name for m in mesh.materials]
    shade_attr = mesh.attributes.get("shade")
    shade_of = [d.value for d in shade_attr.data] if shade_attr else [1.0] * len(mesh.vertices)
    attr = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for poly in mesh.polygons:
        key = names[poly.material_index]
        rgb, kind = PALETTE[key]
        alpha = (KINDS.index(kind) + 0.5) / 16.0
        lit = kind in ("glow", "lamp")
        for li in poly.loop_indices:
            v = mesh.vertices[mesh.loops[li].vertex_index]
            s = 1.0 if lit else shade_of[v.index]
            mix = (s, s, s)
            if tone and not lit:
                # A tone is one number, or three to shift the colour as rust does.
                worn = tone(Vector((v.co.x, v.co.z, -v.co.y)), key)
                mix = tuple(s * w for w in worn) if isinstance(worn, tuple) else (s * worn,) * 3
            attr.data[li].color = (*(max(0.0, min(1.0, c * m)) ** (1 / 2.2) for c, m in zip(rgb, mix)), alpha)
    mesh.color_attributes.active_color_index = 0
    mesh.color_attributes.render_color_index = 0


def unwrap(obj):
    """Box-projected UVs in metres, so the weave has one scale everywhere and stays on the cloth."""
    mesh = obj.data
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        n = poly.normal
        axis = max(range(3), key=lambda k: abs(n[k]))
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv = [(co.y, co.z), (co.x, co.z), (co.x, co.y)][axis]


def smooth_shade(obj, angle=38.0):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    limit = math.radians(angle)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = len(e.link_faces) == 2 and e.calc_face_angle(9.0) < limit
    bm.to_mesh(obj.data)
    bm.free()


def char_material():
    """One material for every mesh. In Blender it only has to show what the game will."""
    m = bpy.data.materials.get("Char")
    if m:
        return m
    m = bpy.data.materials.new("Char")
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes["Principled BSDF"]
    col = nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Col"
    gamma = nodes.new("ShaderNodeGamma")
    gamma.inputs[1].default_value = 2.2
    links.new(col.outputs["Color"], gamma.inputs[0])
    tinted = nodes.new("ShaderNodeMix")
    tinted.data_type = "RGBA"
    tinted.blend_type = "MULTIPLY"
    tinted.inputs[7].default_value = (*PREVIEW_TINT[0], 1)
    links.new(gamma.outputs[0], tinted.inputs[6])
    links.new(tinted.outputs[2], bsdf.inputs["Base Color"])

    def ramp(values):
        node = nodes.new("ShaderNodeValToRGB")
        node.color_ramp.interpolation = "CONSTANT"
        elems = node.color_ramp.elements
        elems[0].position = 0.0
        elems[0].color = (values[0],) * 3 + (1,)
        elems[1].position = 1 / 16
        elems[1].color = (values[1],) * 3 + (1,)
        for i in range(2, len(values)):
            e = elems.new(i / 16)
            e.color = (values[i],) * 3 + (1,)
        links.new(col.outputs["Alpha"], node.inputs[0])
        return node

    links.new(ramp([1.0 if k in ("skin", "tint") else 0.0 for k in KINDS]).outputs[0], tinted.inputs[0])
    links.new(ramp([KIND_LOOK[k][0] for k in KINDS]).outputs[0], bsdf.inputs["Roughness"])
    links.new(ramp([KIND_LOOK[k][1] for k in KINDS]).outputs[0], bsdf.inputs["Metallic"])
    links.new(ramp([4.0 if k in ("glow", "lamp") else 0.0 for k in KINDS]).outputs[0], bsdf.inputs["Emission Strength"])
    links.new(tinted.outputs[2], bsdf.inputs["Emission Color"])
    return m


def finish(part, label=None, tone=None, angle=38.0):
    """Joins a part's pieces into the one mesh the game loads, named with its level of detail."""
    obj = join(part)
    smooth_shade(obj, angle)
    paint(obj, tone)
    if fine(0):
        unwrap(obj)
    obj.data.materials.clear()
    obj.data.materials.append(char_material())
    for poly in obj.data.polygons:
        poly.material_index = 0
    obj.name = f"{label or part}_L{lod()}"
    obj.data.name = obj.name
    return obj


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# ---------------------------------------------------------------- the skeleton and the file

def armature(name="Rig"):
    """The game's joints as bones. Each stands upright, so a bone at rest has no rotation and
    SoldierModel's joints can be copied onto it as they are."""
    data = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for bone in BONES:
        eb = data.edit_bones.new(bone)
        eb.head = B(JOINT[bone])
        eb.tail = eb.head + Vector((0, 0, 0.06))
        eb.roll = 0.0
        if bone in PARENT:
            eb.parent = made[PARENT[bone]]
        made[bone] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def skin(obj, rig):
    obj.parent = rig
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    for bone in BONES:
        if bone not in obj.vertex_groups:
            obj.vertex_groups.new(name=bone)


def export(path, objs, rig=None):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    if rig:
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_normals=True, export_tangents=False, export_materials="EXPORT", export_vertex_color="ACTIVE",
        export_all_vertex_colors=False, export_skins=rig is not None, export_animations=False, export_cameras=False,
        export_lights=False, export_texcoords=True,
    )


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    PIECES.clear()


# ---------------------------------------------------------------- previews

def studio(width=1400, height=900, sky=(0.42, 0.45, 0.5)):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (*sky, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    for energy, angles in ((3.2, (52, 8, 28)), (1.1, (62, 0, 205))):
        sun = bpy.data.lights.new("sun", "SUN")
        sun.energy = energy
        s = bpy.data.objects.new("sun", sun)
        s.rotation_euler = tuple(math.radians(a) for a in angles)
        bpy.context.collection.objects.link(s)
    cam = bpy.data.cameras.new("cam")
    cam.lens = 85
    c = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(c)
    scene.camera = c
    return c


def stand(obj, x, y=0.0):
    """A loose copy of a mesh for the previews, moved along the row."""
    copy = obj.copy()
    copy.parent = None
    copy.modifiers.clear()
    bpy.context.collection.objects.link(copy)
    copy.location = (x, y, 0)
    return copy


def shoot(cam, folder, label, pos, aim, lens=85):
    """`pos` and `aim` in Godot metres."""
    cam.data.lens = lens
    cam.location = B(pos)
    cam.rotation_euler = (B(aim) - B(pos)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = str(Path(folder) / f"{label}.png")
    bpy.ops.render.render(write_still=True)
