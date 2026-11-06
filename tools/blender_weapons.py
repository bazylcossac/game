"""Builds every firearm, its attachments and the anti-tank round for the game.

Run:  blender --background --factory-startup --python tools/blender_weapons.py [-- --preview DIR]

Each gun is its own design, drawn from side outlines with real holes, rails and machined edges.
The origin sits at the grip and forward is -Z. WeaponFactory relies on these fixed points:
  rifle bore y .06, pistol bore y .08; top rail surface y .1 at z -.05, so fitted optics line up;
  sight line y .145 (.112 pistols, .205 heavy); right hand on the grip near (0, -.07, .05).
Node names Body, Cell, IronSight, ThirdPersonOnly and Muzzle are what the game looks for.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_kit import *  # noqa: E402,F403

OUT = ROOT / "assets/models/armory"
OUT.mkdir(parents=True, exist_ok=True)

STEEL, EDGE, POLY, WOOD, OLIVE, BLACK, CORE, LENS = "ParkerizedSteel", "MachinedSteel", "TexturedPolymer", "LaminatedWood", "OliveHousing", "RecessBlack", "EnergyIndicator", "Glass"
PALETTE.update({
    STEEL: ((0.05, 0.055, 0.06), 0.85, 0.46, 0), EDGE: ((0.26, 0.27, 0.29), 0.95, 0.3, 0),
    POLY: ((0.035, 0.037, 0.036), 0.05, 0.68, 0), WOOD: ((0.2, 0.09, 0.04), 0, 0.46, 0),
    OLIVE: ((0.13, 0.135, 0.075), 0.3, 0.56, 0), BLACK: ((0.008, 0.009, 0.01), 0.1, 0.6, 0),
    CORE: ((0.08, 0.5, 0.7), 0.15, 0.32, 3.0), LENS: ((0.02, 0.04, 0.06), 0.5, 0.08, 0),
    "_Worn": ((1, 0, 1), 0, 1, 0), "SmokeGrey": ((0.7, 0.7, 0.72), 0.1, 0.6, 0), "WarningRed": ((0.6, 0.06, 0.03), 0.1, 0.5, 0),
})
BODY, CELL, SIGHT, STOCK, SPIN = "Body", "Cell", "IronSight", "ThirdPersonOnly", "Spin"
LEATHERISH = WOOD
RIFLE_BORE, PISTOL_BORE = 0.06, 0.08


# ---------------------------------------------------------------- common parts

def rail(z_rear, z_front, y=0.1, half=0.0105, part=BODY):
    """Mounting rail with cross slots. `y` is the top of the teeth."""
    pts = [(z_rear, y - 0.012), (z_front, y - 0.012)]
    z = z_front
    pitch = 0.0104
    up = True
    while z + pitch < z_rear:
        pts += [(z, y if up else y - 0.0036), (z + pitch * (0.62 if up else 0.38), y if up else y - 0.0036)]
        z += pitch * (0.62 if up else 0.38)
        up = not up
    pts.append((z_rear, y - 0.0036))
    return profile(part, "Rail", pts, half, STEEL, 0.0007, seg=1)


def grip(mat=POLY, z=0.0, y=0.0):
    pts = [(-0.02, -0.006), (-0.01, -0.04, 0.008), (-0.004, -0.058, 0.006), (-0.002, -0.072, 0.008), (0.006, -0.086, 0.005),
           (0.016, -0.13, 0.008), (0.064, -0.14, 0.01), (0.06, -0.092, 0.012), (0.046, -0.04, 0.014), (0.05, -0.002)]
    pts = [(p[0] + z, p[1] + y, *p[2:]) for p in pts]
    profile(BODY, "Grip", pts, 0.0165, mat, 0.0052, segments=2)
    for i in range(7):
        t = i / 6
        a = -0.03 - 0.088 * t
        z0 = 0.004 + z + 0.016 * t
        z1 = 0.04 + z + 0.012 * t
        profile(BODY, "Grip stipple", [(z0, a + y), (z1, a + 0.002 + y), (z1, a + 0.0058 + y), (z0, a + 0.0038 + y)], 0.0171, BLACK if mat == POLY else WOOD, 0.0003)


def trigger_group(z=0.0, y=0.0):
    outer = [(-0.012 + z, 0.002 + y), (-0.114 + z, 0.002 + y), (-0.118 + z, -0.012 + y, 0.004), (-0.104 + z, -0.054 + y, 0.01), (-0.02 + z, -0.058 + y, 0.008), (-0.01 + z, -0.04 + y)]
    hole = [(-0.02 + z, -0.006 + y), (-0.106 + z, -0.006 + y, 0.004), (-0.096 + z, -0.047 + y, 0.006), (-0.026 + z, -0.05 + y, 0.006)]
    profile(BODY, "Trigger guard", outer, 0.0062, POLY, 0.0014, [hole])
    profile(BODY, "Trigger", [(-0.056 + z, 0.0 + y), (-0.048 + z, 0.0 + y), (-0.052 + z, -0.024 + y, 0.004), (-0.064 + z, -0.042 + y), (-0.07 + z, -0.04 + y), (-0.06 + z, -0.024 + y, 0.004)], 0.0034, EDGE, 0.0006)


def selector(z, y, half, side=1):
    """A thumb lever with its pivot."""
    x = side * (half + 0.0012)
    profile(BODY, "Selector", [(z - 0.008, y + 0.003), (z + 0.022, y + 0.008), (z + 0.024, y + 0.002), (z - 0.008, y - 0.006)], 0.0012, EDGE, 0.0003, x=x)


def pins(points, half, r=0.0032):
    """Cross pins showing on both sides of a receiver."""
    for z, y in points:
        for side in (1, -1):
            verts = []
            for k in range(8):
                a = math.tau * k / 8
                verts.append((z + r * math.cos(a), y + r * math.sin(a)))
            profile(BODY, "Cross pin", verts, 0.0006, EDGE, 0, x=side * (half + 0.0004))


def port(z0, z1, y0, y1, half, bolt=True):
    """Ejection port on the right, with the bolt showing inside it."""
    profile(BODY, "Port recess", [(z0, y0), (z1, y0), (z1, y1), (z0, y1)], 0.0009, BLACK, 0, x=half + 0.0003)
    if bolt:
        m = (y0 + y1) / 2
        h = (y1 - y0) * 0.26
        profile(BODY, "Bolt", [(z0 - 0.006, m - h), (z1 + 0.012, m - h), (z1 + 0.012, m + h), (z0 - 0.006, m + h)], 0.0007, EDGE, 0.0002, x=half + 0.0012)


def muzzle_mark(z, y):
    e = bpy.data.objects.new("Muzzle", None)
    bpy.context.collection.objects.link(e)
    e.location = B((0, y, z))
    MARKS.append(e)


def crown(z, r, y):
    """Dark bore at the very end of a barrel."""
    lathe(BODY, "Bore", [(z - 0.002, r * 0.5), (z - 0.0015, 0.0)], BLACK, 10, y)


def flash_hider(z, r, y, length=0.06):
    lathe(BODY, "Flash hider", [(z + length, r), (z + length - 0.003, r * 1.28), (z + 0.006, r * 1.28), (z, r * 1.05)], STEEL, 14, y, bevel=0.0007)
    for side in (1, -1):
        profile(BODY, "Flash slot", [(z + 0.005, y - 0.0016), (z + length * 0.62, y - 0.0016), (z + length * 0.62, y + 0.0016), (z + 0.005, y + 0.0016)], 0.001, BLACK, 0, x=side * r * 1.26)
    profile(BODY, "Flash slot top", [(z + 0.005, y + r * 1.25), (z + length * 0.62, y + r * 1.25), (z + length * 0.62, y + r * 1.29), (z + 0.005, y + r * 1.29)], 0.0016, BLACK, 0)
    crown(z, r * 1.05, y)


def slots(z_rear, z_front, y0, y1, count, gap=0.3):
    """Holes for a handguard: long rounded windows, evenly spaced."""
    out = []
    span = (z_rear - z_front) / count
    for i in range(count):
        a = z_front + span * i + span * gap * 0.5
        b = a + span * (1 - gap)
        out.append([(a, y0, 0.003), (b, y0, 0.003), (b, y1, 0.003), (a, y1, 0.003)])
    return out


def curved_mag(z, y, length, depth, half, curve, ribs=3, mat=POLY):
    """A magazine bending forward as it drops."""
    front, back = [], []
    n = 6
    for i in range(n + 1):
        t = i / n
        c = -curve * t * t
        yy = y - length * t
        front.append((z - depth / 2 + c, yy))
        back.append((z + depth / 2 + c, yy))
    outline = front + [(p[0], p[1]) for p in reversed(back)]
    outline[n] = (*outline[n], 0.004)
    outline[n + 1] = (*outline[n + 1], 0.004)
    profile(CELL, "Magazine", outline, half, mat, 0.0022)
    for i in range(1, ribs + 1):
        t = 0.3 + 0.58 * i / (ribs + 1)
        c = -curve * t * t
        yy = y - length * t
        profile(CELL, "Magazine rib", [(z - depth / 2 + c + 0.004, yy - 0.002), (z + depth / 2 + c - 0.004, yy - 0.002), (z + depth / 2 + c - 0.004, yy + 0.002), (z - depth / 2 + c + 0.004, yy + 0.002)], half + 0.0012, mat, 0.0005)
    t = 0.2
    profile(CELL, "Charge window", [(z + c * 0 - 0.004 - curve * t * t, y - length * 0.2), (z + 0.006 - curve * t * t, y - length * 0.2), (z + 0.006 - curve * 0.5 * 0.5, y - length * 0.5), (z - 0.004 - curve * 0.5 * 0.5, y - length * 0.5)], half + 0.0005, CORE, 0)


def straight_mag(z, y, length, depth, half, lean=0.0, ribs=2, mat=STEEL):
    outline = [(z - depth / 2, y), (z + depth / 2, y), (z + depth / 2 - lean, y - length, 0.003), (z - depth / 2 - lean, y - length, 0.003)]
    profile(CELL, "Magazine", outline, half, mat, 0.0018)
    profile(CELL, "Base plate", [(z - depth / 2 - lean - 0.004, y - length + 0.002), (z + depth / 2 - lean + 0.004, y - length + 0.002), (z + depth / 2 - lean + 0.003, y - length - 0.01, 0.003), (z - depth / 2 - lean - 0.003, y - length - 0.01, 0.003)], half + 0.002, POLY, 0.0016)
    for i in range(ribs):
        yy = y - length * (0.3 + 0.28 * i)
        q = lean * (0.3 + 0.28 * i)
        profile(CELL, "Magazine rib", [(z - depth / 2 - q + 0.005, yy - 0.003), (z + depth / 2 - q - 0.005, yy - 0.003), (z + depth / 2 - q - 0.005, yy + 0.003), (z - depth / 2 - q + 0.005, yy + 0.003)], half + 0.0009, BLACK, 0.0002)


def irons(rear_z, front_z, sight_y, base_y=0.1, front_base=None):
    """Folding aperture at the rear, protected post at the front. Fitted optics remove these."""
    b = base_y
    h = sight_y - b
    ring = [(rear_z - 0.011, b), (rear_z + 0.011, b), (rear_z + 0.006, b + h * 0.5, 0.004), (rear_z + 0.003, sight_y + 0.006, 0.002), (rear_z - 0.003, sight_y + 0.006, 0.002), (rear_z - 0.006, b + h * 0.5, 0.004)]
    profile(SIGHT, "Rear sight", ring, 0.0085, STEEL, 0.0008)
    profile(SIGHT, "Rear ear", [(rear_z - 0.005, sight_y - 0.012), (rear_z + 0.005, sight_y - 0.012), (rear_z + 0.005, sight_y + 0.012), (rear_z - 0.005, sight_y + 0.012)], 0.0022, BLACK, 0)
    fb = front_base if front_base is not None else b
    tower = [(front_z - 0.014, fb), (front_z + 0.014, fb), (front_z + 0.006, sight_y - 0.006, 0.003), (front_z - 0.006, sight_y - 0.006, 0.003)]
    profile(SIGHT, "Front tower", tower, 0.0065, STEEL, 0.0008)
    for side in (1, -1):
        x = side * 0.0088
        profile(SIGHT, "Post wing", [(front_z - 0.008, sight_y - 0.016), (front_z + 0.008, sight_y - 0.016), (front_z + 0.006, sight_y + 0.008, 0.002), (front_z - 0.006, sight_y + 0.008, 0.002)], 0.0016, STEEL, 0.0004, x=x)
    profile(SIGHT, "Front post", [(front_z - 0.0016, sight_y - 0.01), (front_z + 0.0016, sight_y - 0.01), (front_z + 0.0016, sight_y), (front_z - 0.0016, sight_y)], 0.0014, EDGE, 0)


def scope_on_rail(z, y, length=0.28, r=0.024):
    """A fixed magnified sight, part of the weapon rather than a fitted extra."""
    lathe(SIGHT, "Scope tube", [(z + length * 0.5, r * 1.32), (z + length * 0.5 - 0.012, r * 1.36), (z + length * 0.36, r * 1.3), (z + length * 0.3, r), (z - length * 0.2, r), (z - length * 0.3, r * 1.45), (z - length * 0.5, r * 1.5), (z - length * 0.5 - 0.004, r * 1.3)], STEEL, 16, y, bevel=0.0007)
    lathe(SIGHT, "Scope lens", [(z - length * 0.5 - 0.002, r * 1.28), (z - length * 0.5 - 0.0025, 0.0)], LENS, 14, y)
    lathe(SIGHT, "Eye lens", [(z + length * 0.5 + 0.0005, r * 1.14), (z + length * 0.5 + 0.001, 0.0)], LENS, 12, y)
    upright(SIGHT, "Elevation turret", [(y + r * 0.9, 0.012, 0.012), (y + r + 0.016, 0.012, 0.012), (y + r + 0.018, 0.009, 0.009)], EDGE, 10, 0.0, z)
    for dz in (-0.07, 0.07):
        profile(SIGHT, "Scope ring", [(z + dz - 0.012, 0.094), (z + dz + 0.012, 0.094), (z + dz + 0.012, y + r + 0.004, 0.006), (z + dz - 0.012, y + r + 0.004, 0.006)], r + 0.004, STEEL, 0.001)


def bipod_folded(z, y):
    profile(BODY, "Bipod mount", [(z - 0.022, y), (z + 0.022, y), (z + 0.018, y - 0.022, 0.004), (z - 0.018, y - 0.022, 0.004)], 0.014, STEEL, 0.001)
    for side in (1, -1):
        tube(BODY, "Bipod leg", [(side * 0.012, y - 0.016, z), (side * 0.016, y - 0.024, z + 0.16)], 0.0055, STEEL, 8)


def buttstock(z0, top, bottom, length, hollow=True, cheek=True, mat=POLY, tube_y=RIFLE_BORE):
    """A collapsing stock on its buffer tube."""
    lathe(STOCK, "Buffer tube", [(z0 - 0.01, 0.0145), (z0 + length * 0.85, 0.0145), (z0 + length * 0.85 + 0.004, 0.0)], STEEL, 12, tube_y)
    z1 = z0 + length
    zc = z0 + length * 0.38
    outline = [(zc, top - 0.004, 0.012), (z1 - 0.012, top + 0.006, 0.008), (z1, top + 0.012), (z1 + 0.006, bottom), (z1 - 0.02, bottom - 0.004, 0.006), (zc + 0.03, tube_y - 0.036, 0.018), (zc, tube_y - 0.022, 0.008)]
    holes = [[(zc + 0.04, tube_y - 0.018, 0.006), (z1 - 0.024, bottom + 0.018, 0.006), (z1 - 0.024, tube_y - 0.022, 0.006)]] if hollow else []
    profile(STOCK, "Stock body", outline, 0.017, mat, 0.003, holes, 2)
    profile(STOCK, "Butt pad", [(z1 + 0.002, top + 0.014, 0.008), (z1 + 0.018, top + 0.014, 0.008), (z1 + 0.022, bottom - 0.002, 0.008), (z1 + 0.006, bottom - 0.002, 0.008)], 0.019, BLACK, 0.003, (), 2)
    if cheek:
        profile(STOCK, "Cheek riser", [(zc + 0.02, top + 0.006), (z1 - 0.024, top + 0.014), (z1 - 0.03, top + 0.03, 0.01), (zc + 0.03, top + 0.026, 0.01)], 0.016, mat, 0.003, (), 2)


def relief(part, name, outline, half, mat=None, raised=0.0006, bevel=0.0004):
    """A shallow raised panel on both sides of a flat wall."""
    return profile(part, name, outline, half + raised, mat or STEEL, bevel)


def rifle_lower(half=0.0145, grip_mat=POLY, mag_front=-0.172, mag_back=-0.098, mat=STEEL):
    grip(grip_mat)
    trigger_group()
    selector(0.02, 0.026, half)
    well = [(0.08, 0.062), (0.08, 0.016, 0.008), (0.054, -0.006, 0.006), (mag_back - 0.004, -0.006), (mag_back, -0.036, 0.004), (mag_front - 0.002, -0.038, 0.004), (mag_front - 0.006, 0.026, 0.006), (-0.215, 0.05), (-0.215, 0.062)]
    profile(BODY, "Lower receiver", well, half, mat, 0.0018)
    relief(BODY, "Magwell flute", [(mag_back - 0.008, 0.028), (mag_front + 0.004, 0.024), (mag_front + 0.006, -0.03, 0.004), (mag_back - 0.008, -0.028, 0.004)], half, mat)
    pins([(0.03, 0.036), (-0.04, 0.036), (-0.062, 0.016), (0.052, 0.046)], half)
    # Magazine release on the right, bolt catch on the left.
    profile(BODY, "Magazine release", [(-0.09, 0.012), (-0.078, 0.012), (-0.078, 0.024), (-0.09, 0.024)], 0.0012, EDGE, 0.0003, x=half + 0.001)
    profile(BODY, "Bolt catch", [(-0.086, 0.034), (-0.06, 0.03), (-0.056, 0.042, 0.002), (-0.082, 0.05, 0.002)], 0.0016, EDGE, 0.0004, x=-half - 0.001)


def upper_details(half, z_port=-0.02):
    """The controls and machining that make a flat upper receiver read as one."""
    relief(BODY, "Upper flat", [(0.074, 0.062), (0.074, 0.088, 0.002), (-0.012, 0.088, 0.002), (-0.012, 0.062)], half, STEEL)
    profile(BODY, "Port cover", [(z_port + 0.002, 0.058), (z_port - 0.08, 0.058), (z_port - 0.08, 0.063), (z_port + 0.002, 0.063)], 0.0014, EDGE, 0.0003, x=half + 0.001)
    profile(BODY, "Brass deflector", [(0.0, 0.086), (0.026, 0.086), (0.026, 0.094, 0.002), (0.012, 0.094)], 0.004, STEEL, 0.0006, x=half - 0.001)
    profile(BODY, "Assist", [(0.05, 0.066), (0.072, 0.07), (0.072, 0.086, 0.003), (0.05, 0.082, 0.003)], 0.0058, STEEL, 0.0009, x=half + 0.002)


# ---------------------------------------------------------------- long guns

def carbine():
    """Service carbine: forged receivers, slotted polymer handguard, sliding stock."""
    rifle_lower()
    upper = [(0.086, 0.058), (0.086, 0.094, 0.004), (0.06, 0.094), (-0.2, 0.094), (-0.205, 0.056), (-0.1, 0.056), (-0.02, 0.058)]
    profile(BODY, "Upper receiver", upper, 0.0148, STEEL, 0.002)
    rail(0.08, -0.205)
    port(-0.02, -0.095, 0.062, 0.086, 0.0148)
    upper_details(0.0148)
    pins([(-0.195, 0.07)], 0.0148, 0.004)
    # Charging handle tab behind the rail.
    profile(BODY, "Charging handle", [(0.086, 0.086), (0.104, 0.086), (0.108, 0.094, 0.003), (0.086, 0.096)], 0.016, EDGE, 0.0008)
    guard = [(-0.205, 0.022, 0.006), (-0.205, 0.09), (-0.52, 0.09), (-0.53, 0.076, 0.004), (-0.53, 0.036, 0.004), (-0.52, 0.022, 0.006)]
    profile(BODY, "Handguard", guard, 0.0215, POLY, 0.0034, slots(-0.222, -0.512, 0.046, 0.072, 5))
    rail(-0.21, -0.522)
    fluted(BODY, "Barrel", -0.2, -0.63, 0.0108, RIFLE_BORE, STEEL, 6)
    lathe(BODY, "Gas block", [(-0.5, 0.0), (-0.5, 0.016), (-0.525, 0.016), (-0.525, 0.0)], STEEL, 12, RIFLE_BORE)
    flash_hider(-0.68, 0.0125, RIFLE_BORE, 0.058)
    curved_mag(-0.135, -0.018, 0.158, 0.062, 0.0118, 0.05)
    buttstock(0.086, 0.094, -0.066, 0.26)
    irons(0.04, -0.49, 0.145)
    muzzle_mark(-0.68, RIFLE_BORE)


def assault():
    """Long-stroke assault rifle: stamped receiver, laminate furniture, gas tube over the barrel."""
    rifle_lower(0.0155, WOOD, -0.172, -0.098)
    cover = [(0.088, 0.058), (0.086, 0.086, 0.012), (0.03, 0.098, 0.008), (-0.205, 0.098), (-0.21, 0.056), (0.0, 0.056)]
    profile(BODY, "Receiver cover", cover, 0.0158, STEEL, 0.0016)
    # Stamped ribs along the cover.
    for y in (0.066, 0.08):
        profile(BODY, "Stamped rib", [(0.07, y), (-0.19, y), (-0.19, y + 0.004), (0.07, y + 0.004)], 0.0163, STEEL, 0.0005)
    rail(0.06, -0.2)
    port(0.0, -0.09, 0.062, 0.082, 0.0158)
    profile(BODY, "Bolt handle", [(-0.07, 0.066), (-0.046, 0.066), (-0.04, 0.078, 0.003), (-0.05, 0.08, 0.003)], 0.0015, EDGE, 0.0004, x=0.0245)
    profile(BODY, "Bolt stem", [(-0.07, 0.069), (-0.05, 0.069), (-0.05, 0.075), (-0.07, 0.075)], 0.0045, EDGE, 0.0003, x=0.0205)
    lower_guard = [(-0.208, 0.024, 0.004), (-0.208, 0.06), (-0.46, 0.06), (-0.466, 0.028, 0.006)]
    profile(BODY, "Lower handguard", lower_guard, 0.0225, WOOD, 0.0052, slots(-0.22, -0.45, 0.034, 0.05, 3), 2)
    profile(BODY, "Upper handguard", [(-0.215, 0.076), (-0.215, 0.1, 0.008), (-0.4, 0.1, 0.008), (-0.41, 0.076)], 0.0185, WOOD, 0.0042, (), 2)
    lathe(BODY, "Gas tube", [(-0.21, 0.012), (-0.5, 0.012)], STEEL, 10, 0.086)
    lathe(BODY, "Barrel", [(-0.2, 0.0122), (-0.6, 0.0106)], STEEL, 12, RIFLE_BORE)
    profile(BODY, "Gas block", [(-0.47, 0.044), (-0.5, 0.044), (-0.51, 0.1, 0.006), (-0.47, 0.1, 0.006)], 0.0125, STEEL, 0.0012)
    lathe(BODY, "Compensator", [(-0.58, 0.012), (-0.585, 0.0165), (-0.636, 0.0165), (-0.64, 0.0115)], STEEL, 12, RIFLE_BORE, bevel=0.0007)
    for z in (-0.6, -0.615):
        profile(BODY, "Port", [(z - 0.004, RIFLE_BORE + 0.015), (z + 0.004, RIFLE_BORE + 0.015), (z + 0.004, RIFLE_BORE + 0.0172), (z - 0.004, RIFLE_BORE + 0.0172)], 0.006, BLACK, 0)
    crown(-0.64, 0.0115, RIFLE_BORE)
    curved_mag(-0.135, -0.018, 0.17, 0.066, 0.0124, 0.092, 3, STEEL)
    # Skeleton stock of bent tube, folding at the receiver.
    for side in (1, -1):
        tube(STOCK, "Stock strut", [(side * 0.013, 0.074, 0.088), (side * 0.013, 0.05, 0.2), (side * 0.013, 0.04, 0.33)], 0.0058, STEEL, 8)
        tube(STOCK, "Stock lower", [(side * 0.013, 0.03, 0.09), (side * 0.013, -0.02, 0.33)], 0.0058, STEEL, 8)
    profile(STOCK, "Butt plate", [(0.32, 0.07, 0.006), (0.34, 0.07, 0.006), (0.344, -0.05, 0.008), (0.324, -0.05, 0.008)], 0.02, POLY, 0.003, (), 2)
    irons(0.03, -0.482, 0.145, 0.1)
    muzzle_mark(-0.64, RIFLE_BORE)


def rifle():
    """Designated marksman rifle: long free-floating guard, fixed stock, straight magazine."""
    rifle_lower(0.0148, POLY, -0.17, -0.1)
    upper = [(0.09, 0.058), (0.09, 0.094, 0.004), (-0.21, 0.094), (-0.215, 0.056), (0.0, 0.056)]
    profile(BODY, "Upper receiver", upper, 0.0152, EDGE, 0.002)
    rail(0.086, -0.215)
    port(-0.015, -0.1, 0.062, 0.086, 0.0152)
    upper_details(0.0152, -0.015)
    guard = [(-0.215, 0.02, 0.008), (-0.215, 0.09), (-0.64, 0.09), (-0.66, 0.08, 0.004), (-0.66, 0.034, 0.004), (-0.64, 0.02, 0.008)]
    profile(BODY, "Handguard", guard, 0.0225, OLIVE, 0.0036, slots(-0.232, -0.645, 0.044, 0.074, 7, 0.34))
    rail(-0.22, -0.65)
    fluted(BODY, "Barrel", -0.2, -0.795, 0.0118, RIFLE_BORE, STEEL, 8)
    flash_hider(-0.84, 0.0132, RIFLE_BORE, 0.052)
    straight_mag(-0.135, -0.014, 0.112, 0.066, 0.0122, 0.018, 2, STEEL)
    profile(STOCK, "Fixed stock", [(0.086, 0.09), (0.21, 0.09, 0.02), (0.36, 0.098), (0.37, -0.068, 0.012), (0.3, -0.07, 0.01), (0.2, -0.02, 0.03), (0.086, 0.018)], 0.0185, POLY, 0.0048, [[(0.13, 0.058, 0.008), (0.31, 0.066, 0.008), (0.32, -0.048, 0.008), (0.215, -0.002, 0.016)]], 2)
    profile(STOCK, "Butt pad", [(0.368, 0.1, 0.008), (0.386, 0.1, 0.008), (0.39, -0.07, 0.008), (0.372, -0.07, 0.008)], 0.02, BLACK, 0.003, (), 2)
    profile(STOCK, "Cheek piece", [(0.17, 0.092), (0.33, 0.098), (0.32, 0.122, 0.012), (0.18, 0.118, 0.012)], 0.0165, POLY, 0.003, (), 2)
    scope_on_rail(-0.075, 0.145, 0.3)
    irons(-0.235, -0.625, 0.145, 0.1)
    muzzle_mark(-0.84, RIFLE_BORE)


def sniper():
    """Precision bolt-action on a metal chassis, with a heavy fluted barrel."""
    rifle_lower(0.0162, POLY, -0.17, -0.1, EDGE)
    chassis = [(0.09, 0.03), (0.09, 0.09, 0.006), (-0.21, 0.09), (-0.22, 0.066), (-0.5, 0.05, 0.012), (-0.52, 0.026, 0.006), (-0.2, 0.012, 0.01), (-0.1, 0.03)]
    profile(BODY, "Chassis", chassis, 0.0235, OLIVE, 0.0032, slots(-0.235, -0.49, 0.034, 0.05, 4))
    lathe(BODY, "Action", [(0.088, 0.0195), (0.092, 0.018), (-0.205, 0.0195), (-0.21, 0.016)], EDGE, 16, 0.066)
    rail(0.09, -0.21)
    port(0.0, -0.1, 0.058, 0.08, 0.0195, False)
    # The bolt handle reaching back to the shooter's hand.
    tube(BODY, "Bolt handle", [(0.018, 0.074, 0.05), (0.038, 0.066, 0.062), (0.06, 0.05, 0.068)], 0.0034, EDGE, 8)
    upright(BODY, "Bolt knob", [(0.04, 0.0, 0.0), (0.043, 0.008, 0.008), (0.054, 0.0105, 0.0105), (0.062, 0.0, 0.0)], EDGE, 10, 0.06, 0.068)
    fluted(BODY, "Barrel", -0.2, -1.0, 0.0152, RIFLE_BORE, STEEL, 8, 0.16)
    lathe(BODY, "Muzzle brake", [(-1.0, 0.016), (-1.004, 0.0225), (-1.115, 0.0225), (-1.12, 0.017)], STEEL, 14, RIFLE_BORE, bevel=0.0009)
    for z in (-1.02, -1.045, -1.07, -1.095):
        for side in (1, -1):
            profile(BODY, "Brake port", [(z - 0.007, RIFLE_BORE - 0.012), (z + 0.007, RIFLE_BORE - 0.012), (z + 0.007, RIFLE_BORE + 0.012), (z - 0.007, RIFLE_BORE + 0.012)], 0.0016, BLACK, 0, x=side * 0.0218)
    crown(-1.12, 0.017, RIFLE_BORE)
    bipod_folded(-0.47, 0.02)
    straight_mag(-0.135, -0.012, 0.09, 0.068, 0.0128, 0.006, 1, STEEL)
    profile(STOCK, "Stock frame", [(0.09, 0.09), (0.4, 0.086), (0.41, -0.07, 0.01), (0.33, -0.08, 0.012), (0.3, -0.02, 0.016), (0.09, 0.012)], 0.0115, EDGE, 0.002, [[(0.11, 0.074, 0.008), (0.2, 0.07, 0.008), (0.2, 0.02, 0.008), (0.11, 0.028, 0.008)], [(0.22, 0.07, 0.008), (0.36, 0.068, 0.008), (0.37, -0.056, 0.008), (0.325, -0.056, 0.008), (0.3, 0.0, 0.01), (0.22, 0.016, 0.008)]])
    profile(STOCK, "Cheek rest", [(0.19, 0.088), (0.36, 0.09), (0.35, 0.124, 0.012), (0.2, 0.122, 0.012)], 0.0175, POLY, 0.003, (), 2)
    for z in (0.23, 0.33):
        tube(STOCK, "Riser post", [(0, 0.08, z), (0, 0.1, z)], 0.005, EDGE, 8)
    profile(STOCK, "Butt pad", [(0.408, 0.092, 0.008), (0.428, 0.092, 0.008), (0.432, -0.08, 0.008), (0.412, -0.08, 0.008)], 0.02, BLACK, 0.003, (), 2)
    scope_on_rail(-0.075, 0.145, 0.34, 0.025)
    muzzle_mark(-1.12, RIFLE_BORE)


def silent():
    """Integrally suppressed rifle: the whole barrel lives inside a wide shroud."""
    rifle_lower(0.0148, POLY, -0.17, -0.1)
    profile(BODY, "Receiver", [(0.086, 0.056), (0.086, 0.094, 0.004), (-0.215, 0.094), (-0.22, 0.05), (0.0, 0.054)], 0.0152, STEEL, 0.002)
    rail(0.08, -0.22)
    port(-0.02, -0.098, 0.062, 0.086, 0.0152)
    upper_details(0.0152)
    lathe(BODY, "Suppressor shroud", [(-0.215, 0.0255), (-0.222, 0.0285), (-0.72, 0.0285), (-0.73, 0.0265), (-0.74, 0.0195)], OLIVE, 18, RIFLE_BORE, bevel=0.0012)
    for z in (-0.3, -0.36, -0.42, -0.48, -0.54, -0.6, -0.66):
        lathe(BODY, "Cooling ring", [(z + 0.0035, 0.0288), (z + 0.0028, 0.0302), (z - 0.0028, 0.0302), (z - 0.0035, 0.0288)], BLACK, 18, RIFLE_BORE)
    crown(-0.74, 0.0195, RIFLE_BORE)
    guard = [(-0.215, 0.02, 0.008), (-0.215, 0.092), (-0.42, 0.092), (-0.43, 0.02, 0.008)]
    profile(BODY, "Upper guard", guard, 0.0305, POLY, 0.0036, slots(-0.23, -0.415, 0.024, 0.038, 3))
    rail(-0.218, -0.42)
    curved_mag(-0.135, -0.018, 0.13, 0.06, 0.0118, 0.022, 2)
    # Thumbhole stock in one sculpted piece.
    profile(STOCK, "Stock", [(0.08, 0.09), (0.2, 0.088, 0.02), (0.36, 0.1), (0.372, -0.07, 0.012), (0.27, -0.09, 0.02), (0.13, -0.035, 0.02), (0.075, 0.0)], 0.0185, POLY, 0.0052, [[(0.1, 0.05, 0.012), (0.17, 0.05, 0.012), (0.17, 0.0, 0.016), (0.11, 0.0, 0.012)]], 2)
    profile(STOCK, "Butt pad", [(0.37, 0.102, 0.008), (0.388, 0.102, 0.008), (0.39, -0.072, 0.008), (0.372, -0.072, 0.008)], 0.02, BLACK, 0.003, (), 2)
    scope_on_rail(-0.075, 0.145, 0.26)
    irons(-0.24, -0.4, 0.145, 0.1)
    muzzle_mark(-0.74, RIFLE_BORE)


def rail_rifle():
    """Coil gun: open accelerator rails around the bore, fed by a capacitor bank."""
    grip()
    trigger_group()
    selector(0.02, 0.022, 0.018)
    shell = [(0.096, 0.03, 0.006), (0.096, 0.09, 0.01), (-0.1, 0.094), (-0.26, 0.09, 0.01), (-0.28, 0.03, 0.008), (-0.172, 0.014), (-0.1, 0.0, 0.006), (0.0, 0.002)]
    profile(BODY, "Capacitor housing", shell, 0.0235, OLIVE, 0.0034, [[(-0.255, 0.04, 0.004), (-0.19, 0.04, 0.004), (-0.19, 0.078, 0.004), (-0.255, 0.078, 0.004)]])
    lathe(BODY, "Core", [(-0.25, 0.012), (-0.27, 0.0135), (-1.11, 0.0098)], STEEL, 12, RIFLE_BORE)
    rail(0.09, -0.26)
    relief(BODY, "Housing panel", [(0.08, 0.036), (0.082, 0.082, 0.006), (-0.12, 0.086, 0.006), (-0.15, 0.03, 0.006), (-0.02, 0.014, 0.006)], 0.0235, STEEL, 0.0008)
    for z, y in ((0.06, 0.05), (0.06, 0.07), (-0.1, 0.05), (-0.1, 0.07)):
        pins([(z, y)], 0.0245, 0.0032)
    for z in (-0.06, -0.03, 0.0):
        profile(BODY, "Vent", [(z - 0.008, 0.048), (z + 0.008, 0.048), (z + 0.008, 0.074), (z - 0.008, 0.074)], 0.0003, BLACK, 0, x=0.0246)
    for side in (1, -1):
        x0 = side * 0.0145
        outline = [(-0.26, 0.082), (-0.28, 0.086), (-1.1, 0.076), (-1.15, 0.07, 0.004), (-1.15, 0.05, 0.004), (-1.1, 0.044), (-0.28, 0.034), (-0.26, 0.038)]
        cut = slots(-0.32, -1.08, 0.05, 0.072, 8, 0.2)
        profile(BODY, "Accelerator rail", outline, 0.0052, STEEL, 0.0014, cut, x=x0)
    for i, z in enumerate((-0.34, -0.48, -0.62, -0.76, -0.9, -1.04)):
        ring = [(z - 0.012, 0.026, 0.004), (z + 0.012, 0.026, 0.004), (z + 0.012, 0.094, 0.004), (z - 0.012, 0.094, 0.004)]
        profile(BODY, "Coil clamp", ring, 0.0232, EDGE if i % 2 else STEEL, 0.0018, [[(z - 0.006, 0.042), (z + 0.006, 0.042), (z + 0.006, 0.078), (z - 0.006, 0.078)]])
        profile(BODY, "Coil lamp", [(z - 0.004, 0.088), (z + 0.004, 0.088), (z + 0.004, 0.092), (z - 0.004, 0.092)], 0.0236, CORE, 0)
    lathe(BODY, "Muzzle ring", [(-1.1, 0.0), (-1.1, 0.03), (-1.112, 0.0335), (-1.15, 0.0335), (-1.16, 0.024), (-1.16, 0.014)], STEEL, 16, RIFLE_BORE, bevel=0.0009)
    crown(-1.16, 0.014, RIFLE_BORE)
    bipod_folded(-0.3, 0.02)
    # A capacitor cell in place of a magazine.
    straight_mag(-0.135, 0.006, 0.12, 0.074, 0.0185, 0.0, 2, OLIVE)
    profile(STOCK, "Stock", [(0.096, 0.09), (0.3, 0.09, 0.016), (0.38, 0.098), (0.388, -0.07, 0.012), (0.33, -0.074, 0.012), (0.27, -0.01, 0.02), (0.096, 0.02)], 0.0195, OLIVE, 0.0048, [[(0.13, 0.066, 0.008), (0.25, 0.066, 0.008), (0.25, 0.022, 0.012), (0.13, 0.034, 0.008)]], 2)
    profile(STOCK, "Butt pad", [(0.386, 0.1, 0.008), (0.404, 0.1, 0.008), (0.408, -0.074, 0.008), (0.39, -0.074, 0.008)], 0.021, BLACK, 0.003, (), 2)
    scope_on_rail(-0.075, 0.145, 0.32, 0.025)
    muzzle_mark(-1.16, RIFLE_BORE)


def heavy():
    """Support weapon: heavy receiver, carrying handle, quick-change barrel and a side box."""
    grip()
    trigger_group()
    selector(0.02, 0.022, 0.024)
    receiver = [(0.09, 0.02), (0.1, 0.13, 0.01), (0.02, 0.15, 0.008), (-0.26, 0.15), (-0.27, 0.03, 0.006), (-0.14, 0.0, 0.01), (0.0, 0.002)]
    profile(BODY, "Receiver", receiver, 0.0285, STEEL, 0.0032, [[(-0.255, 0.05, 0.005), (-0.19, 0.05, 0.005), (-0.19, 0.08, 0.005), (-0.255, 0.08, 0.005)]])
    profile(BODY, "Feed cover", [(0.02, 0.146), (0.03, 0.15, 0.006), (-0.25, 0.152, 0.006), (-0.26, 0.146)], 0.0255, STEEL, 0.0022)
    rail(0.02, -0.25, 0.156, 0.0115)
    port(-0.04, -0.13, 0.05, 0.09, 0.0285)
    relief(BODY, "Side rail", [(0.07, 0.112), (0.07, 0.122), (-0.25, 0.128), (-0.25, 0.118)], 0.0285, STEEL, 0.0014, 0.0008)
    relief(BODY, "Side rib", [(0.06, 0.03), (0.07, 0.1, 0.006), (-0.02, 0.1, 0.006), (-0.02, 0.03, 0.006)], 0.0285, STEEL, 0.001)
    pins([(0.05, 0.05), (0.05, 0.09), (0.0, 0.05), (0.0, 0.09), (-0.2, 0.1), (-0.2, 0.04), (-0.25, 0.1), (-0.25, 0.04)], 0.0295, 0.0036)
    profile(BODY, "Latch", [(0.02, 0.14), (0.04, 0.138), (0.044, 0.148, 0.004), (0.024, 0.15)], 0.027, EDGE, 0.001)
    # Quick-change barrel in a perforated jacket.
    fluted(BODY, "Barrel", -0.26, -0.83, 0.0172, RIFLE_BORE, STEEL, 6)
    jacket = [(-0.262, 0.03, 0.006), (-0.262, 0.094, 0.006), (-0.56, 0.086, 0.006), (-0.57, 0.032, 0.006)]
    profile(BODY, "Barrel jacket", jacket, 0.027, STEEL, 0.0024, slots(-0.28, -0.555, 0.044, 0.078, 6, 0.36))
    lathe(BODY, "Gas tube", [(-0.26, 0.0098), (-0.66, 0.0098)], STEEL, 10, 0.02)
    profile(BODY, "Gas block", [(-0.64, 0.0), (-0.68, 0.0), (-0.68, 0.09, 0.006), (-0.64, 0.09, 0.006)], 0.0145, STEEL, 0.0016)
    flash_hider(-0.9, 0.0195, RIFLE_BORE, 0.08)
    # Carrying handle swinging over the barrel.
    tube(BODY, "Handle", [(0, 0.09, -0.3), (0.03, 0.135, -0.32), (0.03, 0.14, -0.46), (0, 0.09, -0.48)], 0.0075, POLY, 8)
    for side in (1, -1):
        tube(BODY, "Bipod leg", [(side * 0.016, 0.0, -0.66), (side * 0.03, -0.012, -0.44)], 0.0072, STEEL, 8)
    # Side box: the geometry WeaponFactory stretches for larger cells.
    box = [(-0.08, -0.105), (-0.24, -0.105), (-0.24, 0.035, 0.008), (-0.08, 0.035, 0.008)]
    profile(CELL, "Ammunition box", box, 0.066, OLIVE, 0.0034, x=-0.092)
    for z in (-0.12, -0.16, -0.2):
        profile(CELL, "Box rib", [(z - 0.006, -0.1), (z + 0.006, -0.1), (z + 0.006, 0.03), (z - 0.006, 0.03)], 0.0675, OLIVE, 0.0008, x=-0.092)
    profile(CELL, "Lid", [(-0.074, 0.03), (-0.246, 0.03), (-0.246, 0.046, 0.005), (-0.074, 0.046, 0.005)], 0.069, STEEL, 0.002, x=-0.092)
    tube(CELL, "Feed chute", [(-0.1, 0.046, -0.16), (-0.044, 0.09, -0.16), (-0.02, 0.1, -0.16)], 0.016, BLACK, 8)
    # Stock.
    profile(STOCK, "Stock", [(0.09, 0.13), (0.3, 0.104, 0.012), (0.34, 0.11), (0.348, -0.06, 0.012), (0.27, -0.066, 0.012), (0.2, 0.0, 0.02), (0.09, 0.02)], 0.0215, POLY, 0.0048, [[(0.13, 0.1, 0.008), (0.26, 0.086, 0.008), (0.26, 0.016, 0.012), (0.13, 0.04, 0.008)]], 2)
    profile(STOCK, "Butt pad", [(0.346, 0.112, 0.008), (0.366, 0.112, 0.008), (0.368, -0.064, 0.008), (0.35, -0.064, 0.008)], 0.023, BLACK, 0.003, (), 2)
    irons(-0.03, -0.66, 0.205, 0.156, 0.09)
    muzzle_mark(-0.9, RIFLE_BORE)


def smg():
    """Compact submachine gun with a wire stock and a vented barrel shroud."""
    grip()
    trigger_group()
    selector(0.022, 0.024, 0.0165)
    shell = [(0.082, 0.03, 0.006), (0.082, 0.094, 0.008), (-0.25, 0.094), (-0.26, 0.03, 0.006), (-0.17, 0.0), (-0.11, 0.0), (0.0, 0.0)]
    profile(BODY, "Receiver", shell, 0.0172, POLY, 0.0034, slots(-0.195, -0.25, 0.036, 0.078, 1, 0.2))
    rail(0.076, -0.25)
    port(-0.03, -0.1, 0.06, 0.084, 0.0172)
    relief(BODY, "Side panel", [(0.07, 0.036), (0.072, 0.086, 0.004), (-0.012, 0.088, 0.004), (-0.014, 0.036)], 0.0172, POLY, 0.0008, 0.0006)
    relief(BODY, "Side rib", [(-0.11, 0.012), (-0.11, 0.04, 0.004), (-0.19, 0.04, 0.004), (-0.19, 0.012)], 0.0172, POLY, 0.0012, 0.0006)
    pins([(0.056, 0.05), (-0.02, 0.02), (-0.15, 0.08)], 0.0172, 0.0034)
    profile(BODY, "Magazine release", [(-0.09, 0.014), (-0.076, 0.014), (-0.076, 0.026), (-0.09, 0.026)], 0.0014, EDGE, 0.0003, x=0.0186)
    profile(BODY, "Cocking slot", [(-0.11, 0.074), (-0.19, 0.074), (-0.19, 0.08), (-0.11, 0.08)], 0.0006, BLACK, 0, x=-0.0174)
    tube(BODY, "Cocking arm", [(-0.016, 0.077, -0.14), (-0.034, 0.078, -0.14)], 0.0042, EDGE, 8)
    lathe(BODY, "Barrel", [(-0.25, 0.0108), (-0.378, 0.0102)], STEEL, 12, RIFLE_BORE)
    lathe(BODY, "Barrel nut", [(-0.256, 0.0), (-0.256, 0.018), (-0.272, 0.018), (-0.272, 0.0)], STEEL, 12, RIFLE_BORE)
    flash_hider(-0.42, 0.0118, RIFLE_BORE, 0.05)
    straight_mag(-0.135, 0.002, 0.16, 0.044, 0.0105, 0.016, 3, STEEL)
    for side in (1, -1):
        tube(STOCK, "Wire stock", [(side * 0.013, 0.08, 0.08), (side * 0.013, 0.082, 0.3), (side * 0.013, -0.04, 0.3), (side * 0.013, 0.03, 0.078)], 0.0048, STEEL, 8)
    profile(STOCK, "Butt plate", [(0.292, 0.09, 0.006), (0.31, 0.09, 0.006), (0.31, -0.05, 0.006), (0.292, -0.05, 0.006)], 0.018, POLY, 0.003, (), 2)
    irons(0.04, -0.235, 0.145, 0.1)
    muzzle_mark(-0.42, RIFLE_BORE)


def smg2():
    """Personal defence weapon: a sculpted polymer shell, forward grip block, sliding stock rods."""
    grip()
    trigger_group()
    shell = [(0.09, 0.026, 0.01), (0.092, 0.09, 0.012), (-0.11, 0.098, 0.018), (-0.36, 0.09, 0.016), (-0.39, 0.056, 0.01), (-0.36, 0.018, 0.012), (-0.2, 0.002, 0.016), (0.0, 0.002)]
    profile(BODY, "Shell", shell, 0.0208, POLY, 0.0048, [[(-0.35, 0.034, 0.006), (-0.27, 0.03, 0.006), (-0.27, 0.052, 0.006), (-0.35, 0.056, 0.006)]], 2)
    profile(BODY, "Shell panel", [(0.04, 0.03), (0.05, 0.08, 0.008), (-0.08, 0.086, 0.01), (-0.2, 0.076, 0.01), (-0.17, 0.03, 0.01)], 0.0212, OLIVE, 0.0008)
    rail(0.086, -0.355)
    port(-0.04, -0.11, 0.062, 0.082, 0.0212)
    pins([(0.06, 0.05), (-0.03, 0.022), (-0.25, 0.068)], 0.0212, 0.0034)
    profile(BODY, "Magazine release", [(-0.09, 0.014), (-0.076, 0.014), (-0.076, 0.026), (-0.09, 0.026)], 0.0014, EDGE, 0.0003, x=0.0222)
    selector(0.022, 0.026, 0.0208)
    lathe(BODY, "Barrel", [(-0.36, 0.0115), (-0.49, 0.0108)], STEEL, 12, RIFLE_BORE)
    lathe(BODY, "Muzzle device", [(-0.47, 0.0), (-0.47, 0.0165), (-0.53, 0.0165), (-0.53, 0.012)], STEEL, 12, RIFLE_BORE, bevel=0.0008)
    crown(-0.53, 0.012, RIFLE_BORE)
    curved_mag(-0.135, 0.006, 0.142, 0.05, 0.0115, 0.03, 3)
    profile(BODY, "Hand stop", [(-0.3, 0.014), (-0.27, 0.01), (-0.29, -0.024, 0.008), (-0.31, -0.024, 0.006)], 0.012, POLY, 0.003, (), 2)
    for side in (1, -1):
        lathe(STOCK, "Stock rod", [(0.09, 0.006), (0.27, 0.006)], STEEL, 8, 0.076, side * 0.012)
        lathe(STOCK, "Stock rod", [(0.09, 0.006), (0.27, 0.006)], STEEL, 8, 0.03, side * 0.012)
    profile(STOCK, "Butt plate", [(0.262, 0.1, 0.008), (0.284, 0.1, 0.008), (0.288, -0.06, 0.012), (0.268, -0.06, 0.012)], 0.02, POLY, 0.004, (), 2)
    irons(0.04, -0.34, 0.145, 0.1)
    muzzle_mark(-0.53, RIFLE_BORE)


def scatter():
    """Combat shotgun: pump forend on a magazine tube, ghost ring sights, ventilated rib."""
    grip(POLY)
    trigger_group()
    selector(0.022, 0.03, 0.0195)
    receiver = [(0.082, 0.024), (0.082, 0.09, 0.01), (0.03, 0.1, 0.006), (-0.2, 0.1), (-0.21, 0.018, 0.006), (-0.16, 0.0), (0.0, 0.002)]
    profile(BODY, "Receiver", receiver, 0.0195, STEEL, 0.0026)
    rail(0.06, -0.2)
    port(-0.04, -0.13, 0.058, 0.09, 0.0195, False)
    relief(BODY, "Side plate", [(0.066, 0.03), (0.07, 0.088, 0.004), (-0.022, 0.094, 0.004), (-0.022, 0.03)], 0.0195, STEEL)
    relief(BODY, "Side plate front", [(-0.15, 0.02), (-0.15, 0.09, 0.004), (-0.19, 0.09, 0.004), (-0.195, 0.022, 0.004)], 0.0195, STEEL)
    pins([(0.05, 0.04), (0.05, 0.078), (-0.01, 0.04), (-0.01, 0.08), (-0.17, 0.04), (-0.17, 0.08)], 0.0202, 0.003)
    lathe(BODY, "Barrel", [(-0.2, 0.0168), (-0.53, 0.0158)], STEEL, 14, 0.07)
    lathe(BODY, "Magazine tube", [(-0.2, 0.0145), (-0.45, 0.0145), (-0.452, 0.016), (-0.47, 0.016), (-0.474, 0.012)], STEEL, 14, 0.03)
    profile(BODY, "Vent rib", [(-0.205, 0.087), (-0.5, 0.086), (-0.5, 0.094), (-0.205, 0.098)], 0.0052, STEEL, 0.0006, slots(-0.22, -0.49, 0.0878, 0.0925, 9, 0.5))
    profile(BODY, "Barrel clamp", [(-0.44, 0.01), (-0.47, 0.01), (-0.47, 0.09, 0.008), (-0.44, 0.09, 0.008)], 0.0175, STEEL, 0.0014)
    forend = [(-0.235, 0.008, 0.006), (-0.235, 0.05), (-0.405, 0.05), (-0.405, 0.008, 0.006)]
    profile(BODY, "Pump forend", forend, 0.0245, POLY, 0.0044, (), 2)
    for z in (-0.26, -0.285, -0.31, -0.335, -0.36, -0.385):
        profile(BODY, "Forend rib", [(z - 0.006, 0.006), (z + 0.006, 0.006), (z + 0.006, 0.05), (z - 0.006, 0.05)], 0.0252, POLY, 0.0014)
    lathe(BODY, "Choke", [(-0.5, 0.0), (-0.5, 0.0185), (-0.53, 0.0185), (-0.534, 0.0165)], STEEL, 14, 0.07, bevel=0.0008)
    crown(-0.534, 0.0165, 0.07)
    # Shell carrier in front of the trigger: the part that swaps out on a reload.
    box = [(-0.1, 0.006), (-0.19, 0.006), (-0.186, -0.062, 0.006), (-0.104, -0.062, 0.006)]
    profile(CELL, "Shell carrier", box, 0.0195, STEEL, 0.002)
    for i in range(3):
        y = -0.012 - i * 0.017
        lathe(CELL, "Shell", [(-0.108, 0.0072), (-0.178, 0.0072)], OLIVE, 10, y, 0.0205)
        lathe(CELL, "Shell rim", [(-0.102, 0.0078), (-0.108, 0.0078)], EDGE, 10, y, 0.0205)
    profile(STOCK, "Stock", [(0.08, 0.09), (0.3, 0.072, 0.012), (0.33, 0.08), (0.338, -0.076, 0.012), (0.26, -0.082, 0.012), (0.14, -0.01, 0.02), (0.08, 0.02)], 0.0195, POLY, 0.005, [[(0.13, 0.062, 0.008), (0.25, 0.052, 0.008), (0.25, -0.002, 0.012), (0.15, 0.022, 0.008)]], 2)
    profile(STOCK, "Butt pad", [(0.336, 0.082, 0.008), (0.356, 0.082, 0.008), (0.36, -0.08, 0.008), (0.34, -0.08, 0.008)], 0.021, BLACK, 0.003, (), 2)
    irons(0.04, -0.46, 0.145, 0.1, 0.09)
    muzzle_mark(-0.534, 0.07)


# ---------------------------------------------------------------- sidearms

def slide_serrations(z_rear, z_front, count, y0, y1, half):
    for i in range(count):
        z = z_rear - (z_rear - z_front) * i / (count - 1)
        profile(BODY, "Serration", [(z - 0.0014, y0), (z + 0.0014, y0), (z + 0.0034, y1), (z + 0.0006, y1)], 0.0004, BLACK, 0, x=half + 0.0002)
        profile(BODY, "Serration", [(z - 0.0014, y0), (z + 0.0014, y0), (z + 0.0034, y1), (z + 0.0006, y1)], 0.0004, BLACK, 0, x=-half - 0.0002)


def pistol_frame(cell=True):
    """Polymer frame with an accessory rail, shared by the two semi-automatic sidearms."""
    frame = [(0.056, 0.062), (0.058, 0.044, 0.004), (0.078, -0.098, 0.01), (0.026, -0.104, 0.008), (0.006, -0.022, 0.01), (-0.004, -0.024), (-0.074, -0.026, 0.012), (-0.096, 0.012, 0.012), (-0.096, 0.03), (-0.112, 0.036), (-0.205, 0.036, 0.004), (-0.205, 0.062)]
    guard = [(-0.008, 0.026, 0.003), (-0.086, 0.026, 0.003), (-0.086, 0.014, 0.005), (-0.066, -0.016, 0.008), (-0.012, -0.014, 0.006)]
    profile(BODY, "Frame", frame, 0.0132, POLY, 0.0034, [guard], 2)
    for i in range(8):
        y = -0.02 - i * 0.0095
        z0, z1 = 0.014 + 0.0024 * i, 0.058 + 0.0024 * i
        profile(BODY, "Grip stipple", [(z0, y), (z1, y + 0.0015), (z1, y + 0.0055), (z0, y + 0.004)], 0.0136, BLACK, 0.0002)
    profile(BODY, "Trigger", [(-0.05, 0.03), (-0.04, 0.03), (-0.044, 0.01, 0.004), (-0.056, -0.004), (-0.062, -0.002), (-0.052, 0.012, 0.004)], 0.0034, EDGE, 0.0006)
    for z in (-0.13, -0.15, -0.17, -0.19):
        profile(BODY, "Rail slot", [(z - 0.005, 0.03), (z + 0.005, 0.03), (z + 0.005, 0.038), (z - 0.005, 0.038)], 0.0136, BLACK, 0)
    profile(BODY, "Takedown", [(-0.074, 0.05), (-0.058, 0.05), (-0.058, 0.056), (-0.074, 0.056)], 0.0138, EDGE, 0.0003)
    profile(BODY, "Slide stop", [(-0.03, 0.05), (-0.006, 0.05), (-0.002, 0.058, 0.002), (-0.028, 0.058)], 0.0138, EDGE, 0.0003)
    profile(BODY, "Magazine release", [(0.0, 0.02), (0.012, 0.02), (0.012, 0.03), (0.0, 0.03)], 0.0148, EDGE, 0.0003)
    if cell:
        straight_mag(0.05, -0.024, 0.086, 0.04, 0.0108, -0.018, 0, STEEL)


def pistol():
    """Service pistol with a stepped slide and a compensated barrel."""
    pistol_frame()
    slide = [(0.056, 0.058), (0.056, 0.104, 0.005), (0.04, 0.112, 0.006), (-0.2, 0.112, 0.006), (-0.215, 0.1, 0.004), (-0.215, 0.058)]
    profile(BODY, "Slide", slide, 0.0132, STEEL, 0.0022)
    profile(BODY, "Slide cut", [(-0.1, 0.086), (-0.2, 0.086), (-0.2, 0.094, 0.002), (-0.1, 0.094, 0.002)], 0.0137, EDGE, 0.0004)
    port(-0.015, -0.075, 0.082, 0.106, 0.0132, False)
    slide_serrations(0.05, 0.016, 8, 0.066, 0.104, 0.0132)
    slide_serrations(-0.15, -0.195, 7, 0.066, 0.086, 0.0132)
    lathe(BODY, "Barrel", [(-0.2, 0.0098), (-0.232, 0.0098)], EDGE, 12, PISTOL_BORE)
    lathe(BODY, "Compensator", [(-0.214, 0.0), (-0.214, 0.0145), (-0.268, 0.0145), (-0.272, 0.0105)], STEEL, 12, PISTOL_BORE, bevel=0.0007)
    for z in (-0.232, -0.25):
        profile(BODY, "Port", [(z - 0.005, PISTOL_BORE + 0.013), (z + 0.005, PISTOL_BORE + 0.013), (z + 0.005, PISTOL_BORE + 0.0152), (z - 0.005, PISTOL_BORE + 0.0152)], 0.0058, BLACK, 0)
    crown(-0.272, 0.0105, PISTOL_BORE)
    profile(BODY, "Hammer", [(0.05, 0.1), (0.066, 0.1), (0.07, 0.112, 0.003), (0.06, 0.116, 0.003), (0.05, 0.106)], 0.0042, EDGE, 0.0007)
    # Sights sit right on the slide, so their line is the pistol sight line.
    profile(SIGHT, "Rear sight", [(0.036, 0.11), (0.012, 0.11), (0.014, 0.118, 0.002), (0.034, 0.118, 0.002)], 0.0115, BLACK, 0.0007)
    profile(SIGHT, "Front sight", [(-0.178, 0.11), (-0.198, 0.11), (-0.196, 0.117, 0.002), (-0.182, 0.117, 0.002)], 0.003, BLACK, 0.0004)
    muzzle_mark(-0.272, PISTOL_BORE)


def mpistol():
    """Machine pistol: a pistol's frame with a long magazine, folding fore-grip and shroud."""
    pistol_frame(False)
    slide = [(0.056, 0.058), (0.056, 0.106, 0.006), (-0.205, 0.108, 0.006), (-0.215, 0.096, 0.004), (-0.215, 0.058)]
    profile(BODY, "Upper", slide, 0.0145, OLIVE, 0.0024, slots(-0.12, -0.21, 0.066, 0.092, 3, 0.4))
    lathe(BODY, "Barrel", [(-0.05, 0.01), (-0.25, 0.01)], EDGE, 12, PISTOL_BORE)
    lathe(BODY, "Muzzle", [(-0.23, 0.0), (-0.23, 0.0155), (-0.296, 0.0155), (-0.3, 0.0115)], STEEL, 12, PISTOL_BORE, bevel=0.0008)
    crown(-0.3, 0.0115, PISTOL_BORE)
    port(0.0, -0.06, 0.084, 0.102, 0.0145, False)
    slide_serrations(0.05, 0.014, 6, 0.066, 0.102, 0.0145)
    profile(BODY, "Fore grip", [(-0.17, 0.038), (-0.135, 0.038), (-0.122, -0.056, 0.008), (-0.158, -0.056, 0.008)], 0.0115, POLY, 0.0034, (), 2)
    straight_mag(0.05, -0.024, 0.2, 0.04, 0.0108, -0.042, 3, STEEL)
    profile(SIGHT, "Rear sight", [(0.036, 0.106), (0.012, 0.106), (0.014, 0.117, 0.002), (0.034, 0.117, 0.002)], 0.0115, BLACK, 0.0007)
    profile(SIGHT, "Front sight", [(-0.178, 0.106), (-0.198, 0.106), (-0.196, 0.117, 0.002), (-0.182, 0.117, 0.002)], 0.003, BLACK, 0.0004)
    muzzle_mark(-0.3, PISTOL_BORE)


