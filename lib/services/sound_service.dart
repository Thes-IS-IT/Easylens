import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_sound_button/flutter_sound_button.dart';
import 'package:flutter_sound_button/default_sounds.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'settings_service.dart';

/// SoundService provides ultra-low-latency click sounds,
/// bubble screen transitions, dog barking audio, and super-high tactile hardware haptics.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  // Preloaded pool of 4 low-latency just_audio players for instant, zero-delay clicks
  static final List<ja.AudioPlayer> _clickPlayers = [
    ja.AudioPlayer(),
    ja.AudioPlayer(),
    ja.AudioPlayer(),
    ja.AudioPlayer(),
  ];
  static final AudioPlayer _fallbackClickPlayer = AudioPlayer();
  static int _clickIndex = 0;
  static bool _soundButtonLoaded = false;

  // Rooted AudioPlayer instances for bubble transitions and startup bark
  static final AudioPlayer _bubblePlayer = AudioPlayer();
  static final AudioPlayer _barkPlayer = AudioPlayer();

  /// Pre-load button click sound on app boot into memory
  static Future<void> init() async {
    if (_soundButtonLoaded) return;
    _soundButtonLoaded = true;
    try {
      await Future.wait(_clickPlayers.map((player) async {
        try {
          await player.setAsset('assets/sounds/button_click.mp3', preload: true);
          await player.setVolume(1.0);
        } catch (e) {
          print('[SoundService] Click player asset load note: $e');
        }
      }));
      print('[SoundService] 4-player click pool preloaded successfully');
    } catch (e) {
      print('[SoundService] Click pool init note: $e');
    }
  }

  /// Play click sound with super-high tactile haptic punch with ZERO delay.
  static void playClick({bool isHeavy = true}) {
    final settings = SettingsService();

    // 1. Synchronous SUPER-HIGH Hardware Haptic Punch (Physical Vibration at 255 Amplitude + Heavy Impact)
    if (settings.hapticFeedback) {
      try {
        Vibration.vibrate(duration: isHeavy ? 45 : 30, amplitude: 255);
      } catch (_) {}
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
    }

    // 2. Ultra-Fast Zero-Latency Click Sound
    if (settings.soundEffects) {
      // Direct synchronous Native OS Click (0ms execution time)
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}

      // Immediate just_audio playback with seamless audioplayers fallback
      try {
        if (!_soundButtonLoaded) {
          init();
        }
        final player = _clickPlayers[_clickIndex++ % _clickPlayers.length];
        player.seek(Duration.zero).then((_) {
          player.play().catchError((_) {
            _playFallbackClick();
          });
        }).catchError((_) {
          _playFallbackClick();
        });
      } catch (e) {
        _playFallbackClick();
      }
    }
  }

  static void _playFallbackClick() {
    try {
      _fallbackClickPlayer.stop();
      _fallbackClickPlayer.play(AssetSource('sounds/button_click.mp3'), volume: 1.0);
    } catch (_) {}
  }

  /// Play click action with super-high haptics & instant click sound.
  static void playThock({bool isHeavy = true}) => playClick(isHeavy: isHeavy);

  /// Play a crisp action feedback.
  static void playBlop() => playClick(isHeavy: true);

  /// Play pop action feedback.
  static void playPop() => playClick(isHeavy: true);

  /// Play tab navigation action feedback.
  static void playTab() => playClick(isHeavy: false);

  /// Play alert action feedback with intense haptics.
  static void playAlert() {
    final settings = SettingsService();
    if (settings.hapticFeedback) {
      try {
        Vibration.vibrate(duration: 100, amplitude: 255);
      } catch (_) {}
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
    }
    if (settings.soundEffects) {
      playClick(isHeavy: true);
    }
  }

  /// Play the Buddy dog bark sound effect (bark_dashboard.mp3) on app startup.
  static Future<void> playBark() async {
    try {
      await _barkPlayer.stop();
      await _barkPlayer.setReleaseMode(ReleaseMode.stop);
      await _barkPlayer.setVolume(1.0);
      await _barkPlayer.play(AssetSource('sounds/bark_dashboard.mp3'));
    } catch (e) {
      print('[SoundService] Bark error: $e');
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Play the bubble transition sound effect (spongebob_bubble_transition.mp3) synchronized with tab changes.
  static Future<void> playBubbleTransition() async {
    if (!SettingsService().bubbleTransitionSound) return;
    try {
      print('[SoundService] Playing bubble transition sound...');
      await _bubblePlayer.stop();
      await _bubblePlayer.setReleaseMode(ReleaseMode.stop);
      await _bubblePlayer.setVolume(1.0);
      await _bubblePlayer.play(AssetSource('sounds/spongebob_bubble_transition.mp3'));
    } catch (e) {
      print('[SoundService] Bubble transition error: $e');
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }
}
