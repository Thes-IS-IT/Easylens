import 'dart:io';
import 'dart:async';
import 'dart:convert';
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
  final AudioPlayer _elevenPlayer = AudioPlayer();
  List<Map<String, String>> _deviceVoices = [];
  bool _voicesLoaded = false;

  factory TtsService() => _instance;

  TtsService._internal() {
    _initializeTts();
  }

  bool _isLoadingVoices = false;

  void _initializeTts() async {
    await _flutterTts.setSharedInstance(true);
    if (Platform.isIOS) {
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }

    _flutterTts.setStartHandler(() {
      if (!_voicesLoaded && !_isLoadingVoices && Platform.isAndroid) {
        _loadDeviceVoices();
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (!_voicesLoaded && !_isLoadingVoices && Platform.isAndroid) {
        _loadDeviceVoices();
      }
    });

    _flutterTts.setErrorHandler((_) {
      if (!_voicesLoaded && !_isLoadingVoices && Platform.isAndroid) {
        _loadDeviceVoices();
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

    try {
      await _flutterTts.stop();
    } catch (_) {}
    try {
      await _elevenPlayer.stop();
    } catch (_) {}

    // Route Leo (Child) to ElevenLabs custom voice
    if (_settingsService.selectedVoicePersona == 'Leo (Child)') {
      unawaited(_speakElevenLabs(text, awaitCompletion: false));
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

    try {
      await _flutterTts.stop();
    } catch (_) {}
    try {
      await _elevenPlayer.stop();
    } catch (_) {}

    // Route Leo (Child) to ElevenLabs custom voice
    if (_settingsService.selectedVoicePersona == 'Leo (Child)') {
      await _speakElevenLabs(text, awaitCompletion: true);
      return;
    }

    if (!_voicesLoaded && (Platform.isIOS || Platform.isMacOS)) {
      await _loadDeviceVoices();
    }

    await _applyLanguage();
    await _applyVoicePersona();

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
      onTimeout: () {
        print("[TTS] speakAwait timed out.");
      },
    );
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    try {
      await _elevenPlayer.stop();
    } catch (_) {}
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

  /// Private helper that invokes ElevenLabs TTS for Leo (Child) personality.
  /// Falls back to default device voice on network failure or key absence.
  Future<void> _speakElevenLabs(String text, {bool awaitCompletion = false}) async {
    final apiKey = dotenv.env['ELEVEN_LABS']?.trim() ?? '';
    if (apiKey.isEmpty) {
      print('[ElevenLabs] API Key is missing. Falling back to device TTS.');
      await _fallbackToDeviceVoice(text, awaitCompletion);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/S7IsvAvEoDfui6GSZK3A'),
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
          'accept': 'audio/mpeg',
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.75,
          }
        }),
      );

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/elevenlabs_tts.mp3');
        await file.writeAsBytes(response.bodyBytes);

        if (awaitCompletion) {
          final completer = Completer<void>();
          StreamSubscription? sub;
          sub = _elevenPlayer.onPlayerComplete.listen((_) {
            if (!completer.isCompleted) completer.complete();
            sub?.cancel();
          });
          
          await _elevenPlayer.play(DeviceFileSource(file.path), volume: 1.0);
          
          await completer.future.timeout(
            Duration(milliseconds: (text.length * 100) + 3000),
            onTimeout: () {
              print("[ElevenLabs] Playback timed out.");
              sub?.cancel();
            },
          );
        } else {
          await _elevenPlayer.play(DeviceFileSource(file.path), volume: 1.0);
        }
      } else {
        print('[ElevenLabs] API Error: ${response.statusCode} - ${response.body}');
        await _fallbackToDeviceVoice(text, awaitCompletion);
      }
    } catch (e) {
      print('[ElevenLabs] Exception occurred: $e');
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
