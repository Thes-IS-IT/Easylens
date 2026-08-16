# 04 — Services Reference

All services use the Dart singleton factory pattern:

```dart
class ExampleService {
  static final ExampleService _instance = ExampleService._internal();
  factory ExampleService() => _instance;
  ExampleService._internal();
}
```

No dependency injection is used. Services are accessed globally via their factory constructor.

---

### 01 — SERVICE CATALOGUE

#### SettingsService
| | |
|---|---|
| **File** | `lib/services/settings_service.dart` |
| **Pattern** | Singleton + `ChangeNotifier` |
| **Persistence** | `SharedPreferences` |
| **Purpose** | Central settings hub. Stores language, theme, voice persona, notification preferences, contrast theme. All UI reacts to changes via `notifyListeners()`. |
| **Key Properties** | `selectedLanguage`, `selectedContrastTheme`, `voicePersonaId`, `speechRate`, `pitch`, `hapticFeedback`, `globalNotifications` |

#### TtsService
| | |
|---|---|
| **File** | `lib/services/tts_service.dart` |
| **Pattern** | Singleton |
| **Purpose** | Text-to-Speech wrapper with voice persona support (Max, Aria, Nova, Leo). Manages pitch, rate, and language switching. |
| **Key Methods** | `speak(String text)`, `stop()`, `setVoicePersona(String id)` |
| **Android & Persona Enhancements** | - **Lazy Engine Binding**: Defers `getVoices()` loading on Android using `setStartHandler`, `setCompletionHandler`, and `setErrorHandler` callback triggers. Voices are loaded in background after the first speech finishes, preventing engine binding `NullPointerException` crashes.<br>- **Pitch Safety Clamping**: Enforces strict pitch safety boundaries `[0.5, 2.0]` on Android to prevent service binder crashes (`DeadObjectException` / error -22).<br>- **Masculine Voice Emulation**: Overrides pitch values for Max and Echo personas on Android for optimal masculine tone.<br>- **Leo Child Voice Selection**: Features native child voice selection hooks for the Leo persona.<br>- **Locale Fallback**: Implements dynamic gender resolution and locale fallback mechanisms to prevent female voice stuck issues when changing personas. |

#### SttService
| | |
|---|---|
| **File** | `lib/services/stt_service.dart` |
| **Pattern** | Singleton |
| **Purpose** | Speech-to-Text input for Buddy chat and voice commands. |
| **Key Methods** | `startListening(Function(String) onResult)`, `stopListening(Function(String) onFinal)` |

#### RagService
| | |
|---|---|
| **File** | `lib/services/rag_service.dart` |
| **Size** | ~70KB — the largest service file |
| **Pattern** | Singleton |
| **Purpose** | Retrieval-Augmented Generation (RAG) for Buddy AI. Manages the full LLM pipeline: context retrieval → guardrails → model selection → response generation. |
| **LLM Backends** | Gemma 2B (offline), Gemini Flash (cloud), Ollama (local server) |
| **Guardrails** | Off-topic filter (math, trivia rejection), curated Q&A database, keyword-based context retrieval |
| **Key Methods** | `processQuery(String query)`, `initializeGemma()` |

#### FirebaseService
| | |
|---|---|
| **File** | `lib/services/firebase_service.dart` |
| **Pattern** | Singleton |
| **Purpose** | Firebase Auth + Firestore CRUD. Gracefully falls back to mock mode if Firebase config is missing. Restores and preserves custom profile attributes including `isForMyself` and `selectedConditions` during user registration. |
| **Key Methods** | `initialize()`, `signIn()`, `signUp()`, `getUserProfile()`, `updateUserProfile()` |

#### NotificationService
| | |
|---|---|
| **File** | `lib/services/notification_service.dart` |
| **Pattern** | Singleton |
| **Purpose** | High-performance notification system. Persists only critical safety alerts (like `"STOP"`, `"FIRE"`, `"HAZARD"`, or `"EMERGENCY"`) to SharedPreferences to prevent frame-skipping disk I/O lag. |
| **Key Methods** | `initialize()`, `pushObstacleAlert()`, `pushWarning()`, `getUnreadCount()` |

