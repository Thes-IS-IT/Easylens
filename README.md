# EasyLens

EasyLens is a Flutter accessibility-assistance application that combines camera
vision, spoken interaction, route guidance, emergency-contact workflows, and an
optional ESP32-CAM stream. The repository contains a functional mobile-focused
prototype with optional cloud and local-AI integrations.

> Vision, route guidance, and SOS features are assistive tools. They are not a
> substitute for mobility aids, situational awareness, professional advice, or
> emergency services.

## Documentation

Start with the [documentation index](docs/README.md).

- [Project overview and setup](docs/source-of-truth/01_project_overview.md)
- [Architecture](docs/source-of-truth/02_architecture.md)
- [Screens and services](docs/source-of-truth/03_screens_and_navigation.md)
- [AI and vision pipeline](docs/source-of-truth/05_ai_ml_pipeline.md)
- [Configuration and security](docs/SECURITY_CONFIGURATION.md)
- [Testing and CI](docs/source-of-truth/09_testing_cicd.md)
- [Known issues and risks](docs/source-of-truth/07_known_issues.md)

## Features represented in the codebase

- Camera-based image labeling, text recognition, ML Kit object detection, and
  packaged TFLite inference paths.
- Buddy, a local-knowledge assistant that can use local Gemma when installed or
  online Gemini when configured.
- GPS map/route guidance using Geolocator, Google Maps rendering, and OSRM.
- Emergency-contact management and Android SMS gateway/device-SMS pathways.
- Speech synthesis/recognition, configurable voice feedback, themes,
  localization, notifications, face registration, and ESP32-CAM MJPEG input.

Feature availability depends on the target platform, runtime permissions,
bundled model assets, network access, and configured third-party credentials.

## Quick start

1. Install Flutter/Dart compatible with the SDK constraint in
   [pubspec.yaml](pubspec.yaml).
2. Create a local `.env` using the variable names in
   [the configuration guide](docs/SECURITY_CONFIGURATION.md). It is optional for
   local/mock-capable flows, but required integrations need their corresponding
   values.
3. Install packages and run the app:

   ```bash
   flutter pub get
   flutter run
   ```

4. Verify your change:

   ```bash
   flutter test
   flutter analyze --no-fatal-warnings --no-fatal-infos
   ```

Use a physical Android device to validate camera, microphone, location,
contacts, SMS, and ESP32 workflows.

## Repository layout

```text
lib/          Flutter application code
assets/       TFLite assets, Buddy knowledge, images, mascot media, sounds
test/         Widget and service tests
docs/         Project and operational documentation
android/      Android runner and permissions
ios/, macos/, linux/, windows/, web/  Other Flutter platform runners
```

## Security

Do not commit `.env` or production keys. The codebase currently contains
credential-like defaults in client configuration; rotate and restrict them
before a public release. In particular, client-side Cloudflare R2 signing is
not appropriate for shipping long-lived storage credentials. See
[configuration and security](docs/SECURITY_CONFIGURATION.md) for the complete
setup and remediation notes.

## License

No license file is currently present in this repository. Add one before
distributing or accepting external contributions.
