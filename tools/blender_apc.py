"""Builds the troop carrier in Blender, as a smaller relative of the hover tank.

Run:  blender --background --factory-startup --python tools/blender_apc.py

Same lofted hull, sponsons, lift slots and materials as tools/blender_tank.py, so TankAssets paints
it for each side, but with a raised troop box, a rear ramp and no gun at all.
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
PALETTE.update({
    PLATE: ((0.47, 0.36, 0.2), 0.1, 0.55, 0), PLATE2: ((0.3, 0.23, 0.13), 0.1, 0.6, 0),
    DARK: ((0.015, 0.014, 0.013), 0.1, 0.8, 0), STEEL: ((0.2, 0.2, 0.2), 0.9, 0.38, 0),
    TRIM: ((0.7, 0.42, 0.1), 0.9, 0.34, 0), GLASS: ((0.01, 0.03, 0.05), 0.2, 0.08, 0),
    LIGHT: ((0.2, 0.7, 1.0), 0, 0.5, 8), SOFT: ((0.2, 0.7, 1.0), 0, 0.5, 3),
})
P = "ApcHull"


def station(z, belly, chine, shoulder, deck, spine):
    return (z, [(0.0, belly[1]), belly, chine, shoulder, deck, (deck[0] * 0.5, spine - 0.012), (0.0, spine)])


def build():
    stations = [
        station(-3.2, (0.1, 0.4), (0.24, 0.44), (0.2, 0.5), (0.14, 0.53), 0.54),
        station(-2.8, (0.48, 0.22), (0.76, 0.42), (0.66, 0.6), (0.5, 0.68), 0.7),
        station(-2.15, (0.8, 0.08), (1.06, 0.44), (0.96, 0.78), (0.76, 0.92), 0.96),
        station(-1.2, (0.94, 0.0), (1.16, 0.46), (1.08, 0.9), (0.9, 1.06), 1.1),
        station(0.4, (0.96, 0.0), (1.16, 0.48), (1.1, 0.92), (0.96, 1.08), 1.12),
        station(2.0, (0.94, 0.02), (1.14, 0.5), (1.08, 0.94), (0.92, 1.08), 1.12),
        station(2.75, (0.84, 0.14), (1.06, 0.52), (1.0, 0.9), (0.84, 1.02), 1.06),
        station(3.0, (0.72, 0.26), (0.92, 0.54), (0.86, 0.86), (0.72, 0.94), 0.97),
    ]
    core = body(P, "Hull core", stations, PLATE, (1, 2, 3, 4), level=3, bevel=0.014)

    # The troop box: sloped walls rising out of the hull, wider at the bottom like the turret ring.
    box = [
        (-1.05, [(0.0, 0.98), (0.84, 0.98), (0.8, 1.34), (0.5, 1.5), (0.0, 1.52)]),
        (-0.55, [(0.0, 0.98), (0.96, 0.98), (0.86, 1.72), (0.66, 1.96), (0.0, 2.0)]),
        (1.3, [(0.0, 0.98), (1.0, 0.98), (0.9, 1.78), (0.7, 2.04), (0.0, 2.08)]),
        (2.5, [(0.0, 0.98), (1.0, 0.98), (0.9, 1.74), (0.7, 2.0), (0.0, 2.04)]),
        (2.72, [(0.0, 0.98), (0.96, 0.98), (0.86, 1.64), (0.66, 1.88), (0.0, 1.9)]),
    ]
    cabin = body(P, "Troop box", box, PLATE2, (1, 2, 3), level=2, bevel=0.012)

    sponsons = {}
    for side in (1, -1):
        rings = []
        for z, cx, w, lo, hi, mid in [
            (-2.75, 1.14, 0.06, 0.36, 0.5, 0.42), (-2.4, 1.24, 0.18, 0.16, 0.64, 0.4), (-1.6, 1.36, 0.3, 0.0, 0.8, 0.36),
            (-0.4, 1.42, 0.33, -0.06, 0.86, 0.34), (1.1, 1.43, 0.33, -0.06, 0.9, 0.36), (2.3, 1.41, 0.33, -0.02, 0.94, 0.42),
            (2.9, 1.36, 0.3, 0.1, 0.94, 0.5), (3.1, 1.33, 0.26, 0.16, 0.9, 0.54),
        ]:
            ring = [
                (cx - w * 0.8, lo + 0.06, z), (cx + w * 0.5, lo, z), (cx + w, mid, z), (cx + w * 0.56, hi - 0.1, z),
                (cx - w * 0.1, hi, z), (cx - w * 0.86, hi - 0.16, z), (cx - w * 1.02, mid + 0.14, z),
            ]
            rings.append([(p[0] * side, p[1], p[2]) for p in ring])
        sponsons[side] = sculpt(P, f"Sponson {side}", rings, PLATE2, (1, 2, 3, 4, 5), level=3, bevel=0.012)

    # Nose: thick wedge, a wide driver's screen and the same chevron as the tank.
    plate(P, "Glacis", [(-0.42, -2.82), (0.42, -2.82), (0.66, -2.05), (0.48, -1.5), (-0.48, -1.5), (-0.66, -2.05)], "top", core, PLATE2, 0.05, 0.02)
    stripe(P, "Glacis chevron", [(0.05, -2.7), (0.26, -2.3), (0.48, -1.96)], 0.05, "top", core, TRIM, 0.055, mirror=True)
    plate(P, "Screen frame", [(-0.72, -1.3), (0.72, -1.3), (0.8, -0.86), (-0.8, -0.86)], "top", cabin, DARK, 0.03, 0.02)
    plate(P, "Screen", [(-0.62, -1.24), (0.62, -1.24), (0.68, -0.9), (-0.68, -0.9)], "top", cabin, GLASS, 0.04, 0.006)
    # Roof: two hatches, an intake and a sensor mast where a tank would carry its gun.
    plate(P, "Roof plate", [(-0.5, -0.4), (0.5, -0.4), (0.5, 2.3), (-0.5, 2.3)], "top", cabin, PLATE, 0.03, 0.02)
    for z in (0.2, 1.5):
        lathe(P, f"Hatch ring {z}", [(0, 0.34), (0.05, 0.34)], STEEL, 16)
        obj = PARTS[P][-1]
        obj.data.transform(Matrix.Rotation(math.pi / 2, 4, "X"))
        obj.data.transform(Matrix.Translation(B((0, 2.06, z))))
        lathe(P, f"Hatch lid {z}", [(0, 0.29), (0.04, 0.27), (0.07, 0.0)], PLATE2, 16)
        obj = PARTS[P][-1]
        obj.data.transform(Matrix.Rotation(math.pi / 2, 4, "X"))
        obj.data.transform(Matrix.Translation(B((0, 2.1, z))))
    grille(P, "Roof intake", [(0.1, 0.72), (0.46, 0.72), (0.46, 1.1), (0.1, 1.1)], "top", cabin, 5, mirror=True)
    upright(P, "Mast foot", [(2.05, 0.09, 0.09), (2.28, 0.05, 0.05)], STEEL, 10, 0.62, 2.1)
    upright(P, "Mast", [(2.28, 0.02, 0.02), (3.1, 0.01, 0.01)], DARK, 6, 0.62, 2.1)
    for side, target in sponsons.items():
        axis = "right" if side > 0 else "left"
        # Hung side armour, and the firing slits of the troop box.
        plate(P, f"Skirt A {side}", [(-2.1, 0.32), (-0.8, 0.16), (-0.76, 0.72), (-1.8, 0.7)], axis, target, PLATE, 0.04, 0.022)
        plate(P, f"Skirt B {side}", [(-0.7, 0.16), (1.0, 0.16), (1.04, 0.76), (-0.66, 0.73)], axis, target, PLATE, 0.04, 0.022)
        plate(P, f"Skirt C {side}", [(1.1, 0.16), (2.5, 0.22), (2.6, 0.8), (1.14, 0.77)], axis, target, PLATE, 0.04, 0.022)
        stripe(P, f"Skirt trim {side}", [(-2.05, 0.08), (-0.7, 0.05), (1.0, 0.05), (2.55, 0.1)], 0.045, axis, target, TRIM, 0.05)
        studs(P, f"Studs {side}", (-0.6, 0.68), (0.92, 0.7), 8, axis, target)
        x = 1.4 * side
        plate(P, f"Lift well {side}", [(x - 0.24, -1.8), (x + 0.18, -1.8), (x + 0.2, 2.3), (x - 0.22, 2.3)], "bottom", target, DARK, 0.03, 0.01)
        for k, (z0, z1) in enumerate(((-1.65, -0.4), (-0.2, 0.9), (1.1, 2.15))):
            plate(P, f"Lift {side} {k}", [(x - 0.1, z0), (x + 0.08, z0), (x + 0.08, z1), (x - 0.1, z1)], "bottom", target, LIGHT, 0.04, 0.0)
        cx = 1.34 * side
        turned(P, f"Collar {side}", [(2.86, 0.3, 0.38), (2.96, 0.32, 0.4), (3.1, 0.31, 0.39), (3.16, 0.28, 0.35)], STEEL, 16, cx, 0.54, 3.0)
        turned(P, f"Nozzle {side}", [(3.1, 0.27, 0.33), (3.3, 0.24, 0.29), (3.32, 0.2, 0.25), (3.0, 0.2, 0.25)], DARK, 16, cx, 0.54, 3.6)
        turned(P, f"Nozzle glow {side}", [(3.02, 0.2, 0.24), (3.04, 0.0, 0.0)], LIGHT, 16, cx, 0.54, 3.6)
        # Handrail and a step, because this one is for climbing in and out of.
        tube(P, f"Grab rail {side}", [(0.98 * side, 1.3, -0.3), (1.08 * side, 1.42, -0.2), (1.08 * side, 1.46, 2.0), (0.98 * side, 1.34, 2.1)], 0.022, STEEL, 6)
        slab(P, f"Step {side}", [(2.3, 0.82), (2.75, 0.82), (2.75, 0.88), (2.3, 0.88)], 1.5 * side - 0.12, 1.5 * side + 0.12, STEEL, 0.008)
        canister(P, f"Bottle {side}", 1.42 * side, 1.0, 1.5, 1.0, 0.09)
        # Firing ports along the troop box.
        for i in range(3):
            z = 0.1 + i * 0.8
            obj = box_on(P, f"Port frame {side} {i}", (0.97 * side, 1.5, z), (0.06, 0.2, 0.48), DARK, side)
            box_on(P, f"Port glass {side} {i}", (0.99 * side, 1.5, z), (0.03, 0.12, 0.38), GLASS, side)
        box_on(P, f"Box lamp {side}", (0.98 * side, 1.15, 1.0), (0.03, 0.04, 2.6), SOFT, side)
    # Rear ramp, hinged at the bottom: the widest door on the vehicle.
    ramp = [(-0.72, 0.5), (0.72, 0.5), (0.68, 1.75), (-0.68, 1.75)]
    plate(P, "Ramp", ramp, "rear", cabin, PLATE, 0.05, 0.03)
    plate(P, "Ramp window", [(-0.3, 1.32), (0.3, 1.32), (0.28, 1.58), (-0.28, 1.58)], "rear", cabin, GLASS, 0.058, 0.004)
    stripe(P, "Tail lamp", [(-0.62, 0.72), (0.62, 0.72)], 0.05, "rear", core, SOFT, 0.05)
    for x in (-0.5, 0.5):
        slab(P, f"Ramp strut {x}", [(2.72, 1.0), (2.84, 1.0), (2.84, 1.6), (2.72, 1.6)], x - 0.04, x + 0.04, STEEL, 0.006)
    for side in (-1, 1):
        plate(P, f"Nose lamp {side}", [(0.78 * side, -2.3), (1.0 * side, -2.26), (1.02 * side, -2.08), (0.8 * side, -2.12)], "top", core, LIGHT, 0.05, 0.0)
    body(P, "Belly", [
        station(-2.5, (0.3, 0.1), (0.5, 0.2), (0.45, 0.3), (0.3, 0.32), 0.34),
        station(-1.3, (0.76, -0.08), (0.86, 0.1), (0.8, 0.3), (0.5, 0.32), 0.34),
        station(2.1, (0.76, -0.08), (0.86, 0.1), (0.8, 0.3), (0.5, 0.32), 0.34),
        station(2.7, (0.5, 0.1), (0.6, 0.2), (0.5, 0.3), (0.3, 0.32), 0.34),
    ], DARK, (1, 2), level=1, bevel=0)
    return cabin


def box_on(part, name, centre, size, mat, side):
    """A small box leaning with the troop box wall."""
    c = Vector(centre)
    h = Vector(size) / 2
    turn = Matrix.Rotation(-0.13 * side, 3, "Z")
    corners = [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]
    verts = [B(c + turn @ Vector((x * h.x, y * h.y, z * h.z))) for x, y, z in corners]
    obj = add(part, name, verts, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3)], mat)
    outward(obj)
    return obj


def bake(obj):
    mesh = obj.data
    whole = BVHTree.FromPolygons([v.co.copy() for v in mesh.vertices], [tuple(p.vertices) for p in mesh.polygons])
    rnd = random.Random(7)
    dirs = []
    for _ in range(12):
        u, a = rnd.random(), rnd.random() * math.tau
        r = math.sqrt(u)
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(1 - u))))
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
        start = v.co + n * 0.012
        free = sum(1 for d in dirs if whole.ray_cast(start, t * d.x + b * d.y + n * d.z, 1.3)[0] is None)
        attr.data[v.index].color = (0.32 + 0.68 * (free / len(dirs)) ** 0.8, wear[v.index], 0, 1)
    mesh.color_attributes.active_color_index = 0


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    build()
    obj = join(P)
    shade(obj)
    bake(obj)
    for name, pos in {"ApcExhaust_R": (1.34, 0.54, 3.16), "ApcExhaust_L": (-1.34, 0.54, 3.16), "ApcEmblem_R": (0.965, 1.72, 1.5), "ApcEmblem_L": (-0.965, 1.72, 1.5)}.items():
        e = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(e)
        e.parent = obj
        e.location = B(pos)
    print("[apc] triangles", sum(len(p.vertices) - 2 for p in obj.data.polygons), flush=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / "apc.glb"), export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_normals=True, export_materials="EXPORT", export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_animations=False,
    )
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "apc.blend"))
    print("[apc] done", flush=True)


main()
