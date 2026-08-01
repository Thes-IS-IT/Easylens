import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_service.dart';
import '../../services/emergency_contact_service.dart';
import '../../constants/colors.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final _firebaseService = FirebaseService();

  // Controllers for account and profile details
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _birthdayController;
  late TextEditingController _sosNameController;
  late TextEditingController _sosPhoneController;
  late TextEditingController _sosRelController;

  String? _avatarUrl;
  bool _isUploading = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final user = _firebaseService.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? "");
    _emailController = TextEditingController(text: user?.email ?? "");
    _birthdayController = TextEditingController();
    _sosNameController = TextEditingController();
    _sosPhoneController = TextEditingController();
    _sosRelController = TextEditingController();

    _loadProfileDetails();

    // Initialize deterministic avatar URL from Cloudflare R2
    final userId = user?.uid ?? "anonymous";
    final accountId = dotenv.env['ACCOUNT_ID'] ?? '';
    final bucketName = dotenv.env['BUCKET_NAME'] ?? 'easylens';
    final publicUrl = dotenv.env['CLOUDFLARE_R2_PUBLIC_URL'] ?? '';

    if (accountId.isNotEmpty) {
      if (publicUrl.isNotEmpty) {
        _avatarUrl = "$publicUrl/users/$userId/avatar.png";
      } else {
        _avatarUrl = "https://pub-$accountId.r2.dev/$bucketName/users/$userId/avatar.png";
      }
    } else {
      _avatarUrl = "https://mock-cloudflare-storage.easylens.internal/users/$userId/avatar.png";
    }
  }

  Future<void> _loadProfileDetails() async {
    final user = _firebaseService.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;

          // Load name, birthday, photo from preferences
          if (data.containsKey('preferences')) {
            final prefs = data['preferences'] as Map<String, dynamic>;
            if (prefs.containsKey('name') && (prefs['name'] as String).trim().isNotEmpty) {
              _nameController.text = prefs['name'];
              SettingsService().updateDisplayName(prefs['name']);
            }
            if (prefs.containsKey('birthday')) {
              _birthdayController.text = prefs['birthday'] ?? '';
            }
            if (prefs.containsKey('photoUrl') && (prefs['photoUrl'] as String).isNotEmpty) {
              _avatarUrl = prefs['photoUrl'];
            }
          }

          // Load emergency contact
          if (data.containsKey('emergencyContact')) {
            final contact = data['emergencyContact'] as Map<String, dynamic>;
            _sosNameController.text = contact['name'] ?? '';
            _sosPhoneController.text = contact['phone'] ?? '';
            _sosRelController.text = contact['relationship'] ?? '';
          }
        }
      } catch (e) {
        print("Error fetching profile details: $e");
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    _sosNameController.dispose();
    _sosPhoneController.dispose();
    _sosRelController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _isUploading = true;
        });

        final file = File(pickedFile.path);
        final uploadedUrl = await _firebaseService.uploadImageFile(file, "users");

        setState(() {
          _avatarUrl = "$uploadedUrl?t=${DateTime.now().millisecondsSinceEpoch}";
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar uploaded successfully!')),
          );
        }
      }
    } catch (e) {
      print("Image picker/upload error: $e");
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload avatar: $e')),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final birthday = _birthdayController.text.trim();
    final sosName = _sosNameController.text.trim();
    final sosPhone = _sosPhoneController.text.trim();
    final sosRel = _sosRelController.text.trim();

    final user = _firebaseService.currentUser;
    if (user != null) {
      // 1. Update Display Name in Firebase Auth & SettingsService
      if (name.isNotEmpty) {
        await _firebaseService.updateDisplayName(name);
        await SettingsService().updateDisplayName(name);
      }

      // 2. Sync Preferences (Name & Birthday) to Cloud Firestore
      final prefsJson = {
        'name': name,
        'birthday': birthday,
        if (_avatarUrl != null) 'photoUrl': _avatarUrl,
      };
      await _firebaseService.syncPreferencesToCloud(user.uid, prefsJson);

      // 3. Sync Emergency SOS Contact to Cloud Firestore & EmergencyContactService
      if (sosName.isNotEmpty || sosPhone.isNotEmpty) {
        final normPhone = EmergencyContactService.normalizePhoneNumber(sosPhone);
        final sosJson = {
          'name': sosName.isNotEmpty ? sosName : "SOS Contact",
          'phone': normPhone,
          'relationship': sosRel.isNotEmpty ? sosRel : "Family",
        };
        await _firebaseService.syncContactToCloud(user.uid, sosJson);
        await EmergencyContactService().saveContact(
          SharedEmergencyContact(
            name: sosName.isNotEmpty ? sosName : "SOS Contact",
            phone: normPhone,
            relationship: sosRel.isNotEmpty ? sosRel : "Family",
            isActive: true,
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile & Emergency Contact updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Widget _buildInputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required Color tileTextColor,
    required Color inputFill,
    IconData? icon,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: tileTextColor,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 15, color: tileTextColor),
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF94A3B8)) : null,
            hintText: hintText,
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
            filled: true,
            fillColor: inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();
        final isDark = settings.isDarkMode;
        final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;
        final headerColor = AppColors.primaryText;
        final tileTextColor = isDark ? Colors.white : (isDefault ? Colors.black : AppColors.primaryText);
        final cardColor = isDark ? const Color(0xFF141414) : AppColors.primaryBackground;
        final inputFill = isDark ? const Color(0xFF1E1E1E) : (isDefault ? const Color(0xFFF8FAFC) : const Color(0xFF1A1A1A));

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sticky Header Bar (Back Button + Title)
                      Container(
                        color: AppColors.lightBackground,
                        padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E1E) : (isDefault ? Colors.white : AppColors.primaryBackground),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.6 : (isDefault ? 0.0 : 1.0)), width: 1.5),
                                  boxShadow: isDefault
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.06),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chevron_left, color: headerColor, size: 24),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Back',
                                      style: GoogleFonts.inter(
                                        color: headerColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Profile Details',
                              style: GoogleFonts.inter(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: headerColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Scrollable Content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                        const SizedBox(height: 24),

                        // 3. Circle Avatar with Floating Camera Badge
                        Center(
                          child: GestureDetector(
                            onTap: _isUploading ? null : _pickAndUploadImage,
                            child: Stack(
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE2E8F0),
                                    shape: BoxShape.circle,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: _isUploading
                                      ? const Center(
                                          child: SizedBox(
                                            width: 36,
                                            height: 36,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                                            ),
                                          ),
                                        )
                                      : (_avatarUrl != null && !_avatarUrl!.startsWith("https://mock-cloudflare-storage.easylens.internal"))
                                          ? Image.network(
                                              _avatarUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Center(
                                                  child: Icon(
                                                    Icons.person_outline,
                                                    size: 56,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                );
                                              },
                                            )
                                          : const Center(
                                              child: Icon(
                                                Icons.person_outline,
                                                size: 56,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryButton,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // 4. Personal Information Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24.0),
                            border: isDefault ? null : Border.all(color: AppColors.cardBorder, width: 1.5),
                            boxShadow: isDefault
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Personal Information',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: headerColor,
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildInputField(
                                label: 'Full Name',
                                hintText: 'Enter name',
                                controller: _nameController,
                                tileTextColor: tileTextColor,
                                inputFill: inputFill,
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 14),

                              _buildInputField(
                                label: 'Email Address',
                                hintText: 'Your registered email',
                                controller: _emailController,
                                tileTextColor: tileTextColor,
                                inputFill: inputFill,
                                icon: Icons.email_outlined,
                                readOnly: true,
                              ),
                              const SizedBox(height: 14),

                              _buildInputField(
                                label: 'Birthday',
                                hintText: 'DD/MM/YYYY',
                                controller: _birthdayController,
                                tileTextColor: tileTextColor,
                                inputFill: inputFill,
                                icon: Icons.cake_outlined,
                                keyboardType: TextInputType.datetime,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 5. Emergency Contact Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24.0),
                            border: isDefault ? null : Border.all(color: AppColors.cardBorder, width: 1.5),
                            boxShadow: isDefault
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Emergency SOS Contact',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: headerColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Contact alerted in case of an emergency.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildInputField(
                                label: 'Contact Name',
                                hintText: 'Emergency contact name',
                                controller: _sosNameController,
                                tileTextColor: tileTextColor,
                                inputFill: inputFill,
                                icon: Icons.person_pin_outlined,
                              ),
                              const SizedBox(height: 14),

                              _buildInputField(
                                label: 'Phone Number',
                                hintText: 'Emergency contact phone',
                                controller: _sosPhoneController,
                                tileTextColor: tileTextColor,
                                inputFill: inputFill,
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 14),

                              _buildInputField(
                                label: 'Relationship',
                                hintText: 'e.g. Sister, Friend',
                                controller: _sosRelController,
                                tileTextColor: tileTextColor,
                                inputFill: inputFill,
                                icon: Icons.favorite_border,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // 6. Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryButton,
                              foregroundColor: AppColors.primaryButtonText,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28.0),
                              ),
                            ),
                            onPressed: _handleSave,
                            child: Text(
                              'Save Changes',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
