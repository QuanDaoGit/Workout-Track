"""Normalize the form-demo clips into app-ready mp4s + poster stills.

Single source of truth = the source files on disk. Each form-demo clip is filed
by muscle group under assets/exercises/animated-videos/<Group>/<Catalog_Id>.mp4,
where the filename (without extension) is the exercise's **exact catalog id**
(the `id` in assets/exercises.json, e.g. `Barbell_Bench_Press_-_Medium_Grip`).

This script auto-discovers every source clip, validates its id against the
catalog, and for each produces two id-named outputs in assets/exercises/demos/:

  <Catalog_Id>.mp4    normalized clip (H.264 480p, muted, faststart) for the
                      demo cabinet / fullscreen player
  <Catalog_Id>.webp   a mid-frame still for the static thumbnails and the
                      player's pre-init frame

Because every artifact (source, mp4, poster) shares the catalog id as its
basename, the app derives all demo paths from the id alone — there is no
per-exercise path map to hand-maintain. The script regenerates the list of
which ids have a demo into lib/data/exercise_demos.g.dart.

Source .mp4s stay undeclared (not shipped). Only the generated demos/ files are
declared in pubspec.yaml.

Requires ffmpeg + ffprobe on PATH. Run from anywhere:
    python ops/generate_exercise_demos.py
Adding a new demo: drop <Catalog_Id>.mp4 into the right group folder and re-run.
"""

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = REPO_ROOT / "assets" / "exercises" / "animated-videos"
OUT_DIR = REPO_ROOT / "assets" / "exercises" / "demos"
CATALOG = REPO_ROOT / "assets" / "exercises.json"
GEN_DART = REPO_ROOT / "lib" / "data" / "exercise_demos.g.dart"

# 480p H.264 keeps form legible at small file size; -an strips audio; faststart
# moves the moov atom up so asset playback starts instantly. Source aspect ratio
# is preserved (height -2) — the player letterboxes any ratio over near-black.
WIDTH = 480
CRF = 27


def run(args):
    print("  $", " ".join(str(a) for a in args))
    subprocess.run(args, check=True, capture_output=True)


def catalog_ids():
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    return {item["id"] for item in data}


def discover_sources():
    """Every source clip, sorted by id. id = filename stem."""
    return sorted(SRC_DIR.rglob("*.mp4"), key=lambda p: p.stem)


def write_manifest(ids):
    body = "\n".join(f"  '{i}'," for i in sorted(ids))
    GEN_DART.write_text(
        "// GENERATED FILE — DO NOT EDIT BY HAND.\n"
        "// Regenerate with: python ops/generate_exercise_demos.py\n"
        "//\n"
        "// Every exercise catalog id that has a form-demo clip on disk. The mp4\n"
        "// and poster are derived from the id (see exercise_demos.dart).\n"
        "part of 'exercise_demos.dart';\n"
        "\n"
        "const Set<String> kDemoExerciseIds = {\n"
        f"{body}\n"
        "};\n",
        encoding="utf-8",
    )
    print(f"\nwrote {GEN_DART.relative_to(REPO_ROOT)} ({len(ids)} ids)")


def main():
    if not SRC_DIR.is_dir():
        sys.exit(f"Source dir not found: {SRC_DIR}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    catalog = catalog_ids()
    sources = discover_sources()
    if not sources:
        sys.exit(f"No source clips found under {SRC_DIR}")

    # Validate every source id against the catalog BEFORE encoding so a misnamed
    # clip (e.g. Lying_Leg_Curl vs the catalog's Lying_Leg_Curls) fails loudly
    # instead of producing a demo the app can never resolve.
    bad = [p for p in sources if p.stem not in catalog]
    if bad:
        lines = "\n".join(f"  {p.relative_to(SRC_DIR)} (id '{p.stem}')" for p in bad)
        sys.exit(
            "Source filenames must equal an exercise catalog id "
            f"(assets/exercises.json). Not in catalog:\n{lines}"
        )

    ids = []
    for src in sources:
        ident = src.stem
        ids.append(ident)
        video_out = OUT_DIR / f"{ident}.mp4"
        poster_out = OUT_DIR / f"{ident}.webp"

        # Idempotent: skip clips already generated so a re-run only produces the
        # new pairs and leaves committed demo binaries byte-stable.
        if video_out.is_file() and poster_out.is_file():
            print(f"{src.relative_to(SRC_DIR)} -> {ident}: skip (exists)")
            continue

        print(f"{src.relative_to(SRC_DIR)} -> {ident}.mp4 + {ident}.webp")

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

    # Outputs whose source was removed — report so demos/ can be pruned by hand
    # (never auto-deleted: a committed binary shouldn't vanish on a stray run).
    keep = {f"{i}.mp4" for i in ids} | {f"{i}.webp" for i in ids}
    orphans = sorted(
        p.name for p in OUT_DIR.glob("*") if p.name not in keep
    )
    if orphans:
        print("\norphan outputs (no matching source — remove by hand if stale):")
        for name in orphans:
            print(f"  {name}")

    write_manifest(ids)

    print("\nDone. Outputs in", OUT_DIR.relative_to(REPO_ROOT))
    total = 0
    for f in sorted(OUT_DIR.glob("*")):
        size = f.stat().st_size
        total += size
    print(f"  {len(ids)} demos, {total / 1024:.0f} KB total")


if __name__ == "__main__":
    main()
