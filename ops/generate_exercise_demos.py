"""Normalize the Day-1 form-demo clips into app-ready mp4s + poster stills.

The 5 FULL BODY A lifts each have a short source .mp4 in
assets/exercises/animated-videos/. The app plays them with the video_player
plugin (ExoPlayer — hardware-decoded, pausable), so each source produces two
outputs in assets/exercises/demos/:

  <slug>.mp4          normalized clip (H.264 480p, muted, faststart) for the
                      demo cabinet / fullscreen player
  <slug>_poster.webp  a mid-frame still for the static 60px thumbnails and the
                      player's pre-init frame

Source .mp4s stay undeclared (not shipped). Only the generated demos/ files are
declared in pubspec.yaml.

Requires ffmpeg on PATH. Run from the repo root:
    python ops/generate_exercise_demos.py
"""

import os
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(REPO_ROOT, "assets", "exercises", "animated-videos")
OUT_DIR = os.path.join(REPO_ROOT, "assets", "exercises", "demos")

# source filename -> output slug (matches lib/data/exercise_demos.dart)
CLIPS = {
    "barbell-bench-press.mp4": "barbell_bench_press",
    "WideGripLatPullDown (2).mp4": "wide_grip_lat_pulldown",
    "barbell-back-squat.mp4": "barbell_squat",
    "DumbbellBicepCurl (2).mp4": "dumbbell_bicep_curl",
    "TricepPushDown (2).mp4": "triceps_pushdown",
}

# 480p H.264 keeps form legible at small file size; -an strips audio;
# faststart moves the moov atom up so asset playback starts instantly.
WIDTH = 480
CRF = 27


def run(args):
    print("  $", " ".join(a if " " not in a else f'"{a}"' for a in args))
    subprocess.run(args, check=True, capture_output=True)


def main():
    if not os.path.isdir(SRC_DIR):
        sys.exit(f"Source dir not found: {SRC_DIR}")
    os.makedirs(OUT_DIR, exist_ok=True)

    for src_name, slug in CLIPS.items():
        src = os.path.join(SRC_DIR, src_name)
        if not os.path.isfile(src):
            sys.exit(f"Missing source clip: {src}")

        video_out = os.path.join(OUT_DIR, f"{slug}.mp4")
        poster_out = os.path.join(OUT_DIR, f"{slug}_poster.webp")
        print(f"{src_name} -> {slug}.mp4 + {slug}_poster.webp")

        # Normalized, muted, streamable mp4.
        run([
            "ffmpeg", "-y", "-i", src,
            "-vf", f"scale={WIDTH}:-2",
            "-c:v", "libx264",
            "-profile:v", "main",
            "-pix_fmt", "yuv420p",
            "-crf", str(CRF),
            "-preset", "slow",
            "-an",
            "-movflags", "+faststart",
            video_out,
        ])

        # Poster still from roughly the middle of the clip.
        run([
            "ffmpeg", "-y", "-ss", "00:00:01", "-i", src,
            "-frames:v", "1",
            "-vf", f"scale={WIDTH}:-1:flags=lanczos",
            poster_out,
        ])

    # The pre-video pipeline shipped animated-WebP loops; remove any leftovers
    # so only the mp4 + poster pairs stay declared.
    for slug in CLIPS.values():
        stale = os.path.join(OUT_DIR, f"{slug}.webp")
        if os.path.isfile(stale):
            os.remove(stale)
            print(f"removed stale loop: {slug}.webp")

    print("\nDone. Outputs in", os.path.relpath(OUT_DIR, REPO_ROOT))
    total = 0
    for f in sorted(os.listdir(OUT_DIR)):
        size = os.path.getsize(os.path.join(OUT_DIR, f))
        total += size
        print(f"  {f}: {size / 1024:.0f} KB")
    print(f"  total: {total / 1024:.0f} KB")


if __name__ == "__main__":
    main()
