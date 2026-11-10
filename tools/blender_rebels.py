"""Builds the Rebellion for Corp Wars: the last people, armed with what the machines threw away.

Run:  blender --background --factory-startup --python tools/blender_rebels.py [-- --preview DIR]

The look: nobody issues these people anything. Field jackets with the sleeves shoved up, patched
trousers bound at the shin with rags, boots resoled twice, a chest rig sewn from webbing, a red
band tied round the arm. Skin shows at the forearms and round the eyes, because the point of them
is that they are human. Every class adds what its trade has scavenged: a medic's satchel, a
marksman's ragged cape, a welder's apron and bottle, the heavy gunner's armour of cut steel plate.

One body serves every class: the game stretches its skeleton to make a slight scout or a broad
gunner, and paints the skin in each class's own tone. Heads and gear are meshes of their own on
the same bones.

  rebel.glb      Body_Reb, Head_<class>, Gear_<class>
  rebel_fp.glb   the forearm and hand as their owner sees them
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_char import *  # noqa: E402,F403

(SKIN, EYEWHITE, DARK, HAIR, JACKET, HOOD, CANVAS, PANTS, PATCH, LEATHER, BOOT, WEB, SCRAP, RUST, STEEL, RED, WRAP, RUBBER, LENS, LAMP, CROSS, MEDIC,
 DRAB, GREY, BRASS) = (
    "Skin", "EyeWhite", "Dark", "Hair", "Jacket", "Hood", "Canvas", "Pants", "Patch", "Leather", "Boot", "Web", "Scrap", "Rust", "Steel", "Red", "Wrap",
    "Rubber", "Lens", "Lamp", "Cross", "Medic", "Drab", "Grey", "Brass")
PALETTE.update({
    SKIN: ((0.9, 0.9, 0.9), "skin"), EYEWHITE: ((0.55, 0.53, 0.5), "cloth"), DARK: ((0.012, 0.01, 0.01), "rubber"), HAIR: ((0.022, 0.016, 0.012), "cloth"),
    JACKET: ((0.085, 0.095, 0.055), "cloth"), HOOD: ((0.04, 0.038, 0.034), "cloth"), CANVAS: ((0.24, 0.2, 0.13), "cloth"), PANTS: ((0.065, 0.055, 0.045), "cloth"),
    PATCH: ((0.12, 0.1, 0.075), "cloth"), LEATHER: ((0.1, 0.055, 0.028), "leather"), BOOT: ((0.022, 0.018, 0.015), "leather"), WEB: ((0.055, 0.05, 0.034), "cloth"),
    SCRAP: ((0.16, 0.15, 0.14), "paint"), RUST: ((0.2, 0.075, 0.03), "paint"), STEEL: ((0.34, 0.34, 0.36), "metal"), RED: ((0.42, 0.035, 0.025), "cloth"),
    WRAP: ((0.4, 0.36, 0.28), "cloth"), RUBBER: ((0.014, 0.014, 0.015), "rubber"), LENS: ((0.02, 0.03, 0.035), "glass"), LAMP: ((0.3, 0.68, 1.0), "glow"),
    CROSS: ((0.1, 1.0, 0.3), "lamp"), MEDIC: ((0.5, 0.5, 0.47), "cloth"), DRAB: ((0.06, 0.065, 0.035), "cloth"), GREY: ((0.09, 0.09, 0.095), "cloth"),
    BRASS: ((0.5, 0.36, 0.12), "metal"),
})
SX = 0.19
HEAD = (0, 1.56, 0)


def tag(side):
    return "R" if side > 0 else "L"


def worn(p, key):
    """Nothing here is new: cloth is blotched and faded, steel has rusted, and the dirt of the
    street has climbed the legs."""
    blotch = math.sin(p.x * 37.0 + p.y * 23.0) * math.sin(p.z * 41.0 - p.y * 17.0) * 0.6 + math.sin(p.x * 91.0 + p.z * 73.0 + p.y * 57.0) * 0.3
    if key in (SKIN, EYEWHITE, LENS, STEEL, BRASS):
        return 1.0
    if key == SCRAP:
        rust = smooth(0.15, 0.55, blotch)
        return (1.0 + 0.5 * rust, 1.0 - 0.45 * rust, 1.0 - 0.72 * rust)
    dirt = 1.0 - 0.32 * smooth(0.5, 0.02, p.y)
    return (1.0 + 0.16 * blotch) * dirt


# ---------------------------------------------------------------- the body every class shares

def leg(body, side):
    with bound("leg_r" if side > 0 else "leg_l"):
        f = Form([(1.0, 0.082, 0.1), (0.9, 0.096, 0.11, 0.004, 0), (0.78, 0.092, 0.105, 0.002, 0), (0.62, 0.082, 0.093), (0.5, 0.073, 0.084),
                  (0.45, 0.071, 0.082, 0, -0.004), (0.4, 0.069, 0.08), (0.3, 0.068, 0.08, 0, 0.004), (0.24, 0.07, 0.082, 0, 0.004), (0.185, 0.054, 0.064, 0, 0.004)],
                 2.2, origin=(side * 0.1, 0, 0), side=side, folds=0.0045, seed=3.0 + side, bunch=((0.45, 0.06, 1.0), (0.25, 0.04, 1.2)))
        f.mesh(body, "Trouser", PANTS, 16, 0.04)
        # A cargo pocket on the thigh, and a patch sewn over one knee.
        f.pad(body, "Cargo pocket", PANTS, 8.0, 0.64, 0.11, 0.13, 0.016, 0.0, 0.3, 3, 3)
        if fine(1):
            a0, a1 = f.span(8.0, 0.7, 0.112)
            f.shell(body, "Pocket flap", PATCH, a0, a1, 0.675, 0.712, 0.005, 0.014, 2, 1)
        if side < 0:
            f.shell(body, "Knee patch", PATCH, 222.0, 318.0, 0.385, 0.5, 0.004, 0.0, 4, 3)
        # Rags bound round the shin keep the trouser out of the boot's way.
        if fine(1):
            f.strap(body, "Shin wrap", WRAP, [(40.0 + 140.0 * i, 0.345 - 0.03 * i) for i in range(6)], 0.036, 0.004, 0.001, 0.04)
        else:
            f.band(body, "Shin wrap", WRAP, 0.2, 0.34, 0.003, 0.0, 16)
        # The boot's shaft, laced up the front.
        shaft = Form([(0.215, 0.058, 0.068, 0, 0.004), (0.13, 0.054, 0.064, 0, 0.002), (0.06, 0.052, 0.07, 0, -0.01)], 2.2, origin=(side * 0.1, 0, 0), side=side)
        shaft.mesh(body, "Boot shaft", BOOT, 12, 0.05)
        if fine(0):
            for i in range(4):
                y = 0.19 - i * 0.03
                shaft.strap(body, "Lace", WRAP, [(250, y), (270, y - 0.006), (290, y)], 0.005, 0.003, 0.0, 0.02)
    with bound(f"Boot_{tag(side)}"):
        f = Form([(0.086, 0.03, 0.036, 0, 0.056), (0.06, 0.046, 0.046, 0, 0.066), (0.02, 0.052, 0.05, 0, 0.07), (-0.05, 0.054, 0.04, 0, 0.06),
                  (-0.12, 0.056, 0.033, 0, 0.053), (-0.18, 0.052, 0.03, 0, 0.05), (-0.215, 0.04, 0.026, 0, 0.046), (-0.238, 0.016, 0.014, 0, 0.04)],
                 (3.0, 2.0), axis="z", origin=(side * 0.1, 0, 0), side=side)
        f.mesh(body, "Boot", BOOT, 12, 0.035)
        with at(side * 0.1, 0, 0):
            plan = [(0.034, 0.094), (0.05, 0.06), (0.057, -0.02), (0.06, -0.11), (0.056, -0.18), (0.042, -0.228), (0.016, -0.248)]
            plan = plan + [(-x, z) for x, z in reversed(plan)]
            slab(body, "Sole", plan, 0.0, 0.024, RUBBER, 0.0, "xz")
        if fine(1):
            f.shell(body, "Toe cap", RUBBER, 12.0, 168.0, -0.236, -0.17, 0.004, 0.0, 4, 2)


def trunk_form():
    return Form([(0.86, 0.172, 0.124), (0.93, 0.17, 0.122), (1.0, 0.16, 0.114), (1.08, 0.158, 0.112), (1.2, 0.168, 0.119, 0, -0.003), (1.32, 0.182, 0.127, 0, -0.006),
                 (1.42, 0.19, 0.125, 0, -0.004), (1.48, 0.191, 0.117), (1.525, 0.184, 0.105, 0, 0.002), (1.553, 0.162, 0.094, 0, 0.004),
                 (1.575, 0.112, 0.08, 0, 0.006), (1.595, 0.07, 0.067, 0, 0.008), (1.606, 0.058, 0.06, 0, 0.008)], (2.4, 2.3), folds=0.004, seed=1.7, bunch=((1.04, 0.05, 1.0),))


def trunk(body):
    with bound("torso"):
        seat = Form([(0.8, 0.105, 0.09), (0.84, 0.166, 0.116), (0.92, 0.17, 0.12), (1.02, 0.158, 0.11)], 2.3, folds=0.003, seed=5.0)
        seat.mesh(body, "Seat", PANTS, 14, 0.06)
        j = trunk_form()
        j.mesh(body, "Jacket", JACKET, 24, 0.04)
        if fine(1):
            # The jacket hangs open a hand's width at the throat, a dark shirt under it.
            with unshaded():
                j.patch(body, "Shirt", HOOD, [(0.0, 1.4), (0.05, 1.585), (-0.05, 1.585)], "front", 0.002, 0.0, 0.03, 0.0)
            j.strap(body, "Front placket", PATCH, [(271.0, 1.39), (271.0, 1.1), (271.0, 0.87)], 0.022, 0.003, 0.0, 0.06)
            j.shell(body, "Hem patch", PATCH, 300.0, 345.0, 0.875, 0.965, 0.004, 0.0, 3, 2)
        # A belt worn over the jacket, hung with what there is to hang on it.
        j.band(body, "Belt", LEATHER, 0.985, 1.03, 0.006, 0.0, 24)
        if fine(1):
            j.patch(body, "Buckle", SCRAP, [(-0.024, 1.036), (0.024, 1.036), (0.024, 0.98), (-0.024, 0.98)], "front", 0.004, 0.006, 0.04, 0.003)
        j.pad(body, "Belt pouch", WEB, 322.0, 0.97, 0.075, 0.09, 0.03, 0.004, 0.3, 3, 3)
        j.pad(body, "Belt pouch", CANVAS, 30.0, 0.965, 0.085, 0.1, 0.034, 0.004, 0.3, 3, 3)
        j.pad(body, "Canteen", DRAB, 148.0, 0.955, 0.085, 0.12, 0.042, 0.004, 0.5, 3, 3)
        # The chest rig: a panel of webbing with three pouches, held by straps that cross the back.
        j.shell(body, "Rig panel", WEB, 226.0, 314.0, 1.12, 1.345, 0.008, 0.0, 8, 4)
        for i, a in enumerate((246.0, 270.0, 294.0)):
            j.pad(body, "Pouch", WEB, a, 1.2, 0.058, 0.115, 0.03, 0.008, 0.25, 3, 3)
            if fine(1):
                a0, a1 = j.span(a, 1.25, 0.06)
                j.shell(body, "Pouch flap", PATCH if i == 1 else WEB, a0, a1, 1.228, 1.27, 0.005, 0.036, 2, 1)
        for s in (1, -1):
            j.strap(body, "Rig strap", WEB, [(270 + s * 34, 1.34), (270 + s * 40, 1.48), (270 + s * 62, 1.562), (270 + s * 90, 1.582), (270 + s * 118, 1.562),
                                              (270 + s * 142, 1.47), (270 - s * 150, 1.3), (270 - s * 128, 1.14)], 0.04, 0.005, 0.0, 0.045)
        j.band(body, "Rig waist", WEB, 1.115, 1.15, 0.004, 0.0, 24)
        if fine(1):
            # One pouch that does not match, and a lamp that still works.
            j.pad(body, "Odd pouch", CANVAS, 316.0, 1.33, 0.05, 0.06, 0.018, 0.008, 0.3, 2, 2)
            j.stud(body, "Lamp", LAMP, 228.0, 1.4, 0.012, 0.006, 0.0, 6)
        # A scarf wound twice round the neck, one end hanging.
        scarf = Form([(1.535, 0.108, 0.1, 0, 0.012), (1.57, 0.104, 0.1, 0, 0.012), (1.61, 0.092, 0.092, 0, 0.012), (1.64, 0.074, 0.078, 0, 0.012)],
                     2.2, folds=0.006, seed=9.0)
        scarf.mesh(body, "Scarf", CANVAS, 14, 0.03)
        if fine(1):
            j.patch(body, "Scarf end", CANVAS, [(-0.1, 1.56), (-0.05, 1.55), (-0.058, 1.4), (-0.086, 1.375), (-0.108, 1.41)], "front", 0.008, 0.01, 0.035, 0.0)
        neck = Form([(1.58, 0.05, 0.053, 0, 0.012), (1.7, 0.047, 0.051, 0, 0.012)], 2.0)
        neck.mesh(body, "Neck", SKIN, 10, 0.05)
    return j


def sleeve_form(side):
    return Form([(0.056, 0.008, 0.016, -0.044, 0), (0.044, 0.032, 0.046, -0.028, 0), (0.026, 0.052, 0.062, -0.012, 0), (-0.01, 0.062, 0.068, -0.002, 0),
                 (-0.08, 0.062, 0.066), (-0.18, 0.057, 0.061), (-0.245, 0.055, 0.058)], 2.1, origin=(side * SX, 1.5, 0), side=side, folds=0.003, seed=4.0 + side,
                bunch=((-0.22, 0.04, 1.4),))


def forearm_form(side):
    return Form([(-0.2, 0.044, 0.047), (-0.29, 0.042, 0.045), (-0.36, 0.044, 0.047, 0, 0.002), (-0.46, 0.036, 0.039), (-0.555, 0.028, 0.032), (-0.585, 0.027, 0.031)],
                2.0, origin=(side * SX, 1.5, 0), side=side)


def arm(body, side):
    with bound("arm_r" if side > 0 else "arm_l"):
        f = sleeve_form(side)
        f.mesh(body, "Sleeve", JACKET, 14, 0.04)
        # The sleeve shoved up above the elbow: the forearm is bare.
        f.band(body, "Sleeve roll", JACKET, -0.262, -0.222, 0.007, 0.0, 14)
        fore = forearm_form(side)
        fore.mesh(body, "Forearm", SKIN, 12, 0.045)
    with bound(f"UpperArm_{tag(side)}"):
        if side < 0:
            # The red band of the Rebellion, knotted with its ends hanging.
            f.band(body, "Armband", RED, -0.15, -0.1, 0.004, 0.0, 14)
            if fine(1):
                f.patch(body, "Band end", RED, [(-0.012, -0.145), (0.012, -0.145), (0.02, -0.215), (0.004, -0.2), (-0.01, -0.222)], "outer", 0.004, 0.005, 0.03, 0.0)
        elif fine(1):
            f.shell(body, "Shoulder patch", PATCH, -50.0, 50.0, -0.13, -0.045, 0.003, 0.0, 3, 2)
    with bound(f"Forearm_{tag(side)}"):
        if side > 0:
            # A leather bracer on the arm that carries the gun.
            fore.band(body, "Bracer", LEATHER, -0.5, -0.37, 0.005, 0.0, 12)
            if fine(1):
                for y in (-0.47, -0.4):
                    fore.band(body, "Bracer strap", BOOT, y - 0.008, y + 0.008, 0.003, 0.005, 12)
        fore.band(body, "Wrist wrap", WRAP, -0.585, -0.525, 0.004, 0.0, 12)
    human_hand(body, side, (side * SX, 1.5 - UPPER_ARM - FOREARM, 0))


def human_hand(part, side, wrist):
    """A hand in a fingerless glove, closed round a grip. Built hanging from the wrist, palm
    toward the body, with the grip running front to back through the fist."""
    with bound(f"Hand_{tag(side)}"), at(*wrist):
        palm = Form([(-0.1, 0.012, 0.037, 0, -0.002), (-0.086, 0.016, 0.042, 0, -0.002), (-0.05, 0.017, 0.04, 0, -0.002), (-0.012, 0.015, 0.03), (0.012, 0.014, 0.028)],
                    2.6, origin=(side * 0.004, 0, 0), side=side)
        palm.mesh(part, "Glove", LEATHER, 10, 0.04)
        if fine(1):
            palm.shell(part, "Knuckle guard", RUBBER, -64.0, 64.0, -0.1, -0.066, 0.004, 0.0, 3, 1)
        cx, cy, reach = -0.024, -0.103, 0.0235
        fingers = [(-0.031, 1.0, 0.0096), (-0.0105, 1.06, 0.0099), (0.01, 1.0, 0.0094), (0.0295, 0.84, 0.0084)]
        if not fine(1):
            fingers = [(-0.02, 1.03, 0.018), (0.02, 0.94, 0.017)]
        for fz, length, r in fingers:
            pts = [Vector((side * (cx + reach * length * math.cos(math.radians(a))), cy + reach * length * math.sin(math.radians(a)), fz)) for a in (28.0, -40.0, -110.0, -178.0)]
            tube(part, "Finger", pts, r, SKIN, pick(7, 5, 4))
            if fine(0):
                tube(part, "Glove finger", [pts[0], pts[0].lerp(pts[1], 0.62)], r * 1.14, LEATHER, 7)
        thumb = [Vector((side * x, y, z)) for x, y, z in ((-0.002, -0.034, -0.036), (-0.016, -0.062, -0.05), (-0.034, -0.084, -0.043), (-0.045, -0.098, -0.024))]
        tube(part, "Thumb", thumb, 0.0108, SKIN, pick(7, 5, 4))
        if fine(0):
            tube(part, "Glove thumb", [thumb[0], thumb[0].lerp(thumb[1], 0.7)], 0.0122, LEATHER, 7)


def body_reb(body="Body_Reb"):
    trunk(body)
    for side in (1, -1):
        leg(body, side)
        arm(body, side)


# ---------------------------------------------------------------- heads

def face_relief(a, t):
    d = wrap_angle(a, 270.0)
    nose = (0.021 * bump(t, 0.112, 0.016) + 0.008 * smooth(0.1, 0.13, t) * smooth(0.178, 0.15, t)) * bump(d, 0.0, 9.0)
    ridge = 0.005 * bump(t, 0.178, 0.011) * bump(d, 0.0, 44.0)
    sockets = -0.0065 * bump(t, 0.158, 0.011) * (bump(d, 23.0, 11.0) + bump(d, -23.0, 11.0))
    cheeks = 0.004 * bump(t, 0.128, 0.02) * (bump(d, 40.0, 14.0) + bump(d, -40.0, 14.0))
    chin = 0.006 * bump(t, 0.052, 0.014) * bump(d, 0.0, 20.0)
    return nose + ridge + sockets + cheeks + chin


def skull():
    return Form([(0.03, 0.022, 0.03, 0, -0.014), (0.05, 0.045, 0.06, 0, -0.014), (0.085, 0.062, 0.082, 0, -0.006), (0.13, 0.071, 0.092, 0, 0.002),
                 (0.18, 0.074, 0.097, 0, 0.006), (0.225, 0.072, 0.094, 0, 0.008), (0.255, 0.056, 0.074, 0, 0.008), (0.272, 0.028, 0.038, 0, 0.008),
                 (0.2795, 0.003, 0.004, 0, 0.008)], (2.3, 2.1), origin=HEAD, relief=face_relief)


def face(part, eyes=True, ears=False):
    """A human head. Most of it will be under a hood or a helmet; what shows is skin, and where
    the eyes show they are a person's eyes."""
    s = skull()
    s.mesh(part, "Head", SKIN, 24, 0.016)
    if eyes:
        # The sockets are hollows, where a coarse mesh stands proud of the true surface, so the
        # eyes are lifted clear of it.
        for side in (1, -1):
            c = 270.0 + side * 23.0
            if fine(0):
                s.shell(part, "Eye", EYEWHITE, 0, 0, 0, 0, 0.0008, 0.0028, 4, 2,
                        lambda u, v, c=c, side=side: (c + side * (u * 2 - 1) * 11.0, 0.1575 + (v - 0.5) * 0.013 * math.sin((0.08 + 0.84 * u) * math.pi) ** 0.7 + 0.002 * u), 0.004)
                s.stud(part, "Iris", DARK, c + side * 0.5, 0.158, 0.0054, 0.001, 0.0034, 8)
                s.strap(part, "Lid", DARK, [(c - side * 12.0, 0.1612), (c, 0.1668), (c + side * 12.0, 0.1636)], 0.003, 0.001, 0.0036, 0.012)
            elif fine(1):
                s.strap(part, "Eye", HAIR, [(c - side * 8.0, 0.158), (c + side * 8.0, 0.1592)], 0.0055, 0.001, 0.003, 0.03)
            if fine(1):
                s.strap(part, "Brow", HAIR, [(c - side * 14.0, 0.1775), (c - side * 2.0, 0.182), (c + side * 13.0, 0.1785)], 0.0055, 0.002, 0.002, 0.014)
    if ears and fine(1):
        for side in (1, -1):
            face_of = "outer" if side > 0 else "inner"
            s.patch(part, "Ear", SKIN, [(0.002, 0.125), (0.02, 0.118), (0.03, 0.14), (0.026, 0.17), (0.008, 0.178)], face_of, 0.011, 0.0, 0.03, 0.004)
    return s


