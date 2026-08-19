import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_service.dart';
import '../../constants/colors.dart';
import '../../services/sound_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _firebaseService = FirebaseService();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all password fields.')),
      );
      return;
    }

    try {
      await _firebaseService.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Sticky Header Bar (Back Button + Title)
                Container(
                  color: AppColors.lightBackground,
                  padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          SoundService.playClick();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : (isDefault ? Colors.white : AppColors.primaryBackground),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.6 : (isDefault ? 0.0 : 1.0)), width: 1.5),
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
                      const SizedBox(height: 16),
                      Text(
                        'Password',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: headerColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                  
                  // 3. Form Input Container Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.6 : (isDefault ? 0.0 : 1.0)), width: 1.5),
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
                        // Current Password
                        Text(
                          'Current Password',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: tileTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _currentPasswordController,
                          obscureText: true,
                          style: TextStyle(color: tileTextColor),
                          decoration: InputDecoration(
                            hintText: 'Enter current password',
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                            filled: true,
                            fillColor: inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : BorderSide.none.color),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // New Password
                        Text(
                          'New Password',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: tileTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newPasswordController,
                          obscureText: true,
                          style: TextStyle(color: tileTextColor),
                          decoration: InputDecoration(
                            hintText: 'Enter new password',
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                            filled: true,
                            fillColor: inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : BorderSide.none.color),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Update Password Action Button
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
                            onPressed: () {
                              SoundService.playClick();
                              _handleUpdatePassword();
                            },
                            child: Text(
                              'Update Password',
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
        ],
      ),
    ),
  );
      },
    );
  }
}
