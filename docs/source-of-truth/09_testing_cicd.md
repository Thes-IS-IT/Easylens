# 09 — Testing and CI/CD

## Local checks

```bash
flutter test
flutter analyze --no-fatal-warnings --no-fatal-infos
```

At the documentation audit date, `flutter test` passed **17 tests**. The suite covers RAG retrieval/guardrail paths, SMS number formatting, and the welcome widget. The analyzer completed with 10 informational findings and no errors.

## CI

`.github/workflows/ci_cd.yml` runs for pushes to `main` and pull requests to `main`. It installs stable Flutter, runs `flutter pub get`, creates an empty `.env`, and runs the analyzer with warnings and infos non-fatal. It does not run the test suite or create a release artifact.

## Release checklist

1. Run local test and analysis commands.
2. Test denied/approved permissions on a real Android device.
3. Test camera, ESP32 connection loss, voice, location, SOS, and offline/cloud assistant paths appropriate to the release.
4. Verify all production credentials are restricted and no secrets/default keys are bundled.
5. Build the target artifact, for example `flutter build apk`, and test the generated artifact before distribution.
