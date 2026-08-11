# EasyLens - Project Implementation Gantt Chart Specification

---

## 1. Overview & Project Roadmap

This document outlines the project development timeline for **EasyLens**, spanning research, hardware prototyping, dataset curation, transfer learning model training, mobile app development, cloud integration, testing, and deployment.

---

## 2. Simplified Gantt Chart (Phase-Level High Overview)

```mermaid
gantt
    title EasyLens Simplified Project Implementation Timeline
    dateFormat  YYYY-MM-DD
    section Phase 1: Research & Hardware
    Requirements & Hardware Sourcing :p1_1, 2025-09-01, 30d
    3D Box Frame Design & Printing   :p1_2, 2025-10-01, 30d

    section Phase 2: AI & Dataset
    Dataset Engineering (24-Class)  :p2_1, 2025-10-15, 45d
    MobileNetV2 Fine-Tuning & Quant  :p2_2, 2025-11-15, 45d

    section Phase 3: Mobile Development
    Flutter Core & Vision Engine     :p3_1, 2025-12-01, 60d
    Accessibility TTS/STT/Haptics    :p3_2, 2026-01-15, 45d

    section Phase 4: Cloud & Integration
    Cloudflare D1/R2 & Firebase      :p4_1, 2026-02-15, 30d
    End-to-End System Integration    :p4_2, 2026-03-15, 30d

    section Phase 5: Evaluation & Thesis
    Usability Testing (ISO 25010)    :p5_1, 2026-04-15, 30d
    Final Thesis & Release (v1.0)    :p5_2, 2026-05-15, 30d
```

---

## 3. Detailed Gantt Chart (Task & Deliverable Level)

```mermaid
gantt
    title EasyLens Detailed System Development & Execution Schedule
    dateFormat  YYYY-MM-DD
    axisFormat  %b %Y

    section 1. Hardware & Physical Prototyping
    Component Selection (ESP32-CAM-MB, OV2640 70° Lens, 1500mAh Bank) :a1, 2025-09-01, 20d
    ESP32 Wi-Fi AP & MJPEG Streaming Firmware Implementation         :a2, 2025-09-20, 25d
    3D Printed Module Box Frame Prototyping & PETG Thermal Cutouts    :a3, 2025-10-10, 30d
    Hardware Power Drain & Battery Lifetime Benchmarking             :a4, 2025-11-05, 15d

    section 2. AI Model Training & Edge Quantization
    26-Class COCO Dataset Cleaning, Class Merging & Ghost Removal    :b1, 2025-10-15, 25d
    Spatial Data Augmentation & Balanced Class Weight Computation    :b2, 2025-11-05, 20d
    MobileNetV2 Transfer Learning - Phase 1 (Warm-up Head Tuning)    :b3, 2025-11-20, 15d
    MobileNetV2 Transfer Learning - Phase 2 (Unfreeze Top 30 Layers):b4, 2025-12-05, 15d
    MobileNetV2 Transfer Learning - Phase 3 & 4 (Deep Unfreezing)   :b5, 2025-12-20, 20d
    Model Evaluation (>85% Top-1) & INT8 TFLite Edge Quantization    :b6, 2026-01-10, 15d

    section 3. Mobile Application Architecture
    Flutter Core Architecture Setup & Provider State Engine          :c1, 2025-12-01, 30d
    Dart Isolate Parallel Processor for 300x300 Matrix Conversion    :c2, 2025-12-25, 20d
    TFLite Interpreter Integration & Bounding Box Rendering          :c3, 2026-01-10, 25d
    Google ML Kit Text Recognition (OCR) & Gemma 2B Local RAG Engine  :c4, 2026-01-25, 30d
    Bilingual (English/Tagalog) Spatial TTS & Vibration Pulse Engine  :c5, 2026-02-10, 25d
    Turn-by-Turn Navigation (Google Maps API + OSRM Routing)         :c6, 2026-02-25, 25d

    section 4. Cloud Backend & Telemetry
    Cloudflare D1 Serverless SQL Schema Design & REST API Binding    :d1, 2026-02-15, 20d
    Cloudflare R2 Bucket Setup & AWS SigV4 Direct Signed Uploads      :d2, 2026-03-01, 20d
    Firebase Authentication (Email/Google Sign-In) & Firestore Sync   :d3, 2026-03-15, 20d

    section 5. Testing, Verification & Final Deployment
    System Benchmarking (UVC Latency <10ms, Wi-Fi Latency <30ms)      :e1, 2026-03-25, 20d
    Empirical Usability Testing (Learnability, Operability, Safety)   :e2, 2026-04-10, 30d
    Final Bug Fixes, Code Optimization & Release Package Build (v1.0) :e3, 2026-05-05, 20d
    Thesis Defense Presentation & Documentation Sign-off              :e4, 2026-05-25, 15d
```

---

## 4. Phase Milestones Summary

| Phase | Milestone Name | Key Target Deliverable | Completion Target |
| :--- | :--- | :--- | :--- |
| **M-1** | Hardware Assembly Verified | Physical 3D-printed box frame with ESP32-CAM-MB streaming 30 FPS over Wi-Fi AP. | November 2025 |
| **M-2** | TFLite Model Quantized | MobileNetV2 SSD achieving **85.55% Top-1 accuracy** and **2.48 ms latency** exported to `ssd_mobilenet_v2.tflite`. | January 2026 |
| **M-3** | Mobile App Engine Operational | Flutter application executing real-time object detection, OCR reading, and bilingual spatial voice alerts. | March 2026 |
| **M-4** | Cloud Sync Infrastructure Live | Cloudflare D1 SQL, R2 bucket storage (AWS SigV4), and Firebase Auth integrated into production app. | April 2026 |
| **M-5** | Empirical Evaluation & Release | Completed usability testing (ISO 25010 / WEAR Scale) and final app binary release (v1.0). | May 2026 |