def revolver():
    """Double-action revolver: forged frame with a top strap, full lug and fluted cylinder."""
    frame = [(0.062, 0.03, 0.006), (0.058, 0.104, 0.01), (-0.046, 0.112, 0.006), (-0.17, 0.106), (-0.172, 0.046), (-0.09, 0.03, 0.006), (-0.09, 0.014, 0.006), (-0.012, 0.012, 0.004), (0.0, -0.006), (0.06, -0.006)]
    window = [(-0.012, 0.05, 0.004), (0.036, 0.05, 0.004), (0.036, 0.098, 0.004), (-0.082, 0.098, 0.004), (-0.082, 0.05, 0.004)]
    profile(BODY, "Frame", frame, 0.0165, STEEL, 0.0024, [window])
    outer = [(-0.008, 0.022), (-0.1, 0.022), (-0.1, 0.004, 0.006), (-0.08, -0.03, 0.01), (-0.018, -0.03, 0.01), (-0.004, 0.0)]
    hole = [(-0.02, 0.012, 0.004), (-0.09, 0.012, 0.004), (-0.074, -0.02, 0.006), (-0.024, -0.02, 0.006)]
    profile(BODY, "Trigger guard", outer, 0.006, STEEL, 0.0012, [hole])
    profile(BODY, "Trigger", [(-0.052, 0.02), (-0.042, 0.02), (-0.046, 0.002, 0.004), (-0.056, -0.012), (-0.062, -0.01), (-0.054, 0.004, 0.004)], 0.0034, STEEL, 0.0006)
    # Cylinder: six flutes in a ring, on the bore line of the top chamber.
    cy = 0.0645
    sides = 36
    ring = []
    for i in range(sides):
        a = math.tau * i / sides
        k = (i % 6) / 6
        groove = 0.0052 * math.sin(math.pi * min(max((k - 0.15) / 0.7, 0), 1))
        r = 0.0335 - groove
        ring.append((r * math.cos(a), cy + r * math.sin(a)))
    stations = []
    for z in (0.03, -0.074):
        stations.append([(p[0], p[1], z) for p in ring])
    obj = add(BODY, "Cylinder", [B(p) for st in stations for p in st], rings_to_faces(2, sides), STEEL)
    outward(obj)
    worn_chamfer(obj, 0.0012, 35.0)
    for i in range(6):
        a = math.tau * i / 6 + 0.26
        lathe(BODY, "Chamber", [(-0.0745, 0.0058), (-0.0748, 0.0)], BLACK, 8, cy + 0.021 * math.sin(a), 0.021 * math.cos(a))
    # Round barrel over a slim ejector shroud, under a vented rib.
    lathe(BODY, "Barrel", [(-0.17, 0.0166), (-0.312, 0.0152), (-0.32, 0.0132)], STEEL, 16, PISTOL_BORE, bevel=0.0006)
    profile(BODY, "Ejector shroud", [(-0.165, 0.076), (-0.3, 0.078), (-0.31, 0.072, 0.003), (-0.31, 0.05, 0.006), (-0.165, 0.048)], 0.0072, STEEL, 0.0018)
    profile(BODY, "Top rib", [(-0.17, 0.092), (-0.318, 0.092), (-0.318, 0.104), (-0.17, 0.104)], 0.0055, STEEL, 0.0008, slots(-0.18, -0.31, 0.0968, 0.1012, 5, 0.5))
    crown(-0.32, 0.0132, PISTOL_BORE)
    lathe(BODY, "Ejector", [(-0.31, 0.0034), (-0.316, 0.0034)], EDGE, 8, 0.058)
    pins([(0.03, 0.022), (-0.03, 0.03), (0.05, 0.05)], 0.0168, 0.003)
    relief(BODY, "Side plate", [(0.052, 0.012), (0.052, 0.044, 0.004), (-0.004, 0.044, 0.004), (-0.004, 0.012)], 0.0165, EDGE)
    profile(BODY, "Hammer", [(0.046, 0.086), (0.07, 0.092), (0.088, 0.126, 0.004), (0.078, 0.128, 0.003), (0.058, 0.108), (0.044, 0.1)], 0.0042, STEEL, 0.0008)
    profile(BODY, "Grip", [(0.0, -0.002), (0.06, -0.002), (0.066, 0.03, 0.008), (0.084, -0.02, 0.01), (0.086, -0.104, 0.012), (0.03, -0.104, 0.012), (0.014, -0.06, 0.012)], 0.0172, WOOD, 0.0056, (), 3)
    for i in range(3):
        y = -0.03 - i * 0.022
        profile(BODY, "Grip groove", [(0.02, y), (0.078, y), (0.078, y + 0.003), (0.02, y + 0.003)], 0.0174, BLACK, 0)
    # A power cell in the base of the grip, as on every other sidearm.
    straight_mag(0.058, -0.1, 0.022, 0.054, 0.0128, 0.0, 0, STEEL)
    profile(SIGHT, "Rear sight", [(0.02, 0.108), (-0.008, 0.108), (-0.006, 0.116, 0.002), (0.018, 0.116, 0.002)], 0.0095, BLACK, 0.0007)
    profile(SIGHT, "Front sight", [(-0.29, 0.106), (-0.31, 0.106), (-0.308, 0.116, 0.003), (-0.296, 0.116, 0.002)], 0.0028, STEEL, 0.0004)
    muzzle_mark(-0.32, PISTOL_BORE)


