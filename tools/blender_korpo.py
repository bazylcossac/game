"""Builds Korpo's machines for Corp Wars: robots in black suits, white shirts and ties.

Run:  blender --background --factory-startup --python tools/blender_korpo.py [-- --preview DIR]

The look: a corporation that replaced its staff with machines and dressed them for the office.
Below the collar it is a tailored suit. Above it nothing pretends to be a person: gunmetal plates
over a black skull, a hooded slot where the eyes would be with two red lights in it, and a row of
steel teeth between the face and the jaw. The hands are jointed machine hands, the neck a ringed
column. Nothing on them is bright but the eyes.

Everything hangs on the skeleton from blender_char. A body is one skinned mesh at each of three
levels of detail; heads and each class's fittings are meshes of their own on the same bones.
The tie, and the stripe over the head that repeats its colour, are painted per class in the game.

  korpo.glb       Body_Reg  the employee's suit        Body_Cmd  the headhunter's long coat
                  Head_*    one per class              Gear_*    what a class carries on its back
  korpo_big.glb   Body_Big  the liquidator: a suit stretched over armour, its forearms a laser
                  cannon (right) and a two-rocket pod (left)      Head_Big
  korpo_fp.glb    the hands, sleeves and weapon arms as their owner sees them
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_char import *  # noqa: E402,F403

SUIT, SATIN, SHIRT, SHELL, CARBON, CHROME, SHOE, TIE, EYE, SOLE, GOLD, GUN, WARN, GLASS, CROSS, HAZARD = (
    "Suit", "Satin", "Shirt", "Shell", "Carbon", "Chrome", "Shoe", "Tie", "Eye", "Sole", "Gold", "Gun", "Warn", "Lens", "Cross", "Hazard")
PALETTE.update({
    SUIT: ((0.012, 0.012, 0.015), "suit"), SATIN: ((0.005, 0.005, 0.007), "satin"), SHIRT: ((0.5, 0.5, 0.5), "cloth"),
    SHELL: ((0.075, 0.078, 0.088), "paint"), CARBON: ((0.01, 0.01, 0.012), "paint"), CHROME: ((0.3, 0.31, 0.34), "metal"),
    SHOE: ((0.007, 0.007, 0.008), "ceramic"), TIE: ((0.92, 0.92, 0.92), "tint"), EYE: ((1.0, 0.1, 0.06), "glow"),
    SOLE: ((0.012, 0.012, 0.013), "rubber"), GOLD: ((0.78, 0.52, 0.16), "metal"), GUN: ((0.06, 0.062, 0.07), "paint"),
    WARN: ((0.62, 0.04, 0.025), "paint"), GLASS: ((0.01, 0.012, 0.016), "glass"), CROSS: ((0.1, 1.0, 0.3), "lamp"),
    HAZARD: ((0.9, 0.9, 0.9), "tint"),
})
SX = 0.19
SX_BIG = 0.245


def tag(side):
    return "R" if side > 0 else "L"


# ---------------------------------------------------------------- the suit

def crease(a, t):
    """The pressed line down the front of a trouser leg, and a fainter one behind."""
    return 0.0035 * (bump(wrap_angle(a, 270.0), 0.0, 13.0) + 0.6 * bump(wrap_angle(a, 90.0), 0.0, 13.0))


def leg(body, side, k=1.0):
    with bound("leg_r" if side > 0 else "leg_l"):
        f = Form([(1.0, 0.08 * k, 0.1 * k), (0.9, 0.092 * k, 0.108 * k, 0.004, 0), (0.78, 0.088 * k, 0.102 * k, 0.002, 0), (0.62, 0.077 * k, 0.089 * k),
                  (0.5, 0.068 * k, 0.08 * k), (0.45, 0.066 * k, 0.078 * k, 0, -0.004), (0.4, 0.064 * k, 0.076 * k), (0.28, 0.061 * k, 0.074 * k, 0, 0.004),
                  (0.15, 0.058 * k, 0.07 * k), (0.066, 0.058 * k, 0.074 * k, 0, -0.005)],
                 2.2, origin=(side * 0.1, 0, 0), side=side, relief=crease)
        f.mesh(body, "Trouser", SUIT, 16, 0.045)


def shoe(body, side, k=1.0):
    """An oxford: a low glossy upper on a thin sole, with a stacked heel."""
    with bound(f"Boot_{tag(side)}"):
        f = Form([(0.078, 0.026 * k, 0.028, 0, 0.04), (0.058, 0.04 * k, 0.039, 0, 0.05), (0.02, 0.046 * k, 0.046, 0, 0.057), (-0.04, 0.048 * k, 0.038, 0, 0.049),
                  (-0.1, 0.05 * k, 0.029, 0, 0.04), (-0.16, 0.047 * k, 0.023, 0, 0.034), (-0.2, 0.036 * k, 0.019, 0, 0.03), (-0.224, 0.014 * k, 0.011, 0, 0.025)],
                 (2.9, 2.0), axis="z", origin=(side * 0.1, 0, 0), side=side)
        f.mesh(body, "Shoe", SHOE, 12, 0.03)
        with at(side * 0.1, 0, 0):
            plan = [(0.03 * k, 0.084), (0.045 * k, 0.05), (0.051 * k, -0.02), (0.055 * k, -0.1), (0.051 * k, -0.17), (0.037 * k, -0.214), (0.013 * k, -0.232)]
            plan = plan + [(-x, z) for x, z in reversed(plan)]
            slab(body, "Sole", plan, 0.0, 0.013, SOLE, 0.0, "xz")
            if fine(1):
                heel = [(0.03 * k, 0.086), (0.046 * k, 0.05), (0.047 * k, 0.012), (-0.047 * k, 0.012), (-0.046 * k, 0.05), (-0.03 * k, 0.086)]
                slab(body, "Heel", heel, 0.0, 0.026, SOLE, 0.0, "xz")
        if fine(0):
            # The cap seam across the toe, and three laces over the instep.
            f.strap(body, "Toe seam", SOLE, [(20, -0.156), (90, -0.156), (160, -0.156)], 0.004, 0.0012, 0.0, 0.02)
            for z in (-0.075, -0.052, -0.029):
                f.strap(body, "Lace", SOLE, [(52, z), (90, z), (128, z)], 0.005, 0.003, 0.0, 0.02)


def trunk_form(w=1.0, d=1.0, hem=0.83):
    """The jacket: square shoulders, a chest, a taken-in waist, and a skirt that flares to the hem."""
    st = [(1.0, 0.154 * w, 0.108 * d), (1.06, 0.15 * w, 0.106 * d), (1.18, 0.165 * w, 0.115 * d, 0, -0.003), (1.3, 0.182 * w, 0.124 * d, 0, -0.006),
          (1.4, 0.19 * w, 0.123 * d, 0, -0.004), (1.47, 0.193 * w, 0.116 * d), (1.52, 0.19 * w, 0.106 * d, 0, 0.002), (1.55, 0.176 * w, 0.096 * d, 0, 0.004),
          (1.572, 0.13 * w, 0.082, 0, 0.006), (1.59, 0.076, 0.068, 0, 0.008), (1.602, 0.058, 0.06, 0, 0.008)]
    if hem < 0.7:
        st = [(hem, 0.196 * w, 0.148 * d), (0.66, 0.186 * w, 0.138 * d), (0.82, 0.172 * w, 0.126 * d), (0.9, 0.166 * w, 0.12 * d)] + st
    else:
        st = [(hem, 0.17 * w, 0.124 * d), (0.9, 0.166 * w, 0.12 * d)] + st
    return Form(st, (2.5, 2.3))


def shirt_and_tie(body, j, w=1.0, drop=0.0):
    """What shows in the V of a jacket: the shirt, the lapels along its edges, and the tie, whose
    colour is the class's and is set in the game. `drop` lowers the bottom of the V."""
    low = 1.25 - drop
    with unshaded():
        j.patch(body, "Shirt front", SHIRT, [(0.0, low - 0.002), (0.072, 1.585), (-0.072, 1.585)], "front", 0.002, 0.0, 0.03, 0.0)
    for s in (1, -1):
        lapel = [(0.002, low), (0.05 * w, 1.33), (0.088 * w, 1.42), (0.124 * w, 1.49), (0.101 * w, 1.503), (0.13 * w, 1.535), (0.112, 1.566), (0.074, 1.584),
                 (0.06, 1.56), (0.03, 1.4), (0.002, low + 0.028)]
        j.patch(body, "Lapel", SATIN, [(s * x, y) for x, y in lapel], "front", pick(0.008, 0.008, 0.012), 0.001, 0.03, 0.004)
        if fine(1):
            j.patch(body, "Collar point", SHIRT, [(s * 0.008, 1.574), (s * 0.058, 1.582), (s * 0.036, 1.526)], "front", 0.006, 0.003, 0.03, 0.0)
    with unshaded():
        j.patch(body, "Tie knot", TIE, [(-0.019, 1.566), (0.019, 1.566), (0.013, 1.534), (-0.013, 1.534)], "front", 0.012, 0.004, 0.03, 0.003)
        j.patch(body, "Tie blade", TIE, [(-0.012, 1.536), (0.012, 1.536), (0.031, 1.33 - drop * 0.5), (0.0, 1.29 - drop * 0.5), (-0.031, 1.33 - drop * 0.5)],
                "front", 0.006, 0.004, 0.03, 0.003)
    if fine(0):
        j.patch(body, "Tie clip", CHROME, [(-0.034, 1.414), (0.034, 1.414), (0.034, 1.406), (-0.034, 1.406)], "front", 0.003, 0.01, 0.03, 0.0)


