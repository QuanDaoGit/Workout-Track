#!/usr/bin/env python3
"""Generate the feature-unlock ceremony fanfare at `assets/audio/`:

    unlock_fanfare.wav   ~1.05 s — the NEW SYSTEM ONLINE victory hit (t=500ms)

The unlock ceremony originally reused the session ceremony's surge chime
(660->990 Hz, two square blips) which read as "a beep, not victorious"
(user note, 2026-07-14). This is its dedicated replacement — the classic
"achievement unlocked" shape in the app's chiptune voice:

  1. power-on riser  (0.00-0.12s)  a quick square sweep 220->880 Hz, quiet —
                                   the sonic twin of the scanline reveal
  2. rising arpeggio (0.10-0.34s)  C5 -> E5 -> G5, 80 ms squares — the climb
  3. victory chord   (0.32-1.00s)  C6 held over G5 (a perfect fifth), a
                                   slightly detuned double voice for width,
                                   gentle vibrato blooming after 150 ms
  4. sparkle         (0.32s)       a C7 ping + a fast-decaying bright noise
                                   shimmer riding the hit

Peaks at the same 0.32 internal headroom as the other ceremony cues
(`SfxService` applies play-volume on top). Deterministic; re-run after any
edit:

    python ops/gen_unlock_sfx.py
"""
import math
import os
import random
import struct
import wave

SR = 44100
PEAK = 0.32
_HERE = os.path.dirname(os.path.abspath(__file__))
_OUT_DIR = os.path.normpath(os.path.join(_HERE, "..", "assets", "audio"))

DUR = 1.05

C5, E5, G5 = 523.25, 659.25, 783.99
C6, C7 = 1046.50, 2093.00


def _square(phase: float) -> float:
    return 1.0 if (phase % 1.0) < 0.5 else -1.0


def _env_attack_decay(t: float, attack: float, dur: float) -> float:
    """Linear attack, exponential-ish decay reaching ~0 at `dur`."""
    if t < 0:
        return 0.0
    if t < attack:
        return t / attack
    if t >= dur:
        return 0.0
    return math.exp(-3.0 * (t - attack) / max(1e-9, dur - attack))


def main() -> None:
    n = int(SR * DUR)
    rng = random.Random(0x0B17)
    out = [0.0] * n

    # 1 — power-on riser: 220 -> 880 Hz over 120 ms, quiet, fading into the
    # arpeggio so the fanfare starts as a "system waking" not a note.
    phase = 0.0
    for i in range(int(0.12 * SR)):
        t = i / SR
        freq = 220.0 + (t / 0.12) ** 2 * 660.0
        phase += freq / SR
        env = 0.30 * (t / 0.12) * (1.0 - max(0.0, (t - 0.09) / 0.03))
        out[i] += _square(phase) * env * PEAK

    # 2 — the climb: three quick square notes, each slightly louder.
    for k, (at, freq, gain) in enumerate(
        [(0.10, C5, 0.55), (0.18, E5, 0.65), (0.26, G5, 0.75)]
    ):
        phase = 0.0
        note_dur = 0.11
        n0 = int(at * SR)
        for i in range(n0, min(n, int((at + note_dur) * SR))):
            t = i / SR - at
            phase += freq / SR
            env = _env_attack_decay(t, 0.006, note_dur)
            out[i] += _square(phase) * env * gain * PEAK

    # 3 — the victory chord: C6 lead + G5 fifth below, each doubled by a
    # +6-cent detuned voice (chorus width), vibrato blooming after 150 ms.
    hit = 0.32
    chord_dur = DUR - hit
    for freq, gain in [(C6, 0.62), (G5, 0.38)]:
        for detune in (1.0, 1.0035):
            phase = 0.0
            for i in range(int(hit * SR), n):
                t = i / SR - hit
                vib = 1.0 + (
                    0.006 * math.sin(2 * math.pi * 5.5 * t)
                    * min(1.0, max(0.0, (t - 0.15) / 0.20))
                )
                phase += freq * detune * vib / SR
                env = _env_attack_decay(t, 0.008, chord_dur)
                out[i] += _square(phase) * env * gain * 0.5 * PEAK

    # 4 — sparkle: a C7 sine ping + a bright noise shimmer, both decaying fast
    # (the amber spark ring, heard).
    phase = 0.0
    low = band = 0.0
    f = 2 * math.sin(math.pi * 5200 / SR)
    for i in range(int(hit * SR), min(n, int((hit + 0.30) * SR))):
        t = i / SR - hit
        phase += C7 / SR
        ping = math.sin(2 * math.pi * phase) * math.exp(-t / 0.07) * 0.30
        noise = rng.uniform(-1.0, 1.0)
        low += f * band
        high = noise - low - 0.5 * band
        band += f * high
        shimmer = band * math.exp(-t / 0.05) * 0.22
        out[i] += (ping + shimmer) * PEAK

    # Close the file clean.
    fade = int(0.03 * SR)
    for i in range(n - fade, n):
        out[i] *= (n - i) / fade

    # Normalize any stacked-voice overshoot back to PEAK headroom.
    peak = max(abs(s) for s in out)
    if peak > PEAK:
        out = [s * (PEAK / peak) for s in out]

    path = os.path.join(_OUT_DIR, "unlock_fanfare.wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(
            b"".join(
                struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767))
                for s in out
            )
        )
    print(f"wrote {path}  ({n} samples, {DUR:.2f}s, peak {max(abs(s) for s in out):.3f})")


if __name__ == "__main__":
    main()