def hood_form(drop=0.0):
    return Form([(-0.04 - drop, 0.122, 0.112, 0, 0.032), (0.03, 0.102, 0.11, 0, 0.022), (0.1, 0.096, 0.118, 0, 0.014), (0.19, 0.096, 0.124, 0, 0.008),
                 (0.25, 0.084, 0.11, 0, 0.008), (0.287, 0.05, 0.07, 0, 0.014), (0.3, 0.005, 0.007, 0, 0.014)], (2.3, 2.1), origin=HEAD, folds=0.003, seed=2.4)


def hood(part, mat, opening=45.0, mid=0.15, height=0.078, thick=0.008, form=None):
    """Cloth over the head and down to the shoulders, open at the face."""
    f = form or hood_form()
    lo, hi = f.keys[0], f.keys[-1]

    def wrap(u, v):
        t = lo + (hi - lo) * (1 - (1 - v) ** 1.25)
        gap = opening * math.sqrt(max(0.0, 1.0 - ((t - mid) / height) ** 2))
        return 270.0 + gap + u * (360.0 - 2 * gap), t

    f.shell(part, "Hood", mat, 0, 0, 0, 0, thick, 0.0, pick(22, 12, 7), pick(12, 6, 4), wrap, 0.006, True)
    return f


def bandana(part, s, mat, top=0.134, low=0.04, half=72.0, thick=0.004):
    """Cloth tied over the nose and mouth."""
    def wrap(u, v):
        w = u * 2 - 1
        high = top + 0.012 * bump(w * half, 0.0, 16.0) - 0.012 * abs(w) ** 2
        return 270.0 + w * half, low + (high - low) * v

    s.shell(part, "Bandana", mat, 0, 0, 0, 0, thick, 0.003, 10, 4, wrap, 0.006)


