"""Builds the infantry body for the game, as rigid parts that hang on the procedural skeleton.

Run:  blender --background --factory-startup --python tools/blender_trooper.py [-- --preview DIR]

Every part is modelled around its own joint, in Godot metres (+Y up, -Z forward). Sleeves and
trousers overlap at the joints and pads cover the elbows and knees, because a rigid body has to
hide what bends. Material names are the keys ModelAssets recolours for each side. Nobody shows a
face: both sides wear full helmets and masks.

Joints, from SoldierModel: pelvis .95 above the ground, torso .08 above that, head .53 above the
torso, shoulders at (+-.28, .47) on the torso, upper arm .29, forearm .28, hips at (+-.1, -.05)
on the pelvis, thigh .45, shin .45.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_kit import *  # noqa: E402,F403

OUT = ROOT / "assets/models/armory"
MAIN, DARK_CLOTH, PANTS, WEB, ARMOR, HELMET, RUBBER, LEATHER, METAL, VISOR, CORE = (
    "Cloth_Main", "Cloth_Dark", "Trouser", "Webbing", "ArmorPlate", "HelmetShell", "Rubber", "Leather", "Fitting", "Glass", "EnergyIndicator")
PALETTE.update({
    MAIN: ((0.09, 0.13, 0.2), 0, 0.9, 0), DARK_CLOTH: ((0.05, 0.08, 0.12), 0, 0.92, 0), PANTS: ((0.16, 0.15, 0.1), 0, 0.9, 0),
    WEB: ((0.13, 0.11, 0.07), 0, 0.86, 0), ARMOR: ((0.2, 0.22, 0.24), 0.1, 0.55, 0), HELMET: ((0.15, 0.2, 0.25), 0.1, 0.5, 0),
    RUBBER: ((0.015, 0.015, 0.016), 0, 0.84, 0), LEATHER: ((0.07, 0.045, 0.03), 0, 0.62, 0), METAL: ((0.3, 0.31, 0.33), 0.85, 0.4, 0),
    VISOR: ((0.02, 0.04, 0.06), 0.5, 0.08, 0), CORE: ((0.2, 0.6, 1.0), 0, 0.4, 3), "_Worn": ((1, 0, 1), 0, 1, 0),
    "MedicCloth": ((0.6, 0.6, 0.62), 0, 0.85, 0), "Camouflage": ((0.14, 0.16, 0.09), 0, 0.92, 0), "Canister": ((0.26, 0.24, 0.14), 0.4, 0.5, 0),
    "CommandMark": ((0.75, 0.75, 0.72), 0, 0.7, 0), "Hood": ((0.07, 0.065, 0.055), 0, 0.92, 0), "Armband": ((0.42, 0.04, 0.03), 0, 0.85, 0),
})


def catmull(a, b, c, d, t):
    return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t ** 3)


def interpolate(stations, step):
    """Smooths a list of stations, keeping the ends, at about `step` metres between rings."""
    out = []
    n = len(stations)
    for i in range(n - 1):
        p0, p1, p2, p3 = stations[max(i - 1, 0)], stations[i], stations[i + 1], stations[min(i + 2, n - 1)]
        count = max(int(abs(p2[0] - p1[0]) / step), 1)
        for k in range(count):
            t = k / count
            out.append(tuple(catmull(p0[j], p1[j], p2[j], p3[j], t) for j in range(len(p1))))
    out.append(tuple(stations[-1]))
    return out


def cloth(part, name, stations, mat, sides=20, step=0.022, folds=0.0055, seed=1.0, squash=2.3, bunch=(), caps=True):
    """A soft lofted volume with fabric folds. Stations: (y, rx, rz, cx, cz).
    `bunch` lists (y, width, strength): places the cloth gathers, such as behind a knee."""
    rings = []
    for y, rx, rz, cx, cz in interpolate(stations, step):
        gather = sum(s * math.exp(-((y - by) / w) ** 2) for by, w, s in bunch)
        ring = []
        for i in range(sides):
            a = math.tau * i / sides
            c, s = math.cos(a), math.sin(a)
            # Diagonal folds, stronger where the cloth gathers, weaker on the outside of a limb.
            wave = math.sin(y * 62 + a * 2 + seed) * 0.55 + math.sin(y * 113 - a * 3 + seed * 2.3) * 0.3 + math.sin(y * 31 + a + seed * 0.7) * 0.5
            # Added in metres, not as a ratio: on a flat drape a ratio would blow up the long side.
            grow = folds * (1 + gather * 2.4) * wave
            ring.append((cx + (rx + grow) * math.copysign(abs(c) ** (2 / squash), c), y, cz + (rz + grow) * math.copysign(abs(s) ** (2 / squash), s)))
        rings.append(ring)
    obj = add(part, name, [B(p) for r in rings for p in r], rings_to_faces(len(rings), sides, caps), mat)
    outward(obj)
    return obj


def ribbon(part, name, points, width, thick, mat, across=(0, 1, 0)):
    """A strap: a flat band following a line, with its width lying along `across`."""
    pts = [Vector(p) for p in points]
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = Vector(across) - d * Vector(across).dot(d)
        if side.length < 0.01:
            side = d.orthogonal()
        side.normalize()
        out = side.cross(d).normalized()
        rings.append([p + side * width / 2 + out * thick / 2, p - side * width / 2 + out * thick / 2, p - side * width / 2 - out * thick / 2, p + side * width / 2 - out * thick / 2])
    obj = add(part, name, [B(q) for r in rings for q in r], rings_to_faces(len(rings), 4), mat)
    outward(obj)
    return obj


def pouch(part, name, x, y, z, w, h, d, mat=WEB, flap=True, tilt=0.0):
    """A padded nylon pouch hanging on a vest, with a closing flap."""
    rings = []
    for k, (t, s) in enumerate(((0.0, 0.84), (0.1, 0.98), (0.55, 1.0), (0.9, 0.98), (1.0, 0.86))):
        yy = y - h / 2 + h * t
        ww, dd = w / 2 * s, d / 2 * s
        ring = []
        for i in range(10):
            a = math.tau * i / 10
            c, n = math.cos(a), math.sin(a)
            ring.append((x + ww * math.copysign(abs(c) ** 0.55, c), yy, z + dd * math.copysign(abs(n) ** 0.55, n) + tilt * (t - 0.5)))
        rings.append(ring)
    obj = add(part, name, [B(p) for r in rings for p in r], rings_to_faces(len(rings), 10), mat)
    outward(obj)
    if flap:
        pts = [(x - w * 0.5, y + h * 0.52, z - d * 0.5), (x + w * 0.5, y + h * 0.52, z - d * 0.5), (x + w * 0.5, y + h * 0.16, z - d * 0.56), (x - w * 0.5, y + h * 0.16, z - d * 0.56)]
        back = [(p[0], p[1] + 0.006, p[2] + 0.008) for p in pts]
        flap_obj = add(part, name + " flap", [B(p) for p in pts + back], [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], mat)
        outward(flap_obj)
        worn_chamfer(flap_obj, 0.003, 30.0)
        ribbon(part, name + " strap", [(x, y + h * 0.5, z - d * 0.57), (x, y + h * 0.12, z - d * 0.6)], 0.018, 0.003, RUBBER, (1, 0, 0))
    return obj


def hard(part, name, rings, mat, sharp=(), level=2, bevel=0.003):
    return sculpt(part, name, rings, mat, sharp, level=level, bevel=bevel)


def dome_ring(t, rx, rz, top, rim, cx=0.0, cz=0.0, sides=28, squash=2.2):
    """One ring of a helmet: `t` runs from the rim (0) to the crown (1). `rim(a)` is the rim height."""
    ring = []
    for i in range(sides):
        a = math.tau * i / sides
        c, s = math.cos(a), math.sin(a)
        low = rim(a)
        r = math.cos(t * math.pi / 2) ** 0.72
        y = low + (top - low) * math.sin(t * math.pi / 2)
        ring.append((cx + rx * r * math.copysign(abs(c) ** (2 / squash), c), y, cz + rz * r * math.copysign(abs(s) ** (2 / squash), s)))
    return ring


# ---------------------------------------------------------------- body

def pelvis():
    part = "Pelvis"
    cloth(part, "Hips", [(-0.17, 0.11, 0.1, 0, 0), (-0.13, 0.165, 0.118, 0, 0), (-0.04, 0.188, 0.128, 0, 0.004), (0.06, 0.172, 0.122, 0, 0), (0.115, 0.166, 0.118, 0, 0)], PANTS, 24, seed=2.0, bunch=((-0.1, 0.05, 1.0),))
    cloth(part, "Battle belt", [(0.055, 0.183, 0.133, 0, 0), (0.07, 0.189, 0.138, 0, 0), (0.115, 0.186, 0.136, 0, 0), (0.125, 0.178, 0.13, 0, 0)], WEB, 24, 0.012, 0.0005, squash=2.5)
    ribbon(part, "Inner belt", [(-0.19, 0.082, -0.09), (-0.06, 0.082, -0.141), (0.06, 0.082, -0.141), (0.19, 0.082, -0.09)], 0.03, 0.006, RUBBER)
    profile(part, "Buckle", [(-0.1475, 0.068), (-0.1395, 0.068), (-0.1395, 0.096), (-0.1475, 0.096)], 0.034, METAL, 0.0012)
    pouch(part, "Hip pouch", 0.195, 0.015, 0.03, 0.05, 0.13, 0.11)
    pouch(part, "Dump pouch", -0.19, 0.0, 0.06, 0.055, 0.15, 0.13, DARK_CLOTH)
    pouch(part, "Rear pouch", 0.0, 0.03, 0.15, 0.14, 0.09, 0.05)
    for side in (1, -1):
        ribbon(part, "Leg strap", [(side * 0.18, 0.05, -0.02), (side * 0.2, -0.1, -0.02)], 0.024, 0.004, WEB, (0, 0, 1))


def torso():
    part = "Torso"
    body_obj = cloth(part, "Shirt", [(-0.06, 0.158, 0.11, 0, 0), (0.05, 0.168, 0.118, 0, 0), (0.2, 0.196, 0.136, 0, -0.004), (0.32, 0.222, 0.14, 0, -0.004), (0.42, 0.225, 0.122, 0, 0.004), (0.5, 0.15, 0.095, 0, 0.012), (0.54, 0.075, 0.07, 0, 0.012), (0.6, 0.06, 0.062, 0, 0.012)], MAIN, 28, seed=3.1)
    # Plate carrier: a stiff shell around the chest, then the plate bags on top of it.
    vest = cloth(part, "Carrier", [(0.05, 0.178, 0.135, 0, -0.002), (0.08, 0.186, 0.142, 0, -0.002), (0.22, 0.208, 0.156, 0, -0.008), (0.33, 0.214, 0.158, 0, -0.008), (0.405, 0.19, 0.148, 0, -0.006), (0.425, 0.16, 0.135, 0, -0.004)], WEB, 28, 0.03, 0.0012, 1.2, 2.7)
    fbag = hard(part, "Front plate bag", [
        [(-0.135, 0.09, -0.14), (0.135, 0.09, -0.14), (0.15, 0.24, -0.15), (0.14, 0.34, -0.145), (0.075, 0.415, -0.128), (-0.075, 0.415, -0.128), (-0.14, 0.34, -0.145), (-0.15, 0.24, -0.15)],
        [(-0.125, 0.1, -0.175), (0.125, 0.1, -0.175), (0.14, 0.24, -0.186), (0.13, 0.33, -0.18), (0.07, 0.4, -0.158), (-0.07, 0.4, -0.158), (-0.13, 0.33, -0.18), (-0.14, 0.24, -0.186)],
    ], WEB, tuple(range(8)), level=1, bevel=0.004)
    hard(part, "Back plate bag", [
        [(-0.13, 0.09, 0.14), (0.13, 0.09, 0.14), (0.145, 0.26, 0.15), (0.13, 0.36, 0.14), (0.075, 0.43, 0.12), (-0.075, 0.43, 0.12), (-0.13, 0.36, 0.14), (-0.145, 0.26, 0.15)],
        [(-0.12, 0.1, 0.168), (0.12, 0.1, 0.168), (0.135, 0.26, 0.18), (0.12, 0.35, 0.17), (0.07, 0.415, 0.148), (-0.07, 0.415, 0.148), (-0.12, 0.35, 0.17), (-0.135, 0.26, 0.18)],
    ], WEB, tuple(range(8)), level=1, bevel=0.004)
    # Shoulder straps carry the plates over the top.
    for side in (1, -1):
        ribbon(part, "Shoulder strap", [(side * 0.092, 0.385, -0.135), (side * 0.118, 0.47, -0.08), (side * 0.128, 0.505, 0.0), (side * 0.118, 0.47, 0.08), (side * 0.092, 0.39, 0.13)], 0.056, 0.012, WEB, (1, 0, 0))
        ribbon(part, "Strap pad", [(side * 0.122, 0.482, -0.05), (side * 0.13, 0.512, 0.0), (side * 0.122, 0.482, 0.05)], 0.06, 0.016, DARK_CLOTH, (1, 0, 0))
        ribbon(part, "Side strap", [(side * 0.212, 0.2, -0.05), (side * 0.218, 0.2, 0.06)], 0.05, 0.008, WEB)
    # Webbing rows, then what hangs on them.
    for y in (0.13, 0.17, 0.21):
        ribbon(part, "Molle row", [(-0.13, y, -0.189), (0.13, y, -0.189)], 0.012, 0.0035, WEB)
    for i, x in enumerate((-0.094, 0.0, 0.094)):
        pouch(part, f"Magazine pouch {i}", x, 0.15, -0.212, 0.082, 0.14, 0.048)
    pouch(part, "Radio pouch", -0.095, 0.3, -0.204, 0.08, 0.1, 0.034)
    pouch(part, "Admin pouch", 0.082, 0.31, -0.2, 0.1, 0.08, 0.022, DARK_CLOTH)
    tube(part, "Antenna", [(-0.126, 0.34, -0.19), (-0.13, 0.46, -0.13), (-0.14, 0.56, -0.05)], 0.0035, RUBBER, 5)
    profile(part, "Status lamp", [(-0.22, 0.226), (-0.206, 0.226), (-0.206, 0.232), (-0.22, 0.232)], 0.014, CORE, 0, x=0.082)
    # Slim hydration carrier on the back, which leaves room for each class's own pack.
    pouch(part, "Hydration carrier", 0.0, 0.29, 0.2, 0.2, 0.24, 0.05, WEB, False)
    ribbon(part, "Drag handle", [(-0.05, 0.43, 0.13), (0.0, 0.452, 0.125), (0.05, 0.43, 0.13)], 0.022, 0.006, WEB)
    # A collar and neck gaiter close the gap under the helmet.
    cloth(part, "Gaiter", [(0.47, 0.098, 0.09, 0, 0.012), (0.53, 0.075, 0.075, 0, 0.012), (0.6, 0.066, 0.068, 0, 0.008), (0.63, 0.06, 0.062, 0, 0.008)], DARK_CLOTH, 18, 0.012, 0.004, 4.0)
    return body_obj


def upper_arm():
    part = "UpperArm_R"
    cloth(part, "Sleeve", [(0.07, 0.008, 0.008, 0, 0), (0.062, 0.036, 0.038, 0, 0), (0.042, 0.056, 0.058, 0, 0), (0.0, 0.068, 0.07, 0, 0), (-0.08, 0.066, 0.068, 0, 0), (-0.18, 0.058, 0.06, 0, 0), (-0.26, 0.052, 0.054, 0, 0), (-0.31, 0.05, 0.052, 0, 0)], MAIN, 20, folds=0.0028, seed=4.0, bunch=((-0.27, 0.05, 1.2),))
    hard(part, "Shoulder patch", [
        [(0.054, -0.03, -0.044), (0.074, -0.03, 0.0), (0.054, -0.03, 0.044), (0.04, -0.03, 0.0)],
        [(0.05, -0.13, -0.04), (0.068, -0.13, 0.0), (0.05, -0.13, 0.04), (0.038, -0.13, 0.0)],
    ], DARK_CLOTH, (0, 1, 2, 3), level=1, bevel=0.0)
    # The red band of the Rebellion, tied round each arm.
    cloth(part, "Armband", [(-0.13, 0.071, 0.073, 0, 0), (-0.09, 0.072, 0.074, 0, 0), (-0.05, 0.072, 0.074, 0, 0)], "Armband", 18, 0.012, 0.0014, 3.3)


def forearm():
    part = "Forearm_R"
    # An elbow pad over the joint, then the sleeve down to the glove cuff.
    cloth(part, "Sleeve", [(0.05, 0.058, 0.06, 0, 0), (-0.02, 0.06, 0.062, 0, 0), (-0.08, 0.058, 0.058, 0, 0), (-0.19, 0.043, 0.044, 0, 0), (-0.23, 0.037, 0.038, 0, 0)], MAIN, 20, folds=0.0034, seed=5.2, bunch=((0.0, 0.05, 1.0),))
    hard(part, "Elbow pad", [
        [(-0.046, 0.05, 0.036), (0.046, 0.05, 0.036), (0.05, 0.05, 0.0), (0.0, 0.05, -0.0), (-0.05, 0.05, 0.0)],
        [(-0.062, 0.005, 0.058), (0.062, 0.005, 0.058), (0.072, 0.005, 0.0), (0.0, 0.005, -0.012), (-0.072, 0.005, 0.0)],
        [(-0.05, -0.06, 0.054), (0.05, -0.06, 0.054), (0.062, -0.06, 0.0), (0.0, -0.06, -0.008), (-0.062, -0.06, 0.0)],
    ], ARMOR, (0, 1), level=1, bevel=0.002)
    ribbon(part, "Pad strap", [(-0.066, -0.05, 0.01), (-0.05, -0.05, -0.044), (0.0, -0.05, -0.066), (0.05, -0.05, -0.044), (0.066, -0.05, 0.01)], 0.018, 0.004, RUBBER)
    cloth(part, "Cuff", [(-0.195, 0.05, 0.052, 0, 0), (-0.205, 0.052, 0.054, 0, 0), (-0.27, 0.045, 0.047, 0, 0), (-0.29, 0.04, 0.042, 0, 0)], LEATHER, 16, 0.012, 0.0004)
    ribbon(part, "Wrist strap", [(-0.05, -0.24, -0.006), (-0.034, -0.24, -0.038), (0.0, -0.24, -0.054), (0.034, -0.24, -0.038), (0.05, -0.24, -0.006)], 0.016, 0.004, RUBBER)
    with at(0, -0.325, -0.02):
        fist(part, turn=False)


def fist(part, turn=True):
    """A gloved hand closed on a grip. Palm at the origin, fingers wrapping forward round +X."""
    y_sign = 1
    hard(part, "Palm", [
        [(-0.03, -0.05, 0.02), (0.03, -0.05, 0.02), (0.034, -0.05, -0.014), (-0.026, -0.05, -0.014)],
        [(-0.034, 0.0, 0.03), (0.034, 0.0, 0.03), (0.04, 0.0, -0.014), (-0.03, 0.0, -0.018)],
        [(-0.028, 0.05, 0.022), (0.03, 0.05, 0.022), (0.034, 0.05, -0.012), (-0.024, 0.05, -0.014)],
    ], LEATHER, (), level=2, bevel=0.0)
    for i in range(4):
        y = -0.033 + i * 0.022
        pts = [(0.03, y, 0.016), (0.044, y, -0.012), (0.036, y, -0.04), (0.012, y, -0.052), (-0.008, y, -0.04)]
        tube(part, "Finger", pts, 0.0105, LEATHER, 7)
        ribbon(part, "Knuckle pad", [(0.043, y, 0.004), (0.05, y, -0.014)], 0.017, 0.005, RUBBER)
    tube(part, "Thumb", [(-0.028, 0.03, 0.012), (-0.042, 0.04, -0.016), (-0.03, 0.046, -0.04), (-0.008, 0.046, -0.05)], 0.0118, LEATHER, 7)


def thigh():
    part = "Thigh_R"
    cloth(part, "Trouser", [(0.09, 0.09, 0.1, 0, 0), (0.02, 0.1, 0.108, 0, 0), (-0.12, 0.094, 0.102, 0, 0), (-0.28, 0.08, 0.086, 0, 0), (-0.4, 0.066, 0.072, 0, 0), (-0.47, 0.062, 0.068, 0, 0)], PANTS, 22, folds=0.0042, seed=6.5, bunch=((-0.42, 0.06, 1.3), (0.0, 0.05, 0.7)))
    pouch(part, "Cargo pocket", 0.098, -0.22, 0.0, 0.034, 0.17, 0.13, PANTS)
    ribbon(part, "Thigh strap", [(0.066, -0.08, -0.086), (0.098, -0.08, -0.05), (0.112, -0.08, 0.0), (0.098, -0.08, 0.05), (0.066, -0.08, 0.086)], 0.022, 0.004, WEB)


def shin():
    part = "Shin_R"
    limb = cloth(part, "Trouser", [(0.05, 0.066, 0.072, 0, 0), (-0.02, 0.07, 0.076, 0, 0.004), (-0.12, 0.066, 0.076, 0, 0.012), (-0.25, 0.056, 0.064, 0, 0.012), (-0.34, 0.05, 0.056, 0, 0.006), (-0.39, 0.046, 0.052, 0, 0.004)], PANTS, 20, folds=0.0042, seed=7.3, bunch=((0.0, 0.06, 1.2), (-0.36, 0.05, 1.5)))
    # Knee pad: the hard cup that also hides the joint from the front.
    hard(part, "Knee pad", [
        [(-0.058, 0.08, -0.05), (0.058, 0.08, -0.05), (0.07, 0.07, -0.0), (-0.07, 0.07, -0.0)],
        [(-0.072, 0.0, -0.088), (0.072, 0.0, -0.088), (0.085, 0.0, -0.0), (-0.085, 0.0, -0.0)],
        [(-0.066, -0.09, -0.086), (0.066, -0.09, -0.086), (0.076, -0.09, -0.01), (-0.076, -0.09, -0.01)],
    ], ARMOR, (0, 1), level=2, bevel=0.002)
    for y in (0.045, -0.06):
        ribbon(part, "Pad strap", [(-0.08, y, -0.02), (-0.06, y, 0.052), (0.0, y, 0.086), (0.06, y, 0.052), (0.08, y, -0.02)], 0.02, 0.004, RUBBER)
    return limb


def boot():
    part = "Boot_R"
    cloth(part, "Ankle", [(0.11, 0.054, 0.062, 0, 0.006), (0.04, 0.056, 0.064, 0, 0.006), (-0.01, 0.054, 0.066, 0, 0.002), (-0.04, 0.056, 0.08, 0, -0.012)], LEATHER, 18, 0.016, 0.0012, 8.1, 2.4)
    rings = []
    for z, w, top, bottom in ((0.082, 0.038, 0.0, -0.062), (0.05, 0.05, 0.03, -0.066), (0.0, 0.056, 0.04, -0.068), (-0.08, 0.055, 0.012, -0.068), (-0.15, 0.056, -0.012, -0.068), (-0.2, 0.05, -0.02, -0.066), (-0.222, 0.03, -0.03, -0.064)):
        rings.append([(w, bottom, z), (w * 1.06, (top + bottom) / 2, z), (w * 0.62, top, z), (-w * 0.62, top, z), (-w * 1.06, (top + bottom) / 2, z), (-w, bottom, z)])
    upper = sculpt(part, "Upper", rings, LEATHER, (0, 5), level=2, bevel=0.0)
    rings = []
    for z, w in ((0.088, 0.04), (0.06, 0.055), (-0.02, 0.06), (-0.12, 0.062), (-0.2, 0.054), (-0.232, 0.032)):
        rings.append([(w, -0.092, z), (w, -0.066, z), (-w, -0.066, z), (-w, -0.092, z)])
    sculpt(part, "Sole", rings, RUBBER, (0, 1, 2, 3), level=1, bevel=0.002)
    for z in (-0.19, -0.15, -0.11, -0.07, -0.03, 0.03, 0.065):
        profile(part, "Tread", [(z - 0.012, -0.102), (z + 0.012, -0.102), (z + 0.012, -0.09), (z - 0.012, -0.09)], 0.05, RUBBER, 0.001)
    # Toe cap and laces.
    hard(part, "Toe cap", [
        [(-0.058, -0.066, -0.17), (0.058, -0.066, -0.17), (0.052, -0.02, -0.164), (-0.052, -0.02, -0.164)],
        [(-0.034, -0.066, -0.226), (0.034, -0.066, -0.226), (0.03, -0.034, -0.226), (-0.03, -0.034, -0.226)],
    ], RUBBER, (), level=2, bevel=0.0)
    for i in range(7):
        y = 0.1 - i * 0.022
        z = -0.066 - i * 0.012 - max(0, i - 3) * 0.006
        ribbon(part, "Lace", [(-0.028, y, z), (0.028, y - 0.006, z)], 0.006, 0.003, RUBBER, (0, 0.5, -1))
    return upper


# ---------------------------------------------------------------- heads

def face_mask(part):
    """Balaclava and sealed mask: the wearer's own face never shows."""
    cloth(part, "Balaclava", [(-0.05, 0.062, 0.064, 0, 0.0), (0.0, 0.086, 0.09, 0, -0.002), (0.08, 0.104, 0.114, 0, 0.0), (0.16, 0.1, 0.112, 0, 0.0)], DARK_CLOTH, 20, 0.018, 0.0015, 9.0, 2.2)
    snout = 0.13
    hard(part, "Mask shell", [
        [(-0.078, 0.0, -0.056), (0.078, 0.0, -0.056), (0.09, 0.075, -0.05), (0.06, 0.112, -0.078), (-0.06, 0.112, -0.078), (-0.09, 0.075, -0.05)],
        [(-0.056, 0.0, -0.1), (0.056, 0.0, -0.1), (0.074, 0.07, -0.098), (0.05, 0.11, -0.104), (-0.05, 0.11, -0.104), (-0.074, 0.07, -0.098)],
        [(-0.03, 0.012, -snout), (0.03, 0.012, -snout), (0.04, 0.05, -snout - 0.006), (0.0, 0.07, -0.118), (-0.04, 0.05, -snout - 0.006)][:5] + [(-0.03, 0.012, -snout)],
    ], RUBBER, (), level=2, bevel=0.0)


