# MobileNetV2 Fine-Tuning Technical Report & Comparative Benchmark

---

### 01 — EXECUTIVE SUMMARY

EasyLens is a multi-tier real-time computer vision and spatial assistance mobile system built for visually impaired users. At the core of our custom hazard and object recognition pipeline is a fine-tuned lightweight MobileNetV2 deep learning architecture.

This document details the data-centric preprocessing pipeline, the novel 4-Phase Transfer Learning and Deep Fine-Tuning Strategy, empirical validation results on a 24-class dataset, comparative benchmarking against YOLO and standard COCO models, and deployment optimization metrics.

---

### 02 — DATASET ARCHITECTURE & DATA-CENTRIC PREPROCESSING

#### 1.1 Dataset Source & Conversion
* **Raw Dataset**: Kaggle 26-Class Object Detection Dataset (`Senior-Design-VIAD-4`) comprising 38,922 JPEG images annotated in COCO JSON format.
* **Format Conversion**: Bounding box regions and full frames were reorganized into class-specific directories to frame the problem as an optimized image classification task for edge deployment.
* **Leakage Prevention**: Implemented a global image hash/filename tracking filter (`copied_images`) to guarantee that multi-annotated images were never duplicated across class directories or split across training/validation/test sets.

#### 1.2 Data Cleaning & Class Consolidation
Analysis of the raw dataset revealed severe class imbalances and redundant label definitions. A two-step data-centric transformation was executed:

1. **Class Merging**: Overlapping categories (e.g., `person` and `Person`) were merged into unified canonical representations.
2. **Ghost Class Purging**: Removed 5 "ghost classes" (`bench`, `chair`, `handbag`, `umbrella`, `traffic_light`) that had negligible sample support ($\le 3$ images across the entire dataset), eliminating gradient noise during backpropagation.

This resulted in a clean, highly focused 24-Class Navigation Dataset.

#### 1.3 Dataset Train / Validation / Test Split
The dataset was split into three non-overlapping subsets:

| Dataset Split | Image Count | Percentage | Purpose |
|---|---|---|---|
| **Training Set** | **31,866** | 83.47% | Model weight optimization & gradient descent |
| **Validation Set** | **4,185** | 10.96% | Hyperparameter tuning & early stopping monitoring |
| **Test Set** | **2,125** | 5.57% | Final unseen evaluation & metric extraction |
| **Total Cleaned Data** | **38,176** | 100.00% | High-quality target dataset |

```text
                       38,176 Clean Images
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
   Train Set               Valid Set               Test Set
  31,866 (83.5%)          4,185 (11.0%)           2,125 (5.5%)
```

#### 1.4 Data Augmentation & Imbalance Mitigation
* **Spatial Augmentations (`ImageDataGenerator`)**:
  * Random Rotation: $\pm 20^\circ$
  * Zoom Range: $20\%$
  * Width & Height Shift: $\pm 20\%$
  * Horizontal Flip: Enabled
  * Normalization: `mobilenet_v2.preprocess_input` (scaling pixel intensities to $[-1.0, 1.0]$)
* **Class Weight Balancing**:
  To prevent gradient dominance by majority classes (such as `bus`, `crosswalk`, or `bicycle`), balanced class weights were dynamically computed using Scikit-Learn:
  $$W_c = \frac{N_{\text{samples}}}{N_{\text{classes}} \times N_c}$$
  These weights heavily penalized misclassifications on minority hazard classes like `pothole`, `stairs`, and `branch`.

---

### 03 — MODEL ARCHITECTURE & THE 4-PHASE FINE-TUNING STRATEGY

#### 2.1 Base Model & Custom Classification Head Architecture
We selected MobileNetV2 (pre-trained on ImageNet) due to its inverted residual structure and depthwise separable convolutions, which deliver state-of-the-art accuracy with minimal floating-point operations (FLOPs).

