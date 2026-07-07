import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';

// STEP 6: Voice Persona
class StepVoicePersona extends StatelessWidget {
  final String selectedPersona;
  final ValueChanged<String> onChanged;

  StepVoicePersona({
    super.key,
    required this.selectedPersona,
    required this.onChanged,
  });

  final List<Map<String, String>> personas = [
    {'name': 'Aria (Calm)', 'desc': 'Soft, reassuring voice assistant tone.'},
    {'name': 'Max (Bold)', 'desc': 'Clear, loud, and confident command style.'},
    {'name': 'Nova (Bright)', 'desc': 'Energetic, friendly, and enthusiastic.'},
    {'name': 'Echo (Deep)', 'desc': 'Low baritone voice with strong echoes.'},
    {'name': 'Bella (Gentle)', 'desc': 'Quiet, slow-paced directions for focus.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Voice Persona',
          subtitle: 'Choose the AI synthesizer voice tone preference.',
        ),
        const SizedBox(height: 24),
        Column(
          children: personas.map((p) {
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