def hood_shell(part, name, stations, mat, a0=328.0, a1=572.0, steps=22, thick=0.008, seed=1.0):
    """Cloth that wraps round the back and sides of the head and leaves the face open.
    Stations: (y, rx, rz, cz). The angles run round Y with -Z, the face, at 270 degrees."""
    outer, inner = [], []
    for y, rx, rz, cz in stations:
        o, i = [], []
        for k in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * k / steps)
            c, n = math.cos(a), math.sin(a)
            fold = 1.0 + 0.045 * math.sin(a * 5 + y * 40 + seed) * min(1.0, max(0.0, (0.22 - y) * 6))
            ex, ez = math.copysign(abs(c) ** (2 / 2.2), c), math.copysign(abs(n) ** (2 / 2.2), n)
            o.append((rx * fold * ex, y, cz + rz * fold * ez))
            i.append(((rx * fold - thick) * ex, y, cz + (rz * fold - thick) * ez))
        outer.append(o)
        inner.append(i)
    m = steps + 1
    rows = len(stations)
    verts = [B(p) for r in outer for p in r] + [B(p) for r in inner for p in r]
    base = rows * m
    faces = []
    for r in range(rows - 1):
        for k in range(m - 1):
            q = (r * m + k, r * m + k + 1, (r + 1) * m + k + 1, (r + 1) * m + k)
            faces.append(q)
            faces.append(tuple(base + v for v in reversed(q)))
        for k in (0, m - 1):
            faces.append((r * m + k, (r + 1) * m + k, base + (r + 1) * m + k, base + r * m + k))
    for r in (0, rows - 1):
        for k in range(m - 1):
            faces.append((r * m + k, base + r * m + k, base + r * m + k + 1, r * m + k + 1))
    obj = add(part, name, verts, faces, mat)
    outward(obj)
    return obj


