# Appendix D: Use Case Diagrams

---

## Figure D.1: High-Level Simplified Use Case Diagram

### APA 7th Citation & Metadata
- **Figure Number**: Figure D.1
- **Figure Title**: *High-Level Simplified Use Case Diagram*
- **Manuscript Page**: 179
- **PDF Page**: 187
- **Image Asset**: [fig_d_use_case_diagrams.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_d_use_case_diagrams.png)

```
Figure D.1
High-Level Simplified Use Case Diagram

Note. Figure D.1 illustrates the high-level system boundary and primary operational use cases accessible to the visually impaired user and designated emergency contacts within the EasyLens ecosystem.
```

---

### Technical Diagram (Mermaid)

```mermaid
flowchart LR
    subgraph SYSTEM ["EasyLens Assistive System Boundary"]
        UC1(["UC-1: Continuous Real-Time Object & Hazard Detection"])
        UC2(["UC-2: OCR Document & Street Sign Text Reader"])
        UC3(["UC-3: Conversational AI Assistance & Scene Description"])
        UC4(["UC-4: Turn-by-Turn GPS Navigation & Geocoding"])
        UC5(["UC-5: Trigger Emergency SOS & Location Broadcast"])
        UC6(["UC-6: Hands-Free Voice Command Control"])
    end

    USER(("Visually Impaired / Neurodivergent User"))
    CONTACT(("Emergency Contact"))

    USER --> UC1
    USER --> UC2
    USER --> UC3
    USER --> UC4
    USER --> UC5
    USER --> UC6

    UC5 -.->|SMS Alert & GPS Pin| CONTACT
```

---

## Figure D.2: Detailed Architectural Use Case Diagram

### APA 7th Citation & Metadata
- **Figure Number**: Figure D.2
- **Figure Title**: *Detailed Architectural Use Case Diagram*
- **Manuscript Page**: 179
- **PDF Page**: 187
- **Image Asset**: [fig_d_use_case_diagrams.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_d_use_case_diagrams.png)

```
Figure D.2
Detailed Architectural Use Case Diagram

Note. Figure D.2 maps the granular sub-functions, system inclusions (<<include>>), extensions (<<extend>>), and hardware/cloud boundary interactions across the EasyLens edge architecture.
```

---

### Technical Diagram (Mermaid)

```mermaid
flowchart TD
    USER(("Visually Impaired User"))
    GLASSES(("Smart Glasses Hardware\n(ESP32-CAM OV2640)"))
    CLOUD(("Cloud Tier\n(Cloudflare & Firebase)"))
    CONTACT(("Emergency Contact"))

    subgraph SYSTEM_DETAILED ["EasyLens Architectural Boundary"]
        direction TB

        subgraph SUB_PERCEPTION ["Subsystem 1: Edge Computer Vision"]
            UC_STREAM(["Capture MJPEG Video Stream @ 30 FPS"])
            UC_ISOLATE(["Worker Isolate: 300x300 Matrix Resize\n<<include>>"])
            UC_DETECT(["TFLite MobileNetV2 SSD Inference\n<<include>>"])
            UC_OCR(["ML Kit Text Recognition"])
            UC_ALERT(["Spatial Voice Alert & Haptic Pulse\n<<extend>>"])
        end

        subgraph SUB_CONVERSATIONAL ["Subsystem 2: Conversational AI"]
            UC_VOICE(["Hands-Free Speech-to-Text Input"])
            UC_GEMMA(["Local On-Device Gemma-IT 2B INT4 LLM\n<<include>>"])
            UC_GEMINI(["Cloud Gemini 3.6 Flash Fallback\n<<extend>>"])
            UC_RAG(["Local TF-IDF Knowledge Retrieval"])
        end

        subgraph SUB_NAV ["Subsystem 3: Spatial Navigation"]
            UC_GPS(["Retrieve Device Geolocation"])
            UC_CLOCK(["Calculate Clock-Face Bearings (e.g. 'At 2 o'clock')"])
        end

        subgraph SUB_SOS ["Subsystem 4: Emergency Safety Dispatch"]
            UC_SOS_INIT(["Initiate SOS Countdown (5-Second Beep)"])
            UC_SMS(["Dispatch Telephony SMS with GPS Link\n<<include>>"])
            UC_R2_UPLOAD(["Upload Scene Snapshot to Cloudflare R2\n<<include>>"])
            UC_D1_LOG(["Log Spatial Incident to Cloudflare D1\n<<include>>"])
        end
    end

    %% Hardware & User Triggers
    GLASSES --> UC_STREAM
    USER --> UC_STREAM
    USER --> UC_OCR
    USER --> UC_VOICE
    USER --> UC_GPS
    USER --> UC_SOS_INIT

    %% Subsystem Inclusions & Extensions
    UC_STREAM --> UC_ISOLATE
    UC_ISOLATE --> UC_DETECT
    UC_DETECT -.->|Hazard Detected| UC_ALERT

    UC_VOICE --> UC_RAG
    UC_RAG --> UC_GEMMA
    UC_GEMMA -.->|"Tagalog or Complex Scene"| UC_GEMINI

    UC_GPS --> UC_CLOCK

    UC_SOS_INIT --> UC_SMS
    UC_SOS_INIT --> UC_R2_UPLOAD
    UC_SOS_INIT --> UC_D1_LOG

    %% Cloud & External Actor Interactions
    UC_GEMINI -.-> CLOUD
    UC_R2_UPLOAD -.-> CLOUD
    UC_D1_LOG -.-> CLOUD
    UC_SMS --> CONTACT
```
