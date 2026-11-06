"""Turns the pictures from `--test=menu-art --out=<dir>` into the menu card images.
Usage: python tools/menu_art.py <dir>"""
import glob
import os
import sys

from PIL import Image

OUT = "assets/textures/menu"
os.makedirs(OUT, exist_ok=True)
for path in glob.glob(os.path.join(sys.argv[1], "*.png")):
    name = os.path.splitext(os.path.basename(path))[0]
    image = Image.open(path).convert("RGB").resize((800, 450), Image.LANCZOS)
    image.save(os.path.join(OUT, name + ".jpg"), quality=86, optimize=True)
    print(name)
