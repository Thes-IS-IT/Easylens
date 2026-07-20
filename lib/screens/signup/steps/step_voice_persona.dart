import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';

// STEP 6: Voice Persona
class StepVoicePersona extends StatelessWidget {
  final String selectedPersona;
  final String language;
  final ValueChanged<String> onChanged;

  StepVoicePersona({
    super.key,
    required this.selectedPersona,
    required this.language,
    required this.onChanged,
  });

  List<Map<String, String>> _buildPersonas(String lang) => [
    {'name': 'Aria (Calm)', 'desc': SignupL10n.t('voice_aria_desc', lang)},
    {'name': 'Max (Bold)', 'desc': SignupL10n.t('voice_max_desc', lang)},
    {'name': 'Nova (Bright)', 'desc': SignupL10n.t('voice_nova_desc', lang)},
    {'name': 'Echo (Deep)', 'desc': SignupL10n.t('voice_echo_desc', lang)},
    {'name': 'Bella (Gentle)', 'desc': SignupL10n.t('voice_bella_desc', lang)},
    {'name': 'Leo (Child)', 'desc': SignupL10n.t('voice_leo_desc', lang)},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('voice_persona_title', language),
          subtitle: SignupL10n.t('voice_persona_subtitle', language),
        ),
        const SizedBox(height: 24),
        Column(
          children: _buildPersonas(language).map((p) {
            final name = p['name']!;
            final desc = p['desc']!;
            final isSelected = selectedPersona == name;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () => onChanged(name),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryButton : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryButton : AppColors.cardBorder.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.volume_up,
                        color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
                              ),
                            ),
                            Text(
                              desc,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isSelected ? AppColors.primaryButtonText.withOpacity(0.8) : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
                            width: 2.0,
                          ),
                        ),
                        child: isSelected
                            ? Icon(Icons.check, size: 16, color: AppColors.primaryButtonText)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
