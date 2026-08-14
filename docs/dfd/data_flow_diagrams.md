# EasyLens - Current vs. Proposed Data Flow Diagrams (DFD)

---

## 1. Overview & System Evolution

This document presents the **Current Data Flow Diagram** (Baseline Assistance Model without integrated edge-AI hardware) versus the **Proposed Data Flow Diagram** (The complete **EasyLens** Wearable Edge-AI System). 

Both **Simplified High-Level** and **Detailed Architectural Level-1/Level-2 Data Flow Diagrams** are provided below using standard GitHub-compatible Mermaid syntax.

---

## 2. Simplified Data Flow Diagrams

### 2.1 Current Data Flow Diagram (Baseline / Existing System)
In traditional assistive apps, visual input relies entirely on manual phone camera framing, single-frame cloud API calls, and standard voice output without edge processing or real-time spatial awareness.

```mermaid
flowchart LR
    USER(("Visually Impaired User"))
    PHONE["Manual Smartphone Camera Interface"]
    CLOUD["Remote Cloud AI API (High Latency)"]
    AUDIO["Basic Phone Audio Output"]

    USER -->|"Manual Point & Snap"| PHONE
    PHONE -->|"Raw Image via Cellular/Internet"| CLOUD
    CLOUD -->|"Parsed Text / Basic Label"| PHONE
    PHONE -->|"Generic Voice Alert"| AUDIO
    AUDIO -->|"Auditory Feedback"| USER
```

---

### 2.2 Proposed Data Flow Diagram (EasyLens System)
The proposed EasyLens system introduces continuous wearable camera streaming via an **ESP32-CAM-MB (OV2640 70° Light Wide Angle)** inside a **3D-printed module box frame** powered by a **1500 mAh powerbank**, processing real-time video frames on-device using **TensorFlow Lite (MobileNetV2 SSD)**, **Google Gemma 2B**, and **Google ML Kit**, with spatial TTS, haptics, and serverless Cloudflare D1/R2 sync.

```mermaid
flowchart LR
    HARDWARE[["EasyLens Wearable Hardware\n(ESP32-CAM / 1500mAh Bank)"]]
    APP["EasyLens Mobile Core Engine\n(Dart Isolates & Edge AI)"]
    USER(("Visually Impaired User"))
    CLOUD[("Cloud Infrastructure\n(Cloudflare D1/R2 & Firebase)")]

    HARDWARE -->|"Continuous Wi-Fi AP Frame Stream (30 FPS)"| APP
    APP -->|"Spatial Voice Alerts & Tactile Haptics"| USER
    USER -->|"Hands-Free Voice Commands"| APP
    APP -.->|"Encrypted Telemetry & Media Sync"| CLOUD
```

---

## 3. Detailed Data Flow Diagrams

### 3.1 Current System Detailed Data Flow Diagram (Level-1 DFD)

```mermaid
flowchart TB
    subgraph External_Entities ["External Entities"]
        USER(("User / Patient"))
        CLOUD_API["Remote Vision Cloud API"]
    end

    subgraph Current_Process ["Traditional Assistive App Pipeline"]
        P1["1.0 Manual Image Capture Process"]
        P2["2.0 Cloud Payload Serializer"]
        P3["3.0 Remote Cloud Processing"]
        P4["4.0 Monolithic Voice Generator"]

        D1[("Local Cache / Saved Images")]
    end

    USER -->|"Manual Capture Button Tap"| P1
    P1 -->|"Raw JPEG Buffer"| P2
    P2 -->|"HTTP REST Post Request"| CLOUD_API
    CLOUD_API -->|"JSON Response Payload"| P3
    P3 -->|"Parsed Category String"| P4
    P4 -->|"Standard TTS Voice Stream"| USER

    P1 -.->|"Save Snapshots"| D1
```

---

### 3.2 Proposed System Detailed Data Flow Diagram (Level-1 & Level-2 DFD)

