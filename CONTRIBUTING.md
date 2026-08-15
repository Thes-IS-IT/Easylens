# Contributing to EasyLens 👁️🦮

Thank you for your interest in contributing to **EasyLens**! EasyLens is an open-source assistive mobile application combining real-time edge computer vision (fine-tuned MobileNetV2 SSD), on-device multimodal large language models (Google Gemma 2B & Gemini Flash), spatial audio feedback, and wearable ESP32 smart glasses for visually impaired and neurodivergent users.

---

## 🎓 Academic Thesis Context & Research Team

EasyLens is conceptualized, researched, and actively engineered as an undergraduate thesis project at **Holy Angel University (HAU)**, Angeles City, Pampanga, Philippines by the **Thes-IS-IT** research team:

| Researcher / Author | Role / Area of Focus |
|---|---|
| **Graciella Mhervie D. Jimenez** | Research Co-Author & Development Team |
| **Jian Kalel D. Marquez** | Research Co-Author & Development Team & Hardware Engineering |
| **Arron Kian M. Parejas** | Lead Software Architect & AI/Machine Learning Engineer |
| **Jenica Sarah B. Tongol** | Research Co-Author & Development Team |

We welcome contributions from fellow researchers, developers, accessibility advocates, and open-source enthusiasts. Please review the guidelines below before submitting issues or pull requests.

---

## 📜 Code of Conduct & Academic Integrity

When participating in this project, you agree to uphold the following standards:

1. **Accessibility First:** Prioritize the safety, dignity, and real-world needs of visually impaired and neurodivergent individuals in every architectural and UI/UX decision.
2. **Academic & Ethical Integrity:** Ensure that all submitted code, datasets, and intellectual contributions respect intellectual property rights, data privacy, and open-source software licensing.
3. **Respectful & Constructive Collaboration:** Maintain an inclusive, professional, and supportive environment for all contributors regardless of background or experience level.

---

## 🛠️ How You Can Contribute

We welcome contributions across various domains:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                           EasyLens Core Domains                         │
├───────────────────┬───────────────────┬─────────────────────────────────┤
│ 📱 Flutter Mobile │ 🧠 Edge AI / CV   │ 🔌 Wearable Hardware & Cloud   │
│ - UI & Themes     │ - TFLite Models   │ - ESP32-CAM MJPEG Stream        │
│ - State Providers │ - MobileNetV2 SSD │ - Cloudflare D1 / R2 Storage    │
│ - Accessibility   │ - Gemma / Gemini  │ - Firebase Auth & Firestore     │
│ - TTS / STT Voice │ - RAG Knowledge   │ - MensaHero Emergency SMS       │
└───────────────────┴───────────────────┴─────────────────────────────────┘
```

### 1. Flutter & Mobile Development
- Refine UI screens with WCAG 2.2 AAA accessibility compliance (high contrast AMOLED themes, large touch targets).
- Optimize state management with `Provider` and `ListenableBuilder` without introducing unnecessary rebuilds.
- Enhance the Filipino/Tagalog and English localization strings in `lib/constants/`.

### 2. Machine Learning & Computer Vision
- Improve fine-tuned MobileNetV2 SSD 24-class detection accuracy while keeping inference latency strictly under **15ms** on edge devices.
- Extend Google ML Kit text recognition (OCR) and facial landmark feature vector analysis.
- Expand Buddy's knowledge base (`assets/models/buddy_knowledge.json`) with accurate mobility, safety, and assistive tips.

### 3. Hardware & Embedded Systems
- Optimize ESP32-CAM Wi-Fi Access Point streaming (`hardware/esp32_cam_wifi_ap/`) to reduce frame drop rates and power consumption.
- Design wearable 3D-printable mounts or ergonomic frames for smart glass integration.

---

## 💻 Development Workflow & Setup

### Prerequisites
- **Flutter SDK:** Version `^3.11.5` (Dart SDK `>=3.0.0 <4.0.0`)
- **Android Studio / Xcode:** Android SDK 21+ / iOS 14+
- **Git**

### Step-by-Step Local Setup

1. **Fork and Clone the Repository:**
   ```bash
   git clone https://github.com/Thes-IS-IT/Easylens.git
   cd easylens
   ```

2. **Install Flutter Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables:**
   Copy `.env.example` to `.env` and configure the necessary API keys:
   ```bash
   cp .env.example .env
   ```
   > ⚠️ **IMPORTANT:** Never commit `.env` or any sensitive API keys to git.

4. **Verify Static Analysis & Lint Rules:**
   ```bash
   flutter analyze
   ```

5. **Run the Test Suite:**
   ```bash
   flutter test
   ```

6. **Run on a Device / Emulator:**
   ```bash
   # Physical Android Device (Recommended for camera & sensors)
   flutter run --target-platform android-arm64

   # Android Emulator (x86_64)
   flutter run --target-platform android-x64
   ```

---

## 🌿 Branching & Commit Guidelines

### Git Branch Naming
- Feature branches: `feature/short-description` (e.g., `feature/voice-persona-enhancement`)
- Bugfix branches: `fix/short-description` (e.g., `fix/tts-null-pointer`)
- Documentation: `docs/short-description` (e.g., `docs/update-algorithm-guide`)

### Commit Message Conventions
Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:
- `feat:` A new feature or capability
- `fix:` A bug fix
- `docs:` Documentation-only changes
- `perf:` A code change that improves performance or latency
- `refactor:` Code refactoring without functional changes
- `test:` Adding or updating unit/widget tests
- `chore:` Dependency bumps, CI updates, or build configuration

---

## 🚀 Submitting a Pull Request (PR)

Before submitting a Pull Request, verify that:

- [ ] `flutter analyze` passes with zero errors and warnings.
- [ ] `flutter test` executes successfully.
- [ ] Code follows existing architectural patterns (singleton services, null safety, dynamic `AppColors` tokens).
- [ ] Audio, TTS, or visual changes are verified on physical hardware or emulators.
- [ ] New features or major changes include corresponding documentation or tests.
- [ ] The PR description clearly explains the **motivation**, **changes made**, and **testing proof** (screenshots, videos, or logs).

---

## 📬 Contact & Inquiries

For questions regarding research collaboration, academic reproduction, or thesis inquiries, please contact the EasyLens development team via our [GitHub Issues](https://github.com/Thes-IS-IT/Easylens/issues) or reach out directly to the researchers:

- **Graciella Mhervie D. Jimenez**
- **Jian Kalel D. Marquez**
- **Arron Kian M. Parejas**
- **Jenica Sarah B. Tongol**

*Holy Angel University — Department of Computer Science*
