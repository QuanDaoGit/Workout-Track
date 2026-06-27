"""Cleanly remove — or replace — one BUILT-IN exercise across the whole app.

DRY-RUN by default: prints the plan plus a unified diff of every file it would
change, and writes NOTHING. Pass --apply to commit.

  python ops/remove_exercise.py <Id>                                 # preview
  python ops/remove_exercise.py <Id> --apply                         # remove
  python ops/remove_exercise.py <Id> --replace-with <Other> --apply  # program lift

Auto touchpoints: assets/exercises.json (the catalog entry), the image folder(s)
from its `images`, lib/data/curated_exercises.dart, lib/data/muscle_splits.dart
(curatedMuscleSplits), the demo trio (animated-videos/<Group>/<Id>.mp4 +
demos/<Id>.mp4 + demos/<Id>.webp) with a manifest regen, and — for a program
lift, REPLACE only — lib/data/programs_library.dart.

Warn-only: lib/services/demo_seed_service.dart (bespoke seed weights — swap by
hand). Never touches persisted user data: workout history snapshots the exercise
name so it still renders; favorites are filtered to the live catalog; pinned
lifts self-heal. Custom exercises live in app storage and are removed in-app via
the exercise editor, not here.

The removal is transactional: all validation runs before any write, deletions
are staged into a backup dir, and any failure rolls everything back.
"""

import argparse
import difflib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "assets" / "exercises.json"
CURATED = ROOT / "lib" / "data" / "curated_exercises.dart"
SPLITS = ROOT / "lib" / "data" / "muscle_splits.dart"
PROGRAMS = ROOT / "lib" / "data" / "programs_library.dart"
SEEDER = ROOT / "lib" / "services" / "demo_seed_service.dart"
MANIFEST = ROOT / "lib" / "data" / "exercise_demos.g.dart"
PUBSPEC = ROOT / "pubspec.yaml"
IMG_ROOT = ROOT / "assets" / "exercises" / "exercises"
DEMO_SRC_ROOT = ROOT / "assets" / "exercises" / "animated-videos"
DEMO_OUT = ROOT / "assets" / "exercises" / "demos"
GENERATOR = ROOT / "ops" / "generate_exercise_demos.py"


def fail(msg):
    sys.exit(f"ERROR: {msg}")


def token(ident):
    """A quoted-exact Dart string token, so 'Barbell_Curl' never matches inside
    'Barbell_Curls' or a longer id."""
    return re.compile(r"'" + re.escape(ident) + r"'")


# ── catalog (assets/exercises.json) ──────────────────────────────────────────

def catalog_trailing(text):
    return text[len(text.rstrip("\n")):]


def dump_catalog(data, trailing):
    return json.dumps(data, indent=2, ensure_ascii=False) + trailing


def assert_format_stable(text):
    """F1 gate: the catalog must round-trip byte-identical, else removing one
    entry would silently reformat all ~870 and bury the real diff. Refuse."""
    data = json.loads(text)
    if dump_catalog(data, catalog_trailing(text)) != text:
        fail(
            "assets/exercises.json is not byte-stable under "
            "json.dump(indent=2, ensure_ascii=False) — removing an entry would "
            "reformat the whole file. Normalize it first, or edit by hand."
        )


# ── Dart source transforms (pure: text in → text out) ─────────────────────────

def curated_removed(text, ident):
    """Drop the standalone list line `    '<id>',` (whole-token match)."""
    line_pat = re.compile(r"^\s*'" + re.escape(ident) + r"',?\s*$")
    out, removed = [], 0
    for line in text.splitlines(keepends=True):
        if line_pat.match(line):
            removed += 1
            continue
        out.append(line)
    return "".join(out), removed


def splits_removed(text, ident):
    """Drop the single-line curatedMuscleSplits entry `'<id>': {...},`."""
    line_pat = re.compile(r"^\s*'" + re.escape(ident) + r"'\s*:.*$\n?", re.MULTILINE)
    new, n = line_pat.subn("", text)
    return new, n


def programs_replaced(text, ident, other):
    """Replace the quoted id token everywhere — this re-keys both the
    suggestedExerciseIds entry and the prescription key (both quote the id),
    preserving the SetRepScheme value."""
    new, n = token(ident).subn("'" + other + "'", text)
    return new, n


