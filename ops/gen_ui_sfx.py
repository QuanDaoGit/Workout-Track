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
        out.append(band * gain)
    return out


def noise_bp(n, center, q=1.0, seed=7, gain=1.0):
    return sweep_noise(n, center, center, q, seed, gain)


def sine(freq, n, gain=1.0):
    return [math.sin(2 * math.pi * freq * i / SR) * gain for i in range(n)]


def silence(seconds):
    return [0.0] * int(seconds * SR)


def syllable(f0, f1, dur, vib=0.0, vibr=8.0):
    """One spoken 'syllable': pitch glide + optional vibrato, soft envelope."""
    n = int(dur * SR)
    fr = []
    for i in range(n):
        t = i / SR
        base = f0 + (f1 - f0) * (i / max(1, n - 1))
        fr.append(base * (1.0 + vib * math.sin(2 * math.pi * vibr * t)))
    return apply_env(tri_wave(fr), env_ad(n, 0.008, dur, 3.2))


G6, C7, E6, E7 = 1567.98, 2093.00, 1318.51, 2637.02


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

    # ═══ SFX v2 — the coherent kit (audition picks, 2026-07-19) ═══════════════

    # ── ui_select_1..3 — "data zip": a 4-step rising micro-arpeggio, the
    # ArcadeChip select. Digital by design: pure square, hard steps, no noise
    # (the v1 candidates' noise transients read as "random clicks").
    for i, (cents, d4) in enumerate([(0, 0.011), (-5, 0.012), (5, 0.010)], 1):
        c7 = C7 * (2 ** (cents / 1200))
        fz = steps([(C6, 0.007), (E6, 0.007), (G6, 0.007), (c7, d4)])
        write_wav(f"ui_select_{i}",
                  apply_env(bl_square(fz), env_ad(len(fz), 0.0008, 0.007 * 3 + d4, 4)), 0.07)

    # ── toggle pair — state direction you can hear: on rises, off falls.
    ft = steps([(G5, 0.015), (C6, 0.022)])
    write_wav("ui_toggle_on", apply_env(bl_square(ft), env_ad(len(ft), 0.001, 0.037)), 0.07)
    fd = steps([(C6, 0.015), (G5, 0.022)])
    write_wav("ui_toggle_off", apply_env(bl_square(fd), env_ad(len(fd), 0.001, 0.037)), 0.07)

    # ── stepper pair — bent micro-pips for ±15s rest / numeric steppers.
    su = glide(C6, C6 * 1.06, 0.018)
    write_wav("ui_step_up", apply_env(bl_square(su), env_ad(len(su), 0.001, 0.018, 5)), 0.07)
    sd = glide(G5, G5 * 0.94, 0.018)
    write_wav("ui_step_down", apply_env(bl_square(sd), env_ad(len(sd), 0.001, 0.018, 5)), 0.07)

    # ── ui_skip — the soft descending glide (pick B): a release, not an error.
    gsk = glide(C6, E5, 0.100)
    write_wav("ui_skip", apply_env(tri_wave(gsk), env_ad(len(gsk), 0.003, 0.100)), 0.10)

    # ── rest_go_set — the weaker between-SET sibling: same G5->C6 identity as
    # rest_go, single voice, no chorus/vibrato, shorter. The smaller moment
    # sounds smaller; rest_go becomes the between-EXERCISE cue only.
    frs = steps([(G5, 0.095), (C6, 0.155)])
    write_wav("rest_go_set", apply_env(bl_square(frs), env_ad(len(frs), 0.003, 0.250)), 0.22)

    # ── ui_notice — the CRT center-notice power-on blip (a notification).
    nsw = apply_env(bl_square(glide(1500, 3000, 0.040), 0.5), env_ad(int(0.040 * SR), 0.002, 0.040))
    ntk = apply_env(noise_bp(int(0.006 * SR), 2600, q=1.0, seed=67), env_ad(int(0.006 * SR), 0.0005, 0.006, 6))
    write_wav("ui_notice", mix(ntk, [s * 0.8 for s in nsw]), 0.08)

    # ═══ Signatures (audition picks) ══════════════════════════════════════════

    # ── TRAIN "heavy keycap" (pick A), split for the real two-part press:
    # down = felt thunk at tap-down, up = C5+G5 dyad engage at commit.
    dn = mix(
        apply_env(noise_bp(int(0.022 * SR), 750, q=0.8, seed=71), env_ad(int(0.022 * SR), 0.0005, 0.022, 6)),
        apply_env(bl_square([700.0] * int(0.018 * SR), 0.6), env_ad(int(0.018 * SR), 0.001, 0.018)),
    )
    write_wav("train_down", dn, 0.20)
    up = apply_env(
        mix(bl_square([C5] * int(0.060 * SR), 0.6), bl_square([G5] * int(0.060 * SR), 0.4)),
        env_ad(int(0.060 * SR), 0.002, 0.060))
    write_wav("train_up", up, 0.22)

    # ── board_tap "degauss wake" (pick A): thump -> static sweeps up -> hum.
    th = apply_env(bl_square([200.0] * int(0.018 * SR), 0.7), env_ad(int(0.018 * SR), 0.001, 0.018))
    swp = apply_env(sweep_noise(int(0.075 * SR), 300, 3200, 0.6, 103), env_ad(int(0.075 * SR), 0.010, 0.075, 2.5))
    hum = apply_env(mix(bl_square([C6] * int(0.045 * SR), 0.30), bl_square([G5] * int(0.045 * SR), 0.20)),
                    env_ad(int(0.045 * SR), 0.012, 0.045, 3))
    write_wav("board_tap", mix(th, silence(0.012) + swp, silence(0.080) + hum), 0.15)

    # ── pad_tap "prime" (pick A): the dispatch whoosh's little sibling —
    # rising doppler + air, anticipation not completion.
    fpr = glide(392.00, C5 * 1.05, 0.110)
    pra = apply_env(bl_square(fpr, 0.6), env_ad(len(fpr), 0.035, 0.110, 2.2))
    air = apply_env(sweep_noise(int(0.110 * SR), 1200, 3800, 0.5, 89), env_ad(int(0.110 * SR), 0.030, 0.110, 2.2))
    write_wav("pad_tap", mix(pra, [s * 0.45 for s in air]), 0.18)

    # ── pad_dispatch — the launch whoosh (approved).
    fdw = glide(392.00, G5, 0.250)
    airw = apply_env(sweep_noise(int(0.250 * SR), 2400, 2400, 0.4, 97), env_ad(int(0.250 * SR), 0.030, 0.250, 2.5))
    wh = apply_env(bl_square(fdw, 0.6), env_ad(len(fdw), 0.020, 0.250, 2.5))
    write_wav("pad_dispatch", mix(wh, [s * 0.5 for s in airw]), 0.25)

    # ── haul_collect — chunky haul: thunk + bright 2-step tail (approved).
    th2 = mix(
        apply_env(noise_bp(int(0.030 * SR), 900, q=0.8, seed=101), env_ad(int(0.030 * SR), 0.0005, 0.030, 6)),
        apply_env(bl_square([C5] * int(0.045 * SR), 0.7), env_ad(int(0.045 * SR), 0.001, 0.045)),
    )
    ftl = steps([(E6, 0.045), (G6, 0.070)])
    tl = apply_env(bl_square(ftl), env_ad(len(ftl), 0.002, 0.115))
    write_wav("haul_collect", mix(th2, silence(0.030) + [s * 0.5 for s in tl]), 0.25)

    # ── bit_chirp "bi-di-bip?" (pick A): three spoken syllables, the last
    # bending UP — a question. Soft triangle timbre, deliberately not a UI
    # square: a character response. ONE-OFF — BIT gets no wider voice without
    # explicit product-owner sign-off.
    write_wav("bit_chirp",
              syllable(E6, E6 * 1.02, 0.070) + silence(0.030) +
              syllable(G6, G6 * 0.98, 0.060) + silence(0.025) +
              syllable(G6, C7 * 1.06, 0.130, vib=0.015), 0.15)

    gen_home_ambience()


