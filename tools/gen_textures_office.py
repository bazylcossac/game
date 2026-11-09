"""Textures for the office floors of Corp City: carpet tiles, interior wall panels and a suspended
ceiling. Every texture tiles, because the noise is made in the frequency domain and every pattern
wraps round the edge.

Run with a Python that has numpy and pillow (Blender's own python has numpy; pillow is optional
there, so this writes through Blender's image API when pillow is missing):
    python tools/gen_textures_office.py
"""
import os

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures")
N = 1024
rng = np.random.default_rng(2087)


def fbm(beta=1.8, n=N, low=1.0):
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.fftfreq(n)[None, :] * n
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spec = np.fft.fft2(rng.normal(size=(n, n))) / np.maximum(f, low) ** beta
    spec[0, 0] = 0
    x = np.real(np.fft.ifft2(spec))
    return (x - x.min()) / (np.ptp(x) or 1.0)


def blur(x, s):
    """Gaussian blur through the FFT, wrapping round the edges."""
    n = x.shape[0]
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.fftfreq(n)[None, :]
    g = np.exp(-2 * (np.pi * s) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(x) * g))


def normal_map(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    length = np.sqrt(dx * dx + dy * dy + 1.0)
    return np.stack([-dx / length * 0.5 + 0.5, dy / length * 0.5 + 0.5, 1.0 / length * 0.5 + 0.5], -1)


def save_png(path, rgb):
    data = (np.clip(rgb, 0, 1) * 255).astype(np.uint8)
    try:
        from PIL import Image
        Image.fromarray(data).save(path)
    except ImportError:
        import bpy
        h, w = data.shape[:2]
        img = bpy.data.images.new("t", w, h, alpha=False)
        rgba = np.dstack([data, np.full((h, w), 255, np.uint8)])[::-1].astype(np.float32) / 255.0
        img.pixels.foreach_set(rgba.ravel())
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()


def write(name, albedo, height, strength):
    save_png(os.path.join(OUT, name + "_albedo.png"), albedo)
    save_png(os.path.join(OUT, name + "_normal.png"), normal_map(height, strength))
    print("texture", name, flush=True)


def grid(count, n=N):
    """Position inside each of count x count tiles (0..1), and which tile it is."""
    yy, xx = np.mgrid[0:n, 0:n] / n * count
    return xx % 1.0, yy % 1.0, np.floor(xx).astype(int), np.floor(yy).astype(int)


def carpet():
    """Carpet tiles, 50 cm square, the texture 2 m across: a tight loop pile laid in alternating
    directions, a little wear on the walkways and old stains nobody cleaned."""
    u, v, i, j = grid(4)
    turn = (i + j) % 2 == 0
    along = np.where(turn, u, v)
    rows = 0.5 + 0.5 * np.sin(along * np.pi * 2 * 60)
    fibre = fbm(0.6)
    pile = rows * 0.35 + fibre * 0.65
    seam = np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v))
    gap = np.clip(seam * 140, 0, 1)
    wear = blur(fbm(2.2), 6)
    stains = np.clip((fbm(1.3) - 0.8) * 5, 0, 1) * 0.18
    shade = (0.78 + 0.22 * pile) * (0.86 + 0.14 * gap) * (1 - stains) * (0.92 + 0.16 * wear)
    shade *= np.where(turn, 1.0, 0.94)
    base = np.array([0.2, 0.205, 0.225])
    albedo = shade[..., None] * base[None, None, :] * 1.5
    write("carpet", albedo, pile * 0.6 + gap * 0.4, 2.0)


def office_wall():
    """Interior wall panels: matt off-white boards 1.2 m wide with shadow gaps, the texture 2.4 m
    across, scuffed low down where chairs and trolleys hit them."""
    yy, xx = np.mgrid[0:N, 0:N] / N
    u = (xx * 2) % 1.0
    gap = np.clip(np.minimum(u, 1 - u) * 300, 0, 1)
    band = np.clip(np.abs(((yy * 2) % 1.0) - 0.5) * 300, 0, 1)
    grain = fbm(1.2) * 0.06 + fbm(2.6) * 0.08
    scuff = np.clip((fbm(1.6) - 0.62) * 4, 0, 1) * np.clip((yy - 0.7) * 4, 0, 1) * 0.25
    shade = (0.86 + grain) * (0.55 + 0.45 * gap) * (0.75 + 0.25 * band) * (1 - scuff)
    albedo = shade[..., None] * np.array([0.84, 0.85, 0.87])[None, None, :]
    write("office_wall", albedo, gap * 0.7 + band * 0.3 + grain, 3.0)


def ceiling():
    """A suspended ceiling: 60 cm mineral tiles, pin-hole speckle, in a thin metal grid."""
    u, v, i, j = grid(4)
    edge = np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v))
    bar = edge < 0.012
    bevel = np.clip((edge - 0.012) * 60, 0, 1)
    holes = (rng.random((N, N)) < 0.03).astype(float)
    holes = blur(holes, 0.6)
    tone = 0.8 + fbm(1.4) * 0.1 - holes * 0.5
    sag = blur(fbm(2.5), 4) * 0.06
    shade = np.where(bar, 0.55, tone * (0.82 + 0.18 * bevel) - sag)
    albedo = shade[..., None] * np.array([0.88, 0.88, 0.86])[None, None, :]
    write("ceiling_tiles", albedo, np.where(bar, 0.0, 0.5 + bevel * 0.5) - holes * 0.3, 3.0)


if __name__ == "__main__":
    carpet()
    office_wall()
    ceiling()