def neck(body, k=1.0):
    """Shirt collar, and the ringed neck of the machine rising out of it."""
    collar = Form([(1.552, 0.07 * k, 0.068 * k, 0, 0.008), (1.6, 0.06 * k, 0.06 * k, 0, 0.008), (1.626, 0.056 * k, 0.056 * k, 0, 0.008)], 2.2)
    collar.mesh(body, "Collar", SHIRT, 14, 0.04)
    column = Form([(1.6, 0.041 * k, 0.041 * k, 0, 0.012), (1.7, 0.038 * k, 0.038 * k, 0, 0.012)], 2.0)
    column.mesh(body, "Neck", CARBON, 10, 0.03)
    if fine(0):
        for y in (1.638, 1.654, 1.67):
            column.band(body, "Neck ring", CHROME, y - 0.004, y + 0.004, 0.003, 0.0, 10)


def jacket(body, w=1.0, d=1.0):
    with bound("torso"):
        seat = Form([(0.8, 0.1 * w, 0.085 * d), (0.84, 0.162 * w, 0.112 * d), (0.92, 0.166 * w, 0.116 * d), (1.02, 0.155 * w, 0.108 * d)], 2.3)
        seat.mesh(body, "Seat", SUIT, 14, 0.06)
        j = trunk_form(w, d)
        j.mesh(body, "Jacket", SUIT, 24, 0.04)
        shirt_and_tie(body, j, w)
        if fine(1):
            for y in (1.225, 1.125):
                j.stud(body, "Button", SATIN, FRONT, y, 0.011, 0.005, 0.0, 8)
            # The jacket parts below its lower button, and has a flap pocket at each hip.
            j.patch(body, "Cutaway", SATIN, [(0.0, 1.085), (0.03, 0.833), (-0.03, 0.833)], "front", 0.0015, 0.0, 0.05, 0.0)
            for s in (1, -1):
                j.patch(body, "Pocket flap", SUIT, [(s * 0.066 * w, 0.995), (s * 0.15 * w, 1.0), (s * 0.15 * w, 0.958), (s * 0.066 * w, 0.953)], "front", 0.005, 0.0, 0.04, 0.0)
            j.patch(body, "Breast welt", SATIN, [(-0.156 * w, 1.398), (-0.084 * w, 1.392), (-0.084 * w, 1.383), (-0.156 * w, 1.389)], "front", 0.003, 0.0, 0.04, 0.0)
        if fine(0):
            j.patch(body, "Pocket square", SHIRT, [(-0.152 * w, 1.396), (-0.137 * w, 1.418), (-0.121 * w, 1.402), (-0.104 * w, 1.414), (-0.09 * w, 1.392)],
                    "front", 0.004, 0.002, 0.04, 0.0)
            j.strap(body, "Back seam", SATIN, [(90, 1.5), (90, 1.2), (90, 0.835)], 0.004, 0.0012, 0.0, 0.08)
            # The company pin: one red light on the lapel.
            j.stud(body, "Pin", EYE, 270.0 - 36.0, 1.458, 0.007, 0.004, 0.009, 8)
        neck(body)
    return j


