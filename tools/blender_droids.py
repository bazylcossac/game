"""Builds Korpo's machines for Corp Wars: robots in black suits, white shirts and ties.

Run:  blender --background --factory-startup --python tools/blender_droids.py [-- --preview DIR]

Every frame hangs on the same procedural skeleton as the human soldiers, so each part is modelled
around its joint, in Godot metres (+Y up, -Z forward). Joints: pelvis .95 above the ground, torso
.08 above that, head .53 above the torso, shoulders at (+-.28, .47), upper arm .29, forearm .28,
hips at (+-.1, -.05), thigh .45, shin .45.

The look: a corporation that replaced its staff. Tailored black suits over a machine, white
shirts, a pale porcelain face with nothing behind the eyes but two red lights, chrome showing at
the neck, wrists and ankles. The tie is a separate part, recoloured per class in the game.

  Reg  the employee: a slim suit, the standard face.
  Big  the liquidator: a suit stretched over armour; its forearms are a laser cannon (right) and a
       two-rocket pod (left), the way a war droid's would be.
  Cmd  the headhunter: a long overcoat and a hat brim over the eyes.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector, geometry

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_kit import *  # noqa: E402,F403

OUT = ROOT / "assets/models/armory"
CORE, LENS, CABLE, METAL = "EnergyIndicator", "Glass", "Rubber", "DroidMetal"
SUIT, SATIN, SHIRT, SHELL, FACE, SHOE, TIE, GUN, WARN = (
    "Suit", "SuitSatin", "Shirt", "DroidShell", "DroidFace", "Shoe", "Tie", "DroidGun", "WarningRed")
FRAMES = ["Reg", "Big", "Cmd"]
PALETTE.update({
    CORE: ((1.0, 0.08, 0.05), 0, 0.4, 5), LENS: ((0.005, 0.005, 0.007), 0.4, 0.06, 0), CABLE: ((0.012, 0.012, 0.014), 0, 0.8, 0),
    METAL: ((0.6, 0.61, 0.64), 0.95, 0.2, 0), SUIT: ((0.018, 0.018, 0.021), 0, 0.72, 0), SATIN: ((0.01, 0.01, 0.012), 0.1, 0.3, 0),
    SHIRT: ((0.8, 0.8, 0.79), 0, 0.6, 0), SHELL: ((0.02, 0.02, 0.024), 0.8, 0.2, 0), FACE: ((0.72, 0.7, 0.66), 0.05, 0.28, 0),
    SHOE: ((0.012, 0.011, 0.011), 0.1, 0.22, 0), TIE: ((0.6, 0.6, 0.6), 0, 0.4, 0), GUN: ((0.07, 0.072, 0.08), 0.75, 0.32, 0),
    WARN: ((0.7, 0.05, 0.03), 0.1, 0.45, 0), "_Worn": ((1, 0, 1), 0, 1, 0),
})


# ---------------------------------------------------------------- helpers

def ring_y(y, w, d, cut, cz=0.0, cx=0.0):
    """A chamfered eight-sided section lying flat, for hard parts built up the body."""
    return [(cx + w - cut, y, cz - d), (cx + w, y, cz - d + cut), (cx + w, y, cz + d - cut), (cx + w - cut, y, cz + d),
            (cx - w + cut, y, cz + d), (cx - w, y, cz + d - cut), (cx - w, y, cz - d + cut), (cx - w + cut, y, cz - d)]


def block(part, name, stations, mat, bevel=0.004, cx=0.0):
    """Hard parts built from sections: [(y, half_w, half_d, cut[, cz]), ...]."""
    rings = [ring_y(s[0], s[1], s[2], s[3], s[4] if len(s) > 4 else 0.0, cx) for s in stations]
    obj = sculpt(part, name, rings, mat, tuple(range(8)), level=0, bevel=0.0)
    worn_chamfer(obj, bevel, 22.0)
    return obj


def cloth_y(part, name, stations, mat, sides=20, squash=2.4, cx=0.0, cz=0.0):
    """Tailored cloth standing along Y: [(y, rx, rz[, dz]), ...]. `dz` shifts a ring forward or back."""
    rings = []
    for st in stations:
        y, rx, rz = st[0], st[1], st[2]
        dz = st[3] if len(st) > 3 else 0.0
        ring = []
        for i in range(sides):
            a = math.tau * i / sides
            c, s = math.cos(a), math.sin(a)
            ring.append((cx + rx * math.copysign(abs(c) ** (2 / squash), c), y, cz + dz + rz * math.copysign(abs(s) ** (2 / squash), s)))
        rings.append(ring)
    obj = add(part, name, [B(p) for r in rings for p in r], rings_to_faces(len(rings), sides), mat)
    outward(obj)
    return obj


def facing(part, name, outline, z, depth, mat, bevel=0.0012, bow=0.0):
    """A flat shape seen from the front, as (x, y) points, standing `depth` thick behind `z`.
    `bow` bends it back at the sides, so it lies on a rounded chest."""
    ring = [Vector(p) for p in outline]
    area = sum(ring[i].x * ring[(i + 1) % len(ring)].y - ring[(i + 1) % len(ring)].x * ring[i].y for i in range(len(ring)))
    if area < 0:
        ring.reverse()
    out = geometry.delaunay_2d_cdt(ring, [], [list(range(len(ring)))], 2, 1e-7)
    flat, tris = out[0], out[2]
    n = len(flat)
    verts = [B((v.x, v.y, z + bow * v.x * v.x)) for v in flat] + [B((v.x, v.y, z + depth + bow * v.x * v.x)) for v in flat]
    faces = [tuple(reversed(t)) for t in tris] + [tuple(i + n for i in t) for t in tris]
    key = {(round(v.x, 6), round(v.y, 6)): i for i, v in enumerate(flat)}
    ids = [key.get((round(p.x, 6), round(p.y, 6))) for p in ring]
    ids = [i for i in ids if i is not None]
    for j in range(len(ids)):
        a, b = ids[j], ids[(j + 1) % len(ids)]
        faces.append((a, b, b + n, a + n))
    obj = add(part, name, verts, faces, mat)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    worn_chamfer(obj, bevel, 30.0)
    return obj


def shell_front(part, name, stations, mat, a0=200.0, a1=340.0, steps=12, thick=0.006, squash=2.2):
    """The front of an egg, as a thin mask: [(y, rx, rz), ...], from angle a0 to a1 round Y."""
    outer, inner = [], []
    for y, rx, rz in stations:
        o, i = [], []
        for k in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * k / steps)
            c, s = math.cos(a), math.sin(a)
            ex, ez = math.copysign(abs(c) ** (2 / squash), c), math.copysign(abs(s) ** (2 / squash), s)
            o.append((rx * ex, y, rz * ez))
            i.append(((rx - thick) * ex, y, (rz - thick) * ez))
        outer.append(o)
        inner.append(i)
    m = steps + 1
    rows = len(stations)
    verts = [B(p) for r in outer for p in r] + [B(p) for r in inner for p in r]
    base = rows * m
    faces = []
    for r in range(rows - 1):
        for k in range(m - 1):
            a, b, c, d = r * m + k, r * m + k + 1, (r + 1) * m + k + 1, (r + 1) * m + k
            faces.append((a, b, c, d))
            faces.append((base + d, base + c, base + b, base + a))
    for r in range(rows - 1):
        for k in (0, m - 1):
            a, d = r * m + k, (r + 1) * m + k
            faces.append((a, d, base + d, base + a))
    for r in (0, rows - 1):
        for k in range(m - 1):
            a, b = r * m + k, r * m + k + 1
            faces.append((a, base + a, base + b, b))
    obj = add(part, name, verts, faces, mat)
    outward(obj)
    return obj


def joint(part, pos, r, mat=SHELL):
    """A ball joint, squashed like a machined bearing, with a chrome band."""
    x, y, z = pos
    stations = [(y - r, 0.0, 0.0), (y - r * 0.8, r * 0.6, r * 0.6), (y - r * 0.3, r * 0.96, r * 0.96), (y + r * 0.3, r * 0.96, r * 0.96), (y + r * 0.8, r * 0.6, r * 0.6), (y + r, 0.0, 0.0)]
    upright(part, "Joint", stations, mat, 12, x, z)
    upright(part, "Joint band", [(y - r * 0.12, r * 1.02, r * 1.02), (y + r * 0.12, r * 1.02, r * 1.02)], METAL, 12, x, z)


def piston(part, a, b, r):
    """A chrome rod in a black sleeve: the machine showing where the suit does not cover it."""
    mid = tuple(Vector(a).lerp(Vector(b), 0.55))
    tube(part, "Sleeve", [a, mid], r, SHELL, 8)
    tube(part, "Rod", [mid, b], r * 0.55, METAL, 8)


def hand(part, size=1.0):
    """A machine hand closed on a grip: black palm, chrome finger joints. The palm sits at the origin."""
    block(part, "Palm", [(-0.048 * size, 0.03 * size, 0.024 * size, 0.008), (0.0, 0.034 * size, 0.03 * size, 0.01), (0.046 * size, 0.028 * size, 0.024 * size, 0.008)], SHELL, 0.002)
    for i in range(4):
        y = (-0.034 + i * 0.022) * size
        pts = [(0.028 * size, y, 0.014 * size), (0.046 * size, y, -0.014 * size), (0.038 * size, y, -0.042 * size), (0.014 * size, y, -0.054 * size), (-0.008 * size, y, -0.044 * size)]
        tube(part, "Finger", pts, 0.0085 * size, SHELL, 6)
        for p in pts[1:4]:
            upright(part, "Knuckle", [(p[1] - 0.008 * size, 0.0098 * size, 0.0098 * size), (p[1] + 0.008 * size, 0.0098 * size, 0.0098 * size)], METAL, 8, p[0], p[2])
    tube(part, "Thumb", [(-0.026 * size, 0.03 * size, 0.012 * size), (-0.042 * size, 0.04 * size, -0.016 * size), (-0.03 * size, 0.046 * size, -0.04 * size), (-0.008 * size, 0.046 * size, -0.05 * size)], 0.0095 * size, SHELL, 6)
    upright(part, "Knuckle", [(0.032 * size, 0.011 * size, 0.011 * size), (0.048 * size, 0.011 * size, 0.011 * size)], METAL, 8, -0.042 * size, -0.016 * size)


# ---------------------------------------------------------------- the suit, shared by every frame

def pelvis(L, k, coat):
    p = f"{L}_Pelvis"
    cloth_y(p, "Trousers", [(-0.16, 0.13 * k, 0.1 * k), (-0.1, 0.166 * k, 0.116 * k), (0.0, 0.176 * k, 0.12 * k), (0.07, 0.17 * k, 0.118 * k), (0.12, 0.164 * k, 0.114 * k)], SUIT, 20, 2.2)
    cloth_y(p, "Belt", [(0.07, 0.173 * k, 0.121 * k), (0.105, 0.173 * k, 0.121 * k)], SHOE, 20, 2.2)
    block(p, "Buckle", [(0.074, 0.018, 0.004, 0.002, -0.124 * k), (0.101, 0.018, 0.004, 0.002, -0.124 * k)], METAL, 0.001)
    # The jacket's skirt: buttoned at the waist, parting in a narrow V below the button.
    hem = -0.22 if coat else -0.11
    cloth_y(p, "Jacket skirt", [(0.14, 0.174 * k, 0.122 * k), (0.06, 0.186 * k, 0.13 * k), (-0.02, 0.194 * k, 0.136 * k), (hem, 0.2 * k, 0.142 * k, 0.004)], SUIT, 24, 2.3)
    facing(p, "Skirt split", [(0.0, 0.0), (0.028 * k, hem + 0.002), (-0.028 * k, hem + 0.002)], -0.146 * k + (0.004 if coat else 0.0) - 0.002, 0.004, SATIN)
    if coat:
        for side in (1, -1):
            facing(p, "Coat lapel", [(side * 0.004, 0.13), (side * 0.06, 0.13), (side * 0.03, hem + 0.01), (side * 0.004, hem + 0.01)], -0.15 * k, 0.006, SATIN)
    for side in (1, -1):
        joint(p, (side * 0.1, -0.05, 0), 0.045)


def torso(L, k, coat):
    t = f"{L}_Torso"
    w = 1.0 + (k - 1.0) * 1.6
    # Jacket over the frame: a chest, a waist, and shoulders that round over into the sleeves.
    cloth_y(t, "Jacket", [(-0.05, 0.168 * w, 0.118 * k), (0.06, 0.17 * w, 0.12 * k), (0.18, 0.19 * w, 0.13 * k, -0.002), (0.3, 0.214 * w, 0.136 * k, -0.003),
                          (0.4, 0.228 * w, 0.132 * k), (0.46, 0.226 * w, 0.122 * k), (0.5, 0.2 * w, 0.106 * k), (0.535, 0.15 * w, 0.088 * k), (0.555, 0.09, 0.074)], SUIT, 28, 2.3)
    front = -0.136 * k
    # White shirt in the opening of the jacket, then the lapels laid over its edges.
    facing(t, "Shirt front", [(0.0, 0.25), (0.078, 0.535), (-0.078, 0.535)], front - 0.002, 0.012, SHIRT, 0.0008, 1.4)
    for side in (1, -1):
        s = side
        facing(t, "Lapel", [(s * 0.004, 0.245), (s * 0.08, 0.54), (s * 0.13 * w, 0.53), (s * 0.15 * w, 0.47), (s * 0.118 * w, 0.452), (s * 0.06, 0.3)], front - 0.012, 0.012, SATIN, 0.0015, 1.4)
        facing(t, "Collar point", [(s * 0.012, 0.5), (s * 0.075, 0.54), (s * 0.05, 0.47)], front - 0.017, 0.006, SHIRT, 0.0008, 1.4)
    facing(t, "Pocket", [(-0.165 * w, 0.37), (-0.085 * w, 0.37), (-0.085 * w, 0.364), (-0.165 * w, 0.364)], front - 0.004, 0.005, SATIN, 0.0, 1.4)
    facing(t, "Pocket square", [(-0.16 * w, 0.37), (-0.14 * w, 0.392), (-0.12 * w, 0.378), (-0.1 * w, 0.388), (-0.09 * w, 0.37)], front - 0.006, 0.005, SHIRT, 0.0, 1.4)
    # The company pin: a single red light on the lapel, the only colour on the suit.
    turned(t, "Lapel pin", [(front - 0.012, 0.009), (front - 0.017, 0.009), (front - 0.018, 0.0)], CORE, 10, -0.112 * w, 0.44)
    for y in (0.2, 0.12):
        turned(t, "Button", [(front - 0.002, 0.01), (front - 0.007, 0.009), (front - 0.008, 0.0)], SATIN, 10, 0.0, y)
    # Shirt collar and the chrome neck rising out of it.
    cloth_y(t, "Shirt collar", [(0.51, 0.074, 0.07), (0.575, 0.068, 0.064)], SHIRT, 16)
    upright(t, "Neck", [(0.5, 0.05, 0.05), (0.6, 0.042, 0.042)], METAL, 12)
    for side in (1, -1):
        tube(t, "Neck cable", [(side * 0.034, 0.5, 0.03), (side * 0.04, 0.56, 0.02), (side * 0.03, 0.62, 0.018)], 0.008, CABLE, 6)
    # Down the back, the jacket is split over a lit vent: the only place the machine shows through.
    facing(t, "Back seam", [(-0.008, 0.08), (0.008, 0.08), (0.008, 0.4), (-0.008, 0.4)], 0.122 * k + 0.004, -0.004, LENS, 0.0)
    for y in (0.16, 0.24, 0.32):
        facing(t, "Vent light", [(-0.004, y), (0.004, y), (0.004, y + 0.03), (-0.004, y + 0.03)], 0.122 * k + 0.005, -0.002, CORE, 0.0)
    if coat:
        cloth_y(t, "Coat collar", [(0.47, 0.17, 0.12), (0.56, 0.12, 0.1), (0.6, 0.11, 0.095)], SUIT, 20, 2.6)


def tie(name, k):
    """Knot, then a blade widening down the shirt to a point. Recoloured per class in the game."""
    front = -0.136 * k - 0.016
    facing(name, "Knot", [(-0.019, 0.508), (0.019, 0.508), (0.014, 0.478), (-0.014, 0.478)], front - 0.006, 0.012, TIE, 0.002, 1.4)
    facing(name, "Blade", [(-0.012, 0.478), (0.012, 0.478), (0.034, 0.3), (0.0, 0.262), (-0.034, 0.3)], front, 0.006, TIE, 0.0015, 1.4)
    facing(name, "Tie clip", [(-0.03, 0.39), (0.03, 0.39), (0.03, 0.384), (-0.03, 0.384)], front - 0.002, 0.004, METAL, 0.0, 1.4)


def head(L, hat):
    h = f"{L}_Head"
    upright(h, "Neck top", [(-0.02, 0.04, 0.04), (0.06, 0.036, 0.036)], METAL, 12)
    for y in (0.0, 0.03):
        upright(h, "Neck ring", [(y, 0.044, 0.044), (y + 0.008, 0.044, 0.044)], SHELL, 12)
    # A smooth black skull, the shape of a head and nothing more.
    upright(h, "Skull", [(0.03, 0.048, 0.054), (0.06, 0.084, 0.094), (0.12, 0.1, 0.112), (0.2, 0.098, 0.108), (0.25, 0.08, 0.092), (0.28, 0.046, 0.054), (0.293, 0.0, 0.0)], SHELL, 24, 0.0, 0.004, 2.2)
    # Moulded hair, swept back the way the company's portraits wear it.
    shell_front(h, "Hair", [(0.21, 0.104, 0.114), (0.25, 0.086, 0.098), (0.282, 0.052, 0.06)], SATIN, 150.0, 390.0, 16, 0.006, 2.2)
    # The face: a pale porcelain mask, too smooth, too calm.
    shell_front(h, "Face", [(0.05, 0.07, 0.088), (0.08, 0.09, 0.104), (0.13, 0.102, 0.116), (0.19, 0.1, 0.114), (0.225, 0.088, 0.104)], FACE, 205.0, 335.0, 14, 0.008, 2.2)
    facing(h, "Nose", [(-0.012, 0.115), (0.012, 0.115), (0.004, 0.16), (-0.004, 0.16)], -0.124, 0.014, FACE, 0.002)
    for side in (1, -1):
        x = side * 0.04
        # Deep sockets and a hard red light in each, under a brow that slants down to the middle.
        facing(h, "Eye socket", [(x - side * 0.026, 0.162), (x + side * 0.022, 0.168), (x + side * 0.02, 0.146), (x - side * 0.024, 0.142)], -0.118, 0.012, LENS, 0.001)
        turned(h, "Eye", [(-0.121, 0.0, 0.0), (-0.122, 0.014, 0.006), (-0.118, 0.014, 0.006)], CORE, 12, x, 0.156)
        facing(h, "Brow", [(x - side * 0.03, 0.178), (x + side * 0.026, 0.168), (x + side * 0.026, 0.176), (x - side * 0.03, 0.188)], -0.122, 0.012, FACE, 0.0015)
        tube(h, "Ear", [(side * 0.094, 0.15, 0.01), (side * 0.112, 0.15, 0.01)], 0.03, METAL, 14)
        tube(h, "Ear light", [(side * 0.111, 0.15, 0.01), (side * 0.114, 0.15, 0.01)], 0.012, CORE, 10)
    facing(h, "Mouth", [(-0.026, 0.094), (0.026, 0.094), (0.022, 0.088), (-0.022, 0.088)], -0.116, 0.01, LENS, 0.0)
    if hat:
        # A brimmed hat pulled low: the eyes glow from under it.
        upright(h, "Hat brim", [(0.236, 0.15, 0.16), (0.246, 0.15, 0.16), (0.25, 0.12, 0.13)], SATIN, 24, 0.0, 0.004, 2.0)
        upright(h, "Hat crown", [(0.24, 0.1, 0.11), (0.3, 0.096, 0.104), (0.33, 0.084, 0.09), (0.336, 0.05, 0.05)], SUIT, 20, 0.0, 0.004, 2.4)
        upright(h, "Hat band", [(0.25, 0.102, 0.112), (0.268, 0.1, 0.11)], SATIN, 20, 0.0, 0.004, 2.4)


def upper_arm(L, k):
    a = f"{L}_UpperArm_R"
    cloth_y(a, "Sleeve", [(0.07, 0.0, 0.0), (0.062, 0.04 * k, 0.044 * k), (0.036, 0.062 * k, 0.068 * k), (0.0, 0.068 * k, 0.072 * k), (-0.08, 0.066 * k, 0.07 * k), (-0.18, 0.06 * k, 0.064 * k), (-0.3, 0.055 * k, 0.058 * k), (-0.32, 0.054 * k, 0.057 * k)], SUIT, 18, 2.0)


def forearm(L, k):
    f = f"{L}_Forearm_R"
    joint(f, (0, 0, 0), 0.042 * k)
    cloth_y(f, "Sleeve", [(0.03, 0.058 * k, 0.06 * k), (-0.02, 0.06 * k, 0.062 * k), (-0.12, 0.054 * k, 0.056 * k), (-0.2, 0.049 * k, 0.051 * k), (-0.225, 0.048 * k, 0.05 * k)], SUIT, 18, 2.0)
    cloth_y(f, "Cuff", [(-0.21, 0.044 * k, 0.046 * k), (-0.248, 0.043 * k, 0.045 * k)], SHIRT, 16)
    turned(f, "Cufflink", [(-0.044 * k, 0.007), (-0.05 * k, 0.007), (-0.051 * k, 0.0)], METAL, 8, 0.0, -0.232)
    upright(f, "Wrist", [(-0.31, 0.022, 0.022), (-0.24, 0.026, 0.026)], METAL, 10)
    piston(f, (0.0, -0.2, 0.02), (0.0, -0.3, 0.012), 0.008)
    with at(0, -0.325, -0.02):
        hand(f, k)


def thigh(L, k):
    th = f"{L}_Thigh_R"
    cloth_y(th, "Trousers", [(0.08, 0.09 * k, 0.1 * k), (0.0, 0.1 * k, 0.108 * k), (-0.15, 0.092 * k, 0.098 * k), (-0.3, 0.078 * k, 0.084 * k), (-0.45, 0.066 * k, 0.072 * k), (-0.48, 0.064 * k, 0.07 * k)], SUIT, 18, 2.1)
    slab(th, "Crease", [(-0.1 * k, 0.04), (-0.098 * k, 0.04), (-0.071 * k, -0.46), (-0.073 * k, -0.46)], -0.003, 0.003, SATIN, 0.0)


def shin(L, k):
    s = f"{L}_Shin_R"
    joint(s, (0, 0, 0), 0.05 * k)
    cloth_y(s, "Trousers", [(0.05, 0.068 * k, 0.074 * k), (-0.05, 0.07 * k, 0.076 * k), (-0.2, 0.065 * k, 0.071 * k), (-0.34, 0.064 * k, 0.07 * k), (-0.385, 0.067 * k, 0.073 * k, 0.004)], SUIT, 18, 2.1)
    slab(s, "Crease", [(-0.076 * k, 0.04), (-0.074 * k, 0.04), (-0.07 * k, -0.38), (-0.072 * k, -0.38)], -0.003, 0.003, SATIN, 0.0)
    upright(s, "Ankle", [(-0.45, 0.026, 0.026), (-0.37, 0.03, 0.03)], METAL, 10)
    piston(s, (0.0, -0.36, 0.03), (0.0, -0.45, 0.02), 0.009)


def shoe(L, k):
    b = f"{L}_Boot_R"
    upright(b, "Ankle ball", [(-0.03, 0.0, 0.0), (-0.01, 0.028, 0.028), (0.02, 0.028, 0.028), (0.035, 0.0, 0.0)], METAL, 10)
    rings = []
    for z, w, top, bottom in ((0.075, 0.034, -0.02, -0.098), (0.05, 0.046, 0.006, -0.1), (0.0, 0.05, 0.012, -0.1), (-0.08, 0.05, -0.02, -0.1), (-0.15, 0.048, -0.05, -0.1), (-0.2, 0.04, -0.062, -0.1), (-0.226, 0.022, -0.072, -0.098)):
        w *= k
        rings.append([(w, bottom, z), (w * 1.04, (top + bottom) / 2, z), (w * 0.7, top, z), (-w * 0.7, top, z), (-w * 1.04, (top + bottom) / 2, z), (-w, bottom, z)])
    sculpt(b, "Shoe", rings, SHOE, (0, 5), level=2, bevel=0.0)
    rings = []
    for z, w in ((0.08, 0.036), (0.05, 0.05), (-0.02, 0.054), (-0.12, 0.054), (-0.2, 0.044), (-0.232, 0.024)):
        w *= k
        rings.append([(w, -0.108, z), (w, -0.096, z), (-w, -0.096, z), (-w, -0.108, z)])
    sculpt(b, "Sole", rings, SATIN, (0, 1, 2, 3), level=1, bevel=0.001)
    for i in range(3):
        z = -0.07 - i * 0.022
        tube(b, "Lace", [(-0.022 * k, -0.03 - i * 0.012, z), (0.022 * k, -0.03 - i * 0.012, z)], 0.003, SATIN, 4)


# ---------------------------------------------------------------- the liquidator's weapon arms

def cannon(part, along):
    """A laser cannon where a forearm should be. `along` maps (across, out, length) to the part's
    space, so the same arm is built for the body (down -Y) and for first person (forward -Z)."""
    def P(x, y, l):
        return along(x, y, l)
    tube(part, "Barrel housing", [P(0, 0, 0.0), P(0, 0, 0.36)], 0.07, GUN, 16)
    for l in (0.06, 0.14, 0.22, 0.3):
        tube(part, "Cooling fin", [P(0, 0, l), P(0, 0, l + 0.018)], 0.082, METAL, 16)
    for l in (0.1, 0.18, 0.26):
        tube(part, "Coil", [P(0, 0, l), P(0, 0, l + 0.012)], 0.073, CORE, 16)
    tube(part, "Barrel", [P(0, 0, 0.36), P(0, 0, 0.5)], 0.038, SHELL, 14)
    tube(part, "Muzzle ring", [P(0, 0, 0.47), P(0, 0, 0.51)], 0.046, METAL, 14)
    tube(part, "Bore", [P(0, 0, 0.505), P(0, 0, 0.512)], 0.026, CORE, 12)
    tube(part, "Top rail", [P(0, 0.075, 0.02), P(0, 0.075, 0.34)], 0.016, SHELL, 6)
    tube(part, "Sensor", [P(0.05, 0.06, 0.3), P(0.05, 0.06, 0.36)], 0.012, CORE, 8)
    tube(part, "Feed cable", [P(-0.06, 0.02, -0.02), P(-0.075, 0.02, 0.12), P(-0.07, 0.03, 0.3)], 0.012, CABLE, 6)


def pod(part, along, rounds_part=None):
    """Two rocket tubes side by side on a forearm, the warheads showing red at the front."""
    def P(x, y, l):
        return along(x, y, l)
    tube(part, "Pod mount", [P(0, 0, 0.0), P(0, 0, 0.3)], 0.062, GUN, 14)
    for x in (-0.048, 0.048):
        tube(part, "Tube", [P(x, 0.07, -0.02), P(x, 0.07, 0.4)], 0.046, GUN, 14)
        tube(part, "Tube lip", [P(x, 0.07, 0.38), P(x, 0.07, 0.42)], 0.052, METAL, 14)
        target = rounds_part or part
        tube(target, "Warhead", [P(x, 0.07, 0.36), P(x, 0.07, 0.4), P(x, 0.07, 0.43)], 0.032, WARN, 12)
        tube(target, "Warhead tip", [P(x, 0.07, 0.43), P(x, 0.07, 0.445)], 0.018, WARN, 10)
    tube(part, "Strap", [P(0, 0.0, 0.08), P(0, 0.0, 0.1)], 0.068, METAL, 14)
    tube(part, "Strap", [P(0, 0.0, 0.24), P(0, 0.0, 0.26)], 0.068, METAL, 14)
    tube(part, "Lock light", [P(0.0, 0.124, 0.3), P(0.0, 0.128, 0.3)], 0.01, CORE, 8)


def big_arms():
    """The body's forearms, pointing down the arm (-Y) from the elbow."""
    L, k = "Big", 1.12
    down = lambda x, y, l: (x, -l - 0.05, -y)
    for side, name, build in ((1, "Forearm_R", cannon), (-1, "Forearm_L", pod)):
        part = f"{L}_{name}"
        joint(part, (0, 0, 0), 0.05 * k)
        # The sleeve is torn off at the elbow, where the weapon is bolted on.
        cloth_y(part, "Sleeve stub", [(0.03, 0.06 * k, 0.062 * k), (-0.04, 0.064 * k, 0.066 * k), (-0.07, 0.068 * k, 0.07 * k)], SUIT, 18)
        build(part, down)


