"""Builds the Iron Empire's machines: three separate robot frames for the game.

Run:  blender --background --factory-startup --python tools/blender_droids.py [-- --preview DIR]

Every frame hangs on the same procedural skeleton as the human soldiers, so each part is modelled
around its joint, in Godot metres (+Y up, -Z forward). Joints: pelvis .95 above the ground, torso
.08 above that, head .53 above the torso, shoulders at (+-.28, .47), upper arm .29, forearm .28,
hips at (+-.1, -.05), thigh .45, shin .45.

  Reg  line droid: a bare mechanical skeleton of struts and rams under a few bolted plates.
  Big  heavy droid: slab armour on thick limbs, a head sunk between the shoulders.
  Cmd  commando droid: a smooth, dark, close-fitting shell with a split visor.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_kit import *  # noqa: E402,F403

OUT = ROOT / "assets/models/armory"
CORE, LENS, CABLE, METAL = "EnergyIndicator", "Glass", "Rubber", "DroidMetal"
FRAMES = {
    "Reg": {"plate": (0.5, 0.48, 0.42), "plate2": (0.23, 0.23, 0.22), "frame": (0.07, 0.07, 0.075)},
    "Big": {"plate": (0.15, 0.16, 0.17), "plate2": (0.26, 0.04, 0.03), "frame": (0.035, 0.035, 0.04)},
    "Cmd": {"plate": (0.06, 0.065, 0.08), "plate2": (0.2, 0.05, 0.04), "frame": (0.02, 0.02, 0.024)},
}
PALETTE.update({
    CORE: ((1.0, 0.25, 0.12), 0, 0.4, 4), LENS: ((0.02, 0.02, 0.03), 0.5, 0.08, 0), CABLE: ((0.012, 0.012, 0.014), 0, 0.8, 0),
    METAL: ((0.42, 0.43, 0.45), 0.9, 0.34, 0), "_Worn": ((1, 0, 1), 0, 1, 0),
})
for label, colours in FRAMES.items():
    PALETTE[f"DroidPlate_{label}"] = (colours["plate"], 0.25, 0.46, 0)
    PALETTE[f"DroidPlate2_{label}"] = (colours["plate2"], 0.3, 0.5, 0)
    PALETTE[f"DroidFrame_{label}"] = (colours["frame"], 0.7, 0.45, 0)


def ring_y(y, w, d, cut, cz=0.0, cx=0.0):
    """A chamfered eight-sided section lying flat, for armour built up the body."""
    return [(cx + w - cut, y, cz - d), (cx + w, y, cz - d + cut), (cx + w, y, cz + d - cut), (cx + w - cut, y, cz + d),
            (cx - w + cut, y, cz + d), (cx - w, y, cz + d - cut), (cx - w, y, cz - d + cut), (cx - w + cut, y, cz - d)]


def block(part, name, stations, mat, bevel=0.004, cx=0.0, level=0):
    """Hard armour built from sections: [(y, half_w, half_d, cut[, cz]), ...]."""
    rings = [ring_y(s[0], s[1], s[2], s[3], s[4] if len(s) > 4 else 0.0, cx) for s in stations]
    obj = sculpt(part, name, rings, mat, tuple(range(8)), level=level, bevel=0.0)
    worn_chamfer(obj, bevel, 22.0)
    return obj


def strut(part, a, b, r, mat, sides=8):
    return tube(part, "Strut", [a, b], r, mat, sides)


def ram(part, a, b, r):
    """A hydraulic ram: fat cylinder from `a`, a bright rod running on to `b`."""
    mid = tuple(Vector(a).lerp(Vector(b), 0.58))
    tube(part, "Ram body", [a, mid], r, f"DroidFrame_{part[:3]}", 8)
    tube(part, "Ram rod", [mid, b], r * 0.5, METAL, 8)


def joint(part, pos, r, label):
    """A ball joint, slightly squashed like a machined bearing."""
    x, y, z = pos
    stations = [(y - r, 0.0, 0.0), (y - r * 0.8, r * 0.6, r * 0.6), (y - r * 0.3, r * 0.96, r * 0.96), (y + r * 0.3, r * 0.96, r * 0.96), (y + r * 0.8, r * 0.6, r * 0.6), (y + r, 0.0, 0.0)]
    upright(part, "Joint", stations, f"DroidFrame_{label}", 12, x, z)
    upright(part, "Joint band", [(y - r * 0.12, r * 1.02, r * 1.02), (y + r * 0.12, r * 1.02, r * 1.02)], METAL, 12, x, z)


def bolts(part, xs, y, z, r=0.007):
    for x in xs:
        turned(part, "Bolt", [(z, r), (z - 0.004, r), (z - 0.005, 0.0)], METAL, 6, x, y)


def cable(part, points, r=0.006):
    tube(part, "Cable", points, r, CABLE, 5)


def claw(part, label, size=1.0):
    """A three-fingered metal hand closed on a grip. The palm sits at the origin."""
    plate, frame = f"DroidPlate2_{label}", f"DroidFrame_{label}"
    block(part, "Palm", [(-0.048 * size, 0.03 * size, 0.026 * size, 0.008), (0.0, 0.036 * size, 0.032 * size, 0.01), (0.048 * size, 0.03 * size, 0.026 * size, 0.008)], plate, 0.002)
    for i in range(3):
        y = (-0.03 + i * 0.03) * size
        pts = [(0.03 * size, y, 0.014 * size), (0.05 * size, y, -0.016 * size), (0.04 * size, y, -0.046 * size), (0.014 * size, y, -0.058 * size), (-0.012 * size, y, -0.046 * size)]
        tube(part, "Finger", pts, 0.0095 * size, METAL, 6)
        for p in pts[1:4]:
            joint(part, p, 0.0125 * size, label)
    tube(part, "Thumb", [(-0.026 * size, 0.03 * size, 0.012 * size), (-0.044 * size, 0.04 * size, -0.018 * size), (-0.03 * size, 0.046 * size, -0.044 * size), (-0.006 * size, 0.046 * size, -0.054 * size)], 0.0105 * size, METAL, 6)
    joint(part, (-0.044 * size, 0.04 * size, -0.018 * size), 0.0135 * size, label)


# ---------------------------------------------------------------- line droid

def reg():
    L = "Reg"
    plate, plate2, frame = f"DroidPlate_{L}", f"DroidPlate2_{L}", f"DroidFrame_{L}"
    p = f"{L}_Pelvis"
    block(p, "Hip plate", [(-0.13, 0.05, 0.045, 0.016), (-0.07, 0.125, 0.08, 0.03), (0.03, 0.14, 0.085, 0.034), (0.07, 0.1, 0.07, 0.03)], plate2)
    block(p, "Belt", [(0.03, 0.146, 0.09, 0.03), (0.055, 0.146, 0.09, 0.03)], frame, 0.002)
    for side in (1, -1):
        joint(p, (side * 0.1, -0.05, 0), 0.055, L)
    strut(p, (0, 0.05, 0), (0, 0.13, 0), 0.03, METAL)

    t = f"{L}_Torso"
    strut(t, (0, -0.02, 0.0), (0, 0.5, 0.01), 0.026, frame)
    joint(t, (0, 0.03, 0), 0.05, L)
    # The rib cage stays open at the waist, showing the machinery that drives the body.
    for side in (1, -1):
        cable(t, [(side * 0.03, 0.03, -0.03), (side * 0.07, 0.09, -0.05), (side * 0.06, 0.16, -0.05)])
        cable(t, [(side * 0.03, 0.03, 0.03), (side * 0.08, 0.1, 0.05), (side * 0.07, 0.16, 0.05)], 0.008)
        ram(t, (side * 0.05, 0.03, 0), (side * 0.1, 0.17, 0), 0.016)
    block(t, "Chest", [(0.14, 0.11, 0.075, 0.03), (0.22, 0.17, 0.1, 0.044), (0.37, 0.2, 0.11, 0.054), (0.45, 0.14, 0.088, 0.04)], plate)
    block(t, "Sternum", [(0.2, 0.05, 0.022, 0.012, -0.11), (0.4, 0.06, 0.022, 0.012, -0.114)], plate2, 0.002)
    for i in range(4):
        y = 0.23 + i * 0.034
        for side in (1, -1):
            slab(t, "Vent", [(-0.112, y), (-0.112, y + 0.016), (-0.1, y + 0.016), (-0.1, y)], *sorted((side * 0.07, side * 0.15)), frame, 0)
    block(t, "Power pack", [(0.16, 0.11, 0.05, 0.02, 0.15), (0.42, 0.125, 0.056, 0.02, 0.15)], plate2)
    turned(t, "Pack lamp", [(0.205, 0.022), (0.21, 0.0)], CORE, 8, 0.0, 0.34)
    for side in (1, -1):
        upright(t, "Exhaust", [(0.38, 0.018, 0.018), (0.46, 0.018, 0.018)], METAL, 8, side * 0.07, 0.15)
    tube(t, "Yoke", [(-0.26, 0.47, 0), (0.26, 0.47, 0)], 0.032, frame, 8)
    block(t, "Collar", [(0.45, 0.09, 0.07, 0.024), (0.5, 0.06, 0.054, 0.018)], plate2)
    bolts(t, (-0.15, 0.15), 0.34, -0.112)
    profile(t, "Rank lamp", [(-0.112, 0.385), (-0.11, 0.385), (-0.11, 0.4), (-0.112, 0.4)], 0.05, CORE, 0)

    h = f"{L}_Head"
    joint(h, (0, 0.0, 0), 0.036, L)
    strut(h, (0, 0.0, 0), (0, 0.08, 0), 0.02, METAL)
    for side in (1, -1):
        ram(h, (side * 0.03, -0.03, 0.02), (side * 0.03, 0.07, 0.02), 0.009)
    # A low, wide sensor head, not a human face: three lenses in a raked housing.
    section(h, "Skull", [(0.13, 0.05, 0.04, 0.016), (0.03, 0.085, 0.052, 0.022), (-0.075, 0.088, 0.046, 0.02), (-0.12, 0.06, 0.026, 0.012)], plate, 0.003, 0.0, 0.105)
    section(h, "Brow", [(-0.03, 0.09, 0.012, 0.004), (-0.126, 0.066, 0.01, 0.004)], plate2, 0.002, 0.0, 0.146)
    turned(h, "Main lens", [(-0.11, 0.024), (-0.128, 0.024), (-0.13, 0.016), (-0.126, 0.0)], METAL, 12, 0.0, 0.103)
    turned(h, "Eye", [(-0.126, 0.014), (-0.1275, 0.0)], CORE, 10, 0.0, 0.103)
    for side in (1, -1):
        turned(h, "Side lens", [(-0.09, 0.012), (-0.112, 0.012), (-0.113, 0.0)], METAL, 8, side * 0.05, 0.1)
        turned(h, "Side eye", [(-0.1125, 0.007), (-0.1135, 0.0)], CORE, 8, side * 0.05, 0.1)
        slab(h, "Fin", [(0.06, 0.09), (0.1, 0.09), (0.15, 0.155), (0.11, 0.15)], *sorted((side * 0.082, side * 0.092)), plate2, 0.002)
    tube(h, "Aerial", [(0.05, 0.15, 0.08), (0.06, 0.26, 0.14)], 0.0035, CABLE, 5)

    a = f"{L}_UpperArm_R"
    joint(a, (0, 0, 0), 0.06, L)
    strut(a, (0, 0, 0), (0, -0.29, 0), 0.024, frame)
    ram(a, (0, -0.03, -0.04), (0, -0.25, -0.03), 0.014)
    block(a, "Shoulder plate", [(0.06, 0.05, 0.05, 0.016), (0.0, 0.075, 0.068, 0.022), (-0.11, 0.056, 0.055, 0.018)], plate)
    cable(a, [(-0.03, -0.03, 0.04), (-0.04, -0.17, 0.04), (-0.02, -0.29, 0.03)])

    f = f"{L}_Forearm_R"
    joint(f, (0, 0, 0), 0.044, L)
    strut(f, (0, 0, 0), (0, -0.26, 0), 0.022, METAL)
    block(f, "Guard", [(-0.04, 0.035, 0.03, 0.012), (-0.1, 0.05, 0.044, 0.016), (-0.22, 0.038, 0.034, 0.012)], plate)
    ram(f, (0.03, -0.03, 0.026), (0.02, -0.25, 0.02), 0.01)
    with at(0, -0.325, -0.02):
        claw(f, L)
    strut(f, (0, -0.26, 0), (0, -0.28, -0.012), 0.018, frame)

    th = f"{L}_Thigh_R"
    joint(th, (0, 0, 0), 0.058, L)
    strut(th, (0, 0, 0), (0, -0.45, 0), 0.03, frame)
    ram(th, (0, -0.05, 0.05), (0, -0.4, 0.045), 0.018)
    block(th, "Thigh plate", [(-0.04, 0.06, 0.044, 0.016, -0.02), (-0.14, 0.074, 0.056, 0.02, -0.02), (-0.3, 0.054, 0.042, 0.016, -0.018)], plate)

    s = f"{L}_Shin_R"
    joint(s, (0, 0, 0), 0.054, L)
    block(s, "Knee cap", [(0.06, 0.04, 0.02, 0.01, -0.05), (-0.01, 0.056, 0.03, 0.012, -0.05), (-0.08, 0.04, 0.02, 0.01, -0.05)], plate2, 0.003)
    strut(s, (0, 0, 0), (0, -0.45, 0), 0.026, METAL)
    block(s, "Shin guard", [(-0.08, 0.05, 0.03, 0.012, -0.03), (-0.2, 0.056, 0.036, 0.014, -0.03), (-0.38, 0.04, 0.026, 0.01, -0.028)], plate)
    ram(s, (0, -0.06, 0.04), (0, -0.4, 0.05), 0.015)

    b = f"{L}_Boot_R"
    joint(b, (0, 0, 0), 0.05, L)
    block(b, "Instep", [(-0.1, 0.06, 0.13, 0.03, -0.07), (-0.06, 0.056, 0.125, 0.03, -0.07), (-0.02, 0.04, 0.07, 0.02, -0.03)], plate2)
    for side in (1, -1):
        block(b, "Toe", [(-0.102, 0.022, 0.05, 0.01, -0.21), (-0.062, 0.018, 0.04, 0.008, -0.2)], frame, 0.002, side * 0.034)
    block(b, "Heel", [(-0.102, 0.036, 0.04, 0.012, 0.05), (-0.05, 0.03, 0.03, 0.01, 0.04)], frame, 0.002)


# ---------------------------------------------------------------- heavy droid

def big():
    L = "Big"
    plate, plate2, frame = f"DroidPlate_{L}", f"DroidPlate2_{L}", f"DroidFrame_{L}"
    p = f"{L}_Pelvis"
    block(p, "Hip", [(-0.15, 0.08, 0.07, 0.02), (-0.08, 0.17, 0.11, 0.036), (0.05, 0.19, 0.12, 0.04), (0.11, 0.16, 0.1, 0.034)], plate)
    for side in (1, -1):
        joint(p, (side * 0.12, -0.05, 0), 0.075, L)
        block(p, "Tasset", [(0.04, 0.06, 0.09, 0.02, 0.0), (-0.14, 0.05, 0.08, 0.02, -0.01)], plate2, 0.004, side * 0.2)

    t = f"{L}_Torso"
    block(t, "Waist", [(-0.04, 0.15, 0.1, 0.04), (0.08, 0.17, 0.11, 0.04)], frame)
    block(t, "Hull", [(0.06, 0.2, 0.13, 0.05), (0.2, 0.28, 0.17, 0.07), (0.4, 0.32, 0.19, 0.08), (0.52, 0.27, 0.16, 0.07), (0.58, 0.14, 0.11, 0.04)], plate, 0.007)
    block(t, "Breast slab", [(0.16, 0.16, 0.03, 0.02, -0.17), (0.42, 0.22, 0.034, 0.024, -0.195), (0.5, 0.15, 0.026, 0.02, -0.17)], plate2, 0.006)
    for i in range(3):
        y = 0.22 + i * 0.07
        slab(t, "Armour rib", [(-0.232, y), (-0.232, y + 0.03), (-0.216, y + 0.03), (-0.216, y)], -0.17, 0.17, plate, 0.003)
    bolts(t, (-0.18, -0.09, 0.09, 0.18), 0.455, -0.226, 0.01)
    block(t, "Reactor", [(0.14, 0.17, 0.08, 0.03, 0.25), (0.46, 0.2, 0.095, 0.036, 0.26), (0.54, 0.13, 0.07, 0.03, 0.24)], plate2, 0.006)
    turned(t, "Reactor core", [(0.355, 0.05), (0.362, 0.05), (0.364, 0.0)], CORE, 12, 0.0, 0.3)
    turned(t, "Core ring", [(0.348, 0.062), (0.36, 0.062), (0.36, 0.052)], METAL, 14, 0.0, 0.3)
    for side in (1, -1):
        upright(t, "Stack", [(0.44, 0.03, 0.03), (0.68, 0.026, 0.026), (0.7, 0.032, 0.032), (0.74, 0.032, 0.032)], METAL, 10, side * 0.13, 0.3)
        cable(t, [(side * 0.17, 0.5, 0.17), (side * 0.25, 0.52, 0.06), (side * 0.27, 0.47, 0.0)], 0.012)

    h = f"{L}_Head"
    # Sunk between the shoulders behind a collar: a slab with one long visor.
    block(h, "Collar", [(-0.06, 0.15, 0.13, 0.04, 0.02), (0.1, 0.13, 0.12, 0.04, 0.04), (0.13, 0.1, 0.1, 0.03, 0.05)], plate, 0.005)
    block(h, "Skull", [(0.0, 0.094, 0.098, 0.03, -0.015), (0.09, 0.104, 0.108, 0.032, -0.02), (0.17, 0.08, 0.092, 0.03, -0.012), (0.2, 0.05, 0.06, 0.02, 0.0)], plate2, 0.005)
    section(h, "Visor", [(-0.112, 0.082, 0.016, 0.005), (-0.128, 0.076, 0.012, 0.004)], CORE, 0, 0.0, 0.082)
    block(h, "Brow", [(0.1, 0.09, 0.02, 0.008, -0.11), (0.122, 0.08, 0.018, 0.008, -0.106)], plate, 0.003)
    for side in (1, -1):
        block(h, "Jaw", [(-0.02, 0.022, 0.05, 0.01, -0.074), (0.066, 0.03, 0.06, 0.012, -0.076)], plate, 0.003, side * 0.074)

    a = f"{L}_UpperArm_R"
    joint(a, (0, 0, 0), 0.085, L)
    block(a, "Pauldron", [(0.1, 0.09, 0.1, 0.03, 0.0), (0.03, 0.135, 0.13, 0.04, 0.0), (-0.11, 0.12, 0.12, 0.04, 0.0), (-0.14, 0.09, 0.09, 0.03, 0.0)], plate2, 0.006, 0.03)
    block(a, "Upper arm", [(-0.1, 0.07, 0.075, 0.022), (-0.28, 0.06, 0.066, 0.02)], plate, 0.004)
    ram(a, (0, -0.1, -0.09), (0, -0.28, -0.07), 0.02)

    f = f"{L}_Forearm_R"
    joint(f, (0, 0, 0), 0.066, L)
    block(f, "Forearm", [(-0.03, 0.062, 0.066, 0.02), (-0.14, 0.085, 0.09, 0.028), (-0.26, 0.07, 0.074, 0.024)], plate, 0.005)
    block(f, "Guard", [(-0.04, 0.012, 0.075, 0.006), (-0.26, 0.012, 0.075, 0.006)], plate2, 0.003, 0.09)
    with at(0, -0.325, -0.02):
        claw(f, L, 1.25)

    th = f"{L}_Thigh_R"
    joint(th, (0, 0, 0), 0.08, L)
    block(th, "Thigh", [(-0.04, 0.09, 0.1, 0.03), (-0.2, 0.1, 0.11, 0.034), (-0.4, 0.074, 0.084, 0.026)], plate, 0.005)
    block(th, "Thigh slab", [(-0.08, 0.07, 0.022, 0.012, -0.11), (-0.32, 0.06, 0.02, 0.012, -0.09)], plate2, 0.003)
    ram(th, (0.0, -0.06, 0.1), (0, -0.4, 0.08), 0.024)

    s = f"{L}_Shin_R"
    joint(s, (0, 0, 0), 0.074, L)
    block(s, "Knee", [(0.08, 0.06, 0.03, 0.014, -0.07), (-0.02, 0.09, 0.05, 0.02, -0.075), (-0.1, 0.07, 0.03, 0.014, -0.07)], plate2, 0.005)
    block(s, "Greave", [(-0.06, 0.08, 0.085, 0.026), (-0.24, 0.098, 0.1, 0.03), (-0.42, 0.074, 0.08, 0.024)], plate, 0.005)

    b = f"{L}_Boot_R"
    joint(b, (0, 0, 0), 0.066, L)
    block(b, "Foot", [(-0.102, 0.09, 0.17, 0.04, -0.06), (-0.06, 0.086, 0.16, 0.04, -0.06), (0.0, 0.066, 0.09, 0.03, -0.01)], plate, 0.005)
    block(b, "Toe plate", [(-0.102, 0.08, 0.05, 0.02, -0.2), (-0.03, 0.05, 0.04, 0.02, -0.16)], plate2, 0.004)


# ---------------------------------------------------------------- commando droid

def seam_ring(part, y, rx, rz, cz=0.0):
    upright(part, "Seam", [(y - 0.003, rx, rz), (y + 0.003, rx, rz)], f"DroidFrame_{part[:3]}", 14, 0.0, cz, 2.5)


def cmd():
    L = "Cmd"
    plate, plate2, frame = f"DroidPlate_{L}", f"DroidPlate2_{L}", f"DroidFrame_{L}"
    p = f"{L}_Pelvis"
    upright(p, "Pelvis", [(-0.14, 0.05, 0.05), (-0.1, 0.13, 0.095), (-0.02, 0.165, 0.112), (0.07, 0.15, 0.105), (0.12, 0.12, 0.09)], plate, 18, 0.0, 0.0, 2.6)
    seam_ring(p, 0.06, 0.154, 0.108)
    for side in (1, -1):
        joint(p, (side * 0.1, -0.05, 0), 0.05, L)

    t = f"{L}_Torso"
    upright(t, "Waist", [(-0.05, 0.11, 0.085), (0.1, 0.105, 0.08)], frame, 16, 0.0, 0.0, 2.6)
    for i in range(3):
        seam_ring(t, 0.0 + i * 0.04, 0.116, 0.09)
    upright(t, "Chest", [(0.1, 0.12, 0.09), (0.2, 0.175, 0.115), (0.34, 0.205, 0.125), (0.44, 0.18, 0.108), (0.5, 0.11, 0.08)], plate, 20, 0.0, 0.0, 2.8, 0.002)
    block(t, "Breast", [(0.2, 0.09, 0.02, 0.012, -0.112), (0.4, 0.13, 0.024, 0.014, -0.118)], plate2, 0.003)
    profile(t, "Spine lamp", [(0.122, 0.2), (0.126, 0.2), (0.126, 0.42), (0.122, 0.42)], 0.004, CORE, 0)
    for side in (1, -1):
        slab(t, "Dorsal blade", [(0.11, 0.2), (0.2, 0.3), (0.2, 0.52), (0.1, 0.46)], *sorted((side * 0.08, side * 0.095)), plate2, 0.002)
    upright(t, "Neck", [(0.48, 0.07, 0.062), (0.56, 0.05, 0.05)], frame, 12)
    block(t, "Upper plate", [(0.34, 0.15, 0.022, 0.012, -0.112), (0.46, 0.11, 0.02, 0.012, -0.096)], plate2, 0.003)
    for side in (1, -1):
        block(t, "Rib plate", [(0.16, 0.04, 0.05, 0.012, -0.05), (0.32, 0.05, 0.06, 0.014, -0.06)], plate2, 0.003, side * 0.16)
        block(t, "Shoulder guard", [(0.42, 0.05, 0.07, 0.016), (0.5, 0.06, 0.07, 0.018), (0.54, 0.04, 0.05, 0.014)], plate2, 0.003, side * 0.17)
        profile(t, "Chest lamp", [(-0.128, 0.36), (-0.126, 0.36), (-0.126, 0.41), (-0.128, 0.41)], 0.005, CORE, 0, x=side * 0.09)
    block(t, "Spine unit", [(0.14, 0.07, 0.03, 0.012, 0.128), (0.46, 0.09, 0.036, 0.014, 0.13)], plate2, 0.003)
    for i in range(4):
        y = 0.18 + i * 0.07
        slab(t, "Spine rib", [(0.164, y), (0.164, y + 0.03), (0.172, y + 0.03), (0.172, y)], -0.07, 0.07, frame, 0)

    h = f"{L}_Head"
    upright(h, "Skull", [(0.0, 0.05, 0.055), (0.03, 0.082, 0.09), (0.1, 0.095, 0.108), (0.17, 0.082, 0.096), (0.215, 0.05, 0.062), (0.23, 0.0, 0.0)], plate, 18, 0.0, 0.006, 2.5, 0.0015)
    # A split visor: two raked slits meeting at the brow.
    for side in (1, -1):
        a = (side * 0.008, 0.14, -0.098)
        b = (side * 0.086, 0.104, -0.05)
        tube(h, "Visor", [a, b], 0.007, CORE, 5)
        slab(h, "Cheek", [(-0.07, 0.03), (0.02, 0.02), (0.05, 0.1), (-0.04, 0.09)], *sorted((side * 0.086, side * 0.098)), plate2, 0.002)
    slab(h, "Crest", [(0.0, 0.2), (0.07, 0.2), (0.1, 0.23), (-0.02, 0.232)], -0.006, 0.006, plate2, 0.0015)

    a = f"{L}_UpperArm_R"
    upright(a, "Shoulder", [(0.07, 0.0, 0.0), (0.06, 0.04, 0.04), (0.03, 0.066, 0.066), (-0.02, 0.07, 0.07), (-0.07, 0.06, 0.062)], plate, 16, 0.0, 0.0, 2.2)
    upright(a, "Arm", [(-0.06, 0.05, 0.052), (-0.2, 0.046, 0.048), (-0.3, 0.04, 0.042)], plate2, 14, 0.0, 0.0, 2.4)
    seam_ring(a, -0.1, 0.053, 0.055)
    block(a, "Arm plate", [(0.03, 0.02, 0.05, 0.008), (-0.12, 0.016, 0.044, 0.008)], plate2, 0.002, 0.06)

    f = f"{L}_Forearm_R"
    joint(f, (0, 0, 0), 0.044, L)
    upright(f, "Forearm", [(-0.02, 0.04, 0.042), (-0.1, 0.05, 0.052), (-0.22, 0.04, 0.042), (-0.27, 0.032, 0.034)], plate, 14, 0.0, 0.0, 2.5)
    slab(f, "Blade guard", [(0.02, -0.04), (0.06, -0.08), (0.05, -0.22), (0.02, -0.24)], 0.04, 0.05, plate2, 0.002)
    with at(0, -0.325, -0.02):
        claw(f, L, 0.92)

    th = f"{L}_Thigh_R"
    joint(th, (0, 0, 0), 0.052, L)
    upright(th, "Thigh", [(0.0, 0.07, 0.075), (-0.14, 0.078, 0.086), (-0.32, 0.058, 0.064), (-0.44, 0.046, 0.05)], plate, 16, 0.0, 0.0, 2.5)
    seam_ring(th, -0.2, 0.076, 0.083)
    block(th, "Thigh plate", [(-0.04, 0.05, 0.02, 0.01, -0.076), (-0.28, 0.04, 0.018, 0.01, -0.062)], plate2, 0.003)
    block(th, "Hip plate", [(0.02, 0.016, 0.06, 0.008), (-0.18, 0.014, 0.05, 0.008)], plate2, 0.002, 0.08)

    s = f"{L}_Shin_R"
    joint(s, (0, 0, 0), 0.05, L)
    block(s, "Knee", [(0.05, 0.036, 0.016, 0.008, -0.05), (-0.03, 0.05, 0.024, 0.012, -0.052), (-0.1, 0.036, 0.016, 0.008, -0.05)], plate2, 0.003)
    upright(s, "Calf", [(-0.03, 0.048, 0.054), (-0.15, 0.056, 0.066, ), (-0.34, 0.04, 0.046), (-0.44, 0.034, 0.038)], plate, 14, 0.0, 0.01, 2.5)
    block(s, "Shin plate", [(-0.1, 0.038, 0.016, 0.008, -0.05), (-0.34, 0.03, 0.014, 0.008, -0.04)], plate2, 0.003)

    b = f"{L}_Boot_R"
    joint(b, (0, 0, 0), 0.042, L)
    block(b, "Foot", [(-0.102, 0.05, 0.14, 0.026, -0.07), (-0.06, 0.046, 0.13, 0.026, -0.07), (-0.01, 0.034, 0.07, 0.018, -0.02)], plate, 0.003)
    block(b, "Sole", [(-0.108, 0.052, 0.144, 0.026, -0.07), (-0.1, 0.052, 0.144, 0.026, -0.07)], frame, 0.0015)


# ---------------------------------------------------------------- first person and class fittings

def first_person():
    """A droid's forearm as its pilot sees it, one metre long so the game can scale it."""
    part, L = "FP_Arm_D", "Reg"
    tube(part, "Bone", [(0, 0, 0), (0, 1.0, 0)], 0.022, METAL, 8)
    block(part, "Guard", [(0.1, 0.04, 0.034, 0.012), (0.3, 0.052, 0.046, 0.016), (0.75, 0.044, 0.038, 0.014), (1.0, 0.05, 0.044, 0.016)], f"DroidPlate_{L}", 0.003)
    tube(part, "Ram", [(0.04, 0.06, 0.03), (0.04, 0.8, 0.026)], 0.009, METAL, 8)
    tube(part, "Cable", [(-0.04, 0.0, 0.028), (-0.05, 0.5, 0.03), (-0.04, 1.0, 0.03)], 0.006, CABLE, 5)
    joint(part, (0, 0.03, 0), 0.03, L)
    claw("FP_Glove_D", L)