def sleeve_form(side, sx, k=1.0):
    return Form([(0.056, 0.008, 0.016, -0.044, 0), (0.044, 0.032 * k, 0.046 * k, -0.028, 0), (0.026, 0.052 * k, 0.062 * k, -0.012, 0), (-0.01, 0.061 * k, 0.068 * k, -0.002, 0),
                 (-0.07, 0.061 * k, 0.066 * k), (-0.18, 0.055 * k, 0.059 * k), (-0.29, 0.051 * k, 0.054 * k), (-0.4, 0.047 * k, 0.049 * k),
                 (-0.52, 0.043 * k, 0.045 * k), (-0.562, 0.042 * k, 0.044 * k)], 2.1, origin=(side * sx, 1.5, 0), side=side)


def arm(body, side, sx=SX, mat=SUIT):
    with bound("arm_r" if side > 0 else "arm_l"):
        f = sleeve_form(side, sx)
        f.mesh(body, "Sleeve", mat, 14, 0.04)
        if fine(0):
            for y in (-0.535, -0.515, -0.495):
                f.stud(body, "Sleeve button", SATIN, 62.0, y, 0.006, 0.003, 0.0, 6)
    with bound(f"Forearm_{tag(side)}"):
        cuff = Form([(-0.588, 0.036, 0.038), (-0.54, 0.037, 0.039)], 2.1, origin=(side * sx, 1.5, 0), side=side)
        cuff.mesh(body, "Cuff", SHIRT, 12, 0.05)
    robot_hand(body, side, (side * sx, 1.5 - UPPER_ARM - FOREARM, 0))


def robot_hand(part, side, wrist, size=1.0):
    """A machine hand closed round a grip: gunmetal segments on black joints. Built hanging from the
    wrist, palm toward the body, with the grip running front to back through the fist."""
    with bound(f"Hand_{tag(side)}"), at(*wrist):
        z = size
        tube(part, "Wrist", [(0, 0.012, 0), (0, -0.024 * z, 0)], 0.021 * z, CARBON, 8)
        palm = Form([(-0.1 * z, 0.01 * z, 0.036 * z, 0, -0.002), (-0.088 * z, 0.014 * z, 0.041 * z, 0, -0.002), (-0.05 * z, 0.015 * z, 0.039 * z, 0, -0.002),
                     (-0.018 * z, 0.013 * z, 0.027 * z)], 3.0, origin=(side * 0.004 * z, 0, 0), side=side)
        palm.mesh(part, "Palm", CARBON, 10, 0.04)
        if fine(1):
            palm.shell(part, "Back plate", SHELL, -62.0, 62.0, -0.092 * z, -0.028 * z, 0.004 * z, 0.0, 3, 2)
        cx, cy, reach = -0.024 * z, -0.103 * z, 0.0235 * z
        fingers = [(-0.031, 1.0, 0.0088), (-0.0105, 1.06, 0.009), (0.01, 1.0, 0.0086), (0.0295, 0.84, 0.0076)]
        if not fine(1):
            # Far away the fingers are two thick ones.
            fingers = [(-0.02, 1.03, 0.017), (0.02, 0.94, 0.016)]
        for fz, length, r in fingers:
            pts = [(side * (cx + reach * length * math.cos(math.radians(a))), cy + reach * length * math.sin(math.radians(a)), fz * z) for a in (28.0, -40.0, -110.0, -178.0)]
            if fine(0):
                tube(part, "Finger joint", pts, r * z * 0.78, CARBON, 6)
                for p, q in zip(pts, pts[1:]):
                    p, q = Vector(p), Vector(q)
                    tube(part, "Finger", [p.lerp(q, 0.13), p.lerp(q, 0.87)], r * z, SHELL, 6)
            else:
                tube(part, "Finger", pts, r * z, SHELL, pick(6, 5, 4))
        thumb = [(-0.002, -0.034, -0.036), (-0.016, -0.062, -0.05), (-0.034, -0.084, -0.043), (-0.045, -0.098, -0.024)]
        thumb = [(side * x * z, y * z, tz * z) for x, y, tz in thumb]
        if fine(0):
            tube(part, "Thumb joint", thumb, 0.0076 * z, CARBON, 6)
            for p, q in zip(thumb, thumb[1:]):
                p, q = Vector(p), Vector(q)
                tube(part, "Thumb", [p.lerp(q, 0.13), p.lerp(q, 0.87)], 0.0098 * z, SHELL, 6)
        else:
            tube(part, "Thumb", thumb, 0.0098 * z, SHELL, pick(6, 5, 4))


def body_reg(body="Body_Reg"):
    jacket(body)
    for side in (1, -1):
        leg(body, side)
        shoe(body, side)
        arm(body, side)


