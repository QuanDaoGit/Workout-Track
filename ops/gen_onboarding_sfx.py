#!/usr/bin/env python3
"""Generate the ONBOARDING bespoke event-SFX at `app/assets/audio/`.

The first-run cinematic's narrative-peak sounds, designed per the doctrine in
`docs/superpowers/specs/2026-07-23-onboarding-sfx-doctrine-and-backlog-design.md`
(bespoke EVENT-SFX at the peaks only, NO music bed, budgeted density, mix
hierarchy interaction < event < ceremony, co-designed with the existing haptic
beats). Recipes came from the per-beat design workflow (timeline audit -> 3-lens
design panel -> judge synthesis -> adversarial critique); crt_boot's judge pass
was done by hand after the workflow hit a session limit.

Pure-stdlib additive/subtractive synthesis, the SAME pipeline + helper vocabulary
as `gen_ui_sfx.py` / `gen_ceremony_sfx.py` / `gen_boost_sfx.py` (band-limited
squares/triangles, C-major, primary cue >= ~700 Hz for the phone-speaker floor).
Deterministic. Re-run after any edit:

    python ops/gen_onboarding_sfx.py

Assets (write_wav peak on the loudness ladder in parens):
    onb_crt_boot / _settled          (0.32 / 0.28) — the cabinet powers on (first sound)
    onb_face_reveal / _v2 / _v3       (0.32 / 0.33 / 0.30) — BIT reveals its face (the peak)
    onb_face_reveal_settled           (0.24) — reduced-motion arrival
    onb_class_seal_{bruiser,assassin,tank} (0.33) — the class identity SEAL
    onb_class_gate_tick               (0.10) — 'I AM <CLASS>' commit becomes tappable
    onb_name_arm_1..3 / _rm           (0.24) — the self-naming vow arming
    onb_name_committed                (0.16) — the understated character birth
    onb_rank_assessed                 (0.32) — the rank verdict STAMP
    onb_boot                          (0.08) — loader 'system waking'
    onb_confirm_1..4                  (0.12) — the readback confirm-ladder (a piece of YOU)
    onb_resolve / onb_ready           (0.16) — calibration COMPLETE / program READY
    onb_seek_climb                    (0.06) — program 'matching...' thinking texture
"""
import math
import os
import random
import struct
import wave

SR = 44100
_HERE = os.path.dirname(os.path.abspath(__file__))
_OUT_DIR = os.path.normpath(os.path.join(_HERE, "..", "app", "assets", "audio"))

# Notes (Hz) — every primary cue sits >= ~700 Hz (small speakers kill lows).
C5, E5, G5, A4 = 523.25, 659.25, 783.99, 440.00
C6, E6, G6, C7 = 1046.50, 1318.51, 1567.98, 2093.00


# ── shared synth toolkit (copied verbatim from gen_ui_sfx.py) ──────────────────
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


def tri_wave(freqs, gain=1.0):
    """Band-limited triangle (odd harmonics, 1/k^2, alternating sign)."""
    n = len(freqs)
    phases = []
    p = 0.0
    for f in freqs:
        p += f / SR
        phases.append(p)
    kmax = max(1, int((SR * 0.45) / max(freqs)))
    out = [0.0] * n
    k, sign = 1, 1.0
    while k <= kmax:
        g = sign * gain / (k * k)
        for i in range(n):
            out[i] += math.sin(2 * math.pi * k * phases[i]) * g
        k += 2
        sign = -sign
    return [(8 / (math.pi ** 2)) * s for s in out]


def steps(seq):
    """[(freq, seconds), ...] -> per-sample freqs (hard chiptune steps)."""
    freqs = []
    for f, d in seq:
        freqs.extend([f] * int(d * SR))
    return freqs


def glide(f0, f1, dur):
    n = int(dur * SR)
    return [f0 + (f1 - f0) * (i / max(1, n - 1)) for i in range(n)]


