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
    """A clear two-part bubble pop that survives phone-speaker playback."""
    dur = 0.26
    n = int(SR * dur)
    out = []
    phase = 0.0
    sparkle_phase = 0.0
    for i in range(n):
        t = i / SR
        progress = t / dur
        freq = 520 + 560 * progress
        phase += 2 * math.pi * freq / SR
        env = min(1.0, t / 0.003) * math.exp(-4.2 * progress)
        body = env * (
            0.76 * math.sin(phase) + 0.24 * math.sin(2 * phase)
        )

        sparkle_t = t - 0.105
        sparkle = 0.0
        if sparkle_t >= 0:
            sparkle_progress = sparkle_t / (dur - 0.105)
            sparkle_freq = 980 + 520 * sparkle_progress
            sparkle_phase += 2 * math.pi * sparkle_freq / SR
            sparkle_env = min(1.0, sparkle_t / 0.002) * math.exp(
                -5.5 * sparkle_progress
            )
            sparkle = 0.48 * sparkle_env * math.sin(sparkle_phase)

        out.append(math.tanh(1.7 * (0.82 * body + sparkle)))
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