def resistance_head():
    """The last humans: a deep hood, a respirator for the poisoned air, scavenged goggles."""
    part = "Head"
    face_mask(part)
    shell = hood_shell(part, "Hood", [
        (0.3, 0.02, 0.024, 0.01), (0.29, 0.07, 0.08, 0.012), (0.26, 0.112, 0.124, 0.012), (0.2, 0.134, 0.146, 0.016),
        (0.12, 0.138, 0.15, 0.02), (0.04, 0.13, 0.142, 0.03), (-0.03, 0.15, 0.15, 0.05), (-0.07, 0.19, 0.17, 0.07),
    ], "Hood", 332.0, 568.0, seed=0.6, thick=0.014)
    # Goggles: frame and two lenses behind a strap, the lenses lit faintly from the inside.
    hard(part, "Goggle frame", [
        [(-0.104, 0.086, -0.078), (0.104, 0.086, -0.078), (0.108, 0.136, -0.078), (-0.108, 0.136, -0.078)],
        [(-0.094, 0.09, -0.116), (0.094, 0.09, -0.116), (0.098, 0.132, -0.118), (-0.098, 0.132, -0.118)],
    ], RUBBER, (0, 1, 2, 3), level=1, bevel=0.002)
    for side in (1, -1):
        x = 0.046 * side
        hard(part, f"Lens {side}", [
            [(x - 0.04, 0.094, -0.116), (x + 0.04, 0.094, -0.116), (x + 0.04, 0.129, -0.118), (x - 0.04, 0.129, -0.118)],
            [(x - 0.034, 0.098, -0.122), (x + 0.034, 0.098, -0.122), (x + 0.034, 0.125, -0.124), (x - 0.034, 0.125, -0.124)],
        ], VISOR, (0, 1, 2, 3), level=0, bevel=0.0)
    profile(part, "Lens glow", [(-0.1245, 0.106), (-0.1205, 0.106), (-0.1205, 0.109), (-0.1245, 0.109)], 0.03, CORE, 0, x=0.0)
    # Respirator cans either side of the mask, the way people breathe in a city the machines run.
    for side in (1, -1):
        turned(part, f"Filter {side}", [(-0.112, 0.0), (-0.114, 0.026), (-0.15, 0.028), (-0.156, 0.024), (-0.158, 0.0)], "Canister", 14, side * 0.062, 0.02)
        turned(part, f"Filter grille {side}", [(-0.157, 0.02), (-0.161, 0.02), (-0.162, 0.0)], RUBBER, 12, side * 0.062, 0.02)
    # A scarf wound round the neck, the end of it tucked under the hood.
    cloth(part, "Scarf", [(-0.06, 0.1, 0.098, 0, 0.008), (-0.02, 0.098, 0.1, 0, 0.0), (0.03, 0.086, 0.092, 0, -0.004)], "Armband", 20, 0.012, 0.004, 2.2)
    return shell


