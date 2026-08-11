# EasyLens documentation

This directory documents the code currently in this repository. The numbered
[`source-of-truth`](source-of-truth/README.md) set is the canonical technical
reference; the topic pages in this directory provide shorter entry points.

## Start here

| Need | Document |
| --- | --- |
| Official Releases & Version Changelog (v1.0 - v20.0) | [Release Notes & History](RELEASES.md) |
| Run or configure the app | [Project overview](source-of-truth/01_project_overview.md) |
| Understand app structure and data flow | [Architecture](source-of-truth/02_architecture.md) |
| Find a screen or service | [Screens](source-of-truth/03_screens_and_navigation.md) / [services](source-of-truth/04_services_reference.md) |
| Work on AI, vision, or Buddy | [AI and ML pipeline](source-of-truth/05_ai_ml_pipeline.md) |
| Review MobileNetV2 Fine-Tuning & Benchmarks | [MobileNetV2 Training Report](training/MOBILENETV2_FINETUNING_REPORT.md) |
| Review Vision Datasets & ML Kit Comparison | [Dataset Specifications](dataset_specifications.md) |
| Review Multi-Tier Hybrid Vision Architecture | [Hybrid Vision Fusion](training/HYBRID_AI_FUSION_APP_INTEGRATION.md) |
| Work on navigation safety | [Walking navigation](source-of-truth/06_walking_navigation.md) |
| Configure cloud services or secrets | [Configuration and security](SECURITY_CONFIGURATION.md) |
| Test or release the app | [Testing and CI](source-of-truth/09_testing_cicd.md) |

## Scope and status

EasyLens is a Flutter accessibility-assistance application. It includes camera
vision features, a conversational assistant, GPS navigation, emergency-contact
workflows, and an ESP32-CAM stream integration. Some integrations are optional
or run in local/mock mode when credentials or platform services are unavailable.
Do not interpret a documented integration as a production guarantee without
verifying the relevant platform and cloud configuration.

Documentation was reconciled with the repository on 2026-07-25.