def hunter_gear():
    part, L = "Gear_hunter", "Reg"
    block(part, "Sensor pack", [(0.2, 0.09, 0.04, 0.014, 0.21), (0.44, 0.1, 0.044, 0.014, 0.21)], f"DroidPlate2_{L}")
    tube(part, "Mast", [(0.06, 0.44, 0.22), (0.08, 0.86, 0.24)], 0.008, METAL, 6)
    block(part, "Dish", [(0.82, 0.05, 0.016, 0.01, 0.24), (0.92, 0.07, 0.02, 0.012, 0.24)], f"DroidPlate_{L}", 0.002, 0.08)


def marshal_gear():
    part, L = "Gear_marshal", "Reg"
    block(part, "Command unit", [(0.16, 0.12, 0.05, 0.018, 0.21), (0.46, 0.14, 0.06, 0.02, 0.22)], f"DroidPlate2_{L}")
    for side, height in ((1, 1.2), (-1, 0.86)):
        tube(part, "Array", [(side * 0.09, 0.46, 0.22), (side * 0.12, height, 0.28)], 0.0055, CABLE, 5)
    for side in (1, -1):
        block(part, "Shoulder bar", [(0.48, 0.1, 0.05, 0.012), (0.5, 0.1, 0.05, 0.012)], "DroidCommand", 0.002, side * 0.16)


