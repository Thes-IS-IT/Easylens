# Hybrid AI Vision Fusion & EasyLens App Integration Architecture

---

### 01 — EXECUTIVE SUMMARY

To deliver comprehensive spatial awareness for visually impaired users without compromising real-time performance or battery life, EasyLens implements a Multi-Tier Hybrid AI Vision Fusion Architecture.

Instead of relying on a single vision model, EasyLens dynamically combines:
1. **On-Device Google ML Kit Image Labeler** (400+ detectable objects & scene categories)
2. **On-Device TFLite SSD MobileNetV2** (91 COCO classes with 2D spatial bounding boxes)
3. **Custom Fine-Tuned 24-Class MobileNetV2** (High-priority navigation & safety hazard classifier)
4. **Multimodal LLM / Offline RAG Pipeline** (Offline Gemma 2B & Cloud Gemini 3.5 Flash for natural speech & scene synthesis)

---

### 02 — MULTI-TIER VISION ENGINE TAXONOMY

```text
                           Live Camera Frame (YUV / NV21 / JPEG)
                                            │
           ┌────────────────────────────────┼────────────────────────────────┐
           ▼                                ▼                                ▼
   Google ML Kit Labeler           SSD MobileNetV2 TFLite          Fine-Tuned MobileNetV2
 (400+ General Objects & Scene)   (80 COCO Bounding Boxes)       (24 Fine-Tuned Navigation Classes)
           │                                │                                │
  General Scene Labels             Spatial Coordinates & Boxes       High-Risk Hazard Alerts
  ("furniture", "kitchen")        ([ymin, xmin, ymax, xmax])       ("Pothole", "Crosswalk", "Stairs")
           │                                │                                │
           └────────────────────────────────┼────────────────────────────────┘
                                            │
                                            ▼
                           EasyLens Multi-Tier Fusion Layer
                                            │
                    ┌───────────────────────┴───────────────────────┐
                    ▼                                               ▼
     Real-Time TTS Audio Warnings                   Offline RAG / Cloud LLM Synthesis
  ("Warning: Pothole 2 meters ahead")             ("You are standing in a living room...")
```

---

### 03 — DEEP DIVE: THE 3 VISION ENGINES