def goggles(part, s, y, band=True, lens=LENS):
    """Two framed lenses on a strap. `y` is where they sit: on the eyes, or pushed up on the brow."""
    if band:
        s.band(part, "Goggle strap", RUBBER, y - 0.008, y + 0.008, 0.003, 0.004, 16)
    for side in (1, -1):
        c = 270.0 + side * 23.0
        a0, a1 = s.span(c, y, 0.047)
        s.shell(part, "Goggle frame", RUBBER, a0, a1, y - 0.017, y + 0.017, 0.014, 0.0, 3, 2)
        a0, a1 = s.span(c, y, 0.034)
        s.shell(part, "Goggle lens", lens, a0, a1, y - 0.0105, y + 0.0105, 0.002, 0.0145, 2, 1, None, 0.002)
    if fine(1):
        a0, a1 = s.span(270.0, y, 0.016)
        s.shell(part, "Goggle bridge", RUBBER, a0, a1, y - 0.006, y + 0.006, 0.008, 0.0, 1, 1)


def head_fighter(part="Head_fighter"):
    """The assault trooper: hood up, a red cloth over the mouth, goggles pushed up on the brow."""
    with bound("Head"):
        s = face(part)
        bandana(part, s, RED)
        hood(part, HOOD)
        goggles(part, s, 0.203, band=False)