def thermal_sight(metal, lens):
    """The thermal sight on the left of the tube: a boxed sensor, an arm and a rubber eyepiece."""
    x = -0.118
    profile(BODY, "Sight arm", [(-0.2, 0.082), (-0.06, 0.082), (-0.06, 0.112, 0.006), (-0.2, 0.112, 0.006)], 0.05, metal, 0.002, x=-0.082)
    profile(BODY, "Sensor body", [(-0.34, 0.088), (0.03, 0.088), (0.05, 0.116, 0.012), (0.03, 0.172, 0.012), (-0.34, 0.172, 0.012)], 0.034, metal, 0.003, x=x)
    lathe(BODY, "Sensor hood", [(-0.40, 0.034), (-0.38, 0.04), (-0.335, 0.04), (-0.33, 0.034)], metal, 14, 0.13, x)
    lathe(BODY, "Germanium lens", [(-0.385, 0.03), (-0.388, 0.0)], lens, 12, 0.13, x)
    lathe(BODY, "Eyepiece", [(0.05, 0.022), (0.075, 0.026), (0.1, 0.03), (0.104, 0.024)], BLACK, 12, 0.128, x)
    for z in (-0.26, -0.2, -0.14):
        profile(BODY, "Cooling fin", [(z, 0.172), (z + 0.018, 0.172), (z + 0.018, 0.184), (z, 0.184)], 0.03, metal, 0, x=x)
    tube(BODY, "Cable", [(x + 0.03, 0.1, -0.02), (x + 0.075, 0.08, 0.02), (0.05, 0.06, 0.06)], 0.006, BLACK, 6)


