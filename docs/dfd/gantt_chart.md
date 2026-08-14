# EasyLens - Project Implementation Gantt Chart Specification

---

## 1. Overview & Project Roadmap

This document outlines the formal project development and evaluation timeline for **EasyLens**, spanning **December 1, 2025 to August 28, 2026**.

The key project phases follow an expanded engineering and validation roadmap:
1. **Phase 1: Project Initiation, Literature Review & Hardware Sourcing** *(Dec 1, 2025 – Feb 15, 2026)*
2. **Phase 2: 3D Box Frame Design & Physical Prototyping** *(Feb 1, 2026 – Mar 31, 2026)*
3. **Phase 3: Dataset Curation & MobileNetV2 Model Training** *(Apr 1, 2026 – May 31, 2026)*
4. **Phase 4: Flutter App Development, Edge AI Engine & Multimodal Accessibility** *(May 1, 2026 – Jul 15, 2026)*
5. **Phase 5: Cloud Integration (Cloudflare D1/R2 & Firebase)** *(Jun 15, 2026 – Jul 20, 2026)*
6. **Phase 6: Empirical User Testing & System Benchmarking Phase** *(Jul 1, 2026 – Aug 15, 2026)*
7. **Phase 7: Final Document Polish, Thesis Refinement & Final Defense** *(Aug 1, 2026 – Aug 28, 2026)*

---

## 2. Simplified Gantt Chart (Phase-Level Overview)

```mermaid
gantt
    title EasyLens Project Implementation Timeline (Dec 2025 - Aug 2026)
    dateFormat  YYYY-MM-DD
    axisFormat  %b %Y

    section Phase 1: Research
    Reqs & Sourcing            :p1, 2025-12-01, 2026-02-15

    section Phase 2: Hardware
    3D Box Frame Design        :p2, 2026-02-01, 2026-03-31

    section Phase 3: AI Model
    Dataset & Model Training   :p3, 2026-04-01, 2026-05-31

    section Phase 4: Mobile App
    Flutter Core & Vision App  :p4, 2026-05-01, 2026-07-15

    section Phase 5: Cloud Tier
    Cloudflare & Firebase Sync :p5, 2026-06-15, 2026-07-20

    section Phase 6: User Testing
    User Evaluation & Audits   :p6, 2026-07-01, 2026-08-15

    section Phase 7: Final Polish
    Thesis Polish & Release    :p7, 2026-08-01, 2026-08-28
```

---

## 3. Detailed Gantt Chart (Task & Deliverable Breakdown)

```mermaid
gantt
    title EasyLens Detailed Execution Schedule (Dec 2025 - Aug 2026)
    dateFormat  YYYY-MM-DD
    axisFormat  %b %Y

    section 1. Initiation & Hardware
    System Modeling & Architecture     :a1, 2025-12-01, 2026-01-15
    Hardware Sourcing (ESP32 / Lens)   :a2, 2026-01-05, 2026-02-15

    section 2. 3D Box Frame & Hardware
    3D Box Frame PETG CAD Design       :b1, 2026-02-01, 2026-03-05
    Thermal Heatsink Pad Fitting       :b2, 2026-02-20, 2026-03-20
    ESP32 Wi-Fi AP Stream Test         :b3, 2026-03-05, 2026-03-31

    section 3. AI Model Training (Apr-May)
    24-Class COCO Cleaning             :c1, 2026-04-01, 2026-04-18
    Spatial Data Augmentation          :c2, 2026-04-12, 2026-04-28
    Phase 1 Warm-up Head Training      :c3, 2026-04-25, 2026-05-08
    Phase 2 Unfreeze Top 30 Layers     :c4, 2026-05-05, 2026-05-18
    Phase 3 & 4 Micro LR Fine-Tuning   :c5, 2026-05-12, 2026-05-25
    TFLite INT8 Quantization           :c6, 2026-05-20, 2026-05-31

    section 4. App Development (May-Jul)
    Flutter Setup & Provider State     :d1, 2026-05-01, 2026-05-20
    Dart Isolate 300x300 Resizer       :d2, 2026-05-15, 2026-06-05
    TFLite Overlay & Bounding Boxes    :d3, 2026-05-25, 2026-06-20
    ML Kit OCR & Gemma 2B LLM          :d4, 2026-06-05, 2026-06-30
    Spatial TTS (EN/TL) & Haptics      :d5, 2026-06-15, 2026-07-08
    Google Maps & OSRM Navigation      :d6, 2026-06-25, 2026-07-15

    section 5. Cloud Backend Sync
    Cloudflare D1 SQL Telemetry API    :e1, 2026-06-15, 2026-07-05
    Cloudflare R2 Bucket & AWS SigV4   :e2, 2026-06-25, 2026-07-15
    Firebase Auth & Firestore Sync     :e3, 2026-07-05, 2026-07-20

    section 6. Empirical User Testing (Jul-Aug)
    Participant Onboarding & Consent   :f1, 2026-07-01, 2026-07-12
    Task Completion Time & Learnability:f2, 2026-07-08, 2026-07-22
    WEAR Scale Comfort & Thermal Audit :f3, 2026-07-18, 2026-08-02
    ISO 5055 Signal Fault Tolerance    :f4, 2026-07-25, 2026-08-08
    WCAG 2.2 AAA Audio Audit           :f5, 2026-08-01, 2026-08-15

    section 7. Document Polish (Aug 1-28)
    Empirical Data & Likert Analysis   :g1, 2026-08-01, 2026-08-10
    Thesis Manuscript Polish & Citations:g2, 2026-08-08, 2026-08-18
    Final Code Optimization & APK/IPA  :g3, 2026-08-15, 2026-08-22
    Final Defense & Academic Sign-off   :g4, 2026-08-20, 2026-08-28
```

---

## 4. Phase Milestone Summary

| Phase | Target Date Range | Key Milestone Deliverable | Status / Output |
| :--- | :--- | :--- | :--- |
| **Phase 1** | Dec 1, 2025 – Feb 15, 2026 | System Requirements & Hardware Component Procurement | ESP32-CAM-MB, OV2640 70° Lens & 1500mAh Bank Sourced |
| **Phase 2** | Feb 1, 2026 – Mar 31, 2026 | 3D Printed Box Frame Prototyping & Thermal Verification | PETG Enclosure with Heatsink Pad Mounting |
| **Phase 3** | **Apr 1, 2026 – May 31, 2026** | **AI Model Training & INT8 Quantization** | **MobileNetV2 SSD (>85% Top-1) Exported to TFLite** |
| **Phase 4** | **May 1, 2026 – Jul 15, 2026** | **Flutter Mobile App Development & Vision Pipeline** | **60 FPS Accessible UI, TFLite, ML Kit OCR & Spatial TTS** |
| **Phase 5** | Jun 15, 2026 – Jul 20, 2026 | Cloud Infrastructure Integration | Cloudflare D1/R2 & Firebase Auth Sync Active |
| **Phase 6** | **Jul 1, 2026 – Aug 15, 2026** | **Empirical User Testing & Verification Phase** | **Learnability, WEAR Scale, ISO 5055 & WCAG 2.2 Audits** |
| **Phase 7** | **Aug 1, 2026 – Aug 28, 2026** | **Document Polish, Thesis Refinement & v1.0 Release** | **Final Manuscript, Production APK/IPA & Defense Sign-off** |
