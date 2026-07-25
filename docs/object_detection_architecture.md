# Vision and object-detection architecture

EasyLens uses multiple vision paths rather than one universal detector:

- `MlKitService` supports image labeling and text recognition.
- `ObjectDetectorService` uses Google ML Kit object detection.
- `TfliteProcessor` loads packaged TFLite assets and exposes SSD-style results.
- `HardwareScreen` coordinates device-camera frames, ESP32 frames, UI overlays,
  and selected HUD modes.

The packaged files in `assets/models/` determine the models and labels actually
available at runtime. Keep their input/output tensor assumptions synchronized
with `TfliteProcessor`; a model file name alone does not guarantee compatibility.

Further details and limitations are in [05 — AI & ML Pipeline](source-of-truth/05_ai_ml_pipeline.md).
