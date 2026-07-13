#!/usr/bin/env python3
"""Generate the BIT Session-Complete ceremony micro-cues at `assets/audio/`:

    ceremony_tick.wav    330 Hz square, 35 ms  — the arrival tick (t=150ms)
    ceremony_chime.wav   660 Hz 60 ms -> 990 Hz 100 ms (starts +55 ms) — the surge release
    ceremony_land.wav    210 Hz square, 50 ms  — the touchdown blip (t=2550ms)
    ceremony_flight.wav  1.5 s chiptune thrust-swoosh — the banked flight (t=1050ms)

The three micro-cues are a faithful synthesis of the handoff prototype's
WebAudio `tone()` calls (`assets/design_handoff_session_ceremony/reference/
Session Complete.html`): square oscillator, gain envelope 0.0001 -> exponential
ramp to `gain` over 12 ms -> exponential ramp back to 0.0001 at `dur`. The
prototype's relative gains (tick 0.05 / chime 0.14 / land 0.09) are preserved as
a ratio, normalized so the chime peaks at 0.32 (the same internal headroom as
`gen_xp_riser.py`; `SfxService` applies play-volume on top).

The flight swoosh is a sensory-pass ADDITION (the handoff is silent on flight
audio): band-passed noise — the chiptune "wind" idiom — whose center frequency
and level both track the flight's speed curve (soft through the −4% pull-back,
swelling through the acceleration, tapering into the settle) and, per Codex
review, it FADES TO SILENCE by 1.40s so the 2550ms land blip never cuts live
energy (the single-player SfxService replaces the current shot).

Deterministic; re-run after any edit.

    python ops/gen_ceremony_sfx.py
"""
import math
import os
import random
import struct
import wave

SR = 44100
# Normalize the prototype's gain ratio (0.05 : 0.14 : 0.09) to chime = 0.32.
GAIN_SCALE = 0.32 / 0.14
ATTACK = 0.012      # exponentialRampToValueAtTime(gain, at + 0.012)
FLOOR = 0.0001      # the WebAudio envelope's start/end value
TAIL = 0.02         # o.stop(at + dur + 0.02) — release tail past the ramp

_HERE = os.path.dirname(os.path.abspath(__file__))
_OUT_DIR = os.path.normpath(os.path.join(_HERE, "..", "assets", "audio"))


def tone(samples: list, at: float, freq: float, dur: float, gain: float) -> None:
    """Mix one prototype `tone()` into `samples` (which must already be long
    enough): square wave at `freq`, exponential attack over ATTACK seconds,
    exponential decay reaching FLOOR at `at + dur`."""
    peak = gain * GAIN_SCALE
    n0 = int(at * SR)
    n1 = min(len(samples), int((at + dur + TAIL) * SR))
    phase = 0.0
    for i in range(n0, n1):
        t = i / SR - at
        phase += freq / SR
        sq = 1.0 if (phase % 1.0) < 0.5 else -1.0
        if t < ATTACK:
            # exponential ramp FLOOR -> peak over the attack window
            env = FLOOR * (peak / FLOOR) ** (t / ATTACK)
        else:
            # exponential ramp peak -> FLOOR, reaching FLOOR at t == dur
            decay = (t - ATTACK) / max(1e-9, dur - ATTACK)
            env = peak * (FLOOR / peak) ** min(1.0, decay)
        samples[i] += sq * env


def write(name: str, seconds: float, tones: list) -> None:
    n = int(SR * seconds)
    mix = [0.0] * n
    for at, freq, dur, gain in tones:
        tone(mix, at, freq, dur, gain)
    out = os.path.join(_OUT_DIR, name)
    with wave.open(out, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(
            b"".join(
                struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767))
                for s in mix
            )
        )
    print(f"wrote {out}  ({n} samples, {seconds:.3f}s)")


# ── the flight fwoosh ─────────────────────────────────────────────────────────
FLIGHT_DUR = 1.5      # matches the 1050→2550ms flight window
FLIGHT_FADE_END = 1.40  # silent from here — the land hit must never cut energy
FLIGHT_PEAK = 0.32    # peak amplitude (the chime's headroom)


def _flight_level(t: float) -> float:
    """Amplitude envelope tracking the flight's speed curve: quiet through the
    0.21s pull-back, swelling through the acceleration (peak ~0.8s), tapering
    into the settle, and HARD-FADED to zero by FLIGHT_FADE_END."""
    if t < 0.21:
        base = 0.25 + 0.35 * (t / 0.21)  # soft thrust building
    elif t < 0.80:
        base = 0.60 + 0.40 * math.sin(((t - 0.21) / 0.59) * math.pi / 2)
    else:
        base = max(0.0, 1.0 - (t - 0.80) / 0.55)  # taper through the settle
    if t > FLIGHT_FADE_END - 0.08:  # final safety fade into silence
        base *= max(0.0, (FLIGHT_FADE_END - t) / 0.08)
    return base


