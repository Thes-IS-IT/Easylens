# 08 — Coding Conventions

## Patterns to Follow

### 1. Singleton Services
All services use the Dart singleton factory pattern:

```dart
class MyService {
  static final MyService _instance = MyService._internal();
  factory MyService() => _instance;
  MyService._internal();
}
```

**Never** use `new MyService()` — always use `MyService()` which returns the singleton.

---

### 2. State Management
- `SettingsService` extends `ChangeNotifier` and is the **only** service that notifies the UI directly
- Screens use `ListenableBuilder(listenable: SettingsService(), ...)` for reactive rebuilds
- Other services store state internally and expose it via getters
- Camera screen uses `setState()` directly for frame-by-frame UI updates (bounding boxes, labels)

---

### 3. Navigation
Always use the custom route wrapper:

```dart
Navigator.push(context, AppRoute.to(TargetScreen()));
```

When navigating away from `HardwareScreen`, always use `_navigateTo()` which:
1. Sets `_isPaused = true`
2. Stops TTS
3. Pushes route
4. Sets `_isPaused = false` on return

---

### 4. Camera Frame Processing
**Critical rules** — violating these causes OOM crashes:

- ✅ Always check `if (_isProcessingFrame) return;` before processing
- ✅ Always check `if (!mounted) return;` in async callbacks
- ✅ Always call `stopImageStream()` before `dispose()`
- ✅ Navigation mode: only run object detection, skip image labeling
- ✅ Use 400ms cooldown between frames
- ❌ Never run two ML Kit detectors on the same frame in navigation mode
- ❌ Never remove the `_isProcessingFrame` lock
- ❌ Never reduce the 400ms cooldown below 300ms

---

### 5. TTS Speech
Always use `TtsService().speak()` — never directly call `FlutterTts`:

```dart
if (!_isContinuousVoiceEnabled) {
  TtsService().speak("Your message");
}
```

- Always gate TTS on `!_isContinuousVoiceEnabled` to respect the user's voice output toggle
- Use speech cooldowns to prevent spamming (see Walking Navigation doc)

---

### 6. Localization
Use `TranslationService.translate()` for all user-facing strings:

```dart
final label = TranslationService.translate('key_name', SettingsService().selectedLanguage);
```

For navigation warnings, use the `isTagalog` boolean pattern:

```dart
final lang = SettingsService().selectedLanguage;
final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
final message = isTagalog ? 'Tagalog text' : 'English text';
```

---

### 7. SharedPreferences Keys
Tutorial dismissal flags follow this pattern:

```
tutorial_dismissed_<screenKey>
```

Examples: `tutorial_dismissed_dashboard`, `tutorial_dismissed_camera`, `tutorial_dismissed_rag_chat`, `tutorial_dismissed_settings`

---

### 8. Error Handling
- Wrap ML Kit calls in `try/catch` — they can throw on malformed images
- Wrap Firebase calls in `try/catch` — network failures are expected
- Use `print()` for debug logging (acceptable since this is a mobile app, not production server code)
- Always check `mounted` before `setState` in async callbacks

---

## Anti-Patterns to Avoid

| ❌ Anti-Pattern | ✅ Correct Approach |
|---|---|
| Calling `_cameraController?.dispose()` without stopping the stream first | Call `stopImageStream()` → then `dispose()` |
| Running image labeling + object detection per frame in navigation mode | Only run object detection in navigation mode |
| Using `setVoice()` on Android | Skip `setVoice()` on Android, use `setLanguage()` only |
| Creating `ObjectDetector` with `CustomObjectDetectorOptions(localModel: ...)` | Use base `ObjectDetectorOptions` |
| Calling `setState` without checking `mounted` | Always `if (mounted) setState(...)` |
| Hardcoding English strings in TTS | Use `isTagalog` conditional or `TranslationService.translate()` |

---

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Files | `snake_case.dart` | `hardware_screen.dart` |
| Classes | `PascalCase` | `HardwareScreen` |
| Private methods | `_camelCase` | `_processObjectResults` |
| Constants | `camelCase` | `primaryColor` |
| Service singletons | `PascalCase` + factory | `TtsService()` |
| Screen keys | `snake_case` | `tutorial_dismissed_camera` |
| HUD modes | `HudMode.camelCase` enum | `HudMode.navigation` |
