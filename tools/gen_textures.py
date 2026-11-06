"""Authored surface textures: mud, trench planks, burlap, corrugated iron, wet asphalt, sci-fi wall
panels and the macro noise the world shader uses. Every texture tiles, because the noise is made in
the frequency domain and every pattern wraps round the edge.

Run with a Python that has numpy, scipy and pillow:  python tools/gen_textures.py
"""
import os

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
from scipy.spatial import cKDTree

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
N = 1024
rng = np.random.default_rng(1917)


def fbm(beta=1.8, n=N, stretch=(1.0, 1.0), low=1.0):
    """Periodic noise with a 1/f^beta spectrum, scaled to 0..1."""
    fy = np.fft.fftfreq(n)[:, None] * n * stretch[0]
    fx = np.fft.fftfreq(n)[None, :] * n * stretch[1]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spec = np.fft.fft2(rng.normal(size=(n, n))) / np.maximum(f, low) ** beta
    spec[0, 0] = 0
    x = np.real(np.fft.ifft2(spec))
    return (x - x.min()) / (np.ptp(x) or 1.0)


def cells(count, n=N):
    """Periodic Worley noise: distance to the nearest point and the gap to the second nearest."""
    pts = rng.uniform(0, n, (count, 2))
    tiled = np.concatenate([pts + (dx * n, dy * n) for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    yy, xx = np.mgrid[0:n, 0:n]
    d, _ = cKDTree(tiled).query(np.stack([xx.ravel(), yy.ravel()], 1), k=2)
    return d[:, 0].reshape(n, n), (d[:, 1] - d[:, 0]).reshape(n, n)


def blur(x, s):
    return gaussian_filter(x, s, mode="wrap")


def normal_map(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    length = np.sqrt(dx * dx + dy * dy + 1.0)
    return np.stack([-dx / length * 0.5 + 0.5, dy / length * 0.5 + 0.5, 1.0 / length * 0.5 + 0.5], -1)


def write(name, albedo, height, strength, alpha=None):
    a = np.clip(albedo, 0, 1)
    if alpha is not None:
        a = np.dstack([a, np.clip(alpha, 0, 1)])
    Image.fromarray((a * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_albedo.png"))
    Image.fromarray((normal_map(height, strength) * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_normal.png"))
    print("texture", name)


def tint(mask, a, b):
    return np.array(a)[None, None, :] * (1 - mask[..., None]) + np.array(b)[None, None, :] * mask[..., None]


def mud():
    lumps = fbm(1.9)
    fine = fbm(1.1)
    _, gap = cells(420)
    cracks = np.clip(gap / 7.0, 0, 1)
    h = lumps * 0.75 + fine * 0.2 + cracks * 0.05
    # Tyre and boot furrows, churned through it.
    rut = fbm(2.2, stretch=(1.0, 0.14))
    h = h + np.abs(rut - 0.5) * 0.25
    water = np.clip((0.44 - h) / 0.12, 0, 1)
    col = tint(np.clip(lumps * 1.5 - 0.3, 0, 1), (0.1, 0.075, 0.05), (0.23, 0.17, 0.11))
    col *= (0.82 + fine * 0.36)[..., None]
    col = col * (1 - 0.55 * water[..., None])
    write("mud", col, h, 22.0, alpha=1.0 - water)


def planks():
    boards = 8
    y = np.arange(N) / N * boards
    board = y.astype(int)
    edge = np.abs(y - np.round(y))
    gap = np.clip(edge / 0.035, 0, 1)
    h = np.repeat(gap[:, None], N, 1)
    grain = fbm(1.5, stretch=(1.0, 0.03))
    shift = rng.uniform(0.74, 1.15, boards)[board]
    col = tint(grain, (0.2, 0.135, 0.08), (0.42, 0.3, 0.19))
    col = col * shift[:, None, None]
    knots = np.zeros((N, N))
    for _ in range(26):
        cy, cx = rng.integers(0, N, 2)
        yy = np.minimum(np.abs(np.arange(N) - cy), N - np.abs(np.arange(N) - cy))[:, None]
        xx = np.minimum(np.abs(np.arange(N) - cx), N - np.abs(np.arange(N) - cx))[None, :]
        knots = np.maximum(knots, np.exp(-(xx * xx / 200.0 + yy * yy / 60.0)))
    col = col * (1 - knots[..., None] * 0.6)
    # Wet mud creeping up the boards, and nail heads on each joint.
    splash = np.clip(fbm(1.7) * 1.4 - 0.45, 0, 1)
    col = col * (1 - splash[..., None] * 0.55)
    h = h * 0.6 + grain * 0.32 - knots * 0.15
    for _ in range(90):
        b = rng.integers(0, boards)
        x = rng.integers(0, N)
        yy = int((b + 0.5) / boards * N)
        col[yy - 2:yy + 3, x - 2:x + 3] = (0.09, 0.08, 0.075)
    write("planks", col * gap[:, None, None] ** 0.5, h, 9.0)


def burlap():
    x = np.arange(N) / N * 220 * np.pi * 2
    weave = (np.sin(x)[None, :] * 0.5 + 0.5) * (np.sin(x)[:, None] * 0.5 + 0.5)
    h = weave * 0.45 + fbm(1.6) * 0.55
    col = tint(fbm(1.6), (0.3, 0.25, 0.17), (0.5, 0.42, 0.29))
    col = col * (0.72 + weave * 0.4)[..., None] * (1 - np.clip(fbm(1.9) * 1.6 - 0.6, 0, 1)[..., None] * 0.6)
    write("burlap", col, h, 6.0)


def corrugated():
    x = np.arange(N) / N * 16 * np.pi * 2
    ribs = np.sin(x)[None, :] * 0.5 + 0.5
    h = np.repeat(ribs, N, 0)
    rust = np.clip(fbm(1.7, stretch=(0.3, 1.0)) * 1.8 - 0.55, 0, 1)
    col = tint(rust, (0.3, 0.31, 0.32), (0.3, 0.14, 0.07))
    col = col * (0.75 + ribs * 0.35)[..., None]
    write("corrugated", col, h * 0.9 + rust * 0.1, 7.0)


def asphalt():
    grit = fbm(0.45)
    base = fbm(1.8)
    _, gap = cells(70)
    crack = 1 - np.clip(gap / 2.4, 0, 1)
    crack = crack * np.clip(fbm(2.0) * 2.4 - 0.9, 0, 1)
    h = grit * 0.55 + base * 0.45 - crack * 0.6
    col = tint(base, (0.055, 0.057, 0.065), (0.13, 0.135, 0.145))
    col = col * (0.72 + grit * 0.62)[..., None]
    tar = np.clip(fbm(2.1) * 2.6 - 1.5, 0, 1)
    col = col * (1 - tar[..., None] * 0.45) * (1 - crack[..., None] * 0.7)
    write("asphalt", col, h, 7.0)


def panel():
    """Wall panels of a space station: an uneven grid of plates with seams, bolts and vents."""
    h = np.zeros((N, N))
    tone = np.zeros((N, N))
    rects = [(0, 0, N, N)]
    for _ in range(5):
        out = []
        for y, x, hh, ww in rects:
            if hh > 170 and ww > 170 and rng.random() < 0.9:
                if rng.random() < 0.5:
                    c = int(hh * rng.uniform(0.35, 0.65) / 16) * 16
                    out += [(y, x, c, ww), (y + c, x, hh - c, ww)]
                else:
                    c = int(ww * rng.uniform(0.35, 0.65) / 16) * 16
                    out += [(y, x, hh, c), (y, x + c, hh, ww - c)]
            else:
                out.append((y, x, hh, ww))
        rects = out
    seam = np.ones((N, N))
    for y, x, hh, ww in rects:
        level = rng.uniform(0.55, 0.85)
        h[y:y + hh, x:x + ww] = level
        tone[y:y + hh, x:x + ww] = rng.uniform(0.82, 1.1)
        seam[y:y + 3, x:x + ww] = 0
        seam[y + hh - 3:y + hh, x:x + ww] = 0
        seam[y:y + hh, x:x + 3] = 0
        seam[y:y + hh, x + ww - 3:x + ww] = 0
        for cy, cx in ((y + 14, x + 14), (y + 14, x + ww - 14), (y + hh - 14, x + 14), (y + hh - 14, x + ww - 14)):
            yy, xx = np.ogrid[max(cy - 6, 0):min(cy + 7, N), max(cx - 6, 0):min(cx + 7, N)]
            bolt = (yy - cy) ** 2 + (xx - cx) ** 2 <= 30
            h[max(cy - 6, 0):min(cy + 7, N), max(cx - 6, 0):min(cx + 7, N)][bolt] += 0.14
        if ww > 200 and hh > 120 and rng.random() < 0.45:
            for i in range(8):
                vy = y + hh // 2 - 44 + i * 11
                h[vy:vy + 6, x + 40:x + ww - 40] -= 0.3
                seam[vy:vy + 6, x + 40:x + ww - 40] *= 0.3
    h = blur(h, 1.2) * blur(seam, 0.8)
    grime = fbm(1.8)
    col = tint(grime, (0.3, 0.33, 0.38), (0.47, 0.5, 0.55))
    col = col * tone[..., None] * (0.25 + 0.75 * blur(seam, 1.0))[..., None]
    streak = np.clip(fbm(1.9, stretch=(0.12, 1.0)) * 1.8 - 0.8, 0, 1)
    col = col * (1 - streak[..., None] * 0.28)
    write("panel", col, h + fbm(1.0) * 0.012, 9.0)


def leaves():
    """A clump of leaves on transparent ground, for the cards of a tree's crown."""
    from PIL import ImageDraw
    size = 512
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for i in range(520):
        cx, cy = rng.normal(size / 2, size / 5.2, 2)
        a = rng.uniform(0, np.pi * 2)
        length = rng.uniform(26, 50)
        width = length * rng.uniform(0.32, 0.46)
        shade = rng.uniform(0.55, 1.0)
        tone = (int(150 * shade), int(205 * shade), int(120 * shade), 255)
        pts = []
        for t in np.linspace(0, 1, 9):
            w = np.sin(t * np.pi) * width
            pts.append((cx + np.cos(a) * length * t - np.sin(a) * w, cy + np.sin(a) * length * t + np.cos(a) * w))
        for t in np.linspace(1, 0, 9):
            w = -np.sin(t * np.pi) * width
            pts.append((cx + np.cos(a) * length * t - np.sin(a) * w, cy + np.sin(a) * length * t + np.cos(a) * w))
        draw.polygon(pts, fill=tone)
    img.save(os.path.join(OUT, "leaf_cards.png"))
    print("texture leaf_cards")


def macro():
    size = 512
    a, b, c = fbm(2.1, size), fbm(1.6, size, low=4.0), fbm(1.3, size, stretch=(0.08, 1.0), low=2.0)
    d = fbm(2.4, size)
    Image.fromarray((np.dstack([a, b, c, d]) * 255).astype(np.uint8)).save(os.path.join(OUT, "macro_noise.png"))
    print("texture macro_noise")


if __name__ == "__main__":
    mud()
    planks()
    burlap()
    corrugated()
    asphalt()
    panel()
    leaves()
    macro()
