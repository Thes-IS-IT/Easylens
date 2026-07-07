import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/firebase_service.dart';
import '../../constants/colors.dart';

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
                  width: 95,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chevron_left, color: Color(0xFF002663), size: 24),
                      const SizedBox(width: 4),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF002663),
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
                'Password',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF002663),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 3. Form Input Container Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ],
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
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Enter current password',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
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
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Enter new password',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
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
                        onPressed: _handleUpdatePassword,
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
    );
  }
}
