"""Synthesises every gunshot twice: close-up for the shooter, muffled for everyone else.

The sound is a physical model, not a sample: a steel wire struck by a hammer. Bending waves in a
stiff wire are dispersive, so the highest frequencies arrive first and the pitch falls as 1/t^2.
Each reflection off the wire's ends arrives later and more smeared, which gives the "pyew-ew" tail.

Output: own_<sound>_N.wav (stereo, played flat by the shooter) and <sound>_N.wav (mono, played in
the world). Run with a Python that has numpy:  python tools/gen_audio_blaster.py
"""
import os
import wave

import numpy as np

from gen_audio import OUT, SR

rng = np.random.default_rng(1138)


def spectrum_axis(n):
    return np.fft.rfftfreq(n, 1 / SR)


def shaped(x, gain):
    """Applies a magnitude curve in the frequency domain, padded so nothing wraps round."""
    n = 1 << (len(x) * 2 - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, n) * gain(spectrum_axis(n)), n)[: len(x)]


def low_cut(f, fc, order=4):
    r = (np.maximum(f, 1e-3) / fc) ** order
    return r / (1 + r)


def high_cut(f, fc, order=4):
    return 1 / (1 + (f / fc) ** order)


def wire(sweep, hi, lo, d, echoes=0.34, damping=7.0):
    """One struck wire. `sweep` is the delay at `hi`; the fall to `lo` takes a few times longer."""
    n = 1 << (int(SR * max(d, sweep * 14)) * 2).bit_length()
    f = spectrum_axis(n)
    safe = np.maximum(f, lo * 0.25)
    # When each frequency arrives after the first wavefront, and the phase that delay needs.
    arrival = sweep * (np.sqrt(hi / safe) - 1)
    phase = 2 * np.pi * sweep * (2 * np.sqrt(hi * safe) - safe)
    band = low_cut(f, lo, 6) * high_cut(f, hi, 4)
    # Repeated shots hurt around 3.5 kHz, so that part of the sweep is held back a little.
    band = band * (1 - 0.3 * np.exp(-((np.log2(safe / 3500.0)) ** 2) / 0.5))
    out = np.zeros(len(f), dtype=complex)
    for k in range(4):
        trip = 2 * k + 1
        late = arrival * trip + 2 * k * sweep
        out += echoes ** k * band * np.exp(-late * damping) * np.exp(-1j * (phase * trip - 2 * np.pi * f * 2 * k * sweep))
    x = np.fft.irfft(out, n)[: int(SR * d)]
    return x / (np.max(np.abs(x)) or 1.0)


def thump(d, top, bottom, decay):
    t = np.arange(int(SR * d)) / SR
    pitch = bottom + (top - bottom) * np.exp(-t / 0.018)
    return np.sin(np.cumsum(pitch) / SR * 2 * np.pi) * np.minimum(t / 0.002, 1) * np.exp(-t * decay)


def tick(d):
    """The hammer landing on the wire: a few milliseconds that make the shot feel instant."""
    x = np.zeros(int(SR * d))
    m = int(SR * 0.004)
    x[:m] = rng.normal(size=m) * np.exp(-np.arange(m) / SR * 1400)
    return shaped(x, lambda f: low_cut(f, 1800, 2) * high_cut(f, 7500, 2))


def room(x, wet, length=0.4, dark=2600.0):
    n = int(SR * length)
    ir = shaped(rng.normal(size=n), lambda f: high_cut(f, dark, 2)) * np.exp(-np.arange(n) / SR * (7 / length))
    ir /= np.sqrt(np.sum(ir ** 2)) or 1.0
    size = 1 << (len(x) + n).bit_length()
    tail = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]
    return x + tail * wet


def strands(s, d, spread):
    """The main wire and a neighbour that beats against it. `spread` detunes one ear from the other."""
    sweep = s["sweep"] * (1 + spread)
    x = np.zeros(int(SR * d))
    for lag in s.get("burst", (0.0,)):
        hit = wire(sweep, s["hi"], s["lo"], d, s["echoes"]) + 0.5 * wire(sweep * 1.09, s["hi"] * 0.82, s["lo"] * 1.12, d, s["echoes"])
        x += np.roll(hit, int(SR * lag)) * (0.75 if lag else 1.0)
    return x / (np.max(np.abs(x)) or 1.0)


def closing(x, ms=25):
    n = min(int(SR * ms / 1000), len(x))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n) ** 2
    return x


def shot(spec):
    take = dict(spec)
    take["sweep"] = spec["sweep"] * rng.uniform(0.95, 1.05)
    take["hi"] = spec["hi"] * rng.uniform(0.96, 1.04)
    d = spec["d"]
    left = strands(take, d, -0.012)
    right = np.roll(strands(take, d, 0.012), int(SR * 0.0003))
    weight = thump(d, spec.get("top", 150.0), spec.get("bottom", 52.0), spec.get("thud", 24.0)) * spec["body"]
    if "boom" in spec:
        rumble = shaped(rng.normal(size=int(SR * d)), lambda f: high_cut(f, 260, 2)) * np.exp(-np.arange(int(SR * d)) / SR * 3.6)
        weight = weight + rumble / (np.max(np.abs(rumble)) or 1.0) * spec["boom"]
    snap = tick(d) * spec.get("snap", 0.5)
    drive = spec.get("drive", 1.25)
    # Only the wire is driven: saturating it together with the thump would smear the clean sweep.
    own = [closing(room(np.tanh(ear * drive) + weight * 0.6 + snap, spec["room"])) for ear in (left, right)]

    # Someone else's shot: one source, no hammer, no chest thump, and the top of the sweep gone.
    far = (left + right) * 0.5 + weight * 0.35
    muffled = lambda f: low_cut(f, 110, 2) * high_cut(f, spec.get("muffle", 2300.0), 4)
    far = shaped(far, muffled)
    t = np.arange(len(far)) / SR
    far = np.tanh(far / (np.max(np.abs(far)) or 1.0) * 1.1) * np.minimum(t / 0.007, 1)
    # Filtered again, because the saturation above grows new harmonics over the cut-off.
    far = closing(room(shaped(far, muffled), spec["room"] * 1.8 + 0.12, dark=1100.0))
    return np.stack(own, axis=1), far