def head_medic(part="Head_medic"):
    """The medic: a knitted cap and a cloth mask."""
    with bound("Head"):
        s = face(part, ears=True)
        bandana(part, s, MEDIC, 0.13, 0.045, 64.0)
        if fine(1):
            for side in (1, -1):
                s.strap(part, "Mask tie", MEDIC, [(270 + side * 62, 0.12), (270 + side * 88, 0.135), (270 + side * 118, 0.125)], 0.006, 0.002, 0.0, 0.03)
        cap = Form([(0.186, 0.078, 0.1, 0, 0.007), (0.23, 0.078, 0.101, 0, 0.008), (0.262, 0.062, 0.082, 0, 0.008), (0.283, 0.03, 0.04, 0, 0.008), (0.289, 0.004, 0.005, 0, 0.008)],
                   (2.3, 2.1), origin=HEAD)
        cap.mesh(part, "Cap", GREY, 16, 0.02)
        cap.band(part, "Cap fold", GREY, 0.186, 0.212, 0.006, 0.0, 16)
        if fine(1):
            cap.patch(part, "Cap cross", CROSS, [(-0.006, 0.222), (0.006, 0.222), (0.006, 0.232), (0.016, 0.232), (0.016, 0.244), (0.006, 0.244), (0.006, 0.254),
                                               (-0.006, 0.254), (-0.006, 0.244), (-0.016, 0.244), (-0.016, 0.232), (-0.006, 0.232)], "front", 0.002, 0.0, 0.03, 0.0)
        s.shell(part, "Hair", HAIR, 30.0, 150.0, 0.09, 0.19, 0.006, 0.0, 6, 3)


def head_sniper(part="Head_sniper"):
    """The marksman: a ragged hood and a veil to the eyes. Only the eyes show."""
    with bound("Head"):
        s = face(part)
        bandana(part, s, DRAB, 0.146, 0.04, 78.0)
        f = hood(part, DRAB, 40.0, 0.166, 0.05)
        # Strips of rag sewn to the hood break up the shape of a head.
        for i, (a, t, length) in enumerate(((20, 0.2, 0.09), (65, 0.24, 0.1), (118, 0.21, 0.11), (160, 0.17, 0.08), (200, 0.22, 0.07), (340, 0.23, 0.07), (90, 0.12, 0.12))):
            if fine(1) or i % 2 == 0:
                f.strap(part, "Rag", JACKET if i % 2 else PATCH, [(a, t), (a + 6, t - length * 0.5), (a - 4, t - length)], 0.03, 0.004, 0.008, 0.04)


def head_engineer(part="Head_engineer"):
    """The engineer: welder's goggles, a respirator, and a rag tied over the head."""
    with bound("Head"):
        s = face(part, eyes=False, ears=True)
        goggles(part, s, 0.16)
        # The respirator: a rubber cup over nose and mouth with a filter on the front.
        s.pad(part, "Respirator", RUBBER, 270.0, 0.088, 0.09, 0.078, 0.026, 0.0, 0.5, 4, 3)
        p = s.at(270.0, 0.08, 0.03)
        block(part, "Filter", SCRAP, p + Vector((0, 0, -0.008)), (0.052, 0.04, 0.034), 0.006)
        if fine(1):
            block(part, "Filter grille", DARK, p + Vector((0, 0, -0.027)), (0.036, 0.024, 0.004), 0.0)
            for side in (1, -1):
                s.strap(part, "Mask strap", RUBBER, [(270 + side * 34, 0.09), (270 + side * 70, 0.1), (270 + side * 110, 0.11), (270 + side * 150, 0.1)], 0.012, 0.003, 0.0, 0.035)
        rag = Form([(0.19, 0.077, 0.1, 0, 0.007), (0.232, 0.077, 0.1, 0, 0.008), (0.262, 0.06, 0.08, 0, 0.008), (0.281, 0.03, 0.04, 0, 0.008), (0.287, 0.004, 0.005, 0, 0.008)],
                   (2.3, 2.1), origin=HEAD, folds=0.002)
        rag.mesh(part, "Head rag", RED, 16, 0.02)
        if fine(1):
            rag.patch(part, "Rag knot", RED, [(-0.02, 0.2), (0.02, 0.2), (0.03, 0.13), (0.008, 0.15), (-0.012, 0.125), (-0.03, 0.15)], "back", 0.006, 0.004, 0.03, 0.0)


