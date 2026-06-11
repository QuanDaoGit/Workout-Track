"""Generate the quest-claim chime: a short chiptune "power-up" arpeggio.

The app's first sound effect. Theme-coherent with the CRT / pixel-arcade
identity: a clean ascending square-wave arpeggio (C5-E5-G5-C6) with a quick
per-note attack/decay envelope so there are no clicks. Stdlib only (wave,
struct, math) — no numpy.

Run from the repo root:
    python ops/generate_quest_chime.py

Output: assets/audio/quest_claim.wav (16-bit PCM, mono, 44.1 kHz).
Swap the asset freely; SfxService just plays whatever lives at that path.
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100
AMPLITUDE = 0.32  # headroom; square waves are loud
NOTE_SECONDS = 0.075
GAP_SECONDS = 0.012
ATTACK_SECONDS = 0.004
RELEASE_SECONDS = 0.030

# Ascending major arpeggio, then an octave sparkle on top.
NOTES_HZ = [523.25, 659.25, 783.99, 1046.50, 1318.51]


def _square(phase: float) -> float:
    return 1.0 if (phase % 1.0) < 0.5 else -1.0


def _envelope(t: float, duration: float) -> float:
    if t < ATTACK_SECONDS:
        return t / ATTACK_SECONDS
    if t > duration - RELEASE_SECONDS:
        return max(0.0, (duration - t) / RELEASE_SECONDS)
    return 1.0


def _render() -> bytes:
    samples = []
    for note_hz in NOTES_HZ:
        note_samples = int(SAMPLE_RATE * NOTE_SECONDS)
        for i in range(note_samples):
            t = i / SAMPLE_RATE
            phase = note_hz * t
            value = _square(phase) * _envelope(t, NOTE_SECONDS) * AMPLITUDE
            samples.append(value)
        for _ in range(int(SAMPLE_RATE * GAP_SECONDS)):
            samples.append(0.0)
    return b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
    )


def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(here)
    out_dir = os.path.join(repo_root, "assets", "audio")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "quest_claim.wav")

    frames = _render()
    with wave.open(out_path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(frames)

    duration_ms = len(frames) / 2 / SAMPLE_RATE * 1000
    print(f"Wrote {out_path} ({len(frames)} bytes, ~{duration_ms:.0f} ms)")


if __name__ == "__main__":
    main()
