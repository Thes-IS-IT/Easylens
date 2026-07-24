import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';

// STEP 1: Language Selection
class StepLanguage extends StatelessWidget {
  final String selectedLanguage;
  final String language;
  final ValueChanged<String> onChanged;

  const StepLanguage({
    super.key,
    required this.selectedLanguage,
    required this.language,
    required this.onChanged,
  });

  Widget _buildLanguageButton(String language) {
    final isSelected = selectedLanguage == language;
    return GestureDetector(
      onTap: () => onChanged(language),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryButton : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(28.0),
          border: Border.all(
            color: isSelected ? AppColors.primaryButton : AppColors.cardBorder.withValues(alpha: 0.4),
            width: isSelected ? 2.0 : 1.5,
          ),
        ),
        child: Center(
          child: Text(
            language,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('language_title', language),
          subtitle: SignupL10n.t('language_subtitle', language),
        ),
        const SizedBox(height: 32),
        _buildLanguageButton('English'),
        const SizedBox(height: 16),
        _buildLanguageButton('Filipino'),
      ],
    );
  }
}
