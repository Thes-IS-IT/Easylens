# Appendix H: Project Timeline & Gantt Charts

---

## Figure H.1: Simplified Gantt Chart (Phase-Level Overview)

### APA 7th Citation & Metadata
- **Figure Number**: Figure H.1
- **Figure Title**: *Simplified Gantt Chart (Phase-Level Overview)*
- **Manuscript Page**: 187
- **PDF Page**: 195
- **Image Asset**: [fig_h_gantt_charts.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_h_gantt_charts.png)

```
Figure H.1
Simplified Gantt Chart (Phase-Level Overview)

Note. Figure H.1 provides a high-level visual summary of the seven (7) core phases comprising the EasyLens research and development schedule between December 2025 and August 2026.
```

---

### Technical Diagram (Mermaid High-Level Gantt)

```mermaid
gantt
    title EasyLens High-Level Phase Overview (Dec 2025 – Aug 2026)
    dateFormat  YYYY-MM-DD
    axisFormat  %b %Y

    section Phase 1: Research
    Research & Component Sourcing       :done, p1, 2025-12-01, 2026-01-31

    section Phase 2: Hardware
    3D Box Frame Design & Prototyping   :done, p2, 2026-01-15, 2026-03-31

    section Phase 3: AI Model
    Dataset Cleaning & Model Training   :done, p3, 2026-03-15, 2026-05-15

    section Phase 4: Mobile App
    Flutter Core & Vision App Pipeline  :done, p4, 2026-05-01, 2026-06-30

    section Phase 5: Cloud Tier
    Cloudflare & Firebase Backend Sync  :done, p5, 2026-06-15, 2026-07-20

    section Phase 6: User Testing
    User Evaluation & Technical Audits  :done, p6, 2026-07-01, 2026-08-15

    section Phase 7: Final Polish
    Thesis Polish & Official Release    :done, p7, 2026-08-01, 2026-08-28
```

---

## Figure H.2: Detailed Gantt Chart (Task & Deliverable Breakdown)

### APA 7th Citation & Metadata
- **Figure Number**: Figure H.2
- **Figure Title**: *Detailed Gantt Chart (Task & Deliverable Breakdown)*
- **Manuscript Page**: 187
- **PDF Page**: 195
- **Image Asset**: [fig_h_gantt_charts.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_h_gantt_charts.png)

```
Figure H.2
Detailed Gantt Chart (Task & Deliverable Breakdown)

Note. Figure H.2 outlines the comprehensive work-breakdown structure (WBS), itemizing the twenty-one (21) discrete engineering tasks, AI fine-tuning milestones, and field-testing protocols executed during project implementation.
```

---

### Technical Diagram (Mermaid Detailed Gantt)

```mermaid
gantt
    title EasyLens Detailed Execution Schedule (Dec 2025 – Aug 2026)
    dateFormat  YYYY-MM-DD
    axisFormat  %b %Y

    section 1. Initiation & Hardware
    System Modeling & Architecture Definition    :done, t1, 2025-12-01, 2026-01-15
    Hardware Sourcing (ESP32-CAM, Lens, LiPo)    :done, t2, 2025-12-15, 2026-01-31

    section 2. 3D Frame & Hardware Fitting
    3D Box Frame PLA CAD Design & Printing       :done, t3, 2026-01-15, 2026-02-28
    Thermal Heatsink Pad & Eyewear Fitting       :done, t4, 2026-02-15, 2026-03-15
    ESP32 Wi-Fi AP MJPEG Stream Latency Test     :done, t5, 2026-03-01, 2026-03-31

    section 3. AI Model Training (Apr–May)
    24-Class COCO Cleaning & Pruning             :done, t6, 2026-03-15, 2026-04-15
    Spatial Data Augmentation Pipeline           :done, t7, 2026-04-01, 2026-04-20
    Phase 1 Warm-up Head Training in Colab       :done, t8, 2026-04-15, 2026-04-25
    Phase 2 Unfreeze Top 30 Layers               :done, t9, 2026-04-25, 2026-05-05
    Phase 3 & 4 Micro-LR Fine-Tuning             :done, t10, 2026-05-01, 2026-05-15
    TFLite INT8 Post-Training Quantization       :done, t11, 2026-05-10, 2026-05-20

    section 4. App Development (May–Jul)
    Flutter Setup & Provider State Layer         :done, t12, 2026-05-01, 2026-05-25
    Dart Isolate 300x300 Resize Pipeline         :done, t13, 2026-05-20, 2026-06-10
    TFLite Overlay & Spatial Bounding Boxes      :done, t14, 2026-06-01, 2026-06-20
    ML Kit OCR & Local Gemma 2B LLM Integration  :done, t15, 2026-06-10, 2026-06-30
    Spatial TTS (EN/TL) & Haptics Engine         :done, t16, 2026-06-20, 2026-07-10
    GPS Clock-Face Walking Navigation            :done, t17, 2026-06-25, 2026-07-15

    section 5. Cloud Backend Sync
    Cloudflare D1 SQL Telemetry API Integration  :done, t18, 2026-06-15, 2026-07-15
    Cloudflare R2 Bucket & AWS SigV4 Uploads     :done, t19, 2026-06-20, 2026-07-20
    Firebase Auth & Firestore Real-Time Sync     :done, t20, 2026-06-25, 2026-07-25

    section 6. Empirical User Testing (Jul–Aug)
    Participant Onboarding & Informed Consent    :done, t21, 2026-07-01, 2026-07-10
    Walking Trials with Visually Impaired (N=15) :done, t22, 2026-07-10, 2026-08-05
    WEAR Scale Comfort & Thermal Safety Audit    :done, t23, 2026-07-15, 2026-08-10
    ISO/IEC 25010 Signal Fault Tolerance Audits  :done, t24, 2026-07-20, 2026-08-12
    WCAG 2.2 AAA Contrast & Audio Priority Audit :done, t25, 2026-07-25, 2026-08-15
    Empirical Data Transcription & Likert Stat   :done, t26, 2026-08-01, 2026-08-18

    section 7. Document Polish (Aug 1–28)
    Thesis Manuscript APA 7th Revisions          :done, t27, 2026-08-01, 2026-08-20
    Final Code Optimization & Release APK/IPA    :done, t28, 2026-08-15, 2026-08-25
    Final Academic Defense & Institutional Sign  :done, t29, 2026-08-25, 2026-08-28
```