def minigun():
    """Six barrels round a motor, a belt from a box on the side, carried at the hip."""
    y = 0.07
    grip()
    trigger_group()
    receiver = [(0.1, 0.02), (0.11, 0.14, 0.012), (0.02, 0.165, 0.01), (-0.2, 0.165, 0.01), (-0.21, -0.02, 0.012), (-0.1, -0.03, 0.012), (0.0, 0.0)]
    profile(BODY, "Receiver", receiver, 0.05, STEEL, 0.0036)
    rail(0.02, -0.19, 0.17, 0.0115)
    lathe(BODY, "Motor housing", [(-0.2, 0.082), (-0.21, 0.09), (-0.3, 0.09), (-0.31, 0.074)], BLACK, 20, y, bevel=0.002)
    tube(BODY, "Handle", [(0, 0.16, 0.0), (0.0, 0.215, -0.03), (0.0, 0.215, -0.16), (0, 0.16, -0.19)], 0.0095, POLY, 8)
    # The barrels turn as one, so they are a part of their own.
    for i in range(6):
        a = math.tau * i / 6
        bx, by = math.cos(a) * 0.04, y + math.sin(a) * 0.04
        lathe(SPIN, f"Barrel {i}", [(-0.3, 0.0125), (-0.9, 0.0125)], STEEL, 10, by, bx)
    for z in (-0.46, -0.66, -0.84):
        lathe(SPIN, "Barrel clamp", [(z + 0.012, 0.058), (z - 0.012, 0.058)], BLACK, 16, y)
    lathe(SPIN, "Barrel hub", [(-0.3, 0.03), (-0.31, 0.058), (-0.34, 0.058), (-0.35, 0.02)], EDGE, 16, y)
    # The ammunition box and its belt: the part WeaponFactory stretches for larger cells.
    box = [(-0.02, -0.17), (-0.2, -0.17), (-0.2, 0.03, 0.008), (-0.02, 0.03, 0.008)]
    profile(CELL, "Ammunition box", box, 0.07, OLIVE, 0.0034, x=-0.12)
    profile(CELL, "Lid", [(-0.014, 0.03), (-0.206, 0.03), (-0.206, 0.05, 0.005), (-0.014, 0.05, 0.005)], 0.073, STEEL, 0.002, x=-0.12)
    tube(CELL, "Feed chute", [(-0.12, 0.05, -0.1), (-0.07, 0.1, -0.1), (-0.04, 0.12, -0.1)], 0.018, BLACK, 8)
    profile(STOCK, "Stock", [(0.1, 0.13), (0.26, 0.11, 0.012), (0.29, 0.11), (0.296, -0.05, 0.012), (0.24, -0.056, 0.012), (0.18, 0.0, 0.02), (0.1, 0.02)], 0.024, POLY, 0.004)
    profile(STOCK, "Butt pad", [(0.294, 0.112, 0.008), (0.314, 0.112, 0.008), (0.316, -0.054, 0.008), (0.298, -0.054, 0.008)], 0.026, BLACK, 0.003, (), 2)
    muzzle_mark(-0.9, y)


