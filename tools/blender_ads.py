"""Renders the pictures for Korpo's billboards in Corp City, from the robots' own models.

Run after blender_droids.py:
    blender --background --factory-startup --python tools/blender_ads.py -- OUT_DIR
Then lay the slogans over them with:  python tools/gen_ads.py OUT_DIR

Each picture is a studio portrait the way a corporation would shoot its staff: black ground, hard
red rim light from behind, a cold key from the front. The machines are meant to look calm, clean
and certain, which is what makes them frightening.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "art_source" / "ads"
OUT.mkdir(parents=True, exist_ok=True)
POSE = {"Pelvis": (0, 0.95, 0), "Torso": (0, 1.03, 0), "Head": (0, 1.56, 0), "UpperArm_R": (0.28, 1.5, 0), "UpperArm_L": (-0.28, 1.5, 0), "Forearm_R": (0.28, 1.21, 0), "Forearm_L": (-0.28, 1.21, 0),
        "Thigh_R": (0.1, 0.9, 0), "Thigh_L": (-0.1, 0.9, 0), "Shin_R": (0.1, 0.45, 0), "Shin_L": (-0.1, 0.45, 0), "Boot_R": (0.1, 0.0, 0), "Boot_L": (-0.1, 0.0, 0)}
TIES = [(0.1, 0.24, 0.72), (0.72, 0.05, 0.05), (0.9, 0.72, 0.08), (0.08, 0.5, 0.18), (0.02, 0.02, 0.025), (0.9, 0.38, 0.05)]

bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art_source" / "droids.blend"))
scene = bpy.context.scene
source = {o.name: o for o in scene.objects if o.type == "MESH"}
for o in source.values():
    o.hide_render = True


def vertex_shading():
    """The models carry their shading in vertex colours, which a plain material ignores."""
    for m in bpy.data.materials:
        if m.name.startswith("_") or m.node_tree is None or "Principled BSDF" not in m.node_tree.nodes:
            continue
        nodes = m.node_tree.nodes
        if any(n.type == "VERTEX_COLOR" for n in nodes):
            continue
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


vertex_shading()
placed = []


def robot(frame, at, tie_colour, turn=0.0, arm_up=0.0):
    """Puts a copy of one frame together at `at` (Blender space), turned round its own up axis."""
    group = bpy.data.objects.new("robot", None)
    scene.collection.objects.link(group)
    group.location = at
    # The models face +Y in Blender; the camera stands on the -Y side.
    group.rotation_euler = (0, 0, turn + math.pi)
    names = dict(POSE)
    for name, pos in names.items():
        src = source.get(f"{frame}_{name}")
        if src is None:
            continue
        o = src.copy()
        o.hide_render = False
        scene.collection.objects.link(o)
        o.parent = group
        o.location = (pos[0], -pos[2], pos[1])
        if arm_up and name in ("Forearm_R", "UpperArm_R"):
            # Raised round the shoulder, so the weapon arm points at the camera's side of the room.
            angle = math.radians(arm_up)
            o.rotation_euler = (angle, 0, 0)
            if name == "Forearm_R":
                o.location = (pos[0], 0.29 * math.sin(angle), 1.5 - 0.29 * math.cos(angle))
        placed.append(o)
    tie = source["Tie_Big" if frame == "Big" else "Tie"].copy()
    tie.data = tie.data.copy()
    tie.hide_render = False
    scene.collection.objects.link(tie)
    tie.parent = group
    tie.location = (0, 0, 1.03)
    mat = bpy.data.materials.new("tie")
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*tie_colour, 1)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.35
    tie.data.materials[0] = mat
    placed.append(tie)
    return group


def clear():
    for o in list(scene.objects):
        if o.name.startswith("robot") or o in placed:
            bpy.data.objects.remove(o, do_unlink=True)
    placed.clear()


def lights():
    for name, kind, energy, colour, pos, size in [
        ("key", "AREA", 260.0, (0.78, 0.84, 1.0), (1.6, -3.2, 2.6), 2.0),
        ("rim", "AREA", 900.0, (1.0, 0.08, 0.04), (-1.2, 2.4, 2.4), 1.2),
        ("rim2", "AREA", 500.0, (1.0, 0.1, 0.06), (1.8, 2.2, 1.4), 1.0),
        ("fill", "AREA", 40.0, (0.3, 0.4, 0.7), (-2.6, -2.0, 1.0), 3.0),
    ]:
        light = bpy.data.lights.new(name, kind)
        light.energy = energy
        light.color = colour
        light.size = size
        o = bpy.data.objects.new(name, light)
        scene.collection.objects.link(o)
        o.location = pos
        o.rotation_euler = (Vector((0, 0, 1.4)) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()


def shoot(label, cam_pos, aim, lens, width=1024, height=512):
    cam = scene.camera
    cam.location = cam_pos
    cam.rotation_euler = (Vector(aim) - Vector(cam_pos)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.filepath = str(OUT / f"{label}.png")
    bpy.ops.render.render(write_still=True)


scene.render.engine = "BLENDER_EEVEE"
scene.render.film_transparent = False
world = bpy.data.worlds.new("void")
world.node_tree.nodes["Background"].inputs[0].default_value = (0.004, 0.004, 0.006, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
scene.world = world
for o in list(scene.objects):
    if o.type in ("LIGHT", "CAMERA"):
        bpy.data.objects.remove(o, do_unlink=True)
cam_data = bpy.data.cameras.new("cam")
scene.camera = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(scene.camera)
lights()
try:
    scene.view_settings.look = "AgX - High Contrast"
except TypeError:
    pass

# A face, close and a little from the side.
robot("Reg", (0, 0, 0), TIES[1], math.radians(-18))
shoot("face", (0.55, -1.25, 1.66), (0.02, 0, 1.68), 85)
shoot("stare", (0.0, -1.4, 1.68), (0.0, 0, 1.68), 105)
clear()
# The new staff: a row of them, from a little below, like an annual report.
for i, x in enumerate((-1.6, -0.8, 0.0, 0.8, 1.6)):
    robot("Reg", (x, 0.25 * abs(x), 0), TIES[i], math.radians(-x * 4))
shoot("lineup", (0.0, -5.2, 1.0), (0.0, 0, 1.35), 50)
clear()
# The liquidator, weapon arm up.
robot("Big", (0, 0, 0), TIES[1], math.radians(-24), 82.0)
shoot("liquidator", (1.2, -3.0, 1.45), (0.1, 0, 1.45), 55)
print("[ads] done", flush=True)
