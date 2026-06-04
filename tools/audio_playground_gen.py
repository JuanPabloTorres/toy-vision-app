"""Generate a fun, bouncy 'playground' loop for the mission screen (stdlib).

Upbeat but soft and low-volume so it sits under the guidance without
distracting. Loopable 16-bit WAV. Child-friendly, no branding.

Run: tools/toy_model_export/.venv312/Scripts/python.exe tools/audio_playground_gen.py
Output: assets/audio/mission_playground_loop.wav
"""

from __future__ import annotations

import math
import os
import struct
import wave

SR = 44100
OUT = os.path.join("assets", "audio", "mission_playground_loop.wav")

N = {
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46,
    "G5": 783.99, "A5": 880.00, "C6": 1046.50,
}
# Bouncy, playful motif.
MOTIF = [
    ("C5", 1), ("E5", 1), ("G5", 1), ("C6", 1),
    ("G5", 1), ("E5", 1), ("F5", 1), ("D5", 1),
    ("E5", 1), ("G5", 1), ("A5", 1), ("G5", 1),
    ("E5", 1), ("C5", 1), ("G5", 1), ("C5", 1),
]
BEAT = 0.26  # faster than home → playful


def pluck(freq: float, dur: float, vol: float) -> list[float]:
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.006) * math.exp(-5.0 * t / dur)
        s = math.sin(2 * math.pi * freq * t)
        tri = 2 / math.pi * math.asin(math.sin(2 * math.pi * freq * t))
        out.append(vol * env * (0.7 * s + 0.3 * tri))
    return out


def main() -> None:
    samples: list[float] = []
    for name, beats in MOTIF:
        samples += pluck(N[name], BEAT * beats, 0.17)
    fade = int(SR * 0.03)
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
    print(f"[playground] wrote {OUT} ({len(samples) / SR:.2f}s)")


if __name__ == "__main__":
    main()