# ---------------------------------------------------------------- class gear

def pack(part, name, y, z, w, h, d, mat, flap=True):
    """A soft backpack seen from behind: `flap` puts a closing lid on top."""
    rings = []
    for t, k in ((0.0, 0.8), (0.08, 0.95), (0.5, 1.0), (0.9, 0.96), (1.0, 0.82)):
        yy = y - h / 2 + h * t
        ring = []
        for i in range(14):
            a = math.tau * i / 14
            c, n = math.cos(a), math.sin(a)
            ring.append((w / 2 * k * math.copysign(abs(c) ** 0.6, c), yy, z + d / 2 * k * math.copysign(abs(n) ** 0.6, n)))
        rings.append(ring)
    obj = add(part, name, [B(p) for r in rings for p in r], rings_to_faces(len(rings), 14), mat)
    outward(obj)
    if flap:
        top = [(-w * 0.5, y + h * 0.5, z - d * 0.42), (w * 0.5, y + h * 0.5, z - d * 0.42), (w * 0.52, y + h * 0.5, z + d * 0.42), (-w * 0.52, y + h * 0.5, z + d * 0.42)]
        low = [(-w * 0.5, y + h * 0.16, z + d * 0.56), (w * 0.5, y + h * 0.16, z + d * 0.56)]
        lid = add(part, name + " lid", [B(p) for p in top + low], [(0, 1, 2, 3), (3, 2, 5, 4)], WEB if mat != WEB else DARK_CLOTH)
        outward(lid)
    for side in (1, -1):
        ribbon(part, "Compression strap", [(side * w * 0.3, y + h * 0.3, z + d * 0.52), (side * w * 0.3, y - h * 0.3, z + d * 0.52)], 0.022, 0.004, RUBBER, (1, 0, 0))
    return obj