#### TranslationService
| | |
|---|---|
| **File** | `lib/services/translation_service.dart` |
| **Pattern** | Static methods |
| **Purpose** | Provides translated strings for English and Tagalog (Filipino). Uses a static `Map<String, Map<String, String>>` lookup. Works alongside `SignupStrings` for full app localization. |
| **Key Method** | `TranslationService.translate(String key, String language)` |

#### WeatherService
| | |
|---|---|
| **File** | `lib/services/weather_service.dart` |
| **Pattern** | Singleton |
| **Purpose** | Fetches current weather using Open-Meteo API via device GPS. Used by Buddy for weather-related questions. |
| **Key Method** | `fetchWeather()` → returns temperature, weather code, and storm status |

#### Esp32Service
| | |
|---|---|
| **File** | `lib/services/esp32_service.dart` |
| **Pattern** | Singleton + `ChangeNotifier` |
| **Purpose** | Manages ESP32-CAM and Smart Glasses frame streams. Streams MJPEG video frames and controls flash LED. Supports automatic fallback to mobile camera preview when the external stream disconnects. |
| **Default URL** | `http://192.168.4.1:81/stream` |
| **Key Methods** | `initialize()`, `connect(String url)`, `setFlash(bool on)` |

#### FaceRegistrationService
| | |
|---|---|
| **File** | `lib/services/face_registration_service.dart` |
| **Pattern** | Singleton + `ChangeNotifier` |
| **Purpose** | Stores registered face embeddings for face recognition HUD mode. |

#### EmergencyContactService
| | |
|---|---|
| **File** | `lib/services/emergency_contact_service.dart` |
| **Pattern** | Singleton |
| **Purpose** | CRUD for emergency contacts. Integrates with native contact pickers during signup and SOS management. |

#### SmsService
| | |
|---|---|
| **File** | `lib/services/sms_service.dart` |
| **Pattern** | Singleton |
| **Purpose** | Formats and sends SMS messages for emergency SOS. Handles Philippine phone number formatting (`09xx` → `+639xx`). |

#### ActiveNavigationService
| | |
|---|---|
| **File** | `lib/services/active_navigation_service.dart` |
| **Pattern** | Singleton |
| **Purpose** | Manages active walking navigation state and audio turn-by-turn cues. |

#### JournalService
| | |
|---|---|
| **File** | `lib/services/journal_service.dart` |
| **Pattern** | Singleton |
| **Purpose** | Buddy conversation journal logging and history management. |

#### UndoService
| | |
|---|---|
| **File** | `lib/services/undo_service.dart` |
| **Pattern** | Singleton |
| **Purpose** | Manages undo stack for shake-to-undo. Records user actions (tab switches, navigation) and reverses them on shake gesture. |

#### ObjectDetectorService
| | |
|---|---|
| **File** | `lib/services/object_detector_service.dart` |
| **Pattern** | Singleton |
| **Purpose** | Wrapper for Google ML Kit object detector initialization and configuration. |

#### TfliteProcessor
| | |
|---|---|
| **File** | `lib/services/tflite_processor.dart` |
| **Pattern** | Singleton |
| **Purpose** | TensorFlow Lite interpreter for SSD MobileNetV2. Loads the model, runs inference, and returns bounding boxes + class IDs. |
| **Model** | `assets/models/ssd_mobilenet_v2.tflite` (300×300 RGB input) |

#### IsolateRunner
| | |
|---|---|
| **File** | `lib/services/isolate_runner.dart` |
| **Purpose** | Utility for running heavy computation in Dart isolates (used by YUV→NV21 conversion). |

#### MlKitService
| | |
|---|---|
| **File** | `lib/services/ml_kit_service.dart` |
| **Purpose** | Shared ML Kit initialization helpers. |

#### Storage Services

##### CloudflareD1Service
| | |
|---|---|
| **File** | `lib/services/storage/cloudflare_d1_service.dart` |
| **Purpose** | HTTP client for Cloudflare D1 serverless SQL database. |

##### CloudflareR2Service
| | |
|---|---|
| **File** | `lib/services/storage/cloudflare_r2_service.dart` |
| **Purpose** | S3-compatible object storage client with AWS Signature V4 signing (HMAC-SHA256). |

##### StorageService
| | |
|---|---|
| **File** | `lib/services/storage/storage_service.dart` |
| **Purpose** | Abstraction layer over R2 and D1 for unified storage operations. |
