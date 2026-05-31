# app-management/ — Agent operating brief

You are working in **app management**: the product's lifecycle outside the code — roadmap,
releases, store presence, versioning, and user support.

## Purpose
Track *what's planned, what's shipped, and how the app reaches and serves users*. Pre-launch:
prepare the store listing, release process, and support scaffolding before the first publish.

## What lives here
- `roadmap.md` — near-term priorities and backlog at the product level (not code TODOs).
- `releases/` — release notes / changelog per version. One file per release (`vX.Y.Z.md`).
- `store-listing/` — Play Store metadata: title, descriptions, screenshots manifest, content rating notes.
- `support/` — FAQ, canned responses, known-issues log.

## Key facts to respect
- **Android-first**, offline, no account (see [../docs/PRD.md](../docs/PRD.md)).
- Versioning lives in [pubspec.yaml](../pubspec.yaml) (`version: x.y.z+build`). A release entry here
  must match the `pubspec.yaml` version it describes.
- Build/signing/CI mechanics are **engineering ops** — see [../ops/](../ops/), don't duplicate them here.

## Common tasks & how to do them well
- *Cut a release* → bump `pubspec.yaml` version, add `releases/vX.Y.Z.md` (date, highlights,
  fixes, known issues), confirm the build steps in [../ops/build-release.md](../ops/build-release.md).
- *Draft the store listing* → fill `store-listing/` using marketing copy from
  [../marketing/](../marketing/); keep Play Store character limits.
- *Log a support issue* → append to `support/known-issues.md` with repro + status.

## Do NOT
- Promise features that aren't in the PRD in store copy.
- Duplicate the changelog into git tags only — keep `releases/` as the human-readable record.
