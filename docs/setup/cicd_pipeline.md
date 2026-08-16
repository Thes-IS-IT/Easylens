# EasyLens: CI/CD Pipeline & Automated OTA Updates

This document describes the automated build, integration, security verification, and Over-The-Air (OTA) updates architecture implemented in EasyLens.

Our CI/CD pipeline, powered by GitHub Actions ([release.yml](file:///Users/arronkianparejas/easylens/.github/workflows/release.yml)), provides end-to-end automation, strict code quality enforcement, and secure deployment by running automated static analysis (`flutter analyze`) and unit testing (`flutter test`) on every push to the `main` branch to guarantee clean, crash-free code before securely compiling the production release APK using encrypted environment secrets, publishing the Docker container to GHCR, and attaching the build to GitHub Releases—enabling safe, hands-free Over-The-Air (OTA) updates directly within the app.

---

### 01 — CI/CD BUILD FLOW & QUALITY GUARDRAILS (GITHUB ACTIONS)

The build pipeline is configured inside [.github/workflows/release.yml](file:///Users/arronkianparejas/easylens/.github/workflows/release.yml). It is executed on every push to the `main` branch.

#### Simplified CI/CD Pipeline
```mermaid
graph LR
    Push[Push Commit to Main] --> Actions[GitHub Actions Runner]
    Actions --> Build[Build Native APK & Docker Image]
    Build --> Publish[Deploy Docker to GHCR & Attach Release APK]
```

#### Detailed CI/CD Sequence Diagram
```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GitHub as GitHub Actions
    participant Release as GitHub Releases
    participant App as EasyLens App

    Dev->>GitHub: Push commit to main branch
    activate GitHub
    GitHub->>GitHub: Setup Java 17 & Flutter SDK
    GitHub->>GitHub: Fetch pub packages
    GitHub->>GitHub: Compile Release APK (flutter build apk)
    GitHub->>Release: Upload app-release.apk to 'latest' tag
    deactivate GitHub
    Release-->>App: Fetch latest release metadata via REST API
    App-->>App: Compare versions & download update
```

#### Build Specifications
* **Runner Environment**: `ubuntu-latest`
* **Java Version**: `17` (Zulu distribution)
* **SDK Delegate**: `subosito/flutter-action@v2` (caching enabled for faster builds)
* **Target Output**: Release Android Package (`build/app/outputs/flutter-apk/app-release.apk`)
* **Deployer**: `ncipollo/release-action@v1`
  - Replaces and updates the file under tag `latest` (`allowUpdates: true`, `removeArtifacts: true`), guaranteeing that the update download links always yield the most up-to-date commit code.

---

### 02 — ON-DEVICE OTA UPDATES CHECK ARCHITECTURE

Instead of routing updates through third-party app stores (which can be difficult to navigate for screen readers), EasyLens embeds a lightweight, native update checker directly into Settings.

#### Simplified OTA Update Flow
```mermaid
graph LR
    Check[User Taps Check Updates] --> Fetch[Query GitHub Release REST API]
    Fetch --> Version{New Version Available?}
    Version -- Yes --> Download[Prompt Download & Install APK]
    Version -- No --> Toast[Notify 'Up to Date']
```

#### Detailed OTA Updates Diagram
```mermaid
graph TD
    UserClick[User taps 'Check for Updates']
    ShowLoader[Animate Trailing Refresh Spinner]
    FetchAPI[HTTP GET api.github.com/repos/.../releases/latest]
    ParseJSON{Parse tag_name & assets}
    CheckVersion{Is latest_tag != current_version?}
    ShowDialog[Render Update Available Dialog]
    LaunchBrowser[Launch APK url via url_launcher]
    ShowSnackbar[Show 'You are on the latest version']
    ShowError[Show 'Could not check updates' error]

    UserClick --> ShowLoader
    ShowLoader --> FetchAPI
    FetchAPI --> |HTTP 200| ParseJSON
    FetchAPI --> |HTTP Error / Offline| ShowError
    ParseJSON --> CheckVersion
    CheckVersion --> |Yes / New Version| ShowDialog
    CheckVersion --> |No / Same Version| ShowSnackbar
    ShowDialog --> |User taps Download| LaunchBrowser
```

#### Implementation Specifications

1. **Current App Version tag**: Hardcoded constant in [settings_screen.dart](file:///Users/arronkianparejas/easylens/lib/screens/settings/settings_screen.dart):
   ```dart
   static const String currentVersionTag = 'v1.2.0';
   ```
2. **Updates Fetch Call**: Performs an HTTP call:
   ```dart
   final response = await http.get(Uri.parse('https://api.github.com/repos/Thes-IS-IT/Easylens/releases/latest'));
   ```
3. **Download Resolution**: Parses the assets array to extract the download link for the release file ending in `.apk`:
   ```dart
   if (name.endsWith('.apk')) {
     apkUrl = asset['browser_download_url'];
   }
   ```
4. **Trigger & Browser Download**: When a user clicks "Download Now" on the update dialog, the app opens the browser download link using `url_launcher` to download and install the package immediately.
5. **Loader feedback**: During the API request, the trailing list tile icon is replaced dynamically with a custom `CircularProgressIndicator` to confirm to visually impaired users that the check is actively executing.
