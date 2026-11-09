"""Corp Wars: the menu music and the sound of Corp City at night.

Run with a Python that has numpy (Blender's own will do):
    python tools/gen_audio_corp.py
Writes assets/audio/menu_music.wav and assets/audio/ambient_neon.wav.

The music is the machines' world, not the rebels': a sub drone that never resolves, a pad built on
a minor second, a sequencer ticking like a clock in an empty office, and a heavy brass-like blast
every eight bars. Everything filtered and reverberated with FFTs, so it builds in seconds.
"""
import os
import wave

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
SR = 44100
rng = np.random.default_rng(2087)


def t_of(d):
    return np.arange(int(SR * d)) / SR


def place(out, x, at):
    """Adds `x` into `out` from sample `at`, wrapping round the end so the loop has no seam."""
    idx = (at + np.arange(len(x))) % len(out)
    np.add.at(out, idx, x)


def spectral(x, response):
    """Filters with a frequency response given as a function of Hz."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(spec * response(f), len(x))


def lowpass(x, fc, order=2):
    return spectral(x, lambda f: 1 / np.sqrt(1 + (f / fc) ** (2 * order)))


def highpass(x, fc, order=2):
    return spectral(x, lambda f: 1 / np.sqrt(1 + (fc / np.maximum(f, 1e-3)) ** (2 * order)))


def band(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def sweep_lowpass(x, fcs, block=4096):
    """A filter that opens and closes: blocks with overlap, each its own cut-off."""
    out = np.zeros(len(x) + block)
    win = np.hanning(block * 2)
    hop = block
    for i, start in enumerate(range(0, len(x), hop)):
        seg = x[start:start + block * 2]
        if len(seg) < 8:
            break
        fc = fcs[min(start + len(seg) // 2, len(fcs) - 1)]
        seg = lowpass(np.pad(seg, (0, block * 2 - len(seg))), fc) * win
        out[start:start + block * 2] += seg[: len(out) - start]
    return out[: len(x)]


def reverb(x, seconds=3.2, wet=0.35, dark=3000.0):
    """Convolution with a decaying, darkened noise tail: a large empty hall."""
    n = int(SR * seconds)
    ir = rng.normal(0, 1, n) * np.exp(-np.arange(n) / SR * (6.9 / seconds))
    ir = lowpass(ir, dark)
    ir /= np.sqrt(np.sum(ir ** 2))
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    tail = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    # Fold the tail that runs past the end back to the start, so the loop is seamless.
    wetted = tail[: len(x)].copy()
    wetted[: n] += tail[len(x): len(x) + n][: len(wetted)]
    return x * (1 - wet) + wetted * wet * 2.2


def saw(f, t, detune=0.0):
    ph = (f * (1 + detune) * t + rng.uniform(0, 1)) % 1
    return 2 * ph - 1


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) or 1.0) * gain
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print("audio", name, round(len(x) / SR, 1), "s", flush=True)


# ---------------------------------------------------------------- music

def music():
    bpm = 76.0
    beat = 60.0 / bpm
    bars = 24
    d = bars * 4 * beat
    n = int(SR * d)
    t = t_of(d)
    out = np.zeros(n)
    D1, D2 = 36.71, 73.42

    # The floor: a sub drone on D with a fifth that slowly beats against itself.
    drone = np.sin(2 * np.pi * D1 * t) * 0.9 + np.sin(2 * np.pi * D1 * 1.4983 * t * 1.0007) * 0.35 + np.sin(2 * np.pi * D2 * t) * 0.3
    swell = 0.7 + 0.3 * np.sin(2 * np.pi * t / d * 2) ** 2
    out += drone * swell * 0.22

    # The pad: D, E flat and A at once. The minor second never resolves.
    pad = np.zeros(n)
    for f, amp in ((146.83, 1.0), (155.56, 0.7), (220.0, 0.6), (293.66, 0.35), (311.13, 0.25)):
        for det in (-0.004, 0.0, 0.0045):
            pad += saw(f, t, det) * amp
    opening = 380 + 1400 * (0.5 - 0.5 * np.cos(2 * np.pi * t / (d / 3)))
    pad = sweep_lowpass(pad, opening)
    out += pad * 0.035

    # The machine's pulse: a filtered square arpeggio in D phrygian, sixteenths, from bar 5.
    notes = [146.83, 155.56, 220.0, 155.56, 146.83, 174.61, 220.0, 233.08]
    step = beat / 4
    for i in range(int(bars * 16)):
        bar = i // 16
        if bar < 4 or (bar >= 20 and i % 2):
            continue
        f = notes[i % len(notes)] * (2 if (i // 64) % 2 else 1)
        dd = step * 0.9
        tt = t_of(dd)
        tone = np.sign(np.sin(2 * np.pi * f * tt)) * np.exp(-tt * 18)
        accent = 1.0 if i % 4 == 0 else 0.55
        place(out, lowpass(tone, 900 + 300 * (bar % 4)) * 0.05 * accent, int(i * step * SR))

    # A clock: a dry tick on every beat, the sound of an office nobody works in any more.
    for i in range(bars * 4):
        dd = 0.03
        tick = highpass(rng.normal(0, 1, int(SR * dd)), 3500) * np.exp(-t_of(dd) * 260)
        place(out, tick * (0.05 if i % 2 else 0.08), int(i * beat * SR))

    # The blast: a stack of detuned saws on D, dirty and enormous, once every eight bars.
    for bar in (0, 8, 16):
        dd = 6.0
        tt = t_of(dd)
        stack = np.zeros(len(tt))
        for f in (D2, D2 * 2, D2 * 1.4983, D2 * 0.5):
            for det in (-0.006, 0.0, 0.006):
                stack += saw(f, tt, det)
        stack = np.tanh(stack * 0.8)
        env = np.minimum(tt / 0.08, 1) * np.exp(-tt * 0.7)
        stack = sweep_lowpass(stack * env, 200 + 2200 * np.exp(-tt * 1.4))
        place(out, stack * 0.16, int(bar * 4 * beat * SR))
    # Heavy impacts under the blasts and halfway between them.
    for bar in (0, 4, 8, 12, 16, 20):
        dd = 2.5
        tt = t_of(dd)
        kick = np.sin(2 * np.pi * np.cumsum(30 + 90 * np.exp(-tt * 9)) / SR) * np.exp(-tt * 2.2)
        thud = lowpass(rng.normal(0, 1, len(tt)), 260) * np.exp(-tt * 9) * 0.6
        place(out, (kick + thud) * 0.5, int(bar * 4 * beat * SR))

    # Notification bells, cold and spaced out: the system talking to itself.
    for bar, f in ((6, 1174.7), (10, 1244.5), (14, 880.0), (18, 1174.7), (22, 1318.5)):
        dd = 3.0
        tt = t_of(dd)
        mod = np.sin(2 * np.pi * f * 1.41 * tt) * 2.2 * np.exp(-tt * 3)
        bell = np.sin(2 * np.pi * f * tt + mod) * np.exp(-tt * 1.6)
        place(out, bell * 0.05, int((bar * 4 + 2) * beat * SR))

    out = reverb(out, 3.6, 0.32, 2600.0)
    out += np.sin(2 * np.pi * D1 * t) * 0.05
    save("menu_music", out, 0.8)


# ---------------------------------------------------------------- the city at night

def ambience():
    """Corp City after the rain: wet tyres far off, neon buzzing, drips from the ledges, drones
    passing over and a public address chime now and then. No rain and no thunder."""
    d = 36.0
    n = int(SR * d)
    t = t_of(d)
    out = band(rng.normal(0, 1, n), 120, 900) * 0.05
    # The city's hum: mains and the transformers in every tower.
    out += (np.sin(2 * np.pi * 50 * t) * 0.03 + np.sin(2 * np.pi * 100 * t) * 0.02 + np.sin(2 * np.pi * 150 * t) * 0.008) * (0.8 + 0.2 * np.sin(2 * np.pi * t / 9))
    # Traffic on the wet avenues: slow swells of tyre hiss.
    for _ in range(14):
        dd = rng.uniform(3.0, 6.0)
        tt = t_of(dd)
        hiss = band(rng.normal(0, 1, len(tt)), 600, 4500) * np.sin(np.pi * tt / dd) ** 2
        place(out, hiss * rng.uniform(0.03, 0.07), int(rng.integers(0, n)))
    # Neon tubes buzzing close by, fading in and out as if the listener turned.
    buzz = np.sign(np.sin(2 * np.pi * 100 * t)) * 0.5 + np.sin(2 * np.pi * 200 * t)
    out += highpass(buzz, 900) * 0.006 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 13) ** 2)
    # Water dripping from the ledges.
    for _ in range(120):
        dd = 0.06
        tt = t_of(dd)
        f = rng.uniform(900, 2200)
        drip = np.sin(2 * np.pi * np.cumsum(f * (1 + 0.6 * np.exp(-tt * 60))) / SR) * np.exp(-tt * 70)
        place(out, drip * rng.uniform(0.01, 0.035), int(rng.integers(0, n)))
    # Drones passing over: a whine that rises and falls with a little Doppler.
    for _ in range(3):
        dd = 7.0
        tt = t_of(dd)
        pitch = 420 * (1 + 0.05 * np.tanh((dd / 2 - tt) * 0.8))
        whine = np.sin(2 * np.pi * np.cumsum(pitch) / SR) + 0.4 * np.sin(4 * np.pi * np.cumsum(pitch) / SR)
        place(out, lowpass(whine * np.sin(np.pi * tt / dd) ** 3, 1800) * 0.03, int(rng.integers(0, n)))
    # The public address: three falling chimes far down the street.
    for at in (0.3, 0.75):
        for k, f in enumerate((987.8, 784.0, 659.3)):
            dd = 1.6
            tt = t_of(dd)
            chime = np.sin(2 * np.pi * f * tt) * np.exp(-tt * 3) + 0.3 * np.sin(4 * np.pi * f * tt) * np.exp(-tt * 5)
            place(out, lowpass(chime, 2500) * 0.025, int(n * at) + int(k * 0.42 * SR))
    out = reverb(out, 2.4, 0.3, 3500.0)
    save("ambient_neon", out, 0.7)


if __name__ == "__main__":
    music()
    ambience()
