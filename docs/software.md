# Easylens - Software & Supported Mobile Devices Specification

This document provides complete software specifications, supported Android and iPhone (iOS) devices, minimum, recommended, and maximum hardware specifications, as well as build package deployment details for the **Easylens** mobile application.

---

## 1. Supported Operating Systems & Mobile Devices

### 🤖 Android Compatibility
* **Minimum Supported OS**: **Android 10** (API Level 29)
* **Recommended OS**: **Android 13 to Android 15** (API Level 33–35)
* **Architecture**: 64-bit ARM (`arm64-v8a`)
* **USB Feature**: USB Host / USB-OTG (On-The-Go) support required for wired camera modules.

### 🍎 iPhone (iOS) Compatibility
* **Minimum Supported OS**: **iOS 16.0** (Required by native `flutter_gemma` & `MediaPipe` AI runtime dependencies)
* **Recommended OS**: **iOS 17.0 – iOS 18+**
* **Supported Models**: 
  * iPhone 8 / 8 Plus, iPhone X
  * iPhone XR / XS / XS Max
  * iPhone 11 / 11 Pro / 11 Pro Max
  * iPhone 12 / 12 mini / 12 Pro / 12 Pro Max
  * iPhone 13 / 13 mini / 13 Pro / 13 Pro Max
  * iPhone 14 / 14 Plus / 14 Pro / 14 Pro Max
  * iPhone 15 / 15 Plus / 15 Pro / 15 Pro Max
  * iPhone 16 / 16 Plus / 16 Pro / 16 Pro Max
  * iPhone SE (2nd & 3rd Gen)

---

## 2. Hardware Specifications Matrix

| System Resource | Minimum Specification | Recommended Specification | Maximum / Ultra Specification |
| :--- | :--- | :--- | :--- |
| **Android Processor (SoC)** | 64-bit Octa-Core @ 2.0 GHz (Snapdragon 680 / Helio G88) | Snapdragon 8 Gen 1/Gen 2, Tensor G2/G3, Dimensity 9000 | Snapdragon 8 Gen 3 / Tensor G4 (Dedicated NPU/TPU acceleration) |
| **iPhone Processor (SoC)** | Apple A11 / A12 Bionic (iPhone 8 / X / XS / XR / 11) | Apple A15 / A16 Bionic (iPhone 13 / 14 / 15) | Apple A17 Pro / A18 Pro (iPhone 15 Pro / 16 Pro with 16-core Neural Engine) |
| **Android RAM** | **4 GB** LPDDR4 | **8 GB** LPDDR5 | **12 GB – 16 GB** LPDDR5X |
| **iPhone RAM** | **4 GB** RAM | **6 GB** RAM | **8 GB** RAM |
| **Storage Space** | **2.5 GB** Free NVMe/UFS (Local Gemma 2B weights & OCR) | **5.0 GB** Free NVMe/UFS 3.1 | **10.0 GB+** High-Speed NVMe/UFS 4.0 |
| **Wireless Camera Stream** | Dual-band Wi-Fi 802.11 b/g/n (2.4 GHz AP Mode) | Wi-Fi 6 (802.11ax) Dual-Band | Wi-Fi 6E / Wi-Fi 7 (802.11be) |

---

## 3. Platform Build Packages & Deployment Footprint