def _flight_pitch(t: float) -> float:
    """Monotonic RISING sweep — the pitch only ever climbs (user note: the
    doppler fall + vibrato read as 'down up down up'; a launch goes UP). Slow
    build through the pull-back, accelerating rise through the rush, still
    creeping upward as the level tapers out."""
    if t < 0.21:
        return 140 + (t / 0.21) * 100             # 140 -> 240: coiling
    p = min(1.0, (t - 0.21) / (FLIGHT_FADE_END - 0.21))
    return 240 + (p * p) * 760                    # 240 -> 1000: the climb


def write_flight() -> None:
    """A chiptune **dash fwoosh**: the dominant voice is a square wave on a
    strictly rising pitch sweep (no vibrato, no doppler fall — a launch goes
    up), and a quiet band-passed noise layer (~25%) sits underneath for air.
    Rewritten twice: from the noise-only swoosh (read as wind/hiss), then from
    the vibrato+doppler contour (read as pitch wobble)."""
    n = int(SR * FLIGHT_DUR)
    rng = random.Random(0xB17)  # deterministic noise layer
    low = 0.0
    band = 0.0
    phase = 0.0
    out = []
    for i in range(n):
        t = i / SR
        # Tonal voice: square on the pure rising sweep.
        phase += _flight_pitch(t) / SR
        sq = 1.0 if (phase % 1.0) < 0.5 else -1.0
        # Air layer: band-passed noise following the same contour, kept low.
        fc = _flight_pitch(t) * 2.2
        f = 2 * math.sin(math.pi * min(fc, 4000) / SR)
        noise = rng.uniform(-1.0, 1.0)
        low += f * band
        high = noise - low - 0.6 * band
        band += f * high
        mix = 0.75 * sq + 0.25 * band
        out.append(mix * _flight_level(t) * FLIGHT_PEAK)
    path = os.path.join(_OUT_DIR, "ceremony_flight.wav")
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
    # Validate the Codex fade requirement: the last 100ms must be silent.
    tail = out[int(SR * FLIGHT_FADE_END):]
    peak_tail = max((abs(s) for s in tail), default=0.0)
    assert peak_tail < 1e-6, f"flight tail not silent (peak {peak_tail})"
    print(f"wrote {path}  ({n} samples, {FLIGHT_DUR:.2f}s, silent after "
          f"{FLIGHT_FADE_END:.2f}s)")


# ── the landing impact ────────────────────────────────────────────────────────
def write_land() -> None:
    """A **strong landing thud** — user-directed replacement of the handoff's
    quiet 210 Hz blip (a named delta: 'show a strong landing, not a beep').
    Two layers: a sub-bass pitch-drop punch (140→45 Hz over ~130ms, the 8-bit
    'impact' idiom) + a sharp noise burst decaying fast (the dust). Peaks at
    the chime's headroom so it lands as hard as the surge."""
    dur = 0.24
    n = int(SR * dur)
    rng = random.Random(0x1A4D)
    phase = 0.0
    low = 0.0
    band = 0.0
    out = []
    for i in range(n):
        t = i / SR
        # Sub punch: fast pitch drop, near-square for grit, strong then gone.
        freq = 140 - min(1.0, t / 0.13) * 95      # 140 -> 45 Hz
        phase += freq / SR
        sub = 1.0 if (phase % 1.0) < 0.5 else -1.0
        sub_env = math.exp(-t / 0.075)
        # Impact noise: bright burst, very fast decay (the dust puff).
        f = 2 * math.sin(math.pi * 1400 / SR)
        noise = rng.uniform(-1.0, 1.0)
        low += f * band
        high = noise - low - 0.7 * band
        band += f * high
        noise_env = math.exp(-t / 0.035)
        s = (0.8 * sub * sub_env + 0.5 * band * noise_env) * 0.34
        # Short fade at the very end so the file closes clean.
        if t > dur - 0.02:
            s *= (dur - t) / 0.02
        out.append(s)
    path = os.path.join(_OUT_DIR, "ceremony_land.wav")
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
    print(f"wrote {path}  ({n} samples, {dur:.2f}s, impact thud)")


def main() -> None:
    # sfx('tick'):  tone(330, t0, 0.035, 0.05)
    write("ceremony_tick.wav", 0.035 + TAIL, [(0.0, 330.0, 0.035, 0.05)])
    # sfx('chime'): tone(660, t0, 0.06, 0.14); tone(990, t0 + 0.055, 0.1, 0.14)
    write(
        "ceremony_chime.wav",
        0.055 + 0.1 + TAIL,
        [(0.0, 660.0, 0.06, 0.14), (0.055, 990.0, 0.1, 0.14)],
    )
    write_land()
    write_flight()


if __name__ == "__main__":
    main()
