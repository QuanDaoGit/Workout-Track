#!/usr/bin/env python3
"""Generate the chiptune 'XP bar filling / running up' riser at
`assets/audio/xp_riser.wav`.

A square-wave pitch sweep that STEPS up a scale (arcade 'bar filling' feel), not a
single blip — the sound the XP level meter plays as the bar climbs
(`SfxService.playXpRiser`). 8-bit style to match the app's other retro SFX.
Deterministic and tunable via the constants below; re-run after any edit.

    python ops/gen_xp_riser.py
"""
import math
import os
import struct
import wave

SR = 44100
DUR = 0.80          # seconds — slower climb (the chime resolves it at the crossing)
F_START = 262.0     # C4
F_END = 1046.0      # C6 (two octaves up)
VOL = 0.32          # 0..1 internal headroom (SfxService applies play-volume on top)
DUTY = 0.5          # square-wave duty cycle
STEPS = 9           # fewer, chunkier steps (bigger pitch jumps = steppier)

_HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(_HERE, "..", "assets", "audio", "xp_riser.wav"))


def freq_at(t: float) -> float:
    # Exponential sweep start->end, snapped to STEPS discrete notes so it
    # arpeggiates up like a filling bar.
    frac = t / DUR
    step = min(STEPS - 1, int(frac * STEPS))
    sfrac = step / (STEPS - 1)
    return F_START * (F_END / F_START) ** sfrac


def main() -> None:
    n = int(SR * DUR)
    samples = []
    phase = 0.0
    atk, rel = 0.008, 0.06
    step_len = DUR / STEPS
    for i in range(n):
        t = i / SR
        phase += freq_at(t) / SR
        sq = 1.0 if (phase % 1.0) < DUTY else -1.0
        env = 1.0
        if t < atk:
            env *= t / atk
        if t > DUR - rel:
            env *= (DUR - t) / rel
        into = (t % step_len) / step_len
        env *= 0.7 + 0.3 * (1.0 - into)  # per-step pluck so notes read distinct
        samples.append(int(max(-1.0, min(1.0, sq * env * VOL)) * 32767))

    with wave.open(OUT, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", s) for s in samples))
    print(f"wrote {OUT}  ({n} samples, {DUR:.2f}s, "
          f"{F_START:.0f}->{F_END:.0f}Hz, {STEPS} steps)")


if __name__ == "__main__":
    main()
