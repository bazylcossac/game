"""Synthesises the combat sounds: weapon handling, energy blades, explosions, voices.
The shots themselves come from gen_audio_blaster.py.

Everything is built from scratch in the style of space-opera sound design, not sampled.
Run with a Python that has numpy:  python tools/gen_audio_battle.py
"""
import numpy as np

import gen_audio as g
from gen_audio import SR, env, highpass, lowpass, mix, noise, save, sweep, t_of

rng = np.random.default_rng(1977)


def const(x, fc):
    return lowpass(x, fc + np.zeros(len(x)))


def reverb(x, wet=0.25, length=0.5, dark=2600.0):
    """A short open-air tail: convolution with filtered, decaying noise."""
    # Close the dry signal first: a hard stop here would be a click in every shot.
    x = fade_tail(x, 8)
    n = int(SR * length)
    ir = const(rng.normal(size=n), dark) * np.exp(-np.arange(n) / SR * (7.0 / length))
    ir /= np.sqrt(np.sum(ir ** 2)) or 1.0
    size = len(x) + n
    fft = 1 << (size - 1).bit_length()
    tail = np.fft.irfft(np.fft.rfft(x, fft) * np.fft.rfft(ir, fft), fft)[:size]
    out = np.zeros(size)
    out[: len(x)] = x
    return out + tail * wet


def fade_tail(x, ms=30):
    n = min(int(SR * ms / 1000), len(x))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def falling_phase(f0, f1, d, tau):
    """Pitch that drops exponentially: the shape of a struck tension wire."""
    t = t_of(d)
    return np.cumsum(f1 + (f0 - f1) * np.exp(-t / tau)) / SR * 2 * np.pi


def weapon_handling():
    save("empty_click", highpass(noise(0.04), 1800) * env(0.04, 0.0005, 120))
    click = highpass(noise(0.05), 1200) * env(0.05, 0.0005, 90)
    drain = sweep(1400, 240, 0.28, 1.4) * env(0.28, 0.002, 14) * 0.35
    charge = sweep(240, 3200, 0.55, 0.55) * env(0.55, 0.05, 4.5) * 0.3
    save("reload_out", mix(click, drain))
    save("reload_in", mix(np.concatenate([np.zeros(int(SR * 0.02)), click]), charge))


def hum_tone(t, base=86.0):
    """Two near-unison buzzing tones, like an old projector motor."""
    a = sum(np.sin(2 * np.pi * base * k * t) / k ** 0.9 for k in range(1, 9))
    b = sum(np.sin(2 * np.pi * (base + 1.5) * k * t + 0.7) / k ** 1.1 for k in range(1, 7))
    return a + 0.8 * b