def bottle(part, name, x, y, z, height, r, mat=METAL, cap=METAL):
    upright(part, name, [(y - height / 2, r * 0.7, r * 0.7), (y - height / 2 + 0.02, r, r), (y + height / 2 - 0.05, r, r), (y + height / 2 - 0.012, r * 0.72, r * 0.72), (y + height / 2, r * 0.3, r * 0.3)], mat, 14, x, z)
    upright(part, name + " valve", [(y + height / 2, r * 0.3, r * 0.3), (y + height / 2 + 0.03, r * 0.3, r * 0.3), (y + height / 2 + 0.036, r * 0.44, r * 0.44), (y + height / 2 + 0.05, r * 0.44, r * 0.44)], cap, 10, x, z)
    for t in (0.26, 0.74):
        yy = y - height / 2 + height * t
        upright(part, name + " strap", [(yy - 0.012, r * 1.05, r * 1.05), (yy + 0.012, r * 1.05, r * 1.05)], RUBBER, 14, x, z)


def medic():
    part = "Gear_medic"
    pack(part, "Aid pack", 0.3, 0.27, 0.34, 0.44, 0.15, "MedicCloth")
    pouch(part, "Side pouch", 0.2, 0.22, 0.26, 0.05, 0.2, 0.1, "MedicCloth")
    pouch(part, "Side pouch", -0.2, 0.22, 0.26, 0.05, 0.2, 0.1, "MedicCloth")


