import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';

// STEP 5: Accessibility
class StepAccessibility extends StatelessWidget {
  final bool voiceFeedback;
  final bool hapticFeedback;
  final String language;
  final ValueChanged<bool> onVoiceChanged;
  final ValueChanged<bool> onHapticChanged;

  const StepAccessibility({
    super.key,
    required this.voiceFeedback,
    required this.hapticFeedback,
    required this.language,
    required this.onVoiceChanged,
    required this.onHapticChanged,
  });

  Widget _buildAccessibilityCard({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primaryButtonText,
            activeTrackColor: AppColors.primaryButton,
            inactiveThumbColor: AppColors.primaryText.withValues(alpha: 0.6),
            inactiveTrackColor: AppColors.unselectedBorder,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('accessibility_title', language),
          subtitle: SignupL10n.t('accessibility_subtitle', language),
        ),
        const SizedBox(height: 32),
        _buildAccessibilityCard(
          title: SignupL10n.t('accessibility_voice', language),
          value: voiceFeedback,
          onChanged: onVoiceChanged,
        ),
        const SizedBox(height: 16),
        _buildAccessibilityCard(
          title: SignupL10n.t('accessibility_haptic', language),
          value: hapticFeedback,
          onChanged: onHapticChanged,
        ),
      ],
    );
  }
}
