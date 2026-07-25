# 10 — Localization

EasyLens uses local static maps rather than Flutter's generated `intl`/ARB pipeline.

- `lib/services/translation_service.dart` provides general screen and feature strings.
- `lib/l10n/signup_strings.dart` exposes `SignupL10n` for onboarding strings.
- `SettingsService.selectedLanguage` stores the selection. Consumers commonly rebuild from the settings notifier.
- `TtsService` and `RagService` use the active setting when choosing voice/model behavior, but actual speech locale and response language depend on platform voices and configured model paths.

## Adding a language

1. Add complete key coverage in both relevant local maps.
2. Add the option to the onboarding/settings UI.
3. Update any language-name/code matching in services that need it.
4. Verify layout at large text sizes and validate TTS on each supported platform.
5. Test assistant responses and navigation directives in the added language.

Do not document a voice or model as guaranteed for a locale until it has been tested with the deployed platform and credentials.