def peak_to(x, gain):
    return x / (np.max(np.abs(x)) or 1.0) * gain


def attack_level(x):
    """Loudness of the first 150 ms, which is what a listener compares two shots by."""
    return np.sqrt(np.mean(x[: int(SR * 0.15)] ** 2))


def write(name, x):
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1 if x.ndim == 1 else x.shape[1])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


# gain: peak level of the shooter's copy. Fast guns sit lower, because they repeat.
SHOTS = {
    "laser_pistol": dict(sweep=0.034, hi=4200, lo=250, d=0.4, echoes=0.3, body=0.7, room=0.16, drive=1.4, gain=0.84),
    "laser_rifle": dict(sweep=0.042, hi=3800, lo=200, d=0.46, echoes=0.32, body=0.9, room=0.18, drive=1.4, gain=0.84),
    "laser_assault": dict(sweep=0.046, hi=3400, lo=170, d=0.46, echoes=0.32, body=1.05, room=0.18, drive=1.45, gain=0.78),
    "laser_smg": dict(sweep=0.026, hi=3800, lo=280, d=0.28, echoes=0.22, body=0.62, room=0.12, drive=1.4, gain=0.72),
    "laser_marksman": dict(sweep=0.06, hi=3800, lo=150, d=0.68, echoes=0.4, body=1.1, room=0.24, drive=1.4, gain=0.88),
    "laser_revolver": dict(sweep=0.055, hi=3200, lo=130, d=0.68, echoes=0.38, body=1.3, room=0.24, drive=1.5, gain=0.9),
    "laser_heavy": dict(sweep=0.04, hi=3000, lo=170, d=0.38, echoes=0.3, body=1.0, room=0.16, drive=1.4, gain=0.7, muffle=1800.0),
    "laser_plasma": dict(sweep=0.066, hi=1900, lo=62, d=0.8, echoes=0.38, body=2.3, boom=1.5, room=0.26, drive=1.95, gain=1.0, thud=12.0, top=120.0, bottom=38.0, muffle=1600.0),
    "laser_minigun": dict(sweep=0.03, hi=2500, lo=95, d=0.24, echoes=0.2, body=1.5, boom=0.5, room=0.12, drive=1.8, gain=0.92, thud=16.0, top=135.0, bottom=46.0, muffle=1700.0),
    "mech_launcher": dict(sweep=0.05, hi=1100, lo=50, d=0.9, echoes=0.32, body=1.9, boom=1.4, room=0.26, drive=1.6, gain=0.92, thud=8.0, top=105.0, bottom=36.0, muffle=1300.0),
    "laser_scatter": dict(sweep=0.04, hi=3600, lo=170, d=0.54, echoes=0.3, body=1.1, room=0.22, drive=1.5, gain=0.88, burst=(0.0, 0.006, 0.013, 0.021), muffle=1100.0),
    "laser_sniper": dict(sweep=0.085, hi=4800, lo=110, d=1.28, echoes=0.46, body=1.75, boom=0.7, room=0.36, drive=1.6, gain=0.98, thud=11.0, top=125.0, bottom=40.0),
    "laser_rail": dict(sweep=0.11, hi=5600, lo=90, d=1.55, echoes=0.5, body=1.4, room=0.4, drive=1.5, gain=0.94, thud=11.0, top=120.0, bottom=38.0),
    "laser_suppressed": dict(sweep=0.03, hi=2800, lo=230, d=0.34, echoes=0.2, body=0.75, room=0.09, snap=0.25, drive=1.35, gain=0.82, muffle=1300.0),
    "mech_cannon": dict(sweep=0.075, hi=2000, lo=70, d=0.85, echoes=0.4, body=1.6, room=0.3, drive=1.6, gain=0.92, thud=9.0, top=110.0, bottom=34.0, muffle=900.0),
    "tank_fire": dict(sweep=0.1, hi=1800, lo=45, d=1.7, echoes=0.42, body=1.6, boom=1.8, room=0.32, drive=1.5, gain=0.95, thud=5.0, top=95.0, bottom=30.0, muffle=700.0, takes=2),
}
## Nearby shots are clear enough to place by ear, but well below the shooter's own.
WORLD_DROP_DB = 2.0
WORLD_PEAK = 0.8


def main():
    for name, spec in SHOTS.items():
        for i in range(spec.get("takes", 3)):
            own, far = shot(spec)
            own = peak_to(own, spec["gain"])
            far = far * attack_level(own) / (attack_level(far) or 1.0) * 10 ** (-WORLD_DROP_DB / 20)
            write(f"own_{name}_{i + 1}", own)
            write(f"{name}_{i + 1}", peak_to(far, WORLD_PEAK) if np.max(np.abs(far)) > WORLD_PEAK else far)


if __name__ == "__main__":
    main()