def cloak(part, length, mat, hood=True):
    """A long drape from the shoulders, and its hood lying back on the neck."""
    cloth(part, "Cloak", [
        (0.53, 0.14, 0.03, 0, 0.09), (0.48, 0.24, 0.05, 0, 0.13), (0.3, 0.27, 0.05, 0, 0.21), (0.05, 0.28, 0.05, 0, 0.22), (0.5 - length * 0.6, 0.285, 0.045, 0, 0.23), (0.5 - length, 0.29, 0.03, 0, 0.24),
    ], mat, 26, 0.03, 0.014, 3.3, 2.6)
    if hood:
        cloth(part, "Hood", [(0.48, 0.11, 0.05, 0, 0.13), (0.56, 0.14, 0.09, 0, 0.13), (0.62, 0.115, 0.08, 0, 0.13), (0.66, 0.05, 0.04, 0, 0.14)], mat, 18, 0.02, 0.006, 4.8, 2.3)


def sniper_gear():
    part = "Gear_sniper"
    cloak(part, 0.86, "Camouflage")
    pack(part, "Drag bag", 0.2, 0.3, 0.16, 0.5, 0.08, "Camouflage", False)


def engineer():
    part = "Gear_engineer"
    pack(part, "Tool pack", 0.26, 0.31, 0.42, 0.5, 0.18, WEB)
    pouch(part, "Tool roll", 0.0, 0.54, 0.31, 0.42, 0.07, 0.07, DARK_CLOTH, False)
    for side in (1, -1):
        bottle(part, f"Gas bottle {side}", side * 0.275, 0.22, 0.3, 0.46, 0.04, "Canister", METAL)
    tube(part, "Hose", [(0.275, 0.5, 0.3), (0.2, 0.58, 0.26), (0.12, 0.54, 0.16), (0.2, 0.34, 0.14)], 0.008, RUBBER, 6)


