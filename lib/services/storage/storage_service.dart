import '../../models/user_preferences.dart';
import '../../models/emergency_contact.dart';

abstract class StorageService {
  Future<void> init();
  
  // User Preferences persistence
  Future<UserPreferences> getUserPreferences();
  Future<void> saveUserPreferences(UserPreferences prefs);
  
  // Emergency Contacts persistence
  Future<List<EmergencyContact>> getEmergencyContacts();
  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts);
  Future<void> addEmergencyContact(EmergencyContact contact);
  Future<void> deleteEmergencyContact(int index);
}

class InMemoryStorageService implements StorageService {
  UserPreferences _prefs = UserPreferences();
  final List<EmergencyContact> _contacts = [
    EmergencyContact(
      name: 'SOS Contact 1',
      phone: '+63 912 345 6789',
      relationship: 'Family',
      isActive: true,
    ),
  ];

  @override
  Future<void> init() async {
    // Simulated startup delay
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<UserPreferences> getUserPreferences() async {
    return _prefs;
  }

  @override
  Future<void> saveUserPreferences(UserPreferences prefs) async {
    _prefs = prefs;
  }

  @override
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    return List.unmodifiable(_contacts);
  }

  @override
  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) async {
    _contacts.clear();
    _contacts.addAll(contacts);
  }

  @override
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    _contacts.add(contact);
  }

  @override
  Future<void> deleteEmergencyContact(int index) async {
    if (index >= 0 && index < _contacts.length) {
      _contacts.removeAt(index);
    }
  }
}
