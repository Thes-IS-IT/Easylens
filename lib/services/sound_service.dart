import 'package:flutter/services.dart';
import 'settings_service.dart';

/// SoundService provides instant, 100% native Flutter built-in button click sound effects
/// (SystemSoundType.click / SystemSoundType.alert) and tactile haptic feedback without external MP3 dependencies.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  /// Play Flutter's built-in native system button click sound (SystemSoundType.click).
  static void playClick() {
    final settings = SettingsService();
    if (!settings.soundEffects) return;

    try {
      // 1. Flutter built-in native system click audio
      SystemSound.play(SystemSoundType.click);

      // 2. Tactile haptic feedback
      if (settings.hapticFeedback) {
        HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  /// Play a crisp native button click sound.
  static void playBlop() => playClick();

  /// Play a primary action button pop sound with medium haptic impact.
  static void playPop() {
    final settings = SettingsService();
    if (!settings.soundEffects) return;

    try {
      SystemSound.play(SystemSoundType.click);
      if (settings.hapticFeedback) {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  /// Play tab or back button navigation sound with light haptic impact.
  static void playTab() {
    final settings = SettingsService();
    if (!settings.soundEffects) return;

    try {
      SystemSound.play(SystemSoundType.click);
      if (settings.hapticFeedback) {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Play native system alert sound for warnings or emergency actions.
  static void playAlert() {
    final settings = SettingsService();
    if (!settings.soundEffects) return;

    try {
      SystemSound.play(SystemSoundType.alert);
      if (settings.hapticFeedback) {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }
}