def pubspec_without(text, folder_names):
    """Drop the per-folder `- assets/exercises/exercises/<name>/` asset
    declarations. Image folders are declared individually in pubspec (Flutter
    asset dirs are non-recursive), so a removed folder MUST lose its line or
    `flutter build` fails on the missing directory."""
    targets = {f"assets/exercises/exercises/{n}/" for n in folder_names}
    out, removed = [], 0
    for line in text.splitlines(keepends=True):
        s = line.strip()
        if s.startswith("- ") and s[2:].strip() in targets:
            removed += 1
            continue
        out.append(line)
    return "".join(out), removed


def program_days_with(text, ident):
    """suggestedExerciseIds blocks that contain the id token (for the
    replacement collision check)."""
    blocks = re.findall(r"suggestedExerciseIds:\s*\[(.*?)\]", text, re.DOTALL)
    return [b for b in blocks if token(ident).search(b)]


def unified(path, old, new):
    return "".join(
        difflib.unified_diff(
            old.splitlines(keepends=True),
            new.splitlines(keepends=True),
            fromfile=str(path.relative_to(ROOT)),
            tofile=str(path.relative_to(ROOT)) + " (after)",
        )
    )


# ── demo + image discovery ────────────────────────────────────────────────────

def demo_source(ident):
    hits = [p for p in DEMO_SRC_ROOT.rglob("*.mp4") if p.stem == ident]
    return hits[0] if hits else None


def image_dirs(entry):
    """Unique image folders referenced by the catalog entry's `images`."""
    dirs = []
    for rel in entry.get("images", []):
        folder = IMG_ROOT / Path(rel).parts[0]
        if folder not in dirs:
            dirs.append(folder)
    return dirs


def _commit(changes, deletions, regen_demo, verify_gone=()):
    """Transactional apply shared by single + batch removal: write every text
    edit, stage every deletion into a backup dir, optionally regenerate the demo
    manifest — and roll EVERYTHING back on any exception. [verify_gone] is the
    ids that must NOT survive in the regenerated manifest (single + batch)."""
    text_targets = [MANIFEST] + [p for p, _, _ in changes]
    originals = {p: p.read_text(encoding="utf-8") for p in text_targets if p.exists()}
    backup = Path(tempfile.mkdtemp(prefix="remove_exercise_"))
    moved = []  # (original_path, backup_path)

    def stage_delete(path):
        path = Path(path)
        if path.exists():
            dest = backup / f"{len(moved)}_{path.name}"
            shutil.move(str(path), str(dest))
            moved.append((path, dest))

    try:
        for path, _old, new in changes:
            path.write_text(new, encoding="utf-8")
        for d in deletions:
            stage_delete(d)
        if regen_demo:
            # ffmpeg-free in the removal case: remaining sources already have
            # outputs, so the generator only rewrites the manifest.
            subprocess.run([sys.executable, str(GENERATOR)],
                           check=True, capture_output=True)
            manifest = MANIFEST.read_text(encoding="utf-8")
            still = [i for i in verify_gone if token(i).search(manifest)]
            if still:
                raise RuntimeError(f"manifest still lists after regen: {still}")
    except Exception as exc:  # noqa: BLE001 — restore on ANY failure
        for path, original in originals.items():
            path.write_text(original, encoding="utf-8")
        for path, dest in moved:
            shutil.move(str(dest), str(path))
        shutil.rmtree(backup, ignore_errors=True)
        fail(f"apply failed and was rolled back: {exc}")
    shutil.rmtree(backup, ignore_errors=True)  # commit deletions