def blades():
    # Exactly two seconds of whole cycles, so it loops with no seam at all.
    t = t_of(2.0)
    hum = hum_tone(t) * (1 + 0.12 * np.sin(2 * np.pi * 3.5 * t)) + 0.35 * np.sin(2 * np.pi * 172.5 * t)
    save("sword_hum", hum / np.max(np.abs(hum)), 0.7, fade=False)

    def crackle(d, rate, floor=2000):
        x = np.zeros(int(SR * d))
        for _ in range(int(d * rate)):
            p = rng.integers(0, len(x) - 200)
            x[p: p + 120] += rng.uniform(-1, 1) * np.exp(-np.arange(120) / 18)
        return highpass(x, floor)

    def swing(rise, d):
        t = t_of(d)
        bell = np.sin(np.pi * t / d) ** 1.6
        # The pitch bends as the blade passes the ear, then falls away.
        f = 86.0 * (1 + rise * bell)
        ph = np.cumsum(f) / SR * 2 * np.pi
        tone = sum(np.sin(k * ph) / k ** 0.9 for k in range(1, 8)) * bell
        whoosh = lowpass(noise(d), 500 + 4200 * bell) * bell * 1.3
        return fade_tail(reverb(mix(tone * 0.6, whoosh), 0.12, 0.25))

    for i, (rise, d) in enumerate(((0.9, 0.34), (1.3, 0.38), (0.6, 0.46))):
        save(f"sword_swing_{i + 1}", swing(rise, d))

    # Ignition: a sharp snap, then the hum climbs into place.
    d = 0.6
    t = t_of(d)
    ph = np.cumsum(86.0 * (0.4 + 0.6 * np.minimum(t / 0.22, 1))) / SR * 2 * np.pi
    body = sum(np.sin(k * ph) / k ** 0.9 for k in range(1, 8)) * np.minimum(t / 0.05, 1) * np.exp(-np.maximum(t - 0.28, 0) * 7)
    snap = highpass(noise(d), 1500) * env(d, 0.0005, 30)
    save("sword_on", fade_tail(reverb(mix(body * 0.6, snap * 1.2, crackle(d, 90) * env(d, 0.001, 10)), 0.15, 0.3)))
    save("sword_off", fade_tail(reverb(mix(body[::-1] * 0.6, crackle(d, 50)[::-1] * env(d, 0.001, 6)[::-1] * 0.7), 0.1, 0.2)))

    for i in range(2):
        d = 0.8
        t = t_of(d)
        ring = sum(np.sin(2 * np.pi * f * rng.uniform(0.97, 1.03) * t) * a * np.exp(-t * k) for f, a, k in ((1180, 1, 9), (1890, 0.8, 11), (2960, 0.6, 15), (4310, 0.4, 22)))
        crack = crackle(d, 260, 1200) * env(d, 0.0008, 7) * 2.6
        thump = sweep(140, 50, d, 2) * env(d, 0.001, 20)
        save(f"sword_clash_{i + 1}", fade_tail(reverb(np.tanh(mix(ring * 0.6, crack, thump) * 1.4), 0.3, 0.6)))
    for i in range(2):
        d = 0.5
        sizzle = highpass(noise(d), 2400) * env(d, 0.002, 7) * (0.6 + 0.4 * np.sin(2 * np.pi * 95 * t_of(d)))
        burn = crackle(d, 180) * env(d, 0.001, 8) * 1.6
        thud = const(noise(0.12), 320) * env(0.12, 0.001, 34) * 1.6
        save(f"sword_hit_{i + 1}", fade_tail(mix(sizzle, burn, thud)))
    for i in range(2):
        # A bolt turned aside: it rises off the blade and flies away.
        d = 0.42
        t = t_of(d)
        ph = np.cumsum(1200 + 3200 * np.sin(np.pi * np.minimum(t / 0.3, 1)) ** 2 * rng.uniform(0.85, 1.15)) / SR * 2 * np.pi
        zing = (np.sin(ph) + 0.4 * np.sin(2.01 * ph)) * env(d, 0.0008, 9)
        save(f"deflect_{i + 1}", fade_tail(reverb(mix(zing, crackle(d, 160) * env(d, 0.001, 22) * 1.5), 0.3, 0.45)))


def impacts():
    for i in range(3):
        d = 0.24
        t = t_of(d)
        ph = falling_phase(rng.uniform(4200, 5600), 900, d, 0.018)
        zap = np.sin(ph) * env(d, 0.0004, 40) * 0.5
        burst = highpass(noise(d), 2200) * env(d, 0.0004, 42)
        chip = const(noise(0.08), 900) * env(0.08, 0.0008, 60) * 1.2
        patter = np.zeros(len(t))
        for _ in range(7):
            p = rng.integers(int(SR * 0.04), len(t) - 900)
            patter[p: p + 700] += highpass(noise(700 / SR), 2500) * np.exp(-np.arange(700) / 90) * rng.uniform(0.1, 0.45)
        save(f"impact_wall_{i + 1}", fade_tail(reverb(mix(zap, burst, chip, patter), 0.12, 0.25)))
    for i in range(3):
        d = 0.3
        # Energy striking armour and cloth: a dull thud with a hot crackle on top.
        thud = const(noise(d), rng.uniform(260, 380)) * env(d, 0.001, 26) * 2.4
        sub = sweep(120, 55, d, 2) * env(d, 0.001, 24) * 0.9
        sizzle = const(highpass(noise(d), 1800), 6500) * env(d, 0.002, 34) * 0.22
        zap = np.sin(falling_phase(1500, 240, d, 0.03)) * env(d, 0.0008, 26) * 0.35
        save(f"impact_body_{i + 1}", fade_tail(reverb(np.tanh(mix(thud, sub, sizzle, zap) * 1.1), 0.08, 0.18), 20))


def boom(d, sub_hz, crack, rumble, debris):
    t = t_of(d)
    snap = highpass(noise(d), 2000) * env(d, 0.0003, 70) * crack
    body = lowpass(noise(d), 120 + 3800 * np.exp(-t * 11)) * env(d, 0.002, 2.6) * 2.6
    sub = sweep(sub_hz, 26, d, 2.6) * env(d, 0.003, 2.4) * 1.8
    roll = const(noise(d), 110) * (0.6 + 0.4 * np.sin(2 * np.pi * 2.3 * t + 1)) * np.minimum(t / 0.2, 1) * np.exp(-t * 1.7) * rumble
    bits = np.zeros(len(t))
    for _ in range(debris):
        p = int(SR * rng.uniform(0.15, d * 0.8))
        n = min(1400, len(t) - p)
        bits[p: p + n] += highpass(noise(n / SR), 1800) * np.exp(-np.arange(n) / 200) * rng.uniform(0.05, 0.32) * np.exp(-p / SR * 1.2)
    whine = sweep(1900, 120, min(0.6, d), 2.4, "saw") * env(min(0.6, d), 0.001, 9) * 0.22
    x = np.tanh(mix(snap, body, sub, roll, bits, whine) * 1.7)
    return fade_tail(reverb(x, 0.35, 1.1, 1400), 120)


