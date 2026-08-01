import 'package:speech_to_text/speech_to_text.dart';
import 'settings_service.dart';
import 'tts_service.dart';

class SttService {
  static final SttService _instance = SttService._internal();
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  Function(bool)? _currentListeningStateCallback;

  factory SttService() {
    return _instance;
  }

  SttService._internal();

  bool get isTtsSpeaking => TtsService().isSpeaking;

  Future<bool> initializeStt() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (val) {
          print('STT Error: $val');
          _currentListeningStateCallback?.call(false);
        },
        onStatus: (val) {
          print('STT Status: $val');
          if (val == 'notListening' || val == 'done') {
            _currentListeningStateCallback?.call(false);
          } else if (val == 'listening') {
            _currentListeningStateCallback?.call(true);
          }
        },
      );
    } catch (e) {
      _isInitialized = false;
      print('STT Init Exception: $e');
    }

    return _isInitialized;
  }

  bool get isListening => _speechToText.isListening;

  Future<void> startListening({
    required Function(String, bool) onResult,
    required Function(bool) onListeningStateChanged,
  }) async {
    _currentListeningStateCallback = onListeningStateChanged;

    // Do not start listening if TTS engine is currently speaking or in decay period
    if (TtsService().isSpeaking) {
      print('[STT] TTS is currently speaking. Deferring microphone listening.');
      onListeningStateChanged(false);
      return;
    }

    final hasPermissions = await initializeStt();
    if (!hasPermissions) {
      onListeningStateChanged(false);
      return;
    }

    // Determine correct locale dynamically
    final settings = SettingsService();
    String localeId = 'en_US';
    final lang = settings.selectedLanguage.toLowerCase();
    if (lang.contains('tagalog') || lang.contains('filipino')) {
      localeId = 'fil_PH';
    }

    onListeningStateChanged(true);
    await _speechToText.listen(
      localeId: localeId,
      listenMode: ListenMode.dictation,
      pauseFor: const Duration(seconds: 10),
      listenFor: const Duration(seconds: 60),
      listenOptions: SpeechListenOptions(cancelOnError: false, partialResults: true),
      onResult: (result) {
        // Double check TTS status and self-echo filter before processing result
        if (TtsService().isSpeaking || TtsService().isSelfEcho(result.recognizedWords)) {
          print('[STT] Ignored self-voice echo input: "${result.recognizedWords}"');
          return;
        }

        if (result.recognizedWords.trim().isNotEmpty) {
          onResult(result.recognizedWords, result.finalResult);
        }
      },
    );
  }

  Future<void> stopListening(Function(bool) onListeningStateChanged) async {
    _currentListeningStateCallback = null;
    await _speechToText.stop();
    onListeningStateChanged(false);
  }
}