def sweep_noise(n, f0, f1, q, seed, gain=1.0):
    """Noise through a bandpass whose center sweeps f0->f1."""
    rng = random.Random(seed)
    low = band = 0.0
    out = []
    for i in range(n):
        c = f0 + (f1 - f0) * (i / max(1, n - 1))
        f = 2 * math.sin(math.pi * min(c, SR * 0.45) / SR)
        x = rng.uniform(-1, 1)
        low += f * band
        high = x - low - q * band
        band += f * high
        # Stability clamp: this SVF diverges if q leaves the stable range (q was
        # meant as damping; high q breaks it). Bound `band` so a bad recipe param
        # saturates instead of blowing up and silently crushing normalization.
        band = -4.0 if band < -4.0 else (4.0 if band > 4.0 else band)
        out.append(band * gain)
    return out


def noise_bp(n, center, q=1.0, seed=7, gain=1.0):
    return sweep_noise(n, center, center, q, seed, gain)


def sine(freq, n, gain=1.0):
    return [math.sin(2 * math.pi * freq * i / SR) * gain for i in range(n)]


def silence(seconds):
    return [0.0] * int(seconds * SR)


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
    print(f"  {name}.wav  {len(sig) / SR:.3f}s  peak {peak}")


# ═══════════════════════════════════════════════════════════════════════════════
# BEAT: crt_boot — the CRT 'boot the cabinet' power-on (the app's FIRST sound).
# Hand-synthesized judge merge of the 3-lens design panel: boost-kin onset +
# collapse, tonal C-major bloom resolve, warm-triangle settle. Asset t=0 == GET
# STARTED press; flash -> crush -> dark breath -> bloom -> hush, TRUE silence by
# 1.36s (subsumes the button tap so the boot is the single first sound).
# ═══════════════════════════════════════════════════════════════════════════════
def crt_boot():
    # 1 — inrush sub-punch: power hits the glass (felt weight; subsumes the tap).
    npu = int(0.18 * SR)
    punch = [s * 0.42 for s in
             apply_env(bl_square(glide(70, 52, 0.18), 0.9), env_ad(npu, 0.002, 0.18, 4.0))]

    # 2 — ignition riser: the electric surge charging the tube. Two detuned
    #     band-limited squares (grit without the boost saw grammar) glide E4->C6
    #     over 0-360ms, then hold C6 flat through the white hold (360-540), cut at
    #     540. Amplitude swells into the plateau.
    rf = glide(330.0, C6, 0.36) + [C6] * int(0.18 * SR)   # 0.54s
    nrf = len(rf)
    swell = []
    for i in range(nrf):
        t = i / SR
        swell.append(0.12 + 0.50 * (t / 0.36) ** 1.6 if t < 0.36 else 0.62)
    riser = mix(
        apply_env(bl_square(rf, 0.55), swell),
        apply_env(bl_square([f * 1.008 for f in rf], 0.42), swell),
    )
    air_env = [(i / max(1, nrf - 1)) ** 2 for i in range(nrf)]
    air = [s * 0.22 for s in apply_env(sweep_noise(nrf, 800, 3000, 1.2, 0xC0FF), air_env)]

    # 3 — CRT collapse crush (@0.54): the image crushing to a scanline + the
    #     mechanical thunk-to-black. Descending square + descending noise whoosh +
    #     a short snap transient. Decays to silence by ~0.76 -> the dark breath.
    ncr = int(0.22 * SR)
    crush_sq = apply_env(bl_square(glide(C6, 90.0, 0.22), 0.6), env_ad(ncr, 0.002, 0.22, 5.0))
    crush_wh = [s * 0.32 for s in
                apply_env(sweep_noise(ncr, 3000, 200, 0.7, 0xC27), env_ad(ncr, 0.004, 0.22, 3.0))]
    nsn = int(0.03 * SR)
    thunk = [s * 0.40 for s in
             apply_env(noise_bp(nsn, 900.0, q=0.9, seed=0xC33), env_ad(nsn, 0.0005, 0.03, 6.0))]
    crush = mix(crush_sq, crush_wh, thunk)

    # 4 — power-on bloom (@0.86): the warm phosphor slit widening -> the 'alive'
    #     C6+G5 dyad + a rising sparkle. THE payoff — loudest, warmest, C-major.
    nbl = int(0.19 * SR)
    bloom_env = env_ad(nbl, 0.02, 0.19, 1.6)
    bloom = [s * 0.78 for s in mix(
        apply_env(tri_wave(glide(C5, C6, 0.19), 1.0), bloom_env),
        apply_env(bl_square(glide(C5, C6, 0.19), 0.35), bloom_env),
    )]
    # the 'alive' dyad (@1.05): held C6+G5, hard-faded to TRUE silence by 1.36s.
    ndy = int(0.31 * SR)
    dyenv = env_ad(ndy, 0.02, 0.31, 2.6)
    fd = int(0.10 * SR)
    for i in range(ndy - fd, ndy):
        dyenv[i] *= (ndy - i) / fd
    dyad = mix(
        apply_env(tri_wave([C6] * ndy, 0.5), dyenv),
        apply_env(tri_wave([G5] * ndy, 0.34), dyenv),
    )
    # sparkle (@0.90): neon edge-glow glint, gone by ~1.12.
    sp = steps([(C6, 0.05), (E6, 0.05), (G6, 0.10)])
    sparkle = [s * 0.20 for s in apply_env(tri_wave(sp), env_ad(len(sp), 0.004, 0.20, 4.0))]

    return mix(
        silence(1.36),                # length anchor
        punch,                        # @0.00
        riser,                        # @0.00
        air,                          # @0.00
        silence(0.54) + crush,        # @0.54
        silence(0.86) + bloom,        # @0.86
        silence(0.90) + sparkle,      # @0.90
        silence(1.05) + dyad,         # @1.05
    )