def explosions():
    save("explosion_1", boom(2.6, 110, 1.3, 2.4, 24))
    save("explosion_2", boom(2.9, 95, 1.1, 2.8, 30))
    save("explosion_big", boom(4.2, 80, 1.6, 3.8, 60))
    t = t_of(0.22)
    save("grenade_throw", lowpass(noise(0.22), 900 + 1500 * np.sin(np.pi * t / 0.22)) * np.sin(np.pi * t / 0.22))
    save("grenade_bounce", mix(sweep(1800, 900, 0.08, 2) * env(0.08, 0.0005, 60), highpass(noise(0.05), 2500) * env(0.05, 0.0005, 90) * 0.5))


def resonator(x, freqs, bw):
    """Two-pole band-pass whose centre can move over time."""
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    r = np.exp(-np.pi * bw / SR)
    a2 = -r * r
    gain = 1 - r
    c = 2 * r * np.cos(2 * np.pi * freqs / SR)
    for i in range(len(x)):
        v = gain * x[i] + c[i] * y1 + a2 * y2
        y2 = y1
        y1 = v
        y[i] = v
    return y


# First three formants of the vowels used, in Hz.
VOWELS = {"a": (760, 1180, 2500), "o": (520, 880, 2450), "u": (340, 760, 2300), "e": (560, 1750, 2500)}


def voice(p0, p1, d, start, end, breath=0.25, rough=0.2, attack=0.03, release=0.25):
    """A pained cry, heard through a gas mask: formant synthesis over a pulse source."""
    t = t_of(d)
    k = t / d
    pitch = p0 + (p1 - p0) * k ** 0.7
    pitch = pitch * (1 + 0.012 * np.sin(2 * np.pi * 6.5 * t) + rough * 0.05 * const(rng.normal(size=len(t)), 26) * 12)
    ph = np.cumsum(pitch) / SR * 2 * np.pi
    source = sum(np.sin(h * ph + rng.uniform(0, 0.4)) / h ** 1.15 for h in range(1, 34))
    source += const(rng.normal(size=len(t)), 5000) * breath * 3
    sound = np.zeros(len(t))
    a = np.array(VOWELS[start], dtype=float)
    b = np.array(VOWELS[end], dtype=float)
    for f in range(3):
        track = a[f] + (b[f] - a[f]) * k
        sound += resonator(source, track, (90, 120, 170)[f]) * (1.0, 0.7, 0.35)[f]
    shape = np.minimum(t / attack, 1) * np.minimum((d - t) / release, 1)
    sound *= np.maximum(shape, 0) ** 1.2
    # The mask: a narrow band with a slight rattle.
    masked = highpass(const(sound, 3100), 260)
    masked = np.tanh(masked / (np.max(np.abs(masked)) or 1) * 2.2) * (1 + 0.1 * np.sin(2 * np.pi * 88 * t))
    return fade_tail(reverb(masked, 0.14, 0.3), 40)


def voices():
    cries = [
        (225, 118, 0.95, "a", "o", 0.25, 0.3),
        (180, 92, 1.15, "o", "u", 0.3, 0.35),
        (300, 150, 0.7, "e", "a", 0.2, 0.25),
        (150, 80, 0.85, "a", "u", 0.35, 0.45),
        (260, 110, 1.05, "a", "e", 0.2, 0.3),
    ]
    for i, (p0, p1, d, s, e, b, r) in enumerate(cries):
        save(f"death_{i + 1}", voice(p0, p1, d, s, e, b, r), 0.8)
    grunts = [(170, 130, 0.2, "u", "o"), (205, 150, 0.17, "a", "a"), (140, 110, 0.24, "o", "u"), (240, 170, 0.15, "e", "a")]
    for i, (p0, p1, d, s, e) in enumerate(grunts):
        save(f"hurt_{i + 1}", voice(p0, p1, d, s, e, 0.35, 0.3, 0.012, 0.09), 0.75)


if __name__ == "__main__":
    weapon_handling()
    blades()
    impacts()
    explosions()
    voices()