#### Tier 1: On-Device Google ML Kit Image Labeler (400+ Objects)
* **Service**: `MlKitService` ([`lib/services/ml_kit_service.dart`](file:///Users/arronkianparejas/easylens/lib/services/ml_kit_service.dart))
* **Scope**: Detects over 400 general object categories and scene descriptors based on the Google Knowledge Graph taxonomy.
* **Role in App**:
  * Provides high-level ambient scene classification (e.g., `"indoor"`, `"office"`, `"tableware"`).
  * Refines raw labels via fuzzy matching (`_refineLabel()`) into natural language equivalents (`"partition"` $\rightarrow$ `"wall"`, `"musical instrument"` $\rightarrow$ `"keyboard or laptop"`).
  * Feeds labels to the Creative Dialogue Generator to produce natural spoken ambient summaries ("You are near a desk with a computer").

#### Tier 2: Standard TFLite SSD MobileNetV2 (91 COCO Classes)
* **Service**: `ObjectDetectorService` ([`lib/services/object_detector_service.dart`](file:///Users/arronkianparejas/easylens/lib/services/object_detector_service.dart)) & `TfliteProcessor` ([`lib/services/tflite_processor.dart`](file:///Users/arronkianparejas/easylens/lib/services/tflite_processor.dart))
* **Model Asset**: `assets/models/ssd_mobilenet_v2.tflite`
* **Labels Asset**: `assets/models/coco_labels.txt` (91 COCO classes)
* **Scope**: Real-time object localization and tracking with normalized bounding boxes `[ymin, xmin, ymax, xmax]`.
* **Role in App**:
  * Calculates relative object center positions in portrait mode (`normCenterX = 1.0 - (top + bottom) / (2 * height)`).
  * Announces directional cues ("Door on your left", "Chair in front").
  * Renders bounding box HUD overlays for low-vision users and caregivers.

#### Tier 3: Custom Fine-Tuned 24-Class MobileNetV2 Model
* **Model Spec**: 4-Phase Transfer Learning Trained Model ([`docs/training/mobilenetv2_finetuning_report.md`](file:///Users/arronkianparejas/easylens/docs/training/mobilenetv2_finetuning_report.md))
* **Scope**: 24 high-priority navigation hazards and accessibility targets:
  `Bus`, `Bushes`, `Person`, `Truck`, `bicycle`, `branch`, `car`, `crosswalk`, `door`, `elevator`, `fire_hydrant`, `green_light`, `gun`, `motorcycle`, `pothole`, `rat`, `red_light`, `scooter`, `stairs`, `stop_sign`, `traffic_cone`, `train`, `tree`, `yellow_light`.
* **Role in App**:
  * **High-Urgency Interrupt Warnings**: Bypasses normal speech queues to immediately vocalize critical safety hazards (e.g., 97% recall for potholes, 92% recall for stairs, 95% F1 for crosswalks).
  * **Traffic Signal Assistant**: Specifically identifies traffic light state (`red_light` vs `green_light` vs `yellow_light`) to guide safe pedestrian street crossing.
  * **Threat Detection**: Identifies dangerous objects (`gun`, `rat`) to provide early warning audio alerts.

---

### 04 — HOW THE APP INTEGRATES AND FUSES THE ENGINES

#### Mode-Specific Processing & Execution Budget

To ensure 60 FPS UI responsiveness and avoid thermal throttling, frame processing is governed by strict execution rules:

| HUD Mode | ML Kit Labeler | SSD COCO Bounding Box | Fine-Tuned 24-Class Model | Execution Strategy & Throttle |
|---|---|---|---|---|
| **Navigation Mode** | Yes | Yes | Yes | **Staggered Alternating Frames** (400ms interval, 2.5 FPS target) |
| **Object Detection Mode** | No | Yes | Yes | Runs SSD + Custom classifier for bounding box & hazard mapping |
| **Face Recognition Mode** | No | No | No | Only MTCNN / Google Face Detector runs (1500ms cooldown) |
| **Default Scene Mode** | Yes | No | No | ML Kit scene labeling for ambient audio dialogues |

#### Performance & Memory Optimization Pipeline

1. **NV21 Fast Downsampling**:
   In `lib/services/tflite_processor.dart`, camera NV21 bytes are converted directly to $300 \times 300$ RGB Uint8 arrays using inline fixed-point integer bit-shifting without invoking heavy image decoding packages.
2. **Isolate Threading (`compute()`)**:
   Heavy tensor reshaping and buffer preparation are offloaded to background Dart isolates, keeping the main Flutter UI thread free of frame drops.
3. **Single-Frame Lock (`_isProcessingFrame`)**:
   Prevents memory leak accumulation by dropping incoming camera frames until the active inference cycle completes.
4. **Staggered Frame Execution**:
   In `navigation` mode, Tier 1 (ML Kit) and Tier 2/3 (TFLite models) are executed on alternate frames. This cuts memory bandwidth draw by 50% while maintaining continuous real-time coverage.

---

### 05 — MULTI-TIER VISION ENGINE SUMMARY MATRIX

| Engine | Model Type | Number of Classes | Bounding Box Spatial Info? | Primary Target Use Case | Latency |
|---|---|---|---|---|---|
| **Tier 1: Google ML Kit** | On-Device Neural Net | **400+ Categories** | No (Global Labels) | General scene context & indoor/outdoor dialogues | ~15-25 ms |
| **Tier 2: TFLite SSD MobileNetV2** | Single Shot Detector | **91 COCO Classes** | Yes (`[ymin, xmin, ymax, xmax]`) | Object tracking, obstacle location & HUD overlays | ~12-18 ms |
| **Tier 3: Fine-Tuned MobileNetV2** | 4-Phase Classifier | **24 Custom Classes** | Image / Region Crop | **High-hazard safety alerts (potholes, crosswalks, stairs, traffic lights)** | **2.48 ms** |
| **Tier 4: Multimodal RAG** | Gemma 2B / Gemini Flash | Open Domain | Scene Context Synthesis | Conversational Q&A assistant ("Buddy") | Stream / Speech |

---

### 06 — ARCHITECTURAL REFERENCES

* **AI/ML Pipeline Source of Truth**: [`docs/source-of-truth/05_ai_ml_pipeline.md`](file:///Users/arronkianparejas/easylens/docs/source-of-truth/05_ai_ml_pipeline.md)
* **MobileNetV2 Training Report**: [`docs/training/mobilenetv2_finetuning_report.md`](file:///Users/arronkianparejas/easylens/docs/training/mobilenetv2_finetuning_report.md)
* **TFLite Processor Implementation**: [`lib/services/tflite_processor.dart`](file:///Users/arronkianparejas/easylens/lib/services/tflite_processor.dart)
* **ML Kit Service Implementation**: [`lib/services/ml_kit_service.dart`](file:///Users/arronkianparejas/easylens/lib/services/ml_kit_service.dart)
* **Object Detector Service**: [`lib/services/object_detector_service.dart`](file:///Users/arronkianparejas/easylens/lib/services/object_detector_service.dart)
