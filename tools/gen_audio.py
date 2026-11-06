"""Synthesises every sound effect and music loop used by the game.

Run with a Python that has numpy:  python tools/gen_audio.py
Output: 16-bit mono WAV files in assets/audio.
"""
import os
import wave

import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
SR = 44100
rng = np.random.default_rng(1943)


def t_of(d):
    return np.arange(int(SR * d)) / SR


def env(d, a=0.002, decay=6.0):
    t = t_of(d)
    return np.minimum(t / max(a, 1e-5), 1.0) * np.exp(-t * decay)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lowpass(x, fc):
    """One-pole lowpass, run twice for a gentler 12 dB/oct slope. fc may be an array."""
    a = 1 - np.exp(-2 * np.pi * np.broadcast_to(fc, x.shape) / SR)
    for _ in range(2):
        y = np.empty_like(x)
        s = 0.0
        for i in range(len(x)):
            s += a[i] * (x[i] - s)
            y[i] = s
        x = y
    return x


def highpass(x, fc):
    return x - lowpass(x, fc)


def sweep(f0, f1, d, curve=2.0, shape="sine"):
    t = t_of(d)
    f = f1 + (f0 - f1) * (1 - t / d) ** curve
    ph = np.cumsum(f) / SR * 2 * np.pi
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if shape == "square":
        return np.sign(np.sin(ph))
    return np.sin(ph)


def echo(x, delay=0.11, fb=0.35, n=4):
    d = int(delay * SR)
    out = np.concatenate([x, np.zeros(d * n)])
    for i in range(1, n + 1):
        out[d * i:d * i + len(x)] += x * fb ** i
    return out


def save(name, x, gain=0.9, fade=True):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    if fade:
        n = min(400, len(x))
        x[-n:] *= np.linspace(1, 0, n)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print("audio", name)


def mix(*xs):
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[:len(x)] += x
    return out


def laser(f0, f1, d, body=0.5, crack=0.5, decay=9.0, tail=True):
    a = sweep(f0, f1, d, 2.6, "saw") * env(d, 0.001, decay)
    b = sweep(f0 * 0.5, f1 * 0.4, d, 2.0) * env(d, 0.001, decay * 0.8) * body
    c = highpass(noise(d), 2500) * env(d, 0.0005, 70) * crack
    low = sweep(190, 60, d, 2) * env(d, 0.001, 18) * 0.7
    s = mix(lowpass(a, 6000 + np.zeros(len(a))), b, c, low)
    return echo(s, 0.09, 0.22, 3) if tail else s


def impacts():
    footsteps()
    save("land", lowpass(noise(0.25), 260 + np.zeros(int(SR * 0.25))) * env(0.25, 0.002, 18))
    save("hitmarker", mix(sweep(2600, 2400, 0.05) * env(0.05, 0.0005, 70), highpass(noise(0.03), 4000) * env(0.03, 0.0003, 160) * 0.3))
    t = t_of(0.3)
    save("headshot", (np.sin(2 * np.pi * 1760 * t) + 0.6 * np.sin(2 * np.pi * 2640 * t)) * env(0.3, 0.0005, 15))
    t = t_of(0.28)
    save("kill", mix((np.sin(2 * np.pi * 880 * t) + np.sin(2 * np.pi * 1320 * t) * 0.5) * env(0.28, 0.0005, 13), np.concatenate([np.zeros(int(SR * 0.07)), np.sin(2 * np.pi * 1320 * t) * env(0.28, 0.0005, 13)])))
    save("spawn", mix(sweep(120, 900, 0.6, 0.7, "saw") * env(0.6, 0.04, 5) * 0.35, sweep(240, 1800, 0.6, 0.7) * env(0.6, 0.04, 5) * 0.3))


def ui():
    save("ui_hover", sweep(1500, 1700, 0.05) * env(0.05, 0.001, 70), 0.4)
    save("ui_click", mix(sweep(1000, 620, 0.09) * env(0.09, 0.001, 45), highpass(noise(0.02), 3000) * env(0.02, 0.0005, 150) * 0.3), 0.6)
    t = t_of(0.8)
    chord = sum(np.sin(2 * np.pi * f * t) for f in (220, 277.2, 329.6, 440))
    save("ui_deploy", mix(chord * env(0.8, 0.01, 5) * 0.4, sweep(100, 1400, 0.4, 0.6, "saw") * env(0.4, 0.03, 8) * 0.25))
    t = t_of(0.75)
    save("flag_captured", mix(*[np.concatenate([np.zeros(int(SR * 0.12 * i)), np.sin(2 * np.pi * f * t) * env(0.75, 0.002, 6)]) for i, f in enumerate((440, 554.4, 659.3, 880))]))
    save("flag_lost", mix(*[np.concatenate([np.zeros(int(SR * 0.14 * i)), (np.sign(np.sin(2 * np.pi * f * t)) * 0.3 + np.sin(2 * np.pi * f * t)) * env(0.75, 0.002, 6)]) for i, f in enumerate((392, 311.1, 233.1))]))
    t = t_of(0.12)
    save("capture_tick", np.sin(2 * np.pi * 980 * t) * env(0.12, 0.001, 40), 0.4)


