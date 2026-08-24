import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easylens/services/settings_service.dart';
import 'package:easylens/models/user_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Haptic Settings Independence Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('SettingsService initializes buttonHaptics and navigationHaptics to true by default', () async {
      final settings = SettingsService();
      await settings.resetToDefaults();

      expect(settings.buttonHaptics, isTrue);
      expect(settings.navigationHaptics, isTrue);
      expect(settings.hapticFeedback, isTrue);
    });

    test('Disabling buttonHaptics leaves navigationHaptics enabled (true)', () async {
      final settings = SettingsService();
      await settings.resetToDefaults();

      await settings.updateButtonHaptics(false);

      expect(settings.buttonHaptics, isFalse, reason: 'Button haptics should be disabled');
      expect(settings.hapticFeedback, isFalse, reason: 'Legacy hapticFeedback alias should be disabled');
      expect(settings.navigationHaptics, isTrue, reason: 'EasyLens Navigation haptics must remain enabled for accessibility');
    });

    test('Disabling navigationHaptics leaves buttonHaptics enabled (true)', () async {
      final settings = SettingsService();
      await settings.resetToDefaults();

      await settings.updateNavigationHaptics(false);

      expect(settings.navigationHaptics, isFalse, reason: 'Navigation haptics should be disabled');
      expect(settings.buttonHaptics, isTrue, reason: 'Button haptics must remain enabled');
      expect(settings.hapticFeedback, isTrue, reason: 'Legacy alias must remain enabled');
    });

    test('updateSettings updates buttonHaptics and navigationHaptics independently', () async {
      final settings = SettingsService();
      await settings.resetToDefaults();

      await settings.updateSettings(
        buttonHaptics: false,
        navigationHaptics: true,
      );

      expect(settings.buttonHaptics, isFalse);
      expect(settings.navigationHaptics, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('buttonHaptics'), isFalse);
      expect(prefs.getBool('navigationHaptics'), isTrue);

      // Now reload from local storage
      await settings.loadSettingsFromLocal();
      expect(settings.buttonHaptics, isFalse);
      expect(settings.navigationHaptics, isTrue);
    });

    test('UserPreferences serializes and deserializes buttonHaptics and navigationHaptics independently', () {
      final prefs = UserPreferences(
        buttonHaptics: false,
        navigationHaptics: true,
      );

      final json = prefs.toJson();
      expect(json['buttonHaptics'], isFalse);
      expect(json['navigationHaptics'], isTrue);

      final fromJson = UserPreferences.fromJson(json);
      expect(fromJson.buttonHaptics, isFalse);
      expect(fromJson.navigationHaptics, isTrue);
    });

    test('UserPreferences backwards compatibility with legacy json', () {
      final legacyJson = {
        'hapticFeedback': false,
        'voiceFeedback': true,
      };

      final fromLegacy = UserPreferences.fromJson(legacyJson);
      expect(fromLegacy.buttonHaptics, isFalse, reason: 'buttonHaptics should read from legacy hapticFeedback');
      expect(fromLegacy.navigationHaptics, isTrue, reason: 'navigationHaptics should default to true for safety');
    });
  });
}