def at_launcher():
    """Recoilless launcher: wound composite tube, blast cone, fire control box."""
    y = 0.09
    lathe(BODY, "Launch tube", [(-0.72, 0.074), (-0.71, 0.078), (-0.66, 0.078), (-0.65, 0.072), (0.3, 0.072), (0.34, 0.076), (0.4, 0.11), (0.44, 0.112), (0.44, 0.1)], OLIVE, 24, y, bevel=0.0012)
    lathe(BODY, "Bore", [(-0.715, 0.066), (-0.7, 0.0)], BLACK, 20, y)
    lathe(BODY, "Rear bore", [(0.4425, 0.098), (0.4425, 0.0)], BLACK, 24, y)
    for z in (-0.5, -0.2, 0.1):
        lathe(BODY, "Winding band", [(z + 0.016, 0.0735), (z + 0.012, 0.0755), (z - 0.012, 0.0755), (z - 0.016, 0.0735)], BLACK, 24, y)
    profile(BODY, "Grip block", [(-0.09, 0.03), (0.08, 0.03), (0.08, 0.0, 0.006), (0.0, -0.016, 0.008), (-0.09, -0.01, 0.008)], 0.03, POLY, 0.003)
    grip()
    trigger_group()
    profile(BODY, "Fore grip", [(-0.3, 0.03), (-0.24, 0.03), (-0.238, -0.09, 0.01), (-0.285, -0.094, 0.01)], 0.0165, POLY, 0.0052, (), 2)
    profile(BODY, "Shoulder rest", [(0.16, 0.024), (0.33, 0.024), (0.336, -0.03, 0.02), (0.18, -0.03, 0.016)], 0.058, POLY, 0.008, (), 2)
    profile(BODY, "Fire control", [(-0.42, 0.102), (-0.18, 0.102), (-0.18, 0.178, 0.01), (-0.42, 0.178, 0.01)], 0.0225, STEEL, 0.003, x=0.098)
    lathe(BODY, "Lens hood", [(-0.42, 0.0185), (-0.442, 0.022), (-0.442, 0.0195)], STEEL, 14, 0.14, 0.098)
    lathe(BODY, "Lens", [(-0.43, 0.0178), (-0.432, 0.0)], LENS, 12, 0.14, 0.098)
    profile(BODY, "Status lamp", [(-0.2, 0.15), (-0.19, 0.15), (-0.19, 0.16), (-0.2, 0.16)], 0.0226, CORE, 0, x=0.098)
    for z in (-0.38, -0.22):
        tube(BODY, "Bracket", [(0.05, 0.145, z), (0.085, 0.145, z)], 0.008, STEEL, 8)
    profile(CELL, "Charge latch", [(0.02, 0.0), (0.086, 0.0), (0.086, -0.02, 0.004), (0.02, -0.02, 0.004)], 0.018, EDGE, 0.0014)
    profile(SIGHT, "Rear sight", [(-0.02, 0.164), (0.02, 0.164), (0.016, 0.182, 0.004), (-0.016, 0.182, 0.004)], 0.016, STEEL, 0.0014, [[(-0.006, 0.17, 0.002), (0.006, 0.17, 0.002), (0.006, 0.178, 0.002), (-0.006, 0.178, 0.002)]])
    profile(SIGHT, "Front sight", [(-0.58, 0.164), (-0.54, 0.164), (-0.552, 0.182, 0.003), (-0.568, 0.182, 0.003)], 0.006, STEEL, 0.0008)
    thermal_sight(STEEL, LENS)
    muzzle_mark(-0.72, y)


def rocket_load():
    """The same rocket with its fins still folded, as it goes into the tube."""
    rocket_round(0.066)


def rocket_round(span=0.12):
    lathe(BODY, "Motor", [(0.26, 0.03), (0.26, 0.043), (0.24, 0.045), (-0.14, 0.045), (-0.2, 0.038)], OLIVE, 16, 0.0, bevel=0.001)
    lathe(BODY, "Nose", [(-0.19, 0.04), (-0.3, 0.02), (-0.33, 0.006), (-0.335, 0.0)], EDGE, 16, 0.0)
    lathe(BODY, "Band", [(-0.04, 0.0462), (-0.05, 0.0462)], STEEL, 16, 0.0)
    for k in range(4):
        a = math.pi / 2 * k + math.pi / 4
        c, s = math.cos(a), math.sin(a)
        verts = []
        for r, z in ((0.04, 0.12), (span, 0.24), (span, 0.28), (0.04, 0.26)):
            for off in (-0.003, 0.003):
                verts.append((c * r - s * off, s * r + c * off, z))
        faces = [(0, 2, 4, 6), (7, 5, 3, 1), (0, 1, 3, 2), (2, 3, 5, 4), (4, 5, 7, 6), (6, 7, 1, 0)]
        obj = add(BODY, "Fin", [B(p) for p in verts], faces, STEEL)
        outward(obj)


# ---------------------------------------------------------------- the Iron Empire's arsenal
# One machine-made family: open frames, ribbed barrels, forked emitters and exposed red cells.
# Every gun keeps the fixed points listed at the top of this file, so attachments still fit.

BONE, GUNMETAL = "ImperialBone", "ImperialDark"
PALETTE.update({BONE: ((0.46, 0.44, 0.38), 0.3, 0.48, 0), GUNMETAL: ((0.05, 0.05, 0.058), 0.7, 0.42, 0)})


def e_grip():
    """An open skeleton grip: machines have no need of a comfortable one."""
    outer = [(-0.016, 0.0), (-0.006, -0.05, 0.006), (0.012, -0.132, 0.006), (0.058, -0.136, 0.008), (0.06, -0.122, 0.004), (0.042, -0.05, 0.01), (0.05, 0.0)]
    hole = [(0.012, -0.03, 0.004), (0.03, -0.03, 0.004), (0.042, -0.11, 0.005), (0.026, -0.114, 0.004)]
    profile(BODY, "Grip", outer, 0.0125, GUNMETAL, 0.0024, [hole])


def e_trigger():
    outer = [(-0.012, 0.0), (-0.11, 0.0), (-0.098, -0.05, 0.004), (-0.02, -0.054, 0.004), (-0.012, -0.04)]
    hole = [(-0.02, -0.007), (-0.098, -0.007, 0.002), (-0.09, -0.044, 0.003), (-0.026, -0.047, 0.003)]
    profile(BODY, "Trigger guard", outer, 0.005, GUNMETAL, 0.0012, [hole])
    profile(BODY, "Trigger", [(-0.054, 0.0), (-0.046, 0.0), (-0.052, -0.03), (-0.064, -0.04), (-0.066, -0.036), (-0.056, -0.022)], 0.003, EDGE, 0.0005)


def e_receiver(front=-0.215, top=0.094, half=0.0125):
    outline = [(0.082, 0.024), (0.086, top - 0.004, 0.003), (0.03, top), (front, top), (front - 0.012, top - 0.022), (front + 0.012, 0.03, 0.005), (-0.1, 0.0), (0.0, 0.0), (0.05, 0.012)]
    holes = [[(-0.14, 0.02, 0.003), (-0.05, 0.02, 0.003), (-0.05, 0.05, 0.003), (-0.14, 0.05, 0.003)]]
    profile(BODY, "Receiver", outline, half, GUNMETAL, 0.002, holes)
    profile(BODY, "Side plate", [(0.07, 0.056), (0.074, top - 0.01, 0.003), (front + 0.03, top - 0.012), (front + 0.05, 0.058)], half + 0.0007, BONE, 0.0005)
    profile(BODY, "Charge line", [(-0.02, 0.07), (front + 0.05, 0.07), (front + 0.05, 0.074), (-0.02, 0.074)], half + 0.001, CORE, 0)
    for z in (0.056, 0.04, 0.024):
        profile(BODY, "Vent", [(z - 0.005, 0.062), (z + 0.005, 0.062), (z + 0.005, 0.082), (z - 0.005, 0.082)], half + 0.0012, BLACK, 0)
    pins([(0.06, 0.036), (-0.03, 0.012)], half, 0.003)


