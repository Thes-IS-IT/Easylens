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

  /// Normalizes a phone number to standard 11-digit Philippine mobile format (e.g. 09171234567).
  static String normalizePhoneNumber(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('639') && digits.length == 12) {
      return '0${digits.substring(2)}';
    }
    if (digits.startsWith('9') && digits.length == 10) {
      return '0$digits';
    }
    if (digits.startsWith('09') && digits.length == 11) {
      return digits;
    }
    return phone.trim();
  }

  /// Validates whether the given input is a valid 11-digit Philippine mobile number.
  static bool isValidPHPhoneNumber(String phone) {
    final cleaned = phone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final norm = normalizePhoneNumber(cleaned);
    return RegExp(r'^09\d{9}$').hasMatch(norm);
  }

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

  /// Replaces local contact list cleanly (e.g. after Cloud Firestore fetch), enforcing deduplication & max 3 contacts limit.
  Future<void> setContacts(List<SharedEmergencyContact> list) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getUserPrefsKey();

    final Map<String, SharedEmergencyContact> unique = {};
    for (var c in list) {
      final norm = normalizePhoneNumber(c.phone);
      if (norm.isNotEmpty && unique.length < 3) {
        unique[norm] = SharedEmergencyContact(
          name: c.name.trim(),
          phone: norm,
          relationship: c.relationship.trim(),
          isActive: c.isActive,
        );
      }
    }

    final contacts = unique.values.toList();
    await prefs.setStringList(
      key,
      contacts.map((c) => jsonEncode(c.toJson())).toList(),
    );
    notifyListeners();
  }

  /// Save or update an emergency contact profile. Returns true if saved, false if limit exceeded.
  Future<bool> saveContact(SharedEmergencyContact contact) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getUserPrefsKey();
    final contacts = await getContacts();

    final normalizedPhone = normalizePhoneNumber(contact.phone);
    final normalizedContact = SharedEmergencyContact(
      name: contact.name.trim(),
      phone: normalizedPhone,
      relationship: contact.relationship.trim(),
      isActive: contact.isActive,
    );

    final existingIndex = contacts.indexWhere(
      (c) => normalizePhoneNumber(c.phone) == normalizedPhone,
    );

    if (existingIndex == -1 && contacts.length >= 3) {
      // Cannot add more than 3 emergency contacts
      return false;
    }

    if (existingIndex != -1) {
      contacts[existingIndex] = normalizedContact;
    } else {
      contacts.add(normalizedContact);
    }

    await prefs.setStringList(
      key,
      contacts.map((c) => jsonEncode(c.toJson())).toList(),
    );
    notifyListeners();
    return true;
  }

  /// Update an existing emergency contact profile, locating them by their original phone number.
  Future<void> updateContact(String originalPhone, SharedEmergencyContact newContact) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getUserPrefsKey();
    final contacts = await getContacts();

    final normOriginal = normalizePhoneNumber(originalPhone);
    final normNew = normalizePhoneNumber(newContact.phone);

    final normalizedContact = SharedEmergencyContact(
      name: newContact.name.trim(),
      phone: normNew,
      relationship: newContact.relationship.trim(),
      isActive: newContact.isActive,
    );

    contacts.removeWhere((c) => normalizePhoneNumber(c.phone) == normOriginal);
    contacts.removeWhere((c) => normalizePhoneNumber(c.phone) == normNew);

    if (contacts.length < 3) {
      contacts.add(normalizedContact);
    }

    await prefs.setStringList(
      key,
      contacts.map((c) => jsonEncode(c.toJson())).toList(),
    );
    notifyListeners();
  }

  /// Delete a single emergency contact by phone number (removes locally and from Firestore).
  Future<void> deleteContact(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getUserPrefsKey();
    final contacts = await getContacts();
    final targetNorm = normalizePhoneNumber(phone);

    contacts.removeWhere((c) => normalizePhoneNumber(c.phone) == targetNorm);
    await prefs.setStringList(
      key,
      contacts.map((c) => jsonEncode(c.toJson())).toList(),
    );

    final user = FirebaseService().currentUser;
    if (user != null) {
      await FirebaseService().deleteContactFromCloud(user.uid, phone);
    }

    notifyListeners();
  }
}
