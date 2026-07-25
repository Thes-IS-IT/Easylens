# Algorithms used in EasyLens

| Area | Implementation |
| --- | --- |
| Knowledge retrieval | Keyword inverted index plus TF-IDF scoring in `RagService` |
| Object detection | TFLite SSD-style model processing in `TfliteProcessor`; model/label assets are in `assets/models` |
| On-device labeling and OCR | Google ML Kit services |
| Location guidance | Position stream, OSRM route geometry, distance calculations through `Geolocator` |
| ESP32 image stream | MJPEG boundary/frame parsing in `Esp32Service` |

Algorithms run under device, model, and platform constraints. Refer to
[AI & ML pipeline](source-of-truth/05_ai_ml_pipeline.md) and
[walking navigation](source-of-truth/06_walking_navigation.md) before changing
thresholds or safety messaging.