def jump_pack():
    part = "Gear_maccabee"
    hard(part, "Spine", [
        [(-0.09, 0.08, 0.22), (0.09, 0.08, 0.22), (0.09, 0.08, 0.3), (-0.09, 0.08, 0.3)],
        [(-0.11, 0.3, 0.22), (0.11, 0.3, 0.22), (0.11, 0.3, 0.33), (-0.11, 0.3, 0.33)],
        [(-0.08, 0.54, 0.22), (0.08, 0.54, 0.22), (0.08, 0.54, 0.29), (-0.08, 0.54, 0.29)],
    ], ARMOR, (0, 1, 2, 3), level=2, bevel=0.004)
    for side in (1, -1):
        upright(part, f"Engine {side}", [(0.6, 0.0, 0.0), (0.585, 0.05, 0.05), (0.54, 0.082, 0.082), (0.1, 0.086, 0.086), (0.04, 0.076, 0.076)], ARMOR, 16, side * 0.155, 0.3, 2.0, 0.003)
        upright(part, f"Nozzle {side}", [(0.05, 0.05, 0.05), (0.0, 0.056, 0.056), (-0.07, 0.08, 0.08), (-0.075, 0.074, 0.074), (-0.02, 0.04, 0.04)], METAL, 16, side * 0.155, 0.3)
        for y in (0.2, 0.42):
            upright(part, f"Band {side}", [(y - 0.012, 0.089, 0.089), (y + 0.012, 0.089, 0.089)], RUBBER, 16, side * 0.155, 0.3)


def commander():
    """A radio on the back, its aerial above everyone else's head, and the leader's marks."""
    part = "Gear_leader"
    pack(part, "Radio case", 0.28, 0.27, 0.3, 0.34, 0.13, DARK_CLOTH, False)
    hard(part, "Radio face", [
        [(-0.12, 0.2, 0.335), (0.12, 0.2, 0.335), (0.12, 0.38, 0.335), (-0.12, 0.38, 0.335)],
        [(-0.11, 0.21, 0.35), (0.11, 0.21, 0.35), (0.11, 0.37, 0.35), (-0.11, 0.37, 0.35)],
    ], ARMOR, (0, 1, 2, 3), level=0, bevel=0.003)
    for i, x in enumerate((-0.06, -0.02, 0.02)):
        turned(part, f"Dial {i}", [(0.35, 0.012), (0.362, 0.012), (0.364, 0.0)], METAL, 8, x, 0.33)
    profile(part, "Radio lamp", [(0.351, 0.24), (0.353, 0.24), (0.353, 0.262), (0.351, 0.262)], 0.05, CORE, 0, x=0.04)
    tube(part, "Whip aerial", [(0.11, 0.46, 0.3), (0.13, 0.9, 0.34), (0.15, 1.3, 0.4)], 0.0055, RUBBER, 5)
    upright(part, "Aerial base", [(0.44, 0.02, 0.02), (0.5, 0.012, 0.012)], METAL, 8, 0.11, 0.3)
    tube(part, "Short aerial", [(-0.11, 0.46, 0.3), (-0.12, 0.7, 0.33)], 0.0045, RUBBER, 5)
    tube(part, "Handset cord", [(-0.12, 0.42, 0.25), (-0.17, 0.46, 0.08), (-0.14, 0.42, -0.13), (-0.11, 0.38, -0.215)], 0.005, RUBBER, 5)
    pouch(part, "Handset", -0.1, 0.34, -0.232, 0.044, 0.09, 0.03, RUBBER, False)
    # Binocular case and a map board on the chest.
    pouch(part, "Binocular case", 0.09, 0.325, -0.222, 0.12, 0.085, 0.06, LEATHER)
    pouch(part, "Map case", -0.222, 0.1, 0.0, 0.03, 0.15, 0.12, LEATHER)
    # Shoulder boards: three bars each, the rank marks of the leader.
    for side in (1, -1):
        hard(part, f"Shoulder board {side}", [
            [(side * 0.1, 0.515, -0.04), (side * 0.2, 0.47, -0.04), (side * 0.2, 0.484, -0.04), (side * 0.1, 0.53, -0.04)],
            [(side * 0.1, 0.515, 0.04), (side * 0.2, 0.47, 0.04), (side * 0.2, 0.484, 0.04), (side * 0.1, 0.53, 0.04)],
        ], "CommandMark", (0, 1, 2, 3), level=0, bevel=0.002)


def commander_head():
    """Marks on the helmet, and a sight arm over one eye. Fits on both sides' helmets."""
    part = "Gear_leader_head"
    ribbon(part, "Command stripe", [(0.0, 0.12, -0.15), (0.0, 0.22, -0.11), (0.0, 0.272, -0.02), (0.0, 0.262, 0.08), (0.0, 0.17, 0.155)], 0.034, 0.006, "CommandMark", (1, 0, 0))
    tube(part, "Sight arm", [(0.12, 0.17, -0.02), (0.135, 0.175, -0.1), (0.075, 0.156, -0.158)], 0.006, METAL, 6)
    hard(part, "Sight", [
        [(0.05, 0.14, -0.152), (0.1, 0.14, -0.152), (0.1, 0.17, -0.152), (0.05, 0.17, -0.152)],
        [(0.056, 0.146, -0.176), (0.094, 0.146, -0.176), (0.094, 0.165, -0.176), (0.056, 0.165, -0.176)],
    ], RUBBER, (0, 1, 2, 3), level=0, bevel=0.002)
    tube(part, "Helmet aerial", [(-0.11, 0.2, 0.08), (-0.14, 0.42, 0.16)], 0.0035, RUBBER, 5)


