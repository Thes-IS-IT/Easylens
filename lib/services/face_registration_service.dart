import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// A single registered face profile persisted to SharedPreferences.
class FaceProfile {
  final String id;
  final String name;
  final String? imageLocalPath;
  final List<double>? faceFeatures;
  final DateTime registeredAt;

  FaceProfile({
    required this.id,
    required this.name,
    this.imageLocalPath,
    this.faceFeatures,
    required this.registeredAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imageLocalPath': imageLocalPath,
        'faceFeatures': faceFeatures,
        'registeredAt': registeredAt.toIso8601String(),
      };

  factory FaceProfile.fromJson(Map<String, dynamic> json) => FaceProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        imageLocalPath: json['imageLocalPath'] as String?,
        faceFeatures: (json['faceFeatures'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
        registeredAt: DateTime.parse(json['registeredAt'] as String),
      );
}

class FaceRegistrationService extends ChangeNotifier {
  static const _prefsKey = 'registered_face_profiles';

  static final FaceRegistrationService _instance =
      FaceRegistrationService._internal();
  factory FaceRegistrationService() => _instance;
  FaceRegistrationService._internal();

  /// Save a new [FaceProfile] to local storage.
  Future<void> saveProfile(FaceProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getAllProfiles();
    profiles.removeWhere((p) => p.id == profile.id);
    profiles.add(profile);
    await prefs.setStringList(
      _prefsKey,
      profiles.map((p) => jsonEncode(p.toJson())).toList(),
    );
    notifyListeners();
  }

  /// Load all stored [FaceProfile] objects from local storage.
  Future<List<FaceProfile>> getAllProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    return raw.map((s) {
      try {
        return FaceProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<FaceProfile>().toList();
  }

  /// Delete a single profile by [id].
  Future<void> deleteProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getAllProfiles();
    profiles.removeWhere((p) => p.id == id);
    await prefs.setStringList(
      _prefsKey,
      profiles.map((p) => jsonEncode(p.toJson())).toList(),
    );
    notifyListeners();
  }

  /// Remove all registered face profiles.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    notifyListeners();
  }
}
