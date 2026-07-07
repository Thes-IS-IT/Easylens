import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';

// STEP 9: Create Account
class StepCreateAccount extends StatelessWidget {
  final ValueChanged<String> onSelectedMethod;

  const StepCreateAccount({
    super.key,
    required this.onSelectedMethod,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Create Account',
          subtitle: 'Choose how to sign up.',
        ),
        const SizedBox(height: 32),
        
        // Google button
        SizedBox(
          width: double.infinity,
          height: 72,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryButton,
              foregroundColor: AppColors.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),
            onPressed: () => onSelectedMethod('Google'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.g_mobiledata, size: 44),
                const SizedBox(width: 8),
                Text(
                  'Google',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Email button
        SizedBox(
          width: double.infinity,
          height: 72,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryText,
              side: BorderSide(color: AppColors.cardBorder, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),
            onPressed: () => onSelectedMethod('Email'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mail_outline, size: 26),
                const SizedBox(width: 8),
                Text(
                  'Email',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
