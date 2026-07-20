# 02 — Architecture

## Design Principles

1. **Offline-First** — Core features (object detection, OCR, face recognition, Buddy AI) work without internet using on-device ML models.
2. **Singleton Services** — All services use the `factory` singleton pattern for global access without dependency injection.
3. **Reactive UI** — `SettingsService` extends `ChangeNotifier`. The root `MaterialApp` is wrapped in `AnimatedBuilder(animation: settingsService)` so theme/language changes propagate instantly.
4. **Accessibility by Default** — Every interaction has a TTS announcement. Contrast themes, large tap targets, and haptic feedback are first-class citizens.
5. **Power & Screen Persistence** — Continuous camera stream HUD modes and multi-step onboarding wizard utilize `wakelock_plus` to maintain active display power without unexpected OS dimming or screen lock.
6. **Zero-Lag Disk Filtering** — High-frequency transient notifications (such as rapid obstacle warnings) are announced via speech and rendered in UI but filtered out of `SharedPreferences` write queues; only critical alerts are persisted to disk to eliminate main-thread I/O jank.

---

## System Architecture Diagram

```mermaid
graph TD
    subgraph UI["Flutter UI Layer"]
        Welcome[WelcomeScreen]
        Login[LoginScreen]
        Signup[SignupScreen - 18 Steps]
        Home[HomeTab / DashboardHome]
        Camera[HardwareScreen - Modular Component Tree]
        RAG[RagAssistantScreen]
        Settings[SettingsScreen]
    end

    subgraph HardwareSub["Hardware Sub-Components"]
        PairingWiz[pairing_wizard.dart]
        HudCamera[hud_camera_view.dart]
        HudControls[hud_controls_panel.dart - 3x3 Grid]
        HudModeSel[hud_mode_selector.dart]
    end

    subgraph Services["Service Layer (Singletons)"]
        SettingsSvc[SettingsService]
        TTSSvc[TtsService]
        STTSvc[SttService]
        RagSvc[RagService]
        FirebaseSvc[FirebaseService]
        NotifSvc[NotificationService]
        FaceRegSvc[FaceRegistrationService]
        ESP32Svc[Esp32Service]
        WeatherSvc[WeatherService]
        TransSvc[TranslationService]
        SmsSvc[SmsService]
        NavSvc[ActiveNavigationService]
        UndoSvc[UndoService]
        JournalSvc[JournalService]
    end

    subgraph ML["ML / AI Layer"]
        MLKit[Google ML Kit]
        TFLite[TFLite SSD MobileNetV2]
        Gemma[Gemma 2B Local LLM]
        Gemini[Gemini Flash Cloud LLM]
        Ollama[Ollama Local Server]
    end

    subgraph Storage["Storage Layer"]
        Firebase[Firebase Auth + Firestore]
        CloudflareD1[Cloudflare D1 SQL]
        CloudflareR2[Cloudflare R2 Objects]
        SharedPrefs[SharedPreferences]
    end

    Home --> Camera
    Camera --> HardwareSub
    Home --> RAG
    Home --> Settings

    Camera --> MLKit
    Camera --> TFLite
    RAG --> RagSvc
    RagSvc --> Gemma
    RagSvc --> Gemini
    RagSvc --> Ollama

    Camera --> TTSSvc
    Camera --> NotifSvc
    RAG --> TTSSvc
    RAG --> STTSvc

    SettingsSvc --> SharedPrefs
    FirebaseSvc --> Firebase
    FirebaseSvc --> CloudflareD1
    FirebaseSvc --> CloudflareR2
```

---

## Service Dependency Graph

All services are singletons accessed via their factory constructor (e.g., `TtsService()`). There is **no** DI framework.

```
SettingsService (root — no service dependencies)
  ├── read by: TtsService, TranslationService, all screens
  └── persists to: SharedPreferences

TtsService
  ├── depends on: SettingsService (voice persona, rate, pitch)
  ├── platform: flutter_tts (with lazy Android binding & safe pitch [0.5, 2.0])
  └── fallback: dynamic voice persona resolution & locale fallback

RagService
  ├── depends on: SettingsService (language), WeatherService, TranslationService
  ├── uses: Gemma (offline), Gemini (cloud), Ollama (local server)
  └── guardrails: off-topic filter, curated Q&A, keyword context retrieval

FirebaseService
  ├── depends on: firebase_core, firebase_auth, cloud_firestore
  └── provides: user profile CRUD (including isForMyself & selectedConditions), auth state

NotificationService
  ├── depends on: SharedPreferences
  └── provides: filtered in-app alerts (obstacle, battery, buddy follow-up; only critical write to disk)

Esp32Service
  ├── depends on: SharedPreferences
  └── provides: MJPEG frame stream, LED control, Smart Glasses mobile camera fallback
```

---

## Data Flow: Camera Frame Processing

This is the most performance-critical pipeline in the app.

```mermaid
sequenceDiagram
    participant Camera as CameraController / ESP32 Feed
    participant Stream as startImageStream / MJPEG Stream
    participant Lock as _isProcessingFrame
    participant YUV as _yuvToNv21Async (Isolate)
    participant MLKit as Google ML Kit
    participant UI as setState / TTS / 3x3 Overlay Grid

    Camera->>Stream: CameraImage / MJPEG Frames (30fps)
    Stream->>Lock: Check lock
    alt Lock is free
        Lock->>YUV: Convert YUV420 → NV21 (compute isolate)
        YUV->>MLKit: InputImage.fromBytes
        alt Navigation Mode
            MLKit->>UI: Object Detection (Staggered alternate frame)
        else Object Detection Mode
            MLKit->>UI: Object Detection + Image Labeling + Non-critical Door/Window Detections
        else Default
            MLKit->>UI: Image Labeling only
        end
        UI->>Lock: 400ms delay → release lock
    else Lock is busy
        Stream-->>Camera: Skip frame (drop)
    end
```

### Key Design Decisions
- **Single-frame lock** (`_isProcessingFrame`): Only one frame is processed at a time. All other frames are dropped. This prevents memory accumulation.
- **400ms cooldown**: After each processed frame, a 400ms delay ensures ~2.5 FPS processing rate, preventing CPU saturation.
- **Navigation mode skips image labeling**: In `HudMode.navigation`, only `_detectObjectsOnFrame` runs — NOT `_processCameraImage`. This halves per-frame memory and CPU load.
- **YUV→NV21 in isolate**: The byte conversion runs in a `compute()` isolate to avoid blocking the main thread.
- **`stopImageStream()` in `dispose()`**: Critical — the camera stream MUST be stopped before the controller is disposed to prevent native memory leaks.
- **Smart Glasses Fallback**: If the external ESP32 stream drops, the system seamlessly falls back to the device's native camera preview, keeping HUD features active.
- **Disk I/O Optimization**: Transient obstacle warnings write only to memory and UI state. Storage persistence is reserved for critical safety alerts (`"STOP"`, `"FIRE"`, `"HAZARD"`, `"EMERGENCY"`) to ensure zero main-thread jank.

---

## Widget Tree Overview

```
MaterialApp
  └── AnimatedBuilder (listens to SettingsService)
      └── ConfettiOverlay
          └── SpeechNavigationOverlay
              └── WelcomeScreen → LoginScreen / SignupScreen (18 Steps) → HomeTab
                  └── Scaffold + BottomNavigationBar
                      ├── Tab 0: DashboardHome
                      ├── Tab 1: HardwareScreen (Camera Feed + 3x3 Controls + Mode Selector)
                      ├── Tab 2: RagAssistantScreen (Buddy Chat)
                      └── Tab 3: SettingsScreen
```