GEAR = [medic, sniper_gear, engineer, jump_pack, commander, commander_head]


# ---------------------------------------------------------------- first person

def first_person():
    """The forearm a player sees, one metre long so the game can scale it from hand to elbow."""
    part = "FP_Arm"
    rings = []
    for y, r, in ((0.1, 0.036), (0.16, 0.043), (0.24, 0.047), (0.45, 0.052), (0.7, 0.055), (1.0, 0.058)):
        rings.append((y, r, r * 1.04, 0, 0))
    cloth(part, "Sleeve", rings, MAIN, 18, 0.03, 0.0026, 2.4)
    cloth(part, "Cuff", [(-0.05, 0.038, 0.039, 0, 0), (0.0, 0.043, 0.044, 0, 0), (0.1, 0.048, 0.05, 0, 0), (0.14, 0.052, 0.054, 0, 0), (0.15, 0.05, 0.052, 0, 0)], LEATHER, 16, 0.02, 0.0004)
    ribbon(part, "Wrist strap", [(-0.05, 0.05, -0.004), (-0.034, 0.05, -0.036), (0.0, 0.05, -0.052), (0.034, 0.05, -0.036), (0.05, 0.05, -0.004)], 0.022, 0.004, RUBBER)
    fist("FP_Glove")


PIVOTLESS = ["Pelvis", "Torso", "Head", "UpperArm_R", "Forearm_R", "Thigh_R", "Shin_R", "Boot_R", "FP_Arm", "FP_Glove",
             "Gear_medic", "Gear_sniper", "Gear_engineer", "Gear_maccabee", "Gear_leader", "Gear_leader_head"]
MIRROR = {"UpperArm_R": "UpperArm_L", "Forearm_R": "Forearm_L", "Thigh_R": "Thigh_L", "Shin_R": "Shin_L", "Boot_R": "Boot_L"}
POSE = {
    "Pelvis": (0, 0.95, 0), "Torso": (0, 1.03, 0), "Head": (0, 1.56, 0),
    "UpperArm_R": (0.28, 1.5, 0), "UpperArm_L": (-0.28, 1.5, 0), "Forearm_R": (0.28, 1.21, 0), "Forearm_L": (-0.28, 1.21, 0),
    "Thigh_R": (0.1, 0.9, 0), "Thigh_L": (-0.1, 0.9, 0), "Shin_R": (0.1, 0.45, 0), "Shin_L": (-0.1, 0.45, 0),
    "Boot_R": (0.1, 0.0, 0), "Boot_L": (-0.1, 0.0, 0), "FP_Arm": (2.4, 1.0, 3.0), "FP_Glove": (2.4, 0.9, 3.0),
    "Gear_medic": (-1.6, 1.03, 0), "Gear_sniper": (-3.0, 1.03, 0),
    "Gear_leader": (0, 1.03, 0), "Gear_leader_head": (0, 1.56, 0), "Gear_engineer": (-8.6, 1.03, 0), "Gear_maccabee": (-11.4, 1.03, 0),
}


def mirrored_copy(obj, name):
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
    root = bpy.data.objects.new("TrooperParts", None)
    bpy.context.collection.objects.link(root)
    objs = {}
    tris = {}
    for name in PIVOTLESS:
        obj = join(name)
        shade(obj, 40.0)
        bake_wear(obj, 0.14, 10, 0.8)
        objs[name] = obj
        tris[name] = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    for right, left in MIRROR.items():
        objs[left] = mirrored_copy(objs[right], left)
    for obj in objs.values():
        obj.parent = root
    print("[trooper] triangles", tris, flush=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in objs.values():
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / "trooper_parts.glb"), export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_normals=True, export_materials="EXPORT", export_vertex_color="ACTIVE", export_all_vertex_colors=False,
        export_animations=False, export_cameras=False, export_lights=False,
    )
    return objs


def preview(folder, objs):
    for name, obj in objs.items():
        p = POSE[name]
        obj.location = (p[0], -p[2], p[1])
    for m in bpy.data.materials:
        if m.name.startswith("_"):
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
    scene.render.resolution_x, scene.render.resolution_y = 640, 900
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.64, 0.7, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.0
    s = bpy.data.objects.new("sun", sun)
    s.rotation_euler = (math.radians(55), math.radians(10), math.radians(25))
    bpy.context.collection.objects.link(s)
    cam = bpy.data.cameras.new("cam")
    cam.lens = 85
    c = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(c)
    scene.camera = c
    for label, pos, aim in [
        ("front", (1.6, 6.2, 1.3), (0, 0, 0.92)), ("back", (-2.4, -6.0, 1.5), (0, 0, 0.92)), ("side", (6.4, 0.2, 1.1), (0, 0, 0.92)),
        ("head", (0.7, 2.1, 1.85), (0, 0, 1.66)), ("hand", (2.95, -2.1, 1.5), (2.4, -3.0, 1.0)),
    ]:
        c.location = pos
        c.rotation_euler = (Vector(aim) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(Path(folder) / f"{label}.png")
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    pelvis()
    torso()
    upper_arm()
    forearm()
    thigh()
    shin()
    boot()
    resistance_head()
    first_person()
    for build in GEAR:
        build()
    objs = finish()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "trooper.blend"))
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--preview" in args:
        preview(args[args.index("--preview") + 1], objs)
    print("[trooper] done", flush=True)


main()
