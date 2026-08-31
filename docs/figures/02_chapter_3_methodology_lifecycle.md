# Chapter 3: Research Methodology & Lifecycle Models

---

## Figure 3.1: EasyLens Project Implementation Timeline and Seven-Phase Activity Roadmap

### APA 7th Citation & Metadata
- **Figure Number**: Figure 3.1
- **Figure Title**: *EasyLens Project Implementation Timeline and Seven-Phase Activity Roadmap*
- **Manuscript Page**: 42
- **PDF Page**: 49
- **Image Asset**: [fig_3_1_timeline_roadmap.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_3_1_timeline_roadmap.png)

```
Figure 3.1
EasyLens Project Implementation Timeline and Seven-Phase Activity Roadmap

Note. Figure 3.1 represents the chronological Gantt chart mapping out the hardware prototyping, machine learning engineering, mobile software construction, empirical walking evaluations, and thesis document finalization phases executed between December 2025 and August 2026.
```

---

### Technical Diagram (Mermaid)

```mermaid
gantt
    title EasyLens Seven-Phase Implementation Roadmap (Dec 2025 – Aug 2026)
    dateFormat  YYYY-MM-DD
    axisFormat  %b %Y

    section Phase 1: Research & Hardware
    Literature Review & Architecture Sourcing       :p1, 2025-12-01, 2026-01-15
    Component Procurement (ESP32-CAM, Lens, Battery) :p1b, 2025-12-15, 2026-01-31

    section Phase 2: Hardware & Enclosure
    Parametric CAD 3D Box Frame Design              :p2, 2026-01-15, 2026-02-28
    PLA 3D Printing, Heatsink & Frame Assembly      :p2b, 2026-02-15, 2026-03-31

    section Phase 3: AI Model Training
    24-Class COCO Cleaning & Spatial Augmentation   :p3, 2026-03-15, 2026-04-30
    4-Phase MobileNetV2 Transfer Learning & TFLite  :p3b, 2026-04-01, 2026-05-15

    section Phase 4: Flutter Mobile App
    Flutter Core Architecture & Dart Isolates       :p4, 2026-05-01, 2026-06-15
    ML Kit OCR, Gemma 2B & Spatial Audio/Haptics    :p4b, 2026-05-15, 2026-06-30

    section Phase 5: Cloud & Backend Sync
    Cloudflare D1 SQL Telemetry & R2 Storage Sync   :p5, 2026-06-15, 2026-07-15
    Firebase Authentication & CI/CD Pipeline Setup  :p5b, 2026-06-20, 2026-07-20

    section Phase 6: Empirical User Testing
    Visually Impaired Walking Trials (N=15)         :p6, 2026-07-01, 2026-08-10
    Technical Expert Quality Evaluations (N=5)      :p6b, 2026-07-15, 2026-08-15

    section Phase 7: Document Polish & Release
    Empirical Data Analysis & WCAG AAA Verification :p7, 2026-08-01, 2026-08-20
    Final Manuscript Defense & Open-Source Release  :p7b, 2026-08-15, 2026-08-28
```

---

## Figure 3.2: The Six-Phase Cross-Industry Standard Process for Data Mining (CRISP-DM) Lifecycle for EasyLens AI Development

### APA 7th Citation & Metadata
- **Figure Number**: Figure 3.2
- **Figure Title**: *The Six-Phase Cross-Industry Standard Process for Data Mining (CRISP-DM) Lifecycle for EasyLens AI Development*
- **Manuscript Page**: 43
- **PDF Page**: 50
- **Image Asset**: [fig_3_2_crisp_dm_lifecycle.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_3_2_crisp_dm_lifecycle.png)

```
Figure 3.2
The Six-Phase Cross-Industry Standard Process for Data Mining (CRISP-DM) Lifecycle for EasyLens AI Development

Note. Figure 3.2 illustrates the cyclical and iterative stages of the CRISP-DM methodology utilized to design, preprocess, fine-tune, evaluate, and deploy the MobileNetV2 SSD edge object detection model for visually impaired pedestrian obstacle recognition.
```

---

### Technical Diagram (Mermaid)

```mermaid
flowchart TD
    subgraph CRISP_DM ["CRISP-DM LIFECYCLE FOR EASYLENS EDGE-AI"]
        direction TB

        BU["1. Business Understanding\n• Real-time edge inference (<20 ms latency)\n• Low-cost, offline wearable constraint\n• Identify 24 critical pedestrian hazards"]
        
        DU["2. Data Understanding\n• Analyze 38,922 raw images from Gobara (2024)\n• Profile 29 raw classes & minority distributions\n• Inspect Philippine urban obstacle variations"]

        DP["3. Data Preparation\n• Prune 5 extreme ghost classes (<=3 instances)\n• Merge 'Person' into 'person' canonical label\n• Map Jeepneys/Tricycles to 'vehicle_other'\n• Spatial augmentations: ±15% brightness, rotation, flip\n• Partition 38,176 images: 80% Train / 10% Val / 10% Test"]

        M["4. Modeling\n• Backbone: MobileNetV2 SSD (Depthwise Separable Convs)\n• 4-Phase Layer-Unfreezing Schedule in Google Colab\n• Adam Optimizer with Cosine Annealing (lr: 1e-3 to 1e-5)"]

        EV["5. Evaluation\n• Confusion matrix over 2,125 isolated test images\n• Top-1 classification accuracy: 88.75%\n• Precision: 87.42%, Recall: 86.91%, mAP@0.5: 85.12%\n• Real-world on-device latency benchmarking (13–18 ms)"]

        DEP["6. Deployment\n• INT8 Post-Training Quantization via TFLite Converter\n• Bundle model binary into Flutter mobile assets\n• Execute on Dart Background Isolates with zero UI jitter\n• Over-The-Air (OTA) distribution via GitHub Releases"]
    end

    BU <--> DU
    DU --> DP
    DP <--> M
    M --> EV
    EV -->|Meets Accuracy & Latency Thresholds| DEP
    EV -.->|Iterate on Failure Cases| BU
    DEP -.->|Continuous Real-World Telemetry| BU
```

---

### Methodological Narrative & Manuscript Context

The research follows the standardized CRISP-DM framework adapted for resource-constrained edge-AI mobile deployment:
1. **Iterative Alignment**: Data understanding and preparation required extensive cleansing to prevent class imbalance from skewing obstacle detection on mobile hardware.
2. **Quantization & Deployment**: The transition from Google Colab cloud training to mobile deployment was bridged via TensorFlow Lite INT8 quantization, reducing the model footprint to under 15 MB while preserving 88.75% classification accuracy across all 24 pedestrian classes.