def head_leader(part="Head_leader"):
    """The squad leader: a red beret, a beard, and a headset."""
    with bound("Head"):
        s = face(part, ears=True)

        def beard(u, v):
            w = u * 2 - 1
            high = 0.1 + 0.045 * abs(w) ** 1.6
            low = 0.036 + 0.05 * abs(w) ** 2.4
            return 270.0 + w * 66.0, low + (high - low) * v

        s.shell(part, "Beard", HAIR, 0, 0, 0, 0, 0.007, 0.0, 10, 3, beard, 0.004)
        if fine(1):
            s.strap(part, "Moustache", HAIR, [(250, 0.094), (270, 0.1), (290, 0.094)], 0.012, 0.005, 0.0, 0.02)
        s.shell(part, "Hair", HAIR, 20.0, 160.0, 0.085, 0.2, 0.005, 0.0, 6, 3)
        beret = Form([(0.196, 0.08, 0.102, 0, 0.008), (0.222, 0.098, 0.116, 0.014, 0.01), (0.25, 0.094, 0.11, 0.022, 0.012), (0.268, 0.056, 0.068, 0.024, 0.012),
                      (0.273, 0.004, 0.005, 0.024, 0.012)], (2.2, 2.1), origin=HEAD)
        beret.mesh(part, "Beret", RED, 16, 0.02)
        beret.band(part, "Beret band", BOOT, 0.196, 0.21, 0.003, 0.0, 16)
        if fine(1):
            beret.stud(part, "Badge", BRASS, 252.0, 0.228, 0.011, 0.004, 0.0, 6)
            # A headset: one cup over the left ear and a microphone arm to the mouth.
            s.patch(part, "Earcup", RUBBER, [(-0.012, 0.118), (0.022, 0.118), (0.03, 0.15), (0.02, 0.178), (-0.01, 0.178), (-0.018, 0.148)], "inner", 0.02, 0.0, 0.03, 0.004)
            tube(part, "Mic arm", [(-0.086, 1.56 + 0.13, -0.004), (-0.084, 1.56 + 0.1, -0.05), (-0.05, 1.56 + 0.088, -0.094)], 0.004, RUBBER, 5)
            block(part, "Mic", RUBBER, (-0.042, 1.56 + 0.088, -0.1), (0.022, 0.014, 0.014), 0.003)


def head_gunner(part="Head_gunner"):
    """The heavy gunner: a helmet welded from cut plate, with a slit to see through."""
    with bound("Head"):
        s = skull()
        s.mesh(part, "Head", DARK, 12, 0.05)
        h = Form([(0.012, 0.074, 0.09, 0, 0.0), (0.09, 0.09, 0.112, 0, 0.004), (0.2, 0.093, 0.116, 0, 0.008), (0.262, 0.08, 0.1, 0, 0.008), (0.292, 0.042, 0.054, 0, 0.008),
                  (0.299, 0.004, 0.005, 0, 0.008)], (3.2, 2.6), origin=HEAD)
        h.mesh(part, "Helmet", SCRAP, 16, 0.045)
        # The slit, and the plates welded round it.
        h.shell(part, "Slit", DARK, 228.0, 312.0, 0.152, 0.168, 0.002, 0.0, 6, 1, None, 0.002)
        h.shell(part, "Brow plate", SCRAP, 218.0, 322.0, 0.172, 0.222, 0.008, 0.0, 6, 2)
        h.shell(part, "Face plate", SCRAP, 232.0, 308.0, 0.03, 0.146, 0.008, 0.0, 6, 3)
        h.strap(part, "Nose bar", STEEL, [(270, 0.03), (270, 0.15), (270, 0.23), (270, 0.285)], 0.018, 0.006, 0.008, 0.05)
        if fine(1):
            for side in (1, -1):
                for y in (0.06, 0.09, 0.12):
                    for a in (14.0, 24.0):
                        h.stud(part, "Breather", DARK, 270 + side * a, y, 0.0045, 0.002, 0.008, 5)
                for a in (30.0, 50.0):
                    h.stud(part, "Rivet", STEEL, 270 + side * a, 0.205, 0.006, 0.004, 0.008, 6)
                h.shell(part, "Ear plate", RUST, 270 + side * 62, 270 + side * 112, 0.07, 0.19, 0.007, 0.0, 3, 3)
        # A skirt of plate at the back, down to the collar.
        h.shell(part, "Neck guard", SCRAP, 20.0, 160.0, -0.035, 0.07, 0.006, 0.004, 6, 2,
                lambda u, v: (20.0 + 140.0 * u, -0.04 + 0.11 * v))
        h.strap(part, "Stripe", RED, [(90, 0.285), (90, 0.2), (90, 0.08)], 0.03, 0.002, 0.0, 0.05)


def head_jumper(part="Head_jumper"):
    """The jumper: an old flying helmet of leather, goggles down, a scarf over the mouth."""
    with bound("Head"):
        s = face(part, eyes=False)
        bandana(part, s, CANVAS, 0.136, 0.04, 70.0)
        f = Form([(0.02, 0.09, 0.102, 0, 0.016), (0.1, 0.086, 0.106, 0, 0.012), (0.19, 0.086, 0.11, 0, 0.008), (0.25, 0.074, 0.096, 0, 0.008), (0.283, 0.042, 0.056, 0, 0.008),
                  (0.292, 0.004, 0.005, 0, 0.008)], (2.3, 2.1), origin=HEAD)
        hood(part, LEATHER, 50.0, 0.125, 0.07, 0.007, f)
        if fine(1):
            f.strap(part, "Crown seam", BOOT, [(270, 0.2), (270, 0.26), (270, 0.289)], 0.016, 0.003, 0.007, 0.03)
            f.strap(part, "Crown seam", BOOT, [(90, 0.289), (90, 0.22), (90, 0.06)], 0.016, 0.003, 0.007, 0.04)
            for side in (1, -1):
                face_of = "outer" if side > 0 else "inner"
                f.patch(part, "Ear flap", BOOT, [(-0.022, 0.1), (0.03, 0.1), (0.036, 0.16), (0.006, 0.185), (-0.026, 0.16)], face_of, 0.006, 0.007, 0.03, 0.003)
        goggles(part, s, 0.162, band=False, lens=LAMP if False else LENS)
        f.band(part, "Goggle strap", RUBBER, 0.153, 0.171, 0.003, 0.008, 16)


HEADS = {"Head_fighter": head_fighter, "Head_medic": head_medic, "Head_sniper": head_sniper, "Head_engineer": head_engineer, "Head_leader": head_leader,
         "Head_gunner": head_gunner, "Head_jumper": head_jumper}


# ---------------------------------------------------------------- what the classes carry

def pack(part, j, name, y, w, h, depth, mat, lift=0.0, soft=0.35):
    """A bag worn on the back, shaped to it."""
    a0, a1 = j.span(BACK, y, w)
    return j.shell(part, name, mat, a0, a1, y - h / 2, y + h / 2, lambda u, v: depth * (0.5 + 0.5 * min(1.0, min(u, 1 - u, v, 1 - v) * 2 / soft) ** 0.6), lift, 5, 5)


def cross(j, part, face_of, cx, cy, size, lift):
    k = size
    outline = [(-k, -3 * k), (k, -3 * k), (k, -k), (3 * k, -k), (3 * k, k), (k, k), (k, 3 * k), (-k, 3 * k), (-k, k), (-3 * k, k), (-3 * k, -k), (-k, -k)]
    with unshaded():
        j.patch(part, "Cross", CROSS, [(cx + x, cy + y) for x, y in outline], face_of, 0.003, lift, 0.06, 0.0)