def marshal_head():
    part = "Gear_marshal_head"
    slab(part, "Command crest", [(-0.06, 0.15), (0.12, 0.13), (0.14, 0.2), (-0.02, 0.27)], -0.008, 0.008, "DroidCommand", 0.002)


PALETTE["DroidCommand"] = ((0.6, 0.08, 0.05), 0.2, 0.5, 0)
NAMES = ["Pelvis", "Torso", "Head", "UpperArm_R", "Forearm_R", "Thigh_R", "Shin_R", "Boot_R"]
SIDES = ["UpperArm", "Forearm", "Thigh", "Shin", "Boot"]
EXTRA = ["FP_Arm_D", "FP_Glove_D", "Gear_hunter", "Gear_marshal", "Gear_marshal_head"]
POSE = {"Pelvis": (0, 0.95, 0), "Torso": (0, 1.03, 0), "Head": (0, 1.56, 0), "UpperArm_R": (0.28, 1.5, 0), "UpperArm_L": (-0.28, 1.5, 0), "Forearm_R": (0.28, 1.21, 0), "Forearm_L": (-0.28, 1.21, 0),
        "Thigh_R": (0.1, 0.9, 0), "Thigh_L": (-0.1, 0.9, 0), "Shin_R": (0.1, 0.45, 0), "Shin_L": (-0.1, 0.45, 0), "Boot_R": (0.1, 0.0, 0), "Boot_L": (-0.1, 0.0, 0)}


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
        for name in NAMES:
            key = f"{label}_{name}"
            obj = join(key)
            shade(obj, 32.0)
            bake_wear(obj, 0.09, 8, 0.72)
            objs[key] = obj
            total += sum(len(p.vertices) - 2 for p in obj.data.polygons) * (2 if name.endswith("_R") else 1)
        for side in SIDES:
            objs[f"{label}_{side}_L"] = mirrored(objs[f"{label}_{side}_R"], f"{label}_{side}_L")
        tris[label] = total
    for name in EXTRA:
        obj = join(name)
        shade(obj, 32.0)
        bake_wear(obj, 0.09, 8, 0.72)
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
    for i, label in enumerate(FRAMES):
        for name, pos in POSE.items():
            obj = objs[f"{label}_{name}"]
            obj.location = (pos[0] + (i - 1) * 1.5, -pos[2], pos[1])
    for name in EXTRA:
        objs[name].location = (9, 9, 0)
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
    scene.render.resolution_x, scene.render.resolution_y = 1100, 800
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.66, 0.72, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.85
    scene.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.0
    s = bpy.data.objects.new("sun", sun)
    s.rotation_euler = (math.radians(55), math.radians(10), math.radians(25))
    bpy.context.collection.objects.link(s)
    cam = bpy.data.cameras.new("cam")
    cam.lens = 70
    c = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(c)
    scene.camera = c
    for label, pos, aim in [("front", (1.6, 7.6, 1.4), (0, 0, 0.95)), ("back", (-2.4, -7.4, 1.6), (0, 0, 0.95)), ("close", (0.7, 3.2, 1.75), (0, 0, 1.45))]:
        c.location = pos
        c.rotation_euler = (Vector(aim) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(Path(folder) / f"{label}.png")
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    reg()
    big()
    cmd()
    first_person()
    hunter_gear()
    marshal_gear()
    marshal_head()
    objs = finish()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "droids.blend"))
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--preview" in args:
        preview(args[args.index("--preview") + 1], objs)
    print("[droids] done", flush=True)


main()
