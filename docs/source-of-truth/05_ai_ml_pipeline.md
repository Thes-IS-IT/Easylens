# 05 — AI and ML pipeline

## Buddy

Startup asks `RagService` to load `assets/models/buddy_knowledge.json`. Knowledge items are indexed by keywords and ranked with cached TF-IDF engines. The service has curated/local responses and local-only guardrails for selected off-topic prompts.

When Local AI is enabled, the service can initialize Gemma through `flutter_gemma` if the model is available in app storage. The service can also download a Gemma model from its hard-coded source. Online Gemini requests use the Google Generative AI package and configured/user-supplied keys. Model choice is governed by mode, language, key availability, model availability, and failure/fallback paths—not merely by a language label.

Online LLM requests, model downloads, reverse geocoding, and other remote calls may transmit user content or location. Handle consent, retention, and provider terms before production use.

## Vision

| Path | Code | Notes |
| --- | --- | --- |
| Image labeling/OCR | `MlKitService` | Google ML Kit device processing |
| Object detection | `ObjectDetectorService` | ML Kit object-detection wrapper |
| TFLite inference | `TfliteProcessor` | Packaged TFLite model and label assets |
| Camera orchestration | `HardwareScreen` | Camera/ESP32 frames, HUD, overlays, mode-specific work |

`assets/models/` contains `ssd_mobilenet*.tflite`, `mobilenetv2.tflite`, and label files. Tensor shapes, labels, thresholds, and outputs must be verified against `TfliteProcessor` when models change.

## Tests

The existing test suite exercises RAG context retrieval, representative local-only guardrails, SMS phone normalization, and welcome-screen rendering. It does not validate live camera, model inference, ESP32, Firebase, Gemini, or route services end-to-end.
