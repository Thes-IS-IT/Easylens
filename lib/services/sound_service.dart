import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'settings_service.dart';

/// SoundService provides native Flutter button click sound effects, haptics, and dog bark audio.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  static AudioPlayer? _audioPlayer;
  static AudioPlayer? _transitionPlayer;

  /// Play the Buddy dog bark sound effect on app startup or interaction.
  static Future<void> playBark() async {
    try {
      _audioPlayer?.stop();
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.play(AssetSource('sounds/bark_dashboard.mp3'));
    } catch (e) {
      print('Bark sound error: $e');
    }
  }

  /// Play the Spongebob bubble transition sound effect synchronized with tab changes.
  static Future<void> playBubbleTransition() async {
    if (!SettingsService().bubbleTransitionSound) return;
    try {
      _transitionPlayer?.stop();
      _transitionPlayer = AudioPlayer();
      await _transitionPlayer!.play(AssetSource('sounds/spongebob-bubble-transition.mp3'));
    } catch (e) {
      print('Bubble transition sound error: $e');
    }
  }

  /// Play click action with tactile haptic feedback (audio SFX removed).
  static void playClick() {
    final settings = SettingsService();
    try {
      if (settings.hapticFeedback) {
        HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  /// Play a crisp action feedback.
  static void playBlop() => playClick();

  /// Play pop action feedback.
  static void playPop() {
    final settings = SettingsService();
    try {
      if (settings.hapticFeedback) {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  /// Play tab navigation action feedback.
  static void playTab() {
    final settings = SettingsService();
    try {
      if (settings.hapticFeedback) {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Play alert action feedback.
  static void playAlert() {
    final settings = SettingsService();
    try {
      if (settings.hapticFeedback) {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }
}
