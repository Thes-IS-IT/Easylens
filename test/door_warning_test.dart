import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easylens/services/danger_warning_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Door Warning & Tagalog Translation Tests', () {
    final warningService = DangerWarningService();

    test('Elevator, lift, entrance, and metal door labels should all evaluate as safe severity', () {
      expect(warningService.evaluateLabel('elevator door'), equals(HazardSeverity.safe));
      expect(warningService.evaluateLabel('doorway'), equals(HazardSeverity.safe));
      expect(warningService.evaluateLabel('entrance'), equals(HazardSeverity.safe));
      expect(warningService.evaluateLabel('gate'), equals(HazardSeverity.safe));
    });

    test('getHazardInfo for door labels should return generalized Door warning info in English and Tagalog', () {
      final info = warningService.getHazardInfo('elevator door');
      expect(info.label, equals('Door'));
      expect(info.severity, equals(HazardSeverity.safe));
      expect(info.title, equals('DOOR APPROACHING'));
      expect(info.messageEn, equals('You are approaching a door.'));
      expect(info.messageTl, equals('Papalapit ka sa isang pintuan.'));
    });

    test('getHazardInfo for plain door label should return generalized Door warning info', () {
      final info = warningService.getHazardInfo('door');
      expect(info.label, equals('Door'));
      expect(info.severity, equals(HazardSeverity.safe));
      expect(info.title, equals('DOOR APPROACHING'));
      expect(info.messageEn, equals('You are approaching a door.'));
      expect(info.messageTl, equals('Papalapit ka sa isang pintuan.'));
    });
  });
}
