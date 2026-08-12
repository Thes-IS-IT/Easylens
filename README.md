# EasyLens 👓

EasyLens is a state-of-the-art accessibility assistant mobile application designed to empower visually impaired and neurodivergent users. **At its core, EasyLens operates on a Custom Fine-Tuned MobileNetV2 Object Detection pipeline.** This high-speed edge vision engine acts as the primary "lens," seamlessly blending local computer vision, on-device large language models (Gemma/Gemini), cloud storage, and wearable ESP32 smart glasses into a real-time smart companion.

---

## 🚀 Key Features

| Feature | Description |
|---|---|
| **Custom Object Detector** | **Core Component:** Custom fine-tuned MobileNetV2 SSD drawing real-time bounding boxes via Dart Isolate background threads for instant obstacle TTS alerts. |
| **Speech Navigation** | Advanced turn-by-turn guidance controlled fully via continuous speech (STT). Includes Filipino/Tagalog support, dynamic map pinning, and global arrival confetti celebrations. |
| **Buddy Local AI** | On-device Gemma-IT 2B LLM for English; Google Gemini 3.6 Flash (Low) for Filipino. Full voice I/O and RAG knowledge base. |
| **Nearby Text Scanner** | Supported by ML Kit OCR; reads text aloud; forwards to Buddy for intelligent context explanation. |
| **SOS & Emergency** | One-tap SMS dispatch to active emergency contacts via MensaHero gateway. |
| **Voice Personas** | 6 personas (including Maya for native Tagalog) with distinct pitch/rate. Applied universally across all TTS output. |
| **Filipino Language** | Full app localization — UI strings, greetings, Buddy, Navigation, Settings — all switch live. |
| **Dynamic Theming** | Default (light) and Black (AMOLED) themes with 8 accent color choices applied globally in real time. |
| **ESP32 Smart Glass** | Streams MJPEG video from a custom ESP32-CAM head-mounted device over WiFi directly into the Object Detection pipeline. |
| **Shake to Undo** | Accelerometer gesture (>2.5g) triggers undo action + TTS confirmation. |
| **Bark Sound Cue** | `bark_dashboard.mp3` plays once when returning to the Home tab. |

---

## 🛠️ Tech Stack & Services

### Core
- **Flutter (Dart SDK `^3.11.5`)** — Cross-platform mobile runtime
- **Provider + ListenableBuilder** — Reactive state management

### AI / ML
- **`flutter_gemma: ^0.13.6`** — On-device Gemma-IT 2B (English Buddy, offline)
- **`google_generative_ai: ^0.4.4`** — Gemini 3.6 Flash (Low) API (Filipino Buddy)
- **`google_mlkit_text_recognition: ^0.15.1`** — On-device OCR (Text Scanner)
- **`google_mlkit_image_labeling: ^0.14.2`** — On-device image labeling
- **`tflite_flutter: ^0.12.1`** — MobileNetV2 SSD object detection

### Audio & Accessibility
- **`flutter_tts: ^4.2.5`** — Text-to-Speech with persona support
- **`speech_to_text: ^7.4.0`** — Voice input for Buddy and navigation
- **`audioplayers: ^6.1.0`** — Sound effect cues (bark, etc.)

### Location & Sensors
- **`google_maps_flutter: ^2.5.3`** — Map rendering & route display
- **`geolocator: ^11.0.0`** — GPS position stream
- **`sensors_plus: ^5.0.1`** — Accelerometer (shake detection)

### Cloud & Storage
- **Firebase Auth + Firestore + Storage** — Auth, profile sync, avatar storage
- **Cloudflare R2** — Object storage (captures, backups)
- **Cloudflare D1** — Serverless SQL (relational sync)
- **`shared_preferences: ^2.2.3`** — Local on-device key-value store

### Networking
- **`http: ^1.2.1`** — REST calls (Google Maps routing, Ollama, Geocoding, ESP32)
- **`flutter_dotenv: ^5.2.1`** — `.env` secrets management

---

## 📐 Architecture

For a complete breakdown of the project layout, database systems, and data flow, see the [Full Architecture Document](docs/ARCHITECTURE.md).

```mermaid
graph TD
    UI[Flutter Screen UI] <--> Providers[ListenableBuilder / Provider]
    Providers <--> Vision[TFLite / MLKit Services]
    Providers <--> Hardware[ESP32 Smart Glass via WiFi]
    Providers <--> RAG[RagService — Gemma / Gemini]
    Providers <--> Cloud[Firebase & Cloudflare Services]
    Providers <--> Audio[TtsService / AudioPlayers]
    Providers <--> GPS[Geolocator Position Stream]
```

### Key Documents

