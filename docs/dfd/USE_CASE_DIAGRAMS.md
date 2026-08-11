# EasyLens - Use Case Diagrams (UCD) Specification

---

## 1. Overview & System Scope

This document provides both **Simplified High-Level** and **Detailed Architectural Use Case Diagrams** for **EasyLens**. It models interactions between the primary actor (**Visually Impaired / Neurodivergent User**), secondary actors (**Emergency Contacts**, **Caregivers / System Administrators**), and system boundaries spanning **Wearable Physical Hardware**, **Edge Application Core**, and **Cloud Infrastructure Tier**.

---

## 2. Simplified Use Case Diagram

The high-level Use Case Diagram illustrates core interactions between the primary user and the primary system capabilities:

```mermaid
flowchart LR
    USER(("Visually Impaired / Neurodivergent User"))

    subgraph SYSTEM ["EasyLens Assistive System"]
        UC1(["UC-1: Continuous Real-Time Object & Hazard Detection"])
        UC2(["UC-2: OCR Document & Street Sign Text Reader"])
        UC3(["UC-3: Conversational AI Assistance & Scene Description"])
        UC4(["UC-4: Turn-by-Turn GPS Navigation & Geocoding"])
        UC5(["UC-5: Trigger Emergency SOS & Location Broadcast"])
        UC6(["UC-6: Hands-Free Voice Command Control"])
    end

    CONTACT(("Emergency Contact"))

    USER --> UC1
    USER --> UC2
    USER --> UC3
    USER --> UC4
    USER --> UC5
    USER --> UC6

    UC5 -.->|"SMS Alert & Real-time Location"| CONTACT
```

---

## 3. Detailed Architectural Use Case Diagram

The detailed Use Case Diagram captures system inclusions (`<<include>>`), extensions (`<<extend>>`), hardware sensor triggers, and cloud backend interfaces.

```mermaid
flowchart TB
    subgraph ACTORS ["System Actors"]
        PRIMARY(("Primary Actor:\nVisually Impaired User"))
        CARE(("Secondary Actor:\nCaregiver / Contact"))
        HW_ACTOR[["Hardware Unit:\nESP32-CAM / 1500mAh Bank"]]
    end

    subgraph BOUNDARY ["EasyLens Core System Boundary"]
        direction TB

        subgraph VISION_MODULE ["Real-Time Vision & Perception"]
            UC_STREAM(["UC-10: Stream Wearable Video (OV2640 70°)"])
            UC_DETECT(["UC-11: Detect Navigational Hazards (MobileNetV2 SSD)"])
            UC_OCR(["UC-12: Read Document & Sign Text (ML Kit OCR)"])
            UC_LABEL(["UC-13: Two-Stage Image Labeling"])
        end

        subgraph AI_MODULE ["On-Device & Cloud Intelligence"]
            UC_LOCAL_LLM(["UC-20: Offline Scene Description (Gemma 2B)"])
            UC_CLOUD_LLM(["UC-21: Cloud Reasoning Query (Gemini 3.6 Flash)"])
            UC_VOICE_CMD(["UC-22: Parse Hands-Free Voice Commands (Speech-to-Text)"])
        end

        subgraph AUDIO_MODULE ["Multimodal Feedback Subsystem"]
            UC_TTS(["UC-30: Speak Spatial Voice Warning (English / Tagalog)"])
            UC_HAPTIC(["UC-31: Trigger Proximity Vibration Pulse"])
        end

        subgraph NAV_MODULE ["Navigation & Location Services"]
            UC_MAP(["UC-40: Turn-by-Turn Walking Navigation (Google Maps & OSRM)"])
            UC_GEO(["UC-41: Reverse Geocoding Address Search (Photon API)"])
        end

        subgraph SAFETY_MODULE ["Emergency & Telemetry System"]
            UC_SOS(["UC-50: Trigger Emergency SOS Panic Button"])
            UC_SYNC_D1(["UC-51: Sync Telemetry & Contacts (Cloudflare D1)"])
            UC_STORE_R2(["UC-52: Upload Diagnostic Snapshot (Cloudflare R2)"])
            UC_AUTH(["UC-53: Authenticate User Session (Firebase Auth)"])
        end
    end

    HW_ACTOR -->|"Wi-Fi AP Video Stream"| UC_STREAM
    PRIMARY -->|"Hands-Free Voice Inputs"| UC_VOICE_CMD
    PRIMARY -->|"Touch Interface / HW Trigger"| UC_SOS
    PRIMARY -->|"Request Route / Location"| UC_MAP

    UC_STREAM -->|"Input Frames"| UC_DETECT
    UC_STREAM -->|"High-Res Crop"| UC_OCR
    UC_DETECT -.->|"include"| UC_LABEL

    UC_DETECT -->|"Hazard Trigger"| UC_TTS
    UC_DETECT -->|"Proximity Alert"| UC_HAPTIC
    UC_OCR -->|"Parsed Text"| UC_LOCAL_LLM
    UC_LOCAL_LLM -.->|"extend (online fallback)"| UC_CLOUD_LLM
    UC_LOCAL_LLM -->|"Synthesized Speech"| UC_TTS

    UC_MAP -.->|"include"| UC_GEO

    UC_SOS -->|"Send Incident SMS & Location"| CARE
    UC_SOS -.->|"include"| UC_SYNC_D1
    UC_SOS -.->|"include"| UC_STORE_R2
    UC_SYNC_D1 -.->|"requires"| UC_AUTH
```