def body_cmd(body="Body_Cmd"):
    """The headhunter: a long belted coat to the knee, its collar turned up."""
    with bound("torso"):
        seat = Form([(0.8, 0.1, 0.085), (0.84, 0.162, 0.112), (0.92, 0.166, 0.116), (1.02, 0.155, 0.108)], 2.3)
        seat.mesh(body, "Seat", SUIT, 12, 0.08)
        j = trunk_form(1.03, 1.06, 0.5)
        j.mesh(body, "Coat", SUIT, 24, 0.045)
        shirt_and_tie(body, j, 1.0)
        # The coat hangs open below the belt: a dark parting down the front, and a vent behind.
        if fine(1):
            j.patch(body, "Parting", SATIN, [(0.0, 1.02), (0.034, 0.503), (-0.034, 0.503)], "front", 0.0015, 0.0, 0.06, 0.0)
            j.patch(body, "Vent", SATIN, [(0.0, 0.86), (0.014, 0.503), (-0.014, 0.503)], "back", 0.0015, 0.0, 0.06, 0.0)
        j.band(body, "Belt", SATIN, 1.03, 1.075, 0.005, 0.0, 24)
        if fine(1):
            j.patch(body, "Buckle", CHROME, [(-0.026, 1.082), (0.026, 1.082), (0.026, 1.024), (-0.026, 1.024)], "front", 0.004, 0.005, 0.04, 0.003)
            # Double-breasted: two columns of buttons.
            for y in (1.2, 1.13):
                for s in (1, -1):
                    j.stud(body, "Button", SATIN, 270.0 + s * 17.0, y, 0.011, 0.005, 0.0, 8)
            for s in (1, -1):
                j.patch(body, "Pocket flap", SUIT, [(s * 0.075, 0.93), (s * 0.165, 0.94), (s * 0.165, 0.89), (s * 0.075, 0.88)], "front", 0.005, 0.0, 0.04, 0.0)
                j.patch(body, "Shoulder tab", SUIT, [(s * 0.11, 1.556), (s * 0.186, 1.53), (s * 0.186, 1.5), (s * 0.11, 1.528)], "back", 0.005, 0.0, 0.04, 0.0)
        # The collar stands up round the neck and hides it from behind.
        stand = Form([(1.545, 0.118, 0.104, 0, 0.012), (1.6, 0.092, 0.088, 0, 0.014), (1.69, 0.088, 0.086, 0, 0.016)], 2.2)
        stand.shell(body, "Stand collar", SUIT, 0, 0, 0, 0, 0.007, 0.0, 12, 3,
                    lambda u, v: (-46.0 + 272.0 * u, 1.548 + (0.066 + 0.05 * math.sin(u * math.pi)) * v))
        neck(body)
    for side in (1, -1):
        leg(body, side)
        shoe(body, side)
        arm(body, side)
        if fine(1):
            f = sleeve_form(side, SX)
            with bound(f"Forearm_{tag(side)}"):
                f.band(body, "Sleeve strap", SATIN, -0.5, -0.47, 0.004, 0.0, 14)


# ---------------------------------------------------------------- heads

def skull(k=1.06, wide=1.0):
    st = [(0.03, 0.022 * wide, 0.03, 0, -0.016), (0.048, 0.042 * wide, 0.058, 0, -0.016), (0.085, 0.061 * wide, 0.081, 0, -0.006), (0.13, 0.073 * wide, 0.094, 0, 0.002),
          (0.18, 0.078, 0.1, 0, 0.006), (0.225, 0.074, 0.096, 0, 0.008), (0.255, 0.056, 0.074, 0, 0.008), (0.272, 0.028, 0.038, 0, 0.008),
          (0.2795, 0.003, 0.004, 0, 0.008)]
    return Form([tuple(v * k for v in s) for s in st], (2.5, 2.15), origin=(0, 1.56, 0))


def brow(a):
    """The lower edge of the cranium: a hard brow that dips to the middle, then falls away to the
    nape at the back."""
    front = abs(wrap_angle(a, 270.0))
    if front < 58.0:
        return 0.182 - 0.012 * (1 - front / 58.0) ** 1.4
    return 0.182 - 0.078 * smooth(58.0, 150.0, front)


