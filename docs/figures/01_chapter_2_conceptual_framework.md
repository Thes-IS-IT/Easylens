# Chapter 2: Theoretical & Conceptual Framework Figures

---

## Figure 2.1: Input-Process-Output (IPO) Conceptual Framework of the EasyLens System

### APA 7th Citation & Metadata
- **Figure Number**: Figure 2.1
- **Figure Title**: *Input-Process-Output (IPO) Conceptual Framework of the EasyLens System*
- **Manuscript Page**: 32
- **PDF Page**: 39
- **Image Asset**: [fig_2_1_ipo_conceptual_framework.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_2_1_ipo_conceptual_framework.png)

```
Figure 2.1
Input-Process-Output (IPO) Conceptual Framework of the EasyLens System

Note. Figure 2.1 provides a visual representation of the Input-Process-Output (IPO) conceptual framework underpinning the EasyLens system, illustrating the end-to-end transformation of multi-sensory environmental inputs into real-time assistive guidance.
```

---

### Technical Diagram (Mermaid)

```mermaid
flowchart TD
    subgraph INPUT ["INPUT LAYER"]
        direction TB
        I1["Visually Impaired & Neurodivergent User Intent\n• Hands-Free Voice Commands (Speech-to-Text)\n• Touch Gestures & Accelerometer Shake"]
        I2["Real-Time Optical Video Stream\n• OmniVision OV2640 70° Light Wide Angle Lens\n• 30 FPS MJPEG Stream via Wi-Fi AP (192.168.4.1:81)"]
        I3["Spatial & Telemetry Sensor Data\n• GPS Real-Time Geolocation Coordinates\n• Device Accelerometer & Compass Heading\n• Wi-Fi RSSI & Battery Telemetry"]
        I4["Knowledge & Preference Base\n• On-Device 'buddy_knowledge.json' Index\n• SQLite Local User Settings & Custom Themes\n• Emergency Contacts & SOS Registry"]
    end

    subgraph PROCESS ["PROCESS LAYER: EDGE & CLOUD PROCESSING"]
        direction TB
        
        subgraph P_HW ["1. Wearable Edge Sensing & Ingestion"]
            HW1["ESP32-CAM Dual-Core SoC (240 MHz, 4MB PSRAM)"]
            HW2["5V 1,500 mAh External Keychain Power Bank"]
            HW3["Passive Aluminum Heatsink Dissipation"]
        end

        subgraph P_CV ["2. Edge-AI Vision & Perception Engine"]
            CV1["Dart Parallel Background Isolate (Zero UI Thread Jitter)"]
            CV2["300x300 Matrix Normalization Pipeline"]
            CV3["MobileNetV2 SSD (24-Class Quantized INT8 Edge Detector)"]
            CV4["Google ML Kit SDK (On-Device OCR & Text Extraction)"]
        end

        subgraph P_LLM ["3. Dual-Tier Conversational AI & RAG Engine"]
            LLM1["Primary On-Device: Google Gemma-IT 2B INT4 (Offline English)"]
            LLM2["Secondary Cloud Fallback: Google Gemini 3.6 Flash Low (Tagalog/Filipino)"]
            LLM3["Local TF-IDF Vector Search Index & Grounding"]
        end

        subgraph P_AUDIO ["4. Multimodal Feedback & Priority Engine"]
            AU1["Priority Audio Manager (Instant Hazard Interruption)"]
            AU2["Bilingual Text-to-Speech Engine (English & Tagalog)"]
            AU3["Tactile Haptic Impulse Controller (Pattern Generator)"]
        end

        subgraph P_CLOUD ["5. Cloud Synchronization & Storage Infrastructure"]
            CL1["Cloudflare D1 Serverless SQL (Telemetry & Hazard Logs)"]
            CL2["Cloudflare R2 Bucket (AWS SigV4 Signed Snapshot Uploads)"]
            CL3["Firebase Auth & Firestore Synchronization"]
            CL4["GitHub Releases REST API (OTA Software Updates)"]
        end
    end

    subgraph OUTPUT ["OUTPUT LAYER"]
        direction TB
        O1["Real-Time Spoken Spatial Audio<br>• Directional Hazard Warnings (e.g. Stop! Stairs Ahead)<br>• Real-Time OCR Text Readout<br>• Turn-by-Turn Clock-Face GPS Navigation (e.g. Target at 2 o'clock)"]
        O2["Tactile Haptic Feedback\n• Single Pulse: Low/Medium Hazard Notification\n• Double High-Intensity Pulse: Critical Immediate Danger"]
        O3["Emergency Telemetry & SOS Dispatch\n• Automated SMS Location Broadcast with Google Maps Link\n• 5-Second Cancellation Countdown Safety Window"]
        O4["High-Contrast Visual UI\n• WCAG 2.2 Level AAA Compliant Themes (Up to 21:1 Contrast)\n• Dynamic Sizing Hierarchy (Extra Large High-Legibility)"]
    end

    INPUT --> PROCESS
    P_HW --> P_CV
    P_CV --> P_LLM
    P_LLM --> P_AUDIO
    P_CV --> P_AUDIO
    P_CV -.-> P_CLOUD
    PROCESS --> OUTPUT
```

---

### Architectural Narrative & Manuscript Context

The Input-Process-Output (IPO) model is the core structural paradigm of the EasyLens system. As documented on Manuscript Page 32:

1. **Input**: Environmental data is captured via the right-temple-mounted ESP32-CAM OV2640 sensor module and on-device smartphone sensors (GPS, accelerometer, microphone).
2. **Process**: Processing is divided into a strictly offline, edge-first computational pipeline on the smartphone device. Dart Isolates prevent garbage collection frame drops on the main Flutter UI thread. The 24-class fine-tuned MobileNetV2 SSD network performs object inference within 13–18 ms, while Google ML Kit handles on-device OCR. Conversational reasoning is executed locally via INT4 quantized Gemma-IT 2B, falling back to Google Gemini 3.6 Flash Low when internet connectivity is active for complex Tagalog language queries.
3. **Output**: Multi-sensory feedback channels provide users with low-latency spoken spatial audio cues, distinct tactile vibration pulses, and automated emergency SOS alerts, ensuring total navigational independence without visual dependency.