def run_batch(list_path, apply):
    """Remove every id in [list_path] (one per line, # comments ok) in ONE
    transactional pass. Refuses program lifts (batch can't choose a replacement)
    — handle those individually with --replace-with."""
    ids = [l.strip() for l in Path(list_path).read_text(encoding="utf-8").splitlines()
           if l.strip() and not l.strip().startswith("#")]
    if not ids:
        fail(f"no ids in {list_path}")

    catalog_text = CATALOG.read_text(encoding="utf-8")
    assert_format_stable(catalog_text)
    data = json.loads(catalog_text)
    cat_ids = {e["id"] for e in data}
    idset = set(ids)
    unknown = sorted(idset - cat_ids)
    if unknown:
        fail(f"{len(unknown)} id(s) not in the catalog, e.g. {unknown[:5]}")

    programs_text = PROGRAMS.read_text(encoding="utf-8")
    prog_hit = sorted(i for i in idset if token(i).search(programs_text))
    if prog_hit:
        fail(f"{len(prog_hit)} id(s) are used by preset programs — batch removal "
             f"can't replace them. Handle individually with --replace-with: "
             f"{prog_hit[:5]}{' ...' if len(prog_hit) > 5 else ''}")

    new_data = [e for e in data if e["id"] not in idset]
    changes = [(CATALOG, catalog_text,
                dump_catalog(new_data, catalog_trailing(catalog_text)))]

    curated_text = CURATED.read_text(encoding="utf-8")
    new_curated, n_cur = curated_text, 0
    for i in idset:
        new_curated, n = curated_removed(new_curated, i)
        n_cur += n
    if n_cur:
        changes.append((CURATED, curated_text, new_curated))

    splits_text = SPLITS.read_text(encoding="utf-8")
    new_splits, n_spl = splits_text, 0
    for i in idset:
        new_splits, n = splits_removed(new_splits, i)
        n_spl += n
    if n_spl:
        changes.append((SPLITS, splits_text, new_splits))

    deletions, demo_ids, n_imgdirs, folder_names = [], [], 0, []
    for e in data:
        if e["id"] in idset:
            dirs = image_dirs(e)
            n_imgdirs += len(dirs)
            deletions += dirs
            for d in dirs:
                folder_names.append(d.name)
                deletions.append(IMG_ROOT / f"{d.name}.json")  # dataset sibling
            src = demo_source(e["id"])
            if src or (DEMO_OUT / f"{e['id']}.mp4").exists():
                demo_ids.append(e["id"])
                if src:
                    deletions.append(src)
                deletions += [DEMO_OUT / f"{e['id']}.mp4", DEMO_OUT / f"{e['id']}.webp"]

    pubspec_text = PUBSPEC.read_text(encoding="utf-8")
    new_pubspec, n_pub = pubspec_without(pubspec_text, folder_names)
    if n_pub:
        changes.append((PUBSPEC, pubspec_text, new_pubspec))

    print(f"== BATCH REMOVE {len(idset)} exercises ({len(data)} -> {len(new_data)}) ==")
    print(f"  curated lines removed:  {n_cur}")
    print(f"  split entries removed:  {n_spl}")
    print(f"  pubspec decls removed:  {n_pub}")
    print(f"  image folders deleted:  {n_imgdirs}")
    print(f"  demo clips removed:     {len(demo_ids)}")
    print(f"  survivors:              {len(new_data)}")
    print("  ( persisted user data — history / favorites / pins — left untouched )")

    if not apply:
        print("\nDRY RUN — nothing written. Re-run with --apply, then `flutter test`.")
        return
    _commit(changes, deletions, regen_demo=bool(demo_ids), verify_gone=demo_ids)
    print(f"APPLIED. Removed {len(idset)} exercises; {len(new_data)} remain. "
          "Run `flutter analyze` + `flutter test`.")


