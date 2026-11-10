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


# ---------------------------------------------------------------- the energy shield

def tail(x, seconds, wet, dark):
    """Reverb for a one-shot: room is made for the tail, so nothing wraps back onto the attack."""
    padded = np.concatenate([x, np.zeros(int(SR * seconds * 1.2))])
    return reverb(padded, seconds, wet, dark)


def _crackle(d, density=0.5, decay=20.0, lo=2500.0):
    """Electric sizzle: short bursts of bright noise that switch on and off at random."""
    n = int(SR * d)
    t = t_of(d)
    gate = (rng.random(n // 64 + 1) < density).repeat(64)[:n].astype(float)
    gate = np.convolve(gate, np.ones(32) / 32, mode="same")
    return highpass(rng.normal(0, 1, n), lo) * gate * np.exp(-t * decay)


def _ring(f, d, decay, wobble=0.0, drop=0.0):
    """A struck tone with a slight downward bend: the field itself ringing where it was hit."""
    t = t_of(d)
    pitch = f * (1 - drop * (1 - np.exp(-t * 12))) * (1 + wobble * np.sin(2 * np.pi * 31 * t) * np.exp(-t * 8))
    return np.sin(2 * np.pi * np.cumsum(pitch) / SR) * np.exp(-t * decay)


def shield_hit(variant):
    """A shot stopped by the shield: a soft heavy thump into the field, the field ringing like a
    struck pane, and a crackle of discharge. Felt more than heard, so it never tires the ear."""
    d = 0.42
    t = t_of(d)
    f = (640.0, 760.0, 880.0)[variant]
    thump = np.sin(2 * np.pi * np.cumsum(95 * np.exp(-t * 6) + 48) / SR) * np.exp(-t * 16)
    body = lowpass(rng.normal(0, 1, len(t)), 700) * np.exp(-t * 40) * 0.6
    ring = _ring(f, d, 9.0, 0.012, 0.06) * 0.42 + _ring(f * 1.51, d, 14.0, 0.02, 0.05) * 0.22 + _ring(f * 2.76, d, 22.0) * 0.1
    click = highpass(rng.normal(0, 1, len(t)), 4000) * np.exp(-t * 500) * 0.5
    sizzle = _crackle(d, 0.45, 14.0) * 0.18
    x = thump * 0.9 + body + ring + click + sizzle
    save(f"shield_hit_{variant + 1}", tail(x, 0.5, 0.18, 4000.0), 0.85)


def shield_on():
    """Drawing the shield: a rising charge, a bright shimmer as the plate forms, then it locks."""
    d = 0.75
    t = t_of(d)
    rise = 110 + 520 * (t / d) ** 1.6
    charge = np.sin(2 * np.pi * np.cumsum(rise) / SR) + 0.5 * np.sin(4 * np.pi * np.cumsum(rise) / SR * 1.003)
    env = np.minimum(t / 0.05, 1) * np.where(t < 0.45, 1.0, np.exp(-(t - 0.45) * 9))
    shimmer = band(rng.normal(0, 1, len(t)), 3000, 9000) * np.sin(np.pi * np.clip(t / 0.5, 0, 1)) ** 2 * 0.15
    lock = np.zeros(len(t))
    k = int(0.42 * SR)
    lt = t_of(0.3)
    lock[k:k + len(lt)] = (np.sin(2 * np.pi * 70 * lt) * np.exp(-lt * 18) + _ring(1320, 0.3, 16) * 0.3)[: len(t) - k]
    x = lowpass(charge * env, 2600) * 0.45 + shimmer + lock * 0.7
    save("shield_on", tail(x, 0.6, 0.2, 4500.0), 0.8)


def shield_off():
    """Putting the shield away: the field drains down in pitch and the emitter clicks off."""
    d = 0.55
    t = t_of(d)
    fall = 520 * np.exp(-t * 5) + 70
    drain = np.sin(2 * np.pi * np.cumsum(fall) / SR) * np.exp(-t * 5)
    x = lowpass(drain, 2200) * 0.5 + _crackle(d, 0.3, 9.0) * 0.12
    x[:200] += np.linspace(0.3, 0, 200)
    save("shield_off", tail(x, 0.5, 0.18, 4000.0), 0.7)


def shield_break():
    """The shield gives way: a heavy blow, the plate shattering into glassy splinters of light, and a
    long discharge whining down."""
    d = 1.3
    t = t_of(d)
    blow = np.sin(2 * np.pi * np.cumsum(140 * np.exp(-t * 8) + 40) / SR) * np.exp(-t * 7) * 1.2
    blow += lowpass(rng.normal(0, 1, len(t)), 500) * np.exp(-t * 14) * 0.8
    shards = np.zeros(len(t))
    for _ in range(46):
        at = int(abs(rng.normal(0.03, 0.12)) * SR)
        dd = rng.uniform(0.04, 0.25)
        piece = _ring(rng.uniform(2200, 7000), dd, rng.uniform(25, 60)) * rng.uniform(0.05, 0.16)
        end = min(at + len(piece), len(t))
        shards[at:end] += piece[: end - at]
    whine = np.sin(2 * np.pi * np.cumsum(900 * np.exp(-t * 2.2) + 60) / SR) * np.exp(-t * 2.6) * 0.3
    x = blow + shards + lowpass(whine, 3000) + _crackle(d, 0.55, 3.5) * 0.25
    save("shield_break", tail(x, 1.2, 0.25, 5000.0), 0.9)


def deflect(variant):
    """A laser bolt turned aside by a blade: a bright, short zing that flies off, not a clang."""
    d = 0.32
    t = t_of(d)
    f = (1900.0, 2300.0)[variant]
    zing = np.sin(2 * np.pi * np.cumsum(f * (1 + 0.35 * np.exp(-t * 30)) * (1 - 0.25 * t / d)) / SR) * np.exp(-t * 16)
    sub = np.sin(2 * np.pi * np.cumsum(260 * np.exp(-t * 10) + 120) / SR) * np.exp(-t * 22) * 0.6
    snap = highpass(rng.normal(0, 1, len(t)), 3000) * np.exp(-t * 160) * 0.6
    x = zing * 0.5 + sub + snap + _crackle(d, 0.4, 24.0) * 0.12
    save(f"deflect_{variant + 1}", tail(x, 0.45, 0.16, 6000.0), 0.8)


def shield_sounds():
    for i in range(3):
        shield_hit(i)
    shield_on()
    shield_off()
    shield_break()
    for i in range(2):
        deflect(i)


if __name__ == "__main__":
    import sys
    if "--shield" in sys.argv:
        shield_sounds()
    else:
        music()
        ambience()
        shield_sounds()
