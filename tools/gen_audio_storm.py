"""Storm sounds: thunder near and far, and a rain and wind loop for the trench map.

Run with a Python that has numpy:  python tools/gen_audio_storm.py
"""
import numpy as np

from gen_audio import SR, save

rng = np.random.default_rng(1916)


def shaped(n, lo, hi, tilt=1.0):
    """White noise cut to a band in the spectrum, which is far quicker than a filter loop."""
    spec = np.fft.rfft(rng.normal(size=n))
    f = np.fft.rfftfreq(n, 1 / SR)
    gain = 1 / (1 + (lo / np.maximum(f, 1.0)) ** 4) / (1 + (f / hi) ** 4)
    gain = gain / np.maximum(f / max(lo, 1.0), 1.0) ** tilt
    x = np.fft.irfft(spec * gain, n)
    return x / (np.max(np.abs(x)) or 1.0)


def rolls(d, count, slow):
    """The uneven rise and fall of thunder rolling away."""
    t = np.arange(int(SR * d)) / SR
    out = np.zeros_like(t)
    for _ in range(count):
        at = rng.uniform(0.05, d * 0.7)
        width = rng.uniform(0.15, slow)
        out += rng.uniform(0.4, 1.0) * np.exp(-((t - at) / width) ** 2)
    return out / (np.max(out) or 1.0)


def thunder(d, crack, depth, count, slow):
    n = int(SR * d)
    t = np.arange(n) / SR
    low = shaped(n, 22, depth, 0.9) * rolls(d, count, slow)
    mid = shaped(n, 120, depth * 4, 0.6) * rolls(d, count, slow * 0.6) * 0.45
    tail = np.exp(-t / (d * 0.42))
    x = (low + mid) * tail
    if crack:
        snap = shaped(n, 500, 6500, 0.2) * np.exp(-t / 0.09) * np.minimum(t / 0.002, 1.0)
        boom = shaped(n, 30, 240, 0.8) * np.exp(-t / 0.35)
        x = x * 0.8 + snap * crack + boom * crack * 1.3
    return np.tanh(x * 1.6)


def main():
    for i in range(2):
        save(f"thunder_near_{i + 1}", thunder(5.5, 0.9, 200, 7, 0.6), 0.95)
        save(f"thunder_far_{i + 1}", thunder(7.0, 0.0, 120, 6, 1.1), 0.8)
    d = 24.0
    n = int(SR * d)
    t = np.arange(n) / SR
    rain = shaped(n, 900, 7000, 0.3) * 0.5 + shaped(n, 240, 1600, 0.4) * 0.5
    gust = 0.6 + 0.4 * np.sin(2 * np.pi * t / d) * np.sin(2 * np.pi * 3 * t / d)
    wind = shaped(n, 40, 420, 0.8) * gust * 0.9
    guns = np.zeros(n)
    for _ in range(9):
        at = int(rng.uniform(0.5, d - 3.0) * SR)
        shot = shaped(int(SR * 2.4), 24, 170, 0.9) * np.exp(-np.arange(int(SR * 2.4)) / SR / 0.55)
        guns[at : at + len(shot)] += shot * rng.uniform(0.3, 0.75)
    x = rain * 0.55 + wind * 0.5 + guns * 0.8
    # A seamless loop: the end fades into the start.
    k = int(SR * 2.0)
    fade = np.linspace(0, 1, k)
    x[:k] = x[:k] * fade + x[-k:] * (1 - fade)
    save("ambient_storm", x[:-k], 0.8, fade=False)


if __name__ == "__main__":
    main()