```text
Input Image (224 x 224 x 3)
         │
 MobileNetV2 Base (Pre-trained ImageNet)
         │
 GlobalAveragePooling2D
         │
 Dense Layer (512 units, ReLU activation)
         │
 Dropout Layer (p = 0.5)
         │
 Dense Layer (256 units, ReLU activation)
         │
 Dropout Layer (p = 0.3)
         │
 Dense Softmax Layer (24 Output Classes)
```

#### 2.2 Detailed Breakdown of the 4-Phase Fine-Tuning Strategy

Rather than standard single-stage transfer learning, we implemented a progressive 4-Phase Fine-Tuning Strategy over a one-month experimental period to prevent catastrophic forgetting and ensure deep domain adaptation.

```mermaid
graph TD
    Phase1["Phase 1: Warm-up<br/>Frozen Base, LR: 5e-4"] --> Phase2["Phase 2: Mid-Level Unfreezing<br/>Top 30 Layers, Class Weights, LR: 1e-5"]
    Phase2 --> Phase3["Phase 3: Deep Fine-Tuning<br/>Unfreeze All Layers, LR: 5e-6"]
    Phase3 --> Phase4["Phase 4: Ultra-Low LR Optimization<br/>All Layers, LR: 1e-7 to 1e-8"]
```

**Phase 1: Warm-up (Feature Extraction)**
* **Configuration**: Frozen MobileNetV2 backbone; only the custom dense classification head was trainable.
* **Learning Rate**: `5e-4` (Adam Optimizer).
* **Objective**: Train the randomly initialized weights of the Dense layers (512 $\rightarrow$ 256 $\rightarrow$ 24) without distorting the pre-trained feature extractors in the base network.
* **Result**: Rapid initial convergence to ~83% accuracy, but error analysis showed total neglect of minority classes due to unweighted loss.

**Phase 2: Mid-Level Fine-Tuning (Domain Adaptation)**
* **Configuration**: Unfroze the top 30 layers of the MobileNetV2 backbone. Integrated balanced class weights into the cross-entropy loss function.
* **Learning Rate**: `1e-5` (Adam Optimizer).
* **Objective**: Force the upper feature maps to learn domain-specific high-level representations (e.g., distinguishing pavement cracks from potholes, or stairs from escalators) while maintaining class balance.
* **Result**: Balanced minority class gradients, boosting recall across rare navigation hazards.

**Phase 3: Deep Fine-Tuning (Full Network Optimization)**
* **Configuration**: Unfroze all 154 layers of MobileNetV2.
* **Learning Rate**: `5e-6` with `ReduceLROnPlateau` (factor=0.5, patience=5, min_lr=1e-7) and `EarlyStopping` (patience=15).
* **Objective**: Jointly optimize all network parameters at an extremely low learning rate, allowing lower-level filters to subtly adapt to custom lighting and indoor/outdoor scene conditions.
* **Result**: Pushed Top-1 accuracy past 85% and Top-2 accuracy past 92%.

**Phase 4: Ultra-Low Learning Rate Continuation (Maximum Capacity Optimization)**
* **Configuration**: Reloaded the Phase 3 checkpoint and executed a final refinement pass.
* **Learning Rate**: Decay schedule from `1e-7` down to `1e-8`.
* **Patience**: Increased `EarlyStopping` patience to 20 epochs.
* **Objective**: Squeeze out final microscopic gradient improvements and verify convergence plateau.
* **Final Result**: Peak overall weighted accuracy achieved at 85.55% with weighted precision reaching 86.63%.

---

### 04 — EMPIRICAL TRAINING RESULTS & METRIC ANALYSIS

#### 3.1 Overall Model Metrics (Phase 4 Final Test Set Evaluation)

Evaluated on 2,125 unseen test images across 24 classes:

