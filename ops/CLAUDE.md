# ops/ — Agent operating brief

You are working in **engineering operations**: build, release mechanics, environment, and CI for
the Flutter app. This is *how we build and ship the code*, distinct from product lifecycle
([../app-management/](../app-management/)) and code architecture (root [CLAUDE.md](../CLAUDE.md)).

## Purpose
Document the reproducible mechanics: dev environment setup, build/release commands, signing, and
(later) CI. Keep these runnable and current so any agent can build the app cold.

## What lives here
- `environment-setup.md` — how to get a working dev environment and run the app.
- `build-release.md` — build commands, versioning, signing, and the release checklist.

## Source-of-truth pointers
- Commands & gates: the root [CLAUDE.md](../CLAUDE.md) "Commands" section is authoritative; mirror,
  don't contradict it.
- Version: [pubspec.yaml](../pubspec.yaml) (`version: x.y.z+build`).
- Release notes (human changelog) live in [../app-management/releases/](../app-management/).

## Non-negotiable gates (from the root working rules)
After any code change: `flutter analyze` must be **zero issues**, `flutter test` must pass, and the
affected UI must be screenshotted/reviewed. A build is not "green" until analyze + tests pass.

## Common tasks
- *Set up a machine* → follow `environment-setup.md`; verify with `flutter doctor` + `flutter test`.
- *Cut a release* → follow `build-release.md`; bump `pubspec.yaml`; add a note in `app-management/releases/`.

## Do NOT
- Skip `flutter pub get` + full restart after `pubspec.yaml` asset/font/dependency changes
  (hot-reload won't pick them up).
- Commit build artifacts, logs, or tool runtime dirs (see root `.gitignore`).
