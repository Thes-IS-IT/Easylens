import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_service.dart';
import '../../constants/colors.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final _firebaseService = FirebaseService();
  late TextEditingController _nameController;
  String? _avatarUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final user = _firebaseService.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? "");
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
      // Fetch dynamic displayName from Firestore
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data.containsKey('preferences')) {
            final prefs = data['preferences'] as Map<String, dynamic>;
            if (prefs.containsKey('name') && (prefs['name'] as String).trim().isNotEmpty) {
              setState(() {
                _nameController.text = prefs['name'];
              });
            }
          }
        }
      } catch (e) {
        print("Error fetching profile name: $e");
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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
        // This will attempt upload to Cloudflare R2, falling back to Firebase Storage if credentials missing S01
        final uploadedUrl = await _firebaseService.uploadImageFile(file, "users");

        setState(() {
          // Append cache buster to force Image.network to update the image
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
    if (name.isNotEmpty) {
      final user = _firebaseService.currentUser;
      if (user != null) {
        // Sync name preference to Firestore
        await _firebaseService.syncPreferencesToCloud(user.uid, {'name': name});
      }
      await _firebaseService.updateDisplayName(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile details updated successfully.')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final isDefault = SettingsService().selectedContrastTheme == 'Default';
        final headerColor = isDefault ? const Color(0xFF002663) : AppColors.primaryText;
        final tileTextColor = isDefault ? Colors.black : AppColors.primaryText;
        final cardColor = AppColors.primaryBackground;
        final inputFill = isDefault ? const Color(0xFFF8FAFC) : const Color(0xFF1A1A1A);

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Floating Pill Back Button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDefault ? Colors.white : AppColors.primaryBackground,
                        borderRadius: BorderRadius.circular(22),
                        border: isDefault ? null : Border.all(color: AppColors.cardBorder, width: 1.5),
                        boxShadow: isDefault ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ] : null,
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

                  const SizedBox(height: 32),

                  // 2. Title Header
                  Text(
                    'Profile Details',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: headerColor,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 3. Circle Avatar with Floating Camera Action Badge
                  Center(
                    child: GestureDetector(
                      onTap: _isUploading ? null : _pickAndUploadImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _isUploading
                                ? const Center(
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
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
                                              size: 64,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(
                                            child: SizedBox(
                                              width: 30,
                                              height: 30,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          );
                                        },
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.person_outline,
                                          size: 64,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 38,
                              height: 38,
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
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 4. Input Form Container Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24.0),
                      border: isDefault ? null : Border.all(color: AppColors.cardBorder, width: 1.5),
                      boxShadow: isDefault ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ] : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What should I call you?',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: tileTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose how Buddy refers to you in the app.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _nameController,
                          style: TextStyle(color: tileTextColor),
                          decoration: InputDecoration(
                            hintText: 'Enter name',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                            filled: true,
                            fillColor: inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 24),
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
                              'Save Profile',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
