import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';

class StepSignupMode extends StatelessWidget {
  final bool isVoiceMode;
  final String language;
  final ValueChanged<bool> onChanged;

  const StepSignupMode({
    super.key,
    required this.isVoiceMode,
    required this.language,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('mode_title', language),
          subtitle: SignupL10n.t('mode_subtitle', language),
        ),
        const SizedBox(height: 24),

        // Option 1: Voice Command Fillup
        GestureDetector(
          onTap: () => onChanged(true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isVoiceMode ? AppColors.primaryButton.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isVoiceMode ? AppColors.primaryButton : AppColors.cardBorder.withOpacity(0.4),
                width: isVoiceMode ? 2.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isVoiceMode ? AppColors.primaryButton : AppColors.lightBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    color: isVoiceMode ? Colors.white : AppColors.primaryText,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              SignupL10n.t('mode_voice_title', language),
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                          if (isVoiceMode)
                            Icon(Icons.check_circle, color: AppColors.primaryButton, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        SignupL10n.t('mode_voice_desc', language),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.primaryText.withOpacity(0.7),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Option 2: Manual Form Fillup
        GestureDetector(
          onTap: () => onChanged(false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: !isVoiceMode ? AppColors.primaryButton.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: !isVoiceMode ? AppColors.primaryButton : AppColors.cardBorder.withOpacity(0.4),
                width: !isVoiceMode ? 2.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: !isVoiceMode ? AppColors.primaryButton : AppColors.lightBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.touch_app_rounded,
                    color: !isVoiceMode ? Colors.white : AppColors.primaryText,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              SignupL10n.t('mode_manual_title', language),
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                          if (!isVoiceMode)
                            Icon(Icons.check_circle, color: AppColors.primaryButton, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        SignupL10n.t('mode_manual_desc', language),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.primaryText.withOpacity(0.7),
                          height: 1.3,
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
    );
  }
}
