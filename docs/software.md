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

## 4. Software Stack Overview

* **Framework**: Flutter SDK (`^3.11.5`) & Dart SDK (`^3.5.0`)
* **State Management**: Provider (`provider: ^6.1.2`)
* **Edge AI Engine**: TensorFlow Lite (`tflite_flutter: ^0.12.1`) running custom fine-tuned MobileNetV2 SSD (`ssd_mobilenet_v2.tflite`) detecting 24 specialized accessibility object categories (with MS-COCO fallback)
* **Local Generative LLM**: Google Gemma 2B (`flutter_gemma: ^0.13.6`) via Google AI Edge C++ SDK
* **OCR & Vision Labeling**: Google ML Kit Text Recognition (`^0.15.1`) & Image Labeling (`^0.14.2`)
* **Cloud Fallback & Remote AI**: Google Gemini 3.6 Flash (Low) (`google_generative_ai: ^0.4.4`) & Ollama Local Daemon
* **Cloud Backend & Storage**: Cloudflare D1 (SQL Database), Cloudflare R2 (S3-compatible via HMAC AWS SigV4), Firebase Auth/Firestore
* **Accessibility Engines**: `flutter_tts` (Spatial Voice Alerts), `speech_to_text` (Hands-Free Voice Control), `vibration` (Obstacle Haptic Proximity Feedback)
