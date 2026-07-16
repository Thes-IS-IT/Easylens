# 07 — Known Issues & Workarounds

This document tracks all known platform-specific bugs, workarounds, and gotchas that developers must be aware of.

---

## 🔴 Critical — Active Workarounds in Code

### 1. Android TTS `setVoice` NullPointerException
| | |
|---|---|
| **Severity** | Critical (native JVM crash) |
| **Platform** | Android only |
| **Symptom** | App crashes with `NullPointerException` at `FlutterTtsPlugin.setVoice` when the TextToSpeech engine becomes unbound or disconnected |
| **Root Cause** | The `flutter_tts` plugin's Kotlin implementation calls `Set.iterator()` on a null voice set when the TTS engine is in an unbound state |
| **Workaround** | `TtsService._setDeviceVoiceByGender()` checks `Platform.isAndroid` and **skips the `setVoice` call entirely** on Android. Only `setLanguage()` is used, which is sufficient for English and Tagalog. |
| **File** | `lib/services/tts_service.dart` |
| **Impact** | Voice persona switching (Max/Aria/Nova) only changes pitch and rate on Android, not the actual voice engine. iOS uses the full native voice selection. |

---

### 2. Google ML Kit Custom TFLite Model Metadata Crash
| | |
|---|---|
| **Severity** | Critical (detector fails to initialize) |
| **Platform** | Android |
| **Symptom** | `ObjectDetector` initialized with `LocalModel(modelPath: 'ssd_mobilenet_v2.tflite')` throws a native metadata parsing error and returns `null` |
| **Root Cause** | Google ML Kit's `ObjectDetector` requires TFLite models to have specific Google metadata tags compiled into the `.tflite` file. Standard TFLite Hub models lack these tags. |
| **Workaround** | Use the built-in base `ObjectDetectorOptions` instead of `CustomObjectDetectorOptions(localModel: ...)`. The base detector uses Google's own bundled model. |
| **File** | `lib/screens/hardware/hardware_screen.dart` → `_loadObjectDetectionModel()` |
| **Impact** | Object detection uses Google's default model instead of the custom SSD MobileNetV2. The custom TFLite model is still used separately via `TfliteProcessor` for additional inference. |

---

### 3. Camera Image Stream Memory Leak on Dispose
| | |
|---|---|
| **Severity** | Critical (OOM crash) |
| **Platform** | Android |
| **Symptom** | App crashes with `Lost connection to device` after switching away from the camera screen. Logcat shows dozens of `Image buffer was dropped by garbage collector` messages and GC thrashing up to 133MB. |
| **Root Cause** | `CameraController.startImageStream()` continues producing native frames even after the Flutter widget is disposed. Without `stopImageStream()`, frames pile up in native memory. |
| **Fix** | `dispose()` now calls `stopImageStream()` before `_cameraController?.dispose()`. Added `mounted` guards in all async frame callbacks. |
| **File** | `lib/screens/hardware/hardware_screen.dart` → `dispose()` |

---

### 4. Navigation Mode Double Processing
| | |
|---|---|
| **Severity** | Resolved / Mitigated |
| **Platform** | All |
| **Symptom** | Memory grows rapidly when navigation mode is active, triggering aggressive GC and jank |
| **Root Cause** | Running BOTH `_detectObjectsOnFrame` (ML Kit object detection) and `_processCameraImage` (ML Kit image labeling) concurrently on the same frame created excessive memory allocation and thread contention. |
| **Fix** | Staggered frame processing: alternating Object Detector and Image Labeler on separate 400ms cycles (800ms intervals each). They never run concurrently, cutting memory overhead by 50%. |
| **File** | `lib/screens/hardware/hardware_screen.dart` → `startImageStream` callback |

---

## 🟡 Medium — Platform Quirks

### 5. Choreographer Frame Skipping
| | |
|---|---|
| **Severity** | Medium (jank) |
| **Platform** | Android |
| **Symptom** | `Choreographer: Skipped 40-56 frames!` messages in logcat |
| **Cause** | Heavy ML inference on the main thread combined with `setState` calls |
| **Mitigation** | 400ms frame processing cooldown, isolate for YUV conversion, skip labeling in navigation mode |

---

### 6. Google Maps Tile Thread Contention
| | |
|---|---|
| **Severity** | Low (cosmetic warning) |
| **Platform** | Android |
| **Symptom** | `Long monitor contention with owner androidmapsapi-TilePrep` warnings (144-465ms) |
| **Cause** | Google Maps SDK tile preparation threads contend with ML Kit processing |
| **Impact** | Minor thread blocking, no user-facing issue |

---

### 7. Flogger Log Overflow
| | |
|---|---|
| **Severity** | Low (cosmetic warning) |
| **Platform** | Android |
| **Symptom** | `ProxyAndroidLoggerBackend: Too many Flogger logs received before configuration. Dropping old logs.` |
| **Cause** | Google Play Services internal logger floods before full initialization |
| **Impact** | None — purely internal Google library log noise |

---

## 🟢 Informational

### 8. Firebase Mock Mode
When Firebase configuration files (`google-services.json` / `GoogleService-Info.plist`) are not present, `FirebaseService` gracefully falls back to **mock mode** with local-only data. This is by design for development environments.

### 9. Weather Service Geolocator in Tests
`WeatherService.fetchWeather()` throws `MissingPluginException` in unit tests because `geolocator` requires a native platform channel. This is expected and does not affect test results.

### 10. `_isProcessingFrame` Lock Race Condition
The frame processing lock is a simple boolean, not a mutex. In theory, two `Future.microtask` callbacks could both read `false` before either sets it to `true`. In practice, Dart's single-threaded event loop prevents this because `startImageStream` callbacks are serialized on the platform channel.
