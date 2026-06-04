"""Generate short, friendly UI sound effects for Toy Vision (pure stdlib).

No numpy — keeps memory tiny. Writes 16-bit PCM WAVs used for button taps
and a small success chime. Child-friendly, no branding.

Run: tools/toy_model_export/.venv312/Scripts/python.exe tools/audio_sfx_gen.py
(any python works; only stdlib is used)
Outputs:
  assets/audio/button_tap_pop.wav
  assets/audio/button_success_chime.wav
"""

from __future__ import annotations

import math
import os
import struct
import wave

SR = 44100
OUT_DIR = os.path.join("assets", "audio")


def _write(name: str, samples: list[float]) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            s = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(s * 32767 * 0.9))
        w.writeframes(bytes(frames))
    print(f"[sfx] wrote {path} ({len(samples) / SR:.2f}s)")


def pop() -> list[float]:
    """A soft 'bloop' — a quick upward pitch slide with a fast bell decay."""
    dur = 0.13
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        freq = 420 + 520 * (t / dur)  # rise 420→940 Hz
        env = min(1.0, t / 0.004) * math.exp(-10 * t / dur)
        out.append(0.5 * env * math.sin(2 * math.pi * freq * t))
    return out


def success() -> list[float]:
    """Two happy ascending notes (E6→A6) with a gentle ring."""
    out: list[float] = []
    for freq, dur in [(1318.51, 0.12), (1760.0, 0.30)]:
        n = int(SR * dur)
        for i in range(n):
            t = i / SR
            env = min(1.0, t / 0.004) * math.exp(-4.5 * t / dur)
            s = math.sin(2 * math.pi * freq * t)
            sq = 1.0 if s >= 0 else -1.0
            out.append(0.42 * env * (0.8 * s + 0.2 * sq))
    return out


def main() -> None:
    _write("button_tap_pop.wav", pop())
    _write("button_success_chime.wav", success())


if __name__ == "__main__":
    main()