def gear_fighter(part="Gear_fighter"):
    """The assault trooper travels light: a small pack and a blade."""
    with bound("Torso"):
        j = trunk_form()
        pack(part, j, "Pack", 1.3, 0.2, 0.25, 0.07, CANVAS)
        if fine(1):
            a0, a1 = j.span(BACK, 1.38, 0.2)
            j.shell(part, "Pack lid", PATCH, a0, a1, 1.345, 1.425, 0.006, 0.066, 3, 1)
            for s in (-1, 1):
                j.strap(part, "Pack strap", LEATHER, [(90 + s * 16, 1.4), (90 + s * 16, 1.3), (90 + s * 16, 1.19)], 0.014, 0.003, 0.073, 0.05)
        block(part, "Machete sheath", LEATHER, (-0.13, 1.28, 0.165), (0.04, 0.34, 0.016), 0.004, Matrix.Rotation(math.radians(-14.0), 3, "Z"))
        if fine(1):
            block(part, "Machete grip", RUBBER, (-0.178, 1.475, 0.165), (0.024, 0.09, 0.02), 0.004, Matrix.Rotation(math.radians(-14.0), 3, "Z"))


def gear_medic(part="Gear_medic"):
    """The medic: an aid pack on the back, a satchel on the hip, and the cross on both."""
    with bound("Torso"):
        j = trunk_form()
        pack(part, j, "Aid pack", 1.3, 0.25, 0.3, 0.085, MEDIC)
        cross(j, part, "back", 0.0, 1.3, 0.017, pick(0.087, 0.09, 0.096))
        if fine(1):
            a0, a1 = j.span(BACK, 1.41, 0.25)
            j.shell(part, "Pack lid", GREY, a0, a1, 1.385, 1.455, 0.006, 0.08, 3, 1)
        # The satchel's strap, from the right shoulder to the left hip.
        j.strap(part, "Satchel strap", LEATHER, [(200, 1.0), (236, 1.16), (268, 1.32), (300, 1.46), (326, 1.55), (0, 1.584)], 0.03, 0.004, 0.01, 0.05)
        j.strap(part, "Satchel strap", LEATHER, [(0, 1.584), (40, 1.5), (80, 1.3), (130, 1.12), (170, 1.0)], 0.03, 0.004, 0.0, 0.06)
        # A white band on the right arm says what the cross says.
    with bound("Pelvis"):
        hips = Form([(0.8, 0.17, 0.122), (0.9, 0.174, 0.126), (1.0, 0.166, 0.118)], 2.3)
        hips.pad(part, "Satchel", MEDIC, 186.0, 0.9, 0.17, 0.15, 0.065, 0.004, 0.3, 4, 4)
        if fine(1):
            a0, a1 = hips.span(186.0, 0.95, 0.172)
            hips.shell(part, "Satchel flap", GREY, a0, a1, 0.9, 0.98, 0.006, 0.066, 3, 1)
    with bound("UpperArm_R"):
        f = sleeve_form(1)
        f.band(part, "Medic band", MEDIC, -0.16, -0.1, 0.004, 0.003, 14)


def gear_sniper(part="Gear_sniper"):
    """The marksman: a ragged cape down the back, and rags on the shoulders."""
    with bound("torso"):
        cape = Form([(0.5, 0.215, 0.185, 0, 0.05), (0.75, 0.21, 0.175, 0, 0.045), (1.0, 0.2, 0.16, 0, 0.035), (1.3, 0.2, 0.15, 0, 0.022), (1.5, 0.19, 0.125, 0, 0.012),
                     (1.57, 0.12, 0.1, 0, 0.012)], 2.3, folds=0.008, seed=6.0)

        def hang(u, v):
            a = 18.0 + 144.0 * u
            ragged = 0.56 + 0.07 * math.sin(u * 31.0) + 0.05 * math.sin(u * 67.0 + 1.0)
            return a, ragged + (1.565 - ragged) * (1 - (1 - v) ** 1.3)

        cape.shell(part, "Cape", DRAB, 0, 0, 0, 0, 0.006, 0.0, pick(12, 7, 4), pick(10, 5, 3), hang, 0.004, True)
        j = trunk_form()
        for i, (a, t, length) in enumerate(((330, 1.52, 0.12), (300, 1.5, 0.1), (240, 1.5, 0.1), (210, 1.52, 0.12), (20, 1.5, 0.14), (160, 1.5, 0.14), (350, 1.45, 0.1), (190, 1.45, 0.1))):
            if fine(1) or i % 2 == 0:
                j.strap(part, "Rag", JACKET if i % 2 else PATCH, [(a, t), (a + 4, t - length * 0.5), (a - 3, t - length)], 0.045, 0.004, 0.004, 0.05)
        j.strap(part, "Sling", LEATHER, [(240, 1.02), (262, 1.2), (296, 1.44), (326, 1.55), (0, 1.584)], 0.022, 0.004, 0.01, 0.05)


def gear_engineer(part="Gear_engineer"):
    """The engineer: a leather apron, a tool pack, and a gas bottle strapped beside it."""
    with bound("torso"):
        apron = Form([(0.6, 0.176, 0.13), (0.86, 0.18, 0.132), (1.0, 0.17, 0.124), (1.1, 0.168, 0.122), (1.3, 0.19, 0.135, 0, -0.006), (1.4, 0.196, 0.132, 0, -0.004)], (2.4, 2.3))

        def bib(u, v):
            t = 0.61 + 0.77 * v
            half = 46.0 - 20.0 * smooth(1.12, 1.38, t)
            return 270.0 + (u * 2 - 1) * half, t

        apron.shell(part, "Apron", LEATHER, 0, 0, 0, 0, 0.005, 0.0, 6, 8, bib, 0.004)
        if fine(1):
            apron.pad(part, "Apron pocket", LEATHER, 270.0, 0.95, 0.15, 0.09, 0.012, 0.005, 0.3, 3, 2)
    with bound("Torso"):
        j = trunk_form()
        pack(part, j, "Tool pack", 1.3, 0.27, 0.34, 0.1, WEB)
        if fine(1):
            a0, a1 = j.span(BACK, 1.43, 0.27)
            j.shell(part, "Tool roll", CANVAS, a0, a1, 1.42, 1.5, 0.03, 0.07, 3, 1)
            for s in (1, -1):
                j.strap(part, "Apron strap", LEATHER, [(270 + s * 24, 1.38), (270 + s * 40, 1.5), (270 + s * 70, 1.566), (270 + s * 100, 1.566)], 0.02, 0.004, 0.012, 0.05)
        # A cutting-gas bottle, dented and rusty.
        tube(part, "Gas bottle", [(0.17, 1.06, 0.2), (0.17, 1.09, 0.2), (0.17, 1.44, 0.2), (0.17, 1.48, 0.2), (0.17, 1.51, 0.2)], [0.03, 0.042, 0.042, 0.026, 0.014], RUST, 10)
        if fine(1):
            tube(part, "Bottle valve", [(0.17, 1.51, 0.2), (0.17, 1.535, 0.2)], 0.018, BRASS, 6)
            tube(part, "Hose", [(0.17, 1.53, 0.2), (0.2, 1.57, 0.13), (0.215, 1.5, 0.02), (0.2, 1.3, -0.06)], 0.007, RUBBER, 5)
            for y in (1.16, 1.38):
                tube(part, "Bottle strap", [(0.17, y - 0.012, 0.2), (0.17, y + 0.012, 0.2)], 0.045, LEATHER, 10)
    with bound("Pelvis"):
        hips = Form([(0.8, 0.178, 0.13), (0.9, 0.182, 0.134), (1.0, 0.172, 0.126)], 2.3)
        hips.pad(part, "Tool pouch", LEATHER, 352.0, 0.92, 0.1, 0.13, 0.04, 0.004, 0.3, 3, 3)
        if fine(1):
            block(part, "Wrench", STEEL, (0.19, 0.99, 0.01), (0.014, 0.12, 0.03), 0.003)


