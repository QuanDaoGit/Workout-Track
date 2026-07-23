#!/usr/bin/env python3
"""5 candidate flight+land PAIRS for the BIT ceremony (replaces ceremony_flight/
land everywhere). Five distinct, web-researched approaches. Doctrine from the
research: momentum comes from FILTERED NOISE + amplitude arcs, NOT tonal
pitch-glides (the rising/falling glissando is the slide-whistle comedy idiom —
the likely source of the "annoying" feeling). Each land = transient(crack) +
body(weight) + tail(debris). Ceremony tier. Pure-stdlib toolkit (gen_ui_sfx.py).

Outputs to ./flight_candidates/ (audition only — NOT app/assets).
    python gen_flight_land_candidates.py
"""
import math, os, random, struct, wave

SR = 44100
_HERE = os.path.dirname(os.path.abspath(__file__))
_OUT = os.path.join(_HERE, "flight_candidates")
os.makedirs(_OUT, exist_ok=True)
G5, C6, E6, G6 = 783.99, 1046.50, 1318.51, 1567.98

# ── toolkit (from gen_ui_sfx.py) + a few additions ───────────────────────────
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

def tri_wave(freqs, gain=1.0):
    n = len(freqs); phases = []; p = 0.0
    for f in freqs: p += f / SR; phases.append(p)
    kmax = max(1, int((SR * 0.45) / max(freqs))); out = [0.0] * n; k, sign = 1, 1.0
    while k <= kmax:
        g = sign * gain / (k * k)
        for i in range(n): out[i] += math.sin(2 * math.pi * k * phases[i]) * g
        k += 2; sign = -sign
    return [(8 / (math.pi ** 2)) * s for s in out]

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
        band = -4.0 if band < -4.0 else (4.0 if band > 4.0 else band)   # stability clamp
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
    """Amplitude arc 0 -> 1 (at fraction `peak`) -> 0 — a flyby swell."""
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

# ══ A1 — JET THRUSTER (cinematic power): broadband noise roar + sub + air ══════
def flight_jet(dur=1.4):
    n = int(dur * SR); amp = bell(n, 0.42, 2.0, 1.6)
    b1 = sweep_noise(n, 300, 1400, 0.5, 11); b2 = sweep_noise(n, 900, 3000, 0.7, 22)
    roar = [(b1[i] * 0.6 + b2[i] * 0.5) * amp[i] for i in range(n)]
    sub = []; ph = 0.0
    for i in range(n):
        t = i / SR; f = 55 * (1 + 0.03 * math.sin(2 * math.pi * 3 * t)); ph += f / SR
        sub.append(math.sin(2 * math.pi * ph) * amp[i] * 0.5)
    air = [s * 0.18 for s in apply_env(sweep_noise(n, 2500, 5500, 0.5, 33), amp)]
    return _fade_out(mix(roar, sub, air), 0.12)

def land_boom(dur=0.34):
    nt = int(0.012 * SR)
    crack = [s * 0.7 for s in apply_env(noise_bp(nt, 1600, 0.6, 44), env_ad(nt, 0.0004, 0.012, 6))]
    gl = glide(70, 38, 0.20); boom = apply_env(psine(gl, 1.0), env_ad(len(gl), 0.001, 0.20, 3.5))
    thump = apply_env(bl_square([120] * int(0.06 * SR), 0.6), env_ad(int(0.06 * SR), 0.001, 0.06, 5))
    nd = int(0.18 * SR)
    debris = [s * 0.25 for s in apply_env(sweep_noise(nd, 1200, 300, 0.6, 55), env_ad(nd, 0.004, 0.18, 3))]
    return _fade_out(mix(crack, boom, thump, debris), 0.03)

# ══ A2 — AIR SWISH (organic foley): staggered bandpass swishes, no tone ════════
def flight_swish(dur=1.15):
    n = int(dur * SR)
    def swoosh(lo, hi, start, length, seed, gain):
        m = int(length * SR); body = sweep_noise(m, lo, hi, 0.5, seed); env = bell(m, 0.4, 2.5, 2.0)
        return silence(start) + [body[i] * env[i] * gain for i in range(m)]
    s1 = swoosh(700, 2600, 0.0, 0.45, 101, 0.85)
    s2 = swoosh(600, 3200, 0.35, 0.55, 202, 0.7)
    low = [s * 0.2 for s in apply_env(sweep_noise(n, 200, 700, 0.6, 303), bell(n, 0.45, 2, 2))]
    return _fade_out(mix(s1, s2, low), 0.08)

def land_clack(dur=0.24):
    nt = int(0.006 * SR)
    click = [s * 0.7 for s in apply_env(noise_bp(nt, 2600, 0.5, 71), env_ad(nt, 0.0003, 0.006, 6))]
    b1 = apply_env(tri_wave([200] * int(0.09 * SR), 0.85), env_ad(int(0.09 * SR), 0.001, 0.09, 4))
    b2 = apply_env(tri_wave([330] * int(0.07 * SR), 0.4), env_ad(int(0.07 * SR), 0.001, 0.07, 4))
    tail = [s * 0.15 for s in apply_env(sweep_noise(int(0.10 * SR), 900, 400, 0.6, 72), env_ad(int(0.10 * SR), 0.003, 0.10, 4))]
    return _fade_out(mix(click, b1, b2, tail), 0.02)

