#!/usr/bin/env python3
"""Generate the interaction-tier UI sounds at `app/assets/audio/`:

    ui_tap_1..3.wav     34 ms  — PixelButton press tick ("keycap rise", G5->C6)
    set_logged_1..3.wav 130 ms — set-logged confirm ("checkmark", C5->G5)
    ui_warn.wav         125 ms — destructive-confirm buzz (E5->A4, descending)
    rest_go.wav         450 ms — rest-end "ready-go" (G5->C6 chorus + vibrato)

The palette the user picked from the 2026-07-18 audition (15 synthesized
candidates on an HTML audition page; picks: tap C / set-log B / warning /
rest-end A; selection tier dropped). Doctrine baked in:

- **Band-limited additive squares** (odd harmonics capped at 0.45*SR) — a naive
  square at G5+ aliases audibly and reads as artifact, not pixel style.
- **C-major** throughout — coheres with the existing C-major ceremony fanfares.
- **Loudness ladder** (peaks): tap 0.10 < warn 0.20 < set-log 0.22 < rest 0.30
  < ceremony 0.32. A tick must never compete with a fanfare.
- **3 pre-rendered variants** for the high-frequency sounds (tap, set-log) —
  audio fatigues faster than visuals on repeat; variants share the identity
  (same interval/envelope family) with micro detune/timing offsets, peak-matched.
- **Phone-speaker floor:** every primary cue >= ~700 Hz (small speakers kill lows).

Deterministic; re-run after any edit:

    python ops/gen_ui_sfx.py
"""
import math
import os
import random
import struct
import wave

SR = 44100
_HERE = os.path.dirname(os.path.abspath(__file__))
_OUT_DIR = os.path.normpath(os.path.join(_HERE, "..", "app", "assets", "audio"))

G5, C6 = 783.99, 1046.50
C5, E5, A4 = 523.25, 659.25, 440.00


def env_ad(n, attack_s, dur_s, curve=4.0):
    """Linear attack, exponential decay reaching ~0 at dur_s."""
    out = []
    a = max(1, int(attack_s * SR))
    for i in range(n):
        t = i / SR
        if i < a:
            out.append(i / a)
        elif t >= dur_s:
            out.append(0.0)
        else:
            out.append(math.exp(-curve * (t - attack_s) / max(1e-9, dur_s - attack_s)))
    return out


def bl_square(freqs, gain=1.0):
    """Band-limited square: additive odd harmonics capped below Nyquist."""
    n = len(freqs)
    phases = []
    p = 0.0
    for f in freqs:
        p += f / SR
        phases.append(p)
    kmax = max(1, int((SR * 0.45) / max(freqs)))
    out = [0.0] * n
    k = 1
    while k <= kmax:
        g = gain / k
        for i in range(n):
            out[i] += math.sin(2 * math.pi * k * phases[i]) * g
        k += 2
    return [(4 / math.pi) * s for s in out]


def steps(seq):
    """[(freq, seconds), ...] -> per-sample freqs (hard chiptune steps)."""
    freqs = []
    for f, d in seq:
        freqs.extend([f] * int(d * SR))
    return freqs


def apply_env(sig, env):
    return [s * e for s, e in zip(sig, env)]


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, s in enumerate(l):
            out[i] += s
    return out


def write_wav(name, sig, peak):
    m = max(1e-9, max(abs(s) for s in sig))
    sig = [s * (peak / m) for s in sig]
    path = os.path.join(_OUT_DIR, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in sig))
    print(f"wrote {path}  ({len(sig) / SR:.3f}s, peak {peak})")


def main() -> None:
    # ── ui_tap_1..3 — "keycap rise": G5 -> C6 two hard steps, 34 ms, peak 0.10.
    # Variants: micro second-step detune (0 / -6 / +6 cents) + decay offsets.
    for i, (cents, d1, d2) in enumerate(
        [(0, 0.015, 0.019), (-6, 0.014, 0.018), (6, 0.016, 0.020)], start=1
    ):
        c6 = C6 * (2 ** (cents / 1200))
        f = steps([(G5, d1), (c6, d2)])
        write_wav(f"ui_tap_{i}",
                  apply_env(bl_square(f), env_ad(len(f), 0.001, d1 + d2)), 0.10)

    # ── set_logged_1..3 — "checkmark": C5 -> G5, 130 ms, peak 0.22.
    # Variants: note-length balance + micro detune on the resolve.
    for i, (cents, d1, d2) in enumerate(
        [(0, 0.055, 0.075), (-5, 0.052, 0.078), (5, 0.058, 0.072)], start=1
    ):
        g5 = G5 * (2 ** (cents / 1200))
        f = steps([(C5, d1), (g5, d2)])
        write_wav(f"set_logged_{i}",
                  apply_env(bl_square(f), env_ad(len(f), 0.002, d1 + d2)), 0.22)

    # ── ui_warn — descending detuned buzz: E5 -> A4, 125 ms, peak 0.20.
    fw = steps([(E5, 0.055), (A4, 0.070)])
    w1 = bl_square(fw, 0.6)
    w2 = bl_square([f * 1.02 for f in fw], 0.45)  # detune roughness
    write_wav("ui_warn", apply_env(mix(w1, w2), env_ad(len(fw), 0.002, 0.125)), 0.20)

    # ── rest_go — "ready-go": G5 -> C6, detune-doubled, vibrato blooming on the
    # C6, 450 ms, peak 0.30. The one functional cue (best-effort over music —
    # the rest-end notification stays the reliable path).
    n1, n2 = int(0.140 * SR), int(0.300 * SR)
    fr = [G5] * n1
    for i in range(n2):
        t = i / SR
        vib = 1.0 + 0.005 * math.sin(2 * math.pi * 6 * t) * min(1.0, t / 0.12)
        fr.append(C6 * vib)
    ra = mix(bl_square(fr, 0.55), bl_square([f * 1.004 for f in fr], 0.45))
    er = env_ad(len(fr), 0.003, 0.150)
    for i in range(n1, len(fr)):
        t = (i - n1) / SR
        er[i] = 1.0 if t < 0.02 else math.exp(-3.2 * (t - 0.02) / 0.28)
    write_wav("rest_go", apply_env(ra, er), 0.30)


if __name__ == "__main__":
    main()
