# 01 — Project overview

EasyLens is a Flutter application for assistive camera use, voice interaction, route guidance, emergency contacts, and optional ESP32-CAM smart-glasses input. The app targets Android, iOS, macOS, Linux, Windows, and web project shells, although mobile-only packages and permissions mean Android is the most complete configured target in this repository.

## Requirements

- Flutter and Dart compatible with `pubspec.yaml` (`sdk: ^3.11.5`)
- A configured target device/emulator; use physical hardware for camera, microphone, location, contacts, and SMS behavior
- Optional Firebase, Gemini, Maps, SMS, Cloudflare, and ElevenLabs credentials in `.env`; see [configuration](../SECURITY_CONFIGURATION.md)

## Common commands

```bash
flutter pub get
flutter run
flutter test
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter build apk
```

## Repository map

```text
lib/
  main.dart                 application bootstrap and MaterialApp
  screens/                  feature UI
  services/                 device, AI, storage, and cloud coordination
  widgets/                  shared overlays and dialogs
  models/                   application data models
  l10n/                     onboarding strings
  constants/                theme tokens
assets/                     models, knowledge base, images, sounds, mascots
test/                       widget and service tests
docs/                       maintained documentation
android/, ios/, ...         platform runners
```

No `.env.example` is committed. Use the variable list in the configuration guide to create a local `.env`; do not commit it.
