# EasyLens — Complete Feature Reference

This document is the authoritative catalogue of every feature available in EasyLens, organized by functional area. It is maintained alongside the codebase and updated with every significant addition.

---

## Table of Contents

1. [Dashboard & Home](#1-dashboard--home)
2. [Buddy Local AI Assistant](#2-buddy-local-ai-assistant)
3. [EasyLens Camera (Hardware Screen)](#3-easylens-camera-hardware-screen)
4. [Audio Navigation](#4-audio-navigation)
5. [Nearby Text Scanner](#5-nearby-text-scanner)
6. [Object Detector](#6-object-detector)
7. [SOS & Emergency](#7-sos--emergency)
8. [Settings](#8-settings)
9. [Notifications](#9-notifications)
10. [Contacts](#10-contacts)
11. [Voice & TTS System](#11-voice--tts-system)
12. [Language & Localization](#12-language--localization)
13. [Appearance & Theming](#13-appearance--theming)
14. [Onboarding & Signup](#14-onboarding--signup)
15. [Hardware Integration (ESP32)](#15-hardware-integration-esp32)
16. [Sound & Audio Cues](#16-sound--audio-cues)

---

## 1. Dashboard & Home

The Dashboard is the central hub of EasyLens. It is built as a `StatelessWidget` wrapped in a `ListenableBuilder` that reacts live to `SettingsService` changes — meaning language, theme, and enabled-card changes reflect instantly without requiring an app restart.

### Features
- **Personalized greeting** — Shows time-aware greeting ("Good morning / afternoon / evening" or Filipino equivalents "Magandang umaga / hapon / gabi") with the user's first name fetched from Firestore.
- **Localized date header** — Date row ("MONDAY, JUL 9") switches to Filipino month/day names ("LUNES, HULYO 9") when Filipino is the active language.
- **Mascot Banner (Buddy)** — Animated rotating messages from Buddy displayed in a banner above the action buttons. Messages rotate on a timer and switch language based on the active locale.
- **Configurable action cards** — The set of action buttons shown on the home screen is user-configurable. Cards include:
  - Talk to Buddy (Local AI)
  - EasyLens Camera
  - Nearby Text
  - Nearby Objects
  - Audio Navigation
  - SOS Emergency
- **Bark sound on return** — `bark_dashboard.mp3` plays once when the user navigates back to the Home tab from another tab (non-spamming: does not play if already on Home tab).
- **Shake-to-undo** — Detects accelerometer shake gestures (> 2.5g) and undos the user's recent navigations or click events (e.g. going back a screen or closing the mascot assistant). Buddy announces "Action undone" (or Tagalog equivalent) via TTS.
- **Notification Badge Count** — Renders a dynamic red badge count on the notification bell icon inside the top header, indicating the number of unread alerts. Updates in real-time.

### Key Files
- `lib/screens/dashboard/dashboard_home.dart`
- `lib/screens/dashboard/dashboard_screen.dart`
- `lib/screens/dashboard/components/mascot_banner.dart`
- `lib/screens/dashboard/components/dashboard_button.dart`
- `lib/screens/dashboard/components/header_bar.dart`
- `lib/screens/dashboard/components/custom_navbar.dart`

---

## 2. Buddy Local AI Assistant

Buddy is EasyLens's primary conversational AI, presented as a golden retriever mascot. It is accessible from the Dashboard home button or the draggable floating Buddy button visible on all tabs.

### Architecture
| Language Mode | Backend | Behaviour |
|---|---|---|
| **English** | Gemma-IT 2B (on-device) | Fully offline, no network required |
| **Filipino / Tagalog** | Google Gemini 2.0 Flash (cloud) | Natively fluent Tagalog responses |

### Features
- **Voice input (STT)** — Tap the microphone button to speak; transcription feeds directly into the chat.
- **Text input** — Type any question or navigation command.
- **Navigation via chat** — Buddy parses `[NAVIGATE: x]` tags from the LLM response and automatically routes the user to any screen:
  - `home`, `nav`, `hardware`, `text`, `objects`, `emergency`, `settings`, `notifications`, `contacts`
- **TTS read-back** — Every Buddy response is automatically read aloud using the user's selected voice persona.
- **Localized UI** — Header, status text ("Buddy is thinking…" / "Nag-iisip si Buddy…"), input hints, and the welcome greeting all switch to Tagalog when Filipino is active.
- **Context awareness** — The prompt includes the user's name, mobility aid, and active language so Buddy personalises every reply.
- **RAG knowledge base** — Buddy has a local knowledge base covering app features, ESP32 hardware, Firebase usage, ML Kit models, and EasyLens identity. Matched context is injected into every English prompt.
- **Scanned text explanation** — When the user scans nearby text, Buddy receives the scan and explains it (food labels, safety signs, directional signs) in 2–3 sentences.
- **Draggable floating button** — The Buddy button can be dragged anywhere on screen and persists across all tabs.
- **Typewriter Reply Animation** — Conversational replies are typed out character-by-character sequentially in real-time (typing 3 characters every 15ms) to feel lively and responsive. (Bypassed for instant autopilot navigation).
- **Latency & Speed Optimizations** — Cap on-device Gemma output to `maxTokens: 150` to guarantee fast, responsive, low-latency offline responses on mobile GPU/CPU backend execution.

### Key Files
- `lib/screens/dashboard/components/buddy_assistant_sheet.dart`
- `lib/services/rag_service.dart`

---

## 3. EasyLens Camera (Hardware Screen)

The Hardware Screen provides live camera-based vision assistance. It supports two camera sources: the device's built-in camera and an external ESP32-CAM smart glass.

### Features
- **Live ML Kit image labeling** — Classifies what the camera sees in real time and reads aloud top labels above a confidence threshold.
- **TensorFlow Lite object detection** — MobileNetV2 SSD (MS-COCO, 80 classes) draws bounding boxes around detected objects on a live canvas overlay.
- **ESP32-CAM stream** — Connects to the ESP32 Access Point (`EasyLens-Camera`) and streams MJPEG video frames via `Esp32Service`.
- **LED flash control** — Toggle the ESP32's hardware flash LED remotely via HTTP endpoint (`/led?val=1` / `0`).
- **Obstacle TTS alerts** — Detected objects with high-hazard labels trigger a spoken warning to the user.
- **Camera switch** — Toggle between device front/rear cameras and the ESP32 stream.

### Key Files
- `lib/screens/hardware/hardware_screen.dart`
- `lib/services/esp32_service.dart`
- `lib/services/ml_kit_service.dart`
- `lib/services/object_detector_service.dart`
- `lib/services/tflite_processor.dart`
- `lib/services/isolate_runner.dart`

---

## 4. Audio Navigation

The Navigation screen provides GPS-based turn-by-turn guidance with full TTS guidance, real-time map rendering, and proximity-based alerts.

### Features
- **Real-time GPS tracking** — Uses `Geolocator` with `LocationAccuracy.bestForNavigation` and a 5-metre distance filter for smooth tracking.
- **Live route drawing** — Fetches road geometry from the OSRM open-source routing API and draws a polyline on the Google Map.
- **Search & geocoding** — Live search with local place cache; falls back to Google Geocoding API for unfound locations.
- **Quick-filter chips** — Pre-defined shortcuts (Home, Work, Holy Angel University) for instant navigation.
- **Step-by-step TTS guidance** — Reads the initial direction, then each subsequent step.
- **Proximity-based guidance system (anti-spam):**

| Distance | Action |
|---|---|
| < 200 m to next waypoint | Reminds current step |
| < 80 m to next waypoint | "In X meters, turn right…" |
| < 30 m to next waypoint | Auto-advances to next step + reads it |
| < 80 m to destination | "Almost there! X meters away" |
| < 20 m to destination | "You have arrived!" + transitions to arrived view |

- **8-second cooldown** between all spoken alerts — prevents spamming.
- **Imperial/Metric units** — Distances and steps are converted to feet/miles when Imperial is selected.
- **Recent navigation save** — Each route is saved to Firestore for history tracking.
- **Manual Next/Cancel buttons** — User can manually advance steps or cancel navigation.
- **Arrived screen** — Dedicated map view shown on arrival (navState 2).
- **Single-Tap or Long-Press Pinning** — Users can tap or hold anywhere on the map to drop a custom location marker pin. The app instantly queries the OSRM router to fetch directions, draw route polylines, and start active guidance.
- **Conversational Voice Search & Choice Selection** — Users can say "search for [place]" or "hanapin ang [place]" using Speech Navigation. The overlay lists the top 3 search results aloud (e.g., "1: Nepo Mall, 2: SM Clark..."). The user selects their destination hands-free by speaking the corresponding number ("one", "two", "three" or "una", "pangalawa", "pangatlo") to start navigation immediately. Can say "cancel" to abort.

### Key Files
- `lib/screens/navigation/navigation_screen.dart`

---

## 5. Nearby Text Scanner

Uses Google ML Kit Text Recognition to scan and read text visible through the camera.

### Features
- **On-device OCR** — Runs entirely offline using ML Kit's on-device Text Recognition model.
- **Live feed** — Camera feed processes frames continuously; recognized text appears in real time.
- **TTS read-back** — Detected text is read aloud automatically.
- **Buddy context** — Scanned text can be forwarded to Buddy for explanation ("What is this label?").

### Key Files
- `lib/screens/image_labeling/image_labeling_screen.dart`
- `lib/services/ml_kit_service.dart`

---

## 6. Object Detector

Runs SSD MobileNetV2 for real-time 80-class object detection.

### Features
- **Bounding boxes** — Draws labelled boxes around detected objects in real time on a canvas overlay.
- **Background isolate** — Heavy inference runs on a Dart Isolate worker thread to keep the UI at 60 fps.
- **Confidence threshold** — Only detections above the threshold are displayed and spoken.
- **TTS labels** — Detected object labels are read aloud.

### Key Files
- `lib/screens/object_detection/object_detection_screen.dart`
- `lib/services/tflite_processor.dart`
- `lib/services/isolate_runner.dart`

---

## 7. SOS & Emergency

The Emergency screen provides rapid contact with pre-saved emergency contacts via SMS.

### Features
- **One-tap SOS** — Large, high-contrast SOS button accessible from the Dashboard header and the navigation bar.
- **SMS dispatch** — Sends a pre-formatted emergency SMS (with optional GPS coordinates) to all active emergency contacts via the MensaHero SMS gateway.
- **Emergency contacts list** — Managed in the Contacts screen; saved to both Firestore and local storage.
- **Voice confirmation** — TTS announces when SOS is dispatched.

### Key Files
- `lib/screens/emergency/emergency_screen.dart`
- `lib/services/sms_service.dart`

---

## 8. Settings

A comprehensive configuration panel accessible from the Dashboard header.

### Sections

#### Account
- View profile name and email.
- Sign out.

#### Appearance
- **Contrast theme:** Default (light) or Black (dark/AMOLED).
- **Accent color:** Choose from a palette of accent colors applied globally (buttons, highlights, borders).
- Both selections are saved to `SharedPreferences` and Firestore, and applied instantly via `AppColors` — no restart needed.

#### Accessibility
- **Language:** English or Filipino/Tagalog. Switches all UI strings, Buddy greeting, date header, and routes Filipino queries to Gemini.
- **Units:** Metric (km/m) or Imperial (mi/ft). Applied to navigation distances and step instructions.
- **Shake to Undo:** Toggle accelerometer shake gesture detection.
- **Voice Feedback:** Global TTS on/off toggle.

#### Voice Settings
- **Voice Persona:** Choose from Aria, Echo, Nova, River, Sage. Each persona has a distinct pitch and rate profile.
  - Applied in all TTS calls: Navigation, Buddy, Object Detection, Text Scanner.
- **Speech Rate:** Slider (0.25× – 2.0×).
- **Pitch:** Slider control.
- **Test Persona:** Tap to hear a sample with the current persona.

#### Notifications
- Global notification toggle.
- Per-category toggles: Obstacle Alerts, Battery Alerts, Connection Alerts, Buddy Follow-Up.

#### Home Screen Cards
- Reorder and toggle which action cards appear on the Dashboard.

#### Voice Feedback Screen
- Full dedicated screen (`VoiceFeedbackScreen`) with theme-aware styling and a persona card carousel.

### Key Files
- `lib/screens/settings/settings_screen.dart`
- `lib/screens/settings/voice_feedback_screen.dart`
- `lib/services/settings_service.dart`
- `lib/services/tts_service.dart`
- `lib/constants/colors.dart`

---

## 9. Notifications

### Features
- **In-app notification log** — All system events (obstacle detections, SOS dispatches, navigation arrivals, Buddy interactions) are logged as `AppNotification` objects.
- **Per-category filtering** — View All, Alerts, Navigation, Buddy messages.
- **Persistent storage** — Notification history persisted to `SharedPreferences` (up to 100 entries).
- **Theme-aware** — Adapts to the selected contrast theme and accent color.

### Key Files
- `lib/screens/notifications/notifications_screen.dart`
- `lib/services/notification_service.dart`
- `lib/models/app_notification.dart`

---

## 10. Contacts

### Features
- **Emergency contact management** — Add, edit, and delete contacts with name, phone number, and relationship.
- **Active/inactive toggle** — Only active contacts receive SOS SMS messages.
- **Firestore sync** — Contacts synced to `users/{uid}/contacts` subcollection.
- **Companion mode** — Family/caregiver accounts can be linked for monitoring.

### Key Files
- `lib/screens/contacts/contacts_screen.dart`
- `lib/models/emergency_contact.dart`

---

## 11. Voice & TTS System

EasyLens uses a singleton `TtsService` that is the single point of speech output for every screen.

### Voice Personas

| ID | Name | Pitch | Rate | Character |
|---|---|---|---|---|
| `aria` | Aria | 1.3 | 0.55 | Warm, clear female |
| `echo` | Echo | 0.85 | 0.50 | Deep, calm male |
| `nova` | Nova | 1.5 | 0.65 | Bright, energetic female |
| `river` | River | 1.0 | 0.45 | Neutral, measured |
| `sage` | Sage | 0.75 | 0.40 | Authoritative, slow |

### Filipino TTS Rule
When Filipino is selected, the TTS locale is set to `en-US` (not Tagalog), because:
- English TTS voices correctly pronounce Filipino text (Filipino is a Tagalog-English mix)
- Tagalog-locale voices are robotic and unintelligible on most Android devices
- The persona's pitch and rate profile applies normally

### Features
- `TtsService().speak(text)` — Queued, interrupt-safe speech output.
- `TtsService().stop()` — Cancels any in-progress speech immediately.
- Automatic language detection per locale.
- Applied universally: Navigation, Buddy, Object Detection, Text Scanner, Shake gestures, SOS.

### Key Files
- `lib/services/tts_service.dart`
- `lib/services/settings_service.dart`

---

## 12. Language & Localization

EasyLens supports two languages: **English** and **Filipino (Tagalog)**.

### Translation System
- `TranslationService.translate(key, lang)` — Static lookup map for UI strings.
- All screens that display translated text are wrapped in `ListenableBuilder(listenable: SettingsService())` so they re-render immediately on language change.

### Translation Keys (selected)

| Key | English | Filipino |
|---|---|---|
| `talk_to_buddy` | Talk to Buddy (Local AI) | Kausapin si Buddy (Lokal AI) |
| `easylens` | EasyLens | EasyLens |
| `nearby_text` | Nearby Text | Teksto sa Malapit |
| `nearby_objects` | Nearby Objects | Bagay sa Malapit |
| `audio_navigation` | Audio Navigation | Audio Nabigasyon |
| `sos_emergency` | SOS Emergency | SOS Emerhensya |
| `metric` | Metric | Metriko |
| `imperial` | Imperial | Imperial |

### Screens with live language switching
- Dashboard Home (greeting, date, button labels)
- Settings Screen (all section headers, tile labels)
- Buddy Assistant Sheet (welcome, status, hint text, LLM language)
- Voice Feedback Screen (persona descriptions, labels)
- Navigation Screen (distances in selected unit)

### Key Files
- `lib/services/translation_service.dart`
- `lib/services/settings_service.dart`

---

## 13. Appearance & Theming

EasyLens uses a centralized `AppColors` class that dynamically resolves color values based on the `SettingsService.selectedContrastTheme` and `SettingsService.selectedAccentColor`.

### Contrast Themes

| Theme | Background | Text | Buttons |
|---|---|---|---|
| **Default** | White / Light grey | Navy blue `#002663` | Navy blue |
| **Black** | `#000000` / `#111111` | White | Accent color |

### Accent Colors
A palette of 8 colors is available. When the Black theme is active, the accent color replaces navy blue on buttons, icons, borders, and highlights. The selected accent is saved to `SharedPreferences` and synced to Firestore.

### Dynamic Theming
All screens and components use `AppColors.*` tokens instead of hardcoded colors. `AppColors` resolves at read time by querying `SettingsService()`, so theme changes propagate immediately without rebuilding the widget tree from the root.

### Key Files
- `lib/constants/colors.dart`
- `lib/services/settings_service.dart`

---

## 14. Onboarding & Signup

EasyLens features a multi-step onboarding wizard that collects user preferences before the first launch.

### Steps
1. **Name** — Capture display name.
2. **Conditions** — Select visual/mobility conditions.
3. **Other Conditions** — Free-text for additional conditions.
4. **Mobility Aid** — Select aid type (wheelchair, cane, walker, etc.).
5. **Voice Persona** — Choose and preview a voice persona.
6. **Contrast Theme** — Pick Default or Black theme.
7. **Language** — English or Filipino.
8. **Celebration** — Confetti screen confirming setup completion.

All preferences collected during onboarding are written to `SettingsService` (SharedPreferences) and synced to Firestore under `users/{uid}/preferences`.

### Key Files
- `lib/screens/signup/`
- `lib/screens/signup/steps/`
- `lib/screens/signup/celebration_screen.dart`
- `lib/models/user_preferences.dart`

---

## 15. Hardware Integration (ESP32)

EasyLens supports a custom ESP32-CAM smart glass device for hands-free vision assistance.

### Architecture
- **WiFi AP Mode:** The ESP32 hosts an Access Point: SSID `EasyLens-Camera`, no password.
- **MJPEG Streaming:** `Esp32Service` connects to `http://192.168.4.1:81/stream`, parses raw JPEG boundary frames, and emits `Uint8List` frame updates.
- **LED Flash:** HTTP GET to `/led?val=1` (on) or `/led?val=0` (off).
- **Custom URL:** Users can override the default stream endpoint in Settings.

### Key Files
- `lib/services/esp32_service.dart`
- `lib/screens/hardware/hardware_screen.dart`

---

## 16. Sound & Audio Cues

EasyLens uses `audioplayers` for non-TTS audio feedback — distinct from the voice TTS system.

### Current Sound Cues

| Sound File | Trigger | Behaviour |
|---|---|---|
| `assets/sounds/bark_dashboard.mp3` | User navigates to the Home/Dashboard tab | Plays once; skipped if already on Home tab |

### Implementation
- `AudioPlayer` is instantiated as a field in `_DashboardScreenState` and disposed with the widget.
- The `_onTabChanged(index)` method is the single point of tab switching for the entire dashboard — all navigation paths (navbar tap, Buddy nav, Dashboard button tap) route through it.

### Key Files
- `lib/screens/dashboard/dashboard_screen.dart`
- `assets/sounds/bark_dashboard.mp3`

---

## Changelog

| Version | Date | Changes |
|---|---|---|
| 1.0.0 | 2026-07-08 | Initial release — core vision, navigation, Buddy, SOS, settings |
| 1.1.0 | 2026-07-09 | Filipino language support (all screens), Gemini for Filipino Buddy, bark sound on dashboard, proximity guidance TTS for navigation, dynamic theming rollout |
| 1.2.0 | 2026-07-11 | Capped Gemma tokens to 150 (speedup), typewriter message animations, fixed XNNPACK cancel crash, notification badge count header, shake-to-undo gesture triggers, voice-activated destination search and choices selection, single-tap/long-press map pinning navigation, and refined traffic sign classification. |
