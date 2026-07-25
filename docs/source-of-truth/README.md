# 📘 EasyLens — Source of Truth

> **Last Updated:** July 20, 2026  
> **Flutter SDK:** `^3.11.5` · **Dart 3**  
> **Platforms:** Android, iOS

This folder is the single source of truth for the EasyLens project. Every architectural decision, known issue, coding convention, and operational pattern is documented here.

---

## 📑 Document Index

| Document | Description |
|---|---|
| [01 — Project Overview](./01_project_overview.md) | Mission, tech stack, and repository layout |
| [02 — Architecture](./02_architecture.md) | High-level system architecture, data flow, and service dependency graph |
| [03 — Screens & Navigation](./03_screens_and_navigation.md) | Every screen, its purpose, key files, and navigation patterns |
| [04 — Services Reference](./04_services_reference.md) | All singleton services, their responsibilities, and public APIs |
| [05 — AI & ML Pipeline](./05_ai_ml_pipeline.md) | Object detection, image labeling, TFLite, Gemma, Gemini, RAG, and guardrails |
| [06 — Walking Navigation System](./06_walking_navigation.md) | Obstacle warning logic, coordinate math, and state machine |
| [07 — Known Issues & Workarounds](./07_known_issues.md) | Active bugs, platform-specific workarounds, and gotchas |
| [08 — Coding Conventions](./08_coding_conventions.md) | Patterns, naming, state management, and anti-patterns to avoid |
| [09 — Testing & CI/CD](./09_testing_cicd.md) | Test suite, GitHub Actions pipeline, and deployment |
| [10 — Localization](./10_localization.md) | English/Tagalog translation system and adding new languages |

---

## 🔑 Quick Reference

- **Primary Color:** `#002663` (Deep Blue)
- **Entry Point:** `lib/main.dart` → `WelcomeScreen`
- **State Management:** Singleton services + `ChangeNotifier` / `ListenableBuilder`
- **Storage:** Firebase Auth + Firestore, Cloudflare D1 (SQL), Cloudflare R2 (Object Store)
- **AI Stack:** Google ML Kit (on-device) → TFLite SSD MobileNetV2 → Gemma 2B (offline LLM) → Gemini Flash (cloud LLM)
- **Languages:** English, Tagalog (Filipino) with dynamic fallback and `signup_strings.dart`
- **Hardware Integrations:** Smart Glasses / ESP32-CAM MJPEG Video Stream with Mobile Camera Fallback
- **Safety & Power:** Wakelock integration (`wakelock_plus`) + Non-critical Door & Window warnings + Safe Android Pitch range [0.5, 2.0]
- **CI/CD:** GitHub Actions → `flutter analyze` static verification on every push and PR to `main`