def crt_boot_settled():
    """Reduced-motion boot: ONE compressed power-on (no collapse/trough build that
    would imply motion the stilled hard-cut never shows). A short tick -> the warm
    bloom + 'alive' dyad + sparkle, ~0.9s to silence. Caller writes at ~0.28."""
    npu = int(0.06 * SR)
    tick = [s * 0.35 for s in apply_env(bl_square([C5] * npu, 0.7), env_ad(npu, 0.002, 0.06, 4.0))]
    nbl = int(0.16 * SR)
    bloom_env = env_ad(nbl, 0.015, 0.16, 1.6)
    bloom = [s * 0.78 for s in mix(
        apply_env(tri_wave(glide(C5, C6, 0.16), 1.0), bloom_env),
        apply_env(bl_square(glide(C5, C6, 0.16), 0.35), bloom_env),
    )]
    ndy = int(0.26 * SR)
    dyenv = env_ad(ndy, 0.02, 0.26, 2.6)
    fd = int(0.08 * SR)
    for i in range(ndy - fd, ndy):
        dyenv[i] *= (ndy - i) / fd
    dyad = mix(
        apply_env(tri_wave([C6] * ndy, 0.5), dyenv),
        apply_env(tri_wave([G5] * ndy, 0.34), dyenv),
    )
    sp = steps([(C6, 0.05), (G6, 0.08)])
    sparkle = [s * 0.18 for s in apply_env(tri_wave(sp), env_ad(len(sp), 0.004, 0.13, 4.0))]
    return mix(silence(0.50), tick, silence(0.05) + bloom, silence(0.09) + sparkle, silence(0.20) + dyad)


# ═══════════════════════════════════════════════════════════════════════════════
# BEAT: face_reveal — "the breath, the grin, the friend". Asset t=0 == controller
# 520ms; apex at asset 0.82s == controller 1340ms. (workflow recipe, verbatim)
# ═══════════════════════════════════════════════════════════════════════════════
def _crescendo(n, lo=0.30, hi=1.00, shape=1.5, attack_s=0.004):
    a = max(1, int(attack_s * SR))
    return [(lo + (hi - lo) * (i / max(1, n - 1)) ** shape) * min(1.0, i / a)
            for i in range(n)]


