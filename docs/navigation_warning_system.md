# EasyLens Navigation & Hazard Warning System

This document outlines the real-time hazard mapping, classification logic, and alert feedback mechanisms implemented in the EasyLens edge computer vision and audio navigation systems.

---

## 1. Warning & Hazard Categories

EasyLens classifies environmental features detected in the camera view into three hazard priority levels:

### 🔴 Priority 1: Critical Hazards (Immediate Action Required)
- **Haptic Alert**: Double high-intensity vibration sequence (vibrate, pause 150ms, vibrate).
- **Audio Feedback**: Priority Text-to-Speech (TTS) command interrupting previous speech.
- **UI Styling**: Crimson Red background card (`Color(0xFFFFEBEE)`) with error icon.
- **Triggers**:
  - **STOP!**: Bounding box proximity threshold exceeded; direct collision path detected.
  - **Fire Hazard!**: Inference detection of fire, open flames, or heavy smoke.

### 🟡 Priority 2: Moderate Hazards (Precautionary Actions)
- **Haptic Alert**: Single medium-impact haptic feedback impulse.
- **Audio Feedback**: Spoken guidance advising user on steering/speed adjustments.
- **UI Styling**: Amber/Orange background cards (`Color(0xFFFFF8E1)` or `Color(0xFFFFFDE7)`).
- **Triggers**:
  - **Vehicle Detected**: Approaching jeepneys, tricycles, cars, or motorcycles.
  - **Damaged Pathway**: sidewalk cracks, potholes, or open grates.
  - **Stairs Detected**: Approaching step-downs or step-ups.
  - **Obstacle Ahead**: Generic pathway blockages (e.g. posts, poles, construction barriers).
  - **Multiple Hazards**: Extremely complex environment with multiple active threat items.
  - **Moving Too Fast**: Device motion exceeds accelerometer tracking limits for accurate visual scan.

### 🔵 Priority 3: Informational & Assistive Events
- **Haptic Alert**: None.
- **Audio Feedback**: Conversational announcements.
- **UI Styling**: Indigo/Blue background cards (`Color(0xFFE8EAF6)`).
- **Triggers**:
  - **Traffic Sign Located**: Crosswalk markers, Stop signs, or street warnings.
  - **Person Detected**: Nearby pedestrians (encouraging spatial awareness).
  - **GO Signal Detected**: Pedestrian green lights detected at traffic signals.
  - **Low Light Detected**: Ambient illumination falls below threshold, warning that camera scanning confidence is reduced.
  - **Path Clear**: Reverting to normal walking state (Green card).

---

## 2. Threat Calculation Logic

Threat scoring is computed dynamically for every detected object based on three primary factors:

$$\text{Threat Score} = (\text{Base Risk} \times 0.4) + (\text{Proximity Score} \times 0.4) + (\text{Velocity Score} \times 0.2)$$

1. **Base Risk (40%)**: Pre-assigned hazard level weight per class label (e.g., vehicles and stairs have higher base risk than tables or cups).
2. **Proximity Score (40%)**: Normalized bounding box area relative to image width/height (larger area indicates closer proximity).
3. **Velocity Score (20%)**: Change in bounding box area over time, highlighting objects that are moving rapidly towards the user.

---

## 3. Settings Control & Haptic Toggles

All haptic alerts are linked directly to user preferences saved in [SettingsService](file:///Users/arronkianparejas/easylens/lib/services/settings_service.dart):
- **Haptic Feedback Toggle**: Turning off **Haptic Feedback** in the settings screen completely suppresses all Priority 1 and Priority 2 vibrations during navigation.
- **Companion Mode Sharing**: Enabling companion mode routes hazard logs to the caregiver portal in real time.
