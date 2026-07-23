#!/usr/bin/env python3
"""THE ROOT GENERATOR for the reusable BIT flight -> land ceremony SFX.

Produces the two canonical assets consumed everywhere the "BIT banks a flight and
lands in its seat" gesture plays:

    app/assets/audio/ceremony_flight.wav   the flight (V5 "chunky arcade" dash)
    app/assets/audio/ceremony_land.wav     the landing thud (V4 "servo latch")

Chosen by audition (2026-07-23): flight = the arcade dash (noise burst + a
discrete bright stab, NO pitch-slide — the rising/falling glissando is the
slide-whistle comedy idiom the old flight suffered from); land = the mechanical
servo latch (click + inharmonic metallic ring + power-down + sub thunk),
fitting BIT-the-drone-core. Momentum comes from filtered noise + amplitude arcs,
each land is transient -> body -> tail. Ceremony tier (flight 0.30 / land 0.34).

This is the REUSABLE flight/land audio — play it via SfxService.playFlight() /
playLand() (aliases of playCeremonyFlight/Land). Re-run after any edit:

    python ops/gen_flight_land_sfx.py

(Supersedes the flight/land recipes in the older gen_ceremony_sfx.py, whose
OUT path is a stale pre-move repo-root path; this writes to app/assets/audio.)
"""
import math, os, random, struct, wave

SR = 44100
_HERE = os.path.dirname(os.path.abspath(__file__))
_OUT = os.path.normpath(os.path.join(_HERE, "..", "app", "assets", "audio"))
C6, E6, G6 = 1046.50, 1318.51, 1567.98

# ── toolkit (shared with gen_ui_sfx.py; sweep_noise carries the stability clamp) ─
def env_ad(n, attack_s, dur_s, curve=4.0):
    out = []; a = max(1, int(attack_s * SR))
    for i in range(n):
        t = i / SR
        if i < a: out.append(i / a)
        elif t >= dur_s: out.append(0.0)
        else: out.append(math.exp(-curve * (t - attack_s) / max(1e-9, dur_s - attack_s)))
    return out

def bl_square(freqs, gain=1.0):
    n = len(freqs); phases = []; p = 0.0
    for f in freqs: p += f / SR; phases.append(p)
    kmax = max(1, int((SR * 0.45) / max(freqs))); out = [0.0] * n; k = 1
    while k <= kmax:
        g = gain / k
        for i in range(n): out[i] += math.sin(2 * math.pi * k * phases[i]) * g
        k += 2
    return [(4 / math.pi) * s for s in out]

def steps(seq):
    freqs = []
    for f, d in seq: freqs.extend([f] * int(d * SR))
    return freqs

def glide(f0, f1, dur):
    n = int(dur * SR)
    return [f0 + (f1 - f0) * (i / max(1, n - 1)) for i in range(n)]

def sweep_noise(n, f0, f1, q, seed, gain=1.0):
    rng = random.Random(seed); low = band = 0.0; out = []
    for i in range(n):
        c = f0 + (f1 - f0) * (i / max(1, n - 1))
        f = 2 * math.sin(math.pi * min(c, SR * 0.45) / SR)
        x = rng.uniform(-1, 1); low += f * band; high = x - low - q * band; band += f * high
        band = -4.0 if band < -4.0 else (4.0 if band > 4.0 else band)
        out.append(band * gain)
    return out

def noise_bp(n, center, q=1.0, seed=7, gain=1.0):
    return sweep_noise(n, center, center, q, seed, gain)

def sine(freq, n, gain=1.0):
    return [math.sin(2 * math.pi * freq * i / SR) * gain for i in range(n)]

def psine(freqs, gain=1.0):
    out = []; ph = 0.0
    for f in freqs: ph += f / SR; out.append(math.sin(2 * math.pi * ph) * gain)
    return out

def silence(seconds): return [0.0] * int(seconds * SR)
def apply_env(sig, env): return [s * e for s, e in zip(sig, env)]

def mix(*layers):
    n = max(len(l) for l in layers); out = [0.0] * n
    for l in layers:
        for i, s in enumerate(l): out[i] += s
    return out

def bell(n, peak=0.4, rise=2.0, fall=2.0):
    out = []
    for i in range(n):
        x = i / max(1, n - 1)
        out.append((x / peak) ** rise if x < peak else ((1 - x) / max(1e-9, 1 - peak)) ** fall)
    return out

def _fade_out(sig, fade_s):
    f = max(1, int(fade_s * SR)); nn = len(sig)
    for i in range(max(0, nn - f), nn): sig[i] *= (nn - i) / f
    return sig

def write_wav(name, sig, peak):
    m = max(1e-9, max(abs(s) for s in sig)); sig = [s * (peak / m) for s in sig]
    path = os.path.join(_OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in sig))
    print(f"  {name}.wav  {len(sig)/SR:.3f}s  peak {peak}")


def flight():
    """V5 CHUNKY ARCADE — a noise dash + a discrete bright stab (C6-E6-G6, NOT a
    slide) + a mid body + whoosh air, over a flyby amplitude arc. ~1.0s, fades
    to silence so the land hits clean air."""
    dur = 1.0; n = int(dur * SR); amp = bell(n, 0.35, 2.5, 1.8)
    dash = [s * 0.5 for s in apply_env(sweep_noise(int(0.25 * SR), 800, 2600, 0.5, 808),
                                       env_ad(int(0.25 * SR), 0.005, 0.25, 3))] + silence(dur - 0.25)
    stab = steps([(C6, 0.05), (E6, 0.05), (G6, 0.06)])
    stabsig = silence(0.05) + apply_env(bl_square(stab, 0.8), env_ad(len(stab), 0.003, 0.16, 3))
    body = [s * 0.4 for s in apply_env(bl_square([400] * n, 0.5), amp)]
    air = [s * 0.25 for s in apply_env(sweep_noise(n, 1200, 3000, 0.6, 909), amp)]
    return _fade_out(mix(dash, stabsig, body, air), 0.05)


def land():
    """V4 SERVO LATCH — a metallic click + an inharmonic metallic ring + a servo
    power-down + a sub thunk: BIT-the-drone-core clicking into its dock. ~0.12s."""
    click = [s * 0.7 for s in apply_env(noise_bp(int(0.005 * SR), 3200, 0.5, 77),
                                        env_ad(int(0.005 * SR), 0.0003, 0.005, 6))]
    ring = mix(
        apply_env(sine(1250, int(0.12 * SR), 0.3), env_ad(int(0.12 * SR), 0.001, 0.12, 4)),
        apply_env(sine(1870, int(0.10 * SR), 0.2), env_ad(int(0.10 * SR), 0.001, 0.10, 4)),
        apply_env(sine(2430, int(0.08 * SR), 0.14), env_ad(int(0.08 * SR), 0.001, 0.08, 4)),
    )
    gl = glide(240, 90, 0.10)
    pdown = silence(0.02) + apply_env(bl_square(gl, 0.5), env_ad(len(gl), 0.002, 0.10, 4))
    thunk = apply_env(psine(glide(75, 45, 0.09), 0.7), env_ad(int(0.09 * SR), 0.001, 0.09, 4))
    return _fade_out(mix(click, ring, pdown, thunk), 0.03)


if __name__ == "__main__":
    print("generating flight/land ->", _OUT)
    write_wav("ceremony_flight", flight(), 0.30)
    write_wav("ceremony_land", land(), 0.34)
    print("done.")
