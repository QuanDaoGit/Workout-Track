# AGENTS.md

Guidance for Codex (and other coding agents) working in this repository. The detailed
**architecture and theme truth lives in [CLAUDE.md](CLAUDE.md) and [docs/](docs/)** — this file
holds the working rules and points to the canonical sources, so the two never drift apart again.

## Working Rules

**Before starting any task:**
- Read [docs/PRD.md](docs/PRD.md) for scope and intent.
- Ask clarifying questions until 95% confident. Do not make any assumptions.

**After every major step:**
1. Run `flutter analyze` — zero issues required.
2. Run `flutter test` if tests exist.
3. Always screenshot the affected UI section.
4. Review: theme coherence, design consistency, functionality correctness.
5. Fix all issues before proceeding.

**Always:**
- One change at a time. Never rewrite whole files unless explicitly asked.
- State after each change: what changed, which file, what to test.
- Never build features outside [docs/PRD.md](docs/PRD.md) without asking first.

---

## Commands

```bash
flutter pub get          # Install/update dependencies
flutter run              # Run on connected device/emulator
flutter analyze          # Lint (zero issues is the bar)
flutter test             # Run tests
flutter build apk        # Build Android APK
```

After changing `pubspec.yaml` (assets, fonts, dependencies), run `flutter pub get` and do a
**full restart** — hot-reload won't pick up asset/font changes.

---

## Canonical sources (link, do not duplicate)

| You need… | Read |
|---|---|
| Architecture, services, persistence, app boot sequence | [CLAUDE.md](CLAUDE.md) |
| Theme tokens, icon rules, motion | [CLAUDE.md](CLAUDE.md) "Theme Conventions" + `lib/theme/tokens.dart` |
| Product scope & intent | [docs/PRD.md](docs/PRD.md) |
| Product doctrine + mechanics rationale (long-term hooks, stats, classes, overload) | [docs/PRODUCT.md](docs/PRODUCT.md) |
| Design / UX / brand rules | [design/](design/) |
| Build & release mechanics | [ops/](ops/) |

> History note: earlier versions of this file inlined an architecture + palette snapshot that went
> stale — it described the old `0xFF0D0D1A` palette and removed files (`pages/home.dart`,
> `pages/start_workout.dart`). That snapshot was removed on 2026-05-31 to keep a single source of
> truth. Use the links above. Never hard-code palette hex — import `lib/theme/tokens.dart`.

---

## Workspace Map

The project root wraps the whole product, not just the app code. Each non-code folder has its own
`CLAUDE.md` (agent brief) + `README.md` — read a folder's brief before working in it.

| Folder | Purpose |
|---|---|
| `lib/` `test/` `android/` `ios/` `assets/` … | The Flutter app (code). |
| `docs/` | Product source of truth — PRD, PRODUCT, specs/plans, decisions. |
| `design/` | Visual identity, UX guidelines, screenshots. |
| `marketing/` | Positioning, copy, campaigns, marketing assets. |
| `app-management/` | Roadmap, releases/changelog, store listing, support. |
| `statistics/` | Analytics, metrics, observability planning (pre-launch, no data yet). |
| `research/` | User + competitive research. |
| `ops/` | Build, release, environment, CI mechanics. |

---

## Execution Mode
Skip planning confirmation. Execute immediately without asking for approval to proceed from plan
to implementation.
