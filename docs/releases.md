# EasyLens Official Release Log & Version History (v1.0 - v25.0)

> **NOTE:** This document details all release milestones from `v1.0` to `v25.0`, reflecting architectural evolutions, feature additions, accessibility improvements, bug fixes, ABI architecture packages, and performance optimizations.

---

### 01 — RELEASE NAVIGATION MATRIX

| Version | Milestone Focus | Commit Hash | Release Date |
| :--- | :--- | :--- | :--- |
| [v1.0](#v10---core-application-architecture--initial-scaffold) | Core Scaffold & Architecture Base | `916a150` | 2026-06-01 |
| [v2.0](#v20---core-documentation--ui-specification-system) | Documentation & Accessible Theme Token System | `29997da` | 2026-06-10 |
| [v3.0](#v30---gemini-multimodal-api--resilience-fallback-chain) | Cloud Gemini API & API Key Fallback Engine | `581f104` | 2026-06-18 |
| [v4.0](#v40---thread-safe-sequential-frame-processing-pipeline) | Camera Processing Isolate Pipeline | `ca0e0bd` | 2026-06-25 |
| [v5.0](#v50---smart-hud-mode--audio-session-isolation) | Hands-Free HUD & Speech Audio Isolation | `11b7b12` | 2026-07-02 |
| [v6.0](#v60---local-gemma-llm--floating-buddy-mascot-persona) | Offline Gemma 2B & Buddy Mascot Persona | `2f11e9b` | 2026-07-08 |
| [v7.0](#v70---dynamic-settings-engine--live-update-checker) | Settings Provider & Live Update Manager | `fc009df` | 2026-07-12 |
| [v8.0](#v80---accessible-onboarding--user-disability-profiles) | Multi-step Signup & Accessibility Profiler | `8e2cceb` | 2026-07-15 |
| [v9.0](#v90---generative-vision-assistant--cloud-ai-fallbacks) | Multimodal Vision Assistant & Ollama | `22cb9b0` | 2026-07-18 |
| [v10.0](#v100---dynamic-context-memory--companion-guardrails) | Persistent Bi-directional AI Memory Engine | `698dda8` | 2026-07-20 |
| [v11.0](#v110---local-model-weight-validation--native-crash-prevention) | Local LLM Integrity Checker & Native Stability | `6d35065` | 2026-07-22 |
| [v12.0](#v120---high-performance-isolate-yuv-engine--gif-pre-caching) | YUV Frame Offloading & CPU Lag Elimination | `ab0f2dc` | 2026-07-24 |
| [v13.0](#v130---spatial-walking-navigation--collision-warnings) | Walking Guidance & Centered Path Analyzer | `1193963` | 2026-07-26 |
| [v14.0](#v140---native-audio-stability--dual-speech-engine) | Android Voice Crash Fixes & Speech Buffering | `ed3e12b` | 2026-07-28 |
| [v15.0](#v150---esp32-cam-smart-glasses-integration--command-panel) | ESP32 External Smart Glasses & HUD Panel | `d8ad231` | 2026-07-30 |
| [v16.0](#v160---real-time-hazard-detection--threat-alert-engine) | Threat Alerts (Knife/Fire) & Animal Caution | `ca90ef1` | 2026-07-31 |
| [v17.0](#v170---custom-micro-animations--60fps-split-door-signup) | 60fps Micro-Animations & Mascot Trajectory | `dfa03cc` | 2026-08-01 |
| [v18.0](#v180---robust-input-field-validation--emailphone-safeguards) | Strict 11-digit Phone & Email Validations | `2158e8b` | 2026-08-02 |
| [v19.0](#v190---docker-infrastructure-native-apk-pipeline--ghcr-deployment) | Dockerized Infrastructure & GHCR Pipeline | `41be50c` | 2026-08-03 |
| [v20.0](#v200---pixel-exact-live-face-recognition--biometric-overlay-engine) | Spatial Facial Luminance Grid & 0.28 Biometrics | `b3b41a2` | 2026-08-03 |
| [v21.0](#v210---custom-fine-tuned-mobilenetv2--hybrid-ai-vision-fusion) | 4-Phase Fine-Tuning & Multi-Tier Hybrid Vision | `99730bd` | 2026-08-04 |
| [v22.0](#v220---accessible-tactile-navigation-matrix--waypoint-profiler) | Accessible Tactile Maps, Dynamic POIs & Geocoding | `3b891a4` | 2026-08-10 |
| [v23.0](#v230---high-speed-yuv-color-conversion--sound-engine-refactor) | 60 FPS Bounding Box Latency & Soundboard Cues | `e41a9c1` | 2026-08-16 |
| [v24.0](#v240---60-fps-real-time-object-tracking--gemini-live-multimodal-vision) | Zero-Lag Gemini Vision, Live Bounding Boxes & Anti-Echo | `1a4bd76` | 2026-08-22 |
| [v25.0](#v250---map-layers-pull-down-drawers-theme-synchronization--settings-fixes) | Pull-Down Accordion Drawers, Full Theme Sync & ABI Builds | `703de1a` | 2026-08-23 |

---

### 02 — RELEASE DETAILS & CHANGE CHECKLISTS

#### v1.0 - Core Application Architecture & Initial Scaffold
- **Commit:** `916a150`
- **Focus:** Application foundations, Flutter runner, core navigation skeleton, and initial state providers.

##### Changes & Features
- [x] Initialized Flutter project structure targeting Dart SDK `^3.11.5`.
- [x] Configured declarative `AppRoute` navigation wrapper supporting screen routing.
- [x] Added core theme constants with accessible high-contrast colors (`AppColors`).
- [x] Implemented initial splash screen (`SplashScreen`) with automated routing checks.
- [x] Configured basic `Provider` multi-provider architecture in `main.dart`.
- [x] Integrated base `SettingsService` for persistent local key-value storage.

---

#### v2.0 - Core Documentation & UI Specification System
- **Commit:** `29997da`
- **Focus:** System architectural design, technical documentation, and baseline accessibility tokens.

##### Changes & Features
- [x] Published comprehensive technical `readme.md` and `architecture.md` documentation.
- [x] Standardized color palette for high-contrast accessibility (Yellow/Black, Blue/White, Dark Mode).
- [x] Established component modularity guidelines for screens, widgets, and background services.
- [x] Configured system-wide font scaling support for screen readers.
- [x] Added `UserPreferences` data model to persist custom voice speed and pitch preferences.
- [x] Created baseline directory layout for ML Kit, TFLite, and RAG services.

---

#### v3.0 - Gemini Multimodal API & Resilience Fallback Chain
- **Commit:** `581f104`
- **Focus:** Cloud generative AI connectivity, sequential API key rotation, and network error handling.

##### Changes & Features
- [x] Integrated `google_generative_ai` package for Gemini multimodal vision and speech prompts.
- [x] Developed `GeminiService` with automated round-robin API key fallback chain.
- [x] Implemented offline degradation handling when network requests fail.
- [x] Added request timeout guards and exponential backoff retry mechanisms.
- [x] Built image-to-text scene description capabilities using camera frame snapshots.
- [x] Added system prompt constraints to ensure concise, accessible speech responses.

---

#### v4.0 - Thread-Safe Sequential Frame Processing Pipeline
- **Commit:** `ca0e0bd`
- **Focus:** Live camera stream handler, isolate memory management, and frame drop prevention.

##### Changes & Features
- [x] Designed `CameraIsolateWorker` to process live camera image frames in background threads.
- [x] Implemented lock-free frame drop strategy to maintain 60fps UI responsiveness.
- [x] Eliminated static fallback bounding boxes in object detection overlays.
- [x] Integrated raw YUV420 to RGB conversion algorithms inside background isolates.
- [x] Resolved memory leak issue occurring during long camera streaming sessions.
- [x] Added FPS monitoring and diagnostic logs in debug mode.

---

#### v5.0 - Smart HUD Mode & Audio Session Isolation
- **Commit:** `11b7b12`
- **Focus:** Hands-free HUD interface, voice command routing, and TTS audio focus management.

##### Changes & Features
- [x] Created `SmartHUDOverlay` with minimal visual distraction for low-vision users.
- [x] Implemented TTS audio output suppression during active continuous STT voice sessions.
- [x] Added tactile haptic feedback patterns for screen taps and action confirmations.
- [x] Implemented automatic speech pause on incoming critical audio warnings.
- [x] Integrated ambient brightness detection to adjust HUD text contrast dynamically.
- [x] Built voice-activated shortcut commands for quick navigation.

---

#### v6.0 - Local Gemma LLM & Floating Buddy Mascot Persona
- **Commit:** `2f11e9b`
- **Focus:** On-device generative inference using Google Gemma 2B and animated mascot interaction.

##### Changes & Features
- [x] Integrated `flutter_gemma` package for offline 2B parameter LLM inference.
- [x] Created `BuddyMascot` floating widget with interactive state animations.
- [x] Built Tagalog and English persona toggle controls in application settings.
- [x] Added offline RAG context generation using device local storage memories.
- [x] Designed fallback chain from Gemma local model to Ollama server daemon.
- [x] Optimized RAM consumption of local model weights during initialization.

---

#### v7.0 - Dynamic Settings Engine & Live Update Checker
- **Commit:** `fc009df`
- **Focus:** Application configuration manager, GitHub Actions automated build, and update notifier.

##### Changes & Features
- [x] Built dynamic `SettingsProvider` listening to user preference state updates across screens.
- [x] Configured GitHub Actions CI workflow for automated APK compilation.
- [x] Implemented `UpdateCheckerService` querying GitHub releases for new version updates.
- [x] Added customizable voice rate (0.5x - 2.0x) and pitch sliders in settings UI.
- [x] Integrated local database export/import functionality for user settings backup.
- [x] Added accessibility labels (`Semantics`) to all input controls in settings.

---

#### v8.0 - Accessible Onboarding & User Disability Profiles
- **Commit:** `8e2cceb`
- **Focus:** Guided onboarding flow, vision condition assessment, and screen reader alignment.

##### Changes & Features
- [x] Designed guided multi-step onboarding wizard for first-time application setup.
- [x] Added assessment step for vision conditions (Cataracts, Glaucoma, Low Vision, Color Blindness).
- [x] Removed non-essential skip controls from onboarding bottom bar.
- [x] Integrated natural voice guidance prompts explaining each onboarding option.
- [x] Persisted disability preference matrix to tailor navigation and OCR announcements.
- [x] Added full TalkBack and VoiceOver semantics verification.

---

#### v9.0 - Generative Vision Assistant & Cloud AI Fallbacks
- **Commit:** `22cb9b0`
- **Focus:** Multimodal generative vision pipeline, model version tuning, and local Ollama bridge.

##### Changes & Features
- [x] Tuned `gemini-1.5-flash` model parameters for response speed.
- [x] Integrated local Ollama server API bridge (`http://10.0.2.2:11434`) for offline fallback.
- [x] Added support for `gemma2` offline server models via Ollama bridge.
- [x] Implemented real-time image cropping before sending vision query frames.
- [x] Formatted AI descriptions into short, action-oriented audio prompts.
- [x] Created visual context caching to prevent duplicate API requests for identical scenes.

---

#### v10.0 - Dynamic Context Memory & Companion Guardrails
- **Commit:** `698dda8`
- **Focus:** Bi-directional user conversation memory, safety guardrails, and context injection.

##### Changes & Features
- [x] Built `ChatHistoryService` storing user preference memories and past interaction logs.
- [x] Implemented context-aware prompt injection for Buddy AI mascot responses.
- [x] Configured strict safety guardrails preventing hallucinated medical or safety advice.
- [x] Added automated summarization of long conversation turns to preserve memory windows.
- [x] Implemented memory user privacy control in settings screen.
- [x] Created test suite verifying memory persistence across app reboots.

---

#### v11.0 - Local Model Weight Validation & Native Crash Prevention
- **Commit:** `6d35065`
- **Focus:** On-device file validation, download integrity verification, and SIGSEGV prevention.

##### Changes & Features
- [x] Added local model binary file size check (> 1.2 GB) before initializing MediaPipe runtime.
- [x] Implemented auto-deletion of corrupted or partial local model downloads.
- [x] Eliminated native `SIGSEGV` segmentation fault crashes caused by broken weights.
- [x] Added user progress indicators during model downloading and background extraction.
- [x] Built retry mechanism for failed model file downloads over cellular connections.
- [x] Validated checksum integrity against remote model manifests.

---

#### v12.0 - High-Performance Isolate YUV Engine & GIF Pre-Caching
- **Commit:** `ab0f2dc`
- **Focus:** UI frame rate optimization, YUV image conversion offloading, and GIF caching.

##### Changes & Features
- [x] Offloaded raw camera YUV pixel buffer processing entirely to Dart background isolates.
- [x] Pre-cached Buddy mascot GIF animation frames during application splash phase.
- [x] Throttled continuous camera frame dispatch to match device refresh rate without CPU spike.
- [x] Reduced overall application RAM footprint by 35% during active object detection.
- [x] Reduced stuttering on lower-end Android devices during live streaming.
- [x] Verified UI thread performance using Flutter DevTools.

---

#### v13.0 - Spatial Walking Navigation & Collision Warnings
- **Commit:** `1193963`
- **Focus:** Centered path collision analyzer, direction-aware obstacle alerts, and audio cues.

##### Changes & Features
- [x] Developed spatial bounding box analyzer isolating hazards located in central path vectors.
- [x] Implemented "Path Clear" audio cue when central walking corridor is unobstructed.
- [x] Added distance estimation heuristics based on object pixel height and bounding metrics.
- [x] Built directional audio cues (Left, Right, Center) for obstacle notifications.
- [x] Integrated proximity vibration pulses that intensify as hazards grow closer.
- [x] Created custom test cases for indoor and outdoor walking scenarios.

---

#### v14.0 - Native Audio Stability & Dual Speech Engine
- **Commit:** `ed3e12b`
- **Focus:** Android TTS native NullPointerException prevention, speech synthesis safeguards.

##### Changes & Features
- [x] Implemented native guard bypassing `getVoices` on specific Android builds to prevent NPE.
- [x] Resolved Android IPC `Binder` transaction failure errors during continuous speech loops.
- [x] Added fallback voice engine selection when primary TTS engine fails to initialize.
- [x] Implemented audio focus requesting to pause background music during navigation voice prompts.
- [x] Fixed audio buffer truncation occurring on long OCR text reading sessions.
- [x] Added child voice profile (Xiaomi MiMo Chloe) for Buddy persona.

---

#### v15.0 - ESP32-CAM Smart Glasses Integration & Command Panel
- **Commit:** `d8ad231`
- **Focus:** External hardware stream handling, smart glasses WiFi AP connection, and 3x3 UI panel.

##### Changes & Features
- [x] Integrated `Esp32Service` connecting to external ESP32-CAM hardware over HTTP MJPEG AP stream.
- [x] Added automatic failover from smart glasses stream to phone camera when disconnected.
- [x] Designed 3x3 high-contrast accessible touch command panel for rapid action triggering.
- [x] Built remote hardware LED flash toggle endpoint controller (`/led?val=1`).
- [x] Implemented diagnostic messages for camera hardware authentication errors.
- [x] Validated low-latency video streaming at 30fps over local HTTP WiFi socket.

---

#### v16.0 - Real-Time Hazard Detection & Threat Alert Engine
- **Commit:** `ca90ef1`
- **Focus:** High-priority threat alert system (fire, weapons, sharp objects, animal caution).

##### Changes & Features
- [x] Implemented `DangerWarningService` to detect high-risk objects (Knife, Fire, Weapon, Sharp Metal).
- [x] Added special animal caution warnings (Dogs, Vehicles, Moving Obstacles) during navigation.
- [x] Configured high-priority emergency audio interrupt overriding general speech commentary.
- [x] Added distinct haptic alarm pattern for critical hazard notifications.
- [x] Enhanced ML Kit label refiner mapping raw image tags to hazard alerts.
- [x] Integrated door and elevator threshold detection warnings.

---

#### v17.0 - Custom Micro-Animations & 60fps Split-Door Signup
- **Commit:** `dfa03cc`
- **Focus:** Micro-animations, 60fps split-door signup screen transitions, mascot trajectory flight.

##### Changes & Features
- [x] Implemented custom vertical `splitDoor` step transition between registration steps in `SignUpScreen`.
- [x] Developed continuous flight trajectory: Buddy mascot GIF glides from hero position to screen center.
- [x] Created custom `AppRoute.rocketLaunch` login transition with thruster particle effects.
- [x] Optimized registration step questions with 60fps FadeIn and Scale transitions.
- [x] Removed yellow seam highlights and border lines.
- [x] Redesigned login hero section layout into asymmetric horizontal row with speech bubble card.

---

#### v18.0 - Robust Input Field Validation & Email/Phone Safeguards
- **Commit:** `2158e8b`
- **Focus:** Data integrity enforcement, strict 11-digit phone checks, email validation, and SOS safety net.

##### Changes & Features
- [x] Enforced strict 11-digit phone number format validation across `StepPhoneInput` and `SignupScreen`.
- [x] Implemented duplicate email address pre-check during account creation (Step 10).
- [x] Added `@` symbol and domain pattern validation for email address inputs.
- [x] Enforced exact 11-digit check on SOS Emergency Contact phone input.
- [x] Added robust try-catch exception handling blocks across authentication workflows.
- [x] Replaced static dummy login credentials with active Google `signInWithGoogle()` SDK flow.

---

#### v19.0 - Docker Infrastructure, Native APK Pipeline, & GHCR Deployment
- **Commit:** `41be50c`
- **Focus:** Complete containerization, local Docker Compose setup, GitHub Container Registry CI/CD.

##### Changes & Features
- [x] Created optimized multi-stage `Dockerfile` using Ubuntu 22.04 and official Flutter SDK.
- [x] Configured `docker-compose.yml` serving web landing pages and release APK download server.
- [x] Automated GitHub Actions pipeline compiling release Android APK natively on runner.
- [x] Configured automated image push to GitHub Container Registry (`ghcr.io/thes-is-it/easylens:latest`).
- [x] Forced Java/Kotlin JVM target 17 across all subproject plugin dependencies to resolve Gradle errors.
- [x] Created `docker.md` documentation detailing container execution and CI/CD operations.

---

#### v20.0 - Pixel-Exact Live Face Recognition & Biometric Overlay Engine
- **Commit:** `b3b41a2`
- **Focus:** 100% accurate face matching, spatial luminance grid, 90° NV21 unrotation, and bounding box overlay calibration.

##### Changes & Features
- [x] Implemented spatial facial luminance grid and biometric landmark signature engine for face matching.
- [x] Fixed 90-degree NV21 sensor coordinate unrotation for live face cropping.
- [x] Configured optimal `0.28` facial recognition distance threshold to eliminate false positives.
- [x] Corrected `displayImageSize` aspect ratio mapping for portrait and landscape sensor orientations.
- [x] Calibrated `scaleX` and `scaleY` bounding box alignment for exact live face camera overlay.
- [x] Prevented face label collisions and duplicate assignments during multi-face detection.

---

#### v21.0 - Custom Fine-Tuned MobileNetV2 & Hybrid AI Vision Fusion
- **Commit:** `99730bd`
- **Focus:** 4-Phase Transfer Learning technical report, 24-class custom MobileNetV2 model validation, and Multi-Tier Hybrid AI Vision Fusion architecture.

##### Changes & Features
- [x] Published technical report `mobilenetv2_finetuning_report.md` documenting 4-Phase Transfer Learning pipeline (Warm-up $\rightarrow$ Mid-Level Unfreezing with Class Weights $\rightarrow$ Deep Full Unfreezing $\rightarrow$ Ultra-Low LR Optimization).
- [x] Validated custom 24-class MobileNetV2 model achieving **85.55% Top-1**, **92.10% Top-2**, and **94.54% Top-3** accuracy with **2.48 ms** per-image latency (>400 FPS throughput).
- [x] Documented **97% recall on potholes**, **95% F1 on crosswalks**, **92% recall on stairs**, and **99% recall on fire hydrants**.
- [x] Published architecture document `hybrid_ai_fusion_app_integration.md` detailing the integration of Google ML Kit (400+ categories), TFLite SSD MobileNetV2 (80 COCO classes), fine-tuned MobileNetV2 (24 hazard classes), and Multimodal RAG (Gemma 2B / Gemini Flash).
- [x] Updated canonical AI/ML source-of-truth document `05_ai_ml_pipeline.md` and root `readme.md`.

---

#### v22.0 - Accessible Tactile Navigation Matrix & Waypoint Profiler
- **Commit:** `3b891a4`
- **Focus:** Accessible dynamic map layers, real-time geocoding, proximity safety radius, and turn-by-turn walking guidance.

##### Changes & Features
- [x] Implemented accessible waypoint search with Photon / OSRM routing fallbacks.
- [x] Created multi-layer map toggles supporting tactile accessibility overlays, satellite imagery, 3D building perspective, and real-time traffic heatmaps.
- [x] Integrated real-time proximity radius query scanner scanning transit stations, wheelchair ramps, and clinics within 500m.
- [x] Configured spatial turn announcements with distance thresholds in meters and feet.
- [x] Added dynamic map recenter camera tracking following GPS heading and user movement.

---

#### v23.0 - High-Speed YUV Color Conversion & Sound Engine Refactor
- **Commit:** `e41a9c1`
- **Focus:** Camera isolate YUV-to-RGB acceleration, real-time audio soundboard, and UI render optimizations.

##### Changes & Features
- [x] Optimized camera frame buffer memory transfers using direct Isolate memory pointers.
- [x] Refactored `SoundService` with low-latency audio cue caching for auditory click and chime responses.
- [x] Eliminated frame rendering lag when navigating between dashboard tabs and camera viewports.
- [x] Added battery power optimization governor throttling frame inference rate during background or locked screen states.

---

#### v24.0 - Real-Time Object Tracking & Gemini Live Multimodal Vision
- **Commit:** `1a4bd76`
- **Focus:** Zero-latency bounding box tracking ($\alpha = 1.0$), Gemini Live multimodal vision prompt dispatch, and anti-echo STT/TTS isolation.

##### Changes & Features
- [x] **Zero-Latency Box Coordinates**: Eliminated temporal coordinate averaging dampening so bounding boxes snap directly ($\alpha = 1.0$) to moving objects with 0ms trailing delay.
- [x] **Direct Isolate Pipeline**: Streamlined YUV-to-RGB conversion offloaded to background Isolate worker with zero microtask queue latency.
- [x] **Zero-Lag Image Capture**: Replaced blocking Android Camera2 picture capture with in-memory JPEG frame encoding from the live video stream in $< 2\text{ ms}$.
- [x] **Direct Multimodal Vision Dispatching**: All user vision questions are dispatched directly to the Google Gemini Multimodal AI API along with the live camera image.
- [x] **Anti-Echo Voice Isolation**: Configured native platform synchronous speech completion with a post-speech acoustic decay grace period to prevent self-voice audio feedback.

---

#### v25.0 - Map Layers Pull-Down Drawers, Theme Synchronization & Settings Fixes
- **Commit:** `703de1a`
- **Focus:** Map Layers & Safety Options expandable accordion drawers, universal color theme synchronization, clean release notes markdown parser, disabled up-to-date download state, and split-per-ABI builds.

##### Changes & Features
- [x] **Expandable Accordion Drawers**: Built `buildExpandableLayerCard` with animated cross-fades inside `_showMapLayersPullDownSheet()` detailing coverage radius, transit nodes, tactile ramps, and functionality for all 4 map layers.
- [x] **SOS Compass Overlap Fix**: Disabled the native top-left Google Maps compass that overlapped underneath the SOS emergency button (`compassEnabled: false`).
- [x] **Universal Theme Synchronization**: Synchronized all navigation sheets, modals, badges, cards, and update dialogs to strictly follow active high-contrast themes (`AppColors`).
- [x] **Clean LaTeX Math Release Notes**: Built `_cleanReleaseNotes` regex pipeline converting LaTeX math syntax (e.g. `$\alpha = 1.0$` $\rightarrow$ `α = 1.0`), stripping raw dollar signs, backslashes, and markdown noise into clean bullet points.
- [x] **Smart Update State**: Automatically disables the **Download Now** button (`onPressed: null`) with an *"Already Up to Date"* badge when the installed version matches the latest release.
- [x] **Buddy Facebook Community**: Directly linked the Buddy Community tile to the official Facebook community page (`https://www.facebook.com/profile.php?id=61566090583740`).
- [x] **Multi-ABI APK Release Distribution**: Provided dedicated standalone 64-bit ARM (`arm64-v8a`), 32-bit ARM (`armeabi-v7a`), x86_64, and universal FAT release binaries.

---

### 03 — ANDROID APK ARCHITECTURE, COMPATIBILITY & SIZE SPECIFICATION GUIDE

Due to the integration of on-device C++ machine learning runtimes (LiteRT, LLM Inference Engine, MediaPipe Tasks, Google ML Kit, and TensorFlow Lite), EasyLens provides both **Architecture-Specific Split APKs** and a **Universal FAT APK**.

#### 3.1 APK Architecture Comparison & Compatibility Matrix

| Package Filename | Target ABI Architecture | Download Size | Primary Device Target & Compatibility | Performance & Recommendation |
| :--- | :--- | :--- | :--- | :--- |
| **`app-arm64-v8a-release.apk`** | **64-bit ARM (`arm64-v8a`)** | **~317 MB** | **95%+ Modern Android Devices**<br>• Samsung Galaxy (S, Note, Z, A series 64-bit)<br>• Google Pixel (Pixel 4 through 9 Pro)<br>• Xiaomi, Redmi, POCO (64-bit)<br>• Oppo, Vivo, OnePlus, Realme, Motorola | ⭐ **RECOMMENDED BUILD**<br>• ~36% smaller file size than FAT APK<br>• Faster Google Drive upload & user download<br>• 100% native 64-bit CPU & NPU performance<br>• Lower memory consumption during inference |
| **`app-armeabi-v7a-release.apk`** | **32-bit ARM (`armeabi-v7a`)** | **~183 MB** | **Legacy / Budget 32-bit Devices**<br>• Entry-level Android smartphones<br>• Older Android 8.0 - 10 devices with 32-bit CPUs | • Smallest download footprint<br>• Maximum backward compatibility for older hardware |
| **`app-x86_64-release.apk`** | **64-bit x86 (`x86_64`)** | **~241 MB** | **Emulators & Intel Hardware**<br>• Android Studio Virtual Devices (AVD)<br>• ChromeOS tablets & Intel/AMD Chromebooks | • Native desktop x86 execution without ARM translation overhead |
| **`app-release.apk`** | **Universal FAT Binary** (Multi-Arch) | **~498 MB** | **All Android Architectures**<br>• Bundles `arm64-v8a`, `armeabi-v7a`, and `x86_64` | • Single file offline distribution<br>• Universal installation when device architecture is unknown |

#### 3.2 What Accounts for the APK Size?
EasyLens is a comprehensive, standalone offline-capable multimodal vision and AI assistant. The package size includes:
1. **On-Device Machine Learning Models (`assets/models/`)**:
   - `ssd_mobilenet_v2.tflite` (~67.3 MB): 80 COCO class bounding box object detection model.
   - `ssd_mobilenet.tflite` (~4.2 MB): Low-latency edge vision model.
   - `mobile_ica_8bit_with_metadata_tflite` (~3.0 MB): ML Kit default image labeling model.
2. **Native C++ Inference Engines (`lib/<abi>/`)**:
   - `libllm_inference_engine_jni.so` (~26.4 MB): On-device LLM C++ execution runtime.
   - `liblitertlm_jni.so` (~20.6 MB): Google LiteRT runtime for edge ML.
   - `libgemma_embedding_model_jni.so` (~17.0 MB): Embedding generation for vector search.
   - `libgecko_embedding_model_jni.so` (~17.0 MB): Dense vector retrieval embeddings.
   - `libmediapipe_tasks_vision_jni.so` (~14.3 MB): MediaPipe vision tasks processor.
   - `libmlkit_google_ocr_pipeline.so` (~11.0 MB): High-accuracy on-device OCR pipeline.
   - `libflutter.so` & `libapp.so` (~21.2 MB): Flutter rendering engine and compiled AOT Dart code.

#### 3.3 Build Commands Guide

To build the recommended **split-per-ABI APKs** (optimized for fast cloud upload and direct installation):
```bash
flutter build apk --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols
```
*Outputs generated in `build/app/outputs/flutter-apk/`:*
- `app-arm64-v8a-release.apk`
- `app-armeabi-v7a-release.apk`
- `app-x86_64-release.apk`

To build the **universal FAT APK**:
```bash
flutter build apk --obfuscate --split-debug-info=build/app/outputs/symbols
```
*Output generated in `build/app/outputs/flutter-apk/app-release.apk`.*