---

## 4. Use Case Specifications & Actor Descriptions

### 4.1 Actor Catalog

| Actor | Category | Description |
| :--- | :--- | :--- |
| **Visually Impaired / Neurodivergent User** | Primary | Interacts with EasyLens hands-free via spatial audio feedback, voice commands, screen-reader touch gestures, and physical hardware buttons. |
| **Wearable Hardware Unit** | System / Sensor | Captures continuous video frames via **OV2640 70° light wide angle lens**, powered by **ESP32-CAM-MB** and **1500 mAh powerbank**. |
| **Emergency Contact / Caregiver** | Secondary | Receives real-time SMS notifications, current GPS coordinates, and incident logs when an Emergency SOS is triggered. |
| **Cloud Services (Cloudflare D1/R2 & Firebase)** | Infrastructure | Manages serverless database records, secure AWS SigV4 media uploads, and user authentication sessions. |

---

### 4.2 Core Use Case Descriptions

| Use Case ID | Use Case Name | Primary Trigger | Key Operational Flow |
| :--- | :--- | :--- | :--- |
| **UC-10 / UC-11** | Real-Time Obstacle Detection | Camera power on & continuous Wi-Fi stream active. | Frame bytes ingestion $\rightarrow$ Dart isolate normalization $\rightarrow$ TFLite MobileNetV2 SSD inference $\rightarrow$ Priority spatial TTS & tactile vibration pulse output. |
| **UC-12 / UC-20** | OCR & Offline Scene Understanding | Spoken prompt or screen button tap. | ML Kit OCR extracts text string $\rightarrow$ Google Gemma 2B synthesizes natural speech $\rightarrow$ Spatial TTS speaks English/Tagalog output offline. |
| **UC-40** | Turn-by-Turn Walking Navigation | User voice command or location search. | Geocodes destination via Photon API $\rightarrow$ Calculates walking route via OSRM/Google Maps API $\rightarrow$ Emits spatial voice guidance cues. |
| **UC-50** | Emergency SOS & Telemetry Sync | Double-tap SOS button or voice command "*Emergency*". | Captures current GPS coordinates $\rightarrow$ Sends direct SMS alert to registered contact $\rightarrow$ Logs incident to Cloudflare D1 & uploads snapshot to R2. |