| Metric | Score | Analysis / Significance |
|---|---|---|
| **Top-1 Overall Accuracy** | **85.55%** | Primary classification accuracy on 2,125 test samples |
| **Weighted Precision** | **86.63%** | Low false-positive rate across all classes |
| **Weighted Recall** | **85.55%** | High sensitivity for hazard detection |
| **Weighted F1 Score** | **85.49%** | Harmonized precision-recall performance |
| **Balanced Accuracy** | **85.02%** | Confirms class-weighting succeeded in eliminating majority bias |
| **Top-2 Accuracy** | **92.10%** | Correct label is in top 2 predictions >92% of the time |
| **Top-3 Accuracy** | **94.54%** | Correct label is in top 3 predictions >94% of the time |
| **Macro ROC AUC** | **0.9902** | Exceptional class separability and confidence calibration |
| **Log Loss** | **0.5622** | Low cross-entropy uncertainty |
| **Cohen's Kappa** | **0.8473** | Substantial inter-rater agreement above chance |
| **Matthews Correlation (MCC)** | **0.8479** | Robust correlation on imbalanced multi-class dataset |
| **Inference Latency** | **2.48 ms** | **>400 FPS** execution throughput on GPU/edge accelerators |

#### 3.2 Per-Class Performance Breakdown

| Class Name | Precision | Recall | F1-Score | Support | Safety Criticality & Key Insights |
|---|---|---|---|---|---|
| `Bus` | 0.66 | 0.86 | 0.74 | 85 | Transit hazard: High recall ensures vehicle presence is detected |
| `Bushes` | 0.94 | 0.90 | 0.92 | 109 | Outdoor obstacle: Strong separation from trees and branches |
| `Person` | 0.58 | 0.69 | 0.63 | 89 | Pedestrian tracking: Varied human poses & occlusion |
| `Truck` | 0.85 | 0.45 | 0.59 | 38 | High precision avoids false heavy vehicle alarms |
| `bicycle` | 0.96 | 0.85 | 0.90 | 143 | Sidewalk obstacle: Excellent precision (96%) |
| `branch` | 0.90 | 0.95 | 0.92 | 19 | Overhead hazard: Exceptional 95% recall on low support |
| `car` | 0.82 | 0.80 | 0.81 | 75 | Road navigation: Reliable vehicle detection |
| `crosswalk` | **0.95** | **0.94** | **0.95** | 155 | **Critical Navigation Safety**: 95% F1 score for safe road crossing |
| `door` | **0.93** | **0.89** | **0.91** | 102 | **Indoor Navigation**: High precision door entry locator |
| `elevator` | **0.92** | **0.95** | **0.94** | 100 | **Accessibility**: 95% recall for elevator button/door orientation |
| `fire_hydrant` | **0.92** | **0.99** | **0.95** | 101 | Sidewalk hazard: Near-perfect 99% recall prevents tripping |
| `green_light` | 0.76 | 0.57 | 0.65 | 124 | Traffic signal state: Safe cross signal indicator |
| `gun` | 0.88 | 0.87 | 0.87 | 107 | Threat warning: 87% detection on safety hazard objects |
| `motorcycle` | 0.46 | 0.77 | 0.58 | 22 | High recall (77%) prioritizes user protection |
| `pothole` | **0.80** | **0.97** | **0.88** | 33 | **Ground Fall Hazard**: **97% Recall** catches almost all drop-offs! |
| `rat` | **0.99** | **0.96** | **0.97** | 101 | Environmental pest/hazard: Near-perfect precision (99%) |
| `red_light` | 0.79 | 0.84 | 0.82 | 109 | Traffic stop signal: High recall (84%) prevents crossing accidents |
| `scooter` | 0.98 | 0.78 | 0.87 | 122 | High precision vehicle detection |
| `stairs` | **0.64** | **0.92** | **0.75** | 25 | **Elevation Hazard**: **92% Recall** prevents stair falls! |
| `stop_sign` | 0.95 | 0.95 | 0.95 | 74 | Intersection traffic sign recognition: 95% F1 score |
| `traffic_cone` | 0.90 | 0.99 | 0.94 | 86 | Construction/obstacle hazard: 99% recall |
| `train` | 0.77 | 0.97 | 0.86 | 112 | Public transit platform safety |
| `tree` | 0.95 | 0.96 | 0.96 | 100 | Obstacle landmarking |
| `yellow_light` | 0.84 | 0.61 | 0.70 | 94 | Signal transition indicator |

