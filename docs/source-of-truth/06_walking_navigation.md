# 06 — Walking Navigation System

## Overview

The walking navigation system provides real-time obstacle warnings, non-critical architectural cues, and turn-by-turn guidance for visually impaired users. It uses Google ML Kit's object detector to track objects in the camera feed and maps their positions to **4 distinct guidance states** alongside GPS-based directional waypoint cues.

---

## Routing, Location Tracking & Navigation Algorithms

EasyLens integrates global map routing with localized safety metrics to construct a safe walking corridor:

### 1. Pedestrian Shortest Path Routing: Dijkstra's / A* Search Algorithm
* **Algorithm**: **Dijkstra's Algorithm / A\* Search** (used internally by Google Maps Directions API).
* **Details**: Computes the optimal walking paths along pedestrian networks, sidewalks, and crosswalk segments, returning a collection of coordinate waypoints and localized routing instructions.

### 2. Distance Calculations: The Haversine Formula
* **Algorithm**: **Haversine Formula**.
* **Details**: To calculate the exact real-time great-circle distance (arc distance over the Earth's spherical surface) between the user's current GPS location $(lat_1, lon_1)$ and the next navigation waypoint step $(lat_2, lon_2)$, the system solves the Haversine equation on-device:
  $$d = 2R \cdot \arcsin\left(\sqrt{\sin^2\left(\frac{lat_2 - lat_1}{2}\right) + \cos(lat_1) \cdot \cos(lat_2) \cdot \sin^2\left(\frac{lon_2 - lon_1}{2}\right)}\right)$$
  Where $R$ is the mean radius of the Earth (6,371,000 meters). This ensures accurate coordinate distance mapping.

### 3. Dynamic 30-Meter Turn Warning System
* **Trigger Mechanism**:
  - The `ActiveNavigationService` continuously polls the device GPS provider and computes the Haversine distance to the next path node.
  - When the user approaches a transition coordinate and the distance drops to **$\le 30$ meters**, the system preemptively announces the turn action via Text-to-Speech (e.g., *"In 30 meters, turn right on acacia street"*).
  - The warning is repeated at smaller intervals as they approach, concluding with an immediate notification at the corner.

---

## State Machine

```mermaid
stateDiagram-v2
    [*] --> PathClear
    PathClear --> Stop: Centered + area > 0.20
    PathClear --> Avoid: Centered + 0.05 < area ≤ 0.20
    PathClear --> SlowDown: Side + area > 0.08
    PathClear --> DoorWindowCue: Door or Window detected (Non-critical)

    Stop --> PathClear: Object cleared
    Avoid --> PathClear: Object cleared
    Avoid --> Stop: Object grows closer
    SlowDown --> PathClear: Object cleared
    SlowDown --> Avoid: Object moves to center
    SlowDown --> Stop: Object moves to center + very close
    DoorWindowCue --> PathClear: Feature passed
```

---

## 4 Guidance States & Non-Critical Cues

### 1. 🔴 Stop Immediately (`area > 0.20` + centered)
| Property | English | Tagalog |
|---|---|---|
| Title | Stop immediately | Huminto agad |
| Speech | "Stop immediately. {Object} is directly in front of you." | "Huminto agad. May {Object} sa iyong tapat." |
| UI Color | `#FFEBEE` (red tint) |
| Icon | `Icons.report_problem` (red) |
| Haptic | Critical (strong vibration) |

### 2. 🟠 Avoid Obstacle (`0.05 < area ≤ 0.20` + centered)
| Property | English | Tagalog |
|---|---|---|
| Title | Avoid Obstacle | Iwasan ang Harang |
| Speech | "Obstacle ahead: {Object} is directly in your path. Avoid it by stepping to your {left/right}." | "May harang sa harap: ang {Object} ay nasa tapat mo. Iwasan ito sa pamamagitan ng paghakbang sa {kaliwa/kanan}." |
| UI Color | `#FFF3E0` (orange tint) |
| Icon | `Icons.warning_amber_rounded` (orange) |
| Haptic | Normal |
| Escape Direction | Checks all other detected objects to find the clearer side |

### 3. 🟡 Slow Down (`area > 0.08` + NOT centered)
| Property | English | Tagalog |
|---|---|---|
| Title | Slow Down | Dahan-dahan |
| Speech | "Slow down. {Object} detected on your {left/right}." | "Magdahan-dahan. May {Object} sa iyong {kaliwa/kanan}." |
| UI Color | `#FFFDE7` (yellow tint) |
| Icon | `Icons.speed` (yellow) |
| Haptic | None |

### 4. 🟢 Path Clear (default — all other cases)
| Property | English | Tagalog |
|---|---|---|
| Title | Path Clear | Malinis ang Daan |
| Speech | "The pathway ahead is clear." (only spoken once on transition from blocked) | "Malinis ang daan." |
| UI Color | `#E8F5E9` (green tint) |
| Icon | `Icons.check_circle_outline` (green) |
| Haptic | None |

---

### 🚪 Non-Critical Architectural Cues (Door & Window Detection)
| Property | English | Tagalog |
|---|---|---|
| Trigger | Detection of doors or windows in frame | Detection of doors or windows in frame |
| Speech | "Door detected" / "Window detected" | "May pintuan sa malapit" / "May bintana sa malapit" |
| Behavior | Non-interrupting spoken advice; does NOT trigger high-priority warning card state or haptic alarms |
| UI Overlay | Rendered smoothly above the bottom 3x3 control card panel |

---

## Coordinate Math

### Centering Detection
An object is "centered" when it occupies the middle ~24% of the screen horizontally:

```dart
final isCentered = normCenterX >= 0.38 && normCenterX <= 0.62;
```

### Portrait Rotation Correction
Phone cameras in portrait mode have a 90° sensor rotation. The raw image Y axis corresponds to the screen X axis:

```dart
final normCenterX = 1.0 - (((obj.boundingBox.top + obj.boundingBox.bottom) / 2.0) / height);
```

### Area Calculation
Object size is measured as normalized area (fraction of total frame):

```dart
final normW = obj.boundingBox.width / width;
final normH = obj.boundingBox.height / height;
final area = normW * normH;
```

---

## Escape Direction Logic

When an obstacle is centered (Avoid state), the system checks all other detected objects to determine which side is clearer:

```dart
bool leftBlocked = false;
bool rightBlocked = false;
for (final r in objects) {
  if (r == targetObject) continue;
  final cX = 1.0 - (((r.boundingBox.top + r.boundingBox.bottom) / 2.0) / height);
  if (cX < 0.42) leftBlocked = true;
  if (cX > 0.58) rightBlocked = true;
}
final escapeDir = (leftBlocked && !rightBlocked) ? 'right' : 'left';
```

---

## Speech Cooldowns

| State | Repeat same message | New message |
|---|---|---|
| Stop | Every 3 seconds | Immediately |
| Avoid | Every 5 seconds | Immediately |
| Slow Down | Every 6 seconds | Immediately |
| Path Clear | Once per transition | — |
| Door / Window Cue | Every 8 seconds | Immediately upon detection |

The `_wasPathBlocked` flag ensures "Path Clear" is only spoken once when transitioning from a blocked state.

---

## Key Variables

| Variable | Type | Purpose |
|---|---|---|
| `_wasPathBlocked` | `bool` | Tracks if path was previously blocked (for "clear" announcement) |
| `_lastGuidanceText` | `String` | Last spoken guidance text (dedup) |
| `_lastGuidanceTime` | `DateTime?` | Timestamp of last speech (cooldown) |
| `_lastObjectDetectionTime` | `int` | Milliseconds epoch of last detection run |

---

## Key Files

All navigation logic and UI components live in:
- `lib/screens/hardware/hardware_screen.dart` → `_processObjectResults()` and `_clearPath()`
- `lib/screens/hardware/components/hud_controls_panel.dart` → Controls grid & Warning Status Card overlay positioning