def first_person_arms():
    """The same weapons for the eye, forward along -Z with the grip at the origin. The forearm runs
    back under the camera, out of view."""
    ahead = lambda x, y, l: (x, y, -l + 0.12)
    cannon("FP_ArmCannon", ahead)
    pod("FP_ArmPod", ahead, "FP_ArmPod_Cell")
    for part in ("FP_ArmCannon", "FP_ArmPod"):
        tube(part, "Sleeve", [(0, 0, 0.12), (0, 0, 0.7)], 0.068, SUIT, 16)
        tube(part, "Cuff", [(0, 0, 0.1), (0, 0, 0.14)], 0.074, SHELL, 16)


# ---------------------------------------------------------------- first person and class fittings

def first_person():
    """The forearm as its owner sees it, one metre long so the game can scale it: a suit sleeve
    with the shirt cuff at the wrist."""
    part = "FP_Arm_D"
    tube(part, "Sleeve", [(0, 0.08, 0), (0, 1.0, 0)], 0.05, SUIT, 14)
    tube(part, "Cuff", [(0, 0.0, 0), (0, 0.1, 0)], 0.044, SHIRT, 14)
    tube(part, "Wrist", [(0, -0.04, 0), (0, 0.02, 0)], 0.024, METAL, 10)
    hand("FP_Glove_D")