```mermaid
flowchart TB
    subgraph HARDWARE_LAYER ["1.0 Wearable Physical Ingestion Tier"]
        BATT["1500 mAh Powerbank (Regulated 5V)"]
        ESP["ESP32-CAM-MB Baseboard (CH340G)"]
        CAM["OV2640 70° Light Wide Angle Lens"]
        HS["Heatsink Pad Thermal Dissipation"]

        BATT -->|"5V Rail"| ESP
        CAM -->|"DVP Bus Raw Pixels"| ESP
        HS -.->|"Passive Heat Sinking"| ESP
    end

    subgraph TRANSPORT_LAYER ["2.0 Wireless Transport Protocol"]
        WIFI["Wi-Fi AP Video Stream\n(HTTP MJPEG @ 192.168.4.1:81)"]
        ESP -->|"2.4GHz Wi-Fi AP Packets"| WIFI
    end

    subgraph MOBILE_EDGE_ENGINE ["3.0 EasyLens Mobile Processing Engine (Flutter Core)"]
        direction TB
        RECV["3.1 MJPEG Frame Ingestion & Buffer"]
        ISO["3.2 Dart Parallel Isolate Worker\n(Resize to 300x300 & Normalize)"]

        subgraph AI_PIPELINE ["3.3 Hybrid Edge AI Vision Stack"]
            TFLITE["TFLite Model\n(MobileNetV2 SSD - 24 Classes)"]
            MLKIT["Google ML Kit SDK\n(OCR & Text Extraction)"]
            GEMMA["Google Gemma 2B Local LLM\n(On-Device Scene Understanding)"]
            CLOUD_GEMINI["Google Gemini 3.6 Flash\n(Cloud Reasoning Fallback)"]
        end

        subgraph MULTIMODAL_OUTPUT ["3.4 Multimodal Feedback Engine"]
            PRIORITY["Priority Audio Manager\n(Hazard Overrides)"]
            TTS["Spatial Voice TTS\n(English & Tagalog Alerts)"]
            HAPTIC["Tactile Haptic Engine\n(Vibration Pulses)"]
        end

        RECV -->|"Byte Stream"| ISO
        ISO -->|"300x300 Matrix"| TFLITE
        ISO -->|"High-Res Crop"| MLKIT
        MLKIT -->|"Parsed Text String"| GEMMA
        GEMMA -.->|"Online Context Query"| CLOUD_GEMINI

        TFLITE -->|"Detected Object & Bounding Box"| PRIORITY
        GEMMA -->|"Natural Scene Description"| PRIORITY
        PRIORITY -->|"Voice Queue"| TTS
        PRIORITY -->|"Proximity Signal"| HAPTIC
    end

    subgraph DATA_PERSISTENCE ["4.0 Cloud & Storage Infrastructure Tier"]
        LOCAL_DB[("Local SQLite Database\n(User Settings & Offline Logs)")]
        D1[("Cloudflare D1 Serverless SQL\n(Telemetry & Contacts)")]
        R2[("Cloudflare R2 Storage\n(AWS SigV4 Signed Images)")]
        FIREBASE[("Firebase Suite\n(Auth & Firestore Sync)")]
    end

    subgraph USER_LAYER ["5.0 User Interaction Layer"]
        USER_ACTOR(("Visually Impaired User"))
        STT["Hands-Free Speech-to-Text Driver"]
    end

    WIFI --> RECV
    TTS -->|"Spatial Audio Alerts"| USER_ACTOR
    HAPTIC -->|"Tactile Proximity Feedback"| USER_ACTOR
    USER_ACTOR -->|"Spoken Voice Commands"| STT
    STT -->|"Parsed Intent String"| RECV

    MOBILE_EDGE_ENGINE <-->|"Offline Cache Read/Write"| LOCAL_DB
    MOBILE_EDGE_ENGINE <-->|"TLS REST Sync"| D1
    MOBILE_EDGE_ENGINE -->|"Direct Signed Media Upload"| R2
    MOBILE_EDGE_ENGINE <-->|"Auth Tokens"| FIREBASE
```

---

## 4. Key Improvements Summary (Current vs. Proposed)

| Architectural Parameter | Current Baseline System | Proposed EasyLens System |
| :--- | :--- | :--- |
| **Video Stream Ingestion** | Manual single-shot snapshot via smartphone camera. | Continuous 30 FPS hands-free video stream from wearable **OV2640 70° wide angle lens**. |
| **Hardware Form Factor** | Handheld mobile device (occupies user's hand). | Lightweight **3D-printed module box frame** powered by a **1500 mAh powerbank**. |
| **Inference Latency** | High cloud latency ($1.5\text{s} - 3.0\text{s}$ per query). | Real-time edge inference (**28 ms** TFLite MobileNetV2 SSD / ~88 ms end-to-end). |
| **Offline Functionality** | Fails completely without cellular/Wi-Fi connection. | **100% offline edge processing** (TFLite, ML Kit OCR, and Google Gemma 2B LLM). |
| **Multimodal Feedback** | Monolithic text-to-speech output. | Priority spatial voice alerts (English/Tagalog) + tactile vibration pulse patterns. |
| **Cloud Telemetry & Sync** | Proprietary closed API. | Serverless **Cloudflare D1** (SQL), **Cloudflare R2** (AWS SigV4), and **Firebase Auth**. |