def footsteps():
    """A boot on broken ground: heel, then grit shifting under the sole."""
    for i in range(3):
        d = 0.22
        n = int(SR * d)
        heel = sweep(150 - i * 14, 68, d, 2.6) * env(d, 0.002, 44) * 0.42
        knock = lowpass(noise(d), 620 + i * 130 + np.zeros(n)) * env(d, 0.001, 58)
        grit = np.zeros(n)
        for _ in range(16):
            dd = 0.012
            grain = lowpass(highpass(noise(dd), 700), 2600 + np.zeros(int(SR * dd))) * env(dd, 0.0005, 320)
            pos = int(SR * rng.uniform(0.012, 0.13))
            grit[pos:pos + len(grain)] += grain * rng.uniform(0.2, 0.7)
        save(f"step{i + 1}", lowpass(mix(heel, knock * 0.8, grit * 2.6), 4200 + np.zeros(n)), 0.7)


def ambience():
    """A city under fire, far away. The air stays level on purpose: noise that swells and
    falls slowly is heard as surf."""
    d = 32.0
    n = int(SR * d)
    out = lowpass(highpass(noise(d), 170), 820 + np.zeros(n)) * 0.045

    def place(x, pos):
        # Wraps round the end, so nothing is cut off where the loop restarts.
        idx = (pos + np.arange(len(x))) % n
        np.add.at(out, idx, x)

    # Artillery: a quick thump, then a long low roll off the buildings.
    for i in range(9):
        dd = rng.uniform(2.2, 3.6)
        m = int(SR * dd)
        crump = lowpass(noise(dd), 150 + np.zeros(m)) * env(dd, 0.006, 3.0) * rng.uniform(1.6, 3.4)
        sub = sweep(68, 30, dd, 2.2) * env(dd, 0.006, 3.4) * rng.uniform(0.2, 0.45)
        place(crump + sub, int(n * (i + rng.uniform(0.1, 0.9)) / 9))
    # Bursts of far-off blasters, dulled by distance.
    for _ in range(16):
        dd = 0.16
        shot = lowpass(sweep(rng.uniform(700, 1100), 170, dd, 2.6) * env(dd, 0.004, 24), 620 + np.zeros(int(SR * dd)))
        pos = int(rng.integers(0, n))
        level = rng.uniform(0.02, 0.07)
        for k in range(int(rng.integers(3, 8))):
            place(shot * level * rng.uniform(0.7, 1.1), pos + k * int(SR * rng.uniform(0.11, 0.17)))
    # A nearby fire: sparse dry cracks.
    for _ in range(90):
        dd = 0.02
        crack = lowpass(highpass(noise(dd), 900), 3000 + np.zeros(int(SR * dd))) * env(dd, 0.0006, 240)
        place(crack * rng.uniform(0.01, 0.05), int(rng.integers(0, n)))
    # One air-raid siren across the river, barely there.
    dd = 11.0
    tt = t_of(dd)
    pitch = 240 + 150 * np.sin(np.pi * tt / dd) ** 2
    siren = np.sin(np.cumsum(pitch) / SR * 2 * np.pi) * np.sin(np.pi * tt / dd) ** 2
    place(lowpass(siren, 700 + np.zeros(len(siren))) * 0.035, int(n * 0.55))
    save("ambient_battle", out, 0.7, fade=False)