def hunter_gear():
    """The auditor: a sensor mast on a slim pack, and an earpiece."""
    part = "Gear_hunter"
    block(part, "Sensor pack", [(0.2, 0.08, 0.035, 0.012, 0.165), (0.42, 0.09, 0.04, 0.012, 0.165)], SHELL)
    tube(part, "Mast", [(0.06, 0.42, 0.17), (0.08, 0.84, 0.2)], 0.007, METAL, 6)
    block(part, "Dish", [(0.82, 0.045, 0.014, 0.01, 0.2), (0.9, 0.062, 0.018, 0.012, 0.2)], SHELL, 0.002, 0.08)
    turned(part, "Dish light", [(0.205, 0.0), (0.21, 0.012)], CORE, 8, 0.08, 0.86)


def marshal_gear():
    """The director: two comms antennas on the shoulders and a black briefcase-shaped uplink."""
    part = "Gear_marshal"
    block(part, "Uplink", [(0.18, 0.11, 0.04, 0.014, 0.165), (0.44, 0.12, 0.045, 0.014, 0.17)], SHELL)
    for side, height in ((1, 1.1), (-1, 0.82)):
        tube(part, "Array", [(side * 0.09, 0.44, 0.17), (side * 0.12, height, 0.24)], 0.005, CABLE, 5)
        turned(part, "Array tip", [(0.24, 0.0), (0.245, 0.01), (0.25, 0.0)], CORE, 8, side * 0.12, height)


