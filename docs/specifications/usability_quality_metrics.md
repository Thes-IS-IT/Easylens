# EasyLens - Usability Quality Metrics & Evaluation Targets

---

### 01 — EXECUTIVE SUMMARY

This document defines the usability quality metrics, core evaluation parameters, and empirical testing targets for EasyLens. Grounded in standardized software quality frameworks (ISO/IEC 25010, ISO/IEC 5055, WCAG 2.2 AAA), this evaluation model validates screen-reader navigation, real-time wireless video streaming latency, audio alert clarity (English & Filipino), and overall user confidence when navigating physical environments.

---

### 02 — USABILITY QUALITY METRICS MATRIX

| Usability Quality Metric | Core Evaluation Parameter | Specific EasyLens Testing Target | Standard / Baseline |
| :--- | :--- | :--- | :--- |
| **Learnability** | Ease of interface memorization and onboarding | Tapping the high-contrast accessible touch buttons on the EasyLens screen main dashboard (Object Detection, OCR Reader, AI Assistant, Emergency SOS) or pressing the dedicated hardware trigger button and locating primary navigation tools without visual assistance. | ISO/IEC 25010 (Learnability Sub-characteristic) |
| **Operability** | Comfort and physical wearability of hardware | Comfort, secure fit, thermal performance, and weight distribution of the custom 3D-printed module box frame housing the ESP32-CAM-MB, OV2640 70° light wide angle lens, heatsink pad, and 1500 mAh powerbank. | WEAR Scale (Wearable Quality Evaluation) |
| **User Error Protection** | Code fault tolerance and exception recovery | System recovery and immediate spatial voice/audio feedback triggered during wireless Wi-Fi AP frame drops, camera disconnects, or low-battery thresholds. | ISO/IEC 5055 (Software Reliability & Fault Tolerance) |
| **Accessibility** | Multilingual spatial audio clarity & visual adaptation | Audibility, speech rate customization, and pitch clarity of English and Filipino spatial Text-to-Speech (TTS) alerts under noisy ambient outdoor environments, combined with high-contrast screen scaling. | WCAG 2.2 (Level AAA Guidelines) |
| **Appropriateness Recognizability** | User confidence & supplementary safety utility | Subjective user confidence in detecting dynamic obstacles (vehicles, pedestrians, curbs, low-hanging hazards) while reinforcing that EasyLens functions as a secondary assistive tool (not a total replacement for traditional white canes). | ISO/IEC 25010 (Appropriateness Recognizability) |

---

### 03 — METRIC-BY-METRIC TESTING CRITERIA

#### 3.1 Learnability Evaluation
* **Target Users**: Visually impaired (blind/low vision) and neurodivergent test participants.
* **Test Method**: Task Completion Time (TCT) on initial launch without tutorial prompts.
* **Success Criteria**:
  * $\ge 90\%$ of participants successfully navigate from the EasyLens screen dashboard or activate controls via physical hardware buttons to active vision mode within **15 seconds** using accessibility gestures, screen-reader audio cues, or direct touch inputs.

#### 3.2 Operability & Thermal Wearability
* **Hardware Profile**: Wearable unit consisting of the **3D-Printed Module Box Frame**, **ESP32-CAM-MB with CH340G**, **OV2640 70° Light Wide Angle Lens**, **Heatsink Pad**, and **1500 mAh Powerbank**.
* **Test Method**: Continuous 60-minute wearability assessment.
* **Success Criteria**:
  * Enclosure weight remains under **25 grams** (excluding powerbank cable).
  * External surface temperature does not exceed **40°C** due to effective heat dissipation via the heatsink pad.

#### 3.3 User Error Protection & Reliability
* **Test Method**: Simulated Wi-Fi packet loss, frame dropping, and battery voltage degradation tests.
* **Success Criteria**:
  * Voice notification ("*Camera disconnected, attempting reconnection*") plays within **$500\text{ ms}$** of connection interruption.
  * Application auto-reconnects to `192.168.4.1` AP stream without crashing or freezing the UI main thread.

#### 3.4 Accessibility (WCAG 2.2 AAA & Spatial Audio)
* **Test Method**: Speech intelligibility scoring in ambient background noise ($65\text{ dBA} - 75\text{ dBA}$).
* **Success Criteria**:
  * $100\%$ text-to-speech comprehension for obstacle warnings in both **English** and **Filipino/Tagalog**.
  * High-contrast UI elements achieve a minimum color contrast ratio of **7:1**.

#### 3.5 Appropriateness Recognizability & User Safety
* **Test Method**: Guided indoor and outdoor obstacle course evaluation.
* **Success Criteria**:
  * Users report a statistically significant increase in environmental awareness score ($\ge 4.5/5.0$ Likert rating).
  * Clear user understanding that EasyLens is an auxiliary spatial vision assistant supplementing primary mobility aids (white cane / guide dog).
