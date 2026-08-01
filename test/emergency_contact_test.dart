import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easylens/services/emergency_contact_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EmergencyContactService Unit Tests', () {
    test('Phone normalization converts standard PH formats to 09XXXXXXXXX', () {
      expect(EmergencyContactService.normalizePhoneNumber('09171234567'), '09171234567');
      expect(EmergencyContactService.normalizePhoneNumber('+639171234567'), '09171234567');
      expect(EmergencyContactService.normalizePhoneNumber('639171234567'), '09171234567');
      expect(EmergencyContactService.normalizePhoneNumber('9171234567'), '09171234567');
      expect(EmergencyContactService.normalizePhoneNumber('0917-123-4567'), '09171234567');
      expect(EmergencyContactService.normalizePhoneNumber('+63 917 123 4567'), '09171234567');
    });

    test('isValidPHPhoneNumber correctly validates Philippine mobile numbers', () {
      expect(EmergencyContactService.isValidPHPhoneNumber('09171234567'), true);
      expect(EmergencyContactService.isValidPHPhoneNumber('+639171234567'), true);
      expect(EmergencyContactService.isValidPHPhoneNumber('639171234567'), true);
      expect(EmergencyContactService.isValidPHPhoneNumber('9171234567'), true);

      // Invalid cases
      expect(EmergencyContactService.isValidPHPhoneNumber('12345'), false);
      expect(EmergencyContactService.isValidPHPhoneNumber('08171234567'), false);
      expect(EmergencyContactService.isValidPHPhoneNumber('0917123456789'), false);
      expect(EmergencyContactService.isValidPHPhoneNumber('abc'), false);
    });

    test('Enforces maximum 3 contacts limit on saveContact', () async {
      final service = EmergencyContactService();

      final c1 = SharedEmergencyContact(name: 'One', phone: '09171111111', relationship: 'Family');
      final c2 = SharedEmergencyContact(name: 'Two', phone: '09172222222', relationship: 'Friend');
      final c3 = SharedEmergencyContact(name: 'Three', phone: '09173333333', relationship: 'Work');
      final c4 = SharedEmergencyContact(name: 'Four', phone: '09174444444', relationship: 'Other');

      expect(await service.saveContact(c1), true);
      expect(await service.saveContact(c2), true);
      expect(await service.saveContact(c3), true);

      // 4th contact addition should be rejected
      expect(await service.saveContact(c4), false);

      final list = await service.getContacts();
      expect(list.length, 3);
      expect(list.any((c) => c.phone == '09174444444'), false);
    });

    test('Deduplicates contacts with same phone number under different formats', () async {
      final service = EmergencyContactService();

      final c1 = SharedEmergencyContact(name: 'Initial Name', phone: '09171234567', relationship: 'Family');
      final c2 = SharedEmergencyContact(name: 'Updated Name', phone: '+639171234567', relationship: 'Sibling');

      await service.saveContact(c1);
      await service.saveContact(c2);

      final list = await service.getContacts();
      expect(list.length, 1);
      expect(list.first.name, 'Updated Name');
      expect(list.first.phone, '09171234567');
    });

    test('setContacts replaces local storage with deduplicated, max-3 list', () async {
      final service = EmergencyContactService();

      final cloudList = [
        SharedEmergencyContact(name: 'A', phone: '09171111111', relationship: 'Rel'),
        SharedEmergencyContact(name: 'A Duplicate', phone: '+639171111111', relationship: 'Rel'),
        SharedEmergencyContact(name: 'B', phone: '09172222222', relationship: 'Rel'),
        SharedEmergencyContact(name: 'C', phone: '09173333333', relationship: 'Rel'),
        SharedEmergencyContact(name: 'D Exceeded', phone: '09174444444', relationship: 'Rel'),
      ];

      await service.setContacts(cloudList);

      final list = await service.getContacts();
      expect(list.length, 3);
      expect(list[0].phone, '09171111111');
      expect(list[1].phone, '09172222222');
      expect(list[2].phone, '09173333333');
    });

    test('deleteContact removes target contact by normalized phone', () async {
      final service = EmergencyContactService();

      await service.saveContact(SharedEmergencyContact(name: 'Target', phone: '+639179999999', relationship: 'Test'));
      expect((await service.getContacts()).length, 1);

      await service.deleteContact('09179999999');
      expect((await service.getContacts()).length, 0);
    });
  });
}