def marshal_head():
    part = "Gear_marshal_head"
    # A thin gold rim round the skull: the board's mark.
    upright(part, "Circlet", [(0.215, 0.103, 0.113), (0.228, 0.102, 0.112)], "Gold", 24, 0.0, 0.004, 2.2)


def servicer_gear():
    """The servicer: a repair unit on the back with two folded tool arms."""
    part = "Gear_servicer"
    block(part, "Repair unit", [(0.16, 0.11, 0.045, 0.016, 0.17), (0.44, 0.12, 0.05, 0.016, 0.17)], SHELL)
    for side in (1, -1):
        tube(part, "Tool arm", [(side * 0.1, 0.42, 0.2), (side * 0.18, 0.56, 0.16), (side * 0.2, 0.5, 0.02)], 0.012, METAL, 6)
        turned(part, "Tool tip", [(0.0, 0.0), (0.01, 0.016), (0.03, 0.006)], CORE, 8, side * 0.2, 0.5)


PALETTE["Gold"] = ((0.8, 0.56, 0.18), 0.95, 0.26, 0)
SIDES = ["UpperArm", "Forearm", "Thigh", "Shin", "Boot"]
NAMES = ["Pelvis", "Torso", "Head", "UpperArm_R", "Forearm_R", "Thigh_R", "Shin_R", "Boot_R"]
EXTRA = ["FP_Arm_D", "FP_Glove_D", "FP_ArmCannon", "FP_ArmPod", "FP_ArmPod_Cell", "Gear_hunter", "Gear_marshal", "Gear_marshal_head", "Gear_servicer", "Tie", "Tie_Big"]
POSE = {"Pelvis": (0, 0.95, 0), "Torso": (0, 1.03, 0), "Head": (0, 1.56, 0), "UpperArm_R": (0.28, 1.5, 0), "UpperArm_L": (-0.28, 1.5, 0), "Forearm_R": (0.28, 1.21, 0), "Forearm_L": (-0.28, 1.21, 0),
        "Thigh_R": (0.1, 0.9, 0), "Thigh_L": (-0.1, 0.9, 0), "Shin_R": (0.1, 0.45, 0), "Shin_L": (-0.1, 0.45, 0), "Boot_R": (0.1, 0.0, 0), "Boot_L": (-0.1, 0.0, 0)}