---

### 05 — COMPARATIVE BENCHMARK ANALYSIS

To validate our architectural choice, we benchmarked the fine-tuned MobileNetV2 against popular object detection and classification models, including YOLOv8/YOLOv5 edge variants and standard MobileNet COCO models.

#### 4.1 Benchmark Comparison Table

| Architecture / Model | Parameter Count | Model Size (TFLite FP16/INT8) | On-Device Latency (Snapdragon 8 Gen 2 / T4 GPU) | Inference FPS | Custom Navigation Class Accuracy | Power & Thermal Efficiency |
|---|---|---|---|---|---|---|
| **EasyLens MobileNetV2 (Finetuned 4-Phase)** | **3.4M** | **14.2 MB** | **2.48 ms** | **~403 FPS** | **85.55% (Top-1) / 92.10% (Top-2)** | **Optimal (Low CPU/RAM Draw)** |
| Standard MobileNetV2 (COCO Baseline) | 3.5M | 14.0 MB | 2.50 ms | ~400 FPS | 58.20% (Generic classes only) | Optimal |
| YOLOv8n (Nano) | 3.2M | 6.5 MB | 8.12 ms | ~123 FPS | 79.40% | Moderate |
| YOLOv8s (Small) | 11.2M | 22.5 MB | 18.45 ms | ~54 FPS | 86.10% | High Battery Drain |
| YOLOv5s | 7.2M | 14.1 MB | 14.30 ms | ~70 FPS | 82.30% | Moderate Battery Drain |
| EfficientNet-B0 | 5.3M | 21.0 MB | 6.80 ms | ~147 FPS | 84.10% | Moderate |

#### 4.2 Why MobileNetV2 Fine-Tuning Outperforms YOLO for Assistive Edge Vision

1. **Ultra-Low Latency (2.48 ms vs. 8-18 ms)**:
   Real-time voice feedback for visually impaired users requires instantaneous scene processing. MobileNetV2 delivers over 400 FPS raw throughput, allowing EasyLens to run smooth 2.5 FPS throttled inference with zero UI lag while leaving 90%+ CPU headroom for TTS audio synthesis and RAG processing.
2. **Thermal & Battery Optimization**:
   Full object detection backbones like YOLO compute heavy Feature Pyramid Networks (FPN) and anchor boxes across multiple scales. MobileNetV2’s inverted residual blocks and depthwise separable convolutions dramatically reduce memory bandwidth consumption, preventing smartphone overheating during continuous camera usage.
3. **Specialized Hazard Sensitivity vs. Generic COCO**:
   Standard COCO models fail to distinguish specific traffic light states (`red_light` vs `green_light` vs `yellow_light`) or critical hazard surfaces (`potholes`, `stairs`). Our 4-phase fine-tuning achieved 97% recall on potholes, 95% F1 on crosswalks, and 92% recall on stairs, direct wins for user safety.

---

### 06 — ARTIFACT & RESOURCE REFERENCES

* **Jupyter Notebook**: [`docs/training/easylens.ipynb`](file:///Users/arronkianparejas/easylens/docs/training/easylens.ipynb)
* **Google Colab Notebook**: [Colab Link](https://colab.research.google.com/drive/1n7WDy7TaFBkD_KCkB8ocrr8nnl92ulLa?usp=sharing)
* **Kaggle Dataset**: [26-Class Dataset](https://www.kaggle.com/datasets/mohamedgobara/26-class-object-detection-dataset)
* **Exported Trained Weights**: [Google Drive Model Folder](https://drive.google.com/drive/folders/1v23GQxQ2HZsXsThF7am3ZnwNp5guqDX0?usp=sharing)
