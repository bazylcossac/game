"""Seamless, original ambience for the sci-fi maps. Requires numpy, writes PCM WAVs."""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
SECONDS = 24
N = RATE * SECONDS
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
rng = np.random.default_rng(1943)


def noise(band_min, band_max):
    # Construct periodic noise in the frequency domain, avoiding a pop at the loop seam.
    f = np.fft.rfftfreq(N, 1 / RATE)
    spectrum = rng.normal(size=len(f)) + 1j * rng.normal(size=len(f))
    spectrum *= np.exp(-(f / band_max) ** 2) * (1 - np.exp(-(f / band_min) ** 2))
    x = np.fft.irfft(spectrum, n=N)
    return x / max(np.std(x), 1e-9)


def save(name, signal):
    signal = np.clip(signal, -0.8, 0.8)
    with wave.open(str(OUT / (name + '.wav')), 'wb') as w:
        w.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        w.writeframes((signal * 32767).astype('<i2').tobytes())
    print(name, '24 s, peak', round(float(np.max(np.abs(signal))), 3))


def main():
    t = np.arange(N) / RATE
    # Steady rain and electrical hum, without the slow swell of surf.
    rain = noise(1100, 6500) * 0.045 + noise(300, 2200) * 0.012
    rain += np.sin(2 * np.pi * 100 * t) * 0.006
    save('ambient_neon', rain)
    # Ventilation, transformer harmonics, sparse relay clicks.
    station = noise(80, 650) * 0.024
    station += sum(np.sin(2 * np.pi * f * t) * amp for f, amp in [(50, .015), (100, .009), (150, .004)])
    for second in [3, 9, 16, 21]:
        start = second * RATE
        length = int(.12 * RATE)
        click = rng.normal(size=length) * np.exp(-np.arange(length) / (RATE * .012)) * .025
        station[start:start + length] += click
    save('ambient_station', station)


if __name__ == '__main__':
    main()