def gear_leader(part="Gear_leader"):
    """The squad leader: a long coat's skirts, a field radio with its aerial, and binoculars."""
    with bound("torso"):
        skirt = Form([(0.5, 0.212, 0.165, 0, 0.012), (0.7, 0.2, 0.152, 0, 0.008), (0.9, 0.184, 0.136, 0, 0.004), (1.03, 0.166, 0.12)], 2.3, folds=0.006, seed=3.3)

        def tails(u, v):
            return -58.0 + 296.0 * u, 0.5 + 0.02 * math.sin(u * 23.0) + (0.53 - 0.02 * math.sin(u * 23.0)) * v

        skirt.shell(part, "Coat skirt", PATCH, 0, 0, 0, 0, 0.006, 0.0, pick(16, 9, 5), pick(6, 3, 2), tails, 0.004, True)
    with bound("Torso"):
        j = trunk_form()
        pack(part, j, "Radio", 1.31, 0.23, 0.28, 0.085, DRAB, 0.0, 0.15)
        if fine(1):
            j.patch(part, "Radio face", SCRAP, [(-0.08, 1.24), (0.08, 1.24), (0.08, 1.38), (-0.08, 1.38)], "back", 0.004, 0.086, 0.06, 0.003)
            j.stud(part, "Dial", STEEL, 82.0, 1.34, 0.012, 0.008, 0.09, 6)
            j.stud(part, "Dial", STEEL, 98.0, 1.34, 0.012, 0.008, 0.09, 6)
            j.stud(part, "Radio lamp", LAMP, 90.0, 1.28, 0.009, 0.005, 0.09, 6)
        tube(part, "Aerial", [(0.09, 1.44, 0.2), (0.1, 1.75, 0.23), (0.115, 2.12, 0.29)], [0.006, 0.004, 0.0028], RUBBER, 5)
        if fine(1):
            tube(part, "Aerial base", [(0.09, 1.42, 0.2), (0.09, 1.47, 0.2)], 0.012, STEEL, 6)
            tube(part, "Handset cord", [(-0.1, 1.42, 0.18), (-0.17, 1.5, 0.06), (-0.15, 1.44, -0.1), (-0.11, 1.4, -0.14)], 0.005, RUBBER, 5)
        # Binoculars on the chest.
        block(part, "Binoculars", RUBBER, (0.005, 1.4, -0.168), (0.11, 0.05, 0.05), 0.012)
        if fine(1):
            j.strap(part, "Binocular strap", LEATHER, [(252, 1.42), (240, 1.52), (220, 1.57)], 0.01, 0.003, 0.012, 0.04)
            j.strap(part, "Binocular strap", LEATHER, [(288, 1.42), (300, 1.52), (320, 1.57)], 0.01, 0.003, 0.012, 0.04)
    with bound("UpperArm_R"):
        f = sleeve_form(1)
        if fine(1):
            for y in (-0.07, -0.095, -0.12):
                f.shell(part, "Rank bar", BRASS, -38.0, 38.0, y - 0.008, y + 0.008, 0.002, 0.004, 2, 1)


def gear_gunner(part="Gear_gunner"):
    """The heavy gunner: armour cut from the hulls of dead machines and bolted to a harness."""
    with bound("Torso"):
        j = trunk_form()

        def chest(u, v):
            w = u * 2 - 1
            t = 1.1 + 0.4 * v
            return 270.0 + w * (58.0 - 14.0 * smooth(1.36, 1.5, t)), t - 0.02 * abs(w) ** 2 * (1 - v)

        j.shell(part, "Chest plate", SCRAP, 0, 0, 0, 0, 0.018, 0.012, 8, 5, chest, 0.006)
        j.shell(part, "Belly plate", SCRAP, 236.0, 304.0, 0.94, 1.085, 0.014, 0.01, 5, 2)
        j.shell(part, "Back plate", SCRAP, 40.0, 140.0, 1.08, 1.5, 0.016, 0.0, 6, 5)
        j.shell(part, "Patch plate", RUST, 276.0, 312.0, 1.2, 1.34, 0.008, 0.03, 3, 2)
        for s in (1, -1):
            j.strap(part, "Harness", LEATHER, [(270 + s * 46, 1.46), (270 + s * 62, 1.562), (270 + s * 90, 1.584), (270 + s * 118, 1.562), (270 + s * 136, 1.48)], 0.05, 0.006, 0.006, 0.05)
        if fine(1):
            for a, t in ((232, 1.44), (308, 1.44), (228, 1.16), (312, 1.16), (250, 1.47), (290, 1.47)):
                j.stud(part, "Bolt", STEEL, a, t, 0.009, 0.006, 0.03, 6)
            # A belt of charge cells slung across the chest.
            path = [(226, 1.1), (252, 1.22), (282, 1.36), (304, 1.48)]
            j.strap(part, "Cell belt", LEATHER, path, 0.05, 0.004, 0.031, 0.05)
            for i in range(7):
                u = (i + 0.5) / 7
                a = 226 + (304 - 226) * u
                t = 1.1 + (1.48 - 1.1) * u ** 0.9
                j.stud(part, "Cell", BRASS, a, t, 0.012, 0.014, 0.035, 6)
        # A reactor for the minigun on the back, the one thing here that glows.
        pack(part, j, "Power pack", 1.3, 0.24, 0.3, 0.11, SCRAP, 0.016, 0.15)
        j.strap(part, "Power light", LAMP, [(84, 1.36), (96, 1.36)], 0.014, 0.003, 0.127, 0.03)
    for side in (1, -1):
        with bound(f"UpperArm_{tag(side)}"):
            p = Form([(0.07, 0.03, 0.05, -0.03, 0), (0.035, 0.07, 0.082, -0.012, 0), (-0.04, 0.084, 0.09), (-0.14, 0.08, 0.086), (-0.17, 0.076, 0.082)], 2.6,
                     origin=(side * SX, 1.5, 0), side=side)
            p.shell(part, "Pauldron", SCRAP, -112.0, 112.0, -0.165, 0.066, 0.012, 0.0, 6, 4)
            if fine(1):
                p.shell(part, "Pauldron rim", RUST if side > 0 else STEEL, -112.0, 112.0, -0.17, -0.14, 0.006, 0.012, 6, 1)
                for a in (-70.0, 0.0, 70.0):
                    p.stud(part, "Bolt", STEEL, a, -0.05, 0.008, 0.005, 0.012, 6)
        with bound(f"Thigh_{tag(side)}"):
            f = Form([(0.82, 0.098, 0.112), (0.62, 0.086, 0.098), (0.52, 0.078, 0.09)], 2.2, origin=(side * 0.1, 0, 0), side=side)
            f.shell(part, "Thigh plate", SCRAP, -64.0, 30.0, 0.56, 0.8, 0.012, 0.0, 4, 3)
            f.shell(part, "Thigh plate", SCRAP, 250.0, 296.0, 0.56, 0.8, 0.012, 0.0, 3, 3)
            if fine(1):
                f.band(part, "Plate strap", LEATHER, 0.66, 0.69, 0.004, 0.0, 12)
        with bound(f"Shin_{tag(side)}"):
            f = Form([(0.44, 0.074, 0.086, 0, -0.004), (0.3, 0.07, 0.084, 0, 0.004), (0.2, 0.062, 0.076, 0, 0.004)], 2.2, origin=(side * 0.1, 0, 0), side=side)
            f.shell(part, "Shin plate", SCRAP, 212.0, 328.0, 0.21, 0.435, 0.012, 0.0, 5, 3)
            if fine(1):
                f.shell(part, "Knee cap", RUST if side < 0 else SCRAP, 226.0, 314.0, 0.4, 0.5, 0.012, 0.012, 4, 2)