# ═════════════════════════════════════════════════════════════════════════════
# home_ambience.wav — the Home room's bed (audition pick "PAD LIGHT", round 6.1,
# 2026-07-19): a ~69Hz electric discharge-train buzz whose amplitude envelope is
# a VERBATIM port of BitPadLightPainter._intensity() (bit_pad_light.dart — the
# light pool's breath/jitter/dip curve at chunky 14fps; regenerate this asset if
# that curve changes), an octave-coupled macro swell (rises brighter, sinks
# darker, once per 8s loop), arc snaps fired at the light's dip onsets, and
# room depth from lowpassed circular-delay reflections. TRUE STEREO, perfectly
# loopable, authored at peak 0.05 — BELOW every kit sound (a bed, not a track).
# ═════════════════════════════════════════════════════════════════════════════

A_DUR = 8.0
A_N = int(SR * A_DUR)


def _qloop(f):
    return round(f * A_DUR) / A_DUR


def _train(period, brightness_hz, gain):
    f0 = SR / period
    kmax = max(1, int(brightness_hz / f0))
    p = [0.0] * period
    for k in range(1, kmax + 1):
        g = gain / k
        for i in range(period):
            p[i] += math.sin(2 * math.pi * k * i / period) * g
    return (p * (A_N // period + 1))[:A_N]


def _hashn(x):
    s = math.sin(x * 12.9898) * 43758.5453
    return s - math.floor(s)


def _light_env():
    breath_hz = _qloop(1.6 / (2 * math.pi))
    env = [0.0] * A_N
    onsets = []
    in_dip = False
    for i in range(A_N):
        t = i / SR
        tq = math.floor(t * 14) / 14
        breath = 0.80 + 0.20 * math.sin(2 * math.pi * breath_hz * tq)
        jitter = 0.94 + 0.06 * _hashn(tq * 1.7)
        dipping = _hashn(tq * 0.37 + 11) < 0.16
        dip = (0.5 + 0.22 * _hashn(tq * 2.1 + 3)) if dipping else 1.0
        if dipping and not in_dip:
            onsets.append(i)
        in_dip = dipping
        env[i] = breath * jitter * dip
    xf = int(0.4 * SR)
    for i in range(xf):
        w = i / xf
        env[i] = env[i] * w + env[A_N - xf + i] * (1 - w)
    return env, onsets


def _reflect(sig, delay_s, gain, alpha):
    d = int(delay_s * SR)
    out = [0.0] * A_N
    v = 0.0
    for i in range(A_N):
        s = sig[(i - d) % A_N]
        v += alpha * (s - v)
        out[i] = v * gain
    return out


def gen_home_ambience():
    env, onsets = _light_env()
    bright, dark = 6500, 2925
    dkL = [a + b for a, b in zip(_train(320, dark, 0.55), _train(322, dark, 0.45))]
    brL = [a + b for a, b in zip(_train(320, bright, 0.55), _train(322, bright, 0.45))]
    dkR = [a + b for a, b in zip(_train(320, dark, 0.45), _train(324, dark, 0.55))]
    brR = [a + b for a, b in zip(_train(320, bright, 0.45), _train(324, bright, 0.55))]
    swell_hz = _qloop(0.125)
    L = [0.0] * A_N
    R = [0.0] * A_N
    for i in range(A_N):
        t = i / SR
        up = 0.5 + 0.5 * math.sin(2 * math.pi * swell_hz * t - math.pi / 2)
        e = env[i] * (0.55 + 0.45 * up)
        L[i] = (dkL[i] * (1 - up) + brL[i] * up) * e
        R[i] = (dkR[i] * (1 - up) + brR[i] * up) * e
    crng = random.Random(907)
    for k, at in enumerate(onsets):
        pan = 0.25 if k % 2 == 0 else 0.75
        for i in range(90):
            t = i / SR
            if at + i >= A_N:
                break
            v = crng.uniform(-1, 1) * math.exp(-t / 0.0015) * 0.5
            L[at + i] += v * (1 - pan)
            R[at + i] += v * pan
    refL = _reflect(R, 0.023, 0.42, 0.10)
    refR = _reflect(L, 0.041, 0.42, 0.08)
    washL = _reflect(L, 0.130, 0.22, 0.03)
    washR = _reflect(R, 0.155, 0.22, 0.03)
    for i in range(A_N):
        L[i] += refL[i] + washL[i]
        R[i] += refR[i] + washR[i]
    if not all(math.isfinite(s) for s in L[::997]):
        raise ValueError("home_ambience: non-finite samples")
    m = max(max(abs(s) for s in L), max(abs(s) for s in R))
    k2 = 0.05 / m
    path = os.path.join(_OUT_DIR, "home_ambience.wav")
    with wave.open(path, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for l, r in zip(L, R):
            frames += struct.pack(
                "<hh",
                int(max(-1.0, min(1.0, l * k2)) * 32767),
                int(max(-1.0, min(1.0, r * k2)) * 32767),
            )
        w.writeframes(bytes(frames))
    print(f"wrote {path}  ({A_DUR:.2f}s stereo loop, peak 0.05)")


if __name__ == "__main__":
    main()