| Document | Description |
|---|---|
| [object_detection_architecture.md](docs/object_detection_architecture.md) | Deep dive into the core MobileNetV2 pipeline, ML Kit, and Speech Navigation |
| [ai_architecture.md](docs/ai_architecture.md) | Deep dive into Local LLM (Gemma), Gemini integration, RAG system, and Autopilot routing |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Complete technical architecture, data flow, database schemas |
| [FEATURES.md](docs/FEATURES.md) | Full feature catalogue with screen-by-screen breakdown |
| [cloudflare_r2_setup.md](docs/cloudflare_r2_setup.md) | Cloudflare R2 bucket setup and CORS configuration |
| [local_storage_architecture.md](docs/local_storage_architecture.md) | Local storage strategy, Firestore sync, and security rules |

---

## 💻 Developer Guide

### Prerequisites
- Flutter SDK (version matching `pubspec.yaml` environment — SDK `^3.11.5`)
- Android SDK 21+ / Xcode 14+
- A physical Android device or emulator
- Firebase project configured (see `google-services.json`)
- `.env` file with required keys (see `.env.example`)

### Environment Variables (`.env`)
```env
GEMINI_API_KEY=your_gemini_api_key
FIREBASE_API_KEY=...
FIREBASE_APP_ID=...
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_PROJECT_ID=...
FIREBASE_STORAGE_BUCKET=...
GOOGLE_MAPS_KEY=your_maps_api_key
MENSAHERO_API_KEY=your_sms_gateway_key
MENSAHERO_BASE_URL=https://mensahero.onrender.com
ACCOUNT_ID=your_cloudflare_account_id
S3_API=https://<account_id>.r2.cloudflarestorage.com/<bucket>
ACCESS_KEY_ID=...
SECRET_ACCESS_KEY=...
BUCKET_NAME=easylens
```

### Running the App

#### Physical Device (recommended)
```bash
flutter run --target-platform android-arm64
```

#### Android Emulator
Because the app bundles complex native libraries (ML Kit, Gemma, TensorFlow Lite), debug builds compile for all ABIs by default. To avoid `Requested internal only, but not enough space` errors on the emulator:
```bash
flutter run --target-platform android-x64
```

#### Wireless ADB (Samsung Galaxy A55 / similar)
```bash
adb connect <device-ip>:5555
flutter run
```

### Installing the On-Device Gemma Model
The Gemma-IT 2B model (`model.bin`, ~1.3 GB) must be pushed to the device manually:
```bash
adb push model.bin /sdcard/Android/data/com.company.easylens/files/model.bin
```
Then restart the app. Buddy will automatically detect the model and use it for English queries.

### Running Tests
```bash
flutter test
flutter analyze
```

---

## 🌐 Language Support

| Language | Code | UI | Buddy | TTS Voice |
|---|---|---|---|---|
| English | `en` | ✅ | Gemma (offline) | en-US persona |
| Filipino / Tagalog | `fil` | ✅ | Gemini 3.6 Flash (Low) | en-US persona (Filipino text pronounced correctly) |

---

## 📁 Project Structure (abbreviated)

```
easylens/
├── lib/
│   ├── constants/        # AppColors — dynamic theme tokens
│   ├── models/           # UserPreferences, AppNotification, EmergencyContact
│   ├── services/         # TtsService, RagService, SettingsService, Esp32Service…
│   ├── screens/
│   │   ├── dashboard/    # Home, Buddy, Navbar, Mascot Banner
│   │   ├── navigation/   # GPS turn-by-turn with proximity TTS
│   │   ├── hardware/     # ESP32 camera + ML Kit live feed
│   │   ├── settings/     # Full settings panel + Voice Feedback screen
│   │   ├── emergency/    # SOS dispatch
│   │   ├── contacts/     # Emergency contact management
│   │   ├── notifications/ # In-app notification log
│   │   ├── signup/       # 8-step onboarding wizard
│   │   └── object_detection/ # TFLite bounding box screen
│   └── utils/            # AppRoute (declarative navigation)
├── assets/
│   ├── Mascots/          # Buddy mascot images (idle, thinking, listening…)
│   ├── models/           # TFLite model files
│   ├── images/           # App images
│   └── sounds/           # bark_dashboard.mp3 and other audio cues
├── docs/                 # Full technical documentation
└── .env                  # API keys and secrets (never commit)
```

---

## 🔒 Security

- All API keys stored in `.env` (excluded from git via `.gitignore`)
- Cloudflare R2 uploads use client-side **AWS Signature Version 4** (HMAC-SHA256) — no secrets transmitted in plaintext
- Firebase Security Rules enforce per-user read/write isolation
- Gemma runs fully **on-device** for English — no user query data leaves the device





