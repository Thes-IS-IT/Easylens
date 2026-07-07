import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  static final SttService _instance = SttService._internal();
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  factory SttService() {
    return _instance;
  }

  SttService._internal();

  Future<bool> initializeStt() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (val) => print('STT Error: $val'),
        onStatus: (val) => print('STT Status: $val'),
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
    final hasPermissions = await initializeStt();
    if (!hasPermissions) {
      onListeningStateChanged(false);
      return;
    }

    onListeningStateChanged(true);
    await _speechToText.listen(
      pauseFor: const Duration(milliseconds: 2500),
      listenFor: const Duration(seconds: 30),
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
    );
  }

  Future<void> stopListening(Function(bool) onListeningStateChanged) async {
    await _speechToText.stop();
    onListeningStateChanged(false);
  }
}
