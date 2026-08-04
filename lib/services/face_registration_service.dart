import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// A single registered face profile persisted to SharedPreferences locally.
class FaceProfile {
  final String id;
  final String name;
  final String? imageLocalPath;
  final List<double>? faceFeatures;
  /// Multiple feature vectors from different angle captures (front, left, right).
  /// Each inner list is a full geometric feature vector.
  final List<List<double>>? multiSampleFeatures;
  final DateTime registeredAt;
  final String? userId;

  FaceProfile({
    required this.id,
    required this.name,
    this.imageLocalPath,
    this.faceFeatures,
    this.multiSampleFeatures,
    required this.registeredAt,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imageLocalPath': imageLocalPath,
        'faceFeatures': faceFeatures,
        'multiSampleFeatures': multiSampleFeatures,
        'registeredAt': registeredAt.toIso8601String(),
        'userId': userId,
      };

  factory FaceProfile.fromJson(Map<String, dynamic> json) => FaceProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        imageLocalPath: json['imageLocalPath'] as String?,
        faceFeatures: (json['faceFeatures'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
        multiSampleFeatures: (json['multiSampleFeatures'] as List<dynamic>?)
            ?.map((sample) => (sample as List<dynamic>)
                .map((e) => (e as num).toDouble())
                .toList())
            .toList(),
        registeredAt: DateTime.parse(json['registeredAt'] as String),
        userId: json['userId'] as String?,
      );

  /// Returns all available feature vectors for matching (multi-sample first, fallback to single).
  List<List<double>> get allFeatureVectors {
    final result = <List<double>>[];
    if (multiSampleFeatures != null && multiSampleFeatures!.isNotEmpty) {
      result.addAll(multiSampleFeatures!);
    }
    if (faceFeatures != null && faceFeatures!.isNotEmpty) {
      // Only add single-sample if not already covered by multi-sample
      if (result.isEmpty) {
        result.add(faceFeatures!);
      }
    }
    return result;
  }
}

class FaceRegistrationService extends ChangeNotifier {
  static const _legacyPrefsKey = 'registered_face_profiles';

  static final FaceRegistrationService _instance =
      FaceRegistrationService._internal();
  factory FaceRegistrationService() => _instance;
  FaceRegistrationService._internal();

  /// Gets the active user UID, or 'guest' if unauthenticated
  String get currentUserId {
    try {
      final user = FirebaseService().currentUser;
      if (user != null && user.uid.isNotEmpty) {
        return user.uid;
      }
    } catch (_) {}
    return 'guest';
  }

  /// Dynamic per-account key based on current logged-in user UID
  String get _accountPrefsKey {
    final uid = currentUserId;
    return 'registered_face_profiles_$uid';
  }

  /// Save a new [FaceProfile] to local storage for the active account.
  Future<void> saveProfile(FaceProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final activeUid = currentUserId;

    // Ensure the profile is explicitly tagged with the active account's UID
    final taggedProfile = FaceProfile(
      id: profile.id,
      name: profile.name,
      imageLocalPath: profile.imageLocalPath,
      faceFeatures: profile.faceFeatures,
      registeredAt: profile.registeredAt,
      userId: profile.userId ?? activeUid,
    );

    final profiles = await getAllProfiles();
    profiles.removeWhere((p) => p.id == taggedProfile.id);
    profiles.add(taggedProfile);

    await prefs.setStringList(
      _accountPrefsKey,
      profiles.map((p) => jsonEncode(p.toJson())).toList(),
    );
    notifyListeners();
  }

  /// Load all stored [FaceProfile] objects from local storage ONLY for the active account.
  Future<List<FaceProfile>> getAllProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final activeUid = currentUserId;
    final accountKey = _accountPrefsKey;
    final migrationFlagKey = 'legacy_faces_migrated_$activeUid';

    // 1. Read account-specific storage list
    List<String> rawList = prefs.getStringList(accountKey) ?? [];

    // 2. Perform legacy migration ONCE if active account has not been migrated yet
    final alreadyMigrated = prefs.getBool(migrationFlagKey) ?? false;
    if (!alreadyMigrated && rawList.isEmpty && prefs.containsKey(_legacyPrefsKey)) {
      final legacyRaw = prefs.getStringList(_legacyPrefsKey) ?? [];
      final migratedList = <String>[];
      for (final jsonStr in legacyRaw) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final prof = FaceProfile.fromJson(map);
          // Only adopt legacy profile if it matches current UID or has no UID set yet
          if (prof.userId == null || prof.userId == activeUid) {
            final adoptProf = FaceProfile(
              id: prof.id,
              name: prof.name,
              imageLocalPath: prof.imageLocalPath,
              faceFeatures: prof.faceFeatures,
              registeredAt: prof.registeredAt,
              userId: activeUid,
            );
            migratedList.add(jsonEncode(adoptProf.toJson()));
          }
        } catch (_) {}
      }
      await prefs.setBool(migrationFlagKey, true);
      await prefs.remove(_legacyPrefsKey);
      if (migratedList.isNotEmpty) {
        await prefs.setStringList(accountKey, migratedList);
        rawList = migratedList;
      }
    }

    // 3. Parse profiles and strictly filter by active user ID
    final List<FaceProfile> result = [];
    for (final s in rawList) {
      try {
        final profile = FaceProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
        // Enforce strict local filtering: profile MUST belong to active user
        if (profile.userId == activeUid || profile.userId == null) {
          result.add(profile);
        }
      } catch (_) {}
    }

    return result;
  }

  /// Delete a single profile by [id] for the active account.
  Future<void> deleteProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final activeUid = currentUserId;

    // Prevent any legacy re-migration loop
    await prefs.setBool('legacy_faces_migrated_$activeUid', true);
    if (prefs.containsKey(_legacyPrefsKey)) {
      await prefs.remove(_legacyPrefsKey);
    }

    final profiles = await getAllProfiles();
    profiles.removeWhere((p) => p.id == id);
    await prefs.setStringList(
      _accountPrefsKey,
      profiles.map((p) => jsonEncode(p.toJson())).toList(),
    );
    notifyListeners();
  }

  /// Remove all registered face profiles for the active account.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final activeUid = currentUserId;

    await prefs.setBool('legacy_faces_migrated_$activeUid', true);
    if (prefs.containsKey(_legacyPrefsKey)) {
      await prefs.remove(_legacyPrefsKey);
    }
    await prefs.remove(_accountPrefsKey);
    notifyListeners();
  }
}