def head(part, k=1.06, scanner=False, crown=None, jaw=1.0, visor=False, hat=False):
    """Gunmetal plates over a black skull. `scanner` puts a sighting unit over the right eye,
    `crown` a band of that material round the cranium, `visor` one bar of light in place of two
    eyes, `hat` a brimmed hat pulled low."""
    with bound("Head"):
        s = skull(k, jaw)
        s.mesh(part, "Skull", CARBON, 20, 0.03)
        top = 0.2793 * k

        def cranium(u, v):
            a = u * 360.0
            low = brow(a) * k
            return a, low + (top - low) * (1 - (1 - v) ** 1.6)

        s.band(part, "Cranium", SHELL, 0, 0, 0.006, 0.0, 24, pick(6, 3, 2), 0.004, warp=cranium)
        s.cap(part, "Crown", SHELL, top - 0.0004, 8, 0.0055)
        # A hood of plate over the eyes: they look out from under it.
        s.shell(part, "Brow", SHELL, 0, 0, 0, 0, lambda u, v: 0.007 + 0.011 * (1 - v), 0.0, 10, 2,
                lambda u, v: (270.0 + (u * 2 - 1) * 62.0, (brow(270.0 + (u * 2 - 1) * 62.0) - 0.003 + 0.026 * v) * k), 0.004)

        def half(t):
            return 30.0 * jaw + 38.0 * smooth(0.04, 0.15, t)

        def cheeks(u, v):
            w = u * 2 - 1
            high = 0.146 + 0.016 * abs(w) ** 1.5
            low = 0.1 + 0.03 * abs(w) ** 2
            t = low + (high - low) * v
            return 270.0 + w * half(t), t * k

        def mandible(u, v):
            w = u * 2 - 1
            high = 0.078 + 0.04 * abs(w) ** 2
            low = 0.044 + 0.07 * abs(w) ** 2.2
            t = low + (high - low) * v
            return 270.0 + w * half(t), t * k

        s.shell(part, "Face", SHELL, 0, 0, 0, 0, 0.006, 0.0, 12, 3, cheeks, 0.004)
        s.shell(part, "Jaw", SHELL, 0, 0, 0, 0, 0.007, 0.0, 12, 2, mandible, 0.004)
        if visor:
            s.shell(part, "Visor", EYE, 236.0, 304.0, 0.156 * k, 0.164 * k, 0.002, 0.0, 6, 1, None, 0.002)
        else:
            for side in (1, -1):
                # Slits that slant up to the outside.
                s.shell(part, "Eye", EYE, 0, 0, 0, 0, 0.002, 0.0, 2, 1,
                        lambda u, v, side=side: (270.0 + side * (11.0 + 21.0 * u), (0.153 + 0.008 * u + 0.008 * v) * k), 0.002)
        if fine(1):
            # Steel teeth in the gap between the face and the jaw.
            for i in range(-3, 4):
                a0, a1 = s.span(270.0 + i * 6.4, 0.09 * k, 0.0062)
                s.shell(part, "Tooth", CHROME, a0, a1, 0.072 * k, 0.106 * k, 0.003, 0.0, 1, 1, None, 0.002)
            # Hubs at the sides of the head, where ears would be, each with a status light.
            for side in (1, -1):
                hub = [(-0.02, 0.118), (0.012, 0.11), (0.03, 0.134), (0.022, 0.166), (-0.012, 0.174), (-0.03, 0.148)]
                face_of = "outer" if side > 0 else "inner"
                s.patch(part, "Hub", CARBON, [((z + 0.008) * k, y * k) for z, y in hub], face_of, 0.008, 0.0, 0.03, 0.003)
                s.patch(part, "Hub light", EYE, [(0.0, 0.136 * k), (0.016 * k, 0.136 * k), (0.016 * k, 0.148 * k), (0.0, 0.148 * k)], face_of, 0.002, 0.008, 0.03, 0.0)
        # The class's colour runs over the head from brow to nape.
        for path in ([(270, 0.176 * k), (270, 0.25 * k), (270, 0.279 * k)], [(90, 0.279 * k), (90, 0.24 * k), (90, 0.125 * k)]):
            s.strap(part, "Stripe", TIE, path, 0.014, 0.0015, pick(0.006, 0.008, 0.014), 0.035)
        if fine(0):
            for side in (1, -1):
                s.strap(part, "Cheek line", CARBON, [(270 + side * 52, 0.146 * k), (270 + side * 40, 0.1 * k), (270 + side * 24, 0.058 * k)], 0.0025, 0.001, 0.006, 0.02)
                s.strap(part, "Temple line", CARBON, [(270 + side * 62, 0.186 * k), (270 + side * 66, 0.23 * k), (270 + side * 80, 0.262 * k)], 0.0025, 0.001, 0.006, 0.02)
        if crown:
            s.band(part, "Band", crown, 0, 0, 0.004, pick(0.006, 0.008, 0.014), 24, 1, 0.004,
                   warp=lambda u, v: (u * 360.0, (brow(u * 360.0) + 0.006 + 0.014 * v) * k))
        if scanner:
            # A sighting unit bolted over the right eye: the auditor sees further than the rest.
            a = 270.0 + 23.0
            p = s.at(a, 0.164 * k, 0.012)
            n = s.normal(a, 0.164 * k)
            turn = Matrix.Rotation(math.atan2(n.x, -n.z) * -1.0, 3, "Y")
            block(part, "Scanner", CARBON, p + n * 0.012, (0.044, 0.03, 0.05), 0.004, turn)
            block(part, "Scanner eye", EYE, p + n * 0.038, (0.03, 0.016, 0.004), 0.0, turn)
            if fine(1):
                block(part, "Scanner rail", CHROME, p + n * 0.012 + Vector((0, 0.019, 0)), (0.03, 0.008, 0.04), 0.002, turn)
        if hat:
            # A brimmed hat pulled low: the eyes glow from under it.
            brim = Form([(0.214, 0.132, 0.146, 0, 0.004), (0.224, 0.136, 0.152, 0, 0.004), (0.232, 0.1, 0.11, 0, 0.006)], 2.0, origin=(0, 1.56, 0))
            brim.mesh(part, "Brim", SATIN, 20, 0.02)
            dome = Form([(0.226, 0.09, 0.104, 0, 0.008), (0.29, 0.084, 0.098, 0, 0.01), (0.318, 0.072, 0.088, 0, 0.012), (0.327, 0.05, 0.066, 0, 0.012)], 2.6, origin=(0, 1.56, 0))
            dome.mesh(part, "Hat", SUIT, 16, 0.03)
            dome.band(part, "Hat band", TIE, 0.232, 0.256, 0.002, 0.0, 16)
    return s


def head_big(part="Head_Big"):
    """The liquidator: the same machine with a heavier jaw, and one bar of light for eyes."""
    s = head(part, 1.0, jaw=1.14, visor=True)
    with bound("Head"):
        if fine(1):
            # Armour bolted over the cheeks.
            for side in (1, -1):
                s.shell(part, "Cheek guard", CARBON, 270 + side * 34, 270 + side * 76, 0.05, 0.13, 0.007, 0.006, 3, 3)


HEADS = {
    "Head_Reg": lambda p: head(p),
    "Head_Auditor": lambda p: head(p, scanner=True),
    "Head_Director": lambda p: head(p, crown=GOLD),
    "Head_Hat": lambda p: head(p, hat=True),
}


# ---------------------------------------------------------------- what the classes carry

def back_pack(part, j, name, y, w, h, depth, mat=CARBON):
    """A slim unit worn flat against the back of the jacket."""
    a0, a1 = j.span(BACK, y, w)
    return j.shell(part, name, mat, a0, a1, y - h / 2, y + h / 2, lambda u, v: depth * (0.6 + 0.4 * min(1.0, min(u, 1 - u, v, 1 - v) * 6)), 0.0, 5, 4)


