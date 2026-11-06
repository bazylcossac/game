"""Generates the armour detail map used by shaders/armor.gdshader, and the Golem's brow mark.

Run with a Python that has numpy + pillow:  python tools/gen_armor.py
armor_detail.png channels: RG surface normal, B seam cavity (0 in a seam), A wear noise.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
S = 1024
rng = np.random.default_rng(1944)


def fractal(beta, seed):
    r = np.random.default_rng(seed)
    fx = np.fft.fftfreq(S)[:, None]
    fy = np.fft.fftfreq(S)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spec = (r.normal(size=(S, S)) + 1j * r.normal(size=(S, S))) / f ** (beta / 2 + 0.5)
    spec[0, 0] = 0
    n = np.fft.ifft2(spec).real
    return (n - n.min()) / (n.max() - n.min())


def split(x, y, w, h, out, depth=0):
    """Cuts the tile into uneven plates, the way real armour panels are laid out."""
    if depth >= 4 or (w < 300 and h < 300) or (depth >= 2 and rng.random() < 0.28):
        out.append((x, y, w, h))
        return
    if w >= h:
        c = int(w * rng.uniform(0.34, 0.66))
        split(x, y, c, h, out, depth + 1)
        split(x + c, y, w - c, h, out, depth + 1)
    else:
        c = int(h * rng.uniform(0.34, 0.66))
        split(x, y, w, c, out, depth + 1)
        split(x, y + c, w, h - c, out, depth + 1)


def main():
    plates = []
    split(0, 0, S, S, plates)
    height = Image.new("F", (S, S), 0.5)
    cavity = Image.new("L", (S, S), 255)
    hd = ImageDraw.Draw(height)
    cd = ImageDraw.Draw(cavity)
    for x, y, w, h in plates:
        hd.rectangle([x, y, x + w, y + h], fill=float(rng.uniform(0.46, 0.56)))
    for x, y, w, h in plates:
        hd.rectangle([x, y, x + w, y + h], outline=0.0, width=3)
        cd.rectangle([x, y, x + w, y + h], outline=0, width=3)
        if rng.random() < 0.55:
            # A row of bolts just inside the seam.
            step = int(rng.integers(44, 70))
            pts = [(x + i, y + 13) for i in range(20, w - 12, step)] + [(x + i, y + h - 13) for i in range(20, w - 12, step)]
            for px, py in pts:
                hd.ellipse([px - 5, py - 5, px + 5, py + 5], fill=0.95)
                cd.ellipse([px - 7, py - 7, px + 7, py + 7], outline=120, width=1)
        if rng.random() < 0.3 and w > 170 and h > 170:
            # An inspection hatch.
            cx, cy = x + w // 2, y + h // 2
            hw, hh = int(w * 0.26), int(h * 0.26)
            hd.rectangle([cx - hw, cy - hh, cx + hw, cy + hh], outline=0.1, width=2)
            cd.rectangle([cx - hw, cy - hh, cx + hw, cy + hh], outline=70, width=2)
    h = np.asarray(height, dtype=np.float64)
    h = (h + np.roll(h, 1, 0) + np.roll(h, -1, 0) + np.roll(h, 1, 1) + np.roll(h, -1, 1)) / 5

    # Scratches and dents, drawn at every wrap offset so the tile stays seamless.
    scratch = Image.new("L", (S, S), 0)
    sd = ImageDraw.Draw(scratch)
    for _ in range(170):
        x0, y0 = rng.uniform(0, S, 2)
        a = rng.uniform(0, np.pi)
        ln = rng.uniform(20, 170)
        x1, y1 = x0 + np.cos(a) * ln, y0 + np.sin(a) * ln
        v = int(rng.integers(70, 200))
        for ox in (-S, 0, S):
            for oy in (-S, 0, S):
                sd.line([x0 + ox, y0 + oy, x1 + ox, y1 + oy], fill=v, width=1)
    sc = np.asarray(scratch.filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float64) / 255
    h = h - sc * 0.09 + (fractal(2.3, 5) - 0.5) * 0.16 + (fractal(0.9, 6) - 0.5) * 0.018

    gx = np.roll(h, -1, 1) - np.roll(h, 1, 1)
    gy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
    k = 5.5
    r = np.clip(0.5 - gx * k, 0, 1)
    g = np.clip(0.5 + gy * k, 0, 1)
    cav = np.asarray(cavity.filter(ImageFilter.GaussianBlur(1.4)), dtype=np.float64) / 255
    cav = np.clip(cav * (1 - sc * 0.25), 0, 1)
    wear = fractal(1.7, 7) * 0.72 + fractal(0.8, 8) * 0.28
    wear = (wear - wear.min()) / (wear.max() - wear.min())
    a = 0.02 + wear * 0.98
    rgba = np.dstack([r, g, cav, a])
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "armor_detail.png"))

    # "Emet", truth, the word on the brow of the Golem in the old story. It reads right to left
    # and is written here in visual order, because Pillow's basic layout does no bidi.
    font = ImageFont.truetype("C:/Windows/Fonts/timesbd.ttf", 150)
    img = Image.new("RGBA", (512, 192), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    d.text((256, 92), "\u05ea\u05de\u05d0", font=font, fill=(255, 255, 255, 255), anchor="mm")
    img.save(os.path.join(OUT, "emet.png"))
    print("armour done")


if __name__ == "__main__":
    main()
