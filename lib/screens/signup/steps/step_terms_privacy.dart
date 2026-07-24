import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';

// STEP 13: Terms & Privacy
class StepTermsPrivacy extends StatelessWidget {
  final String language;
  final VoidCallback onAgree;
  final VoidCallback onReadDocument;

  const StepTermsPrivacy({
    super.key,
    required this.language,
    required this.onAgree,
    required this.onReadDocument,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('terms_title', language),
          subtitle: '',
        ),
        const SizedBox(height: 24),

        // Data safety card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.lightBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Data is Safe',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                SignupL10n.t('terms_body', language),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _PrivacyItem(
                icon: Icons.smartphone_outlined,
                label: SignupL10n.t('terms_local_label', language),
                body: SignupL10n.t('terms_local_body', language),
              ),
              const SizedBox(height: 16),
              _PrivacyItem(
                icon: Icons.shield_outlined,
                label: SignupL10n.t('terms_privacy_label', language),
                body: SignupL10n.t('terms_privacy_body', language),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // I Agree button
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryButton,
              foregroundColor: AppColors.primaryButtonText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: onAgree,
            child: Text(
              SignupL10n.t('terms_agree', language),
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Read Full Document button
        SizedBox(
          width: double.infinity,
          height: 58,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryText,
              side: BorderSide(color: AppColors.primaryButton, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: onReadDocument,
            child: Text(
              SignupL10n.t('terms_read', language),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String body;

  const _PrivacyItem({
    required this.icon,
    required this.label,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primaryText.withOpacity(0.3), width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.primaryText),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.primaryText, height: 1.5),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
