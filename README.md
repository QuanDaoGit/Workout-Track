# Ironbit

A workout tracker with an RPG character-growth layer: every rep you log feeds a character you become
attached to.
Flutter, **Android-first**, fully **offline** — no account, no cloud, no tracking. Pre-launch.

> **Soul doctrine:** every logged workout should make your character feel harder to abandon.
> Real training is the fuel; identity, streak, rank, loot, and ritual are the psychological engine.

## What it does
Log workouts (muscle group → exercises → sets/reps/weight); the app derives a readable character
profile (STR/AGI/END radar, VIT recovery, LCK streak), levels you up, runs quests/loot/guild, and suggests progressive
overload. The hook is long-term attachment: visible progress, named identity, rank aspiration,
collection pull, and a repeatable return ritual, all stored locally via `SharedPreferences`.

## Repository layout

This root is a **whole product workspace**, not just the app. Code and business/ops domains live
side by side; each non-code folder has its own `CLAUDE.md` (agent brief) + `README.md`.

```
workout_track/
├── lib/  test/  android/  ios/  web/  assets/  fonts/   # the Flutter app
├── docs/            # product source of truth — PRD, PRODUCT, specs/plans, decisions
├── design/          # visual identity, UX guidelines, screenshots
├── marketing/       # positioning, copy, campaigns, marketing assets
├── app-management/  # roadmap, releases/changelog, store listing, support
├── statistics/      # analytics, metrics, observability planning (no data yet)
├── research/        # user + competitive research
├── ops/             # build, release, environment, CI mechanics
├── CLAUDE.md        # agent brief for code work (architecture, theme, conventions)
└── AGENTS.md        # Codex entry point → defers to CLAUDE.md + docs/
```

## Getting started

```bash
flutter pub get     # install dependencies
flutter test        # run the suite (40+ test files)
flutter run         # launch on a device/emulator
flutter analyze     # lint — zero issues is the bar
```

Full setup and release steps: [ops/environment-setup.md](ops/environment-setup.md) and
[ops/build-release.md](ops/build-release.md).

## Where to read next
- **Product scope & intent:** [docs/PRD.md](docs/PRD.md)
- **Mechanics & rationale:** [docs/PRODUCT.md](docs/PRODUCT.md)
- **Architecture & theme:** [CLAUDE.md](CLAUDE.md)
- **Design rules:** [design/](design/)