def e_barrel(z0, z1, r, y, rib_from=None, rib_gap=0.03):
    """A slim tube wearing cooling discs along the part nearest the muzzle."""
    lathe(BODY, "Barrel", [(z0, r * 1.15), (z1, r)], EDGE, 12, y)
    z = rib_from if rib_from is not None else z0
    while z > z1 + 0.012:
        lathe(BODY, "Cooling disc", [(z + 0.006, r * 1.1), (z + 0.004, r * 1.62), (z - 0.004, r * 1.62), (z - 0.006, r * 1.1)], GUNMETAL, 12, y)
        z -= rib_gap


def e_emitter(z, r, y, reach=0.07):
    """The forked muzzle every Imperial gun ends in, with the bolt's glow between the tines."""
    lathe(BODY, "Emitter collar", [(z + reach + 0.02, r * 1.1), (z + reach + 0.014, r * 1.7), (z + reach - 0.006, r * 1.7), (z + reach - 0.012, r * 1.2)], GUNMETAL, 12, y, bevel=0.0006)
    for side in (1, -1):
        tine = [(z + reach, y - r * 1.2), (z + reach * 0.6, y - r * 1.2), (z, y - r * 0.6), (z, y + r * 0.6), (z + reach * 0.6, y + r * 1.2), (z + reach, y + r * 1.2)]
        profile(BODY, "Tine", tine, r * 0.34, EDGE, 0.0006, x=side * r * 1.2)
    lathe(BODY, "Bolt glow", [(z + reach * 0.5, r * 0.62), (z + reach * 0.34, 0.0)], CORE, 8, y)


def e_forend(z_rear, z_front, y_low, y_high, half=0.0145):
    """An angular bar under the barrel: the hand holds it and foregrips bolt to its lower edge."""
    outline = [(z_rear, y_low), (z_rear, y_high), (z_front + 0.016, y_high), (z_front, y_high - 0.016), (z_front + 0.02, y_low, 0.004)]
    count = max(int((z_rear - z_front) / 0.06), 2)
    profile(BODY, "Forend", outline, half, BONE, 0.002, slots(z_rear - 0.016, z_front + 0.03, y_low + 0.009, y_high - 0.009, count, 0.42))


def e_clip(z, y, length, depth, half):
    """A straight charge clip with its red core showing down one side."""
    outline = [(z - depth / 2, y), (z + depth / 2, y), (z + depth / 2, y - length, 0.002), (z - depth / 2, y - length, 0.002)]
    profile(CELL, "Clip", outline, half, GUNMETAL, 0.0016)
    profile(CELL, "Clip core", [(z - 0.005, y - length * 0.18), (z + 0.005, y - length * 0.18), (z + 0.005, y - length * 0.86), (z - 0.005, y - length * 0.86)], half + 0.0006, CORE, 0)
    profile(CELL, "Clip foot", [(z - depth / 2 - 0.003, y - length), (z + depth / 2 + 0.003, y - length), (z + depth / 2 + 0.002, y - length - 0.012, 0.003), (z - depth / 2 - 0.002, y - length - 0.012, 0.003)], half + 0.0015, BONE, 0.0012)


def e_drum(z, y, r):
    """A round charge drum for the heavier guns."""
    circle = [(z + r * math.cos(math.tau * k / 16), y + r * math.sin(math.tau * k / 16)) for k in range(16)]
    profile(CELL, "Drum", circle, 0.022, GUNMETAL, 0.002)
    ring = [(z + r * 0.55 * math.cos(math.tau * k / 12), y + r * 0.55 * math.sin(math.tau * k / 12)) for k in range(12)]
    profile(CELL, "Drum core", ring, 0.0226, CORE, 0)


def e_stock(kind, top=0.09, half=0.009):
    if kind == "blade":
        outline = [(0.084, top), (0.3, top - 0.03, 0.006), (0.335, top - 0.012), (0.34, -0.07, 0.006), (0.316, -0.076, 0.006), (0.1, 0.02, 0.012)]
        holes = [[(0.13, top - 0.016, 0.004), (0.29, top - 0.042, 0.005), (0.3, -0.04, 0.005)]]
        profile(STOCK, "Blade stock", outline, half, GUNMETAL, 0.0018, holes)
        profile(STOCK, "Butt", [(0.33, top - 0.006), (0.346, top - 0.006), (0.35, -0.076, 0.004), (0.334, -0.076, 0.004)], half + 0.006, BONE, 0.002)
    elif kind == "fold":
        for side in (1, -1):
            tube(STOCK, "Fold bar", [(side * 0.012, 0.074, 0.084), (side * 0.012, 0.074, 0.3), (side * 0.012, -0.03, 0.3)], 0.0046, EDGE, 6)
        profile(STOCK, "Butt", [(0.296, 0.08), (0.31, 0.08), (0.31, -0.04), (0.296, -0.04)], 0.016, GUNMETAL, 0.002)
    elif kind == "rod":
        lathe(STOCK, "Rod", [(0.08, 0.0085), (0.31, 0.0085)], EDGE, 8, 0.07)
        profile(STOCK, "Butt", [(0.3, 0.1, 0.006), (0.318, 0.1, 0.006), (0.322, -0.05, 0.006), (0.304, -0.05, 0.006)], 0.015, BONE, 0.0024)
    elif kind == "chassis":
        outline = [(0.084, top), (0.4, top - 0.01), (0.41, -0.076, 0.008), (0.34, -0.082, 0.008), (0.3, -0.016, 0.012), (0.09, 0.018, 0.01)]
        holes = [[(0.12, top - 0.014, 0.004), (0.2, top - 0.016, 0.004), (0.2, 0.024, 0.006), (0.12, 0.03, 0.004)], [(0.22, top - 0.016, 0.004), (0.37, top - 0.02, 0.005), (0.38, -0.06, 0.006), (0.33, -0.06, 0.005), (0.3, 0.004, 0.006), (0.22, 0.02, 0.005)]]
        profile(STOCK, "Chassis", outline, half + 0.002, BONE, 0.002, holes)
        profile(STOCK, "Cheek", [(0.2, top), (0.36, top - 0.004), (0.35, top + 0.026, 0.008), (0.21, top + 0.024, 0.008)], 0.014, GUNMETAL, 0.002)


def e_long(muzzle, forend, under, stock, clip, y=RIFLE_BORE, r=0.0105, rib_from=None, rib_gap=0.03, scope=None, irons_at=None, reach=0.07):
    e_grip()
    e_trigger()
    e_receiver()
    rail(0.08, -0.205)
    e_forend(forend[0], forend[1], under, y + 0.03)
    e_barrel(-0.2, -muzzle + reach, r, y, rib_from, rib_gap)
    e_emitter(-muzzle, r, y, reach)
    if clip is not None:
        e_clip(*clip)
    e_stock(stock)
    if scope:
        scope_on_rail(-0.075, 0.145, scope, 0.024)
    if irons_at:
        irons(irons_at[0], irons_at[1], 0.145, 0.1, y + 0.02)
    muzzle_mark(-muzzle, y)


def e_carbine():
    e_long(0.68, (-0.21, -0.46), 0.022, "blade", (-0.135, -0.002, 0.15, 0.05, 0.011), rib_from=-0.47, irons_at=(0.04, -0.455))


def e_assault():
    e_long(0.64, (-0.21, -0.42), 0.024, "fold", (-0.135, -0.002, 0.17, 0.056, 0.0115), r=0.0115, rib_from=-0.43, rib_gap=0.026, irons_at=(0.03, -0.41))


def e_rifle():
    e_long(0.84, (-0.21, -0.56), 0.02, "chassis", (-0.135, -0.002, 0.11, 0.052, 0.011), rib_from=-0.57, rib_gap=0.036, scope=0.3, irons_at=(-0.235, -0.55))


def e_smg():
    e_long(0.42, (-0.21, -0.27), 0.012, "fold", (-0.135, -0.002, 0.16, 0.04, 0.0095), rib_from=-0.28, rib_gap=0.022, reach=0.05, irons_at=(0.04, -0.262))


def e_smg2():
    e_long(0.53, (-0.21, -0.33), 0.012, "rod", (-0.135, -0.002, 0.13, 0.044, 0.01), rib_from=-0.34, rib_gap=0.024, reach=0.06, irons_at=(0.04, -0.32))


def e_silent():
    e_grip()
    e_trigger()
    e_receiver()
    rail(0.08, -0.205)
    e_forend(-0.21, -0.42, 0.02, 0.09)
    lathe(BODY, "Dampener", [(-0.21, 0.018), (-0.22, 0.027), (-0.72, 0.027), (-0.736, 0.016)], GUNMETAL, 8, RIFLE_BORE, bevel=0.001)
    for z in (-0.46, -0.52, -0.58, -0.64, -0.7):
        lathe(BODY, "Dampener band", [(z + 0.005, 0.0274), (z + 0.004, 0.0288), (z - 0.004, 0.0288), (z - 0.005, 0.0274)], EDGE, 8, RIFLE_BORE)
    crown(-0.736, 0.016, RIFLE_BORE)
    e_clip(-0.135, -0.002, 0.13, 0.05, 0.011)
    e_stock("blade")
    scope_on_rail(-0.075, 0.145, 0.26)
    irons(-0.24, -0.4, 0.145, 0.1, RIFLE_BORE + 0.03)
    muzzle_mark(-0.74, RIFLE_BORE)


def e_sniper():
    e_long(1.12, (-0.21, -0.5), 0.02, "chassis", (-0.135, -0.002, 0.09, 0.056, 0.0118), r=0.0128, rib_from=-0.76, rib_gap=0.034, scope=0.34, reach=0.09)
    bipod_folded(-0.47, 0.02)


def e_rail():
    e_long(1.16, (-0.21, -0.3), 0.024, "chassis", (-0.135, 0.002, 0.12, 0.066, 0.016), r=0.0095, rib_from=-0.34, rib_gap=0.1, scope=0.32, reach=0.1)
    for side in (1, -1):
        outline = [(-0.32, 0.08), (-1.04, 0.074), (-1.08, 0.068), (-1.08, 0.052), (-1.04, 0.046), (-0.32, 0.04)]
        profile(BODY, "Accelerator", outline, 0.0036, GUNMETAL, 0.001, slots(-0.34, -1.02, 0.051, 0.069, 9, 0.24), x=side * 0.019)
    for z in (-0.5, -0.72, -0.94):
        profile(BODY, "Accelerator tie", [(z - 0.008, 0.034), (z + 0.008, 0.034), (z + 0.008, 0.086), (z - 0.008, 0.086)], 0.024, EDGE, 0.0012, [[(z - 0.003, 0.044), (z + 0.003, 0.044), (z + 0.003, 0.076), (z - 0.003, 0.076)]])


def e_heavy():
    e_grip()
    e_trigger()
    outline = [(0.09, 0.02), (0.094, 0.144, 0.006), (-0.26, 0.15), (-0.28, 0.12), (-0.27, 0.03, 0.006), (-0.14, 0.0, 0.008), (0.0, 0.0)]
    profile(BODY, "Receiver", outline, 0.026, GUNMETAL, 0.003, [[(-0.24, 0.04, 0.004), (-0.17, 0.04, 0.004), (-0.17, 0.1, 0.004), (-0.24, 0.1, 0.004)]])
    profile(BODY, "Side plate", [(0.07, 0.04), (0.074, 0.13, 0.005), (-0.12, 0.134, 0.005), (-0.12, 0.04)], 0.0268, BONE, 0.0008)
    profile(BODY, "Charge line", [(0.05, 0.11), (-0.1, 0.11), (-0.1, 0.116), (0.05, 0.116)], 0.0274, CORE, 0)
    rail(0.02, -0.25, 0.156, 0.0115)
    pins([(0.05, 0.06), (0.05, 0.1), (-0.09, 0.06), (-0.09, 0.1)], 0.0272, 0.0034)
    for x in (0.014, -0.014):
        lathe(BODY, "Twin barrel", [(-0.26, 0.0124), (-0.84, 0.0104)], EDGE, 10, RIFLE_BORE, x)
    z = -0.3
    while z > -0.8:
        profile(BODY, "Barrel tie", [(z - 0.008, 0.038), (z + 0.008, 0.038), (z + 0.008, 0.082), (z - 0.008, 0.082)], 0.032, GUNMETAL, 0.0014)
        z -= 0.1
    e_forend(-0.27, -0.56, 0.03, 0.038, 0.016)
    e_emitter(-0.9, 0.019, RIFLE_BORE, 0.08)
    box = [(-0.08, -0.105), (-0.24, -0.105), (-0.24, 0.035, 0.006), (-0.08, 0.035, 0.006)]
    profile(CELL, "Power box", box, 0.066, GUNMETAL, 0.003, x=-0.092)
    for z in (-0.11, -0.16, -0.21):
        profile(CELL, "Box rib", [(z - 0.008, -0.1), (z + 0.008, -0.1), (z + 0.008, 0.03), (z - 0.008, 0.03)], 0.0672, BONE, 0.0008, x=-0.092)
    tube(CELL, "Feed", [(-0.1, 0.05, -0.16), (-0.044, 0.09, -0.16), (-0.02, 0.1, -0.16)], 0.013, BLACK, 8)
    e_stock("chassis", 0.13, 0.012)
    irons(-0.03, -0.66, 0.205, 0.156, 0.09)
    muzzle_mark(-0.9, RIFLE_BORE)


def e_scatter():
    e_grip()
    e_trigger()
    e_receiver(-0.2, 0.1, 0.0185)
    rail(0.06, -0.2)
    y = 0.07
    for i, (x, dy) in enumerate(((0.0, 0.011), (0.0125, -0.011), (-0.0125, -0.011))):
        lathe(BODY, "Tube", [(-0.2, 0.0108), (-0.5, 0.0096)], EDGE, 10, y + dy, x)
    for z in (-0.26, -0.34, -0.42):
        profile(BODY, "Tube tie", [(z - 0.01, 0.04), (z + 0.01, 0.04), (z + 0.01, 0.1, 0.003), (z - 0.01, 0.1, 0.003)], 0.026, GUNMETAL, 0.0014)
    e_forend(-0.23, -0.4, 0.008, 0.04, 0.02)
    e_emitter(-0.534, 0.016, y, 0.05)
    e_drum(-0.145, -0.026, 0.038)
    e_stock("blade", 0.09, 0.011)
    irons(0.04, -0.46, 0.145, 0.1, 0.1)
    muzzle_mark(-0.534, y)


def e_sidearm(muzzle, clip_length, rib_from, fore_grip=False):
    y = PISTOL_BORE
    frame = [(0.056, 0.104), (0.06, 0.04, 0.004), (0.084, -0.098, 0.006), (0.04, -0.104, 0.006), (0.012, -0.024, 0.008), (-0.07, -0.026, 0.01), (-0.094, 0.012, 0.008), (-0.094, 0.05), (-0.2, 0.056), (-0.2, 0.104)]
    guard = [(-0.006, 0.03, 0.003), (-0.08, 0.03, 0.003), (-0.08, 0.016, 0.004), (-0.06, -0.015, 0.006), (-0.01, -0.013, 0.005)]
    grip_hole = [(0.036, 0.0, 0.004), (0.05, 0.0, 0.004), (0.066, -0.08, 0.004), (0.05, -0.084, 0.004)]
    profile(BODY, "Frame", frame, 0.0115, GUNMETAL, 0.0022, [guard, grip_hole])
    profile(BODY, "Top plate", [(0.044, 0.078), (0.046, 0.1, 0.003), (-0.19, 0.1, 0.003), (-0.19, 0.078)], 0.0122, BONE, 0.0006)
    profile(BODY, "Charge line", [(0.02, 0.086), (-0.17, 0.086), (-0.17, 0.09), (0.02, 0.09)], 0.0128, CORE, 0)
    profile(BODY, "Trigger", [(-0.05, 0.03), (-0.04, 0.03), (-0.044, 0.01, 0.003), (-0.056, -0.004), (-0.06, -0.002), (-0.05, 0.012, 0.003)], 0.003, EDGE, 0.0005)
    e_barrel(-0.2, -muzzle + 0.05, 0.0092, y, rib_from, 0.018)
    e_emitter(-muzzle, 0.0092, y, 0.05)
    e_clip(0.058, -0.03, clip_length, 0.034, 0.0092)
    if fore_grip:
        profile(BODY, "Fore grip", [(-0.17, 0.056), (-0.14, 0.056), (-0.126, -0.05, 0.006), (-0.156, -0.05, 0.006)], 0.0095, GUNMETAL, 0.0024)
    profile(SIGHT, "Rear sight", [(0.036, 0.1), (0.012, 0.1), (0.014, 0.116, 0.002), (0.034, 0.116, 0.002)], 0.0095, BLACK, 0.0007)
    profile(SIGHT, "Front sight", [(-0.176, 0.1), (-0.194, 0.1), (-0.192, 0.116, 0.002), (-0.18, 0.116, 0.002)], 0.0028, EDGE, 0.0004)
    muzzle_mark(-muzzle, y)


