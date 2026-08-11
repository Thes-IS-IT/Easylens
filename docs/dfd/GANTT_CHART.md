# EasyLens - Project Implementation Gantt Chart Specification

---

## 1. Overview & Project Roadmap

This document outlines the formal project development timeline for **EasyLens**, spanning **December 1, 2025 to August 5, 2026**.

The key project phases follow a chronological engineering roadmap:
1. **Phase 1: Project Initiation, Literature Review & Hardware Sourcing** *(Dec 1, 2025 – Feb 15, 2026)*
2. **Phase 2: 3D Box Frame Design & Physical Prototyping** *(Feb 1, 2026 – Mar 31, 2026)*
3. **Phase 3: Dataset Curation & MobileNetV2 Model Training** *(Apr 1, 2026 – May 31, 2026)*
4. **Phase 4: Flutter App Development, Edge AI Engine & Multimodal Accessibility** *(May 1, 2026 – Jul 15, 2026)*
5. **Phase 5: Cloud Integration (Cloudflare D1/R2 & Firebase)** *(Jun 15, 2026 – Jul 25, 2026)*
6. **Phase 6: Empirical Usability Evaluation, System Benchmarking & Release** *(Jul 1, 2026 – Aug 5, 2026)*

---

## 2. Simplified Gantt Chart (Phase-Level Overview)

```mermaid
gantt
    title EasyLens Project Timeline (Dec 1, 2025 – Aug 5, 2026)
    dateFormat  YYYY-MM-DD
    axisFormat  %b %Y

    section Phase 1: Research & Hardware Sourcing
    Project Initiation & Requirements      :p1, 2025-12-01, 2026-02-15

    section Phase 2: 3D Prototyping & Frame Design
    3D Box Frame Design & Thermal Fit      :p2, 2026-02-01, 2026-03-31

    section Phase 3: AI Model Training & Quantization
    COCO Dataset Cleaning & Model Training :p3, 2026-04-01, 2026-05-31

    section Phase 4: Mobile App Development
    Flutter Core, Edge AI & Accessibility  :p4, 2026-05-01, 2026-07-15

    section Phase 5: Cloud & Telemetry Sync
    Cloudflare D1/R2 & Firebase Setup      :p5, 2026-06-15, 2026-07-25

    section Phase 6: Evaluation & Final Release
    Usability Testing & Final Defense v1.0 :p6, 2026-07-01, 2026-08-05
```

---

## 3. Detailed Gantt Chart (Task & Deliverable Breakdown)

```mermaid
gantt
    title EasyLens Detailed Engineering Execution Schedule (Dec 2025 - Aug 2026)
    dateFormat  YYYY-MM-DD
    axisFormat  %b %d

    section 1. Project Initiation & Hardware Sourcing
    Literature Review, System Architecture & Use Case Modeling :a1, 2025-12-01, 2026-01-15
    Hardware Sourcing (ESP32-CAM-MB, OV2640 70° Lens, 1500mAh Bank):a2, 2026-01-05, 2026-02-15

    section 2. 3D Box Frame & Physical Prototyping
    3D Printed Module Box Frame CAD Modeling (PETG Housing)    :b1, 2026-02-01, 2026-03-05
    Thermal Dissipation Fit (Heatsink Pad & Air Ventilation)   :b2, 2026-02-20, 2026-03-20
    ESP32 Wi-Fi AP & Video Stream Firmware Benchmarking        :b3, 2026-03-05, 2026-03-31

    section 3. AI Model Training & Quantization (Apr - May 2026)
    26-Class COCO Dataset Cleaning, Class Merging & Ghost Removal:c1, 2026-04-01, 2026-04-18
    Spatial Data Augmentation & Class Weighting Calculation      :c2, 2026-04-12, 2026-04-28
    MobileNetV2 Phase 1 Warm-up Head Training (LR = 1e-3)        :c3, 2026-04-25, 2026-05-08
    MobileNetV2 Phase 2 Mid-Level Layer Tuning (Top 30 Layers)  :c4, 2026-05-05, 2026-05-18
    MobileNetV2 Phase 3 & 4 Deep Fine-Tuning (Micro LR Decay)    :c5, 2026-05-12, 2026-05-25
    TFLite INT8 Post-Training Quantization (ssd_mobilenet_v2.tflite):c6, 2026-05-20, 2026-05-31

    section 4. Mobile App Development (May - Jul 2026)
    Flutter SDK Framework Setup & Provider State Engine         :d1, 2026-05-01, 2026-05-20
    Dart Isolate Parallel Processor (300x300 Matrix Conversion) :d2, 2026-05-15, 2026-06-05
    TFLite Interpreter Integration & Bounding Box UI Overlay    :d3, 2026-05-25, 2026-06-20
    Google ML Kit Text OCR & Google Gemma 2B Local LLM Integration:d4, 2026-06-05, 2026-06-30
    Bilingual Spatial Audio TTS (EN/TL) & Vibration Pulse Engine:d5, 2026-06-15, 2026-07-08
    Turn-by-Turn Navigation (Google Maps API + OSRM Routing)    :d6, 2026-06-25, 2026-07-15

    section 5. Cloud Integration & Backend Sync
    Cloudflare D1 Serverless SQL Telemetry & Contact Binding    :e1, 2026-06-15, 2026-07-05
    Cloudflare R2 Bucket & AWS SigV4 Direct Signed Uploads      :e2, 2026-06-25, 2026-07-15
    Firebase Auth (Google Sign-In) & Firestore Sync Integration  :e3, 2026-07-05, 2026-07-25

    section 6. Evaluation, Testing & Final Release (Jul - Aug 2026)
    System Latency Benchmarking (UVC <10ms, Wi-Fi <30ms)         :f1, 2026-07-01, 2026-07-18
    Empirical Usability Testing (ISO 25010 / WEAR Scale Evaluation):f2, 2026-07-10, 2026-07-28
    Final Bug Fixes, Code Polish & APK/IPA Build Release (v1.0) :f3, 2026-07-20, 2026-08-02
    Thesis Defense & Final Project Sign-off                      :f4, 2026-08-01, 2026-08-05
```

---

## 4. Phase Milestone Summary

| Phase | Target Date Range | Key Milestone Deliverable | Status / Output |
| :--- | :--- | :--- | :--- |
| **Phase 1** | Dec 1, 2025 – Feb 15, 2026 | System Requirements & Hardware Component Procurement | ESP32-CAM-MB, OV2640 70° Lens & 1500mAh Bank Sourced |
| **Phase 2** | Feb 1, 2026 – Mar 31, 2026 | 3D Printed Box Frame Prototyping & Thermal Verification | PETG Enclosure with Heatsink Pad Mounting |
| **Phase 3** | **Apr 1, 2026 – May 31, 2026** | **AI Model Training & INT8 Quantization** | **MobileNetV2 SSD (>85% Top-1) Exported to TFLite** |
| **Phase 4** | **May 1, 2026 – Jul 15, 2026** | **Flutter Mobile App Development & Vision Pipeline** | **60 FPS Accessible UI, TFLite, ML Kit OCR & Spatial TTS** |
| **Phase 5** | Jun 15, 2026 – Jul 25, 2026 | Cloud Infrastructure Integration | Cloudflare D1/R2 & Firebase Auth Sync Active |
| **Phase 6** | **Jul 1, 2026 – Aug 5, 2026** | **Empirical Evaluation, Thesis Defense & v1.0 Release** | **Usability Verification & Production Build Release** |