def gear_hunter(part="Gear_hunter"):
    """The auditor: a sensor mast on a slim pack."""
    with bound("Torso"):
        j = trunk_form()
        back_pack(part, j, "Sensor pack", 1.33, 0.2, 0.24, 0.045)
        tube(part, "Mast", [(0.07, 1.42, 0.17), (0.085, 1.72, 0.2), (0.09, 1.9, 0.21)], [0.008, 0.006, 0.005], CHROME, 6)
        block(part, "Sensor", CARBON, (0.09, 1.93, 0.2), (0.07, 0.05, 0.03), 0.006)
        block(part, "Sensor eye", EYE, (0.09, 1.93, 0.183), (0.05, 0.012, 0.004), 0.0)
        if fine(1):
            j.strap(part, "Pack light", TIE, [(84, 1.4), (96, 1.4)], 0.012, 0.002, 0.047, 0.03)


def gear_marshal(part="Gear_marshal"):
    """The director: an uplink on the back and two aerials over the shoulders."""
    with bound("Torso"):
        j = trunk_form()
        back_pack(part, j, "Uplink", 1.33, 0.24, 0.28, 0.05)
        for side, height in ((1, 2.08), (-1, 1.82)):
            tube(part, "Aerial", [(side * 0.09, 1.44, 0.17), (side * 0.11, 1.7, 0.21), (side * 0.12, height, 0.25)], [0.006, 0.004, 0.003], CARBON, 5)
            block(part, "Aerial tip", EYE, (side * 0.12, height, 0.25), (0.012, 0.03, 0.012), 0.0)
        if fine(1):
            j.strap(part, "Gold line", GOLD, [(74, 1.44), (90, 1.45), (106, 1.44)], 0.01, 0.002, 0.052, 0.03)
            j.strap(part, "Pack light", TIE, [(84, 1.26), (96, 1.26)], 0.012, 0.002, 0.052, 0.03)


def gear_servicer(part="Gear_servicer"):
    """The servicer: a repair unit with two folded tool arms, and the green cross that says so."""
    with bound("Torso"):
        j = trunk_form()
        back_pack(part, j, "Repair unit", 1.31, 0.25, 0.32, 0.07)
        j.patch(part, "Cross", CROSS, [(-0.016, 1.26), (0.016, 1.26), (0.016, 1.294), (0.05, 1.294), (0.05, 1.326), (0.016, 1.326), (0.016, 1.36),
                                       (-0.016, 1.36), (-0.016, 1.326), (-0.05, 1.326), (-0.05, 1.294), (-0.016, 1.294)], "back", 0.003, pick(0.071, 0.073, 0.08), 0.06, 0.0)
        for side in (1, -1):
            # Two tool arms, folded down the sides of the unit until something needs mending.
            tube(part, "Tool arm", [(side * 0.118, 1.45, 0.2), (side * 0.132, 1.3, 0.205), (side * 0.122, 1.19, 0.2)], [0.012, 0.011, 0.009], CHROME, 6)
            block(part, "Tool head", CARBON, (side * 0.12, 1.172, 0.198), (0.03, 0.045, 0.03), 0.004)
            if fine(1):
                block(part, "Tool light", CROSS, (side * 0.12, 1.146, 0.198), (0.014, 0.008, 0.014), 0.0)


def gear_tech(part="Gear_tech"):
    """The technician: a tool case on the back with a hazard stripe, and a cutter on the hip."""
    with bound("Torso"):
        j = trunk_form()
        back_pack(part, j, "Tool case", 1.3, 0.27, 0.34, 0.085)
        for y in (1.2, 1.4):
            j.strap(part, "Hazard", HAZARD, [(72, y), (90, y + 0.004), (108, y)], 0.022, 0.002, 0.086, 0.03)
        if fine(1):
            tube(part, "Handle", [(-0.05, 1.47, 0.2), (-0.05, 1.5, 0.215), (0.05, 1.5, 0.215), (0.05, 1.47, 0.2)], 0.007, CHROME, 5)
    with bound("Pelvis"):
        if fine(1):
            block(part, "Cutter", CARBON, (0.185, 0.98, 0.03), (0.035, 0.14, 0.06), 0.006)
            block(part, "Cutter tip", HAZARD, (0.185, 0.9, 0.03), (0.022, 0.03, 0.03), 0.004)


GEARS = {"Gear_hunter": gear_hunter, "Gear_marshal": gear_marshal, "Gear_servicer": gear_servicer, "Gear_tech": gear_tech}


# ---------------------------------------------------------------- the liquidator

def cannon(part, along):
    """A laser cannon where a forearm should be. `along` maps (across, out, length) to the part's
    space, so the same arm is built for the body (down the arm) and for first person (ahead)."""
    def P(x, y, l):
        return along(x, y, l)
    n = 12
    tube(part, "Housing", [P(0, 0, -0.02), P(0, 0, 0.02), P(0, 0, 0.34), P(0, 0, 0.37)], [0.058, 0.072, 0.072, 0.05], GUN, n)
    for l in (0.07, 0.15, 0.23, 0.31):
        tube(part, "Cooling fin", [P(0, 0, l), P(0, 0, l + 0.016)], 0.083, CHROME, n)
    if fine(1):
        for l in (0.108, 0.188, 0.268):
            tube(part, "Coil", [P(0, 0, l), P(0, 0, l + 0.014)], 0.075, EYE, n)
    tube(part, "Barrel", [P(0, 0, 0.36), P(0, 0, 0.5)], 0.037, CARBON, 10)
    tube(part, "Muzzle ring", [P(0, 0, 0.468), P(0, 0, 0.512)], [0.046, 0.043], CHROME, 10)
    tube(part, "Bore", [P(0, 0, 0.509), P(0, 0, 0.514)], 0.026, EYE, 8)
    if fine(1):
        tube(part, "Top rail", [P(0, 0.078, 0.03), P(0, 0.078, 0.33)], 0.014, CARBON, 4)
        tube(part, "Sensor", [P(0.052, 0.058, 0.29), P(0.052, 0.058, 0.36)], 0.011, EYE, 6)
        tube(part, "Feed cable", [P(-0.06, 0.02, -0.02), P(-0.08, 0.025, 0.12), P(-0.072, 0.03, 0.3)], 0.011, SOLE, 5)


