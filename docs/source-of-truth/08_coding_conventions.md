# 08 — Coding Conventions

---

### 01 — PATTERNS TO FOLLOW

#### 1. Singleton Services
All services use the Dart singleton factory pattern:

```dart
class MyService {
  static final MyService _instance = MyService._internal();
  factory MyService() => _instance;
  MyService._internal();
}
```

Never use `new MyService()` — always use `MyService()` which returns the singleton.

#### 2. State Management
- `SettingsService` extends `ChangeNotifier` and is the **only** service that notifies the UI directly
- Screens use `ListenableBuilder(listenable: SettingsService(), ...)` for reactive rebuilds
- Other services store state internally and expose it via getters
- Camera screen uses `setState()` directly for frame-by-frame UI updates (bounding boxes, labels)

#### 3. Navigation & Screen Modularization
Always use the custom route wrapper:

```dart
Navigator.push(context, AppRoute.to(TargetScreen()));
```

When navigating away from `HardwareScreen`, always use `_navigateTo()` which:
1. Sets `_isPaused = true`
2. Stops TTS
3. Pushes route
4. Sets `_isPaused = false` on return

For large screens like `HardwareScreen`, split UI modules into separate components inside a `components/` subfolder (e.g., `hud_controls_panel.dart`, `hud_mode_selector.dart`, `hud_camera_view.dart`, `pairing_wizard.dart`).

#### 4. Camera Frame Processing & Power Management
Critical rules — violating these causes OOM crashes or frame drops:

- Always check `if (_isProcessingFrame) return;` before processing
- Always check `if (!mounted) return;` in async callbacks
- Always call `stopImageStream()` before `dispose()`
- Navigation mode: alternate object detection and labeling on separate frames (staggered 400ms cycles)
- Use 400ms cooldown between frames
- Enable `WakelockPlus` during continuous camera monitoring and multi-step onboarding
- Never run two ML Kit detectors concurrently on the exact same frame in navigation mode
- Never remove the `_isProcessingFrame` lock
- Never reduce the 400ms cooldown below 300ms

#### 5. TTS Speech & Pitch Safety
Always use `TtsService().speak()` — never directly call `FlutterTts`:

```dart
if (!_isContinuousVoiceEnabled) {
  TtsService().speak("Your message");
}
```

- Always gate TTS on `!_isContinuousVoiceEnabled` to respect the user's voice output toggle
- Use speech cooldowns to prevent spamming (see Walking Navigation doc)
- On Android, enforce pitch range limits between `0.5` and `2.0` to avoid native binder connection crashes (`DeadObjectException`)

#### 6. Localization & Signup Strings
Use `TranslationService.translate()` for general app strings and `SignupStrings` for onboarding wizard steps:

```dart
final label = TranslationService.translate('key_name', SettingsService().selectedLanguage);
```

For navigation warnings and signup steps, use the `isTagalog` boolean pattern or static lookup map:

```dart
final lang = SettingsService().selectedLanguage;
final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
final message = isTagalog ? 'Tagalog text' : 'English text';
```

#### 7. Notification Persistence Rules
To maintain zero-lag main thread performance:
- Transient obstacle warnings and ambient scenery descriptions are memory/UI only
- Write **only** critical safety alerts containing `"STOP"`, `"FIRE"`, `"HAZARD"`, or `"EMERGENCY"` to `SharedPreferences`
- Do not write frame-by-frame walking guidance or obstacle state changes to persistent disk storage

#### 8. SharedPreferences Keys
Tutorial dismissal flags follow this pattern:

```
tutorial_dismissed_<screenKey>
```

Examples: `tutorial_dismissed_dashboard`, `tutorial_dismissed_camera`, `tutorial_dismissed_rag_chat`, `tutorial_dismissed_settings`

#### 9. Error Handling
- Wrap ML Kit calls in `try/catch` — they can throw on malformed images
- Wrap Firebase calls in `try/catch` — network failures are expected
- Use `print()` for debug logging (acceptable since this is a mobile app, not production server code)
- Always check `mounted` before `setState` in async callbacks

---

### 02 — ANTI-PATTERNS TO AVOID

| Anti-Pattern | Correct Approach |
|---|---|
| Calling `_cameraController?.dispose()` without stopping the stream first | Call `stopImageStream()` → then `dispose()` |
| Running image labeling + object detection concurrently on same frame | Stagger processing on alternating 400ms frames |
| Setting TTS pitch below 0.5 or above 2.0 on Android | Clamp pitch safely to `[0.5, 2.0]` |
| Persisting every transient obstacle warning to SharedPreferences | Persist only critical safety alerts (`STOP`, `FIRE`, `HAZARD`, `EMERGENCY`) |
| Creating `ObjectDetector` with `CustomObjectDetectorOptions(localModel: ...)` | Use base `ObjectDetectorOptions` |
| Calling `setState` without checking `mounted` | Always `if (mounted) setState(...)` |
| Hardcoding English strings in TTS | Use `isTagalog` conditional, `TranslationService.translate()`, or `SignupStrings` |

---

### 03 — NAMING CONVENTIONS

| Element | Convention | Example |
|---|---|---|
| Files | `snake_case.dart` | `hardware_screen.dart` |
| Classes | `PascalCase` | `HardwareScreen` |
| Private methods | `_camelCase` | `_processObjectResults` |
| Constants | `camelCase` | `primaryColor` |
| Service singletons | `PascalCase` + factory | `TtsService()` |
| Screen keys | `snake_case` | `tutorial_dismissed_camera` |
| HUD modes | `HudMode.camelCase` enum | `HudMode.navigation` |
