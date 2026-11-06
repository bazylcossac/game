"""Draws the marks of both sides: the American flag, the star and camouflage, and the Iron
Empire's flag, icon and hanging banner.

Run with a Python that has pillow:  python tools/gen_emblems.py
The mark is a toothed ring around a horizontal slit: a machine's eye, the Empire's only symbol.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
STEEL = (196, 200, 204, 255)
DARK = (22, 24, 28, 255)
EYE = (232, 56, 34, 255)


def empire_mark(draw, cx, cy, r, ring=STEEL, field=DARK, eye=EYE):
    """Eight teeth on a ring, with a split eye inside."""
    teeth = 8
    points = []
    for i in range(teeth * 4):
        a = math.tau * i / (teeth * 4) - math.pi / (teeth * 4) * 1.5
        reach = r if i % 4 in (1, 2) else r * 0.82
        points.append((cx + math.cos(a) * reach, cy + math.sin(a) * reach))
    draw.polygon(points, fill=ring)
    inner = r * 0.62
    draw.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], fill=field)
    w, h = r * 0.5, r * 0.11
    draw.polygon([(cx - w, cy), (cx - w * 0.3, cy - h), (cx + w * 0.3, cy - h), (cx + w, cy), (cx + w * 0.3, cy + h), (cx - w * 0.3, cy + h)], fill=eye)


def star(draw, cx, cy, r, fill):
    points = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        k = r if i % 2 == 0 else r * 0.382
        points.append((cx + math.cos(a) * k, cy + math.sin(a) * k))
    draw.polygon(points, fill=fill)


def american_flag(width=1024, height=640):
    """Thirteen stripes and fifty stars, drawn large and scaled down so the stars stay clean."""
    k = 3
    w, h = width * k, height * k
    img = Image.new("RGB", (w, h), (255, 255, 255))
    d = ImageDraw.Draw(img)
    red = (178, 34, 52)
    for i in range(13):
        if i % 2 == 0:
            d.rectangle([0, i * h / 13, w, (i + 1) * h / 13], fill=red)
    union_w, union_h = w * 0.4, h * 7 / 13
    d.rectangle([0, 0, union_w, union_h], fill=(60, 59, 110))
    for row in range(9):
        for col in range(6 if row % 2 == 0 else 5):
            x = union_w * (col * 2 + (1 if row % 2 == 0 else 2)) / 12
            y = union_h * (row + 1) / 10
            star(d, x, y, union_h * 0.0616 * 0.8, (255, 255, 255))
    return img.resize((width, height), Image.LANCZOS)


def american_star(size=256):
    k = 3
    s = size * k
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    d.ellipse([c - s * 0.47, c - s * 0.47, c + s * 0.47, c + s * 0.47], fill=(235, 235, 228, 255))
    d.ellipse([c - s * 0.43, c - s * 0.43, c + s * 0.43, c + s * 0.43], fill=(34, 44, 84, 255))
    star(d, c, c + s * 0.012, s * 0.4, (240, 240, 232, 255))
    return img.resize((size, size), Image.LANCZOS)


def camouflage(size=512):
    """Soft blotches in sand, olive and brown. Tiles, since each blotch wraps round the edges."""
    rnd = random.Random(1776)
    img = Image.new("RGB", (size, size), (142, 128, 100))
    d = ImageDraw.Draw(img)
    for colour, count, lo, hi in (((172, 158, 126), 34, 24, 62), ((104, 102, 72), 30, 22, 58), ((122, 96, 70), 22, 16, 44), ((74, 72, 52), 18, 10, 30), ((196, 184, 152), 16, 6, 18)):
        for _ in range(count):
            x, y = rnd.uniform(0, size), rnd.uniform(0, size)
            blob = [(rnd.uniform(-1, 1), rnd.uniform(-0.6, 0.6)) for _ in range(5)]
            r = rnd.uniform(lo, hi)
            for ox in (-size, 0, size):
                for oy in (-size, 0, size):
                    for bx, by in blob:
                        cx, cy = x + ox + bx * r, y + oy + by * r
                        d.ellipse([cx - r * 0.6, cy - r * 0.42, cx + r * 0.6, cy + r * 0.42], fill=colour)
    return img.filter(ImageFilter.GaussianBlur(1.6))


def draw_all(width=1024, height=640):
    american_flag(width, height).save(os.path.join(OUT, "flag_usa.png"))
    american_star().save(os.path.join(OUT, "icon_usa.png"))
    camouflage().save(os.path.join(OUT, "camo_usa.png"))

    img = Image.new("RGB", (width, height), (24, 26, 30))
    d = ImageDraw.Draw(img)
    red = (150, 34, 24)
    steel = (150, 154, 160)
    for y0, y1, col in ((0, 40, steel), (40, 58, red), (height - 58, height - 40, red), (height - 40, height, steel)):
        d.rectangle([0, y0, width, y1], fill=col)
    empire_mark(d, width / 2, height / 2, 190)
    img.save(os.path.join(OUT, "flag_empire.png"))

    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    empire_mark(ImageDraw.Draw(img), size / 2, size / 2, 118)
    img.save(os.path.join(OUT, "icon_empire.png"))

    bw, bh = 256, 640
    img = Image.new("RGB", (bw, bh), (24, 26, 30))
    d = ImageDraw.Draw(img)
    for x0, x1, col in ((0, 18, steel), (18, 30, red), (bw - 30, bw - 18, red), (bw - 18, bw, steel)):
        d.rectangle([x0, 0, x1, bh], fill=col)
    empire_mark(d, bw / 2, bh * 0.34, 84)
    d.rectangle([0, bh - 18, bw, bh], fill=red)
    img.save(os.path.join(OUT, "banner_empire.png"))


if __name__ == "__main__":
    draw_all()
