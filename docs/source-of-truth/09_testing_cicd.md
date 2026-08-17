# 09 — Testing & CI/CD

This document details the testing framework, continuous integration setup, and manual/automated deployment procedures for EasyLens.

---

### 01 — TEST SUITE & VERIFICATION

EasyLens utilizes Flutter's standard testing tools for unit, widget, and integration testing.

#### Running Unit & Widget Tests
To run all tests in the test suite locally:
```bash
flutter test
```

#### Running Static Code Analysis
To verify code formatting, guidelines, and compilation correctness:
```bash
flutter analyze --no-fatal-warnings --no-fatal-infos
```

#### Manual Pre-Release Quality Checklist
Before committing to `main` or building release packages, verify:
- [x] Static code analysis passes with zero severe errors (`flutter analyze`)
- [x] Audio TTS persona switching executes cleanly on Android without binder disconnects
- [x] Camera stream stops cleanly on screen pop (`stopImageStream()`)
- [x] Wakelock stays active during camera and onboarding wizard flows
- [x] Multi-step signup wizard (18 steps) saves profile data (`isForMyself`, `selectedConditions`) to Firestore

---

### 02 — SIMPLIFIED CI/CD & RELEASE FLOWCHART

```mermaid
graph LR
    Commit[Push Commit to Main] --> Actions[GitHub Actions Runner]
    Actions --> Analyze[Run Static Code Analysis]
    Analyze --> Build[Docker Compose & Release Package Generation]
```

---

### 03 — CI/CD GITHUB ACTIONS PIPELINE

The pipeline is defined in [.github/workflows/ci_cd.yml](file:///Users/arronkianparejas/easylens/.github/workflows/ci_cd.yml).

#### Triggers
- **Push events** to the `main` branch.
- **Pull requests** targeting the `main` branch.

#### Jobs & Steps
The CI pipeline is lightweight, focusing on static code analysis to ensure changes build successfully:
1. **Environment Setup**: Initializes standard JDK 17 (Zulu distribution) and the Flutter SDK (`^3.11.5`).
2. **Install Dependencies**: Fetches package dependencies via `flutter pub get`.
3. **Environment Prep**: Creates a mock `.env` file to satisfy dependency imports.
4. **Code Analysis**: Executes `flutter analyze --no-fatal-warnings --no-fatal-infos` to verify formatting, syntax, and type safety constraints.

*Note: Unit tests and automated APK builds have been removed from the CI workflow to optimize runner resources and prevent unnecessary build issues.*

---

### 04 — MANUAL DEPLOYMENT & RELEASE

To compile and package the app for manual release:

#### Build Android release APK
```bash
flutter build apk
```
This compiles the application, treeshakes icons/assets, bundles local LLM assets, and outputs:
- **Location**: `build/app/outputs/flutter-apk/app-release.apk`
- **Output Type**: Production release package (FAT APK containing ARM and x86 binaries).