def _ramp(n):
    return [i / max(1, n - 1) for i in range(n)]


def _vibrato(fbase, n, depth=0.006, rate=5.5, bloom_start=0.15, bloom_ramp=0.20):
    fr = []
    for i in range(n):
        t = i / SR
        bloom = min(1.0, max(0.0, (t - bloom_start) / bloom_ramp))
        fr.append(fbase * (1.0 + depth * math.sin(2 * math.pi * rate * t) * bloom))
    return fr


def bit_face_reveal(seed=41, peak_body=0.45, sparkle_gain=0.5,
                    triad_curve=3.5, add_ping=False):
    # 1 — INHALE (asset 0.00-0.24): audible indrawn breath — downward air + a
    #     sinking triangle tone. Whisper-quiet wind-up.
    ni = int(0.24 * SR)
    inhale_air = apply_env(sweep_noise(ni, 1400, 520, 3.0, seed), env_ad(ni, 0.06, 0.24))
    inhale_air = [s * 0.20 for s in inhale_air]
    inhale_tone = apply_env(tri_wave(glide(330, 250, 0.24)), env_ad(ni, 0.04, 0.24))
    inhale_tone = [s * 0.11 for s in inhale_tone]

    # 2 — RISE (0.24-0.82): the coil snaps — a rising C-major SQUARE run landing
    #     on C6 at the apex, a brightening air sweep beneath.
    rise_f = steps([(C5, 0.145), (E5, 0.145), (G5, 0.145), (C6, 0.145)])
    nr = len(rise_f)
    rise = [s * 0.55 for s in apply_env(bl_square(rise_f), _crescendo(nr))]
    rise_air = [s * 0.10 for s in apply_env(sweep_noise(nr, 800, 2200, 2.0, seed + 12), _ramp(nr))]

    # 3 — APEX (asset 0.82): a bright C-major triad (blooming vibrato keeps the
    #     hold alive), a felt low-mid body thud, an eyes-open sparkle.
    na = int(0.58 * SR)
    lead = bl_square(_vibrato(C6, na), 1.0)
    mid = bl_square([E6] * na, 0.6)
    top = bl_square([G6] * na, 0.5)
    triad = apply_env(mix(lead, mid, top), env_ad(na, 0.006, 0.58, triad_curve))
    nb = int(0.14 * SR)
    body = [s * peak_body for s in
            apply_env(bl_square(glide(160, 90, 0.14), 0.9), env_ad(nb, 0.004, 0.14, 4.0))]
    ns = int(0.03 * SR)
    sparkle = [s * sparkle_gain for s in
               apply_env(noise_bp(ns, 4000, q=1.0, seed=seed + 7), env_ad(ns, 0.002, 0.03, 6))]
    ping = []
    if add_ping:
        npg = int(0.09 * SR)
        ping = [s * 0.18 for s in apply_env(sine(C7, npg), env_ad(npg, 0.002, 0.09, 5))]

    # 3d — SHIMMER GLINT (asset ~1.02): decay-only tri E6 partnering the blink.
    ng = int(0.10 * SR)
    shimmer = [s * 0.12 for s in apply_env(tri_wave([E6] * ng), env_ad(ng, 0.006, 0.10))]

    # 4 — SETTLE (asset 1.40-1.78): the exhale + the SIGNATURE colour morph — a
    #     warm triangle easing C6 -> grounded G5 (bright 'amber' -> warm
    #     'turquoise'), hard-faded to true silence before the denouement.
    nst = int(0.38 * SR)
    senv = env_ad(nst, 0.05, 0.38, 2.5)
    fade = int(0.10 * SR)
    for i in range(nst - fade, nst):
        senv[i] *= (nst - i) / fade
    settle = [s * 0.35 for s in apply_env(tri_wave(glide(C6, G5, 0.38)), senv)]

    return mix(
        silence(1.80),                                  # length anchor
        inhale_air,                                     # @0.00
        inhale_tone,                                    # @0.00
        silence(0.24) + rise,                           # @0.24
        silence(0.24) + rise_air,                       # @0.24
        silence(0.82) + triad,                          # @0.82 (apex)
        silence(0.82) + body,                           # @0.82
        silence(0.82) + sparkle,                        # @0.82
        (silence(0.82) + ping) if add_ping else silence(0.82),
        silence(1.02) + shimmer,                        # @1.02
        silence(1.40) + settle,                         # @1.40
    )


