import 'package:flutter/services.dart';

/// SoundService provides instant, zero-latency "blop / pop" button click sounds
/// and tactile haptic feedback across the EasyLens application.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  static bool isMuted = false;

  /// Play a crisp "blop / pop" click sound and subtle haptic feedback when pressing any button.
  static void playBlop() {
    if (isMuted) return;
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Play a slightly stronger "pop" for primary action buttons (e.g. Sign In, Continue, Start Navigation).
  static void playPop() {
    if (isMuted) return;
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Play tactile feedback for back buttons or tab switches.
  static void playTab() {
    if (isMuted) return;
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
    } catch (_) {}
  }
}
