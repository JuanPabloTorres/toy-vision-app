"""Generate a soft, loopable 'music-box' background loop for Home (pure stdlib).

Gentle sine bells, slow tempo, low volume — pleasant under the UI and not
annoying on repeat. Child-friendly, no branding. Writes a small 16-bit WAV.

Run: tools/toy_model_export/.venv312/Scripts/python.exe tools/audio_home_gen.py
Output: assets/audio/home_theme_loop.wav
"""

from __future__ import annotations

import math
import os
import struct
import wave

SR = 44100
OUT = os.path.join("assets", "audio", "home_theme_loop.wav")

# Note frequencies (C major, gentle).
N = {
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99,
    "A5": 880.00, "C6": 1046.50,
}

# A simple, calm 16-step motif (note, beats). One beat ≈ 0.42s.
MOTIF = [
    ("C5", 1), ("E5", 1), ("G5", 1), ("E5", 1),
    ("A5", 1), ("G5", 1), ("E5", 1), ("D5", 1),
    ("C5", 1), ("E5", 1), ("G5", 2),
    ("A5", 1), ("G5", 1), ("E5", 1), ("C5", 1),
]
BEAT = 0.42


def bell(freq: float, dur: float, vol: float) -> list[float]:
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.01) * math.exp(-2.6 * t / dur)
        # soft sine + faint 2nd harmonic for a music-box shimmer
        s = math.sin(2 * math.pi * freq * t) + 0.18 * math.sin(
            2 * math.pi * freq * 2 * t
        )
        out.append(vol * env * s)
    return out


def main() -> None:
    samples: list[float] = []
    for name, beats in MOTIF:
        samples += bell(N[name], BEAT * beats, 0.16)
    # Gentle fade in/out at the seams so the loop doesn't click.
    fade = int(SR * 0.04)
    for i in range(fade):
        g = i / fade
        samples[i] *= g
        samples[-1 - i] *= g

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            s = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(s * 32767 * 0.9))
        w.writeframes(bytes(frames))
    print(f"[home] wrote {OUT} ({len(samples) / SR:.2f}s)")


if __name__ == "__main__":
    main()