def bit_face_reveal_settled(seed=41):
    """Reduced-motion arrival: ONE soft amber->turquoise resolve (the colour-morph
    only, climb/apex/sparkle stripped). Caller normalizes to ~0.24."""
    na = int(0.12 * SR)
    amber = apply_env(bl_square([C6] * na, 0.8), env_ad(na, 0.006, 0.12, 4))
    nt = int(0.36 * SR)
    tenv = env_ad(nt, 0.05, 0.36, 2.5)
    fade = int(0.10 * SR)
    for i in range(nt - fade, nt):
        tenv[i] *= (nt - i) / fade
    turq = [s * 0.9 for s in apply_env(tri_wave(glide(C6, G5, 0.36)), tenv)]
    return mix(silence(0.46), amber, silence(0.06) + turq)


# ═══════════════════════════════════════════════════════════════════════════════
# BEAT: class_reveal — the identity SEAL (struck-then-rings), class-coloured.
# Buffer t=0 == the 120ms slam. (workflow recipe, verbatim)
# ═══════════════════════════════════════════════════════════════════════════════
_CLASS = {
    "bruiser":  dict(triad=(C6, E6, G6), chord_dur=0.22, ring_dur=0.60,
                     ring_curve=3.2, sub=(150.0, 58.0, 0.55)),
    "assassin": dict(triad=(E6, G6, C7), chord_dur=0.18, ring_dur=0.46,
                     ring_curve=3.6, sub=(150.0, 62.0, 0.34)),
    "tank":     dict(triad=(G5, C6, E6), chord_dur=0.28, ring_dur=0.72,
                     ring_curve=2.8, sub=(160.0, 52.0, 0.68)),
}


def _const_sq(freq, dur, attack, curve, gain):
    n = int(dur * SR)
    return [s * gain for s in apply_env(bl_square([freq] * n), env_ad(n, attack, dur, curve))]


def _const_tri(freq, dur, attack, curve, gain):
    n = int(dur * SR)
    return [s * gain for s in apply_env(tri_wave([freq] * n), env_ad(n, attack, dur, curve))]


def build_class_reveal_seal(klass="bruiser", reduced_motion=False):
    cfg = _CLASS[klass]
    t1, t2, t3 = cfg["triad"]
    sub_f0, sub_f1, sub_g = cfg["sub"]
    if reduced_motion:
        sub_g *= 0.6

    layers = []
    # 1 — STRIKE transient: the metal-on-metal crack of the stamp (~2.6 kHz).
    n_strike = int(0.05 * SR)
    layers.append(apply_env(noise_bp(n_strike, 2600.0, q=1.2, seed=0x5EA1),
                            env_ad(n_strike, 0.0, 0.05, 6.0)))
    # 2 — SUB impact: a fast downward pitch-drop thump (felt weight of the shake).
    sub_fr = glide(sub_f0, sub_f1, 0.10)
    layers.append([s * sub_g for s in
                   apply_env(bl_square(sub_fr), env_ad(len(sub_fr), 0.001, 0.10, 5.0))])
    # 3 — STRUCK class chord: the class NAME asserting (a stamp, not an arpeggio).
    cd = cfg["chord_dur"]
    layers.append(mix(
        _const_sq(t1, cd, 0.004, 3.5, 0.60),
        _const_sq(t2, cd, 0.004, 3.5, 0.42),
        _const_sq(t3, cd, 0.004, 3.5, 0.34),
    ))
    # 4 — IDENTITY ring: who you are, HELD (a sustained triangle triad).
    rd, rc = cfg["ring_dur"], cfg["ring_curve"]
    layers.append(mix(
        _const_tri(t1, rd, 0.006, rc, 0.50),
        _const_tri(t2, rd, 0.006, rc, 0.34),
        _const_tri(t3, rd, 0.006, rc, 0.26),
    ))
    # 5 — SCANLINE shimmer: rides the 120->440ms emblem wipe, center sweeping UP
    #     (crystallizing / powering-ON, opposite of boost_ignite's collapse).
    if not reduced_motion:
        n_sh = int(0.32 * SR)
        shimmer = apply_env(sweep_noise(n_sh, 1500.0, 4600.0, 0.6, 0x5CA9),
                            env_ad(n_sh, 0.02, 0.32, 2.5))
        layers.append(silence(0.03) + [s * 0.14 for s in shimmer])

    out = mix(*layers)
    fade = int(0.03 * SR)
    for i in range(max(0, len(out) - fade), len(out)):
        out[i] *= (len(out) - i) / fade
    return out