def pod(part, along, rounds_part=None):
    """A launcher bolted along a forearm: one housing, two tubes, the warheads showing red."""
    def P(x, y, l):
        return along(x, y, l)
    tube(part, "Pod mount", [P(0, 0, -0.02), P(0, 0, 0.02), P(0, 0, 0.3)], [0.05, 0.062, 0.058], GUN, 10)
    c = 0.022
    rings = []
    for l, grow in ((-0.03, -0.012), (-0.01, 0.0), (0.385, 0.0), (0.4, -0.01)):
        w, lo, hi = 0.104 + grow, 0.018 - grow, 0.124 + grow
        rings.append([P(-w + c, lo, l), P(w - c, lo, l), P(w, lo + c, l), P(w, hi - c, l), P(w - c, hi, l), P(-w + c, hi, l), P(-w, hi - c, l), P(-w, lo + c, l)])
    loft(part, "Pod housing", rings, GUN)
    for x in (-0.05, 0.05):
        tube(part, "Tube lip", [P(x, 0.071, 0.39), P(x, 0.071, 0.416)], [0.045, 0.042], CHROME, 10)
        tube(part, "Tube mouth", [P(x, 0.071, 0.4), P(x, 0.071, 0.418)], 0.036, SOLE, 10)
        target = rounds_part or part
        tube(target, "Warhead", [P(x, 0.071, 0.34), P(x, 0.071, 0.405), P(x, 0.071, 0.434), P(x, 0.071, 0.446)], [0.03, 0.03, 0.024, 0.007], WARN, 8)
    if fine(1):
        for l in (0.09, 0.25):
            tube(part, "Strap", [P(0, 0.0, l - 0.012), P(0, 0.0, l + 0.012)], 0.066, CHROME, 10)
        for l in (0.06, 0.2, 0.34):
            rings = [[P(-0.09, 0.124, l), P(0.09, 0.124, l), P(0.09, 0.13, l), P(-0.09, 0.13, l)], [P(-0.09, 0.124, l + 0.02), P(0.09, 0.124, l + 0.02), P(0.09, 0.13, l + 0.02), P(-0.09, 0.13, l + 0.02)]]
            loft(part, "Rib", rings, CHROME)
        tube(part, "Lock light", [P(0.0, 0.129, 0.3), P(0.0, 0.134, 0.3)], 0.01, EYE, 6)


def body_big(body="Body_Big"):
    """A suit stretched over armour: a barrel chest, a short thick neck, and weapons for forearms."""
    w, d, k = 1.2, 1.2, 1.12
    with bound("torso"):
        seat = Form([(0.8, 0.11, 0.095), (0.84, 0.18, 0.124), (0.92, 0.186, 0.13), (1.02, 0.178, 0.124)], 2.3)
        seat.mesh(body, "Seat", SUIT, 14, 0.06)
        j = Form([(0.815, 0.2, 0.142), (0.9, 0.196, 0.14), (1.0, 0.19, 0.134), (1.06, 0.188, 0.134), (1.18, 0.206, 0.146, 0, -0.004), (1.3, 0.228, 0.158, 0, -0.008),
                  (1.4, 0.24, 0.156, 0, -0.006), (1.47, 0.244, 0.146), (1.515, 0.238, 0.13, 0, 0.002), (1.548, 0.212, 0.112, 0, 0.004),
                  (1.572, 0.15, 0.092, 0, 0.006), (1.592, 0.088, 0.078, 0, 0.008), (1.604, 0.07, 0.07, 0, 0.008)], (2.6, 2.4))
        j.mesh(body, "Jacket", SUIT, 24, 0.04)
        shirt_and_tie(body, j, 1.16)
        if fine(1):
            for y in (1.225, 1.125):
                j.stud(body, "Button", SATIN, FRONT, y, 0.012, 0.005, 0.0, 8)
            j.patch(body, "Cutaway", SATIN, [(0.0, 1.085), (0.034, 0.818), (-0.034, 0.818)], "front", 0.0015, 0.0, 0.05, 0.0)
            for s in (1, -1):
                j.patch(body, "Pocket flap", SUIT, [(s * 0.08, 0.995), (s * 0.176, 1.0), (s * 0.176, 0.958), (s * 0.08, 0.953)], "front", 0.005, 0.0, 0.04, 0.0)
            # The armour shows through where the suit has split: plates at the shoulders.
            for s in (1, -1):
                j.patch(body, "Shoulder plate", CARBON, [(s * 0.13, 1.57), (s * 0.236, 1.545), (s * 0.236, 1.47), (s * 0.15, 1.5)], "back", 0.008, 0.0, 0.04, 0.003)
        if fine(0):
            j.strap(body, "Back seam", SATIN, [(90, 1.5), (90, 1.2), (90, 0.82)], 0.004, 0.0012, 0.0, 0.08)
            j.stud(body, "Pin", EYE, 270.0 - 36.0, 1.458, 0.008, 0.004, 0.009, 8)
        neck(body, 1.22)
    for side in (1, -1):
        leg(body, side, k)
        shoe(body, side, 1.1)
        with bound("arm_r" if side > 0 else "arm_l"):
            f = Form([(0.046, 0.01, 0.02, -0.046, 0), (0.032, 0.04, 0.056, -0.03, 0), (0.014, 0.064, 0.074, -0.014, 0), (-0.018, 0.078, 0.082, -0.002, 0),
                      (-0.08, 0.078, 0.08), (-0.18, 0.072, 0.074), (-0.26, 0.07, 0.072), (-0.3, 0.072, 0.074)], 2.1, origin=(side * SX_BIG, 1.5, 0), side=side)
            f.mesh(body, "Sleeve", SUIT, 14, 0.04, -0.3, 0.046)
        with bound(f"Forearm_{tag(side)}"):
            # The sleeve ends in a steel collar at the elbow, where the weapon is bolted on.
            f.band(body, "Elbow collar", CHROME, -0.305, -0.272, 0.006, 0.0, 14)
            elbow = Vector((side * SX_BIG, 1.5 - UPPER_ARM, 0))
            down = lambda x, y, l, e=elbow: (e.x + x, e.y - l - 0.05, e.z - y)
            (cannon if side > 0 else pod)(body, down)


