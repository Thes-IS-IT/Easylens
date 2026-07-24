import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedEmergencyContact {
  final String name;
  final String phone;
  final String relationship;
  final bool isActive;

  SharedEmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'isActive': isActive,
      };

  factory SharedEmergencyContact.fromJson(Map<String, dynamic> json) =>
      SharedEmergencyContact(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        relationship: json['relationship'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
      );
}

class EmergencyContactService extends ChangeNotifier {
  static const _prefsKey = 'easylens_emergency_contacts';

  static final EmergencyContactService _instance =
      EmergencyContactService._internal();
  factory EmergencyContactService() => _instance;
  EmergencyContactService._internal();

  /// Clear all stored emergency contacts (used on logout/reset)
  Future<void> clearContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    notifyListeners();
  }

  /// Retrieve all emergency contacts. If none are stored, seeds a default contact.
  Future<List<SharedEmergencyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    if (raw == null) {
      // Seed default contact on first run
      final defaultContact = SharedEmergencyContact(
        name: 'SOS Contact 1',
        phone: '+63 912 345 6789',
        relationship: 'Family',
        isActive: true,
      );
      await prefs.setStringList(
        _prefsKey,
        [jsonEncode(defaultContact.toJson())],
      );
      return [defaultContact];
    }
    return raw.map((s) {
      try {
        return SharedEmergencyContact.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<SharedEmergencyContact>().toList();
  }

  /// Save or update an emergency contact profile.
  Future<void> saveContact(SharedEmergencyContact contact) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    List<SharedEmergencyContact> contacts = [];
    if (raw != null) {
      contacts = raw.map((s) {
        try {
          return SharedEmergencyContact.fromJson(jsonDecode(s) as Map<String, dynamic>);
        } catch (_) {
          return null;
        }
      }).whereType<SharedEmergencyContact>().toList();
    }
    contacts.removeWhere((c) => c.phone == contact.phone);
    contacts.add(contact);
    await prefs.setStringList(
      _prefsKey,
      contacts.map((c) => jsonEncode(c.toJson())).toList(),
    );
    notifyListeners();
  }

  /// Update an existing emergency contact profile, locating them by their original phone number.
  Future<void> updateContact(String originalPhone, SharedEmergencyContact newContact) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = await getContacts();
    contacts.removeWhere((c) => c.phone == originalPhone);
    contacts.add(newContact);
    await prefs.setStringList(
      _prefsKey,
      contacts.map((c) => jsonEncode(c.toJson())).toList(),
    );
    notifyListeners();
  }

  /// Delete a single emergency contact by phone number.
  Future<void> deleteContact(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = await getContacts();
    contacts.removeWhere((c) => c.phone == phone);
    await prefs.setStringList(
      _prefsKey,
      contacts.map((c) => jsonEncode(c.toJson())).toList(),
    );
    notifyListeners();
  }
}