def build_gate_tick():
    """Tap-tier 'you may commit' cue when 'I AM <CLASS>' becomes tappable. A soft
    high triangle blip (NOT the press sound). Caller writes at peak 0.10."""
    n = int(0.055 * SR)
    return apply_env(tri_wave([G6] * n), env_ad(n, 0.004, 0.055, 4.0))


# ═══════════════════════════════════════════════════════════════════════════════
# BEAT: name_birth — the self-naming vow ARM (resolves to tonic) + the understated
# birth PERIOD on commit. (workflow recipe, verbatim)
# ═══════════════════════════════════════════════════════════════════════════════
def _tail_fade(sig, fade_s=0.030):
    f = max(1, int(fade_s * SR))
    n = len(sig)
    for i in range(max(0, n - f), n):
        sig[i] *= (n - i) / f
    return sig


def name_arm(variant=0, reduce_motion=False):
    cents, tshift, seed = [(0, 0.0, 4201), (5, -0.003, 4231),
                           (-5, 0.003, 4259)][variant]
    c6 = C6 * (2 ** (cents / 1200))

    n_tonic = int(0.190 * SR)
    tonic_sq = apply_env(bl_square([c6] * n_tonic, 1.0),
                         env_ad(n_tonic, 0.003, 0.190, 4.0))
    n_warm = int(0.170 * SR)
    warm = mix(
        apply_env(tri_wave([c6] * n_warm, 0.35), env_ad(n_warm, 0.010, 0.170, 3.0)),
        apply_env(tri_wave([C5] * n_warm, 0.18), env_ad(n_warm, 0.010, 0.170, 3.0)),
    )

    if reduce_motion:
        n_air = int(0.170 * SR)
        air = apply_env(sweep_noise(n_air, 1400, 2400, 0.6, seed, 0.40),
                        env_ad(n_air, 0.006, 0.150, 2.2))
        return _tail_fade(mix(tonic_sq, warm, air))

    n_step = int(0.066 * SR)
    step_e = apply_env(bl_square([E5] * n_step, 0.50), env_ad(n_step, 0.003, 0.085, 4.0))
    step_g = apply_env(bl_square([G5] * n_step, 0.70), env_ad(n_step, 0.003, 0.085, 4.0))
    off1 = 0.060 + tshift
    off2 = 0.120 + 2 * tshift
    lead = mix(step_e, silence(off1) + step_g, silence(off2) + tonic_sq)
    warmth = silence(off2) + warm
    n_air = int(0.220 * SR)
    air = apply_env(sweep_noise(n_air, 700, 2400, 0.6, seed, 0.50),
                    env_ad(n_air, 0.020, 0.200, 2.2))
    return _tail_fade(mix(lead, warmth, air))


def name_committed():
    n = int(0.130 * SR)
    body = mix(
        apply_env(tri_wave([C6] * n, 0.60), env_ad(n, 0.004, 0.130, 3.2)),
        apply_env(tri_wave([G5] * n, 0.30), env_ad(n, 0.004, 0.130, 3.2)),
    )
    ns = int(0.010 * SR)
    spark = apply_env(noise_bp(ns, 5200, 0.6, 913, 0.50),
                      env_ad(ns, 0.0005, 0.010, 6.0))
    return _tail_fade(mix(body, spark), 0.025)


