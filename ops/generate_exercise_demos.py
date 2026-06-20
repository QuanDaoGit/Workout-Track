"""Normalize the form-demo clips into app-ready mp4s + poster stills.

The curated program lifts (FULL BODY A Day-1 lifts plus the chest/back lifts
across Full Body / Upper-Lower / PPL) each have a short source .mp4 filed by
muscle group under assets/exercises/animated-videos/<Group>/<Catalog_Id>.mp4
(e.g. Chest/, Back/, Legs/). The app plays them with the video_player
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

# source path (muscle-group subfolder / Catalog_Id.mp4) -> output slug.
# Sources are filed by muscle group under animated-videos/; the filename is the
# exercise's catalog id (matches the keys in lib/data/exercise_demos.dart).
CLIPS = {
    # FULL BODY A (Day-1) lifts.
    "Chest/Barbell_Bench_Press_-_Medium_Grip.mp4": "barbell_bench_press",
    "Back/Wide-Grip_Lat_Pulldown.mp4": "wide_grip_lat_pulldown",
    "Legs/Barbell_Squat.mp4": "barbell_squat",
    "Arms/Dumbbell_Bicep_Curl.mp4": "dumbbell_bicep_curl",
    "Arms/Triceps_Pushdown.mp4": "triceps_pushdown",
    # Remaining chest + back program lifts (Full Body / Upper-Lower / PPL).
    "Chest/Dumbbell_Bench_Press.mp4": "dumbbell_bench_press",
    "Chest/Incline_Dumbbell_Press.mp4": "incline_dumbbell_press",
    "Chest/Barbell_Incline_Bench_Press_-_Medium_Grip.mp4": "barbell_incline_bench_press",
    "Chest/Cable_Crossover.mp4": "cable_crossover",
    "Chest/Dumbbell_Flyes.mp4": "dumbbell_flyes",
    "Back/One-Arm_Dumbbell_Row.mp4": "one_arm_dumbbell_row",
    "Back/Seated_Cable_Rows.mp4": "seated_cable_rows",
    "Back/Close-Grip_Front_Lat_Pulldown.mp4": "close_grip_lat_pulldown",
    "Back/Bent_Over_Barbell_Row.mp4": "bent_over_barbell_row",
    "Back/Straight-Arm_Pulldown.mp4": "straight_arm_pulldown",
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
        src = os.path.join(SRC_DIR, *src_name.split("/"))
        if not os.path.isfile(src):
            sys.exit(f"Missing source clip: {src}")

        video_out = os.path.join(OUT_DIR, f"{slug}.mp4")
        poster_out = os.path.join(OUT_DIR, f"{slug}_poster.webp")

        # Idempotent: skip clips already generated so a re-run only produces the
        # new pairs and leaves committed demo binaries byte-stable.
        if os.path.isfile(video_out) and os.path.isfile(poster_out):
            print(f"{src_name} -> {slug}: skip (exists)")
            continue

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
