import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';

// STEP 9: Create Account
class StepCreateAccount extends StatelessWidget {
  final String language;
  final ValueChanged<String> onSelectedMethod;

  const StepCreateAccount({
    super.key,
    required this.language,
    required this.onSelectedMethod,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('create_account_title', language),
          subtitle: SignupL10n.t('create_account_subtitle', language),
        ),
        const SizedBox(height: 32),
        
        // Email Button (Primary Sign In Method)
        SizedBox(
          width: double.infinity,
          height: 72,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryButton,
              foregroundColor: AppColors.primaryButtonText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),
            onPressed: () => onSelectedMethod('Email'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mail_outline, size: 26),
                const SizedBox(width: 12),
                Text(
                  SignupL10n.t('create_account_email', language),
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