# ═══════════════════════════════════════════════════════════════════════════════
# BEAT: rank_assessed — the verdict STAMP (fired AT the 500ms Timer mark).
# (workflow recipe, verbatim)
# ═══════════════════════════════════════════════════════════════════════════════
def rank_assessed(dur=0.50):
    n = int(dur * SR)
    # 1 — leading NEON CRACK: high, tight, DESCENDING bandpass zap (the strobe).
    #     NOTE: in this SVF `q` is DAMPING, so a tight/resonant zap wants LOW q
    #     (0.6, like pad_dispatch/board_tap) — the recipe's q=6.0 was both wrong
    #     for the intent and numerically unstable (it blew up + crushed the cue).
    n_cr = int(0.05 * SR)
    crack = apply_env(sweep_noise(n_cr, 3000, 1200, q=0.6, seed=0x51, gain=1.0),
                      env_ad(n_cr, 0.0004, 0.045, curve=6.0))
    crack = [s * 0.42 for s in crack]
    # 2 — FROZEN C-major triad SLAM (primary cue): static pitch = 'official'.
    tri_env = env_ad(n, 0.001, 0.12, curve=4.0)
    triad_layers = []
    for note in (C6, E6, G6):
        triad_layers.append(apply_env([s * 0.20 for s in bl_square([note] * n)], tri_env))
        triad_layers.append(apply_env([s * 0.10 for s in bl_square([note * 1.006] * n)], tri_env))
    triad = mix(*triad_layers)
    # 3 — sub-bass verdict PUNCH: 150->48Hz pitch-drop (stands in for the haptic).
    gl = glide(150, 48, 0.12)
    punch = apply_env([s * 0.75 for s in bl_square(gl)], env_ad(len(gl), 0.0005, 0.12, curve=5.0))
    # 4 — descending POWER-CYCLE WHOOSH: blankets the three strobe windows.
    n_wh = int(0.30 * SR)
    whoosh = apply_env(sweep_noise(n_wh, 1900, 180, q=1.2, seed=0xA5, gain=1.0),
                       env_ad(n_wh, 0.03, 0.30, curve=3.0))
    whoosh = silence(0.12) + [s * 0.26 for s in whoosh]
    # 5 — two FLASH-LOCKED descending glints (settle carried by pitch stepping down).
    n_g = int(0.055 * SR)
    g_env = env_ad(n_g, 0.001, 0.05, curve=4.0)
    glint2 = silence(0.16) + apply_env([s * 0.17 for s in tri_wave([G6] * n_g)], g_env)
    glint3 = silence(0.32) + apply_env([s * 0.11 for s in tri_wave([E6] * n_g)], g_env)

    out = mix(crack, triad, punch, whoosh, glint2, glint3)
    fade0 = int((dur - 0.08) * SR)
    for i in range(fade0, n):
        out[i] *= max(0.0, (n - i) / (n - fade0))
    return out[:n]


# ═══════════════════════════════════════════════════════════════════════════════
# BEAT: loaders — the readback confirm-ladder + resolves + seek texture.
# (workflow recipe, verbatim)
# ═══════════════════════════════════════════════════════════════════════════════
_CONFIRM_LADDER = [(G5, C6), (C6, E6), (E6, G6), (G6, C7)]
_CONFIRM_DETUNE = (0.0, -6.0, 6.0, -3.0)   # per-rung micro-detune, vary-on-repeat


def onboarding_confirm(idx):
    fa, fb = _CONFIRM_LADDER[idx]
    fb = fb * (2 ** (_CONFIRM_DETUNE[idx] / 1200.0))
    f = steps([(fa, 0.016), (fb, 0.020)])          # 36 ms, two hard chiptune steps
    return apply_env(bl_square(f), env_ad(len(f), 0.001, 0.036, 4.0))


