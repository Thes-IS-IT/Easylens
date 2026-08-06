import 'package:flutter/services.dart';
import 'settings_service.dart';

/// SoundService provides instant, 100% native Flutter built-in button click sound effects
/// (SystemSoundType.click / SystemSoundType.alert) and tactile haptic feedback without external MP3 dependencies.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

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