def e_pistol():
    e_sidearm(0.27, 0.07, -0.205)


def e_mpistol():
    e_sidearm(0.3, 0.17, -0.205, True)


def e_revolver():
    e_sidearm(0.32, 0.05, -0.215)
    circle = [(-0.03 + 0.03 * math.cos(math.tau * k / 14), 0.066 + 0.03 * math.sin(math.tau * k / 14)) for k in range(14)]
    profile(BODY, "Charge drum", circle, 0.018, BONE, 0.002)
    ring = [(-0.03 + 0.016 * math.cos(math.tau * k / 10), 0.066 + 0.016 * math.sin(math.tau * k / 10)) for k in range(10)]
    profile(BODY, "Drum glow", ring, 0.0186, CORE, 0)


def e_at_launcher():
    y = 0.09
    section(BODY, "Launch tube", [(-0.72, 0.066, 0.066, 0.024), (-0.68, 0.074, 0.074, 0.028), (0.3, 0.07, 0.07, 0.026), (0.36, 0.09, 0.09, 0.034), (0.44, 0.1, 0.1, 0.04)], GUNMETAL, 0.003, 0.0, y)
    section(BODY, "Bore", [(-0.725, 0.056, 0.056, 0.02), (-0.72, 0.056, 0.056, 0.02)], BLACK, 0, 0.0, y)
    section(BODY, "Rear bore", [(0.4425, 0.09, 0.09, 0.036), (0.4415, 0.09, 0.09, 0.036)], BLACK, 0, 0.0, y)
    for z in (-0.5, -0.2, 0.1):
        section(BODY, "Plate band", [(z + 0.05, 0.076, 0.076, 0.03), (z - 0.05, 0.076, 0.076, 0.03)], BONE, 0.002, 0.0, y)
    profile(BODY, "Charge line", [(-0.62, 0.15), (0.24, 0.15), (0.24, 0.156), (-0.62, 0.156)], 0.012, CORE, 0)
    e_grip()
    e_trigger()
    profile(BODY, "Mount", [(-0.11, 0.03), (0.08, 0.03), (0.08, 0.0), (-0.11, 0.0)], 0.024, GUNMETAL, 0.002)
    profile(BODY, "Fore grip", [(-0.3, 0.03), (-0.25, 0.03), (-0.24, -0.09, 0.006), (-0.286, -0.09, 0.006)], 0.012, GUNMETAL, 0.003)
    profile(BODY, "Shoulder rest", [(0.16, 0.024), (0.33, 0.024), (0.336, -0.03, 0.012), (0.18, -0.03, 0.012)], 0.05, BONE, 0.004)
    profile(BODY, "Targeter", [(-0.42, 0.102), (-0.18, 0.102), (-0.18, 0.17, 0.006), (-0.42, 0.17, 0.006)], 0.02, GUNMETAL, 0.002, x=0.098)
    turned(BODY, "Targeter eye", [(-0.42, 0.018), (-0.426, 0.012), (-0.428, 0.0)], CORE, 10, 0.098, 0.136)
    profile(CELL, "Charge latch", [(0.02, 0.0), (0.086, 0.0), (0.086, -0.02, 0.004), (0.02, -0.02, 0.004)], 0.016, EDGE, 0.0014)
    profile(SIGHT, "Rear sight", [(-0.02, 0.164), (0.02, 0.164), (0.016, 0.182, 0.004), (-0.016, 0.182, 0.004)], 0.014, EDGE, 0.0012, [[(-0.006, 0.17, 0.002), (0.006, 0.17, 0.002), (0.006, 0.178, 0.002), (-0.006, 0.178, 0.002)]])
    profile(SIGHT, "Front sight", [(-0.58, 0.164), (-0.54, 0.164), (-0.552, 0.182, 0.003), (-0.568, 0.182, 0.003)], 0.005, EDGE, 0.0007)
    thermal_sight(GUNMETAL, CORE)
    muzzle_mark(-0.72, y)


EMPIRE_GUNS = [
    ("e_pistol", e_pistol), ("e_carbine", e_carbine), ("e_sniper", e_sniper), ("e_heavy", e_heavy), ("e_smg", e_smg), ("e_assault", e_assault),
    ("e_scatter", e_scatter), ("e_silent", e_silent), ("e_revolver", e_revolver), ("e_mpistol", e_mpistol), ("e_smg2", e_smg2), ("e_rifle", e_rifle),
    ("e_rail", e_rail), ("e_at_launcher", e_at_launcher),
]


# ---------------------------------------------------------------- attachments

def hollow(part, name, stations, mat, sides=18, cy=0.0):
    """A turned part open at both ends: stations run out along one wall and back along the other."""
    rings = [round_ring(0, cy, z, r, r, sides, 2.0) for z, r in stations]
    n = len(rings[0])
    faces = rings_to_faces(len(rings), n, False)
    faces += [(((len(rings) - 1) * n) + j, ((len(rings) - 1) * n) + (j + 1) % n, (j + 1) % n, j) for j in range(n)]
    obj = add(part, name, [B(q) for ring in rings for q in ring], faces, mat)
    outward(obj)
    return obj


def rail_clamp(part, y, length=0.05):
    """Claw that bolts an optic to the rail. `y` is the rail surface below the sight line."""
    profile(part, "Clamp", [(-length, y + 0.014), (length, y + 0.014), (length, y + 0.002, 0.002), (-length, y + 0.002, 0.002)], 0.0145, STEEL, 0.0012)
    profile(part, "Clamp jaw", [(-length * 0.7, y + 0.012), (length * 0.7, y + 0.012), (length * 0.7, y - 0.004), (-length * 0.7, y - 0.004)], 0.0132, STEEL, 0.0008)
    for z in (-length * 0.5, length * 0.5):
        pts = [(z + 0.0058 * math.cos(math.tau * k / 10), y + 0.008 + 0.0058 * math.sin(math.tau * k / 10)) for k in range(10)]
        profile(part, "Thumb screw", pts, 0.0026, EDGE, 0.0005, x=0.0168)


def reddot():
    part = "Optic_reddot"
    base = -0.05
    rail_clamp(part, base, 0.036)
    hollow(part, "Tube", [(0.03, 0.0215), (0.03, 0.0258), (0.026, 0.0272), (-0.026, 0.0272), (-0.03, 0.0258), (-0.03, 0.0215)], STEEL, 22)
    profile(part, "Riser", [(-0.034, base + 0.012), (0.034, base + 0.012), (0.03, -0.018, 0.004), (-0.03, -0.018, 0.004)], 0.0155, STEEL, 0.0014)
    circle = [(0.0065 * math.cos(math.tau * k / 12), -0.012 + 0.0065 * math.sin(math.tau * k / 12)) for k in range(12)]
    profile(part, "Dial", circle, 0.0065, EDGE, 0.0007, x=0.0315)
    profile(part, "Top cap", [(-0.008, 0.026), (0.008, 0.026), (0.007, 0.034, 0.002), (-0.007, 0.034, 0.002)], 0.0075, STEEL, 0.0008)


def holo():
    part = "Optic_holo"
    base = -0.05
    rail_clamp(part, base, 0.05)
    profile(part, "Body", [(-0.05, base + 0.012), (0.046, base + 0.012), (0.046, -0.026, 0.004), (-0.05, -0.03, 0.004)], 0.0225, STEEL, 0.0018)
    for side in (1, -1):
        profile(part, "Hood wall", [(-0.044, -0.03), (0.016, -0.03), (0.016, 0.03, 0.008), (-0.044, 0.036, 0.008)], 0.002, STEEL, 0.0005, x=side * 0.0275)
    profile(part, "Hood", [(-0.05, 0.034), (0.02, 0.029), (0.02, 0.034, 0.003), (-0.05, 0.04, 0.003)], 0.0295, STEEL, 0.001)
    profile(part, "Rear box", [(0.02, base + 0.012), (0.05, base + 0.012), (0.05, -0.02, 0.004), (0.02, -0.024, 0.004)], 0.0245, POLY, 0.002)
    for i, z in enumerate((0.03, 0.04)):
        profile(part, "Button", [(z - 0.003, -0.024), (z + 0.003, -0.024), (z + 0.003, -0.018), (z - 0.003, -0.018)], 0.0065, EDGE, 0.0003, x=(-1 if i else 1) * 0.01)


def scope():
    part = "Optic_scope"
    r = 0.0205
    lathe(part, "Tube", [(0.18, r * 1.46), (0.172, r * 1.5), (0.13, r * 1.42), (0.09, r), (-0.09, r), (-0.13, r * 1.5), (-0.17, r * 1.6), (-0.176, r * 1.42)], STEEL, 18, 0.0, bevel=0.0007)
    lathe(part, "Objective lens", [(-0.172, r * 1.4), (-0.173, 0.0)], LENS, 16, 0.0)
    lathe(part, "Eye lens", [(0.176, r * 1.3), (0.177, 0.0)], LENS, 14, 0.0)
    upright(part, "Elevation", [(r * 0.9, 0.0125, 0.0125), (r + 0.016, 0.0125, 0.0125), (r + 0.019, 0.0095, 0.0095)], EDGE, 12, 0.0, 0.0)
    circle = [(0.0125 * math.cos(math.tau * k / 12), 0.0125 * math.sin(math.tau * k / 12)) for k in range(12)]
    profile(part, "Windage", circle, 0.009, EDGE, 0.0008, x=r + 0.009)
    for z in (-0.06, 0.06):
        profile(part, "Ring", [(z - 0.011, -0.05), (z + 0.011, -0.05), (z + 0.011, r + 0.004, 0.006), (z - 0.011, r + 0.004, 0.006)], r + 0.0045, STEEL, 0.0012)
    rail_clamp(part, -0.05, 0.08)


def comp():
    part = "Muzzle_comp"
    lathe(part, "Body", [(0.0, 0.015), (-0.004, 0.0205), (-0.08, 0.0205), (-0.088, 0.0165), (-0.09, 0.0125)], STEEL, 16, 0.0, bevel=0.0008)
    for i in range(3):
        z = -0.022 - i * 0.022
        for side in (1, -1):
            profile(part, "Port", [(z - 0.0065, -0.012), (z + 0.0065, -0.012), (z + 0.0065, 0.012), (z - 0.0065, 0.012)], 0.0016, BLACK, 0, x=side * 0.0194)
        profile(part, "Top port", [(z - 0.0065, 0.0194), (z + 0.0065, 0.0194), (z + 0.0065, 0.021), (z - 0.0065, 0.021)], 0.008, BLACK, 0)
    lathe(part, "Bore", [(-0.0895, 0.0102), (-0.0898, 0.0)], BLACK, 10, 0.0)


def suppressor():
    part = "Muzzle_suppressor"
    lathe(part, "Mount", [(0.0, 0.0165), (-0.006, 0.0225), (-0.03, 0.0225), (-0.034, 0.0245)], EDGE, 18, 0.0, bevel=0.0006)
    lathe(part, "Can", [(-0.03, 0.03), (-0.036, 0.0335), (-0.25, 0.0335), (-0.258, 0.0295), (-0.26, 0.018)], OLIVE, 20, 0.0, bevel=0.0009)
    for i in range(7):
        z = -0.06 - i * 0.027
        lathe(part, "Baffle line", [(z + 0.0018, 0.0337), (z + 0.0014, 0.0345), (z - 0.0014, 0.0345), (z - 0.0018, 0.0337)], BLACK, 20, 0.0)
    lathe(part, "Bore", [(-0.2595, 0.0125), (-0.26, 0.0)], BLACK, 12, 0.0)


def stabilizer():
    part = "Muzzle_stabilizer"
    lathe(part, "Core", [(0.0, 0.0155), (-0.006, 0.019), (-0.16, 0.0165), (-0.166, 0.0135), (-0.17, 0.011)], STEEL, 16, 0.0, bevel=0.0006)
    for i in range(4):
        z = -0.03 - i * 0.04
        lathe(part, "Baffle", [(z + 0.006, 0.0165), (z + 0.003, 0.033 - i * 0.0026), (z - 0.003, 0.033 - i * 0.0026), (z - 0.006, 0.0165)], EDGE if i % 2 else STEEL, 18, 0.0)
    lathe(part, "Bore", [(-0.1695, 0.0088), (-0.17, 0.0)], BLACK, 10, 0.0)


def fore_clamp(part):
    """The short rail section every under-barrel fitting bolts on with."""
    profile(part, "Rail", [(-0.07, 0.006), (0.07, 0.006), (0.066, -0.01, 0.003), (-0.066, -0.01, 0.003)], 0.0145, POLY, 0.0014)
    for z in (-0.045, 0.045):
        for side in (1, -1):
            pts = [(z + 0.0036 * math.cos(math.tau * k / 8), -0.002 + 0.0036 * math.sin(math.tau * k / 8)) for k in range(8)]
            profile(part, "Screw", pts, 0.0006, EDGE, 0, x=side * 0.0148)


def vgrip():
    part = "Grip_vgrip"
    fore_clamp(part)
    upright(part, "Handle", [(-0.008, 0.0195, 0.0225), (-0.03, 0.021, 0.0245), (-0.08, 0.0195, 0.023), (-0.118, 0.0185, 0.022), (-0.125, 0.0225, 0.026), (-0.132, 0.022, 0.0255), (-0.138, 0.0, 0.0)], POLY, 14, 0.0, 0.004, 2.6, 0.0012)
    for i in range(3):
        y = -0.042 - i * 0.022
        upright(part, "Finger ring", [(y + 0.006, 0.0212, 0.0245), (y + 0.003, 0.0222, 0.0258), (y - 0.003, 0.0222, 0.0258), (y - 0.006, 0.0212, 0.0245)], BLACK, 14, 0.0, 0.004, 2.6)


def agrip():
    part = "Grip_agrip"
    fore_clamp(part)
    outline = [(-0.066, -0.008), (0.066, -0.008), (0.066, -0.016, 0.004), (-0.012, -0.03, 0.01), (-0.05, -0.076, 0.008), (-0.07, -0.066, 0.006), (-0.074, -0.03, 0.01)]
    profile(part, "Wedge", outline, 0.0165, POLY, 0.0052, (), 2)
    for i in range(3):
        z = -0.06 + i * 0.012
        profile(part, "Rib", [(z - 0.0024, -0.074 + i * 0.012), (z + 0.0024, -0.074 + i * 0.012), (z + 0.0024, -0.03), (z - 0.0024, -0.03)], 0.0172, BLACK, 0.0002)