def build_frames():
    for L in FRAMES:
        k = 1.12 if L == "Big" else 1.0
        coat = L == "Cmd"
        pelvis(L, k, coat)
        torso(L, k, coat)
        head(L, L == "Cmd")
        upper_arm(L, k)
        if L != "Big":
            forearm(L, k)
        thigh(L, k)
        shin(L, k)
        shoe(L, k)
    big_arms()


def mirrored(obj, name):
    copy = obj.copy()
    copy.data = obj.data.copy()
    copy.name = name
    copy.data.name = name
    bpy.context.collection.objects.link(copy)
    bm = bmesh.new()
    bm.from_mesh(copy.data)
    bmesh.ops.scale(bm, vec=Vector((-1, 1, 1)), verts=bm.verts)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(copy.data)
    bm.free()
    return copy


def finish():
    root = bpy.data.objects.new("DroidParts", None)
    bpy.context.collection.objects.link(root)
    objs = {}
    tris = {}
    for label in FRAMES:
        total = 0
        names = NAMES + (["Forearm_L"] if label == "Big" else [])
        for name in names:
            key = f"{label}_{name}"
            obj = join(key)
            shade(obj, 32.0)
            bake_wear(obj, 0.07, 8, 1.0)
            objs[key] = obj
            total += sum(len(p.vertices) - 2 for p in obj.data.polygons) * (2 if name.endswith("_R") and not (label == "Big" and name == "Forearm_R") else 1)
        for side in SIDES:
            if label == "Big" and side == "Forearm":
                continue
            objs[f"{label}_{side}_L"] = mirrored(objs[f"{label}_{side}_R"], f"{label}_{side}_L")
        tris[label] = total
    for name in EXTRA:
        obj = join(name)
        shade(obj, 32.0)
        bake_wear(obj, 0.07, 8, 1.0)
        objs[name] = obj
    for obj in objs.values():
        obj.parent = root
    print("[droids] triangles", tris, flush=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in objs.values():
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / "droid_parts.glb"), export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_normals=True, export_materials="EXPORT", export_vertex_color="ACTIVE", export_all_vertex_colors=False,
        export_animations=False, export_cameras=False, export_lights=False,
    )
    return objs


