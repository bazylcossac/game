"""Synthesises the sounds of the bomb mode: arming, ticking, defusing and the round horn.

Run with a Python that has numpy:  python tools/gen_audio_modes.py
"""
import numpy as np

from gen_audio import SR, env, highpass, lowpass, mix, noise, save, t_of


def artillery():
    """Incoming shells, an order over the radio, and a beacon being set down."""
    d = 6.0
    t = t_of(d)
    pitch = 2300 * np.exp(-t / 3.4) + 420
    whistle = np.sin(np.cumsum(pitch) / SR * 2 * np.pi) * np.minimum(t / 1.6, 1) * np.minimum((d - t) / 0.08, 1)
    air = highpass(noise(d), 1200) * 0.05 * np.minimum(t / 2.0, 1)
    save("artillery_whistle", mix(whistle * 0.5, air), 0.8)
    d = 0.9
    t = t_of(d)
    gate = (np.sin(2 * np.pi * 7.3 * t) > -0.4).astype(float)
    voice = lowpass(highpass(noise(d) + np.sin(2 * np.pi * 900 * t) * 0.5, 500), 2400) * gate * np.minimum(t / 0.02, 1) * np.minimum((d - t) / 0.04, 1)
    beep_a = np.sin(2 * np.pi * 1300 * t) * (t < 0.08) * 0.5
    save("radio_call", mix(voice * 0.7, beep_a), 0.7)
    d = 0.5
    clunk = lowpass(noise(d), 900) * env(d, 0.001, 22.0)
    hum = np.sin(2 * np.pi * 620 * t_of(d)) * env(d, 0.08, 6.0) * 0.3
    save("beacon_place", mix(clunk, hum), 0.75)


def machines():
    """What the Empire's droids sound like when hit: servos, metal and a dying whine."""
    for i, (start, end) in enumerate(((900, 240), (720, 180), (1100, 300))):
        d = 0.75
        t = t_of(d)
        pitch = end + (start - end) * np.exp(-t * 4.0)
        whine = np.sign(np.sin(np.cumsum(pitch) / SR * 2 * np.pi)) * env(d, 0.004, 3.4) * 0.3
        clank = highpass(noise(d), 1600) * env(d, 0.0008, 40.0)
        ring = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in ((610 + i * 90, 11), (1430, 16), (2210, 22))) * 0.3
        save(f"droid_death_{i + 1}", lowpass(mix(whine, clank, ring), 5200), 0.7)
        d = 0.24
        t = t_of(d)
        ping = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in ((930 + i * 150, 30), (2100, 44))) * 0.5
        save(f"droid_hurt_{i + 1}", mix(ping, highpass(noise(d), 2400) * env(d, 0.0006, 70.0) * 0.6), 0.6)


def grenades():
    """A pin coming out, smoke pouring from a canister, and fuel catching and burning."""
    d = 0.2
    t = t_of(d)
    tick = np.sin(2 * np.pi * 4200 * t) * env(d, 0.0005, 70.0) * 0.5
    slide = highpass(noise(d), 3000) * env(d, 0.002, 26.0) * 0.5
    save("grenade_pin", mix(tick, slide), 0.6)
    d = 3.2
    t = t_of(d)
    hiss = lowpass(highpass(noise(d), 1400), 6500) * np.minimum(t / 0.05, 1) * np.exp(-t * 0.7)
    save("smoke_hiss", hiss, 0.55)
    d = 0.9
    t = t_of(d)
    whoomp = lowpass(noise(d), 700) * env(d, 0.01, 6.0) + np.sin(np.cumsum(180 - 120 * t / d) / SR * 2 * np.pi) * env(d, 0.004, 7.0) * 0.8
    save("fire_ignite", whoomp, 0.8)
    d = 2.2
    t = t_of(d)
    roar = lowpass(noise(d), 500) * 0.5
    crack = np.zeros(len(t))
    for at in np.random.default_rng(31).uniform(0.02, d - 0.05, 46):
        i = int(at * SR)
        n = int(0.012 * SR)
        crack[i:i + n] += highpass(noise(0.012), 1800)[:n] * np.linspace(1, 0, n)
    edge = np.minimum(np.minimum(t, d - t) / 0.08, 1)
    save("fire_burn", (roar + crack * 0.7) * edge, 0.6)


def click(d=0.03, tone=2400.0):
    """One dry mechanical tick: a short burst of filtered noise on a metal ring."""
    t = t_of(d)
    return (noise(d) * 0.6 + np.sin(2 * np.pi * tone * t) * 0.5) * env(d, 0.0005, 180.0)


def place(out, x, at):
    i = int(at * SR)
    n = min(len(x), len(out) - i)
    out[i : i + n] += x[:n]


if __name__ == "__main__":
    artillery()
    grenades()
    machines()