| Parameter | Android Build (`.apk`) | iOS Build (`.ipa`) |
| :--- | :--- | :--- |
| **File Artifact** | `build/app/outputs/flutter-apk/app-release.apk` | `build/ios/ipa/easylens.ipa` |
| **Package Size** | **~475 MB** | **~154 MB** (ZIP) / **~250 MB** (Uncompressed `.app`) |
| **Architecture Profile** | Multi-Arch FAT Binary (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | Single Architecture (`arm64` iOS devices) |
| **Installation Methods** | Direct APK install / ADB sideload / Google Play Store | AltStore / Sideloadly / Xcode / Apple TestFlight |

---

## 4. EasyLens Full Software Component & Technology Stack Table

| Software Component | Technology Integrated | Primary Architectural Purpose |
| :--- | :--- | :--- |
| **Mobile Application Framework** | **Flutter / Dart** (SDK `^3.11.5` / Dart `^3.5.0`) | Cross-platform accessible UI rendering, camera stream ingestion, and background isolate workers. |
| **State Management** | **Provider Pattern** (`provider: ^6.1.2`) | Reactive application state propagation, settings persistence, and real-time UI rebuilds. |
| **Edge Vision Inference** | **TensorFlow Lite** (`tflite_flutter: ^0.12.1`) | Local, real-time execution of the custom fine-tuned **MobileNetV2 SSD** object detection model (`ssd_mobilenet_v2.tflite`). |
| **On-Device Vision Tools** | **Google ML Kit SDK** (`google_mlkit_*`) | Real-time optical character recognition (OCR), multi-class image labeling, object tracking, and face detection. |
| **On-Device LLM Runtime** | **Google Gemma 2B** (`flutter_gemma: ^0.13.6`) | Offline natural language reasoning, scene description synthesis, and local RAG context handling via Google AI Edge C++ SDK. |
| **Cloud-Based Conversational AI** | **Google Gemini 3.6 Flash (Low)** (`google_generative_ai`) | Remote cloud-backed multi-turn reasoning, vision scene explanation, and conversational assistant mode. |
| **Local LLM Daemon Fallback** | **Ollama Daemon** (`gemma2:2b`) | Local HTTP REST bridge fallback for LLM query processing (`http://10.0.2.2:11434` / `http://localhost:11434`). |
| **Bilingual Spatial Audio Output** | **Flutter TTS** (`flutter_tts: ^4.2.5`) | Offline spatial speech synthesis and priority hazard voice warnings in **English** and **Filipino/Tagalog**. |
| **Voice Command Capture** | **Speech to Text** (`speech_to_text: ^7.4.0`) | Hands-free continuous voice input parsing and spoken assistant query capture. |
| **Tactile Haptic Feedback** | **Vibration Engine** (`vibration: ^3.2.0`) | Variable tactile vibration pulse patterns for button confirmation and proximity hazard warnings. |
| **Mapping, Routing & Navigation** | **Google Maps API** (`google_maps_flutter`) + **OSRM / Photon** | Interactive mapping, turn-by-turn walking route calculations, and address geocoding search. |
| **Soundboard & Audio Alerts** | **AudioPlayers** (`audioplayers: ^6.1.0`) | High-priority hazard warning sound effects, UI chime feedback, and soundboard cues. |
| **Serverless Database** | **Cloudflare D1** | Serverless SQLite relational database for user profile metadata, emergency contacts, and incident logs. |
| **Cloud Object Storage** | **Cloudflare R2** (S3-Compatible) | Diagnostic image store, avatar hosting, and direct uploads signed via HMAC **AWS SigV4** (`crypto: ^3.0.3`). |
| **Authentication & Document Sync** | **Firebase Suite** (`firebase_auth`, `cloud_firestore`) | User session authentication, Google Sign-In (`google_sign_in`), real-time Firestore sync, and Firebase Storage. |
| **Hardware & Environment Sensors** | **Sensors Plus**, **Battery Plus**, **Wakelock Plus** | Accelerometer/gyroscope orientation tracking, real-time power level sensing, and screen wake lock management. |
| **Android Deployment Package** | **Android APK** (`app-release.apk` ~475 MB) | Multi-arch FAT binary (`arm64-v8a`, `armeabi-v7a`, `x86_64`) for direct sideloading and Google Play Store deployment. |
| **iOS Deployment Package** | **iOS IPA** (`easylens.ipa` ~154 MB / ~250 MB `.app`) | Single 64-bit ARM (`arm64`) binary package for AltStore, TestFlight, and Apple App Store deployment. |
