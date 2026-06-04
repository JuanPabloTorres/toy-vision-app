"""Generate a short, cheerful arcade-style "reward" chime for mission complete.

Pure synthesis (numpy) — no third-party audio, no branding. Writes a small
16-bit PCM WAV the app plays once when a mission completes.

Run: tools/toy_model_export/.venv312/Scripts/python.exe tools/audio_gen.py
Output: assets/audio/mission_complete_reward.wav
"""

from __future__ import annotations

import math
import os
import struct
import wave

SR = 44100
OUT = os.path.join("assets", "audio", "mission_complete_reward.wav")


def tone(freq: float, dur: float, vol: float, square: float = 0.25) -> list[float]:
    """A bell-ish note: sine + a touch of square for arcade sparkle, with a
    fast attack and exponential decay envelope."""
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        # exp decay envelope, quick attack
        env = min(1.0, t / 0.005) * math.exp(-3.2 * t / dur)
        s = math.sin(2 * math.pi * freq * t)
        sq = 1.0 if math.sin(2 * math.pi * freq * t) >= 0 else -1.0
        out.append(vol * env * ((1 - square) * s + square * sq))
    return out


def main() -> None:
    samples: list[float] = []
    # Ascending major arpeggio C5-E5-G5-C6 (happy, "you won"), short blips.
    arp = [(523.25, 0.10), (659.25, 0.10), (783.99, 0.10), (1046.50, 0.14)]
    for f, d in arp:
        samples += tone(f, d, 0.32)
    # Final sparkle chord (C6+E6+G6) ringing out.
    chord_n = int(SR * 0.55)
    c1 = tone(1046.50, 0.55, 0.16)
    c2 = tone(1318.51, 0.55, 0.13)
    c3 = tone(1567.98, 0.55, 0.11)
    for i in range(chord_n):
        samples.append(c1[i] + c2[i] + c3[i])

    # Soft-clip to avoid overflow, then to 16-bit PCM.
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
    dur = len(samples) / SR
    print(f"[audio] wrote {OUT} ({dur:.2f}s, {len(samples)} samples)")


if __name__ == "__main__":
    main()
