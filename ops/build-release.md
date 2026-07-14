# Build & Release — Ironbit

> Seed document. Android-first. Update signing details once a keystore exists.

## Quality gates (must pass before any build is "green")
```bash
flutter analyze         # zero issues required
flutter test            # all tests pass
```

## Versioning
- Single source: [pubspec.yaml](../app/pubspec.yaml) → `version: x.y.z+build`.
- Bump `x.y.z` for user-facing releases; bump `+build` for every store upload.
- Record the human changelog in [../app-management/releases/vX.Y.Z.md](../app-management/).

## Build
```bash
flutter build apk           # APK (sideload / testing)
flutter build appbundle     # AAB (Play Store submission)
```

## Signing (to be configured before first publish)
- [ ] Create an upload keystore (kept OUT of git).
- [ ] Wire `android/key.properties` + `android/app/build.gradle` signingConfig.
- [ ] Confirm the keystore is backed up securely (loss = cannot update the app).

## Release checklist
1. Gates pass (`analyze` + `test`).
2. `pubspec.yaml` version bumped.
3. Signed AAB built.
4. `app-management/releases/vX.Y.Z.md` written.
5. Store listing current ([../app-management/store-listing/](../app-management/)).
6. (If adopted) crash-mapping upload — see [../statistics/instrumentation-plan.md](../statistics/instrumentation-plan.md).

## Symbolication note
If/when a crash reporter is adopted, upload the R8/ProGuard mapping (`build/app/outputs/mapping/`)
per release so stack traces are readable. No reporter is wired today.
