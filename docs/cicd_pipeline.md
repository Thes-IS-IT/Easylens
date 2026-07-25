# CI/CD pipeline

The repository has one GitHub Actions workflow at `.github/workflows/ci_cd.yml`.
It runs on pushes to `main` and pull requests targeting `main`.

1. Checks out the repository.
2. Installs JDK 17 and stable Flutter.
3. Runs `flutter pub get`.
4. Creates an empty `.env` file.
5. Runs `flutter analyze --no-fatal-warnings --no-fatal-infos`.

The workflow does not currently run `flutter test`, build an APK/IPA, publish an
artifact, or deploy an environment. Local verification and release guidance are
in [09 — Testing & CI/CD](source-of-truth/09_testing_cicd.md).
