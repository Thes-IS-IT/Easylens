# 01 — Project Overview

## Mission

**EasyLens** is a real-time accessibility assistant for visually impaired and neurodivergent users. It combines on-device computer vision, local and cloud AI, voice interaction, and optional ESP32 hardware to give users a "smart companion" that can:

- Identify objects, read text, and recognize faces through the phone camera
- Provide walking navigation warnings (Stop, Avoid, Slow Down, Path Clear)
- Issue non-critical ambient architectural warnings (Door and Window detection)
- Answer questions through an offline-capable AI assistant called **Buddy**
- Send emergency SOS alerts with location data and native contact selection
- Connect to an ESP32-CAM or Smart Glasses for an external camera feed with automatic mobile camera fallback
- Maintain display wakefulness (`wakelock_plus`) during continuous navigation and active onboarding

---

## Technology Stack

### Core
| Layer | Technology | Version |
|---|---|---|
| Framework | Flutter (Dart) | SDK `^3.11.5` |
| State Management | Singleton Services + `ChangeNotifier` + `ListenableBuilder` | — |
| Navigation | Custom `AppRoute` wrapper (`lib/utils/app_route.dart`) | — |
| Build System | GitHub Actions CI/CD | `ci_cd.yml` |
| Screen Power | `wakelock_plus: ^1.2.8` | Screen wake lock during camera, navigation, and signup |
| Device Contacts | `flutter_contacts: ^1.1.9` | Native device contact picker for emergency SOS contact selection |
| Permissions | `permission_handler: ^11.3.1` | Runtime permission management (Contacts, Camera, Location, Audio) |

### AI & Machine Learning
| Component | Package | Purpose |
|---|---|---|
| Object Detection | `google_mlkit_object_detection: ^0.15.1` | Real-time bounding box detection |
| Image Labeling | `google_mlkit_image_labeling: ^0.14.2` | Scene classification labels |
| Text Recognition | `google_mlkit_text_recognition: ^0.15.1` | OCR for reading text |
| Face Detection | `google_mlkit_face_detection: ^0.13.1` | Face registration & recognition |
| TFLite Inference | `tflite_flutter: ^0.12.1` | SSD MobileNetV2 on MS-COCO |
| Offline LLM | `flutter_gemma: ^0.13.6` | Gemma 2B Instruction-Tuned (on-device) |
| Cloud LLM | `google_generative_ai: ^0.4.4` | Gemini 1.5 Flash (online) |

### Storage & Auth
| Component | Package | Purpose |
|---|---|---|
| Authentication | `firebase_auth: ^5.1.2` | User login (email, Google Sign-In) |
| Real-time DB | `cloud_firestore: ^5.0.2` | User profiles, sync state |
| Object Storage | Cloudflare R2 (S3-compatible) | Profile avatars, hazard reports |
| SQL Database | Cloudflare D1 (Workers) | Relational data, emergency contacts |
| Local Prefs | `shared_preferences: ^2.2.3` | Settings persistence, tutorial flags |

### Audio & Accessibility
| Component | Package | Purpose |
|---|---|---|
| Text-to-Speech | `flutter_tts: ^4.2.5` | Voice feedback with personas (Max, Aria, Nova, Leo) & pitch safety [0.5, 2.0] |
| Speech-to-Text | `speech_to_text: ^7.4.0` | Voice command input |
| Sound Effects | `audioplayers: ^6.1.0` | Bark sounds, alert chimes |
| Haptics | `sensors_plus: ^5.0.1` | Vibration for obstacle alerts |

### Hardware
| Component | Package | Purpose |
|---|---|---|
| ESP32-CAM / Glasses | Custom `Esp32Service` | MJPEG video stream, LED flash control, mobile camera auto-fallback |
| Battery | `battery_plus: ^6.0.2` | Battery level monitoring |
| Location | `geolocator: ^11.0.0` | GPS for SOS and weather |
| Maps | `google_maps_flutter: ^2.5.3` | Map display on navigation |

---

## Repository Layout

```
easylens/
├── .github/workflows/       # CI/CD pipeline (ci_cd.yml)
├── assets/
├── Mascots/              # Buddy mascot GIFs and images
│   ├── models/               # TFLite model files, COCO labels
│   ├── images/               # UI images
│   └── sounds/               # Audio files (bark, alerts)
├── docs/
│   ├── source-of-truth/      # 📘 THIS FOLDER — the single source of truth
│   ├── architecture.md        # Detailed technical architecture
│   ├── features.md            # Complete feature catalogue
│   └── ...                    # Additional topic-specific docs
├── lib/
│   ├── main.dart              # App entry point
│   ├── constants/
│   │   └── colors.dart        # AppColors with contrast theme switching
│   ├── l10n/
│   │   └── signup_strings.dart# Multilingual strings for 18-step onboarding signup wizard
│   ├── models/
│   │   ├── app_notification.dart
│   │   ├── emergency_contact.dart
│   │   └── user_preferences.dart
│   ├── screens/               # 16 screen modules (see 03_screens)
│   │   └── hardware/
│   │       └── components/    # Modular UI sub-components (pairing_wizard, hud_camera_view, etc.)
│   ├── services/              # 19 singleton services (see 04_services)
│   ├── utils/
│   │   └── app_route.dart     # Custom page route transitions
│   └── widgets/               # Shared UI widgets (CameraLoadingOverlay, screen tutorials, etc.)
├── test/                      # Unit & widget tests
├── android/                   # Android platform layer
├── ios/                       # iOS platform layer
├── pubspec.yaml               # Dependencies & assets
└── .env                       # Environment variables (API keys)
```

---

## Environment Variables (`.env`)

The app loads `.env` at startup via `flutter_dotenv`. Required keys:

| Key | Purpose |
|---|---|
| `GEMINI_API_KEY` | Google Gemini cloud LLM access |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account for D1/R2 |
| `CLOUDFLARE_R2_ACCESS_KEY_ID` | R2 bucket access key |
| `CLOUDFLARE_R2_SECRET_ACCESS_KEY` | R2 bucket secret key |
| `CLOUDFLARE_R2_BUCKET_NAME` | R2 bucket name |
| `CLOUDFLARE_D1_API_TOKEN` | D1 database API token |
| `CLOUDFLARE_D1_DATABASE_ID` | D1 database ID |

> ⚠️ **Never commit `.env` to version control.** It is listed in `.gitignore`.

---

## App Initialization Order (`main.dart`)

1. Lock orientation to portrait
2. Enable immersive sticky mode (hide system bars)
3. Load `.env` variables
4. Initialize Firebase (graceful fallback to mock mode if config missing)
5. Initialize Gemma offline LLM in background (non-blocking)
6. Initialize `NotificationService` (loads persisted + schedules daily Buddy follow-up)
7. Initialize `Esp32Service` (restores last stream URL from prefs)
8. Initialize `WakelockPlus` to keep screen active when specified by active HUD modes or signup flows
9. `runApp(EasyLensApp())` → `WelcomeScreen`
