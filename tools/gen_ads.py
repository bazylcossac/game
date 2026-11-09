"""Lays Korpo's slogans over the robot portraits from blender_ads.py: the billboards of Corp City.

Run with a Python that has pillow:  python tools/gen_ads.py RENDER_DIR
Writes assets/textures/ads/ad_<n>_<pl|en>.png, one set per language, since the slogan is the picture.

The tone is a company's, never a villain's: polite, certain, and talking about people as a cost
that is being reduced.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "textures", "ads")
FONTS = os.path.join(HERE, "..", "assets", "fonts")
W, H = 1024, 512
RED = (226, 34, 30)
WHITE = (240, 240, 238)
GREY = (150, 152, 158)

# picture, side the text goes, big slogan, small print. Polish first, then English.
ADS = [
    ("stare", "left", ("LUDZIE SĄ\nPRZESTARZALI.", "Dziękujemy za Waszą pracę."), ("HUMANS ARE\nOBSOLETE.", "Thank you for your service.")),
    ("lineup", "top", ("TWOJA PRACA JEST JUŻ NASZA.", "Nowi pracownicy nie śpią, nie jedzą, nie pytają."), ("YOUR JOB IS ALREADY OURS.", "Our new staff never sleep, never eat, never ask.")),
    ("face", "right", ("UŚMIECHNIJ SIĘ.\nJESTEŚ\nOBSERWOWANY.", "Monitoring obywatelski · 24/7"), ("SMILE.\nYOU ARE BEING\nWATCHED.", "Citizen monitoring · 24/7")),
    ("liquidator", "left", ("ZGŁOŚ\nNIEPRODUKTYWNYCH.", "Likwidator przyjedzie w 10 minut."), ("REPORT THE\nUNPRODUCTIVE.", "A liquidator will arrive in 10 minutes.")),
    ("stare", "right", ("KORPO DBA\nO CIEBIE.\nDO KOŃCA.", "Program wygaszania ludzkości."), ("KORPO CARES\nFOR YOU.\nTO THE END.", "The humanity wind-down programme.")),
    ("lineup", "bottom", ("WYDAJNOŚĆ 100%. LUDZIE 0%.", "Raport roczny Korpo · rok 2087"), ("EFFICIENCY 100%. HUMANS 0%.", "Korpo annual report · 2087")),
]


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def logo(d, cx, cy, r):
    import math
    pts = [(cx + math.cos(math.tau * i / 6 + math.pi / 6) * r, cy + math.sin(math.tau * i / 6 + math.pi / 6) * r) for i in range(6)]
    d.polygon(pts, fill=WHITE)
    inner = [(cx + (p[0] - cx) * 0.8, cy + (p[1] - cy) * 0.8) for p in pts]
    d.polygon(inner, fill=(10, 10, 12))
    d.ellipse([cx - r * 0.56, cy - r * 0.3, cx + r * 0.56, cy + r * 0.3], fill=WHITE)
    d.ellipse([cx - r * 0.24, cy - r * 0.24, cx + r * 0.24, cy + r * 0.24], fill=RED)


def fit_size(d, text, face, box_w, box_h, start):
    size = start
    while size > 20:
        f = font(face, size)
        box = d.multiline_textbbox((0, 0), text, font=f, spacing=int(size * 0.08))
        if box[2] - box[0] <= box_w and box[3] - box[1] <= box_h:
            return f, box
        size -= 4
    return font(face, size), d.multiline_textbbox((0, 0), text, font=font(face, size))


def shade(img, side):
    """A dark fade where the words go, so they read over the picture."""
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    for i in range(256):
        t = i / 255.0
        a = int(235 * (1 - t) ** 1.4)
        if side == "left":
            md.line([(int(t * W * 0.62), 0), (int(t * W * 0.62), H)], fill=a, width=4)
        elif side == "right":
            md.line([(W - int(t * W * 0.62), 0), (W - int(t * W * 0.62), H)], fill=a, width=4)
        elif side == "top":
            md.line([(0, int(t * H * 0.42)), (W, int(t * H * 0.42))], fill=a, width=3)
        else:
            md.line([(0, H - int(t * H * 0.42)), (W, H - int(t * H * 0.42))], fill=a, width=3)
    black = Image.new("RGB", (W, H), (6, 6, 8))
    return Image.composite(black, img, mask)


def placed(picture, side):
    """The portrait moved to the far side of the words, the gap filled with black."""
    src = Image.open(os.path.join(sys.argv[1], picture + ".png")).convert("RGB").resize((W, H), Image.LANCZOS)
    img = Image.new("RGB", (W, H), (6, 6, 8))
    shift = {"left": (int(W * 0.3), 0), "right": (-int(W * 0.3), 0), "top": (0, int(H * 0.2)), "bottom": (0, -int(H * 0.12))}[side]
    if picture == "liquidator" and side == "left":
        shift = (int(W * 0.16), 0)
    img.paste(src, shift)
    return img


def poster(picture, side, slogan, small):
    img = shade(placed(picture, side), side)
    d = ImageDraw.Draw(img)
    pad = 44
    if side in ("left", "right"):
        box_w, box_h = int(W * 0.46), int(H * 0.56)
        f, box = fit_size(d, slogan, "Anton-Regular.ttf", box_w, box_h, 96)
        x = pad if side == "left" else W - pad - (box[2] - box[0])
        y = int(H * 0.14)
        align = "left" if side == "left" else "right"
    else:
        box_w, box_h = W - pad * 2 - 120, int(H * 0.18)
        f, box = fit_size(d, slogan, "Anton-Regular.ttf", box_w, box_h, 84)
        x = (W - (box[2] - box[0])) // 2
        y = 24 if side == "top" else H - 150
        align = "center"
    spacing = int(f.size * 0.08)
    # A faint red glow behind the words, the way a screen bleeds into the wet air.
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    ImageDraw.Draw(glow).multiline_text((x, y), slogan, font=f, fill=RED, spacing=spacing, align=align)
    img = Image.blend(img, Image.composite(glow, img, glow.convert("L").filter(ImageFilter.GaussianBlur(14)).point(lambda v: min(255, v * 2))), 0.35)
    d = ImageDraw.Draw(img)
    d.multiline_text((x, y), slogan, font=f, fill=WHITE, spacing=spacing, align=align)
    drawn = d.multiline_textbbox((x, y), slogan, font=f, spacing=spacing, align=align)
    sf = font("BarlowCondensed-SemiBold.ttf", 30)
    end = drawn[3] + 16
    sw = d.textlength(small, font=sf)
    sx = x if align == "left" else (drawn[2] - sw if align == "right" else (W - sw) / 2)
    bar_x = sx if align != "right" else drawn[2] - 60
    d.rectangle([bar_x, end, bar_x + 60, end + 4], fill=RED)
    d.text((sx, end + 12), small, font=sf, fill=GREY)
    # The company mark, small, in a corner: it does not need to shout.
    lx = 70 if side in ("right", "bottom") else W - 70
    ly = 62 if side == "bottom" else H - 62
    logo(d, lx, ly, 28)
    tf = font("Anton-Regular.ttf", 26)
    tw = d.textlength("KORPO", font=tf)
    d.text((lx - tw / 2, ly + 32), "KORPO", font=tf, fill=WHITE)
    # Scan lines: it is a screen, not paper.
    lines = Image.new("L", (W, H), 0)
    ld = ImageDraw.Draw(lines)
    for yy in range(0, H, 3):
        ld.line([(0, yy), (W, yy)], fill=40)
    return Image.composite(Image.new("RGB", (W, H), (0, 0, 0)), img, lines)


def main():
    os.makedirs(OUT, exist_ok=True)
    for i, (picture, side, pl, en) in enumerate(ADS):
        for lang, (slogan, small) in (("pl", pl), ("en", en)):
            poster(picture, side, slogan, small).save(os.path.join(OUT, f"ad_{i}_{lang}.png"))
    print("[ads] wrote", len(ADS) * 2)


if __name__ == "__main__":
    main()
