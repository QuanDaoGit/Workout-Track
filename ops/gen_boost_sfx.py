#!/usr/bin/env python3
"""Generate the Charge Ritual 'boost' SFX at `assets/audio/`:

    boost_charge.wav   3.0 s  V2 detuned-saw charge riser (the ~3s hold-to-charge)
    boost_ignite.wav   1.10 s E2 sub-bass boom + descending power-cycle whoosh (ignition)
    boost_release.wav  0.34 s short descending power-down blip (released before 100%)

Character was selected by audition (hybrid V2 riser + E2 ending): a chiptune-rooted
detuned-saw glide layered with a rising filtered-noise energy sweep, resolving into a
sub-bass ignition boom + a descending noise whoosh voiced to the CRT power-cycle
collapse. Pure-stdlib additive/subtractive synthesis, the same pipeline as
`gen_ceremony_sfx.py` / `gen_xp_riser.py`. Deterministic. Re-run after any edit:

    python ops/gen_boost_sfx.py

Played through `SfxService` on its dedicated boost channel: charge on pour-start,
ignite on 100%, release on an early let-go. Volume is applied on top by SfxService
(~0.65); these are normalized to 0.9 peak for internal headroom.
"""
import math
import os
import random
import struct
import wave

SR = 44100
PEAK = 0.9
_HERE = os.path.dirname(os.path.abspath(__file__))
_OUT = os.path.normpath(os.path.join(_HERE, "..", "assets", "audio"))


def _saw(p):
    return 2.0 * (p % 1.0) - 1.0


def _square(p, duty=0.5):
    return 1.0 if (p % 1.0) < duty else -1.0


def _write(samples, name):
    peak = max(1e-6, max(abs(x) for x in samples))
    g = PEAK / peak
    path = os.path.join(_OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", max(-32767, min(32767, int(x * g * 32767))))
            for x in samples))
    print(f"  {name}  {len(samples) / SR:.2f}s")


def charge(dur=3.0):
    """V2 riser: two detuned saws + a sub square gliding 110 -> ~932 Hz over `dur`,
    amplitude swelling, with a rising filtered-noise energy sweep."""
    n = int(dur * SR)
    b = [0.0] * n
    rng = random.Random(2)
    p1 = p2 = p3 = 0.0
    lp = 0.0
    for i in range(n):
        t = i / SR
        prog = t / dur
        f = 110.0 * (8.475 ** prog)              # three-octave exponential glide
        swell = 0.12 + 0.62 * (prog ** 1.6)
        p1 += f / SR
        p2 += (f * 1.008) / SR                    # detune
        p3 += (f * 0.5) / SR                      # sub square
        tone = 0.42 * _saw(p1) + 0.34 * _saw(p2) + 0.3 * _square(p3)
        # rising filtered-noise energy sweep (cutoff brightens with the charge)
        cut = 0.02 + 0.47 * (prog ** 2)
        lp += cut * (rng.uniform(-1, 1) - lp)
        b[i] = 0.42 * tone * swell + lp * (0.10 + 0.18 * prog)
    return b


def ignite(dur=1.10):
    """E2: a sub-bass ignition boom + a bright transient + a descending
    filtered-noise whoosh (voiced longer, to ride the CRT collapse)."""
    n = int(dur * SR)
    b = [0.0] * n
    rng = random.Random(12)
    # sub-bass boom (low sine, slight downward pitch, punchy)
    ph = 0.0
    for i in range(int(0.6 * SR)):
        t = i / SR
        f = 56.0 * (1.0 - 0.3 * t)
        ph += f / SR
        b[i] += 0.9 * math.sin(2 * math.pi * ph) * math.exp(-t / 0.19)
    # bright transient at the hit
    for i in range(int(0.03 * SR)):
        t = i / SR
        b[i] += 0.4 * rng.uniform(-1, 1) * math.exp(-t / 0.008)
    # descending power-cycle whoosh (falling cutoff = collapse), spans the tail
    lp = 0.0
    for i in range(n):
        t = i / SR
        cut = 0.6 * math.exp(-t / 0.34)
        lp += cut * (rng.uniform(-1, 1) - lp)
        b[i] += lp * 0.32 * math.exp(-t / 0.5)
    return b


def release(dur=0.34):
    """Short descending power-down blip (a let-go before 100%)."""
    n = int(dur * SR)
    b = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 320.0 * (2.0 ** (-3.2 * t / dur))     # slides down ~1.5 octaves
        ph += f / SR
        env = math.exp(-t / 0.11)
        b[i] = 0.6 * (0.7 * _square(ph, 0.5) + 0.3 * _saw(ph * 0.5)) * env
    return b


if __name__ == "__main__":
    print("generating boost SFX:")
    _write(charge(), "boost_charge.wav")
    _write(ignite(), "boost_ignite.wav")
    _write(release(), "boost_release.wav")
    print("done ->", _OUT)
