"""Draws the marks of both sides of Corp Wars: the Rebellion's fist, flag and patched cloth, and
Korpo's logo, flag and hanging banner.

Run with a Python that has pillow:  python tools/gen_emblems.py
File names are the old internal ids: "usa" is the Rebellion, "empire" is Korpo.

Rebelia: a raised fist breaking a chain link, sprayed in red on black, the mark of the last humans.
Korpo: a clean white hexagon holding one red, unblinking eye. A logo, not a symbol: it is meant to
look like a company that already owns everything.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
FONT = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts", "Anton-Regular.ttf")
RED = (196, 30, 28, 255)
BONE = (232, 226, 210, 255)
INK = (16, 16, 18, 255)
WHITE = (238, 240, 242, 255)
EYE = (236, 34, 30, 255)


def fist(d, cx, cy, s, fill):
    """A raised fist, knuckles up, drawn from blocks so it reads at any size."""
    def box(x0, y0, x1, y1, r=0.06):
        d.rounded_rectangle([cx + x0 * s, cy + y0 * s, cx + x1 * s, cy + y1 * s], radius=r * s, fill=fill)
    # Four fingers folded over, the thumb across them, the wrist below.
    for i in range(4):
        x = -0.36 + i * 0.185
        box(x, -0.62 + (0.05 if i in (0, 3) else 0.0), x + 0.17, -0.2)
    box(-0.4, -0.3, 0.38, 0.12, 0.1)
    box(-0.42, -0.2, 0.06, -0.04, 0.07)
    box(-0.26, 0.05, 0.26, 0.62, 0.05)


def chain_break(d, cx, cy, s, fill, gap):
    """A chain link snapped in two, either side of the wrist."""
    w = 0.09 * s
    for side in (-1, 1):
        x = cx + side * 0.55 * s
        d.arc([x - 0.2 * s, cy - 0.13 * s, x + 0.2 * s, cy + 0.13 * s], 0 if side < 0 else 180, 180 if side < 0 else 360, fill=fill, width=int(w))
        d.line([x - side * 0.2 * s, cy, x - side * 0.08 * s, cy - 0.06 * s], fill=gap, width=int(w * 0.8))


def rebel_mark(size, ring=RED, field=INK, mark=BONE):
    k = 3
    s = size * k
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    d.ellipse([c - s * 0.48, c - s * 0.48, c + s * 0.48, c + s * 0.48], fill=ring)
    d.ellipse([c - s * 0.42, c - s * 0.42, c + s * 0.42, c + s * 0.42], fill=field)
    chain_break(d, c, c + s * 0.15, s * 0.42, mark, field)
    fist(d, c, c - s * 0.02, s * 0.34, mark)
    return img.resize((size, size), Image.LANCZOS)


def hexagon(cx, cy, r, turn=0.0):
    return [(cx + math.cos(math.tau * i / 6 + turn) * r, cy + math.sin(math.tau * i / 6 + turn) * r) for i in range(6)]


def korpo_mark(d, cx, cy, r, shell=WHITE, field=INK, eye=EYE):
    """A white hexagon, a black field, one red eye with a hard white glint."""
    d.polygon(hexagon(cx, cy, r, math.pi / 6), fill=shell)
    d.polygon(hexagon(cx, cy, r * 0.8, math.pi / 6), fill=field)
    w, h = r * 0.56, r * 0.3
    d.ellipse([cx - w, cy - h, cx + w, cy + h], fill=shell)
    e = r * 0.24
    d.ellipse([cx - e, cy - e, cx + e, cy + e], fill=eye)
    g = r * 0.07
    d.ellipse([cx - e * 0.4 - g, cy - e * 0.4 - g, cx - e * 0.4 + g, cy - e * 0.4 + g], fill=shell)


def worn(img, seed, amount=0.22):
    """Scrapes and sprayed edges, so the Rebellion's marks look painted by hand."""
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img)
    w, h = img.size
    for _ in range(int(w * h * amount / 900)):
        x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        r = rnd.uniform(0.6, 3.2)
        col = img.getpixel((int(x) % w, int(y) % h))
        shade = tuple(max(0, int(c * rnd.uniform(0.55, 0.85))) for c in col[:3])
        d.ellipse([x - r, y - r, x + r, y + r], fill=shade + ((col[3],) if len(col) > 3 else ()))
    return img