# ---------------------------------------------------------------- first person

def first_person():
    """What the owner sees. The forearm is one metre long so the game can stretch it from wrist to
    elbow; the hand is turned to the frame the viewmodel poses it in: grip upright, fingers ahead."""
    with bound("Torso"):
        sleeve = Form([(0.07, 0.046, 0.048), (0.2, 0.05, 0.052), (0.6, 0.054, 0.056), (1.0, 0.058, 0.06)], 2.1)
        sleeve.mesh("FP_Arm_D", "Sleeve", SUIT, 14, 0.2)
        cuff = Form([(-0.01, 0.039, 0.041), (0.1, 0.04, 0.042)], 2.1)
        cuff.mesh("FP_Arm_D", "Cuff", SHIRT, 14, 0.2)
        tube("FP_Arm_D", "Wrist", [(0, -0.05, 0), (0, 0.02, 0)], 0.022, CARBON, 8)
    robot_hand("FP_Glove_D", 1, (0, 0, 0))
    remap("FP_Glove_D", fist_frame)
    ahead = lambda x, y, l: (x, y, -l + 0.12)
    with bound("Torso"):
        cannon("FP_ArmCannon", ahead)
        pod("FP_ArmPod", ahead, "FP_ArmPod_Cell")
        for part in ("FP_ArmCannon", "FP_ArmPod"):
            tube(part, "Sleeve", [(0, 0, 0.16), (0, 0, 0.7)], 0.07, SUIT, 12)
            tube(part, "Elbow collar", [(0, 0, 0.12), (0, 0, 0.17)], 0.076, CHROME, 12)


def fist_frame(p):
    """From a hand hanging at the wrist to the viewmodel's fist: the grip stands upright through
    the origin, the fingers wrap forward round it and the thumb sits on top."""
    return Vector((p.x + 0.024, -p.z, p.y + 0.103))


# ---------------------------------------------------------------- the files

def build_set(names):
    made = {}
    counts = {}
    for level in (0, 1, 2):
        set_lod(level)
        for name, fn in names:
            fn(name)
            obj = finish(name)
            made[obj.name] = obj
            counts[obj.name] = triangles(obj)
    rig = armature("Rig")
    for obj in made.values():
        skin(obj, rig)
    print("[korpo] triangles", counts, flush=True)
    return made, rig


def build():
    set_joints(SX)
    made, rig = build_set([("Body_Reg", body_reg), ("Body_Cmd", body_cmd)] + list(HEADS.items()) + list(GEARS.items()))
    export(OUT / "korpo.glb", list(made.values()), rig)
    set_joints(SX_BIG)
    big, big_rig = build_set([("Body_Big", body_big), ("Head_Big", head_big)])
    export(OUT / "korpo_big.glb", list(big.values()), big_rig)
    set_joints(SX)
    set_lod(0)
    first_person()
    fp = [finish(name) for name in ("FP_Arm_D", "FP_Glove_D", "FP_ArmCannon", "FP_ArmPod", "FP_ArmPod_Cell")]
    export(OUT / "korpo_fp.glb", fp)
    made.update(big)
    made.update({obj.name: obj for obj in fp})
    return made


LINEUP = [("Body_Reg", "Head_Reg", None), ("Body_Reg", "Head_Auditor", "Gear_hunter"), ("Body_Big", "Head_Big", None), ("Body_Reg", "Head_Reg", "Gear_servicer"),
          ("Body_Reg", "Head_Director", "Gear_marshal"), ("Body_Reg", "Head_Reg", "Gear_tech"), ("Body_Cmd", "Head_Hat", None)]


def preview(folder, made):
    cam = studio(1900, 900)
    for level in (0, 1, 2):
        for i, names in enumerate(LINEUP):
            for name in names:
                if name:
                    stand(made[f"{name}_L{level}"], (i - 3) * 0.95 + level * 10.0)
    for i, name in enumerate(("FP_Arm_D", "FP_Glove_D", "FP_ArmCannon", "FP_ArmPod", "FP_ArmPod_Cell")):
        stand(made[name + "_L0"], -8.0 + (0.0, 0.35, 0.8, 1.3, 1.3)[i])
    for obj in made.values():
        obj.hide_render = True
    shoot(cam, folder, "front", (1.4, 1.3, -13.0), (0, 0.98, 0), 72)
    shoot(cam, folder, "back", (-1.4, 1.5, 13.0), (0, 0.98, 0), 72)
    shoot(cam, folder, "mid", (11.4, 1.3, -13.0), (10, 0.98, 0), 72)
    shoot(cam, folder, "far", (21.4, 1.3, -13.0), (20, 0.98, 0), 72)
    shoot(cam, folder, "bust_reg", (-2.5, 1.62, -2.3), (-2.85, 1.5, 0), 105)
    shoot(cam, folder, "bust_aud", (-1.6, 1.66, -2.2), (-1.9, 1.56, 0), 105)
    shoot(cam, folder, "bust_big", (-0.6, 1.66, -2.6), (-0.95, 1.5, 0), 105)
    shoot(cam, folder, "bust_cmd", (3.2, 1.66, -2.4), (2.85, 1.52, 0), 105)
    shoot(cam, folder, "head", (-2.6, 1.74, -1.0), (-2.85, 1.71, 0), 105)
    shoot(cam, folder, "hand", (-2.3, 1.0, -0.8), (-2.66, 0.86, 0), 105)
    shoot(cam, folder, "fp", (-6.6, 0.9, -2.4), (-7.3, 0.25, 0), 85)


def main():
    clear_scene()
    PREVIEW_TINT[0] = (0.02, 0.06, 0.5)
    made = build()
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--preview" in args:
        preview(args[args.index("--preview") + 1], made)
    SOURCE.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "korpo.blend"))
    print("[korpo] done", flush=True)


main()
