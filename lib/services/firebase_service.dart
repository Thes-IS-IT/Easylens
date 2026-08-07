import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'storage/cloudflare_r2_service.dart';
import 'settings_service.dart';
import 'emergency_contact_service.dart';

class EasyLensUser {
  final String uid;
  final String email;
  final String displayName;
  final bool isForMyself;

  EasyLensUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.isForMyself,
  });
}

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  bool _firebaseInitialized = false;
  EasyLensUser? _mockUser;

  bool get isFirebaseAvailable => _firebaseInitialized;

  /// Saves session credentials locally so the user remains logged in across restarts if rememberMe is true.
  Future<void> saveUserSession(EasyLensUser user, {bool rememberMe = true}) async {
    _mockUser = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);
      await prefs.setBool('is_logged_in', rememberMe);
      await prefs.setBool('remember_me', rememberMe);
      if (user.displayName.isNotEmpty) {
        await SettingsService().updateDisplayName(user.displayName);
      }
      if (rememberMe) {
        await prefs.setString('user_uid', user.uid);
        await prefs.setString('user_email', user.email);
        await prefs.setString('user_display_name', user.displayName);
      } else {
        await prefs.remove('user_uid');
        await prefs.remove('user_email');
        await prefs.remove('user_display_name');
      }
      print('[FirebaseService] User session save (rememberMe: $rememberMe) for ${user.email}');
    } catch (e) {
      print("[FirebaseService] Failed to save user session: $e");
    }
  }

  Future<void> initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _firebaseInitialized = true;
        print("Firebase already initialized (apps not empty)");
        return;
      }

      // On iOS, native Objective-C SDK reads bundled GoogleService-Info.plist automatically.
      // Passing explicit FirebaseOptions on iOS causes FIRApp addAppToAppDictionary native SIGSEGV exceptions.
      if (!kIsWeb && Platform.isIOS) {
        await Firebase.initializeApp();
      } else {
        final apiKey = dotenv.env['FIREBASE_API_KEY'] ?? '';
        final appId = dotenv.env['FIREBASE_APP_ID'] ?? '';
        final projectId = dotenv.env['FIREBASE_PROJECT_ID'] ?? 'easylens-a6191';
        final messagingSenderId = dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
        final storageBucket = dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';

        if (apiKey.isNotEmpty && projectId.isNotEmpty) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: apiKey,
              appId: appId,
              projectId: projectId,
              messagingSenderId: messagingSenderId,
              storageBucket: storageBucket,
            ),
          );
        } else {
          await Firebase.initializeApp();
        }
      }
      _firebaseInitialized = true;
      print("Firebase successfully initialized");
    } catch (e) {
      if (Firebase.apps.isNotEmpty || e.toString().contains("duplicate-app") || e.toString().contains("already exists")) {
        _firebaseInitialized = true;
        print("Firebase already initialized (caught duplicate-app exception)");
      } else {
        try {
          await Firebase.initializeApp();
          _firebaseInitialized = true;
        } catch (_) {
          print("Firebase initialization notice: $e. Operating in safe local mode.");
          _firebaseInitialized = false;
        }
      }
    }

    // Restore persisted local user session only if stay logged in (remember_me) was enabled
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? prefs.getBool('is_logged_in') ?? false;

      if (!rememberMe) {
        if (_firebaseInitialized) {
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {}
        }
        _mockUser = null;
        await prefs.setBool('is_logged_in', false);
        print('[FirebaseService] Stay logged in is false. Cleared session for restart.');
      } else {
        final savedUid = prefs.getString('user_uid') ?? "persisted_user_uid";
        final savedEmail = prefs.getString('user_email') ?? "user@easylens.app";
        final savedName = prefs.getString('user_display_name') ?? "EasyLens Explorer";
        _mockUser = EasyLensUser(
          uid: savedUid,
          email: savedEmail,
          displayName: savedName,
          isForMyself: true,
        );
        print('[FirebaseService] Restored user session for $savedEmail');
      }
    } catch (_) {}
  }

  // Get current user (real or mock)
  EasyLensUser? get currentUser {
    if (_firebaseInitialized) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return EasyLensUser(
          uid: user.uid,
          email: user.email ?? "",
          displayName: user.displayName ?? "User",
          isForMyself: true, // Defaults to true
        );
      }
    }
    return _mockUser;
  }

  // Check if email already registered
  Future<bool> isEmailAlreadyRegistered(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_firebaseInitialized) return false;
    try {
      // 1. Check via Firebase Auth
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(cleanEmail);
      if (methods.isNotEmpty) return true;
    } catch (_) {}

    try {
      // 2. Check via Firestore users collection
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return true;
    } catch (_) {}

    return false;
  }

  // Sign up
  Future<EasyLensUser?> signUp(
    String email,
    String password,
    String name,
    bool isForMyself, {
    bool rememberMe = true,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    EasyLensUser? newUser;

    if (_firebaseInitialized) {
      try {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPassword,
        );
        if (credential.user != null) {
          try {
            await credential.user!.updateDisplayName(name);
          } catch (_) {}
          newUser = EasyLensUser(
            uid: credential.user!.uid,
            email: cleanEmail,
            displayName: name,
            isForMyself: isForMyself,
          );
        }
      } catch (e) {
        print("Firebase Sign Up Error: $e");
        rethrow;
      }
    } else {
      // Mock Sign Up
      await Future.delayed(const Duration(milliseconds: 800));
      newUser = EasyLensUser(
        uid: "mock_uid_${DateTime.now().millisecondsSinceEpoch}",
        email: email,
        displayName: name,
        isForMyself: isForMyself,
      );
    }

    if (newUser != null) {
      await saveUserSession(newUser, rememberMe: rememberMe);
    }
    return newUser;
  }

  // Sign in
  Future<EasyLensUser?> signIn(String email, String password, {bool rememberMe = true}) async {
    EasyLensUser? user;
    if (_firebaseInitialized) {
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (credential.user != null) {
          user = EasyLensUser(
            uid: credential.user!.uid,
            email: email,
            displayName: credential.user!.displayName ?? "User",
            isForMyself: true,
          );
        }
      } catch (e) {
        print("Firebase Sign In Error: $e");
        rethrow;
      }
    } else {
      // Mock Sign In
      await Future.delayed(const Duration(milliseconds: 800));
      if (email.contains("error")) {
        throw Exception("Mock Authentication Failure: Invalid email address.");
      }
      user = EasyLensUser(
        uid: "mock_uid_12345",
        email: email,
        displayName: "EasyLens Explorer",
        isForMyself: true,
      );
    }

    if (user != null) {
      await saveUserSession(user, rememberMe: rememberMe);
    }
    return user;
  }

  // Google Sign In
  Future<EasyLensUser?> signInWithGoogle({bool rememberMe = true}) async {
    if (!_firebaseInitialized) {
      throw Exception("Firebase is not initialized.");
    }

    GoogleSignInAccount? googleUser;
    dynamic nativeError;

    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? "1082778201757-v5b4s0ppmei019gm0tg5727k3706r3if.apps.googleusercontent.com";
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: webClientId,
      );
      googleUser = await googleSignIn.signIn();
    } catch (signInErr) {
      print("GoogleSignIn native picker error: $signInErr");
      nativeError = signInErr;
    }

    if (googleUser == null) {
      if (nativeError != null) {
        throw Exception("Google Sign-In unavailable on device: $nativeError. Please sign in with Email.");
      }
      return null; // User cancelled
    }

    final String userEmail = googleUser.email.trim();
    final String userDisplayName = googleUser.displayName?.trim().isNotEmpty == true
        ? googleUser.displayName!.trim()
        : userEmail.split('@')[0];

    EasyLensUser? gUser;

    // Attempt 1: Authenticate via Google Auth Credential with Firebase
    try {
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        gUser = EasyLensUser(
          uid: user.uid,
          email: user.email ?? userEmail,
          displayName: user.displayName ?? userDisplayName,
          isForMyself: true,
        );
      }
    } catch (firebaseCredentialErr) {
      print("Firebase Google Credential Error ($firebaseCredentialErr). Linking real Gmail ($userEmail)...");
      
      // Attempt 2: Register/Sign-in the user's REAL Gmail address with Firebase Auth
      final String customPass = "EasyLens_Google_${userEmail.hashCode}";
      try {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: userEmail,
          password: customPass,
        );
        if (cred.user != null) {
          await cred.user!.updateDisplayName(userDisplayName);
          gUser = EasyLensUser(
            uid: cred.user!.uid,
            email: userEmail,
            displayName: userDisplayName,
            isForMyself: true,
          );
        }
      } catch (signUpErr) {
        if (signUpErr.toString().contains("email-already-in-use")) {
          try {
            final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: userEmail,
              password: customPass,
            );
            if (cred.user != null) {
              gUser = EasyLensUser(
                uid: cred.user!.uid,
                email: userEmail,
                displayName: cred.user!.displayName ?? userDisplayName,
                isForMyself: true,
              );
            }
          } catch (_) {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null && currentUser.email == userEmail) {
              gUser = EasyLensUser(
                uid: currentUser.uid,
                email: userEmail,
                displayName: currentUser.displayName ?? userDisplayName,
                isForMyself: true,
              );
            } else {
              gUser = EasyLensUser(
                uid: "google_${userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}",
                email: userEmail,
                displayName: userDisplayName,
                isForMyself: true,
              );
            }
          }
        }
      }
    }

    if (gUser != null) {
      await saveUserSession(gUser, rememberMe: rememberMe);
    }

    return gUser;
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('user_uid');
      await prefs.remove('user_email');
      await prefs.remove('user_display_name');
      await prefs.remove('remember_me');
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
    } catch (_) {}

    try {
      await SettingsService().resetToDefaults();
      await EmergencyContactService().clearContacts();
    } catch (_) {}

    if (_firebaseInitialized) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    _mockUser = null;
  }

  /// Creates a temporary Firebase account for [email] with a random password,
  /// then sends Firebase's built-in email verification link.
  /// Returns true if the verification email was dispatched successfully.
  Future<bool> sendEmailVerificationLink(String email) async {
    if (_firebaseInitialized) {
      try {
        // Use a strong temp password — user will set their real one later
        final tempPassword = 'TempPwd!${DateTime.now().millisecondsSinceEpoch}';
        UserCredential cred;
        try {
          cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: tempPassword,
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            // Account already exists — sign in to resend verification
            cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: tempPassword,
            );
          } else {
            rethrow;
          }
        }
        final user = cred.user;
        if (user != null && !user.emailVerified) {
          await user.sendEmailVerification();
          return true;
        }
        return user?.emailVerified ?? false;
      } catch (e) {
        print('sendEmailVerificationLink error: $e');
        return false;
      }
    } else {
      // Mock: always succeed
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }
  }

  /// Reloads the current Firebase user and returns whether their email is verified.
  Future<bool> checkEmailVerified() async {
    if (_firebaseInitialized) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return false;
        await user.reload();
        return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      } catch (e) {
        print('checkEmailVerified error: $e');
        return false;
      }
    } else {
      // Mock: always return verified
      return true;
    }
  }

  // Upload an image file to cloud storage (with Cloudflare R2 rewiring)
  Future<String> uploadImageFile(File file, String folder) async {
    final user = currentUser;
    final userId = user?.uid ?? "anonymous";

    try {
      final r2Service = CloudflareR2Service();
      final uploadUrl = await r2Service.uploadAvatar(file, userId);
      return uploadUrl;
    } catch (e) {
      print("Cloudflare R2 upload failed or credentials missing: $e. Falling back to Firebase Storage.");
      
      final fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
      if (_firebaseInitialized) {
        try {
          final ref = FirebaseStorage.instance.ref().child("$folder/$fileName");
          final uploadTask = await ref.putFile(file);
          final downloadUrl = await uploadTask.ref.getDownloadURL();
          return downloadUrl;
        } catch (storageError) {
          print("Firebase Storage Error: $storageError");
          rethrow;
        }
      } else {
        // Mock Upload: returns local path representing stored image
        await Future.delayed(const Duration(milliseconds: 1000));
        return "https://mock-firebase-storage.easylens.internal/$folder/$fileName";
      }
    }
  }

  // Update Display Name
  Future<void> updateDisplayName(String name) async {
    if (_firebaseInitialized) {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
    } else {
      if (_mockUser != null) {
        _mockUser = EasyLensUser(
          uid: _mockUser!.uid,
          email: _mockUser!.email,
          displayName: name,
          isForMyself: _mockUser!.isForMyself,
        );
      }
    }
  }

  // Update Password
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_firebaseInitialized) {
      // Reauthenticate can be added here if needed by real firebase, but basic update is:
      await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  // Sync user preferences — writes to Firebase Firestore.
  Future<void> syncPreferencesToCloud(String userId, Map<String, dynamic> prefsJson) async {
    if (_firebaseInitialized) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        final Map<String, dynamic> updateData = {
          'uid': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (currentUser?.email != null) {
          updateData['email'] = currentUser!.email;
        }

        if (prefsJson.containsKey('name')) {
          updateData['displayName'] = prefsJson['name'];
        } else if (currentUser?.displayName != null) {
          updateData['displayName'] = currentUser!.displayName;
        }

        if (prefsJson.containsKey('isForMyself')) {
          updateData['isForMyself'] = prefsJson['isForMyself'];
        }

        if (prefsJson.containsKey('selectedConditions')) {
          updateData['selectedConditions'] = prefsJson['selectedConditions'];
        }

        if (prefsJson.containsKey('photoUrl')) {
          updateData['photoUrl'] = prefsJson['photoUrl'];
        }

        final docRef = FirebaseFirestore.instance.collection('users').doc(userId);
        final doc = await docRef.get();
        if (!doc.exists) {
          updateData['createdAt'] = FieldValue.serverTimestamp();
        }

        updateData['preferences'] = prefsJson;

        await docRef.set(updateData, SetOptions(merge: true));
        print('Firestore: Preferences saved for $userId.');
      } catch (e) {
        print('Firestore preferences sync error: $e');
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 100));
      print('Mock: Preferences saved locally.');
    }
  }

  // Sync emergency contact — writes to Firebase Firestore.
  Future<void> syncContactToCloud(String userId, Map<String, dynamic> contactJson) async {
    if (_firebaseInitialized) {
      try {
        final rawPhone = contactJson['phone'] as String? ?? '';
        final normalizedPhone = EmergencyContactService.normalizePhoneNumber(rawPhone);
        final updatedJson = Map<String, dynamic>.from(contactJson)..['phone'] = normalizedPhone;
        final contactId = normalizedPhone.replaceAll(RegExp(r'\s+'), '');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('contacts')
            .doc(contactId)
            .set(updatedJson);
        print('Firestore: Contact saved for $userId ($contactId).');
      } catch (e) {
        print('Firestore contact sync error: $e');
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 100));
      print('Mock: Contact saved locally.');
    }
  }

  /// Deletes an emergency contact document from Cloud Firestore.
  Future<void> deleteContactFromCloud(String userId, String phone) async {
    if (_firebaseInitialized) {
      try {
        final normalizedPhone = EmergencyContactService.normalizePhoneNumber(phone);
        final contactId = normalizedPhone.replaceAll(RegExp(r'\s+'), '');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('contacts')
            .doc(contactId)
            .delete();
        print('Firestore: Contact deleted for $userId ($contactId).');
      } catch (e) {
        print('Firestore contact delete error: $e');
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 100));
      print('Mock: Contact deleted locally.');
    }
  }

  /// Fetches emergency contacts from Cloud Firestore for the logged-in user and populates local storage.
  Future<void> fetchContactsFromCloud(String userId) async {
    if (!_firebaseInitialized) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get();

      List<SharedEmergencyContact> cloudContacts = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        final contact = SharedEmergencyContact.fromJson(data);
        cloudContacts.add(contact);
      }
      await EmergencyContactService().setContacts(cloudContacts);
    } catch (e) {
      print('Firestore contact fetch error: $e');
    }
  }

  // Save recent navigation data to local storage and Firestore (Max 5 items)
  Future<void> saveRecentNavigation(String userId, Map<String, dynamic> navData) async {
    final nameStr = (navData['name'] as String? ?? '').trim();
    if (nameStr.isEmpty) return;

    // 1. Save to SharedPreferences locally
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> recentList = prefs.getStringList('recent_navigation') ?? [];
      
      // Keep only unique entries by destination name
      final newName = nameStr.toLowerCase();
      recentList.removeWhere((item) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(item);
          final existingName = (decoded['name'] as String? ?? '').trim().toLowerCase();
          return existingName == newName;
        } catch (_) {
          return false;
        }
      });
      
      // Insert newest at top (index 0)
      recentList.insert(0, jsonEncode(navData));
      
      // Limit local list size strictly to 5 entries (removes oldest when > 5)
      if (recentList.length > 5) {
        recentList.removeRange(5, recentList.length);
      }
      await prefs.setStringList('recent_navigation', recentList);
      print('Local: Navigation history saved (Max 5 entries).');
    } catch (e) {
      print('Local navigation history save error: $e');
    }

    // 2. Save to Firestore
    if (_firebaseInitialized) {
      try {
        final docId = DateTime.now().millisecondsSinceEpoch.toString();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('recent_navigation')
            .doc(docId)
            .set({
              ...navData,
              'timestamp': FieldValue.serverTimestamp(),
            });
        print('Firestore: Navigation history saved for $userId.');
      } catch (e) {
        print('Firestore navigation history sync error: $e');
      }
    }
  }

  // Get recent navigation history from local storage and Firestore (Max 5 items)
  Future<List<Map<String, dynamic>>> getRecentNavigations(String? userId) async {
    final List<Map<String, dynamic>> results = [];
    final Set<String> seenNames = {};

    // 1. Load from local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> recentList = prefs.getStringList('recent_navigation') ?? [];
      for (final item in recentList) {
        try {
          final Map<String, dynamic> decoded = Map<String, dynamic>.from(jsonDecode(item));
          final name = (decoded['name'] as String? ?? '').trim();
          if (name.isNotEmpty && !seenNames.contains(name.toLowerCase())) {
            seenNames.add(name.toLowerCase());
            results.add(decoded);
          }
          if (results.length >= 5) break;
        } catch (_) {}
      }
    } catch (e) {
      print('Local recent navigation read error: $e');
    }

    // 2. Load from Firestore if user logged in
    if (_firebaseInitialized && userId != null && userId.isNotEmpty && results.length < 5) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('recent_navigation')
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final name = (data['name'] as String? ?? '').trim();
          if (name.isNotEmpty && !seenNames.contains(name.toLowerCase())) {
            seenNames.add(name.toLowerCase());
            results.add(Map<String, dynamic>.from(data));
          }
          if (results.length >= 5) break;
        }
      } catch (e) {
        print('Firestore recent navigation read error: $e');
      }
    }

    return results.take(5).toList();
  }
}