# 04 — Services reference

Most services use a singleton factory. Their public methods and behavior should be read from the implementation before changing a UI flow.

| Service group | Main files | Responsibility |
| --- | --- | --- |
| Settings and app state | `settings_service`, `active_navigation_service`, `undo_service` | Persisted preferences, active route state, undo actions |
| Assistant and language | `rag_service`, `translation_service`, `journal_service` | Buddy retrieval/model requests, static UI strings, journals |
| Speech and alerts | `tts_service`, `stt_service`, `sound_service`, `notification_service`, `danger_warning_service` | Speech, recognition, sounds, notifications, hazard cues |
| Vision | `ml_kit_service`, `object_detector_service`, `tflite_processor`, `isolate_runner` | Label/OCR, detection, model inference, background work |
| Hardware and navigation | `esp32_service`, `navigation_voice_assistant`, `weather_service` | MJPEG stream, guidance speech, weather lookup |
| People and emergency | `firebase_service`, `face_registration_service`, `emergency_contact_service`, `sms_service` | Account/cloud data, local face/contact data, emergency SMS |
| Storage adapters | `storage/*` | Abstract in-memory storage plus optional Cloudflare D1/R2 clients |

`FirebaseService.initialize()` has a local mock fallback. `CloudflareD1Service` and `CloudflareR2Service` depend on environment values; their use must not make local user flows unavailable.
