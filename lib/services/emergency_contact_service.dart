import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

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
  static final EmergencyContactService _instance =
      EmergencyContactService._internal();
  factory EmergencyContactService() => _instance;
  EmergencyContactService._internal();

  /// Scopes prefs key per authenticated user UID to prevent cross-account contact leakage.
  String _getUserPrefsKey() {
    final uid = FirebaseService().currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      return 'easylens_emergency_contacts_$uid';
    }
    return 'easylens_emergency_contacts_guest';
  }

  /// Clear stored emergency contacts for the current user session (used on logout/reset).
  Future<void> clearContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getUserPrefsKey());
    notifyListeners();
  }

  /// Retrieve all emergency contacts for the active user. If none exist, returns empty list.
  /// NEVER seeds default fake phone numbers or fallbacks.
  Future<List<SharedEmergencyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_getUserPrefsKey());
    if (raw == null || raw.isEmpty) {
      return [];
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
    final key = _getUserPrefsKey();
    final raw = prefs.getStringList(key);
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
      key,
      contacts.map((c) => jsonEncode(c.toJson())).toList(),
    );
    notifyListeners();
  }

  /// Update an existing emergency contact profile, locating them by their original phone number.
  Future<void> updateContact(String originalPhone, SharedEmergencyContact newContact) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getUserPrefsKey();
    final contacts = await getContacts();
    contacts.removeWhere((c) => c.phone == originalPhone);
    contacts.add(newContact);
    await prefs.setStringList(
      key,
      contacts.map((c) => jsonEncode(c.toJson())).toList(),
    );
    notifyListeners();
  }

  /// Delete a single emergency contact by phone number.
  Future<void> deleteContact(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getUserPrefsKey();
    final contacts = await getContacts();
    contacts.removeWhere((c) => c.phone == phone);
    await prefs.setStringList(
      key,
      contacts.map((c) => jsonEncode(c.toJson())).toList(),
    );
    notifyListeners();
  }
}
