# 08 — Coding conventions

## Existing patterns

- Files use `snake_case.dart`; classes use `PascalCase`; private members begin with `_`.
- Services commonly expose a singleton factory, for example `SettingsService()`.
- Prefer `SettingsService`/other relevant `ChangeNotifier` listeners for shared settings. Use local widget state for short-lived screen interactions.
- Use `AppRoute` for page transitions instead of duplicating transition code.
- Keep heavy camera/model work off the interaction path and guard async UI work with `mounted` checks.
- Keep user-visible strings in `TranslationService` or `SignupL10n` rather than adding a new hard-coded English-only UI string.

## Resource handling

Camera/image streams, TTS/STT listeners, timers, and subscriptions must be stopped or cancelled in `dispose`. Do not assume a camera or network service is available; surface a usable fallback/error state.

## Security and safety

Do not add secrets, signed credentials, or personal data to source, docs, logs, or test fixtures. Safety messages should not overstate vision/navigation confidence. Any change to emergency, hazard, or speech behavior needs physical-device testing in addition to unit tests.

The analyzer configuration intentionally suppresses several common diagnostics; run `flutter analyze` and inspect the remaining output rather than assuming a clean exit proves behavior is correct.