# ══ A3 — SCI-FI WARP (hi-tech magic): detuned shimmer chord + noise riser ══════
def flight_warp(dur=1.4):
    n = int(dur * SR); amp = bell(n, 0.55, 1.6, 2.2)
    shim = [0.0] * n
    for f in (900, 1200, 1500, 1800):
        for det in (1.0, 1.006):
            s = psine([f * det] * n, 0.25)
            for i in range(n): shim[i] += s[i]
    shim = [shim[i] * amp[i] * 0.4 for i in range(n)]
    riser = [s * 0.3 for s in apply_env(sweep_noise(n, 500, 4500, 0.5, 404), [(i / n) ** 1.5 for i in range(n)])]
    return _fade_out(mix(shim, riser), 0.10)

def land_discharge(dur=0.32):
    zap = [s * 0.6 for s in apply_env(sweep_noise(int(0.07 * SR), 4200, 800, 0.5, 505), env_ad(int(0.07 * SR), 0.0005, 0.07, 5))]
    gl = glide(60, 40, 0.16); boom = apply_env(psine(gl, 0.9), env_ad(len(gl), 0.001, 0.16, 3.5))
    spark = silence(0.04) + mix(
        apply_env(sine(2600, int(0.05 * SR), 0.3), env_ad(int(0.05 * SR), 0.001, 0.05, 5)),
        silence(0.03) + apply_env(sine(2000, int(0.05 * SR), 0.22), env_ad(int(0.05 * SR), 0.001, 0.05, 5)),
    )
    return _fade_out(mix(zap, boom, spark), 0.03)

# ══ A4 — SERVO DRONE (on-identity: BIT is a drone core): tremolo motor whir ════
def flight_servo(dur=1.3):
    n = int(dur * SR); fr = []
    for i in range(n):
        x = i / n; fr.append(190 + 60 * math.sin(math.pi * min(1.0, x / 0.85)))   # small rev up/down
    buzz = bl_square(fr, 0.7)
    trem = []
    for i in range(n):
        t = i / SR; lfo = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(2 * math.pi * 42 * t)); trem.append(buzz[i] * lfo)
    amp = bell(n, 0.45, 2.0, 2.0)
    motor = [trem[i] * amp[i] * 0.7 for i in range(n)]
    air = [s * 0.18 for s in apply_env(sweep_noise(n, 1500, 3000, 0.6, 606), amp)]
    return _fade_out(mix(motor, air), 0.08)

def land_latch(dur=0.34):
    click = [s * 0.7 for s in apply_env(noise_bp(int(0.005 * SR), 3200, 0.5, 77), env_ad(int(0.005 * SR), 0.0003, 0.005, 6))]
    ring = mix(
        apply_env(sine(1250, int(0.12 * SR), 0.3), env_ad(int(0.12 * SR), 0.001, 0.12, 4)),
        apply_env(sine(1870, int(0.10 * SR), 0.2), env_ad(int(0.10 * SR), 0.001, 0.10, 4)),
        apply_env(sine(2430, int(0.08 * SR), 0.14), env_ad(int(0.08 * SR), 0.001, 0.08, 4)),
    )
    gl = glide(240, 90, 0.10); pdown = silence(0.02) + apply_env(bl_square(gl, 0.5), env_ad(len(gl), 0.002, 0.10, 4))
    thunk = apply_env(psine(glide(75, 45, 0.09), 0.7), env_ad(int(0.09 * SR), 0.001, 0.09, 4))
    return _fade_out(mix(click, ring, pdown, thunk), 0.03)

# ══ A5 — CHUNKY ARCADE (the family, done right): noise dash + discrete stab ════
def flight_arcade(dur=1.0):
    n = int(dur * SR); amp = bell(n, 0.35, 2.5, 1.8)
    dash = [s * 0.5 for s in apply_env(sweep_noise(int(0.25 * SR), 800, 2600, 0.5, 808), env_ad(int(0.25 * SR), 0.005, 0.25, 3))] + silence(dur - 0.25)
    stab = steps([(C6, 0.05), (E6, 0.05), (G6, 0.06)])
    stabsig = silence(0.05) + apply_env(bl_square(stab, 0.8), env_ad(len(stab), 0.003, 0.16, 3))
    body = [s * 0.4 for s in apply_env(bl_square([400] * n, 0.5), amp)]
    air = [s * 0.25 for s in apply_env(sweep_noise(n, 1200, 3000, 0.6, 909), amp)]
    return _fade_out(mix(dash, stabsig, body, air), 0.05)

def land_arcade(dur=0.22):
    thud = apply_env(bl_square(glide(120, 80, 0.06), 0.8), env_ad(int(0.06 * SR), 0.0008, 0.06, 5))
    stab = steps([(G5, 0.04), (C6, 0.06)])
    stabsig = [s * 0.6 for s in apply_env(bl_square(stab, 0.7), env_ad(len(stab), 0.002, 0.10, 3))]
    stabsig = silence(0.03) + stabsig
    dust = [s * 0.2 for s in apply_env(noise_bp(int(0.05 * SR), 1400, 0.7, 111), env_ad(int(0.05 * SR), 0.001, 0.05, 5))]
    return _fade_out(mix(thud, stabsig, dust), 0.02)

PAIRS = [
    ("a1_jet",     flight_jet,     land_boom),
    ("a2_swish",   flight_swish,   land_clack),
    ("a3_warp",    flight_warp,    land_discharge),
    ("a4_servo",   flight_servo,   land_latch),
    ("a5_arcade",  flight_arcade,  land_arcade),
]

if __name__ == "__main__":
    print("generating flight/land candidates ->", _OUT)
    for tag, f_fn, l_fn in PAIRS:
        write_wav(f"ceremony_flight_{tag}", f_fn(), 0.30)
        write_wav(f"ceremony_land_{tag}", l_fn(), 0.34)
    print("done.")
