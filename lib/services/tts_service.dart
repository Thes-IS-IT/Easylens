import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  final FlutterTts _flutterTts = FlutterTts();
  final SettingsService _settingsService = SettingsService();
  final AudioPlayer _mimoPlayer = AudioPlayer();
  List<Map<String, String>> _deviceVoices = [];
  bool _voicesLoaded = false;

  /// Notifier for real-time TTS speaking state. True while TTS is actively speaking
  /// or within post-speech acoustic decay window.
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);

  /// Helper getter for current TTS speaking state.
  bool get isSpeaking => isSpeakingNotifier.value;

  /// Cache of recently spoken text for self-echo deduplication.
  final List<String> _recentlySpokenPhrases = [];
  List<String> get recentlySpokenPhrases => List.unmodifiable(_recentlySpokenPhrases);

  String _lastSpokenText = "";
  String get lastSpokenText => _lastSpokenText;

  Timer? _decayTimer;

  factory TtsService() => _instance;

  TtsService._internal() {
    _initializeTts();
  }

  bool _isLoadingVoices = false;

  void _onSpeechStarted(String text) {
    _decayTimer?.cancel();
    final clean = text.toLowerCase().trim();
    if (clean.isNotEmpty) {
      _lastSpokenText = text;
      if (!_recentlySpokenPhrases.contains(clean)) {
        _recentlySpokenPhrases.add(clean);
        if (_recentlySpokenPhrases.length > 25) {
          _recentlySpokenPhrases.removeAt(0);
        }
        // Auto-expire phrase after 12 seconds
        Timer(const Duration(seconds: 12), () {
          _recentlySpokenPhrases.remove(clean);
        });
      }
    }
    if (!isSpeakingNotifier.value) {
      isSpeakingNotifier.value = true;
      print('[TTS] Speech started: "$text". STT muted.');
    }
  }

  void _onSpeechFinished() {
    _decayTimer?.cancel();
    // 500ms post-speech decay timer for acoustic echo clearance before unmuting STT mic
    _decayTimer = Timer(const Duration(milliseconds: 500), () {
      if (isSpeakingNotifier.value) {
        isSpeakingNotifier.value = false;
        print('[TTS] Speech completed & acoustic decay period passed. STT unmuted.');
      }
    });
  }

  /// Checks if [recognizedInput] matches or overlaps with recent TTS speech,
  /// preventing self-voice loop commands.
  bool isSelfEcho(String recognizedInput) {
    final candidate = recognizedInput.toLowerCase().trim();
    if (candidate.isEmpty) return true;

    // Check last spoken text
    final lastClean = _lastSpokenText.toLowerCase().trim();
    if (lastClean.isNotEmpty) {
      if (candidate == lastClean || candidate.contains(lastClean) || lastClean.contains(candidate)) {
        return true;
      }
    }

    // Check against history of recently spoken phrases
    for (final phrase in _recentlySpokenPhrases) {
      if (phrase.isEmpty) continue;
      if (candidate == phrase || candidate.contains(phrase) || phrase.contains(candidate)) {
        return true;
      }

      // Word overlap heuristic for longer phrases (>= 2 words)
      final candidateWords = candidate.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
      final phraseWords = phrase.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();

      if (candidateWords.length >= 2 && phraseWords.length >= 2) {
        final common = candidateWords.intersection(phraseWords);
        if (common.length / candidateWords.length > 0.5) {
          return true;
        }
      }
    }

    return false;
  }

  void _initializeTts() async {
    await _flutterTts.setSharedInstance(true);
    if (Platform.isIOS) {
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }

    _flutterTts.setStartHandler(() {
      _onSpeechStarted(_lastSpokenText);
      if (!_voicesLoaded && !_isLoadingVoices && Platform.isAndroid) {
        _loadDeviceVoices();
      }
    });

    _flutterTts.setCompletionHandler(() {
      _onSpeechFinished();
      if (!_voicesLoaded && !_isLoadingVoices && Platform.isAndroid) {
        _loadDeviceVoices();
      }
    });

    _flutterTts.setCancelHandler(() {
      _onSpeechFinished();
    });

    _flutterTts.setErrorHandler((_) {
      _onSpeechFinished();
      if (!_voicesLoaded && !_isLoadingVoices && Platform.isAndroid) {
        _loadDeviceVoices();
      }
    });

    _mimoPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        _onSpeechStarted(_lastSpokenText);
      } else if (state == PlayerState.completed || state == PlayerState.stopped) {
        _onSpeechFinished();
      }
    });

    if (Platform.isIOS || Platform.isMacOS) {
      Future.delayed(const Duration(seconds: 3), () {
        _loadDeviceVoices();
      });
    }
  }

  /// Loads and caches all voices available on the device.
  Future<void> _loadDeviceVoices() async {
    if (_voicesLoaded || _isLoadingVoices) return;
    _isLoadingVoices = true;
    try {
      final voices = await _flutterTts.getVoices;
      if (voices != null && voices is List && voices.isNotEmpty) {
        _deviceVoices = List<Map<String, String>>.from(
          (voices).map((v) {
            if (v is Map) {
              return Map<String, String>.from(
                  v.map((k, val) => MapEntry(k.toString(), val.toString())));
            }
            return <String, String>{};
          }).where((m) => m.isNotEmpty),
        );
        _voicesLoaded = true;
        print('[TTS] Loaded ${_deviceVoices.length} device voices.');
      }
    } catch (e) {
      print('[TTS] Warning: Failed to fetch platform voices: $e');
    } finally {
      _isLoadingVoices = false;
    }
  }

  Future<void> speak(String text) async {
    // Always reload saved preferences
    await _settingsService.loadSettingsFromLocal();
    if (!_settingsService.voiceFeedback) return;

    _onSpeechStarted(text);

    try {
      await _flutterTts.stop();
    } catch (_) {}
    try {
      await _mimoPlayer.stop();
    } catch (_) {}

    // Route Buddy (Child) / Leo (Child) to Xiaomi MiMo TTS custom voice (Chloe)
    if (_settingsService.selectedVoicePersona == 'Buddy (Child)' ||
        _settingsService.selectedVoicePersona == 'Leo (Child)') {
      unawaited(_speakMiMo(text, awaitCompletion: false));
      return;
    }

    // Lazily load voices if not yet cached
    if (!_voicesLoaded && (Platform.isIOS || Platform.isMacOS)) {
      await _loadDeviceVoices();
    }

    await _applyLanguage();
    await _applyVoicePersona();
    await _flutterTts.speak(text);
  }

  Future<void> speakAwait(String text) async {
    await _settingsService.loadSettingsFromLocal();
    if (!_settingsService.voiceFeedback) return;

    _onSpeechStarted(text);

    try {
      await _flutterTts.stop();
    } catch (_) {}
    try {
      await _mimoPlayer.stop();
    } catch (_) {}

    // Route Buddy (Child) / Leo (Child) to Xiaomi MiMo TTS custom voice (Chloe)
    if (_settingsService.selectedVoicePersona == 'Buddy (Child)' ||
        _settingsService.selectedVoicePersona == 'Leo (Child)') {
      await _speakMiMo(text, awaitCompletion: true);
      return;
    }

    if (!_voicesLoaded && (Platform.isIOS || Platform.isMacOS)) {
      await _loadDeviceVoices();
    }

    await _applyLanguage();
    await _applyVoicePersona();

    final completer = Completer<void>();
    _flutterTts.setCompletionHandler(() {
      _onSpeechFinished();
      if (!completer.isCompleted) completer.complete();
    });
    _flutterTts.setCancelHandler(() {
      _onSpeechFinished();
      if (!completer.isCompleted) completer.complete();
    });
    _flutterTts.setErrorHandler((_) {
      _onSpeechFinished();
      if (!completer.isCompleted) completer.complete();
    });

    await _flutterTts.speak(text);
    await completer.future.timeout(
      Duration(milliseconds: (text.length * 80) + 2000),
      onTimeout: () {
        print("[TTS] speakAwait timed out.");
        _onSpeechFinished();
      },
    );
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    try {
      await _mimoPlayer.stop();
    } catch (_) {}
    _onSpeechFinished();
  }

  /// Returns the TTS language/locale code.
  /// NOTE: Tagalog/Filipino UI language intentionally maps to 'en-US' so that
  /// voice personas (Aria, Max, Nova, etc.) always resolve to clear English
  /// voices. The UI language is independent from the TTS voice locale.
  String _getLangCode() {
    final selected = _settingsService.selectedLanguage.toLowerCase();
    if (selected.contains('tagalog') || selected.contains('filipino')) {
      return 'fil-PH';
    }
    switch (_settingsService.selectedLanguage) {
      case 'English (US)':
        return 'en-US';
      case 'English (UK)':
        return 'en-GB';
      case 'Spanish':
        return 'es-ES';
      case 'French':
        return 'fr-FR';
      case 'German':
        return 'de-DE';
      case 'Japanese':
        return 'ja-JP';
      case 'Mandarin':
        return 'zh-CN';
      default:
        return 'en-US';
    }
  }

  Future<void> _applyLanguage() async {
    final langCode = _getLangCode();
    try {
      await _flutterTts.setLanguage(langCode);
    } catch (e) {
      await _flutterTts.setLanguage('en-US');
    }
  }

  /// Picks a distinct device voice matching [persona] and [gender] for the current language.
  Future<void> _setDeviceVoiceByPersona(String persona, String gender) async {
    if (_deviceVoices.isEmpty) {
      await _loadDeviceVoices();
    }
    if (_deviceVoices.isEmpty) return;

    final langCode = _getLangCode().toLowerCase();
    var langBase = langCode.replaceAll('-', '_'); // e.g. "en_us"

    // Filter available device voices by locale
    var localeVoices = _deviceVoices.where((v) {
      final locale = (v['locale'] ?? v['language'] ?? '').toLowerCase();
      if (langCode == 'fil-ph' || langCode == 'tl-ph') {
        return locale.contains('fil') || locale.contains('tl') || locale.contains('ph');
      }
      return locale == langBase ||
          locale == langCode ||
          locale.startsWith(langBase.substring(0, 2));
    }).toList();

    if (localeVoices.isEmpty) {
      langBase = 'en_us';
      localeVoices = _deviceVoices.where((v) {
        final locale = (v['locale'] ?? v['language'] ?? '').toLowerCase();
        return locale == 'en_us' || locale == 'en-us' || locale.startsWith('en');
      }).toList();
    }

    if (localeVoices.isEmpty) return;

    Map<String, String>? selectedVoice;

    // Define persona-specific priority key search lists
    List<String> priorityKeys = [];
    switch (persona) {
      case 'Aria (Calm)':
        priorityKeys = ['samantha', 'aria', 'en-us-x-sfg', 'wavenet-a', 'female'];
        break;
      case 'Max (Bold)':
        priorityKeys = ['daniel', 'max', 'en-us-x-iom', 'wavenet-d', 'male'];
        break;
      case 'Nova (Bright)':
        priorityKeys = ['karen', 'nova', 'en-us-x-iob', 'wavenet-c', 'female'];
        break;
      case 'Echo (Deep)':
        priorityKeys = ['arthur', 'echo', 'gordon', 'en-us-x-rgd', 'wavenet-b', 'male'];
        break;
      case 'Bella (Gentle)':
        priorityKeys = ['moira', 'bella', 'tessa', 'en-us-x-tpc', 'wavenet-e', 'female'];
        break;
      case 'Maya (Filipino)':
        priorityKeys = ['maya', 'fil', 'tl', 'ph', 'female'];
        break;
      case 'Buddy (Child)':
      case 'Leo (Child)':
        priorityKeys = ['joelle', 'noelle', 'child', 'kid', 'young', 'boy'];
        break;
    }

    // Attempt matching priority voice keys
    for (final key in priorityKeys) {
      for (final v in localeVoices) {
        final name = (v['name'] ?? '').toLowerCase();
        if (name.contains(key)) {
          selectedVoice = v;
          break;
        }
      }
      if (selectedVoice != null) break;
    }

    // Fallback: If priority match failed, pick by index offset based on gender
    if (selectedVoice == null) {
      final genderVoices = localeVoices.where((v) {
        final name = (v['name'] ?? '').toLowerCase();
        if (gender == 'male') {
          return !name.contains('female');
        } else if (gender == 'female') {
          return name.contains('female') || !name.contains('male');
        }
        return true;
      }).toList();

      if (genderVoices.isNotEmpty) {
        int index = 0;
        if (persona == 'Nova (Bright)' || persona == 'Echo (Deep)') index = 1;
        if (persona == 'Bella (Gentle)') index = 2;
        selectedVoice = genderVoices[index % genderVoices.length];
      } else {
        selectedVoice = localeVoices.first;
      }
    }

    print('[TTS] Applying voice persona "$persona": ${selectedVoice['name']}');
    try {
      await _flutterTts.setVoice(selectedVoice);
    } catch (e) {
      print('[TTS] Failed to apply voice: $e');
    }
  }

  Future<void> _applyVoicePersona() async {
    double pitch = 1.0;
    double rate = 0.5;
    final isAndroid = Platform.isAndroid;
    final persona = _settingsService.selectedVoicePersona;

    switch (persona) {
      case 'Aria (Calm)':
        pitch = 1.0;
        rate = 0.45;
        await _setDeviceVoiceByPersona(persona, 'female');
        break;
      case 'Max (Bold)':
        pitch = isAndroid ? 0.55 : 0.85;
        rate = 0.55;
        await _setDeviceVoiceByPersona(persona, 'male');
        break;
      case 'Nova (Bright)':
        pitch = 1.25;
        rate = 0.52;
        await _setDeviceVoiceByPersona(persona, 'female');
        break;
      case 'Echo (Deep)':
        pitch = isAndroid ? 0.50 : 0.65;
        rate = 0.45;
        await _setDeviceVoiceByPersona(persona, 'male');
        break;
      case 'Bella (Gentle)':
        pitch = 1.15;
        rate = 0.40;
        await _setDeviceVoiceByPersona(persona, 'female');
        break;
      case 'Maya (Filipino)':
        pitch = 1.05;
        rate = 0.48;
        await _setDeviceVoiceByPersona(persona, 'female');
        break;
      case 'Buddy (Child)':
      case 'Leo (Child)':
        pitch = 1.65;
        rate = 0.55;
        await _setDeviceVoiceByPersona(persona, 'child');
        break;
      default:
        pitch = 1.0;
        rate = 0.5;
    }

    final double pitchMultiplier = 0.5 + _settingsService.speechPitch;
    final double rateMultiplier = 0.5 + _settingsService.speechRate;

    double finalPitch = (isAndroid && (persona == 'Max (Bold)' || persona == 'Echo (Deep)'))
        ? pitch
        : pitch * pitchMultiplier;

    if (isAndroid) {
      if (finalPitch < 0.5) finalPitch = 0.5;
      if (finalPitch > 2.0) finalPitch = 2.0;
    }

    await _flutterTts.setPitch(finalPitch);
    await _flutterTts.setSpeechRate(rate * rateMultiplier);
  }

  /// Private helper that invokes Xiaomi MiMo TTS (voice: Chloe) for Buddy (Child) personality.
  /// Falls back to default device voice on network failure or key absence.
  Future<void> _speakMiMo(String text, {bool awaitCompletion = false}) async {
    final apiKey = dotenv.env['MIMO_API_KEY']?.trim() ?? dotenv.env['ELEVEN_LABS']?.trim() ?? '';
    if (apiKey.isEmpty) {
      print('[Xiaomi MiMo TTS] API Key (MIMO_API_KEY) is missing. Falling back to device TTS.');
      await _fallbackToDeviceVoice(text, awaitCompletion);
      return;
    }

    try {
      final bodyPayload = jsonEncode({
        'model': 'mimo-v2.5-tts',
        'messages': [
          {'role': 'user', 'content': text},
          {'role': 'assistant', 'content': text}
        ],
        'audio': {
          'format': 'mp3',
          'voice': 'Chloe',
        }
      });

      final headers = {
        'Authorization': 'Bearer $apiKey',
        'api-key': apiKey,
        'Content-Type': 'application/json',
      };

      final response = await http.post(
        Uri.parse('https://api.xiaomimimo.com/v1/chat/completions'),
        headers: headers,
        body: bodyPayload,
      );

      if (response.statusCode == 200) {
        Uint8List? audioBytes;
        final contentType = response.headers['content-type'] ?? '';

        if (contentType.contains('audio') || contentType.contains('octet-stream')) {
          audioBytes = response.bodyBytes;
        } else {
          try {
            final jsonRes = jsonDecode(response.body);
            final messageAudio = jsonRes['choices']?[0]?['message']?['audio'];
            String? base64Str;
            if (messageAudio is Map) {
              base64Str = messageAudio['data']?.toString();
            } else if (messageAudio is String) {
              base64Str = messageAudio;
            }
            base64Str ??= jsonRes['choices']?[0]?['audio']?['data']?.toString();
            base64Str ??= jsonRes['audio']?['data']?.toString();

            if (base64Str != null && base64Str.isNotEmpty) {
              audioBytes = base64Decode(base64Str);
            }
          } catch (_) {}
        }

        if (audioBytes != null && audioBytes.isNotEmpty) {
          final directory = await getTemporaryDirectory();
          final file = File('${directory.path}/mimo_tts.mp3');
          await file.writeAsBytes(audioBytes);

          if (awaitCompletion) {
            final completer = Completer<void>();
            StreamSubscription? sub;
            sub = _mimoPlayer.onPlayerComplete.listen((_) {
              if (!completer.isCompleted) completer.complete();
              sub?.cancel();
            });

            await _mimoPlayer.play(DeviceFileSource(file.path), volume: 1.0);

            await completer.future.timeout(
              Duration(milliseconds: (text.length * 100) + 3000),
              onTimeout: () {
                print("[Xiaomi MiMo TTS] Playback timed out.");
                sub?.cancel();
              },
            );
          } else {
            await _mimoPlayer.play(DeviceFileSource(file.path), volume: 1.0);
          }
          return;
        }
      }

      print('[Xiaomi MiMo TTS] API Error: ${response.statusCode} - ${response.body}');
      await _fallbackToDeviceVoice(text, awaitCompletion);
    } catch (e) {
      print('[Xiaomi MiMo TTS] Exception occurred: $e');
      await _fallbackToDeviceVoice(text, awaitCompletion);
    }
  }

  /// Fallback method that handles speech using device-based TTS.
  Future<void> _fallbackToDeviceVoice(String text, bool awaitCompletion) async {
    await _applyLanguage();
    await _applyVoicePersona();
    if (awaitCompletion) {
      final completer = Completer<void>();
      _flutterTts.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete();
      });
      _flutterTts.setCancelHandler(() {
        if (!completer.isCompleted) completer.complete();
      });
      _flutterTts.setErrorHandler((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _flutterTts.speak(text);
      await completer.future.timeout(
        Duration(milliseconds: (text.length * 80) + 2000),
        onTimeout: () {},
      );
    } else {
      await _flutterTts.speak(text);
    }
  }
}
