# Chapter 4: Model Training, CI/CD Pipeline & Over-The-Air Update Architecture

---

## Figure 4.1: The Multi-Phase Transfer Learning and Unfreezing Workflow for the MobileNetV2 SSD Network Architecture

### APA 7th Citation & Metadata
- **Figure Number**: Figure 4.1
- **Figure Title**: *The Multi-Phase Transfer Learning and Unfreezing Workflow for the MobileNetV2 SSD Network Architecture*
- **Manuscript Page**: 122
- **PDF Page**: 130
- **Image Asset**: [fig_4_1_transfer_learning_workflow.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_4_1_transfer_learning_workflow.png)

```
Figure 4.1
The Multi-Phase Transfer Learning and Unfreezing Workflow for the MobileNetV2 SSD Network Architecture

Note. Figure 4.1 illustrates the systematic four-phase transfer learning and layer-unfreezing workflow implemented in Google Colab to train the MobileNetV2 SSD network, showing the progressive transition from a frozen feature extractor to fully unfrozen convolutional base weights.
```

---

### Technical Diagram (Mermaid Flowchart)

```mermaid
flowchart TD
    PRETRAINED["Pre-Trained Base Weights\n(ImageNet Pre-Trained MobileNetV2 SSD Backbone)"]

    subgraph PHASE1 ["Phase 1: Warm-Up Head Training (Epochs 1–10)"]
        direction TB
        P1_ACT["Freeze entire convolutional base (Layers 1–154)\nTrain newly initialized SSD detection heads & 24-class classifiers"]
        P1_LR["Learning Rate: 1e-3 | Optimizer: Adam | Batch Size: 32"]
    end

    subgraph PHASE2 ["Phase 2: Partial Unfreezing (Epochs 11–25)"]
        direction TB
        P2_ACT["Unfreeze Top 30 Bottleneck Residual Blocks (Layers 125–154)\nAdapt higher-level feature representations to pedestrian hazards"]
        P2_LR["Learning Rate: 1e-4 with Step Decay"]
    end

    subgraph PHASE3 ["Phase 3: Deep Base Unfreezing (Epochs 26–40)"]
        direction TB
        P3_ACT["Unfreeze Intermediate Convolutional Layers (Layers 60–124)\nAlign low-level edge and texture filters with sidewalk terrain"]
        P3_LR["Learning Rate: 5e-5 with Cosine Annealing"]
    end

    subgraph PHASE4 ["Phase 4: Full Network Micro Fine-Tuning (Epochs 41–50)"]
        direction TB
        P4_ACT["Unfreeze All 154 Layers\nFine-tune all weights across full 38,176 image dataset"]
        P4_LR["Learning Rate: 1e-5 (Micro-Learning Rate)"]
    end

    subgraph POST_TRAIN ["Post-Training Quantization & Export"]
        direction TB
        EVAL["Model Validation on 2,125 Test Images\n• Top-1 Accuracy: 88.75%\n• mAP@0.5: 85.12%\n• Precision: 87.42% | Recall: 86.91%"]
        QUANT["TensorFlow Lite INT8 Post-Training Quantization\nFootprint reduced from ~68 MB to 14.8 MB"]
        EXPORT["Deploy to Flutter Assets (mobilenetv2_24class.tflite)"]
    end

    PRETRAINED --> PHASE1
    PHASE1 --> PHASE2
    PHASE2 --> PHASE3
    PHASE3 --> PHASE4
    PHASE4 --> EVAL
    EVAL --> QUANT
    QUANT --> EXPORT
```

---

## Figure 4.2: EasyLens Automated CI/CD Codebase Analysis and Deployment Pipeline Flowchart

### APA 7th Citation & Metadata
- **Figure Number**: Figure 4.2
- **Figure Title**: *EasyLens Automated CI/CD Codebase Analysis and Deployment Pipeline Flowchart*
- **Manuscript Page**: 126
- **PDF Page**: 134
- **Image Asset**: [fig_4_2_cicd_pipeline_flowchart.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_4_2_cicd_pipeline_flowchart.png)

```
Figure 4.2
EasyLens Automated CI/CD Codebase Analysis and Deployment Pipeline Flowchart

Note. Figure 4.2 outlines the automated continuous integration and continuous deployment (CI/CD) pipeline built using GitHub Actions, detailing the static code analysis, native testing, containerized runner compilation, and automated artifact release channels.
```

---

### Technical Diagram (Mermaid Flowchart)