def gear_jumper(part="Gear_jumper"):
    """The jumper: two salvaged thrusters on a frame, and the harness that holds a person to them."""
    with bound("Torso"):
        j = trunk_form()
        block(part, "Frame", SCRAP, (0.0, 1.3, 0.2), (0.16, 0.4, 0.07), 0.012)
        for side in (1, -1):
            x = side * 0.15
            rings = []
            for y, w, d in ((1.0, 0.04, 0.05), (1.04, 0.058, 0.07), (1.5, 0.058, 0.07), (1.56, 0.044, 0.054), (1.585, 0.02, 0.026)):
                c = min(w, d) * 0.42
                rings.append([(x - w + c, y, 0.29 - d), (x + w - c, y, 0.29 - d), (x + w, y, 0.29 - d + c), (x + w, y, 0.29 + d - c), (x + w - c, y, 0.29 + d),
                              (x - w + c, y, 0.29 + d), (x - w, y, 0.29 + d - c), (x - w, y, 0.29 - d + c)])
            loft(part, "Thruster", rings, SCRAP)
            tube(part, "Nozzle", [(x, 1.01, 0.29), (x, 0.965, 0.29)], [0.046, 0.058], RUBBER, 8)
            if fine(1):
                for y in (1.16, 1.4):
                    rings = []
                    for yy in (y - 0.014, y + 0.014):
                        w, d = 0.063, 0.075
                        rings.append([(x - w, yy, 0.29 - d), (x + w, yy, 0.29 - d), (x + w, yy, 0.29 + d), (x - w, yy, 0.29 + d)])
                    loft(part, "Thruster band", rings, RUST)
                block(part, "Intake", DARK, (x, 1.5, 0.366), (0.07, 0.06, 0.006), 0.0)
                block(part, "Thruster light", LAMP, (x, 1.28, 0.366), (0.016, 0.1, 0.006), 0.0)
        for s in (1, -1):
            j.strap(part, "Harness", LEATHER, [(270 + s * 30, 1.12), (270 + s * 36, 1.4), (270 + s * 60, 1.562), (270 + s * 90, 1.584), (270 + s * 116, 1.562), (270 + s * 130, 1.46)],
                    0.034, 0.005, 0.01, 0.05)
        j.band(part, "Harness waist", LEATHER, 1.06, 1.1, 0.005, 0.006, 24)
        if fine(1):
            j.patch(part, "Harness buckle", STEEL, [(-0.03, 1.38), (0.03, 1.38), (0.03, 1.34), (-0.03, 1.34)], "front", 0.004, 0.014, 0.04, 0.003)
            j.strap(part, "Chest strap", LEATHER, [(240, 1.36), (270, 1.36), (300, 1.36)], 0.026, 0.004, 0.012, 0.04)


GEARS = {"Gear_fighter": gear_fighter, "Gear_medic": gear_medic, "Gear_sniper": gear_sniper, "Gear_engineer": gear_engineer, "Gear_leader": gear_leader,
         "Gear_gunner": gear_gunner, "Gear_jumper": gear_jumper}


# ---------------------------------------------------------------- first person

def first_person():
    """What the owner sees. The forearm is one metre long so the game can stretch it from wrist to
    elbow; the hand is turned to the frame the viewmodel poses it in: grip upright, fingers ahead."""
    with bound("Torso"):
        arm_form = Form([(-0.02, 0.027, 0.03), (0.12, 0.03, 0.033), (0.45, 0.04, 0.043), (0.72, 0.045, 0.048), (1.0, 0.044, 0.047)], 2.0)
        arm_form.mesh("FP_Arm", "Forearm", SKIN, 14, 0.2)
        arm_form.band("FP_Arm", "Wrist wrap", WRAP, -0.02, 0.2, 0.004, 0.0, 14)
        arm_form.band("FP_Arm", "Sleeve roll", JACKET, 0.86, 1.0, 0.012, 0.0, 14)
    human_hand("FP_Glove", 1, (0, 0, 0))
    remap("FP_Glove", fist_frame)


def fist_frame(p):
    """From a hand hanging at the wrist to the viewmodel's fist: the grip stands upright through
    the origin, the fingers wrap forward round it and the thumb sits on top."""
    return Vector((p.x + 0.024, -p.z, p.y + 0.103))


# ---------------------------------------------------------------- the files

LINEUP = ["fighter", "medic", "sniper", "engineer", "leader", "gunner", "jumper"]


def build():
    set_joints(SX)
    made = {}
    counts = {}
    for level in (0, 1, 2):
        set_lod(level)
        for name, fn in [("Body_Reb", body_reb)] + list(HEADS.items()) + list(GEARS.items()):
            fn(name)
            obj = finish(name, tone=worn)
            made[obj.name] = obj
            counts[obj.name] = triangles(obj)
    rig = armature("Rig")
    for obj in made.values():
        skin(obj, rig)
    print("[rebels] triangles", counts, flush=True)
    export(OUT / "rebel.glb", list(made.values()), rig)
    set_lod(0)
    first_person()
    fp = [finish(name, tone=worn) for name in ("FP_Arm", "FP_Glove")]
    export(OUT / "rebel_fp.glb", fp)
    made.update({obj.name: obj for obj in fp})
    return made


def preview(folder, made):
    cam = studio(1900, 900)
    for level in (0, 1, 2):
        for i, name in enumerate(LINEUP):
            for label in ("Body_Reb", f"Head_{name}", f"Gear_{name}"):
                stand(made[f"{label}_L{level}"], (i - 3) * 0.95 + level * 10.0)
    for i, name in enumerate(("FP_Arm", "FP_Glove")):
        stand(made[name + "_L0"], -8.0 + i * 0.4)
    for obj in made.values():
        obj.hide_render = True
    shoot(cam, folder, "front", (1.4, 1.3, -13.0), (0, 0.98, 0), 72)
    shoot(cam, folder, "back", (-1.4, 1.5, 13.0), (0, 0.98, 0), 72)
    shoot(cam, folder, "mid", (11.4, 1.3, -13.0), (10, 0.98, 0), 72)
    shoot(cam, folder, "far", (21.4, 1.3, -13.0), (20, 0.98, 0), 72)
    for i, name in enumerate(LINEUP):
        x = (i - 3) * 0.95
        shoot(cam, folder, f"bust_{name}", (x + 0.4, 1.66, -2.3), (x, 1.56, 0), 105)
    shoot(cam, folder, "head", (-2.6, 1.74, -1.0), (-2.85, 1.71, 0), 105)
    shoot(cam, folder, "fp", (-7.2, 0.8, -1.6), (-7.8, 0.3, 0), 85)


def main():
    clear_scene()
    PREVIEW_TINT[0] = (0.48, 0.27, 0.17)
    made = build()
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--preview" in args:
        preview(args[args.index("--preview") + 1], made)
    SOURCE.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "rebels.blend"))
    print("[rebels] done", flush=True)


main()
