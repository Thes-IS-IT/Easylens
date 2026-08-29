# EasyLens Documentation Index & Directory Map

---

Welcome to the **EasyLens** documentation repository. All technical specifications, architectural diagrams, model training notebooks, setup guides, and project management artifacts are organized into structured topic folders below.

---

### 01 — DIRECTORY STRUCTURE & FILE MAP

#### `/architecture`
Architectural blueprints, system design models, and database tier specs:
* [`architecture.md`](file:///Users/arronkianparejas/easylens/docs/architecture/architecture.md) - System architecture overview & Flutter provider engine
* [`conceptual_framework.md`](file:///Users/arronkianparejas/easylens/docs/architecture/conceptual_framework.md) - Conceptual Framework & Theoretical IPO Model (Input-Process-Output)
* [`ai_architecture.md`](file:///Users/arronkianparejas/easylens/docs/architecture/ai_architecture.md) - Multi-tier edge AI architecture
* [`local_storage_architecture.md`](file:///Users/arronkianparejas/easylens/docs/architecture/local_storage_architecture.md) - SQLite & SharedPreferences caching strategy
* [`object_detection_architecture.md`](file:///Users/arronkianparejas/easylens/docs/architecture/object_detection_architecture.md) - TFLite MobileNetV2 SSD pipeline

#### `/vision_and_ai`
Computer vision algorithms, face recognition, and LLM guardrails:
* [`face_registration_and_recognition.md`](file:///Users/arronkianparejas/easylens/docs/vision_and_ai/face_registration_and_recognition.md) - 25D geometric landmark feature vector extraction & face recognition pipeline
* [`ai_memory_and_guardrails.md`](file:///Users/arronkianparejas/easylens/docs/vision_and_ai/ai_memory_and_guardrails.md) - Context memory windowing & Gemini guardrails
* [`algorithm.md`](file:///Users/arronkianparejas/easylens/docs/vision_and_ai/algorithm.md) - Spatial hazard scoring & bounding box intersection algorithms

#### `/specifications`
Technical specs, software stack table, hardware details, and usability metrics:
* [`software_and_hardware_specifications.md`](file:///Users/arronkianparejas/easylens/docs/specifications/software_and_hardware_specifications.md) - Hardware specs & software engine matrix
* [`usability_quality_metrics.md`](file:///Users/arronkianparejas/easylens/docs/specifications/usability_quality_metrics.md) - ISO/IEC 25010 & WCAG 2.2 usability testing criteria
* [`software.md`](file:///Users/arronkianparejas/easylens/docs/specifications/software.md) - Full technology stack table & build deployment footprint

#### `/dfd`
Data flow, use case, entity relationship diagrams, data dictionary, and Gantt charts:
* [`data_flow_diagrams.md`](file:///Users/arronkianparejas/easylens/docs/dfd/data_flow_diagrams.md) - Current vs. Proposed Level-1 & Level-2 DFDs
* [`use_case_diagrams.md`](file:///Users/arronkianparejas/easylens/docs/dfd/use_case_diagrams.md) - Simplified & Detailed Use Case Diagrams (UCD)
* [`entity_relationship_diagram.md`](file:///Users/arronkianparejas/easylens/docs/dfd/entity_relationship_diagram.md) - Conceptual & Relational ERD models
* [`data_dictionary.md`](file:///Users/arronkianparejas/easylens/docs/dfd/data_dictionary.md) - Table schemas, data types, and key constraints
* [`gantt_chart.md`](file:///Users/arronkianparejas/easylens/docs/dfd/gantt_chart.md) - Project implementation Gantt chart timeline (Dec 2025 - Aug 2026)

#### `/setup`
Deployment guides, Cloudflare R2 bucket setup, and CI/CD pipelines:
* [`security_configuration.md`](file:///Users/arronkianparejas/easylens/docs/setup/security_configuration.md) - API key management & environment security
* [`cloudflare_r2_setup.md`](file:///Users/arronkianparejas/easylens/docs/setup/cloudflare_r2_setup.md) - S3-compatible R2 storage & AWS SigV4 signing guide
* [`cicd_pipeline.md`](file:///Users/arronkianparejas/easylens/docs/setup/cicd_pipeline.md) - GitHub Actions & release build pipelines

#### `/features_and_modules`
Application feature catalogs and spatial warning subsystems:
* [`features.md`](file:///Users/arronkianparejas/easylens/docs/features_and_modules/features.md) - Complete application feature catalog
* [`navigation_warning_system.md`](file:///Users/arronkianparejas/easylens/docs/features_and_modules/navigation_warning_system.md) - Spatial audio & haptic obstacle warning engine

#### `/training`
Machine learning notebooks and fine-tuning reports:
* [`easylens.ipynb`](file:///Users/arronkianparejas/easylens/docs/training/easylens.ipynb) - Jupyter Notebook for MobileNetV2 24-class fine-tuning
* [`mobilenetv2_transfer_learning_workflow.md`](file:///Users/arronkianparejas/easylens/docs/training/mobilenetv2_transfer_learning_workflow.md) - Figure 4.1 Transfer Learning & Unfreezing workflow
* [`mobilenetv2_finetuning_report.md`](file:///Users/arronkianparejas/easylens/docs/training/mobilenetv2_finetuning_report.md) - Training empirical evaluation report
* [`hybrid_ai_fusion_app_integration.md`](file:///Users/arronkianparejas/easylens/docs/training/hybrid_ai_fusion_app_integration.md) - TFLite + ML Kit + Gemma fusion integration

#### `/system_architecture`
* [`system_architecture_and_uml.md`](file:///Users/arronkianparejas/easylens/docs/system_architecture/system_architecture_and_uml.md) - Comprehensive UML diagrams & hardware specifications

#### `/source-of-truth`
* Canonical technical references & numbered specification set: [`readme.md`](file:///Users/arronkianparejas/easylens/docs/source-of-truth/readme.md)

### 02 — PROJECT GOVERNANCE, RESEARCH TEAM & POLICIES

* [`LICENSE.md`](file:///Users/arronkianparejas/easylens/LICENSE.md) - Modified MIT License with Academic Thesis Conditions & copyright
* [`CONTRIBUTING.md`](file:///Users/arronkianparejas/easylens/CONTRIBUTING.md) - Thesis contribution guidelines, code standards & PR workflows
* [`SECURITY.md`](file:///Users/arronkianparejas/easylens/SECURITY.md) - Edge AI privacy model, credential isolation & vulnerability reporting

### 03 — RELEASE HISTORY & APK ARCHITECTURE SPECIFICATIONS

* [`releases.md`](file:///Users/arronkianparejas/easylens/docs/releases.md) - Complete release milestones (v1.0 - v25.0), ABI compatibility matrix (`arm64-v8a` vs. FAT APK), and size optimization guidelines.