def onboarding_boot():
    n = int(0.045 * SR)
    sweep = apply_env(bl_square(glide(1200.0, 2600.0, 0.045), 0.5), env_ad(n, 0.002, 0.045))
    air = apply_env(noise_bp(n, 2400.0, q=1.2, seed=41), env_ad(n, 0.004, 0.045, 3.0))
    return mix(sweep, [s * 0.35 for s in air])


def onboarding_resolve(program=False):
    if program:
        seq = [(E6, 0.060), (G6, 0.065), (C7, 0.080)]
    else:
        seq = [(C6, 0.060), (E6, 0.065), (G6, 0.075)]
    f = steps(seq)
    body = bl_square(f)
    if program:                                    # fifth doubling the top note
        n_top = int(0.080 * SR)
        fifth = apply_env(bl_square([G6] * n_top, 0.5), env_ad(n_top, 0.004, 0.080, 3.0))
        body = mix(body, silence(0.060 + 0.065) + fifth)
    sig = apply_env(body, env_ad(len(f), 0.002, sum(d for _, d in seq), 3.5))
    fade = int(0.028 * SR)                          # hard end-fade -> true zero
    for i in range(fade):
        sig[len(sig) - 1 - i] *= i / fade
    return sig


def onboarding_seek_climb(dur=3.2):
    n = int(dur * SR)
    out = silence(dur)
    seed, t = 300, 0.20
    while t < dur - 0.45:
        blen = int(0.006 * SR)
        center = 2200.0 + (seed % 5) * 90.0         # wobble 2200-2560 Hz
        blip = apply_env(noise_bp(blen, center, q=1.2, seed=seed), env_ad(blen, 0.0005, 0.006, 6.0))
        at = int(t * SR)
        for i in range(blen):
            if at + i < n:
                out[at + i] += blip[i] * 0.5
        t += 0.26 + 0.10 * ((seed % 7) / 6.0)       # irregular ~0.26-0.36 s gaps
        seed += 1
    return out


# ═══════════════════════════════════════════════════════════════════════════════
def main():
    print("generating onboarding SFX ->", _OUT_DIR)
    # crt_boot
    write_wav("onb_crt_boot", crt_boot(), 0.32)
    write_wav("onb_crt_boot_settled", crt_boot_settled(), 0.28)
    # face_reveal (V1 ships; V2/V3 are audition alternates)
    write_wav("onb_face_reveal", bit_face_reveal(), 0.32)
    write_wav("onb_face_reveal_v2", bit_face_reveal(add_ping=True, seed=83, sparkle_gain=0.6), 0.33)
    write_wav("onb_face_reveal_v3",
              bit_face_reveal(peak_body=0.30, triad_curve=4.5, sparkle_gain=0.4, seed=17), 0.30)
    write_wav("onb_face_reveal_settled", bit_face_reveal_settled(), 0.24)
    # class_reveal
    for k in ("bruiser", "assassin", "tank"):
        write_wav(f"onb_class_seal_{k}", build_class_reveal_seal(k), 0.33)
    write_wav("onb_class_gate_tick", build_gate_tick(), 0.10)
    # name_birth
    for i in range(3):
        write_wav(f"onb_name_arm_{i + 1}", name_arm(i), 0.24)
    write_wav("onb_name_arm_rm", name_arm(0, reduce_motion=True), 0.24)
    write_wav("onb_name_committed", name_committed(), 0.16)
    # rank_assessed
    write_wav("onb_rank_assessed", rank_assessed(), 0.32)
    # loaders
    write_wav("onb_boot", onboarding_boot(), 0.08)
    for i in range(4):
        write_wav(f"onb_confirm_{i + 1}", onboarding_confirm(i), 0.12)
    write_wav("onb_resolve", onboarding_resolve(False), 0.16)
    write_wav("onb_ready", onboarding_resolve(True), 0.16)
    write_wav("onb_seek_climb", onboarding_seek_climb(), 0.06)
    print("done.")


if __name__ == "__main__":
    main()