def preview(folder, objs):
    ties = {"Reg": (0.1, 0.24, 0.72), "Big": (0.72, 0.05, 0.05), "Cmd": (0.36, 0.08, 0.5)}
    for i, label in enumerate(FRAMES):
        for name, pos in POSE.items():
            obj = objs[f"{label}_{name}"]
            obj.location = (pos[0] + (i - 1) * 1.5, -pos[2], pos[1])
        tie_obj = objs["Tie_Big" if label == "Big" else "Tie"].copy()
        tie_obj.data = tie_obj.data.copy()
        bpy.context.collection.objects.link(tie_obj)
        tie_obj.location = ((i - 1) * 1.5, 0, 1.03)
        mat = bpy.data.materials.new(f"tie_{label}")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*ties[label], 1)
        tie_obj.data.materials[0] = mat
    for name in EXTRA:
        objs[name].location = (9, 9, 0)
    objs["FP_ArmCannon"].location = (2.6, 0, 1.2)
    objs["FP_ArmPod"].location = (2.6, 0, 0.7)
    objs["FP_ArmPod_Cell"].location = (2.6, 0, 0.7)
    for m in bpy.data.materials:
        if m.name.startswith("_") or not m.use_nodes or m.name.startswith("tie_"):
            continue
        nodes = m.node_tree.nodes
        q = nodes["Principled BSDF"]
        attr = nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[6].default_value = q.inputs["Base Color"].default_value
        m.node_tree.links.new(attr.outputs[0], mix.inputs[7])
        m.node_tree.links.new(mix.outputs[2], q.inputs["Base Color"])
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1100, 800
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.34, 0.38, 0.46, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    scene.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.4
    s = bpy.data.objects.new("sun", sun)
    s.rotation_euler = (math.radians(55), math.radians(10), math.radians(25))
    bpy.context.collection.objects.link(s)
    cam = bpy.data.cameras.new("cam")
    cam.lens = 70
    c = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(c)
    scene.camera = c
    shots = [("front", (1.6, 7.6, 1.4), (0, 0, 0.95)), ("back", (-2.4, -7.4, 1.6), (0, 0, 0.95)), ("face", (0.2, 1.6, 1.62), (0, 0, 1.52)),
             ("bigface", (1.4, 1.8, 1.6), (1.5, 0, 1.4)), ("arms", (3.6, 2.4, 1.3), (2.6, 0, 0.95))]
    for label, pos, aim in shots:
        c.location = pos
        c.rotation_euler = (Vector(aim) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(Path(folder) / f"{label}.png")
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    build_frames()
    first_person()
    first_person_arms()
    hunter_gear()
    marshal_gear()
    marshal_head()
    servicer_gear()
    tie("Tie", 1.0)
    tie("Tie_Big", 1.12)
    objs = finish()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "droids.blend"))
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--preview" in args:
        preview(args[args.index("--preview") + 1], objs)
    print("[droids] done", flush=True)


main()
