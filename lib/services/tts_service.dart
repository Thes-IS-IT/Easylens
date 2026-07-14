import 'dart:io';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'settings_service.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  final FlutterTts _flutterTts = FlutterTts();
  final SettingsService _settingsService = SettingsService();
  List<Map<String, String>> _deviceVoices = [];
  bool _voicesLoaded = false;

  factory TtsService() => _instance;

  TtsService._internal() {
    _initializeTts();
  }

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
    await _loadDeviceVoices();
  }

  /// Loads and caches all voices available on the device.
  Future<void> _loadDeviceVoices() async {
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
    }
  }

  Future<void> speak(String text) async {
    // Always reload saved preferences
    await _settingsService.loadSettingsFromLocal();
    if (!_settingsService.voiceFeedback) return;

    // Lazily load voices if not yet cached
    if (!_voicesLoaded) {
      await _loadDeviceVoices();
    }

    await _applyLanguage();
    await _applyVoicePersona();
    await _flutterTts.speak(text);
  }

  Future<void> speakAwait(String text) async {
    await _settingsService.loadSettingsFromLocal();
    if (!_settingsService.voiceFeedback) return;

    if (!_voicesLoaded) {
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
  }

  /// Returns the TTS language/locale code.
  /// NOTE: Tagalog/Filipino UI language intentionally maps to 'en-US' so that
  /// voice personas (Aria, Max, Nova, etc.) always resolve to clear English
  /// voices. The UI language is independent from the TTS voice locale.
  String _getLangCode() {
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
      case 'Tagalog':
        return 'fil-PH';
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

  /// Picks a device voice matching [gender] for the current language.
  Future<void> _setDeviceVoiceByGender(String gender) async {
    if (_deviceVoices.isEmpty) return;

    final langCode = _getLangCode().toLowerCase();
    // e.g. "en-US" → match "en-us" or "en_us"
    final langBase = langCode.replaceAll('-', '_'); // "en_us"

    // Filter by language
    final localeVoices = _deviceVoices.where((v) {
      final locale = (v['locale'] ?? v['language'] ?? '').toLowerCase();
      if (langCode == 'fil-ph' || langCode == 'tl-ph') {
        return locale.contains('fil') || locale.contains('tl');
      }
      return locale == langBase ||
          locale == langCode ||
          locale.startsWith(langBase.substring(0, 2)); // language prefix only
    }).toList();

    if (localeVoices.isEmpty) {
      print('[TTS] No voices found for locale $langCode – keeping default');
      return;
    }

    // Debug: print all available voices for this locale
    print('[TTS] Voices for $langCode: ${localeVoices.map((v) => v['name']).toList()}');

    Map<String, String>? selectedVoice;

    if (gender == 'male') {
      // iOS voice names
      const maleNames = [
        'daniel', 'arthur', 'gordon', 'aaron', 'rishi', 'jorge',
        'thomas', 'david', 'james', 'robert', 'john', 'william',
        'richard', 'charles', 'steven', 'paul', 'mark',
      ];
      // Android Google TTS male variant codes (network & local)
      const androidMaleCodes = [
        '-x-iom', '-x-rgd', '-x-lts', '-x-gsk',
        'wavenet-d', 'wavenet-b', 'wavenet-j',
        '-d-', '-b-', '-j-',
      ];

      for (final v in localeVoices) {
        final name = (v['name'] ?? '').toLowerCase();
        if (maleNames.any((k) => name.contains(k))) {
          selectedVoice = v;
          break;
        }
      }
      if (selectedVoice == null) {
        for (final v in localeVoices) {
          final name = (v['name'] ?? '').toLowerCase();
          if (androidMaleCodes.any((k) => name.contains(k))) {
            selectedVoice = v;
            break;
          }
        }
      }
    } else {
      // Female
      const femaleNames = [
        'samantha', 'karen', 'moira', 'tessa', 'susan', 'aria',
        'bella', 'nova', 'daisy', 'lisa', 'mary', 'patricia',
        'jennifer', 'elizabeth', 'linda', 'barbara', 'margaret',
        'zira', 'hazel', 'heather',
      ];
      // Android Google TTS female variant codes
      const androidFemaleCodes = [
        '-x-iob', '-x-sfg', '-x-tpc', '-x-iol',
        'wavenet-a', 'wavenet-c', 'wavenet-e', 'wavenet-f',
        '-a-', '-c-', '-e-', '-f-',
      ];

      for (final v in localeVoices) {
        final name = (v['name'] ?? '').toLowerCase();
        if (femaleNames.any((k) => name.contains(k))) {
          selectedVoice = v;
          break;
        }
      }
      if (selectedVoice == null) {
        for (final v in localeVoices) {
          final name = (v['name'] ?? '').toLowerCase();
          if (androidFemaleCodes.any((k) => name.contains(k))) {
            selectedVoice = v;
            break;
          }
        }
      }
    }

    // Fallback: first locale match
    selectedVoice ??= localeVoices.first;

    print('[TTS] Applying voice: ${selectedVoice['name']} (gender=$gender)');
    try {
      await _flutterTts.setVoice(selectedVoice);
    } catch (e) {
      print('[TTS] Failed to apply voice: $e');
    }
  }

  Future<void> _applyVoicePersona() async {
    double pitch = 1.0;
    double rate = 0.5;

    switch (_settingsService.selectedVoicePersona) {
      case 'Aria (Calm)':
        pitch = 1.0;
        rate = 0.45;
        await _setDeviceVoiceByGender('female');
        break;
      case 'Max (Bold)':
        pitch = 0.85;
        rate = 0.55;
        await _setDeviceVoiceByGender('male');
        break;
      case 'Nova (Bright)':
        pitch = 1.25;
        rate = 0.52;
        await _setDeviceVoiceByGender('female');
        break;
      case 'Echo (Deep)':
        pitch = 0.65;
        rate = 0.45;
        await _setDeviceVoiceByGender('male');
        break;
      case 'Bella (Gentle)':
        pitch = 1.15;
        rate = 0.40;
        await _setDeviceVoiceByGender('female');
        break;
      case 'Maya (Filipino)':
        pitch = 1.05;
        rate = 0.48;
        await _setDeviceVoiceByGender('female');
        break;
      case 'Leo (Child)':
        pitch = 1.65; // High pitch to simulate a cute child voice
        rate = 0.55;  // Cheerful and fast pace
        await _setDeviceVoiceByGender('female');
        break;
      default:
        pitch = 1.0;
        rate = 0.5;
    }

    final double pitchMultiplier = 0.5 + _settingsService.speechPitch;
    final double rateMultiplier = 0.5 + _settingsService.speechRate;

    await _flutterTts.setPitch(pitch * pitchMultiplier);
    await _flutterTts.setSpeechRate(rate * rateMultiplier);
  }
}
