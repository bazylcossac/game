"""Builds the project's own hover tank in Blender and exports it for the game.

Run:  blender --background --factory-startup --python tools/blender_tank.py [-- --preview DIR]

Materials are named after the tones TankAssets paints with. Each vertex stores baked occlusion
in red and edge wear in green.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_kit import *  # noqa: E402,F403

OUT = ROOT / "assets/models/tank"
OUT.mkdir(parents=True, exist_ok=True)
PALETTE.update({
    PLATE: ((0.47, 0.36, 0.2), 0.1, 0.55, 0), PLATE2: ((0.3, 0.23, 0.13), 0.1, 0.6, 0),
    DARK: ((0.015, 0.014, 0.013), 0.1, 0.8, 0), STEEL: ((0.2, 0.2, 0.2), 0.9, 0.38, 0),
    TRIM: ((0.7, 0.42, 0.1), 0.9, 0.34, 0), GLASS: ((0.01, 0.03, 0.05), 0.2, 0.08, 0),
    LIGHT: ((0.2, 0.7, 1.0), 0, 0.5, 8), SOFT: ((0.2, 0.7, 1.0), 0, 0.5, 3),
})
EMBLEMS = []


# ---------------------------------------------------------------- hull

def station(z, belly, chine, shoulder, deck, spine):
    """Keel, belly edge, chine, shoulder, deck edge, deck crown, spine."""
    return (z, [(0.0, belly[1]), belly, chine, shoulder, deck, (deck[0] * 0.5, spine - 0.012), (0.0, spine)])


def build_hull():
    stations = [
        station(-3.74, (0.08, 0.36), (0.2, 0.41), (0.16, 0.46), (0.1, 0.49), 0.5),
        station(-3.3, (0.42, 0.2), (0.74, 0.4), (0.6, 0.58), (0.42, 0.65), 0.67),
        station(-2.65, (0.78, 0.08), (1.1, 0.42), (0.92, 0.72), (0.66, 0.84), 0.875),
        station(-1.65, (0.98, 0.0), (1.28, 0.46), (1.1, 0.88), (0.84, 1.03), 1.07),
        station(-0.5, (1.0, 0.0), (1.2, 0.48), (1.1, 0.92), (0.96, 1.08), 1.12),
        station(0.9, (1.0, 0.0), (1.2, 0.5), (1.14, 0.94), (1.0, 1.1), 1.14),
        station(2.0, (0.98, 0.02), (1.26, 0.52), (1.16, 0.96), (0.96, 1.12), 1.17),
        station(2.9, (0.88, 0.1), (1.18, 0.54), (1.04, 0.92), (0.8, 1.05), 1.1),
        station(3.36, (0.68, 0.24), (0.94, 0.56), (0.82, 0.82), (0.6, 0.9), 0.93),
    ]
    core = body("Hull", "Hull core", stations, PLATE, (1, 2, 3, 4), level=3, bevel=0.014)
    # Sponsons: long blades that carry the lift fans and end in the thrust nozzles.
    sponsons = {}
    for side in (1, -1):
        rings = []
        for z, cx, w, lo, hi, mid in [
            (-3.05, 1.2, 0.06, 0.34, 0.5, 0.42), (-2.7, 1.3, 0.2, 0.14, 0.66, 0.4), (-1.9, 1.46, 0.34, -0.02, 0.84, 0.36),
            (-0.6, 1.53, 0.38, -0.08, 0.92, 0.34), (1.1, 1.54, 0.38, -0.08, 0.96, 0.36), (2.5, 1.52, 0.38, -0.04, 1.02, 0.42),
            (3.3, 1.46, 0.36, 0.08, 1.02, 0.5), (3.56, 1.43, 0.31, 0.14, 0.96, 0.54),
        ]:
            ring = [
                (cx - w * 0.8, lo + 0.06, z), (cx + w * 0.5, lo, z), (cx + w, mid, z), (cx + w * 0.56, hi - 0.1, z),
                (cx - w * 0.1, hi, z), (cx - w * 0.86, hi - 0.16, z), (cx - w * 1.02, mid + 0.14, z),
            ]
            rings.append([(p[0] * side, p[1], p[2]) for p in ring])
        sponsons[side] = sculpt("Hull", f"Sponson {side}", rings, PLATE2, (1, 2, 3, 4, 5), level=3, bevel=0.012)
    dress_hull(core, sponsons)


def dress_hull(core, sponsons):
    # Glacis: an arrowhead of thicker armour, with the driver's sight sunk behind it.
    plate("Hull", "Glacis", [(-0.46, -3.25), (0.46, -3.25), (0.72, -2.45), (0.5, -1.95), (-0.5, -1.95), (-0.72, -2.45)], "top", core, PLATE2, 0.045, 0.024)
    stripe("Hull", "Glacis chevron", [(0.05, -3.1), (0.3, -2.7), (0.55, -2.32)], 0.05, "top", core, TRIM, 0.05, mirror=True)
    plate("Hull", "Sight frame", [(-0.42, -1.92), (0.42, -1.92), (0.5, -1.66), (-0.5, -1.66)], "top", core, DARK, 0.05, 0.02)
    plate("Hull", "Sight glass", [(-0.34, -1.88), (0.34, -1.88), (0.4, -1.72), (-0.4, -1.72)], "top", core, GLASS, 0.058, 0.004)
    plate("Hull", "Shoulder", [(0.52, -1.6), (0.86, -1.62), (0.95, -0.5), (0.98, 0.6), (0.74, 0.62), (0.7, -0.5)], "top", core, PLATE2, 0.03, 0.018, mirror=True)
    # Engine deck.
    grille("Hull", "Deck grille", [(0.14, 1.72), (0.8, 1.72), (0.72, 2.86), (0.14, 2.86)], "top", core, 7, mirror=True)
    plate("Hull", "Spine", [(-0.09, 1.5), (0.09, 1.5), (0.09, 3.12), (-0.09, 3.12)], "top", core, PLATE2, 0.04, 0.018)
    plate("Hull", "Rear lip", [(-0.72, 2.95), (0.72, 2.95), (0.56, 3.26), (-0.56, 3.26)], "top", core, PLATE2, 0.03, 0.016)
    # Rear face.
    plate("Hull", "Tail panel", [(-0.56, 0.42), (0.56, 0.42), (0.5, 0.82), (-0.5, 0.82)], "rear", core, DARK, 0.03, 0.016)
    stripe("Hull", "Tail lamp", [(-0.42, 0.72), (0.42, 0.72)], 0.05, "rear", core, SOFT, 0.04)

    for side, target in sponsons.items():
        axis = "right" if side > 0 else "left"
        # Side armour, in three hung plates with raked joints.
        plate("Hull", f"Skirt A {side}", [(-2.35, 0.3), (-0.98, 0.14), (-0.92, 0.76), (-2.0, 0.72)], axis, target, PLATE, 0.04, 0.022)
        plate("Hull", f"Skirt B {side}", [(-0.86, 0.14), (0.62, 0.14), (0.68, 0.8), (-0.8, 0.77)], axis, target, PLATE, 0.04, 0.022)
        plate("Hull", f"Skirt C {side}", [(0.74, 0.14), (2.36, 0.2), (2.5, 0.88), (0.8, 0.82)], axis, target, PLATE, 0.04, 0.022)
        stripe("Hull", f"Skirt trim {side}", [(-2.3, 0.08), (-0.9, 0.04), (0.7, 0.04), (2.45, 0.1)], 0.045, axis, target, TRIM, 0.02)
        # Lift emitters: long slots under the blade, not round pads.
        x = 1.5 * side
        plate("Hull", f"Lift well {side}", [(x - 0.26, -2.05), (x + 0.2, -2.05), (x + 0.22, 2.6), (x - 0.24, 2.6)], "bottom", target, DARK, 0.018, 0.012, 0.3)
        for k, (z0, z1) in enumerate(((-1.9, -0.5), (-0.3, 1.1), (1.3, 2.45))):
            plate("Hull", f"Lift {side} {k}", [(x - 0.12, z0), (x + 0.1, z0), (x + 0.1, z1), (x - 0.12, z1)], "bottom", target, LIGHT, 0.03, 0.004, 0.6)
        # Top of the blade: walkway plate, intake grille and a sensor fairing.
        grille("Hull", f"Intake {side}", [(1.32 * side, 0.15), (1.66 * side, 0.2), (1.66 * side, 1.28), (1.32 * side, 1.34)], "top", target, 6)
        plate("Hull", f"Walkway {side}", [(1.3 * side, -1.8), (1.6 * side, -1.72), (1.66 * side, 0.02), (1.32 * side, 0.02)], "top", target, PLATE, 0.022, 0.014)
        plate("Hull", f"Blade cap {side}", [(1.28 * side, 1.5), (1.66 * side, 1.5), (1.66 * side, 3.14), (1.32 * side, 3.14)], "top", target, PLATE, 0.03, 0.016)
        # Nose lamps.
        plate("Hull", f"Nose lamp {side}", [(1.13 * side, 0.46), (1.32 * side, 0.46), (1.42 * side, 0.54), (1.17 * side, 0.54)], "front", target, SOFT, 0.03, 0.004, 0.2)
        # Thrust nozzle: a rectangular, vectoring duct.
        cx = 1.43 * side
        turned("Hull", f"Collar {side}", [(3.18, 0.35, 0.45), (3.28, 0.375, 0.47), (3.44, 0.365, 0.455), (3.52, 0.33, 0.41), (3.5, 0.3, 0.37)], PLATE2, 24, cx, 0.56, 4.2, 0.008)
        turned("Hull", f"Nozzle {side}", [(3.46, 0.31, 0.38), (3.7, 0.285, 0.345), (3.74, 0.255, 0.31), (3.68, 0.23, 0.28), (3.3, 0.21, 0.25)], STEEL, 24, cx, 0.56, 4.2)
        turned("Hull", f"Nozzle glow {side}", [(3.34, 0.23, 0.27), (3.36, 0.0, 0.0)], LIGHT, 16, cx, 0.56, 3.6)
        for k in (-1, 0, 1):
            slab("Hull", f"Vane {side} {k}", [(3.36, 0.53 + k * 0.17), (3.72, 0.5 + k * 0.17), (3.72, 0.53 + k * 0.17), (3.36, 0.58 + k * 0.17)], cx - 0.27, cx + 0.27, DARK, 0)
        # Fairing that joins the blade to the hull.
        fairing = [(1.06, 0.64, -1.9), (1.2, 0.66, -1.9), (1.2, 0.86, -1.9), (1.06, 0.92, -1.9)]
        rings = [[(p[0] * side, p[1] + dy, z) for p in fairing] for z, dy in ((-2.0, -0.08), (-1.4, 0), (0.5, 0.02), (2.5, 0.05), (2.9, -0.04))]
        sculpt("Hull", f"Fairing {side}", rings, PLATE, (0, 1, 2, 3), level=2, bevel=0.008)
        tube("Hull", f"Grab rail {side}", [(1.08 * side, 1.02, -0.9), (1.08 * side, 1.12, -0.82), (1.08 * side, 1.14, 0.2), (1.08 * side, 1.15, 1.2), (1.08 * side, 1.06, 1.3)], 0.016, STEEL)
        # Tow eye.
        slab("Hull", f"Tow eye {side}", [(-3.04, 0.3), (-3.26, 0.33), (-3.3, 0.42), (-3.2, 0.46), (-3.04, 0.42)], 0.48 * side - 0.03, 0.48 * side + 0.03, STEEL, 0.006)
    for side, target in sponsons.items():
        axis = "right" if side > 0 else "left"
        skirt = PARTS["Hull"]
        # Service hatches and fasteners on the side plates.
        plate("Hull", f"Hatch {side}", [(-0.6, 0.3), (0.2, 0.3), (0.3, 0.62), (-0.5, 0.62)], axis, target, PLATE2, 0.062, 0.014)
        plate("Hull", f"Hatch tag {side}", [(-0.46, 0.5), (-0.1, 0.5), (-0.08, 0.56), (-0.44, 0.56)], axis, target, TRIM, 0.068, 0.004, 0.3)
        plate("Hull", f"Wedge A {side}", [(-2.12, 0.34), (-1.44, 0.28), (-1.34, 0.62), (-1.86, 0.62)], axis, target, PLATE2, 0.066, 0.02)
        plate("Hull", f"Wedge C {side}", [(1.02, 0.28), (1.82, 0.3), (1.94, 0.66), (1.08, 0.64)], axis, target, PLATE2, 0.066, 0.02)
        studs("Hull", f"Stud A {side}", (-2.28, 0.68), (-1.02, 0.7), 7, axis, target)
        studs("Hull", f"Stud B {side}", (-0.78, 0.72), (0.58, 0.74), 8, axis, target)
        studs("Hull", f"Stud C {side}", (0.86, 0.76), (2.36, 0.8), 8, axis, target)
        studs("Hull", f"Stud D {side}", (-0.78, 0.2), (0.58, 0.2), 8, axis, target)
        seam("Hull", [(-2.62, 0.5), (-2.42, 0.86)], axis, target)
        seam("Hull", [(2.6, 0.3), (2.74, 0.9)], axis, target)
        # Coolant bottles on the blade, behind the intake.
        canister("Hull", f"Bottle a {side}", (1.44 * side), 1.14, 2.32, 1.1, 0.1)
        canister("Hull", f"Bottle b {side}", (1.67 * side), 1.1, 2.32, 1.1, 0.09)
        plate("Hull", f"Bottle rest {side}", [(1.32 * side, 1.7), (1.66 * side, 1.7), (1.66 * side, 2.92), (1.32 * side, 2.92)], "top", target, DARK, 0.05, 0.012)
        seam("Hull", [(1.3 * side, -0.9), (1.7 * side, -0.86)], "top", target)
    # Lower ram across the nose, and a fitted sensor bar above it.
    plate("Hull", "Nose cap", [(-0.12, -3.62), (0.12, -3.62), (0.34, -3.32), (-0.34, -3.32)], "top", core, STEEL, 0.03, 0.016)
    plate("Hull", "Sensor bar", [(-0.2, -3.3), (0.2, -3.3), (0.26, -3.22), (-0.26, -3.22)], "top", core, GLASS, 0.05, 0.006, 0.2)
    studs("Hull", "Glacis studs R", (0.46, -2.42), (0.3, -3.1), 5, "top", core)
    studs("Hull", "Glacis studs L", (-0.46, -2.42), (-0.3, -3.1), 5, "top", core)
    for line in ([(-0.92, -1.2), (-1.02, -0.5)], [(-0.62, 0.8), (-0.96, 0.82)], [(-0.4, 1.56), (-0.96, 1.6)]):
        seam("Hull", line, "top", core)
        seam("Hull", [(-a, b) for a, b in line], "top", core)
    # Belly the lift field works against.
    body("Hull", "Belly", [
        station(-2.9, (0.3, 0.1), (0.5, 0.2), (0.45, 0.3), (0.3, 0.32), 0.34),
        station(-1.6, (0.8, -0.08), (0.9, 0.1), (0.85, 0.3), (0.5, 0.32), 0.34),
        station(2.3, (0.8, -0.08), (0.9, 0.1), (0.85, 0.3), (0.5, 0.32), 0.34),
        station(3.0, (0.5, 0.1), (0.6, 0.2), (0.5, 0.3), (0.3, 0.32), 0.34),
    ], DARK, (1, 2), level=1, bevel=0)


# ---------------------------------------------------------------- turret

TURRET = (0.0, 1.0, 0.25)
MANTLET = (0.0, 0.34, -1.05)
STATION = (0.0, 0.8, 0.0)
STATION_GUN = (0.0, 0.44, 0.0)


def carve(obj, rings):
    cutter = add("_cut", "cutter", [B(p) for ring in rings for p in ring], rings_to_faces(len(rings), len(rings[0])), DARK)
    outward(cutter)
    mod = obj.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    bake_modifiers(obj)
    bpy.data.objects.remove(cutter)
    PARTS.pop("_cut")


def build_turret():
    with at(*TURRET):
        stations = [
            station(-2.05, (0.12, 0.2), (0.2, 0.22), (0.16, 0.28), (0.1, 0.3), 0.31),
            station(-1.55, (0.46, 0.06), (0.72, 0.12), (0.62, 0.36), (0.44, 0.46), 0.48),
            station(-0.7, (0.8, 0.0), (1.12, 0.1), (1.0, 0.5), (0.68, 0.7), 0.74),
            station(0.3, (0.92, -0.02), (1.28, 0.1), (1.16, 0.54), (0.78, 0.78), 0.82),
            station(1.2, (0.88, 0.0), (1.24, 0.12), (1.12, 0.56), (0.78, 0.78), 0.82),
            station(1.95, (0.7, 0.06), (1.02, 0.16), (0.92, 0.54), (0.62, 0.72), 0.76),
            station(2.42, (0.44, 0.16), (0.66, 0.22), (0.58, 0.46), (0.38, 0.58), 0.6),
        ]
        shell = body("Turret", "Turret shell", stations, PLATE, (2, 3, 4), level=3, bevel=0.014)
        # The gun sits in a slot in the nose, not on the face of the turret.
        slot = [box_ring(0, 0.34, z, w, h, 0.05) for z, w, h in ((-2.3, 0.42, 0.34), (-1.5, 0.38, 0.32), (-0.72, 0.34, 0.28))]
        carve(shell, slot)
        upright("Turret", "Race", [(-0.14, 1.04, 1.1), (0.08, 1.06, 1.12)], DARK, 28, 0, 0.0, 2.3)

        plate("Turret", "Cheek", [(0.46, -1.5), (0.66, -1.36), (0.96, -0.66), (1.06, 0.2), (0.82, 0.2), (0.6, -0.7)], "top", shell, PLATE2, 0.055, 0.026, mirror=True)
        plate("Turret", "Roof", [(0.34, 1.05), (0.72, 1.05), (0.72, 1.6), (0.58, 1.94), (0.34, 1.98)], "top", shell, PLATE2, 0.03, 0.018, mirror=True)
        grille("Turret", "Bustle vent", [(-0.26, 1.02), (0.26, 1.02), (0.22, 1.9), (-0.22, 1.9)], "top", shell, 5)
        studs("Turret", "Cheek studs R", (0.58, -1.2), (0.82, -0.5), 5, "top", shell)
        studs("Turret", "Cheek studs L", (-0.58, -1.2), (-0.82, -0.5), 5, "top", shell)
        for line in ([(0.6, -0.2), (0.7, 0.9)], [(0.2, 0.7), (0.72, 0.72)]):
            seam("Turret", line, "top", shell, mirror=True)
        for side in (1, -1):
            axis = "right" if side > 0 else "left"
            flank = plate("Turret", f"Flank {side}", [(-0.5, 0.14), (1.24, 0.16), (1.34, 0.48), (-0.34, 0.44)], axis, shell, PLATE2, 0.03, 0.018, 0.2)
            stripe("Turret", f"Flank trim {side}", [(-1.05, 0.03), (0.4, 0.015), (1.7, 0.08)], 0.03, axis, shell, TRIM, 0.014)
            seam("Turret", [(-0.72, 0.12), (-0.56, 0.42)], axis, shell)
            seam("Turret", [(1.5, 0.18), (1.6, 0.46)], axis, shell)
            studs("Turret", f"Flank studs {side}", (-0.42, 0.42), (1.22, 0.46), 8, axis, shell, 0.017)
            point, normal = project(shell, axis, 0.42, 0.3)
            EMBLEMS.append((f"Emblem_{'R' if side > 0 else 'L'}", point + normal * 0.045, normal))
            # Smoke dischargers: an angular pod on each cheek.
            sculpt("Turret", f"Smoke pod {side}", [
                [(0.86 * side, 0.46, -0.72), (1.1 * side, 0.26, -0.72), (1.1 * side, 0.34, -0.72), (0.86 * side, 0.56, -0.72)],
                [(0.88 * side, 0.52, 0.0), (1.2 * side, 0.3, 0.0), (1.2 * side, 0.44, 0.0), (0.88 * side, 0.68, 0.0)],
            ], PLATE2, (0, 1, 2, 3), level=0, bevel=0.012)
            for k in range(3):
                x = (0.93 + k * 0.075) * side
                y = 0.46 - k * 0.055
                turned("Turret", f"Smoke tube {side} {k}", [(-0.66, 0.03), (-0.78, 0.03), (-0.78, 0.02), (-0.72, 0.0)], STEEL, 8, x, y)
            tube("Turret", f"Rail {side}", [(0.7 * side, 0.74, 1.2), (0.78 * side, 0.86, 1.26), (0.72 * side, 0.86, 1.92), (0.58 * side, 0.72, 2.04)], 0.014, STEEL)
        # Rear basket of stowage, the sort of clutter a crew really carries.
        tube("Turret", "Basket", [(-0.72, 0.42, 2.32), (-0.52, 0.42, 2.72), (0.52, 0.42, 2.72), (0.72, 0.42, 2.32)], 0.018, STEEL)
        tube("Turret", "Basket top", [(-0.7, 0.62, 2.22), (-0.5, 0.62, 2.66), (0.5, 0.62, 2.66), (0.7, 0.62, 2.22)], 0.018, STEEL)
        for x in (-0.5, -0.17, 0.17, 0.5):
            tube("Turret", "Basket post", [(x, 0.42, 2.72), (x, 0.62, 2.66)], 0.012, STEEL)
        sculpt("Turret", "Kit bag", [
            [(0.42, 0.42, 2.34), (0.48, 0.5, 2.34), (0.42, 0.6, 2.34), (-0.42, 0.6, 2.34), (-0.48, 0.5, 2.34), (-0.42, 0.42, 2.34)],
            [(0.42, 0.42, 2.64), (0.46, 0.5, 2.62), (0.4, 0.58, 2.6), (-0.4, 0.58, 2.6), (-0.46, 0.5, 2.62), (-0.42, 0.42, 2.64)],
        ], DARK, (), level=2, bevel=0)
        # Commander's hatch, off to one side so the weapon station keeps the axis.
        upright("Turret", "Hatch", [(0.74, 0.24, 0.27), (0.82, 0.25, 0.28), (0.86, 0.2, 0.22)], PLATE2, 10, 0.62, 0.68, 3.0, 0.006)
        tube("Turret", "Hatch handle", [(0.5, 0.87, 0.68), (0.54, 0.9, 0.68), (0.7, 0.9, 0.68), (0.74, 0.87, 0.68)], 0.01, STEEL)
        # Gunner's sight: a raked armoured box ahead of the roof gun.
        sculpt("Turret", "Sight box", [
            [(-0.5, 0.6, -0.72), (-0.26, 0.6, -0.72), (-0.27, 0.74, -0.72), (-0.49, 0.74, -0.72)],
            [(-0.54, 0.6, -0.34), (-0.22, 0.6, -0.34), (-0.24, 0.84, -0.26), (-0.52, 0.84, -0.26)],
        ], PLATE2, (0, 1, 2, 3), level=0, bevel=0.012)
        section("Turret", "Sight glass", [(-0.725, 0.09, 0.05, 0.015), (-0.74, 0.08, 0.044, 0.014)], GLASS, 0, -0.38, 0.67)
        # Sensor mast with an offset head.
        tube("Turret", "Mast", [(0.56, 0.74, 1.72), (0.58, 1.3, 1.76)], 0.022, STEEL)
        section("Turret", "Mast head", [(1.84, 0.05, 0.05, 0.02), (1.76, 0.07, 0.07, 0.025), (1.64, 0.06, 0.06, 0.02)], PLATE2, 0.004, 0.58, 1.32)
        tube("Turret", "Whip aerial", [(-0.5, 0.72, 2.04), (-0.72, 1.75, 3.0)], 0.008, DARK, 4)
        tube("Turret", "Short aerial", [(0.38, 0.72, 2.1), (0.5, 1.45, 2.66)], 0.007, DARK, 4)
    return shell


def build_gun():
    with at(*TURRET), at(*MANTLET):
        body("Mantlet", "Mantlet", [
            station(0.32, (0.26, -0.24), (0.34, -0.06), (0.32, 0.12), (0.22, 0.24), 0.26),
            station(-0.3, (0.27, -0.25), (0.34, -0.08), (0.33, 0.12), (0.24, 0.25), 0.27),
            station(-0.8, (0.2, -0.2), (0.28, -0.08), (0.27, 0.08), (0.18, 0.2), 0.21),
            station(-1.02, (0.15, -0.15), (0.2, -0.06), (0.2, 0.06), (0.14, 0.15), 0.16),
        ], PLATE2, (1, 2, 3, 4), level=2, bevel=0.01)
        section("Mantlet", "Coax", [(-0.72, 0.03, 0.03, 0.01), (-1.1, 0.024, 0.024, 0.008)], STEEL, 0, 0.27, -0.05)

        # Railgun: a tapering shroud between two long rails, not a tube.
        section("Barrel", "Shroud", [(-0.9, 0.17, 0.15, 0.06), (-1.5, 0.15, 0.13, 0.05), (-3.05, 0.115, 0.1, 0.04), (-3.55, 0.105, 0.09, 0.035)], DARK, 0.006)
        for side in (1, -1):
            x0, x1 = sorted((0.1 * side, 0.2 * side))
            outline = [(-1.0, 0.13), (-1.2, 0.15), (-1.7, 0.13), (-3.25, 0.075), (-3.62, 0.075), (-3.62, -0.075), (-3.25, -0.075), (-1.7, -0.13), (-1.2, -0.15), (-1.0, -0.13)]
            slab("Barrel", f"Rail {side}", outline, x0, x1, PLATE, 0.008)
            x0, x1 = sorted((0.2 * side, 0.214 * side))
            slab("Barrel", f"Rail lamp {side}", [(-1.5, 0.018), (-3.4, 0.018), (-3.4, -0.018), (-1.5, -0.018)], x0, x1, SOFT, 0)
        slab("Barrel", "Spine", [(-1.1, 0.16), (-1.4, 0.2), (-3.0, 0.14), (-3.5, 0.11), (-3.5, 0.08), (-1.1, 0.1)], -0.03, 0.03, PLATE2, 0.006)
        for z, w in ((-1.14, 0.245), (-1.78, 0.235), (-2.42, 0.22), (-3.02, 0.205)):
            section("Barrel", f"Clamp {z}", [(z + 0.08, w - 0.03, w * 0.74, 0.07), (z + 0.05, w, w * 0.78, 0.07), (z - 0.05, w, w * 0.78, 0.07), (z - 0.08, w - 0.03, w * 0.74, 0.07)], STEEL, 0.004)
        section("Barrel", "Trim band", [(-1.1, 0.256, 0.2, 0.074), (-1.18, 0.256, 0.2, 0.074)], TRIM, 0.002)
        # Muzzle shroud with side vents.
        section("Barrel", "Muzzle", [(-3.56, 0.2, 0.135, 0.05), (-3.66, 0.235, 0.15, 0.06), (-4.05, 0.215, 0.135, 0.055), (-4.18, 0.17, 0.11, 0.045)], STEEL, 0.006)
        for z in (-3.74, -3.84, -3.94):
            for side in (1, -1):
                x0, x1 = sorted((0.2 * side, 0.245 * side))
                slab("Barrel", f"Brake slot {z} {side}", [(z, 0.09), (z - 0.05, 0.09), (z - 0.05, -0.09), (z, -0.09)], x0, x1, DARK, 0)
        turned("Barrel", "Bore glow", [(-4.17, 0.1, 0.07), (-4.19, 0.0, 0.0)], LIGHT, 10, 0, 0, 3.0)


def build_station():
    """The second crew member's long gun, on the turret's own axis so it can traverse fully."""
    with at(*TURRET), at(*STATION):
        upright("Station", "Turntable", [(-0.05, 0.56, 0.64), (0.05, 0.58, 0.66), (0.1, 0.5, 0.58), (0.13, 0.4, 0.46)], PLATE2, 22, 0, 0, 3.0, 0.008)
        upright("Station", "Bearing", [(-0.08, 0.6, 0.68), (-0.04, 0.6, 0.68)], DARK, 22, 0, 0, 3.0)
        # Two raked cheeks carry the trunnions, joined behind the gun by a sloping rear housing.
        for side in (1, -1):
            axis = "right" if side > 0 else "left"
            cheek = []
            for z, outer, shoulder, top, height in ((-0.54, 0.3, 0.27, 0.25, 0.22), (-0.14, 0.46, 0.4, 0.3, 0.6), (0.3, 0.5, 0.44, 0.32, 0.64), (0.74, 0.44, 0.38, 0.27, 0.44)):
                ring = [(0.238, 0.08, z), (outer * 0.9, 0.08, z), (outer, 0.13, z), (shoulder, height * 0.76, z), (top, height, z), (0.238, height + 0.01, z)]
                cheek.append([(p[0] * side, p[1], p[2]) for p in ring])
            cowl = sculpt("Station", f"Cheek {side}", cheek, PLATE, (1, 2, 3, 4, 5, 0), level=2, bevel=0.01)
            plate("Station", f"Cheek plate {side}", [(-0.08, 0.16), (0.64, 0.16), (0.56, 0.4), (0.04, 0.42)], axis, cowl, PLATE2, 0.022, 0.012, 0.1)
            studs("Station", f"Cheek studs {side}", (0.02, 0.2), (0.58, 0.2), 4, axis, cowl, 0.014)
        rear = body("Station", "Rear housing", [
            station(0.52, (0.24, 0.08), (0.27, 0.14), (0.26, 0.26), (0.24, 0.3), 0.31),
            station(0.74, (0.3, 0.08), (0.34, 0.12), (0.32, 0.36), (0.26, 0.43), 0.44),
            station(1.0, (0.18, 0.1), (0.26, 0.14), (0.22, 0.24), (0.16, 0.28), 0.3),
        ], PLATE, (2, 3, 4), level=2, bevel=0.01)
        grille("Station", "Housing vent", [(-0.18, 0.62), (0.18, 0.62), (0.15, 0.88), (-0.15, 0.88)], "top", rear, 3, PLATE2, STEEL, 0.035)
        with at(*STATION_GUN):
            section("StationGun", "Receiver", [(0.52, 0.12, 0.1, 0.04), (0.36, 0.2, 0.15, 0.06), (-0.28, 0.2, 0.14, 0.06), (-0.52, 0.13, 0.1, 0.04)], PLATE, 0.008)
            slab("StationGun", "Top rail", [(0.3, 0.14), (-0.42, 0.14), (-0.4, 0.17), (0.28, 0.18)], -0.05, 0.05, STEEL, 0.004)
            for side in (1, -1):
                x0, x1 = sorted((0.2 * side, 0.26 * side))
                slab("StationGun", f"Pin {side}", [(0.08, 0.05), (0.05, 0.08), (-0.05, 0.08), (-0.08, 0.05), (-0.08, -0.05), (-0.05, -0.08), (0.05, -0.08), (0.08, -0.05)], x0, x1, STEEL, 0.006)
            # Long barrel: a jacketed, fluted run with a slotted brake.
            turned("StationGun", "Gun tube", [(-0.5, 0.062), (-3.0, 0.042)], STEEL, 10)
            section("StationGun", "Jacket", [(-0.52, 0.098, 0.098, 0.036), (-1.72, 0.082, 0.082, 0.03)], DARK, 0.004)
            for z in (-0.72, -0.98, -1.24, -1.5):
                section("StationGun", f"Jacket band {z}", [(z + 0.022, 0.106, 0.106, 0.038), (z - 0.022, 0.104, 0.104, 0.038)], PLATE2, 0.002)
            for side in (1, -1):
                x0, x1 = sorted((0.06 * side, 0.09 * side))
                slab("StationGun", f"Fin {side}", [(-1.76, 0.014), (-2.75, 0.01), (-2.75, -0.01), (-1.76, -0.014)], x0, x1, STEEL, 0)
            slab("StationGun", "Lamp line", [(-0.55, 0.106), (-1.7, 0.092), (-1.7, 0.102), (-0.55, 0.118)], -0.012, 0.012, SOFT, 0)
            section("StationGun", "Brake", [(-2.82, 0.06, 0.06, 0.02), (-2.9, 0.09, 0.075, 0.03), (-3.2, 0.085, 0.07, 0.028), (-3.26, 0.06, 0.05, 0.02)], STEEL, 0.004)
            for z in (-2.96, -3.05, -3.14):
                for side in (1, -1):
                    x0, x1 = sorted((0.07 * side, 0.094 * side))
                    slab("StationGun", f"Brake slot {z} {side}", [(z, 0.045), (z - 0.04, 0.045), (z - 0.04, -0.045), (z, -0.045)], x0, x1, DARK, 0)
            turned("StationGun", "Bore", [(-3.25, 0.036), (-3.27, 0.0)], LIGHT, 8)
            # Feed tray on the left, sensor head on the right.
            section("StationGun", "Sensor", [(-0.3, 0.045, 0.04, 0.014), (-0.38, 0.055, 0.05, 0.016), (-0.62, 0.055, 0.05, 0.016), (-0.67, 0.042, 0.036, 0.012)], PLATE2, 0.004, 0.17, 0.12)
            section("StationGun", "Sensor glass", [(-0.665, 0.03, 0.024, 0.008), (-0.68, 0.03, 0.024, 0.008)], GLASS, 0, 0.17, 0.12)
            slab("StationGun", "Sensor foot", [(-0.34, 0.03), (-0.6, 0.03), (-0.6, 0.1), (-0.34, 0.1)], 0.1, 0.17, STEEL, 0.004)


# ---------------------------------------------------------------- finishing

PIVOTS = {
    "Hull": (None, (0, 0, 0)),
    "Turret": ("Hull", TURRET),
    "Mantlet": ("Turret", tuple(Vector(TURRET) + Vector(MANTLET))),
    "Barrel": ("Mantlet", tuple(Vector(TURRET) + Vector(MANTLET))),
    "Station": ("Turret", tuple(Vector(TURRET) + Vector(STATION))),
    "StationGun": ("Station", tuple(Vector(TURRET) + Vector(STATION) + Vector(STATION_GUN))),
}
MARKERS = {
    "Muzzle": ("Barrel", (0, 0, -4.2)),
    "StationMuzzle": ("StationGun", (0, 0, -3.28)),
    "Exhaust_R": ("Hull", (1.43, 0.56, 3.6)),
    "Exhaust_L": ("Hull", (-1.43, 0.56, 3.6)),
}


def bake_vertex_data(objs):
    """Occlusion from rays against the whole assembled tank; wear from how convex each edge is."""
    verts, polys = [], []
    for obj in objs:
        base = len(verts)
        verts += [v.co.copy() for v in obj.data.vertices]
        polys += [tuple(i + base for i in p.vertices) for p in obj.data.polygons]
    whole = BVHTree.FromPolygons(verts, polys)
    rnd = random.Random(7)
    dirs = []
    for i in range(14):
        u, a = rnd.random(), rnd.random() * math.tau
        r = math.sqrt(u)
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(1 - u))))
    for obj in objs:
        mesh = obj.data
        attr = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        bm = bmesh.new()
        bm.from_mesh(mesh)
        wear = [0.0] * len(mesh.vertices)
        for e in bm.edges:
            if len(e.link_faces) == 2:
                w = max(0.0, min(1.0, e.calc_face_angle_signed(0.0) / 0.9))
                for v in e.verts:
                    wear[v.index] = max(wear[v.index], w)
        bm.free()
        for v in mesh.vertices:
            n = v.normal
            t = n.orthogonal().normalized()
            b = n.cross(t)
            open_rays = 0
            start = v.co + n * 0.012
            for d in dirs:
                if whole.ray_cast(start, t * d.x + b * d.y + n * d.z, 1.3)[0] is None:
                    open_rays += 1
            ao = 0.32 + 0.68 * (open_rays / len(dirs)) ** 0.8
            attr.data[v.index].color = (ao, wear[v.index], 0, 1)
        mesh.color_attributes.active_color_index = 0


def assemble():
    objs = {name: join(name) for name in PIVOTS}
    for obj in objs.values():
        shade(obj)
    bake_vertex_data(list(objs.values()))
    root_pos = {}
    for name, (parent, pivot) in PIVOTS.items():
        world = B(pivot)
        root_pos[name] = world
        obj = objs[name]
        obj.data.transform(Matrix.Translation(-world))
        obj.data.update()
        obj.location = world - (root_pos[parent] if parent else Vector((0, 0, 0)))
        if parent:
            obj.parent = objs[parent]
    for name, (parent, pos) in MARKERS.items():
        e = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(e)
        e.parent = objs[parent]
        e.location = B(pos)
    for name, point, normal in EMBLEMS:
        e = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(e)
        e.parent = objs["Turret"]
        up = Vector((0, 0, 1))
        right = up.cross(normal).normalized()
        up = normal.cross(right).normalized()
        e.matrix_local = Matrix.Translation(point - root_pos["Turret"]) @ Matrix((right, -normal, up)).transposed().to_4x4()
    bpy.context.view_layer.update()
    return objs


def show_occlusion():
    for m in bpy.data.materials:
        nodes = m.node_tree.nodes
        p = nodes["Principled BSDF"]
        attr = nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        split = nodes.new("ShaderNodeSeparateColor")
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[6].default_value = p.inputs["Base Color"].default_value
        links = m.node_tree.links
        links.new(attr.outputs[0], split.inputs[0])
        links.new(split.outputs[0], mix.inputs[7])
        links.new(mix.outputs[2], p.inputs["Base Color"])


def preview(folder):
    show_occlusion()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 960, 600
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.6, 0.68, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    scene.world = world
    ground = bpy.data.meshes.new("ground")
    ground.from_pydata([(-40, -40, -0.62), (40, -40, -0.62), (40, 40, -0.62), (-40, 40, -0.62)], [], [(0, 1, 2, 3)])
    g = bpy.data.objects.new("ground", ground)
    bpy.context.collection.objects.link(g)
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.4
    sun.angle = math.radians(6)
    s = bpy.data.objects.new("sun", sun)
    s.rotation_euler = (math.radians(52), math.radians(8), math.radians(-40))
    bpy.context.collection.objects.link(s)
    cam = bpy.data.cameras.new("cam")
    cam.lens = 58
    c = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(c)
    scene.camera = c
    for label, pos, aim in [
        ("front", (9.5, -11.5, 3.6), (0, -0.6, 1.0)), ("rear", (-9.5, 11, 4.2), (0, 0.4, 1.0)),
        ("side", (15, -1, 1.5), (0, -0.6, 0.9)), ("top", (0.2, -1, 18), (0, -0.6, 0)),
        ("close", (3.6, -6.2, 3.6), (0, -1.4, 1.5)), ("gun", (-2.4, 3.0, 3.9), (0, -1.0, 2.0)),
    ]:
        c.location = pos
        c.rotation_euler = (Vector(aim) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(Path(folder) / f"{label}.png")
        bpy.ops.render.render(write_still=True)


def export(objs):
    bpy.ops.object.select_all(action="SELECT")
    for name in ("ground", "sun", "cam"):
        o = bpy.data.objects.get(name)
        if o:
            o.select_set(False)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / "tank.glb"), export_format="GLB", use_selection=True, export_yup=True,
        export_apply=False, export_normals=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
        export_all_vertex_colors=False, export_animations=False,
    )


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    build_hull()
    build_turret()
    build_gun()
    build_station()
    objs = assemble()
    tris = {name: sum(len(p.vertices) - 2 for p in o.data.polygons) for name, o in objs.items()}
    print("[tank] triangles", tris, "total", sum(tris.values()), flush=True)
    export(objs)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "tank.blend"))
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--preview" in args:
        preview(args[args.index("--preview") + 1])
    print("[tank] done", flush=True)


main()
