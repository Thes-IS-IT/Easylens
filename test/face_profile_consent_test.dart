import 'package:flutter_test/flutter_test.dart';
import 'package:easylens/services/face_registration_service.dart';

void main() {
  group('FaceProfile consent', () {
    test('consent fields survive a JSON round trip', () {
      final consentAt = DateTime(2026, 9, 27, 10, 30);
      final profile = FaceProfile(
        id: 'face_1',
        name: 'Mom',
        faceFeatures: [0.1, 0.2],
        registeredAt: DateTime(2026, 9, 27, 10, 31),
        isGdprConsented: true,
        consentDate: consentAt,
      );

      final restored = FaceProfile.fromJson(profile.toJson());

      expect(restored.isGdprConsented, isTrue);
      expect(restored.consentDate, consentAt);
    });

    test('profiles saved before consent existed load as pending', () {
      final legacyJson = {
        'id': 'face_legacy',
        'name': 'John',
        'imageLocalPath': null,
        'faceFeatures': [0.1, 0.2],
        'multiSampleFeatures': null,
        'registeredAt': '2026-01-01T00:00:00.000',
        'userId': 'guest',
      };

      final restored = FaceProfile.fromJson(legacyJson);

      expect(restored.isGdprConsented, isFalse);
      expect(restored.consentDate, isNull);
    });

    test('a profile built without consent is not marked consented', () {
      final profile = FaceProfile(
        id: 'face_2',
        name: 'Ana',
        registeredAt: DateTime(2026, 9, 27),
      );

      expect(profile.isGdprConsented, isFalse);
    });
  });
}
