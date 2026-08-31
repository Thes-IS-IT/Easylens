# Appendix E: Current & Proposed Data Flow Diagrams (DFD)

---

## Figure E.1: Current Baseline System Detailed Data Flow Diagram

### APA 7th Citation & Metadata
- **Figure Number**: Figure E.1
- **Figure Title**: *Current Baseline System Detailed Data Flow Diagram*
- **Manuscript Page**: 180
- **PDF Page**: 188
- **Image Asset**: [fig_e_1_baseline_dfd.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_e_1_baseline_dfd.png)

```
Figure E.1
Current Baseline System Detailed Data Flow Diagram

Note. Figure E.1 illustrates the traditional cloud-reliant assistive application pipeline, highlighting the severe latency bottlenecks caused by continuous image uploading to remote servers.
```

---

### Technical Diagram (Mermaid Level-1 DFD)

```mermaid
flowchart LR
    USER["External Entity:\nUser / Patient"]
    CLOUD["External Entity:\nRemote Vision Cloud API"]
    STORE[("Data Store:\nLocal Saved Images")]

    subgraph BASELINE_PIPELINE ["Traditional Cloud-Dependent Assistive Pipeline"]
        P1["1.0 Manual Image Capture Process"]
        P2["2.0 Cloud Payload Serializer"]
        P3["3.0 Remote Cloud Processing Engine"]
        P4["4.0 Monolithic Voice Generator"]
    end

    USER -->|"Manual Button Tap"| P1
    P1 -->|"Raw JPEG Buffer"| P2
    P1 -->|"Save Snapshots"| STORE
    P2 -->|"HTTP REST POST (Base64 JPEG)"| CLOUD
    CLOUD -->|"JSON Classification Response\n(High Latency: 1,500–4,000 ms)"| P3
    P3 -->|"Parsed Category String"| P4
    P4 -->|"Monolithic Audio TTS Stream"| USER
```

---

## Figure E.2: Proposed EasyLens Wearable Edge-AI System Detailed Data Flow Diagram

### APA 7th Citation & Metadata
- **Figure Number**: Figure E.2
- **Figure Title**: *Proposed EasyLens Wearable Edge-AI System Detailed Data Flow Diagram*
- **Manuscript Page**: 181
- **PDF Page**: 189
- **Image Asset**: [fig_e_2_proposed_edge_ai_dfd.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_e_2_proposed_edge_ai_dfd.png)

```
Figure E.2
Proposed EasyLens Wearable Edge-AI System Detailed Data Flow Diagram

Note. Figure E.2 presents the comprehensive Level-1 and Level-2 data flow diagram of the proposed EasyLens wearable edge-AI system, demonstrating the localized real-time data streaming, parallel Dart Isolate processing, on-device machine learning inference, and asynchronous cloud synchronization tiers.
```

---

### Technical Diagram (Mermaid Detailed Architecture DFD)

```mermaid
flowchart TD
    subgraph HW ["1.0 Physical Wearable Hardware Unit"]
        direction TB
        CAM["ESP32-CAM OV2640 Sensor (70° Lens)"]
        PWR["1,500 mAh Keychain Powerbank (5V)"]
        SINK["Passive Aluminum Heatsink Dissipation"]
    end

    subgraph NET ["2.0 Wireless Transport Protocol"]
        WIFI["Wi-Fi AP Video Stream (192.168.4.1:81/stream)\nMJPEG Byte Stream @ 30 FPS"]
    end

    subgraph ENGINE ["3.0 EasyLens Mobile Processing Engine (Flutter Core)"]
        direction TB
        
        P31["3.1 MJPEG Frame Ingestion & Buffer"]
        P32["3.2 Dart Parallel Isolate Worker\n(Resize to 300x300 Matrix & Normalize)"]

        subgraph AI_STACK ["3.3 Hybrid Edge-AI Vision Stack"]
            direction TB
            TFLITE["TFLite MobileNetV2 SSD (24 Classes)\nInfer in 13–18 ms"]
            OCR["Google ML Kit SDK (OCR & Text Extraction)"]
            GEMMA["Google Gemma-IT 2B INT4 (Local Offline LLM)"]
            GEMINI["Google Gemini 3.6 Flash Low (Cloud Fallback)"]
        end

        subgraph FEEDBACK ["3.4 Multimodal Feedback Engine"]
            direction TB
            MGR["Priority Audio Manager (Hazard Overrides)"]
            TTS["Spatial Voice TTS (English & Tagalog Alerts)"]
            HAPTIC["Tactile Haptic Engine (Vibration Patterns)"]
        end
    end

    subgraph USER_LAYER ["5.0 User Interaction Layer"]
        direction TB
        U_ACT["Visually Impaired Pedestrian"]
        STT["Hands-Free Speech-to-Text Driver"]
        LOCAL_DB[("Local SQLite Database\n(Preferences, Contacts, Incident Logs)")]
    end

    subgraph CLOUD_LAYER ["4.0 Cloud & Storage Infrastructure Tier"]
        direction TB
        D1[("Cloudflare D1 Serverless SQL\n(Incident Telemetry)")]
        R2[("Cloudflare R2 Bucket\n(AWS SigV4 Signed Snapshots)")]
        FB["Firebase Suite (Auth & Firestore Sync)"]
    end

    %% Data Flows
    HW -->|"Raw Video Stream"| NET
    NET -->|"Byte Stream"| P31
    P31 -->|"Raw Frame Array"| P32
    P32 -->|"300x300 Matrix"| TFLITE
    P32 -->|"High-Res Crop"| OCR
    TFLITE -->|"Bounding Boxes & Hazard Scores"| MGR
    OCR -->|"Parsed Text String"| MGR
    GEMMA -->|"Offline Natural Dialogue"| MGR
    GEMINI -->|"Tagalog / Rich Dialogue"| MGR

    MGR -->|"Voice Queue"| TTS
    MGR -->|"Proximity Signal"| HAPTIC

    TTS -->|"Spatial Audio Alerts"| U_ACT
    HAPTIC -->|"Tactile Proximity Feedback"| U_ACT

    U_ACT -->|"Spoken Voice Commands"| STT
    STT -->|"Parsed Intent String"| GEMMA
    STT -->|"Complex Query Fallback"| GEMINI

    U_ACT <-->|"Read / Write Settings"| LOCAL_DB
    LOCAL_DB -.->|"Async REST Sync"| D1
    P31 -.->|"Direct Signed Media Upload"| R2
    U_ACT -.->|"Auth Tokens"| FB
```