def music():
    bpm = 60.0
    beat = 60.0 / bpm
    bars = 16
    d = bars * 4 * beat
    n = int(SR * d)
    t = t_of(d)
    out = np.zeros(n)
    # A sombre minor progression: Dm, Bb, Gm, A.
    roots = [73.42, 58.27, 49.0, 55.0]
    thirds = [1.1892, 1.2599, 1.1892, 1.2599]
    bar_len = int(SR * 4 * beat)
    for b in range(bars):
        idx = (b // 2) % 4
        r = roots[idx]
        seg_len = bar_len * 2 if b % 2 == 0 else 0
        if seg_len == 0:
            continue
        tt = np.arange(seg_len) / SR
        pad = np.zeros(seg_len)
        for mult, amp in ((1, 1.0), (thirds[idx], 0.5), (1.4983, 0.6), (2, 0.5), (2 * thirds[idx], 0.25), (3, 0.14)):
            for det in (0.997, 1.0, 1.003):
                pad += amp * np.sin(2 * np.pi * r * mult * det * tt + rng.uniform(0, 6))
        e = np.minimum(tt / 1.6, 1) * np.minimum((seg_len / SR - tt) / 1.6, 1)
        start = b * bar_len
        end = min(start + seg_len, n)
        out[start:end] += (pad * e)[: end - start] * 0.05
    # Slow war drum on beats 1 and 3, with a soft pickup.
    for i in range(bars * 4):
        if i % 4 in (0, 2) or (i % 16 == 15):
            dd = 1.2
            k = sweep(95, 42, dd, 3) * env(dd, 0.002, 4.5)
            nz = lowpass(noise(0.1), 500 + np.zeros(int(SR * 0.1))) * env(0.1, 0.001, 32) * 0.5
            hit = mix(k, nz) * (0.5 if i % 4 else 0.62)
            p = int(i * beat * SR)
            e = min(p + len(hit), n)
            out[p:e] += hit[: e - p]
    # A lonely minor-key melody in the second half.
    melody = [(32, 293.7, 3), (35, 349.2, 1), (36, 329.6, 3), (39, 293.7, 1), (40, 277.2, 4), (44, 293.7, 3), (47, 220.0, 1),
              (48, 233.1, 3), (51, 261.6, 1), (52, 293.7, 4), (56, 349.2, 3), (59, 329.6, 1), (60, 293.7, 4)]
    for beat_i, f, ln in melody:
        dd = ln * beat + 1.2
        tt = t_of(dd)
        vib = np.sin(2 * np.pi * 5 * tt) * 0.004 * np.minimum(tt, 1)
        ph = np.cumsum(f * (1 + vib)) / SR * 2 * np.pi
        tone = np.sin(ph) + 0.4 * np.sin(ph * 2) + 0.18 * np.sin(ph * 3)
        e = np.minimum(tt / 0.18, 1) * np.minimum((dd - tt) / 0.9, 1)
        p = int(beat_i * beat * SR)
        end = min(p + len(tone), n)
        out[p:end] += (tone * e)[: end - p] * 0.07
    save("menu_music", echo(out, 0.42, 0.28, 3)[:n], 0.75)


def supers():
    t = t_of(0.7)
    save("coin_spawn", mix(*[np.concatenate([np.zeros(int(SR * 0.09 * i)), np.sin(2 * np.pi * f * t) * env(0.7, 0.002, 7)]) for i, f in enumerate((1318.5, 1760, 2093, 2637))]), 0.7)
    t = t_of(0.45)
    save("coin_pickup", mix(np.sin(2 * np.pi * 1760 * t) * env(0.45, 0.001, 10), np.concatenate([np.zeros(int(SR * 0.08)), np.sin(2 * np.pi * 2637 * t) * env(0.45, 0.001, 9)])), 0.8)
    d = 1.3
    rise = sweep(70, 900, d, 0.6, "saw") * env(d, 0.05, 2.6) * 0.5
    hit = lowpass(noise(0.6), 300 + np.zeros(int(SR * 0.6))) * env(0.6, 0.002, 7) * 2.2
    save("transform", mix(rise, np.concatenate([np.zeros(int(SR * 0.5)), hit])))
    d = 0.5
    thud = lowpass(noise(d), 130 + np.zeros(int(SR * d))) * env(d, 0.002, 11) * 3.0
    clank = sum(np.sin(2 * np.pi * f * t_of(0.16)) for f in (410, 655, 980)) * env(0.16, 0.001, 30) * 0.3
    save("mech_step", mix(thud, sweep(70, 34, d, 2) * env(d, 0.002, 9) * 1.4, clank))
    d = 0.34
    save("jet", lowpass(noise(d), 1400 + np.zeros(int(SR * d))) * np.sin(np.pi * t_of(d) / d) ** 0.5)


def maglev():
    """A long electric rush, swelling as it passes overhead."""
    d = 9.0
    t = t_of(d)
    swell = np.sin(np.pi * t / d) ** 2
    air = lowpass(noise(d), 500 + 900 * swell) * swell * 1.4
    hum = (np.sin(2 * np.pi * 96 * t) + 0.4 * np.sin(2 * np.pi * 192 * t)) * swell * 0.22
    save("maglev", air + hum, 0.8)


def vehicles():
    d = 1.0
    t = t_of(d)
    hum = sum(a * np.sin(2 * np.pi * f * t + 2 * np.sin(2 * np.pi * 7 * t)) for f, a in ((58, 1.0), (116, 0.6), (174, 0.3), (233, 0.15)))
    air = lowpass(noise(d), 500 + np.zeros(int(SR * d))) * 0.5
    n = int(SR * 0.05)
    x = mix(hum, air)
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    save("tank_hum", x, 0.6)


if __name__ == "__main__":
    impacts()
    ui()
    ambience()
    music()
    supers()
    vehicles()