def rebel_flag(width, height):
    """Black cloth, a red band across it, the fist in the middle."""
    img = Image.new("RGB", (width, height), (20, 19, 18))
    d = ImageDraw.Draw(img)
    d.rectangle([0, height * 0.36, width, height * 0.64], fill=(150, 24, 22))
    mark = rebel_mark(int(height * 0.8), ring=(196, 30, 28, 255), field=(20, 19, 18, 255))
    img.paste(mark, (int(width / 2 - mark.width / 2), int(height / 2 - mark.height / 2)), mark)
    return worn(img, 1, 0.5)


def patchwork(size=512):
    """Rebel clothing: patched cloth in faded olive, brown, grey and denim. Tiles."""
    rnd = random.Random(2049)
    img = Image.new("RGB", (size, size), (86, 74, 58))
    d = ImageDraw.Draw(img)
    colours = [(98, 84, 62), (78, 62, 46), (88, 84, 70), (66, 68, 56), (110, 92, 66), (72, 62, 50), (112, 44, 34)]
    for _ in range(46):
        x, y = rnd.uniform(0, size), rnd.uniform(0, size)
        w, h = rnd.uniform(40, 140), rnd.uniform(30, 120)
        col = rnd.choice(colours)
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d.rectangle([x + ox, y + oy, x + ox + w, y + oy + h], fill=col)
                # Stitches round the patch.
                for t in range(0, int(w), 9):
                    d.line([x + ox + t, y + oy + 2, x + ox + t + 4, y + oy + 2], fill=(52, 48, 40), width=1)
                    d.line([x + ox + t, y + oy + h - 2, x + ox + t + 4, y + oy + h - 2], fill=(52, 48, 40), width=1)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    return worn(img.convert("RGB"), 7, 0.4)


def draw_all(width=1024, height=640):
    rebel_flag(width, height).save(os.path.join(OUT, "flag_usa.png"))
    rebel_mark(256).save(os.path.join(OUT, "icon_usa.png"))
    patchwork().save(os.path.join(OUT, "camo_usa.png"))

    img = Image.new("RGB", (width, height), (12, 12, 14))
    d = ImageDraw.Draw(img)
    for y0, y1, col in ((0, 26, (226, 228, 230)), (height - 26, height, (226, 228, 230))):
        d.rectangle([0, y0, width, y1], fill=col)
    korpo_mark(d, width * 0.5, height * 0.44, 180)
    font = ImageFont.truetype(FONT, 78)
    text = "KORPO"
    tw = d.textlength(text, font=font)
    d.text((width / 2 - tw / 2, height * 0.74), text, font=font, fill=(226, 228, 230))
    img.save(os.path.join(OUT, "flag_empire.png"))

    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    korpo_mark(ImageDraw.Draw(img), size / 2, size / 2, 124)
    img.save(os.path.join(OUT, "icon_empire.png"))

    bw, bh = 256, 640
    img = Image.new("RGB", (bw, bh), (12, 12, 14))
    d = ImageDraw.Draw(img)
    for x0, x1 in ((0, 12), (bw - 12, bw)):
        d.rectangle([x0, 0, x1, bh], fill=(226, 228, 230))
    korpo_mark(d, bw / 2, bh * 0.3, 92)
    font = ImageFont.truetype(FONT, 46)
    tw = d.textlength(text, font=font)
    d.text((bw / 2 - tw / 2, bh * 0.5), text, font=font, fill=(226, 228, 230))
    d.rectangle([bw * 0.3, bh * 0.62, bw * 0.7, bh * 0.625], fill=(196, 30, 28))
    img.save(os.path.join(OUT, "banner_empire.png"))


if __name__ == "__main__":
    draw_all()
