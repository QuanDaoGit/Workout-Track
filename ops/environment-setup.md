# Environment Setup — Ironbit

> Seed document. Keep these steps runnable; update when the toolchain changes.

## Prerequisites
- Flutter SDK (matching [pubspec.yaml](../app/pubspec.yaml) `environment: sdk` constraint).
- Android toolchain (Android Studio / SDK) — the app is **Android-first**.
- A device or emulator.

## First-time setup
```bash
flutter doctor          # resolve any reported issues first
flutter pub get         # install dependencies
flutter test            # confirm the suite is green
```

## Run the app
```bash
flutter run             # on a connected device/emulator
```

## After changing pubspec.yaml (assets / fonts / dependencies)
```bash
flutter pub get
# then do a FULL restart — hot-reload won't pick up asset/font changes
```

## Notes
- Persistence is `SharedPreferences` only (no DB to provision); user/training data stays on-device.
- Telemetry (ADR 0001): **Firebase** needs `android/app/google-services.json` + the Google-services
  Gradle plugin; **Sentry** needs a DSN. Keep secrets out of git. The app still runs offline-first —
  it is no longer "no backend / no keys / fully offline".
