import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';

// STEP 7: Mobility Aids
class StepMobilityAids extends StatelessWidget {
  final String selectedAid;
  final String language;
  final ValueChanged<String> onChanged;

  StepMobilityAids({
    super.key,
    required this.selectedAid,
    required this.language,
    required this.onChanged,
  });

  List<String> _aidKeys = [
    'mobility_white_cane',
    'mobility_guide_dog',
    'mobility_smart_glasses',
    'mobility_eyeglasses',
    'mobility_wheelchair',
    'mobility_walker',
    'mobility_sighted_guide',
    'mobility_none',
  ];

  // The stored value stays in English (for Firestore compatibility)
  final List<String> _aidValues = [
    'White Cane',
    'Guide Dog',
    'Smart Glasses',
    'Eyeglasses',
    'Wheelchair',
    'Walker',
    'Sighted Guide',
    'None',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('mobility_title', language),
          subtitle: SignupL10n.t('mobility_subtitle', language),
        ),
        const SizedBox(height: 24),
        Column(
          children: List.generate(_aidKeys.length, (i) {
            final key = _aidKeys[i];
            final value = _aidValues[i];
            final label = SignupL10n.t(key, language);
            final isSelected = selectedAid == value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF002663) : Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF002663) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF002663),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