```mermaid
flowchart TD
    DEV_PUSH["Developer Pushes Commit to 'main' Branch"] --> GH_TRIGGER["GitHub Actions Webhook Triggers CI Workflow"]
    
    subgraph STAGE1 ["Stage 1: Code Quality & Static Analysis"]
        direction TB
        SETUP["Setup Runner: Ubuntu Environment + Java 17 + Flutter SDK"]
        PUB["Fetch Dependencies: 'flutter pub get'"]
        LINT["Static Code Linting: 'flutter analyze' (Zero Errors Threshold)"]
    end

    subgraph STAGE2 ["Stage 2: Native Automated Testing"]
        direction TB
        UNIT["Unit & Widget Testing: 'flutter test --coverage'"]
        ASSERT["Assert Test Passes & State Management Isolation"]
    end

    subgraph STAGE3 ["Stage 3: Multi-Architecture Build & Containerization"]
        direction TB
        APK["Compile Release FAT APK ('flutter build apk --release')\n(Bundling TFLite, ML Kit & INT4 Model Weights)"]
        IPA["Compile iOS Release Bundle ('flutter build ipa --no-codesign')"]
        DOCKER["Build Docker Container for CI Artifact Reproducibility"]
    end

    subgraph STAGE4 ["Stage 4: Automated Distribution & Registry"]
        direction TB
        GHCR["Push Docker Image to GitHub Container Registry (GHCR)"]
        RELEASE["Create GitHub Release Tag with Release Notes"]
        ATTACH["Attach 'app-release.apk' & 'app-release.ipa' to GitHub Releases"]
    end

    GH_TRIGGER --> SETUP
    SETUP --> PUB
    PUB --> LINT
    LINT -->|Clean Codebase| UNIT
    UNIT --> ASSERT
    ASSERT -->|All Tests Pass| APK
    APK --> IPA
    IPA --> DOCKER
    DOCKER --> GHCR
    GHCR --> RELEASE
    RELEASE --> ATTACH
    ATTACH --> OTA_READY(["Artifact Ready for In-App Over-The-Air (OTA) Delivery"])
```

---

## Figure 4.3: Detailed CI/CD Sequence and Over-The-Air (OTA) Application Update Architecture

### APA 7th Citation & Metadata
- **Figure Number**: Figure 4.3
- **Figure Title**: *Detailed CI/CD Sequence and Over-The-Air (OTA) Application Update Architecture*
- **Manuscript Page**: 126
- **PDF Page**: 134–135
- **Image Asset**: [fig_4_3_ota_update_sequence.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_4_3_ota_update_sequence.png)

```
Figure 4.3
Detailed CI/CD Sequence and Over-The-Air (OTA) Application Update Architecture

Note. Figure 4.3 displays the UML sequence diagram and physical interaction loop of the over-the-air (OTA) update system, mapping the network transactions between the Buddy client application and the GitHub Releases API to retrieve stable package versions.
```

---

### Technical Diagram (Mermaid Sequence Diagram)

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer
    participant Git as GitHub Repository
    participant Actions as GitHub Actions Runner
    participant GHCR as GitHub Container Registry (GHCR)
    participant Releases as GitHub Releases API
    participant App as EasyLens Mobile Client

    %% Continuous Integration & Deployment Flow
    rect rgb(240, 248, 255)
        note over Dev, Releases: CI/CD Build & Release Phase
        Dev->>Git: git push origin main
        Git->>Actions: Trigger CI/CD Workflow
        Actions->>Actions: Run 'flutter analyze' & 'flutter test'
        Actions->>Actions: Compile Release FAT APK (Android) & IPA (iOS)
        Actions->>GHCR: Push Containerized Build Image
        Actions->>Releases: Create Tagged Release (e.g., v1.4.2) & Upload APK Artifacts
        Releases-->>Actions: Artifacts Published Successfully
    end

    %% Over-The-Air (OTA) In-App Update Flow
    rect rgb(255, 250, 240)
        note over App, Releases: Client Over-The-Air (OTA) Update Flow
        App->>App: User Enters Settings Panel / Periodic Background Check
        App->>Releases: GET /repos/Thes-IS-IT/Easylens/releases/latest
        Releases-->>App: Return JSON Payload (tag_name, body, assets[browser_download_url])
        App->>App: Compare Local App Version (e.g., v1.4.1) vs. Remote Tag (v1.4.2)
        
        alt Newer Version Available
            App->>App: Spoken Announcement: "A new EasyLens update is available."
            App->>Releases: GET /download/app-release.apk (Stream Download)
            Releases-->>App: Binary Stream Transferred
            App->>App: Verify SHA-256 Checksum & Prompt Native Package Installer
        else App is Up to Date
            App->>App: Spoken Confirmation: "EasyLens is currently up to date."
        end
    end
```