def main():
    ap = argparse.ArgumentParser(description="Cleanly remove a built-in exercise.")
    ap.add_argument("id", nargs="?", help="exercise catalog id, e.g. Around_The_Worlds")
    ap.add_argument("--replace-with", dest="replace", metavar="OtherId",
                    help="required when the exercise is used by a preset program")
    ap.add_argument("--from-file", dest="from_file", metavar="PATH",
                    help="batch: remove every id listed in the file (one per line)")
    ap.add_argument("--apply", action="store_true", help="write changes (default: dry run)")
    args = ap.parse_args()

    if args.from_file:
        if args.id or args.replace:
            fail("--from-file is batch removal; don't combine it with an id or "
                 "--replace-with.")
        run_batch(args.from_file, args.apply)
        return
    if not args.id:
        fail("provide an exercise id, or --from-file <list> for batch removal.")
    ident, other = args.id, args.replace

    # ── Phase 1: load + validate everything (no writes) ──────────────────────
    catalog_text = CATALOG.read_text(encoding="utf-8")
    assert_format_stable(catalog_text)
    data = json.loads(catalog_text)
    ids = {e["id"] for e in data}
    if ident not in ids:
        fail(f"'{ident}' is not in assets/exercises.json. If it is a CUSTOM "
             "exercise it lives in app storage — remove it in-app via the "
             "exercise editor, not with this script.")
    entry = next(e for e in data if e["id"] == ident)

    curated_text = CURATED.read_text(encoding="utf-8")
    splits_text = SPLITS.read_text(encoding="utf-8")
    programs_text = PROGRAMS.read_text(encoding="utf-8")
    seeder_text = SEEDER.read_text(encoding="utf-8")

    in_programs = bool(token(ident).search(programs_text))
    if in_programs and not other:
        fail(f"'{ident}' is used by a preset program. A program lift must be "
             "REPLACED, not removed — re-run with --replace-with <OtherId>.")
    if other:
        if not in_programs:
            fail(f"'{ident}' is not used by any program; drop --replace-with "
                 "to remove it outright.")
        if other not in ids:
            fail(f"--replace-with '{other}' is not a catalog id.")
        for block in program_days_with(programs_text, ident):
            if token(other).search(block):
                fail(f"'{other}' already appears in a program day that uses "
                     f"'{ident}' — replacing would duplicate it. Pick another.")

    # Compute the new file contents.
    changes = []  # (path, old, new)
    new_data = [e for e in data if e["id"] != ident]
    assert len(new_data) == len(data) - 1
    changes.append((CATALOG, catalog_text,
                    dump_catalog(new_data, catalog_trailing(catalog_text))))

    new_curated, n_curated = curated_removed(curated_text, ident)
    if n_curated:
        changes.append((CURATED, curated_text, new_curated))
    new_splits, n_splits = splits_removed(splits_text, ident)
    if n_splits:
        changes.append((SPLITS, splits_text, new_splits))
    if other:
        new_programs, n_prog = programs_replaced(programs_text, ident, other)
        if token(ident).search(new_programs):
            fail("internal: id token still present after program replacement.")
        changes.append((PROGRAMS, programs_text, new_programs))

    src = demo_source(ident)
    demo_video = DEMO_OUT / f"{ident}.mp4"
    demo_poster = DEMO_OUT / f"{ident}.webp"
    has_demo = src is not None or demo_video.exists() or demo_poster.exists()
    imgs = image_dirs(entry)
    folder_names = [d.name for d in imgs]
    json_sibs = [IMG_ROOT / f"{n}.json" for n in folder_names]
    pubspec_text = PUBSPEC.read_text(encoding="utf-8")
    new_pubspec, n_pub = pubspec_without(pubspec_text, folder_names)
    if n_pub:
        changes.append((PUBSPEC, pubspec_text, new_pubspec))
    in_seeder = bool(token(ident).search(seeder_text))

    # ── Report ────────────────────────────────────────────────────────────────
    verb = f"REPLACE with '{other}'" if other else "REMOVE"
    print(f"== {verb}: {ident} ({entry.get('name', '?')}) ==\n")
    print("Touchpoints:")
    print(f"  [x] assets/exercises.json            ({len(data)} -> {len(new_data)} entries)")
    if imgs:
        joined = ", ".join(str(d.relative_to(ROOT)) for d in imgs)
        print(f"  [x] image folder(s)                  {joined}")
    else:
        print("  [ ] image folder(s)                  (none)")
    print(f"  [{'x' if n_curated else ' '}] curated_exercises.dart           "
          f"({n_curated} line)")
    print(f"  [{'x' if n_splits else ' '}] muscle_splits.dart               "
          f"({n_splits} entry)")
    print(f"  [{'x' if n_pub else ' '}] pubspec.yaml asset decl          "
          f"({n_pub} line)")
    if has_demo:
        print(f"  [x] demo trio + manifest regen       "
              f"{src.relative_to(ROOT) if src else '(source missing)'}")
    else:
        print("  [ ] demo                             (none)")
    if other:
        print(f"  [x] programs_library.dart            ({n_prog} token(s) -> '{other}')")
    elif in_programs:
        print("  [!] programs_library.dart            REFERENCED (needs --replace-with)")
    if in_seeder:
        print("  [!] demo_seed_service.dart           WARN: seeds this id — swap "
              "the _Move by hand (bespoke weights); dev-only marketing seeder.")
    print("\n  ( persisted user data — history / favorites / pins — left untouched )\n")

    for path, old, new in changes:
        diff = unified(path, old, new)
        if diff:
            print(diff if len(diff) < 4000 else diff[:4000] + "\n  ...(diff truncated)\n")

    if not args.apply:
        print("DRY RUN — nothing written. Re-run with --apply to commit, then "
              "`flutter test`.")
        return

    # ── Phase 2: apply (transactional) ───────────────────────────────────────
    deletions = list(imgs) + json_sibs
    if has_demo:
        deletions += [src, demo_video, demo_poster]
    _commit(changes, deletions, regen_demo=has_demo, verify_gone=[ident])
    print(f"APPLIED. Removed '{ident}'"
          + (f", replaced with '{other}' in programs." if other else ".")
          + " Run `flutter analyze` + `flutter test`.")


if __name__ == "__main__":
    main()
