# Chapter 3: System Architecture & UML Sequence Diagram

---

## Figure 3.11: EasyLens System Architecture and Detailed UML Sequence Diagram

### APA 7th Citation & Metadata
- **Figure Number**: Figure 3.11
- **Figure Title**: *EasyLens System Architecture and Detailed UML Sequence Diagram*
- **Manuscript Page**: 102
- **PDF Page**: 109
- **Image Asset**: [fig_3_11_system_architecture_sequence.png](file:///Users/arronkianparejas/easylens/docs/figures/assets/fig_3_11_system_architecture_sequence.png)

```
Figure 3.11
EasyLens System Architecture and Detailed UML Sequence Diagram

Note. Figure 3.11 exhibits the overall EasyLens system architecture and unified modeling language (UML) sequence diagram, outlining the asynchronous data transmission, thread separation protocols via Dart Isolates, and dual Large Language Model reasoning paths.
```

---

### Technical Diagram (Mermaid Sequence Diagram)

```mermaid
sequenceDiagram
    autonumber
    actor User as Visually Impaired User
    participant Glasses as Smart Glasses (ESP32-CAM)
    participant App as EasyLens App (Flutter Core)
    participant Isolate as Dart Background Isolate
    participant EdgeAI as Edge-AI Engine (TFLite / ML Kit)
    participant LLM as Conversational AI (Gemma 2B / Gemini)
    participant AudioHaptic as Spatial Audio & Haptics
    participant Cloud as Cloud Tier (Cloudflare / Firebase)

    %% System Initialization
    rect rgb(240, 245, 255)
        note over User, Glasses: System Startup & Handshake
        Glasses->>Glasses: Broadcast Standalone Wi-Fi AP ("EasyLens-Camera")
        User->>App: Launch EasyLens Application
        App->>Glasses: Establish Persistent HTTP Connection (192.168.4.1:81/stream)
        Glasses-->>App: Acknowledge Connection & Begin MJPEG Byte Stream
    end

    %% Real-Time Continuous Perception Loop
    rect rgb(245, 255, 245)
        note over App, AudioHaptic: Continuous Edge Perception Loop (15–30 FPS)
        loop Every Video Frame
            Glasses->>App: Deliver MJPEG Frame Bytes
            App->>Isolate: Transfer Raw Frame Buffer (Zero Main-Thread Jitter)
            Isolate->>Isolate: Resize to 300x300 Matrix & Normalize
            Isolate->>EdgeAI: Pass Normalized Tensor to TFLite
            EdgeAI->>EdgeAI: Execute MobileNetV2 SSD Inference (24 Classes)
            EdgeAI-->>Isolate: Return Bounding Boxes & Confidence Scores
            
            alt Hazard Detected (Confidence > 0.65)
                Isolate->>App: Post Hazard Event (e.g., "Vehicle Approaching - Left")
                App->>AudioHaptic: Trigger Priority Audio Override & Haptic Pattern
                AudioHaptic->>User: Emit Spatial Directional Voice Alert + Haptic Vibration
                App-.->Cloud: Asynchronously Log Incident Telemetry (Cloudflare D1)
            else Path Clear
                Isolate-->>App: Return Path Clear State
            end
        end
    end

    %% Multimodal Conversational AI Flow
    rect rgb(255, 250, 240)
        note over User, LLM: Multimodal Natural Voice Query Flow
        User->>App: Spoken Voice Query (e.g., "What is in front of me?")
        App->>App: Speech-to-Text Conversion
        
        alt Query in English (Offline Mode)
            App->>LLM: Pass Query + Knowledge Base to On-Device Gemma-IT 2B (INT4)
            LLM-->>App: Return Structured Local Response String
        else Query in Filipino / Complex Scene (Online Fallback)
            App->>Cloud: Forward Request to Cloud Gemini 3.6 Flash Low
            Cloud-->>App: Return Natural Filipino Context String
        end

        App->>AudioHaptic: Synthesize Voice Output
        AudioHaptic->>User: Spoken Natural Response
    end

    %% Emergency SOS Dispatch Flow
    rect rgb(255, 240, 240)
        note over User, Cloud: Emergency SOS Trigger Flow
        User->>App: Long-Press SOS / Trigger Word / Critical Impact Fall
        App->>AudioHaptic: Emit Audible 5-Second Countdown Beeps
        AudioHaptic->>User: "Emergency SOS alerting in 5 seconds. Tap to cancel."
        
        opt Not Cancelled
            App->>Cloud: Post Emergency SMS Payload via Telephony Gateway
            App->>Cloud: Upload Incident Snapshot Image to Cloudflare R2
            Cloud-->>User: Broadcast GPS Coordinates to Registered Contacts
        end
    end
```

---

### Architectural Characteristics

1. **Dart Isolate Concurrency**: Offloads raw frame resizing, tensor formatting, and TFLite execution to background threads, guaranteeing that the Flutter UI thread renders at a consistent 60 FPS without frame stutter.
2. **Dual-Tier Large Language Model Orchestration**: Ensures complete offline functionality via the local Gemma-IT 2B INT4 quantized LLM while providing high-quality contextual reasoning via Gemini 3.6 Flash Low when network access is available.
3. **Priority Audio Management**: Audio alerts operate on a strict priority queue where immediate collision and hazard warnings instantly preempt background voice dialogue or navigation prompts.