def laser():
    part = "Grip_laser"
    fore_clamp(part)
    profile(part, "Housing", [(-0.05, -0.008), (0.05, -0.008), (0.05, -0.042, 0.004), (-0.05, -0.042, 0.004)], 0.0172, STEEL, 0.0016)
    lathe(part, "Emitter", [(-0.05, 0.0135), (-0.066, 0.0135), (-0.066, 0.0105)], EDGE, 14, -0.026)
    profile(part, "Switch", [(0.02, -0.04), (0.038, -0.04), (0.038, -0.03), (0.02, -0.03)], 0.0178, POLY, 0.0005)


def wrapped_grip(part, y0, y1, r, mat=LEATHERISH):
    """A corded grip: a slim core with a raised ring every centimetre or so."""
    upright(part, "Grip core", [(y0, r, r * 0.86), (y1, r, r * 0.86)], BLACK, 12, 0.0, 0.0, 2.4)
    y = y0 + 0.008
    while y < y1 - 0.004:
        upright(part, "Cord", [(y - 0.0048, r, r * 0.86), (y - 0.0026, r * 1.12, r * 0.98), (y + 0.0026, r * 1.12, r * 0.98), (y + 0.0048, r, r * 0.86)], mat, 12, 0.0, 0.0, 2.4)
        y += 0.0125


def pommel(part, y, r):
    upright(part, "Pommel", [(y + 0.02, r * 0.62, r * 0.56), (y + 0.012, r * 0.9, r * 0.8), (y - 0.012, r, r * 0.9), (y - 0.024, r * 0.72, r * 0.64), (y - 0.03, 0.0, 0.0)], EDGE, 12, 0.0, 0.0, 2.6, 0.0007)


def hilt_sword():
    """A sabre's hilt: corded grip, swept knuckle bow with a real gap for the fingers."""
    part = "Hilt_sword"
    wrapped_grip(part, -0.07, 0.078, 0.0172)
    pommel(part, -0.082, 0.024)
    bow = [(0.012, 0.094), (-0.03, 0.094, 0.01), (-0.074, 0.074, 0.02), (-0.082, 0.0, 0.024), (-0.056, -0.082, 0.016), (-0.008, -0.092), (-0.008, -0.078), (-0.044, -0.072, 0.012), (-0.066, 0.0, 0.016), (-0.058, 0.062, 0.016), (-0.026, 0.08, 0.008), (0.012, 0.08)]
    profile(part, "Knuckle bow", bow, 0.0072, STEEL, 0.0016, (), 2)
    profile(part, "Guard plate", [(0.044, 0.08), (-0.052, 0.08), (-0.05, 0.094, 0.004), (0.04, 0.098, 0.006)], 0.034, STEEL, 0.0018)
    upright(part, "Emitter collar", [(0.092, 0.018, 0.02), (0.104, 0.016, 0.022), (0.114, 0.012, 0.018)], EDGE, 12, 0.0, 0.0, 2.8, 0.0006)


def hilt_saber():
    """A machined energy hilt: emitter shroud, ribbed grip, control plate and a counterweight."""
    part = "Hilt_saber"
    upright(part, "Body", [(-0.1, 0.0205, 0.0205), (0.09, 0.0195, 0.0195)], STEEL, 14, 0.0, 0.0, 2.0, 0.0006)
    for i in range(7):
        y = -0.07 + i * 0.016
        upright(part, "Rib", [(y - 0.0052, 0.0208, 0.0208), (y - 0.0028, 0.0232, 0.0232), (y + 0.0028, 0.0232, 0.0232), (y + 0.0052, 0.0208, 0.0208)], BLACK, 14)
    upright(part, "Shroud", [(0.08, 0.0225, 0.0225), (0.092, 0.0255, 0.0255), (0.128, 0.03, 0.03), (0.134, 0.0285, 0.0285), (0.134, 0.019, 0.019), (0.122, 0.0165, 0.0165)], EDGE, 16, 0.0, 0.0, 2.0, 0.0007)
    upright(part, "Counterweight", [(-0.098, 0.0235, 0.0235), (-0.124, 0.0245, 0.0245), (-0.13, 0.0205, 0.0205), (-0.134, 0.0, 0.0)], EDGE, 14, 0.0, 0.0, 2.0, 0.0006)
    profile(part, "Control plate", [(-0.012, 0.03), (0.012, 0.03), (0.012, 0.084, 0.004), (-0.012, 0.084, 0.004)], 0.0024, STEEL, 0.0006, x=0.0212)
    profile(part, "Switch", [(-0.007, 0.05), (0.007, 0.05), (0.007, 0.068, 0.002), (-0.007, 0.068, 0.002)], 0.0028, EDGE, 0.0005, x=0.0234)


def hilt_great():
    """A two-handed hilt with a long corded grip and a broad, tapering crossguard."""
    part = "Hilt_great"
    wrapped_grip(part, -0.12, 0.112, 0.0188)
    pommel(part, -0.13, 0.03)
    rings = []
    for x, h, d in ((-0.14, 0.012, 0.016), (-0.09, 0.016, 0.024), (-0.03, 0.022, 0.032), (0.03, 0.022, 0.032), (0.09, 0.016, 0.024), (0.14, 0.012, 0.016)):
        rings.append([(x, 0.125 - h, -d), (x, 0.125 - h, d), (x, 0.125 + h, d * 0.86), (x, 0.125 + h, -d * 0.86)])
    sculpt(part, "Crossguard", rings, STEEL, (0, 1, 2, 3), level=0, bevel=0.002)
    upright(part, "Emitter collar", [(0.14, 0.026, 0.026), (0.148, 0.03, 0.018), (0.154, 0.026, 0.012)], EDGE, 12, 0.0, 0.0, 2.8, 0.0006)


def beacon():
    """The squad's spawn point: a folding tripod under a sealed relay and a lit mast."""
    part = "Beacon"
    for k in range(3):
        a = math.tau * k / 3 + 0.5
        foot = (math.cos(a) * 0.46, 0.02, math.sin(a) * 0.46)
        hip = (math.cos(a) * 0.09, 0.62, math.sin(a) * 0.09)
        tube(part, "Leg", [hip, foot], 0.022, STEEL, 8)
        tube(part, "Stay", [(math.cos(a) * 0.26, 0.3, math.sin(a) * 0.26), (0, 0.42, 0)], 0.011, EDGE, 6)
        upright(part, "Foot", [(0.0, 0.05, 0.05), (0.03, 0.04, 0.04), (0.05, 0.026, 0.026)], POLY, 10, foot[0], foot[2])
    upright(part, "Relay", [(0.56, 0.12, 0.12), (0.6, 0.17, 0.17), (0.92, 0.18, 0.18), (0.98, 0.15, 0.15), (1.02, 0.11, 0.11)], OLIVE, 14, 0.0, 0.0, 3.2, 0.006)
    for y in (0.68, 0.84):
        upright(part, "Relay band", [(y - 0.012, 0.183, 0.183), (y + 0.012, 0.183, 0.183)], BLACK, 14, 0.0, 0.0, 3.2)
    upright(part, "Mast", [(1.02, 0.03, 0.03), (1.72, 0.018, 0.018)], STEEL, 10)
    upright(part, "Lamp", [(1.36, 0.028, 0.028), (1.38, 0.05, 0.05), (1.44, 0.05, 0.05), (1.46, 0.028, 0.028)], CORE, 12)
    upright(part, "Tip", [(1.72, 0.04, 0.04), (1.76, 0.04, 0.04), (1.84, 0.0, 0.0)], CORE, 10)
    for k in range(4):
        a = math.tau * k / 4
        tube(part, "Whisker", [(0, 1.6, 0), (math.cos(a) * 0.2, 1.54, math.sin(a) * 0.2)], 0.006, EDGE, 5)
    profile(part, "Status", [(-0.18, 0.72), (-0.178, 0.72), (-0.178, 0.8), (-0.18, 0.8)], 0.05, CORE, 0)


def fuze_head(part, top):
    """The fuze every grenade shares: a neck and a cap, with the lever and pin kept apart."""
    upright(part, "Neck", [(top - 0.004, 0.015, 0.015), (top + 0.012, 0.012, 0.012), (top + 0.016, 0.017, 0.017), (top + 0.03, 0.016, 0.016), (top + 0.034, 0.0, 0.0)], EDGE, 12, 0.0, 0.0, 2.0, 0.0005)


def nade_frag():
    part = "Nade_0"
    upright(part, "Body", [(-0.05, 0.0, 0.0), (-0.047, 0.014, 0.014), (-0.03, 0.03, 0.03), (0.0, 0.036, 0.036), (0.03, 0.03, 0.03), (0.046, 0.018, 0.018)], OLIVE, 16, 0.0, 0.0, 2.0)
    for y in (-0.024, -0.008, 0.008, 0.024):
        r = 0.0366 - abs(y) * 0.2
        upright(part, "Groove", [(y - 0.0022, r, r), (y + 0.0022, r, r)], BLACK, 16)
    upright(part, "Lamp", [(-0.051, 0.0, 0.0), (-0.0505, 0.009, 0.009), (-0.048, 0.009, 0.009)], CORE, 10)
    fuze_head(part, 0.046)


def canister(part, band, r):
    upright(part, "Can", [(-0.065, r * 0.9, r * 0.9), (-0.062, r, r), (0.05, r, r), (0.056, r * 0.86, r * 0.86), (0.058, 0.0, 0.0)], EDGE, 16, 0.0, 0.0, 2.0, 0.0006)
    upright(part, "Base", [(-0.068, r * 0.92, r * 0.92), (-0.062, r * 1.02, r * 1.02), (-0.056, r * 1.02, r * 1.02)], STEEL, 16)
    for y, h in ((-0.022, 0.012), (0.018, 0.012)):
        upright(part, "Band", [(y - h, r * 1.012, r * 1.012), (y + h, r * 1.012, r * 1.012)], band, 16)
    fuze_head(part, 0.056)


def nade_smoke():
    part = "Nade_1"
    canister(part, "SmokeGrey", 0.03)
    for k in range(8):
        a = math.tau * k / 8
        upright(part, "Vent", [(0.0555, 0.0036, 0.0036), (0.0585, 0.0036, 0.0036)], BLACK, 6, math.cos(a) * 0.02, math.sin(a) * 0.02)


def nade_fire():
    part = "Nade_2"
    canister(part, "WarningRed", 0.034)
    for y in (-0.044, 0.038):
        upright(part, "Rib", [(y - 0.003, 0.0352, 0.0352), (y + 0.003, 0.0352, 0.0352)], STEEL, 16)


def nade_pin():
    part = "Nade_pin"
    pts = [(0.03 + 0.018 * math.cos(math.tau * k / 12), 0.066 + 0.018 * math.sin(math.tau * k / 12), 0.0) for k in range(13)]
    tube(part, "Ring", pts, 0.0024, EDGE, 6)
    tube(part, "Pin", [(0.012, 0.066, 0.0), (-0.02, 0.066, 0.0)], 0.002, EDGE, 6)


def nade_spoon():
    part = "Nade_spoon"
    profile(part, "Lever", [(-0.008, 0.086), (0.03, 0.086, 0.004), (0.046, 0.066, 0.006), (0.046, -0.03, 0.004), (0.038, -0.03, 0.004), (0.036, 0.06, 0.006), (0.024, 0.076, 0.004), (-0.008, 0.076)], 0.008, STEEL, 0.0007)


ATTACHMENTS = [reddot, holo, scope, comp, suppressor, stabilizer, vgrip, agrip, laser, hilt_sword, hilt_saber, hilt_great, beacon, nade_frag, nade_smoke, nade_fire, nade_pin, nade_spoon]


def finish_attachments():
    root = bpy.data.objects.new("Attachments", None)
    bpy.context.collection.objects.link(root)
    for build in ATTACHMENTS:
        build()
    tris = 0
    for part in list(PARTS):
        obj = join(part)
        shade(obj, 32.0)
        bake_wear(obj)
        obj.parent = root
        tris += sum(len(q.vertices) - 2 for q in obj.data.polygons)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children:
        child.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / "attachments.glb"), export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_normals=True, export_materials="EXPORT", export_vertex_color="ACTIVE", export_all_vertex_colors=False,
        export_animations=False, export_cameras=False, export_lights=False,
    )
    print(f"[weapons] attachments: {tris} triangles", flush=True)
    PARTS.clear()
    return root


GUNS = [
    ("pistol", pistol), ("carbine", carbine), ("sniper", sniper), ("heavy", heavy), ("smg", smg), ("assault", assault),
    ("scatter", scatter), ("silent", silent), ("revolver", revolver), ("mpistol", mpistol), ("smg2", smg2), ("rifle", rifle),
    ("rail", rail_rifle), ("minigun", minigun), ("at_launcher", at_launcher), ("rocket_round", rocket_round), ("rocket_load", rocket_load),
]
MARKS = []
LAYOUT = []


def finish_gun(name):
    bpy.ops.object.select_all(action="DESELECT")
    root = bpy.data.objects.new("Weapon_" + name, None)
    bpy.context.collection.objects.link(root)
    tris = 0
    for part in (BODY, CELL, SIGHT, STOCK, SPIN):
        if part not in PARTS:
            continue
        obj = join(part)
        shade(obj, 32.0)
        bake_wear(obj)
        obj.parent = root
        tris += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    for mark in MARKS:
        mark.parent = root
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children:
        child.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / f"{name}.glb"), export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_normals=True, export_materials="EXPORT", export_vertex_color="ACTIVE", export_all_vertex_colors=False,
        export_animations=False, export_cameras=False, export_lights=False,
    )
    print(f"[weapons] {name}: {tris} triangles", flush=True)
    MARKS.clear()
    PARTS.clear()
    for child in root.children:
        child.name = f"{name}_{child.name}"
        if child.data:
            child.data.name = child.name
    return root


def preview(folder, roots):
    show_paint()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1900, 1300
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.66, 0.72, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.2
    s = bpy.data.objects.new("sun", sun)
    s.rotation_euler = (math.radians(60), math.radians(-20), math.radians(40))
    bpy.context.collection.objects.link(s)
    cam = bpy.data.cameras.new("cam")
    cam.lens = 70
    c = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(c)
    scene.camera = c
    scene.render.resolution_x, scene.render.resolution_y = 800, 450
    for i, root in enumerate(roots):
        root.location = ((i % 4) * 4.0, (i // 4) * 4.0, 0)
    bpy.context.view_layer.update()
    for root in roots:
        corners = [child.matrix_world @ Vector(c2) for child in root.children if child.type == "MESH" for c2 in child.bound_box]
        lo = Vector((min(v[k] for v in corners) for k in range(3)))
        hi = Vector((max(v[k] for v in corners) for k in range(3)))
        centre = (lo + hi) / 2
        size = (hi - lo).length
        c.location = centre + Vector((0.74, 0.46, 0.3)).normalized() * size * 1.9
        c.rotation_euler = (centre - c.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(Path(folder) / f"{root.name}.png")
        bpy.ops.render.render(write_still=True)


def show_paint():
    for m in bpy.data.materials:
        if m.name.startswith("_"):
            continue
        nodes = m.node_tree.nodes
        p = nodes["Principled BSDF"]
        attr = nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        rgb = p.inputs["Base Color"].default_value
        mix.inputs[6].default_value = (min(rgb[0] * 1.5, 1), min(rgb[1] * 1.5, 1), min(rgb[2] * 1.5, 1), 1)
        m.node_tree.links.new(attr.outputs[0], mix.inputs[7])
        m.node_tree.links.new(mix.outputs[2], p.inputs["Base Color"])


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    roots = []
    for name, build in GUNS + EMPIRE_GUNS:
        build()
        roots.append(finish_gun(name))
    roots.append(finish_attachments())
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "weapons.blend"))
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--preview" in args:
        preview(args[args.index("--preview") + 1], roots)
    print("[weapons] done", flush=True)


main()
